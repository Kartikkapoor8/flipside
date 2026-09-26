import SwiftUI

/// Shared glass behaviour for the desk, matched to the editor's radii (12 / 18 / capsule) and motion.
///
/// - `deskPress`: cards scale to 0.97 while pressed, with a spring, and fire on release.
/// - `hingeHighlight`: a faint specular sweep whose angle follows the hinge, so the glass reads as
///   lit from the fold and turns as the phone folds.
extension View {
    func deskPress(perform action: @escaping () -> Void) -> some View {
        modifier(DeskPress(action: action))
    }

    func hingeHighlight(_ shape: some InsettableShape, angle: Double) -> some View {
        overlay {
            HingeHighlight(angle: angle)
                .clipShape(shape)
                .allowsHitTesting(false)
        }
    }
}

private struct DeskPress: ViewModifier {
    let action: () -> Void
    @State private var pressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(.spring(duration: 0.28, bounce: 0.35), value: pressed)
            ._onButtonGesture(pressing: { pressed = $0 }, perform: action)
    }
}

/// Angle 90 (standing) lights the glass from the top; 180 (flat) from the leading edge.
struct HingeHighlight: View {
    let angle: Double

    var body: some View {
        let t = min(max((angle - 90) / 90, 0), 1)
        let start = UnitPoint(x: 0.5 - 0.5 * t, y: 0)
        let end = UnitPoint(x: 0.5 + 0.5 * t, y: 1)
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.32), location: 0),
                .init(color: .white.opacity(0.06), location: 0.35),
                .init(color: .clear, location: 0.7),
            ],
            startPoint: start, endPoint: end
        )
        .blendMode(.plusLighter)
        .opacity(0.55)
        .animation(.easeOut(duration: 0.25), value: t)
    }
}
