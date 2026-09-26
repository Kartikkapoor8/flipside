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

    /// Home from the desk: the session view morphs back into the home screen, deck saved.
    func goHome() {
        ProjectStore.save(app.deck, id: projectID)
        withAnimation(HomeMotion.morph) {
            app.laserPoint = nil
            app.clientPoint = nil
            app.mode = .present
            app.isHome = true
        }
    }

    /// Ends the session without the hinge.
    func endMeeting() {
        guard !app.isHome else { return }
        withAnimation(Theme.fade) {
            app.laserPoint = nil
            app.mode = .ended
        }
    }
}

/// The whole inner display when the fold closes on an open deck, or End is pressed. A small glass
/// field takes their email or number; Send collapses it into a pill that draws a check and says
/// "Summary sent", which fades after 2 s and the phone returns to Home.
struct MeetingEndedView: View {
    @Environment(AppState.self) private var appState
    @Environment(StudioModel.self) private var studio
    @State private var address = ""
    @State private var sent = false
    @FocusState private var focused: Bool

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
                if sent {
                    HStack(spacing: 8) {
                        CheckMark().frame(width: 16, height: 16)
                        Text("Summary sent")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text)
                    }
                    .padding(.horizontal, 16).frame(height: 40)
                    .glassEffect(.regular.tint(Theme.mint.opacity(0.18)), in: .capsule)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    HStack(spacing: 8) {
                        TextField("Their email or number", text: $address)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .focused($focused)
                            .submitLabel(.send)
                            .onSubmit(send)
                            .frame(minWidth: 180)
                        Button(action: send) {
                            Text("Send")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14).frame(height: 32)
                        }
                        .buttonStyle(DeskPressStyle())
                        .glassEffect(.regular.tint(Theme.ink).interactive(), in: .capsule)
                        .accessibilityLabel("Send the recap")
                    }
                    .padding(.leading, 14).padding(.trailing, 4).padding(.vertical, 4)
                    .glassEffect(.regular, in: .capsule)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 28).padding(.vertical, 24)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .hingeHighlight(RoundedRectangle(cornerRadius: 22, style: .continuous), angle: appState.hingeAngle)
            // Clear of the seam chip, which sits at the exact centre.
            .offset(y: -150)
            .animation(HomeMotion.morph, value: sent)
        }
        .transition(.opacity)
        .onReceive(NotificationCenter.default.publisher(for: .flipsideDebugSent)) { _ in send() }
    }

    /// No recap sender exists in Generate/ yet, so this plays the animation and goes Home.
    private func send() {
        guard !sent else { return }
        focused = false
        withAnimation(HomeMotion.morph) { sent = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            studio.goHome()
        }
    }
}

/// A check that draws itself on the 400 ms spring.
private struct CheckMark: View {
    @State private var drawn = false

    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 1, y: 9))
            p.addLine(to: CGPoint(x: 6, y: 14))
            p.addLine(to: CGPoint(x: 15, y: 3))
        }
        .trim(from: 0, to: drawn ? 1 : 0)
        .stroke(Theme.mint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        .onAppear { withAnimation(HomeMotion.morph.delay(0.1)) { drawn = true } }
    }
}

extension Notification.Name {
    /// Stage: presses Send on the ended card.
    static let flipsideDebugSent = Notification.Name("flipside.debugSent")
}
