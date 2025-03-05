import Foundation
import Testing

import HTTP

@Suite struct HTTPClientPutTests {
    @Test func test_fetch_putWithEmptyRequestBody_returnEmptyResponseBody() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)

        session.dataAndResponseForRequest = { request in
            // Echo request body.
            return (request.httpBody ?? Data(), HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        let _ = try await httpClient.fetch(
            Void.self,
            url: url,
            method: .put,
            payload: .empty(),
            parser: .void()
        )
    }

    @Test func test_fetch_putWithEmptyRequestBody_returnNonEmptyResponseBody() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)
        let encoder = JSONEncoder()

        struct ResponseBody: Codable, Equatable {
            let message: String
        }

        let expectedResponseBody = ResponseBody(message: "Hello World")

        session.dataAndResponseForRequest = { request in
            let data = (try? encoder.encode(expectedResponseBody)) ?? Data()
            return (data, HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        let responseBody = try await httpClient.fetch(
            ResponseBody.self,
            url: url,
            method: .put,
            payload: .empty(),
            parser: .json()
        )

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_fetch_putWithNonEmptyRequestBody_returnEmptyResponseBody() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)
        let decoder = JSONDecoder()

        struct RequestBody: Codable, Equatable {
            let message: String
        }

        let expectedRequestBody = RequestBody(message: "Hello World")

        session.dataAndResponseForRequest = { request in
            let requestBody = try? decoder.decode(RequestBody.self, from: request.httpBody ?? Data())
            #expect(requestBody == expectedRequestBody)

            return (Data(), HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        let requestBody = RequestBody(message: "Hello World")

        let _ = try await httpClient.fetch(
            Void.self,
            url: url,
            method: .put,
            payload: .json(encoded: requestBody),
            parser: .void()
        )
    }

    @Test func test_fetch_putWithNonEmptyRequestBody_returnNonEmptyResponseBody() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)
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

            // Echo request body.
            return (request.httpBody ?? Data(), HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        let requestBody = RequestBody(message: "Hello World")

        let responseBody = try await httpClient.fetch(
            ResponseBody.self,
            url: url,
            method: .put,
            payload: .json(encoded: requestBody),
            parser: .json()
        )

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_fetch_putWithEmptyRequestBodyAndEmptyResponseStatusCodes_returnNonEmptyResponseBody() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)
        let encoder = JSONEncoder()

        struct ResponseBody: Codable, Equatable {
            let message: String
        }

        let expectedResponseBody = ResponseBody(message: "Hello World")

        session.dataAndResponseForRequest = { request in
            let data = (try? encoder.encode(expectedResponseBody)) ?? Data()
            return (data, HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        let responseBody = try await httpClient.fetch(
            ResponseBody?.self,
            url: url,
            method: .put,
            payload: .empty(),
            parser: .json(ignoring: .noContent)
        )

        #expect(responseBody != nil)
        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_fetch_putWithEmptyRequestBodyAndEmptyResponseStatusCodes_returnEmptyResponseBody() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)
        let encoder = JSONEncoder()

        struct ResponseBody: Codable, Equatable {
            let message: String
        }

        let expectedResponseBody = ResponseBody(message: "Hello World")

        session.dataAndResponseForRequest = { request in
            let data = (try? encoder.encode(expectedResponseBody)) ?? Data()
            return (data, HTTPURLResponse(
                url: url,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        let responseBody = try await httpClient.fetch(
            ResponseBody?.self,
            url: url,
            method: .put,
            payload: .empty(),
            parser: .json(ignoring: .noContent)
        )

        #expect(responseBody == nil)
    }

    @Test func test_fetch_putWithNonEmptyRequestBodyIgnoringNoContent_returnNonEmptyResponseBody() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)
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

            // Echo request body.
            return (request.httpBody ?? Data(), HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        let requestBody = RequestBody(message: "Hello World")

        let responseBody = try await httpClient.fetch(
            ResponseBody?.self,
            url: url,
            method: .put,
            payload: .json(encoded: requestBody),
            parser: .json(ignoring: .noContent)
        )

        #expect(responseBody != nil)
        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_fetch_putWithNonEmptyRequestBodyAndEmptyResponseStatusCodes_returnEmptyResponseBody() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)
        let decoder = JSONDecoder()

        struct RequestBody: Codable, Equatable {
            let message: String
        }

        let expectedRequestBody = RequestBody(message: "Hello World")

        struct ResponseBody: Codable, Equatable {
            let message: String
        }

        session.dataAndResponseForRequest = { request in
            let requestBody = try? decoder.decode(RequestBody.self, from: request.httpBody ?? Data())
            #expect(requestBody == expectedRequestBody)

            // Echo request body.
            return (request.httpBody ?? Data(), HTTPURLResponse(
                url: url,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        let requestBody = RequestBody(message: "Hello World")

        let responseBody = try await httpClient.fetch(
            ResponseBody?.self,
            url: url,
            method: .put,
            payload: .json(encoded: requestBody),
            parser: .json(ignoring: .noContent)
        )

        #expect(responseBody == nil)
    }

    @Test func test_fetch_put_throwsUnexpectedResponse() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)

        struct ErrorBody: Equatable, Codable {
            let message: String
        }

        let expectedErrorBody = ErrorBody(message: "Error")

        session.dataAndResponseForRequest = { request in
            // Echo request body.
            return ((try? session.encoder.encode(expectedErrorBody)) ?? Data(), HTTPURLResponse(
                url: url,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        await #expect {
            try await httpClient.fetch(
                Void.self,
                url: url,
                method: .put,
                payload: .empty(),
                parser: .void()
            )
        } throws: { error in
            guard let unexpectedResponse = error as? HTTP.UnexpectedResponse else {
                return false
            }
            return try unexpectedResponse.parsed(using: .json()) == expectedErrorBody
        }
    }

    @Test func test_fetch_put_throwsUnexpectedResponseWithData() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)

        struct ErrorBody: Equatable, Codable {
            let message: String
        }

        let expectedErrorResponseData = Data("{ \"error\": \"Error\" }".utf8)

        session.dataAndResponseForRequest = { request in
            // Echo request body.
            return (expectedErrorResponseData, HTTPURLResponse(
                url: url,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        await #expect {
            try await httpClient.fetch(
                Void.self,
                url: url,
                method: .put,
                payload: .empty(),
                parser: .void()
            )
        } throws: { error in
            guard let unexpectedResponse = error as? HTTP.UnexpectedResponse else {
                return false
            }
            return unexpectedResponse.body == expectedErrorResponseData
        }
    }
}
