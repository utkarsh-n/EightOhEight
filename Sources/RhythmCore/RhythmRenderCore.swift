import Foundation

private struct StoredPattern {
    var first = 16
    var second = 0
    var scale = 4.0
    var secondScale = 4.0
}
private struct StoredSelection { var pattern = 0; var variation = 0 }

/// Single-owner audio-render state. All working storage is allocated at construction.
/// Configure and transport calls must run on that same owner (the render callback
/// in the live app). The live bridge transfers UI changes at buffer boundaries.
public final class RhythmRenderCore: @unchecked Sendable {
    public let sampleRate: Double
    public private(set) var isPlaying = false
    public private(set) var currentStep = -1
    public private(set) var currentPattern = 0
    public private(set) var currentVariation = Variation.a
    public private(set) var completedMeasures = 0
    public private(set) var renderedFrames: UInt64 = 0
    public private(set) var stepEventCount: UInt64 = 0
    public private(set) var lastStepFrame: UInt64 = 0

    private let voices: UnsafeMutablePointer<AnalogVoice>
    private let masks: UnsafeMutablePointer<UInt32>
    private let patterns: UnsafeMutablePointer<StoredPattern>
    private let tracks: UnsafeMutablePointer<StoredSelection>
    private let trackLengths: UnsafeMutablePointer<Int>
    private let triggerCounts: UnsafeMutablePointer<UInt64>
    private let triggerFrames: UnsafeMutablePointer<UInt64>
    private let sineTable: UnsafeMutablePointer<Double>
    private let metalPhases: UnsafeMutablePointer<Double>
    private let metalFrequencies: UnsafeMutablePointer<Double>
    private var desiredPattern = 0
    private var variationMode = VariationMode.a
    private var baseVariation = Variation.a
    private var fillPattern = 12
    private var fillVariation = Variation.a
    private var autoFillInterval = 0
    private var fillRequested = false
    private var introRequested = false
    private var playingFill = false
    private var playingIntro = false
    private var musicalMeasures = 0
    private var selectedTrack = 0
    private var trackMode = false
    private var composeMode = false
    private var composeWritePosition = 0
    private var trackPosition = 0
    private var tempo = 120.0
    private var accentAmount = 0.55
    private var targetVolume = 0.7
    private var volume = 0.0
    private var nextStepCountdown = 0.0
    private var stepOrdinal = -1
    private var interval = 6000.0
    private var previousInput = 0.0
    private var previousOutput = 0.0

    public init(sampleRate: Double = 48000) {
        self.sampleRate = bounded(sampleRate, 8000, 192000, fallback: 48000)
        voices = .allocate(capacity: 12)
        for instrument in Instrument.allCases {
            voices.advanced(by: instrument.rawValue).initialize(to: AnalogVoice(instrument: instrument))
        }
        masks = .allocate(capacity: 32 * 12); masks.initialize(repeating: 0, count: 32 * 12)
        patterns = .allocate(capacity: 32); patterns.initialize(repeating: StoredPattern(), count: 32)
        tracks = .allocate(capacity: 12 * 64); tracks.initialize(repeating: StoredSelection(), count: 12 * 64)
        trackLengths = .allocate(capacity: 12); trackLengths.initialize(repeating: 0, count: 12)
        triggerCounts = .allocate(capacity: 12); triggerCounts.initialize(repeating: 0, count: 12)
        triggerFrames = .allocate(capacity: 12); triggerFrames.initialize(repeating: 0, count: 12)
        sineTable = .allocate(capacity: 4097)
        for i in 0...4096 { sineTable.advanced(by: i).initialize(to: sin(Double(i) * 2 * .pi / 4096)) }
        metalPhases = .allocate(capacity: 6); metalPhases.initialize(repeating: 0, count: 6)
        metalFrequencies = .allocate(capacity: 6)
        for (i, frequency) in [205.3, 304.4, 369.6, 522.7, 540.0, 800.0].enumerated() {
            metalFrequencies.advanced(by: i).initialize(to: frequency)
        }
        configure(MachineState())
    }

    deinit {
        voices.deinitialize(count: 12); voices.deallocate()
        masks.deinitialize(count: 32 * 12); masks.deallocate()
        patterns.deinitialize(count: 32); patterns.deallocate()
        tracks.deinitialize(count: 12 * 64); tracks.deallocate()
        trackLengths.deinitialize(count: 12); trackLengths.deallocate()
        triggerCounts.deinitialize(count: 12); triggerCounts.deallocate()
        triggerFrames.deinitialize(count: 12); triggerFrames.deallocate()
        sineTable.deinitialize(count: 4097); sineTable.deallocate()
        metalPhases.deinitialize(count: 6); metalPhases.deallocate()
        metalFrequencies.deinitialize(count: 6); metalFrequencies.deallocate()
    }

