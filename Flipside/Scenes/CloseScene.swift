import SwiftUI

/// Slide 6. The Duo folds shut over 500 ms, an envelope slides across to a second phone which bumps
/// once, then the scene fades to Paper. Plays on enter, tap replays.
struct CloseScene: View {
    @State private var shut = false
    @State private var sent = false
    @State private var bump = false
    @State private var faded = false
    @State private var run = 0

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack {
                HStack(spacing: w * 0.12) {
                    DuoView(angle: shut ? 2 : 90).frame(width: w * 0.42)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.paper)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.ink.opacity(0.12)))
                        .frame(width: w * 0.16, height: w * 0.32)
                        .scaleEffect(bump ? 1.08 : 1)
                        .offset(y: bump ? -6 : 0)
                }
                Image(systemName: "envelope.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.coral)
                    .offset(x: sent ? w * 0.31 : -w * 0.1, y: -w * 0.02)
                    .opacity(shut && !bump ? 1 : 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .opacity(faded ? 0 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { run += 1 }
        .task(id: run) {
            shut = false; sent = false; bump = false; faded = false
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeInOut(duration: 0.5)) { shut = true }
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeInOut(duration: 0.55)) { sent = true }
            try? await Task.sleep(for: .milliseconds(560))
            withAnimation(.spring(duration: 0.3, bounce: 0.5)) { bump = true }
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.spring(duration: 0.3, bounce: 0.2)) { bump = false }
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeInOut(duration: 0.6)) { faded = true }
        }
        .accessibilityLabel("Meeting over, recap sent. Tap to replay")
    }
}
