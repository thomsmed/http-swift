import Foundation
import Testing

import HTTP

private extension URL {
    static let baseURL: URL = {
#if DEBUG
        return URL(string: "https://develop.example.ios")!
#else
        return URL(string: "https://example.ios")!
#endif
    }()
}

@Suite struct HTTPEndpointTests {
    @Test func test_call_endpoint() async throws {
        let decoder = JSONDecoder()
        let session = MockSession()
        let httpClient = HTTP.Client(
            session: session,
            decoder: decoder
        )

        struct RequestBody: Codable, Equatable {
            let message: String
        }

        let expectedRequestBody = RequestBody(message: "Hello World")

        struct ResponseBody: Codable, Equatable {
            let message: String
        }

        let expectedResponseBody = ResponseBody(message: "Hello World")

        session.dataAndResponseForRequest = { request in
            let requestBody = try? decoder.decode(RequestBody.self, from: request.httpBody ?? Data())
            #expect(requestBody == expectedRequestBody)

            // Echo request body.
            return (request.httpBody ?? Data(), HTTPURLResponse(
                url: .baseURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        let url: URL = .baseURL
            .appending(component: String(666))
            .appending(path: "hello/world")
            .appending(queryItems: [
                URLQueryItem(name: "t", value: String(1337))
            ])

        let requestBody = RequestBody(message: "Hello World")

        let endpoint = HTTP.Endpoint<RequestBody, ResponseBody>(
            .post,
            at: url,
            requestBody: requestBody,
            requestContentType: .json,
            responseContentType: .json,
            interceptors: []
        )

        let responseBody = try await httpClient.call(endpoint).get()

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_call_staticallyDefinedEndpoint() async throws {
        let decoder = JSONDecoder()
        let session = MockSession()
        let httpClient = HTTP.Client(
            session: session,
            decoder: decoder
        )

        struct Feature {
            struct RequestBody: Codable, Equatable {
                let message: String
            }

            struct ResponseBody: Codable, Equatable {
                let message: String
            }

            static func helloWorld(
                message: String
            ) -> HTTP.Endpoint<RequestBody, ResponseBody> {
                let url: URL = .baseURL
                    .appending(component: String(666))
                    .appending(path: "hello/world")
                    .appending(queryItems: [
                        URLQueryItem(name: "t", value: String(1337))
                    ])

                let requestBody = RequestBody(message: message)

                return HTTP.Endpoint<RequestBody, ResponseBody>(
                    .post,
                    at: url,
                    requestBody: requestBody,
                    requestContentType: .json,
                    responseContentType: .json,
                    interceptors: []
                )
            }
        }

        let expectedRequestBody = Feature.RequestBody(message: "Hello World")

        let expectedResponseBody = Feature.ResponseBody(message: "Hello World")

        session.dataAndResponseForRequest = { request in
            let requestBody = try? decoder.decode(Feature.RequestBody.self, from: request.httpBody ?? Data())
            #expect(requestBody == expectedRequestBody)

            // Echo request body.
            return (request.httpBody ?? Data(), HTTPURLResponse(
                url: .baseURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        let responseBody = try await httpClient.call(Feature.helloWorld(message: "Hello World")).get()

        #expect(responseBody == expectedResponseBody)
    }
}
