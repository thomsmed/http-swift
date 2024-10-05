import Foundation

public extension HTTP {
    final class Client: Sendable {
        private enum FetchResult {
            case success(Response)
            case retry
            case retryAfter(TimeInterval)
            case failure(HTTP.Failure)
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

        // MARK: Request Body Encoding

        private func encode<RequestBody: Encodable>(
            _ requestBody: RequestBody,
            as requestContentType: MimeType
        ) throws -> Data {
            switch requestContentType {
                case .json:
                    return try encoder.encode(requestBody)
            }
        }

        // MARK: Fetching

        private func fetch(
            _ method: HTTP.Method,
            at url: URL,
            requestData: Data,
            requestContentType: HTTP.MimeType?,
            responseContentType: HTTP.MimeType?,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor],
            context: HTTP.Context
        ) async -> FetchResult {
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue

            if let requestContentType {
                request.setValue(requestContentType.rawValue, forHTTPHeaderField: "Content-Type")
                request.httpBody = requestData
            }

            if let responseContentType {
                request.setValue(responseContentType.rawValue, forHTTPHeaderField: "Accept")
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

            let response = Response(
                decoder: decoder,
                statusCode: httpURLResponse.statusCode,
                body: data
            )

            switch httpURLResponse.statusCode {
                case 200..<300:
                    return .success(response)

                case 300..<400:
                    return .success(response)

                case 400..<500:
                    return .failure(.clientError(response))

                case 500..<600:
                    return .failure(.serverError(response))

                default:
                    return .failure(.unexpectedStatusCode(response))
            }
        }
    }
}

// MARK: Handling HTTP.Client.FetchResult

private extension HTTP.Client {
    private func request(
        _ method: HTTP.Method,
        at url: URL,
        requestData: Data,
        requestContentType: HTTP.MimeType?,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor],
        context: HTTP.Context
    ) async -> Result<HTTP.Response, HTTP.Failure> {
        let result = await fetch(
            method,
            at: url,
            requestData: requestData,
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
                    requestData: requestData,
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
                    requestData: requestData,
                    requestContentType: requestContentType,
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
        requestData: Data,
        requestContentType: HTTP.MimeType?,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor],
        context: HTTP.Context
    ) async -> Result<HTTP.Response, HTTP.Failure> {
        let result = await fetch(
            method,
            at: url,
            requestData: requestData,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: [],
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
                    requestData: requestData,
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
                    requestData: requestData,
                    requestContentType: requestContentType,
                    responseContentType: responseContentType,
                    interceptors: interceptors,
                    context: context
                )
        }
    }

    private func request(
        _ method: HTTP.Method,
        at url: URL,
        requestData: Data,
        requestContentType: HTTP.MimeType?,
        interceptors: [HTTP.Interceptor],
        context: HTTP.Context
    ) async -> Result<Void, HTTP.Failure> {
        let result = await fetch(
            method,
            at: url,
            requestData: requestData,
            requestContentType: requestContentType,
            responseContentType: nil,
            emptyResponseStatusCodes: [],
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
                    requestData: requestData,
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
                    requestData: requestData,
                    requestContentType: requestContentType,
                    interceptors: interceptors,
                    context: context
                )
        }
    }
}

// MARK: Making Requests

public extension HTTP.Client {
    func request<RequestBody: Encodable, ResponseBody>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: @escaping (HTTP.Response) throws -> ResponseBody?
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

        let requestData: Data
        do {
            requestData = try encode(requestBody, as: requestContentType)
        } catch {
            return .failure(.encodingError(error))
        }

