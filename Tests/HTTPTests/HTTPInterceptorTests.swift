import Foundation
import Testing

import HTTP

@Suite struct HTTPInterceptorTests {
    @Test func test_fetch_postWithClientInterceptor_wrapsRequestAndUnwrapsResponse() async throws {
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

        let responseBody = try await httpClient.fetch(
            String.self,
            url: url,
            method: .post,
            payload: .json(encoded: expectedResponseBody),
            parser: .json(),
            interceptors: [
                WrappingInterceptor()
            ]
        )

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_fetch_postWithRequestInterceptor_wrapsRequestAndUnwrapsResponse() async throws {
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

        let responseBody = try await httpClient.fetch(
            String.self,
            url: url,
            method: .post,
            payload: .json(encoded: expectedResponseBody),
            parser: .json(),
            interceptors: [
                WrappingInterceptor()
            ]
        )

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_fetch_postWithClientAndRequestInterceptor_wrapsRequestAndUnwrapsResponse() async throws {
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

        let responseBody = try await httpClient.fetch(
            String.self,
            url: url,
            method: .post,
            payload: .json(encoded: expectedResponseBody),
            parser: .json(),
            interceptors: [
                WrappingInterceptor()
            ]
        )

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

        let encoder = JSONEncoder()

        request.httpBody = try encoder.encode(wrapping)
    }

    func handle(_ transportError: HTTP.TransportError, with context: HTTP.Context) async -> HTTP.Evaluation {
        .proceed
    }

    func process(_ response: inout HTTPURLResponse, data: inout Data, with context: HTTP.Context) async throws -> HTTP.Evaluation {
        let decoder = JSONDecoder()

        let wrapping = try decoder.decode(Wrapper.self, from: data)

        guard let wrappedContent = wrapping.content else {
            return .proceed
        }

        data = wrappedContent

        return .proceed
    }
}
