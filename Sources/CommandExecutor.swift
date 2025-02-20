@preconcurrency import DiscordKitBot
@preconcurrency import DiscordKitCore
import Foundation
import Logging

actor CommandExecutor {
  private static let maxIgnoreChannels = 1000
  private static let maxFoodWords = 1000

  private let logger = Logger(label: "CommandExecutor")
  private let interaction: CommandData
  private let ctx: ExecutorContext

  init(interaction: CommandData, context: ExecutorContext) {
    self.interaction = interaction
    self.ctx = context
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

extension CommandExecutor {
  func commandSleep() async throws {
    guard await self.checkAwake() else { return }

    var config = self.ctx.config
    config.awake = false
    try await self.ctx.store.set(self.ctx.server, config: config)

    try await self.interaction.reply(sleepMsgs.randomElement()!)
  }
}

extension CommandExecutor {
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
}

extension CommandExecutor {
  func commandGay() async throws {
    guard await self.checkAwake() else { return }

    try await self.interaction.reply(gayFlag)
  }
}

extension CommandExecutor {
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
}

extension CommandExecutor {
  func commandPet() async throws {
    guard await self.checkAwake() else { return }

    try await self.interaction.reply(petMsgs.randomElement()!)
  }
}

extension CommandExecutor {
  func commandPp() async throws {
    guard await self.checkAwake() else { return }

    if self.interaction.subOption(name: "rank") != nil {
      try await self.interaction.reply("test lol") {
        ActionRow {
          Button("this does nothing", id: "test")
        }
      }
    } else {
      try await self.interaction.reply("pls select a command dingus")
    }
  }
}

extension CommandExecutor {
  func commandConfig() async throws {
    if let group = self.interaction.subGroup(name: "channel") {
      try await self.subcommandConfigChannel(group)
    } else if let group = self.interaction.subGroup(name: "words") {
      try await self.subcommandConfigWords(group)
    }
  }

  private func subcommandConfigChannel(_ command: CommandData) async throws {
    let getChannel = { (option: [String: CommandData.OptionData.Value]) in
      let id: Snowflake = try option.getOption("channel")
      let ref = self.interaction.resolved?.channels?[id]
      return (id, ref)
    }

    ////////////////////////////////////////////////////
    if let option = command.subOption(name: "ignore") {
      let (channelID, channel) = try getChannel(option)
      var config = self.ctx.config

      guard !config.ignoredChannels.contains(channelID) else {
        try await self.interaction.reply(
          "Channel `\(channel?.name ?? channelID)` already in ignore list".codeBlocked(),
          ephemeral: true
        )
        return
      }

      guard config.ignoredChannels.count < Self.maxIgnoreChannels else {
        throw ConfigCommandError("Maximum number of ignored channels added")
      }

      config.ignoredChannels.insert(channelID)
      try await self.ctx.store.set(self.ctx.server, config: config)

      try await self.interaction.reply(
        "Added channel `\(channel?.name ?? channelID)` to ignore list".codeBlocked(),
        ephemeral: true
      )

      ////////////////////////////////////////////////////
    } else if let option = command.subOption(name: "unignore") {
      let (channelID, channel) = try getChannel(option)
      var config = self.ctx.config

      guard config.ignoredChannels.contains(channelID) else {
        try await self.interaction.reply(
          "Channel `\(channel?.name ?? channelID)` is not in ignore list".codeBlocked(),
          ephemeral: true
        )
        return
      }

      config.ignoredChannels.remove(channelID)
      try await self.ctx.store.set(self.ctx.server, config: config)

      try await self.interaction.reply(
        "Removed channel `\(channel?.name ?? channelID)` from ignore list".codeBlocked(),
        ephemeral: true
      )

      ////////////////////////////////////////////////////
    } else if command.subOption(name: "list") != nil {
      let names: [String]
      if let guildID = self.interaction.guildID {
        let channels = (try await self.ctx.api.getGuildChannels(id: guildID)).compactMap {
          channel in
          try? channel.result.get()
        }

        let channelNames = [String: String](
          uniqueKeysWithValues: channels.compactMap { channel in
            guard let name = channel.name else { return nil }
            return (channel.id, name)
          })

        names = self.ctx.config.ignoredChannels.map { channelID in
          channelNames[channelID] ?? channelID
        }
      } else {
        names = Array(self.ctx.config.ignoredChannels)
      }

      let namesBlock =
        names
        .sorted()
        .map { name in "\t\(name)" }
        .joined(separator: "\n")
      try await self.interaction.reply(
        "Currently ignored channels:\n\(namesBlock)".codeBlocked(),
        ephemeral: true
      )
    }
  }

  private func subcommandConfigWords(_ command: CommandData) async throws {
    if let option = command.subOption(name: "add") {
      let word: String = try option.getOption("word")
      var config = self.ctx.config

      guard !config.foodWords.contains(word) else {
        try await self.interaction.reply(
          "Word `\(word)` already in listen list".codeBlocked(),
          ephemeral: true
        )
        return
      }

      guard config.foodWords.count < Self.maxFoodWords else {
        throw ConfigCommandError("Maximum number of word added")
      }

      config.foodWords.append(word)
      try await self.ctx.store.set(self.ctx.server, config: config)

      try await self.interaction.reply(
        "Added word `\(word)` to listen list",
        ephemeral: true
      )
    } else if let option = command.subOption(name: "remove") {
      let word: String = try option.getOption("word")
      var config = self.ctx.config

      guard config.foodWords.contains(word) else {
        try await self.interaction.reply(
          "Word `\(word)` is not in listen list".codeBlocked(),
          ephemeral: true
        )
        return
      }

      config.foodWords.removeAll { foodWord in foodWord == word }
      try await self.ctx.store.set(self.ctx.server, config: config)

      try await self.interaction.reply(
        "Removed word `\(word)` from listen list",
        ephemeral: true
      )
    } else if command.subOption(name: "list") != nil {
      let words = self.ctx.config.foodWords
        .sorted()
        .map { word in "\t\(word)" }
        .joined(separator: "\n")
      try await self.interaction.reply(
        "Current words kevin sniffs for:\n\(words)".codeBlocked(),
        ephemeral: true
      )
    }
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
