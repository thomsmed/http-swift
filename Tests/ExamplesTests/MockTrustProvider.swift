import Foundation

import Examples

public final actor MockTrustProvider: TrustProvider {
    public var mockAccessToken = AccessToken(rawValue: "<some.access.token>")
    public var mockDPoP = DPoP(rawValue: "<some.dpop>")

    public var accessToken: AccessToken? {
        get async {
            mockAccessToken
        }
    }

    public func sign(_ request: URLRequest) async throws -> DPoP {
        mockDPoP
    }
}
