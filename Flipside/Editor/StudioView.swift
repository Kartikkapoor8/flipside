import SwiftUI

/// Both poses. One half is the presenter desk, the other is the audience's full-screen slide.
/// Flat (`presenting == false`): the slide is editable in place. Standing: it's drawn rotated 180° for the far side.
/// The split follows the fold (or the pinned layout), and Swap sides trades the halves.
struct StudioView: View {
  @Bindable var model: StudioModel
  var presenting = false

  var body: some View {
    GeometryReader { proxy in
      // Where the physical fold is, when the device reports one.
      let fold = proxy.reservedRegions(kind: .division, options: .includeInactive).first?.frame
      let sideBySide = resolvedSideBySide(size: proxy.size, fold: fold)
      // Kartik's AppState flag: audience in the leading (side by side) or top (stacked) slot.
      let audienceFirst = model.app.audienceOnLeading
      Group {
        if sideBySide {
          let split = fold.map { $0.midX } ?? proxy.size.width / 2
          HStack(spacing: 0) {
            if audienceFirst {
              audience.frame(width: split).ignoresSafeArea(.container, edges: [.top, .bottom, .leading])
              divider(vertical: true)
              desk
            } else {
              desk.frame(width: split)
              divider(vertical: true)
              audience.ignoresSafeArea(.container, edges: [.top, .bottom, .trailing])
            }
          }
        } else {
          let split = fold.map { $0.midY } ?? proxy.size.height / 2
          VStack(spacing: 0) {
            if !audienceFirst {
              desk.frame(height: split)
              divider(vertical: false)
              audience.ignoresSafeArea(.container, edges: [.bottom, .leading, .trailing])
            } else {
              audience.frame(height: split).ignoresSafeArea(.container, edges: [.top, .leading, .trailing])
              divider(vertical: false)
              desk
            }
          }
        }
      }
      .animation(.snappy(duration: 0.35), value: sideBySide)
    }
    .background(Theme.background)
  }

  private var desk: some View {
    PresenterDesk(model: model, editing: !presenting)
  }

  @ViewBuilder
  private var audience: some View {
    if presenting {
      StudioAudienceFace(model: model)
    } else {
      ArtifactPane(model: model)
    }
  }

  private func divider(vertical: Bool) -> some View {
    Rectangle().fill(Theme.line).frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
  }

  /// Auto follows the fold: a fold running top to bottom splits left/right, one running across splits top/bottom.
  /// With no fold reported, the longer side of the screen decides.
  private func resolvedSideBySide(size: CGSize, fold: CGRect?) -> Bool {
    switch model.layout {
    case .horizontal: return true
    case .vertical: return false
    case .auto:
      if let fold, fold.width > 0 || fold.height > 0 { return fold.height > fold.width }
      return size.width > size.height
    }
  }
}

// MARK: - Audience face (standing)

/// What the other person sees while presenting: the slide full screen, rotated 180° so it reads right
/// from across the table, with the laser dot. Slide changes crossfade.
struct StudioAudienceFace: View {
  let model: StudioModel

  var body: some View {
    ZStack {
      Color.white
      if let slide = model.current {
        FittedSlide { _ in
          SlideSurface(slide: slide, animated: true, laser: model.app.laserPoint)
        }
        .id(slide.id)
        .transition(.opacity)
      }
    }
    .rotationEffect(.degrees(180))
    .onGeometryChange(for: CGSize.self, of: \.size) { size in
      if size.height > 0 { model.artifactAspect = size.width / size.height }
    }
  }
}

// MARK: - Artifact pane

