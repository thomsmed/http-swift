import Foundation
import Testing

import HTTP

@Suite struct HTTPObserverTests {
    @Test func testSingleClientObserverObservesSuccessfulPostRequest() async throws {
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

        let result: Result<String, HTTP.PlainFailure> = await httpClient.request(
            .post,
            at: url,
            requestBody: expectedResponseBody,
            requestContentType: .json,
            responseContentType: .json,
            interceptors: []
        )

        let responseBody = try result.get()

        #expect(responseBody == expectedResponseBody)
        #expect(countingObserver.numberOfDidPrepare == 1)
        #expect(countingObserver.numberOfDidEncounter == 0)
        #expect(countingObserver.numberOfDidReceive == 1)
    }

    @Test func testTwoClientObserversObservesSuccessfulPostRequest() async throws {
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

        let result: Result<String, HTTP.PlainFailure> = await httpClient.request(
            .post,
            at: url,
            requestBody: expectedResponseBody,
            requestContentType: .json,
            responseContentType: .json,
            interceptors: []
        )

        let responseBody = try result.get()

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

    nonisolated func didPrepare(_ request: URLRequest) {
        numberOfDidPrepare += 1
    }

    func didEncounter(_ transportError: any Error) {
        numberOfDidPrepare += 1
    }

    func didReceive(_ response: HTTPURLResponse) {
        numberOfDidReceive += 1
    }
}
