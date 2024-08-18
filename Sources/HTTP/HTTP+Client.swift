import Foundation

public extension HTTP {
    final class Client: Sendable {
        private enum FetchResult<ResponseBody, ErrorBody: Error> {
            case success(ResponseBody)
            case failure(ErrorBody)
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

        private let encoder: JSONEncoder
        private let decoder: JSONDecoder

        private let observers: [any HTTP.Observer]
        private let interceptors: [any HTTP.Interceptor]

        private let options: Options

        public init(
            session: any HTTP.Session = URLSession.shared,
            encoder: JSONEncoder = JSONEncoder(),
            decoder: JSONDecoder = JSONDecoder(),
            observers: [any HTTP.Observer] = [],
            interceptors: [any HTTP.Interceptor] = [],
            options: Options = Options()
        ) {
            self.session = session
            self.encoder = encoder
            self.decoder = decoder
            self.observers = observers
            self.interceptors = interceptors
            self.options = options
        }

        // MARK: Encoding and Decoding

        private func encode<RequestBody: Encodable>(
            _ requestBody: RequestBody,
            as requestContentType: MimeType
        ) throws -> Data {
            switch requestContentType {
                case .json:
                    return try encoder.encode(requestBody)
            }
        }

        private func decode<ResponseBody: Decodable>(
            _ responseData: Data,
            as responseContentType: MimeType
        ) throws ->  ResponseBody {
            switch responseContentType {
                case .json:
                    return try decoder.decode(ResponseBody.self, from: responseData)
            }
        }

        // MARK: Fetching

        private func fetch<RequestBody: Encodable, ResponseBody: Decodable, ErrorBody: Decodable>(
            _ method: HTTP.Method,
            at url: URL,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor],
            context: HTTP.Context
        ) async -> FetchResult<ResponseBody, HTTP.Failure<ErrorBody>>  {
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue

            request.setValue(requestContentType.rawValue, forHTTPHeaderField: "Content-Type")
            request.setValue(responseContentType.rawValue, forHTTPHeaderField: "Accept")

            do {
                request.httpBody = try encode(requestBody, as: requestContentType)
            } catch {
                return .failure(.encodingError(error))
            }

            do {
                for interceptor in interceptors {
                    try await interceptor.prepare(&request, with: context)

                    if Task.isCancelled {
                        return .failure(.canceled)
                    }
                }
            } catch {
                return .failure(.preparationError(error))
            }

            for observer in self.observers {
                observer.didPrepare(request)
            }

            var (data, httpURLResponse): (Data, HTTPURLResponse)
            do {
                (data, httpURLResponse) = try await session.data(for: request)
            } catch {
                for observer in self.observers {
                    observer.didEncounter(error)
                }

                // Give the last interceptor the opportunity to handle the error first.
                for interceptor in interceptors.reversed() {
                    switch await interceptor.handle(error, with: context) {
                        case .retry:
                            return .retry
                        case .retryAfter(let timeInterval):
                            return .retryAfter(timeInterval)
                        case .proceed:
                            break
                    }

                    if Task.isCancelled {
                        return .failure(.canceled)
                    }
                }

                return .failure(.transportError(error))
            }

            for observer in self.observers {
                observer.didReceive(httpURLResponse)
            }

            do {
                // Give the last interceptor the opportunity to process the response first.
                for interceptor in interceptors.reversed() {
                    switch try await interceptor.process(&httpURLResponse, data: &data, with: context) {
                        case .retry:
                            return .retry
                        case .retryAfter(let timeInterval):
                            return .retryAfter(timeInterval)
                        case .proceed:
                            break
                    }

                    if Task.isCancelled {
                        return .failure(.canceled)
                    }
                }
            } catch {
                return .failure(.processingError(error))
            }

            switch httpURLResponse.statusCode {
                case 200..<300:
                    do {
                        return .success(try decode(data, as: responseContentType))
                    } catch {
                        return .failure(.decodingError(error))
                    }

                case 300..<400:
                    do {
                        return .success(try decode(data, as: responseContentType))
                    } catch {
                        return .failure(.decodingError(error))
                    }

                case 400..<500:
                    do {
                        return .failure(.clientError(try decoder.decode(ErrorBody.self, from: data)))
                    } catch {
                        return .failure(.decodingError(error))
                    }

                case 500..<600:
                    do {
                        return .failure(.serverError(try decoder.decode(ErrorBody.self, from: data)))
                    } catch {
                        return .failure(.decodingError(error))
                    }

                default:
                    return .failure(.unexpectedStatusCode(httpURLResponse.statusCode))
            }
        }

