import SwiftUI

#if DEBUG
/// DEBUG only. A small overlay with a slider that fakes the hinge angle, for the simulator when
/// DeviceHub's pose buttons are out of reach. Tap the angle readout to collapse it to a chip.
/// Writes through the same `applyHinge` path as the real hinge so the mode mapping is exercised.
struct HingeDebugView: View {
    @Environment(AppState.self) private var appState
    @State private var isExpanded = false
    @State private var angle: Double = 180

    var body: some View {
        VStack(alignment: .trailing, spacing: Brand.Space.s2) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: Brand.Space.s2) {
                    Image(systemName: "angle")
                    Text("\(Int(appState.hingeAngle.rounded()))°")
                        .monospacedDigit()
                    Text(appState.mode.rawValue)
                        .foregroundStyle(Brand.Presenter.accent)
                }
                .font(Brand.Font.uiLabel)
                .padding(.horizontal, Brand.Space.s3)
                .padding(.vertical, Brand.Space.s2)
                .background(Brand.Presenter.surface.opacity(0.92), in: Capsule())
                .foregroundStyle(Brand.Presenter.text)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: Brand.Space.s2) {
                    Text("FAKE HINGE")
                        .font(Brand.Font.uiLabel).tracking(1.2)
                        .foregroundStyle(Brand.Presenter.muted)
                    Slider(value: $angle, in: 0...180, step: 1) { _ in }
                        .tint(Brand.Presenter.accent)
                        .onChange(of: angle) { _, new in
                            let status: AppState.HingeStatus = new < 5 ? .closed : (new > 175 ? .fullyOpen : .partiallyOpen)
                            appState.applyHinge(angle: new, status: status)
                            print("[hinge] fake angle=\(Int(new)) mode=\(appState.mode.rawValue)")
                        }
                    HStack(spacing: Brand.Space.s2) {
                        // Simulates hearing the cue: the pill fills and the deck advances.
                        Button {
                            NotificationCenter.default.post(name: .flipsideDebugCue, object: nil)
                        } label: {
                            Label("Cue", systemImage: "waveform")
                                .font(Brand.Font.caption)
                                .padding(.horizontal, Brand.Space.s3)
                                .padding(.vertical, Brand.Space.s1)
                                .background(Brand.Presenter.accent, in: Capsule())
                                .foregroundStyle(Brand.ink)
                        }
                        ForEach([("Closed", 0.0), ("Stand", 90.0), ("Flat", 180.0)], id: \.0) { name, value in
                            Button(name) { angle = value }
                                .font(Brand.Font.caption)
                                .padding(.horizontal, Brand.Space.s3)
                                .padding(.vertical, Brand.Space.s1)
                                .background(Brand.Presenter.background, in: Capsule())
                                .foregroundStyle(Brand.Presenter.text)
                        }
                        Spacer()
                        Button("Home") { withAnimation(Theme.land) { appState.isHome.toggle() } }
                            .font(Brand.Font.caption)
                            .foregroundStyle(Brand.Presenter.text)
                        Text("fold \(String(format: "%.2f", appState.foldProgress))")
                            .font(Brand.Font.caption)
                            .foregroundStyle(Brand.Presenter.muted)
                    }
                }
                .padding(Brand.Space.s3)
                .frame(width: 260)
                .background(Brand.Presenter.surface.opacity(0.95), in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear { angle = appState.hingeAngle }
    }
}
#endif
