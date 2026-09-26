import SwiftUI

/// The presenter half, in every pose. Liquid Glass on every control.
/// Left: the deck as a queue of slide cards (drag to reorder, tap to jump).
/// Centre: notes for the current slide (editable when flat).
/// Right: Text / Media / Ask. Bottom: laser trackpad, Back, Next, Swap sides.
struct PresenterDesk: View {
  @Bindable var model: StudioModel
  /// Flat (edit) or standing (present). Notes are editable only when flat.
  let editing: Bool

  var body: some View {
    GeometryReader { proxy in
      let wide = proxy.size.width >= 560
      VStack(spacing: 10) {
        DeskHeader(model: model, editing: editing)
        if wide {
          HStack(alignment: .top, spacing: 10) {
            SlideQueue(model: model, compact: false)
              .frame(width: max(proxy.size.width * 0.28, 170))
            NotesPanel(model: model, editing: editing)
            DeskTabs(model: model)
              .frame(width: proxy.size.width * 0.36)
          }
        } else {
          HStack(alignment: .top, spacing: 10) {
            SlideQueue(model: model, compact: true)
              .frame(width: 92)
            VStack(spacing: 10) {
              NotesPanel(model: model, editing: editing)
                .frame(maxHeight: proxy.size.height * 0.3)
              DeskTabs(model: model)
            }
          }
        }
        DeskBottomBar(model: model)
      }
      .padding(12)
    }
    .background(DeskBackdrop())
  }
}

/// Soft colour behind the glass so it has something to refract.
private struct DeskBackdrop: View {
  var body: some View {
    ZStack {
      Theme.background
      Circle().fill(Theme.violet.opacity(0.16)).frame(width: 420).blur(radius: 120).offset(x: -160, y: -200)
      Circle().fill(Theme.coral.opacity(0.14)).frame(width: 380).blur(radius: 120).offset(x: 200, y: 220)
    }
    .ignoresSafeArea()
  }
}

// MARK: - Header

private struct DeskHeader: View {
  @Bindable var model: StudioModel
  let editing: Bool

  var body: some View {
    HStack(spacing: 8) {
      FlipsideMark()
      VStack(alignment: .leading, spacing: 0) {
        TextField("Untitled", text: Binding(get: { model.app.deck.title }, set: { model.app.deck.title = $0 }))
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Theme.text)
          .lineLimit(1)
          .disabled(!editing)
        Text(editing ? "Editing · lay flat" : "Presenting")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(Theme.textSecondary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      GlassEffectContainer(spacing: 6) {
        HStack(spacing: 6) {
          glassIcon("house", label: "Home", enabled: true) {
            ProjectStore.save(model.app.deck, id: model.projectID)
            withAnimation(.easeInOut(duration: 0.3)) { model.app.isHome = true }
          }
          if editing {
            LayoutToggle(layout: $model.layout)
            glassIcon("arrow.uturn.backward", label: "Undo", enabled: model.canUndo) { model.undo() }
            glassIcon("arrow.uturn.forward", label: "Redo", enabled: model.canRedo) { model.redo() }
          }
          MemoryButton(model: model)
          glassIcon("gearshape", label: "Settings", enabled: true) { model.showSettings = true }
        }
      }
    }
  }
}

func glassIcon(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
  Button(action: action) {
    Image(systemName: icon)
      .font(.system(size: 13, weight: .semibold))
      .frame(width: 34, height: 34)
  }
  .buttonStyle(.plain)
  .foregroundStyle(enabled ? Theme.text : Theme.textSecondary.opacity(0.4))
  .glassEffect(.regular.interactive(), in: .circle)
  .disabled(!enabled)
  .accessibilityLabel(label)
}

// MARK: - Queue

/// Spotify-queue style list of slide cards. Long-press and drag to reorder; tap to jump.
private struct SlideQueue: View {
  @Bindable var model: StudioModel
  let compact: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if !compact {
        Text("QUEUE")
          .font(.system(size: 10, weight: .bold)).tracking(1.2)
          .foregroundStyle(Theme.textSecondary)
          .padding(.leading, 4)
      }
      List {
        ForEach(Array(model.app.deck.slides.enumerated()), id: \.element.id) { index, slide in
          QueueCard(
            slide: slide,
            index: index,
            isCurrent: index == model.app.currentIndex,
            aspect: max(model.artifactAspect, 0.8),
            compact: compact
          )
          .contentShape(Rectangle())
          .onTapGesture { model.select(slide: index) }
          .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
          .listRowSeparator(.hidden)
          .listRowBackground(Color.clear)
        }
        .onMove { model.moveSlides(from: $0, to: $1) }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .scrollIndicators(.hidden)
    }
  }
}

