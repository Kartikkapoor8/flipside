import Foundation

/// Offline stand-in for the model: writes a plausible deck for any topic in the same JSON Lines format,
/// streamed a few characters at a time, so the demo still works when Wi-Fi or the key is missing.
enum DemoWriter {
  static func stream(prompt: String, deck: Deck) -> AsyncThrowingStream<String, Error> {
    let text = script(for: topic(from: prompt))
    return AsyncThrowingStream { continuation in
      let task = Task {
        try? await Task.sleep(for: .milliseconds(500))
        var index = text.startIndex
        while index < text.endIndex, !Task.isCancelled {
          let next = text.index(index, offsetBy: 4, limitedBy: text.endIndex) ?? text.endIndex
          let chunk = String(text[index..<next])
          continuation.yield(chunk)
          index = next
          // Roughly model speed, with a beat between slides so each one lands on its own.
          try? await Task.sleep(for: .milliseconds(chunk.contains("\n") ? 420 : 28))
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  private static func topic(from prompt: String) -> String {
    var t = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    for prefix in ["make a deck about", "make a deck on", "a deck about", "deck about", "pitch", "about"] {
      if t.lowercased().hasPrefix(prefix) { t = String(t.dropFirst(prefix.count)) }
    }
    t = t.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    for article in ["a ", "an ", "the ", "our "] where t.lowercased().hasPrefix(article) {
      t = String(t.dropFirst(article.count))
    }
    return t.isEmpty ? "Your idea" : t.prefix(1).uppercased() + t.dropFirst()
  }

  private static func line(_ object: [String: Any]) -> String {
    // Keep keys in the order the parser renders best: op, layout, title, body, then the rest.
    let order = ["op", "text", "layout", "title", "body", "notes", "cue", "imagePrompt"]
    let fields = order.compactMap { key -> String? in
      guard let value = object[key],
            let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
            let json = String(data: data, encoding: .utf8) else { return nil }
      return "\"\(key)\":\(json)"
    }
    return "{" + fields.joined(separator: ",") + "}\n"
  }

  private static func script(for topic: String) -> String {
    [
      line(["op": "say", "text": "Building your deck"]),
      line(["op": "deck", "title": topic]),
      line(["op": "add", "layout": "cover", "title": topic, "body": ["A five-minute tour", "Built live, on a folding phone"], "notes": "Introduce yourself and why \(topic.lowercased()) matters to this room."]),
      line(["op": "add", "layout": "statement", "title": "Why \(topic.lowercased()) matters now", "body": ["The window is open, and it won't stay open."], "notes": "One sentence of context. Then stop talking."]),
      line(["op": "add", "layout": "two-column", "title": "What we know", "body": ["It saves real time", "People already want it", "The tools finally exist"], "notes": "Walk each line. Give one example for each.", "imagePrompt": "\(topic), editorial photo, soft window light"]),
      line(["op": "add", "layout": "live", "title": "3x faster", "body": ["Measured, not promised"], "notes": "Pause on the number. Let it land.", "cue": "Ask the room to guess first."]),
      line(["op": "add", "layout": "two-column", "title": "The plan", "body": ["Start small this week", "Measure what changes", "Scale what works", "Drop what doesn't"], "notes": "Keep this concrete. Name owners if you can."]),
      line(["op": "add", "layout": "close", "title": "Let's start Monday.", "body": ["Questions welcome."], "notes": "Ask for the decision, then stop."]),
    ].joined()
  }
}
