# HTTPSwift

A simple - yet powerful - HTTP Client library for Swift.

## Install

Add this package as a dependency to your `Package.swift` or the Package List in Xcode.

```swift
dependencies: [
    .package(url: "https://github.com/thomsmed/http-swift.git", .branch: "main)
]
```

Add the `HTTP` product of this package as a product dependency to your targets.

```swift
dependencies: [
    .product(name: "HTTP", package: "HTTPSwift")
]
```

## Fetch

```swift
let httpClient = HTTP.Client()

// Without request payload

struct Response: Decodable {
    /* ... */
}

let _ = try await httpClient.fetch(
    Response.self,
    url: URL(string: "https://example.ios")!,
    method: .get,
    payload: .empty(),
    parser: .json(),
    interceptors: []
)

// With JSON payload

struct Request: Encodable {
    /* ... */
}

let request = Request()

let _ = try await httpClient.fetch(
    Response.self,
    url: URL(string: "https://example.ios")!,
    method: .post,
    payload: .json(encoded: request),
    parser: .json(),
    interceptors: []
)

// With data payload

let data = try JSONEncoder().encode(request)

let _ = try await httpClient.fetch(
    Response.self,
    url: URL(string: "https://example.ios")!,
    method: .post,
    payload: .data(data, representing: .json),
    parser: .json(),
    interceptors: []
)

// Specify response statuses that yield empty responses

let _ = try await httpClient.fetch(
    Response?.self,
    url: URL(string: "https://example.ios")!,
    method: .get,
    payload: .empty(),
    parser: .json(ignoring: .noContent),
    interceptors: []
)

// Parse error responses

struct OneTypeOfErrorBody: Decodable {
    let message: String
}

struct AnotherTypeOfErrorBody: Decodable {
    let code: Int
}

do {
    let _ = try await httpClient.fetch(
        Response.self,
        url: URL(string: "https://example.ios")!,
        method: .get,
        payload: .empty(),
        parser: .json(),
        interceptors: []
    )
} catch let transportError as HTTP.TransportError {
    print("HTTP Transport Error:", transportError)
} catch is HTTP.MaxRetryCountReached {
    print("Max HTTP Request retry count reached")
} catch let unexpectedResponse as HTTP.UnexpectedResponse {
    if let errorBody: OneTypeOfErrorBody = try? unexpectedResponse.parsed(using: .json()) {
        print("Error Body:", errorBody)
    } else if let errorBody = try? unexpectedResponse.parsed(as: AnotherTypeOfErrorBody.self, using: .json()) {
        print("Error Body:", errorBody)
    } else {
        let errorMessage = try? JSONDecoder().decode(String.self, from: unexpectedResponse.body)
        print("Error Message:", errorMessage ?? "<unknown>")
    }
}
```

## Intercept (and retry)

```swift
struct UserAgentInterceptor: HTTP.Interceptor {
    func prepare(_ request: inout URLRequest, with context: HTTP.Context) async throws {
        request.setValue("My User-Agent", forHTTPHeaderField: "User-Agent")
    }

    func handle(_ transportError: HTTP.TransportError, with context: HTTP.Context) async -> HTTP.Evaluation {
        .proceed
    }

    func process(_ response: inout HTTPURLResponse, data: inout Data, with context: HTTP.Context) async throws -> HTTP.Evaluation {
        .proceed
    }
}

struct RetryOnTransportErrorInterceptor: HTTP.Interceptor {
    func prepare(_ request: inout URLRequest, with context: HTTP.Context) async throws {
        // No-op
    }

    func handle(_ transportError: HTTP.TransportError, with context: HTTP.Context) async -> HTTP.Evaluation {
        guard context.retryCount < 5 else {
            return .proceed
        }

        return .retryAfter(TimeInterval(powf(1, Float(context.retryCount))))
    }

    func process(_ response: inout HTTPURLResponse, data: inout Data, with context: HTTP.Context) async throws -> HTTP.Evaluation {
        .proceed
    }
}

let httpClient = HTTP.Client(
    interceptors: [
        UserAgentInterceptor(),
        RetryOnTransportErrorInterceptor()
    ]
)

let _ = try await httpClient.fetch(
    Void.self,
    url: URL(string: "https://example.ios")!,
    method: .get,
    payload: .empty(),
    parser: .void(),
    interceptors: []
)
```

## Observe

```swift
struct PrintingObserver: HTTP.Observer {
    func didPrepare(_ request: URLRequest, with context: HTTP.Context) {
        print("Did prepare request:", request)
    }

    func didEncounter(_ transportError: HTTP.TransportError, with context: HTTP.Context) {
        print("Did encounter transport error:", transportError)
    }

    func didReceive(_ response: HTTPURLResponse, with context: HTTP.Context) {
        print("Did receive response:", response)
    }
}

let httpClient = HTTP.Client(
    observers: [
        PrintingObserver()
    ]
)

let _ = try await httpClient.fetch(
    Void.self,
    url: URL(string: "https://example.ios")!,
    method: .get,
    payload: .empty(),
    parser: .void(),
    interceptors: []
)
```

