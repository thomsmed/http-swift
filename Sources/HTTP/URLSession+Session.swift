import Foundation

extension URLSession: HTTP.Session {
    private final class DoNotFollowRedirectsDelegate: NSObject, URLSessionTaskDelegate {
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest
        ) async -> URLRequest? {
            nil
        }
    }

    public func data(for request: URLRequest, followRedirects: Bool) async throws -> (Data, HTTPURLResponse) {
        let delegate = followRedirects ? nil : DoNotFollowRedirectsDelegate()
        return try await data(for: request, delegate: delegate) as! (Data, HTTPURLResponse)
    }
}
