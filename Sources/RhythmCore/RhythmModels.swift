import Foundation

/// The eleven physical sound channels and the common accent trigger.
public enum Instrument: Int, CaseIterable, Codable, Identifiable, Sendable {
    case accent, bassDrum, snareDrum, lowTom, midTom, highTom
    case rimShot, handClap, cowbell, cymbal, openHat, closedHat

    public var id: Int { rawValue }
    public var abbreviation: String {
        ["AC", "BD", "SD", "LT", "MT", "HT", "RS", "CP", "CB", "CY", "OH", "CH"][rawValue]
    }
    public var title: String {
        ["Accent", "Bass Drum", "Snare Drum", "Low Tom", "Mid Tom", "High Tom", "Rim Shot", "Hand Clap", "Cowbell", "Cymbal", "Open Hi-Hat", "Closed Hi-Hat"][rawValue]
    }
    public var alternateTitle: String? {
        switch self {
        case .lowTom: return "Low Conga"
        case .midTom: return "Mid Conga"
        case .highTom: return "High Conga"
        case .rimShot: return "Claves"
        case .handClap: return "Maracas"
        default: return nil
        }
    }
    public var alternateAbbreviation: String? {
        switch self {
        case .lowTom: return "LC"
        case .midTom: return "MC"
        case .highTom: return "HC"
        case .rimShot: return "CL"
        case .handClap: return "MA"
        default: return nil
        }
    }
}

public enum Prescale: Int, CaseIterable, Codable, Identifiable, Sendable {
    case eighthTriplet = 1, sixteenthTriplet = 2, sixteenth = 3, thirtySecond = 4
    public var id: Int { rawValue }
    public var stepsPerQuarter: Double {
        switch self {
        case .eighthTriplet: return 3
        case .sixteenthTriplet: return 6
        case .sixteenth: return 4
        case .thirtySecond: return 8
        }
    }
    public var label: String {
        switch self {
        case .eighthTriplet: return "⅛ triplet"
        case .sixteenthTriplet: return "¹⁄₁₆ triplet"
        case .sixteenth: return "¹⁄₁₆"
        case .thirtySecond: return "¹⁄₃₂"
        }
    }
}

public enum Variation: String, CaseIterable, Codable, Identifiable, Sendable {
    case a, b
    public var id: String { rawValue }
    public var label: String { rawValue.uppercased() }
}

public enum VariationMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case a, b, alternate
    public var id: String { rawValue }
    public var label: String { self == .alternate ? "AB" : rawValue.uppercased() }
}

public struct VoiceParameters: Codable, Equatable, Sendable {
    public var level: Double
    public var tone: Double
    public var decay: Double
    public var tuning: Double
    public var snappy: Double
    public var alternative: Bool

    public init(level: Double = 0.72, tone: Double = 0.5, decay: Double = 0.5,
                tuning: Double = 0.5, snappy: Double = 0.65, alternative: Bool = false) {
        self.level = level; self.tone = tone; self.decay = decay
        self.tuning = tuning; self.snappy = snappy; self.alternative = alternative
    }
    public var normalized: VoiceParameters {
        VoiceParameters(level: unit(level), tone: unit(tone), decay: unit(decay),
                        tuning: unit(tuning), snappy: unit(snappy), alternative: alternative)
    }
}

public struct MachineSettings: Codable, Equatable, Sendable {
    public var tempo: Double
    public var fineTempo: Double
    public var masterVolume: Double
    public var accentAmount: Double
    public var voices: [VoiceParameters]

    public init(tempo: Double = 120, fineTempo: Double = 0, masterVolume: Double = 0.7,
                accentAmount: Double = 0.55,
                voices: [VoiceParameters] = Array(repeating: VoiceParameters(), count: 12)) {
        self.tempo = tempo; self.fineTempo = fineTempo; self.masterVolume = masterVolume
        self.accentAmount = accentAmount; self.voices = voices
    }
    public var effectiveTempo: Double { bounded(tempo + fineTempo, 40, 300, fallback: 120) }
    public subscript(_ instrument: Instrument) -> VoiceParameters {
        get { voices.indices.contains(instrument.rawValue) ? voices[instrument.rawValue] : VoiceParameters() }
        set {
            while voices.count < 12 { voices.append(VoiceParameters()) }
            voices[instrument.rawValue] = newValue
        }
    }
}

