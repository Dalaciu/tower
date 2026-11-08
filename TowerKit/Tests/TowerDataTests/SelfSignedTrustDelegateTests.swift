import Foundation
import Testing
@testable import TowerData
import TowerCore

/// The delegate has one job: never silently accept a server-trust challenge
/// unless the user explicitly opted in for *this* server. The two tests below
/// guard the two negative branches — opt-out and non-server-trust — because
/// those are the ones a regression would quietly weaken.
///
/// The positive branch (opt-in, real self-signed trust) isn't reachable from
/// a synthetic `URLProtectionSpace`: `serverTrust` is nil unless the OS
/// created it, and the delegate correctly falls through when it's nil. That
/// path is covered end-to-end by sideload testing against the real Unraid
/// https address on 2.2.0.

@MainActor
private func server(trustsSelfSigned: Bool) -> Server {
  Server(
    name: "Tower",
    url: URL(string: "https://nas:444")!,
    apiKey: "secret",
    trustsSelfSignedCertificate: trustsSelfSigned
  )
}

@Test func fallsThroughForServerTrustWhenNotOptedIn() async {
  let delegate = SelfSignedTrustDelegate(server: await server(trustsSelfSigned: false))
  let challenge = URLAuthenticationChallenge(
    protectionSpace: URLProtectionSpace(
      host: "nas", port: 444, protocol: "https",
      realm: nil, authenticationMethod: NSURLAuthenticationMethodServerTrust
    ),
    proposedCredential: nil,
    previousFailureCount: 0,
    failureResponse: nil,
    error: nil,
    sender: NoopSender()
  )

  let (disposition, credential) = await withCheckedContinuation { continuation in
    delegate.urlSession(.shared, didReceive: challenge) { disposition, credential in
      continuation.resume(returning: (disposition, credential))
    }
  }

  #expect(disposition == .performDefaultHandling)
  #expect(credential == nil)
}

@Test func fallsThroughForClientAuthEvenWhenOptedIn() async {
  // The flag is server-trust only — a client-cert challenge must never read
  // as "yes", because that would offer whatever credential the OS proposed as
  // if the user had consented to it.
  let delegate = SelfSignedTrustDelegate(server: await server(trustsSelfSigned: true))
  let challenge = URLAuthenticationChallenge(
    protectionSpace: URLProtectionSpace(
      host: "nas", port: 444, protocol: "https",
      realm: nil, authenticationMethod: NSURLAuthenticationMethodClientCertificate
    ),
    proposedCredential: nil,
    previousFailureCount: 0,
    failureResponse: nil,
    error: nil,
    sender: NoopSender()
  )

  let (disposition, credential) = await withCheckedContinuation { continuation in
    delegate.urlSession(.shared, didReceive: challenge) { disposition, credential in
      continuation.resume(returning: (disposition, credential))
    }
  }

  #expect(disposition == .performDefaultHandling)
  #expect(credential == nil)
}

/// Required by `URLAuthenticationChallenge.init` but never reached — the
/// delegate always calls its completion handler and never invokes the sender.
private final class NoopSender: NSObject, URLAuthenticationChallengeSender {
  func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
  func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
  func cancel(_ challenge: URLAuthenticationChallenge) {}
}
