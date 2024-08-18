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

    public enum Failure<ErrorBody: Decodable & Sendable>: Error {
        case encodingError(any Error)
        case decodingError(any Error)
        case preparationError(any Error)
        case processingError(any Error)
        case transportError(any Error)
        case clientError(ErrorBody)
        case serverError(ErrorBody)
        case unexpectedStatusCode(Int)
        case maxRetryCountReached
        case canceled
    }

    public typealias PlainFailure = Failure<Data>

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
        func didPrepare(_ request: URLRequest)
        func didEncounter(_ transportError: any Error)
        func didReceive(_ response: HTTPURLResponse)
    }

    public protocol Session: Sendable {
        func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
    }
}
