import SwiftUI

/// A glowing dot at a normalized point over whatever it is layered on. Drawn inside the
/// audience slide's own (un-rotated) coordinate space, so the parent's rotation carries it.
/// Nothing draws when `point` is nil.
struct LaserDotView: View {
    var point: CGPoint?
    var radius: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            if let p = point {
                let center = CGPoint(x: p.x * proxy.size.width, y: p.y * proxy.size.height)
                ZStack {
                    Circle()
                        .fill(Brand.verdigris.opacity(0.25))
                        .frame(width: radius * 5, height: radius * 5)
                        .blur(radius: radius)
                    Circle()
                        .fill(Brand.verdigris.opacity(0.55))
                        .frame(width: radius * 2.6, height: radius * 2.6)
                        .blur(radius: radius / 3)
                    Circle()
                        .fill(Brand.Presenter.accent)
                        .frame(width: radius * 2, height: radius * 2)
                    Circle()
                        .fill(.white.opacity(0.85))
                        .frame(width: radius * 0.8, height: radius * 0.8)
                }
                .position(center)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.12), value: point == nil)
    }
}

#Preview {
    ZStack {
        Brand.paper
        LaserDotView(point: CGPoint(x: 0.6, y: 0.4))
    }
    .frame(width: 400, height: 210)
}
