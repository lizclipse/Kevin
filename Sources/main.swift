@preconcurrency import DiscordKitBot
@preconcurrency import DiscordKitCore
import JavaScriptCore
import Logging

func main() throws {
  let token = try String(contentsOfFile: "Config/token").trimmingCharacters(
    in: .whitespacesAndNewlines)
  let guildId = try String(contentsOfFile: "Config/guild_id").trimmingCharacters(
    in: .whitespacesAndNewlines)

  let storePath = URL(
    filePath: "./state.json",
    relativeTo: URL(filePath: FileManager().currentDirectoryPath + "/")
  )

  Task {
    let store = Store(path: storePath)
    try! await store.load()

    let app = App(store: store, token: token, guildId: guildId)
    await app.run()
  }
  RunLoop.main.run()
}

actor App {
  let logger = Logger(label: "App")
  let bot = Client(intents: [.unprivileged, .messageContent])
  let api = DiscordREST()
  let rekog = Rekog()
  let jsContext = JSContext()!

  let store: Store
  let token: String
  let guildId: String

  init(store: Store, token: String, guildId: String) {
    self.store = store
    self.token = token
    self.guildId = guildId
  }

  func run() {
    self.api.setToken(token: token)

    self.bot.ready.listen {
      self.logger.info(
        "Successfully logged in as \(self.bot.user!.username)#\(self.bot.user!.discriminator)!"
      )

      do {
        try await self.registerCommands()
        self.logger.info("Registered commands")
      } catch {
        self.logger.error(
          "Failed to register commands",
          metadata: ["error": "\(error.localizedDescription)"])
      }
    }

    self.bot.messageCreate.listen { message in
      guard let guildId = message.guildID else { return }
      let ctx = await self.context(server: guildId)
      let executor = MessageExecutor(message: message, context: ctx)
      await executor.handleMessage()
    }

    self.bot.login(token: self.token)
  }

  private func registerCommands() async throws {
    try await self.bot.registerApplicationCommands(guild: self.guildId) { @Sendable in
      NewAppCommand("sleep", description: "tucks me into bed for a quick nap") { interaction in
        await self.executeCommand(interaction) { executor in
          try await executor.commandSleep()
        }
      }

      NewAppCommand("wake", description: "waves some celery under my nose to encourage me awake") {
        interaction in
        await self.executeCommand(interaction) { executor in
          try await executor.commandWake()
        }
      }

      NewAppCommand("gay", description: "homosexual") { interaction in
        await self.executeCommand(interaction) { executor in
          try await executor.commandGay()
        }
      }

      NewAppCommand(
        "poke", description: "nudges u with my nose"
      ) {
        UserOption("target", description: "target of the poke (or me if not given)")
        NumberOption(
          "delay", description: "number of seconds to wait before executing the poke",
          max: 14 * 60)
      } handler: { interaction in
        await self.executeCommand(interaction) { executor in
          try await executor.commandSlap(
            target: interaction.optionValue(of: "target"),
            delay: interaction.optionValue(of: "delay")
          )
        }
      }

      NewAppCommand("pet", description: "scritch kevin") { interaction in
        await self.executeCommand(interaction) { executor in
          try await executor.commandPet()
        }
      }

      NewAppCommand("pp", description: "manage privilege points ranking") {
        SubCommand("rank", description: "rank your privilege points")
      } handler: { interaction in
        await self.executeCommand(interaction) { executor in
          try await executor.commandPp()
        }
      }

      NewAppCommand("config", description: "tell kevin what you want him to do") {
        SubCommand(
          "channel-ignore", description: "tell kevin that you want him to ignore a channel"
        ) {
          ChannelOption("channel", description: "the channel to ignore", required: true)
        }

        SubCommand("channel-unignore", description: "tell kevin that a channel is back on the menu")
        {
          ChannelOption("channel", description: "the channel to unignore", required: true)
        }
      } handler: { interaction in
        await self.executeCommand(interaction) { executor in
          try await executor.commandConfig()
        }
      }
    }
  }

  private func executeCommand(
    _ interaction: CommandData,
    _ block: (_ executor: CommandExecutor) async throws -> Void
  ) async {
    let ctx = await self.context(server: self.guildId)
    let executor = CommandExecutor(interaction: interaction, context: ctx)

    do {
      try await block(executor)
    } catch {
      do {
        try await interaction.reply(
          "Failed to execute command:\n\n\(error.localizedDescription)".codeBlocked())
      } catch {
        self.logger.error("Command catastrophically failed", source: error.localizedDescription)
      }
    }
  }

  private func context(server: Snowflake) async -> ExecutorContext {
    return ExecutorContext(
      server: server,
      store: self.store,
      bot: self.bot,
      api: self.api,
      rekog: self.rekog,
      config: await self.store.get(server)
    )
  }
}

try! main()

extension String {
  func codeBlocked() -> String {
    return "```\n\(self)\n```"
  }
}
