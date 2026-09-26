import SwiftUI

@main
struct FlipsideApp: App {
    @State private var appState: AppState
    @State private var studio: StudioModel

    init() {
        // The last edited deck if there is one (Settings can reload the pitch deck), else the bundled pitch.
        let state = AppState(deck: DeckStore.load() ?? .bundled())
        _appState = State(initialValue: state)
        _studio = State(initialValue: StudioModel(app: state))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(studio)
                .studioSupport(studio)
                .onAppear {
                    #if DEBUG
                    DebugSnapshot.armIfRequested()
                    #endif
                }
        }
    }
}
