import Foundation

/// A saved deck on the home screen.
struct Project: Codable, Identifiable, Hashable, Sendable {
  var id: String
  var deck: Deck
  var updatedAt: Date

  var title: String { deck.title.isEmpty ? "Untitled" : deck.title }
}

/// Every deck the presenter has made, one JSON file each in Documents/projects/.
enum ProjectStore {
  /// The bundled pitch deck always appears, under a fixed id, until it has been edited and saved.
  static let pitchID = "flipside-pitch"

  private static var folder: URL {
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("projects", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private static func file(for id: String) -> URL {
    folder.appendingPathComponent("\(id).json")
  }

  /// Newest first. Includes the bundled pitch deck if it hasn't been saved as a project yet.
  static func all() -> [Project] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
    var projects = files
      .filter { $0.pathExtension == "json" }
      .compactMap { try? decoder.decode(Project.self, from: Data(contentsOf: $0)) }
      .filter { !$0.deck.slides.isEmpty }
    if !projects.contains(where: { $0.id == pitchID }) {
      projects.append(Project(id: pitchID, deck: .bundled(), updatedAt: .distantPast))
    }
    return projects.sorted { $0.updatedAt > $1.updatedAt }
  }

  static func save(_ deck: Deck, id: String) {
    guard !deck.slides.isEmpty else { return }
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let project = Project(id: id, deck: deck, updatedAt: .now)
    guard let data = try? encoder.encode(project) else { return }
    try? data.write(to: file(for: id), options: .atomic)
  }

  static func delete(_ id: String) {
    try? FileManager.default.removeItem(at: file(for: id))
  }

  /// The most recently edited project, for launch.
  static func latest() -> Project? {
    all().first
  }
}
