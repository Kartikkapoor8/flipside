import SwiftUI

/// A small tile of what the audience sees, rendered by the audience renderer at reduced scale.
/// Shown only while the hinge is partially open (standing): flat, they can see the other half.
struct LiveMonitor: View {
    let model: StudioModel
    var namespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("THEY SEE")
                .font(.system(size: 9, weight: .bold)).tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
            ZStack {
                if let slide = model.current {
                    SlideView(slide: slide, animated: false, aspect: max(model.artifactAspect, 0.5), cornerRadius: 8)
                        .id(slide.id)
                        .transition(.opacity)
                    if let laser = model.app.laserPoint {
                        GeometryReader { proxy in
                            Circle().fill(Color.red)
                                .frame(width: 6, height: 6)
                                .shadow(color: .red.opacity(0.6), radius: 3)
                                .position(x: laser.x * proxy.size.width, y: laser.y * proxy.size.height)
                        }
                        .allowsHitTesting(false)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(Theme.sunken)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.line))
            .matchedGeometryEffect(id: "deck.cover", in: namespace)
        }
        .padding(6)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .animation(Theme.fade, value: model.current?.id)
        .accessibilityLabel("Live monitor")
    }
}
