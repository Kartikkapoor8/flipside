import SwiftUI

/// The home screen. Every launch opens here, and it shows whenever the phone is folded shut.
/// Nothing is reopened automatically; the presenter picks: start a new deck, import one, or open a past project.
/// After a choice the notice line tells them to open the Duo, where the deck is.
struct HomeView: View {
  @Bindable var model: StudioModel
  @State private var projects: [Project] = []
  @State private var showImport = false

  var body: some View {
    GeometryReader { proxy in
      let wide = proxy.size.width >= 640
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          header
          if let notice = model.homeNotice {
            NoticeBanner(text: notice, working: model.app.isGenerating, orbState: model.orbState)
              .transition(.move(edge: .top).combined(with: .opacity))
          }
          if wide {
            HStack(alignment: .top, spacing: 14) {
              StartDeckCard(model: model)
                .frame(maxWidth: .infinity)
              ImportCard { showImport = true }
                .frame(width: max(proxy.size.width * 0.3, 220))
            }
          } else {
            StartDeckCard(model: model)
            ImportCard(compact: true) { showImport = true }
          }
          projectsSection(columns: wide ? 3 : 1)
        }
        .padding(.horizontal, wide ? 28 : 16)
        .padding(.top, wide ? 24 : 14)
        .padding(.bottom, 20)
        .animation(.snappy(duration: 0.3), value: model.homeNotice)
      }
      .scrollIndicators(.hidden)
      .overlay(alignment: .topTrailing) {
        // Sits in the strip beside the status bar, below the Wi-Fi symbol, when there is one.
        let strip = proxy.safeAreaInsets.trailing
        BuildRail(model: model)
          .frame(width: max(strip, 44), height: proxy.size.height * 0.6)
          .offset(x: strip > 20 ? strip : -6, y: proxy.size.height * 0.28)
      }
    }
    .background(HomeBackdrop())
    .sheet(isPresented: $showImport) { ImportSheet(model: model) }
    .onAppear(perform: reload)
    #if DEBUG
    .task {
      // `-homePrompt "topic"` starts a build on launch, for checking the loading bar without typing.
      if let prompt = UserDefaults.standard.string(forKey: "homePrompt"), !prompt.isEmpty, !model.app.isGenerating {
        UserDefaults.standard.removeObject(forKey: "homePrompt")
        model.startProject(prompt)
      }
    }
    #endif
    .onDisappear {
      // The notice is for the folded moment; don't leave a stale one for next time.
      if !model.app.isGenerating { model.homeNotice = nil }
    }
    .onChange(of: model.app.isGenerating) { reload() }
    .onChange(of: model.projectID) { reload() }
  }

  private var header: some View {
    HStack(spacing: 12) {
      FlipsideMark()
      VStack(alignment: .leading, spacing: 1) {
        Text("Flipside")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(Theme.text)
        Text(model.app.hingeStatus == .closed ? "Folded" : "Home")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(Theme.textSecondary)
      }
      Spacer()
      MemoryButton(model: model)
      glassIcon("gearshape", label: "Settings", enabled: true) { model.showSettings = true }
    }
  }

  @ViewBuilder
  private func projectsSection(columns: Int) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("PAST PROJECTS")
        .font(.system(size: 11, weight: .bold)).tracking(1.2)
        .foregroundStyle(Theme.textSecondary)
        .padding(.leading, 4)
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 12) {
        ForEach(projects) { project in
          Button {
            withAnimation(.snappy(duration: 0.3)) { model.openProject(project) }
          } label: {
            ProjectCard(project: project, isOpen: project.id == model.projectID && !model.app.isHome, large: columns > 1)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func reload() {
    projects = ProjectStore.all()
  }
}

private struct HomeBackdrop: View {
  var body: some View {
    ZStack {
      Theme.background
      Circle().fill(Theme.violet.opacity(0.16)).frame(width: 460).blur(radius: 130).offset(x: -220, y: -260)
      Circle().fill(Theme.coral.opacity(0.14)).frame(width: 420).blur(radius: 130).offset(x: 260, y: 280)
    }
    .ignoresSafeArea()
  }
}

/// "Open your Duo…" after a choice, with the orb while a deck is building.
private struct NoticeBanner: View {
  let text: String
  let working: Bool
  let orbState: OrbState?

  var body: some View {
    HStack(spacing: 12) {
      if working {
        ThinkingOrb(state: orbState ?? .composing, size: 20)
      } else {
        Image(systemName: "iphone.gen3.radiowaves.left.and.right")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Theme.coral)
      }
      Text(text)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Theme.text)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16).padding(.vertical, 14)
    .glassEffect(.regular.tint(Theme.coral.opacity(0.1)), in: .rect(cornerRadius: 18))
  }
}

// MARK: - Start a new deck

/// The big card: the prompt, the mic, and a few starters.
private struct StartDeckCard: View {
  @Bindable var model: StudioModel
  @FocusState private var focused: Bool

  private let starters = [
    "Open house for 12 Elm St",
    "Pitch a coffee subscription",
    "Quarterly update in five slides",
  ]

