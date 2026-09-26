import SwiftUI

/// The home screen, shown when the phone is folded shut (one screen) or when no deck is open.
/// Chat on top: type or say a prompt to start a new deck. Past projects below: tap one to open it.
/// Either way the chat then asks them to open the Duo, where the deck is.
struct HomeView: View {
  @Bindable var model: StudioModel
  @State private var projects: [Project] = []

  var body: some View {
    VStack(spacing: 14) {
      header
      HomeChat(model: model)
      HomeComposer(model: model)
      projectsSection
    }
    .padding(.horizontal, 16)
    .padding(.top, 14)
    .padding(.bottom, 10)
    .background(HomeBackdrop())
    .onAppear(perform: reload)
    .onChange(of: model.messages.count) { reload() }
    .onChange(of: model.app.isGenerating) { reload() }
  }

  private var header: some View {
    HStack(spacing: 10) {
      FlipsideMark()
      VStack(alignment: .leading, spacing: 0) {
        Text("Flipside")
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(Theme.text)
        Text(model.app.hingeStatus == .closed ? "Folded" : "Home")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(Theme.textSecondary)
      }
      Spacer()
      glassIcon("gearshape", label: "Settings", enabled: true) { model.showSettings = true }
    }
  }

  private var projectsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("PAST PROJECTS")
        .font(.system(size: 10, weight: .bold)).tracking(1.2)
        .foregroundStyle(Theme.textSecondary)
        .padding(.leading, 4)
      ScrollView {
        LazyVStack(spacing: 8) {
          ForEach(projects) { project in
            Button {
              withAnimation(.snappy(duration: 0.3)) { model.openProject(project) }
            } label: {
              ProjectRow(project: project, isOpen: project.id == model.projectID)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.bottom, 4)
      }
      .scrollIndicators(.hidden)
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }

  private func reload() {
    projects = ProjectStore.all()
  }
}

private struct HomeBackdrop: View {
  var body: some View {
    ZStack {
      Theme.background
      Circle().fill(Theme.violet.opacity(0.16)).frame(width: 360).blur(radius: 110).offset(x: -140, y: -240)
      Circle().fill(Theme.coral.opacity(0.14)).frame(width: 320).blur(radius: 110).offset(x: 160, y: 260)
    }
    .ignoresSafeArea()
  }
}

// MARK: - Chat

/// The latest few messages. Empty state invites a prompt.
private struct HomeChat: View {
  let model: StudioModel

  var body: some View {
    let recent = Array(model.messages.suffix(4))
    VStack(alignment: .leading, spacing: 10) {
      if recent.isEmpty {
        HStack(alignment: .center, spacing: 12) {
          ThinkingOrb(state: model.mic.isLive ? .listening : .breathing, size: 64, level: model.mic.level)
          VStack(alignment: .leading, spacing: 4) {
            Text("What are we presenting?")
              .font(.system(size: 20, weight: .bold))
              .foregroundStyle(Theme.text)
            Text("Say or type a topic, or paste a link.")
              .font(.system(size: 13))
              .foregroundStyle(Theme.textSecondary)
          }
        }
      } else {
        ForEach(recent) { message in
          HomeMessageRow(message: message, orbState: model.orbState)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .glassEffect(.regular, in: .rect(cornerRadius: 20))
    .animation(.snappy(duration: 0.3), value: model.messages.count)
  }
}

private struct HomeMessageRow: View {
  let message: ChatMessage
  let orbState: OrbState?

  var body: some View {
    switch message.role {
    case .user:
      HStack {
        Spacer(minLength: 40)
        Text(message.text)
          .font(.system(size: 14))
          .foregroundStyle(.white)
          .padding(.horizontal, 12).padding(.vertical, 8)
          .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.ink))
      }
    case .assistant:
      HStack(alignment: .center, spacing: 10) {
        Group {
          if message.isWorking {
            ThinkingOrb(state: orbState ?? .working, size: 20)
          } else {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(Theme.coral)
          }
        }
        .frame(width: 24, height: 24)
        Text(message.text.isEmpty ? "Thinking…" : message.text)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Theme.text)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}

/// Prompt field with the voice glow. Sending starts a new project.
private struct HomeComposer: View {
  @Bindable var model: StudioModel
  @FocusState private var focused: Bool

  var body: some View {
    let busy = model.app.isGenerating
    VoiceBeam(
      level: model.mic.level,
      processing: busy,
      colorVariant: .colorful,
      strength: model.mic.isLive || busy ? 1 : 0.75,
      idle: model.mic.isLive ? 0.12 : 0.1,
      theme: .light,
      cornerRadius: 22
    ) {
      HStack(spacing: 8) {
        TextField(model.mic.isLive ? "Listening…" : "Start a new deck", text: $model.prompt, axis: .vertical)
          .lineLimit(1...3)
          .font(.system(size: 15))
          .foregroundStyle(Theme.text)
          .focused($focused)
          .submitLabel(.send)
          .onSubmit(send)

        Button { model.mic.toggle() } label: {
          Image(systemName: model.mic.isLive ? "stop.fill" : "mic.fill")
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.mic.isLive ? .white : Theme.text)
        .glassEffect(model.mic.isLive ? .regular.tint(Theme.coral).interactive() : .regular.interactive(), in: .circle)
        .accessibilityLabel(model.mic.isLive ? "Stop listening" : "Listen")

        Button {
          if busy { model.cancelGeneration() } else { send() }
        } label: {
          Image(systemName: busy ? "square.fill" : "arrow.up")
            .font(.system(size: 14, weight: .bold))
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(canSend || busy ? Theme.ink : Theme.textSecondary.opacity(0.5)).interactive(), in: .circle)
        .disabled(!canSend && !busy)
        .accessibilityLabel(busy ? "Stop" : "Send")
      }
      .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 6)
      .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
    }
  }

  private var canSend: Bool {
    !model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func send() {
    let text = model.prompt
    focused = false
    model.startProject(text)
  }
}

// MARK: - Project row

private struct ProjectRow: View {
  let project: Project
  let isOpen: Bool

  var body: some View {
    HStack(spacing: 12) {
      if let first = project.deck.slides.first {
        SlideView(slide: first, animated: false, aspect: 1.6, cornerRadius: 8)
          .frame(width: 96)
          .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line))
      }
      VStack(alignment: .leading, spacing: 3) {
        Text(project.title)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Theme.text)
          .lineLimit(2)
        Text(subtitle)
          .font(.system(size: 12))
          .foregroundStyle(Theme.textSecondary)
      }
      Spacer(minLength: 0)
      if isOpen {
        Text("Open")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 8).padding(.vertical, 3)
          .background(Capsule().fill(Theme.coral))
      } else {
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(Theme.textSecondary)
      }
    }
    .padding(10)
    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
  }

  private var subtitle: String {
    let count = project.deck.slides.count
    let slides = count == 1 ? "1 slide" : "\(count) slides"
    guard project.updatedAt > .distantPast else { return "\(slides) · pitch deck" }
    return "\(slides) · \(project.updatedAt.formatted(.relative(presentation: .named)))"
  }
}
