import Foundation

/// API keys. Read from the launch environment first (Xcode scheme, or `SIMCTL_CHILD_ANTHROPIC_API_KEY`
/// when launching with simctl), then from what the user typed into Settings.
enum Secrets {
  static var anthropicKey: String? { value("ANTHROPIC_API_KEY") }
  static var openAIKey: String? { value("OPENAI_API_KEY") }
  /// Model used for deck writing. Change it in Settings.
  static var openAIModel: String { value("OPENAI_MODEL") ?? "gpt-5" }

  static func value(_ name: String) -> String? {
    if let env = ProcessInfo.processInfo.environment[name], !env.isEmpty { return env }
    if let stored = UserDefaults.standard.string(forKey: name), !stored.isEmpty { return stored }
    return nil
  }

  static func store(_ value: String, for name: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    UserDefaults.standard.set(trimmed.isEmpty ? nil : trimmed, forKey: name)
  }
}