/// The artifact fills its half edge to edge. Controls float over it and stay out of the way.
struct ArtifactPane: View {
  @Bindable var model: StudioModel

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Color.white
        if let slide = model.current {
          SlideCanvasEditor(model: model, slide: slide)
            .id(slide.id)
            .transition(.opacity)
            .gesture(swipeBetweenSlides)
        } else {
          EmptyArtifact(model: model)
        }
      }
      .overlay(alignment: .top) { topBar.padding(12) }
      .overlay(alignment: .bottom) { PageControl(model: model).padding(12) }
      .borderBeam(.md, colorVariant: .colorful, strength: 0.9, active: model.app.isGenerating, cornerRadius: 2)
      .onChange(of: proxy.size, initial: true) { _, size in
        if size.height > 0 { model.artifactAspect = size.width / size.height }
      }
    }
    .clipped()
  }

  @ViewBuilder
  private var topBar: some View {
    if let selection = model.selection {
      SelectionToolbar(model: model, elementID: selection)
        .transition(.move(edge: .top).combined(with: .opacity))
    } else if model.app.isGenerating {
      HStack(spacing: 8) {
        ThinkingOrb(state: model.orbState ?? .working, size: 20)
        Text(model.status)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(Theme.text)
          .lineLimit(1)
      }
      .padding(.leading, 8).padding(.trailing, 12).padding(.vertical, 6)
      .background(Capsule().fill(.regularMaterial))
      .overlay(Capsule().strokeBorder(Theme.line))
      .transition(.opacity)
    }
  }

  private var swipeBetweenSlides: some Gesture {
    DragGesture(minimumDistance: 40)
      .onEnded { value in
        guard model.selection == nil, model.editing == nil,
              abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
        model.select(slide: model.app.currentIndex + (value.translation.width < 0 ? 1 : -1))
      }
  }
}

private struct EmptyArtifact: View {
  let model: StudioModel

  var body: some View {
    VStack(spacing: 14) {
      ThinkingOrb(state: model.app.isGenerating ? .searching : .breathing, size: 64)
      Text(model.app.isGenerating ? "Your first slide is on its way" : "Describe what you're presenting")
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(Theme.text)
      Text("It builds here, full screen, slide by slide.")
        .font(.system(size: 13))
        .foregroundStyle(Theme.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// Floating "‹ 2 / 6 ›" over the bottom of the artifact.
private struct PageControl: View {
  let model: StudioModel

  var body: some View {
    let count = model.app.deck.slides.count
    if count > 0 {
      HStack(spacing: 2) {
        button("chevron.left", enabled: model.app.currentIndex > 0) {
          model.select(slide: model.app.currentIndex - 1)
        }
        Text("\(model.app.currentIndex + 1) / \(count)")
          .font(.system(size: 12, weight: .semibold).monospacedDigit())
          .foregroundStyle(Theme.text)
          .contentTransition(.numericText())
          .frame(minWidth: 44)
        button("chevron.right", enabled: model.app.currentIndex < count - 1) {
          model.select(slide: model.app.currentIndex + 1)
        }
      }
      .padding(3)
      .background(Capsule().fill(.regularMaterial))
      .overlay(Capsule().strokeBorder(Theme.line))
      .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
      .animation(.snappy, value: model.app.currentIndex)
    }
  }

  private func button(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
    Button {
      withAnimation(Theme.fade) { action() }
    } label: {
      Image(systemName: icon)
        .font(.system(size: 12, weight: .bold))
        .frame(width: 32, height: 28)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(enabled ? Theme.text : Theme.textSecondary.opacity(0.4))
    .disabled(!enabled)
  }
}

private struct SelectionToolbar: View {
  let model: StudioModel
  let elementID: String

  var body: some View {
    HStack(spacing: 2) {
      if elementID != "image" {
        tool("Edit text", "character.cursor.ibeam") { model.beginEditing(elementID) }
      }
      tool("Smaller", "minus") { model.nudgeScale(elementID, by: 0.9) }
      tool("Bigger", "plus") { model.nudgeScale(elementID, by: 1.1) }
      tool("Reset position", "arrow.counterclockwise") { model.resetElement(elementID) }
      tool("Delete", "trash") { model.removeElement(elementID) }
      Rectangle().fill(Theme.line).frame(width: 1, height: 18).padding(.horizontal, 2)
      tool("Done", "checkmark") {
        model.editing = nil
        model.selection = nil
      }
    }
    .padding(4)
    .background(Capsule().fill(.regularMaterial))
    .overlay(Capsule().strokeBorder(Theme.line))
    .shadow(color: .black.opacity(0.1), radius: 10, y: 3)
  }

  private func tool(_ label: String, _ icon: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .frame(width: 40, height: 32)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(label == "Delete" ? Theme.coral : Theme.text)
    .accessibilityLabel(label)
  }
}
