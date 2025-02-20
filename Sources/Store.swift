import Foundation
import Logging

struct ServerConfigModel: Codable, Sendable {
  var awake: Bool?
  var ignoredChannels: [String]?
  var foodWords: [String]?

  init() {}
  init(from: ServerConfig) {
    self.awake = from.awake
    self.ignoredChannels = Array(from.ignoredChannels)
    self.foodWords = from.foodWords
  }
}

struct ServerConfig: Sendable {
  var awake: Bool
  var ignoredChannels: Set<String>
  var foodWords: [String]

  init() {
    self.init(from: ServerConfigModel())
  }

  init(from: ServerConfigModel) {
    self.awake = from.awake ?? true
    self.ignoredChannels = Set(from.ignoredChannels ?? [])
    self.foodWords = from.foodWords ?? defaultFoodWords
  }
}

actor Store {
  private let logger = Logger(label: "Store")
  private let path: URL
  private var data: [String: ServerConfig] = [:]

  init(path: URL) {
    self.path = path
  }

  func load() throws {
    self.logger.info("Loading config from \(self.path.path())")
    if let contents = try? String(contentsOfFile: self.path.path()) {
      let decoder = JSONDecoder()
      let store = try decoder.decode([String: ServerConfigModel].self, from: Data(contents.utf8))
      self.data = store.mapValues { v in ServerConfig(from: v) }
    }
  }

  func get(_ server: String) throws -> ServerConfig {
    if let config = self.data[server] { return config }
    let config = ServerConfig()
    try self.set(server, config: config)
    return config
  }

  func set(_ server: String, config: ServerConfig) throws {
    self.data[server] = config

    let store = self.data.mapValues { v in ServerConfigModel(from: v) }
    let encoder = JSONEncoder()
    try encoder.encode(store).write(to: self.path)
  }
}

struct StoreError {
  let message: String

  init(_ message: String) {
    self.message = message
  }
}

extension StoreError: LocalizedError {
  var errorDescription: String? { self.message }
}

extension [String] {
  func createAnyMatcher() throws -> Regex<AnyRegexOutput>? {
    guard !self.isEmpty else { return nil }
    return try Regex(
      self
        .map { word in NSRegularExpression.escapedPattern(for: word) }
        .joined(separator: "|")
    )
  }
}
