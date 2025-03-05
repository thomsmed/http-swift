import Foundation

public extension HTTP.Method {
    /// HTTP Method GET.
    static let get = HTTP.Method(rawValue: "GET")

    /// HTTP Method PUT.
    static let put = HTTP.Method(rawValue: "PUT")

    /// HTTP Method POST.
    static let post = HTTP.Method(rawValue: "POST")

    /// HTTP Method DELETE.
    static let delete = HTTP.Method(rawValue: "DELETE")
}

public extension HTTP.MimeType {
    /// HTTP MIME Type `application/json`.
    static let json = HTTP.MimeType(rawValue: "application/json")
}

public extension HTTP.Header {
    /// HTTP (Request and Response) Header `Content-Type`.
    static func contentType(_ mimeType: HTTP.MimeType) -> HTTP.Header {
        HTTP.Header(name: "Content-Type", value: mimeType.rawValue)
    }

    /// HTTP (Request) Header `Accept`.
    static func accept(_ mimeType: HTTP.MimeType) -> HTTP.Header{
        HTTP.Header(name: "Accept", value: mimeType.rawValue)
    }

    /// HTTP (Request) Header `User-Agent`.
    static func userAgent(_ value: String) -> HTTP.Header {
        HTTP.Header(name: "User-Agent", value: value)
    }
}

public extension HTTP.Status {
    /// HTTP Response Status Code `200 OK`.
    static var ok: HTTP.Status {
        HTTP.Status(code: 200, description: HTTPURLResponse.localizedString(forStatusCode: 200))
    }

    /// HTTP Response Status Code `201 Created`.
    static var created: HTTP.Status {
        HTTP.Status(code: 201, description: HTTPURLResponse.localizedString(forStatusCode: 201))
    }

    /// HTTP Response Status Code `204 No Content`.
    static var noContent: HTTP.Status {
        HTTP.Status(code: 204, description: HTTPURLResponse.localizedString(forStatusCode: 204))
    }

    /// HTTP Response Status Codes in the range `200 - 299` (Successful responses).
    static var successful: HTTP.Status {
        HTTP.Status(codes: 200..<300, description: "Successful")
    }
}

public extension HTTP.RequestPayload {
    /// Empty HTTP Request Payload (MIME Type + Request body).
    static func empty() -> HTTP.RequestPayload {
        HTTP.RequestPayload(mimeType: nil, body: nil)
    }

    /// Raw `Data` HTTP Request Payload (MIME Type + Request body).
    static func data(_ data: Data, representing mimeType: HTTP.MimeType? = nil) -> HTTP.RequestPayload {
        HTTP.RequestPayload(mimeType: mimeType, body: data)
    }

    /// JSON HTTP Request Payload (MIME Type + Request body).
    static func json<T: Encodable>(encoded value: T) throws -> HTTP.RequestPayload {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        return HTTP.RequestPayload(mimeType: .json, body: data)
    }
}

public extension HTTP.ResponseParser {
    /// HTTP Response Parser that ignores any HTTP Response body, and just returns `Void`.
    static func void(
        expecting expectedStatus: HTTP.Status = .successful
    ) -> HTTP.ResponseParser<Void> {
        HTTP.ResponseParser(mimeType: nil) { response in
            guard HTTP.Status.successful.contains(response.statusCode) else {
                throw HTTP.UnexpectedResponse(response)
            }
        }
    }

    /// HTTP Response Parser that just passes through the returned HTTP Response untouched.
    static func passthrough(
        expecting expectedStatus: HTTP.Status = .successful
    ) -> HTTP.ResponseParser<HTTP.Response> {
        HTTP.ResponseParser(mimeType: nil) { response in
            guard HTTP.Status.successful.contains(response.statusCode) else {
                throw HTTP.UnexpectedResponse(response)
            }
            return response
        }
    }

    /// HTTP Response Parser that tries to parse any HTTP Response body as JSON.
    static func json<T: Decodable>(
        expecting expectedStatus: HTTP.Status = .successful
    ) -> HTTP.ResponseParser<T> {
        return HTTP.ResponseParser(mimeType: .json) { response in
            guard expectedStatus.contains(response.statusCode) else {
                throw HTTP.UnexpectedResponse(response)
            }
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: response.body)
        }
    }

    /// HTTP Response Parser that tries to parse any HTTP Response body as JSON,
    /// with an optional set of HTTP Response Status Codes to ignore (and just return `nil` instead).
    static func json<T: Decodable>(
        expecting expectedStatus: HTTP.Status = .successful,
        ignoring ignoredStatus: HTTP.Status
    ) -> HTTP.ResponseParser<T?> {
        return HTTP.ResponseParser(mimeType: .json) { response in
            if ignoredStatus.contains(response.statusCode) {
                return nil
            }
            guard expectedStatus.contains(response.statusCode) else {
                throw HTTP.UnexpectedResponse(response)
            }
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: response.body)
        }
    }
}

public extension HTTP.UnexpectedResponseParser {
    /// HTTP Unexpected Response Parser that tries to parse any HTTP Unexpected Response body as JSON.
    static func json<T: Decodable>() -> HTTP.UnexpectedResponseParser<T> {
        return HTTP.UnexpectedResponseParser() { response in
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: response.body)
        }
    }
}
