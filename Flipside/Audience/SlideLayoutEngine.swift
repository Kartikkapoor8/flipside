import SwiftUI

/// Slides are full-screen artifacts: they fill whatever space they are shown in.
/// Content is laid out on a design canvas 1200 points wide whose height follows the space's shape,
/// then scaled to fit, so a slide reflows between side-by-side (tall) and stacked (wide) modes.
enum SlideCanvas {
  static let designWidth: CGFloat = 1200
  /// Height used when nothing gives a shape, e.g. `deck.json` PNG exports.
  static let defaultSize = CGSize(width: 1200, height: 630)

  static func size(forAspect aspect: CGFloat) -> CGSize {
    let clamped = min(max(aspect, 0.3), 3.6)
    return CGSize(width: designWidth, height: (designWidth / clamped).rounded())
  }
}

private struct SlideCanvasSizeKey: EnvironmentKey {
  static let defaultValue = SlideCanvas.defaultSize
}

extension EnvironmentValues {
  /// Design size of the slide being rendered.
  var slideCanvasSize: CGSize {
    get { self[SlideCanvasSizeKey.self] }
    set { self[SlideCanvasSizeKey.self] = newValue }
  }
}

/// A movable thing on a slide. Ids are stable strings so positions survive edits:
/// `title`, `body.0`, `body.1`, …, `image`.
struct SlideElement: Identifiable, Hashable {
  enum Kind: Hashable {
    case title
    case body(Int)
    case image
  }

  let kind: Kind

  var id: String {
    switch kind {
    case .title: "title"
    case .body(let i): "body.\(i)"
    case .image: "image"
    }
  }

  var isText: Bool {
    if case .image = kind { return false }
    return true
  }

  var label: String {
    switch kind {
    case .title: "Title"
    case .body(let i): "Line \(i + 1)"
    case .image: "Image"
    }
  }
}

enum SlideLayoutEngine {
  static func elements(for slide: Slide) -> [SlideElement] {
    var result: [SlideElement] = []
    if hasImage(slide) {
      result.append(SlideElement(kind: .image))
    }
    if !slide.title.isEmpty {
      result.append(SlideElement(kind: .title))
    }
    for i in slide.bodyLines.indices {
      result.append(SlideElement(kind: .body(i)))
    }
    return result.filter { !slide.isHidden($0.id) }
  }

  static func textElements(for slide: Slide) -> [SlideElement] {
    elements(for: slide).filter(\.isText)
  }

  static func frame(for element: SlideElement, in slide: Slide, canvas: CGSize) -> ElementFrame {
    slide.positions?[element.id] ?? defaultFrame(for: element, in: slide, canvas: canvas)
  }

  /// The slide shows a picture, video or animation (inserted media or a generated image).
  static func hasImage(_ slide: Slide) -> Bool {
    (slide.media != nil || slide.imagePrompt != nil || slide.imageURL != nil) && !slide.isHidden("image")
  }

  /// Layouts that put a generated image behind the text.
  static func imageIsFullBleed(_ slide: Slide) -> Bool {
    switch slide.layout {
    case .cover, .statement, .close: true
    case .twoColumn, .live: false
    }
  }

  /// A generated image filling the slide behind the text. Inserted media is never a backdrop.
  static func imageIsBackdrop(_ slide: Slide) -> Bool {
    hasImage(slide) && slide.media == nil && imageIsFullBleed(slide) && slide.positions?["image"] == nil
  }

  /// Media sits as a card on the crease side and the text block takes the leading 45 percent.
  static func hasSideCard(_ slide: Slide) -> Bool {
    hasImage(slide) && !imageIsBackdrop(slide)
  }

  /// Body lines go flush left when they share the slide with a media card.
  static func isLeftAligned(_ slide: Slide) -> Bool {
    titleIsLeftAligned(slide) || hasSideCard(slide)
  }

  /// The title keeps its alignment when media arrives, so it doesn't move.
  static func titleIsLeftAligned(_ slide: Slide) -> Bool {
    slide.layout == .twoColumn || slide.layout == .live
  }

  static func isTall(_ canvas: CGSize) -> Bool { canvas.height > canvas.width * 0.9 }

  // Side-card split: text 0.05...0.45 on the leading side, media 0.475...0.955 toward the crease.
  static let textColumn = (x: 0.25, width: 0.40)
  static let mediaColumn = (x: 0.715, width: 0.48)

