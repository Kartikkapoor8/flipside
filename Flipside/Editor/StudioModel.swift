import Foundation
import Observation
import SwiftUI

struct ChatMessage: Identifiable, Equatable {
  enum Role { case user, assistant }
  let id = UUID()
  var role: Role
  var text: String
  var isWorking = false
}

/// The desk's right-hand tab strip.
enum DeskTab: String, CaseIterable, Identifiable {
  case text = "Text"
  case media = "Media"
  case ask = "Ask"
  var id: String { rawValue }
}

/// Motion from the insert-animation spec. Each desk action wraps its AppState change in one of these,
/// so the presenter-side change and the audience-side effect are a single animation.
enum DeskMotion {
  /// Media in or out: text slides and narrows, card grows from the crease.
  static let media = Animation.easeOut(duration: 0.5)
  /// A new text line fades and rises into place.
  static let line = Animation.easeOut(duration: 0.3)
  /// Jumping or reordering: crossfade, never a slide sideways.
  static let crossfade = Animation.easeInOut(duration: 0.25)
}

/// How the two halves sit. `auto` follows the fold: a fold running top to bottom puts them side by side,
/// a fold running across puts the artifact above the prompt. The other two pin a choice.
enum StudioLayout: String, CaseIterable, Identifiable {
  case auto
  case horizontal
  case vertical
  var id: String { rawValue }

  var label: String {
    switch self {
    case .auto: "Follow the fold"
    case .horizontal: "Side by side"
    case .vertical: "Stacked"
    }
  }

  var icon: String {
    switch self {
    case .auto: "rectangle.portrait.split.2x1"
    case .horizontal: "rectangle.split.2x1"
    case .vertical: "rectangle.split.1x2"
    }
  }
}

/// A snapping guide drawn while dragging, in normalized slide coordinates.
struct SnapGuide: Hashable {
  enum Axis { case vertical, horizontal }
  var axis: Axis
  var value: Double
}

/// Editor state for the flat-phone studio: prompt and chat on one half, the editable deck on the other.
@Observable
@MainActor
final class StudioModel {
  let app: AppState
  let mic = Microphone()

  var tab: DeskTab = .text
  /// Ask tab: `true` sends the prompt to build or change the deck; `false` asks a private question.
  var askBuilds = false
  var askAnswer = ""
  var isAsking = false
  /// The body line the Text tab is typing into.
  var typingLine: Int?
  var prompt = ""
  var messages: [ChatMessage] = []
  var selection: String?
  var editing: String?
  var guides: [SnapGuide] = []
  /// Non-nil while the model is working; drives the orb.
  var orbState: OrbState?
  var status = ""
  var showSettings = false
  var layout: StudioLayout = StudioLayout(rawValue: UserDefaults.standard.string(forKey: "studioLayout") ?? "") ?? .auto {
    didSet { UserDefaults.standard.set(layout.rawValue, forKey: "studioLayout") }
  }
  /// Shape of the artifact pane, so thumbnails match what's on screen.
  var artifactAspect: CGFloat = 0.72

  private var undoStack: [Deck] = []
  private var redoStack: [Deck] = []
  @ObservationIgnored private var generation: Task<Void, Never>?

  /// Which saved project the working deck belongs to (see `ProjectStore`).
  var projectID: String
  /// Building a new deck that was started from the home screen.
  var buildingFromHome = false
  /// One line the home screen shows after an action ("Open your Duo…"). Nil shows the choices only.
  var homeNotice: String?
  /// Files attached to the next prompt (Ask, Build or a new deck). Cleared once sent.
  var attachments: [Attachment] = []
  /// What Flipside remembers about the presenter across decks.
  var memories: [MemoryItem] = MemoryStore.load()
  var showMemory = false
  /// Memory on or off (off: nothing is read or saved).
  var memoryEnabled: Bool = MemoryStore.isEnabled {
    didSet { MemoryStore.isEnabled = memoryEnabled }
  }
  /// Slides fully written in the current build, for the home screen's loading bar.
  var slidesBuilt = 0
  /// A slide is streaming in right now (started but not finished).
  var slideInProgress = false
  /// When the last build finished, so the loading bar can show a full bar briefly and fade.
  var buildFinishedAt: Date?

