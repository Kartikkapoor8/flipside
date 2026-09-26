import SwiftUI

/// The deck as a queue. Standing, a horizontal strip below the notes: the current card sits at the
/// leading anchor, upcoming cards run off to the right, played cards sit dimmed to the left.
/// As the phone lays flat (`verticalness` 0 to 1) the strip turns into a column. Tap to jump.
/// Thumbnails come from the audience renderer at reduced scale.
struct QueueStrip: View {
    let model: StudioModel
    /// 0 = horizontal strip, 1 = vertical list. Driven by the fold.
    var verticalness: Double
    var namespace: Namespace.ID

    var body: some View {
        let slides = model.app.deck.slides
        let current = model.app.currentIndex
        let aspect = max(model.artifactAspect, 0.8)
        QueueLayout(verticalness: verticalness, currentIndex: current, aspect: aspect) {
            ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                QueueCard(
                    slide: slide,
                    index: index,
                    isCurrent: index == current,
                    isPast: index < current,
                    aspect: aspect,
                    showsTitle: verticalness > 0.6
                )
                .matchedGeometryEffect(id: "queue.\(slide.id)", in: namespace)
                .onTapGesture { model.select(slide: index) }
            }
        }
        .clipped()
        .animation(Theme.land, value: current)
        .accessibilityLabel("Slide queue")
    }
}

private struct QueueCard: View {
    let slide: Slide
    let index: Int
    let isCurrent: Bool
    let isPast: Bool
    let aspect: CGFloat
    let showsTitle: Bool

    var body: some View {
        HStack(spacing: 8) {
            SlideView(slide: slide, animated: false, aspect: aspect, cornerRadius: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isCurrent ? Theme.coral : Theme.line, lineWidth: isCurrent ? 2 : 1)
                )
                .overlay(alignment: .topLeading) {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(isCurrent ? Theme.coral : Theme.ink.opacity(0.6)))
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
        .opacity(isPast ? 0.45 : 1)
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

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 300, height: proposal.height ?? 96)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let v = min(max(verticalness, 0), 1)
        let count = subviews.count
        guard count > 0 else { return }

        // Row geometry: card height = bounds height, width from the slide aspect plus padding.
        let rowH = bounds.height
        let rowW = (rowH - 12) * aspect + 12
        // Column geometry: card width = bounds width, thumbnail 56 wide beside a title.
        let colW = bounds.width
        let colH: CGFloat = 56 / aspect + 12
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
