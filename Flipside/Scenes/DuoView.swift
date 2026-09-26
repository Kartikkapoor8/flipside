import SwiftUI

/// A small iPhone Duo: two rounded glass faces around a vertical hinge. `angle` is the fold, 180 flat
/// and 0 shut; the near (trailing) face turns around the seam with a hairline glow on it.
/// Far face shows a tiny card, near face tiny notes lines.
struct DuoView: View {
    var angle: Double
    /// 0 to 1, how lit the faces are.
    var lit: Double = 1
    /// A dot on the far face's card, normalised.
    var dot: CGPoint? = nil
    var dotColor: Color = .red
    /// Position of the sweep highlight, 0 to 1 across, nil for none.
    var sweep: Double? = nil

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            let faceW = min(w * 0.42, h * 0.8 * 0.72)
            let faceH = faceW / 0.72
            let turn = 180 - angle
            HStack(spacing: 0) {
                face(width: faceW, height: faceH) { farContent(faceW, faceH) }
                    .rotation3DEffect(.degrees(-turn / 2), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.6)
                seam(height: faceH)
                face(width: faceW, height: faceH) { nearContent(faceW, faceH) }
                    .rotation3DEffect(.degrees(turn / 2), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.6)
            }
            .frame(width: w, height: h)
        }
    }

    private func face<C: View>(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> C) -> some View {
        let shape = RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
        return ZStack {
            shape.fill(Theme.paper.opacity(0.6 + 0.4 * lit))
            content()
            if let sweep {
                LinearGradient(colors: [.clear, .white.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: width * 0.5)
                    .offset(x: (sweep - 0.5) * width * 2)
                    .blendMode(.plusLighter)
            }
        }
        .frame(width: width, height: height)
        .glassEffect(.regular, in: shape)
        .overlay(shape.strokeBorder(Theme.ink.opacity(0.12), lineWidth: 1))
        .clipShape(shape)
    }

    private func seam(height: CGFloat) -> some View {
        Capsule()
            .fill(LinearGradient(colors: [Theme.violet.opacity(0.2), Theme.coral.opacity(0.9), Theme.violet.opacity(0.2)], startPoint: .top, endPoint: .bottom))
            .frame(width: 2, height: height * 0.92)
            .shadow(color: Theme.coral.opacity(0.7 * lit), radius: 6)
    }

    private func farContent(_ w: CGFloat, _ h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: w * 0.08, style: .continuous)
            .fill(LinearGradient(colors: [Theme.violet.opacity(0.35), Theme.coral.opacity(0.35)], startPoint: .topTrailing, endPoint: .bottomLeading))
            .frame(width: w * 0.72, height: h * 0.5)
            .overlay(alignment: .center) {
                Text("F").font(.system(size: w * 0.18, weight: .black)).foregroundStyle(Theme.ink.opacity(0.85 * lit))
            }
            .overlay {
                if let dot {
                    Circle().fill(dotColor).frame(width: w * 0.07, height: w * 0.07)
                        .shadow(color: dotColor.opacity(0.7), radius: 4)
                        .position(x: dot.x * w * 0.72, y: dot.y * h * 0.5)
                }
            }
            .opacity(lit)
    }

    private func nearContent(_ w: CGFloat, _ h: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: h * 0.05) {
            ForEach(0..<5, id: \.self) { i in
                Capsule().fill(Theme.ink.opacity(i == 2 ? 0.5 : 0.22))
                    .frame(width: w * (i == 4 ? 0.4 : 0.7) * (i == 2 ? 0.6 : 1), height: h * 0.035)
            }
        }
        .padding(.leading, w * 0.14)
        .frame(width: w, alignment: .leading)
        .opacity(lit)
    }
}