        switch await request(
            method,
            at: url,
            requestData: requestData,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: emptyResponseStatusCodes,
            interceptors: interceptors,
            context: context
        ) {
            case .success(let response):
                if emptyResponseStatusCodes.contains(response.statusCode) {
                    return .success(nil)
                }

                do {
                    return .success(try adaptor(response))
                } catch {
                    return .failure(.decodingError(error))
                }

            case .failure(let failure):
                return .failure(failure)
        }
    }

    func request<RequestBody: Encodable, ResponseBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: ((HTTP.Response) throws -> ResponseBody?)? = nil
    ) async -> Result<ResponseBody?, HTTP.Failure> {
        await request(
            method,
            at: url,
            requestBody: requestBody,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: emptyResponseStatusCodes,
            interceptors: interceptors,
            adaptor: adaptor ?? { response in
                try response.decode(as: responseContentType) as ResponseBody
            }
        )
    }

    func request<RequestBody: Encodable, ResponseBody>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: @escaping (HTTP.Response) throws -> ResponseBody
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

        let requestData: Data
        do {
            requestData = try encode(requestBody, as: requestContentType)
        } catch {
            return .failure(.encodingError(error))
        }

        switch await request(
            method,
            at: url,
            requestData: requestData,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            interceptors: interceptors,
            context: context
        ) {
            case .success(let response):
                do {
                    return .success(try adaptor(response))
                } catch {
                    return .failure(.decodingError(error))
                }

            case .failure(let failure):
                return .failure(failure)
        }
    }

    func request<RequestBody: Encodable, ResponseBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: ((HTTP.Response) throws -> ResponseBody)? = nil
    ) async -> Result<ResponseBody, HTTP.Failure> {
        await request(
            method,
            at: url,
            requestBody: requestBody,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            interceptors: interceptors,
            adaptor: adaptor ?? { response in
                try response.decode(as: responseContentType) as ResponseBody
            }
        )
    }

    func request<RequestBody: Encodable>(
        _ method: HTTP.Method,
        at url: URL,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor] = []
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

        let requestData: Data
        do {
            requestData = try encode(requestBody, as: requestContentType)
        } catch {
            return .failure(.encodingError(error))
        }

        return await request(
            method,
            at: url,
            requestData: requestData,
            requestContentType: requestContentType,
            interceptors: interceptors,
            context: context
        )
    }

    func request<ResponseBody>(
        _ method: HTTP.Method,
        at url: URL,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: @escaping (HTTP.Response) throws -> ResponseBody?
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

        switch await request(
            method,
            at: url,
            requestData: Data(),
            requestContentType: nil,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: emptyResponseStatusCodes,
            interceptors: interceptors,
            context: context
        ) {
            case .success(let response):
                if emptyResponseStatusCodes.contains(response.statusCode) {
                    return .success(nil)
                }

                do {
                    return .success(try adaptor(response))
                } catch {
                    return .failure(.decodingError(error))
                }

            case .failure(let failure):
                return .failure(failure)
        }
    }

    func request<ResponseBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: ((HTTP.Response) throws -> ResponseBody?)? = nil
    ) async -> Result<ResponseBody?, HTTP.Failure> {
        await request(
            method,
            at: url,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: emptyResponseStatusCodes,
            interceptors: interceptors,
            adaptor: adaptor ?? { response in
                try response.decode(as: responseContentType) as ResponseBody
            }
        )
    }

    func request<ResponseBody>(
        _ method: HTTP.Method,
        at url: URL,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: @escaping (HTTP.Response) throws -> ResponseBody
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

        switch await request(
            method,
            at: url,
            requestData: Data(),
            requestContentType: nil,
            responseContentType: responseContentType,
            interceptors: interceptors,
            context: context
        ) {
            case .success(let response):
                do {
                    return .success(try adaptor(response))
                } catch {
                    return .failure(.decodingError(error))
                }

            case .failure(let failure):
                return .failure(failure)
        }
    }

    func request<ResponseBody: Decodable>(
        _ method: HTTP.Method,
        at url: URL,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: ((HTTP.Response) throws -> ResponseBody)? = nil
    ) async -> Result<ResponseBody, HTTP.Failure> {
        await request(
            method,
            at: url,
            responseContentType: responseContentType,
            interceptors: interceptors,
            adaptor: adaptor ?? { response in
                try response.decode(as: responseContentType) as ResponseBody
            }
        )
    }

    func request(
        _ method: HTTP.Method,
        at url: URL,
        interceptors: [HTTP.Interceptor] = []
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
            requestData: Data(),
            requestContentType: nil,
            interceptors: interceptors,
            context: context
        )
    }
}

// MARK: Calling Endpoints

public extension HTTP {
    struct Endpoint<RequestBody, ResponseBody> {
        public let method: HTTP.Method
        public let url: URL
        public let requestBody: RequestBody
        public let requestContentType: HTTP.MimeType
        public let responseContentType: HTTP.MimeType
        public let emptyResponseStatusCodes: Set<Int>
        public let interceptors: [HTTP.Interceptor]
        public let adaptor: (HTTP.Response) throws -> ResponseBody

