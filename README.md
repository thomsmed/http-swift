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

## Request

```swift
let httpClient = HTTP.Client()

struct Response {
    /* ... */
}

let result: Result<Response, HTTP.Failure> = await httpClient.request(
    .get,
    at: URL(string: "https://example.ios")!,
    responseContentType: .json,
    interceptors: []
)

// Optionally specify response status codes that yield empty responses

let result: Result<Response?, HTTP.Failure> = await httpClient.request(
    .get,
    at: url,
    responseContentType: .json,
    emptyResponseStatusCodes: [204],
    interceptors: []
)

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
            // ...
        } else if let errorBody = try? errorResponse.decode(as: .json) as AnotherTypeOfErrorBody {
            // ...
        } else {
            // ...
        }
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

        return .retryAfter(powf(1, Float(context.retryCount)))
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

let result: Result<Void, HTTP.Failure> = await httpClient.request(
    .get,
    at: URL(string: "https://example.ios")!,
    interceptors: []
)
```

## Observe

```swift
struct PrintingObserver: HTTP.Observer {
    func didPrepare(_ request: URLRequest, with context: Context)
        print("Did prepare request:", request)
    }

    func didEncounter(_ transportError: any Error, with context: Context)
        print("Did encounter transport error:", transportError)
    }

    func didReceive(_ response: HTTPURLResponse, with context: Context)
        print("Did receive response:", response)
    }
}

let httpClient = HTTP.Client(
    observers: [
        PrintingObserver()
    ]
)

let result: Result<Void, HTTP.Failure> = await httpClient.request(
    .get,
    at: URL(string: "https://example.ios")!,
    interceptors: []
)
```

## Encapsulate requests in Endpoints

```swift
let httpClient = HTTP.Client()

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
            .post,
            at: url,
            requestBody: request,
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

let result = await httpClient.call(Feature.featureEndpoint(text: "Hello World"))
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
