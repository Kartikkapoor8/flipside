import SwiftUI

enum BeamSize {
  case md
  case sm
  case line
  case pulseInner
  case pulseOutside
}

enum BeamColorVariant: CaseIterable {
  case colorful
  case mono
  case ocean
  case sunset

  var colors: [Color] {
    switch self {
    case .colorful: [Theme.coral, Color(hex: 0xFF3D8B), Theme.violet, Theme.sky, Theme.mint]
    case .mono: [.white, Color(hex: 0x9A9AA6), .white]
    case .ocean: [Color(hex: 0x1E6BFF), Color(hex: 0x00D1C1), Color(hex: 0x6AE3FF)]
    case .sunset: [Theme.coral, Color(hex: 0xFFB36B), Color(hex: 0xFF3D8B)]
    }
  }
}

enum FXTheme {
  case dark
  case light
}

/// Wraps a child and rides an animated glow around its border.
/// `size`, `colorVariant`, `strength` (0...1), `active` (fades the beam in and out), `theme`.
struct BorderBeam<Content: View>: View {
  var size: BeamSize = .md
  var colorVariant: BeamColorVariant = .colorful
  var strength: Double = 0.7
  var active = true
  var theme: FXTheme = .light
  var cornerRadius: CGFloat = 16
  @ViewBuilder var content: Content

  var body: some View {
    content
      .overlay {
        BeamLayer(size: size, colors: colorVariant.colors, strength: strength, active: active, theme: theme, cornerRadius: cornerRadius)
          .opacity(active ? 1 : 0)
          .animation(.easeOut(duration: 0.45), value: active)
          .allowsHitTesting(false)
      }
  }
}

extension View {
  func borderBeam(
    _ size: BeamSize = .md,
    colorVariant: BeamColorVariant = .colorful,
    strength: Double = 0.7,
    active: Bool = true,
    theme: FXTheme = .light,
    cornerRadius: CGFloat = 16
  ) -> some View {
    BorderBeam(size: size, colorVariant: colorVariant, strength: strength, active: active, theme: theme, cornerRadius: cornerRadius) { self }
  }
}

private struct BeamLayer: View {
  let size: BeamSize
  let colors: [Color]
  let strength: Double
  let active: Bool
  let theme: FXTheme
  let cornerRadius: CGFloat

  var body: some View {
    TimelineView(.animation(paused: !active)) { context in
      let t = context.date.timeIntervalSinceReferenceDate
      Group {
        switch size {
        case .md, .sm: ring(t: t)
        case .line: line(t: t)
        case .pulseInner, .pulseOutside: pulse(t: t)
        }
      }
      .blendMode(theme == .dark ? .plusLighter : .normal)
    }
  }

  private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }

  private func gradient(_ t: Double) -> AngularGradient {
    AngularGradient(colors: colors + [colors[0]], center: .center, angle: .degrees(t * 40))
  }

  private func window(_ angle: Double, from: Double, to: Double) -> AngularGradient {
    AngularGradient(
      stops: [
        .init(color: .clear, location: 0),
        .init(color: .clear, location: from),
        .init(color: .white, location: (from + to) / 2),
        .init(color: .white, location: to),
        .init(color: .clear, location: min(to + 0.02, 1)),
      ],
      center: .center,
      angle: .degrees(angle)
    )
  }

  @ViewBuilder
  private func ring(t: Double) -> some View {
    let isMd = size == .md
    let period = isMd ? 3.4 : 2.6
    let angle = (t / period).truncatingRemainder(dividingBy: 1) * 360
    let width: CGFloat = isMd ? 2 : 1.4
    let glow: CGFloat = isMd ? 14 : 8
    ZStack {
      shape.strokeBorder(gradient(t), lineWidth: width * 5)
        .blur(radius: glow)
        .opacity(0.9 * strength)
        .mask(window(angle, from: 0.55, to: 0.96).padding(-40))
      shape.strokeBorder(gradient(t), lineWidth: width)
        .mask(window(angle, from: 0.5, to: 0.97))
        .opacity(0.6 + 0.4 * strength)
      shape.strokeBorder(theme == .dark ? Color.white.opacity(0.9) : colors[colors.count / 2], lineWidth: width * 0.6)
        .mask(window(angle, from: 0.86, to: 0.96))
        .opacity(strength)
      // A faint static rim so the frame reads even between passes.
      shape.strokeBorder(gradient(t), lineWidth: 0.6).opacity(0.18 * strength)
    }
  }

  @ViewBuilder
  private func line(t: Double) -> some View {
    GeometryReader { proxy in
      let phase = (t / 2.4).truncatingRemainder(dividingBy: 1)
      let x = -0.3 + phase * 1.6
      let beam = LinearGradient(
        stops: [
          .init(color: .clear, location: max(x - 0.28, 0)),
          .init(color: colors[0], location: max(x - 0.12, 0)),
          .init(color: colors[min(2, colors.count - 1)], location: min(max(x, 0), 1)),
          .init(color: .clear, location: min(max(x + 0.1, 0), 1)),
        ],
        startPoint: .leading, endPoint: .trailing
      )
      ZStack(alignment: .bottom) {
        Rectangle().fill(beam).frame(height: 10).blur(radius: 10).opacity(strength)
        Rectangle().fill(beam).frame(height: 1.5)
      }
      .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
    }
  }

  @ViewBuilder
  private func pulse(t: Double) -> some View {
    let breath = 0.55 + 0.45 * (sin(t * 2.2) + 1) / 2
    if size == .pulseInner {
      shape.stroke(gradient(t), lineWidth: 34)
        .blur(radius: 22)
        .clipShape(shape)
        .opacity(breath * strength)
    } else {
      shape.strokeBorder(gradient(t), lineWidth: 10)
        .blur(radius: 18)
        .padding(-6)
        .opacity(breath * strength)
    }
  }
}
