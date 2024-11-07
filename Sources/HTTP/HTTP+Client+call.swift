import Foundation

public extension HTTP.Client {
    func call<RequestBody: Encodable, Resource>(
        _ endpoint: HTTP.Endpoint<RequestBody, Resource?>
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
        _ endpoint: HTTP.Endpoint<Void, Resource?>
    ) async -> Result<Resource?, HTTP.Failure> {
        await fetch(
            Resource.self,
            url: endpoint.url,
            method: endpoint.method,
            responseContentType: endpoint.responseContentType ?? .json,
            emptyResponseStatusCodes: endpoint.emptyResponseStatusCodes,
            interceptors: endpoint.interceptors,
            adaptor: endpoint.adaptor
        )
    }

    func call<RequestBody: Encodable, Resource>(
        _ endpoint: HTTP.Endpoint<RequestBody, Resource>
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

    func call<Resource>(
        _ endpoint: HTTP.Endpoint<Void, Resource>
    ) async -> Result<Resource, HTTP.Failure> {
        await fetch(
            Resource.self,
            url: endpoint.url,
            method: endpoint.method,
            responseContentType: endpoint.responseContentType ?? .json,
            interceptors: endpoint.interceptors,
            adaptor: endpoint.adaptor
        )
    }

    func call<RequestBody: Encodable>(
        _ endpoint: HTTP.Endpoint<RequestBody, Void>
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

    func call(
        _ endpoint: HTTP.Endpoint<Void, Void>
    ) async -> Result<Void, HTTP.Failure> {
        await fetch(
            url: endpoint.url,
            method: endpoint.method,
            interceptors: endpoint.interceptors
        )
    }
}
