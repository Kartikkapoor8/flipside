import SwiftUI

/// The fold, as a number. `foldProgress` is 0 at 90 degrees (standing) and 1 at 180 (flat).
/// The desk keeps one structure in every pose; the fold only changes sizes: the queue column
/// widens toward flat and the notes type steps up.
struct DeskMorph: Equatable {
    var progress: Double

    init(foldProgress p: Double) {
        progress = min(max(p, 0), 1)
    }

    static let standing = DeskMorph(foldProgress: 0)
    static let flat = DeskMorph(foldProgress: 1)
}

/// Where each desk piece sits. Top to bottom: AI bar, tab strip, content row (queue column on the
/// left, notes on the right), bottom bar. Plain rects, all full width except the two halves of
/// the content row. Nothing dissolves and nothing overlaps.
struct DeskFrames: Equatable {
    var aiBar: CGRect
    var tabs: CGRect
    var queue: CGRect
    var notes: CGRect
    var bar: CGRect
    /// The pointer trackpad: the whole content row.
    var pointer: CGRect
    /// The live monitor tile, top trailing over the notes.
    var monitor: CGRect

    static let pad: CGFloat = 12
    static let gap: CGFloat = 10
    static let aiBarHeight: CGFloat = 40
    static let tabsHeight: CGFloat = 36
    static let barHeight: CGFloat = 48

    static func compute(size: CGSize, wide: Bool, morph m: DeskMorph) -> DeskFrames {
        let W = size.width, H = size.height
        let inner = CGRect(x: pad, y: pad, width: W - 2 * pad, height: H - 2 * pad)

        let aiBar = CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: aiBarHeight)
        let tabs = CGRect(x: inner.minX, y: aiBar.maxY + 8, width: inner.width, height: tabsHeight)
        let bar = CGRect(x: inner.minX, y: inner.maxY - barHeight, width: inner.width, height: barHeight)
        let contentTop = tabs.maxY + gap
        let contentBottom = bar.minY - gap
        let content = CGRect(x: inner.minX, y: contentTop, width: inner.width, height: contentBottom - contentTop)

        // The queue column: a quarter of the width standing, a third flat, within sane bounds.
        let standingColumn = min(max(inner.width * 0.26, 132), 190)
        let flatColumn = min(max(inner.width * 0.34, 150), 230)
        let column = standingColumn + (flatColumn - standingColumn) * CGFloat(m.progress)
        let queue = CGRect(x: content.minX, y: content.minY, width: column, height: content.height)
        let notes = CGRect(x: queue.maxX + gap, y: content.minY, width: content.width - column - gap, height: content.height)

        let monitorW: CGFloat = min(116, notes.width * 0.4)
        let monitor = CGRect(x: notes.maxX - monitorW - 8, y: notes.minY + 8, width: monitorW, height: monitorW * 1.3)

        return DeskFrames(aiBar: aiBar, tabs: tabs, queue: queue, notes: notes, bar: bar, pointer: content, monitor: monitor)
    }
}

extension View {
    /// Places a view at an absolute rect inside its parent.
    func deskFrame(_ rect: CGRect) -> some View {
        frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}
