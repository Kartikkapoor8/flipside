import SwiftUI

/// Media in present mode: his Media tab (Editor/PresenterDesk) in one glass card over the notes,
/// opened from the desk bar. Kept in its own file so it merges cleanly.
struct MediaDock: View {
    let model: StudioModel
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MEDIA")
                    .font(.system(size: 10, weight: .bold)).tracking(1.2)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.text)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Close media")
            }
            MediaTab(model: model)
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .hingeHighlight(RoundedRectangle(cornerRadius: 18, style: .continuous), angle: model.app.hingeAngle)
    }
}
