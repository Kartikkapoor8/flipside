import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// "Import a project": a deck file opens as-is; a document or a link becomes a new deck.
struct ImportSheet: View {
  let model: StudioModel
  @Environment(\.dismiss) private var dismiss
  @State private var picking: Pick?
  @State private var link = ""
  @State private var error: String?

  private enum Pick: Identifiable {
    case deck, document
    var id: Int { hashValue }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 12) {
          option(
            icon: "rectangle.stack",
            title: "Deck file",
            detail: "A Flipside deck.json. Opens exactly as saved."
          ) { picking = .deck }
          option(
            icon: "doc.text",
            title: "Document",
            detail: "PDF, text or Markdown. We turn it into a deck."
          ) { picking = .document }
          VStack(alignment: .leading, spacing: 10) {
            Label("From a link", systemImage: "link")
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(Theme.text)
            Text("A web page, article or listing. We read it and build the deck.")
              .font(.system(size: 13))
              .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
              TextField("https://", text: $link)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(.system(size: 15))
                .padding(.horizontal, 12).padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
              Button("Build") { build(from: link) }
                .buttonStyle(.glassProminent)
                .disabled(URL(string: link)?.scheme?.hasPrefix("http") != true)
            }
          }
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .glassEffect(.regular, in: .rect(cornerRadius: 20))
          if let error {
            Text(error).font(.system(size: 13)).foregroundStyle(Theme.coral)
          }
        }
        .padding(16)
      }
      .background(Theme.background)
      .navigationTitle("Import a project")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      }
      .fileImporter(
        isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
        allowedContentTypes: picking == .deck ? [.json] : Self.documentTypes
      ) { result in
        let kind = picking
        picking = nil
        switch result {
        case .success(let url): load(url, as: kind)
        case .failure(let failure): error = failure.localizedDescription
        }
      }
    }
  }

  private static var documentTypes: [UTType] {
    [.pdf, .plainText, .text] + [UTType(filenameExtension: "md")].compactMap { $0 }
  }

  private func option(icon: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: icon)
          .font(.system(size: 20, weight: .semibold))
          .frame(width: 44, height: 44)
          .glassEffect(.regular.tint(Theme.coral.opacity(0.15)), in: .rect(cornerRadius: 12))
        VStack(alignment: .leading, spacing: 3) {
          Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
          Text(detail).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textSecondary)
      }
      .padding(16)
      .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }
    .buttonStyle(.plain)
  }

  private func load(_ url: URL, as kind: Pick?) {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    switch kind {
    case .deck:
      guard let data = try? Data(contentsOf: url), let deck = try? JSONDecoder().decode(Deck.self, from: data), !deck.slides.isEmpty else {
        error = "That file isn't a Flipside deck."
        return
      }
      model.importDeck(deck)
      dismiss()
    case .document:
      let text: String?
      if url.pathExtension.lowercased() == "pdf" {
        text = PDFDocument(url: url)?.string
      } else {
        text = try? String(contentsOf: url, encoding: .utf8)
      }
      guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        error = "Couldn't read any text from that document."
        return
      }
      let name = url.deletingPathExtension().lastPathComponent
      model.startProject("Make a deck from this document, \"\(name)\":\n\n\(text.prefix(8000))")
      dismiss()
    case nil:
      break
    }
  }

  private func build(from link: String) {
    model.startProject("Make a deck from this link: \(link)")
    dismiss()
  }
}
