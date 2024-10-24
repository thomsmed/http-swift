import Foundation
import HTTP

public enum AuthenticationScheme: Sendable {
    case none
    case dPoP
    case accessToken
    case dPoPAndAccessToken
}

public struct ProtectedEndpoint<Resource> {
    let endpoint: HTTP.Endpoint<Resource>
    let authenticationScheme: AuthenticationScheme

    public init<RequestBody: Encodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        authenticationScheme: AuthenticationScheme,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: ((HTTP.Response) throws -> Resource)? = nil
    ) where Resource == Optional<Decodable> {
        self.endpoint = HTTP.Endpoint(
            method,
            at: url,
            requestBody: requestBody,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: emptyResponseStatusCodes,
            interceptors: interceptors,
            adaptor: adaptor
        )
        self.authenticationScheme = authenticationScheme
    }

    public init<RequestBody: Encodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        authenticationScheme: AuthenticationScheme,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: @escaping (HTTP.Response) throws -> Resource
    ) {
        self.endpoint = HTTP.Endpoint(
            method,
            at: url,
            requestBody: requestBody,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: emptyResponseStatusCodes,
            interceptors: interceptors,
            adaptor: adaptor
        )
        self.authenticationScheme = authenticationScheme
    }

    public init<RequestBody: Encodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        authenticationScheme: AuthenticationScheme,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: ((HTTP.Response) throws -> Resource)? = nil
    ) where Resource: Decodable {
        self.endpoint = HTTP.Endpoint(
            method,
            at: url,
            requestBody: requestBody,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            interceptors: interceptors,
            adaptor: adaptor
        )
        self.authenticationScheme = authenticationScheme
    }

    public init<RequestBody: Encodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        authenticationScheme: AuthenticationScheme,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: @escaping (HTTP.Response) throws -> Resource
    ) {
        self.endpoint = HTTP.Endpoint(
            method,
            at: url,
            requestBody: requestBody,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            interceptors: interceptors,
            adaptor: adaptor
        )
        self.authenticationScheme = authenticationScheme
    }

    public init<RequestBody: Encodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        authenticationScheme: AuthenticationScheme,
        interceptors: [HTTP.Interceptor] = []
    ) where Resource == Void {
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
        authenticationScheme: AuthenticationScheme,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: ((HTTP.Response) throws -> Resource)? = nil
    ) where Resource == Optional<Decodable> {
        self.endpoint = HTTP.Endpoint(
            method,
            at: url,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: emptyResponseStatusCodes,
            interceptors: interceptors,
            adaptor: adaptor
        )
        self.authenticationScheme = authenticationScheme
    }

    public init(
        _ method: HTTP.Method,
        at url: URL,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        authenticationScheme: AuthenticationScheme,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: @escaping (HTTP.Response) throws -> Resource
    ) {
        self.endpoint = HTTP.Endpoint(
            method,
            at: url,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: emptyResponseStatusCodes,
            interceptors: interceptors,
            adaptor: adaptor
        )
        self.authenticationScheme = authenticationScheme
    }

    public init(
        _ method: HTTP.Method,
        at url: URL,
        responseContentType: HTTP.MimeType,
        authenticationScheme: AuthenticationScheme,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: ((HTTP.Response) throws -> Resource)? = nil
    ) where Resource: Decodable {
        self.endpoint = HTTP.Endpoint(
            method,
            at: url,
            responseContentType: responseContentType,
            interceptors: interceptors,
            adaptor: adaptor
        )
        self.authenticationScheme = authenticationScheme
    }

    public init(
        _ method: HTTP.Method,
        at url: URL,
        responseContentType: HTTP.MimeType,
        authenticationScheme: AuthenticationScheme,
        interceptors: [HTTP.Interceptor] = [],
        adapt: @escaping (HTTP.Response) throws -> Resource
    ) {
        self.endpoint = HTTP.Endpoint(
            method,
            at: url,
            responseContentType: responseContentType,
            interceptors: interceptors,
            adapt: adapt
        )
        self.authenticationScheme = authenticationScheme
    }

    public init(
        _ method: HTTP.Method,
        at url: URL,
        authenticationScheme: AuthenticationScheme,
        interceptors: [HTTP.Interceptor] = []
    ) where Resource == Void {
        self.endpoint = HTTP.Endpoint(
            method,
            at: url,
            interceptors: interceptors
        )
        self.authenticationScheme = authenticationScheme
    }
}
