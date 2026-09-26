import Foundation

/// A tab on the desk: a run of slides that belong together. Tapping it jumps to `firstIndex`.
struct DeckSection: Identifiable, Equatable {
    let id: String
    let name: String
    let firstIndex: Int
    let lastIndex: Int

    func contains(_ index: Int) -> Bool { index >= firstIndex && index <= lastIndex }
}

extension Deck {
    /// Consecutive slides sharing a `section` name form one tab. A slide without a section stands
    /// alone under its own title, so a deck the model wrote without sections still gets a strip.
    var sections: [DeckSection] {
        var result: [DeckSection] = []
        for (index, slide) in slides.enumerated() {
            let named = slide.section?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let name = named.isEmpty ? (slide.title.isEmpty ? "Slide \(index + 1)" : slide.title) : named
            if !named.isEmpty, let last = result.last, last.name == name, last.lastIndex == index - 1 {
                result[result.count - 1] = DeckSection(id: last.id, name: name, firstIndex: last.firstIndex, lastIndex: index)
            } else {
                result.append(DeckSection(id: "\(index)-\(name)", name: name, firstIndex: index, lastIndex: index))
            }
        }
        return result
    }

    func section(containing index: Int) -> DeckSection? {
        sections.first { $0.contains(index) }
    }
}
