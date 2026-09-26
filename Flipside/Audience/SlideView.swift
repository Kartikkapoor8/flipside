import SwiftUI

/// Shows a slide surface scaled into the space it's given.
/// `aspect == nil` fills the space edge to edge (the full-screen artifact); a number fits that shape (thumbnails).
struct FittedSlide<Content: View>: View {
  var aspect: CGFloat?
  var cornerRadius: CGFloat = 0
  @ViewBuilder var content: (_ scale: CGFloat) -> Content

  var body: some View {
    GeometryReader { proxy in
      let space = proxy.size
      let shape = aspect ?? (space.height > 0 ? space.width / space.height : 1.9)
      let canvas = SlideCanvas.size(forAspect: shape)
      let scale = min(space.width / canvas.width, space.height / canvas.height)
      content(scale)
        .environment(\.slideCanvasSize, canvas)
        .frame(width: canvas.width, height: canvas.height)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: canvas.width * scale, height: canvas.height * scale, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .modifier(OptionalAspect(aspect: aspect))
  }
}

private struct OptionalAspect: ViewModifier {
  let aspect: CGFloat?
  func body(content: Content) -> some View {
    if let aspect { content.aspectRatio(aspect, contentMode: .fit) } else { content }
  }
}

/// Read-only slide: the audience face, thumbnails and the next-slide preview.
struct SlideView: View {
  let slide: Slide
  var animated = true
  var aspect: CGFloat?
  var cornerRadius: CGFloat = 0

  var body: some View {
    FittedSlide(aspect: aspect, cornerRadius: cornerRadius) { _ in
      SlideSurface(slide: slide, animated: animated)
    }
  }
}

/// The slide at design size. Every element is absolutely placed from its `ElementFrame`,
/// so moving one in the editor is a data change, not a layout change, and every change animates.
struct SlideSurface: View {
  let slide: Slide
  var animated = true
  /// Elements the editor is drawing itself (for inline text editing).
  var suppressed: Set<String> = []
  /// Normalized laser point from the presenter's trackpad.
  var laser: CGPoint?

  @Environment(\.slideCanvasSize) private var size
  /// When this slide first appeared. Elements arriving later (a line added from the desk) use the insert motion.
  @State private var mountedAt = Date()

  var body: some View {
    ZStack(alignment: .topLeading) {
      SlideBackground(slide: slide)
      if SlideLayoutEngine.imageIsBackdrop(slide) {
        backdrop
      }
      if SlideLayoutEngine.hasSideCard(slide) {
        sideCard
      }
      ForEach(SlideLayoutEngine.textElements(for: slide)) { element in
        let frame = SlideLayoutEngine.frame(for: element, in: slide, canvas: size)
        textView(element, frame: frame)
          .opacity(suppressed.contains(element.id) ? 0 : 1)
          .scaleEffect(frame.scale)
          .rotationEffect(.degrees(frame.rotation))
          .anchorPreference(key: SlideElementBoundsKey.self, value: .bounds) { [element.id: $0] }
          .position(x: frame.x * size.width, y: frame.y * size.height)
          .modifier(Entrance(kind: element.kind, enabled: animated, mountedAt: mountedAt))
      }
      SlideDecor(slide: slide)
      if let laser {
        LaserDot()
          .position(x: laser.x * size.width, y: laser.y * size.height)
          .allowsHitTesting(false)
      }
    }
    .frame(width: size.width, height: size.height)
    .clipped()
  }

  // MARK: Text

  @ViewBuilder
  private func textView(_ element: SlideElement, frame: ElementFrame) -> some View {
    let color = SlideLayoutEngine.textColor(slide)
    switch element.kind {
    case .title:
      let leading = SlideLayoutEngine.titleIsLeftAligned(slide)
      Text(slide.title)
        .font(SlideLayoutEngine.titleFont(slide.layout, canvas: size))
        .tracking(slide.layout == .statement ? -0.5 : -1.5)
        .foregroundStyle(color)
        .multilineTextAlignment(leading ? .leading : .center)
        .frame(width: frame.width * size.width, alignment: leading ? .leading : .center)
        .fixedSize(horizontal: false, vertical: true)
    case .body(let i):
      let leading = SlideLayoutEngine.isLeftAligned(slide)
      HStack(alignment: .firstTextBaseline, spacing: 14) {
        if slide.layout == .twoColumn {
          Circle().fill(Theme.coral).frame(width: 10, height: 10).offset(y: -4)
        }
        Text(slide.bodyLines.indices.contains(i) ? slide.bodyLines[i] : "")
          .font(SlideLayoutEngine.bodyFont(slide.layout, canvas: size))
          .foregroundStyle(color.opacity(0.72))
          .multilineTextAlignment(leading ? .leading : .center)
      }
      .frame(width: frame.width * size.width, alignment: leading ? .leading : .center)
      .fixedSize(horizontal: false, vertical: true)
    case .image:
      EmptyView()
    }
  }

