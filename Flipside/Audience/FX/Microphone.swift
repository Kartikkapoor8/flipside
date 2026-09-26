import AVFoundation
import Observation
import Speech
import os

/// Microphone for the prompt: a smoothed 0...1 level for the voice glow, plus live speech-to-text.
/// Call `start()` from a button tap.
@Observable
@MainActor
final class Microphone {
  enum State: Equatable {
    case idle
    case requesting
    case live
    case denied(String)
  }

  private(set) var state: State = .idle
  /// Live transcript of the current take.
  private(set) var transcript = ""

  /// Input chain, matching the web props: gain, gate, envelope.
  var sensitivity: Double = 1.4
  var threshold: Double = 0.04
  var attack: Double = 0.55
  var release: Double = 0.12

  @ObservationIgnored private let levelBox = OSAllocatedUnfairLock(initialState: 0.0)
  @ObservationIgnored private let engine = AVAudioEngine()
  @ObservationIgnored private var recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
  @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
  @ObservationIgnored private var task: SFSpeechRecognitionTask?

  var isLive: Bool { state == .live }

  /// Read every frame by the glow; never triggers a SwiftUI update.
  nonisolated func level() -> Double {
    levelBox.withLock { $0 }
  }

  func toggle() {
    if isLive { stop() } else { start() }
  }

  func start() {
    #if targetEnvironment(simulator)
    // No mic on the simulator: stay idle so no permission alert appears; the desk shows its stage transcript.
    return
    #endif
    guard !isLive else { return }
    state = .requesting
    transcript = ""
    Task { @MainActor in
      let micOK = await AVAudioApplication.requestRecordPermission()
      guard micOK else {
        state = .denied("Microphone access is off. Turn it on in Settings.")
        return
      }
      let speechOK = await withCheckedContinuation { cont in
        SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
      }
      do {
        try begin(withSpeech: speechOK)
        state = .live
      } catch {
        state = .denied(error.localizedDescription)
      }
    }
  }

  func stop() {
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    request?.endAudio()
    task?.finish()
    request = nil
    task = nil
    levelBox.withLock { $0 = 0 }
    if isLive { state = .idle }
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func begin(withSpeech: Bool) throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
    try session.setActive(true, options: .notifyOthersOnDeactivation)

    if withSpeech, let recognizer, recognizer.isAvailable {
      let request = SFSpeechAudioBufferRecognitionRequest()
      request.shouldReportPartialResults = true
      request.addsPunctuation = true
      self.request = request
      task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
        guard let result else { return }
        let text = result.bestTranscription.formattedString
        Task { @MainActor in self?.transcript = text }
      }
    }

    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    input.removeTap(onBus: 0)
    // The tap runs on the audio thread, so it only touches thread-safe things.
    nonisolated(unsafe) let speech = request
    let box = levelBox
    let chain = MeterChain(sensitivity: sensitivity, threshold: threshold, attack: attack, release: release)
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      speech?.append(buffer)
      Microphone.meter(buffer, chain: chain, into: box)
    }
    engine.prepare()
    try engine.start()
  }

  private struct MeterChain: Sendable {
    let sensitivity: Double
    let threshold: Double
    let attack: Double
    let release: Double
  }

  /// RMS to dBFS, mapped -55...-12 dB onto 0...1, gated, then an attack/release envelope per buffer.
  private nonisolated static func meter(_ buffer: AVAudioPCMBuffer, chain: MeterChain, into levelBox: OSAllocatedUnfairLock<Double>) {
    guard let samples = buffer.floatChannelData?[0] else { return }
    let count = Int(buffer.frameLength)
    guard count > 0 else { return }
    var sum: Float = 0
    for i in 0..<count { sum += samples[i] * samples[i] }
    let rms = sqrt(sum / Float(count))
    let db = 20 * log10(max(rms, 1e-7))
    let raw = min(max((Double(db) + 55) / 43, 0), 1) * chain.sensitivity
    let target = raw < chain.threshold ? 0 : min(raw, 1)
    levelBox.withLock { level in
      let k = target > level ? chain.attack : chain.release
      level += (target - level) * k
    }
  }
}
