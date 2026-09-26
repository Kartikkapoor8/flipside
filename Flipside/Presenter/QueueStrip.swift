import SwiftUI

/// The deck as a queue: a plain vertical list of equal cards, 8 point gaps, scrolling when it does
/// not fit. Current card lit, NEXT on the one after it, played ones dimmed. Tap to jump, press and
/// drag to reorder. Thumbnails come from the audience renderer at reduced scale.
struct QueueStrip: View {
    let model: StudioModel
    var namespace: Namespace.ID

    @State private var dragging: (id: String, offset: CGSize)?

    private let gap: CGFloat = 8
    static let thumb: CGFloat = 56

    var body: some View {
        let slides = model.app.deck.slides
        let current = model.app.currentIndex
        let aspect = max(model.artifactAspect, 0.8)
        let angle = model.app.hingeAngle
        let cardHeight = Self.thumb / aspect + 12
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: gap) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                        QueueCard(
                            slide: slide,
                            index: index,
                            isCurrent: index == current,
                            isPast: index < current,
                            isNext: index == current + 1,
                            aspect: aspect,
                            hingeAngle: angle
                        )
                        .frame(height: cardHeight)
                        .matchedGeometryEffect(id: "queue.\(slide.id)", in: namespace)
                        .offset(dragging?.id == slide.id ? dragging!.offset : .zero)
                        .zIndex(dragging?.id == slide.id ? 1 : 0)
                        .deskPress { model.select(slide: index) }
                        .simultaneousGesture(reorderGesture(for: slide, pitch: cardHeight + gap))
                        .id(slide.id)
                    }
                }
            }
            .onChange(of: current) { _, i in
                guard slides.indices.contains(i) else { return }
                withAnimation(DeskMotion.crossfade) { proxy.scrollTo(slides[i].id, anchor: .center) }
            }
        }
        .animation(Theme.land, value: current)
        .animation(DeskMotion.crossfade, value: slides.map(\.id))
        .accessibilityLabel("Slide queue")
    }

    /// Hold, then drag along the list. Each card pitch crossed moves the slide one slot.
    private func reorderGesture(for slide: Slide, pitch: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 4))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                dragging = (slide.id, drag.translation)
            }
            .onEnded { value in
                defer { withAnimation(Theme.land) { dragging = nil } }
                guard case .second(true, let drag?) = value else { return }
                let steps = Int((drag.translation.height / pitch).rounded())
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
    let hingeAngle: Double

    var body: some View {
        HStack(spacing: 8) {
            SlideView(slide: slide, animated: false, aspect: aspect, cornerRadius: 6)
                .frame(width: QueueStrip.thumb)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isCurrent ? Theme.coral : Theme.line, lineWidth: isCurrent ? 2 : 1)
                )
                .overlay(alignment: .topLeading) {
                    Text(isNext ? "NEXT" : "\(index + 1)")
                        .font(.system(size: 9, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(isCurrent ? Theme.coral : (isNext ? Theme.ink : Theme.ink.opacity(0.6))))
                        .padding(3)
                }
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
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .glassEffect(isCurrent ? .regular.tint(Theme.coral.opacity(0.12)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 12))
        .hingeHighlight(RoundedRectangle(cornerRadius: 12, style: .continuous), angle: hingeAngle)
        .opacity(isPast ? 0.45 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}
