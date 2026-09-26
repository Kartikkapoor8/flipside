import SwiftUI

/// Slide 5. The laptop pose: near half a dot-grid trackpad, far half a card, the real laser point as
/// the red dot. Client touches on the audience side are drawn separately by the audience layer.
struct PointScene: View {
    var laser: CGPoint?

    var body: some View {
        SceneClock { t in
            let idle = CGPoint(x: 0.5 + 0.12 * sin(t * 0.7), y: 0.5 + 0.1 * cos(t * 0.9))
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.violet.opacity(0.35), Theme.coral.opacity(0.35)], startPoint: .topTrailing, endPoint: .bottomLeading))
                    .overlay {
                        GeometryReader { p in
                            let dot = laser ?? idle
                            Circle().fill(.red).frame(width: 12, height: 12)
                                .shadow(color: .red.opacity(0.7), radius: 5)
                                .position(x: dot.x * p.size.width, y: dot.y * p.size.height)
                                .animation(.easeOut(duration: 0.2), value: dot)
                        }
                    }
                Canvas { ctx, size in
                    for x in stride(from: 8, to: size.width, by: 12) {
                        for y in stride(from: 8, to: size.height, by: 12) {
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(Theme.ink.opacity(0.25)))
                        }
                    }
                }
                .overlay {
                    GeometryReader { p in
                        let dot = laser ?? idle
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.ink.opacity(0.7))
                            .position(x: dot.x * p.size.width, y: dot.y * p.size.height)
                            .animation(.easeOut(duration: 0.2), value: dot)
                    }
                }
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
            }
        }
    }
}
