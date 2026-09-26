import SwiftUI

// MARK: - Attachments

/// Paperclip button for a prompt box. Picks one or more files to send as context.
struct AttachButton: View {
  let model: StudioModel
  var size: CGFloat = 36
  @State private var picking = false

  var body: some View {
    Button { picking = true } label: {
      Image(systemName: "paperclip")
        .font(.system(size: size * 0.4, weight: .semibold))
        .frame(width: size, height: size)
    }
    .buttonStyle(.plain)
    .foregroundStyle(Theme.text)
    .glassEffect(.regular.interactive(), in: .circle)
    .accessibilityLabel("Attach files")
    .fileImporter(isPresented: $picking, allowedContentTypes: Attachment.allowedTypes, allowsMultipleSelection: true) { result in
      if case .success(let urls) = result { model.attach(urls) }
    }
  }
}

/// The attached files as removable chips. Shows nothing when there are none.
struct AttachmentChips: View {
  let model: StudioModel

  var body: some View {
    if !model.attachments.isEmpty {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(model.attachments) { file in
            HStack(spacing: 6) {
              if let data = file.imageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
                  .frame(width: 20, height: 20)
                  .clipShape(RoundedRectangle(cornerRadius: 4))
              } else {
                Image(systemName: file.icon).font(.system(size: 11, weight: .semibold))
              }
              Text(file.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: 140)
              Button { withAnimation(.snappy) { model.detach(file) } } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
              }
              .buttonStyle(.plain)
              .accessibilityLabel("Remove \(file.name)")
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: .capsule)
            .transition(.scale.combined(with: .opacity))
          }
        }
      }
      .animation(.snappy, value: model.attachments)
    }
  }
}

// MARK: - Memory

/// Opens the Memory sheet.
struct MemoryButton: View {
  let model: StudioModel

  var body: some View {
    glassIcon("brain.head.profile", label: "Memory", enabled: true) { model.showMemory = true }
      .overlay(alignment: .topTrailing) {
        if model.memoryEnabled, !model.memories.isEmpty {
          Text("\(model.memories.count)")
            .font(.system(size: 9, weight: .bold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(Capsule().fill(Theme.coral))
            .offset(x: 4, y: -4)
            .allowsHitTesting(false)
        }
      }
  }
}

/// What Flipside remembers about the presenter. Add, remove, or turn memory off.
struct MemorySheet: View {
  @Bindable var model: StudioModel
  @Environment(\.dismiss) private var dismiss
  @State private var draft = ""

  var body: some View {
    NavigationStack {
      List {
        Section {
          Toggle("Use memory", isOn: $model.memoryEnabled)
          Button {
            Task { await model.learnFromPastTexts() }
          } label: {
            HStack {
              Label("Learn from past texts", systemImage: "text.book.closed")
              Spacer()
              if model.isLearning {
                ThinkingOrb(state: .searching, size: 20)
              }
            }
          }
          .disabled(!model.memoryEnabled || model.isLearning)
        } footer: {
          VStack(alignment: .leading, spacing: 4) {
            Text("Flipside keeps short facts about you (your business, audience, style) and uses them in every deck and answer. It updates them on its own from what you type: adding new facts, fixing ones that changed, and dropping duplicates. Add your own below, or say \"remember …\" in Ask.")
            if let error = model.memoryError {
              Text(error).foregroundStyle(Theme.coral)
            } else if let updated = model.memoryUpdatedAt {
              Text("Last updated \(updated.formatted(.relative(presentation: .named))).")
            }
          }
        }
        Section("Add a memory") {
          HStack {
            TextField("e.g. I'm a realtor at Compass in Austin", text: $draft, axis: .vertical)
              .onSubmit(add)
            Button("Add", action: add)
              .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || !model.memoryEnabled)
          }
        }
        Section(model.memories.isEmpty ? "Nothing remembered yet" : "Remembered") {
          ForEach(model.memories.reversed()) { item in
            VStack(alignment: .leading, spacing: 2) {
              Text(item.text).foregroundStyle(Theme.text)
              Text(item.createdAt.formatted(.relative(presentation: .named)))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            }
            .swipeActions {
              Button("Forget", role: .destructive) { model.forget(item) }
            }
          }
        }
        if !model.memories.isEmpty {
          Section {
            Button("Forget everything", role: .destructive) { model.forgetAll() }
          }
        }
      }
      .navigationTitle("Memory")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
    }
  }

  private func add() {
    model.remember(draft)
    draft = ""
  }
}
