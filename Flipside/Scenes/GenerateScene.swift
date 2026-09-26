import SwiftUI

/// Slide 4. An empty glass card with the beam running; a title lands, three lines fade and rise in,
/// a cursor blinks. Loops every 6 s; a tap restarts it.
struct GenerateScene: View {
    @State private var step = 0
    @State private var run = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if step >= 1 {
                Text("Alder Street")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            ForEach(0..<3, id: \.self) { i in
                if step >= 2 + i {
                    Capsule().fill(Theme.ink.opacity(0.18))
                        .frame(width: [180, 140, 110][i], height: 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            SceneClock { t in
                Rectangle().fill(Theme.coral)
                    .frame(width: 2, height: 18)
                    .opacity(Int(t * 2) % 2 == 0 ? 1 : 0.1)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.surface.opacity(0.75), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.ink.opacity(0.1)))
        .borderBeam(.md, colorVariant: .colorful, strength: 0.9, active: true, cornerRadius: 22)
        .contentShape(Rectangle())
        .onTapGesture { run += 1 }
        .task(id: run) {
            while !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.3)) { step = 0 }
                try? await Task.sleep(for: .milliseconds(900))
                for s in 1...4 {
                    withAnimation(.spring(duration: 0.4, bounce: 0.15)) { step = s }
                    try? await Task.sleep(for: .milliseconds(650))
                }
                try? await Task.sleep(for: .milliseconds(2500))
            }
        }
        .accessibilityLabel("A deck writing itself, tap to replay")
    }
}
