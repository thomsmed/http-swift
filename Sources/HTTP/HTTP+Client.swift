import Foundation

public extension HTTP {
    final class Client: Sendable {
        private enum SendResult {
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

        // MARK: Encoding

        private func encode<RequestBody: Encodable>(
            _ requestBody: RequestBody,
            as requestContentType: MimeType
        ) throws -> Data {
            switch requestContentType {
                case .json:
                    return try encoder.encode(requestBody)
            }
        }

        // MARK: Sending

        private func send(
            _ request: HTTP.Request,
            interceptors: [HTTP.Interceptor],
            context: HTTP.Context
        ) async -> SendResult {
            var urlRequest = URLRequest(url: request.url)
            urlRequest.httpMethod = request.method.rawValue

            if let contentType = request.contentType {
                urlRequest.setValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = request.body
            }

            if let accept = request.accept {
                urlRequest.setValue(accept.rawValue, forHTTPHeaderField: "Accept")
            }

            do {
                for interceptor in interceptors {
                    try await interceptor.prepare(&urlRequest, with: context)

                    if Task.isCancelled {
                        return .failure(.canceled)
                    }
                }
            } catch {
                return .failure(.preparationError(error))
            }

            for observer in self.observers {
                observer.didPrepare(urlRequest, with: context)
            }

            var (data, httpURLResponse): (Data, HTTPURLResponse)
            do {
                (data, httpURLResponse) = try await session.data(for: urlRequest)
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

            let headers = httpURLResponse.allHeaderFields.keys
                .reduce(into: [String: String]()) { headers, key in
                    guard let headerField = key as? String else {
                        return
                    }

                    headers[headerField] = httpURLResponse.value(forHTTPHeaderField: headerField)
                }

            let response = Response(
                decoder: decoder,
                statusCode: httpURLResponse.statusCode,
                headers: headers,
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

// MARK: Handling HTTP.Client.SendResult

private extension HTTP.Client {
    private func sendAndHandleRetry(
        _ request: HTTP.Request,
        interceptors: [HTTP.Interceptor],
        context: HTTP.Context
    ) async -> Result<HTTP.Response, HTTP.Failure> {
        let result = await send(
            request,
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
                return await sendAndHandleRetry(
                    request,
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
                return await sendAndHandleRetry(
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
        interceptors: [HTTP.Interceptor]
    ) async -> Result<HTTP.Response, HTTP.Failure> {
        // Apply per-request interceptors last,
        // having per-request interceptors prepare outgoing requests after per-client interceptors.
        // And having per-request interceptors process incoming responses before per-client interceptors.
        let interceptors = self.interceptors + interceptors

        let context = HTTP.Context(
            encoder: encoder,
            decoder: decoder,
            retryCount: 0
        )

        return await sendAndHandleRetry(
            request,
            interceptors: interceptors,
            context: context
        )
    }
}

// MARK: Fetching Responses

public extension HTTP.Client {
    func fetch<ResponseBody>(
        _: ResponseBody.Type,
        url: URL,
        method: HTTP.Method,
        requestData: Data,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor] = [],
        adaptor adapt: @escaping (HTTP.Response) throws -> ResponseBody?
    ) async -> Result<ResponseBody?, HTTP.Failure> {
        let request = HTTP.Request(
            url: url,
            method: method,
            body: requestData,
            contentType: requestContentType,
            accept: responseContentType
        )

        return await send(
            request,
            interceptors: interceptors
        ).flatMap { response in
            if emptyResponseStatusCodes.contains(response.statusCode) {
                return .success(nil)
            }

            do {
                return .success(try adapt(response))
            } catch {
                return .failure(.decodingError(error))
            }
        }
    }

    func fetch<RequestBody: Encodable, ResponseBody>(
        _ responseBodyType: ResponseBody.Type,
        url: URL,
        method: HTTP.Method,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: @escaping (HTTP.Response) throws -> ResponseBody?
    ) async -> Result<ResponseBody?, HTTP.Failure> {
        let requestData: Data
        do {
            requestData = try encode(requestBody, as: requestContentType)
        } catch {
            return .failure(.encodingError(error))
        }

        return await fetch(
            responseBodyType,
            url: url,
            method: method,
            requestData: requestData,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: emptyResponseStatusCodes,
            interceptors: interceptors,
            adaptor: adaptor
        )
    }

    func fetch<RequestBody: Encodable, ResponseBody: Decodable>(
        _ responseBodyType: ResponseBody.Type,
        url: URL,
        method: HTTP.Method,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: ((HTTP.Response) throws -> ResponseBody?)? = nil
    ) async -> Result<ResponseBody?, HTTP.Failure> {
        await fetch(
            responseBodyType,
            url: url,
            method: method,
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

    func fetch<ResponseBody>(
        _: ResponseBody.Type,
        url: URL,
        method: HTTP.Method,
        requestData: Data,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor] = [],
        adaptor adapt: @escaping (HTTP.Response) throws -> ResponseBody
    ) async -> Result<ResponseBody, HTTP.Failure> {
        let request = HTTP.Request(
            url: url,
            method: method,
            body: requestData,
            contentType: requestContentType,
            accept: responseContentType
        )

        return await send(
            request,
            interceptors: interceptors
        ).flatMap { response in
            do {
                return .success(try adapt(response))
            } catch {
                return .failure(.decodingError(error))
            }
        }
    }

    func fetch<RequestBody: Encodable, ResponseBody>(
        _ responseBodyType: ResponseBody.Type,
        url: URL,
        method: HTTP.Method,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: @escaping (HTTP.Response) throws -> ResponseBody
    ) async -> Result<ResponseBody, HTTP.Failure> {
        let requestData: Data
        do {
            requestData = try encode(requestBody, as: requestContentType)
        } catch {
            return .failure(.encodingError(error))
        }

        return await fetch(
            responseBodyType,
            url: url,
            method: method,
            requestData: requestData,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            interceptors: interceptors,
            adaptor: adaptor
        )
    }

    func fetch<RequestBody: Encodable, ResponseBody: Decodable>(
        _ responseBodyType: ResponseBody.Type,
        url: URL,
        method: HTTP.Method,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: ((HTTP.Response) throws -> ResponseBody)? = nil
    ) async -> Result<ResponseBody, HTTP.Failure> {
        await fetch(
            responseBodyType,
            url: url,
            method: method,
            requestBody: requestBody,
            requestContentType: requestContentType,
            responseContentType: responseContentType,
            interceptors: interceptors,
            adaptor: adaptor ?? { response in
                try response.decode(as: responseContentType) as ResponseBody
            }
        )
    }

    func fetch(
        url: URL,
        method: HTTP.Method,
        requestData: Data,
        requestContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor] = []
    ) async -> Result<Void, HTTP.Failure> {
        let request = HTTP.Request(
            url: url,
            method: method,
            body: requestData,
            contentType: requestContentType
        )

        return await send(
            request,
            interceptors: interceptors
        ).map { _ in Void() }
    }

    func fetch<RequestBody: Encodable>(
        url: URL,
        method: HTTP.Method,
        requestBody: RequestBody,
        requestContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor] = []
    ) async -> Result<Void, HTTP.Failure> {
        let requestData: Data
        do {
            requestData = try encode(requestBody, as: requestContentType)
        } catch {
            return .failure(.encodingError(error))
        }

        return await fetch(
            url: url,
            method: method,
            requestData: requestData,
            requestContentType: requestContentType,
            interceptors: interceptors
        )
    }

    func fetch<ResponseBody>(
        _: ResponseBody.Type,
        url: URL,
        method: HTTP.Method,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor] = [],
        adaptor adapt: @escaping (HTTP.Response) throws -> ResponseBody?
    ) async -> Result<ResponseBody?, HTTP.Failure> {
        let request = HTTP.Request(
            url: url,
            method: method,
            accept: responseContentType
        )

        return await send(
            request,
            interceptors: interceptors
        ).flatMap { response in
            if emptyResponseStatusCodes.contains(response.statusCode) {
                return .success(nil)
            }

            do {
                return .success(try adapt(response))
            } catch {
                return .failure(.decodingError(error))
            }
        }
    }

    func fetch<ResponseBody: Decodable>(
        _ responseBodyType: ResponseBody.Type,
        url: URL,
        method: HTTP.Method,
        responseContentType: HTTP.MimeType,
        emptyResponseStatusCodes: Set<Int>,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: ((HTTP.Response) throws -> ResponseBody?)? = nil
    ) async -> Result<ResponseBody?, HTTP.Failure> {
        await fetch(
            responseBodyType,
            url: url,
            method: method,
            responseContentType: responseContentType,
            emptyResponseStatusCodes: emptyResponseStatusCodes,
            interceptors: interceptors,
            adaptor: adaptor ?? { response in
                try response.decode(as: responseContentType) as ResponseBody
            }
        )
    }

    func fetch<ResponseBody>(
        _: ResponseBody.Type,
        url: URL,
        method: HTTP.Method,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor] = [],
        adaptor adapt: @escaping (HTTP.Response) throws -> ResponseBody
    ) async -> Result<ResponseBody, HTTP.Failure> {
        let request = HTTP.Request(
            url: url,
            method: method,
            accept: responseContentType
        )

        return await send(
            request,
            interceptors: interceptors
        ).flatMap { response in
            do {
                return .success(try adapt(response))
            } catch {
                return .failure(.decodingError(error))
            }
        }
    }

    func fetch<ResponseBody: Decodable>(
        _ responseBodyType: ResponseBody.Type,
        url: URL,
        method: HTTP.Method,
        responseContentType: HTTP.MimeType,
        interceptors: [HTTP.Interceptor] = [],
        adaptor: ((HTTP.Response) throws -> ResponseBody)? = nil
    ) async -> Result<ResponseBody, HTTP.Failure> {
        await fetch(
            responseBodyType,
            url: url,
            method: method,
            responseContentType: responseContentType,
            interceptors: interceptors,
            adaptor: adaptor ?? { response in
                try response.decode(as: responseContentType) as ResponseBody
            }
        )
    }

    func fetch(
        url: URL,
        method: HTTP.Method,
        interceptors: [HTTP.Interceptor] = []
    ) async -> Result<Void, HTTP.Failure> {
        let request = HTTP.Request(
            url: url,
            method: method
        )

        return await send(
            request,
            interceptors: interceptors
        ).map { _ in Void() }
    }
}

// MARK: Calling Endpoints

public extension HTTP {
    struct Endpoint<Resource> {
        public let url: URL
        public let method: HTTP.Method
        public let requestBody: (any Encodable)?
        public let requestContentType: HTTP.MimeType?
        public let responseContentType: HTTP.MimeType?
        public let emptyResponseStatusCodes: Set<Int>
        public let interceptors: [HTTP.Interceptor]
        public let adaptor: (HTTP.Response) throws -> Resource

        public init<RequestBody: Encodable>(
            url: URL,
            method: HTTP.Method,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: ((HTTP.Response) throws -> Resource)? = nil
        ) where Resource == Optional<Decodable> {
            self.url = url
            self.method = method
            self.requestBody = requestBody
            self.requestContentType = requestContentType
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = emptyResponseStatusCodes
            self.interceptors = interceptors
            self.adaptor = adaptor ?? { _ in Optional<Decodable>(nil) }
        }

        public init<RequestBody: Encodable>(
            url: URL,
            method: HTTP.Method,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: @escaping (HTTP.Response) throws -> Resource
        ) {
            self.url = url
            self.method = method
            self.requestBody = requestBody
            self.requestContentType = requestContentType
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = emptyResponseStatusCodes
            self.interceptors = interceptors
            self.adaptor = adaptor
        }

        public init<RequestBody: Encodable>(
            url: URL,
            method: HTTP.Method,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: ((HTTP.Response) throws -> Resource)? = nil
        ) where Resource: Decodable {
            self.url = url
            self.method = method
            self.requestBody = requestBody
            self.requestContentType = requestContentType
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = adaptor ?? { response in try response.decode(as: responseContentType) }
        }

        public init<RequestBody: Encodable>(
            url: URL,
            method: HTTP.Method,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: @escaping (HTTP.Response) throws -> Resource
        ) {
            self.url = url
            self.method = method
            self.requestBody = requestBody
            self.requestContentType = requestContentType
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = adaptor
        }

        public init<RequestBody: Encodable>(
            url: URL,
            method: HTTP.Method,
            requestBody: RequestBody,
            requestContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = []
        ) where Resource == Void {
            self.url = url
            self.method = method
            self.requestBody = requestBody
            self.requestContentType = requestContentType
            self.responseContentType = nil
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = { _ in Void() }
        }

        public init(
            url: URL,
            method: HTTP.Method,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: ((HTTP.Response) throws -> Resource)? = nil
        ) where Resource == Optional<Decodable> {
            self.url = url
            self.method = method
            self.requestBody = nil
            self.requestContentType = nil
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = emptyResponseStatusCodes
            self.interceptors = interceptors
            self.adaptor = adaptor ?? { _ in Optional<Decodable>(nil) }
        }

        public init(
            url: URL,
            method: HTTP.Method,
            responseContentType: HTTP.MimeType,
            emptyResponseStatusCodes: Set<Int>,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: @escaping (HTTP.Response) throws -> Resource
        ) {
            self.url = url
            self.method = method
            self.requestBody = nil
            self.requestContentType = nil
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = emptyResponseStatusCodes
            self.interceptors = interceptors
            self.adaptor = adaptor
        }

        public init(
            url: URL,
            method: HTTP.Method,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = [],
            adaptor: ((HTTP.Response) throws -> Resource)? = nil
        ) where Resource: Decodable {
            self.url = url
            self.method = method
            self.requestBody = nil
            self.requestContentType = nil
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = adaptor ?? { response in try response.decode(as: responseContentType) }
        }

        public init(
            url: URL,
            method: HTTP.Method,
            responseContentType: HTTP.MimeType,
            interceptors: [HTTP.Interceptor] = [],
            adapt: @escaping (HTTP.Response) throws -> Resource
        ) {
            self.url = url
            self.method = method
            self.requestBody = nil
            self.requestContentType = nil
            self.responseContentType = responseContentType
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = adapt
        }

        public init(
            url: URL,
            method: HTTP.Method,
            interceptors: [HTTP.Interceptor] = []
        ) where Resource == Void {
            self.url = url
            self.method = method
            self.requestBody = nil
            self.requestContentType = nil
            self.responseContentType = nil
            self.emptyResponseStatusCodes = []
            self.interceptors = interceptors
            self.adaptor = { _ in Void() }
        }
    }
}

public extension HTTP.Client {
    func call<Resource>(
        _ endpoint: HTTP.Endpoint<Resource?>
    ) async -> Result<Resource?, HTTP.Failure> {
        if let requestBody = endpoint.requestBody, let requestContentType = endpoint.requestContentType {
            return await fetch(
                Resource.self,
                url: endpoint.url,
                method: endpoint.method,
                requestBody: requestBody,
                requestContentType: requestContentType,
                responseContentType: endpoint.responseContentType ?? .json,
                emptyResponseStatusCodes: endpoint.emptyResponseStatusCodes,
                interceptors: endpoint.interceptors,
                adaptor: endpoint.adaptor
            )
        } else {
            return await fetch(
                Resource.self,
                url: endpoint.url,
                method: endpoint.method,
                responseContentType: endpoint.responseContentType ?? .json,
                emptyResponseStatusCodes: endpoint.emptyResponseStatusCodes,
                interceptors: endpoint.interceptors,
                adaptor: endpoint.adaptor
            )
        }
    }

    func call<Resource>(
        _ endpoint: HTTP.Endpoint<Resource>
    ) async -> Result<Resource, HTTP.Failure> {
        if let requestBody = endpoint.requestBody, let requestContentType = endpoint.requestContentType {
            return await fetch(
                Resource.self,
                url: endpoint.url,
                method: endpoint.method,
                requestBody: requestBody,
                requestContentType: requestContentType,
                responseContentType: endpoint.responseContentType ?? .json,
                interceptors: endpoint.interceptors,
                adaptor: endpoint.adaptor
            )
        } else {
            return await fetch(
                Resource.self,
                url: endpoint.url,
                method: endpoint.method,
                responseContentType: endpoint.responseContentType ?? .json,
                interceptors: endpoint.interceptors,
                adaptor: endpoint.adaptor
            )
        }
    }

    func call(
        _ endpoint: HTTP.Endpoint<Void>
    ) async -> Result<Void, HTTP.Failure> {
        if let requestBody = endpoint.requestBody, let requestContentType = endpoint.requestContentType {
            return await fetch(
                url: endpoint.url,
                method: endpoint.method,
                requestBody: requestBody,
                requestContentType: requestContentType,
                interceptors: endpoint.interceptors
            )
        } else {
            return await fetch(
                url: endpoint.url,
                method: endpoint.method,
                interceptors: endpoint.interceptors
            )
        }
    }
}
