import SwiftUI

/// The deck as a queue. Standing, a horizontal strip below the notes: the current card sits at the
/// leading anchor, upcoming cards run off to the right, played cards sit dimmed to the left.
/// As the phone lays flat (`verticalness` 0 to 1) the strip turns into a column. Tap to jump,
/// press and drag to reorder. Thumbnails come from the audience renderer at reduced scale.
struct QueueStrip: View {
    let model: StudioModel
    /// 0 = horizontal strip, 1 = vertical list. Driven by the fold.
    var verticalness: Double
    var namespace: Namespace.ID

    @State private var dragging: (id: String, offset: CGSize)?
    @State private var rowHeight: CGFloat = DeskFrames.queueRowHeight

    var body: some View {
        let slides = model.app.deck.slides
        let current = model.app.currentIndex
        let aspect = max(model.artifactAspect, 0.8)
        let angle = model.app.hingeAngle
        QueueLayout(verticalness: verticalness, currentIndex: current, aspect: aspect) {
            ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                QueueCard(
                    slide: slide,
                    index: index,
                    isCurrent: index == current,
                    isPast: index < current,
                    isNext: index == current + 1,
                    aspect: aspect,
                    showsTitle: verticalness > 0.6,
                    hingeAngle: angle
                )
                .matchedGeometryEffect(id: "queue.\(slide.id)", in: namespace)
                .offset(dragging?.id == slide.id ? dragging!.offset : .zero)
                .zIndex(dragging?.id == slide.id ? 1 : 0)
                .deskPress { model.select(slide: index) }
                .simultaneousGesture(reorderGesture(for: slide, at: index, aspect: aspect))
            }
        }
        .clipped()
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { rowHeight = $0 }
        .animation(Theme.land, value: current)
        .animation(DeskMotion.crossfade, value: slides.map(\.id))
        .accessibilityLabel("Slide queue")
    }

    /// Hold, then drag along the strip's main axis. Each card pitch crossed moves the slide one slot.
    private func reorderGesture(for slide: Slide, at index: Int, aspect: CGFloat) -> some Gesture {
        let vertical = verticalness > 0.5
        // Card pitch in the current orientation (see QueueLayout).
        let pitch: CGFloat = vertical ? (QueueLayout.thumb / aspect + 12 + 8) : ((min(rowHeight, DeskFrames.queueRowMax) - 12) * aspect + 12 + 8)
        return LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 4))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                dragging = (slide.id, drag.translation)
            }
            .onEnded { value in
                defer { withAnimation(Theme.land) { dragging = nil } }
                guard case .second(true, let drag?) = value else { return }
                let travel = vertical ? drag.translation.height : drag.translation.width
                let steps = Int((travel / pitch).rounded())
                guard steps != 0, let from = model.app.deck.slides.firstIndex(where: { $0.id == slide.id }) else { return }
                let to = min(max(from + steps, 0), model.app.deck.slides.count - 1)
                guard to != from else { return }
                model.moveSlides(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
            }
    }
}

private struct QueueCard: View {
    let slide: Slide
    let index: Int
    let isCurrent: Bool
    let isPast: Bool
    let isNext: Bool
    let aspect: CGFloat
    let showsTitle: Bool
    let hingeAngle: Double

    var body: some View {
        HStack(spacing: 8) {
            SlideView(slide: slide, animated: false, aspect: aspect, cornerRadius: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isCurrent ? Theme.coral : Theme.line, lineWidth: isCurrent ? 2 : 1)
                )
                .overlay(alignment: .topLeading) {
                    // Keynote's presenter display names the next slide; the rest carry their number.
                    Text(isNext ? "NEXT" : "\(index + 1)")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(isCurrent ? Theme.coral : (isNext ? Theme.ink : Theme.ink.opacity(0.6))))
                        .padding(4)
                }
            if showsTitle {
                VStack(alignment: .leading, spacing: 2) {
                    Text(slide.title.isEmpty ? "Untitled" : slide.title)
                        .font(.system(size: 12, weight: isCurrent ? .bold : .semibold))
                        .foregroundStyle(isCurrent ? Theme.coral : Theme.text)
                        .lineLimit(2)
                    Text(slide.layout.label)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
            }
        }
        .padding(6)
        .glassEffect(isCurrent ? .regular.tint(Theme.coral.opacity(0.12)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 12))
        .hingeHighlight(RoundedRectangle(cornerRadius: 12, style: .continuous), angle: hingeAngle)
        // Spotify's queue: the playing card lit, upcoming quieter, played ones faded.
        .opacity(isPast ? 0.45 : (isCurrent ? 1 : 0.82))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Places every card at a frame interpolated between its row slot and its column slot.
/// Row: cards of one height side by side, current card at the leading edge. Column: cards stacked,
/// full width, current card at the top. Past cards sit before the anchor in both.
struct QueueLayout: Layout {
    var verticalness: Double
    var currentIndex: Int
    var aspect: CGFloat

    var animatableData: Double {
        get { verticalness }
        set { verticalness = newValue }
    }

    private let gap: CGFloat = 8
    /// Column thumbnail width. Spotify keeps the art big enough to recognise.
    static let thumb: CGFloat = 72

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 300, height: proposal.height ?? 96)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let v = min(max(verticalness, 0), 1)
        let count = subviews.count
        guard count > 0 else { return }

        // Row geometry: card height = bounds height, width from the slide aspect plus padding.
        // Mid-fold the frame is already growing toward the column; the row cards keep their height.
        let rowH = min(bounds.height, DeskFrames.queueRowMax)
        let rowW = (rowH - 12) * aspect + 12
        // Column geometry: card width = bounds width, thumbnail 56 wide beside a title.
        let colW = bounds.width
        let colH: CGFloat = Self.thumb / aspect + 12
        // Past cards peek in before the anchor: about a third of a card.
        let rowAnchor = min(CGFloat(currentIndex), 1) * (rowW * 0.35 + gap)
        let colAnchor = min(CGFloat(currentIndex), 1) * (colH * 0.35 + gap)

        for (index, view) in subviews.enumerated() {
            let offset = CGFloat(index - currentIndex)
            let rowFrame = CGRect(
                x: bounds.minX + rowAnchor + offset * (rowW + gap),
                y: bounds.minY,
                width: rowW, height: rowH
            )
            let colFrame = CGRect(
                x: bounds.minX,
                y: bounds.minY + colAnchor + offset * (colH + gap),
                width: colW, height: colH
            )
            let frame = CGRect(
                x: rowFrame.minX + (colFrame.minX - rowFrame.minX) * v,
                y: rowFrame.minY + (colFrame.minY - rowFrame.minY) * v,
                width: rowFrame.width + (colFrame.width - rowFrame.width) * v,
                height: rowFrame.height + (colFrame.height - rowFrame.height) * v
            )
            view.place(at: frame.origin, proposal: ProposedViewSize(frame.size))
        }
    }
}
