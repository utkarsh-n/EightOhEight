import Foundation
import XCTest
@testable import RhythmCore

final class RhythmCoreTests: XCTestCase {
    private func synth(_ instrument: Instrument, parameters: VoiceParameters = VoiceParameters(),
                       frames: Int = 24000) -> [Float] {
        let core = RhythmRenderCore()
        var machine = MachineState()
        machine.settings[instrument] = parameters
        core.configure(machine)
        core.trigger(instrument)
        return core.render(frameCount: frames)
    }
    private func energy(_ samples: ArraySlice<Float>) -> Double {
        samples.reduce(0) { $0 + Double($1 * $1) } / Double(max(1, samples.count))
    }
    private func difference(_ a: [Float], _ b: [Float]) -> Double {
        zip(a, b).reduce(0) { $0 + abs(Double($1.0 - $1.1)) } / Double(max(1, min(a.count, b.count)))
    }
    private func advanceMeasure(_ core: RhythmRenderCore) {
        let before = core.completedMeasures
        while core.completedMeasures == before { _ = core.nextSample() }
    }

    func testAllSixteenGeneratedSoundsAreAudibleFiniteAndDistinct() {
        var sounds = [(String, [Float])]()
        for instrument in Instrument.allCases where instrument != .accent {
            let main = synth(instrument)
            XCTAssertTrue(main.allSatisfy { $0.isFinite && abs($0) <= 1 }, instrument.title)
            XCTAssertGreaterThan(energy(main[0..<12000]), 0.000001, instrument.title)
            sounds.append((instrument.title, main))
            if let alternate = instrument.alternateTitle {
                var p = VoiceParameters(); p.alternative = true
                let alternateSound = synth(instrument, parameters: p)
                XCTAssertTrue(alternateSound.allSatisfy { $0.isFinite && abs($0) <= 1 }, alternate)
                XCTAssertGreaterThan(energy(alternateSound[0..<12000]), 0.000001, alternate)
                sounds.append((alternate, alternateSound))
            }
        }
        XCTAssertEqual(sounds.count, 16)
        for a in sounds.indices {
            for b in sounds.indices where b > a {
                XCTAssertGreaterThan(difference(sounds[a].1, sounds[b].1), 0.0001,
                                     "\(sounds[a].0) and \(sounds[b].0) must be different circuits")
            }
        }
    }

    func testKickDecayChangesTailEnergy() {
        var short = VoiceParameters(); short.decay = 0
        var long = short; long.decay = 1
        let a = synth(.bassDrum, parameters: short, frames: 48000)
        let b = synth(.bassDrum, parameters: long, frames: 48000)
        XCTAssertGreaterThan(energy(b[24000..<48000]), energy(a[24000..<48000]) * 100)
    }

    func testEachOriginalSoundControlChangesRenderedAudio() {
        for (instrument, keyPath) in [
            (Instrument.bassDrum, \VoiceParameters.tone),
            (.snareDrum, \VoiceParameters.tone),
            (.snareDrum, \VoiceParameters.snappy),
            (.lowTom, \VoiceParameters.tuning),
            (.midTom, \VoiceParameters.tuning),
            (.highTom, \VoiceParameters.tuning),
            (.cymbal, \VoiceParameters.tone),
            (.cymbal, \VoiceParameters.decay),
            (.openHat, \VoiceParameters.decay)
        ] {
            var a = VoiceParameters(); a[keyPath: keyPath] = 0
            var b = a; b[keyPath: keyPath] = 1
            XCTAssertGreaterThan(difference(synth(instrument, parameters: a), synth(instrument, parameters: b)), 0.0002,
                                 "\(instrument.title) control")
        }
    }

    func testLevelAndMasterVolumeActuallyMute() {
        var p = VoiceParameters(); p.level = 0
        XCTAssertEqual(energy(synth(.bassDrum, parameters: p)[...]), 0)
        var machine = MachineState(); machine.settings.masterVolume = 0
        let core = RhythmRenderCore(); core.configure(machine); core.trigger(.bassDrum)
        XCTAssertEqual(energy(core.render(frameCount: 12000)[...]), 0)
    }

