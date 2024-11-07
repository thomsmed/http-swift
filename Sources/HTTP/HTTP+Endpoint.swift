import Foundation

public extension HTTP {
    struct Endpoint<RequestBody, Resource> {
        public let url: URL
        public let method: HTTP.Method
        public let requestBody: RequestBody?
        public let requestContentType: HTTP.MimeType?
        public let responseContentType: HTTP.MimeType?
        public let emptyResponseStatusCodes: Set<Int>
        public let interceptors: [HTTP.Interceptor]
        public let adaptor: (HTTP.Response) throws -> Resource

        public init(
            url: URL,
            method: HTTP.Method,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: ((HTTP.Response) throws -> Resource)? = nil
        ) where RequestBody: Encodable, Resource == Optional<Decodable> {
            self.url = url
            self.method = method
            self.requestBody = requestBody
            self.requestContentType = requestContentType
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = emptyResponseStatusCodes
            self.interceptors = interceptors
            self.adaptor = adaptor ?? { _ in Optional<Decodable>(nil) }
        }

        public init(
            url: URL,
            method: HTTP.Method,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: @escaping (HTTP.Response) throws -> Resource
        ) where RequestBody: Encodable {
            self.url = url
            self.method = method
            self.requestBody = requestBody
            self.requestContentType = requestContentType
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = emptyResponseStatusCodes
            self.interceptors = interceptors
            self.adaptor = adaptor
        }

        public init(
            url: URL,
            method: HTTP.Method,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: ((HTTP.Response) throws -> Resource)? = nil
        ) where RequestBody: Encodable, Resource: Decodable {
            self.url = url
            self.method = method
            self.requestBody = requestBody
            self.requestContentType = requestContentType
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = adaptor ?? { response in try response.decode(as: responseContentType) }
        }

        public init(
            url: URL,
            method: HTTP.Method,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: @escaping (HTTP.Response) throws -> Resource
        ) where RequestBody: Encodable {
            self.url = url
            self.method = method
            self.requestBody = requestBody
            self.requestContentType = requestContentType
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = adaptor
        }

        public init(
            url: URL,
            method: HTTP.Method,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = []
        ) where RequestBody: Encodable, Resource == Void {
            self.url = url
            self.method = method
            self.requestBody = requestBody
            self.requestContentType = requestContentType
            self.responseContentType = nil
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
        ) where RequestBody: Encodable, Resource == Optional<Decodable> {
            self.url = url
            self.method = method
            self.requestBody = nil
            self.requestContentType = nil
            self.responseContentType = responseContentType
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
        ) where RequestBody: Encodable {
            self.url = url
            self.method = method
            self.requestBody = nil
            self.requestContentType = nil
            self.responseContentType = responseContentType
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
        ) where RequestBody: Encodable, Resource: Decodable {
            self.url = url
            self.method = method
            self.requestBody = nil
            self.requestContentType = nil
            self.responseContentType = responseContentType
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
        ) where RequestBody: Encodable {
            self.url = url
            self.method = method
            self.requestBody = nil
            self.requestContentType = nil
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = adapt
        }

        public init(
            url: URL,
            method: HTTP.Method,
            interceptors: [HTTP.Interceptor] = []
        ) where RequestBody: Encodable, Resource == Void {
            self.url = url
            self.method = method
            self.requestBody = nil
            self.requestContentType = nil
            self.responseContentType = nil
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = { _ in Void() }
        }
    }
}
