@preconcurrency import DiscordKitBot
@preconcurrency import DiscordKitCore
import Foundation
import Logging

actor CommandExecutor {
  private let logger = Logger(label: "CommandExecutor")
  private let interaction: CommandData
  private let ctx: ExecutorContext

  init(interaction: CommandData, context: ExecutorContext) {
    self.interaction = interaction
    self.ctx = context
  }

  func commandSleep() async throws {
    guard await self.checkAwake() else { return }

    var config = self.ctx.config
    config.awake = false
    try await self.ctx.store.set(self.ctx.server, config: config)

    try await self.interaction.reply(sleepMsgs.randomElement()!)
  }

  func commandWake() async throws {
    guard !self.ctx.config.awake else {
      try await self.interaction.reply(awakeMsgs.randomElement()!)
      return
    }

    var config = self.ctx.config
    config.awake = true
    try await self.ctx.store.set(self.ctx.server, config: config)

    try await self.interaction.reply(wakeMsgs.randomElement()!)
  }

  func commandGay() async throws {
    guard await self.checkAwake() else { return }

    try await self.interaction.reply(gayFlag)
  }

  func commandSlap(target: String?, delay: Double?) async throws {
    guard await self.checkAwake() else { return }

    if let delay: Double = delay {
      try await self.interaction.deferReply()
      try await Task.sleep(for: .seconds(delay))
    }

    if let target: Snowflake = target {
      try await self.interaction.reply(poke(target: target))
    } else {
      try await self.interaction.reply(pokeMsgs.randomElement()!)
    }
  }

  func commandPet() async throws {
    guard await self.checkAwake() else { return }

    try await self.interaction.reply(petMsgs.randomElement()!)
  }

  func commandPp() async throws {
    guard await self.checkAwake() else { return }

    if let _option = self.interaction.subOption(name: "rank") {
      try await self.interaction.reply("test lol") {
        ActionRow {
          Button("this does nothing", id: "test")
        }
      }
    } else {
      try await self.interaction.reply("pls select a command dingus")
    }
  }

  func commandConfig() async throws {
    // config channel-ignore
    if let option = self.interaction.subOption(name: "channel-ignore") {
      let channel: String = try option.getOption("channel")

      guard !self.ctx.config.ignoredChannels.contains(channel) else {
        try await self.interaction.reply("Channel \(channel) already in ignore list".codeBlocked())
        return
      }

      var config = self.ctx.config
      if config.ignoredChannels.count > 1000 {
        throw ConfigCommandError("Maximum number of ignored channels added")
      }
      config.ignoredChannels.insert(channel)
      try await self.ctx.store.set(self.ctx.server, config: config)

      try await self.interaction.reply("Added channel ID \(channel) to ignore list".codeBlocked())

      // config channel-unignore
    } else if let option = self.interaction.subOption(name: "channel-unignore") {
      let channel: String = try option.getOption("channel")

      guard self.ctx.config.ignoredChannels.contains(channel) else {
        try await self.interaction.reply("Channel \(channel) is not in ignore list".codeBlocked())
        return
      }

      var config = self.ctx.config
      if !config.ignoredChannels.contains(channel) {
        throw ConfigCommandError("Channel was not ignored")
      }
      config.ignoredChannels.remove(channel)
      try await self.ctx.store.set(self.ctx.server, config: config)

      try await self.interaction.reply(
        "Removed channel ID \(channel) from ignore list".codeBlocked())
    }
  }

  private func checkAwake() async -> Bool {
    guard !self.ctx.config.awake else { return true }

    do {
      try await self.asleepRespond()
    } catch {
      self.logger.error("failed to send sleeping message", source: error.localizedDescription)
    }

    return false
  }

  private func asleepRespond() async throws {
    try await self.interaction.reply(asleepMsgs.randomElement()!)
  }
}

extension [String: CommandData.OptionData.Value] {
  func getOption(_ name: String) throws -> CommandData.OptionData.Value {
    guard let value = self[name] else {
      throw ConfigCommandError("Missing option `\(name)`")
    }
    return value
  }

  func getOption(_ name: String) throws -> String {
    guard let value: String = try self.getOption(name).value() else {
      throw ConfigCommandError("Option `\(name)` has incorrect data type")
    }
    return value
  }

  func getOption(_ name: String) throws -> Int {
    guard let value: Int = try self.getOption(name).value() else {
      throw ConfigCommandError("Option `\(name)` has incorrect data type")
    }
    return value
  }

  func getOption(_ name: String) throws -> Double {
    guard let value: Double = try self.getOption(name).value() else {
      throw ConfigCommandError("Option `\(name)` has incorrect data type")
    }
    return value
  }

  func getOption(_ name: String) throws -> Bool {
    guard let value: Bool = try self.getOption(name).value() else {
      throw ConfigCommandError("Option `\(name)` has incorrect data type")
    }
    return value
  }
}

struct ConfigCommandError {
  let message: String

  init(_ message: String) {
    self.message = message
  }
}

extension ConfigCommandError: LocalizedError {
  var errorDescription: String? { self.message }
}
