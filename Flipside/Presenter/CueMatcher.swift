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

    /// Word index just past the last place `phrase` appears (in order, adjacent) in the transcript.
    static func lastMatchEnd(of phrase: String, in spoken: [String]) -> Int? {
        let target = words(phrase)
        guard !target.isEmpty, spoken.count >= target.count else { return nil }
        for start in stride(from: spoken.count - target.count, through: 0, by: -1) {
            if Array(spoken[start..<(start + target.count)]) == target { return start + target.count }
        }
        return nil
    }

    /// The section whose name was spoken most recently, if it was spoken after word `after`.
    /// Names are matched whole, so "the fold" jumps and "fold" alone inside another name does not.
    static func sectionMatch(in transcript: String, sections: [DeckSection], after: Int) -> (section: DeckSection, end: Int)? {
        let spoken = words(transcript)
        var best: (section: DeckSection, end: Int)?
        for section in sections {
            guard let end = lastMatchEnd(of: section.name, in: spoken), end > after else { continue }
            if best == nil || end > best!.end { best = (section, end) }
        }
        return best
    }

    /// The last `count` words of the transcript, for the ticker in the AI bar.
    static func tail(_ transcript: String, count: Int = 7) -> String {
        transcript
            .split(whereSeparator: \.isWhitespace)
            .suffix(count)
            .joined(separator: " ")
    }
}
