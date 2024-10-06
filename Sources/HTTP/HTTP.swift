import Foundation

public enum HTTP {
    public enum Method: String, Sendable {
        case get = "GET"
        case put = "PUT"
        case post = "POST"
        case delete = "DELETE"
    }

    public enum MimeType: String, Sendable {
        case json = "application/json"
    }

    public struct Response: Sendable {
        private let decoder: JSONDecoder

        public let statusCode: Int
        public let headers: [String: String]
        public let body: Data

        internal init(
            decoder: JSONDecoder,
            statusCode: Int,
            headers: [String: String],
            body: Data
        ) {
            self.decoder = decoder
            self.statusCode = statusCode
            self.headers = headers
            self.body = body
        }

        public func decode<T: Decodable>(as mimeType: MimeType) throws -> T {
            switch mimeType {
                case .json:
                    return try decoder.decode(T.self, from: body)
            }
        }
    }

    public enum Failure: Error {
        case encodingError(any Error)
        case decodingError(any Error)
        case preparationError(any Error)
        case processingError(any Error)
        case transportError(any Error)
        case clientError(Response)
        case serverError(Response)
        case unexpectedStatusCode(Response)
        case maxRetryCountReached
        case canceled
    }

    public struct Context {
        public let encoder: JSONEncoder
        public let decoder: JSONDecoder
        public let retryCount: Int
    }

    public enum Evaluation {
        case retry
        case retryAfter(TimeInterval)
        case proceed
    }

    public protocol Interceptor: Sendable {
        func prepare(_ request: inout URLRequest, with context: Context) async throws
        func handle(_ transportError: any Error, with context: Context) async -> Evaluation
        func process(_ response: inout HTTPURLResponse, data: inout Data, with context: Context) async throws -> Evaluation
    }

    public protocol Observer: Sendable {
        func didPrepare(_ request: URLRequest, with context: Context)
        func didEncounter(_ transportError: any Error, with context: Context)
        func didReceive(_ response: HTTPURLResponse, with context: Context)
    }

    public protocol Session: Sendable {
        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
    }
}
