import SwiftUI

/// The strip that says the app is listening: a live waveform, the word Listening, and the last
/// few words of the transcript rolling through, dimmed. Tap to start or stop the mic.
/// Same piece on the home screen's topic tile.
struct AIBar: View {
    let model: StudioModel
    /// Narrower variant for a half-height slot.
    var compact = false

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
            TranscriptTicker(text: CueMatcher.tail(mic.transcript, count: compact ? 6 : 8), placeholder: placeholder)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 12).padding(.trailing, 14).padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
        .contentShape(Capsule())
        .onTapGesture { mic.toggle() }
        .animation(Theme.fade, value: mic.isLive)
        .accessibilityLabel(mic.isLive ? "Listening. Tap to stop." : "Tap to listen")
    }

    private var statusWord: String {
        switch model.mic.state {
        case .live: "Listening"
        case .requesting: "Listening…"
        case .denied: "Mic off"
        case .idle: "Listen"
        }
    }

    private var placeholder: String {
        switch model.mic.state {
        case .live: "say the cue to advance"
        case .requesting: "asking for the mic"
        case .denied(let why): why
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
                    .id(text)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .font(.system(size: 12))
        .lineLimit(1)
        .truncationMode(.head)
        .clipped()
        .animation(.easeOut(duration: 0.25), value: text)
    }
}
