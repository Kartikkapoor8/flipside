import SwiftUI

/// The editable, full-screen artifact. Tap an element to select it (a generous hit area around it),
/// tap it again to edit its text, drag to move (snapping to the centre and to other elements),
/// drag a corner or pinch to resize.
struct SlideCanvasEditor: View {
  @Bindable var model: StudioModel
  let slide: Slide

  static let space = "slide-canvas"

  var body: some View {
    FittedSlide { scale in
      CanvasContent(model: model, slide: slide, scale: scale)
    }
  }
}

private struct CanvasContent: View {
  @Bindable var model: StudioModel
  let slide: Slide
  let scale: CGFloat
  @Environment(\.slideCanvasSize) private var canvas

  var body: some View {
    SlideSurface(slide: slide, animated: true, suppressed: model.editing.map { [$0] } ?? [], laser: model.app.laserPoint)
      .contentShape(Rectangle())
      .onTapGesture {
        model.editing = nil
        model.selection = nil
      }
      .overlayPreferenceValue(SlideElementBoundsKey.self) { anchors in
        GeometryReader { proxy in
          let elements = SlideLayoutEngine.elements(for: slide)
          ZStack(alignment: .topLeading) {
            ForEach(elements) { element in
              if let anchor = anchors[element.id] {
                ElementHandle(
                  model: model,
                  slide: slide,
                  element: element,
                  rect: proxy[anchor],
                  canvasScale: scale,
                  otherFrames: otherFrames(except: element.id, anchors: anchors, proxy: proxy)
                )
              }
            }
            GuidesLayer(guides: model.guides, canvasScale: scale)
          }
          .coordinateSpace(.named(SlideCanvasEditor.space))
        }
      }
  }

  private func otherFrames(except id: String, anchors: [String: Anchor<CGRect>], proxy: GeometryProxy) -> [CGRect] {
    // A backdrop image covers the whole slide, so it is not a useful snap target.
    let skipImage = SlideLayoutEngine.imageIsBackdrop(slide)
    return anchors
      .filter { $0.key != id && !(skipImage && $0.key == "image") }
      .map { proxy[$0.value] }
  }
}

private struct ElementHandle: View {
  @Bindable var model: StudioModel
  let slide: Slide
  let element: SlideElement
  let rect: CGRect
  let canvasScale: CGFloat
  let otherFrames: [CGRect]

  @Environment(\.slideCanvasSize) private var size
  @State private var dragStart: ElementFrame?
  @State private var pinchStart: ElementFrame?
  @State private var resizeStart: (frame: ElementFrame, distance: CGFloat)?
  @FocusState private var focused: Bool

  private var isSelected: Bool { model.selection == element.id }
  private var isEditing: Bool { model.editing == element.id }
  /// One on-screen point in canvas units, so chrome keeps a constant size however the slide is scaled.
  private var px: CGFloat { 1 / max(canvasScale, 0.05) }
  /// Extra touch area around each element, in on-screen points.
  private var slop: CGFloat { 14 * px }
  /// A backdrop image fills the slide; tapping empty space shouldn't grab it. Select it from Layers.
  private var isBackdrop: Bool { element.kind == .image && SlideLayoutEngine.imageIsBackdrop(slide) }

  var body: some View {
    ZStack {
      if isEditing {
        editor
      } else {
        Rectangle()
          .fill(Color.white.opacity(0.001))
          .overlay { chrome }
      }
    }
    .frame(width: rect.width, height: rect.height)
    .contentShape(Rectangle().inset(by: -slop))
    .position(x: rect.midX, y: rect.midY)
    .gesture(isEditing ? nil : drag)
    .simultaneousGesture(isSelected && !isEditing ? pinch : nil)
    .onTapGesture { model.tap(element.id) }
    .allowsHitTesting(!isBackdrop || isSelected)
  }

