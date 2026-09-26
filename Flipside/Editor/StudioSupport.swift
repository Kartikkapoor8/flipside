import SwiftUI

/// App-level plumbing for the Studio pieces placed in RootView's faces:
/// the Settings sheet, saving the deck as it changes, and speech filling the prompt.
struct StudioSupport: ViewModifier {
  @Bindable var model: StudioModel
  @State private var saveTask: Task<Void, Never>?

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: $model.showSettings) { SettingsSheet(model: model) }
      .onChange(of: model.mic.transcript) { _, text in
        if model.mic.isLive, !text.isEmpty { model.prompt = text }
      }
      .onChange(of: model.app.deck) { _, deck in
        // Save shortly after edits settle, so streaming and dragging don't write every frame.
        saveTask?.cancel()
        saveTask = Task {
          try? await Task.sleep(for: .milliseconds(600))
          guard !Task.isCancelled else { return }
          ProjectStore.save(deck, id: model.projectID)
        }
      }
  }
}

extension View {
  func studioSupport(_ model: StudioModel) -> some View {
    modifier(StudioSupport(model: model))
  }
}

/// The audience slot in RootView: editable when flat, read-only when standing. Always upright.
struct StudioAudienceSlot: View {
  let model: StudioModel

  var body: some View {
    if model.app.mode == .edit {
      ArtifactPane(model: model)
    } else {
      StudioAudienceFace(model: model)
    }
  }
}
