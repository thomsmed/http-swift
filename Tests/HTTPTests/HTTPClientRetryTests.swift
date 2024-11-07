import Foundation
import Testing

import HTTP

@Suite struct HTTPClientRetryTests {
    @Test func test_request_withClientRetryInterceptor_retriesRequest() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let maxRetryCount = 5
        let options = HTTP.Client.Options(maxRetryCount: maxRetryCount)
        let retryInterceptor = RetryInterceptor(
            numberOfErrorsToRetry: 0,
            numberOfResponsesToRetry: 1
        )
        let httpClient = HTTP.Client(
            session: session,
            interceptors: [
                retryInterceptor
            ],
            options: options
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

        let result = await httpClient.fetch(
            String.self,
            url: url,
            method: .post,
            requestPayload: .unprepared(expectedResponseBody),
            requestContentType: .json,
            responseContentType: .json,
            interceptors: []
        )

        let responseBody = try result.get()

        #expect(responseBody == expectedResponseBody)
        #expect(retryInterceptor.numberOfErrorsHandled == 0)
        #expect(retryInterceptor.numberOfResponsesProcessed == 2)
    }

    @Test func test_request_withRequestRetryInterceptor_retriesRequest() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let retryInterceptor = RetryInterceptor(
            numberOfErrorsToRetry: 0,
            numberOfResponsesToRetry: 1
        )
        let httpClient = HTTP.Client(
            session: session
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

        let result = await httpClient.fetch(
            String.self,
            url: url,
            method: .post,
            requestPayload: .unprepared(expectedResponseBody),
            requestContentType: .json,
            responseContentType: .json,
            interceptors: [
                retryInterceptor
            ]
        )

        let responseBody = try result.get()

        #expect(responseBody == expectedResponseBody)
        #expect(retryInterceptor.numberOfErrorsHandled == 0)
        #expect(retryInterceptor.numberOfResponsesProcessed == 2)
    }