        public init(
            _ method: HTTP.Method,
            at url: URL,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: ((HTTP.Response) throws -> ResponseBody)? = nil
        ) where RequestBody: Encodable, ResponseBody == Optional<Decodable> {
            self.method = method
            self.url = url
            self.requestBody = requestBody
            self.requestContentType = requestContentType
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = emptyResponseStatusCodes
            self.interceptors = interceptors
            self.adaptor = adaptor ?? { _ in Optional<Decodable>(nil) }
        }

        public init(
            _ method: HTTP.Method,
            at url: URL,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: @escaping (HTTP.Response) throws -> ResponseBody
        ) where RequestBody: Encodable {
            self.method = method
            self.url = url
            self.requestBody = requestBody
            self.requestContentType = requestContentType
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = emptyResponseStatusCodes
            self.interceptors = interceptors
            self.adaptor = adaptor
        }

        public init(
            _ method: HTTP.Method,
            at url: URL,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: ((HTTP.Response) throws -> ResponseBody)? = nil
        ) where RequestBody: Encodable, ResponseBody: Decodable {
            self.method = method
            self.url = url
            self.requestBody = requestBody
            self.requestContentType = requestContentType
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = adaptor ?? { response in try response.decode(as: responseContentType) }
        }

        public init(
            _ method: HTTP.Method,
            at url: URL,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: @escaping (HTTP.Response) throws -> ResponseBody
        ) where RequestBody: Encodable {
            self.method = method
            self.url = url
            self.requestBody = requestBody
            self.requestContentType = requestContentType
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = adaptor
        }

        public init(
            _ method: HTTP.Method,
            at url: URL,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = []
        ) where RequestBody: Encodable, ResponseBody == Void {
            self.method = method
            self.url = url
            self.requestBody = requestBody
            self.requestContentType = requestContentType
            self.responseContentType = .json
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = { _ in Void() }
        }

        public init(
            _ method: HTTP.Method,
            at url: URL,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: ((HTTP.Response) throws -> ResponseBody)? = nil
        ) where RequestBody == Void, ResponseBody == Optional<Decodable> {
            self.method = method
            self.url = url
            self.requestBody = ()
            self.requestContentType = .json
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = emptyResponseStatusCodes
            self.interceptors = interceptors
            self.adaptor = adaptor ?? { _ in Optional<Decodable>(nil) }
        }

        public init(
            _ method: HTTP.Method,
            at url: URL,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: @escaping (HTTP.Response) throws -> ResponseBody
        ) where RequestBody == Void {
            self.method = method
            self.url = url
            self.requestBody = ()
            self.requestContentType = .json
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = emptyResponseStatusCodes
            self.interceptors = interceptors
            self.adaptor = adaptor
        }

        public init(
            _ method: HTTP.Method,
            at url: URL,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: ((HTTP.Response) throws -> ResponseBody)? = nil
        ) where RequestBody == Void, ResponseBody: Decodable {
            self.method = method
            self.url = url
            self.requestBody = ()
            self.requestContentType = .json
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = adaptor ?? { response in try response.decode(as: responseContentType) }
        }

        public init(
            _ method: HTTP.Method,
            at url: URL,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: @escaping (HTTP.Response) throws -> ResponseBody
        ) where RequestBody == Void {
            self.method = method
            self.url = url
            self.requestBody = ()
            self.requestContentType = .json
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = adaptor
        }

        public init(
            _ method: HTTP.Method,
            at url: URL,
            interceptors: [HTTP.Interceptor]
        ) where RequestBody == Void, ResponseBody == Void {
            self.method = method
            self.url = url
            self.requestBody = ()
            self.requestContentType = .json
            self.responseContentType = .json
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = { _ in Void() }
        }
    }
}

public extension HTTP.Client {
    func call<RequestBody: Encodable, ResponseBody: Decodable>(
        _ endpoint: HTTP.Endpoint<RequestBody, ResponseBody?>
    ) async -> Result<ResponseBody?, HTTP.Failure> {
        await request(
            endpoint.method,
            at: endpoint.url,
            requestBody: endpoint.requestBody,
            requestContentType: endpoint.requestContentType,
            responseContentType: endpoint.responseContentType,
            emptyResponseStatusCodes: endpoint.emptyResponseStatusCodes,
            interceptors: endpoint.interceptors,
            adaptor: endpoint.adaptor
        )
    }