    func testAllVoicesSummedStayFiniteAndBounded() {
        var state = MachineState()
        state.settings.masterVolume = 1
        for instrument in Instrument.allCases {
            state.settings[instrument] = VoiceParameters(level: 1, tone: 1, decay: 1, tuning: 1, snappy: 1)
        }
        let core = RhythmRenderCore(); core.configure(state)
        for instrument in Instrument.allCases { core.trigger(instrument, accented: true) }
        let audio = core.render(frameCount: 48000)
        XCTAssertTrue(audio.allSatisfy { $0.isFinite && abs($0) <= 1 })
        XCTAssertGreaterThan(energy(audio[...]), 0.001)
    }

    func testClosedHatTerminatesOpenHatEnvelope() {
        var state = MachineState(); state.settings[.openHat].decay = 1
        let core = RhythmRenderCore(); core.configure(state); core.trigger(.openHat)
        _ = core.render(frameCount: 9600)
        XCTAssertTrue(core.voiceIsActive(.openHat))
        core.trigger(.closedHat)
        _ = core.render(frameCount: 2400)
        XCTAssertFalse(core.voiceIsActive(.openHat))
    }

    func testKnobOrStepEditsCannotUndoHiHatChoke() {
        var state = MachineState(); state.settings[.openHat].decay = 1
        let core = RhythmRenderCore(); core.configure(state); core.trigger(.openHat)
        _ = core.render(frameCount: 2000); core.trigger(.closedHat)
        _ = core.render(frameCount: 20)
        state.settings.tempo = 175; core.configure(state)
        _ = core.render(frameCount: 2400)
        XCTAssertFalse(core.voiceIsActive(.openHat))
        core.trigger(.openHat); _ = core.render(frameCount: 2400)
        XCTAssertTrue(core.voiceIsActive(.openHat), "A fresh open hit resets the choke release")
    }

    func testAccentChangesSoundAndStrength() {
        func rendered(_ accented: Bool) -> [Float] {
            let core = RhythmRenderCore(); core.trigger(.bassDrum, accented: accented)
            return core.render(frameCount: 12000)
        }
        let plain = rendered(false), accented = rendered(true)
        XCTAssertGreaterThan(energy(accented[...]), energy(plain[...]))
        XCTAssertGreaterThan(difference(plain, accented), 0.01)
    }

    func testAllFourPrescalesAreSampleAccurateWithoutClockDrift() {
        for scale in Prescale.allCases {
            var state = MachineState(); state.settings.tempo = 123
            state.patterns[0].a.prescale = scale
            let core = RhythmRenderCore(sampleRate: 8000); core.configure(state); core.setPlaying(true)
            let interval = 8000 * 60 / (123 * scale.stepsPerQuarter)
            for event in 0..<100 {
                while core.stepEventCount <= UInt64(event) { _ = core.nextSample() }
                XCTAssertEqual(Double(core.lastStepFrame), ceil(Double(event) * interval), accuracy: 1,
                               "Prescale \(scale.rawValue), event \(event)")
            }
        }
    }

    func testSecondPartUsesPhysicalStepSeventeenAndIndependentScale() {
        var state = MachineState()
        var pattern = RhythmPattern(firstPartLength: 2, secondPartLength: 2,
                                    prescale: .sixteenth, secondPartPrescale: .eighthTriplet)
        pattern.setHit(.snareDrum, step: 16, enabled: true)
        state.updatePattern(pattern, index: 0, variation: .a)
        let core = RhythmRenderCore(sampleRate: 8000); core.configure(state); core.setPlaying(true)
        var steps = [Int](), frames = [UInt64]()
        for event in 0..<5 {
            while core.stepEventCount <= UInt64(event) { _ = core.nextSample() }
            steps.append(core.currentStep); frames.append(core.lastStepFrame)
        }
        XCTAssertEqual(steps, [0, 1, 16, 17, 0])
        XCTAssertEqual(frames, [0, 1000, 2000, 3334, 4667])
        XCTAssertEqual(core.triggerCount(.snareDrum), 1)
    }

