import Foundation
import Testing

import HTTP

@Suite struct HTTPInterceptorTests {
    @Test func test_request_post_withClientInterceptor_wrapsRequestAndUnwrapsResponse() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let httpClient = HTTP.Client(
            session: session,
            interceptors: [
                WrappingInterceptor()
            ]
        )

        let expectedResponseBody = "Hello World"

        session.dataAndResponseForRequest = { request in
            let expectedWrappedResponseBody = "{\"content\":\"eyJjb250ZW50IjoiSWtobGJHeHZJRmR2Y214a0lnPT0ifQ==\"}"
            #expect(String(data: request.httpBody ?? Data(), encoding: .utf8) == expectedWrappedResponseBody)

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
            interceptors: [
                WrappingInterceptor()
            ]
        )

        let responseBody = try result.get()

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_request_post_withRequestInterceptor_wrapsRequestAndUnwrapsResponse() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let httpClient = HTTP.Client(
            session: session
        )

        let expectedResponseBody = "Hello World"

        session.dataAndResponseForRequest = { request in
            let expectedWrappedResponseBody = "{\"content\":\"IkhlbGxvIFdvcmxkIg==\"}"
            #expect(String(data: request.httpBody ?? Data(), encoding: .utf8) == expectedWrappedResponseBody)

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
            interceptors: [
                WrappingInterceptor()
            ]
        )

        let responseBody = try result.get()

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_request_post_withClientAndRequestInterceptor_wrapsRequestAndUnwrapsResponse() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let httpClient = HTTP.Client(
            session: session,
            interceptors: [
                WrappingInterceptor()
            ]
        )

        let expectedResponseBody = "Hello World"

        session.dataAndResponseForRequest = { request in
            let expectedWrappedResponseBody = "{\"content\":\"eyJjb250ZW50IjoiSWtobGJHeHZJRmR2Y214a0lnPT0ifQ==\"}"
            #expect(String(data: request.httpBody ?? Data(), encoding: .utf8) == expectedWrappedResponseBody)

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
            interceptors: [
                WrappingInterceptor()
            ]
        )

        let responseBody = try result.get()

        #expect(responseBody == expectedResponseBody)
    }
}

// MARK: Test Helpers

private struct WrappingInterceptor: HTTP.Interceptor {
    struct Wrapper: Codable {
        let content: Data?
    }

    func prepare(_ request: inout URLRequest, with context: HTTP.Context) async throws {
        let wrapping = Wrapper(content: request.httpBody)

        request.httpBody = try context.encoder.encode(wrapping)
    }
    
    func handle(_ transportError: any Error, with context: HTTP.Context) async -> HTTP.Evaluation {
        .proceed
    }
    
    func process(_ response: inout HTTPURLResponse, data: inout Data, with context: HTTP.Context) async throws -> HTTP.Evaluation {
        let wrapping = try context.decoder.decode(Wrapper.self, from: data)

        guard let wrappedContent = wrapping.content else {
            return .proceed
        }

        data = wrappedContent

        return .proceed
    }
}
