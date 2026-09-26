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

    /// True while a deck is streaming in from the model.
    var isGenerating: Bool = false

    /// Which half of the split holds the audience: `true` puts it in ArrangementView's primary
    /// (top / leading) slot. Default is the mockup: presenter on top, audience on the bottom half
    /// nearest the room. Swap when the phone is turned around.
    var audienceOnLeading: Bool = false

    /// Seconds since the session (or the last `reset()`) began.
    var elapsed: TimeInterval = 0

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
