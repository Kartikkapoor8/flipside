import SwiftUI

/// Home, when no deck is open. Matches design/home-mockup.png in brand colour: serif greeting,
/// the mic capsule as the hero, a chip row, recent decks as a 2 by 2 grid.
///
/// - Flat: one widescreen canvas, greeting and capsule left, grid right.
/// - Laptop pose: the grid on the far half, the capsule on the near half.
///
/// The mic is the gesture. Tap it and the capsule morphs (matchedGeometryEffect, 400 ms) into the
/// chat from Generate/ (his HomeChat and HomeComposer); while the deck builds the card glows, and
/// when it finishes the card morphs into the desk's AI card. The desk's AI card opens the same chat.
struct DeckHomeView: View {
    enum Part { case canvas, grid, topic }

    let part: Part
    let namespace: Namespace.ID
    @Environment(AppState.self) private var appState
    @Environment(StudioModel.self) private var studio
    @State private var chatOpen = false
    @State private var startedHere = false

    var body: some View {
        ZStack {
            PaperBackdrop()
            switch part {
            case .canvas:
                HStack(alignment: .top, spacing: 24) {
                    lead
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    RecentDecks(namespace: namespace)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.top, 8)
                }
                .padding(24)
            case .grid:
                RecentDecks(namespace: namespace, showsMark: true)
                    .padding(16)
            case .topic:
                lead
                    .padding(16)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .flipsideDebugChat)) { _ in
            if chatOpen { withAnimation(HomeMotion.morph) { chatOpen = false } } else { open(speaking: false) }
        }
        .onChange(of: appState.isGenerating) { _, generating in
            // The deck finished building here: the card becomes the desk.
            guard !generating, startedHere, !appState.deck.slides.isEmpty else { return }
            startedHere = false
            withAnimation(HomeMotion.morph) { appState.isHome = false }
        }
    }

    private var lead: some View {
        VStack(alignment: .leading, spacing: 18) {
            if part != .grid { HomeGreeting(compact: part == .topic) }
            ZStack(alignment: .top) {
                if chatOpen {
                    ChatCard(namespace: namespace, onClose: { withAnimation(HomeMotion.morph) { chatOpen = false } }, onSend: start)
                        .transition(.opacity)
                } else {
                    TopicCapsule(namespace: namespace) { open(speaking: false) }
                        .transition(.opacity)
                }
            }
            if !chatOpen {
                HStack(spacing: 10) {
                    HomeChip("Paste a link", "link") { pasteLink() }
                    HomeChip("Type a topic", "pencil") { open(speaking: false) }
                    HomeChip("Start speaking", "waveform") { open(speaking: true) }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Spacer(minLength: 0)
        }
        .animation(HomeMotion.morph, value: chatOpen)
    }

    private func open(speaking: Bool) {
        withAnimation(HomeMotion.morph) { chatOpen = true }
        if speaking, studio.mic.state == .idle { studio.mic.toggle() }
    }

    private func pasteLink() {
        if let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            studio.prompt = text
        }
        open(speaking: false)
    }

    /// His `startProject`, minus leaving home: the phone stays here, glowing, until the deck is built.
    private func start(_ request: String) {
        let request = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty, !appState.isGenerating else { return }
        ProjectStore.save(appState.deck, id: studio.projectID)
        studio.selection = nil
        studio.editing = nil
        studio.projectID = UUID().uuidString
        appState.deck = Deck(title: request, slides: [])
        appState.reset()
        studio.buildingFromHome = false
        studio.askBuilds = true
        startedHere = true
        studio.send(request)
    }
}

enum HomeMotion {
    /// Capsule to chat card to desk: one spring, 400 ms.
    static let morph = Animation.spring(duration: 0.4, bounce: 0.15)
}

// MARK: - Greeting

private struct HomeGreeting: View {
    var compact: Bool

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                HStack(spacing: 10) {
                    FlipsideMark()
                    Text("Flipside")
                        .font(Brand.Font.display(compact ? 20 : 24))
                        .foregroundStyle(Theme.text)
                }
                .padding(.bottom, compact ? 4 : 14)
                Text("\(greeting(for: context.date)),\nKartik.")
                    .font(Brand.Font.display(compact ? 34 : 48))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(-2)
                Text("Great things happen on the other side.")
                    .font(Brand.Font.displayItalic(compact ? 15 : 18))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func greeting(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Late night"
        }
    }
}

// MARK: - The capsule, the chat card