    func testChangingTempoPreservesCurrentStepProgress() {
        var state = MachineState()
        let core = RhythmRenderCore(); core.configure(state); core.setPlaying(true)
        _ = core.render(frameCount: 3000)
        state.settings.tempo = 240; core.configure(state)
        while core.stepEventCount < 2 { _ = core.nextSample() }
        XCTAssertEqual(core.lastStepFrame, 4500)
    }

    func testPatternChangesAreQueuedToMeasureBoundary() {
        var state = MachineState()
        state.patterns[0].a.firstPartLength = 2
        state.patterns[1].a.firstPartLength = 2
        let core = RhythmRenderCore(sampleRate: 8000); core.configure(state); core.setPlaying(true)
        _ = core.render(frameCount: 100)
        state.selectedPattern = 1; core.configure(state)
        XCTAssertEqual(core.currentPattern, 0)
        advanceMeasure(core)
        XCTAssertEqual(core.currentPattern, 1)
    }

    func testABVariationAlternatesAtMeasureBoundary() {
        var state = MachineState(); state.variationMode = .alternate
        state.patterns[0].a.firstPartLength = 1; state.patterns[0].b.firstPartLength = 1
        let core = RhythmRenderCore(sampleRate: 8000); core.configure(state); core.setPlaying(true)
        _ = core.nextSample(); XCTAssertEqual(core.currentVariation, .a)
        advanceMeasure(core); XCTAssertEqual(core.currentVariation, .b)
        advanceMeasure(core); XCTAssertEqual(core.currentVariation, .a)
    }

    func testSwitchingToABAlternatesFromCurrentlyPlayingBasicVariation() {
        var state = MachineState()
        state.patterns[0].a.firstPartLength = 1; state.patterns[0].b.firstPartLength = 1
        let core = RhythmRenderCore(sampleRate: 8000); core.configure(state); core.setPlaying(true)
        _ = core.nextSample(); advanceMeasure(core)
        state.variationMode = .alternate; core.configure(state)
        advanceMeasure(core); XCTAssertEqual(core.currentVariation, .b)
    }

    func testFillRunsOnceThenReturnsToBase() {
        var state = MachineState(); state.fillVariation = .b
        state.patterns[0].a.firstPartLength = 1
        state.patterns[12].b.firstPartLength = 1
        let core = RhythmRenderCore(sampleRate: 8000); core.configure(state); core.setPlaying(true)
        _ = core.nextSample(); core.requestFill()
        advanceMeasure(core)
        XCTAssertEqual(core.currentPattern, 12); XCTAssertEqual(core.currentVariation, .b)
        advanceMeasure(core); XCTAssertEqual(core.currentPattern, 0)
    }

    func testIntroPrecedesBasicAndDoesNotCountTowardAutomaticFill() {
        var state = MachineState(); state.autoFillInterval = 2
        state.patterns[0].a.firstPartLength = 1; state.patterns[12].a.firstPartLength = 1
        let core = RhythmRenderCore(sampleRate: 8000); core.configure(state)
        core.requestFill(); core.setPlaying(true)
        _ = core.nextSample(); XCTAssertEqual(core.currentPattern, 12)
        advanceMeasure(core); XCTAssertEqual(core.currentPattern, 0)
        advanceMeasure(core); XCTAssertEqual(core.currentPattern, 12)
        advanceMeasure(core); XCTAssertEqual(core.currentPattern, 0)
    }

    func testTrackChainLoopsAndUsesLiveVariation() {
        var state = MachineState(); state.trackMode = true; state.variationMode = .b
        state.tracks[0] = [PatternSelection(pattern: 2, variation: .a), PatternSelection(pattern: 4)]
        state.patterns[2].b.firstPartLength = 1; state.patterns[4].b.firstPartLength = 1
        let core = RhythmRenderCore(sampleRate: 8000); core.configure(state); core.setPlaying(true)
        _ = core.nextSample(); XCTAssertEqual(core.currentPattern, 2); XCTAssertEqual(core.currentVariation, .b)
        advanceMeasure(core); XCTAssertEqual(core.currentPattern, 4)
        advanceMeasure(core); XCTAssertEqual(core.currentPattern, 2)
    }

