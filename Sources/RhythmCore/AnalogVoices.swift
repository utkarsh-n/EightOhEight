import Foundation

/// A stateful band-pass filter. Coefficients are prepared between render buffers.
internal struct BandPass {
    var b0 = 0.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    var z1 = 0.0, z2 = 0.0

    mutating func prepare(frequency: Double, q: Double, sampleRate: Double) {
        let omega = 2 * Double.pi * min(sampleRate * 0.44, max(20, frequency)) / sampleRate
        let alpha = sin(omega) / (2 * q)
        let divisor = 1 + alpha
        b0 = alpha / divisor; b1 = 0; b2 = -b0
        a1 = -2 * cos(omega) / divisor; a2 = (1 - alpha) / divisor
    }
    @inline(__always) mutating func sample(_ input: Double) -> Double {
        let output = b0 * input + z1
        z1 = b1 * input - a1 * output + z2
        z2 = b2 * input - a2 * output
        return output
    }
    mutating func reset() { z1 = 0; z2 = 0 }
}

@inline(__always) internal func sine(_ phase: Double, table: UnsafePointer<Double>) -> Double {
    let position = phase * 4096
    let index = Int(position)
    let fraction = position - Double(index)
    return table[index] + fraction * (table[index + 1] - table[index])
}

@inline(__always) internal func advance(_ phase: inout Double, frequency: Double, sampleRate: Double) {
    phase += frequency / sampleRate
    if phase >= 1 { phase -= 1 }
}

/// Band-limited square oscillators retain the metallic source without folded ultrasonics.
@inline(__always) internal func polyBLEP(_ phase: Double, increment: Double) -> Double {
    if phase < increment {
        let t = phase / increment
        return t + t - t * t - 1
    }
    if phase > 1 - increment {
        let t = (phase - 1) / increment
        return t * t + t + t + 1
    }
    return 0
}

@inline(__always) internal func square(_ phase: Double, frequency: Double, sampleRate: Double) -> Double {
    let increment = frequency / sampleRate
    var output = phase < 0.5 ? 1.0 : -1.0
    output += polyBLEP(phase, increment: increment)
    let shifted = phase < 0.5 ? phase + 0.5 : phase - 0.5
    output -= polyBLEP(shifted, increment: increment)
    return output
}

/// Each physical channel is monophonic. These generated voices follow the original
/// resonator/noise/oscillator mechanisms; they are not a measured circuit emulation.
internal struct AnalogVoice {
    let instrument: Instrument
    var parameters = VoiceParameters()
    var active = false
    var playingAlternative = false
    var isChoked = false
    var phase1 = 0.0, phase2 = 0.0, phase3 = 0.0
    var envelope1 = 0.0, envelope2 = 0.0, envelope3 = 0.0
    var coefficient1 = 0.0, coefficient2 = 0.0, coefficient3 = 0.0
    var pitchEnvelope = 0.0, pitchCoefficient = 0.0
    var frequency1 = 0.0, frequency2 = 0.0
    var noiseLowpass = 0.0
    var noiseState: UInt32
    var gain = 0.0, velocity = 1.0
    var age = 0
    var pulse1 = 0, pulse2 = 0, reverbStart = 0
    var filter1 = BandPass(), filter2 = BandPass()

    init(instrument: Instrument) {
        self.instrument = instrument
        noiseState = 0x8_080_808 &+ UInt32(instrument.rawValue * 8171)
    }

    mutating func prepare(_ parameters: VoiceParameters, sampleRate: Double) {
        self.parameters = parameters.normalized
        let p = self.parameters
        let isAlternative = active ? playingAlternative : p.alternative
        func decay(_ timeConstant: Double) -> Double { exp(-1 / (sampleRate * timeConstant)) }
        pitchCoefficient = decay(0.012)
        coefficient3 = decay(0.005)
        switch instrument {
        case .accent: break
        case .bassDrum:
            // Bridged-T ringing at fixed pitch, plus the brief trigger pitch pulse.
            frequency1 = 55
            coefficient1 = decay(0.065 + 0.86 * p.decay * p.decay)
            coefficient2 = decay(0.0045)
        case .snareDrum:
            frequency1 = 185; frequency2 = 330
            coefficient1 = decay(0.052); coefficient2 = decay(0.076)
            filter1.prepare(frequency: 1900 + 3100 * p.tone, q: 0.72, sampleRate: sampleRate)
        case .lowTom, .midTom, .highTom:
            let base: Double = instrument == .lowTom ? 105 : instrument == .midTom ? 165 : 240
            frequency1 = base * (0.8 + p.tuning * 0.4) * (isAlternative ? 1.28 : 1)
            coefficient1 = decay(isAlternative ? 0.085 : 0.15)
            coefficient2 = decay(0.065)
            pitchCoefficient = decay(0.035)
            filter1.prepare(frequency: 600, q: 0.7, sampleRate: sampleRate)
        case .rimShot:
            frequency1 = isAlternative ? 2450 : 1680
            frequency2 = isAlternative ? 2450 : 820
            coefficient1 = decay(isAlternative ? 0.022 : 0.018)
            coefficient2 = decay(0.009)
        case .handClap:
            coefficient1 = decay(isAlternative ? 0.028 : 0.0032)
            coefficient2 = decay(0.085)
            pulse1 = Int(sampleRate * 0.0105)
            pulse2 = Int(sampleRate * 0.021)
            reverbStart = Int(sampleRate * 0.029)
            filter1.prepare(frequency: isAlternative ? 5200 : 1250, q: isAlternative ? 0.65 : 0.95, sampleRate: sampleRate)
        case .cowbell:
            frequency1 = 540; frequency2 = 800
            coefficient1 = decay(0.055); coefficient2 = decay(0.18)
            filter1.prepare(frequency: 700, q: 1.2, sampleRate: sampleRate)
        case .cymbal:
            coefficient1 = decay(0.16 + p.decay * 1.3)
            coefficient2 = decay(0.032 + p.decay * 0.15)
            filter1.prepare(frequency: 2400 + 5000 * p.tone, q: 0.72, sampleRate: sampleRate)
            filter2.prepare(frequency: 8600, q: 0.8, sampleRate: sampleRate)
        case .openHat:
            coefficient1 = decay(isChoked ? 0.0015 : 0.065 + p.decay * 0.49)
            filter1.prepare(frequency: 7600, q: 0.75, sampleRate: sampleRate)
        case .closedHat:
            coefficient1 = decay(0.014)
            filter1.prepare(frequency: 8200, q: 0.8, sampleRate: sampleRate)
        }
    }

