import SwiftUI

enum ImageGenerationPreset {
  case pixelsOrganic
  case pixelsMechanic
  case sweepGradient

  var mode: Float {
    switch self {
    case .pixelsOrganic: 0
    case .pixelsMechanic: 1
    case .sweepGradient: 2
    }
  }
}

/// WebGL-style image loader rebuilt with a SwiftUI Metal layer effect: a churning pixel mosaic
/// that resolves into the real image once `image` arrives.
struct ImageGeneration: View {
  var preset: ImageGenerationPreset = .pixelsOrganic
  var image: Image?
  var colors: [Color] = [Theme.violet, Theme.coral, Theme.sky]
  /// Seconds the reveal takes once the image lands.
  var revealDuration: Double = 1.2
  var animated = true

  @State private var revealStart: Date?

  var body: some View {
    TimelineView(.animation(paused: !animated || isSettled)) { context in
      let t = context.date.timeIntervalSinceReferenceDate
      let progress = progress(at: context.date)
      GeometryReader { proxy in
        ZStack {
          Theme.sunken
          if let image {
            image.resizable().scaledToFill()
              .frame(width: proxy.size.width, height: proxy.size.height)
              .clipped()
          }
        }
        .layerEffect(
          ShaderLibrary.fxPixelReveal(
            .float2(proxy.size),
            .float(Float(t.truncatingRemainder(dividingBy: 1000))),
            .float(Float(progress)),
            .float(preset.mode),
            .color(colors[0]),
            .color(colors[min(1, colors.count - 1)]),
            .color(colors[min(2, colors.count - 1)])
          ),
          maxSampleOffset: CGSize(width: 28, height: 28),
          isEnabled: progress < 1
        )
      }
    }
    .onChange(of: image != nil, initial: true) { _, hasImage in
      revealStart = hasImage ? (animated ? .now : .distantPast) : nil
    }
  }

  private var isSettled: Bool {
    guard let revealStart else { return false }
    return Date.now.timeIntervalSince(revealStart) > revealDuration + 0.1
  }

  private func progress(at date: Date) -> Double {
    guard image != nil, let revealStart else { return 0 }
    let x = min(max(date.timeIntervalSince(revealStart) / revealDuration, 0), 1)
    return x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
  }
}

/// A slide image: shows the generation loader, fetches the picture for `prompt`, then reveals it.
struct GeneratedImageView: View {
  let prompt: String
  let url: String?
  var animated = true

  @State private var image: Image?

  var body: some View {
    ImageGeneration(image: image, animated: animated)
      .task(id: url ?? prompt) {
        image = nil
        if let ui = await ImageProvider.shared.image(prompt: prompt, url: url) {
          image = Image(uiImage: ui)
        }
      }
  }
}
