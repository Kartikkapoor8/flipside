import Foundation
import SwiftUI

/// Runs a deck build from a local JSON Lines stream through the same chat, orb and card-by-card
/// motion as a model call. Used by the stage replay and the preset Flipside pitch, so neither needs
/// a network call or a key.
extension StudioModel {
    private struct LocalRun {
        var startedDeck = false
        var addIndex: Int?
        var built = 0
        var changed = 0
    }

    /// Posts `request` to the chat, then streams `stream` as if the model had written it.
    func runLocal(request: String, stream: AsyncThrowingStream<String, Error>) {
        guard !app.isGenerating else { return }
        if mic.isLive { mic.stop() }
        prompt = ""
        logText(request)
        tab = .ask
        messages.append(ChatMessage(role: .user, text: request))
        messages.append(ChatMessage(role: .assistant, text: buildingFromHome ? Self.openYourDuo : "", isWorking: true))
        Task { @MainActor in
            await consume(stream)
        }
    }

    @MainActor
    private func consume(_ stream: AsyncThrowingStream<String, Error>) async {
        checkpoint()
        selection = nil
        editing = nil
        app.isGenerating = true
        slidesBuilt = 0
        slideInProgress = false
        buildFinishedAt = nil
        orbState = .searching
        status = "Reading your request"
        var parser = DeckStreamParser()
        var run = LocalRun()
        do {
            for try await chunk in stream {
                try Task.checkCancellation()
                let (completed, partial) = parser.feed(chunk)
                for op in completed { applyLocal(op, &run) }
                if let partial { applyLocal(partial, &run) }
            }
            if let last = parser.finish() { applyLocal(last, &run) }
            let note: String? = run.built > 0 ? (run.built == 1 ? "Added 1 slide." : "Built \(run.built) slides.") : nil
            finishLocal(note)
        } catch {
            finishLocal("Stopped.")
        }
        app.isGenerating = false
        slideInProgress = false
        buildFinishedAt = .now
        orbState = nil
        status = ""
        if buildingFromHome { homeNotice = "Your deck is ready. Open your Duo." }
        buildingFromHome = false
        ProjectStore.save(app.deck, id: projectID)
    }

    private func finishLocal(_ note: String?) {
        guard let i = messages.lastIndex(where: { $0.role == .assistant }) else { return }
        messages[i].isWorking = false
        if let note {
            messages[i].text = messages[i].text.isEmpty ? note : messages[i].text + "\n" + note
        }
    }

    private func applyLocal(_ op: DeckOp, _ run: inout LocalRun) {
        switch op.kind {
        case .say:
            guard let i = messages.lastIndex(where: { $0.role == .assistant }) else { return }
            messages[i].text = buildingFromHome ? Self.openYourDuo : (op.text ?? messages[i].text)
        case .deck:
            if !run.startedDeck {
                run.startedDeck = true
                app.deck = Deck(title: op.title ?? "Untitled", slides: [])
                app.currentIndex = 0
            }
            if let title = op.title { app.deck.title = title }
        case .add:
            if run.addIndex == nil {
                guard op.layout != nil || op.title != nil else { return }
                let slide = Slide(id: op.id ?? UUID().uuidString, layout: op.layout ?? .statement, title: "")
                app.deck.slides.append(slide)
                run.addIndex = app.deck.slides.count - 1
                app.currentIndex = app.deck.slides.count - 1
                slideInProgress = true
            }
            guard let index = run.addIndex, app.deck.slides.indices.contains(index) else { return }
            fillLocal(&app.deck.slides[index], from: op)
            orbState = .composing
            status = "Writing slide \(index + 1)" + (op.title.map { " · \($0)" } ?? "")
            if op.complete {
                run.addIndex = nil
                run.built += 1
                slidesBuilt = run.built
                slideInProgress = false
            }
        case .replace, .delete, .remember:
            break
        }
    }

    private func fillLocal(_ slide: inout Slide, from op: DeckOp) {
        if let layout = op.layout, layout != slide.layout {
            slide.layout = layout
            slide.positions = nil
        }
        if let title = op.title, title != slide.title { slide.title = title }
        if op.body.count > slide.bodyLines.count || (op.complete && op.body != slide.bodyLines) {
            slide.bodyLines = op.body
        } else {
            for i in op.body.indices where slide.bodyLines[i] != op.body[i] { slide.bodyLines[i] = op.body[i] }
        }
        if let notes = op.notes { slide.notes = notes }
        if let cue = op.cue { slide.cue = cue }
        if op.complete || op.imagePrompt != nil {
            if slide.imagePrompt != op.imagePrompt, op.imagePrompt != nil || op.complete {
                slide.imagePrompt = op.imagePrompt
                slide.imageURL = nil
            }
        }
    }

    /// Replays a deck build through the streaming path with the offline writer, key or no key,
    /// so the stage is deterministic.
    func replayGeneration(topic: String = "A two-bedroom on Alder Street") {
        withAnimation(Theme.land) {
            app.open(Deck(title: topic, slides: []))
        }
        runLocal(request: topic, stream: DemoWriter.stream(prompt: topic, deck: app.deck))
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            while app.isGenerating { try? await Task.sleep(for: .milliseconds(200)) }
            select(slide: 0)
        }
    }
}
