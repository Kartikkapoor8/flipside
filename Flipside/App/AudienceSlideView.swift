import SwiftUI

/// The audience's view of one slide. Draws the pre-rendered PNG for the slide's id when the
/// bundle has one (`NN-<id>.png` from `assets/deck/slides/2400x1260`), scaled to fill the
/// width of the half. The 40:21 canvas is wider than a 669x475 half, so a true fill would crop
/// the left-aligned titles; the PNG background is Paper, so letterboxing on Paper is seamless. Otherwise a plain title-and-body card on the brand background, so a
/// generated deck still shows something before the teammate's renderer lands in `Audience/`.
struct AudienceSlideView: View {
    let slide: Slide

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image = SlideImageStore.image(for: slide.id) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    fallback
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .background(Brand.Audience.background)
    }

    private var fallback: some View {
        ZStack {
            Brand.Audience.background
            VStack(alignment: .leading, spacing: Brand.Space.s4) {
                Spacer(minLength: 0)
                Text(slide.title)
                    .font(slide.layout == .statement ? Brand.Font.slideStatement : Brand.Font.slideTitle)
                    .foregroundStyle(Brand.Audience.text)
                    .fixedSize(horizontal: false, vertical: true)
                if !slide.body.isEmpty {
                    Text(slide.body)
                        .font(Brand.Font.slideBody)
                        .foregroundStyle(Brand.Audience.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Brand.Space.slideMargin * 2)
        }
    }
}

/// Finds and caches slide PNGs by slide id. Files are named `NN-<id>.png`, so the lookup
/// matches on the `-<id>.png` suffix and ignores the number prefix.
enum SlideImageStore {
    nonisolated(unsafe) private static var cache: [String: UIImage?] = [:]
    nonisolated(unsafe) private static let pngURLs: [URL] =
        Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? []

    static func image(for id: String) -> UIImage? {
        if let hit = cache[id] { return hit }
        let suffix = "-\(id).png"
        let url = pngURLs.first { $0.lastPathComponent == "\(id).png" }
            ?? pngURLs.first { $0.lastPathComponent.hasSuffix(suffix) }
        let image = url.flatMap { UIImage(contentsOfFile: $0.path) }
        cache[id] = image
        return image
    }
}

#Preview("PNG") {
    AudienceSlideView(slide: Deck.bundled().slides[0])
        .frame(width: 669, height: 475)
}

#Preview("Fallback") {
    AudienceSlideView(slide: Slide(id: "gen-1", layout: .statement,
                                   title: "A generated slide with no PNG yet.",
                                   body: "Body copy lands here."))
        .frame(width: 669, height: 475)
}
