import Foundation

public enum HTTP {
    /// HTTP Method.
    public struct Method: RawRepresentable, Equatable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    /// HTTP MIME Type.
    public struct MimeType: RawRepresentable, Equatable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    /// HTTP Header.
    public struct Header: Equatable, Hashable, Sendable {
        public let name: String
        public let value: String

        public init(name: String, value: String) {
            self.name = name
            self.value = value
        }
    }

    /// HTTP Status (code + description).
    public struct Status: Sendable {
        public let codes: [Range<Int>]
        public let description: String

        public init(codes: [Range<Int>], description: String) {
            self.codes = codes
            self.description = description
        }

        public init(codes: Range<Int>, description: String) {
            self.codes = [codes]
            self.description = description
        }

        public init(code: Int, description: String) {
            self.codes = [code..<code + 1]
            self.description = description
        }

        public func contains(_ code: Int) -> Bool {
            for range in codes {
                if range.contains(code) {
                    return true
                }
            }
            return false
        }
    }

    /// HTTP Request.
    public struct Request: Sendable {
        public var url: URL
        public var method: HTTP.Method
        public var body: Data?
        public var headers: [Header]
        public var followRedirects: Bool

        public init(
            url: URL,
            method: HTTP.Method,
            body: Data? = nil,
            headers: [Header] = [],
            followRedirects: Bool = true
        ) {
            self.url = url
            self.method = method
            self.body = body
            self.headers = headers
            self.followRedirects = followRedirects
        }
    }

    /// HTTP Response.
    public struct Response: Sendable {
        public let statusCode: Int
        public let headers: [Header]
        public let body: Data

        internal init(
            statusCode: Int,
            headers: [Header],
            body: Data
        ) {
            self.statusCode = statusCode
            self.headers = headers
            self.body = body
        }

        public func parsed<Value>(
            as _: Value.Type = Value.self,
            using parser: ResponseParser<Value>
        ) throws -> Value {
            try parser.parse(self)
        }
    }

    /// HTTP Request Payload (HTTP MIME Type for the `Content-Type` HTTP Request Header + any HTTP Request body data).
    public struct RequestPayload: Sendable {
        public let mimeType: MimeType?
        public let body: Data?

        public init(
            mimeType: MimeType?,
            body: Data?
        ) {
            self.mimeType = mimeType
            self.body = body
        }
    }

    /// HTTP Response Parser (expected HTTP MIME Type for the `Content-Type` HTTP Response Header + HTTP Response parse closure).
    /// Sets the `Accept` HTTP Request Header to the expected HTTP MIME Type.
    public struct ResponseParser<Value>: Sendable {
        public let mimeType: MimeType?
        public let parse: @Sendable (Response) throws -> Value

        public init(
            mimeType: MimeType?,
            type _: Value.Type = Value.self,
            _ parse: @escaping @Sendable (Response) throws -> Value
        ) {
            self.mimeType = mimeType
            self.parse = parse
        }
    }

    /// Transport error.
    /// Thrown when something went wrong in the network stack trying to send a HTTP Request.
    public struct TransportError: Error {
        public let error: any Error

        internal init(_ error: any Error) {
            self.error = error
        }
    }

    /// Max request retry count reached.
    /// Thrown when the configured max retry count for the `HTTP.Client` was (for some reason) reached.
    public struct MaxRetryCountReached: Error {}

    /// Unexpected HTTP Response.
    /// Thrown when the received HTTP Response did not (for some reason) live up to expectations (e.g wrong HTTP Status Code).
    public struct UnexpectedResponse: Error {
        public let statusCode: Int
        public let headers: [Header]
        public let body: Data

        public init(_ response: Response) {
            self.statusCode = response.statusCode
            self.headers = response.headers
            self.body = response.body
        }

        public func parsed<Value>(
            as _: Value.Type = Value.self,
            using parser: UnexpectedResponseParser<Value>
        ) throws -> Value {
            try parser.parse(self)
        }
    }

    /// HTTP Unexpected Response Parser.
    public struct UnexpectedResponseParser<Value>: Sendable {
        public let parse: @Sendable (UnexpectedResponse) throws -> Value

        public init(
            type _: Value.Type = Value.self,
            _ parse: @escaping @Sendable (UnexpectedResponse) throws -> Value
        ) {
            self.parse = parse
        }
    }

    /// A per-request context.
    public struct Context {
        public let request: Request
        public let tags: [String: String]
        public let retryCount: Int
    }

    /// An `Interceptor`'s evaluation of a received HTTP Response or HTTP Transport Error.
    public enum Evaluation {
        case retry
        case retryAfter(TimeInterval)
        case proceed
    }

    /// An `Interceptor` that can manipulate outgoing HTTP Requests or incoming HTTP Responses, or act on any thrown HTTP Transport Errors.
    public protocol Interceptor: Sendable {
        func prepare(_ request: inout URLRequest, with context: Context) async throws
        func handle(_ transportError: TransportError, with context: Context) async -> Evaluation
        func process(_ response: inout HTTPURLResponse, data: inout Data, with context: Context) async throws -> Evaluation
    }

    /// An `Observer` that is notified about various events during the sending of a HTTP Request.
    public protocol Observer: Sendable {
        func didPrepare(_ request: URLRequest, with context: Context)
        func didEncounter(_ transportError: TransportError, with context: Context)
        func didReceive(_ response: HTTPURLResponse, with context: Context)
    }

    /// A protocol representing something that can send `URLRequests` and receive `HTTPURLResponse` (with `Data`).
    public protocol Session: Sendable {
        func data(for request: URLRequest, followRedirects: Bool) async throws -> (Data, HTTPURLResponse)
    }
}
