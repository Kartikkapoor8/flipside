import SwiftUI
import os

/// Listens to the device hinge and pushes angle and status into `AppState`, which runs the mode
/// mapping. `onHingeChange` and `DeviceHingeContext` live in SwiftUICore (iOS 27.1).
/// `DeviceHinge.Status` is a struct with static members, so it is compared with `==`.
struct HingeMonitor: ViewModifier {
    @Environment(AppState.self) private var appState

    private static let logger = Logger(subsystem: "dev.flipside", category: "hinge")

    func body(content: Content) -> some View {
        content
            .onHingeChange { old, new in
                guard let hinge = new.hinge else {
                    Self.logger.info("hinge: context has no hinge (not a folding device or unknown)")
                    print("[hinge] no hinge in context")
                    return
                }
                let status: AppState.HingeStatus
                if hinge.status == .closed {
                    status = .closed
                } else if hinge.status == .partiallyOpen {
                    status = .partiallyOpen
                } else if hinge.status == .fullyOpen {
                    status = .fullyOpen
                } else {
                    status = .partiallyOpen
                }
                let angle = hinge.angle.degrees
                let before = appState.mode
                appState.applyHinge(angle: angle, status: status)
                let line = "angle=\(String(format: "%.1f", angle)) status=\(status.rawValue) mode=\(before.rawValue)->\(appState.mode.rawValue) fold=\(String(format: "%.2f", appState.foldProgress))"
                Self.logger.info("hinge: \(line, privacy: .public)")
                print("[hinge] \(line)")
            }
    }
}

extension View {
    /// Attach once, near the root. Hinge changes flow into the shared `AppState`.
    func monitorsHinge() -> some View {
        modifier(HingeMonitor())
    }
}
