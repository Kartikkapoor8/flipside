import SwiftUI

/// Placeholder until step 4. Just enough to prove the split and the model.
struct PresenterView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            Brand.Presenter.background.ignoresSafeArea()
            VStack(spacing: Brand.Space.s4) {
                Text("\(appState.currentIndex + 1) / \(appState.slideCount)")
                    .font(Brand.Font.uiLabel)
                    .foregroundStyle(Brand.Presenter.muted)
                Text(appState.currentSlide.notes)
                    .font(Brand.Font.presenterNotes)
                    .foregroundStyle(Brand.Presenter.text)
                    .multilineTextAlignment(.center)
                HStack {
                    Button("Back") { appState.back() }
                    Button("Next") { appState.next() }
                    Button("Swap") { appState.swapSides() }
                }
                .buttonStyle(.bordered)
                .tint(Brand.Presenter.accent)
            }
            .padding(Brand.Space.s5)
        }
    }
}
