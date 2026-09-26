import SwiftUI

@main
struct FlipsideApp: App {
    @State private var appState: AppState
    @State private var studio: StudioModel

    init() {
        // Demo-safe: always launch on the bundled pitch. Past projects stay one tap away on the home
        // screen (`-latest YES` restores launching on the most recent project).
        let project = UserDefaults.standard.bool(forKey: "latest") ? ProjectStore.latest() : nil
        let state = AppState(deck: project?.deck ?? .bundled())
        #if DEBUG
        // `-home YES` opens straight to the home screen, for checking it without folding the phone.
        if UserDefaults.standard.bool(forKey: "home") { state.isHome = true }
        #endif
        _appState = State(initialValue: state)
        _studio = State(initialValue: StudioModel(app: state, projectID: project?.id ?? ProjectStore.pitchID))
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
