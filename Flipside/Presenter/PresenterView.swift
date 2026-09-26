import SwiftUI

/// The desk: the presenter's half while the phone stands. Nothing to tap to advance; the app
/// listens for the cue. Top to bottom: AI bar, notes, queue, bottom bar. The live monitor sits
/// in the top corner while the hinge is partially open. The fold drives the morph toward the
/// editor; at 0.85 the mode flips and RootView hands the half to the editor.
struct PresenterView: View {
    @Environment(AppState.self) private var appState
    @Environment(StudioModel.self) private var studio
    @Environment(\.isWideFace) private var isWide
    let namespace: Namespace.ID

    @State private var pointerShown = false
    /// Slide id the cue was heard for, so it fires once per slide.
    @State private var cueMatchedFor: String?
    @State private var advanceTask: Task<Void, Never>?

    var body: some View {
        let morph = DeskMorph(foldProgress: appState.foldProgress)
        GeometryReader { proxy in
            let frames = DeskFrames.compute(size: proxy.size, wide: isWide, morph: morph)
            ZStack(alignment: .topLeading) {
                PaperBackdrop()
                AIBar(model: studio)
                    .deskFrame(frames.aiBar)
                    .opacity(frames.aiBarOpacity)
                NotesCard(model: studio, editing: appState.mode == .edit, cueMatched: cueMatchedFor == studio.current?.id)
                    .matchedGeometryEffect(id: "desk.notes", in: namespace)
                    .deskFrame(frames.notes)
                    .overlay {
                        if pointerShown {
                            PointerSheet(model: studio, shown: $pointerShown)
                                .deskFrame(frames.notes)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                QueueStrip(model: studio, verticalness: morph.queueTurn, namespace: namespace)
                    .deskFrame(frames.queue)
                DeskBar(model: studio, pointerShown: $pointerShown)
                    .deskFrame(frames.bar)
                    .opacity(frames.barOpacity)
                    .allowsHitTesting(frames.barOpacity > 0.5)
            }
            .overlay(alignment: .topTrailing) {
                if appState.hingeStatus == .partiallyOpen && appState.mode == .present {
                    LiveMonitor(model: studio, namespace: namespace)
                        .frame(width: isWide ? 150 : 128)
                        .padding(.top, DeskFrames.pad + DeskFrames.aiBarHeight + 6)
                        .padding(.trailing, DeskFrames.pad + 4)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(Theme.fade, value: appState.hingeStatus)
            .animation(Theme.land, value: appState.mode)
        }
        .clipped()
        .task(id: appState.mode) { await runClock() }
        .task { autoListen() }
        .onChange(of: studio.mic.transcript) { _, text in checkCue(in: text) }
        .onChange(of: appState.currentIndex) { _, _ in
            advanceTask?.cancel()
            if cueMatchedFor != studio.current?.id { cueMatchedFor = nil }
        }
        .onReceive(NotificationCenter.default.publisher(for: .flipsideDebugCue)) { _ in
            fireCue()
        }
    }

    // MARK: Cue

    private func checkCue(in transcript: String) {
        guard appState.mode == .present, let slide = studio.current,
              cueMatchedFor != slide.id, !slide.cue.isEmpty,
              CueMatcher.matches(cue: slide.cue, transcript: transcript) else { return }
        fireCue()
    }

    /// The pill fills, then the deck advances a beat later so the presenter sees it land.
    private func fireCue() {
        guard let slide = studio.current, cueMatchedFor != slide.id else { return }
        withAnimation(Theme.land) { cueMatchedFor = slide.id }
        advanceTask?.cancel()
        advanceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled, studio.current?.id == slide.id else { return }
            withAnimation(DeskMotion.crossfade) { appState.next() }
        }
    }

    /// Start listening as soon as the desk shows, once. If the mic is unavailable the bar says so
    /// and the seam chip's Cue button drives the same visual.
    private func autoListen() {
        guard studio.mic.state == .idle, appState.mode == .present else { return }
        studio.mic.start()
    }

    // MARK: Clock

    private func runClock() async {
        guard appState.mode == .present else { return }
        let clock = ContinuousClock()
        var last = clock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            let now = clock.now
            let delta = now - last
            last = now
            appState.elapsed += Double(delta.components.seconds) + Double(delta.components.attoseconds) / 1e18
        }
    }
}

/// Brand Paper with the same soft colour wash the editor's desk uses, so the glass has something
/// to refract and both halves read as one app.
struct PaperBackdrop: View {
    var body: some View {
        ZStack {
            Theme.background
            Circle().fill(Theme.violet.opacity(0.16)).frame(width: 420).blur(radius: 120).offset(x: -160, y: -200)
            Circle().fill(Theme.coral.opacity(0.14)).frame(width: 380).blur(radius: 120).offset(x: 200, y: 220)
        }
        .ignoresSafeArea()
    }
}

extension Notification.Name {
    /// DEBUG: the seam chip posts this to simulate hearing the cue.
    static let flipsideDebugCue = Notification.Name("flipside.debugCue")
}
