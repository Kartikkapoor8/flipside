import SwiftUI

/// One glass row at the bottom of the desk: the running timer, the Pointer toggle, Swap sides.
/// No Back, no Next: the deck advances on the cue, the queue jumps on a tap.
struct DeskBar: View {
    let model: StudioModel
    @Binding var pointerShown: Bool

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                timer
                Spacer(minLength: 0)
                Button {
                    withAnimation(.easeOut(duration: 0.3)) { pointerShown.toggle() }
                } label: {
                    Label("Pointer", systemImage: "hand.point.up.left.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                }
                .buttonStyle(DeskPressStyle())
                .foregroundStyle(pointerShown ? .white : Theme.text)
                .glassEffect(pointerShown ? .regular.tint(Theme.coral).interactive() : .regular.interactive(), in: .capsule)
                .accessibilityLabel(pointerShown ? "Hide pointer" : "Show pointer")

                Button {
                    model.app.flipAudience()
                } label: {
                    Label("Flip", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                }
                .buttonStyle(DeskPressStyle())
                .foregroundStyle(model.app.audienceFlipped ? .white : Theme.text)
                .glassEffect(model.app.audienceFlipped ? .regular.tint(Theme.coral).interactive() : .regular.interactive(), in: .capsule)
                .accessibilityLabel(model.app.audienceFlipped ? "Audience upright" : "Flip audience")

                Button {
                    model.swapSides()
                } label: {
                    Label("Swap", systemImage: "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                }
                .buttonStyle(DeskPressStyle())
                .foregroundStyle(Theme.text)
                .glassEffect(.regular.interactive(), in: .capsule)
                .accessibilityLabel("Swap sides")
            }
        }
        .frame(height: 48)
    }

    private var timer: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.coral).frame(width: 6, height: 6)
            Text(PresenterClock.mmss(model.app.elapsed))
                .font(.system(size: 17, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
            if let slide = model.current {
                Text("\(slide.durationHint)s")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .glassEffect(.regular, in: .capsule)
        .hingeHighlight(Capsule(), angle: model.app.hingeAngle)
        .accessibilityLabel("Timer")
    }
}

enum PresenterClock {
    static func mmss(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded(.down)))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

/// Bar buttons scale like the cards while pressed, on the same spring.
struct DeskPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.28, bounce: 0.35), value: configuration.isPressed)
    }
}
