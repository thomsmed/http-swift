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

        private func fetch<RequestBody: Encodable, ResponseBody: Decodable>(
            _ method: HTTP.Method,
            at url: URL,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor],
            context: HTTP.Context
        ) async -> FetchResult<ResponseBody?, HTTP.Failure>  {
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
                observer.didPrepare(request, with: context)
            }

            var (data, httpURLResponse): (Data, HTTPURLResponse)
            do {
                (data, httpURLResponse) = try await session.data(for: request)
            } catch {
                for observer in self.observers {
                    observer.didEncounter(error, with: context)
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
                observer.didReceive(httpURLResponse, with: context)
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

            if emptyResponseStatusCodes.contains(httpURLResponse.statusCode) {
                return .success(nil)
            }

            switch httpURLResponse.statusCode {
                case 200..<300:
                    do {
                        // Decode data as non-optional ResponseBody
                        let response: ResponseBody = try decode(data, as: responseContentType)
                        return .success(response)
                    } catch {
                        return .failure(.decodingError(error))
                    }

                case 300..<400:
                    do {
                        // Decode data as non-optional ResponseBody
                        let response: ResponseBody = try decode(data, as: responseContentType)
                        return .success(response)
                    } catch {
                        return .failure(.decodingError(error))
                    }

                case 400..<500:
                    let failureResponse = Failure.Response(
                        decoder: decoder,
                        statusCode: httpURLResponse.statusCode,
                        body: data
                    )
                    return .failure(.clientError(failureResponse))

                case 500..<600:
                    let failureResponse = Failure.Response(
                        decoder: decoder,
                        statusCode: httpURLResponse.statusCode,
                        body: data
                    )
                    return .failure(.serverError(failureResponse))

                default:
                    let failureResponse = Failure.Response(
                        decoder: decoder,
                        statusCode: httpURLResponse.statusCode,
                        body: data
                    )
                    return .failure(.unexpectedStatusCode(failureResponse))
            }
        }

        private func fetch<RequestBody: Encodable>(
            _ method: HTTP.Method,
            at url: URL,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor],
            context: HTTP.Context
        ) async -> FetchResult<Void, HTTP.Failure> {
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
                observer.didPrepare(request, with: context)
            }

            var (data, httpURLResponse): (Data, HTTPURLResponse)
            do {
                (data, httpURLResponse) = try await session.data(for: request)
            } catch {
                for observer in self.observers {
                    observer.didEncounter(error, with: context)
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
                observer.didReceive(httpURLResponse, with: context)
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
                    let failureResponse = Failure.Response(
                        decoder: decoder,
                        statusCode: httpURLResponse.statusCode,
                        body: data
                    )
                    return .failure(.clientError(failureResponse))

                case 500..<600:
                    let failureResponse = Failure.Response(
                        decoder: decoder,
                        statusCode: httpURLResponse.statusCode,
                        body: data
                    )
                    return .failure(.serverError(failureResponse))

                default:
                    let failureResponse = Failure.Response(
                        decoder: decoder,
                        statusCode: httpURLResponse.statusCode,
                        body: data
                    )
                    return .failure(.unexpectedStatusCode(failureResponse))
            }
        }

        private func fetch<ResponseBody: Decodable>(
            _ method: HTTP.Method,
            at url: URL,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor],
            context: HTTP.Context
        ) async -> FetchResult<ResponseBody?, HTTP.Failure> {
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
                observer.didPrepare(request, with: context)
            }

            var (data, httpURLResponse): (Data, HTTPURLResponse)
            do {
                (data, httpURLResponse) = try await session.data(for: request)
            } catch {
                for observer in self.observers {
                    observer.didEncounter(error, with: context)
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
                observer.didReceive(httpURLResponse, with: context)
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

            if emptyResponseStatusCodes.contains(httpURLResponse.statusCode) {
                return .success(nil)
            }

            switch httpURLResponse.statusCode {
                case 200..<300:
                    do {
                        // Decode data as non-optional ResponseBody
                        let response: ResponseBody = try decode(data, as: responseContentType)
                        return .success(response)
                    } catch {
                        return .failure(.decodingError(error))
                    }

                case 300..<400:
                    do {
                        // Decode data as non-optional ResponseBody
                        let response: ResponseBody = try decode(data, as: responseContentType)
                        return .success(response)
                    } catch {
                        return .failure(.decodingError(error))
                    }

                case 400..<500:
                    let failureResponse = Failure.Response(
                        decoder: decoder,
                        statusCode: httpURLResponse.statusCode,
                        body: data
                    )
                    return .failure(.clientError(failureResponse))

                case 500..<600:
                    let failureResponse = Failure.Response(
                        decoder: decoder,
                        statusCode: httpURLResponse.statusCode,
                        body: data
                    )
                    return .failure(.serverError(failureResponse))

                default:
                    let failureResponse = Failure.Response(
                        decoder: decoder,
                        statusCode: httpURLResponse.statusCode,
                        body: data
                    )
                    return .failure(.unexpectedStatusCode(failureResponse))
            }
        }

        private func fetch(
            _ method: HTTP.Method,
            at url: URL,
            interceptors: [HTTP.Interceptor],
            context: HTTP.Context
        ) async -> FetchResult<Void, HTTP.Failure> {
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
                observer.didPrepare(request, with: context)
            }

            var (data, httpURLResponse): (Data, HTTPURLResponse)
            do {
                (data, httpURLResponse) = try await session.data(for: request)
            } catch {
                for observer in self.observers {
                    observer.didEncounter(error, with: context)
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
                observer.didReceive(httpURLResponse, with: context)
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
                    let failureResponse = Failure.Response(
                        decoder: decoder,
                        statusCode: httpURLResponse.statusCode,
                        body: data
                    )
                    return .failure(.clientError(failureResponse))

                case 500..<600:
                    let failureResponse = Failure.Response(
                        decoder: decoder,
                        statusCode: httpURLResponse.statusCode,
                        body: data
                    )
                    return .failure(.serverError(failureResponse))

                default:
                    let failureResponse = Failure.Response(
                        decoder: decoder,
                        statusCode: httpURLResponse.statusCode,
                        body: data
                    )
                    return .failure(.unexpectedStatusCode(failureResponse))
            }
        }
    }
}

