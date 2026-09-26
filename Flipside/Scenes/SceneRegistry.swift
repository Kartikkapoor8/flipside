import SwiftUI

/// Living scenes for the pitch deck, one per slide id, drawn in SwiftUI. The audience renderer asks
/// here once per slide; a nil answer means the default visual.
enum SceneRegistry {
    static let ids: Set<String> = ["fold", "cover", "generate", "close", "problem", "point"]

    static func has(_ slide: Slide) -> Bool {
        slide.scene.map(ids.contains) ?? false
    }

    /// The scene in the visual slot: below the title, most of the width, growing in from the crease
    /// once the title has landed.
    @ViewBuilder
    static func view(for slide: Slide, canvas: CGSize, animated: Bool, laser: CGPoint?) -> some View {
        if let name = slide.scene, ids.contains(name) {
            let title = SlideLayoutEngine.frame(for: SlideElement(kind: .title), in: slide, canvas: canvas)
            let hasBody = !slide.bodyLines.isEmpty
            let top = min(title.y + (hasBody ? 0.22 : 0.12), 0.5)
            let height = max(0.95 - top, 0.3)
            SceneSlot(name: name, laser: laser, animated: animated)
                .environment(\.sceneLive, animated)
                .frame(width: canvas.width * 0.86, height: canvas.height * height)
                .position(x: canvas.width * 0.5, y: canvas.height * (top + height / 2))
        }
    }
}

/// Picks the scene and runs its entrance: hidden while the title lands, then grows from the crease.
private struct SceneSlot: View {
    let name: String
    let laser: CGPoint?
    let animated: Bool
    @State private var shown = false

    var body: some View {
        Group {
            switch name {
            case "fold": FoldScene()
            case "cover": CoverScene()
            case "generate": GenerateScene()
            case "close": CloseScene()
            case "problem": ProblemScene()
            case "point": PointScene(laser: laser)
            default: EmptyView()
            }
        }
        .scaleEffect(shown ? 1 : 0.6, anchor: .trailing)
        .opacity(shown ? 1 : 0)
        .task {
            if animated {
                try? await Task.sleep(for: .milliseconds(420))
                withAnimation(.spring(duration: 0.5, bounce: 0.18)) { shown = true }
            } else {
                shown = true
            }
        }
    }
}

/// Shared idle clock, so every scene breathes on the same slow beat. Thumbnails and the live
/// monitor are not live: they draw one still frame, so six small copies never animate at once.
struct SceneClock<Content: View>: View {
    @ViewBuilder var content: (TimeInterval) -> Content
    @Environment(\.sceneLive) private var live
    var body: some View {
        if live {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                content(context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            content(0)
        }
    }
}

private struct SceneLiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False for thumbnails: scenes draw a still and run no timers or entrance tasks.
    var sceneLive: Bool {
        get { self[SceneLiveKey.self] }
        set { self[SceneLiveKey.self] = newValue }
    }
}
