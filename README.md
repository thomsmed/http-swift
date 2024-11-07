# HTTPSwift

A simple - yet powerful - HTTP client library for Swift.

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

let _ = await httpClient.fetch(
    Response.self,
    url: URL(string: "https://example.ios")!,
    method: .get,
    responseContentType: .json,
    interceptors: []
)

// With unprepared request payload (have HTTP.Client prepare/encode the payload for us)

struct Request: Encodable {
    /* ... */
}

let request = Request()

let _ = await httpClient.fetch(
    Response.self,
    url: URL(string: "https://example.ios")!,
    method: .post,
    requestPayload: .unprepared(request),
    requestContentType: .json,
    responseContentType: .json,
    interceptors: []
)

// With prepared request payload (prepare/encode the payload ourselves)

let data = try JSONEncoder().encode(request)

let _ = await httpClient.fetch(
    Response.self,
    url: URL(string: "https://example.ios")!,
    method: .post,
    requestPayload: .prepared(data),
    requestContentType: .json,
    responseContentType: .json,
    interceptors: []
)

// Optionally specify response status codes that yield empty responses

let result = await httpClient.fetch(
    Response.self,
    url: URL(string: "https://example.ios")!,
    method: .get,
    responseContentType: .json,
    emptyResponseStatusCodes: [204],
    interceptors: []
)

// Parse error responses

struct OneTypeOfErrorBody: Decodable {
    let message: String
}

struct AnotherTypeOfErrorBody: Decodable {
    let code: Int
}

switch result {
case .success:
    break

case .failure(.clientError(let errorResponse)):
    if let errorBody: OneTypeOfErrorBody = try? errorResponse.decode(as: .json) {
        print("Error Body:", errorBody)
    } else if let errorBody = try? errorResponse.decode(as: .json) as AnotherTypeOfErrorBody {
        print("Error Body:", errorBody)
    } else {
        let errorMessage = try? JSONDecoder().decode(String.self, from: errorResponse.body)
        print("Error Message:", errorMessage ?? "<unknown>")
    }

default:
    break
}
```

## Intercept (and retry)

```swift
struct UserAgentInterceptor: HTTP.Interceptor {
    func prepare(_ request: inout URLRequest, with context: HTTP.Context) async throws {
        request.setValue("My User-Agent", forHTTPHeaderField: "User-Agent")
    }

    func handle(_ transportError: any Error, with context: HTTP.Context) async -> HTTP.Evaluation {
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

    func handle(_ transportError: any Error, with context: HTTP.Context) async -> HTTP.Evaluation {
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

let _ = await httpClient.fetch(
    url: URL(string: "https://example.ios")!,
    method: .get,
    interceptors: []
)
```

## Observe

```swift
struct PrintingObserver: HTTP.Observer {
    func didPrepare(_ request: URLRequest, with context: HTTP.Context) {
        print("Did prepare request:", request)
    }

    func didEncounter(_ transportError: any Error, with context: HTTP.Context) {
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

let _ = await httpClient.fetch(
    url: URL(string: "https://example.ios")!,
    method: .get,
    interceptors: []
)
```

## Encapsulate requests in Endpoints

```swift
let httpClient = HTTP.Client()

// Scope Endpoints to their models/domains

struct Feature {
    struct Response {
        let text: String
    }

    static func featureEndpoint(text: String) -> HTTP.Endpoint<Response> {
        struct Request: Encodable {
            let text: String
        }

        let url = URL(string: "https://example.ios/feature/endpoint")!

        let request = Request(text: text)

        return HTTP.Endpoint(
            url: url,
            method: .post,
            requestPayload: .unprepared(request),
            requestContentType: .json,
            responseContentType: .json,
            interceptors: []
        ) { response in
            struct ActualResponse: Decodable {
                let number: Int
            }
            let actualResponse: ActualResponse = try response.decode(as: .json)
            return Response(text: String(actualResponse.number))
        }
    }
}

// Call endpoints on their models/domains

let _ = await httpClient.call(Feature.featureEndpoint(text: "Hello World"))
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
