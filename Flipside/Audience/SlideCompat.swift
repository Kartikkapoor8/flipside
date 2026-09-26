import Foundation

/// Studio's view of the shared `Slide`: `body` is one string in the schema; the editor works in lines.
extension Slide {
  /// Placeholder for a line that exists but has no text yet, so an empty new line survives the round trip.
  static let emptyLineMarker = "\u{200B}"

  /// `body` split on line breaks. Setting it joins the lines back into `body`.
  var bodyLines: [String] {
    get {
      guard !body.isEmpty else { return [] }
      return body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
    set {
      body = newValue.map { $0.isEmpty ? Slide.emptyLineMarker : $0 }.joined(separator: "\n")
    }
  }

  func isHidden(_ element: String) -> Bool { hidden?.contains(element) ?? false }
}

extension String {
  /// True for a line with no visible text (including the empty-line marker).
  var isBlankLine: Bool {
    trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: Slide.emptyLineMarker))).isEmpty
  }
}
