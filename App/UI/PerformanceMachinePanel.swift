import SwiftUI

/// A phone-sized studio desk: the selected voice gets full-size hardware controls,
/// while transport, rhythm memory, and every step stay directly within reach.
struct PerformanceMachinePanel: View {
    let model: MachineModel
    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 11

    var body: some View {
        GeometryReader { geometry in
            let wideSteps = geometry.size.width >= 780
            let landscape = geometry.size.width >= 600
            ScrollView(.vertical) {
                VStack(spacing: 4) {
                    header(compact: !landscape)
                    voicePads
                    if landscape {
                        HStack(alignment: .center, spacing: 12) {
                            voiceEditor.frame(maxWidth: .infinity, alignment: .leading)
                            transportDesk
                        }
                    } else {
                        voiceEditor
                        transportDesk.frame(maxWidth: .infinity)
                    }
                    controlStrip(compact: !landscape)
                    stepBank(wide: wideSteps)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height, alignment: .center)
            }
            .scrollIndicators(.hidden)
            .background { FasciaTexture() }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("studio-panel")
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("EIGHT OH EIGHT")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.eightOrange)
                Text("STUDIO")
                    .font(.system(size: labelSize, weight: .semibold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Color.eightInk.opacity(0.65))
            }
            Spacer(minLength: 0)
            utilityButton("Rhythm memory", symbol: "square.grid.2x2", sheet: .library)
            if !compact {
                utilityButton("Rhythm tracks", symbol: "list.bullet.rectangle", sheet: .track)
                utilityButton("Play the machine", symbol: "questionmark.circle", sheet: .help)
            }
            utilityButton("Session", symbol: "slider.horizontal.3", sheet: .settings)
            Button(action: model.togglePower) {
                HStack(spacing: 5) {
                    Image(systemName: "power").font(.system(size: 15, weight: .medium))
                    TinyLED(lit: model.isPowered, diameter: 6)
                }
                .foregroundStyle(Color.eightInk)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(PhysicalPressStyle())
            .accessibilityLabel("Power")
            .accessibilityValue(model.isPowered ? "On" : "Off")
            .accessibilityIdentifier("power")
            // The root's shared skin and instrument options occupy this slot.
            Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
        }
        .frame(height: 44)
    }

