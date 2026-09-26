import SwiftUI

/// The largest thing on the desk: the current slide's notes in the brand serif, sized to fit
/// (never truncated), with the cue phrase set inside the text as a tinted glass pill.
/// When the transcript matches the cue, the pill fills and the deck advances.
/// Flat (`editing`), the same block becomes a text editor.
struct NotesCard: View {
    let model: StudioModel
    let editing: Bool
    /// True once the cue was heard for this slide: the pill fills.
    let cueMatched: Bool
    @Environment(\.isWideFace) private var isWide

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("NOTES")
                    .font(.system(size: 10, weight: .bold)).tracking(1.2)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if let slide = model.current {
                    Text("\(model.app.currentIndex + 1) / \(model.app.deck.slides.count) · \(slide.durationHint)s")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                        .contentTransition(.numericText())
                }
            }
            if editing {
                editor
            } else {
                reader
            }
            if !editing, model.app.pendingSuggestion != nil {
                // Clear of the live monitor, which sits in this corner on a tall half.
                SuggestionPill(model: model)
                    .padding(.trailing, !isWide && model.app.hingeStatus == .partiallyOpen ? 124 : 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .hingeHighlight(RoundedRectangle(cornerRadius: 18, style: .continuous), angle: model.app.hingeAngle)
    }

    // MARK: Reading

    @ViewBuilder
    private var reader: some View {
        let notes = model.current?.notes ?? ""
        let cue = model.current?.cue ?? ""
        if notes.isEmpty {
            Text("No notes for this slide.")
                .font(Brand.Font.display(24))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            // ViewThatFits is the minimumScaleFactor here: the first size whose flow fits wins.
            GeometryReader { proxy in
                let cap = Int(proxy.size.width / 8.5)
                ViewThatFits(in: .vertical) {
                    ForEach([38, 34, 30, 27, 24, 21, 18].filter { $0 <= max(cap, 18) }, id: \.self) { size in
                        NotesFlow(notes: notes, cue: cue, size: CGFloat(size), matched: cueMatched)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .id(model.current?.id)
            // The old notes leave at once; the new ones fade in. Two flows never overlap.
            .transition(.asymmetric(insertion: .opacity, removal: .identity))
        }
    }

    // MARK: Editing

    private var editor: some View {
        TextEditor(text: Binding(
            get: { model.current?.notes ?? "" },
            set: { v in model.updateCurrent { $0.notes = v } }
        ))
        .font(Brand.Font.display(24))
        .foregroundStyle(Theme.text)
        .scrollContentBackground(.hidden)
        .overlay(alignment: .topLeading) {
            if (model.current?.notes ?? "").isEmpty {
                Text("What you'll say on this slide")
                    .font(Brand.Font.display(24))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 8).padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .disabled(model.current == nil)
    }
}

/// Notes as wrapped word tokens, with the cue's words grouped into one pill token.
private struct NotesFlow: View {
    let notes: String
    let cue: String
    let size: CGFloat
    let matched: Bool

    var body: some View {
        FlowLayout(spacing: size * 0.28, lineSpacing: size * 0.34) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                switch token {
                case .word(let w):
                    Text(w)
                        .font(Brand.Font.display(size))
                        .foregroundStyle(Theme.text)
                case .cue(let c):
                    CuePill(text: c, size: size, matched: matched)
                }
            }
        }
    }

    private enum Token { case word(String), cue(String) }

    /// Splits the notes on the first occurrence of the cue (case-insensitive). If the cue isn't
    /// in the notes, it's appended as its own pill so the presenter still sees what to say.
    private var tokens: [Token] {
        var result: [Token] = []
        let trimmedCue = cue.trimmingCharacters(in: .whitespaces)
        if !trimmedCue.isEmpty, let range = notes.range(of: trimmedCue, options: [.caseInsensitive, .diacriticInsensitive]) {
            result += notes[..<range.lowerBound].split(whereSeparator: \.isWhitespace).map { .word(String($0)) }
            result.append(.cue(String(notes[range])))
            result += notes[range.upperBound...].split(whereSeparator: \.isWhitespace).map { .word(String($0)) }
        } else {
            result += notes.split(whereSeparator: \.isWhitespace).map { .word(String($0)) }
            if !trimmedCue.isEmpty { result.append(.cue("\u{201C}\(trimmedCue)\u{201D}")) }
        }
        return result
    }
}

/// The cue phrase as a tinted glass pill. `matched` fills it coral with white text.
private struct CuePill: View {
    let text: String
    let size: CGFloat
    let matched: Bool

    var body: some View {
        Text(text)
            .font(Brand.Font.display(size))
            .foregroundStyle(matched ? .white : Theme.coral)
            .padding(.horizontal, size * 0.32)
            .padding(.vertical, size * 0.06)
            .glassEffect(
                .regular.tint(matched ? Theme.coral : Theme.coral.opacity(0.16)),
                in: .capsule
            )
            .scaleEffect(matched ? 1.04 : 1)
            .animation(Theme.land, value: matched)
    }
}

/// Left-to-right, wrapping layout; each line's items are centred on its tallest item.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 10_000
        return arrange(width: width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(width: bounds.width, subviews: subviews)
        for (index, frame) in arrangement.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        var lineStart = 0
        for i in frames.indices {
            let isLast = i == frames.count - 1
            let nextStartsLine = !isLast && frames[i + 1].minY != frames[i].minY
            if nextStartsLine || isLast {
                let tallest = frames[lineStart...i].map(\.height).max() ?? 0
                for j in lineStart...i {
                    frames[j].origin.y += (tallest - frames[j].height) / 2
                }
                lineStart = i + 1
            }
        }
        return (CGSize(width: maxX, height: y + lineHeight), frames)
    }
}
