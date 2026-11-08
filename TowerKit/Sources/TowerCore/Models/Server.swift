import Foundation

public struct Server: Identifiable, Equatable, Sendable, Codable {
  public let id: UUID
  public var name: String
  public var url: URL
  public var apiKey: String
  /// When `true`, the networking layer accepts self-signed TLS certificates
  /// from this server. Opt-in per server, defaults `false`, and is the one
  /// knob the TLS trust delegate reads — see `SelfSignedTrustDelegate`.
  public var trustsSelfSignedCertificate: Bool

  public init(
    id: UUID = UUID(),
    name: String,
    url: URL,
    apiKey: String,
    trustsSelfSignedCertificate: Bool = false
  ) {
    self.id = id
    self.name = name
    self.url = url
    self.apiKey = apiKey
    self.trustsSelfSignedCertificate = trustsSelfSignedCertificate
  }

  /// The GraphQL endpoint, tolerating a trailing slash on the stored URL.
  public var graphQLEndpoint: URL {
    url.appending(path: "graphql")
  }

  /// A keychain payload written before the trust flag existed has no
  /// `trustsSelfSignedCertificate` key. Decoding would throw `.keyNotFound`
  /// and erase the saved credentials on next launch. Default to `false`
  /// (match the old behavior) so pre-2.2.0 payloads keep decoding cleanly.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.name = try container.decode(String.self, forKey: .name)
    self.url = try container.decode(URL.self, forKey: .url)
    self.apiKey = try container.decode(String.self, forKey: .apiKey)
    self.trustsSelfSignedCertificate = try container.decodeIfPresent(
      Bool.self, forKey: .trustsSelfSignedCertificate
    ) ?? false
  }
}