  // MARK: Media

  private var backdrop: some View {
    GeneratedImageView(prompt: slide.imagePrompt ?? slide.title, url: slide.imageURL, animated: animated)
      .frame(width: size.width, height: size.height)
      .overlay(LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.62)], startPoint: .top, endPoint: .bottom))
      .clipped()
      .anchorPreference(key: SlideElementBoundsKey.self, value: .bounds) { ["image": $0] }
  }

  /// The media card. Placed with leading/top padding (which is layout, unlike an offset), so the inserted
  /// view's trailing edge is the card's trailing edge and the grow transition anchors on the crease.
  private var sideCard: some View {
    let frame = SlideLayoutEngine.frame(for: SlideElement(kind: .image), in: slide, canvas: size)
    let width = frame.width * size.width
    let height = frame.height * size.height
    let left = frame.x * size.width - width / 2
    let top = frame.y * size.height - height / 2
    return MediaCard(slide: slide, animated: animated)
      .frame(width: width, height: height)
      .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
      .shadow(color: .black.opacity(0.14), radius: 26, y: 14)
      .scaleEffect(frame.scale)
      .anchorPreference(key: SlideElementBoundsKey.self, value: .bounds) { ["image": $0] }
      // Room for the shadow, so the transition mask doesn't clip it.
      .padding(.trailing, CreaseGrow.shadowRoom)
      .padding(.bottom, CreaseGrow.shadowRoom)
      .padding(.leading, max(left, 0))
      .padding(.top, max(top, 0))
      .transition(.creaseGrow(cardWidth: width, cardHeight: height, left: max(left, 0), top: max(top, 0)))
      .id(slide.media ?? SlideMedia(kind: .image, source: slide.imagePrompt ?? slide.imageURL ?? "", title: ""))
  }
}

/// Media card entrance: grows from the crease (trailing) edge from 0 to full width,
/// scale 0.96 to 1, opacity 0 to 1. Removal runs it backwards.
private struct CreaseGrow: ViewModifier, Animatable {
  static let shadowRoom: CGFloat = 60

  var progress: Double
  let cardWidth: CGFloat
  let cardHeight: CGFloat
  let left: CGFloat
  let top: CGFloat

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func body(content: Content) -> some View {
    let totalWidth = left + cardWidth + Self.shadowRoom
    let totalHeight = top + cardHeight + Self.shadowRoom
    // Scale around the middle of the card's trailing (crease) edge.
    let anchor = UnitPoint(x: (left + cardWidth) / totalWidth, y: (top + cardHeight / 2) / totalHeight)
    // The visible band starts at the card's crease edge and widens toward the leading edge.
    let band = progress >= 1 ? totalWidth : Self.shadowRoom + cardWidth * progress
    return content
      .mask(alignment: .trailing) {
        Rectangle().frame(width: max(band, 0.01))
      }
      .scaleEffect(0.96 + 0.04 * progress, anchor: anchor)
      .opacity(progress)
  }
}

extension AnyTransition {
  static func creaseGrow(cardWidth: CGFloat, cardHeight: CGFloat, left: CGFloat, top: CGFloat) -> AnyTransition {
    .modifier(
      active: CreaseGrow(progress: 0, cardWidth: cardWidth, cardHeight: cardHeight, left: left, top: top),
      identity: CreaseGrow(progress: 1, cardWidth: cardWidth, cardHeight: cardHeight, left: left, top: top)
    )
  }
}

/// Picks what to show in the card: an inserted video, image or animation, or the slide's generated image.
struct MediaCard: View {
  let slide: Slide
  var animated = true

  var body: some View {
    if let media = slide.media {
      switch media.kind {
      case .video:
        LoopingVideo(source: media.source, startDelay: animated ? 0.5 : 0)
      case .image:
        GeneratedImageView(prompt: media.source, url: URL(string: media.source)?.scheme == nil ? nil : media.source, animated: animated)
      case .animation:
        AnimationPreset(rawValue: media.source).map { AnimationPresetView(preset: $0) }
      }
    } else {
      GeneratedImageView(prompt: slide.imagePrompt ?? slide.title, url: slide.imageURL, animated: animated)
    }
  }
}

private struct LaserDot: View {
  var body: some View {
    ZStack {
      Circle().fill(Color.red.opacity(0.25)).frame(width: 64, height: 64).blur(radius: 10)
      Circle().fill(Color.red).frame(width: 20, height: 20)
      Circle().fill(.white.opacity(0.9)).frame(width: 7, height: 7)
    }
  }
}

private struct SlideEntranceEnabledKey: EnvironmentKey {
  static let defaultValue = true
}

