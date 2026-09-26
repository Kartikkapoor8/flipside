import Foundation

/// Matches the slide's cue phrase against the rolling speech transcript.
/// Everything is lowercased and stripped to letters and digits, so "not a button." matches
/// "…this, not a button" however the recogniser punctuates it.
enum CueMatcher {
    static func words(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "'" })
            .map { String($0).replacingOccurrences(of: "'", with: "") }
            .filter { !$0.isEmpty }
    }

    /// True when the cue's words appear in order, adjacent, inside the last `window` words spoken.
    static func matches(cue: String, transcript: String, window: Int = 16) -> Bool {
        let cueWords = words(cue)
        guard !cueWords.isEmpty else { return false }
        let spoken = Array(words(transcript).suffix(window))
        guard spoken.count >= cueWords.count else { return false }
        for start in 0...(spoken.count - cueWords.count) {
            if Array(spoken[start..<(start + cueWords.count)]) == cueWords { return true }
        }
        return false
    }

    /// The last `count` words of the transcript, for the ticker in the AI bar.
    static func tail(_ transcript: String, count: Int = 7) -> String {
        transcript
            .split(whereSeparator: \.isWhitespace)
            .suffix(count)
            .joined(separator: " ")
    }
}