/// The hero: a glass capsule with the mic. Tapping anywhere opens the chat.
private struct TopicCapsule: View {
    let namespace: Namespace.ID
    let action: () -> Void
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.coral)
                .frame(width: 56, height: 56)
                .glassEffect(.regular.tint(Theme.coral.opacity(0.10)), in: .circle)
                .matchedGeometryEffect(id: "home.mic", in: namespace)
            VStack(alignment: .leading, spacing: 3) {
                Text("What are we presenting?")
                    .font(Brand.Font.display(24))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Ask Flipside anything…")
                    .font(Brand.Font.displayItalic(15))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 36, height: 36)
                .glassEffect(.regular, in: .circle)
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
        .hingeHighlight(RoundedRectangle(cornerRadius: 26, style: .continuous), angle: appState.hingeAngle)
        .matchedGeometryEffect(id: "home.chat", in: namespace)
        .deskPress(perform: action)
        .accessibilityLabel("What are we presenting? Tap to speak or type.")
    }
}

/// The chat from Generate/ inside one glass card. Used on the home screen and over the desk.
struct ChatCard: View {
    let namespace: Namespace.ID
    var onClose: () -> Void
    var onSend: (String) -> Void
    @Environment(AppState.self) private var appState
    @Environment(StudioModel.self) private var studio

    var body: some View {
        @Bindable var studio = studio
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Waveform(level: studio.mic.level, live: studio.mic.isLive)
                    .frame(width: 44, height: 18)
                    .matchedGeometryEffect(id: "home.mic", in: namespace)
                Text(appState.isGenerating ? "Building your deck" : (studio.mic.isLive ? "Listening" : "Ask Flipside"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(studio.mic.isLive || appState.isGenerating ? Theme.coral : Theme.text)
                    .contentTransition(.opacity)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.text)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Close")
            }
            HomeChat(model: studio)
            HomeComposer(model: studio, onSend: onSend)
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .borderBeam(.md, colorVariant: .colorful, strength: 0.9, active: appState.isGenerating, cornerRadius: 26)
        .matchedGeometryEffect(id: "home.chat", in: namespace)
    }
}

private struct HomeChip: View {
    let title: String
    let symbol: String
    let action: () -> Void

    init(_ title: String, _ symbol: String, action: @escaping () -> Void) {
        self.title = title; self.symbol = symbol; self.action = action
    }

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.text)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            .deskPress(perform: action)
    }
}

// MARK: - Recent decks

private struct HomeDeck: Identifiable {
    enum Status { case ready, edited, draft }
    let id: String
    let deck: Deck
    let kind: String
    let status: Status
}

/// Our pitch plus the three example decks bundled in Resources, 2 by 2. Thumbnails are each
/// deck's cover card through the audience renderer.
private struct RecentDecks: View {
    let namespace: Namespace.ID
    var showsMark = false
    @Environment(AppState.self) private var appState
    @Environment(StudioModel.self) private var studio

    private static let decks: [HomeDeck] = {
        var list: [HomeDeck] = [HomeDeck(id: ProjectStore.pitchID, deck: .bundled(), kind: "Pitch deck", status: .ready)]
        let edited = Set(ProjectStore.all().filter { $0.updatedAt > .distantPast }.map(\.id))
        for (name, kind) in [("example-realtor", "Listing tour"), ("example-founder", "Investor deck"), ("example-clinic", "Patient talk")] {
            if let deck = try? Deck.load(named: name) {
                list.append(HomeDeck(id: name, deck: deck, kind: kind, status: edited.contains(name) ? .edited : .draft))
            }
        }
        return list
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if showsMark { FlipsideMark() }
                Text("RECENT DECKS")
                    .font(.system(size: 11, weight: .bold)).tracking(1.4)
                    .foregroundStyle(Theme.textSecondary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Self.decks) { item in
                    DeckCard(item: item, hingeAngle: appState.hingeAngle) {
                        withAnimation(HomeMotion.morph) {
                            studio.projectID = item.id
                            appState.open(item.deck)
                        }
                    }
                }
            }
        }
    }
}

private struct DeckCard: View {
    let item: HomeDeck
    let hingeAngle: Double
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let cover = item.deck.slides.first {
                    SlideView(slide: cover, animated: false, aspect: 1, cornerRadius: 12)
                } else {
                    RoundedRectangle(cornerRadius: 12).fill(Theme.sunken)
                }
            }
            .frame(width: 64, height: 64)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.deck.title)
                    .font(Brand.Font.display(17))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text("\(item.deck.slides.count) slides · \(item.kind)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                StatusPill(status: item.status)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
        .hingeHighlight(RoundedRectangle(cornerRadius: 18, style: .continuous), angle: hingeAngle)
        .deskPress(perform: action)
        .accessibilityLabel("\(item.deck.title), \(item.deck.slides.count) slides")
    }
}

private struct StatusPill: View {
    let status: HomeDeck.Status

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(dot).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(dot.opacity(0.12)))
    }

    private var label: String {
        switch status {
        case .ready: "Ready to present"
        case .edited: "Edited"
        case .draft: "Draft"
        }
    }

    private var dot: Color {
        switch status {
        case .ready: Theme.mint
        case .edited: Theme.violet
        case .draft: Theme.textSecondary
        }
    }
}
