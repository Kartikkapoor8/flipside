import SwiftUI

/// Slide 1. The brand mark, two colour halves, folds open into the small Duo standing at 90; both
/// faces light up, one specular sweep crosses them, then the idle breath.
struct CoverScene: View {
    @State private var opened = false
    @State private var lit = false
    @State private var sweep: Double?

    @Environment(\.sceneLive) private var live

    var body: some View {
        SceneClock { t in
            let idle = 90 + 4 * sin(t * 1.1)
            ZStack {
                if !opened && live {
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.coral)
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.violet)
                    }
                    .frame(width: 84, height: 84)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
                DuoView(angle: opened || !live ? idle : 0, lit: lit || !live ? 1 : 0.25, sweep: sweep)
                    .opacity(opened || !live ? 1 : 0)
            }
        }
        .task {
            guard live else { return }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(duration: 0.55, bounce: 0.15)) { opened = true }
            try? await Task.sleep(for: .milliseconds(560))
            withAnimation(.easeOut(duration: 0.4)) { lit = true }
            try? await Task.sleep(for: .milliseconds(420))
            sweep = 0
            withAnimation(.easeInOut(duration: 0.6)) { sweep = 1 }
            try? await Task.sleep(for: .milliseconds(620))
            sweep = nil
        }
    }
}
