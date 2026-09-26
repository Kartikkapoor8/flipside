import SwiftUI

/// The two faces. `ArrangementView` with the split style puts one child on each side of the
/// fold. The audience half is the current slide drawn upside down so it reads from across the
/// table; the presenter half is the control desk. `appState.audienceOnLeading` picks which
/// slot (primary is the top half in portrait) holds which face.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ArrangementView {
            face(isAudience: appState.audienceOnLeading)
        } secondary: {
            face(isAudience: !appState.audienceOnLeading)
        }
        .arrangementViewStyle(.split)
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    @ViewBuilder
    private func face(isAudience: Bool) -> some View {
        if isAudience {
            AudienceFace()
        } else {
            PresenterView()
        }
    }
}

/// Fills its half with the current slide, scaled to fill and rotated 180 degrees for the
/// person on the other side of the hinge. Overlays (laser dot) go here so they rotate with it.
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