/// The second physical row begins at bit 16 even if the first part is shorter.
public struct RhythmPattern: Codable, Equatable, Sendable {
    public var firstPartLength: Int
    public var secondPartLength: Int
    public var prescale: Prescale
    public var secondPartPrescale: Prescale?
    public var laneMasks: [UInt32]

    public init(firstPartLength: Int = 16, secondPartLength: Int = 0,
                prescale: Prescale = .sixteenth, secondPartPrescale: Prescale? = nil,
                laneMasks: [UInt32] = Array(repeating: 0, count: 12)) {
        self.firstPartLength = firstPartLength; self.secondPartLength = secondPartLength
        self.prescale = prescale; self.secondPartPrescale = secondPartPrescale; self.laneMasks = laneMasks
    }
    public var totalSteps: Int { min(16, max(1, firstPartLength)) + min(16, max(0, secondPartLength)) }
    public func hit(_ instrument: Instrument, step: Int) -> Bool {
        guard (0..<32).contains(step), laneMasks.indices.contains(instrument.rawValue) else { return false }
        return laneMasks[instrument.rawValue] & (UInt32(1) << UInt32(step)) != 0
    }
    public mutating func toggle(_ instrument: Instrument, step: Int) {
        setHit(instrument, step: step, enabled: !hit(instrument, step: step))
    }
    public mutating func setHit(_ instrument: Instrument, step: Int, enabled: Bool) {
        guard (0..<32).contains(step) else { return }
        while laneMasks.count < 12 { laneMasks.append(0) }
        let bit = UInt32(1) << UInt32(step)
        if enabled { laneMasks[instrument.rawValue] |= bit }
        else { laneMasks[instrument.rawValue] &= ~bit }
    }
    public mutating func clear(instrument: Instrument? = nil) {
        while laneMasks.count < 12 { laneMasks.append(0) }
        if let instrument { laneMasks[instrument.rawValue] = 0 }
        else { for index in 0..<12 { laneMasks[index] = 0 } }
    }
}

public struct PatternSlot: Codable, Equatable, Sendable {
    public var a: RhythmPattern
    public var b: RhythmPattern
    public init(a: RhythmPattern = RhythmPattern(), b: RhythmPattern = RhythmPattern()) {
        self.a = a; self.b = b
    }
}

public struct PatternSelection: Codable, Equatable, Sendable {
    public var pattern: Int
    public var variation: Variation
    public init(pattern: Int, variation: Variation = .a) { self.pattern = pattern; self.variation = variation }
}

public struct MachineState: Codable, Equatable, Sendable {
    public var settings: MachineSettings
    public var patterns: [PatternSlot]
    public var selectedPattern: Int
    public var variationMode: VariationMode
    public var fillPattern: Int
    public var fillVariation: Variation
    public var autoFillInterval: Int
    public var tracks: [[PatternSelection]]
    public var selectedTrack: Int
    public var trackMode: Bool
    public var composeMode: Bool

