//
//  Rekog.swift
//
//
//  Created by Elizabeth (lizclipse) on 15/08/2023.
//

import Foundation
import Logging
import Vision

actor Rekog {
  let logger = Logger(label: "Rekog")

  func image(url: String) async throws -> [String] {
    let data = try await self.getImage(url: url)
    let texts = try await self.recogniseText(image: data)
    return texts
  }

  private func getImage(url: String) async throws -> Data {
    guard let url = URL(string: url) else {
      throw RekogError.invalidUrl
    }

    let (data, result) = try await URLSession.shared.data(from: url)
    guard let mimeType = result.mimeType, mimeType.hasPrefix("image/") else {
      throw RekogError.nonImage
    }

    return data
  }

  private func recogniseText(image: Data) async throws -> [String] {
    let requestHandler = VNImageRequestHandler(data: image)

    return try await withCheckedThrowingContinuation { continuation in
      let request = VNRecognizeTextRequest(completionHandler: { req, error in
        if let error = error {
          continuation.resume(throwing: error)
        }

        do {
          let texts = try self.extractTexts(request: req)
          continuation.resume(returning: texts)
        } catch {
          continuation.resume(throwing: error)
        }
      })

      request.recognitionLevel = .accurate
      request.preferBackgroundProcessing = true

      do {
        try requestHandler.perform([request])
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }

  private func extractTexts(request: VNRequest) throws -> [String] {
    guard let observations = request.results as? [VNRecognizedTextObservation] else {
      throw RekogError.badRecognitionResult
    }

    return observations.compactMap { observation in
      // Return the string of the top VNRecognizedText instance.
      return observation.topCandidates(1).first?.string
    }
  }
}

enum RekogError: Error {
  case invalidUrl
  case nonImage
  case badRecognitionResult
}

extension RekogError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .invalidUrl: return "An invalid URL was given"
    case .nonImage: return "File loaded from URL did not have an image MIME type"
    case .badRecognitionResult: return "Recognition request did not return a valid result"
    }
  }
}