private struct QueueCard: View {
  let slide: Slide
  let index: Int
  let isCurrent: Bool
  let aspect: CGFloat
  let compact: Bool

  var body: some View {
    HStack(spacing: 10) {
      SlideView(slide: slide, animated: false, aspect: aspect, cornerRadius: 6)
        .frame(width: compact ? 64 : 48)
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isCurrent ? Theme.coral : Theme.line, lineWidth: isCurrent ? 2 : 1))
      if !compact {
        VStack(alignment: .leading, spacing: 2) {
          Text(slide.title.isEmpty ? "Untitled" : slide.title)
            .font(.system(size: 13, weight: isCurrent ? .bold : .semibold))
            .foregroundStyle(isCurrent ? Theme.coral : Theme.text)
            .lineLimit(2)
          Text("\(index + 1) · \(slide.layout.label)")
            .font(.system(size: 11))
            .foregroundStyle(Theme.textSecondary)
        }
        Spacer(minLength: 0)
        if isCurrent {
          // "Now playing" marker.
          Image(systemName: "waveform")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.coral)
            .symbolEffect(.variableColor.iterative, options: .repeating)
        }
      }
    }
    .padding(compact ? 6 : 8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(isCurrent ? .regular.tint(Theme.coral.opacity(0.12)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 14))
    .overlay(alignment: .topLeading) {
      if compact {
        Text("\(index + 1)")
          .font(.system(size: 10, weight: .bold).monospacedDigit())
          .foregroundStyle(.white)
          .padding(.horizontal, 5).padding(.vertical, 1)
          .background(Capsule().fill(isCurrent ? Theme.coral : Theme.ink.opacity(0.6)))
          .padding(4)
      }
    }
  }
}

// MARK: - Notes

private struct NotesPanel: View {
  @Bindable var model: StudioModel
  let editing: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("NOTES")
          .font(.system(size: 10, weight: .bold)).tracking(1.2)
          .foregroundStyle(Theme.textSecondary)
        Spacer()
        if let cue = model.current?.cue, !cue.isEmpty {
          Label(cue, systemImage: "bell")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.coral)
            .lineLimit(1)
        }
      }
      if editing {
        TextEditor(text: Binding(
          get: { model.current?.notes ?? "" },
          set: { v in model.updateCurrent { $0.notes = v } }
        ))
        .font(.system(size: 16))
        .foregroundStyle(Theme.text)
        .scrollContentBackground(.hidden)
        .overlay(alignment: .topLeading) {
          if (model.current?.notes ?? "").isEmpty {
            Text("What you'll say on this slide").font(.system(size: 16)).foregroundStyle(Theme.textSecondary)
              .padding(.top, 8).padding(.leading, 5).allowsHitTesting(false)
          }
        }
      } else {
        ScrollView {
          Text(model.current?.notes ?? "")
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .glassEffect(.regular, in: .rect(cornerRadius: 18))
  }
}

// MARK: - Text / Media / Ask

private struct DeskTabs: View {
  @Bindable var model: StudioModel
  @Namespace private var ns

