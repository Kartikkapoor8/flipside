import SwiftUI

extension StudioModel {
    /// The AI offers a card. Direct ones land after the current slide through the insert motion and
    /// the deck moves onto them; tentative ones wait in the pill under the notes.
    func offerSuggestion(_ s: AppState.Suggestion) {
        if s.kind == .direct { checkpoint() }
        withAnimation(Theme.land) { app.offer(s) }
        if s.kind == .direct { landOnInserted() }
    }

    func approveSuggestion() {
        checkpoint()
        withAnimation(Theme.land) { app.approvePending() }
        landOnInserted()
    }

    private func landOnInserted() {
        let at = min(app.currentIndex + 1, app.deck.slides.count - 1)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(380))
            withAnimation(DeskMotion.crossfade) { app.currentIndex = at }
        }
    }

    static let cannedTentative = AppState.Suggestion(title: "Parking nearby", body: "Two deeded spaces.\nGuest permits from the HOA.", kind: .tentative)
    static let cannedDirect = AppState.Suggestion(title: "Pricing", body: "$29 a month.\nFirst deck free.", kind: .direct)
}

/// "Added: Pricing" for two seconds after a direct suggestion lands.
struct SuggestionToast: View {
    let model: StudioModel
    @State private var shown: AppState.Suggestion?

    var body: some View {
        ZStack {
            if let shown {
                Label("Added: \(shown.title)", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 14).frame(height: 36)
                    .glassEffect(.regular, in: .capsule)
                    .transition(.opacity)
            }
        }
        .animation(Theme.land, value: shown?.id)
        .onChange(of: model.app.lastInserted?.id) { _, _ in
            guard let s = model.app.lastInserted else { return }
            shown = s
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if shown?.id == s.id { shown = nil }
            }
        }
        .allowsHitTesting(false)
    }
}

/// One line at the bottom of the notes: the offered title, Add, and a dismiss. Gone after 12 s.
struct SuggestionPill: View {
    let model: StudioModel

    var body: some View {
        ZStack {
            if let s = model.app.pendingSuggestion {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.coral)
                    Text(s.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    Spacer(minLength: 4)
                    Button { model.approveSuggestion() } label: {
                        Text("Add").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(height: 28)
                    }
                    .buttonStyle(DeskPressStyle())
                    .glassEffect(.regular.tint(Theme.coral).interactive(), in: .capsule)
                    Button { withAnimation(Theme.fade) { model.app.dismissPending() } } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.text)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(DeskPressStyle())
                    .glassEffect(.regular.interactive(), in: .circle)
                }
                .padding(.leading, 12).padding(.trailing, 4).padding(.vertical, 4)
                .glassEffect(.regular, in: .capsule)
                .transition(.opacity)
                .task(id: s.id) {
                    try? await Task.sleep(for: .seconds(12))
                    if model.app.pendingSuggestion?.id == s.id { withAnimation(Theme.fade) { model.app.dismissPending() } }
                }
            }
        }
        .animation(Theme.land, value: model.app.pendingSuggestion?.id)
    }
}
