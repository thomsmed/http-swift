import Foundation

public extension HTTP.Client {
    func call<Resource>(
        _ endpoint: HTTP.Endpoint<Resource>
    ) async throws -> Resource {
        try await fetch(
            Resource.self,
            url: endpoint.url,
            method: endpoint.method,
            payload: endpoint.payload,
            parser: endpoint.parser,
            additionalHeaders: endpoint.additionalHeaders,
            interceptors: endpoint.interceptors,
            tags: endpoint.tags
        )
    }
}