    /// Copies into fixed working storage without retaining any UI arrays.
    public func configure(_ state: MachineState) {
        let oldInterval = interval
        let oldTrack = selectedTrack
        let oldTrackMode = trackMode
        let wasComposing = composeMode
        tempo = state.settings.effectiveTempo
        targetVolume = unit(state.settings.masterVolume)
        accentAmount = unit(state.settings.accentAmount)
        desiredPattern = min(15, max(0, state.selectedPattern))
        variationMode = state.variationMode
        fillPattern = min(15, max(12, state.fillPattern))
        fillVariation = state.fillVariation
        switch state.autoFillInterval {
        case 2, 4, 8, 12, 16: autoFillInterval = state.autoFillInterval
        default: autoFillInterval = 0
        }
        selectedTrack = min(11, max(0, state.selectedTrack))
        trackMode = state.trackMode
        composeMode = state.composeMode
        for channel in 0..<12 {
            let p = state.settings.voices.indices.contains(channel) ? state.settings.voices[channel] : VoiceParameters()
            voices[channel].prepare(p, sampleRate: sampleRate)
        }
        for slot in 0..<16 {
            for v in 0..<2 {
                let offset = slot * 2 + v
                if state.patterns.indices.contains(slot) {
                    let p = v == 0 ? state.patterns[slot].a : state.patterns[slot].b
                    patterns[offset] = StoredPattern(first: min(16, max(1, p.firstPartLength)),
                                                     second: min(16, max(0, p.secondPartLength)),
                                                     scale: p.prescale.stepsPerQuarter,
                                                     secondScale: (p.secondPartPrescale ?? p.prescale).stepsPerQuarter)
                    for lane in 0..<12 {
                        masks[offset * 12 + lane] = p.laneMasks.indices.contains(lane) ? p.laneMasks[lane] : 0
                    }
                } else {
                    patterns[offset] = StoredPattern()
                    for lane in 0..<12 { masks[offset * 12 + lane] = 0 }
                }
            }
        }
        for track in 0..<12 {
            if composeMode && wasComposing && isPlaying && track == selectedTrack && oldTrack == selectedTrack { continue }
            let length = state.tracks.indices.contains(track) ? min(64, state.tracks[track].count) : 0
            trackLengths[track] = length
            for measure in 0..<length {
                let selection = state.tracks[track][measure]
                tracks[track * 64 + measure] = StoredSelection(pattern: min(15, max(0, selection.pattern)),
                                                               variation: selection.variation == .a ? 0 : 1)
            }
        }
        if oldTrack != selectedTrack || oldTrackMode != trackMode { trackPosition = 0 }
        if composeMode && (!wasComposing || oldTrack != selectedTrack) {
            composeWritePosition = 0
        }
        if !isPlaying {
            currentPattern = desiredPattern
            currentVariation = variationMode == .b ? .b : .a
        }
        updateInterval()
        if isPlaying && oldInterval > 0 { nextStepCountdown *= interval / oldInterval }
    }

    public func setPlaying(_ playing: Bool) {
        guard isPlaying != playing else { return }
        isPlaying = playing
        if playing {
            stepOrdinal = -1; currentStep = -1; nextStepCountdown = 0
            completedMeasures = 0; trackPosition = 0
            musicalMeasures = 0; composeWritePosition = 0
            baseVariation = variationMode == .b ? .b : .a
            playingFill = introRequested && !trackMode
            playingIntro = playingFill
            if playingFill { currentPattern = fillPattern; currentVariation = fillVariation }
            else { selectBasePattern(initial: true) }
            introRequested = false; fillRequested = false
            updateInterval()
        } else {
            currentStep = -1; stepOrdinal = -1
            fillRequested = false; playingFill = false
            playingIntro = false
        }
    }

    public func requestFill() {
        guard !trackMode else { return }
        if isPlaying { fillRequested = true } else { introRequested.toggle() }
    }
    public func requestIntro() { if !trackMode { introRequested.toggle() } }
    public func clearTrack() { trackLengths[selectedTrack] = 0; composeWritePosition = 0; trackPosition = 0 }

    public func trigger(_ instrument: Instrument, accented: Bool = false) {
        guard instrument != .accent else { return }
        if instrument == .closedHat { voices[Instrument.openHat.rawValue].choke(sampleRate: sampleRate) }
        let velocity = accented ? 0.76 + accentAmount * 0.36 : 0.76
        voices[instrument.rawValue].trigger(velocity: velocity, accented: accented, sampleRate: sampleRate)
        triggerCounts[instrument.rawValue] &+= 1
        triggerFrames[instrument.rawValue] = renderedFrames
    }

    public func triggerCount(_ instrument: Instrument) -> UInt64 { triggerCounts[instrument.rawValue] }
    public func lastTriggerFrame(_ instrument: Instrument) -> UInt64 { triggerFrames[instrument.rawValue] }
    public func voiceIsActive(_ instrument: Instrument) -> Bool { voices[instrument.rawValue].active }

