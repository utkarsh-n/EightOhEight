import SwiftUI
import Observation
import Combine
import RhythmCore

enum MachineMode: Int, CaseIterable, Identifiable {
    case clear, first, second, manual, trackPlay, compose
    var id: Int { rawValue }
    var title: String { ["PATTERN CLEAR", "1st PART", "2nd PART", "MANUAL PLAY", "PLAY", "COMPOSE"][rawValue] }
}

enum ControlParameter: String { case level, tone, decay, tuning, snappy }
enum MachineSheet: String, Identifiable { case library, help, settings, track, export
    var id: String { rawValue }
}

@MainActor @Observable
final class MachineModel {
    var state: MachineState
    var skin: MachineSkin {
        didSet { UserDefaults.standard.set(skin.rawValue, forKey: "808.skin") }
    }
    var selectedInstrument = 1 {
        didSet {
            if mode == .trackPlay || mode == .compose {
                state.selectedTrack = max(0, min(11, selectedInstrument))
                synchronize()
            }
        }
    }
    var mode: MachineMode = .first {
        didSet {
            state.trackMode = mode == .trackPlay
            state.composeMode = mode == .compose
            if mode == .second && length == 0 { setLength(16) }
            synchronize()
        }
    }
    var editingVariation = 0
    var isPowered = true
    var isPlaying = false
    var currentStep = -1
    var currentVariation = 0
    var playingPattern = 0
    var sheet: MachineSheet?
    var status = "Select a voice · press steps · START"
    var exportURL: URL?
    var exporting = false
    var introArmed = false
    var hapticsEnabled: Bool { didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "808.haptics") } }
    @ObservationIgnored let audio = RhythmAudioEngine()
    @ObservationIgnored private var subscriptions = Set<AnyCancellable>()
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private let selectionFeedback = UISelectionFeedbackGenerator()

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "--skin"), arguments.indices.contains(flag + 1),
           let requested = MachineSkin(rawValue: arguments[flag + 1]) {
            skin = requested
        } else if arguments.contains("--uitesting") {
            skin = .original
        } else {
            skin = UserDefaults.standard.string(forKey: "808.skin").flatMap(MachineSkin.init(rawValue:)) ?? .studio
        }
        hapticsEnabled = UserDefaults.standard.object(forKey: "808.haptics") as? Bool ?? true
        if !ProcessInfo.processInfo.arguments.contains("--uitesting"),
           let data = try? Data(contentsOf: Self.saveURL), let restored = try? JSONDecoder().decode(MachineState.self, from: data),
           restored.patterns.count == 16, restored.settings.voices.count == 12, restored.tracks.count == 12 {
            state = restored
        } else { state = .demo }
        audio.update(state)
        audio.$isPlaying.sink { [weak self] in self?.isPlaying = $0 }.store(in: &subscriptions)
        audio.$currentStep.sink { [weak self] in self?.currentStep = $0 }.store(in: &subscriptions)
        audio.$currentPattern.sink { [weak self] in self?.playingPattern = $0 }.store(in: &subscriptions)
        audio.$currentVariation.sink { [weak self] in self?.currentVariation = $0 == .a ? 0 : 1 }.store(in: &subscriptions)
        audio.$errorMessage.sink { [weak self] message in if let message { self?.status = message } }.store(in: &subscriptions)
        audio.$recordedTrack.sink { [weak self] track in
            guard let self, self.mode == .compose, self.state.tracks[self.state.selectedTrack] != track else { return }
            self.state.tracks[self.state.selectedTrack] = track
            if track.count == 64 { self.status = "Track full · 64 measures recorded" }
            self.synchronize()
        }.store(in: &subscriptions)
    }

    static var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("EightOhEight.json")
    }
    var patternIndex: Int { get { state.selectedPattern } set { selectPattern(newValue) } }
    var patternName: String { patternIndex < 12 ? "BASIC RHYTHM \(patternIndex + 1)" : "INTRO / FILL \(patternIndex - 11)" }
    var variation: Int {
        get { state.variationMode == .a ? 0 : state.variationMode == .alternate ? 1 : 2 }
        set {
            state.variationMode = newValue == 0 ? .a : newValue == 1 ? .alternate : .b
            editingVariation = newValue == 2 ? 1 : 0
            synchronize(); feedback()
        }
    }
    var fillVariation: Int {
        get { state.fillVariation == .a ? 0 : 1 }
        set { state.fillVariation = newValue == 0 ? .a : .b; synchronize(); feedback() }
    }
    var autoFill: Int {
        get { state.autoFillInterval }
        set { state.autoFillInterval = [0, 16, 12, 8, 4, 2].contains(newValue) ? newValue : 0; synchronize() }
    }
    var prescale: Int {
        get { (mode == .second ? (pattern.secondPartPrescale ?? pattern.prescale) : pattern.prescale).rawValue - 1 }
        set {
            var p = pattern
            let value = Prescale(rawValue: max(1, min(4, newValue + 1))) ?? .sixteenth
            if mode == .second { p.secondPartPrescale = value } else { p.prescale = value }
            putPattern(p)
        }
    }
    var tempo: Double {
        get { state.settings.tempo }
        set { state.settings.tempo = min(300, max(40, newValue)); synchronize() }
    }
    var fine: Double {
        get { state.settings.fineTempo / 12 + 0.5 }
        set { state.settings.fineTempo = (min(1, max(0, newValue)) - 0.5) * 12; synchronize() }
    }
    var master: Double {
        get { state.settings.masterVolume }
        set { state.settings.masterVolume = min(1, max(0, newValue)); synchronize() }
    }
    var length: Int {
        get { mode == .second ? pattern.secondPartLength : pattern.firstPartLength }
        set { setLength(newValue) }
    }
    var secondPartEnabled: Bool { pattern.secondPartLength > 0 }
    var writeVariation: Variation { patternIndex >= 12 ? state.fillVariation : (editingVariation == 0 ? .a : .b) }
    var pattern: RhythmPattern { state.pattern(for: patternIndex, variation: writeVariation) }
    var selectedName: String {
        let i = Instrument(rawValue: selectedInstrument) ?? .bassDrum
        return alternative(channel: selectedInstrument) ? (i.alternateTitle ?? i.title) : i.title
    }

    func synchronize() {
        var audibleState = state
        if !isPowered { audibleState.settings.masterVolume = 0 }
        audio.update(audibleState)
        saveTask?.cancel()
        let snapshot = state
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            do { let data = try JSONEncoder().encode(snapshot); try data.write(to: Self.saveURL, options: .atomic) }
            catch { status = "Could not save rhythm: \(error.localizedDescription)" }
        }
    }
    func saveNow() {
        saveTask?.cancel()
        do { try JSONEncoder().encode(state).write(to: Self.saveURL, options: .atomic) }
        catch { status = "Could not save rhythm: \(error.localizedDescription)" }
    }
    func putPattern(_ value: RhythmPattern) {
        state.updatePattern(value, index: patternIndex, variation: writeVariation)
        synchronize()
    }
    func knobBinding(channel: Int, parameter: ControlParameter) -> Binding<Double> {
        Binding(get: { [weak self] in
            guard let self else { return 0.5 }
            if channel == 0 { return self.state.settings.accentAmount }
            let p = self.state.settings.voices[channel]
            switch parameter {
            case .level: return p.level
            case .tone: return p.tone
            case .decay: return p.decay
            case .tuning: return p.tuning
            case .snappy: return p.snappy
            }
        }, set: { [weak self] value in
            guard let self else { return }
            let v = min(1, max(0, value))
            if channel == 0 { self.state.settings.accentAmount = v }
            else {
                switch parameter {
                case .level: self.state.settings.voices[channel].level = v
                case .tone: self.state.settings.voices[channel].tone = v
                case .decay: self.state.settings.voices[channel].decay = v
                case .tuning: self.state.settings.voices[channel].tuning = v
                case .snappy: self.state.settings.voices[channel].snappy = v
                }
            }
            self.synchronize()
        })
    }
    func alternative(channel: Int) -> Bool { state.settings.voices[channel].alternative }
    func toggleAlternative(channel: Int) {
        guard (3...7).contains(channel) else { return }
        state.settings.voices[channel].alternative.toggle(); synchronize(); feedback()
        hit(channel: channel)
    }
    func hit(channel: Int) {
        guard isPowered, let instrument = Instrument(rawValue: channel) else { return }
        audio.trigger(instrument); feedback()
    }
    func selectInstrument(_ index: Int) { selectedInstrument = max(0, min(11, index)); feedback() }
    func toggleStep(_ index: Int) {
        guard isPowered, (0..<16).contains(index) else { return }
        switch mode {
        case .manual, .clear: selectPattern(index)
        case .trackPlay: if index < 12 { state.selectedTrack = index; synchronize(); feedback() }
        case .compose:
            selectPattern(index)
            status = isPlaying ? "Pattern queued · composing track \(state.selectedTrack + 1)" : "Press START to compose performed measures"
        case .first, .second:
            var p = pattern
            let step = index + (mode == .second ? 16 : 0)
            guard index < length else { return }
            p.toggle(Instrument(rawValue: selectedInstrument) ?? .bassDrum, step: step)
            putPattern(p); feedback()
        }
    }
    func stepEnabled(_ index: Int) -> Bool {
        if mode == .manual || mode == .clear { return index == patternIndex || (index >= 12 && index == state.fillPattern) }
        if mode == .trackPlay { return index == state.selectedTrack }
        let step = index + (mode == .second ? 16 : 0)
        return index < length && pattern.hit(Instrument(rawValue: selectedInstrument) ?? .bassDrum, step: step)
    }
    func toggleTransport() {
        guard isPowered else { return }
        if isPlaying { audio.stop(); status = "Stopped · rhythms saved"; saveNow() }
        else {
            state.trackMode = mode == .trackPlay
            state.composeMode = mode == .compose
            audio.update(state)
            do { try audio.start(); introArmed = false; status = mode == .trackPlay ? "TRACK \(state.selectedTrack + 1)" : "\(patternName) · \(Int(tempo)) BPM" }
            catch { status = "Audio: \(error.localizedDescription)" }
        }
        feedback()
    }
    func tap() {
        guard isPowered else { return }
        if mode == .first || mode == .second {
            hit(channel: selectedInstrument)
            if isPlaying && currentStep >= 0 {
                var p = pattern
                p.setHit(Instrument(rawValue: selectedInstrument) ?? .bassDrum, step: min(31, currentStep), enabled: true)
                putPattern(p)
            }
        } else {
            audio.requestFill()
            introArmed = !isPlaying
            status = isPlaying ? "Fill queued for next measure" : "Intro armed · press START"
            feedback()
        }
    }
    func clear() {
        guard isPowered else { return }
        if mode == .compose {
            audio.clearTrack()
            state.tracks[state.selectedTrack] = []; synchronize(); status = "Track cleared"
        } else {
            var p = pattern
            if mode == .clear {
                p = RhythmPattern()
                state.updatePattern(p, index: patternIndex, variation: writeVariation)
                if patternIndex < 12 && variation == 1 {
                    state.updatePattern(p, index: patternIndex, variation: writeVariation == .a ? .b : .a)
                }
                synchronize(); status = patternIndex < 12 && variation == 1 ? "Pattern A + B cleared" : "Pattern \(writeVariation == .a ? "A" : "B") cleared"
            } else { p.clear(instrument: Instrument(rawValue: selectedInstrument)); putPattern(p); status = "\(selectedName) cleared" }
        }
        feedback()
    }
    func selectPattern(_ index: Int) {
        guard (0..<16).contains(index) else { return }
        if mode == .manual && index >= 12 { state.fillPattern = index }
        else { state.selectedPattern = index }
        synchronize(); feedback()
    }
    func togglePower() {
        isPowered.toggle()
        if !isPowered { audio.stop(); saveNow() }
        synchronize(); feedback()
    }
    func cycleVariation() { variation = (variation + 1) % 3 }
    func cycleFillVariation() { fillVariation = 1 - fillVariation }
    func cyclePrescale() { prescale = (prescale + 1) % 4; feedback() }
    func setLength(_ value: Int) {
        var p = pattern
        if mode == .second { p.secondPartLength = max(0, min(16, value)) }
        else { p.firstPartLength = max(1, min(16, value)) }
        putPattern(p)
    }
    func toggleSecondPart() { var p = pattern; p.secondPartLength = secondPartEnabled ? 0 : 16; putPattern(p); feedback() }
    func openSheet(_ value: MachineSheet) { sheet = value }
    func feedback() { if hapticsEnabled { selectionFeedback.selectionChanged() } }
    func appendTrack(pattern: Int, variation: Variation) {
        guard state.tracks[state.selectedTrack].count < 64 else { status = "Track full · 64 measures"; return }
        state.tracks[state.selectedTrack].append(PatternSelection(pattern: pattern, variation: variation))
        synchronize(); feedback(); status = "TRACK \(state.selectedTrack + 1) · \(state.tracks[state.selectedTrack].count) measures"
    }
    func removeTrackMeasure(_ index: Int) { state.tracks[state.selectedTrack].remove(at: index); synchronize() }
    func loadDemo() { audio.stop(); state = .demo; editingVariation = 0; synchronize(); status = "Factory rhythms loaded" }
    func export() {
        guard !exporting else { return }
        exporting = true; status = "Rendering four bars…"
        let snapshot = state
        Task {
            do {
                exportURL = try await Task.detached(priority: .userInitiated) {
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("EightOhEight-\(UUID().uuidString.prefix(8)).wav")
                    try WaveExporter.writeWAV(state: snapshot, bars: 4, to: url)
                    return url
                }.value
                sheet = .export; status = "Four-bar WAV ready"
            }
            catch { status = "Export: \(error.localizedDescription)" }
            exporting = false
        }
    }
}
