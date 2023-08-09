@preconcurrency import DefaultCodable
import Foundation
import Logging

struct ServerConfigModel: Codable, Sendable {
  @Default<True>
  var awake: Bool

  @Default<Empty>
  var ignoredChannels: [String]

  init() {}
  init(from: ServerConfig) {
    self.awake = from.awake
    self.ignoredChannels = Array(from.ignoredChannels)
  }
}

struct ServerConfig: Sendable {
  var awake: Bool
  var ignoredChannels: Set<String>

  init() {
    self.awake = true
    self.ignoredChannels = .init()
  }
  init(from: ServerConfigModel) {
    self.awake = from.awake
    self.ignoredChannels = Set(from.ignoredChannels)
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

  func get(_ server: String) -> ServerConfig {
    return self.data[server] ?? ServerConfig()
  }

  func set(_ server: String, config: ServerConfig) throws {
    self.data[server] = config
    let store = self.data.mapValues { v in ServerConfigModel(from: v) }
    let encoder = JSONEncoder()
    try encoder.encode(store).write(to: self.path)
  }
}