extension EnvironmentValues {
  /// Off for offscreen snapshots, which never fire onAppear.
  var slideEntranceEnabled: Bool {
    get { self[SlideEntranceEnabledKey.self] }
    set { self[SlideEntranceEnabledKey.self] = newValue }
  }
}

/// First appearance: title lands (rise + settle), body lines fade up one after another, each under 600 ms.
/// A line added later (from the desk) fades and rises 8 points into place over 300 ms; the others stay.
private struct Entrance: ViewModifier {
  let kind: SlideElement.Kind
  let enabled: Bool
  let mountedAt: Date
  @State private var shown = false
  @State private var isLateInsert = false
  @Environment(\.slideEntranceEnabled) private var environmentEnabled

  func body(content: Content) -> some View {
    let enabled = enabled && environmentEnabled
    return content
      .opacity(shown || !enabled ? 1 : 0)
      .offset(y: shown || !enabled ? 0 : offset)
      .blur(radius: shown || !enabled || isLateInsert ? 0 : (kind == .title ? 8 : 0))
      .onAppear {
        guard enabled, !shown else { return }
        isLateInsert = Date().timeIntervalSince(mountedAt) > 0.3
        if isLateInsert {
          withAnimation(.easeOut(duration: 0.3)) { shown = true }
        } else {
          withAnimation(kind == .title ? Theme.land.delay(delay) : Theme.fade.delay(delay)) { shown = true }
        }
      }
  }

  private var delay: Double {
    switch kind {
    case .image: 0
    case .title: 0.08
    case .body(let i): 0.34 + 0.12 * Double(i)
    }
  }

  private var offset: CGFloat {
    if isLateInsert { return 8 }
    switch kind {
    case .title: return 28
    case .body: return 14
    case .image: return 0
    }
  }
}

struct SlideBackground: View {
  let slide: Slide
  @Environment(\.slideCanvasSize) private var size

  var body: some View {
    let big = max(size.width, size.height)
    switch slide.layout {
    case .cover:
      ZStack {
        Color.white
        Circle().fill(Theme.coral).frame(width: big * 0.55).blur(radius: 150).offset(x: -size.width * 0.34, y: size.height * 0.42).opacity(0.32)
        Circle().fill(Theme.violet).frame(width: big * 0.5).blur(radius: 160).offset(x: size.width * 0.36, y: -size.height * 0.38).opacity(0.26)
      }
    case .statement:
      Theme.paper
    case .twoColumn:
      ZStack {
        Color.white
        Circle().fill(Theme.sky).frame(width: big * 0.45).blur(radius: 170).offset(x: size.width * 0.42, y: size.height * 0.46).opacity(0.14)
      }
    case .live:
      ZStack {
        Color(hex: 0xFBFAF7)
        DotGrid(spacing: 30, color: .black.opacity(0.07), dot: 2)
      }
    case .close:
      ZStack {
        Theme.coral
        Circle().fill(Color(hex: 0xFFB36B)).frame(width: big * 0.6).blur(radius: 180).offset(x: size.width * 0.3, y: -size.height * 0.4).opacity(0.7)
      }
    }
  }
}

/// Fixed decoration that isn't movable: the LIVE pill, the mark on the cover.
private struct SlideDecor: View {
  let slide: Slide

  var body: some View {
    switch slide.layout {
    case .live:
      HStack(spacing: 10) {
        LivePulse()
        Text("LIVE").font(.system(size: 18, weight: .bold)).tracking(3)
      }
      .foregroundStyle(Theme.ink)
      .padding(.horizontal, 18).padding(.vertical, 10)
      .background(Capsule().fill(.white).shadow(color: .black.opacity(0.08), radius: 10, y: 3))
      .padding(44)
    case .cover:
      Text("FLIPSIDE")
        .font(.system(size: 16, weight: .bold)).tracking(5)
        .foregroundStyle(SlideLayoutEngine.textColor(slide).opacity(0.5))
        .padding(48)
    default:
      EmptyView()
    }
  }
}

private struct LivePulse: View {
  var body: some View {
    TimelineView(.animation) { context in
      let pulse = (sin(context.date.timeIntervalSinceReferenceDate * 3) + 1) / 2
      Circle()
        .fill(Theme.coral)
        .frame(width: 12, height: 12)
        .background(Circle().fill(Theme.coral.opacity(0.3)).scaleEffect(1 + pulse * 1.2))
    }
  }
}

struct DotGrid: View {
  var spacing: CGFloat = 24
  var color: Color = .black.opacity(0.06)
  var dot: CGFloat = 1.6

  var body: some View {
    Canvas { context, size in
      var y = spacing / 2
      while y < size.height {
        var x = spacing / 2
        while x < size.width {
          context.fill(Path(ellipseIn: CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)), with: .color(color))
          x += spacing
        }
        y += spacing
      }
    }
    .allowsHitTesting(false)
  }
}