    @Test func test_request_withClientAndRequestRetryInterceptor_retriesRequest() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let clientRetryInterceptor = RetryInterceptor(
            numberOfErrorsToRetry: 0,
            numberOfResponsesToRetry: 1
        )
        let requestRetryInterceptor = RetryInterceptor(
            numberOfErrorsToRetry: 0,
            numberOfResponsesToRetry: 1
        )
        let httpClient = HTTP.Client(
            session: session,
            interceptors: [
                clientRetryInterceptor
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

        let result = await httpClient.fetch(
            String.self,
            url: url,
            method: .post,
            requestPayload: .unprepared(expectedResponseBody),
            requestContentType: .json,
            responseContentType: .json,
            interceptors: [
                requestRetryInterceptor
            ]
        )

        let responseBody = try result.get()

        // Per-request interceptors processes incoming responses first,
        // hence retrying requests causes per-request to process responses more times than per-client interceptors.
        #expect(responseBody == expectedResponseBody)
        #expect(clientRetryInterceptor.numberOfErrorsHandled == 0)
        #expect(clientRetryInterceptor.numberOfResponsesProcessed == 2)
        #expect(requestRetryInterceptor.numberOfErrorsHandled == 0)
        #expect(requestRetryInterceptor.numberOfResponsesProcessed == 3)
    }

    @Test func test_request_withClientAndRequestRetryInterceptor_retriesRequestMultipleTimes() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let clientRetryInterceptor = RetryInterceptor(
            numberOfErrorsToRetry: 0,
            numberOfResponsesToRetry: 2
        )
        let requestRetryInterceptor = RetryInterceptor(
            numberOfErrorsToRetry: 0,
            numberOfResponsesToRetry: 2
        )
        let httpClient = HTTP.Client(
            session: session,
            interceptors: [
                clientRetryInterceptor
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

        let result = await httpClient.fetch(
            String.self,
            url: url,
            method: .post,
            requestPayload: .unprepared(expectedResponseBody),
            requestContentType: .json,
            responseContentType: .json,
            interceptors: [
                requestRetryInterceptor
            ]
        )

        let responseBody = try result.get()

        // Per-request interceptors processes incoming responses first,
        // hence retrying requests causes per-request to process responses more times than per-client interceptors.
        #expect(responseBody == expectedResponseBody)
        #expect(clientRetryInterceptor.numberOfErrorsHandled == 0)
        #expect(clientRetryInterceptor.numberOfResponsesProcessed == 3)
        #expect(requestRetryInterceptor.numberOfErrorsHandled == 0)
        #expect(requestRetryInterceptor.numberOfResponsesProcessed == 5)
    }

    @Test func test_request_withClientAndRequestRetryInterceptor_retriesRequestAndFailsWithMaxRetryCountReachedError() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let maxRetryCount = 5
        let options = HTTP.Client.Options(maxRetryCount: maxRetryCount)
        let clientRetryInterceptor = RetryInterceptor(
            numberOfErrorsToRetry: 0,
            numberOfResponsesToRetry: 3
        )
        let requestRetryInterceptor = RetryInterceptor(
            numberOfErrorsToRetry: 0,
            numberOfResponsesToRetry: 3
        )
        let httpClient = HTTP.Client(
            session: session,
            interceptors: [
                clientRetryInterceptor
            ],
            options: options
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

        let result = await httpClient.fetch(
            String.self,
            url: url,
            method: .post,
            requestPayload: .unprepared(expectedResponseBody),
            requestContentType: .json,
            responseContentType: .json,
            interceptors: [
                requestRetryInterceptor
            ]
        )

        #expect {
            try result.get()
        } throws: { error in
            guard let httpFailure = error as? HTTP.Failure else {
                return false
            }

            switch httpFailure {
                case .maxRetryCountReached:
                    return true
                default:
                    return false
            }
        }

        // Per-request interceptors processes incoming responses first,
        // hence retrying requests causes per-request to process responses more times than per-client interceptors.
        let expectedNumberOfResponsesProcessedByClientInterceptor = (maxRetryCount + 1) / 2
        let expectedNumberOfResponsesProcessedByRequestInterceptor = maxRetryCount + 1

        #expect(clientRetryInterceptor.numberOfErrorsHandled == 0)
        #expect(clientRetryInterceptor.numberOfResponsesProcessed == expectedNumberOfResponsesProcessedByClientInterceptor)
        #expect(requestRetryInterceptor.numberOfErrorsHandled == 0)
        #expect(requestRetryInterceptor.numberOfResponsesProcessed == expectedNumberOfResponsesProcessedByRequestInterceptor)
    }
}

// MARK: Test Helpers

private final class RetryInterceptor: HTTP.Interceptor, @unchecked Sendable {
    private(set) var numberOfErrorsHandled: Int = 0
    var numberOfErrorsToRetry: Int = 0

    private(set) var numberOfResponsesProcessed: Int = 0
    var numberOfResponsesToRetry: Int = 0

    init(
        numberOfErrorsToRetry: Int,
        numberOfResponsesToRetry: Int
    ) {
        self.numberOfErrorsToRetry = numberOfErrorsToRetry
        self.numberOfResponsesToRetry = numberOfResponsesToRetry
    }

    func prepare(_ request: inout URLRequest, with context: HTTP.Context) async throws {
        // No-op
    }

    func handle(_ transportError: any Error, with context: HTTP.Context) async -> HTTP.Evaluation {
        defer { numberOfErrorsHandled += 1 }
        if numberOfErrorsHandled < numberOfErrorsToRetry {
            return .retry
        } else {
            return .proceed
        }
    }

    func process(_ response: inout HTTPURLResponse, data: inout Data, with context: HTTP.Context) async throws -> HTTP.Evaluation {
        defer { numberOfResponsesProcessed += 1 }
        if numberOfResponsesProcessed < numberOfResponsesToRetry {
            return .retry
        } else {
            return .proceed
        }
    }
}