    func testSelectedFillAndTrackFillUseIndependentIFVariation() {
        var state = MachineState(); state.selectedPattern = 12; state.fillVariation = .b
        state.variationMode = .a; state.patterns[12].b.firstPartLength = 1
        let core = RhythmRenderCore(sampleRate: 8000); core.configure(state); core.setPlaying(true)
        _ = core.nextSample(); XCTAssertEqual(core.currentVariation, .b)
        core.setPlaying(false)
        state.trackMode = true; state.tracks[0] = [PatternSelection(pattern: 12)]
        core.configure(state); core.setPlaying(true)
        _ = core.nextSample(); XCTAssertEqual(core.currentVariation, .b)
    }

    func testTrackPlaybackIgnoresManualAutoFillAndTap() {
        var state = MachineState(); state.trackMode = true; state.autoFillInterval = 2
        state.tracks[0] = [PatternSelection(pattern: 0), PatternSelection(pattern: 1), PatternSelection(pattern: 2)]
        for index in 0..<16 { state.patterns[index].a.firstPartLength = 1 }
        let core = RhythmRenderCore(sampleRate: 8000); core.configure(state); core.requestFill(); core.setPlaying(true)
        _ = core.nextSample(); XCTAssertEqual(core.currentPattern, 0)
        core.requestFill(); advanceMeasure(core); XCTAssertEqual(core.currentPattern, 1)
        advanceMeasure(core); XCTAssertEqual(core.currentPattern, 2)
    }

    func testComposeRecordsPerformedMeasuresAndSurvivesKnobUpdates() {
        var state = MachineState(); state.composeMode = true
        for index in 0..<16 { state.patterns[index].a.firstPartLength = 1 }
        let core = RhythmRenderCore(sampleRate: 8000); core.configure(state); core.setPlaying(true)
        _ = core.nextSample()
        state.selectedPattern = 3; core.configure(state); advanceMeasure(core)
        state.settings.tempo = 140; core.configure(state)
        state.selectedPattern = 7; core.configure(state); advanceMeasure(core)
        var recorded = Array(repeating: PatternSelection(pattern: 0), count: 64)
        let count = recorded.withUnsafeMutableBufferPointer { core.copyRecordedTrack(into: $0) }
        XCTAssertEqual(count, 3)
        XCTAssertEqual(recorded.prefix(count).map(\.pattern), [0, 3, 7])
    }

    func testComposeStopsRecordingAtSixtyFourMeasures() {
        var state = MachineState(); state.composeMode = true
        state.patterns[0].a.firstPartLength = 1
        let core = RhythmRenderCore(sampleRate: 8000); core.configure(state); core.setPlaying(true)
        _ = core.nextSample()
        for _ in 0..<70 { advanceMeasure(core) }
        var recorded = Array(repeating: PatternSelection(pattern: 0), count: 64)
        XCTAssertEqual(recorded.withUnsafeMutableBufferPointer { core.copyRecordedTrack(into: $0) }, 64)
    }

    func testComposeRestartPreservesExistingUnwrittenTail() {
        var state = MachineState(); state.composeMode = true
        state.tracks[0] = [PatternSelection(pattern: 5), PatternSelection(pattern: 6), PatternSelection(pattern: 7)]
        state.patterns[0].a.firstPartLength = 1
        let core = RhythmRenderCore(sampleRate: 8000); core.configure(state); core.setPlaying(true)
        _ = core.nextSample(); core.setPlaying(false)
        var recorded = Array(repeating: PatternSelection(pattern: 0), count: 64)
        let count = recorded.withUnsafeMutableBufferPointer { core.copyRecordedTrack(into: $0) }
        XCTAssertEqual(recorded.prefix(count).map(\.pattern), [0, 6, 7])
    }