        private func fetch<RequestBody: Encodable, ErrorBody: Decodable>(
            _ method: HTTP.Method,
            at url: URL,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor],
            context: HTTP.Context
        ) async -> FetchResult<Void, HTTP.Failure<ErrorBody>> {
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue

            request.setValue(requestContentType.rawValue, forHTTPHeaderField: "Content-Type")

            do {
                request.httpBody = try encode(requestBody, as: requestContentType)
            } catch {
                return .failure(.encodingError(error))
            }

            do {
                for interceptor in interceptors {
                    try await interceptor.prepare(&request, with: context)

                    if Task.isCancelled {
                        return .failure(.canceled)
                    }
                }
            } catch {
                return .failure(.preparationError(error))
            }

            for observer in self.observers {
                observer.didPrepare(request)
            }

            var (data, httpURLResponse): (Data, HTTPURLResponse)
            do {
                (data, httpURLResponse) = try await session.data(for: request)
            } catch {
                for observer in self.observers {
                    observer.didEncounter(error)
                }

                // Give the last interceptor the opportunity to handle the error first.
                for interceptor in interceptors.reversed() {
                    switch await interceptor.handle(error, with: context) {
                        case .retry:
                            return .retry
                        case .retryAfter(let timeInterval):
                            return .retryAfter(timeInterval)
                        case .proceed:
                            break
                    }

                    if Task.isCancelled {
                        return .failure(.canceled)
                    }
                }

                return .failure(.transportError(error))
            }

            for observer in self.observers {
                observer.didReceive(httpURLResponse)
            }

            do {
                // Give the last interceptor the opportunity to process the response first.
                for interceptor in interceptors.reversed() {
                    switch try await interceptor.process(&httpURLResponse, data: &data, with: context) {
                        case .retry:
                            return .retry
                        case .retryAfter(let timeInterval):
                            return .retryAfter(timeInterval)
                        case .proceed:
                            break
                    }

                    if Task.isCancelled {
                        return .failure(.canceled)
                    }
                }
            } catch {
                return .failure(.processingError(error))
            }

            switch httpURLResponse.statusCode {
                case 200..<300:
                    return .success(())

                case 300..<400:
                    return .success(())

                case 400..<500:
                    do {
                        return .failure(.clientError(try decoder.decode(ErrorBody.self, from: data)))
                    } catch {
                        return .failure(.decodingError(error))
                    }

                case 500..<600:
                    do {
                        return .failure(.serverError(try decoder.decode(ErrorBody.self, from: data)))
                    } catch {
                        return .failure(.decodingError(error))
                    }

                default:
                    return .failure(.unexpectedStatusCode(httpURLResponse.statusCode))
            }
        }