// MARK: Handling HTTP.Client.FetchResult

private extension HTTP.Client {
    private func request<RequestBody: Encodable, ResponseBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor],
        context: HTTP.Context
    ) async -> Result<ResponseBody?, HTTP.Failure> {
        let result: FetchResult<ResponseBody?, HTTP.Failure> = await fetch(
            method,
            at: url,
            requestBody: requestBody,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: emptyResponseStatusCodes,
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
                    emptyResponseStatusCodes: emptyResponseStatusCodes,
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
                    emptyResponseStatusCodes: emptyResponseStatusCodes,
                    interceptors: interceptors,
                    context: context
                )
        }
    }

    private func request<RequestBody: Encodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor],
        context: HTTP.Context
    ) async -> Result<Void, HTTP.Failure> {
        let result: FetchResult<Void, HTTP.Failure> = await fetch(
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

    private func request<ResponseBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor],
        context: HTTP.Context
    ) async -> Result<ResponseBody?, HTTP.Failure> {
        let result: FetchResult<ResponseBody?, HTTP.Failure> = await fetch(
            method,
            at: url,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: emptyResponseStatusCodes,
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
                    emptyResponseStatusCodes: emptyResponseStatusCodes,
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
                    emptyResponseStatusCodes: emptyResponseStatusCodes,
                    interceptors: interceptors,
                    context: context
                )
        }
    }

    private func request(
        _ method: HTTP.Method,
        at url: URL,
        interceptors: [HTTP.Interceptor],
        context: HTTP.Context
    ) async -> Result<Void, HTTP.Failure> {
        let result: FetchResult<Void, HTTP.Failure> = await fetch(
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
    func request<RequestBody: Encodable, ResponseBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor]
    ) async -> Result<ResponseBody?, HTTP.Failure> {
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
            emptyResponseStatusCodes: emptyResponseStatusCodes,
            interceptors: interceptors,
            context: context
        )
    }

    func request<RequestBody: Encodable, ResponseBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor]
    ) async -> Result<ResponseBody, HTTP.Failure> {
        // Apply per-request interceptors last,
        // having per-request interceptors prepare outgoing requests after per-client interceptors.
        // And having per-request interceptors process incoming responses before per-client interceptors.
        let interceptors = self.interceptors + interceptors

        let context = HTTP.Context(
            encoder: encoder,
            decoder: decoder,
            retryCount: 0
        )

        let result: Result<ResponseBody?, HTTP.Failure> = await request(
            method,
            at: url,
            requestBody: requestBody,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: [],
            interceptors: interceptors,
            context: context
        )

        switch result {
            case .success(let response):
                guard let response else {
                    fatalError("Expected response to be non-optional when emptyResponseStatusCodes is empty")
                }
                return .success(response)

            case .failure(let error):
                return .failure(error)
        }
    }

    func request<RequestBody: Encodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor]
    ) async -> Result<Void, HTTP.Failure> {
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

    func request<ResponseBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor]
    ) async -> Result<ResponseBody?, HTTP.Failure> {
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
            emptyResponseStatusCodes: emptyResponseStatusCodes,
            interceptors: interceptors,
            context: context
        )
    }

    func request<ResponseBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor]
    ) async -> Result<ResponseBody, HTTP.Failure> {
        // Apply per-request interceptors last,
        // having per-request interceptors prepare outgoing requests after per-client interceptors.
        // And having per-request interceptors process incoming responses before per-client interceptors.
        let interceptors = self.interceptors + interceptors

        let context = HTTP.Context(
            encoder: encoder,
            decoder: decoder,
            retryCount: 0
        )

        let result: Result<ResponseBody?, HTTP.Failure> = await request(
            method,
            at: url,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: [],
            interceptors: interceptors,
            context: context
        )

        switch result {
            case .success(let response):
                guard let response else {
                    fatalError("Expected response to be non-optional when emptyResponseStatusCodes is empty")
                }
                return .success(response)

            case .failure(let error):
                return .failure(error)
        }
    }

    func request(
        _ method: HTTP.Method,
        at url: URL,
        interceptors: [HTTP.Interceptor]
    ) async -> Result<Void, HTTP.Failure> {
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
