import SwiftUI

/// One glass row at the bottom of the desk: the running timer, the Pointer toggle, Swap sides.
/// No Back, no Next: the deck advances on the cue, the queue jumps on a tap.
struct DeskBar: View {
    let model: StudioModel
    @Binding var pointerShown: Bool
    @Binding var mediaShown: Bool
    @State private var settingsShown = false

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    model.goHome()
                } label: {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(DeskPressStyle())
                .foregroundStyle(Theme.text)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Home")
                timer
                Spacer(minLength: 0)
                Button {
                    withAnimation(.easeOut(duration: 0.3)) { mediaShown.toggle() }
                } label: {
                    Label("Media", systemImage: "photo.on.rectangle")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                }
                .buttonStyle(.plain)
                .foregroundStyle(mediaShown ? .white : Theme.text)
                .glassEffect(mediaShown ? .regular.tint(Theme.coral).interactive() : .regular.interactive(), in: .capsule)
                .accessibilityLabel(mediaShown ? "Hide media" : "Show media")

                Button {
                    withAnimation(.easeOut(duration: 0.3)) { pointerShown.toggle() }
                } label: {
                    Label("Pointer", systemImage: "hand.point.up.left.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
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
                        .padding(.horizontal, 12)
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
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                }
                .buttonStyle(DeskPressStyle())
                .foregroundStyle(Theme.text)
                .glassEffect(.regular.interactive(), in: .capsule)
                .accessibilityLabel("Swap sides")

                Button {
                    settingsShown = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(DeskPressStyle())
                .foregroundStyle(Theme.text)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Settings")
            }
        }
        .frame(height: 48)
        .sheet(isPresented: $settingsShown) {
            VStack(spacing: 14) {
                Text("SETTINGS")
                    .font(.system(size: 10, weight: .bold)).tracking(1.2)
                    .foregroundStyle(Theme.textSecondary)
                Text(DeckGenerator.providerLabel)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Button("Close") { settingsShown = false }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).frame(height: 36)
                    .glassEffect(.regular.tint(Theme.ink).interactive(), in: .capsule)
            }
            .padding(24)
            .presentationDetents([.height(180)])
            .presentationBackground(.thinMaterial)
        }
    }

    private var timer: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.coral).frame(width: 6, height: 6)
            Text(PresenterClock.mmss(model.app.elapsed))
                .font(.system(size: 17, weight: .semibold).monospacedDigit())
                .fixedSize()
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
            if let slide = model.current {
                Text("\(slide.durationHint)s")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .fixedSize()
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
