import SwiftUI

/// The trackpad, shown on demand over the notes. A drag moves the laser on their side; lifting
/// clears it. A tap without movement, a downward swipe, or the Done button dismisses it.
struct PointerSheet: View {
    let model: StudioModel
    @Binding var shown: Bool
    @State private var touch: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SlideDotGrid(spacing: 22, color: Theme.textSecondary.opacity(0.25), dot: 2)
                    .padding(10)
                VStack(spacing: 6) {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 22, weight: .semibold))
                    Text(touch == nil ? "Drag to point on their slide" : "Pointing")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Tap or swipe down to close")
                        .font(.system(size: 11))
                        .opacity(0.7)
                }
                .foregroundStyle(Theme.textSecondary)
                .opacity(touch == nil ? 1 : 0.25)
                if let touch {
                    ZStack {
                        Circle().fill(Color.red.opacity(0.25)).frame(width: 44, height: 44).blur(radius: 8)
                        Circle().fill(Color.red).frame(width: 16, height: 16)
                        Circle().fill(.white.opacity(0.9)).frame(width: 6, height: 6)
                    }
                    .position(touch)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let p = CGPoint(
                            x: min(max(value.location.x, 0), proxy.size.width),
                            y: min(max(value.location.y, 0), proxy.size.height)
                        )
                        touch = p
                        model.app.laserPoint = CGPoint(x: p.x / max(proxy.size.width, 1), y: p.y / max(proxy.size.height, 1))
                    }
                    .onEnded { value in
                        touch = nil
                        model.app.laserPoint = nil
                        let moved = hypot(value.translation.width, value.translation.height)
                        let swipedDown = value.translation.height > 90 && abs(value.translation.width) < value.translation.height
                            && value.predictedEndTranslation.height > 160
                        if moved < 8 || swipedDown {
                            withAnimation(.easeOut(duration: 0.3)) { shown = false }
                        }
                    }
            )
            .overlay(alignment: .top) {
                Capsule().fill(Theme.textSecondary.opacity(0.35)).frame(width: 36, height: 4).padding(.top, 6)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation(.easeOut(duration: 0.3)) { shown = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.text)
                .glassEffect(.regular.interactive(), in: .circle)
                .padding(8)
                .accessibilityLabel("Close pointer")
            }
        }
        .glassEffect(.regular.tint(Theme.coral.opacity(0.06)), in: .rect(cornerRadius: 18))
        .accessibilityLabel("Pointer trackpad")
    }
}
