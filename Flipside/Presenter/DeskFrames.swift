import SwiftUI

/// The morph, as numbers. `foldProgress` is 0 at 90 degrees (standing) and 1 at 180 (flat).
/// One thing moves at a time: the queue turns first, then the notes widen, then the bar dissolves.
/// The mode flips to edit at 0.85 (ModeMapper, with hysteresis) and the editor takes over.
struct DeskMorph: Equatable {
    var queueTurn: Double
    var notesWiden: Double
    var barFade: Double

    init(foldProgress p: Double) {
        queueTurn = DeskMorph.band(p, from: 0.05, to: 0.45)
        notesWiden = DeskMorph.band(p, from: 0.45, to: 0.70)
        barFade = DeskMorph.band(p, from: 0.70, to: 0.85)
    }

    static let standing = DeskMorph(foldProgress: 0)
    static let flat = DeskMorph(foldProgress: 1)

    private static func band(_ p: Double, from a: Double, to b: Double) -> Double {
        let x = min(max((p - a) / (b - a), 0), 1)
        // ease in-out so hinge jitter at a band edge does not twitch the layout
        return x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
    }
}

/// Where each desk piece sits for a given half size, shape and morph. Plain rects, so the
/// fold (continuous) and a mode change (discrete, animated) drive the same geometry.
struct DeskFrames: Equatable {
    var aiBar: CGRect
    var notes: CGRect
    var queue: CGRect
    var bar: CGRect
    var barOpacity: Double
    var aiBarOpacity: Double
    /// The live monitor: top of the right column when wide, top-trailing corner over the notes when tall.
    var monitor: CGRect
    var monitorOpacity: Double

    static let pad: CGFloat = 12
    static let gap: CGFloat = 10
    static let aiBarHeight: CGFloat = 40
    static let barHeight: CGFloat = 48
    static let queueRowHeight: CGFloat = 92

    /// - wide: the half is wider than tall (portrait phone, hinge horizontal). Then the queue is a
    ///   column on the right while standing. Tall halves (hinge vertical) put it under the notes.
    static func compute(size: CGSize, wide: Bool, morph m: DeskMorph) -> DeskFrames {
        let W = size.width, H = size.height
        let inner = CGRect(x: pad, y: pad, width: W - 2 * pad, height: H - 2 * pad)

        // Standing layout.
        let aiBar = CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: aiBarHeight)
        let bar = CGRect(x: inner.minX, y: inner.maxY - barHeight, width: inner.width, height: barHeight)
        let contentTop = aiBar.maxY + gap
        let contentBottom = bar.minY - gap

        let standingQueue: CGRect
        let standingNotes: CGRect
        let monitor: CGRect
        if wide {
            let column: CGFloat = max(min(W * 0.26, 190), 150)
            let monitorH: CGFloat = column * 0.78
            monitor = CGRect(x: inner.maxX - column, y: contentTop, width: column, height: monitorH)
            standingQueue = CGRect(x: inner.maxX - column, y: contentTop + monitorH + gap, width: column, height: contentBottom - contentTop - monitorH - gap)
            standingNotes = CGRect(x: inner.minX, y: contentTop, width: inner.width - column - gap, height: contentBottom - contentTop)
        } else {
            let monitorW: CGFloat = 116
            standingQueue = CGRect(x: inner.minX, y: contentBottom - queueRowHeight, width: inner.width, height: queueRowHeight)
            standingNotes = CGRect(x: inner.minX, y: contentTop, width: inner.width, height: standingQueue.minY - gap - contentTop)
            // Bottom corner of the notes card: the serif fills from the top, so this stays clear.
            monitor = CGRect(x: inner.maxX - monitorW - 8, y: standingNotes.maxY - monitorW * 1.3 - 8, width: monitorW, height: monitorW * 1.3)
        }

        // Flat (edit) layout: the queue is a list column on the leading side, the notes take the rest
        // down to the bottom edge; the bar is gone.
        let listColumn: CGFloat = wide ? 200 : 132
        let flatQueue = CGRect(x: inner.minX, y: contentTop, width: listColumn, height: inner.maxY - contentTop)
        let flatNotes = CGRect(x: inner.minX + listColumn + gap, y: contentTop, width: inner.width - listColumn - gap, height: inner.maxY - contentTop)

        // Band 1: the queue turns into the column and the notes make room beside it (same motion).
        let queue = lerp(standingQueue, flatQueue, m.queueTurn)
        let notesAfterTurn = CGRect(
            x: lerp(standingNotes.minX, flatNotes.minX, m.queueTurn),
            y: standingNotes.minY,
            width: lerp(standingNotes.width, flatNotes.width, m.queueTurn),
            height: standingNotes.height
        )
        // Band 2: the notes widen downward into the bar's space.
        let notes = CGRect(
            x: notesAfterTurn.minX,
            y: notesAfterTurn.minY,
            width: notesAfterTurn.width,
            height: lerp(notesAfterTurn.height, flatNotes.maxY - notesAfterTurn.minY, m.notesWiden)
        )
        // Band 3: the bar dissolves, sliding a little toward the edge.
        let barShifted = bar.offsetBy(dx: 0, dy: 16 * m.barFade)

        return DeskFrames(
            aiBar: aiBar,
            notes: notes,
            queue: queue,
            bar: barShifted,
            barOpacity: 1 - m.barFade,
            aiBarOpacity: 1,
            monitor: monitor.offsetBy(dx: 0, dy: -12 * m.queueTurn),
            monitorOpacity: 1 - m.queueTurn
        )
    }

    private static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat { a + (b - a) * CGFloat(t) }
    private static func lerp(_ a: CGRect, _ b: CGRect, _ t: Double) -> CGRect {
        CGRect(x: lerp(a.minX, b.minX, t), y: lerp(a.minY, b.minY, t), width: lerp(a.width, b.width, t), height: lerp(a.height, b.height, t))
    }
}

extension View {
    /// Places a view at an absolute rect inside its parent.
    func deskFrame(_ rect: CGRect) -> some View {
        frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}
