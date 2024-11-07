import Foundation
import Testing

import HTTP

@Suite struct HTTPClientTests {
    @Test func test_fetch() async throws {
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)

        // Without request payload

        struct Response: Decodable {
            /* ... */
        }

        let _ = await httpClient.fetch(
            Response.self,
            url: URL(string: "https://example.ios")!,
            method: .get,
            responseContentType: .json,
            interceptors: []
        )

        // With unprepared request payload (have HTTP.Client prepare/encode the payload for us)

        struct Request: Encodable {
            /* ... */
        }

        let request = Request()

        let _ = await httpClient.fetch(
            Response.self,
            url: URL(string: "https://example.ios")!,
            method: .post,
            requestPayload: .unprepared(request),
            requestContentType: .json,
            responseContentType: .json,
            interceptors: []
        )

        // With prepared request payload (prepare/encode the payload ourselves)

        let data = try JSONEncoder().encode(request)

        let _ = await httpClient.fetch(
            Response.self,
            url: URL(string: "https://example.ios")!,
            method: .post,
            requestPayload: .prepared(data),
            requestContentType: .json,
            responseContentType: .json,
            interceptors: []
        )

        // Optionally specify response status codes that yield empty responses

        let result = await httpClient.fetch(
            Response.self,
            url: URL(string: "https://example.ios")!,
            method: .get,
            responseContentType: .json,
            emptyResponseStatusCodes: [204],
            interceptors: []
        )

        // Parse error responses

        struct OneTypeOfErrorBody: Decodable {
            let message: String
        }

        struct AnotherTypeOfErrorBody: Decodable {
            let code: Int
        }

        switch result {
        case .success:
            break

        case .failure(.clientError(let errorResponse)):
            if let errorBody: OneTypeOfErrorBody = try? errorResponse.decode(as: .json) {
                print("Error Body:", errorBody)
            } else if let errorBody = try? errorResponse.decode(as: .json) as AnotherTypeOfErrorBody {
                print("Error Body:", errorBody)
            } else {
                let errorMessage = try? JSONDecoder().decode(String.self, from: errorResponse.body)
                print("Error Message:", errorMessage ?? "<unknown>")
            }

        default:
            break
        }
    }

    @Test func test_interceptAndRetry() async throws {
        struct UserAgentInterceptor: HTTP.Interceptor {
            func prepare(_ request: inout URLRequest, with context: HTTP.Context) async throws {
                request.setValue("My User-Agent", forHTTPHeaderField: "User-Agent")
            }

            func handle(_ transportError: any Error, with context: HTTP.Context) async -> HTTP.Evaluation {
                .proceed
            }

            func process(_ response: inout HTTPURLResponse, data: inout Data, with context: HTTP.Context) async throws -> HTTP.Evaluation {
                .proceed
            }
        }

        struct RetryOnTransportErrorInterceptor: HTTP.Interceptor {
            func prepare(_ request: inout URLRequest, with context: HTTP.Context) async throws {
                // No-op
            }

            func handle(_ transportError: any Error, with context: HTTP.Context) async -> HTTP.Evaluation {
                guard context.retryCount < 5 else {
                    return .proceed
                }

                return .retryAfter(TimeInterval(powf(1, Float(context.retryCount))))
            }

            func process(_ response: inout HTTPURLResponse, data: inout Data, with context: HTTP.Context) async throws -> HTTP.Evaluation {
                .proceed
            }
        }

        let session = MockSession()
        let httpClient = HTTP.Client(
            session: session,
            interceptors: [
                UserAgentInterceptor(),
                RetryOnTransportErrorInterceptor()
            ]
        )

        let _ = await httpClient.fetch(
            url: URL(string: "https://example.ios")!,
            method: .get,
            interceptors: []
        )
    }

    @Test func test_observe() async throws {
        struct PrintingObserver: HTTP.Observer {
            func didPrepare(_ request: URLRequest, with context: HTTP.Context) {
                print("Did prepare request:", request)
            }

            func didEncounter(_ transportError: any Error, with context: HTTP.Context) {
                print("Did encounter transport error:", transportError)
            }

            func didReceive(_ response: HTTPURLResponse, with context: HTTP.Context) {
                print("Did receive response:", response)
            }
        }

        let session = MockSession()
        let httpClient = HTTP.Client(
            session: session,
            observers: [
                PrintingObserver()
            ]
        )

        let _ = await httpClient.fetch(
            url: URL(string: "https://example.ios")!,
            method: .get,
            interceptors: []
        )
    }

    @Test func test_encapsulateInEndpoints() async throws {
        let session = MockSession()
        let httpClient = HTTP.Client(session: session)

        // Scope Endpoints to their models/domains

        struct Feature {
            struct Response {
                let text: String
            }

            static func featureEndpoint(text: String) -> HTTP.Endpoint<Response> {
                struct Request: Encodable {
                    let text: String
                }

                let url = URL(string: "https://example.ios/feature/endpoint")!

                let request = Request(text: text)

                return HTTP.Endpoint(
                    url: url,
                    method: .post,
                    requestPayload: .unprepared(request),
                    requestContentType: .json,
                    responseContentType: .json,
                    interceptors: []
                ) { response in
                    struct ActualResponse: Decodable {
                        let number: Int
                    }
                    let actualResponse: ActualResponse = try response.decode(as: .json)
                    return Response(text: String(actualResponse.number))
                }
            }
        }

        // Call endpoints on their models/domains

        let _ = await httpClient.call(Feature.featureEndpoint(text: "Hello World"))
    }
}
