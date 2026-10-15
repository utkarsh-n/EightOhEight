import AVFoundation
import Combine
import Foundation
import RhythmCore

private struct RenderTelemetry {
    var playing = false
    var step = -1
    var pattern = 0
    var variation = Variation.a
    var recordedCount = 0
}

/// UI writes can wait; the audio thread only tries this lock and skips a transfer
/// if the UI owns it. Snapshot retirement and array allocations stay on main.
private final class AudioRenderMailbox: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot = MachineState()
    private var snapshotChanged = true
    private var playbackCommand = -1
    private var triggers: UInt16 = 0
    private var fills = 0
    private var clearTrackRequested = false
    private var telemetry = RenderTelemetry()
    private let recorded: UnsafeMutablePointer<PatternSelection>

    init() {
        recorded = .allocate(capacity: 64)
        recorded.initialize(repeating: PatternSelection(pattern: 0), count: 64)
    }
    deinit { recorded.deinitialize(count: 64); recorded.deallocate() }

    func submit(_ state: MachineState) {
        lock.lock(); defer { lock.unlock() }
        snapshot = state; snapshotChanged = true
    }
    func play(_ value: Bool) {
        lock.lock(); defer { lock.unlock() }
        playbackCommand = value ? 1 : 0
    }
    func trigger(_ instrument: Instrument) {
        lock.lock(); defer { lock.unlock() }
        triggers |= UInt16(1) << UInt16(instrument.rawValue)
    }
    func fill() { lock.lock(); fills += 1; lock.unlock() }
    func clearTrack() { lock.lock(); clearTrackRequested = true; lock.unlock() }

    func apply(to core: RhythmRenderCore) {
        guard lock.try() else { return }
        defer { lock.unlock() }
        if snapshotChanged { core.configure(snapshot); snapshotChanged = false }
        if clearTrackRequested { core.clearTrack(); clearTrackRequested = false }
        // A stop and an intro tap may arrive during one render buffer.
        if playbackCommand == 0 { core.setPlaying(false) }
        // Arm a stopped intro before applying a start command from the same UI turn.
        if fills > 0 {
            for _ in 0..<fills { core.requestFill() }
            fills = 0
        }
        if playbackCommand == 1 { core.setPlaying(true) }
        playbackCommand = -1
        if triggers != 0 {
            for channel in 1..<12 where triggers & (UInt16(1) << UInt16(channel)) != 0 {
                if let instrument = Instrument(rawValue: channel) { core.trigger(instrument) }
            }
            triggers = 0
        }
    }

    func publish(from core: RhythmRenderCore) {
        guard lock.try() else { return }
        defer { lock.unlock() }
        telemetry.playing = core.isPlaying; telemetry.step = core.currentStep
        telemetry.pattern = core.currentPattern; telemetry.variation = core.currentVariation
        if snapshot.composeMode {
            telemetry.recordedCount = core.copyRecordedTrack(into: UnsafeMutableBufferPointer(start: recorded, count: 64))
        }
    }

    func read() -> (RenderTelemetry, [PatternSelection]) {
        lock.lock(); defer { lock.unlock() }
        let track = snapshot.composeMode ? Array(UnsafeBufferPointer(start: recorded, count: telemetry.recordedCount)) : []
        return (telemetry, track)
    }
}

