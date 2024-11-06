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

        let endpoint = HTTP.Endpoint<ResponseBody>(
            url: url,
            method: .post,
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
            ) -> HTTP.Endpoint<ResponseBody> {
                let url: URL = .baseURL
                    .appending(component: String(666))
                    .appending(path: "hello/world")
                    .appending(queryItems: [
                        URLQueryItem(name: "t", value: String(1337))
                    ])

                let requestBody = RequestBody(message: message)

                return HTTP.Endpoint<ResponseBody>(
                    url: url,
                    method: .post,
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

    @Test func test_call_endpoint_withAdaptor() async throws {
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

        let endpoint = HTTP.Endpoint<ResponseBody>(
            url: url,
            method: .post,
            requestBody: requestBody,
            requestContentType: .json,
            responseContentType: .json,
            interceptors: []
        ) { response in
            try response.decode(as: .json)
        }

        let responseBody = try await httpClient.call(endpoint).get()

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_call_staticallyDefinedEndpoint_withAdaptor() async throws {
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
            ) -> HTTP.Endpoint<ResponseBody> {
                let url: URL = .baseURL
                    .appending(component: String(666))
                    .appending(path: "hello/world")
                    .appending(queryItems: [
                        URLQueryItem(name: "t", value: String(1337))
                    ])

                let requestBody = RequestBody(message: message)

                return HTTP.Endpoint<ResponseBody>(
                    url: url,
                    method: .post,
                    requestBody: requestBody,
                    requestContentType: .json,
                    responseContentType: .json,
                    interceptors: []
                ) { response in
                    try response.decode(as: .json)
                }
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

    @Test func test_call_endpoint_withToStringAdaptor() async throws {
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

        let endpoint = HTTP.Endpoint<String>(
            url: url,
            method: .post,
            requestBody: requestBody,
            requestContentType: .json,
            responseContentType: .json,
            interceptors: []
        ) { response in
            guard let responseString = String(data: response.body, encoding: .utf8) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
            }
            return responseString
        }

        let responseString = try await httpClient.call(endpoint).get()
        let responseBody = try decoder.decode(ResponseBody.self, from: Data(responseString.utf8))

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_call_staticallyDefinedEndpoint_withToStringAdaptor() async throws {
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
            ) -> HTTP.Endpoint<String> {
                let url: URL = .baseURL
                    .appending(component: String(666))
                    .appending(path: "hello/world")
                    .appending(queryItems: [
                        URLQueryItem(name: "t", value: String(1337))
                    ])

                let requestBody = RequestBody(message: message)

                return HTTP.Endpoint<String>(
                    url: url,
                    method: .post,
                    requestBody: requestBody,
                    requestContentType: .json,
                    responseContentType: .json,
                    interceptors: []
                ) { response in
                    guard let responseString = String(data: response.body, encoding: .utf8) else {
                        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
                    }
                    return responseString
                }
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

        let responseString = try await httpClient.call(Feature.helloWorld(message: "Hello World")).get()
        let responseBody = try decoder.decode(Feature.ResponseBody.self, from: Data(responseString.utf8))

        #expect(responseBody == expectedResponseBody)
    }
}
