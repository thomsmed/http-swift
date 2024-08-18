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

## Request

```swift
let httpClient = HTTP.Client()

let result: Result<Void, HTTP.PlainFailure> = await httpClient.request(
    .get,
    at: URL(string: "https://example.ios")!,
    interceptors: []
)
```

## Intercept

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

let httpClient = HTTP.Client(
    interceptors: [
        UserAgentInterceptor()
    ]
)

let result: Result<Void, HTTP.PlainFailure> = await httpClient.request(
    .get,
    at: URL(string: "https://example.ios")!,
    interceptors: []
)
```

## Observe

```swift
struct PrintingObserver: HTTP.Observer {
    func didPrepare(_ request: URLRequest) {
        print("Did prepare request:", request)
    }

    func didEncounter(_ transportError: any Error) {
        print("Did encounter transport error:", transportError)
    }

    func didReceive(_ response: HTTPURLResponse) {
        print("Did receive response:", response)
    }
}

let httpClient = HTTP.Client(
    observers: [
        PrintingObserver()
    ]
)

let result: Result<Void, HTTP.PlainFailure> = await httpClient.request(
    .get,
    at: URL(string: "https://example.ios")!,
    interceptors: []
)
```
