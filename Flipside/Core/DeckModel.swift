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

/// Where an element sits on a slide, in normalized slide coordinates (0...1, origin top-left).
/// Added by the Studio editor for free-move editing.
struct ElementFrame: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
    /// Width as a fraction of slide width.
    var width: Double
    /// Height as a fraction of slide height. Only images use it; text sizes itself.
    var height: Double = 0
    var scale: Double = 1
    var rotation: Double = 0
}

/// A video, image or animation preset inserted onto a slide from the presenter desk.
struct SlideMedia: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case image
        case video
        case animation
    }

    var kind: Kind
    /// Image: a URL or image prompt. Video: a bundled file name or URL. Animation: the preset name.
    var source: String
    var title: String
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

    // Added by the Studio editor (Audience/Editor). All optional; decks without them decode unchanged.
    /// Element id ("title", "body.0", "image") to a user-moved frame. Missing means the layout default.
    var positions: [String: ElementFrame]? = nil
    /// Element ids the user removed from the slide.
    var hidden: [String]? = nil
    /// What the generated picture on this slide should show. Nil means no generated image.
    var imagePrompt: String? = nil
    /// Resolved image for `imagePrompt`.
    var imageURL: String? = nil
    /// Media inserted from the presenter desk, shown as a card on the crease side.
    var media: SlideMedia? = nil
    /// Section this slide belongs to ("The fold"). Consecutive slides sharing one form a tab on the
    /// desk; slides without one stand alone under their title. Added 2026-09-26 for quick jump.
    var section: String? = nil
    /// A drawn scene for the visual slot ("fold", "cover"), looked up in SceneRegistry. Added 2026-09-26.
    var scene: String? = nil

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
        positions = try? c.decodeIfPresent([String: ElementFrame].self, forKey: .positions)
        hidden = try? c.decodeIfPresent([String].self, forKey: .hidden)
        imagePrompt = try? c.decodeIfPresent(String.self, forKey: .imagePrompt)
        imageURL = try? c.decodeIfPresent(String.self, forKey: .imageURL)
        media = try? c.decodeIfPresent(SlideMedia.self, forKey: .media)
        section = try? c.decodeIfPresent(String.self, forKey: .section)
        scene = try? c.decodeIfPresent(String.self, forKey: .scene)
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
