import Foundation

/// Hinge angle to app mode, with hysteresis so a wobbling hand does not flicker between modes.
///
/// - closed status, or under `closedBelow` degrees: `.ended`
/// - `presentRange` (60 up to fold progress 0.72, the phone standing or leaning): `.present`
/// - above `editAbove` (fold progress 0.85, about 166 degrees): `.edit`
/// - anywhere else: keep the previous mode
///
/// `foldProgress` is 0 at 90 degrees (standing) and 1 at 180 (flat), clamped. The desk morphs
/// continuously on it (DeskMorph) and the mode flips at 0.85 with the 0.72 to 0.85 dead band
/// as hysteresis.
struct ModeMapper: Sendable {
    var closedBelow: Double = 20
    var presentRange: ClosedRange<Double> = 60...ModeMapper.angle(forProgress: 0.72)
    var editAbove: Double = ModeMapper.angle(forProgress: 0.85)

    static func angle(forProgress p: Double) -> Double { 90 + 90 * p }

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
        var next = mapper.mode(forAngle: angle, status: status, previous: mode)
        // Closing from Home, or before any deck was opened, is not a meeting ending: nothing shows
        // and reopening lands on Home.
        if next == .ended && isHome { next = .present }
        guard next != mode else { return }
        if mode == .ended && next == .present { reset() }
        if next == .ended { laserPoint = nil }
        mode = next
    }

    var foldProgress: Double { ModeMapper.foldProgress(forAngle: hingeAngle) }
}
