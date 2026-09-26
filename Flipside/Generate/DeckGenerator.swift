import Foundation

/// Streams deck edits from OpenAI (or Claude when only an Anthropic key is set,
/// or the offline demo writer when there is no key at all).
enum DeckGenerator {
  static let anthropicModel = "claude-sonnet-5"

  /// What the model knows beyond the prompt: remembered facts and attached files.
  struct Context: Sendable {
    var memory: String?
    var attachments: [Attachment] = []

    static let none = Context()

    var images: [Data] { attachments.compactMap(\.imageData) }

    func system(_ base: String) -> String {
      memory.map { base + "\n\n" + $0 } ?? base
    }
  }

  /// What will write the next deck, for the Settings footer.
  static var providerLabel: String {
    if Secrets.openAIKey != nil { return "OpenAI \(Secrets.openAIModel)" }
    if Secrets.anthropicKey != nil { return "Claude \(anthropicModel)" }
    return "Flipside"
  }

  /// The house system prompt. If `GENERATION-PROMPT.md` from the assets folder is bundled, it leads;
  /// the output contract below is always appended so the parser can read the stream.
  static var systemPrompt: String {
    let house = Bundle.main.url(forResource: "GENERATION-PROMPT", withExtension: "md")
      .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
      ?? """
      You write short, confident presentation decks for Flipside, a presenter app on a folding phone. \
      The audience reads the slide from across a table, so every slide is glanceable: a title of at most \
      eight words and zero to four body lines of at most nine words each. Speaker detail goes in notes. \
      Open with a cover, end with a close. Use statement for one big idea, two-column for lists or \
      comparisons, live for a moment of interaction or a key number. Most decks are five to eight slides.
      """
    return house + "\n\n" + outputContract
  }

  static let outputContract = """
  OUTPUT FORMAT (strict). Write only JSON Lines: one JSON object per line, nothing else, no code fences.
  Always put "op" first, then "layout", then "title", then "body", then the other fields, because the app \
  renders each field the moment it arrives.
  Ops:
  {"op":"say","text":"one short sentence to the presenter about what you are doing"}  (always first)
  {"op":"deck","title":"Deck title"}  starts a brand new deck and clears the old one
  {"op":"add","layout":"cover|statement|two-column|live|close","title":"…","body":["…"],"notes":"…","cue":"…","imagePrompt":"…"}
  {"op":"replace","id":"existing slide id","layout":"…","title":"…","body":["…"],"notes":"…","cue":"…","imagePrompt":"…"}
  {"op":"delete","id":"existing slide id"}
  {"op":"remember","text":"one durable fact about the presenter"}  when the request reveals something worth \
  keeping for future decks (their name, company, role, audience, brand or style preferences). Short, third person. \
  Never remember one-off details of this deck. At most two per reply, after say.
  imagePrompt is optional: a concrete photographic subject for slides that benefit from a picture \
  (at most two per deck, usually two-column or live). Omit it otherwise.
  If the request is a new topic, emit say, then deck, then the adds. If it asks to change the current deck, \
  emit say, then only the replace, add or delete ops needed, and keep untouched slides out of the output.
  """

  static func userMessage(prompt: String, deck: Deck, linkText: String?, attachments: [Attachment] = []) -> String {
    var parts: [String] = []
    if let files = Attachment.contextBlock(attachments) {
      parts.append(files)
    }
    if !deck.slides.isEmpty {
      let slides = deck.slides.map { slide in
        let body = slide.bodyLines.map { "\"\($0)\"" }.joined(separator: ", ")
        return "- id=\(slide.id) layout=\(slide.layout.rawValue) title=\"\(slide.title)\" body=[\(body)]"
      }.joined(separator: "\n")
      parts.append("CURRENT DECK \"\(deck.title)\":\n\(slides)")
    }
    if let linkText {
      parts.append("LINKED PAGE (use it as source material):\n\(linkText)")
    }
    parts.append("REQUEST: \(prompt)")
    return parts.joined(separator: "\n\n")
  }

