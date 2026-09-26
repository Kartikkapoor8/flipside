import AVFoundation
import SwiftUI

// MARK: - Video

/// Plays a bundled file (by name, e.g. "Growth.mp4") or a URL, muted and looping.
/// Starts after `startDelay` so it begins once the insert animation has landed.
struct LoopingVideo: UIViewRepresentable {
  let source: String
  var startDelay: Double = 0.5

  func makeUIView(context: Context) -> PlayerView {
    let view = PlayerView()
    view.configure(url: Self.url(for: source), startDelay: startDelay)
    return view
  }

  func updateUIView(_ view: PlayerView, context: Context) {}

  static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
    view.stop()
  }

  static func url(for source: String) -> URL? {
    if let url = URL(string: source), url.scheme != nil { return url }
    let name = (source as NSString).deletingPathExtension
    let ext = (source as NSString).pathExtension
    return Bundle.main.url(forResource: name, withExtension: ext.isEmpty ? "mp4" : ext)
  }

  final class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    func configure(url: URL?, startDelay: Double) {
      backgroundColor = UIColor(white: 0.93, alpha: 1)
      guard let url else { return }
      let player = AVQueuePlayer()
      player.isMuted = true
      looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
      self.player = player
      let layer = self.layer as! AVPlayerLayer
      layer.player = player
      layer.videoGravity = .resizeAspectFill
      DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) { [weak player] in player?.play() }
    }

    func stop() {
      player?.pause()
      looper = nil
      player = nil
    }
  }
}

// MARK: - Animation presets

enum AnimationPreset: String, CaseIterable, Identifiable {
  case orb
  case aurora
  case pulse

  var id: String { rawValue }

  var title: String {
    switch self {
    case .orb: "Orb"
    case .aurora: "Aurora"
    case .pulse: "Pulse"
    }
  }

  var icon: String {
    switch self {
    case .orb: "circle.dotted"
    case .aurora: "sparkles"
    case .pulse: "dot.radiowaves.left.and.right"
    }
  }
}

struct AnimationPresetView: View {
  let preset: AnimationPreset

  var body: some View {
    GeometryReader { proxy in
      let side = min(proxy.size.width, proxy.size.height)
      ZStack {
        switch preset {
        case .orb:
          Theme.paper
          ThinkingOrb(state: .weaving, size: side * 0.8)
        case .aurora:
          AuroraView()
        case .pulse:
          PulseView()
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
  }
}

/// Slowly drifting brand-colour mesh.
private struct AuroraView: View {
  var body: some View {
    TimelineView(.animation) { context in
      let t = context.date.timeIntervalSinceReferenceDate
      let wobble = { (phase: Double) -> Float in Float(0.5 + 0.18 * sin(t * 0.6 + phase)) }
      MeshGradient(
        width: 3,
        height: 3,
        points: [
          [0, 0], [0.5, 0], [1, 0],
          [0, 0.5], [wobble(0), wobble(1.7)], [1, 0.5],
          [0, 1], [0.5, 1], [1, 1],
        ],
        colors: [
          Theme.violet, Theme.sky, Theme.paper,
          Theme.coral, Color(hex: 0xFFB36B), Theme.sky,
          Theme.paper, Theme.coral, Theme.violet,
        ]
      )
    }
  }
}

/// Concentric rings breathing out from the centre.
private struct PulseView: View {
  var body: some View {
    TimelineView(.animation) { context in
      let t = context.date.timeIntervalSinceReferenceDate
      Canvas { ctx, size in
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxR = hypot(size.width, size.height) / 2
        for i in 0..<5 {
          let phase = (t / 2.4 + Double(i) / 5).truncatingRemainder(dividingBy: 1)
          let r = maxR * phase
          let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
          ctx.stroke(Path(ellipseIn: rect), with: .color(Theme.coral.opacity(1 - phase)), lineWidth: 6 * (1 - phase) + 1)
        }
        let core = CGRect(x: center.x - 18, y: center.y - 18, width: 36, height: 36)
        ctx.fill(Path(ellipseIn: core), with: .color(Theme.coral))
      }
      .background(Theme.paper)
    }
  }
}

// MARK: - Library

/// Everything the Media tab can drop onto a slide: the deck's images, bundled videos, and the presets.
enum MediaLibrary {
  static func items(for deck: Deck) -> [SlideMedia] {
    var items: [SlideMedia] = []
    let videos = (Bundle.main.urls(forResourcesWithExtension: "mp4", subdirectory: nil) ?? [])
      .map(\.lastPathComponent)
      .sorted()
    for name in videos {
      items.append(SlideMedia(kind: .video, source: name, title: (name as NSString).deletingPathExtension))
    }
    var seen = Set<String>()
    for slide in deck.slides {
      guard let source = slide.imageURL ?? slide.imagePrompt ?? (slide.media?.kind == .image ? slide.media?.source : nil),
            seen.insert(source).inserted else { continue }
      items.append(SlideMedia(kind: .image, source: source, title: slide.title.isEmpty ? "Image" : slide.title))
    }
    for preset in AnimationPreset.allCases {
      items.append(SlideMedia(kind: .animation, source: preset.rawValue, title: preset.title))
    }
    return items
  }
}
