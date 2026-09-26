import SwiftUI

/// Home, when no deck is open. Flat: one widescreen canvas across both halves. Laptop pose:
/// the deck grid on the far half and the topic tile with the AI bar on the near half.
/// Tapping a deck opens it into the desk as a morph (the cover card becomes the live monitor).
struct HomeView: View {
    enum Part { case canvas, grid, topic }

    let part: Part
    let namespace: Namespace.ID
    @Environment(AppState.self) private var appState
    @Environment(StudioModel.self) private var studio

    var body: some View {
        ZStack {
            PaperBackdrop()
            switch part {
            case .canvas:
                HStack(alignment: .top, spacing: 16) {
                    HomeLead(namespace: namespace)
                        .frame(maxWidth: .infinity)
                    VStack(spacing: 12) {
                        DeckGrid(columns: 3)
                        TopicTile()
                            .frame(height: 118)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(16)
            case .grid:
                VStack(alignment: .leading, spacing: 10) {
                    HomeHeader(compact: true)
                    DeckGrid(columns: 3)
                }
                .padding(12)
            case .topic:
                VStack(spacing: 10) {
                    HomeLead(namespace: namespace, compact: true)
                    TopicTile()
                        .frame(height: 110)
                }
                .padding(12)
            }
        }
    }
}

// MARK: - Lead column: clock, greeting, last deck

private struct HomeLead: View {
    let namespace: Namespace.ID
    var compact = false
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            HomeHeader(compact: compact)
            LastDeckCard(deck: appState.deck, namespace: namespace, compact: compact)
                .frame(maxHeight: .infinity)
        }
    }
}

private struct HomeHeader: View {
    var compact = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(Brand.Font.display(compact ? 30 : 44))
                        .foregroundStyle(Theme.text)
                        .contentTransition(.numericText())
                    Text("\(greeting(for: context.date)), Kartik.")
                        .font(.system(size: compact ? 12 : 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                FlipsideMark()
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

/// The last presented deck: a large cover thumbnail and Continue.
private struct LastDeckCard: View {
    let deck: Deck
    let namespace: Namespace.ID
    var compact: Bool
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LAST PRESENTED")
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
            ZStack {
                if let cover = deck.slides.first {
                    SlideView(slide: cover, animated: false, aspect: 1.6, cornerRadius: 10)
                } else {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.sunken)
                        .aspectRatio(1.6, contentMode: .fit)
                        .overlay(Text("Empty deck").font(.system(size: 12)).foregroundStyle(Theme.textSecondary))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line))
            .matchedGeometryEffect(id: "deck.cover", in: namespace)
            .frame(maxHeight: .infinity)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(deck.title)
                        .font(.system(size: compact ? 14 : 16, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text("\(deck.slides.count) slides · \(deck.slides.reduce(0) { $0 + $1.durationHint } / 60) min")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button {
                    withAnimation(Theme.land) { appState.open(deck) }
                } label: {
                    Label("Continue", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .glassEffect(.regular.tint(Theme.coral).interactive(), in: .capsule)
                .disabled(deck.slides.isEmpty)
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

// MARK: - Deck grid

/// Our pitch plus the example decks bundled in Resources.
private struct DeckGrid: View {
    let columns: Int
    @Environment(AppState.self) private var appState

    private static let decks: [Deck] = {
        var list: [Deck] = [Deck.bundled()]
        for name in ["example-realtor", "example-founder", "example-clinic"] {
            if let deck = try? Deck.load(named: name) { list.append(deck) }
        }
        return list
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DECKS")
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
                ForEach(Self.decks, id: \.title) { deck in
                    DeckTile(deck: deck) {
                        withAnimation(Theme.land) { appState.open(deck) }
                    }
                }
            }
        }
    }
}

private struct DeckTile: View {
    let deck: Deck
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                if let cover = deck.slides.first {
                    SlideView(slide: cover, animated: false, aspect: 1.6, cornerRadius: 8)
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.line))
                }
                Text(deck.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text("\(deck.slides.count) slides")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
    }
}

// MARK: - New from a topic

/// Say or type a topic. Opens an empty deck and streams the slides in through Generate/.
/// The BorderBeam glow runs while it builds.
private struct TopicTile: View {
    @Environment(AppState.self) private var appState
    @Environment(StudioModel.self) private var studio
    @State private var topic = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.coral)
                Text("New from a topic")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                if appState.isGenerating {
                    ThinkingOrb(state: studio.orbState ?? .working, size: 18)
                }
            }
            AIBar(model: studio, compact: true)
            HStack(spacing: 8) {
                TextField("A topic, or paste a link", text: $topic)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                    .focused($focused)
                    .submitLabel(.go)
                    .onSubmit(build)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .glassEffect(.regular, in: .capsule)
                Button(action: build) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .glassEffect(.regular.tint(canBuild ? Theme.ink : Theme.textSecondary.opacity(0.5)).interactive(), in: .circle)
                .disabled(!canBuild)
                .accessibilityLabel("Build the deck")
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .borderBeam(.md, colorVariant: .colorful, strength: 0.9, active: appState.isGenerating, cornerRadius: 18)
        .onChange(of: studio.mic.transcript) { _, text in
            if studio.mic.isLive, !text.isEmpty { topic = text }
        }
    }

    private var canBuild: Bool { !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !appState.isGenerating }

    private func build() {
        let request = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty else { return }
        withAnimation(Theme.land) {
            appState.open(Deck(title: request, slides: []))
        }
        studio.send(request)
        topic = ""
    }
}
