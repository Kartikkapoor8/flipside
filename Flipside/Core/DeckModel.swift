import Foundation

/// Shared deck schema. Frozen after 11:45. Add fields only; never rename or remove one.
/// Matches `assets/deck/deck.json`: id, layout, title, body, notes, cue, durationHint.
enum SlideLayout: String, Codable, CaseIterable, Sendable {
    case cover
    case statement
    case twoColumn = "two-column"
    case live
    case close

    /// Tolerant decoding: `deck.json` v1 used "split" for the two-column layout, and generated
    /// decks may hand back something unexpected. Unknown values fall back to `statement`.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SlideLayout(rawValue: raw) ?? SlideLayout.alias(raw) ?? .statement
    }

    private static func alias(_ raw: String) -> SlideLayout? {
        switch raw.lowercased() {
        case "split", "twocolumn", "two_column", "columns": return .twoColumn
        case "title", "hero": return .cover
        case "closing", "end": return .close
        default: return nil
        }
    }
}

struct Slide: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var layout: SlideLayout
    var title: String
    var body: String
    var notes: String
    var cue: String
    /// Seconds the presenter expects to spend on this slide.
    var durationHint: Int

    init(
        id: String = UUID().uuidString,
        layout: SlideLayout = .statement,
        title: String = "",
        body: String = "",
        notes: String = "",
        cue: String = "",
        durationHint: Int = 30
    ) {
        self.id = id
        self.layout = layout
        self.title = title
        self.body = body
        self.notes = notes
        self.cue = cue
        self.durationHint = durationHint
    }

    /// Missing optional-ish fields decode to empty rather than failing the whole deck.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        layout = try c.decodeIfPresent(SlideLayout.self, forKey: .layout) ?? .statement
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        cue = try c.decodeIfPresent(String.self, forKey: .cue) ?? ""
        durationHint = try c.decodeIfPresent(Int.self, forKey: .durationHint) ?? 30
    }
}

struct Deck: Codable, Hashable, Sendable {
    var title: String
    var slides: [Slide]

    init(title: String, slides: [Slide]) {
        self.title = title
        self.slides = slides
    }

    /// Accepts either `{ "title": ..., "slides": [...] }` or a bare `[ slide, ... ]`
    /// (the shape of `deck.json` and `fallback-deck.json`). When bare, the title is the
    /// first slide's title.
    init(from decoder: Decoder) throws {
        if let slides = try? decoder.singleValueContainer().decode([Slide].self) {
            self.init(title: slides.first?.title ?? "Untitled", slides: slides)
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let slides = try c.decodeIfPresent([Slide].self, forKey: .slides) ?? []
        let title = try c.decodeIfPresent(String.self, forKey: .title) ?? slides.first?.title ?? "Untitled"
        self.init(title: title, slides: slides)
    }

    static let empty = Deck(title: "Untitled", slides: [])

    /// Loads `<name>.json` from the app bundle (files copied into `Flipside/Resources`).
    static func load(named name: String, bundle: Bundle = .main) throws -> Deck {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw DeckError.missingResource(name)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Deck.self, from: data)
    }

    /// The pitch deck, then the fallback deck, then a single placeholder slide.
    /// Never throws so the app always has something to show.
    static func bundled() -> Deck {
        if let deck = try? load(named: "deck"), !deck.slides.isEmpty { return deck }
        if let deck = try? load(named: "fallback-deck"), !deck.slides.isEmpty { return deck }
        return Deck(title: "Flipside", slides: [
            Slide(id: "cover", layout: .cover, title: "Flipside",
                  body: "The show on their side. The notes on yours.",
                  notes: "deck.json did not load. Check Flipside/Resources.")
        ])
    }

    enum DeckError: Error, LocalizedError {
        case missingResource(String)
        var errorDescription: String? {
            switch self {
            case .missingResource(let n): return "No \(n).json in the app bundle."
            }
        }
    }
}
