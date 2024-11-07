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

@Suite struct ProtectedEndpointTests {
    @Test func test_call_endpoint() async throws {
        let decoder = JSONDecoder()
        let session = MockSession()
        let httpClient = HTTP.Client(
            session: session,
            decoder: decoder
        )
        let trustProvider = MockTrustProvider()
        let endpointClient = ProtectedEndpointClient(httpClient: httpClient, trustProvider: trustProvider)

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

            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(request.value(forHTTPHeaderField: "DPoP") == nil)

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
            url: url,
            method: .post,
            requestPayload: .unprepared(requestBody),
            requestContentType: .json,
            responseContentType: .json,
            authenticationScheme: .none,
            interceptors: []
        )

        let responseBody = try await endpointClient.call(endpoint).get()

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_call_endpoint_withDPoPAuthorization() async throws {
        let decoder = JSONDecoder()
        let session = MockSession()
        let httpClient = HTTP.Client(
            session: session,
            decoder: decoder
        )
        let trustProvider = MockTrustProvider()
        let endpointClient = ProtectedEndpointClient(httpClient: httpClient, trustProvider: trustProvider)

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

            let dPoP = await trustProvider.mockDPoP
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(request.value(forHTTPHeaderField: "DPoP") == dPoP.rawValue)

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
            url: url,
            method: .post,
            requestPayload: .unprepared(requestBody),
            requestContentType: .json,
            responseContentType: .json,
            authenticationScheme: .dPoP,
            interceptors: []
        )

        let responseBody = try await endpointClient.call(endpoint).get()

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_call_endpoint_withAccessTokenAuthorization() async throws {
        let decoder = JSONDecoder()
        let session = MockSession()
        let httpClient = HTTP.Client(
            session: session,
            decoder: decoder
        )
        let trustProvider = MockTrustProvider()
        let endpointClient = ProtectedEndpointClient(httpClient: httpClient, trustProvider: trustProvider)

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

            let accessToken = await trustProvider.mockAccessToken
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(accessToken.rawValue)")
            #expect(request.value(forHTTPHeaderField: "DPoP") == nil)

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
            url: url,
            method: .post,
            requestPayload: .unprepared(requestBody),
            requestContentType: .json,
            responseContentType: .json,
            authenticationScheme: .accessToken,
            interceptors: []
        )

        let responseBody = try await endpointClient.call(endpoint).get()

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_call_endpoint_withDPoPAndAccessTokenAuthorization() async throws {
        let decoder = JSONDecoder()
        let session = MockSession()
        let httpClient = HTTP.Client(
            session: session,
            decoder: decoder
        )
        let trustProvider = MockTrustProvider()
        let endpointClient = ProtectedEndpointClient(httpClient: httpClient, trustProvider: trustProvider)

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

            let accessToken = await trustProvider.mockAccessToken
            let dPoP = await trustProvider.mockDPoP
            #expect(request.value(forHTTPHeaderField: "Authorization") == "DPoP \(accessToken.rawValue)")
            #expect(request.value(forHTTPHeaderField: "DPoP") == dPoP.rawValue)

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
            url: url,
            method: .post,
            requestPayload: .unprepared(requestBody),
            requestContentType: .json,
            responseContentType: .json,
            authenticationScheme: .dPoPAndAccessToken,
            interceptors: []
        )

        let responseBody = try await endpointClient.call(endpoint).get()

        #expect(responseBody == expectedResponseBody)
    }
}