  var body: some View {
    VStack(spacing: 10) {
      GlassEffectContainer(spacing: 4) {
        HStack(spacing: 4) {
          ForEach(DeskTab.allCases) { tab in
            Button {
              withAnimation(.snappy(duration: 0.25)) { model.tab = tab }
            } label: {
              Text(tab.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(model.tab == tab ? .white : Theme.text)
            .glassEffect(model.tab == tab ? .regular.tint(Theme.ink).interactive() : .regular.interactive(), in: .capsule)
            .glassEffectID(tab.rawValue, in: ns)
          }
        }
      }
      Group {
        switch model.tab {
        case .text: TextTab(model: model)
        case .media: MediaTab(model: model)
        case .ask: AskTab(model: model)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
  }
}

/// Tap to add a line, type, and it appears on their side as you type.
private struct TextTab: View {
  @Bindable var model: StudioModel
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let i = model.typingLine, let slide = model.current, slide.bodyLines.indices.contains(i) {
        TextField("Type the new line", text: Binding(
          get: { (model.current.flatMap { $0.bodyLines.indices.contains(i) ? $0.bodyLines[i] : nil } ?? "").replacingOccurrences(of: Slide.emptyLineMarker, with: "") },
          set: { v in model.updateCurrent { if $0.bodyLines.indices.contains(i) { $0.bodyLines[i] = v } } }
        ), axis: .vertical)
        .font(.system(size: 15))
        .foregroundStyle(Theme.text)
        .focused($focused)
        .submitLabel(.done)
        .onSubmit { model.finishLine() }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        .onAppear { focused = true }
        HStack {
          Text("Showing on their side as you type")
            .font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
          Spacer()
          Button("Done") { model.finishLine() }
            .buttonStyle(.glass)
            .font(.system(size: 12, weight: .semibold))
        }
      } else {
        Button {
          model.addLine()
        } label: {
          Label("Add a line", systemImage: "plus")
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.text)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        .disabled(model.current == nil)

        ScrollView {
          VStack(alignment: .leading, spacing: 6) {
            ForEach(Array((model.current?.bodyLines ?? []).enumerated()), id: \.offset) { i, line in
              Button { model.typingLine = i } label: {
                Text(line.isBlankLine ? "Empty line" : line)
                  .font(.system(size: 13))
                  .foregroundStyle(line.isBlankLine ? Theme.textSecondary : Theme.text)
                  .lineLimit(2)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.horizontal, 10).padding(.vertical, 8)
              }
              .buttonStyle(.plain)
              .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
            }
          }
        }
      }
    }
  }
}

/// Quick buttons for the deck's videos and images and the three animation presets.
struct MediaTab: View {
  let model: StudioModel

  var body: some View {
    let items = MediaLibrary.items(for: model.app.deck)
    VStack(alignment: .leading, spacing: 10) {
      ScrollView(.horizontal, showsIndicators: false) {
        GlassEffectContainer(spacing: 8) {
          HStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
              let onSlide = model.current?.media == item
              Button { model.insertMedia(item) } label: {
                VStack(spacing: 6) {
                  MediaThumb(item: item)
                    .frame(width: 84, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                  Label(item.title, systemImage: icon(item))
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .frame(width: 84)
                }
                .padding(6)
              }
              .buttonStyle(.plain)
              .foregroundStyle(onSlide ? Theme.coral : Theme.text)
              .glassEffect(onSlide ? .regular.tint(Theme.coral.opacity(0.18)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 16))
              .disabled(model.current == nil)
            }
          }
          .padding(.vertical, 2)
        }
      }
      if let slide = model.current, SlideLayoutEngine.hasSideCard(slide) {
        Button {
          model.removeMedia()
        } label: {
          Label("Remove from slide", systemImage: "minus.circle")
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.text)
        .glassEffect(.regular.interactive(), in: .capsule)
      }
    }
  }

  private func icon(_ item: SlideMedia) -> String {
    switch item.kind {
    case .video: "play.rectangle.fill"
    case .image: "photo"
    case .animation: AnimationPreset(rawValue: item.source)?.icon ?? "sparkles"
    }
  }
}

private struct MediaThumb: View {
  let item: SlideMedia

  var body: some View {
    switch item.kind {
    case .video:
      ZStack {
        LinearGradient(colors: [Theme.violet, Theme.coral], startPoint: .topLeading, endPoint: .bottomTrailing)
        Image(systemName: "play.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
      }
    case .image:
      GeneratedImageView(prompt: item.source, url: URL(string: item.source)?.scheme == nil ? nil : item.source, animated: false)
    case .animation:
      AnimationPreset(rawValue: item.source).map { AnimationPresetView(preset: $0) }
    }
  }
}

/// Ask the AI about the deck (answer stays on your side), or switch to Build to change the deck.
private struct AskTab: View {
  @Bindable var model: StudioModel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      GlassEffectContainer(spacing: 4) {
        HStack(spacing: 4) {
          modeButton("Ask", builds: false)
          modeButton("Build", builds: true)
        }
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          if model.askBuilds {
            if let last = model.messages.last(where: { $0.role == .assistant }) {
              HStack(alignment: .top, spacing: 8) {
                if last.isWorking {
                  ThinkingOrb(state: model.orbState ?? .working, size: 20)
                } else {
                  Image(systemName: "sparkle").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.coral)
                }
                Text(last.text.isEmpty ? "Thinking…" : last.text)
                  .font(.system(size: 13))
                  .foregroundStyle(Theme.text)
              }
            } else {
              Text("Describe a deck or a change. It builds on their side, slide by slide.")
                .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
          } else if model.isAsking || !model.askAnswer.isEmpty {
            HStack(alignment: .top, spacing: 8) {
              if model.isAsking && model.askAnswer.isEmpty {
                ThinkingOrb(state: .searching, size: 20)
              } else {
                Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textSecondary)
              }
              Text(model.askAnswer.isEmpty ? "Thinking…" : model.askAnswer)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
            }
          } else {
            Text("Ask anything about the deck. Only you see the answer.")
              .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      AttachmentChips(model: model)
      Composer(model: model)
    }
  }