  var body: some View {
    let busy = model.app.isGenerating
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .center, spacing: 14) {
        ThinkingOrb(state: model.mic.isLive ? .listening : (busy ? .composing : .breathing), size: 64, level: model.mic.level)
        VStack(alignment: .leading, spacing: 4) {
          Text("Start a new deck")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(Theme.text)
          Text("Say or type what you're presenting, paste a link, or attach files.")
            .font(.system(size: 14))
            .foregroundStyle(Theme.textSecondary)
        }
      }

      VoiceBeam(
        level: model.mic.level,
        processing: busy,
        colorVariant: .colorful,
        strength: model.mic.isLive || busy ? 1 : 0.75,
        idle: model.mic.isLive ? 0.12 : 0.1,
        theme: .light,
        cornerRadius: 20
      ) {
        VStack(alignment: .leading, spacing: 10) {
          AttachmentChips(model: model)
          TextField(model.mic.isLive ? "Listening…" : "A realtor listing, a founder pitch, a class…", text: $model.prompt, axis: .vertical)
            .lineLimit(2...4)
            .font(.system(size: 17))
            .foregroundStyle(Theme.text)
            .focused($focused)
            .submitLabel(.send)
            .onSubmit(send)
          HStack(spacing: 8) {
            AttachButton(model: model, size: 40)
            Spacer()
            Button { model.mic.toggle() } label: {
              Image(systemName: model.mic.isLive ? "stop.fill" : "mic.fill")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(model.mic.isLive ? .white : Theme.text)
            .glassEffect(model.mic.isLive ? .regular.tint(Theme.coral).interactive() : .regular.interactive(), in: .circle)
            .accessibilityLabel(model.mic.isLive ? "Stop listening" : "Listen")

            Button {
              if busy { model.cancelGeneration() } else { send() }
            } label: {
              Image(systemName: busy ? "square.fill" : "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .glassEffect(.regular.tint(canSend || busy ? Theme.ink : Theme.textSecondary.opacity(0.5)).interactive(), in: .circle)
            .disabled(!canSend && !busy)
            .accessibilityLabel(busy ? "Stop" : "Send")
          }
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(starters, id: \.self) { starter in
            Button(starter) { model.prompt = starter }
              .buttonStyle(.plain)
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(Theme.text)
              .padding(.horizontal, 12).padding(.vertical, 8)
              .glassEffect(.regular.interactive(), in: .capsule)
          }
        }
      }
    }
    .padding(20)
    .glassEffect(.regular, in: .rect(cornerRadius: 28))
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

// MARK: - Import

private struct ImportCard: View {
  var compact = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Group {
        if compact {
          HStack(spacing: 14) {
            icon
            text
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textSecondary)
          }
        } else {
          VStack(alignment: .leading, spacing: 14) {
            icon
            Spacer(minLength: 0)
            text
            HStack(spacing: 6) {
              ForEach(["JSON", "PDF", "Notes", "Link"], id: \.self) { tag in
                Text(tag)
                  .font(.system(size: 11, weight: .semibold))
                  .foregroundStyle(Theme.textSecondary)
                  .padding(.horizontal, 8).padding(.vertical, 4)
                  .glassEffect(.regular, in: .capsule)
              }
            }
          }
          .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
        }
      }
      .padding(20)
      .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
    }
    .buttonStyle(.plain)
  }

  private var icon: some View {
    Image(systemName: "square.and.arrow.down.on.square")
      .font(.system(size: 22, weight: .semibold))
      .foregroundStyle(Theme.coral)
      .frame(width: 52, height: 52)
      .glassEffect(.regular.tint(Theme.coral.opacity(0.14)), in: .rect(cornerRadius: 14))
  }

  private var text: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Import a project")
        .font(.system(size: compact ? 17 : 20, weight: .bold))
        .foregroundStyle(Theme.text)
      Text("Bring a deck file, a document or a link.")
        .font(.system(size: 13))
        .foregroundStyle(Theme.textSecondary)
    }
  }
}

// MARK: - Project card

private struct ProjectCard: View {
  let project: Project
  let isOpen: Bool
  let large: Bool

  var body: some View {
    Group {
      if large {
        VStack(alignment: .leading, spacing: 10) {
          thumbnail
          labels
        }
      } else {
        HStack(spacing: 12) {
          thumbnail.frame(width: 110)
          labels
          Spacer(minLength: 0)
        }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
  }

  @ViewBuilder
  private var thumbnail: some View {
    if let first = project.deck.slides.first {
      SlideView(slide: first, animated: false, aspect: 1.6, cornerRadius: 12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
        .overlay(alignment: .topTrailing) {
          if isOpen {
            Text("Open")
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(.white)
              .padding(.horizontal, 8).padding(.vertical, 3)
              .background(Capsule().fill(Theme.coral))
              .padding(8)
          }
        }
    }
  }

  private var labels: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(project.title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Theme.text)
        .lineLimit(2)
      Text(subtitle)
        .font(.system(size: 12))
        .foregroundStyle(Theme.textSecondary)
    }
  }

  private var subtitle: String {
    let count = project.deck.slides.count
    let slides = count == 1 ? "1 slide" : "\(count) slides"
    guard project.updatedAt > .distantPast else { return "\(slides) · pitch deck" }
    return "\(slides) · \(project.updatedAt.formatted(.relative(presentation: .named)))"
  }
}
