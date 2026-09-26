import Foundation

/// Hinge angle to app mode, with hysteresis so a wobbling hand does not flicker between modes.
///
/// - closed status, or under `closedBelow` degrees: `.ended`
/// - `presentRange` (about 60 to 130, the phone standing on the table): `.present`
/// - above `editAbove` (about 150, lying nearly flat): `.edit`
/// - anywhere else: keep the previous mode
///
/// `foldProgress` is 0 at 90 degrees (standing) and 1 at 180 (flat), clamped, for the
/// present-to-edit transition animation.
struct ModeMapper: Sendable {
    var closedBelow: Double = 20
    var presentRange: ClosedRange<Double> = 60...130
    var editAbove: Double = 150

    static let `default` = ModeMapper()

    func mode(forAngle angle: Double, status: AppState.HingeStatus, previous: AppState.Mode) -> AppState.Mode {
        if status == .closed || angle < closedBelow { return .ended }
        if presentRange.contains(angle) { return .present }
        if angle > editAbove { return .edit }
        // Dead bands (closedBelow..<60, 130..<150): hysteresis. A session that ended stays ended
        // until the phone is clearly standing or flat again.
        return previous
    }

    /// 0 at 90 degrees, 1 at 180, clamped.
    static func foldProgress(forAngle angle: Double) -> Double {
        min(max((angle - 90) / 90, 0), 1)
    }
}

extension AppState {
    /// Single entry point for hinge input, real or faked. Writes the angle and status, then
    /// runs the mapper. Leaving `.ended` for `.present` resets the session (timer, slide, laser).
    func applyHinge(angle: Double, status: HingeStatus, mapper: ModeMapper = .default) {
        hingeAngle = angle
        hingeStatus = status
        let next = mapper.mode(forAngle: angle, status: status, previous: mode)
        guard next != mode else { return }
        if mode == .ended && next == .present { reset() }
        if next == .ended { laserPoint = nil }
        mode = next
    }

    var foldProgress: Double { ModeMapper.foldProgress(forAngle: hingeAngle) }
}
