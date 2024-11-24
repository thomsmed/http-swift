import Foundation
import Testing

import HTTP

@Suite struct HTTPClientTests {
    @Test func test_send() async throws {
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)

        session.dataAndResponseForRequest = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: [:])
            return (request.httpBody!, response!)
        }

        let url = URL(string: "https://example.ios")!
        let body = Data("Some Body".utf8)
        let request = HTTP.Request(
            url: url,
            method: .post,
            body: body,
            headers: [
                .userAgent("Some User-Agent"),
                .accept(.json)
            ]
        )

        let response = try await httpClient.send(
            request,
            tags: ["My Tag": "Hello World!"]
        )

        #expect(response.body == body)
    }

    @Test func test_send_withInterceptor() async throws {
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)

        session.dataAndResponseForRequest = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: [:])
            return (request.httpBody!, response!)
        }

        let url = URL(string: "https://example.ios")!
        let body = Data("Some Body".utf8)
        let request = HTTP.Request(
            url: url,
            method: .post,
            body: body,
            headers: [
                .userAgent("Some User-Agent"),
                .contentType(.json),
                .accept(.json)
            ]
        )

        let response = try await httpClient.send(
            request,
            interceptors: [
                WrappingInterceptor()
            ],
            tags: ["My Tag": "Hello World!"]
        )

        #expect(response.body == body)
    }
}

// MARK: Test Helpers

private struct WrappingInterceptor: HTTP.Interceptor {
    struct Wrapper: Codable {
        let content: Data?
        let tag: String?
    }

    func prepare(_ request: inout URLRequest, with context: HTTP.Context) async throws {
        let wrapping = Wrapper(content: request.httpBody, tag: context.tags.first?.value)

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
