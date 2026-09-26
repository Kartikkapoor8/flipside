import SwiftUI

/// The stage strip: a small glass chip on the fold seam that opens into the buttons a demo needs
/// when there is no mic and no real hinge. Every button goes through the same code path as the
/// real event (cue match, hinge callback, insert motion), so what the judges see is the product.
///
/// Hidden until the seam is triple-tapped.
struct HingeDebugView: View {
    @Environment(AppState.self) private var appState
    @Environment(StudioModel.self) private var studio
    @State private var isExpanded = false
    /// Hidden until the seam is triple-tapped, in every build.
    @State private var isVisible = false

    var body: some View {
        ZStack {
            // The seam itself: a wide, invisible target. Triple tap reveals the chip in release.
            Color.clear
                .frame(width: 220, height: 28)
                .contentShape(Rectangle())
                .onTapGesture(count: 3) {
                    withAnimation(Theme.land) { isVisible.toggle(); if !isVisible { isExpanded = false } }
                }
            if isVisible {
                GlassEffectContainer(spacing: 6) {
                    VStack(spacing: 6) {
                        chip
                        if isExpanded { strip.transition(.scale(scale: 0.96).combined(with: .opacity)) }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(Theme.land, value: isExpanded)
    }

    private var chip: some View {
        HStack(spacing: 6) {
            Image(systemName: "angle")
            Text("\(Int(appState.hingeAngle.rounded()))°").monospacedDigit().contentTransition(.numericText())
            Text(appState.mode.rawValue).foregroundStyle(Theme.coral)
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 9, weight: .bold))
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .glassEffect(.regular.interactive(), in: .capsule)
        .deskPress { isExpanded.toggle() }
        .accessibilityLabel("Stage controls")
    }

    private var strip: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                key("Back", "chevron.left") { studio.back() }
                key("Next", "chevron.right") { studio.next() }
                key("Cue heard", "waveform") { NotificationCenter.default.post(name: .flipsideDebugCue, object: nil) }
                key("Client asked", "bubble.left.fill") { studio.insertParkingCard() }
                key("Suggest", "sparkles") { studio.offerSuggestion(StudioModel.cannedTentative) }
                key("Direct", "bolt.fill") { studio.offerSuggestion(StudioModel.cannedDirect) }
                key(appState.laserPoint == nil ? "Laser on" : "Laser off", "scope", tinted: appState.laserPoint != nil) { studio.toggleLaser() }
                key("Flip", "arrow.trianglehead.2.clockwise.rotate.90", tinted: appState.audienceFlipped) { withAnimation(.easeInOut(duration: 0.4)) { appState.flipAudience() } }
            }
            HStack(spacing: 6) {
                ForEach([("90", 90.0), ("135", 135.0), ("180", 180.0)], id: \.0) { name, value in
                    key("Fold \(name)", "angle", tinted: Int(appState.hingeAngle.rounded()) == Int(value)) { fold(to: value) }
                }
                key("Closed", "iphone.gen3", tinted: appState.hingeStatus == .closed) { fold(to: 0) }
                key("Generate", "sparkles") { studio.replayGeneration() }
                key("End", "xmark.circle.fill") { studio.endMeeting() }
            }
        }
        .padding(6)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private func key(_ title: String, _ symbol: String, tinted: Bool = false, action: @escaping () -> Void) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(tinted ? .white : Theme.text)
            .padding(.horizontal, 9).frame(height: 30)
            .glassEffect(tinted ? .regular.tint(Theme.coral).interactive() : .regular.interactive(), in: .capsule)
            .deskPress(perform: action)
    }

    /// Writes the angle straight into the same path the hinge callback uses, so the mode mapper,
    /// the morph and the ended state all run without DeviceHub.
    private func fold(to angle: Double) {
        let status: AppState.HingeStatus = angle < 5 ? .closed : (angle >= 178 ? .fullyOpen : .partiallyOpen)
        withAnimation(.easeInOut(duration: 0.55)) {
            appState.applyHinge(angle: angle, status: status)
        }
        print("[hinge] stage angle=\(Int(angle)) status=\(status.rawValue) mode=\(appState.mode.rawValue)")
    }
}
