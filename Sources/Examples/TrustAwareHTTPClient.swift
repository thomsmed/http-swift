import Foundation
import HTTP

// MARK: AuthenticationScheme and TrustProvider

public enum AuthenticationScheme: Sendable {
    case none
    case dPoP
    case accessToken
    case dPoPAndAccessToken
}

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

// MARK: ProtectedEndpoint

public struct ProtectedEndpoint<RequestBody, ResponseBody> {
    let endpoint: HTTP.Endpoint<RequestBody, ResponseBody>
    let authenticationScheme: AuthenticationScheme

    public init(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor],
        authenticationScheme: AuthenticationScheme
    ) where RequestBody: Encodable, ResponseBody == Optional<Decodable> {
        self.endpoint = HTTP.Endpoint(
            method,
            at: url,
            requestBody: requestBody,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: emptyResponseStatusCodes,
            interceptors: interceptors
        )
        self.authenticationScheme = authenticationScheme
    }

    public init(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor],
        authenticationScheme: AuthenticationScheme
    ) where RequestBody: Encodable, ResponseBody: Decodable {
        self.endpoint = HTTP.Endpoint(
            method,
            at: url,
            requestBody: requestBody,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            interceptors: interceptors
        )
        self.authenticationScheme = authenticationScheme
    }

    public init(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor],
        authenticationScheme: AuthenticationScheme
    ) where RequestBody: Encodable, ResponseBody == Void {
        self.endpoint = HTTP.Endpoint(
            method,
            at: url,
            requestBody: requestBody,
            requestContentType: requestContentType,
            interceptors: interceptors
        )
        self.authenticationScheme = authenticationScheme
    }

    public init(
        _ method: HTTP.Method,
        at url: URL,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor],
        authenticationScheme: AuthenticationScheme
    ) where RequestBody == Void, ResponseBody == Optional<Decodable> {
        self.endpoint = HTTP.Endpoint(
            method,
            at: url,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: emptyResponseStatusCodes,
            interceptors: interceptors
        )
        self.authenticationScheme = authenticationScheme
    }

    public init(
        _ method: HTTP.Method,
        at url: URL,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor],
        authenticationScheme: AuthenticationScheme
    ) where RequestBody == Void, ResponseBody: Decodable {
        self.endpoint = HTTP.Endpoint(
            method,
            at: url,
            responseContentType: responseContentType,
            interceptors: interceptors
        )
        self.authenticationScheme = authenticationScheme
    }

    public init(
        _ method: HTTP.Method,
        at url: URL,
        interceptors: [HTTP.Interceptor],
        authenticationScheme: AuthenticationScheme
    ) where RequestBody == Void, ResponseBody == Void {
        self.endpoint = HTTP.Endpoint(
            method,
            at: url,
            interceptors: interceptors
        )
        self.authenticationScheme = authenticationScheme
    }
}

// MARK: TrustAwareHTTPClient

public final class TrustAwareHTTPClient: Sendable {
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
                        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                    }

                case .dPoPAndAccessToken:
                    if let accessToken = await trustProvider.accessToken {
                        let dPoP = try await trustProvider.sign(request)
                        request.setValue(dPoP.rawValue, forHTTPHeaderField: "DPoP")
                        request.setValue("DPoP \(accessToken)", forHTTPHeaderField: "Authorization")
                    }
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

public extension TrustAwareHTTPClient {
    func call<RequestBody: Encodable, ResponseBody: Decodable>(
        _ protectedEndpoint: ProtectedEndpoint<RequestBody, ResponseBody?>
    ) async -> Result<ResponseBody?, HTTP.Failure> {
        await httpClient.request(
            protectedEndpoint.endpoint.method,
            at: protectedEndpoint.endpoint.url,
            requestBody: protectedEndpoint.endpoint.requestBody,
            requestContentType: protectedEndpoint.endpoint.requestContentType,
            responseContentType: protectedEndpoint.endpoint.responseContentType,
            emptyResponseStatusCodes: protectedEndpoint.endpoint.emptyResponseStatusCodes,
            interceptors: [
                Interceptor(
                    trustProvider: trustProvider,
                    authenticationScheme: protectedEndpoint.authenticationScheme
                )
            ] + protectedEndpoint.endpoint.interceptors
        )
    }

    func call<RequestBody: Encodable, ResponseBody: Decodable>(
        _ protectedEndpoint: ProtectedEndpoint<RequestBody, ResponseBody>
    ) async -> Result<ResponseBody, HTTP.Failure> {
        await httpClient.request(
            protectedEndpoint.endpoint.method,
            at: protectedEndpoint.endpoint.url,
            requestBody: protectedEndpoint.endpoint.requestBody,
            requestContentType: protectedEndpoint.endpoint.requestContentType,
            responseContentType: protectedEndpoint.endpoint.responseContentType,
            interceptors: [
                Interceptor(
                    trustProvider: trustProvider,
                    authenticationScheme: protectedEndpoint.authenticationScheme
                )
            ] + protectedEndpoint.endpoint.interceptors
        )
    }

    func call<RequestBody: Encodable>(
        _ protectedEndpoint: ProtectedEndpoint<RequestBody, Void>
    ) async -> Result<Void, HTTP.Failure> {
        await httpClient.request(
            protectedEndpoint.endpoint.method,
            at: protectedEndpoint.endpoint.url,
            requestBody: protectedEndpoint.endpoint.requestBody,
            requestContentType: protectedEndpoint.endpoint.requestContentType,
            interceptors: [
                Interceptor(
                    trustProvider: trustProvider,
                    authenticationScheme: protectedEndpoint.authenticationScheme
                )
            ] + protectedEndpoint.endpoint.interceptors
        )
    }

    func call<ResponseBody: Decodable>(
        _ protectedEndpoint: ProtectedEndpoint<Void, ResponseBody?>
    ) async -> Result<ResponseBody?, HTTP.Failure> {
        await httpClient.request(
            protectedEndpoint.endpoint.method,
            at: protectedEndpoint.endpoint.url,
            responseContentType: protectedEndpoint.endpoint.responseContentType,
            emptyResponseStatusCodes: protectedEndpoint.endpoint.emptyResponseStatusCodes,
            interceptors: [
                Interceptor(
                    trustProvider: trustProvider,
                    authenticationScheme: protectedEndpoint.authenticationScheme
                )
            ] + protectedEndpoint.endpoint.interceptors
        )
    }

    func call<ResponseBody: Decodable>(
        _ protectedEndpoint: ProtectedEndpoint<Void, ResponseBody>
    ) async -> Result<ResponseBody, HTTP.Failure> {
        await httpClient.request(
            protectedEndpoint.endpoint.method,
            at: protectedEndpoint.endpoint.url,
            responseContentType: protectedEndpoint.endpoint.responseContentType,
            interceptors: [
                Interceptor(
                    trustProvider: trustProvider,
                    authenticationScheme: protectedEndpoint.authenticationScheme
                )
            ] + protectedEndpoint.endpoint.interceptors
        )
    }

    func call(
        _ protectedEndpoint: ProtectedEndpoint<Void, Void>
    ) async -> Result<Void, HTTP.Failure> {
        await httpClient.request(
            protectedEndpoint.endpoint.method,
            at: protectedEndpoint.endpoint.url,
            interceptors: [
                Interceptor(
                    trustProvider: trustProvider,
                    authenticationScheme: protectedEndpoint.authenticationScheme
                )
            ] + protectedEndpoint.endpoint.interceptors
        )
    }
}
