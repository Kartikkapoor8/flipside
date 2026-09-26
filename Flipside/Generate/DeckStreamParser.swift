import Foundation

/// One instruction from the model. The model writes one JSON object per line:
///
///     {"op":"deck","title":"…"}                       start a new deck (clears the old one)
///     {"op":"add","layout":"…","title":"…","body":[…],"notes":"…","cue":"…","imagePrompt":"…"}
///     {"op":"replace","id":"…", …same fields…}         rewrite an existing slide
///     {"op":"delete","id":"…"}
///     {"op":"say","text":"…"}                         a short reply for the chat
///     {"op":"remember","text":"…"}                    a durable fact to keep in memory
struct DeckOp: Equatable {
  enum Kind: String {
    case deck, add, replace, delete, say, remember
  }

  var kind: Kind
  var id: String?
  var title: String?
  var layout: SlideLayout?
  var body: [String] = []
  var notes: String?
  var cue: String?
  var imagePrompt: String?
  var text: String?
  /// False while the line is still streaming.
  var complete: Bool
}

/// Turns streamed text into `DeckOp`s, including a partial op for the line still arriving,
/// so the title can land before the body and body lines appear one by one.
struct DeckStreamParser {
  private var buffer = ""

  /// Feeds a chunk. Returns the ops completed by it, plus the in-progress op if there is one.
  mutating func feed(_ chunk: String) -> (completed: [DeckOp], partial: DeckOp?) {
    buffer += chunk
    var done: [DeckOp] = []
    while let newline = buffer.firstIndex(of: "\n") {
      let line = String(buffer[..<newline])
      buffer = String(buffer[buffer.index(after: newline)...])
      if let op = Self.parse(line: line, complete: true) { done.append(op) }
    }
    return (done, Self.parse(line: buffer, complete: false))
  }

  mutating func finish() -> DeckOp? {
    defer { buffer = "" }
    return Self.parse(line: buffer, complete: true)
  }

  static func parse(line raw: String, complete: Bool) -> DeckOp? {
    let line = raw.trimmingCharacters(in: .whitespaces)
    guard line.hasPrefix("{") else { return nil }
    if complete, let data = line.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      return op(from: json, complete: true)
    }
    // Partial line: pull out whatever fields have fully arrived.
    var json: [String: Any] = [:]
    for key in ["op", "id", "title", "layout", "notes", "cue", "imagePrompt", "text"] {
      if let value = string(for: key, in: line) { json[key] = value }
    }
    json["body"] = bodyLines(in: line)
    return op(from: json, complete: false)
  }

  private static func op(from json: [String: Any], complete: Bool) -> DeckOp? {
    guard let kindRaw = json["op"] as? String, let kind = DeckOp.Kind(rawValue: kindRaw) else { return nil }
    return DeckOp(
      kind: kind,
      id: json["id"] as? String,
      title: json["title"] as? String,
      layout: (json["layout"] as? String).flatMap(SlideLayout.init(rawValue:)),
      body: (json["body"] as? [String]) ?? [],
      notes: json["notes"] as? String,
      cue: json["cue"] as? String,
      imagePrompt: (json["imagePrompt"] as? String).flatMap { $0.isEmpty ? nil : $0 },
      text: json["text"] as? String,
      complete: complete
    )
  }

  private static let stringPattern = #""((?:[^"\\]|\\.)*)""#

  private static func string(for key: String, in line: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: "\"\(key)\"\\s*:\\s*\(stringPattern)"),
          let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
          let range = Range(match.range(at: 1), in: line) else { return nil }
    return unescape(String(line[range]))
  }

  private static func bodyLines(in line: String) -> [String] {
    guard let start = line.range(of: #""body"\s*:\s*\["#, options: .regularExpression) else { return [] }
    var rest = String(line[start.upperBound...])
    if let end = rest.firstIndex(of: "]") { rest = String(rest[..<end]) }
    guard let regex = try? NSRegularExpression(pattern: stringPattern) else { return [] }
    return regex.matches(in: rest, range: NSRange(rest.startIndex..., in: rest)).compactMap { match in
      Range(match.range(at: 1), in: rest).map { unescape(String(rest[$0])) }
    }
  }

  private static func unescape(_ s: String) -> String {
    (try? JSONDecoder().decode(String.self, from: Data("\"\(s)\"".utf8))) ?? s
  }
}
