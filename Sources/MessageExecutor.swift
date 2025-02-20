@preconcurrency import DiscordKitBot
@preconcurrency import DiscordKitCore
import Foundation
import Logging

actor MessageExecutor {
  private let logger = Logger(label: "MessageExecutor")
  private let message: BotMessage
  private let ctx: ExecutorContext

  init(message: BotMessage, context: ExecutorContext) {
    self.message = message
    self.ctx = context
  }

  func handleMessage() async {
    guard let botUser = self.ctx.bot.user,
      self.ctx.config.awake && self.message.author != botUser
    else {
      return
    }

    if let ref = self.message.referencedMessage,
      await self.handleRekogRequest(ref: ref)
    {
      return
    }

    if await self.handleSqueak() { return }
    if await self.handleSniff() { return }
  }

  private func handleRekogRequest(ref: BotMessage) async -> Bool {
    let images = ref.attachments.images()
    guard let botUser = self.ctx.bot.user, self.message.mentions(botUser.id) && !images.isEmpty
    else {
      return false
    }

    try? await self.ctx.api.typingStart(id: self.message.channelID)
    var content = "Transcription:"
    for image in images {
      content.append("\n")
      do {
        let texts = try await self.ctx.rekog.image(url: image.url)
        content.append("```")
        content.append(texts.joined(separator: "\n"))
        content.append("\n```")
      } catch {
        content.append("\n")
        content.append("<failed to recognise text: \(error.localizedDescription)>")
      }
    }

    let response = NewMessage(
      content: content,
      message_reference: MessageReference(
        message_id: ref.id, channel_id: ref.channelID, guild_id: ref.guildID
      )
    )

    do {
      let _ = try await self.ctx.api.createChannelMsg(message: response, id: ref.channelID)
    } catch {
      self.logger.warning("failed to send rekog response", source: error.localizedDescription)
    }

    return true
  }

  private func handleSniff() async -> Bool {
    guard !self.ctx.config.ignoredChannels.contains(self.message.channelID) else { return false }

    do {
      guard let matcher = try self.ctx.config.foodWords.createAnyMatcher() else { return false }
      let found = await self.searchFor(re: matcher, in: self.message)
      if !found { return false }
    } catch {
      self.logger.error("failed to create matcher: \(error.localizedDescription)")
    }

    await self.makeSqueak()
    return true
  }

  private func handleSqueak() async -> Bool {
    guard let botUser = self.ctx.bot.user, self.message.mentions(botUser.id) else { return false }

    await self.makeSqueak()
    return true
  }

  private func makeSqueak() async {
    // let content =
    //   if Int.random(in: 0...1000) == 0 {
    //     manVoice.randomElement()!
    //   } else {
    //     {
    //       let squeak = squeaks.randomElement()!
    //       let times = Int.random(in: 1...5)
    //       let squeaking = (0..<times).map { _ in squeak }.joined(separator: " ")
    //       return "*\(squeaking)*"
    //     }()
    //   }
    let squeak = squeaks.randomElement()!
    let times = Int.random(in: 1...5)
    let squeaking = (0..<times).map { _ in squeak }.joined(separator: " ")
    let content = "*\(squeaking)*"

    let response = NewMessage(content: content)

    do {
      let _ = try await self.ctx.api.createChannelMsg(message: response, id: self.message.channelID)
    } catch {
      self.logger.warning("failed to send squeak", source: error.localizedDescription)
    }
  }

  private func searchFor(re: Regex<AnyRegexOutput>, in: BotMessage) async -> Bool {
    if !`in`.content.matches(of: re).isEmpty { return true }

    for img in `in`.attachments.images() {
      do {
        let texts = try await self.ctx.rekog.image(url: img.url)
        let found = texts.contains { text in
          return !text.matches(of: re).isEmpty
        }
        if found { return true }
      } catch {
        self.logger.warning("failed to perform rekog", source: error.localizedDescription)
      }
    }

    // let rekogs = await withTaskGroup(of: [String].self, returning: [String].self) { group in

    //   var texts: [String] = []
    //   for await result in group {
    //     texts.append(contentsOf: result)
    //   }
    //   return texts
    // }
    // return texts.contains { text in
    //   return !text.matches(of: re).isEmpty
    // }

    return false
  }
}

extension String {
  func findLinks() -> [String] {
    let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    let matches = detector.matches(
      in: self, range: NSRange(location: 0, length: self.utf16.count))
    return matches.compactMap { match in
      guard let range = Range(match.range, in: self) else { return nil }
      return String(self[range])
    }
  }
}

extension [Attachment] {
  func images() -> Self {
    return self.compactMap { attachment in
      guard let contentType = attachment.content_type, contentType.hasPrefix("image/") else {
        return nil
      }
      return attachment
    }
  }
}