  init(app: AppState, projectID: String = ProjectStore.pitchID) {
    self.app = app
    self.projectID = projectID
  }

  // MARK: Home

  static let openYourDuo = "Open your Duo. Your deck is building on the inside screen."

  /// Opens a past project from the home screen.
  func openProject(_ project: Project) {
    ProjectStore.save(app.deck, id: projectID)
    cancelGeneration()
    undoStack.removeAll()
    redoStack.removeAll()
    selection = nil
    editing = nil
    projectID = project.id
    messages.removeAll()
    app.open(project.deck)
    homeNotice = "Please open your screen to view your deck."
  }

  /// Opens a deck from an imported file as a new project.
  func importDeck(_ deck: Deck) {
    ProjectStore.save(app.deck, id: projectID)
    cancelGeneration()
    undoStack.removeAll()
    redoStack.removeAll()
    projectID = UUID().uuidString
    messages.removeAll()
    app.open(deck)
    ProjectStore.save(deck, id: projectID)
    homeNotice = "Please open your screen to view your deck."
  }

  /// Starts a new project from the home screen's prompt.
  func startProject(_ request: String) {
    let request = request.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !request.isEmpty, generation == nil else { return }
    ProjectStore.save(app.deck, id: projectID)
    undoStack.removeAll()
    redoStack.removeAll()
    selection = nil
    editing = nil
    projectID = UUID().uuidString
    messages.removeAll()
    app.open(Deck(title: "New deck", slides: []))
    buildingFromHome = true
    homeNotice = Self.openYourDuo
    askBuilds = true
    send(request)
  }

  var canUndo: Bool { !undoStack.isEmpty }
  var canRedo: Bool { !redoStack.isEmpty }

  // MARK: History

  /// Call once before a user change (at drag start, not on every drag frame).
  func checkpoint() {
    undoStack.append(app.deck)
    if undoStack.count > 80 { undoStack.removeFirst() }
    redoStack.removeAll()
  }

  func undo() {
    guard let previous = undoStack.popLast() else { return }
    redoStack.append(app.deck)
    app.deck = previous
    app.go(to: app.currentIndex)
    selection = nil
  }

  func redo() {
    guard let next = redoStack.popLast() else { return }
    undoStack.append(app.deck)
    app.deck = next
    app.go(to: app.currentIndex)
    selection = nil
  }

  // MARK: Slides

  var current: Slide? {
    app.deck.slides.indices.contains(app.currentIndex) ? app.deck.slides[app.currentIndex] : nil
  }

  func updateCurrent(_ change: (inout Slide) -> Void) {
    guard app.deck.slides.indices.contains(app.currentIndex) else { return }
    change(&app.deck.slides[app.currentIndex])
  }

  func select(slide index: Int) {
    guard app.deck.slides.indices.contains(index), index != app.currentIndex else { return }
    withAnimation(DeskMotion.crossfade) {
      selection = nil
      editing = nil
      typingLine = nil
      app.currentIndex = index
    }
  }

  func next() { select(slide: app.currentIndex + 1) }
  func back() { select(slide: app.currentIndex - 1) }

  func moveSlides(from source: IndexSet, to destination: Int) {
    checkpoint()
    withAnimation(DeskMotion.crossfade) {
      let currentID = current?.id
      app.deck.slides.move(fromOffsets: source, toOffset: destination)
      if let currentID, let i = app.deck.slides.firstIndex(where: { $0.id == currentID }) {
        app.currentIndex = i
      }
    }
  }

  // MARK: Desk actions

  /// Adds an empty line to the current slide and returns its index; the Text tab types into it live.
  @discardableResult
  func addLine() -> Int? {
    guard current != nil else { return nil }
    checkpoint()
    var index: Int?
    withAnimation(DeskMotion.line) {
      updateCurrent { slide in
        slide.bodyLines.append("")
        index = slide.bodyLines.count - 1
      }
    }
    typingLine = index
    return index
  }