        private func fetch<ResponseBody: Decodable, ErrorBody: Decodable>(
            _ method: HTTP.Method,
            at url: URL,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor],
            context: HTTP.Context
        ) async -> FetchResult<ResponseBody, HTTP.Failure<ErrorBody>> {
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue

            request.setValue(responseContentType.rawValue, forHTTPHeaderField: "Accept")

            do {
                for interceptor in interceptors {
                    try await interceptor.prepare(&request, with: context)

                    if Task.isCancelled {
                        return .failure(.canceled)
                    }
                }
            } catch {
                return .failure(.preparationError(error))
            }

            for observer in self.observers {
                observer.didPrepare(request)
            }

            var (data, httpURLResponse): (Data, HTTPURLResponse)
            do {
                (data, httpURLResponse) = try await session.data(for: request)
            } catch {
                for observer in self.observers {
                    observer.didEncounter(error)
                }

                // Give the last interceptor the opportunity to handle the error first.
                for interceptor in interceptors.reversed() {
                    switch await interceptor.handle(error, with: context) {
                        case .retry:
                            return .retry
                        case .retryAfter(let timeInterval):
                            return .retryAfter(timeInterval)
                        case .proceed:
                            break
                    }

                    if Task.isCancelled {
                        return .failure(.canceled)
                    }
                }

                return .failure(.transportError(error))
            }

            for observer in self.observers {
                observer.didReceive(httpURLResponse)
            }

            do {
                // Give the last interceptor the opportunity to process the response first.
                for interceptor in interceptors.reversed() {
                    switch try await interceptor.process(&httpURLResponse, data: &data, with: context) {
                        case .retry:
                            return .retry
                        case .retryAfter(let timeInterval):
                            return .retryAfter(timeInterval)
                        case .proceed:
                            break
                    }

                    if Task.isCancelled {
                        return .failure(.canceled)
                    }
                }
            } catch {
                return .failure(.processingError(error))
            }

            switch httpURLResponse.statusCode {
                case 200..<300:
                    do {
                        return .success(try decode(data, as: responseContentType))
                    } catch {
                        return .failure(.decodingError(error))
                    }

                case 300..<400:
                    do {
                        return .success(try decode(data, as: responseContentType))
                    } catch {
                        return .failure(.decodingError(error))
                    }

                case 400..<500:
                    do {
                        return .failure(.clientError(try decoder.decode(ErrorBody.self, from: data)))
                    } catch {
                        return .failure(.decodingError(error))
                    }

                case 500..<600:
                    do {
                        return .failure(.serverError(try decoder.decode(ErrorBody.self, from: data)))
                    } catch {
                        return .failure(.decodingError(error))
                    }

                default:
                    return .failure(.unexpectedStatusCode(httpURLResponse.statusCode))
            }
        }

        private func fetch<ErrorBody: Decodable>(
            _ method: HTTP.Method,
            at url: URL,
            interceptors: [HTTP.Interceptor],
            context: HTTP.Context
        ) async -> FetchResult<Void, HTTP.Failure<ErrorBody>> {
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue

            do {
                for interceptor in interceptors {
                    try await interceptor.prepare(&request, with: context)

                    if Task.isCancelled {
                        return .failure(.canceled)
                    }
                }
            } catch {
                return .failure(.preparationError(error))
            }

            for observer in self.observers {
                observer.didPrepare(request)
            }

            var (data, httpURLResponse): (Data, HTTPURLResponse)
            do {
                (data, httpURLResponse) = try await session.data(for: request)
            } catch {
                for observer in self.observers {
                    observer.didEncounter(error)
                }

                // Give the last interceptor the opportunity to handle the error first.
                for interceptor in interceptors.reversed() {
                    switch await interceptor.handle(error, with: context) {
                        case .retry:
                            return .retry
                        case .retryAfter(let timeInterval):
                            return .retryAfter(timeInterval)
                        case .proceed:
                            break
                    }

                    if Task.isCancelled {
                        return .failure(.canceled)
                    }
                }

                return .failure(.transportError(error))
            }

            for observer in self.observers {
                observer.didReceive(httpURLResponse)
            }

            do {
                // Give the last interceptor the opportunity to process the response first.
                for interceptor in interceptors.reversed() {
                    switch try await interceptor.process(&httpURLResponse, data: &data, with: context) {
                        case .retry:
                            return .retry
                        case .retryAfter(let timeInterval):
                            return .retryAfter(timeInterval)
                        case .proceed:
                            break
                    }

                    if Task.isCancelled {
                        return .failure(.canceled)
                    }
                }
            } catch {
                return .failure(.processingError(error))
            }

            switch httpURLResponse.statusCode {
                case 200..<300:
                    return .success(())

                case 300..<400:
                    return .success(())

                case 400..<500:
                    do {
                        return .failure(.clientError(try decoder.decode(ErrorBody.self, from: data)))
                    } catch {
                        return .failure(.decodingError(error))
                    }

                case 500..<600:
                    do {
                        return .failure(.serverError(try decoder.decode(ErrorBody.self, from: data)))
                    } catch {
                        return .failure(.decodingError(error))
                    }

                default:
                    return .failure(.unexpectedStatusCode(httpURLResponse.statusCode))
            }
        }
    }
}

// MARK: Handling HTTP.Client.FetchResult