    mutating func trigger(velocity: Double, accented: Bool, sampleRate: Double) {
        self.velocity = velocity
        gain = parameters.level * velocity
        playingAlternative = parameters.alternative
        isChoked = false
        active = true
        prepare(parameters, sampleRate: sampleRate)
        phase1 = 0; phase2 = 0; phase3 = 0
        envelope1 = 1; envelope2 = instrument == .handClap && !playingAlternative ? 0 : 1
        envelope3 = 1
        pitchEnvelope = accented ? 1 : 0.45
        noiseLowpass = 0; age = 0
        filter1.reset(); filter2.reset()
    }

    /// A short release prevents a discontinuity when the closed hat terminates the open hat.
    mutating func choke(sampleRate: Double) {
        isChoked = true
        coefficient1 = exp(-1 / (sampleRate * 0.0015))
    }

    @inline(__always) mutating func noise() -> Double {
        noiseState = 1664525 &* noiseState &+ 1013904223
        return Double(Int32(bitPattern: noiseState)) / 2147483648
    }

    @inline(__always) mutating func nextSample(sampleRate: Double, metal: Double,
                                              table: UnsafePointer<Double>) -> Double {
        guard active else { return 0 }
        let n = noise()
        let p = parameters
        let output: Double
        switch instrument {
        case .accent: output = 0
        case .bassDrum:
            let frequency = frequency1 * (1 + pitchEnvelope * 0.85)
            advance(&phase1, frequency: frequency, sampleRate: sampleRate)
            advance(&phase2, frequency: frequency * 2, sampleRate: sampleRate)
            let body = sine(phase1, table: table) + 0.12 * p.tone * sine(phase2, table: table)
            output = 0.88 * body * envelope1 + n * envelope2 * (0.015 + 0.10 * p.tone)
        case .snareDrum:
            advance(&phase1, frequency: frequency1, sampleRate: sampleRate)
            advance(&phase2, frequency: frequency2, sampleRate: sampleRate)
            let shell = (sine(phase1, table: table) * (1 - p.tone * 0.65) + sine(phase2, table: table) * (0.3 + p.tone * 0.6)) * envelope1
            let wire = filter1.sample(n) * envelope2
            output = shell * 0.36 + wire * (0.12 + p.snappy * 1.1)
        case .lowTom, .midTom, .highTom:
            advance(&phase1, frequency: frequency1 * (1 + pitchEnvelope * 0.14), sampleRate: sampleRate)
            advance(&phase2, frequency: frequency1 * 1.8, sampleRate: sampleRate)
            noiseLowpass += 0.075 * (n - noiseLowpass)
            let body = (sine(phase1, table: table) + 0.055 * sine(phase2, table: table)) * envelope1
            output = 0.64 * body + (playingAlternative ? 0 : filter1.sample(noiseLowpass) * envelope2 * 0.7)
        case .rimShot:
            advance(&phase1, frequency: frequency1, sampleRate: sampleRate)
            advance(&phase2, frequency: frequency2, sampleRate: sampleRate)
            let wood = sine(phase1, table: table) * envelope1
            output = playingAlternative ? wood * 0.75 : wood * 0.5 + sine(phase2, table: table) * envelope2 * 0.35 + n * envelope3 * 0.07
        case .handClap:
            if !playingAlternative {
                if age == pulse1 || age == pulse2 { envelope1 = 1 }
                if age == reverbStart { envelope2 = 0.8 }
            }
            output = filter1.sample(n) * (envelope1 * 1.55 + (playingAlternative ? 0 : envelope2 * 0.48))
        case .cowbell:
            let source = square(phase1, frequency: frequency1, sampleRate: sampleRate)
                + square(phase2, frequency: frequency2, sampleRate: sampleRate)
            advance(&phase1, frequency: frequency1, sampleRate: sampleRate)
            advance(&phase2, frequency: frequency2, sampleRate: sampleRate)
            output = filter1.sample(source) * (envelope1 * 0.47 + envelope2 * 0.11)
        case .cymbal:
            output = filter1.sample(metal) * envelope1 * 0.56 + filter2.sample(metal) * envelope2 * 0.48
        case .openHat, .closedHat:
            output = filter1.sample(metal) * envelope1 * (instrument == .openHat ? 0.57 : 0.66)
        }
        envelope1 *= coefficient1; envelope2 *= coefficient2; envelope3 *= coefficient3
        pitchEnvelope *= pitchCoefficient
        gain += (parameters.level * velocity - gain) * 0.002
        age += 1
        // Keep the later hand-clap pulses alive even while the first pulse decays.
        if envelope1 < 0.00001 && envelope2 < 0.00001 && (instrument != .handClap || age > reverbStart) { active = false }
        return output * gain
    }
}
