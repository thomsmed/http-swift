import Foundation
import Testing

import HTTP

@Suite struct HTTPClientGetTests {
    @Test func test_fetch_get_returnEmptyResponseBody() async throws {
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
            method: .get,
            payload: .empty(),
            parser: .void()
        )
    }

    @Test func test_fetch_get_returnNonEmptyResponseBody() async throws {
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
            method: .get,
            payload: .empty(),
            parser: .json()
        )

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_fetch_getWithEmptyResponseStatusCodes_returnEmptyResponseBody() async throws {
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
            method: .get,
            payload: .empty(),
            parser: .json(ignoring: .noContent)
        )

        #expect(responseBody == nil)
    }

    @Test func test_fetch_getWithEmptyResponseStatusCodes_returnNonEmptyResponseBody() async throws {
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
            method: .get,
            payload: .empty(),
            parser: .json(ignoring: .noContent)
        )

        #expect(responseBody != nil)
        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_fetch_get_throwsUnexpectedResponse() async throws {
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
                method: .get,
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

    @Test func test_fetch_get_throwsUnexpectedResponseWithData() async throws {
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
                method: .get,
                payload: .empty(),
                parser: .void()
            )
        } throws: { error in
            guard let unexpectedResponse = error as? HTTP.UnexpectedResponse else {
                return false
            }
            return try unexpectedResponse.body == expectedErrorResponseData
        }
    }
}
