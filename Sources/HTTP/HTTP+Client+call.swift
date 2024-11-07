import Foundation

public extension HTTP.Client {
    func call<Resource>(
        _ endpoint: HTTP.Endpoint<Resource?>
    ) async -> Result<Resource?, HTTP.Failure> {
        if let requestContentType = endpoint.request.contentType {
            return await fetch(
                Resource.self,
                url: endpoint.request.url,
                method: endpoint.request.method,
                requestPayload: endpoint.request.payload,
                requestContentType: requestContentType,
                responseContentType: endpoint.request.accept ?? .json,
                emptyResponseStatusCodes: endpoint.emptyResponseStatusCodes,
                interceptors: endpoint.interceptors,
                adaptor: endpoint.adaptor
            )
        } else {
            return await fetch(
                Resource.self,
                url: endpoint.request.url,
                method: endpoint.request.method,
                responseContentType: endpoint.request.accept ?? .json,
                emptyResponseStatusCodes: endpoint.emptyResponseStatusCodes,
                interceptors: endpoint.interceptors,
                adaptor: endpoint.adaptor
            )
        }
    }

    func call<Resource>(
        _ endpoint: HTTP.Endpoint<Resource>
    ) async -> Result<Resource, HTTP.Failure> {
        if let requestContentType = endpoint.request.contentType {
            return await fetch(
                Resource.self,
                url: endpoint.request.url,
                method: endpoint.request.method,
                requestPayload: endpoint.request.payload,
                requestContentType: requestContentType,
                responseContentType: endpoint.request.accept ?? .json,
                interceptors: endpoint.interceptors,
                adaptor: endpoint.adaptor
            )
        } else {
            return await fetch(
                Resource.self,
                url: endpoint.request.url,
                method: endpoint.request.method,
                responseContentType: endpoint.request.accept ?? .json,
                interceptors: endpoint.interceptors,
                adaptor: endpoint.adaptor
            )
        }
    }

    func call(
        _ endpoint: HTTP.Endpoint<Void>
    ) async -> Result<Void, HTTP.Failure> {
        if let requestContentType = endpoint.request.contentType {
            return await fetch(
                url: endpoint.request.url,
                method: endpoint.request.method,
                requestPayload: endpoint.request.payload,
                requestContentType: requestContentType,
                interceptors: endpoint.interceptors
            )
        } else {
            return await fetch(
                url: endpoint.request.url,
                method: endpoint.request.method,
                interceptors: endpoint.interceptors
            )
        }
    }
}
