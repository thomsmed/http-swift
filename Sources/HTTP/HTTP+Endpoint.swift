import Foundation

public extension HTTP {
    struct Endpoint<Resource> {
        public let request: HTTP.Request
        public let emptyResponseStatusCodes: Set<Int>
        public let interceptors: [HTTP.Interceptor]
        public let adaptor: (HTTP.Response) throws -> Resource

        public init(
            url: URL,
            method: HTTP.Method,
            requestPayload: HTTP.Request.Payload,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: ((HTTP.Response) throws -> Resource)? = nil
        ) where Resource == Optional<Decodable> {
            self.request = HTTP.Request(
                url: url,
                method: method,
                payload: requestPayload,
                contentType: requestContentType,
                accept: responseContentType
            )
            self.emptyResponseStatusCodes = emptyResponseStatusCodes
            self.interceptors = interceptors
            self.adaptor = adaptor ?? { _ in Optional<Decodable>(nil) }
        }

        public init(
            url: URL,
            method: HTTP.Method,
            requestPayload: HTTP.Request.Payload,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: @escaping (HTTP.Response) throws -> Resource
        ) {
            self.request = HTTP.Request(
                url: url,
                method: method,
                payload: requestPayload,
                contentType: requestContentType,
                accept: responseContentType
            )
            self.emptyResponseStatusCodes = emptyResponseStatusCodes
            self.interceptors = interceptors
            self.adaptor = adaptor
        }

        public init(
            url: URL,
            method: HTTP.Method,
            requestPayload: HTTP.Request.Payload,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: ((HTTP.Response) throws -> Resource)? = nil
        ) where Resource: Decodable {
            self.request = HTTP.Request(
                url: url,
                method: method,
                payload: requestPayload,
                contentType: requestContentType,
                accept: responseContentType
            )
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = adaptor ?? { response in try response.decode(as: responseContentType) }
        }

        public init(
            url: URL,
            method: HTTP.Method,
            requestPayload: HTTP.Request.Payload,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: @escaping (HTTP.Response) throws -> Resource
        ) {
            self.request = HTTP.Request(
                url: url,
                method: method,
                payload: requestPayload,
                contentType: requestContentType,
                accept: responseContentType
            )
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = adaptor
        }

        public init(
            url: URL,
            method: HTTP.Method,
            requestPayload: HTTP.Request.Payload,
            requestContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = []
        ) where Resource == Void {
            self.request = HTTP.Request(
                url: url,
                method: method,
                payload: requestPayload,
                contentType: requestContentType,
                accept: nil
            )
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = { _ in Void() }
        }

        public init(
            url: URL,
            method: HTTP.Method,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: ((HTTP.Response) throws -> Resource)? = nil
        ) where Resource == Optional<Decodable> {
            self.request = HTTP.Request(
                url: url,
                method: method,
                payload: .prepared(nil),
                contentType: nil,
                accept: responseContentType
            )
            self.emptyResponseStatusCodes = emptyResponseStatusCodes
            self.interceptors = interceptors
            self.adaptor = adaptor ?? { _ in Optional<Decodable>(nil) }
        }

        public init(
            url: URL,
            method: HTTP.Method,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: @escaping (HTTP.Response) throws -> Resource
        ) {
            self.request = HTTP.Request(
                url: url,
                method: method,
                payload: .prepared(nil),
                contentType: nil,
                accept: responseContentType
            )
            self.emptyResponseStatusCodes = emptyResponseStatusCodes
            self.interceptors = interceptors
            self.adaptor = adaptor
        }

        public init(
            url: URL,
            method: HTTP.Method,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: ((HTTP.Response) throws -> Resource)? = nil
        ) where Resource: Decodable {
            self.request = HTTP.Request(
                url: url,
                method: method,
                payload: .prepared(nil),
                contentType: nil,
                accept: responseContentType
            )
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = adaptor ?? { response in try response.decode(as: responseContentType) }
        }

        public init(
            url: URL,
            method: HTTP.Method,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = [],
            adapt: @escaping (HTTP.Response) throws -> Resource
        ) {
            self.request = HTTP.Request(
                url: url,
                method: method,
                payload: .prepared(nil),
                contentType: nil,
                accept: responseContentType
            )
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = adapt
        }

        public init(
            url: URL,
            method: HTTP.Method,
            interceptors: [HTTP.Interceptor] = []
        ) where Resource == Void {
            self.request = HTTP.Request(
                url: url,
                method: method,
                payload: .prepared(nil),
                contentType: nil,
                accept: nil
            )
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = { _ in Void() }
        }
    }
}
