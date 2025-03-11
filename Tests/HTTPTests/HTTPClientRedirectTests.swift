import Foundation
import Testing

import HTTP

struct HTTPClientRedirectTests {
    @Test func test_followRedirects() async throws {
        final class MockURLProtocol: URLProtocol {
            static nonisolated(unsafe) var responseBuilders: [(URLRequest) throws -> (Data, HTTPURLResponse, URLRequest?)] = []

            override static func canInit(with request: URLRequest) -> Bool {
                !responseBuilders.isEmpty
            }

            override static func canonicalRequest(for request: URLRequest) -> URLRequest {
                request
            }

            override func startLoading() {
                do {
                    let responseBuilder = Self.responseBuilders.removeFirst()

                    let (data, response, request) = try responseBuilder(request)

                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

                    if let request {
                        client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
                    }

                    client?.urlProtocol(self, didLoad: data)

                    client?.urlProtocolDidFinishLoading(self)
                } catch {
                    client?.urlProtocol(self, didFailWithError: error)
                }
            }

            override func stopLoading() {}
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]

        let session = URLSession(configuration: configuration)
        let httpClient = HTTP.Client(session: session)

        let redirectingResponse = HTTPURLResponse()
        let redirectingResponseData = Data("Some Redirecting Body".utf8)

        let response = HTTPURLResponse()
        let responseData = Data("Some Body".utf8)

        MockURLProtocol.responseBuilders = [
            { request in
                (redirectingResponseData, redirectingResponse, request)
            },
            { request in
                (responseData, response, nil)
            },
        ]

        let url = URL(string: "https://example.ios")!

        let request = HTTP.Request(
            url: url,
            method: .post,
            body: Data(),
            headers: [
                .userAgent("Some User-Agent"),
                .accept(.json)
            ],
            followRedirects: true
        )

        let httpResponse = try await httpClient.send(
            request,
            tags: ["My Tag": "Hello World!"]
        )

        #expect(httpResponse.body == responseData)
    }

    @Test func test_doNotFollowRedirects() async throws {
        final class MockURLProtocol: URLProtocol {
            static nonisolated(unsafe) var responseBuilders: [(URLRequest) throws -> (Data, HTTPURLResponse, URLRequest?)] = []

            override static func canInit(with request: URLRequest) -> Bool {
                !responseBuilders.isEmpty
            }

            override static func canonicalRequest(for request: URLRequest) -> URLRequest {
                request
            }

            override func startLoading() {
                do {
                    let responseBuilder = Self.responseBuilders.removeFirst()

                    let (data, response, request) = try responseBuilder(request)

                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

                    if let request {
                        client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
                    }

                    client?.urlProtocol(self, didLoad: data)

                    client?.urlProtocolDidFinishLoading(self)
                } catch {
                    client?.urlProtocol(self, didFailWithError: error)
                }
            }

            override func stopLoading() {}
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]

        let session = URLSession(configuration: configuration)
        let httpClient = HTTP.Client(session: session)

        let redirectingResponse = HTTPURLResponse()
        let redirectingResponseData = Data("Some Redirecting Body".utf8)

        let response = HTTPURLResponse()
        let responseData = Data("Some Body".utf8)

        MockURLProtocol.responseBuilders = [
            { request in
                (redirectingResponseData, redirectingResponse, request)
            },
            { request in
                (responseData, response, nil)
            },
        ]

        let url = URL(string: "https://example.ios")!

        let request = HTTP.Request(
            url: url,
            method: .post,
            body: Data(),
            headers: [
                .userAgent("Some User-Agent"),
                .accept(.json)
            ],
            followRedirects: false
        )

        let httpResponse = try await httpClient.send(
            request,
            tags: ["My Tag": "Hello World!"]
        )

        #expect(httpResponse.body == redirectingResponseData)
    }
}
