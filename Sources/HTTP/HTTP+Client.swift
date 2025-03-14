import Foundation

public extension HTTP {
    final class Client: Sendable {
        private enum SendResult {
            case success(HTTP.Response)
            case retry
            case retryAfter(TimeInterval)
        }

        public struct Options: Sendable {
            public let maxRetryCount: Int
            public let timeout: TimeInterval

            public init(
                maxRetryCount: Int = 5,
                timeout: TimeInterval = 30
            ) {
                self.maxRetryCount = maxRetryCount
                self.timeout = timeout
            }
        }

        private let session: any HTTP.Session

        private let observers: [any HTTP.Observer]
        private let interceptors: [any HTTP.Interceptor]

        private let options: Options

        public init(
            session: any HTTP.Session = URLSession.shared,
            observers: [any HTTP.Observer] = [],
            interceptors: [any HTTP.Interceptor] = [],
            options: Options = Options()
        ) {
            self.session = session
            self.observers = observers
            self.interceptors = interceptors
            self.options = options
        }

        // MARK: Sending

        private func send(
            _ request: HTTP.Request,
            interceptors: [HTTP.Interceptor],
            context: HTTP.Context
        ) async throws -> SendResult {
            var urlRequest = URLRequest(url: request.url)
            urlRequest.httpMethod = request.method.rawValue
            urlRequest.httpBody = request.body

            for header in request.headers {
                urlRequest.setValue(header.value, forHTTPHeaderField: header.name)
            }

            try Task.checkCancellation()

            for interceptor in interceptors {
                try await interceptor.prepare(&urlRequest, with: context)

                try Task.checkCancellation()
            }

            for observer in self.observers {
                observer.didPrepare(urlRequest, with: context)
            }

            var (data, httpURLResponse): (Data, HTTPURLResponse)
            do {
                (data, httpURLResponse) = try await session.data(
                    for: urlRequest,
                    followRedirects: request.followRedirects
                )
            } catch let cancellationError as CancellationError {
                throw cancellationError
            } catch {
                let transportError = HTTP.TransportError(error)

                for observer in self.observers {
                    observer.didEncounter(transportError, with: context)
                }

                try Task.checkCancellation()

                // Give the last interceptor the opportunity to handle the error first.
                for interceptor in interceptors.reversed() {
                    let evaluation = await interceptor.handle(transportError, with: context)

                    try Task.checkCancellation()

                    switch evaluation {
                    case .retry:
                        return .retry
                    case .retryAfter(let timeInterval):
                        return .retryAfter(timeInterval)
                    case .proceed:
                        break
                    }
                }

                throw transportError
            }

            for observer in self.observers {
                observer.didReceive(httpURLResponse, with: context)
            }

            try Task.checkCancellation()

            // Give the last interceptor the opportunity to process the response first.
            for interceptor in interceptors.reversed() {
                let evaluation = try await interceptor.process(&httpURLResponse, data: &data, with: context)

                try Task.checkCancellation()

                switch evaluation {
                case .retry:
                    return .retry
                case .retryAfter(let timeInterval):
                    return .retryAfter(timeInterval)
                case .proceed:
                    break
                }
            }

            let headers = httpURLResponse.allHeaderFields.keys
                .reduce(into: [Header]()) { headers, key in
                    guard
                        let headerName = key as? String,
                        let headerValue = httpURLResponse.value(forHTTPHeaderField: headerName)
                    else {
                        return
                    }

                    headers.append(Header(name: headerName, value: headerValue))
                }

            try Task.checkCancellation()

            let response = Response(
                statusCode: httpURLResponse.statusCode,
                headers: headers,
                body: data
            )

            return .success(response)
        }
    }
}

// MARK: Handling HTTP.Client.SendResult

private extension HTTP.Client {
    private func sendAndHandleRetry(
        _ request: HTTP.Request,
        interceptors: [HTTP.Interceptor],
        context: HTTP.Context
    ) async throws -> HTTP.Response {
        let result = try await send(
            request,
            interceptors: interceptors,
            context: context
        )

        switch result {
        case .success(let response):
            return response

        case .retry:
            guard context.retryCount < options.maxRetryCount else {
                throw HTTP.MaxRetryCountReached()
            }

            let context = HTTP.Context(
                request: request,
                tags: context.tags,
                retryCount: context.retryCount + 1
            )

            return try await sendAndHandleRetry(
                request,
                interceptors: interceptors,
                context: context
            )

        case .retryAfter(let timeInterval):
            guard context.retryCount < options.maxRetryCount else {
                throw HTTP.MaxRetryCountReached()
            }

            try await Task.sleep(for: .seconds(timeInterval))

            let context = HTTP.Context(
                request: request,
                tags: context.tags,
                retryCount: context.retryCount + 1
            )

            return try await sendAndHandleRetry(
                request,
                interceptors: interceptors,
                context: context
            )
        }
    }
}

// MARK: Sending Requests

public extension HTTP.Client {
    func send(
        _ request: HTTP.Request,
        interceptors: [HTTP.Interceptor] = [],
        tags: [String: String] = [:]
    ) async throws -> HTTP.Response {
        // Apply per-request interceptors last,
        // having per-request interceptors prepare outgoing requests after per-client interceptors.
        // And having per-request interceptors process incoming responses before per-client interceptors.
        let interceptors = self.interceptors + interceptors

        let context = HTTP.Context(
            request: request,
            tags: tags,
            retryCount: 0
        )

        return try await sendAndHandleRetry(
            request,
            interceptors: interceptors,
            context: context
        )
    }
}
