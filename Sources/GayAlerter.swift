//
//  GayAlerter.swift
//
//
//  Created by Elizabeth (lizclipse) on 15/08/2023.
//

@preconcurrency import DiscordKitCore
import Foundation
import Logging

actor GayAlerter {
  private let api: DiscordREST
  private let logger: Logger

  private(set) var foundGay = false
  let channelID: Snowflake

  private let gayWordMatcher = try! Regex("(\\W|^)(\(gayWords.joined(separator: "|")))s?(\\W|$)")
    .ignoresCase()

  init(api: DiscordREST, logger: Logger, channelID: Snowflake) {
    self.api = api
    self.logger = logger
    self.channelID = channelID
  }

  func check(_ string: String) async {
    guard !foundGay else { return }

    foundGay = !string.matches(of: gayWordMatcher).isEmpty
    guard foundGay else { return }

    await sendMsg()
  }

  private func sendMsg() async {
    do {
      let _ = try await api.createChannelMsg(
        message: NewMessage(content: gayAlert), id: channelID)
    } catch {
      logger.warning("failed to alert gayness", source: error.localizedDescription)
    }
  }
}

private let gayWords = [
  "gay",
  "fag",
  "faggot",
  "tran",
  "homo",
  "yuri",
  "yaoi",
  "queer",
  "ace",
  "aro",
  "nonbinary",
  "cock",
  "pussy",
  "boob",
  "dick",
  "clit",
  "pronoun",
  "penis",
  "balls",
]

private let gayAlert =
  "*ALERT!! QUEER ACTIVITY DETECTED! DEPLOYING COUNTERMEASURES*\nhttps://cdn.discordapp.com/attachments/310515540273659905/1138878507221524510/ZE1q3bmCHhVtdLZy.mov"
