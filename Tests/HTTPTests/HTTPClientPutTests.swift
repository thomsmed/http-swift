import Foundation
import Testing

import HTTP

@Suite struct HTTPClientPutTests {
    @Test func testRequestPutEmptyRequestBodyEmptyResponseBody() async throws {
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

        let result: Result<Void, HTTP.PlainFailure> = await httpClient.request(
            .put,
            at: url,
            interceptors: []
        )

        _ = try result.get()
    }

    @Test func testRequestPutEmptyRequestBodyNonEmptyResponseBody() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let encoder = JSONEncoder()
        let httpClient = HTTP.Client(
            session: session,
            encoder: encoder
        )

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

        let result: Result<ResponseBody, HTTP.PlainFailure> = await httpClient.request(
            .put,
            at: url,
            responseContentType: .json,
            interceptors: []
        )

        let responseBody = try result.get()

        #expect(responseBody == expectedResponseBody)
    }

    @Test func testRequestPutNonEmptyRequestBodyEmptyResponseBody() async throws {
        let url = URL(string: "https://example.ios")!
        let session = MockSession()
        let decoder = JSONDecoder()
        let httpClient = HTTP.Client(
            session: session,
            decoder: decoder
        )

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

        let result: Result<Void, HTTP.PlainFailure> = await httpClient.request(
            .put,
            at: url,
            requestBody: requestBody,
            requestContentType: .json,
            interceptors: []
        )

        _ = try result.get()
    }

    @Test func testRequestPutNonEmptyRequestBodyNonEmptyResponseBody() async throws {
        let url = URL(string: "https://example.ios")!
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
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        let requestBody = RequestBody(message: "Hello World")

        let result: Result<ResponseBody, HTTP.PlainFailure> = await httpClient.request(
            .put,
            at: url,
            requestBody: requestBody,
            requestContentType: .json,
            responseContentType: .json,
            interceptors: []
        )

        let responseBody = try result.get()

        #expect(responseBody == expectedResponseBody)
    }
}