    func call<RequestBody: Encodable, ResponseBody>(
        _ endpoint: HTTP.Endpoint<RequestBody, ResponseBody?>
    ) async -> Result<ResponseBody?, HTTP.Failure> {
        await request(
            endpoint.method,
            at: endpoint.url,
            requestBody: endpoint.requestBody,
            requestContentType: endpoint.requestContentType,
            responseContentType: endpoint.responseContentType,
            emptyResponseStatusCodes: endpoint.emptyResponseStatusCodes,
            interceptors: endpoint.interceptors,
            adaptor: endpoint.adaptor
        )
    }

    func call<RequestBody: Encodable, ResponseBody: Decodable>(
        _ endpoint: HTTP.Endpoint<RequestBody, ResponseBody>
    ) async -> Result<ResponseBody, HTTP.Failure> {
        await request(
            endpoint.method,
            at: endpoint.url,
            requestBody: endpoint.requestBody,
            requestContentType: endpoint.requestContentType,
            responseContentType: endpoint.responseContentType,
            interceptors: endpoint.interceptors,
            adaptor: endpoint.adaptor
        )
    }

    func call<RequestBody: Encodable, ResponseBody>(
        _ endpoint: HTTP.Endpoint<RequestBody, ResponseBody>
    ) async -> Result<ResponseBody, HTTP.Failure> {
        await request(
            endpoint.method,
            at: endpoint.url,
            requestBody: endpoint.requestBody,
            requestContentType: endpoint.requestContentType,
            responseContentType: endpoint.responseContentType,
            interceptors: endpoint.interceptors,
            adaptor: endpoint.adaptor
        )
    }

    func call<RequestBody: Encodable>(
        _ endpoint: HTTP.Endpoint<RequestBody, Void>
    ) async -> Result<Void, HTTP.Failure> {
        await request(
            endpoint.method,
            at: endpoint.url,
            requestBody: endpoint.requestBody,
            requestContentType: endpoint.requestContentType,
            interceptors: endpoint.interceptors
        )
    }

    func call<ResponseBody: Decodable>(
        _ endpoint: HTTP.Endpoint<Void, ResponseBody?>
    ) async -> Result<ResponseBody?, HTTP.Failure> {
        await request(
            endpoint.method,
            at: endpoint.url,
            responseContentType: endpoint.responseContentType,
            emptyResponseStatusCodes: endpoint.emptyResponseStatusCodes,
            interceptors: endpoint.interceptors,
            adaptor: endpoint.adaptor
        )
    }

    func call<ResponseBody>(
        _ endpoint: HTTP.Endpoint<Void, ResponseBody?>
    ) async -> Result<ResponseBody?, HTTP.Failure> {
        await request(
            endpoint.method,
            at: endpoint.url,
            responseContentType: endpoint.responseContentType,
            emptyResponseStatusCodes: endpoint.emptyResponseStatusCodes,
            interceptors: endpoint.interceptors,
            adaptor: endpoint.adaptor
        )
    }

    func call<ResponseBody: Decodable>(
        _ endpoint: HTTP.Endpoint<Void, ResponseBody>
    ) async -> Result<ResponseBody, HTTP.Failure> {
        await request(
            endpoint.method,
            at: endpoint.url,
            responseContentType: endpoint.responseContentType,
            interceptors: endpoint.interceptors,
            adaptor: endpoint.adaptor
        )
    }

    func call<ResponseBody>(
        _ endpoint: HTTP.Endpoint<Void, ResponseBody>
    ) async -> Result<ResponseBody, HTTP.Failure> {
        await request(
            endpoint.method,
            at: endpoint.url,
            responseContentType: endpoint.responseContentType,
            interceptors: endpoint.interceptors,
            adaptor: endpoint.adaptor
        )
    }

    func call(
        _ endpoint: HTTP.Endpoint<Void, Void>
    ) async -> Result<Void, HTTP.Failure> {
        await request(
            endpoint.method,
            at: endpoint.url,
            interceptors: endpoint.interceptors
        )
    }
}