  /// Text chunks as they stream.
  static func stream(prompt: String, deck: Deck, context: Context = .none) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          let link = await LinkReader.text(forFirstLinkIn: prompt)
          let user = userMessage(prompt: prompt, deck: deck, linkText: link, attachments: context.attachments)
          let system = context.system(systemPrompt)
          if let key = Secrets.openAIKey {
            try await streamOpenAI(key: key, model: Secrets.openAIModel, system: system, user: user, images: context.images, into: continuation)
          } else if let key = Secrets.anthropicKey {
            try await streamClaude(key: key, system: system, user: user, images: context.images, into: continuation)
          } else {
            for try await chunk in DemoWriter.stream(prompt: prompt, deck: deck) {
              continuation.yield(chunk)
            }
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  /// Plain streamed answer, for the desk's Ask tab. Shown on the presenter's side only.
  static func ask(_ question: String, deck: Deck, currentIndex: Int, context: Context = .none) -> AsyncThrowingStream<String, Error> {
    let base = """
    You are the presenter's private assistant during a live presentation. The audience cannot see your answer. \
    Answer in at most three short sentences, plain text, no markdown. Be concrete and useful right now.
    """
    let system = context.system(base)
    let current = deck.slides.indices.contains(currentIndex) ? deck.slides[currentIndex].title : "none"
    let user = userMessage(prompt: question, deck: deck, linkText: nil, attachments: context.attachments) + "\n\nCURRENT SLIDE: \(current)"
    return AsyncThrowingStream { continuation in
      let task = Task {
        do {
          if let key = Secrets.openAIKey {
            try await streamOpenAI(key: key, model: Secrets.openAIModel, system: system, user: user, images: context.images, into: continuation)
          } else if let key = Secrets.anthropicKey {
            try await streamClaude(key: key, system: system, user: user, images: context.images, into: continuation)
          } else {
            continuation.yield("I can't answer that right now. Keep going, you've got this.")
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  /// One non-streamed JSON reply, for background jobs like memory learning. Nil without a key.
  static func completeJSON(system: String, user: String) async throws -> [String: Any]? {
    var request: URLRequest
    let body: [String: Any]
    if let key = Secrets.openAIKey {
      request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
      request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
      var b: [String: Any] = [
        "model": Secrets.openAIModel,
        "response_format": ["type": "json_object"],
        "messages": [["role": "system", "content": system], ["role": "user", "content": user]],
      ]
      if ["gpt-5", "o1", "o3", "o4"].contains(where: Secrets.openAIModel.hasPrefix) { b["reasoning_effort"] = "minimal" }
      body = b
    } else if let key = Secrets.anthropicKey {
      request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
      request.setValue(key, forHTTPHeaderField: "x-api-key")
      request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
      body = [
        "model": anthropicModel,
        "max_tokens": 1024,
        "system": system + "\nReply with one JSON object only.",
        "messages": [["role": "user", "content": user]],
      ]
    } else {
      return nil
    }
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 60
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, response) = try await URLSession.shared.data(for: request)
    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
      throw GenerationError.http(provider: Secrets.openAIKey != nil ? "OpenAI" : "Claude", http.statusCode, String(decoding: data, as: UTF8.self))
    }
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    let text: String?
    if let choice = (json["choices"] as? [[String: Any]])?.first {
      text = (choice["message"] as? [String: Any])?["content"] as? String
    } else {
      text = ((json["content"] as? [[String: Any]])?.first)?["text"] as? String
    }
    guard let text else { return nil }
    // Tolerate a code fence or stray prose around the object.
    guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { return nil }
    return try JSONSerialization.jsonObject(with: Data(text[start...end].utf8)) as? [String: Any]
  }

  /// OpenAI Chat Completions with `stream: true`; text arrives in `choices[0].delta.content`.
  private static func streamOpenAI(
    key: String,
    model: String,
    system: String,
    user: String,
    images: [Data] = [],
    lowReasoning: Bool = true,
    into continuation: AsyncThrowingStream<String, Error>.Continuation
  ) async throws {
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 120
    var body: [String: Any] = [
      "model": model,
      "stream": true,
      "messages": [
        ["role": "system", "content": system],
        ["role": "user", "content": openAIUserContent(user, images: images)],
      ],
    ]
    // Reasoning models start streaming much sooner with minimal reasoning; slides don't need more.
    if lowReasoning, ["gpt-5", "o1", "o3", "o4"].contains(where: model.hasPrefix) {
      body["reasoning_effort"] = "minimal"
    }
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (bytes, response) = try await URLSession.shared.bytes(for: request)
    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
      var text = ""
      for try await line in bytes.lines { text += line }
      // Some models reject "minimal"; retry once with their default reasoning.
      if http.statusCode == 400, lowReasoning, text.contains("reasoning") {
        return try await streamOpenAI(key: key, model: model, system: system, user: user, images: images, lowReasoning: false, into: continuation)
      }
      throw GenerationError.http(provider: "OpenAI", http.statusCode, text)
    }
    for try await line in bytes.lines {
      guard line.hasPrefix("data: ") else { continue }
      let payload = line.dropFirst(6)
      if payload == "[DONE]" { break }
      guard let event = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any] else { continue }
      if let error = event["error"] as? [String: Any] {
        throw GenerationError.api(error["message"] as? String ?? "Unknown error")
      }
      if let choice = (event["choices"] as? [[String: Any]])?.first,
         let delta = choice["delta"] as? [String: Any],
         let text = delta["content"] as? String {
        continuation.yield(text)
      }
    }
  }

  /// Plain text, or text plus images as data URLs when files are attached.
  private static func openAIUserContent(_ text: String, images: [Data]) -> Any {
    guard !images.isEmpty else { return text }
    var parts: [[String: Any]] = [["type": "text", "text": text]]
    for data in images {
      parts.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(data.base64EncodedString())"]])
    }
    return parts
  }

  private static func claudeUserContent(_ text: String, images: [Data]) -> Any {
    guard !images.isEmpty else { return text }
    var parts: [[String: Any]] = images.map {
      ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": $0.base64EncodedString()]]
    }
    parts.append(["type": "text", "text": text])
    return parts
  }

  private static func streamClaude(
    key: String,
    system: String,
    user: String,
    images: [Data] = [],
    into continuation: AsyncThrowingStream<String, Error>.Continuation
  ) async throws {
    var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
    request.httpMethod = "POST"
    request.setValue(key, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.setValue("application/json", forHTTPHeaderField: "content-type")
    request.timeoutInterval = 120
    let body: [String: Any] = [
      "model": anthropicModel,
      "max_tokens": 4096,
      "stream": true,
      "system": system,
      "messages": [["role": "user", "content": claudeUserContent(user, images: images)]],
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (bytes, response) = try await URLSession.shared.bytes(for: request)
    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
      var text = ""
      for try await line in bytes.lines { text += line }
      throw GenerationError.http(provider: "Claude", http.statusCode, text)
    }
    for try await line in bytes.lines {
      guard line.hasPrefix("data: ") else { continue }
      let payload = Data(line.dropFirst(6).utf8)
      guard let event = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else { continue }
      if event["type"] as? String == "content_block_delta",
         let delta = event["delta"] as? [String: Any],
         let text = delta["text"] as? String {
        continuation.yield(text)
      } else if event["type"] as? String == "error" {
        let message = (event["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
        throw GenerationError.api(message)
      }
    }
  }
}

enum GenerationError: LocalizedError {
  case http(provider: String, Int, String)
  case api(String)

  var errorDescription: String? {
    switch self {
    case .http(let provider, let code, let body):
      if code == 401 { return "The \(provider) key was rejected. Check it in Settings." }
      if let data = body.data(using: .utf8),
         let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let message = (json["error"] as? [String: Any])?["message"] as? String {
        return "\(provider) returned \(code): \(message)"
      }
      return "\(provider) returned \(code). \(body.prefix(160))"
    case .api(let message):
      return message
    }
  }
}

/// Pulls readable text out of the first link in a prompt, so "make a deck from <url>" works.
enum LinkReader {
  static func text(forFirstLinkIn prompt: String) async -> String? {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
          let match = detector.firstMatch(in: prompt, range: NSRange(prompt.startIndex..., in: prompt)),
          let url = match.url,
          url.scheme?.hasPrefix("http") == true else { return nil }
    var request = URLRequest(url: url)
    request.timeoutInterval = 12
    guard let (data, _) = try? await URLSession.shared.data(for: request),
          let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return nil }
    let text = html
      .replacingOccurrences(of: #"(?s)<(script|style|noscript)[^>]*>.*?</\1>"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: #"&nbsp;|&#160;"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespaces)
    return text.isEmpty ? nil : String(text.prefix(6000))
  }
}
