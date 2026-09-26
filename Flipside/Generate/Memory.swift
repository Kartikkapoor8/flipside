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