  /// Ends typing; an empty line is removed again.
  func finishLine() {
    guard let i = typingLine else { return }
    typingLine = nil
    if let slide = current, slide.bodyLines.indices.contains(i),
       slide.bodyLines[i].isBlankLine {
      withAnimation(DeskMotion.line) { updateCurrent { $0.bodyLines.remove(at: i) } }
    }
  }

  func insertMedia(_ media: SlideMedia) {
    guard current != nil else { return }
    checkpoint()
    withAnimation(DeskMotion.media) {
      updateCurrent { slide in
        slide.media = media
        slide.hidden?.removeAll { $0 == "image" }
      }
    }
  }

  func removeMedia() {
    guard current?.media != nil || current?.imagePrompt != nil else { return }
    checkpoint()
    withAnimation(DeskMotion.media) {
      updateCurrent { slide in
        if slide.media != nil {
          slide.media = nil
        } else {
          slide.imagePrompt = nil
          slide.imageURL = nil
        }
        slide.positions?["image"] = nil
      }
    }
    if selection == "image" { selection = nil }
  }

  func swapSides() {
    withAnimation(.snappy(duration: 0.4)) { app.swapSides() }
  }

  // MARK: Memory and attachments

  func remember(_ text: String) {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard memoryEnabled, !text.isEmpty,
          !memories.contains(where: { $0.text.caseInsensitiveCompare(text) == .orderedSame }) else { return }
    memories.append(MemoryItem(text: text))
    MemoryStore.save(memories)
  }

  func forget(_ item: MemoryItem) {
    memories.removeAll { $0.id == item.id }
    MemoryStore.save(memories)
  }

  func forgetAll() {
    memories.removeAll()
    MemoryStore.save(memories)
  }

  func attach(_ urls: [URL]) {
    for url in urls {
      if let file = Attachment.load(from: url) { attachments.append(file) }
    }
  }

  func detach(_ file: Attachment) {
    attachments.removeAll { $0.id == file.id }
  }

  /// Memory plus attached files for the next request; the attachments are used up.
  private func takeContext() -> DeckGenerator.Context {
    let files = attachments
    attachments = []
    return DeckGenerator.Context(memory: memoryEnabled ? MemoryStore.promptBlock(memories) : nil, attachments: files)
  }

  /// A private question about the deck, answered on the presenter's side only.
  /// "Remember …" saves a memory instead of asking.
  func ask(_ question: String) {
    let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !question.isEmpty, !isAsking else { return }
    prompt = ""
    let lower = question.lowercased()
    for prefix in ["remember that ", "remember "] where lower.hasPrefix(prefix) {
      remember(String(question.dropFirst(prefix.count)))
      askAnswer = memoryEnabled ? "Got it, I'll remember that." : "Memory is off. Turn it on in Memory to save this."
      return
    }
    askAnswer = ""
    isAsking = true
    let context = takeContext()
    Task { @MainActor in
      do {
        for try await chunk in DeckGenerator.ask(question, deck: app.deck, currentIndex: app.currentIndex, context: context) {
          askAnswer += chunk
        }
      } catch {
        askAnswer = error.localizedDescription
      }
      isAsking = false
    }
  }

