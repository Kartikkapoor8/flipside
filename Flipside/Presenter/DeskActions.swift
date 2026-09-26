import SwiftUI

/// Desk actions that the stage strip and the desk share. Each wraps its state change in the same
/// animation the desk uses for that motion, so a faked event looks exactly like a real one.
extension StudioModel {
    /// "Client asked": a canned card lands right after the current slide, through the insert motion.
    func insertParkingCard() {
        checkpoint()
        let card = Slide(
            id: "parking-\(UUID().uuidString.prefix(6))",
            layout: .statement,
            title: "Parking",
            body: "Two spaces in the garage.\nStreet permits for guests.",
            notes: "They asked about parking. Two deeded spaces, guest permits from the HOA. Back to the tour after this.",
            cue: "back to the tour",
            durationHint: 20
        )
        let at = min(app.currentIndex + 1, app.deck.slides.count)
        withAnimation(Theme.land) {
            app.deck.slides.insert(card, at: at)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(380))
            withAnimation(DeskMotion.crossfade) { app.currentIndex = at }
        }
    }

    /// Laser on: a dot in the lower middle of their slide. Off: clears it.
    func toggleLaser() {
        withAnimation(DeskMotion.line) {
            app.laserPoint = app.laserPoint == nil ? CGPoint(x: 0.5, y: 0.58) : nil
        }
    }

    /// Replays a deck build through the streaming path. There are no saved runs on disk, so this is
    /// the offline writer's canned deck, forced even when a key is set so the stage is deterministic.
    func replayGeneration(topic: String = "A two-bedroom on Alder Street") {
        UserDefaults.standard.set(true, forKey: DeckGenerator.forceDemoKey)
        withAnimation(Theme.land) {
            app.open(Deck(title: topic, slides: []))
        }
        send(topic)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(30))
            UserDefaults.standard.removeObject(forKey: DeckGenerator.forceDemoKey)
        }
    }

    /// Ends the session without the hinge.
    func endMeeting() {
        withAnimation(Theme.fade) {
            app.laserPoint = nil
            app.mode = .ended
        }
    }
}

/// The whole inner display when the fold closes or End is pressed.
struct MeetingEndedView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            PaperBackdrop()
            VStack(spacing: 14) {
                FlipsideMark()
                Text("Meeting ended")
                    .font(Brand.Font.display(44))
                    .foregroundStyle(Theme.text)
                Text("\(appState.deck.title) · \(appState.slideCount) slides · \(PresenterClock.mmss(appState.elapsed))")
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
                Text("Recap on its way to them.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 28).padding(.vertical, 24)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .hingeHighlight(RoundedRectangle(cornerRadius: 22, style: .continuous), angle: appState.hingeAngle)
        }
        .transition(.opacity)
    }
}
