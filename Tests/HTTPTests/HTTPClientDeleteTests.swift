import Foundation
import Testing

import HTTP

@Suite struct HTTPClientDeleteTests {
    @Test func test_request_delete_withEmptyRequestBody_returnEmptyResponseBody() async throws {
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

        let result: Result<Void, HTTP.Failure> = await httpClient.request(
            .delete,
            at: url,
            interceptors: []
        )

        _ = try result.get()
    }

    @Test func test_request_delete_withEmptyRequestBody_returnNonEmptyResponseBody() async throws {
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

        let result: Result<ResponseBody, HTTP.Failure> = await httpClient.request(
            .delete,
            at: url,
            responseContentType: .json,
            interceptors: []
        )

        let responseBody = try result.get()

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_request_delete_withNonEmptyRequestBody_returnEmptyResponseBody() async throws {
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

        let result: Result<Void, HTTP.Failure> = await httpClient.request(
            .delete,
            at: url,
            requestBody: requestBody,
            requestContentType: .json,
            interceptors: []
        )

        _ = try result.get()
    }

    @Test func test_request_delete_withNonEmptyRequestBody_returnNonEmptyResponseBody() async throws {
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

        let result: Result<ResponseBody, HTTP.Failure> = await httpClient.request(
            .delete,
            at: url,
            requestBody: requestBody,
            requestContentType: .json,
            responseContentType: .json,
            interceptors: []
        )

        let responseBody = try result.get()

        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_request_delete_withEmptyRequestBodyAndEmptyResponseStatusCodes_returnNonEmptyResponseBody() async throws {
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

        let result: Result<ResponseBody?, HTTP.Failure> = await httpClient.request(
            .delete,
            at: url,
            responseContentType: .json,
            emptyResponseStatusCodes: [204],
            interceptors: []
        )

        let responseBody = try result.get()

        #expect(responseBody != nil)
        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_request_delete_withEmptyRequestBodyAndEmptyResponseStatusCodes_returnEmptyResponseBody() async throws {
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
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        let result: Result<ResponseBody?, HTTP.Failure> = await httpClient.request(
            .delete,
            at: url,
            responseContentType: .json,
            emptyResponseStatusCodes: [204],
            interceptors: []
        )

        let responseBody = try result.get()

        #expect(responseBody == nil)
    }

    @Test func test_request_delete_withNonEmptyRequestBodyAndEmptyResponseStatusCodes_returnNonEmptyResponseBody() async throws {
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

        let result: Result<ResponseBody?, HTTP.Failure> = await httpClient.request(
            .delete,
            at: url,
            requestBody: requestBody,
            requestContentType: .json,
            responseContentType: .json,
            emptyResponseStatusCodes: [204],
            interceptors: []
        )

        let responseBody = try result.get()

        #expect(responseBody != nil)
        #expect(responseBody == expectedResponseBody)
    }

    @Test func test_request_delete_withNonEmptyRequestBodyAndEmptyResponseStatusCodes_returnEmptyResponseBody() async throws {
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

        let result: Result<ResponseBody?, HTTP.Failure> = await httpClient.request(
            .delete,
            at: url,
            requestBody: requestBody,
            requestContentType: .json,
            responseContentType: .json,
            emptyResponseStatusCodes: [204],
            interceptors: []
        )

        let responseBody = try result.get()

        #expect(responseBody == nil)
    }

    @Test func test_request_delete_returnClientError() async throws {
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

        let result: Result<Void, HTTP.Failure> = await httpClient.request(
            .delete,
            at: url,
            interceptors: []
        )

        #expect {
            try result.get()
        } throws: { error in
            switch error {
                case let httpFailure as HTTP.Failure:
                    switch httpFailure {
                        case let .clientError(response):
                            return try response.decode() == expectedErrorBody
                        default:
                            return false
                    }
                default:
                    return false
            }
        }
    }

    @Test func test_request_delete_returnClientErrorWithData() async throws {
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

        let result: Result<Void, HTTP.Failure> = await httpClient.request(
            .delete,
            at: url,
            interceptors: []
        )

        #expect {
            try result.get()
        } throws: { error in
            switch error {
                case let httpFailure as HTTP.Failure:
                    switch httpFailure {
                        case let .clientError(response):
                            return response.body == expectedErrorResponseData
                        default:
                            return false
                    }
                default:
                    return false
            }
        }
    }
}
