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

private final actor TestTrustProvider: TrustProvider {
    var accessToken: AccessToken? {
        get async {
            AccessToken(rawValue: "<some.access.token>")
        }
    }

    func sign(_ request: URLRequest) async throws -> DPoP {
        DPoP(rawValue: "<some.dpop>")
    }
}

@Suite struct TrustAwareHTTPClientTests {
    @Test func test_call_protectedEndpoint() async throws {
        let decoder = JSONDecoder()
        let session = MockSession()
        let httpClient = HTTP.Client(
            session: session,
            decoder: decoder
        )
        let trustProvider = TestTrustProvider()
        let trustAwareHTTPClient = TrustAwareHTTPClient(
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

        let endpoint = ProtectedEndpoint<RequestBody, ResponseBody>(
            .post,
            at: url,
            requestBody: requestBody,
            requestContentType: .json,
            responseContentType: .json,
            interceptors: [],
            authenticationScheme: .dPoPAndAccessToken
        )

        let responseBody = try await trustAwareHTTPClient.call(endpoint).get()

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_call_staticallyDefinedProtectedEndpoint() async throws {
        let decoder = JSONDecoder()
        let session = MockSession()
        let httpClient = HTTP.Client(
            session: session,
            decoder: decoder
        )
        let trustProvider = TestTrustProvider()
        let trustAwareHTTPClient = TrustAwareHTTPClient(
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
            ) -> ProtectedEndpoint<RequestBody, ResponseBody> {
                let url: URL = .baseURL
                    .appending(component: String(666))
                    .appending(path: "hello/world")
                    .appending(queryItems: [
                        URLQueryItem(name: "t", value: String(1337))
                    ])

                let requestBody = RequestBody(message: message)

                return ProtectedEndpoint<RequestBody, ResponseBody>(
                    .post,
                    at: url,
                    requestBody: requestBody,
                    requestContentType: .json,
                    responseContentType: .json,
                    interceptors: [],
                    authenticationScheme: .dPoPAndAccessToken
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

        let responseBody = try await trustAwareHTTPClient.call(Feature.helloWorld(message: "Hello World")).get()

        #expect(responseBody == expectedResponseBody)
    }
}
