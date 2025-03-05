import Foundation
import Testing

import HTTP

@Suite struct HTTPObserverTests {
    @Test func test_fetch_postWithSingleClientObserver_observesSuccessfulResponse() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let countingObserver = CountingObserver()
        let httpClient = HTTP.Client(
            session: session,
            observers: [
                countingObserver
            ]
        )

        let expectedResponseBody = "Hello World"

        session.dataAndResponseForRequest = { request in
            // Echo request body.
            return (request.httpBody ?? Data(), HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        let responseBody = try await httpClient.fetch(
            String.self,
            url: url,
            method: .post,
            payload: .json(encoded: expectedResponseBody),
            parser: .json()
        )

        #expect(responseBody == expectedResponseBody)
        #expect(countingObserver.numberOfDidPrepare == 1)
        #expect(countingObserver.numberOfDidEncounter == 0)
        #expect(countingObserver.numberOfDidReceive == 1)
    }

    @Test func test_fetch_postWithTwoClientObservers_observesSuccessfulResponse() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let countingObserver = CountingObserver()
        let httpClient = HTTP.Client(
            session: session,
            observers: [
                countingObserver,
                countingObserver // Apply twice
            ]
        )

        let expectedResponseBody = "Hello World"

        session.dataAndResponseForRequest = { request in
            // Echo request body.
            return (request.httpBody ?? Data(), HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        let responseBody = try await httpClient.fetch(
            String.self,
            url: url,
            method: .post,
            payload: .json(encoded: expectedResponseBody),
            parser: .json()
        )

        #expect(responseBody == expectedResponseBody)
        #expect(countingObserver.numberOfDidPrepare == 2)
        #expect(countingObserver.numberOfDidEncounter == 0)
        #expect(countingObserver.numberOfDidReceive == 2)
    }
}

// MARK: Test Helpers

private final class CountingObserver: HTTP.Observer, @unchecked Sendable {
    private(set) var numberOfDidPrepare: Int = 0
    private(set) var numberOfDidEncounter: Int = 0
    private(set) var numberOfDidReceive: Int = 0

    func didPrepare(_ request: URLRequest, with context: HTTP.Context) {
        numberOfDidPrepare += 1
    }

    func didEncounter(_ transportError: HTTP.TransportError, with context: HTTP.Context) {
        numberOfDidPrepare += 1
    }

    func didReceive(_ response: HTTPURLResponse, with context: HTTP.Context) {
        numberOfDidReceive += 1
    }
}
