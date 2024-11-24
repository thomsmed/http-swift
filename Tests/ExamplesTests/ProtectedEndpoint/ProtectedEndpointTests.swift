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
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)
        let trustMediator = MockTrustMediator()
        let endpointClient = ProtectedEndpointClient(httpClient: httpClient, trustMediator: trustMediator)
        let decoder = JSONDecoder()

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
            payload: (try? .json(from: requestBody)) ?? .empty(),
            parser: .json(),
            authenticationScheme: .none
        )

        let responseBody = try await endpointClient.call(endpoint)

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_call_endpointWithDPoPAuthorization() async throws {
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)
        let trustMediator = MockTrustMediator()
        let endpointClient = ProtectedEndpointClient(httpClient: httpClient, trustMediator: trustMediator)
        let decoder = JSONDecoder()

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

            let dPoP = await trustMediator.mockDPoP
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
            payload: (try? .json(from: requestBody)) ?? .empty(),
            parser: .json(),
            authenticationScheme: .dPoP
        )

        let responseBody = try await endpointClient.call(endpoint)

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_call_endpointWithAccessTokenAuthorization() async throws {
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)
        let trustMediator = MockTrustMediator()
        let endpointClient = ProtectedEndpointClient(httpClient: httpClient, trustMediator: trustMediator)
        let decoder = JSONDecoder()

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

            let accessToken = await trustMediator.mockAccessToken
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
            payload: (try? .json(from: requestBody)) ?? .empty(),
            parser: .json(),
            authenticationScheme: .accessToken
        )

        let responseBody = try await endpointClient.call(endpoint)

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_call_endpointWithDPoPAndAccessTokenAuthorization() async throws {
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)
        let trustMediator = MockTrustMediator()
        let endpointClient = ProtectedEndpointClient(httpClient: httpClient, trustMediator: trustMediator)
        let decoder = JSONDecoder()

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

            let accessToken = await trustMediator.mockAccessToken
            let dPoP = await trustMediator.mockDPoP
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
            payload: (try? .json(from: requestBody)) ?? .empty(),
            parser: .json(),
            authenticationScheme: .dPoPAndAccessToken
        )

        let responseBody = try await endpointClient.call(endpoint)

        #expect(responseBody == expectedResponseBody)
    }
}
