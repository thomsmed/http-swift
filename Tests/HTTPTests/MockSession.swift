import Foundation

import HTTP

final class MockSession: HTTP.Session, @unchecked Sendable {
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    var dataAndResponseForRequest: (_ request: URLRequest) async -> (Data, HTTPURLResponse) = { _ in
        (Data(), HTTPURLResponse())
    }

    func data(for request: URLRequest, followRedirects: Bool) async throws -> (Data, HTTPURLResponse) {
        await dataAndResponseForRequest(request)
    }
}
