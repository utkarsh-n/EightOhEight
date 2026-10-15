import SwiftUI

struct MachinePanel: View {
    let model: MachineModel
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    private let canvas = CGSize(width: 1200, height: 625)

    var body: some View {
        GeometryReader { geometry in
            let portrait = geometry.size.height > geometry.size.width
            if portrait {
                PortraitMachinePanel(model: model)
            } else {
                let fit = min(geometry.size.width / canvas.width, geometry.size.height / canvas.height)
                let scale = fit * min(2.5, max(1, zoom * pinch))
                ScrollView([.horizontal, .vertical]) {
                    OriginalFascia(model: model)
                        .frame(width: canvas.width, height: canvas.height)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: canvas.width * scale, height: canvas.height * scale, alignment: .topLeading)
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
                .simultaneousGesture(MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { zoom = min(2.5, max(1, zoom * $0.magnification)) })
                .simultaneousGesture(TapGesture(count: 2).onEnded {
                    withAnimation(.smooth(duration: 0.25)) { zoom = 1 }
                })
                .overlay(alignment: .bottomTrailing) {
                    if zoom > 1.05 {
                        Button { withAnimation(.smooth(duration: 0.25)) { zoom = 1 } } label: {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 14, weight: .medium)).padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }.accessibilityLabel("Fit complete front panel").padding(8)
                    }
                }
                .background(Color(white: 0.025))
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct OriginalFascia: View {
    let model: MachineModel
    @State private var clearHeld = false
    @State private var clearUsedForLength = false
    private let channelWidth: CGFloat = 68.5
    private let channelStart: CGFloat = 308

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 13).fill(Color.black).frame(width: 1200, height: 625)
                .shadow(color: .black.opacity(0.8), radius: 15, y: 8)
            FasciaTexture().frame(width: 1136, height: 590).clipShape(RoundedRectangle(cornerRadius: 5)).position(x: 600, y: 309)
            SideCheek().frame(width: 36, height: 625).position(x: 19, y: 312.5)
            SideCheek().frame(width: 36, height: 625).position(x: 1181, y: 312.5)
            Rectangle().fill(.white.opacity(0.13)).frame(width: 1129, height: 2).position(x: 600, y: 19)
            Rectangle().fill(.black.opacity(0.8)).frame(width: 1129, height: 11).position(x: 600, y: 613)
            PanelPrint(text: "EIGHT OH EIGHT", size: 31, color: Color.eightOrange, weight: .medium).position(x: 946, y: 62)
            PanelPrint(text: "ANALOG RHYTHM INSTRUMENT", size: 8, color: Color.eightInk.opacity(0.6)).position(x: 946, y: 87)
            powerSection.position(x: 117, y: 55)
            panelLines
            leftControls
            ForEach(0..<12, id: \.self) { channel in
                InstrumentStrip(model: model, channel: channel)
                    .frame(width: channelWidth, height: 273)
                    .position(x: channelStart + channelWidth * (CGFloat(channel) + 0.5), y: 242.5)
            }
            branding
            masterControl.position(x: 1096, y: 395)
            sequencer
            ForEach(Array(screwPoints.enumerated()), id: \.offset) { _, point in
                PanelScrew().position(point)
            }
        }
        .frame(width: 1200, height: 625)
        .opacity(model.isPowered ? 1 : 0.72)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("TR-808 rhythm composer front panel")
    }

    private var screwPoints: [CGPoint] {
        [CGPoint(x: 61, y: 35), CGPoint(x: 269, y: 35), CGPoint(x: 600, y: 35), CGPoint(x: 928, y: 35), CGPoint(x: 1138, y: 35), CGPoint(x: 61, y: 323), CGPoint(x: 1138, y: 323), CGPoint(x: 170, y: 598), CGPoint(x: 602, y: 598), CGPoint(x: 1042, y: 598), CGPoint(x: 515, y: 375), CGPoint(x: 926, y: 375)]
    }

    private var panelLines: some View {
        Canvas { context, _ in
            var borders = Path()
            borders.move(to: CGPoint(x: 96, y: 103)); borders.addLine(to: CGPoint(x: 1127, y: 103))
            borders.move(to: CGPoint(x: 96, y: 432)); borders.addLine(to: CGPoint(x: 1127, y: 432))
            borders.move(to: CGPoint(x: 308, y: 103)); borders.addLine(to: CGPoint(x: 308, y: 424))
            for index in 1...12 {
                let x = channelStart + CGFloat(index) * channelWidth
                borders.move(to: CGPoint(x: x, y: 106)); borders.addLine(to: CGPoint(x: x, y: 362))
            }
            context.stroke(borders, with: .color(Color.eightInk.opacity(0.60)), lineWidth: 1.1)
            var stripe = Path(); stripe.move(to: CGPoint(x: 315, y: 408)); stripe.addLine(to: CGPoint(x: 1017, y: 408))
            context.stroke(stripe, with: .color(Color.eightOrange), lineWidth: 1.5)
        }.allowsHitTesting(false).accessibilityHidden(true)
    }

    private var powerSection: some View {
        VStack(spacing: 0) {
            PanelPrint(text: "POWER", size: 8)
            HStack(spacing: 0) {
                HardwareToggle(isOn: model.isPowered, label: "Power", action: model.togglePower, vertical: false)
                VStack(spacing: 5) { PanelPrint(text: "ON", size: 7); PanelPrint(text: "OFF", size: 7) }
            }
        }
    }

    private var leftControls: some View {
        ZStack(alignment: .topLeading) {
            modeControl.position(x: 149, y: 170)
            instrumentSelector.position(x: 251, y: 169)
            clearKey.position(x: 149, y: 263)
            autoFillControl.position(x: 251, y: 274)
            tempoControl.position(x: 164, y: 366)
            fineControl.position(x: 267, y: 380)
        }
    }

    private var modeControl: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0).stroke(Color.eightCream.opacity(0.82), lineWidth: 1).frame(width: 103, height: 143).offset(y: 8)
            PanelPrint(text: "PATTERN WRITE", size: 8, color: Color.eightCream, weight: .semibold).padding(.horizontal, 4).background(Color.eightPanel).offset(y: -63)
            Text("2nd\nPART").font(.system(size: 7, weight: .medium, design: .rounded)).foregroundStyle(Color.eightCream).offset(x: -25, y: -39)
            Text("1st\nPART").font(.system(size: 7, weight: .medium, design: .rounded)).foregroundStyle(Color.eightCream).offset(x: -38, y: -18)
            Text("MANUAL\nPLAY").font(.system(size: 7, weight: .medium, design: .rounded)).foregroundStyle(Color.eightInk).padding(3).overlay(Rectangle().stroke(Color.eightInk.opacity(0.7), lineWidth: 0.6)).offset(x: 27, y: -39)
            PanelPrint(text: "PLAY", size: 8, color: Color.eightOrange, weight: .semibold).offset(x: 38, y: -12)
            Text("COM-\nPOSE").font(.system(size: 7, weight: .medium, design: .rounded)).foregroundStyle(Color.eightOrange).offset(x: 39, y: 10)
            TactileSelector(selection: Binding(get: { MachineMode.allCases.firstIndex(of: model.mode) ?? 3 }, set: { model.mode = MachineMode.allCases[$0] }), count: MachineMode.allCases.count, label: "Mode", diameter: 44, cap: .black, haptics: model.hapticsEnabled, labels: MachineMode.allCases.map(\.title), identifier: "mode-selector")
            PanelPrint(text: "PATTERN CLEAR", size: 7, color: Color.eightCream, weight: .semibold).padding(.horizontal, 3).background(Color.eightPanel).offset(y: 77)
        }.frame(width: 104, height: 150)
    }

    private var instrumentSelector: some View {
        ZStack {
            PanelPrint(text: "INSTRUMENT SELECT", size: 8, color: Color.eightCream, weight: .semibold).offset(y: -63)
            PanelPrint(text: "RHYTHM TRACK", size: 7, color: Color.eightOrange, weight: .semibold).padding(.horizontal, 4).padding(.vertical, 2).overlay(Rectangle().stroke(Color.eightOrange, lineWidth: 0.7)).offset(y: -48)
            ForEach(0..<12, id: \.self) { index in
                let angle = Double(index) / 12 * 2 * Double.pi + Double.pi * 0.65
                let x: CGFloat = CGFloat(cos(angle)) * 41
                let y: CGFloat = CGFloat(sin(angle)) * 44
                Text(InstrumentStrip.shortNames[index])
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.black)
                    .frame(width: 20, height: 11)
                    .background(Color.eightCream, in: RoundedRectangle(cornerRadius: 1))
                    .offset(x: x, y: y + 9)
            }
            TactileSelector(selection: Binding(get: { model.selectedInstrument }, set: { model.selectInstrument($0) }), count: 12, label: "Instrument select", diameter: 43, cap: .black, haptics: model.hapticsEnabled, labels: InstrumentStrip.names, identifier: "instrument-selector").offset(y: 9)
        }.frame(width: 105, height: 145)
    }

    private var clearKey: some View {
        VStack(spacing: 4) {
            HStack(spacing: 7) {
                Text("STEP\nNUMBER").font(.system(size: 7, weight: .medium, design: .rounded)).foregroundStyle(Color.eightCream)
                Circle().fill(Color.eightRed.gradient).frame(width: 20, height: 20)
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                    .shadow(color: .black, radius: 1, y: clearHeld ? 0 : 2)
                    .frame(width: 32, height: 34).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !clearHeld { clearUsedForLength = false; clearHeld = true }
                        }
                        .onEnded { _ in
                            clearHeld = false
                            if !clearUsedForLength { model.clear() }
                        })
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Clear selected instrument")
                    .accessibilityHint("Hold and press a step to set the pattern length.")
                    .accessibilityAction { model.clear() }
                    .accessibilityIdentifier("clear-pattern")
                Text("TRACK\nCLEAR").font(.system(size: 7, weight: .medium, design: .rounded)).foregroundStyle(Color.eightOrange)
            }
            PanelPrint(text: "PRE-SCALE", size: 7)
        }
    }

    private var autoFillControl: some View {
        ZStack {
            ForEach(Array(["MANUAL", "16", "12", "8", "4", "2"].enumerated()), id: \.offset) { index, label in
                let angle = (-225.0 + Double(index) * 54) * Double.pi / 180
                let x: CGFloat = CGFloat(cos(angle)) * 33
                let y: CGFloat = CGFloat(sin(angle)) * 33
                PanelPrint(text: label, size: 7).offset(x: x, y: y)
            }
            TactileSelector(selection: Binding(get: { [0,16,12,8,4,2].firstIndex(of: model.autoFill) ?? 0 }, set: { model.autoFill = [0,16,12,8,4,2][$0] }), count: 6, label: "Automatic fill interval", diameter: 43, cap: .black, haptics: model.hapticsEnabled, labels: ["Manual", "Every 16 bars", "Every 12 bars", "Every 8 bars", "Every 4 bars", "Every 2 bars"], identifier: "auto-fill")
            Text("MEASURES\nAUTO FILL IN").font(.system(size: 8, design: .rounded)).foregroundStyle(Color.eightInk).offset(y: 42)
        }.frame(width: 91, height: 94)
    }

    private var tempoControl: some View {
        ZStack {
            Circle().stroke(Color.eightInk.opacity(0.82), lineWidth: 10).frame(width: 103, height: 103)
            ForEach(0...10, id: \.self) { index in
                let angle = (-225.0 + Double(index) * 27) * Double.pi / 180
                let x: CGFloat = CGFloat(cos(angle)) * 52
                let y: CGFloat = CGFloat(sin(angle)) * 52
                Text(String(index)).font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(Color(white: 0.12)).offset(x: x, y: y)
            }
            TactileKnob(value: Binding(get: { (model.tempo - 40) / 260 }, set: { model.tempo = 40 + $0 * 260 }), label: "Tempo", cap: .black, diameter: 79, haptics: model.hapticsEnabled, displayValue: { "\(Int(40 + $0 * 260)) BPM" }, identifier: "tempo")
            PanelPrint(text: "TEMPO", size: 10).offset(y: -70)
        }.frame(width: 124, height: 131)
    }

    private var fineControl: some View {
        ZStack {
            TactileKnob(value: Binding(get: { model.fine }, set: { model.fine = $0 }), label: "Tempo fine adjustment", cap: .black, diameter: 31, haptics: model.hapticsEnabled, displayValue: { String(format: "%+.1f BPM", ($0 - 0.5) * 12) }, identifier: "tempo-fine")
            PanelPrint(text: "FINE", size: 8).offset(y: -31)
            PanelPrint(text: "SLOW • FAST", size: 7).offset(y: 29)
        }
    }

    private var branding: some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 25) {
                Text("Rhythm Composer").font(.system(size: 29, weight: .light, design: .rounded))
                Text("TR-808").font(.system(size: 23, weight: .medium, design: .rounded))
            }.foregroundStyle(Color.eightOrange)
            Text("Computer Controlled").font(.system(size: 14, weight: .light, design: .rounded)).foregroundStyle(Color.eightInk.opacity(0.72)).padding(.top, 4)
        }.position(x: 804, y: 393)
    }

    private var masterControl: some View {
        ZStack {
            TactileKnob(value: Binding(get: { model.master }, set: { model.master = $0 }), label: "Master volume", cap: .black, diameter: 44, haptics: model.hapticsEnabled, identifier: "master-volume")
            PanelPrint(text: "MIN        MAX", size: 7).offset(y: 30)
            PanelPrint(text: "MASTER VOLUME", size: 8).offset(y: 42)
        }.frame(width: 82, height: 93)
    }

    private var sequencer: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 2).fill(Color.eightInk.opacity(0.84)).frame(width: 133, height: 146).position(x: 162, y: 515)
            basicVariation.position(x: 162, y: 471)
            Rectangle().fill(Color(white: 0.17)).frame(width: 117, height: 0.8).position(x: 162, y: 514)
            TransportKey(title: "START\nSTOP", color: Color.eightYellow, action: model.toggleTransport).accessibilityValue(model.isPlaying ? "Playing" : "Stopped").frame(width: 80, height: 52).position(x: 162, y: 550)
            prescaleSection.position(x: 267, y: 470)
            partControls.position(x: 266, y: 549)
            rhythmNotation.frame(width: 735, height: 66).position(x: 677, y: 473)
            ForEach(0..<16, id: \.self) { index in
                let x = 330 + CGFloat(index) * 46
                PanelPrint(text: String(index + 1), size: 10, color: Color.eightCream, weight: .semibold).position(x: x, y: 513)
                TactileStepKey(index: index, enabled: model.stepEnabled(index), current: model.isPlaying && model.currentStep % 16 == index, action: {
                        if clearHeld && (model.mode == .first || model.mode == .second) {
                            model.setLength(index + 1); model.feedback(); clearUsedForLength = true
                        } else { model.toggleStep(index) }
                    })
                    .frame(width: 37, height: 54).position(x: x, y: 551)
                Text(String(index < 12 ? index + 1 : index - 11))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.08))
                    .frame(width: 41, height: 20).background(Color.eightInk.opacity(0.84)).position(x: x, y: 591)
            }
            PanelPrint(text: "BASIC RHYTHM →", size: 9, color: Color.eightInk, weight: .semibold)
                .padding(.horizontal, 3).background(Color(white: 0.19)).position(x: 235, y: 591)
            fillSection.position(x: 1089, y: 515)
        }
    }

    private var basicVariation: some View {
        VStack(spacing: 2) {
            PanelPrint(text: "BASIC VARIATION", size: 8, color: Color(white: 0.11))
            Button(action: model.cycleVariation) { switchHandle(selection: model.variation, positions: 3) }
                .buttonStyle(PhysicalPressStyle()).accessibilityLabel("Basic variation").accessibilityValue(["A", "A and B", "B"][model.variation]).accessibilityIdentifier("basic-variation")
            PanelPrint(text: "A      AB      B", size: 8, color: Color(white: 0.11))
            HStack(spacing: 19) { TinyLED(lit: model.isPowered && (model.isPlaying ? model.currentVariation == 0 : model.editingVariation == 0)); TinyLED(lit: model.isPowered && (model.isPlaying ? model.currentVariation == 1 : model.editingVariation == 1)) }
                .padding(.horizontal, 6).padding(.vertical, 2).background(Color(white: 0.13))
        }
    }

    private func switchHandle(selection: Int, positions: Int) -> some View {
        ZStack {
            Capsule().fill(Color(white: 0.08)).frame(width: 49, height: 16)
                .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 0.7))
            Capsule().fill(LinearGradient(colors: [.white, Color(white: 0.47), Color(white: 0.80)], startPoint: .leading, endPoint: .trailing)).frame(width: 8, height: 23)
                .offset(x: -16 + CGFloat(selection) / CGFloat(max(1, positions - 1)) * 32, y: -4)
                .shadow(color: .black.opacity(0.6), radius: 1, y: 2)
        }.frame(width: 64, height: 24)
    }

    private var prescaleSection: some View {
        VStack(spacing: 2) {
            PanelPrint(text: "PRE-SCALE", size: 8)
            HStack(spacing: 3) {
                Button(action: model.cyclePrescale) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 1).fill(.black).frame(width: 12, height: 48)
                        RoundedRectangle(cornerRadius: 1).fill(Color(white: 0.28)).frame(width: 11, height: 10).offset(y: -17 + CGFloat(model.prescale) * 11)
                    }.frame(width: 26, height: 50)
                }.buttonStyle(PhysicalPressStyle()).accessibilityLabel("Pre-scale").accessibilityValue(["Eighth triplets", "Sixteenth triplets", "Sixteenth notes", "Thirty-second notes"][model.prescale]).accessibilityIdentifier("prescale")
                VStack(spacing: 4) { ForEach(1...4, id: \.self) { PanelPrint(text: String($0), size: 7) } }
            }
        }
    }

    private var partControls: some View {
        VStack(spacing: 5) {
            PanelPrint(text: "STEP NO →", size: 8, color: Color(white: 0.11)).padding(.horizontal, 3).padding(.vertical, 2).background(Color.eightInk)
            Button { model.mode = .first } label: {
                VStack(spacing: 2) { TinyLED(lit: model.mode == .first || (model.isPlaying && model.currentStep < 16)); PanelPrint(text: "1st PART", size: 7) }
            }.buttonStyle(PhysicalPressStyle()).accessibilityLabel("Edit first part").accessibilityIdentifier("first-part")
            Button(action: model.toggleSecondPart) {
                VStack(spacing: 2) { TinyLED(lit: model.secondPartEnabled); PanelPrint(text: "2nd PART", size: 7) }
            }.buttonStyle(PhysicalPressStyle()).accessibilityLabel("Second part").accessibilityValue(model.secondPartEnabled ? "Enabled" : "Disabled").accessibilityIdentifier("second-part")
        }
    }

    private var rhythmNotation: some View {
        Canvas { context, size in
            let rowHeight: CGFloat = 13
            let gap: CGFloat = 3
            for row in 0..<4 {
                let subdivisions = [6, 3, 4, 2][row]
                let segment = size.width / CGFloat(subdivisions)
                for section in 0..<subdivisions {
                    let rect = CGRect(x: CGFloat(section) * segment + 2, y: CGFloat(row) * (rowHeight + gap), width: segment - 6, height: rowHeight)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Color.eightInk.opacity(0.83)))
                    let notes = row < 2 ? 3 : 2
                    for note in 0..<notes {
                        let x = rect.minX + 10 + CGFloat(note) * (rect.width - 20) / CGFloat(max(1, notes - 1))
                        let text = Text(row < 2 ? "♪" : "♩").font(.system(size: 13, weight: .medium)).foregroundColor(Color(white: 0.13))
                        context.draw(text, at: CGPoint(x: x, y: rect.midY))
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }

    private var fillSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2).fill(Color.eightInk.opacity(0.84)).frame(width: 78, height: 146)
            VStack(spacing: 5) {
                PanelPrint(text: "I/F VARIATION", size: 8, color: Color(white: 0.11))
                Button(action: model.cycleFillVariation) { switchHandle(selection: model.fillVariation, positions: 2) }
                    .buttonStyle(PhysicalPressStyle()).accessibilityLabel("Intro and fill variation").accessibilityValue(model.fillVariation == 0 ? "A" : "B").accessibilityIdentifier("fill-variation")
                PanelPrint(text: "A        B", size: 8, color: Color(white: 0.11))
                Rectangle().fill(Color(white: 0.17)).frame(width: 68, height: 0.8)
                Text("INTRO SET\nFILL IN TRIGGER").font(.system(size: 7, design: .rounded)).multilineTextAlignment(.center).foregroundStyle(Color(white: 0.11))
                TransportKey(title: "TAP", color: Color.eightYellow, action: model.tap).frame(width: 39, height: 40)
            }.offset(y: -2)
            PanelPrint(text: "← INTRO/FILL IN", size: 8, color: Color.eightInk, weight: .semibold).padding(.horizontal, 3).background(Color(white: 0.19)).offset(y: 76)
        }
    }
}

