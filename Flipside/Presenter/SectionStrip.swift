import SwiftUI

/// Quick jump. Apple Music's segmented capsules on glass, one per section, scrolling sideways:
/// the current section is lit, the rest are quiet. Tap to jump to that section's first slide with
/// the audience crossfade. The AI reads the same strip: a spoken section name jumps too.
struct SectionStrip: View {
    let model: StudioModel

    var body: some View {
        let sections = model.app.deck.sections
        let currentID = model.app.deck.section(containing: model.app.currentIndex)?.id
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(sections) { section in
                            let lit = section.id == currentID
                            Text(section.name)
                                .font(.system(size: 13, weight: lit ? .bold : .semibold))
                                .foregroundStyle(lit ? .white : Theme.text)
                                .lineLimit(1)
                                .padding(.horizontal, 14)
                                .frame(height: 32)
                                .glassEffect(lit ? .regular.tint(Theme.coral).interactive() : .regular.interactive(), in: .capsule)
                                .contentShape(Capsule())
                                .deskPress { model.select(slide: section.firstIndex) }
                                .id(section.id)
                                .accessibilityLabel("Jump to \(section.name)")
                                .accessibilityAddTraits(lit ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .onChange(of: currentID) { _, id in
                guard let id else { return }
                withAnimation(DeskMotion.crossfade) { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .frame(height: 36)
        .animation(DeskMotion.crossfade, value: currentID)
        .animation(DeskMotion.crossfade, value: sections.map(\.id))
        .accessibilityLabel("Sections")
    }
}