  func moveSlide(id: String, before targetID: String) {
    guard let from = app.deck.slides.firstIndex(where: { $0.id == id }),
          let to = app.deck.slides.firstIndex(where: { $0.id == targetID }), from != to else { return }
    moveSlides(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
  }

  func deleteSlides(at offsets: IndexSet) {
    checkpoint()
    app.deck.slides.remove(atOffsets: offsets)
    app.go(to: app.currentIndex)
    selection = nil
  }

  func duplicateCurrent() {
    guard var copy = current else { return }
    checkpoint()
    copy.id = UUID().uuidString
    app.deck.slides.insert(copy, at: app.currentIndex + 1)
    app.currentIndex += 1
  }

  func addSlide(_ layout: SlideLayout) {
    checkpoint()
    let slide = Slide(layout: layout, title: "New \(layout.label.lowercased()) slide", body: layout == .twoColumn ? "First point\nSecond point" : "")
    let index = app.deck.slides.isEmpty ? 0 : app.currentIndex + 1
    app.deck.slides.insert(slide, at: index)
    app.currentIndex = index
    selection = "title"
  }

  func setLayout(_ layout: SlideLayout) {
    checkpoint()
    updateCurrent {
      $0.layout = layout
      $0.positions = nil
    }
  }

  // MARK: Elements

  var canvasSize: CGSize { SlideCanvas.size(forAspect: artifactAspect) }

  func frame(of elementID: String) -> ElementFrame? {
    guard let slide = current,
          let element = SlideLayoutEngine.elements(for: slide).first(where: { $0.id == elementID }) else { return nil }
    return SlideLayoutEngine.frame(for: element, in: slide, canvas: canvasSize)
  }

  /// Tap behaviour: the first tap selects, a second tap on selected text starts editing it.
  func tap(_ elementID: String) {
    if selection == elementID, elementID != "image" {
      beginEditing(elementID)
    } else {
      if editing != nil, editing != elementID { editing = nil }
      selection = elementID
    }
  }

  func setFrame(_ frame: ElementFrame, for elementID: String) {
    updateCurrent { slide in
      var positions = slide.positions ?? [:]
      positions[elementID] = frame
      slide.positions = positions
    }
  }

  func resetElement(_ elementID: String) {
    checkpoint()
    updateCurrent { $0.positions?[elementID] = nil }
  }

  func nudgeScale(_ elementID: String, by factor: Double) {
    guard var frame = frame(of: elementID) else { return }
    checkpoint()
    frame.scale = min(max(frame.scale * factor, 0.3), 3)
    setFrame(frame, for: elementID)
  }

  func removeElement(_ elementID: String) {
    if elementID == "image" {
      removeMedia()
      return
    }
    checkpoint()
    updateCurrent { slide in
      if elementID.hasPrefix("body."), let i = Int(elementID.dropFirst(5)), slide.bodyLines.indices.contains(i) {
        slide.bodyLines.remove(at: i)
        // Body ids shift down; carry moved positions with their lines.
        var moved: [String: ElementFrame] = [:]
        for (key, value) in slide.positions ?? [:] {
          if key.hasPrefix("body."), let j = Int(key.dropFirst(5)) {
            if j < i { moved[key] = value } else if j > i { moved["body.\(j - 1)"] = value }
          } else {
            moved[key] = value
          }
        }
        slide.positions = moved
      } else {
        var hidden = slide.hidden ?? []
        if !hidden.contains(elementID) { hidden.append(elementID) }
        slide.hidden = hidden
      }
    }
    selection = nil
    editing = nil
  }

  func restoreHidden() {
    checkpoint()
    updateCurrent { $0.hidden = nil }
  }

  func text(of elementID: String) -> String {
    guard let slide = current else { return "" }
    if elementID == "title" { return slide.title }
    if elementID.hasPrefix("body."), let i = Int(elementID.dropFirst(5)), slide.bodyLines.indices.contains(i) {
      return slide.bodyLines[i]
    }
    return ""
  }

  func setText(_ text: String, of elementID: String) {
    updateCurrent { slide in
      if elementID == "title" {
        slide.title = text
      } else if elementID.hasPrefix("body."), let i = Int(elementID.dropFirst(5)), slide.bodyLines.indices.contains(i) {
        slide.bodyLines[i] = text
      }
    }
  }

  func beginEditing(_ elementID: String) {
    guard elementID != "image" else { return }
    checkpoint()
    selection = elementID
    editing = elementID
  }

  // MARK: Generation

  func send(_ text: String? = nil) {
    let request = (text ?? prompt).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !request.isEmpty, generation == nil else { return }
    if mic.isLive { mic.stop() }
    prompt = ""
    tab = .ask
    messages.append(ChatMessage(role: .user, text: request))
    messages.append(ChatMessage(role: .assistant, text: buildingFromHome ? Self.openYourDuo : "", isWorking: true))
    generation = Task { @MainActor in
      await run(request)
      generation = nil
    }
  }

  func cancelGeneration() {
    generation?.cancel()
  }

  private struct RunState {
    var startedDeck = false
    var addIndex: Int?
    var built = 0
    var changed = 0
  }

  @MainActor
  private func run(_ request: String) async {
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
    var run = RunState()
    let runContext = takeContext()
    do {
      for try await chunk in DeckGenerator.stream(prompt: request, deck: app.deck, context: runContext) {
        try Task.checkCancellation()
        let (completed, partial) = parser.feed(chunk)
        for op in completed { apply(op, &run) }
        if let partial { apply(partial, &run) }
      }
      if let last = parser.finish() { apply(last, &run) }
      finishAssistant(summary(run))
    } catch is CancellationError {
      finishAssistant("Stopped.")
    } catch {
      if let urlError = error as? URLError, urlError.code == .cancelled {
        finishAssistant("Stopped.")
      } else {
        finishAssistant(error.localizedDescription)
      }
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

  private func summary(_ run: RunState) -> String? {
    if run.built > 0 { return run.built == 1 ? "Added 1 slide." : "Built \(run.built) slides." }
    if run.changed > 0 { return run.changed == 1 ? "Updated 1 slide." : "Updated \(run.changed) slides." }
    return nil
  }

  private func finishAssistant(_ note: String?) {
    guard let i = messages.lastIndex(where: { $0.role == .assistant }) else { return }
    messages[i].isWorking = false
    if let note {
      messages[i].text = messages[i].text.isEmpty ? note : messages[i].text + "\n" + note
    }
  }

  private func setAssistantText(_ text: String) {
    guard let i = messages.lastIndex(where: { $0.role == .assistant }) else { return }
    messages[i].text = text
  }

  private func apply(_ op: DeckOp, _ run: inout RunState) {
    switch op.kind {
    case .say:
      // From the home screen the chat just tells them to open the phone.
      if buildingFromHome {
        setAssistantText(Self.openYourDuo)
      } else if let text = op.text {
        setAssistantText(text)
      }

    case .deck:
      if !run.startedDeck {
        run.startedDeck = true
        app.deck = Deck(title: op.title ?? "Untitled", slides: [])
        app.currentIndex = 0
      }
      if let title = op.title { app.deck.title = title }

    case .add:
      if run.addIndex == nil {
        // Wait until we know the layout or title so the slide doesn't jump.
        guard op.layout != nil || op.title != nil else { return }
        let slide = Slide(layout: op.layout ?? .statement, title: "")
        app.deck.slides.append(slide)
        run.addIndex = app.deck.slides.count - 1
        app.currentIndex = app.deck.slides.count - 1
        slideInProgress = true
      }
      guard let index = run.addIndex, app.deck.slides.indices.contains(index) else { return }
      fill(&app.deck.slides[index], from: op)
      orbState = .composing
      status = "Writing slide \(index + 1)" + (op.title.map { " · \($0)" } ?? "")
      if op.complete {
        run.addIndex = nil
        run.built += 1
        slidesBuilt = run.built
        slideInProgress = false
      }

    case .replace:
      guard let id = op.id, let index = app.deck.slides.firstIndex(where: { $0.id == id }) else { return }
      if app.currentIndex != index { app.currentIndex = index }
      fill(&app.deck.slides[index], from: op)
      orbState = .shaping
      status = "Reworking slide \(index + 1)"
      if op.complete { run.changed += 1 }

    case .delete:
      guard op.complete, let id = op.id, let index = app.deck.slides.firstIndex(where: { $0.id == id }) else { return }
      app.deck.slides.remove(at: index)
      app.go(to: app.currentIndex)
      run.changed += 1

    case .remember:
      guard op.complete, let text = op.text else { return }
      remember(text)
    }
  }

  private func fill(_ slide: inout Slide, from op: DeckOp) {
    if let layout = op.layout, layout != slide.layout {
      slide.layout = layout
      slide.positions = nil
    }
    if let title = op.title, title != slide.title { slide.title = title }
    // Body grows line by line; never shrink it on a partial update.
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
}
