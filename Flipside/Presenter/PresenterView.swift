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
    /// The AI card opened into the chat from Generate/ (same morph as the home screen's capsule).
    @State private var chatOpen = false
    /// Slide id the cue was heard for, so it fires once per slide.
    @State private var cueMatchedFor: String?
    @State private var advanceTask: Task<Void, Never>?
    /// Word position in the transcript where the last section jump matched, so a name fires once.
    @State private var sectionMatchEnd = 0

    var body: some View {
        let morph = DeskMorph(foldProgress: appState.foldProgress)
        GeometryReader { proxy in
            // Shape from the half's own geometry: portrait (hinge horizontal) halves are wider than
            // tall and take the queue as a right column; landscape halves stack it under the notes.
            let wide = proxy.size.width > proxy.size.height
            let frames = DeskFrames.compute(size: proxy.size, wide: wide, morph: morph)
            ZStack(alignment: .topLeading) {
                PaperBackdrop()
                if !chatOpen {
                    AIBar(model: studio, onTap: { withAnimation(HomeMotion.morph) { chatOpen = true } })
                        .matchedGeometryEffect(id: "home.chat", in: namespace)
                        .deskFrame(frames.aiBar)
                        .opacity(frames.aiBarOpacity)
                }
                SectionStrip(model: studio)
                    .deskFrame(frames.tabs)
                NotesCard(model: studio, editing: appState.mode == .edit, cueMatched: cueMatchedFor == studio.current?.id)
                    .matchedGeometryEffect(id: "desk.notes", in: namespace)
                    .deskFrame(frames.notes)
                    .overlay {
                        // The overlay already has the notes card's size, so no extra frame.
                        if pointerShown {
                            PointerSheet(model: studio, shown: $pointerShown)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                // A wide half keeps the queue as a column even while standing.
                QueueStrip(model: studio, verticalness: wide ? 1 : morph.queueTurn, namespace: namespace)
                    .deskFrame(frames.queue)
                DeskBar(model: studio, pointerShown: $pointerShown)
                    .deskFrame(frames.bar)
                    .opacity(frames.barOpacity)
                    .allowsHitTesting(frames.barOpacity > 0.5)
                if chatOpen {
                    // The chat card grows out of the AI card and sits over the notes.
                    ChatCard(namespace: namespace, onClose: { withAnimation(HomeMotion.morph) { chatOpen = false } }, onSend: { studio.send($0) })
                        .frame(width: frames.aiBar.width)
                        .offset(x: frames.aiBar.minX, y: frames.aiBar.minY)
                        .transition(.opacity)
                }
            }
            .animation(HomeMotion.morph, value: chatOpen)
            .overlay(alignment: .topLeading) {
                if appState.hingeStatus == .partiallyOpen && appState.mode == .present {
                    LiveMonitor(model: studio, namespace: namespace)
                        .deskFrame(frames.monitor)
                        .opacity(frames.monitorOpacity)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(Theme.fade, value: appState.hingeStatus)
            .animation(Theme.land, value: appState.mode)
        }
        .clipped()
        .task(id: appState.mode) { await runClock() }
        .task { autoListen() }
        .onChange(of: studio.mic.transcript) { _, text in
            checkCue(in: text)
            checkSection(in: text)
        }
        .onChange(of: appState.isGenerating) { _, generating in
            // Asked the AI mid-pitch and it finished: the card folds back into the AI card.
            if !generating, chatOpen { withAnimation(HomeMotion.morph) { chatOpen = false } }
        }
        .onChange(of: appState.currentIndex) { _, _ in
            advanceTask?.cancel()
            if cueMatchedFor != studio.current?.id { cueMatchedFor = nil }
        }
        .onReceive(NotificationCenter.default.publisher(for: .flipsideDebugCue)) { _ in
            fireCue()
        }
        .onReceive(NotificationCenter.default.publisher(for: .flipsideDebugPointer)) { _ in
            withAnimation(.easeOut(duration: 0.3)) { pointerShown.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .flipsideDebugChat)) { _ in
            withAnimation(HomeMotion.morph) { chatOpen.toggle() }
        }
    }

    // MARK: Cue

    private func checkCue(in transcript: String) {
        guard appState.mode == .present, let slide = studio.current,
              cueMatchedFor != slide.id, !slide.cue.isEmpty,
              CueMatcher.matches(cue: slide.cue, transcript: transcript) else { return }
        fireCue()
    }

    /// "Let's go to the fold": a section name heard after the last jump moves the deck there.
    private func checkSection(in transcript: String) {
        guard appState.mode == .present else { return }
        let sections = appState.deck.sections
        guard sections.count > 1,
              let hit = CueMatcher.sectionMatch(in: transcript, sections: sections, after: sectionMatchEnd) else { return }
        sectionMatchEnd = hit.end
        guard !hit.section.contains(appState.currentIndex) else { return }
        studio.select(slide: hit.section.firstIndex)
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
        #if targetEnvironment(simulator)
        // No mic on stage: the card runs the stage transcript and the strip fires the cue.
        return
        #else
        guard studio.mic.state == .idle, appState.mode == .present else { return }
        studio.mic.start()
        #endif
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
    /// Stage script: opens the chat card (home capsule or desk AI card).
    static let flipsideDebugChat = Notification.Name("flipside.debugChat")
    /// Stage script: toggles the pointer sheet.
    static let flipsideDebugPointer = Notification.Name("flipside.debugPointer")
}
