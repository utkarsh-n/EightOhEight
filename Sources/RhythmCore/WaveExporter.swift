import Foundation

public enum WaveExportError: Error, LocalizedError {
    case invalidMeasureCount
    public var errorDescription: String? { "Choose between 1 and 64 measures to export." }
}

/// Uses the same synthesizer and sample clock as live playback. No microphone or samples.
public enum WaveExporter {
    public static func render(state: MachineState, bars: Int = 4, sampleRate: Double = 48000) throws -> [Float] {
        guard (1...64).contains(bars) else { throw WaveExportError.invalidMeasureCount }
        let core = RhythmRenderCore(sampleRate: sampleRate)
        core.configure(state)
        core.setPlaying(true)
        var samples = [Float]()
        let estimatedFrames = Int(core.sampleRate * 60 / state.settings.effectiveTempo * 4 * Double(bars))
        samples.reserveCapacity(estimatedFrames)
        while core.completedMeasures < bars {
            let value = core.nextSample()
            if core.completedMeasures < bars { samples.append(value) }
        }
        core.setPlaying(false)
        // The next bar's boundary sample is excluded, preserving exact loop length.
        return samples
    }

    @discardableResult
    public static func writeWAV(state: MachineState, bars: Int = 4,
                                sampleRate: Double = 48000, to url: URL) throws -> Int {
        let samples = try render(state: state, bars: bars, sampleRate: sampleRate)
        let rate = UInt32(bounded(sampleRate, 8000, 192000, fallback: 48000))
        var data = Data(count: 44 + samples.count * 2)
        data.withUnsafeMutableBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            func string(_ text: String, at offset: Int) {
                for (i, byte) in text.utf8.enumerated() { bytes[offset + i] = byte }
            }
            func u16(_ value: UInt16, at offset: Int) {
                bytes[offset] = UInt8(truncatingIfNeeded: value)
                bytes[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
            }
            func u32(_ value: UInt32, at offset: Int) {
                for i in 0..<4 { bytes[offset + i] = UInt8(truncatingIfNeeded: value >> UInt32(i * 8)) }
            }
            string("RIFF", at: 0); u32(UInt32(36 + samples.count * 2), at: 4)
            string("WAVE", at: 8); string("fmt ", at: 12)
            u32(16, at: 16); u16(1, at: 20); u16(1, at: 22)
            u32(rate, at: 24); u32(rate * 2, at: 28)
            u16(2, at: 32); u16(16, at: 34)
            string("data", at: 36); u32(UInt32(samples.count * 2), at: 40)
            for (i, sample) in samples.enumerated() {
                let quantized = Int16(max(-32767, min(32767, Int((sample * 32767).rounded()))))
                u16(UInt16(bitPattern: quantized), at: 44 + i * 2)
            }
        }
        try data.write(to: url, options: .atomic)
        return samples.count
    }
}
