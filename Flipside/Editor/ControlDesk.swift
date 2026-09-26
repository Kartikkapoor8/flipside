import SwiftUI

// Shared desk pieces: the layout menu, the Flipside mark and Settings.

/// Follow the fold, side by side, or stacked.
struct LayoutToggle: View {
  @Binding var layout: StudioLayout

  var body: some View {
    Menu {
      Picker("Layout", selection: Binding(
        get: { layout },
        set: { value in withAnimation(.snappy(duration: 0.3)) { layout = value } }
      )) {
        ForEach(StudioLayout.allCases) { option in
          Label(option.label, systemImage: option.icon).tag(option)
        }
      }
    } label: {
      Image(systemName: layout.icon)
        .font(.system(size: 13, weight: .semibold))
        .frame(width: 34, height: 34)
        .foregroundStyle(Theme.text)
    }
    .glassEffect(.regular.interactive(), in: .circle)
    .accessibilityLabel("Layout: \(layout.label)")
  }
}

struct FlipsideMark: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Theme.coral)
        .frame(width: 14, height: 20).offset(x: -4)
      RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Theme.violet.opacity(0.85))
        .frame(width: 14, height: 20).offset(x: 4)
        .blendMode(.multiply)
    }
    .frame(width: 32, height: 32)
    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.surface))
    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
  }
}

// MARK: - Settings

struct SettingsSheet: View {
  let model: StudioModel
  @Environment(\.dismiss) private var dismiss
  @State private var openAI = UserDefaults.standard.string(forKey: "OPENAI_API_KEY") ?? ""
  @State private var openAIModel = UserDefaults.standard.string(forKey: "OPENAI_MODEL") ?? ""
  @State private var anthropic = UserDefaults.standard.string(forKey: "ANTHROPIC_API_KEY") ?? ""

  var body: some View {
    NavigationStack {
      Form {
        Section {
          SecureField("OpenAI API key", text: $openAI)
          TextField("Model (default gpt-5)", text: $openAIModel)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        } header: {
          Text("OpenAI")
        } footer: {
          Text("Writes the slides and generates their images. Decks are currently written by \(DeckGenerator.providerLabel).")
        }
        Section {
          SecureField("Anthropic API key (optional)", text: $anthropic)
        } footer: {
          Text("Used only when no OpenAI key is set.")
        }
        Section("Deck") {
          Button("Load the Flipside pitch deck") {
            model.checkpoint()
            model.app.deck = Deck.bundled()
            model.app.currentIndex = 0
            dismiss()
          }
          Button("Clear deck", role: .destructive) {
            model.checkpoint()
            model.app.deck = Deck.empty
            model.app.currentIndex = 0
            dismiss()
          }
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            Secrets.store(openAI, for: "OPENAI_API_KEY")
            Secrets.store(openAIModel, for: "OPENAI_MODEL")
            Secrets.store(anthropic, for: "ANTHROPIC_API_KEY")
            dismiss()
          }
        }
      }
    }
  }
}
