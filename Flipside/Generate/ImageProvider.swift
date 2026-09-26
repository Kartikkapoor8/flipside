import UIKit

/// Finds a picture for a slide's `imagePrompt`.
/// With an OpenAI key it generates one; without, it falls back to a stock photo seeded by the prompt
/// so the reveal still has something to resolve into.
actor ImageProvider {
  static let shared = ImageProvider()

  private var cache: [String: UIImage] = [:]
  private var inFlight: [String: Task<UIImage?, Never>] = [:]

  func image(prompt: String, url: String?) async -> UIImage? {
    let key = url ?? prompt
    if let cached = cache[key] { return cached }
    if let task = inFlight[key] { return await task.value }
    let task = Task<UIImage?, Never> { await Self.fetch(prompt: prompt, url: url) }
    inFlight[key] = task
    let result = await task.value
    inFlight[key] = nil
    if let result { cache[key] = result }
    return result
  }

  private static func fetch(prompt: String, url: String?) async -> UIImage? {
    if let url, let parsed = URL(string: url) {
      if parsed.isFileURL { return UIImage(contentsOfFile: parsed.path) }
      if let data = try? await URLSession.shared.data(from: parsed).0 { return UIImage(data: data) }
    }
    if let key = Secrets.openAIKey, let generated = await generate(prompt: prompt, key: key) {
      return generated
    }
    return await stock(prompt: prompt)
  }

  private static func generate(prompt: String, key: String) async -> UIImage? {
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 90
    let body: [String: Any] = [
      "model": "gpt-image-1",
      "prompt": "\(prompt). Editorial presentation photo, no text, no watermark.",
      "size": "1536x1024",
      "quality": "low",
      "n": 1,
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    guard let (data, _) = try? await URLSession.shared.data(for: request),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let first = (json["data"] as? [[String: Any]])?.first,
          let b64 = first["b64_json"] as? String,
          let bytes = Data(base64Encoded: b64) else { return nil }
    return UIImage(data: bytes)
  }

  private static func stock(prompt: String) async -> UIImage? {
    let seed = prompt.lowercased().filter { $0.isLetter || $0.isNumber }.prefix(40)
    guard let url = URL(string: "https://picsum.photos/seed/\(seed.isEmpty ? "flipside" : String(seed))/1200/800"),
          let data = try? await URLSession.shared.data(from: url).0 else { return nil }
    return UIImage(data: data)
  }
}
