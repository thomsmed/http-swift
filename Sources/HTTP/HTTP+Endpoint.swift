import Foundation

public extension HTTP {
    struct Endpoint<Resource> {
        public let url: URL
        public let method: HTTP.Method
        public let payload: HTTP.RequestPayload
        public let parser: HTTP.ResponseParser<Resource>
        public let additionalHeaders: [HTTP.Header]
        public let interceptors: [HTTP.Interceptor]
        public let tags: [String: String]

        public init(
            url: URL,
            method: HTTP.Method,
            payload: HTTP.RequestPayload,
            parser: HTTP.ResponseParser<Resource>,
            additionalHeaders: [HTTP.Header] = [],
            interceptors: [HTTP.Interceptor] = [],
            tags: [String: String] = [:]
        ) {
            self.url = url
            self.method = method
            self.payload = payload
            self.parser = parser
            self.additionalHeaders = additionalHeaders
            self.interceptors = interceptors
            self.tags = tags
        }
    }
}
