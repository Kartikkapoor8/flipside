import Foundation
import SwiftUI

/// The pitch deck, "generated". Anything typed or said that mentions Flipside streams the bundled
/// deck card by card through the same glow as a model run, with no network call.
enum PresetPitch {
    static func matches(_ request: String) -> Bool {
        request.lowercased().contains("flipside")
    }

    /// The bundled pitch as the model's JSON Lines, streamed a few characters at a time.
    static func stream(deck: Deck) -> AsyncThrowingStream<String, Error> {
        let text = script(for: deck)
        return AsyncThrowingStream { continuation in
            let task = Task {
                try? await Task.sleep(for: .milliseconds(600))
                var index = text.startIndex
                while index < text.endIndex, !Task.isCancelled {
                    let next = text.index(index, offsetBy: 5, limitedBy: text.endIndex) ?? text.endIndex
                    let chunk = String(text[index..<next])
                    continuation.yield(chunk)
                    index = next
                    try? await Task.sleep(for: .milliseconds(chunk.contains("\n") ? 380 : 22))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func script(for deck: Deck) -> String {
        var lines: [String] = [
            line(["op": "say", "text": "Building your deck"]),
            line(["op": "deck", "title": deck.title]),
        ]
        for slide in deck.slides {
            var object: [String: Any] = [
                "op": "add", "id": slide.id, "layout": slide.layout.rawValue, "title": slide.title,
                "body": slide.body.split(separator: "\n").map(String.init),
                "notes": slide.notes, "cue": slide.cue,
            ]
            if let prompt = slide.imagePrompt { object["imagePrompt"] = prompt }
            lines.append(line(object))
        }
        return lines.joined()
    }

    private static func line(_ object: [String: Any]) -> String {
        let order = ["op", "text", "id", "layout", "title", "body", "notes", "cue", "imagePrompt"]
        let fields = order.compactMap { key -> String? in
            guard let value = object[key],
                  let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
                  let json = String(data: data, encoding: .utf8) else { return nil }
            return "\"\(key)\":\(json)"
        }
        return "{" + fields.joined(separator: ",") + "}\n"
    }
}

extension StudioModel {
    /// Chat entry point for the desk and home: the pitch when Flipside is named, otherwise the generator.
    func submit(_ text: String) {
        send(text)
    }

    /// Streams the bundled pitch through the build animation. Called by `send` when Flipside is named.
    func runPitch(_ request: String) {
        let pitch = Deck.bundled()
        runLocal(request: request, stream: PresetPitch.stream(deck: pitch)) { [weak self] in
            // Sections and timings come from the file; the stream only carries what the parser reads.
            guard let self else { return }
            for (i, slide) in app.deck.slides.enumerated() {
                guard let source = pitch.slides.first(where: { $0.id == slide.id }) else { continue }
                app.deck.slides[i].section = source.section
                app.deck.slides[i].durationHint = source.durationHint
            }
        }
    }

    /// `startProject` for the home composer: a fresh project, the pitch or the generator.
    func submitProject(_ text: String) {
        let request = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty else { return }
        if PresetPitch.matches(request) {
            ProjectStore.save(app.deck, id: projectID)
            selection = nil
            editing = nil
            projectID = ProjectStore.pitchID
            messages.removeAll()
            app.open(Deck(title: "Flipside", slides: []))
            buildingFromHome = true
            homeNotice = Self.openYourDuo
            askBuilds = true
            runPitch(request)
        } else {
            startProject(request)
        }
    }
}
