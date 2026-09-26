import SwiftUI

/// Flipside palette, light mode. Swap these for `~/flipside-assets/brand/tokens.json` values when the assets folder is on this machine.
enum Theme {
  // App chrome
  static let background = Color(hex: 0xF4F3EF)
  static let surface = Color.white
  static let sunken = Color(hex: 0xECEBE6)
  static let line = Color.black.opacity(0.08)
  static let text = Color(hex: 0x16161A)
  static let textSecondary = Color(hex: 0x16161A).opacity(0.55)
  static let selection = Color(hex: 0x1F7AFF)

  // Brand
  static let ink = Color(hex: 0x16161A)
  static let paper = Color(hex: 0xF7F4EC)
  static let coral = Color(hex: 0xF0532C)
  static let violet = Color(hex: 0x6A4DFF)
  static let mint = Color(hex: 0x1FB985)
  static let sky = Color(hex: 0x2E9BFF)

  /// Motion rule from MOTION.md: nothing over 600 ms.
  static let land = Animation.spring(duration: 0.5, bounce: 0.18)
  static let fade = Animation.easeOut(duration: 0.38)
}
