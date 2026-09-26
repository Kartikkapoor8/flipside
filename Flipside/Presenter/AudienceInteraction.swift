import SwiftUI

/// The audience half answers touch too. Swipe left or right moves through the cards with the same
/// crossfade the desk uses; a tap on a slide's media card grows it to full bleed, another tap puts
/// it back. The presenter's Next and the cue still drive the deck underneath.
struct AudienceInteraction: ViewModifier {
    let model: StudioModel
    @State private var expanded = false
    @State private var overlayShown = false
    @State private var clientFade: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay {
                if model.app.mode == .present, let slide = model.current {
                    GeometryReader { proxy in
                        let size = proxy.size
                        let card = Self.mediaRect(for: slide, in: size)
                        ZStack(alignment: .topLeading) {
                            if let card {
                                // Invisible tap target over the media card.
                                Color.clear
                                    .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                                    .frame(width: card.width, height: card.height)
                                    .offset(x: card.minX, y: card.minY)
                                    .onTapGesture { expand(true) }
                                    .accessibilityLabel("Expand \(slide.media?.title ?? "media")")
                            }
                            if overlayShown, let card {
                                let full = CGRect(origin: .zero, size: size)
                                let rect = expanded ? full : card
                                MediaCard(slide: slide, animated: false)
                                    .frame(width: rect.width, height: rect.height)
                                    .clipShape(RoundedRectangle(cornerRadius: expanded ? 0 : 26, style: .continuous))
                                    .shadow(color: .black.opacity(expanded ? 0 : 0.14), radius: 26, y: 14)
                                    .offset(x: rect.minX, y: rect.minY)
                                    .contentShape(Rectangle())
                                    .onTapGesture { expand(false) }
                                    .accessibilityLabel("Collapse media")
                            }
                        }
                    }
                    .id(slide.id)
                }
            }
            .simultaneousGesture(swipe)
            .overlay {
                // The point scene: a touch puts the client's dot on the card, gone 1.5 s after release.
                if model.app.mode == .present, model.current?.scene == "point" {
                    GeometryReader { proxy in
                        Color.clear.contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { v in
                                        clientFade?.cancel()
                                        model.app.clientPoint = CGPoint(x: min(max(v.location.x / proxy.size.width, 0), 1),
                                                                        y: min(max(v.location.y / proxy.size.height, 0), 1))
                                    }
                                    .onEnded { _ in
                                        clientFade = Task { @MainActor in
                                            try? await Task.sleep(for: .milliseconds(1500))
                                            if !Task.isCancelled { withAnimation(Theme.fade) { model.app.clientPoint = nil } }
                                        }
                                    }
                            )
                    }
                }
            }
            .onChange(of: model.app.currentIndex) { _, _ in
                expanded = false
                overlayShown = false
            }
    }

    private func expand(_ open: Bool) {
        if open {
            overlayShown = true
            withAnimation(Theme.land) { expanded = true }
        } else {
            withAnimation(Theme.land) { expanded = false }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(520))
                if !expanded { overlayShown = false }
            }
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard model.app.mode == .present, !expanded else { return }
                let dx = value.translation.width, dy = value.translation.height
                guard abs(dx) > abs(dy) * 1.2, abs(dx) > 40 else { return }
                // Flipped for someone across the table, their left is our right.
                let forward = model.app.audienceFlipped ? dx > 0 : dx < 0
                if forward { model.next() } else { model.back() }
            }
    }

    /// Where the media card sits on the face. `FittedSlide` with no aspect fills the face, so the
    /// normalised frame maps straight onto the face's size.
    static func mediaRect(for slide: Slide, in size: CGSize) -> CGRect? {
        guard size.width > 0, size.height > 0, SlideLayoutEngine.hasSideCard(slide) else { return nil }
        let canvas = SlideCanvas.size(forAspect: size.width / size.height)
        let frame = SlideLayoutEngine.frame(for: SlideElement(kind: .image), in: slide, canvas: canvas)
        let width = frame.width * size.width * frame.scale
        let height = frame.height * size.height * frame.scale
        return CGRect(x: frame.x * size.width - width / 2, y: frame.y * size.height - height / 2, width: width, height: height)
    }
}

extension View {
    func audienceInteractive(_ model: StudioModel) -> some View {
        modifier(AudienceInteraction(model: model))
    }
}
