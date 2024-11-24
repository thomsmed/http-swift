import Foundation

public extension HTTP.Client {
    func fetch<Resource>(
        _: Resource.Type,
        url: URL,
        method: HTTP.Method,
        payload: HTTP.RequestPayload,
        parser: HTTP.ResponseParser<Resource>,
        additionalHeaders: [HTTP.Header] = [],
        interceptors: [HTTP.Interceptor] = [],
        tags: [String: String] = [:]
    ) async throws -> Resource {
        var headers = additionalHeaders

        if let contentType = payload.mimeType {
            headers.append(.contentType(contentType))
        }

        if let accept = parser.mimeType {
            headers.append(.accept(accept))
        }

        let request = HTTP.Request(
            url: url,
            method: method,
            body: payload.body,
            headers: headers
        )

        let response = try await send(
            request,
            interceptors: interceptors,
            tags: tags
        )

        return try response.parsed(using: parser)
    }
}