  static func defaultFrame(for element: SlideElement, in slide: Slide, canvas: CGSize) -> ElementFrame {
    let h = canvas.height
    let s = typeScale(canvas)
    let card = hasSideCard(slide)

    switch element.kind {
    case .image:
      if imageIsBackdrop(slide) { return ElementFrame(x: 0.5, y: 0.5, width: 1, height: 1) }
      let title = titleFrame(slide, canvas: canvas)
      let top = min(title.y + (titlePointSize(slide.layout) * s * 0.7 + 30) / h, 0.6)
      let bottom = 1 - max(0.08, 50 / h)
      return ElementFrame(x: mediaColumn.x, y: (top + bottom) / 2, width: mediaColumn.width, height: bottom - top)

    case .title:
      return titleFrame(slide, canvas: canvas)

    case .body(let i):
      // Line y never depends on how many lines there are or whether media is present,
      // so adding a line or a card never moves the existing lines vertically.
      let lineStep = 56 * s / h
      let listStep = 64 * s / h
      let y: Double
      switch slide.layout {
      case .cover: y = 0.44 + 0.13 * 630 / h + lineStep * Double(i)
      case .statement: y = 0.44 + 0.2 * 630 / h + lineStep * Double(i)
      case .twoColumn: y = max(0.34, 200 / h) + listStep * Double(i)
      case .live: y = 0.4 + 0.16 * 630 / h + listStep * Double(i)
      case .close: y = 0.44 + 0.18 * 630 / h + lineStep * Double(i)
      }
      if card { return ElementFrame(x: textColumn.x, y: y, width: textColumn.width) }
      let width = slide.layout == .twoColumn || slide.layout == .live ? 0.88 : 0.76
      return ElementFrame(x: 0.5, y: y, width: width)
    }
  }

  /// The title stays put whether or not media is on the slide.
  static func titleFrame(_ slide: Slide, canvas: CGSize) -> ElementFrame {
    let h = canvas.height
    switch slide.layout {
    case .cover: return ElementFrame(x: 0.5, y: 0.44, width: 0.84)
    case .statement: return ElementFrame(x: 0.5, y: 0.44, width: 0.82)
    case .twoColumn: return ElementFrame(x: 0.5, y: max(0.16, 110 / h), width: 0.88)
    case .live: return ElementFrame(x: 0.5, y: 0.4, width: 0.88)
    case .close: return ElementFrame(x: 0.5, y: 0.44, width: 0.8)
    }
  }

  // MARK: Type

  /// Type grows a little on tall canvases and shrinks on very wide ones so text fits the shape.
  static func typeScale(_ canvas: CGSize) -> CGFloat {
    min(max(canvas.height / 630, 0.62), 1.2)
  }

  static func titlePointSize(_ layout: SlideLayout) -> CGFloat {
    switch layout {
    case .cover: 88
    case .statement: 60
    case .twoColumn: 50
    case .live: 64
    case .close: 76
    }
  }

  static func titleFont(_ layout: SlideLayout, canvas: CGSize) -> Font {
    let size = titlePointSize(layout) * typeScale(canvas)
    return switch layout {
    case .cover: .system(size: size, weight: .heavy)
    case .statement: .system(size: size, weight: .semibold, design: .serif)
    case .twoColumn: .system(size: size, weight: .bold)
    case .live: .system(size: size, weight: .heavy)
    case .close: .system(size: size, weight: .heavy)
    }
  }

  static func bodyFont(_ layout: SlideLayout, canvas: CGSize) -> Font {
    let s = typeScale(canvas)
    return switch layout {
    case .cover: .system(size: 30 * s, weight: .medium)
    case .statement: .system(size: 28 * s, weight: .regular)
    case .twoColumn: .system(size: 28 * s, weight: .medium)
    case .live: .system(size: 30 * s, weight: .medium)
    case .close: .system(size: 30 * s, weight: .medium)
    }
  }

  static func textColor(_ slide: Slide) -> Color {
    if imageIsBackdrop(slide) || slide.layout == .close { return .white }
    return Theme.ink
  }
}

/// Collects each element's rendered bounds so the editor can draw selection chrome on top.
struct SlideElementBoundsKey: PreferenceKey {
  static let defaultValue: [String: Anchor<CGRect>] = [:]
  static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
    value.merge(nextValue()) { $1 }
  }
}
