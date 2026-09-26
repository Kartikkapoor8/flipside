import Foundation

/// Something Flipside remembers about the presenter across decks ("I'm a realtor at Compass").
struct MemoryItem: Codable, Identifiable, Hashable, Sendable {
  var id = UUID().uuidString
  var text: String
  var createdAt = Date()
}

/// Memories on disk (Documents/memory.json), plus the on/off switch.
enum MemoryStore {
  private static var url: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("memory.json")
  }

  static var isEnabled: Bool {
    get { UserDefaults.standard.object(forKey: "memoryEnabled") as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: "memoryEnabled") }
  }

  static func load() -> [MemoryItem] {
    guard let data = try? Data(contentsOf: url) else { return [] }
    return (try? JSONDecoder().decode([MemoryItem].self, from: data)) ?? []
  }

  static func save(_ items: [MemoryItem]) {
    guard let data = try? JSONEncoder().encode(items) else { return }
    try? data.write(to: url, options: .atomic)
  }

  /// The block added to the model's instructions, or nil when memory is off or empty.
  static func promptBlock(_ items: [MemoryItem]) -> String? {
    guard isEnabled, !items.isEmpty else { return nil }
    let lines = items.suffix(40).map { "- \($0.text)" }.joined(separator: "\n")
    return "WHAT YOU REMEMBER ABOUT THE PRESENTER (use it when relevant, never read it back verbatim):\n\(lines)"
  }
}

/// Everything the presenter has typed (prompts, Build and Ask messages), so memory can learn from it.
struct TextLogEntry: Codable, Identifiable, Hashable, Sendable {
  var id = UUID().uuidString
  var text: String
  var date = Date()
  /// Already read by the memory learner.
  var learned = false
}

enum TextLog {
  private static var url: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("text-log.json")
  }

  static func load() -> [TextLogEntry] {
    guard let data = try? Data(contentsOf: url) else { return [] }
    return (try? JSONDecoder().decode([TextLogEntry].self, from: data)) ?? []
  }

  static func save(_ entries: [TextLogEntry]) {
    // Keep the last 500 texts.
    guard let data = try? JSONEncoder().encode(Array(entries.suffix(500))) else { return }
    try? data.write(to: url, options: .atomic)
  }

  static func append(_ text: String) {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    var entries = load()
    entries.append(TextLogEntry(text: String(text.prefix(2000))))
    save(entries)
  }
}

/// Reads unlearned texts and updates memory in one model call: adds new facts, rewrites changed ones,
/// removes duplicates and anything a newer text contradicts.
enum MemoryLearner {
  static let system = """
  You maintain a short memory about one presenter who uses Flipside, an app that writes presentation decks. \
  You get their current memories (with ids) and texts they recently typed. Keep only durable facts useful \
  for future decks: name, company, role, city, industry, typical audience, brand, tone and style preferences, \
  recurring products or clients. Ignore one-off details of a single deck (a specific address, a date, a slide edit). \
  Each memory is one short third-person sentence. Merge duplicates. If a text changes a fact, update it. \
  Reply with JSON: {"add":["…"],"update":[{"id":"…","text":"…"}],"remove":["id"]}. Use empty arrays when nothing changes.
  """

  struct Result: Sendable {
    var memories: [MemoryItem]
    var learnedIDs: Set<String>
    var changed: Bool
  }

  /// Nil when there's nothing to learn from or no key.
  static func learn(memories: [MemoryItem], log: [TextLogEntry]) async throws -> Result? {
    let pending = log.filter { !$0.learned }.suffix(40)
    guard !pending.isEmpty else { return nil }
    let current = memories.map { "{\"id\":\"\($0.id)\",\"text\":\(jsonString($0.text))}" }.joined(separator: ",\n")
    let texts = pending.map { "- \($0.text.prefix(600))" }.joined(separator: "\n")
    let user = "CURRENT MEMORIES:\n[\(current)]\n\nRECENT TEXTS:\n\(texts)"
    guard let json = try await DeckGenerator.completeJSON(system: system, user: user) else { return nil }

    var result = memories
    var changed = false
    let remove = Set((json["remove"] as? [String]) ?? [])
    if !remove.isEmpty {
      result.removeAll { remove.contains($0.id) }
      changed = true
    }
    for update in (json["update"] as? [[String: Any]]) ?? [] {
      guard let id = update["id"] as? String, let text = update["text"] as? String,
            let i = result.firstIndex(where: { $0.id == id }), result[i].text != text else { continue }
      result[i].text = text
      changed = true
    }
    for text in (json["add"] as? [String]) ?? [] {
      let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty, !result.contains(where: { $0.text.caseInsensitiveCompare(text) == .orderedSame }) else { continue }
      result.append(MemoryItem(text: text))
      changed = true
    }
    return Result(memories: Array(result.suffix(60)), learnedIDs: Set(pending.map(\.id)), changed: changed)
  }

  private static func jsonString(_ s: String) -> String {
    (try? String(data: JSONEncoder().encode(s), encoding: .utf8)) ?? "\"\""
  }
}
