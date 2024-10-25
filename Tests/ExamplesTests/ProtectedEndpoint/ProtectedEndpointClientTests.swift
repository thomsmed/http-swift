import Foundation
import Testing

import HTTP
import Examples

private extension URL {
    static let baseURL: URL = {
#if DEBUG
        return URL(string: "https://develop.example.ios")!
#else
        return URL(string: "https://example.ios")!
#endif
    }()
}

@Suite struct ProtectedEndpointClientTests {
    @Test func test_call_protectedEndpoint() async throws {
        let decoder = JSONDecoder()
        let session = MockSession()
        let httpClient = HTTP.Client(
            session: session,
            decoder: decoder
        )
        let trustProvider = MockTrustProvider()
        let endpointClient = ProtectedEndpointClient(
            httpClient: httpClient,
            trustProvider: trustProvider
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
            #expect(request.value(forHTTPHeaderField: "DPoP") != nil)
            #expect(request.value(forHTTPHeaderField: "Authorization") != nil)

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

        let endpoint = ProtectedEndpoint<ResponseBody>(
            .post,
            at: url,
            requestBody: requestBody,
            requestContentType: .json,
            responseContentType: .json,
            authenticationScheme: .dPoPAndAccessToken,
            interceptors: []
        )

        let responseBody = try await endpointClient.call(endpoint).get()

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_call_staticallyDefinedProtectedEndpoint() async throws {
        let decoder = JSONDecoder()
        let session = MockSession()
        let httpClient = HTTP.Client(
            session: session,
            decoder: decoder
        )
        let trustProvider = MockTrustProvider()
        let endpointClient = ProtectedEndpointClient(
            httpClient: httpClient,
            trustProvider: trustProvider
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
            ) -> ProtectedEndpoint<ResponseBody> {
                let url: URL = .baseURL
                    .appending(component: String(666))
                    .appending(path: "hello/world")
                    .appending(queryItems: [
                        URLQueryItem(name: "t", value: String(1337))
                    ])

                let requestBody = RequestBody(message: message)

                return ProtectedEndpoint<ResponseBody>(
                    .post,
                    at: url,
                    requestBody: requestBody,
                    requestContentType: .json,
                    responseContentType: .json,
                    authenticationScheme: .dPoPAndAccessToken,
                    interceptors: []
                )
            }
        }

        let expectedRequestBody = Feature.RequestBody(message: "Hello World")

        let expectedResponseBody = Feature.ResponseBody(message: "Hello World")

        session.dataAndResponseForRequest = { request in
            #expect(request.value(forHTTPHeaderField: "DPoP") != nil)
            #expect(request.value(forHTTPHeaderField: "Authorization") != nil)

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

        let responseBody = try await endpointClient.call(Feature.helloWorld(message: "Hello World")).get()

        #expect(responseBody == expectedResponseBody)
    }
}