  /// Drawn in the element's own bounds (the touch slop around it doesn't change them).
  @ViewBuilder
  private var chrome: some View {
    if isSelected {
      let knob = 14 * px
      let inset = 6 * px
      ZStack(alignment: .topLeading) {
        Rectangle()
          .strokeBorder(Theme.selection, lineWidth: 2 * px)
          .padding(-inset)
        ForEach(0..<4, id: \.self) { corner in
          Circle()
            .fill(.white)
            .overlay(Circle().strokeBorder(Theme.selection, lineWidth: 2 * px))
            .shadow(color: .black.opacity(0.18), radius: 3 * px, y: 1 * px)
            .frame(width: knob, height: knob)
            .frame(width: 44 * px, height: 44 * px)
            .contentShape(Rectangle())
            .position(
              x: corner % 2 == 0 ? -inset : rect.width + inset,
              y: corner < 2 ? -inset : rect.height + inset
            )
            .gesture(resize)
        }
        Text(isBackdrop ? "Background image" : element.label)
          .font(.system(size: 11 * px, weight: .semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 7 * px).padding(.vertical, 3 * px)
          .background(Capsule().fill(Theme.selection))
          .fixedSize()
          .offset(x: -inset, y: -inset - 24 * px)
      }
      .frame(width: rect.width, height: rect.height, alignment: .topLeading)
    }
  }

  private var editor: some View {
    let binding = Binding(
      get: { model.text(of: element.id) },
      set: { model.setText($0, of: element.id) }
    )
    let leading = SlideLayoutEngine.isLeftAligned(slide)
    let isTitle = element.kind == .title
    return TextField("", text: binding, axis: .vertical)
      .font(isTitle ? SlideLayoutEngine.titleFont(slide.layout, canvas: size) : SlideLayoutEngine.bodyFont(slide.layout, canvas: size))
      .foregroundStyle(SlideLayoutEngine.textColor(slide))
      .tint(Theme.selection)
      .multilineTextAlignment(leading ? .leading : .center)
      .scaleEffect(SlideLayoutEngine.frame(for: element, in: slide, canvas: size).scale)
      .frame(width: max(rect.width, 200))
      .background(Theme.selection.opacity(0.06))
      .overlay(Rectangle().strokeBorder(Theme.selection, lineWidth: 2 * px).padding(-6 * px))
      .focused($focused)
      .onAppear { focused = true }
      .onSubmit { model.editing = nil }
  }

  // MARK: Gestures

  private var drag: some Gesture {
    DragGesture(minimumDistance: 4, coordinateSpace: .named(SlideCanvasEditor.space))
      .onChanged { value in
        guard let base = dragStart ?? startDrag() else { return }
        var frame = base
        let (x, y, guides) = snap(
          x: base.x + value.translation.width / size.width,
          y: base.y + value.translation.height / size.height
        )
        frame.x = min(max(x, 0), 1)
        frame.y = min(max(y, 0), 1)
        model.guides = guides
        model.setFrame(frame, for: element.id)
      }
      .onEnded { _ in
        dragStart = nil
        model.guides = []
      }
  }

  private func startDrag() -> ElementFrame? {
    guard let frame = model.frame(of: element.id) else { return nil }
    model.checkpoint()
    model.editing = nil
    model.selection = element.id
    dragStart = frame
    return frame
  }

  private var pinch: some Gesture {
    MagnifyGesture()
      .onChanged { value in
        if pinchStart == nil {
          model.checkpoint()
          pinchStart = model.frame(of: element.id)
        }
        guard let start = pinchStart else { return }
        model.setFrame(resized(start, by: value.magnification), for: element.id)
      }
      .onEnded { _ in pinchStart = nil }
  }

  private var resize: some Gesture {
    DragGesture(minimumDistance: 1, coordinateSpace: .named(SlideCanvasEditor.space))
      .onChanged { value in
        let center = CGPoint(x: rect.midX, y: rect.midY)
        if resizeStart == nil, let frame = model.frame(of: element.id) {
          model.checkpoint()
          let startDistance = hypot(value.startLocation.x - center.x, value.startLocation.y - center.y)
          resizeStart = (frame, max(startDistance, 1))
        }
        guard let start = resizeStart else { return }
        let distance = hypot(value.location.x - center.x, value.location.y - center.y)
        model.setFrame(resized(start.frame, by: distance / start.distance), for: element.id)
      }
      .onEnded { _ in resizeStart = nil }
  }

  /// Images resize their box; text scales its type.
  private func resized(_ start: ElementFrame, by factor: CGFloat) -> ElementFrame {
    var frame = start
    if element.kind == .image {
      frame.width = min(max(start.width * factor, 0.08), 1.2)
      frame.height = min(max(start.height * factor, 0.08), 1.2)
    } else {
      frame.scale = min(max(start.scale * factor, 0.3), 3)
    }
    return frame
  }

  /// Snaps the element's centre to the slide centre and to other elements' centres or left edges,
  /// within 10 on-screen points.
  private func snap(x: Double, y: Double) -> (Double, Double, [SnapGuide]) {
    let xThreshold = 10 * px / size.width
    let yThreshold = 10 * px / size.height
    let halfWidth = rect.width / 2 / size.width
    var x = x
    var y = y
    var guides: [SnapGuide] = []

    var xTargets: [Double] = [0.5]
    var leftTargets: [Double] = [0.06]
    var yTargets: [Double] = [0.5]
    for other in otherFrames {
      xTargets.append(other.midX / size.width)
      leftTargets.append(other.minX / size.width)
      yTargets.append(other.midY / size.height)
    }

    if let hit = xTargets.min(by: { abs($0 - x) < abs($1 - x) }), abs(hit - x) < xThreshold {
      x = hit
      guides.append(SnapGuide(axis: .vertical, value: hit))
    } else if let left = leftTargets.min(by: { abs($0 - (x - halfWidth)) < abs($1 - (x - halfWidth)) }),
              abs(left - (x - halfWidth)) < xThreshold {
      x = left + halfWidth
      guides.append(SnapGuide(axis: .vertical, value: left))
    }
    if let hit = yTargets.min(by: { abs($0 - y) < abs($1 - y) }), abs(hit - y) < yThreshold {
      y = hit
      guides.append(SnapGuide(axis: .horizontal, value: hit))
    }
    return (x, y, guides)
  }
}

private struct GuidesLayer: View {
  let guides: [SnapGuide]
  let canvasScale: CGFloat
  @Environment(\.slideCanvasSize) private var size

  var body: some View {
    let width = 1.5 / max(canvasScale, 0.05)
    ZStack(alignment: .topLeading) {
      ForEach(guides, id: \.self) { guide in
        switch guide.axis {
        case .vertical:
          Rectangle().fill(Theme.coral)
            .frame(width: width, height: size.height)
            .position(x: guide.value * size.width, y: size.height / 2)
        case .horizontal:
          Rectangle().fill(Theme.coral)
            .frame(width: size.width, height: width)
            .position(x: size.width / 2, y: guide.value * size.height)
        }
      }
    }
    .frame(width: size.width, height: size.height)
    .allowsHitTesting(false)
  }
}
