@preconcurrency import DiscordKitBot
@preconcurrency import DiscordKitCore

struct ExecutorContext {
  let server: Snowflake
  let store: Store
  let bot: Client
  let api: DiscordREST
  let rekog: Rekog
  let config: ServerConfig
}