struct InstrumentStrip: View {
    let model: MachineModel
    let channel: Int
    static let names = ["Accent", "Bass Drum", "Snare Drum", "Low Tom", "Mid Tom", "Hi Tom", "Rim Shot", "Hand Clap", "Cow Bell", "Cymbal", "Open Hi Hat", "Closed Hi Hat"]
    static let shortNames = ["AC", "BD", "SD", "LT", "MT", "HT", "RS", "CP", "CB", "CY", "OH", "CH"]
    static let alternateNames = [3: "Low Conga", 4: "Mid Conga", 5: "Hi Conga", 6: "Claves", 7: "Maracas"]

    var body: some View {
        ZStack(alignment: .top) {
            PanelPrint(text: "LEVEL", size: 8).position(x: 34.25, y: 11)
            knob(.level, label: "Level", cap: Color.eightYellow).position(x: 34.25, y: 41)
            if [1,2,9].contains(channel) {
                PanelPrint(text: "TONE", size: 8).position(x: 34.25, y: 82)
                knob(.tone, label: "Tone").position(x: 34.25, y: 111)
            }
            if [3,4,5].contains(channel) {
                PanelPrint(text: "TUNING", size: 8).position(x: 34.25, y: 82)
                knob(.tuning, label: "Tuning").position(x: 34.25, y: 111)
            }
            if [1,9,10].contains(channel) {
                PanelPrint(text: "DECAY", size: 8).position(x: 34.25, y: 152)
                knob(.decay, label: "Decay").position(x: 34.25, y: 181)
            }
            if channel == 2 {
                PanelPrint(text: "SNAPPY", size: 8).position(x: 34.25, y: 152)
                knob(.snappy, label: "Snappy").position(x: 34.25, y: 181)
            }
            if let alternate = Self.alternateNames[channel] {
                Button { model.toggleAlternative(channel: channel) } label: {
                    NamePlate(name: alternate, selected: model.alternative(channel: channel))
                }.buttonStyle(PhysicalPressStyle()).frame(width: 62).position(x: 34.25, y: 177)
                    .accessibilityLabel("Select \(alternate)").accessibilityIdentifier("alternate-\(channel)")
                HardwareToggle(isOn: model.alternative(channel: channel), label: "\(Self.names[channel]) and \(alternate) switch", action: { model.toggleAlternative(channel: channel) }).position(x: 34.25, y: 213)
            }
            Button {
                model.selectInstrument(channel)
                if !model.isPlaying { model.hit(channel: channel) }
            } label: {
                NamePlate(name: Self.names[channel], selected: model.selectedInstrument == channel)
            }.buttonStyle(PhysicalPressStyle()).frame(width: 62).position(x: 34.25, y: 253)
                .accessibilityLabel(Self.names[channel])
                .accessibilityValue(model.selectedInstrument == channel ? "Selected" : "")
                .accessibilityHint("Select and audition this instrument.")
                .accessibilityIdentifier("instrument-\(channel)")
        }
        .frame(width: 68.5, height: 273)
    }

    private func knob(_ parameter: ControlParameter, label: String, cap: Color = Color.eightInk) -> some View {
        TactileKnob(value: model.knobBinding(channel: channel, parameter: parameter), label: "\(Self.names[channel]) \(label)", cap: cap, diameter: 30, haptics: model.hapticsEnabled, identifier: "knob-\(channel)-\(label.lowercased())")
    }
}
