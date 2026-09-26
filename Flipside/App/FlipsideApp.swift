import SwiftUI

@main
struct FlipsideApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .onAppear {
                    #if DEBUG
                    DebugSnapshot.armIfRequested()
                    #endif
                }
        }
    }
}