## Represent requests and responses as Endpoints

```swift
let httpClient = HTTP.Client()

// Scope Endpoints to their models/domains

struct Feature {
    struct Response {
        let text: String
    }

    static func featureEndpoint(text: String) throws -> HTTP.Endpoint<Response> {
        struct Request: Encodable {
            let text: String
        }

        let url = URL(string: "https://example.ios/feature/endpoint")!

        let request = Request(text: text)

        return HTTP.Endpoint(
            url: url,
            method: .post,
            payload: try .json(encoded: request),
            parser: HTTP.ResponseParser(mimeType: .json) { response in
                struct ActualResponse: Decodable {
                    let number: Int
                }
                let actualResponse: ActualResponse = try response.parsed(using: .json())
                return Response(text: String(actualResponse.number))
            },
            interceptors: []
        )
    }
}

// Call endpoints on their models/domains

let _ = try await httpClient.call(Feature.featureEndpoint(text: "Hello World"))
```

## Extend

```swift
public extension HTTP.Method {
    /// HTTP Method HEAD.
    static let head = HTTP.Method(rawValue: "HEAD")
}

public extension HTTP.MimeType {
    /// HTTP MIME Type `application/jwt`.
    static let jwt = HTTP.MimeType(rawValue: "application/jwt")
}

public extension HTTP.Header {
    /// HTTP (Request) Header `Accept-Language`.
    static func userAgent(_ value: String) -> HTTP.Header {
        HTTP.Header(name: "Accept-Language", value: value)
    }
}

public extension HTTP.Status {
    /// HTTP Response Status Codes in the range `400 - 499` (Client error responses).
    static var clientError: HTTP.Status {
        HTTP.Status(codes: 400..<500, description: "Client Error")
    }
}

public extension HTTP.RequestPayload {
    /// JWT HTTP Request Payload (MIME Type + Request body).
    static func jwt<T: Encodable>(encoded value: T) throws -> HTTP.RequestPayload {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        return HTTP.RequestPayload(mimeType: .jwt, body: data)
    }

    /// JWT HTTP Request Payload (MIME Type + Request body).
    static func jwt(_ data: Data) throws -> HTTP.RequestPayload {
        return HTTP.RequestPayload(mimeType: .jwt, body: data)
    }
}

public extension HTTP.ResponseParser {
    /// HTTP Response Parser that tries to parse any HTTP Response body as a JWT,
    /// with an optional set of HTTP Response Status Codes to ignore (and just return `nil` instead).
    static func jwt<T: Decodable>(
        expecting expectedStatus: HTTP.Status = .successful,
        ignoring ignoredStatus: HTTP.Status = .clientError
    ) -> HTTP.ResponseParser<T?> {
        return HTTP.ResponseParser(mimeType: .jwt) { response in
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

public struct ProblemResponse: Decodable {
    let type: String
    let title: String
    let detail: String
}

public extension HTTP.UnexpectedResponse {
    /// HTTP Unexpected Response Parser that tries to parse any HTTP Unexpected Response body as a `ProblemResponse`.
    static func problem() -> HTTP.UnexpectedResponseParser<ProblemResponse> {
        return HTTP.UnexpectedResponseParser() { response in
            let decoder = JSONDecoder()
            return try decoder.decode(ProblemResponse.self, from: response.body)
        }
    }
}

// Use extensions

let httpClient = HTTP.Client()

struct RequestJWT: Encodable {
    let foo: String
}

struct ResponseJWT: Decodable {
    let bar: String
}

do {
    let endpoint = HTTP.Endpoint<ResponseJWT?>(
        url: URL(string: "https://example.ios")!,
        method: .head,
        payload: try .jwt(encoded: RequestJWT(foo: "bar")),
        parser: .jwt(expecting: .successful, ignoring: .clientError),
        additionalHeaders: [
            .acceptLanguage("en")
        ],
        interceptors: []
    )

    let _ = try await httpClient.call(endpoint)
} catch let unexpectedResponse as HTTP.UnexpectedResponse {
    let problemResponse = try unexpectedResponse.parsed(using: .problem())
    print("Problem Response:", problemResponse)
}
```

## Disclaimer

This library is currently in an early experimentation phase, and might change drastically in all kind of ways.
Use it more as a source of inspiration than anything else.

## License

MIT License

Copyright (c) 2024 Thomas Asheim Smedmann

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
