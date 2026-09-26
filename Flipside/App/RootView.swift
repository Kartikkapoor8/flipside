import SwiftUI
import os

/// The two faces. `ArrangementView` with the split style puts one child on each side of the
/// fold and publishes `splitArrangementAxis` to them:
///
/// - `.vertical`: halves stacked, hinge horizontal (portrait; laptop and flat poses). Primary is
///   the top half. Audience on top, presenter below, by default.
/// - `.horizontal`: halves side by side, hinge vertical (landscape). Primary is the leading half.
/// - `nil`: not split (the cover display, or a non-folding device). Falls back to a plain stack.
///
/// The audience face is rotated 180 in every case so it reads from across the hinge.
/// `appState.audienceOnLeading` decides which slot holds the audience.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ArrangementView {
            Face(isAudience: appState.audienceOnLeading)
        } secondary: {
            Face(isAudience: !appState.audienceOnLeading)
        }
        .arrangementViewStyle(.split)
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

/// One slot of the split. Reads the axis from the environment (only set inside the
/// arrangement's children) and hands it down so the presenter can pick a wide or tall layout.
struct Face: View {
    let isAudience: Bool
    @Environment(\.splitArrangementAxis) private var splitAxis

    var body: some View {
        Group {
            if isAudience {
                AudienceFace()
            } else {
                PresenterView()
            }
        }
        .environment(\.faceAxis, splitAxis)
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
/// tree (PresenterView) can read it without depending on where ArrangementView sets it.
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

/// Fills its half with the current slide, scaled to fill the width and rotated 180 degrees for
/// the person on the other side of the hinge. Overlays (laser dot) go here so they rotate too.
struct AudienceFace: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AudienceSlideView(slide: appState.currentSlide)
                LaserDotView(point: appState.laserPoint)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .rotationEffect(.degrees(180))
        }
        .background(Brand.Audience.background)
        .ignoresSafeArea()
    }
}

#Preview("Root") {
    RootView()
        .environment(AppState())
}
