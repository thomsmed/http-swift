import Foundation

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
