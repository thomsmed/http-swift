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
