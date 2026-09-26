import SwiftUI

/// Slide 3. A Duo lying flat folds up to 90, then breathes between 85 and 95. On the audience side a
/// drag folds it anywhere between 0 and 180; release springs it back to 90.
struct FoldScene: View {
    @State private var raised = false
    @State private var drag: Double?
    @State private var startAngle: Double = 90

    var body: some View {
        SceneClock { t in
            let idle = 90 + 5 * sin(t * 1.1)
            DuoView(angle: drag ?? (raised ? idle : 180))
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { v in
                    let next = startAngle - Double(v.translation.width) * 0.6
                    drag = min(max(next, 0), 180)
                }
                .onEnded { _ in
                    withAnimation(.spring(duration: 0.5, bounce: 0.3)) { drag = nil }
                    startAngle = 90
                }
        )
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(duration: 0.55, bounce: 0.15)) { raised = true }
        }
        .animation(.spring(duration: 0.55, bounce: 0.15), value: raised)
        .accessibilityLabel("A folding phone, drag to fold")
    }
}
