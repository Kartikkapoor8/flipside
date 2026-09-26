import PDFKit
import UIKit
import UniformTypeIdentifiers

/// A file attached to a prompt for context: its text, or a downscaled image.
struct Attachment: Identifiable, Hashable, Sendable {
  enum Kind: Sendable { case document, image }

  var id = UUID()
  var name: String
  var kind: Kind
  /// Extracted text for documents.
  var text: String = ""
  /// JPEG data for images, at most 1024 px on the long side.
  var imageData: Data?

  var icon: String { kind == .image ? "photo" : "doc.text" }

  static let allowedTypes: [UTType] = [.pdf, .plainText, .text, .json, .image] + [UTType(filenameExtension: "md")].compactMap { $0 }

  /// Reads a picked file. Returns nil if nothing usable could be read.
  static func load(from url: URL) -> Attachment? {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let name = url.lastPathComponent
    let type = UTType(filenameExtension: url.pathExtension.lowercased())

    if type?.conforms(to: .image) == true {
      guard let image = UIImage(contentsOfFile: url.path), let data = downscaled(image) else { return nil }
      return Attachment(name: name, kind: .image, imageData: data)
    }
    let text: String?
    if type?.conforms(to: .pdf) == true {
      text = PDFDocument(url: url)?.string
    } else {
      text = try? String(contentsOf: url, encoding: .utf8)
    }
    guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return Attachment(name: name, kind: .document, text: String(text.prefix(12000)))
  }

  private static func downscaled(_ image: UIImage) -> Data? {
    let longSide = max(image.size.width, image.size.height)
    let scale = min(1, 1024 / max(longSide, 1))
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    return resized.jpegData(compressionQuality: 0.8)
  }

  /// The text block describing the attached documents, for the user message.
  static func contextBlock(_ items: [Attachment]) -> String? {
    let docs = items.filter { $0.kind == .document }
    let images = items.filter { $0.kind == .image }
    guard !items.isEmpty else { return nil }
    var parts = docs.map { "--- \($0.name) ---\n\($0.text)" }
    if !images.isEmpty {
      parts.append("Attached images: " + images.map(\.name).joined(separator: ", ") + " (shown below).")
    }
    return "ATTACHED FILES (source material from the presenter):\n" + parts.joined(separator: "\n\n")
  }
}
