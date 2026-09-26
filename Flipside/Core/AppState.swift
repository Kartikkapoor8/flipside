import Foundation
import Observation

/// One shared state object for the whole app. Injected via `.environment(appState)`.
/// Frozen after 11:45: add fields, say so in the commit, never rename or remove.
@Observable
@MainActor
final class AppState {
    enum Mode: String, Sendable {
        case present
        case edit
        case ended
    }

    /// Mirrors `DeviceHinge.Status`, kept as our own enum so views never import SwiftUICore
    /// just to compare hinge state.
    enum HingeStatus: String, Sendable {
        case closed
        case partiallyOpen
        case fullyOpen
    }

    var deck: Deck
    var currentIndex: Int = 0
    var mode: Mode = .present

    /// Degrees. 180 is flat, 0 is closed. Simulator reports 180 until posed.
    var hingeAngle: Double = 180
    var hingeStatus: HingeStatus = .fullyOpen

    /// Presenter's finger on the trackpad, normalized 0...1 in the audience slide's own
    /// (un-rotated) coordinate space. `nil` when lifted.
    var laserPoint: CGPoint? = nil

    /// The client's finger on the audience slide, normalized 0...1, drawn Verdigris on both halves.
    /// `nil` when lifted. Added 2026-09-26 for the point scene.
    var clientPoint: CGPoint? = nil

    /// True while a deck is streaming in from the model.
    var isGenerating: Bool = false

    /// Which half of the split holds the audience: `true` puts it in ArrangementView's primary
    /// slot, which is the top half in portrait (hinge horizontal) and the leading half in
    /// landscape (hinge vertical). Swap when the phone is turned around.
    var audienceOnLeading: Bool = true

    /// Draw the audience half upside down (the other person sits across the table). Off by default:
    /// they are beside you, reading the same half from the same side. Flip on the desk bar toggles it.
    /// Added 2026-09-26 for Block 2.
    var audienceFlipped: Bool = false

    /// Seconds since the session (or the last `reset()`) began.
    var elapsed: TimeInterval = 0

    /// A card the AI wants to add after the current slide. Direct ones land at once; tentative ones
    /// wait for the presenter's Add. Added 2026-09-26 for AI approval.
    struct Suggestion: Identifiable, Equatable, Sendable {
        enum Kind: Sendable { case direct, tentative }
        var id: String = UUID().uuidString
        var title: String
        var body: String
        var kind: Kind
    }
    var pendingSuggestion: Suggestion?
    /// The last suggestion that landed as a card, for the presenter's toast.
    var lastInserted: Suggestion?

    func offer(_ s: Suggestion) {
        switch s.kind {
        case .direct:
            insert(s)
        case .tentative:
            pendingSuggestion = s
        }
    }

    func approvePending() {
        guard let s = pendingSuggestion else { return }
        pendingSuggestion = nil
        insert(s)
    }

    func dismissPending() {
        pendingSuggestion = nil
    }

    private func insert(_ s: Suggestion) {
        let card = Slide(id: "suggest-\(s.id.prefix(6))", layout: .statement, title: s.title, body: s.body,
                         notes: s.body, durationHint: 20)
        let at = min(currentIndex + 1, deck.slides.count)
        deck.slides.insert(card, at: at)
        lastInserted = s
    }

    /// True when no deck is open: the home screen shows instead of the desk and slide.
    /// Added in Block 2 for the home screen. `open(_:)` clears it.
    var isHome: Bool = false

    init(deck: Deck = .bundled()) {
        self.deck = deck
    }

    // MARK: Derived

    var currentSlide: Slide {
        guard !deck.slides.isEmpty else { return Slide(id: "empty", layout: .cover, title: deck.title) }
        return deck.slides[clamped(currentIndex)]
    }

    var nextSlide: Slide? {
        let i = currentIndex + 1
        return deck.slides.indices.contains(i) ? deck.slides[i] : nil
    }

    var isOnLastSlide: Bool { currentIndex >= deck.slides.count - 1 }
    var slideCount: Int { deck.slides.count }

    // MARK: Actions

    func next() {
        guard currentIndex < deck.slides.count - 1 else { return }
        currentIndex += 1
    }

    func back() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    func go(to index: Int) {
        currentIndex = clamped(index)
    }

    func swapSides() {
        audienceOnLeading.toggle()
    }

    func flipAudience() {
        audienceFlipped.toggle()
    }

    /// Opens a deck from the home screen: replaces the working deck, resets the session, leaves home.
    func open(_ deck: Deck) {
        self.deck = deck
        reset()
        isHome = false
    }

    /// Back to the first slide, timer at zero, laser off, presenting.
    func reset() {
        currentIndex = 0
        elapsed = 0
        laserPoint = nil
        isGenerating = false
        mode = .present
    }

    private func clamped(_ i: Int) -> Int {
        min(max(i, 0), max(deck.slides.count - 1, 0))
    }
}
