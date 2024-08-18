import Foundation

extension URLSession: HTTP.Session {
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await data(for: request, delegate: nil) as! (Data, HTTPURLResponse)
    }
}