    public init(settings: MachineSettings = MachineSettings(),
                patterns: [PatternSlot] = Array(repeating: PatternSlot(), count: 16),
                selectedPattern: Int = 0, variationMode: VariationMode = .a,
                fillPattern: Int = 12, fillVariation: Variation = .a, autoFillInterval: Int = 0,
                tracks: [[PatternSelection]] = Array(repeating: [], count: 12),
                selectedTrack: Int = 0, trackMode: Bool = false, composeMode: Bool = false) {
        self.settings = settings; self.patterns = patterns; self.selectedPattern = selectedPattern
        self.variationMode = variationMode; self.fillPattern = fillPattern
        self.fillVariation = fillVariation; self.autoFillInterval = autoFillInterval
        self.tracks = tracks; self.selectedTrack = selectedTrack; self.trackMode = trackMode
        self.composeMode = composeMode
    }
    public func pattern(for index: Int, variation: Variation) -> RhythmPattern {
        guard patterns.indices.contains(index) else { return RhythmPattern() }
        return variation == .a ? patterns[index].a : patterns[index].b
    }
    /// Scale and part lengths are shared by A and B on the original machine.
    public mutating func updatePattern(_ pattern: RhythmPattern, index: Int, variation: Variation) {
        guard (0..<16).contains(index) else { return }
        while patterns.count < 16 { patterns.append(PatternSlot()) }
        if variation == .a { patterns[index].a = pattern } else { patterns[index].b = pattern }
        patterns[index].a.firstPartLength = pattern.firstPartLength
        patterns[index].b.firstPartLength = pattern.firstPartLength
        patterns[index].a.secondPartLength = pattern.secondPartLength
        patterns[index].b.secondPartLength = pattern.secondPartLength
        patterns[index].a.prescale = pattern.prescale
        patterns[index].b.prescale = pattern.prescale
        patterns[index].a.secondPartPrescale = pattern.secondPartPrescale
        patterns[index].b.secondPartPrescale = pattern.secondPartPrescale
    }
    /// A set of editable demonstrations, not factory Roland rhythms.
    public static var demo: MachineState {
        var machine = MachineState()
        for slot in 0..<12 {
            for variation in Variation.allCases {
                var pattern = RhythmPattern()
                let kicks = slot % 3 == 0 ? [0, 4, 8, 12] : (slot % 3 == 1 ? [0, 6, 10] : [0, 7, 10, 14])
                for step in kicks { pattern.setHit(.bassDrum, step: step, enabled: true) }
                for step in [4, 12] { pattern.setHit(.snareDrum, step: step, enabled: true) }
                for step in stride(from: 0, to: 16, by: slot % 4 == 3 ? 1 : 2) {
                    pattern.setHit(.closedHat, step: step, enabled: true)
                }
                for step in [0, 8] { pattern.setHit(.accent, step: step, enabled: true) }
                if slot % 4 == 1 { for step in [2, 10] { pattern.setHit(.cowbell, step: step, enabled: true) } }
                if slot % 4 == 2 { for step in [4, 12] { pattern.setHit(.handClap, step: step, enabled: true) } }
                if variation == .b {
                    pattern.setHit(.openHat, step: 14, enabled: true)
                    pattern.setHit(.closedHat, step: 14, enabled: false)
                    pattern.setHit(.bassDrum, step: 15, enabled: true)
                    pattern.setHit(.rimShot, step: 11, enabled: true)
                }
                machine.updatePattern(pattern, index: slot, variation: variation)
            }
        }
        for slot in 12..<16 {
            for variation in Variation.allCases {
                var pattern = RhythmPattern()
                for step in [0, 8] { pattern.setHit(.bassDrum, step: step, enabled: true) }
                for step in 0..<16 {
                    pattern.setHit(.closedHat, step: step, enabled: true)
                    if step >= 8 { pattern.setHit(slot % 2 == 0 ? .snareDrum : .midTom, step: step, enabled: true) }
                }
                for step in [8, 12, 15] { pattern.setHit(.accent, step: step, enabled: true) }
                pattern.setHit(.cymbal, step: variation == .a ? 0 : 15, enabled: true)
                machine.updatePattern(pattern, index: slot, variation: variation)
            }
        }
        machine.tracks[0] = [PatternSelection(pattern: 0), PatternSelection(pattern: 0, variation: .b),
                             PatternSelection(pattern: 1), PatternSelection(pattern: 12)]
        return machine
    }
}

@inline(__always) internal func bounded(_ value: Double, _ lower: Double, _ upper: Double, fallback: Double) -> Double {
    value.isFinite ? min(upper, max(lower, value)) : fallback
}
@inline(__always) internal func unit(_ value: Double) -> Double { bounded(value, 0, 1, fallback: 0.5) }
