import SwiftUI

/// The card that says the app is listening: a breathing waveform, the word Listening, and the last
/// few words heard drifting through, dimmed. Tap to start or stop the mic.
/// With no mic (the simulator, on stage) it still listens in spirit: the current slide's notes
/// drift through at speaking pace, so the card never reads as dead. Same piece on the home tile.
struct AIBar: View {
    let model: StudioModel
    /// Narrower variant for a half-height slot.
    var compact = false
    /// Tap. Default starts or stops the mic; the desk passes the chat opener instead.
    var onTap: (() -> Void)? = nil

    var body: some View {
        let mic = model.mic
        HStack(spacing: 10) {
            Waveform(level: mic.level, live: mic.isLive)
                .frame(width: compact ? 34 : 44, height: 18)
            Text(statusWord)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(mic.isLive ? Theme.coral : Theme.text)
                .lineLimit(1)
                .fixedSize()
                .contentTransition(.opacity)
            if mic.isLive {
                TranscriptTicker(text: CueMatcher.tail(mic.transcript, count: compact ? 6 : 8), placeholder: "say the cue to advance")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                StageTranscript(source: model.current?.notes ?? "", count: compact ? 6 : 8, placeholder: placeholder)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.leading, 12).padding(.trailing, 14).padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
        .hingeHighlight(Capsule(), angle: model.app.hingeAngle)
        .contentShape(Capsule())
        .deskPress { if let onTap { onTap() } else { mic.toggle() } }
        .animation(Theme.fade, value: mic.isLive)
        .accessibilityLabel(mic.isLive ? "Listening. Tap to stop." : "Tap to listen")
    }

    private var statusWord: String {
        switch model.mic.state {
        case .live: "Listening"
        case .requesting: "Listening…"
        case .denied: "Listening"
        case .idle: "Listening"
        }
    }

    private var placeholder: String {
        switch model.mic.state {
        case .live: "say the cue to advance"
        case .requesting: "asking for the mic"
        case .denied: "mic unavailable, cue from the strip"
        case .idle: "tap to start listening"
        }
    }
}

/// Nine bars. Live: mic level. Idle: a slow breathing wave so the bar never looks dead.
struct Waveform: View {
    var level: () -> Double
    var live: Bool

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let bars = 9
                let gap: CGFloat = 2.5
                let w = (size.width - gap * CGFloat(bars - 1)) / CGFloat(bars)
                let energy = live ? max(level(), 0.08) : 0
                for i in 0..<bars {
                    let fi = Double(i)
                    let centre = 1 - abs(fi - Double(bars - 1) / 2) / (Double(bars - 1) / 2)
                    let idle = 0.18 + 0.14 * (sin(t * 1.6 + fi * 0.8) + 1) / 2 * centre
                    let voice = energy * (0.35 + 0.65 * centre) * (0.7 + 0.3 * sin(t * 9 + fi * 1.3))
                    let h = size.height * min(max(idle + voice, 0.12), 1)
                    let rect = CGRect(x: CGFloat(i) * (w + gap), y: (size.height - h) / 2, width: w, height: h)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: w / 2), with: .color(live ? Theme.coral : Theme.textSecondary))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// The rolling transcript. New words push in from the trailing edge; the whole line stays dimmed.
private struct TranscriptTicker: View {
    let text: String
    let placeholder: String

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(Theme.textSecondary.opacity(0.7))
                    .transition(.opacity)
            } else {
                Text(text)
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.opacity)
            }
        }
        .font(.system(size: 12))
        .lineLimit(1)
        .truncationMode(.head)
        .clipped()
        .animation(.easeOut(duration: 0.25), value: text)
    }
}

/// No mic: walks through the slide's notes at about two words a second, as if it were hearing them.
private struct StageTranscript: View {
    let source: String
    let count: Int
    let placeholder: String

    var body: some View {
        let words = source.split(whereSeparator: \.isWhitespace).map(String.init)
        TimelineView(.periodic(from: .now, by: 0.55)) { context in
            let n = words.isEmpty ? 0 : Int(context.date.timeIntervalSinceReferenceDate / 0.55) % (words.count + 4)
            let shown = Array(words.prefix(n).suffix(count)).joined(separator: " ")
            TranscriptTicker(text: shown, placeholder: placeholder)
        }
    }
}
