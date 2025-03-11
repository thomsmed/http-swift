import Foundation
import HTTP

public enum AuthenticationScheme: Sendable {
    case none
    case dPoP
    case accessToken
    case dPoPAndAccessToken
}

public struct ProtectedEndpoint<Resource> {
    public let url: URL
    public let method: HTTP.Method
    public let payload: HTTP.RequestPayload
    public let parser: HTTP.ResponseParser<Resource>
    public let authenticationScheme: AuthenticationScheme
    public let additionalHeaders: [HTTP.Header]
    public let followRedirects: Bool
    public let interceptors: [HTTP.Interceptor]
    public let tags: [String: String]

    public init(
        url: URL,
        method: HTTP.Method,
        payload: HTTP.RequestPayload,
        parser: HTTP.ResponseParser<Resource>,
        authenticationScheme: AuthenticationScheme,
        additionalHeaders: [HTTP.Header] = [],
        followRedirects: Bool = true,
        interceptors: [HTTP.Interceptor] = [],
        tags: [String: String] = [:]
    ) {
        self.url = url
        self.method = method
        self.payload = payload
        self.parser = parser
        self.authenticationScheme = authenticationScheme
        self.additionalHeaders = additionalHeaders
        self.followRedirects = followRedirects
        self.interceptors = interceptors
        self.tags = tags
    }
}