    func testExplicitTrackClearDuringComposeResetsRecordPosition() {
        var state = MachineState(); state.composeMode = true; state.patterns[0].a.firstPartLength = 1
        let core = RhythmRenderCore(sampleRate: 8000); core.configure(state); core.setPlaying(true)
        _ = core.nextSample(); advanceMeasure(core); core.clearTrack()
        var recorded = Array(repeating: PatternSelection(pattern: 0), count: 64)
        XCTAssertEqual(recorded.withUnsafeMutableBufferPointer { core.copyRecordedTrack(into: $0) }, 0)
        advanceMeasure(core)
        XCTAssertEqual(recorded.withUnsafeMutableBufferPointer { core.copyRecordedTrack(into: $0) }, 1)
    }

    func testStoppingLeavesAuditionUsableAndDoesNotAdvanceSequence() {
        let core = RhythmRenderCore(); core.setPlaying(true); _ = core.render(frameCount: 500)
        core.setPlaying(false); let events = core.stepEventCount
        core.trigger(.bassDrum)
        XCTAssertGreaterThan(energy(core.render(frameCount: 6000)[...]), 0.001)
        XCTAssertEqual(core.stepEventCount, events); XCTAssertEqual(core.currentStep, -1)
    }

    func testModelsRoundTripAllPatternsVariationsTracksAndParameters() throws {
        var original = MachineState.demo
        original.settings[.lowTom].alternative = true
        original.patterns[15].b.secondPartLength = 13
        original.patterns[15].b.secondPartPrescale = .thirtySecond
        original.tracks[11] = (0..<64).map { PatternSelection(pattern: $0 % 16, variation: $0 % 2 == 0 ? .a : .b) }
        let encoded = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(MachineState.self, from: encoded), original)
    }

    func testUpdatingLengthsAndScaleSharesThemAcrossVariations() {
        var state = MachineState()
        state.updatePattern(RhythmPattern(firstPartLength: 7, secondPartLength: 11,
                                         prescale: .eighthTriplet, secondPartPrescale: .thirtySecond),
                            index: 2, variation: .b)
        XCTAssertEqual(state.patterns[2].a.firstPartLength, 7)
        XCTAssertEqual(state.patterns[2].a.secondPartLength, 11)
        XCTAssertEqual(state.patterns[2].a.prescale, .eighthTriplet)
        XCTAssertEqual(state.patterns[2].a.secondPartPrescale, .thirtySecond)
    }

    func testMalformedValuesAreClampedBeforeRendering() {
        var state = MachineState(settings: MachineSettings(tempo: .nan, masterVolume: .infinity, voices: []),
                                 patterns: [], selectedPattern: 99, fillPattern: -1, tracks: [], selectedTrack: 999)
        state.settings[.snareDrum] = VoiceParameters(level: .nan, tone: -999, decay: .infinity, tuning: 999)
        let core = RhythmRenderCore(sampleRate: .nan); core.configure(state); core.setPlaying(true)
        core.trigger(.snareDrum)
        XCTAssertTrue(core.render(frameCount: 12000).allSatisfy { $0.isFinite && abs($0) <= 1 })
    }

    func testWaveFileHasExactLoopDurationAndValidPCMHeader() throws {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("808-core-test-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: destination) }
        let frames = try WaveExporter.writeWAV(state: .demo, bars: 2, sampleRate: 8000, to: destination)
        let data = try Data(contentsOf: destination)
        XCTAssertEqual(frames, 32000)
        XCTAssertEqual(data.count, 44 + frames * 2)
        XCTAssertEqual(String(data: data[0..<4], encoding: .utf8), "RIFF")
        XCTAssertEqual(String(data: data[8..<12], encoding: .utf8), "WAVE")
        XCTAssertEqual(String(data: data[36..<40], encoding: .utf8), "data")
        XCTAssertEqual(data[20], 1); XCTAssertEqual(data[22], 1); XCTAssertEqual(data[34], 16)
    }
}
