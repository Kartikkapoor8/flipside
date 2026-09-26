import SwiftUI

/// The trackpad. A finger on it writes a normalized point (0...1 in both axes, origin top-left
/// of the un-rotated slide) into `appState.laserPoint`; lifting clears it. Top-left of the pad
/// is top-left of the slide as the presenter sees it in the live copy; the audience half's
/// 180 degree rotation carries the dot to the matching spot from their side.
struct LaserPadView: View {
    @Environment(AppState.self) private var appState
    @State private var isTouching = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous)
                    .fill(Brand.Presenter.surface)
                DotGrid()
                    .padding(Brand.Space.s3)
                    .opacity(0.5)
                VStack(spacing: Brand.Space.s1) {
                    Label("Laser", systemImage: "sun.max.fill")
                        .font(Brand.Font.uiLabel)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(isTouching ? Brand.Presenter.accent : Brand.Presenter.muted)
                    Text(isTouching ? "Pointing" : "Touch to point")
                        .font(Brand.Font.caption)
                        .foregroundStyle(Brand.Presenter.muted)
                }
                if let p = appState.laserPoint, isTouching {
                    Circle()
                        .fill(Brand.Presenter.accent)
                        .frame(width: 14, height: 14)
                        .position(x: p.x * proxy.size.width, y: p.y * proxy.size.height)
                        .allowsHitTesting(false)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous)
                    .strokeBorder(isTouching ? Brand.Presenter.accent : Brand.Crease.dark, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        isTouching = true
                        appState.laserPoint = CGPoint(
                            x: min(max(value.location.x / proxy.size.width, 0), 1),
                            y: min(max(value.location.y / proxy.size.height, 0), 1)
                        )
                    }
                    .onEnded { _ in
                        isTouching = false
                        appState.laserPoint = nil
                    }
            )
        }
        .accessibilityLabel("Laser trackpad")
    }
}

/// Faint dot grid so the pad reads as a surface, not a dead panel.
private struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 18
            var x: CGFloat = step / 2
            while x < size.width {
                var y: CGFloat = step / 2
                while y < size.height {
                    context.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                                 with: .color(Brand.Presenter.muted.opacity(0.35)))
                    y += step
                }
                x += step
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    LaserPadView()
        .environment(AppState())
        .frame(width: 236, height: 220)
        .padding()
        .background(Brand.Presenter.background)
}
