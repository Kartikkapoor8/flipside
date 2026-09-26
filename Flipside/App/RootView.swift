import SwiftUI
import os

/// The app's one screen. Home when no deck is open; otherwise the two faces across the fold.
///
/// `ArrangementView` with the split style puts one child on each side of the fold and publishes
/// `splitArrangementAxis` to them: `.vertical` (stacked, hinge horizontal, portrait), `.horizontal`
/// (side by side, hinge vertical, landscape) or nil (not split). The audience face is drawn
/// rotated 180 while presenting so it reads from across the table; flat, it is the editable
/// artifact. `appState.audienceOnLeading` picks which slot holds the audience.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(StudioModel.self) private var studio
    @Namespace private var morph

    var body: some View {
        Group {
            if appState.mode == .ended {
                // Folded shut, or End pressed: the session is over on every face.
                MeetingEndedView()
            } else if appState.isHome && isFlat {
                // One widescreen canvas across both halves.
                DeckHomeView(part: .canvas, namespace: morph)
                    .transition(.opacity)
            } else if studio.layout == .auto {
                foldSplit
            } else {
                // The editor's layout menu pinned side by side or stacked, so Studio lays out the halves itself.
                StudioView(model: studio, presenting: appState.mode != .edit)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .monitorsHinge()
        #if DEBUG
        .task { await DebugSnapshot.runFoldScript(appState, studio: studio) }
        #endif
        .animation(Theme.land, value: appState.isHome)
        .animation(Theme.fade, value: appState.mode == .ended)
        .overlay(alignment: appState.isHome && isFlat && appState.mode != .ended ? .bottom : .center) {
            // Sits on the fold seam, which is the screen centre in both split axes; the flat home
            // canvas has no seam, so it drops to the bottom edge.
            HingeDebugView()
                .padding(.bottom, appState.isHome && isFlat ? 24 : 0)
        }
    }

    /// Follows the fold.
    private var foldSplit: some View {
        ArrangementView {
            Face(isAudience: appState.audienceOnLeading, namespace: morph)
        } secondary: {
            Face(isAudience: !appState.audienceOnLeading, namespace: morph)
        }
        .arrangementViewStyle(.split)
    }

    /// Flat on the table: the fold is inactive and the whole inner display is one canvas.
    private var isFlat: Bool {
        appState.hingeStatus == .fullyOpen || appState.hingeAngle >= ModeMapper.angle(forProgress: 0.85)
    }
}

/// One slot of the split. Reads the axis from the environment (only set inside the
/// arrangement's children) and hands it down so the desk can pick a wide or tall layout.
struct Face: View {
    let isAudience: Bool
    let namespace: Namespace.ID
    @Environment(\.splitArrangementAxis) private var splitAxis
    @Environment(AppState.self) private var appState
    @Environment(StudioModel.self) private var studio

    var body: some View {
        Group {
            if appState.isHome {
                // Laptop pose: the deck grid on the top half, the topic tile on the bottom half.
                DeckHomeView(part: isAudience ? .grid : .topic, namespace: namespace)
            } else if isAudience {
                // Upright by default. Flip (desk bar) turns it for someone across the table.
                StudioAudienceSlot(model: studio)
                    .rotationEffect(.degrees(appState.audienceFlipped ? 180 : 0))
                    .animation(.easeInOut(duration: 0.4), value: appState.audienceFlipped)
            } else if appState.mode == .edit {
                // Flat: the editor's desk (Editor/) takes the half.
                PresenterDesk(model: studio, editing: true)
                    .transition(.opacity)
            } else {
                PresenterView(namespace: namespace)
                    .transition(.opacity)
            }
        }
        .environment(\.faceAxis, splitAxis)
        .animation(Theme.fade, value: appState.mode)
        .onAppear { Self.log(splitAxis, isAudience: isAudience) }
        .onChange(of: splitAxis) { _, new in Self.log(new, isAudience: isAudience) }
    }

    private static let logger = Logger(subsystem: "dev.flipside", category: "layout")
    private static func log(_ axis: Axis?, isAudience: Bool) {
        let name = axis.map { $0 == .vertical ? "vertical (stacked, hinge horizontal)" : "horizontal (side by side, hinge vertical)" } ?? "nil (not split)"
        logger.info("splitArrangementAxis=\(name, privacy: .public) face=\(isAudience ? "audience" : "presenter", privacy: .public)")
        print("[layout] splitArrangementAxis=\(name) face=\(isAudience ? "audience" : "presenter")")
    }
}

/// The split axis this face lives in, re-published under our own key so views deeper in the
/// tree can read it without depending on where ArrangementView sets it.
struct FaceAxisKey: EnvironmentKey {
    static let defaultValue: Axis? = nil
}

extension EnvironmentValues {
    var faceAxis: Axis? {
        get { self[FaceAxisKey.self] }
        set { self[FaceAxisKey.self] = newValue }
    }

    /// True when this half is wider than it is tall: portrait phone, hinge horizontal.
    /// `nil` axis (unsplit) is treated as wide.
    var isWideFace: Bool { faceAxis != .horizontal }
}

#Preview("Root") {
    let state = AppState()
    RootView()
        .environment(state)
        .environment(StudioModel(app: state))
}