  private func modeButton(_ title: String, builds: Bool) -> some View {
    Button {
      withAnimation(.snappy(duration: 0.2)) { model.askBuilds = builds }
    } label: {
      Text(title)
        .font(.system(size: 12, weight: .semibold))
        .padding(.horizontal, 14).padding(.vertical, 6)
    }
    .buttonStyle(.plain)
    .foregroundStyle(model.askBuilds == builds ? .white : Theme.text)
    .glassEffect(model.askBuilds == builds ? .regular.tint(Theme.coral).interactive() : .regular.interactive(), in: .capsule)
  }
}

/// Prompt field with the voice glow and a mic. Sends to Ask or Build depending on the mode.
struct Composer: View {
  @Bindable var model: StudioModel
  @FocusState private var focused: Bool

  var body: some View {
    let busy = model.app.isGenerating || model.isAsking
    VoiceBeam(
      level: model.mic.level,
      processing: busy,
      colorVariant: .colorful,
      strength: model.mic.isLive || busy ? 1 : 0.75,
      idle: model.mic.isLive ? 0.12 : 0.1,
      theme: .light,
      cornerRadius: 20
    ) {
      HStack(spacing: 8) {
        TextField(
          model.mic.isLive ? "Listening…" : (model.askBuilds ? "Topic, link, or a change" : "Ask about the deck"),
          text: $model.prompt,
          axis: .vertical
        )
        .lineLimit(1...3)
        .font(.system(size: 14))
        .foregroundStyle(Theme.text)
        .focused($focused)
        .submitLabel(.send)
        .onSubmit(send)

        AttachButton(model: model, size: 32)

        Button { model.mic.toggle() } label: {
          Image(systemName: model.mic.isLive ? "stop.fill" : "mic.fill")
            .font(.system(size: 13, weight: .semibold))
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.mic.isLive ? .white : Theme.text)
        .glassEffect(model.mic.isLive ? .regular.tint(Theme.coral).interactive() : .regular.interactive(), in: .circle)
        .accessibilityLabel(model.mic.isLive ? "Stop listening" : "Listen")

        Button {
          if model.app.isGenerating { model.cancelGeneration() } else { send() }
        } label: {
          Image(systemName: model.app.isGenerating ? "square.fill" : "arrow.up")
            .font(.system(size: 13, weight: .bold))
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(canSend || model.app.isGenerating ? Theme.ink : Theme.textSecondary.opacity(0.5)).interactive(), in: .circle)
        .disabled(!canSend && !model.app.isGenerating)
        .accessibilityLabel(model.app.isGenerating ? "Stop" : "Send")
      }
      .padding(.leading, 14).padding(.trailing, 6).padding(.vertical, 6)
      .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }
  }

  private var canSend: Bool {
    !model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func send() {
    if model.askBuilds { model.send() } else { model.ask(model.prompt) }
  }
}

// MARK: - Bottom bar

private struct DeskBottomBar: View {
  @Bindable var model: StudioModel

  var body: some View {
    GlassEffectContainer(spacing: 8) {
      HStack(spacing: 8) {
        LaserPad(model: model)
        barButton("Back", icon: "chevron.left", enabled: model.app.currentIndex > 0) { model.back() }
        barButton("Next", icon: "chevron.right", enabled: model.app.currentIndex < model.app.deck.slides.count - 1, prominent: true) { model.next() }
        barButton("Swap sides", icon: "arrow.left.arrow.right", enabled: true) { model.swapSides() }
      }
    }
    .frame(height: 56)
  }

  private func barButton(_ title: String, icon: String, enabled: Bool, prominent: Bool = false, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(spacing: 2) {
        Image(systemName: icon).font(.system(size: 15, weight: .bold))
        Text(title).font(.system(size: 10, weight: .semibold)).lineLimit(1)
      }
      .frame(width: 66, height: 56)
    }
    .buttonStyle(.plain)
    .foregroundStyle(prominent ? .white : (enabled ? Theme.text : Theme.textSecondary.opacity(0.4)))
    .glassEffect(prominent ? .regular.tint(enabled ? Theme.coral : Theme.textSecondary.opacity(0.4)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 16))
    .disabled(!enabled)
    .accessibilityLabel(title)
  }
}

/// Finger on the pad puts a laser dot on their side, at the same spot on the slide.
private struct LaserPad: View {
  let model: StudioModel
  @State private var touch: CGPoint?

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        if let touch {
          Circle().fill(Color.red).frame(width: 14, height: 14)
            .shadow(color: .red.opacity(0.6), radius: 8)
            .position(touch)
        } else {
          Label("Laser", systemImage: "hand.point.up.left")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let p = CGPoint(
              x: min(max(value.location.x, 0), proxy.size.width),
              y: min(max(value.location.y, 0), proxy.size.height)
            )
            touch = p
            model.app.laserPoint = CGPoint(x: p.x / max(proxy.size.width, 1), y: p.y / max(proxy.size.height, 1))
          }
          .onEnded { _ in
            touch = nil
            model.app.laserPoint = nil
          }
      )
    }
    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    .accessibilityLabel("Laser trackpad")
  }
}
