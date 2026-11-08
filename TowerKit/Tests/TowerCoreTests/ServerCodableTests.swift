import Foundation
import Testing
@testable import TowerCore

/// `Server` is written to the keychain as JSON. `trustsSelfSignedCertificate`
/// was added in 2.2.0, so a payload persisted by an older build has no key for
/// it — a naive `try container.decode(Bool.self, …)` throws `.keyNotFound`,
/// which `KeychainServerStore` surfaces as "no saved server" and quietly signs
/// the user out on upgrade. These guard the custom `init(from:)` that defaults
/// the missing field to `false`.

@Test func decodesPre220PayloadWithoutTrustKey() throws {
  let json = """
  {
    "id": "7D4C4F4E-7A5A-45A7-9F5B-6E35E7E7F6E3",
    "name": "Tower",
    "url": "http://192.0.2.10",
    "apiKey": "secret"
  }
  """.data(using: .utf8)!

  let decoded = try JSONDecoder().decode(Server.self, from: json)

  #expect(decoded.name == "Tower")
  #expect(decoded.apiKey == "secret")
  // The migration default — not the user's opt-in, which they must flip
  // themselves on the Connect screen.
  #expect(decoded.trustsSelfSignedCertificate == false)
}

@Test func decodesPayloadWithTrustFlagTrue() throws {
  let json = """
  {
    "id": "7D4C4F4E-7A5A-45A7-9F5B-6E35E7E7F6E3",
    "name": "Tower",
    "url": "https://nas:444",
    "apiKey": "secret",
    "trustsSelfSignedCertificate": true
  }
  """.data(using: .utf8)!

  let decoded = try JSONDecoder().decode(Server.self, from: json)

  #expect(decoded.trustsSelfSignedCertificate == true)
}

@Test func roundTripsThroughJSONEncoder() throws {
  let server = Server(
    name: "Tower",
    url: URL(string: "https://nas:444")!,
    apiKey: "secret",
    trustsSelfSignedCertificate: true
  )
  let data = try JSONEncoder().encode(server)
  let decoded = try JSONDecoder().decode(Server.self, from: data)
  #expect(decoded == server)
}
