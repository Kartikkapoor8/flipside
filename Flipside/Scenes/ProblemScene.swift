import SwiftUI

/// Slide 2. Three line-drawn tables, a person each side, a phone turned toward the client; they slide
/// in from the crease one after another. Idle: each phone tilts a little.
struct ProblemScene: View {
    @State private var shown = 0
    private let labels = ["Realtor", "Founder", "Dentist"]

    @Environment(\.sceneLive) private var live

    var body: some View {
        SceneClock { t in
            HStack(spacing: 18) {
                ForEach(0..<3, id: \.self) { i in
                    VStack(spacing: 8) {
                        TableDrawing(tilt: 6 * sin(t * 0.9 + Double(i) * 1.3))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Text(labels[i])
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(10)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))
                    .opacity(shown > i || !live ? 1 : 0)
                    .offset(x: shown > i || !live ? 0 : 60)
                }
            }
        }
        .task {
            guard live else { return }
            for i in 1...3 {
                try? await Task.sleep(for: .milliseconds(i == 1 ? 100 : 260))
                withAnimation(.spring(duration: 0.45, bounce: 0.15)) { shown = i }
            }
        }
    }
}

private struct TableDrawing: View {
    var tilt: Double

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let stroke = Theme.ink.opacity(0.7)
            var table = Path()
            table.addRoundedRect(in: CGRect(x: w * 0.2, y: h * 0.55, width: w * 0.6, height: h * 0.1), cornerSize: CGSize(width: 4, height: 4))
            ctx.stroke(table, with: .color(stroke), lineWidth: 1.5)
            for x in [w * 0.12, w * 0.88] {
                var person = Path()
                person.addEllipse(in: CGRect(x: x - w * 0.06, y: h * 0.3, width: w * 0.12, height: w * 0.12))
                person.move(to: CGPoint(x: x, y: h * 0.3 + w * 0.12))
                person.addLine(to: CGPoint(x: x, y: h * 0.8))
                ctx.stroke(person, with: .color(stroke), lineWidth: 1.5)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Theme.coral.opacity(0.85))
                .frame(width: 14, height: 22)
                .rotationEffect(.degrees(-20 + tilt))
                .offset(x: 10, y: 4)
        }
    }
}