    /// Copy into the bridge's preallocated telemetry storage; allocation happens on main.
    public func copyRecordedTrack(into buffer: UnsafeMutableBufferPointer<PatternSelection>) -> Int {
        let length = min(buffer.count, trackLengths[selectedTrack])
        for index in 0..<length {
            let item = tracks[selectedTrack * 64 + index]
            buffer[index] = PatternSelection(pattern: item.pattern, variation: item.variation == 0 ? .a : .b)
        }
        return length
    }

    @inline(__always) private func updateInterval() {
        let p = patterns[currentPattern * 2 + (currentVariation == .a ? 0 : 1)]
        interval = sampleRate * 60 / (tempo * (currentStep >= 16 ? p.secondScale : p.scale))
    }

    private func selectBasePattern(initial: Bool = false) {
        let length = trackLengths[selectedTrack]
        if trackMode && length > 0 {
            if trackPosition >= length { trackPosition = 0 }
            let selection = tracks[selectedTrack * 64 + trackPosition]
            currentPattern = selection.pattern
        } else {
            currentPattern = desiredPattern
        }
        if currentPattern >= 12 {
            currentVariation = fillVariation
            return
        }
        switch variationMode {
        case .a: baseVariation = .a
        case .b: baseVariation = .b
        case .alternate: baseVariation = initial ? .a : (baseVariation == .a ? .b : .a)
        }
        currentVariation = baseVariation
    }

    private func advanceStep() {
        var patternOffset = currentPattern * 2 + (currentVariation == .a ? 0 : 1)
        var pattern = patterns[patternOffset]
        stepOrdinal += 1
        if stepOrdinal >= pattern.first + pattern.second {
            completedMeasures += 1
            let wasIntro = playingIntro
            if !playingIntro { musicalMeasures += 1 }
            playingIntro = false
            if trackMode && trackLengths[selectedTrack] > 0 {
                trackPosition = (trackPosition + 1) % trackLengths[selectedTrack]
            }
            let automatic = !trackMode && autoFillInterval > 0 && musicalMeasures > 0 && (musicalMeasures + 1) % autoFillInterval == 0
            if !playingFill && (fillRequested || automatic) {
                playingFill = true; fillRequested = false
                currentPattern = fillPattern; currentVariation = fillVariation
            } else {
                playingFill = false
                selectBasePattern(initial: wasIntro)
            }
            patternOffset = currentPattern * 2 + (currentVariation == .a ? 0 : 1)
            pattern = patterns[patternOffset]
            stepOrdinal = 0
            updateInterval()
        }
        currentStep = stepOrdinal < pattern.first ? stepOrdinal : 16 + stepOrdinal - pattern.first
        updateInterval()
        if stepOrdinal == 0 && composeMode && composeWritePosition < 64 {
            tracks[selectedTrack * 64 + composeWritePosition] = StoredSelection(pattern: currentPattern, variation: currentVariation == .a ? 0 : 1)
            composeWritePosition += 1
            trackLengths[selectedTrack] = max(trackLengths[selectedTrack], composeWritePosition)
        }
        let bit = UInt32(1) << UInt32(currentStep)
        let accented = masks[patternOffset * 12] & bit != 0
        // Open hat goes first, allowing a simultaneous closed-hat trigger to choke it.
        for channel in 1..<12 {
            if masks[patternOffset * 12 + channel] & bit != 0,
               let instrument = Instrument(rawValue: channel) { trigger(instrument, accented: accented) }
        }
        stepEventCount &+= 1
        lastStepFrame = renderedFrames
    }

    /// Call once per audio sample; the sequencer clock is inside this render path.
    @inline(__always) public func nextSample() -> Float {
        if isPlaying {
            if nextStepCountdown <= 0 { advanceStep(); nextStepCountdown += interval }
            nextStepCountdown -= 1
        }
        var metal = 0.0
        for oscillator in 0..<6 {
            let frequency = metalFrequencies[oscillator]
            metal += square(metalPhases[oscillator], frequency: frequency, sampleRate: sampleRate)
            advance(&metalPhases[oscillator], frequency: frequency, sampleRate: sampleRate)
        }
        metal *= 0.37
        var mixed = 0.0
        for channel in 1..<12 { mixed += voices[channel].nextSample(sampleRate: sampleRate, metal: metal, table: UnsafePointer(sineTable)) }
        // Block DC below the useful bass range, then softly limit summed voices.
        let dcBlocked = mixed - previousInput + 0.9995 * previousOutput
        previousInput = mixed; previousOutput = dcBlocked
        volume += (targetVolume - volume) * 0.002
        renderedFrames &+= 1
        return Float(tanh(dcBlocked * 0.84) * volume)
    }

    public func render(into buffer: UnsafeMutableBufferPointer<Float>) {
        for index in buffer.indices { buffer[index] = nextSample() }
    }
    /// Convenience allocation for offline work only.
    public func render(frameCount: Int) -> [Float] {
        var buffer = Array(repeating: Float(0), count: max(0, frameCount))
        buffer.withUnsafeMutableBufferPointer { render(into: $0) }
        return buffer
    }
}