private extension HTTP.Client {
    private func request<RequestBody: Encodable, ResponseBody: Decodable, ErrorBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor],
        context: HTTP.Context
    ) async -> Result<ResponseBody, HTTP.Failure<ErrorBody>> {
        let result: FetchResult<ResponseBody, HTTP.Failure<ErrorBody>> = await fetch(
            method,
            at: url,
            requestBody: requestBody,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            interceptors: interceptors,
            context: context
        )

        switch result {
            case .success(let response):
                return .success(response)

            case .failure(let error):
                return .failure(error)

            case .retry:
                guard context.retryCount < options.maxRetryCount else {
                    return .failure(.maxRetryCountReached)
                }
                if Task.isCancelled {
                    return .failure(.canceled)
                }
                let context = HTTP.Context(
                    encoder: context.encoder,
                    decoder: context.decoder,
                    retryCount: context.retryCount + 1
                )
                return await request(
                    method,
                    at: url,
                    requestBody: requestBody,
                    requestContentType: requestContentType,
                    responseContentType: responseContentType,
                    interceptors: interceptors,
                    context: context
                )

            case .retryAfter(let timeInterval):
                guard context.retryCount < options.maxRetryCount else {
                    return .failure(.maxRetryCountReached)
                }
                do {
                    try await Task.sleep(for: .seconds(timeInterval))
                } catch {
                    // Task canceled.
                }
                if Task.isCancelled {
                    return .failure(.canceled)
                }
                let context = HTTP.Context(
                    encoder: context.encoder,
                    decoder: context.decoder,
                    retryCount: context.retryCount + 1
                )
                return await request(
                    method,
                    at: url,
                    requestBody: requestBody,
                    requestContentType: requestContentType,
                    responseContentType: responseContentType,
                    interceptors: interceptors,
                    context: context
                )
        }
    }

    private func request<RequestBody: Encodable, ErrorBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor],
        context: HTTP.Context
    ) async -> Result<Void, HTTP.Failure<ErrorBody>> {
        let result: FetchResult<Void, HTTP.Failure<ErrorBody>> = await fetch(
            method,
            at: url,
            requestBody: requestBody,
            requestContentType: requestContentType,
            interceptors: interceptors,
            context: context
        )

        switch result {
            case .success:
                return .success(())

            case .failure(let error):
                return .failure(error)

            case .retry:
                guard context.retryCount < options.maxRetryCount else {
                    return .failure(.maxRetryCountReached)
                }
                if Task.isCancelled {
                    return .failure(.canceled)
                }
                let context = HTTP.Context(
                    encoder: context.encoder,
                    decoder: context.decoder,
                    retryCount: context.retryCount + 1
                )
                return await request(
                    method,
                    at: url,
                    requestBody: requestBody,
                    requestContentType: requestContentType,
                    interceptors: interceptors,
                    context: context
                )

            case .retryAfter(let timeInterval):
                guard context.retryCount < options.maxRetryCount else {
                    return .failure(.maxRetryCountReached)
                }
                do {
                    try await Task.sleep(for: .seconds(timeInterval))
                } catch {
                    // Task canceled.
                }
                if Task.isCancelled {
                    return .failure(.canceled)
                }
                let context = HTTP.Context(
                    encoder: context.encoder,
                    decoder: context.decoder,
                    retryCount: context.retryCount + 1
                )
                return await request(
                    method,
                    at: url,
                    requestBody: requestBody,
                    requestContentType: requestContentType,
                    interceptors: interceptors,
                    context: context
                )
        }
    }

    private func request<ResponseBody: Decodable, ErrorBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor],
        context: HTTP.Context
    ) async -> Result<ResponseBody, HTTP.Failure<ErrorBody>> {
        let result: FetchResult<ResponseBody, HTTP.Failure<ErrorBody>> = await fetch(
            method,
            at: url,
            responseContentType: responseContentType,
            interceptors: interceptors,
            context: context
        )

        switch result {
            case .success(let response):
                return .success(response)

            case .failure(let error):
                return .failure(error)

            case .retry:
                guard context.retryCount < options.maxRetryCount else {
                    return .failure(.maxRetryCountReached)
                }
                if Task.isCancelled {
                    return .failure(.canceled)
                }
                let context = HTTP.Context(
                    encoder: context.encoder,
                    decoder: context.decoder,
                    retryCount: context.retryCount + 1
                )
                return await request(
                    method,
                    at: url,
                    responseContentType: responseContentType,
                    interceptors: interceptors,
                    context: context
                )

            case .retryAfter(let timeInterval):
                guard context.retryCount < options.maxRetryCount else {
                    return .failure(.maxRetryCountReached)
                }
                do {
                    try await Task.sleep(for: .seconds(timeInterval))
                } catch {
                    // Task canceled.
                }
                if Task.isCancelled {
                    return .failure(.canceled)
                }
                let context = HTTP.Context(
                    encoder: context.encoder,
                    decoder: context.decoder,
                    retryCount: context.retryCount + 1
                )
                return await request(
                    method,
                    at: url,
                    responseContentType: responseContentType,
                    interceptors: interceptors,
                    context: context
                )
        }
    }

    private func request<ErrorBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        interceptors: [HTTP.Interceptor],
        context: HTTP.Context
    ) async -> Result<Void, HTTP.Failure<ErrorBody>> {
        let result: FetchResult<Void, HTTP.Failure<ErrorBody>> = await fetch(
            method,
            at: url,
            interceptors: interceptors,
            context: context
        )

        switch result {
            case .success:
                return .success(())

            case .failure(let error):
                return .failure(error)

            case .retry:
                guard context.retryCount < options.maxRetryCount else {
                    return .failure(.maxRetryCountReached)
                }
                if Task.isCancelled {
                    return .failure(.canceled)
                }
                let context = HTTP.Context(
                    encoder: context.encoder,
                    decoder: context.decoder,
                    retryCount: context.retryCount + 1
                )
                return await request(
                    method,
                    at: url,
                    interceptors: interceptors,
                    context: context
                )

            case .retryAfter(let timeInterval):
                guard context.retryCount < options.maxRetryCount else {
                    return .failure(.maxRetryCountReached)
                }
                do {
                    try await Task.sleep(for: .seconds(timeInterval))
                } catch {
                    // Task canceled.
                }
                if Task.isCancelled {
                    return .failure(.canceled)
                }
                let context = HTTP.Context(
                    encoder: context.encoder,
                    decoder: context.decoder,
                    retryCount: context.retryCount + 1
                )
                return await request(
                    method,
                    at: url,
                    interceptors: interceptors,
                    context: context
                )
        }
    }
}

