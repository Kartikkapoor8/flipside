import SwiftUI

/// The presenter's half: the control desk. Dark Ink theme from tokens.json. Two layouts,
/// picked from the split axis the face lives in:
///
/// - wide half (portrait phone, 669 x 475): header, then notes on the left with the live copy,
///   next slide and laser pad on the right, then a row of big buttons.
/// - tall half (landscape phone, 475 x 669): the same pieces stacked top to bottom.
struct PresenterView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.isWideFace) private var isWide

    var body: some View {
        ZStack {
            Brand.Presenter.background.ignoresSafeArea()
            Group {
                if isWide { wideLayout } else { tallLayout }
            }
            .padding(.horizontal, Brand.Space.s4)
            .padding(.top, Brand.Space.s3)
            .padding(.bottom, Brand.Space.s4)
        }
        .task(id: appState.mode) { await runClock() }
    }

    private var wideLayout: some View {
        VStack(spacing: Brand.Space.s3) {
            header
            HStack(alignment: .top, spacing: Brand.Space.s3) {
                notesPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                rightColumn
                    .frame(width: 236)
            }
            .frame(maxHeight: .infinity)
            controls
        }
    }

    private var tallLayout: some View {
        VStack(spacing: Brand.Space.s3) {
            header
            notesPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(alignment: .top, spacing: Brand.Space.s3) {
                liveCopy
                    .frame(width: 150)
                VStack(alignment: .leading, spacing: Brand.Space.s2) {
                    SectionLabel("Live · they see this")
                    nextSlideRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            LaserPadView()
                .frame(height: 150)
            controls
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: Brand.Space.s4) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SLIDE \(appState.currentIndex + 1) OF \(appState.slideCount)")
                    .font(Brand.Font.uiLabel)
                    .tracking(1.2)
                    .foregroundStyle(Brand.Presenter.muted)
                Text(appState.currentSlide.title)
                    .font(Brand.Font.text(17, .semibold))
                    .foregroundStyle(Brand.Presenter.text)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 0) {
                Text(PresenterClock.mmss(appState.elapsed))
                    .font(Brand.Font.text(34, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Brand.Presenter.text)
                Text("\(appState.currentSlide.durationHint)s on this slide")
                    .font(Brand.Font.caption)
                    .foregroundStyle(Brand.Presenter.muted)
            }

            ModePill(mode: appState.mode)
        }
    }

    // MARK: Notes

    private var notesPanel: some View {
        VStack(alignment: .leading, spacing: Brand.Space.s3) {
            SectionLabel("Notes")
            // Not a ScrollView: on iOS 27.1 a vertical ScrollView here laid the text out on
            // one line. Long notes shrink instead; the deck's notes are one to three lines.
            Text(appState.currentSlide.notes.isEmpty ? "No notes for this slide." : appState.currentSlide.notes)
                .font(Brand.Font.text(24))
                .lineSpacing(6)
                .lineLimit(nil)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(appState.currentSlide.notes.isEmpty ? Brand.Presenter.muted : Brand.Presenter.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if !appState.currentSlide.cue.isEmpty {
                Divider().overlay(Brand.Crease.dark)
                SectionLabel("Say to advance")
                Text("\u{201C}\(appState.currentSlide.cue)\u{201D}")
                    .font(Brand.Font.text(20, .medium))
                    .foregroundStyle(Brand.Presenter.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(Brand.Space.s4)
        .background(Brand.Presenter.surface, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
    }

    // MARK: Right column: live copy, next, laser

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: Brand.Space.s2) {
            SectionLabel("Live · they see this")
            liveCopy
            nextSlideRow
            LaserPadView()
                .frame(maxHeight: .infinity)
        }
    }

    /// A small un-rotated copy of what the audience sees. Tap to advance.
    private var liveCopy: some View {
        Button(action: appState.next) {
            ZStack {
                AudienceSlideView(slide: appState.currentSlide)
                LaserDotView(point: appState.laserPoint, radius: 5)
            }
            .aspectRatio(Brand.slideAspect, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous)
                    .strokeBorder(Brand.Crease.dark, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Live slide. Tap to advance.")
    }

    private var nextSlideRow: some View {
        HStack(spacing: Brand.Space.s2) {
            Text(appState.nextSlide == nil ? "END" : "NEXT · \(appState.currentIndex + 2)")
                .font(Brand.Font.uiLabel)
                .tracking(1.2)
                .foregroundStyle(Brand.Presenter.muted)
            Text(appState.nextSlide?.title ?? "Last slide")
                .font(Brand.Font.text(14, .medium))
                .foregroundStyle(Brand.Presenter.text)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: Brand.Space.s3) {
            DeskButton("Back", systemImage: "chevron.left", isEnabled: appState.currentIndex > 0, action: appState.back)
            DeskButton("Next", systemImage: "chevron.right", prominent: true, isEnabled: !appState.isOnLastSlide, action: appState.next)
            DeskButton("Swap sides", systemImage: "arrow.up.arrow.down", action: appState.swapSides)
        }
        .frame(height: 56)
    }

    // MARK: Clock

    /// Ticks the shared timer once a second while presenting. Restarts when the mode changes.
    private func runClock() async {
        guard appState.mode == .present else { return }
        let clock = ContinuousClock()
        var last = clock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            let now = clock.now
            let delta = now - last
            last = now
            appState.elapsed += Double(delta.components.seconds) + Double(delta.components.attoseconds) / 1e18
        }
    }
}

// MARK: - Pieces

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(Brand.Font.uiLabel)
            .tracking(1.2)
            .foregroundStyle(Brand.Presenter.muted)
    }
}

/// Big tap target, 56 pt tall. Prominent fills with the accent and puts Ink text on it, per tokens.
struct DeskButton: View {
    let title: String
    let systemImage: String
    var prominent = false
    var isEnabled = true
    let action: () -> Void

    init(_ title: String, systemImage: String, prominent: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.prominent = prominent
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(Brand.Font.text(17, .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(prominent ? Brand.ink : Brand.Presenter.text)
        .background(
            prominent ? Brand.Presenter.accent : Brand.Presenter.surface,
            in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous)
        )
        .opacity(isEnabled ? 1 : 0.4)
        .disabled(!isEnabled)
    }
}

struct ModePill: View {
    let mode: AppState.Mode
    var body: some View {
        Text(mode.rawValue.uppercased())
            .font(Brand.Font.uiLabel)
            .tracking(1.2)
            .foregroundStyle(mode == .present ? Brand.ink : Brand.Presenter.text)
            .padding(.horizontal, Brand.Space.s3)
            .padding(.vertical, Brand.Space.s2)
            .background(
                mode == .present ? Brand.Presenter.accent : Brand.Presenter.surface,
                in: Capsule()
            )
    }
}

enum PresenterClock {
    static func mmss(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded(.down)))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

#Preview("Presenter half") {
    PresenterView()
        .environment(AppState())
        .frame(width: 669, height: 475)
}