    private func utilityButton(_ title: String, symbol: String, sheet: MachineSheet) -> some View {
        Button { model.openSheet(sheet) } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.eightInk.opacity(0.82))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(PhysicalPressStyle())
        .accessibilityLabel(title)
        .accessibilityIdentifier("studio-\(sheet.rawValue)")
    }

    private var voicePads: some View {
        GeometryReader { geometry in
            let canFit = geometry.size.width >= 561
            if canFit {
                HStack(spacing: 3) {
                    ForEach(0..<12, id: \.self) { voicePad($0) }
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 3) {
                        ForEach(0..<12, id: \.self) { voicePad($0).frame(width: 48) }
                    }
                }.scrollIndicators(.hidden)
            }
        }
        .frame(height: 44)
    }

    private func voicePad(_ channel: Int) -> some View {
        let selected = model.selectedInstrument == channel
        return Button {
            model.selectInstrument(channel)
            if !model.isPlaying { model.hit(channel: channel) }
        } label: {
            VStack(spacing: 3) {
                Text(InstrumentStrip.shortNames[channel])
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Capsule()
                    .fill(selected ? Color.eightOrange : Color.eightInk.opacity(0.15))
                    .frame(width: 13, height: 2)
            }
            .foregroundStyle(selected ? Color(white: 0.08) : Color.eightInk)
            .frame(maxWidth: .infinity)
            .frame(minWidth: 44, minHeight: 44)
            .background(selected ? Color.eightCream : Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.eightInk.opacity(selected ? 0.45 : 0.14), lineWidth: 0.6))
        }
        .buttonStyle(PhysicalPressStyle())
        .accessibilityLabel(InstrumentStrip.names[channel])
        .accessibilityValue(selected ? "Selected" : "")
        .accessibilityHint("Select and audition this instrument.")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("instrument-\(channel)")
    }

    private var selectedName: String {
        if model.alternative(channel: model.selectedInstrument),
           let name = InstrumentStrip.alternateNames[model.selectedInstrument] { return name }
        return InstrumentStrip.names[model.selectedInstrument]
    }

    private var voiceParameters: [(ControlParameter, String)] {
        switch model.selectedInstrument {
        case 1: [(.level, "LEVEL"), (.tone, "TONE"), (.decay, "DECAY")]
        case 2: [(.level, "LEVEL"), (.tone, "TONE"), (.snappy, "SNAPPY")]
        case 3...5: [(.level, "LEVEL"), (.tuning, "TUNING")]
        case 9: [(.level, "LEVEL"), (.tone, "TONE"), (.decay, "DECAY")]
        case 10: [(.level, "LEVEL"), (.decay, "DECAY")]
        default: [(.level, "LEVEL")]
        }
    }

    private var voiceEditor: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(selectedName)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.eightCream)
                Spacer(minLength: 0)
            }
            HStack(spacing: 14) {
                ForEach(voiceParameters, id: \.0.rawValue) { parameter, title in
                    VStack(spacing: 1) {
                        Text(title).font(.system(size: labelSize, weight: .medium, design: .rounded)).foregroundStyle(Color.eightInk.opacity(0.8))
                        TactileKnob(
                            value: model.knobBinding(channel: model.selectedInstrument, parameter: parameter),
                            label: "\(selectedName) \(title.capitalized)",
                            cap: parameter == .level ? Color.eightYellow : Color.eightInk,
                            diameter: 44,
                            haptics: model.hapticsEnabled,
                            identifier: "knob-\(model.selectedInstrument)-\(title.lowercased())")
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(minHeight: 112)
        .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.eightInk.opacity(0.10), lineWidth: 0.6))
    }

    private var transportDesk: some View {
        HStack(spacing: 7) {
            VStack(spacing: 0) {
                smallPrint("TEMPO")
                TactileKnob(
                    value: Binding(get: { (model.tempo - 40) / 260 }, set: { model.tempo = 40 + $0 * 260 }),
                    label: "Tempo", cap: Color.black, diameter: 40,
                    haptics: model.hapticsEnabled,
                    displayValue: { "\(Int(40 + $0 * 260)) BPM" }, identifier: "tempo")
                Text("\(Int(model.tempo)) BPM")
                    .font(.system(size: labelSize, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.eightCream)
            }
            VStack(spacing: 0) {
                smallPrint("MASTER")
                TactileKnob(value: Binding(get: { model.master }, set: { model.master = $0 }), label: "Master volume", cap: Color.black, diameter: 40, haptics: model.hapticsEnabled, identifier: "master-volume")
                Text("\(Int(model.master * 100))")
                    .font(.system(size: labelSize, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.eightCream)
            }
            VStack(spacing: 5) {
                HStack(spacing: 7) {
                    TransportKey(title: "START\nSTOP", color: Color.eightYellow, action: model.toggleTransport)
                        .frame(width: 72, height: 50)
                        .accessibilityValue(model.isPlaying ? "Playing" : "Stopped")
                    TransportKey(title: "TAP", color: Color.eightYellow, action: model.tap).frame(width: 44, height: 44)
                }
                HStack(spacing: 5) {
                    TinyLED(lit: model.isPlaying, diameter: 6)
                    Text(model.isPlaying ? "RUNNING" : "READY")
                        .font(.system(size: labelSize, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.eightInk.opacity(0.7))
                }
                fineMenu
            }
        }
        .frame(minHeight: 112)
    }

    private var fineMenu: some View {
        Menu {
            Button("Increase by 0.1 BPM") { model.fine = min(1, model.fine + 0.1 / 12) }
            Button("Decrease by 0.1 BPM") { model.fine = max(0, model.fine - 0.1 / 12) }
            Divider()
            ForEach([-6.0, -3, -1, 0, 1, 3, 6], id: \.self) { offset in
                Button(String(format: "%+.0f BPM", offset)) { model.fine = offset / 12 + 0.5 }
            }
        } label: {
            Text(String(format: "FINE %+.1f", (model.fine - 0.5) * 12))
                .font(.system(size: labelSize, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.eightInk.opacity(0.75))
                .frame(minWidth: 90, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Tempo fine adjustment")
        .accessibilityValue(String(format: "%+.1f BPM", (model.fine - 0.5) * 12))
        .accessibilityIdentifier("tempo-fine")
    }

    @ViewBuilder
    private func controlStrip(compact: Bool) -> some View {
        if compact {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                modeMenu; patternMenu; variationMenu; partMenu; timingMenu; clearButton
            }
        } else {
            HStack(spacing: 5) {
                modeMenu; patternMenu; variationMenu; partMenu; timingMenu; clearButton
            }
        }
    }

    private var modeMenu: some View {
        Menu {
            ForEach(MachineMode.allCases) { mode in
                Button { model.mode = mode; model.feedback() } label: {
                    if model.mode == mode { Label(mode.title, systemImage: "checkmark") }
                    else { Text(mode.title) }
                }
            }
        } label: {
            deskControl(["CLEAR", "WRITE 1", "WRITE 2", "MANUAL", "TRACK", "COMPOSE"][model.mode.rawValue], caption: "MODE", symbol: "dial.low")
        }
        .accessibilityLabel("Mode")
        .accessibilityValue(model.mode.title)
        .accessibilityIdentifier("mode-selector")
    }

    private var patternMenu: some View {
        Menu {
            ForEach(0..<16, id: \.self) { index in
                Button(index < 12 ? "Basic rhythm \(index + 1)" : "Intro / fill \(index - 11)") { model.selectPattern(index) }
            }
        } label: {
            deskControl(model.patternIndex < 12 ? "BASIC \(model.patternIndex + 1)" : "FILL \(model.patternIndex - 11)", caption: "MEMORY", symbol: "square.grid.2x2")
        }
        .accessibilityLabel("Pattern")
        .accessibilityValue(model.patternName)
        .accessibilityIdentifier("pattern-selector")
    }

    private var variationMenu: some View {
        Menu {
            Button("A") { model.variation = 0 }
            Button("A + B") { model.variation = 1 }
            Button("B") { model.variation = 2 }
            if model.variation == 1 {
                Divider()
                Button("Edit variation A") { model.editingVariation = 0; model.feedback() }
                Button("Edit variation B") { model.editingVariation = 1; model.feedback() }
            }
        } label: {
            deskControl(["A", "A + B", "B"][model.variation], caption: "VARIATION", symbol: "arrow.triangle.2.circlepath")
        }
        .accessibilityLabel("Basic variation")
        .accessibilityValue(["A", "A and B", "B"][model.variation])
        .accessibilityIdentifier("basic-variation")
    }

    private var partMenu: some View {
        Menu {
            Button("Edit first part") { model.mode = .first; model.feedback() }
            Button("Edit second part") { model.mode = .second; model.feedback() }
            Button(model.secondPartEnabled ? "Disable second part" : "Enable second part") { model.toggleSecondPart() }
            Menu("Part length: \(model.length) steps") {
                ForEach(1...16, id: \.self) { length in
                    Button("\(length) steps") { model.setLength(length); model.feedback() }
                }
            }
        } label: {
            deskControl(model.mode == .second ? "2nd · \(model.length)" : "1st · \(model.length)", caption: "PART/LENGTH", symbol: "rectangle.split.2x1")
        }
        .accessibilityLabel("Pattern part and length")
        .accessibilityValue("\(model.mode == .second ? "Second" : "First") part, \(model.length) steps")
        .accessibilityIdentifier("part-selector")
    }

    private var timingMenu: some View {
        Menu {
            if let alternate = InstrumentStrip.alternateNames[model.selectedInstrument] {
                Menu("Voice: \(selectedName)") {
                    Button(InstrumentStrip.names[model.selectedInstrument]) {
                        if model.alternative(channel: model.selectedInstrument) { model.toggleAlternative(channel: model.selectedInstrument) }
                    }
                    Button(alternate) {
                        if !model.alternative(channel: model.selectedInstrument) { model.toggleAlternative(channel: model.selectedInstrument) }
                    }
                }
                .accessibilityLabel("Alternate voice")
                .accessibilityValue(selectedName)
                .accessibilityIdentifier("alternate-\(model.selectedInstrument)")
                Divider()
            }
            Menu("Pre-scale") {
                ForEach(0..<4, id: \.self) { scale in
                    Button(["Eighth triplets", "Sixteenth triplets", "Sixteenth notes", "Thirty-second notes"][scale]) { model.prescale = scale; model.feedback() }
                }
            }
            Menu("Auto fill") {
                ForEach([0, 16, 12, 8, 4, 2], id: \.self) { interval in
                    Button(interval == 0 ? "Manual" : "Every \(interval) measures") { model.autoFill = interval; model.feedback() }
                }
            }
            Menu("Intro / fill variation") {
                Button("A") { model.fillVariation = 0 }
                Button("B") { model.fillVariation = 1 }
            }
        } label: {
            deskControl(["1/8 T", "1/16 T", "1/16", "1/32"][model.prescale], caption: InstrumentStrip.alternateNames[model.selectedInstrument] == nil ? "TIMING" : "VOICE / TIME", symbol: "metronome")
        }
        .accessibilityLabel("Pre-scale and fills")
        .accessibilityValue(["Eighth triplets", "Sixteenth triplets", "Sixteenth notes", "Thirty-second notes"][model.prescale])
        .accessibilityIdentifier("timing-selector")
    }

    private var clearButton: some View {
        Button(action: model.clear) {
            deskControl("CLEAR", caption: model.mode == .compose ? "TRACK" : model.mode == .clear ? "PATTERN" : "VOICE", symbol: "delete.left", destructive: true)
        }
        .buttonStyle(PhysicalPressStyle())
        .accessibilityLabel("Clear selected instrument")
        .accessibilityHint("Clears this voice. In Pattern Clear mode it clears the selected pattern.")
        .accessibilityIdentifier("clear-pattern")
    }

    private func deskControl(_ title: String, caption: String, symbol: String, destructive: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 12, weight: .medium))
                .foregroundStyle(destructive ? Color.eightOrange : Color.eightCream)
            VStack(alignment: .leading, spacing: 2) {
                Text(caption).font(.system(size: labelSize, weight: .regular, design: .monospaced)).foregroundStyle(Color.eightInk.opacity(0.55)).lineLimit(1)
                Text(title).font(.system(size: labelSize, weight: .semibold, design: .rounded)).foregroundStyle(Color.eightInk)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Color.black.opacity(0.27), in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.eightInk.opacity(0.15), lineWidth: 0.6))
        .contentShape(Rectangle())
    }

    private func stepBank(wide: Bool) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: wide ? 3 : 7), count: wide ? 16 : 8), spacing: 8) {
            ForEach(0..<16, id: \.self) { index in
                VStack(spacing: 4) {
                    if wide {
                        Text(String(index + 1))
                            .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.eightCream.opacity(index < model.length ? 1 : 0.35))
                    }
                    TactileStepKey(index: index, enabled: model.stepEnabled(index), current: model.isPlaying && model.currentStep % 16 == index, action: { model.toggleStep(index) })
                        .frame(minWidth: 44, minHeight: 44)
                        .overlay(alignment: .bottom) {
                            if !wide {
                                Text(String(index + 1))
                                    .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.black.opacity(0.82))
                                    .padding(.bottom, 5)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                            }
                        }
                        .opacity(index < model.length || model.mode == .manual || model.mode == .clear || model.mode == .compose ? 1 : 0.35)
                }
            }
        }
        .padding(.top, 2)
    }

    private func smallPrint(_ text: String) -> some View {
        Text(text).font(.system(size: labelSize, weight: .medium, design: .rounded)).foregroundStyle(Color.eightInk.opacity(0.7))
    }
}