// MARK: Public Methods

public extension HTTP.Client {
    func request<RequestBody: Encodable, ResponseBody: Decodable, ErrorBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor]
    ) async -> Result<ResponseBody, HTTP.Failure<ErrorBody>> {
        // Apply per-request interceptors last,
        // having per-request interceptors prepare outgoing requests after per-client interceptors.
        // And having per-request interceptors process incoming responses before per-client interceptors.
        let interceptors = self.interceptors + interceptors

        let context = HTTP.Context(
            encoder: encoder,
            decoder: decoder,
            retryCount: 0
        )

        return await request(
            method,
            at: url,
            requestBody: requestBody,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            interceptors: interceptors,
            context: context
        )
    }

    func request<RequestBody: Encodable, ErrorBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor]
    ) async -> Result<Void, HTTP.Failure<ErrorBody>> {
        // Apply per-request interceptors last,
        // having per-request interceptors prepare outgoing requests after per-client interceptors.
        // And having per-request interceptors process incoming responses before per-client interceptors.
        let interceptors = self.interceptors + interceptors

        let context = HTTP.Context(
            encoder: encoder,
            decoder: decoder,
            retryCount: 0
        )

        return await request(
            method,
            at: url,
            requestBody: requestBody,
            requestContentType: requestContentType,
            interceptors: interceptors,
            context: context
        )
    }

    func request<ResponseBody: Decodable, ErrorBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor]
    ) async -> Result<ResponseBody, HTTP.Failure<ErrorBody>> {
        // Apply per-request interceptors last,
        // having per-request interceptors prepare outgoing requests after per-client interceptors.
        // And having per-request interceptors process incoming responses before per-client interceptors.
        let interceptors = self.interceptors + interceptors

        let context = HTTP.Context(
            encoder: encoder,
            decoder: decoder,
            retryCount: 0
        )

        return await request(
            method,
            at: url,
            responseContentType: responseContentType,
            interceptors: interceptors,
            context: context
        )
    }

    func request<ErrorBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        interceptors: [HTTP.Interceptor]
    ) async -> Result<Void, HTTP.Failure<ErrorBody>> {
        // Apply per-request interceptors last,
        // having per-request interceptors prepare outgoing requests after per-client interceptors.
        // And having per-request interceptors process incoming responses before per-client interceptors.
        let interceptors = self.interceptors + interceptors

        let context = HTTP.Context(
            encoder: encoder,
            decoder: decoder,
            retryCount: 0
        )

        return await request(
            method,
            at: url,
            interceptors: interceptors,
            context: context
        )
    }
}
