import SwiftUI

enum OrbState: String, CaseIterable {
  case working
  case searching
  case solving
  case listening
  case connecting
  case weaving
  case composing
  case breathing
  case shaping
}

/// A dotted orb that replaces the spinner while the AI is thinking. Nine states, drawn with Canvas.
/// `size` is tuned for 64 (chat avatar) and 20 (inline with text).
struct ThinkingOrb: View {
  var state: OrbState = .working
  var size: CGFloat = 64
  var speed: Double = 1
  var dark = false
  var paused = false
  /// Optional live input for `.listening`, 0...1.
  var level: (() -> Double)?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(paused: paused || reduceMotion)) { context in
      let t = context.date.timeIntervalSinceReferenceDate * speed
      Canvas { ctx, canvasSize in
        draw(in: &ctx, size: canvasSize, t: t)
      }
    }
    .frame(width: size, height: size)
    .accessibilityElement()
    .accessibilityLabel("Thinking, \(state.rawValue)")
  }

  private var dotCount: Int { size >= 40 ? 260 : 46 }

  private func draw(in ctx: inout GraphicsContext, size canvasSize: CGSize, t: Double) {
    let n = dotCount
    let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
    let radius = min(canvasSize.width, canvasSize.height) * 0.4
    let golden = Double.pi * (3 - sqrt(5))
    let spin = t * spinSpeed
    let tilt = 0.42 + (state == .weaving ? 0.35 * sin(t * 0.7) : 0)
    let live = level?() ?? 0
    let dotScale = size >= 40 ? 1.0 : 1.7

    for i in 0..<n {
      // Fibonacci sphere.
      let fi = Double(i)
      var y = 1 - (fi / Double(n - 1)) * 2
      let ring = sqrt(max(0, 1 - y * y))
      let theta = golden * fi
      var x = cos(theta) * ring
      var z = sin(theta) * ring
      var r = 1.0
      var bright = 1.0

      switch state {
      case .working:
        r += 0.07 * sin(y * 7 - t * 4)
      case .searching:
        let band = sin(t * 1.4) * 0.9
        bright = 0.35 + 1.2 * exp(-pow((y - band) * 3.5, 2))
      case .solving:
        let snap = (sin(t * 1.8) + 1) / 2
        let q = 3.0
        x = x + ((x * q).rounded() / q - x) * snap
        y = y + ((y * q).rounded() / q - y) * snap
        z = z + ((z * q).rounded() / q - z) * snap
      case .listening:
        r += (0.05 + 0.25 * live) * sin(theta * 3 + t * 6) * ring
      case .connecting:
        bright = fi.truncatingRemainder(dividingBy: 5) == 0 ? 1.4 : 0.25
        r += 0.12 * sin(t * 3 + fi) * (bright > 1 ? 1 : 0)
      case .weaving:
        r += 0.08 * sin(x * 6 + t * 3) * cos(z * 6 - t * 2)
      case .composing:
        let wave = (fi / Double(n) - t * 0.35).truncatingRemainder(dividingBy: 1)
        bright = 0.25 + 1.1 * pow(1 - abs(wave < 0 ? wave + 1 : wave), 6)
      case .breathing:
        r += 0.12 * sin(t * 1.7)
      case .shaping:
        let m = (sin(t * 1.2) + 1) / 2
        let edge = max(abs(x), abs(y), abs(z))
        x = x + (x / edge * 0.8 - x) * m
        y = y + (y / edge * 0.8 - y) * m
        z = z + (z / edge * 0.8 - z) * m
      }

      // Rotate around Y (spin) then X (tilt).
      let cs = cos(spin), sn = sin(spin)
      let rx = x * cs + z * sn
      let rz = -x * sn + z * cs
      let ct = cos(tilt), st = sin(tilt)
      let ry = y * ct - rz * st
      let rz2 = y * st + rz * ct

      let depth = (rz2 + 1) / 2
      let px = center.x + CGFloat(rx * r) * radius
      let py = center.y + CGFloat(ry * r) * radius
      let d = CGFloat((0.6 + 1.2 * depth) * dotScale) * max(size / 64, 0.5)
      let alpha = min(1, (0.15 + 0.85 * depth) * bright)
      let color = dotColor(depth: depth, x: rx)
      ctx.fill(
        Path(ellipseIn: CGRect(x: px - d / 2, y: py - d / 2, width: d, height: d)),
        with: .color(color.opacity(alpha))
      )
    }
  }

  private var spinSpeed: Double {
    switch state {
    case .working: 0.9
    case .searching: 0.5
    case .solving: 0.3
    case .listening: 0.4
    case .connecting: 0.25
    case .weaving: 0.7
    case .composing: 0.35
    case .breathing: 0.2
    case .shaping: 0.45
    }
  }

  private func dotColor(depth: Double, x: Double) -> Color {
    let base: Color = dark ? .white : Theme.ink
    // Front dots pick up a warm-to-cool tint across the orb.
    guard depth > 0.6 else { return base }
    return x < 0 ? Theme.coral : Theme.violet
  }
}
