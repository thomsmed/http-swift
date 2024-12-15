import Foundation
import HTTP

// MARK: TrustMediator

public struct DPoP: RawRepresentable, Sendable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct AccessToken: RawRepresentable, Sendable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public protocol TrustMediator: Sendable {
    var accessToken: AccessToken? { get async }
    func sign(_ request: URLRequest) async throws -> DPoP
}

// MARK: ProtectedEndpointClient

public final class ProtectedEndpointClient: Sendable {
    struct Interceptor: HTTP.Interceptor {
        let trustMediator: any TrustMediator
        let authenticationScheme: AuthenticationScheme

        func prepare(
            _ request: inout URLRequest,
            with context: HTTP.Context
        ) async throws {
            switch authenticationScheme {
                case .none:
                    break

                case .dPoP:
                    let dPoP = try await trustMediator.sign(request)
                    request.setValue(dPoP.rawValue, forHTTPHeaderField: "DPoP")

                case .accessToken:
                    if let accessToken = await trustMediator.accessToken {
                        request.setValue("Bearer \(accessToken.rawValue)", forHTTPHeaderField: "Authorization")
                    }

                case .dPoPAndAccessToken:
                    if let accessToken = await trustMediator.accessToken {
                        request.setValue("DPoP \(accessToken.rawValue)", forHTTPHeaderField: "Authorization")
                    }
                    let dPoP = try await trustMediator.sign(request)
                    request.setValue(dPoP.rawValue, forHTTPHeaderField: "DPoP")
            }
        }

        func handle(
            _ transportError: HTTP.TransportError,
            with context: HTTP.Context
        ) async -> HTTP.Evaluation {
            .proceed
        }

        func process(
            _ response: inout HTTPURLResponse,
            data: inout Data,
            with context: HTTP.Context
        ) async throws -> HTTP.Evaluation {
            .proceed
        }
    }

    private let httpClient: HTTP.Client
    private let trustMediator: any TrustMediator

    public init(httpClient: HTTP.Client, trustMediator: any TrustMediator) {
        self.httpClient = httpClient
        self.trustMediator = trustMediator
    }
}

// MARK: Calling ProtectedEndpoint

public extension ProtectedEndpointClient {
    func call<Resource>(
        _ protectedEndpoint: ProtectedEndpoint<Resource>
    ) async throws -> Resource {
        try await httpClient.fetch(
            Resource.self,
            url: protectedEndpoint.url,
            method: protectedEndpoint.method,
            payload: protectedEndpoint.payload,
            parser: protectedEndpoint.parser,
            additionalHeaders: protectedEndpoint.additionalHeaders,
            interceptors: [
                Interceptor(
                    trustMediator: trustMediator,
                    authenticationScheme: protectedEndpoint.authenticationScheme
                )
            ] + protectedEndpoint.interceptors,
            tags: protectedEndpoint.tags
        )
    }
}
