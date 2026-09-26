import SwiftUI

// Home chat and composer. Lived in Editor/HomeView.swift until the studio rewrite; the desk chat card (App/DeckHomeView) still uses them.

// MARK: - Chat

/// The latest few messages. Empty state invites a prompt.
struct HomeChat: View {
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
struct HomeComposer: View {
  @Bindable var model: StudioModel
  /// Home (App/DeckHomeView) starts the project itself so the phone stays on the home screen while it builds.
  var onSend: ((String) -> Void)? = nil
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
    if let onSend { onSend(text) } else { model.startProject(text) }
  }
}
