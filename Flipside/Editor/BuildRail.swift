import SwiftUI

/// Vertical loading bar for the strip beside the status bar (below the Wi-Fi symbol).
/// While a deck builds it fills top to bottom as each slide lands, with a glowing head and the orb above.
/// When the build finishes it fills, turns solid, and fades out.
struct BuildRail: View {
  let model: StudioModel

  private static let linger: TimeInterval = 1.8

  var body: some View {
    let generating = model.app.isGenerating
    let finishedAt = model.buildFinishedAt
    TimelineView(.animation(paused: !generating && !isLingering(finishedAt, now: .now))) { context in
      let now = context.date
      let visible = generating || isLingering(finishedAt, now: now)
      if visible {
        rail(t: now.timeIntervalSinceReferenceDate, generating: generating, opacity: fade(finishedAt, now: now, generating: generating))
      }
    }
    .allowsHitTesting(false)
    .accessibilityElement()
    .accessibilityLabel(generating ? "Building, \(model.slidesBuilt) slides so far" : "Deck ready")
  }

  private var progress: Double {
    guard model.app.isGenerating else { return 1 }
    let built = Double(model.slidesBuilt)
    // Decks are usually five to eight slides; keep headroom so the bar never tops out early.
    let expected = max(6, built + 2)
    return min((built + (model.slideInProgress ? 0.5 : 0.15)) / expected, 0.96)
  }

  private func rail(t: Double, generating: Bool, opacity: Double) -> some View {
    VStack(spacing: 10) {
      ThinkingOrb(state: model.orbState ?? .composing, size: 20, paused: !generating)
      GeometryReader { proxy in
        let height = proxy.size.height
        let fill = max(height * progress, 12)
        ZStack(alignment: .top) {
          Capsule().fill(Theme.line)
          Capsule()
            .fill(generating
                  ? AnyShapeStyle(LinearGradient(colors: [Theme.violet, Theme.sky, Theme.coral], startPoint: .top, endPoint: .bottom))
                  : AnyShapeStyle(Theme.coral))
            .frame(height: fill)
            .overlay(alignment: .top) {
              // A highlight travelling down the filled part.
              if generating {
                let phase = (t / 1.4).truncatingRemainder(dividingBy: 1)
                Capsule()
                  .fill(.white.opacity(0.55))
                  .frame(height: 18)
                  .blur(radius: 3)
                  .offset(y: (fill - 18) * phase)
              }
            }
            .overlay(alignment: .bottom) {
              // Glowing head where the next slide is landing.
              Circle()
                .fill(Theme.coral)
                .frame(width: 20, height: 20)
                .blur(radius: 7)
                .opacity(generating ? 0.55 + 0.35 * sin(t * 4) : 0)
                .offset(y: 8)
            }
            .clipShape(Capsule())
            .animation(.easeOut(duration: 0.5), value: progress)
        }
        .frame(width: 8)
        .frame(maxWidth: .infinity)
      }
      Text(generating ? "\(model.slidesBuilt)" : "Ready")
        .font(.system(size: 11, weight: .bold).monospacedDigit())
        .foregroundStyle(generating ? Theme.text : Theme.coral)
        .contentTransition(.numericText())
        .animation(.snappy, value: model.slidesBuilt)
    }
    .opacity(opacity)
  }

  private func isLingering(_ finishedAt: Date?, now: Date) -> Bool {
    guard let finishedAt else { return false }
    return now.timeIntervalSince(finishedAt) < Self.linger + 0.6
  }

  private func fade(_ finishedAt: Date?, now: Date, generating: Bool) -> Double {
    guard !generating, let finishedAt else { return 1 }
    let x = (now.timeIntervalSince(finishedAt) - Self.linger) / 0.6
    return 1 - min(max(x, 0), 1)
  }
}
