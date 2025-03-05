import Foundation
import Testing

import HTTP

@Suite struct HTTPClientFetchTests {
    @Test func test_fetch_post() async throws {
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)

        struct RequestBody: Encodable {
            // ...
        }

        struct ResponseBody: Decodable {
            // ...
        }

        session.dataAndResponseForRequest = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: [:])
            return (Data("{}".utf8), response!)
        }

        let url = URL(string: "https://example.ios")!
        let requestBody = RequestBody()

        let _ = try await httpClient.fetch(
            ResponseBody.self,
            url: url,
            method: .post,
            payload: .json(encoded: requestBody),
            parser: .json(),
            additionalHeaders: [
                .userAgent("Some User-Agent"),
            ]
        )

        let _ = try await httpClient.fetch(
            HTTP.Response.self,
            url: url,
            method: .post,
            payload: .json(encoded: requestBody),
            parser: .passthrough(),
            additionalHeaders: [
                .userAgent("Some User-Agent"),
            ]
        )

        let _ = try await httpClient.fetch(
            ResponseBody.self,
            url: url,
            method: .post,
            payload: .empty(),
            parser: .json(),
            additionalHeaders: [
                .userAgent("Some User-Agent"),
            ]
        )

        let _ = try await httpClient.fetch(
            HTTP.Response.self,
            url: url,
            method: .post,
            payload: .empty(),
            parser: .passthrough(),
            additionalHeaders: [
                .userAgent("Some User-Agent"),
            ]
        )

        let _ = try await httpClient.fetch(
            ResponseBody.self,
            url: url,
            method: .post,
            payload: .json(encoded: requestBody),
            parser: .json(expecting: .ok),
            additionalHeaders: [
                .userAgent("Some User-Agent"),
            ]
        )

        let _ = try await httpClient.fetch(
            ResponseBody.self,
            url: url,
            method: .post,
            payload: .empty(),
            parser: .json(expecting: .ok),
            additionalHeaders: [
                .userAgent("Some User-Agent"),
            ]
        )
    }

    @Test func test_fetch_get() async throws {
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)

        struct ResponseBody: Decodable {
            // ...
        }

        session.dataAndResponseForRequest = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: [:])
            return (Data("{}".utf8), response!)
        }

        let url = URL(string: "https://example.ios")!

        let _ = try await httpClient.fetch(
            ResponseBody.self,
            url: url,
            method: .get,
            payload: .empty(),
            parser: .json(),
            additionalHeaders: [
                .userAgent("Some User-Agent"),
            ]
        )

        let _ = try await httpClient.fetch(
            HTTP.Response.self,
            url: url,
            method: .get,
            payload: .empty(),
            parser: .passthrough(),
            additionalHeaders: [
                .userAgent("Some User-Agent"),
            ]
        )

        let _ = try await httpClient.fetch(
            ResponseBody.self,
            url: url,
            method: .get,
            payload: .empty(),
            parser: .json(expecting: .ok),
            additionalHeaders: [
                .userAgent("Some User-Agent"),
            ]
        )
    }

    @Test func test_fetch_postWithCustomPayloadAndParser() async throws {
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)

        struct RequestBody: Encodable {
            let numbers: [UInt8]
        }

        struct ResponseBody: Decodable {
            let numbers: [UInt8]
        }

        session.dataAndResponseForRequest = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: [:])
            return (request.httpBody!, response!)
        }

        let numbers: [UInt8] = [1, 2, 3, 4, 5]
        let url = URL(string: "https://example.ios")!
        let requestBody = RequestBody(numbers: numbers)

        let response = try await httpClient.fetch(
            ResponseBody.self,
            url: url,
            method: .post,
            payload: HTTP.RequestPayload(
                mimeType: HTTP.MimeType(rawValue: "some/mime"),
                body: Data(requestBody.numbers)
            ),
            parser: HTTP.ResponseParser(
                mimeType: HTTP.MimeType(rawValue: "some/other+mime")
            ) { response in
                guard HTTP.Status.noContent.contains(response.statusCode) else {
                    throw HTTP.UnexpectedResponse(response)
                }

                return ResponseBody(numbers: Array(response.body))
            },
            additionalHeaders: [
                HTTP.Header(name: "My-Header", value: "Some Header Value")
            ]
        )

        #expect(response.numbers == numbers)
    }

    @Test func test_fetch_getWithCustomParser() async throws {
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)

        struct ResponseBody: Decodable {
            let numbers: [UInt8]
        }

        let expectedNumbers: [UInt8] = [1, 2, 3, 4, 5]

        session.dataAndResponseForRequest = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: [:])
            return (Data(expectedNumbers), response!)
        }

        let url = URL(string: "https://example.ios")!

        let firstResponse = try await httpClient.fetch(
            ResponseBody?.self,
            url: url,
            method: .get,
            payload: .empty(),
            parser: HTTP.ResponseParser(
                mimeType: HTTP.MimeType(rawValue: "some/other+mime")
            ) { response in
                guard HTTP.Status.ok.contains(response.statusCode) else {
                    return nil
                }

                return ResponseBody(numbers: Array(response.body))
            },
            additionalHeaders: [
                HTTP.Header(name: "My-Header", value: "Some Header Value")
            ]
        )

        #expect(firstResponse != nil)
        #expect(firstResponse?.numbers == expectedNumbers)

        session.dataAndResponseForRequest = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: [:])
            return (Data(), response!)
        }

        let secondResponse = try await httpClient.fetch(
            ResponseBody?.self,
            url: url,
            method: .get,
            payload: .empty(),
            parser: HTTP.ResponseParser(
                mimeType: HTTP.MimeType(rawValue: "some/other+mime")
            ) { response in
                guard HTTP.Status.ok.contains(response.statusCode) else {
                    return nil
                }

                return ResponseBody(numbers: Array(response.body))
            },
            additionalHeaders: [
                HTTP.Header(name: "My-Header", value: "Some Header Value")
            ]
        )

        #expect(secondResponse == nil)
    }

    @Test func test_fetch_post_throwsUnexpectedResponse() async throws {
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)

        struct UnexpectedResult: Error {
            let reason: String
        }

        struct ResponseBody: Decodable {
            let numbers: [UInt8]
        }

        session.dataAndResponseForRequest = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: [:])
            return (Data("{\"message\": \"Not Found\"}".utf8), response!)
        }

        let url = URL(string: "https://example.ios")!

        do {
            let _ = try await httpClient.fetch(
                ResponseBody.self,
                url: url,
                method: .get,
                payload: .empty(),
                parser: .json(expecting: .ok),
                additionalHeaders: [
                    .userAgent("Some User-Agent"),
                ]
            )
        } catch is HTTP.TransportError {
            throw UnexpectedResult(reason: "Expected HTTP.UnexpectedResponse")
        } catch is HTTP.MaxRetryCountReached {
            throw UnexpectedResult(reason: "Expected HTTP.UnexpectedResponse")
        } catch let unexpectedResponse as HTTP.UnexpectedResponse {
            #expect(unexpectedResponse.statusCode == 404)
            let errorResponse: [String: String] = try unexpectedResponse.parsed(using: .json())
            #expect(errorResponse == ["message": "Not Found"])
        } catch is CancellationError {
            throw UnexpectedResult(reason: "Expected HTTP.UnexpectedResponse")
        } catch {
            throw UnexpectedResult(reason: "Expected HTTP.UnexpectedResponse")
        }

        do {
            let _ = try await httpClient.fetch(
                ResponseBody.self,
                url: url,
                method: .get,
                payload: .empty(),
                parser: .json(expecting: .ok),
                additionalHeaders: [
                    .userAgent("Some User-Agent"),
                ]
            )
        } catch let unexpectedResponse as HTTP.UnexpectedResponse where unexpectedResponse.statusCode == 404 {
            let errorResponse: [String: String] = try unexpectedResponse.parsed(using: .json())
            #expect(errorResponse == ["message": "Not Found"])
        }
    }
}
