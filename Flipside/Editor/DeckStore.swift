import Foundation

/// Keeps the working deck on disk so edits survive relaunches (Documents/studio-deck.json).
enum DeckStore {
  private static var url: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("studio-deck.json")
  }

  static func load() -> Deck? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(Deck.self, from: data)
  }

  static func save(_ deck: Deck) {
    guard let data = try? JSONEncoder().encode(deck) else { return }
    try? data.write(to: url, options: .atomic)
  }
}
