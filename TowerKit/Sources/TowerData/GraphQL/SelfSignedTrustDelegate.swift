import Foundation
import TowerCore

/// Accepts a self-signed server certificate when the server was saved with
/// `trustsSelfSignedCertificate = true`. Falls through for every other
/// challenge, so the OS still runs its default trust evaluation against the
/// iOS trust store — any production cert chain keeps working untouched.
///
/// Scoped to one server: each `ApolloClientProvider` hands its own delegate,
/// so the opt-in cannot leak to a different host. The provider's URLSession
/// retains this delegate for its lifetime, which matches the repository that
/// owns it — nothing in the app outlives that today, and the lifetime note at
/// `ApolloClientProvider.sessionDelegate` still names the outstanding
/// `finishTasksAndInvalidate()` work.
///
/// This is a per-server, user-opted-in TLS escape hatch, not a global
/// bypass — the toggle in the Connect screen is the only way to set it, and
/// the default is `false` for every server (including migrated ones), so the
/// system default trust evaluation applies unless the user asked otherwise.
public final class SelfSignedTrustDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
  private let server: Server

  public init(server: Server) {
    self.server = server
  }

  public func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  ) {
    guard
      server.trustsSelfSignedCertificate,
      challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
      let trust = challenge.protectionSpace.serverTrust
    else {
      // `.performDefaultHandling` runs the OS's normal validation. A client
      // cert challenge or any other method falls through here too — we only
      // ever bypass server-trust challenges, never client auth.
      completionHandler(.performDefaultHandling, nil)
      return
    }
    completionHandler(.useCredential, URLCredential(trust: trust))
  }
}
