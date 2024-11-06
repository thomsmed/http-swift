import Foundation
import HTTP

// MARK: TrustProvider

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

public protocol TrustProvider: Sendable {
    var accessToken: AccessToken? { get async }
    func sign(_ request: URLRequest) async throws -> DPoP
}

// MARK: ProtectedEndpointClient

public final class ProtectedEndpointClient: Sendable {
    struct Interceptor: HTTP.Interceptor {
        let trustProvider: any TrustProvider
        let authenticationScheme: AuthenticationScheme

        func prepare(
            _ request: inout URLRequest,
            with context: HTTP.Context
        ) async throws {
            switch authenticationScheme {
                case .none:
                    break

                case .dPoP:
                    let dPoP = try await trustProvider.sign(request)
                    request.setValue(dPoP.rawValue, forHTTPHeaderField: "DPoP")

                case .accessToken:
                    if let accessToken = await trustProvider.accessToken {
                        request.setValue("Bearer \(accessToken.rawValue)", forHTTPHeaderField: "Authorization")
                    }

                case .dPoPAndAccessToken:
                    if let accessToken = await trustProvider.accessToken {
                        request.setValue("DPoP \(accessToken.rawValue)", forHTTPHeaderField: "Authorization")
                    }
                    let dPoP = try await trustProvider.sign(request)
                    request.setValue(dPoP.rawValue, forHTTPHeaderField: "DPoP")
            }
        }

        func handle(
            _ transportError: any Error,
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
    private let trustProvider: any TrustProvider

    public init(httpClient: HTTP.Client, trustProvider: any TrustProvider) {
        self.httpClient = httpClient
        self.trustProvider = trustProvider
    }
}

// MARK: Calling ProtectedEndpoint

public extension ProtectedEndpointClient {
    func call<Resource>(
        _ protectedEndpoint: ProtectedEndpoint<Resource?>
    ) async -> Result<Resource?, HTTP.Failure> {
        let endpoint = protectedEndpoint.endpoint
        let authenticationScheme = protectedEndpoint.authenticationScheme

        if let requestBody = endpoint.requestBody, let requestContentType = endpoint.requestContentType {
            return await httpClient.fetch(
                Resource.self,
                url: endpoint.url,
                method: endpoint.method,
                requestBody: requestBody,
                requestContentType: requestContentType,
                responseContentType: endpoint.responseContentType ?? .json,
                emptyResponseStatusCodes: endpoint.emptyResponseStatusCodes,
                interceptors: [
                    Interceptor(
                        trustProvider: trustProvider,
                        authenticationScheme: authenticationScheme
                    )
                ] + endpoint.interceptors,
                adaptor: endpoint.adaptor
            )
        } else {
            return await httpClient.fetch(
                Resource.self,
                url: endpoint.url,
                method: endpoint.method,
                responseContentType: endpoint.responseContentType ?? .json,
                emptyResponseStatusCodes: endpoint.emptyResponseStatusCodes,
                interceptors: [
                    Interceptor(
                        trustProvider: trustProvider,
                        authenticationScheme: authenticationScheme
                    )
                ] + endpoint.interceptors,
                adaptor: endpoint.adaptor
            )
        }
    }

    func call<Resource>(
        _ protectedEndpoint: ProtectedEndpoint<Resource>
    ) async -> Result<Resource, HTTP.Failure> {
        let endpoint = protectedEndpoint.endpoint
        let authenticationScheme = protectedEndpoint.authenticationScheme

        if let requestBody = endpoint.requestBody, let requestContentType = endpoint.requestContentType {
            return await httpClient.fetch(
                Resource.self,
                url: endpoint.url,
                method: endpoint.method,
                requestBody: requestBody,
                requestContentType: requestContentType,
                responseContentType: endpoint.responseContentType ?? .json,
                interceptors: [
                    Interceptor(
                        trustProvider: trustProvider,
                        authenticationScheme: authenticationScheme
                    )
                ] + endpoint.interceptors,
                adaptor: endpoint.adaptor
            )
        } else {
            return await httpClient.fetch(
                Resource.self,
                url: endpoint.url,
                method: endpoint.method,
                responseContentType: endpoint.responseContentType ?? .json,
                interceptors: [
                    Interceptor(
                        trustProvider: trustProvider,
                        authenticationScheme: authenticationScheme
                    )
                ] + endpoint.interceptors,
                adaptor: endpoint.adaptor
            )
        }
    }

    func call(
        _ protectedEndpoint: ProtectedEndpoint<Void>
    ) async -> Result<Void, HTTP.Failure> {
        let endpoint = protectedEndpoint.endpoint
        let authenticationScheme = protectedEndpoint.authenticationScheme

        if let requestBody = endpoint.requestBody, let requestContentType = endpoint.requestContentType {
            return await httpClient.fetch(
                url: endpoint.url,
                method: endpoint.method,
                requestBody: requestBody,
                requestContentType: requestContentType,
                interceptors: [
                    Interceptor(
                        trustProvider: trustProvider,
                        authenticationScheme: authenticationScheme
                    )
                ] + endpoint.interceptors
            )
        } else {
            return await httpClient.fetch(
                url: endpoint.url,
                method: endpoint.method,
                interceptors: [
                    Interceptor(
                        trustProvider: trustProvider,
                        authenticationScheme: authenticationScheme
                    )
                ] + endpoint.interceptors
            )
        }
    }
}
