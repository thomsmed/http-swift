import Foundation
import HTTP

final class MockSession: HTTP.Session, @unchecked Sendable {
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    var dataAndResponseForRequest: (_ request: URLRequest) -> (Data, HTTPURLResponse) = { _ in (Data(), HTTPURLResponse()) }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        dataAndResponseForRequest(request)
    }
}
