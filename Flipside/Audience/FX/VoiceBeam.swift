import SwiftUI

enum VoiceBeamType {
  /// ~350 pt chat input.
  case `default`
  /// ~150 x 44 recording pill.
  case pill
  /// Bottom of a phone screen.
  case mobile
}

enum VoiceColorVariant {
  case colorful, mono, ocean, sunset, forest, candy, ice, gold

  var colors: [Color] {
    switch self {
    case .colorful: [Theme.coral, Color(hex: 0xFF3D8B), Theme.violet, Theme.sky, Theme.mint]
    case .mono: [.white, Color(hex: 0xC8C8D0), Color(hex: 0x8A8A96)]
    case .ocean: [Color(hex: 0x1E6BFF), Color(hex: 0x00D1C1), Color(hex: 0x6AE3FF)]
    case .sunset: [Theme.coral, Color(hex: 0xFFB36B), Color(hex: 0xFF3D8B)]
    case .forest: [Color(hex: 0x2BB673), Color(hex: 0xA3E635), Color(hex: 0x0E9F6E)]
    case .candy: [Color(hex: 0xFF7AD9), Color(hex: 0x9B8CFF), Color(hex: 0x7AE7FF)]
    case .ice: [Color(hex: 0xBFEFFF), Color(hex: 0x7AB8FF), .white]
    case .gold: [Color(hex: 0xFFD166), Color(hex: 0xF4A261), Color(hex: 0xFFF1C1)]
    }
  }
}

/// Wraps a child and blooms a sound-reactive glow up from its bottom edge.
/// Drive it with `level` (0...1 getter, e.g. `mic.level`). `processing` gathers the glow into
/// one beam that travels along the edge while work is in progress.
struct VoiceBeam<Content: View>: View {
  var type: VoiceBeamType = .default
  var level: () -> Double = { 0 }
  var processing = false
  var colorVariant: VoiceColorVariant = .colorful
  var strength: Double = 1
  var reach: Double = 1
  var spread: Double = 1
  var flow: Double = 1
  var idle: Double = 0.18
  var active = true
  var theme: FXTheme = .light
  var cornerRadius: CGFloat = 22
  @ViewBuilder var content: Content

  @State private var processingChanged = Date.distantPast

  var body: some View {
    content
      .overlay {
        TimelineView(.animation(paused: !active)) { context in
          GlowField(
            t: context.date.timeIntervalSinceReferenceDate,
            level: level(),
            processingMix: processingMix(at: context.date),
            colors: colorVariant.colors,
            type: type,
            reach: reach,
            spread: spread,
            flow: flow,
            idle: idle,
            theme: theme
          )
        }
        .opacity(active ? strength : 0)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .blendMode(theme == .dark ? .plusLighter : .normal)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.3), value: active)
      }
      .onChange(of: processing) { processingChanged = .now }
  }

  /// 0 = voice, 1 = travelling beam, eased over 450 ms.
  private func processingMix(at date: Date) -> Double {
    let x = min(max(date.timeIntervalSince(processingChanged) / 0.45, 0), 1)
    let eased = 1 - pow(1 - x, 3)
    return processing ? eased : 1 - eased
  }
}

private struct GlowField: View {
  let t: Double
  let level: Double
  let processingMix: Double
  let colors: [Color]
  let type: VoiceBeamType
  let reach: Double
  let spread: Double
  let flow: Double
  let idle: Double
  let theme: FXTheme

  var body: some View {
    Canvas { ctx, size in
      let w = size.width
      let h = size.height
      let lobeCount = colors.count
      let energy = max(level, idle + 0.05 * sin(t * 1.3))
      let heightScale: Double = switch type {
      case .default: 0.9
      case .pill: 1.4
      case .mobile: 0.55
      }
      ctx.addFilter(.blur(radius: min(h * 0.35, 26)))
      for i in 0..<lobeCount {
        let fi = Double(i)
        let offset = fi - Double(lobeCount - 1) / 2
        // Voice: lobes fan out from the middle and wobble with the flow.
        let voiceX = w / 2
          + offset * w * 0.11 * spread * (0.55 + energy)
          + sin(t * 1.1 * flow + fi * 1.7) * w * 0.035
        let voiceW = w * (0.16 + 0.2 * energy) * spread
        let voiceH = h * heightScale * reach * (0.35 + 1.25 * energy)
          * (0.8 + 0.2 * sin(t * 2.3 * flow + fi))
        // Processing: every lobe collapses onto one travelling beam, with a little lag each.
        let beamX = w / 2 + sin(t * 1.9 - fi * 0.14) * w * 0.38
        let beamW = w * 0.14
        let beamH = h * heightScale * 0.9
        let m = processingMix
        let cx = voiceX + (beamX - voiceX) * m
        let ew = voiceW + (beamW - voiceW) * m
        let eh = voiceH + (beamH - voiceH) * m
        let rect = CGRect(x: cx - ew / 2, y: h - eh / 2, width: ew, height: eh)
        ctx.fill(
          Path(ellipseIn: rect),
          with: .radialGradient(
            Gradient(colors: [colors[i], colors[i].opacity(0)]),
            center: CGPoint(x: rect.midX, y: rect.midY),
            startRadius: 0,
            endRadius: max(ew, eh) / 2
          )
        )
      }
      // Hot white core on the edge.
      let coreW = w * (0.2 + 0.3 * max(energy, processingMix * 0.4))
      let coreX = w / 2 + (sin(t * 1.9) * w * 0.38) * processingMix
      ctx.fill(
        Path(ellipseIn: CGRect(x: coreX - coreW / 2, y: h - 5, width: coreW, height: 10)),
        with: .color(.white.opacity(theme == .dark ? 0.35 + 0.5 * energy : 0.6))
      )
    }
  }
}
