import SwiftUI
import RhythmCore

/// A native instrument surface. The sound, memory, and transport belong to the
/// same MachineModel as the hardware skin; only their presentation changes.
@available(iOS 26.0, *)
struct GlassMachinePanel: View {
    let model: MachineModel
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var voice: Instrument { Instrument(rawValue: model.selectedInstrument) ?? .bassDrum }
    private var parameters: [ControlParameter] {
        switch voice {
        case .bassDrum, .cymbal: return [.level, .tone, .decay]
        case .snareDrum: return [.level, .tone, .snappy]
        case .lowTom, .midTom, .highTom: return [.level, .tuning]
        case .openHat: return [.level, .decay]
        default: return [.level]
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(0, geometry.size.width - 32)
            let wide = contentWidth >= 650 && !dynamicType.isAccessibilitySize
            ScrollView {
                VStack(alignment: .leading, spacing: wide ? 4 : 16) {
                    header(wide: wide)
                    if !wide { navigationControls }
                    instrumentGrid(columns: wide ? 12 : (dynamicType.isAccessibilitySize ? 3 : 6))
                    if wide {
                        HStack(alignment: .top, spacing: 24) {
                            voiceEditor.frame(maxWidth: .infinity, alignment: .leading)
                            tempoAndTransport.frame(width: 310)
                        }
                    } else {
                        voiceEditor
                        tempoAndTransport
                    }
                    sequenceControls(wide: wide)
                    stepGrid(width: contentWidth)
                    Text(model.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(wide ? 1 : nil)
                        .accessibilityIdentifier("machine-status")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, wide ? 6 : 10)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .background { backdrop.ignoresSafeArea() }
        }
        .foregroundStyle(Color.eightInk)
        .tint(Color.eightOrange)
        .preferredColorScheme(.dark)
        .transaction { if reduceMotion { $0.animation = nil } }
        .accessibilityIdentifier("glass-panel")
    }

    private var backdrop: some View {
        ZStack {
            Color(red: 0.055, green: 0.061, blue: 0.069)
            if !reduceTransparency {
                LinearGradient(
                    stops: [.init(color: Color.eightRed.opacity(0.14), location: 0),
                            .init(color: Color.eightOrange.opacity(0.07), location: 0.3),
                            .init(color: Color.clear, location: 0.6),
                            .init(color: Color.eightCream.opacity(0.04), location: 1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    private func header(wide: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Eight Oh Eight")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.eightInk)
                Text("RHYTHM COMPOSER")
                    .font(.caption2.weight(.medium))
                    .tracking(1.6)
                    .foregroundStyle(Color.eightOrange)
            }
            Spacer(minLength: 8)
            if wide { navigationControls }
            // The root presents the persistent skin switch in this reserved space.
            Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
        }
        .frame(minHeight: 44)
    }

    private var navigationControls: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    Picker("Mode", selection: binding(\MachineModel.mode)) {
                        ForEach(MachineMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                } label: {
                    Label(modeTitle, systemImage: "square.stack.3d.up")
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: 32)
                }
                .buttonStyle(.glass)
                .frame(minHeight: 44)
                .accessibilityIdentifier("mode-selector")
                .accessibilityValue(model.mode.title)

                Menu {
                    Section("Basic rhythms") {
                        ForEach(0..<12, id: \.self) { index in
                            Button("Basic \(index + 1)") { model.selectPattern(index) }
                        }
                    }
                    Section("Intro / fill-in") {
                        ForEach(12..<16, id: \.self) { index in
                            Button("Fill \(index - 11)") { model.selectPattern(index) }
                        }
                    }
                    Button("Rhythm memory", systemImage: "square.grid.2x2") { model.openSheet(.library) }
                } label: {
                    Text(model.patternIndex < 12 ? "Basic \(model.patternIndex + 1)" : "Fill \(model.patternIndex - 11)")
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: 32)
                }
                .buttonStyle(.glass)
                .frame(minHeight: 44)
                .accessibilityLabel("Pattern")
                .accessibilityValue(model.patternName)
                .accessibilityIdentifier("pattern-selector")

            }
        }
    }

    private var modeTitle: String {
        switch model.mode {
        case .clear: return "Clear"
        case .first, .second: return "Write"
        case .manual: return "Manual"
        case .trackPlay: return "Track"
        case .compose: return "Compose"
        }
    }

    private func instrumentGrid(columns: Int) -> some View {
        GlassEffectContainer(spacing: 4) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: 4), count: columns), spacing: 8) {
                ForEach(Instrument.allCases) { instrument in
                    instrumentChip(instrument)
                }
            }
        }
    }

    private func instrumentChip(_ instrument: Instrument) -> some View {
        let selected = instrument.rawValue == model.selectedInstrument
        let alternative = model.alternative(channel: instrument.rawValue)
        return Button {
            model.selectInstrument(instrument.rawValue)
            if !model.isPlaying { model.hit(channel: instrument.rawValue) }
        } label: {
            Text(alternative ? (instrument.alternateAbbreviation ?? instrument.abbreviation) : instrument.abbreviation)
                .font(.subheadline.weight(selected ? .bold : .medium))
                .foregroundStyle(selected ? Color(white: 0.08) : Color.eightInk)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 24)
        }
        .controlSize(.small)
        .buttonStyle(.glass(.regular.tint(selected ? Color.eightOrange : Color.clear).interactive(!reduceMotion)))
        .buttonBorderShape(.capsule)
        .frame(minWidth: 44, minHeight: 44)
        .overlay {
            if selected {
                Capsule().stroke(Color.eightInk, lineWidth: 1.2)
                    .padding(1)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(.rect)
        .accessibilityLabel(alternative ? (instrument.alternateTitle ?? instrument.title) : instrument.title)
        .accessibilityValue(selected ? "Selected" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("Select and audition this instrument.")
        .accessibilityIdentifier("instrument-\(instrument.rawValue)")
    }

    private var voiceEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Text(model.selectedName)
                        .font(.headline)
                        .lineLimit(dynamicType.isAccessibilitySize ? nil : 1)
                    Spacer(minLength: 4)
                    if let alternate = voice.alternateTitle {
                        Toggle(voice.alternateAbbreviation ?? "Alternate", isOn: Binding(
                            get: { model.alternative(channel: model.selectedInstrument) },
                            set: { if $0 != model.alternative(channel: model.selectedInstrument) { model.toggleAlternative(channel: model.selectedInstrument) } }))
                        .font(.caption.weight(.semibold))
                        .fixedSize()
                        .accessibilityLabel("\(voice.title) or \(alternate)")
                        .accessibilityIdentifier("alternate-\(model.selectedInstrument)")
                    }
                    Button { model.hit(channel: model.selectedInstrument) } label: {
                        Image(systemName: "speaker.wave.2")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(voice == .accent || !model.isPowered)
                    .accessibilityLabel("Audition \(model.selectedName)")
                    .accessibilityIdentifier("audition")
                }
                .frame(minHeight: 44)
            }
            if dynamicType.isAccessibilitySize {
                VStack(spacing: 8) {
                    ForEach(parameters, id: \.rawValue) { parameter in parameterSlider(parameter) }
                }
            } else {
                HStack(spacing: 14) {
                    ForEach(parameters, id: \.rawValue) { parameter in parameterSlider(parameter) }
                }
            }
        }
    }

    private func parameterSlider(_ parameter: ControlParameter) -> some View {
        let value = model.knobBinding(channel: model.selectedInstrument, parameter: parameter)
        let title = voice == .accent ? "Accent" : parameter.rawValue.capitalized
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title).font(.caption)
                Spacer(minLength: 4)
                Text("\(Int((value.wrappedValue * 100).rounded()))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            Slider(value: value, in: 0...1)
                .frame(minHeight: 44)
                .accessibilityLabel("\(model.selectedName) \(title)")
                .accessibilityValue("\(Int((value.wrappedValue * 100).rounded())) percent")
                .accessibilityIdentifier("knob-\(model.selectedInstrument)-\(parameter.rawValue)")
                .sensoryFeedback(.selection, trigger: Int(value.wrappedValue * 20)) { old, new in
                    model.hapticsEnabled && old != new
                }
        }
        .frame(maxWidth: .infinity)
    }

    private var tempoAndTransport: some View {
        VStack(spacing: 8) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    VStack(spacing: 0) {
                        Text("\(Int(model.state.settings.effectiveTempo.rounded()))")
                            .font(.title3.weight(.semibold).monospacedDigit())
                        Text("BPM").font(.caption2)
                    }
                    .frame(minWidth: 64, minHeight: 44)
                    .glassEffect(.regular, in: .capsule)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Current tempo")
                    .accessibilityValue("\(Int(model.state.settings.effectiveTempo.rounded())) BPM")

                    Slider(value: binding(\MachineModel.tempo), in: 40...300, step: 1)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Tempo")
                        .accessibilityValue("\(Int(model.tempo.rounded())) BPM")
                        .accessibilityIdentifier("tempo")
                        .sensoryFeedback(.selection, trigger: Int(model.tempo / 5)) { old, new in
                            model.hapticsEnabled && old != new
                        }
                    Stepper("Tempo", value: binding(\MachineModel.tempo), in: 40...300, step: 1)
                        .labelsHidden()
                        .fixedSize()
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("tempo-stepper")
                        .accessibilityValue("\(Int(model.tempo.rounded())) BPM")
                }
            }
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button(action: model.toggleTransport) {
                        Label(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                            .font(.headline)
                            .foregroundStyle(Color(white: 0.08))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color.eightYellow)
                    .frame(minHeight: 44)
                    .disabled(!model.isPowered)
                    .accessibilityLabel("Start stop")
                    .accessibilityValue(model.isPlaying ? "Playing" : "Stopped")
                    .accessibilityIdentifier("start-stop")
                    Button(action: model.tap) {
                        Label("Tap", systemImage: "hand.tap")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 32)
                    }
                    .buttonStyle(.glass)
                    .tint(model.introArmed ? Color.eightYellow : Color.eightOrange)
                    .frame(minWidth: 72, minHeight: 44)
                    .disabled(!model.isPowered)
                    .accessibilityLabel("Tap")
                    .accessibilityValue(model.introArmed ? "Intro armed" : "")
                    .accessibilityIdentifier("tap")
                }
            }
        }
    }

    private func sequenceControls(wide: Bool) -> some View {
        Group {
            if wide {
                HStack(spacing: 10) {
                    variationPicker.frame(width: 134)
                    partPicker.frame(width: 138)
                    Spacer(minLength: 0)
                    sequenceMenus
                }
            } else {
                VStack(spacing: 10) {
                    HStack(spacing: 12) { variationPicker; partPicker }
                    sequenceMenus
                }
            }
        }
        .frame(minHeight: 44)
    }

    private var variationPicker: some View {
        Picker("Basic variation", selection: binding(\MachineModel.variation)) {
            Text("A").tag(0); Text("AB").tag(1); Text("B").tag(2)
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .accessibilityIdentifier("basic-variation")
    }
    private var partPicker: some View {
        Picker("Part", selection: Binding(get: { model.mode == .second ? 1 : 0 },
                    set: { model.mode = $0 == 0 ? .first : .second })) {
            Text("Part 1").tag(0).accessibilityIdentifier("first-part")
            Text("Part 2").tag(1).accessibilityIdentifier("second-part")
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .accessibilityIdentifier("part")
    }

    private var sequenceMenus: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    Picker("Part length", selection: binding(\MachineModel.length)) {
                        ForEach(1...16, id: \.self) { Text("\($0) steps").tag($0) }
                    }
                    Toggle("Enable second part", isOn: Binding(get: { model.secondPartEnabled },
                        set: { if $0 != model.secondPartEnabled { model.toggleSecondPart() } }))
                } label: {
                    Text("\(model.length) steps").font(.subheadline).frame(minHeight: 32)
                }
                .buttonStyle(.glass)
                .frame(minHeight: 44)
                .accessibilityIdentifier("part-length")

                Menu {
                    Picker("Pre-scale", selection: binding(\MachineModel.prescale)) {
                        ForEach(Prescale.allCases) { scale in Text("\(scale.rawValue) · \(scale.label)").tag(scale.rawValue - 1) }
                    }
                } label: {
                    Text(["⅛ T", "¹⁄₁₆ T", "¹⁄₁₆", "¹⁄₃₂"][model.prescale])
                        .font(.subheadline)
                        .frame(minWidth: 32, minHeight: 32)
                }
                .buttonStyle(.glass)
                .frame(minWidth: 60, minHeight: 44)
                .accessibilityLabel("Pre-scale")
                .accessibilityIdentifier("prescale")

                Menu {
                    Picker("Fill memory", selection: Binding(get: { model.state.fillPattern },
                        set: { model.state.fillPattern = $0; model.synchronize(); model.feedback() })) {
                        ForEach(12..<16, id: \.self) { Text("Fill \($0 - 11)").tag($0) }
                    }
                    Picker("Intro and fill variation", selection: binding(\MachineModel.fillVariation)) {
                        Text("A").tag(0); Text("B").tag(1)
                    }.accessibilityIdentifier("fill-variation")
                    Picker("Auto fill-in", selection: binding(\MachineModel.autoFill)) {
                        Text("Manual").tag(0)
                        ForEach([2, 4, 8, 12, 16], id: \.self) { Text("Every \($0) measures").tag($0) }
                    }
                } label: {
                    Text("Fill \(model.state.fillPattern - 11) · \(model.fillVariation == 0 ? "A" : "B")").font(.subheadline).frame(minHeight: 32)
                }
                .buttonStyle(.glass)
                .frame(minHeight: 44)
                .accessibilityIdentifier("fill")

                Button(action: model.clear) {
                    Image(systemName: "eraser").frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Clear selected rhythm or instrument")
                .accessibilityIdentifier("clear-pattern")
            }
        }
    }

    private func stepGrid(width: CGFloat) -> some View {
        let columns = width >= 780 && !dynamicType.isAccessibilitySize ? 16 : (width >= 380 ? 8 : 4)
        return GlassEffectContainer(spacing: 4) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: 4), count: columns), spacing: 8) {
                ForEach(0..<16, id: \.self) { index in
                    stepKey(index)
                }
            }
        }
    }

    private func stepKey(_ index: Int) -> some View {
        let enabled = model.stepEnabled(index)
        let current = model.isPlaying && model.currentStep >= 0 && model.currentStep % 16 == index
        let color = stepColor(index)
        return Button { model.toggleStep(index) } label: {
            VStack(spacing: 2) {
                Text("\(index + 1)").font(.subheadline.weight(.semibold).monospacedDigit()).lineLimit(1)
                Image(systemName: current ? "circle.fill" : enabled ? "smallcircle.filled.circle" : "circle")
                    .font(.system(size: 9, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 28)
            .foregroundStyle(enabled && index >= 8 ? Color(white: 0.08) : Color.eightInk)
        }
        .controlSize(.small)
        .buttonStyle(.glass(.regular.tint(color.opacity(enabled ? 0.82 : (contrast == .increased ? 0.36 : 0.2))).interactive(!reduceMotion)))
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .frame(minWidth: 44, minHeight: 48)
        .contentShape(.rect)
        .disabled(!model.isPowered)
        .accessibilityLabel("Step \(index + 1)")
        .accessibilityValue(enabled ? "On" : "Off")
        .accessibilityHint(model.mode == .first || model.mode == .second ? "Programs this step for the selected instrument." : "Selects a rhythm or track for the current mode.")
        .accessibilityIdentifier("step-\(index + 1)")
    }

    private func stepColor(_ index: Int) -> Color {
        switch index / 4 {
        case 0: return .eightRed
        case 1: return .eightOrange
        case 2: return .eightYellow
        default: return .eightInk
        }
    }

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<MachineModel, Value>) -> Binding<Value> {
        Binding(get: { model[keyPath: keyPath] }, set: { model[keyPath: keyPath] = $0 })
    }
}
