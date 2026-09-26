import SwiftUI
import UIKit

#if DEBUG
/// Dev-only. Launch with `-snapshot 2` and the app writes `Documents/snapshot.png` of its key
/// window two seconds later. `-orientation landscape|portrait` asks the scene to rotate first,
/// which is how the landscape (hinge vertical) layout is checked without DeviceHub's rotate button. Used because `simctl io screenshot` returns black for the Duo's
/// inner display in portrait and DeviceHub sits behind other windows on the Mac.
///
///     xcrun simctl launch booted dev.flipside.Flipside -snapshot 2
///     open "$(xcrun simctl get_app_container booted dev.flipside.Flipside data)/Documents/snapshot.png"
enum DebugSnapshot {
    @MainActor
    static func armIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-snapshot") else { return }
        let delay = args.indices.contains(i + 1) ? Double(args[i + 1]) ?? 2 : 2
        Task { @MainActor in
            if let o = args.firstIndex(of: "-orientation"), args.indices.contains(o + 1) {
                try? await Task.sleep(for: .seconds(0.5))
                rotate(to: args[o + 1])
            }
            try? await Task.sleep(for: .seconds(delay))
            capture()
        }
    }

    /// `-fold "90,135,180,0" -foldStep 2.5 -foldDelay 1.5`: walks the fake hinge through the listed
    /// angles, one every `foldStep` seconds, starting after `foldDelay`. Drives the morph for stills
    /// and the recording without DeviceHub. Angle 0 is closed, 180 is flat, the rest partially open.
    @MainActor
    static func runFoldScript(_ appState: AppState, studio: StudioModel) async {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-fold") ?? args.firstIndex(of: "-stage"), args.indices.contains(i + 1) else { return }
        let steps = args[i + 1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        func number(_ flag: String, _ fallback: Double) -> Double {
            guard let j = args.firstIndex(of: flag), args.indices.contains(j + 1) else { return fallback }
            return Double(args[j + 1]) ?? fallback
        }
        try? await Task.sleep(for: .seconds(number("-foldDelay", 1.5)))
        for step in steps {
            if let angle = Double(step) {
                let status: AppState.HingeStatus = angle < 5 ? .closed : (angle >= 178 ? .fullyOpen : .partiallyOpen)
                withAnimation(.easeInOut(duration: 0.55)) { appState.applyHinge(angle: angle, status: status) }
                print("[hinge] script angle=\(Int(angle)) status=\(status.rawValue) mode=\(appState.mode.rawValue)")
            } else {
                // Same actions as the stage strip's buttons.
                switch step {
                case "next": studio.next()
                case "back": studio.back()
                case "cue": NotificationCenter.default.post(name: .flipsideDebugCue, object: nil)
                case "chat": NotificationCenter.default.post(name: .flipsideDebugChat, object: nil)
                case "flip": withAnimation(.easeInOut(duration: 0.4)) { appState.flipAudience() }
                case "client": studio.insertParkingCard()
                case "laser": studio.toggleLaser()
                case "generate": studio.replayGeneration()
                case "end": studio.endMeeting()
                case "home": withAnimation(Theme.land) { appState.isHome.toggle() }
                default: print("[stage] unknown step \(step)")
                }
                print("[stage] \(step)")
            }
            try? await Task.sleep(for: .seconds(number("-foldStep", 2.5)))
        }
    }

    @MainActor
    static func rotate(to name: String) {
        let mask: UIInterfaceOrientationMask = name.hasPrefix("land") ? .landscapeRight : .portrait
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                print("snapshot: rotate \(name) failed: \(error)")
            }
        }
        print("snapshot: requested \(name)")
    }

    @MainActor
    static func capture(name: String = "snapshot") {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first
        else { print("snapshot: no window"); return }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        guard let data = image.pngData(),
              let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        let url = docs.appendingPathComponent("\(name).png")
        try? data.write(to: url)
        print("snapshot: wrote \(url.path) \(window.bounds.size)")
    }
}
#endif