@MainActor
final class RhythmAudioEngine: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentStep = -1
    @Published private(set) var currentPattern = 0
    @Published private(set) var currentVariation = Variation.a
    @Published private(set) var recordedTrack: [PatternSelection] = []
    @Published private(set) var errorMessage: String?

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var renderCore: RhythmRenderCore?
    private let mailbox = AudioRenderMailbox()
    private var state = MachineState()
    private var pollTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var wantedPlaying = false
    private var interruptedPlaying = false

    init() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 45, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshTelemetry() }
        }
        #if os(iOS)
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                            object: nil, queue: .main) { [weak self] notification in
            let type = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
            let options = (notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? NSNumber)?.uintValue ?? 0
            Task { @MainActor in self?.handleInterruption(type: type, options: options) }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification,
                            object: nil, queue: .main) { [weak self] notification in
            let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
            Task { @MainActor in self?.handleRouteChange(reason: reason) }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.rebuildAfterSystemChange() }
        })
        #endif
    }

    deinit {
        pollTimer?.invalidate()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        audioEngine?.stop()
    }

    func update(_ state: MachineState) {
        self.state = state
        mailbox.submit(state)
        if audioEngine == nil {
            currentPattern = state.selectedPattern
            currentVariation = state.variationMode == .b ? .b : .a
        }
    }

    func start() throws {
        do {
            try prepareAudio()
            mailbox.play(true)
            wantedPlaying = true
            isPlaying = true
            errorMessage = nil
        } catch {
            errorMessage = "Audio could not start: \(error.localizedDescription)"
            throw error
        }
    }

    func stop() {
        wantedPlaying = false
        interruptedPlaying = false
        mailbox.play(false)
        isPlaying = false
        currentStep = -1
    }

    func togglePlayback() {
        if wantedPlaying { stop() }
        else { do { try start() } catch { /* start publishes the failure. */ } }
    }

    /// Auditioning runs the sound generator while the sequence remains stopped.
    func trigger(_ instrument: Instrument) {
        guard instrument != .accent else { return }
        do {
            try prepareAudio()
            mailbox.trigger(instrument)
            errorMessage = nil
        } catch { errorMessage = "The instrument could not play: \(error.localizedDescription)" }
    }

    /// While stopped, TAP toggles an intro for the next start; while playing it queues a fill.
    func requestFill() { mailbox.fill() }
    func clearTrack() { mailbox.clearTrack() }

    func exportWAV(state: MachineState, bars: Int = 4) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("EightOhEight-\(UUID().uuidString.prefix(8)).wav")
        try WaveExporter.writeWAV(state: state, bars: bars, to: url)
        return url
    }

    private func prepareAudio() throws {
        if let audioEngine, audioEngine.isRunning { return }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setPreferredSampleRate(48000)
        try session.setPreferredIOBufferDuration(128.0 / 48000)
        try session.setActive(true)
        #endif
        if let audioEngine {
            try audioEngine.start()
            return
        }
        let engine = AVAudioEngine()
        let outputRate = engine.outputNode.inputFormat(forBus: 0).sampleRate
        let rate = outputRate > 0 ? outputRate : 48000
        let core = RhythmRenderCore(sampleRate: rate)
        let mailbox = self.mailbox
        mailbox.submit(state)
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate,
                                        channels: 1, interleaved: false) else {
            throw NSError(domain: "EightOhEight.Audio", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "The output audio format is unavailable."])
        }
        let source = AVAudioSourceNode(format: format) { isSilence, _, frameCount, audioBufferList in
            mailbox.apply(to: core)
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = core.nextSample()
                for buffer in buffers {
                    guard let data = buffer.mData else { continue }
                    let pointer = data.assumingMemoryBound(to: Float.self)
                    // Source format is mono, non-interleaved; mirror if a host supplies more buffers.
                    pointer[frame] = sample
                }
            }
            isSilence.pointee = false
            mailbox.publish(from: core)
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()
        renderCore = core; sourceNode = source; audioEngine = engine
    }

    private func refreshTelemetry() {
        guard audioEngine?.isRunning == true else { return }
        let (telemetry, track) = mailbox.read()
        if currentStep != telemetry.step { currentStep = telemetry.step }
        if currentPattern != telemetry.pattern { currentPattern = telemetry.pattern }
        if currentVariation != telemetry.variation { currentVariation = telemetry.variation }
        let playing = wantedPlaying && telemetry.playing
        if isPlaying != playing { isPlaying = playing }
        if state.composeMode && recordedTrack != track { recordedTrack = track }
    }

    private func rebuildAfterSystemChange() {
        let resume = wantedPlaying
        audioEngine?.stop()
        audioEngine = nil; sourceNode = nil; renderCore = nil
        do {
            try prepareAudio()
            mailbox.play(resume)
            isPlaying = resume
            errorMessage = nil
        } catch {
            isPlaying = false
            errorMessage = "Audio output changed and could not restart: \(error.localizedDescription)"
        }
    }

    #if os(iOS)
    private func handleInterruption(type: UInt?, options: UInt) {
        if type == AVAudioSession.InterruptionType.began.rawValue {
            interruptedPlaying = wantedPlaying
            audioEngine?.pause()
            isPlaying = false
            currentStep = -1
        } else if type == AVAudioSession.InterruptionType.ended.rawValue {
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
            if shouldResume && interruptedPlaying && wantedPlaying { rebuildAfterSystemChange() }
            else { stop() }
            interruptedPlaying = false
        }
    }

    private func handleRouteChange(reason: UInt?) {
        guard audioEngine != nil,
              reason != AVAudioSession.RouteChangeReason.categoryChange.rawValue else { return }
        if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
            // Unplugging headphones should not unexpectedly send the beat to the speaker.
            stop()
        }
        rebuildAfterSystemChange()
    }
    #endif
}
