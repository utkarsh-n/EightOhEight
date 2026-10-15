import SwiftUI

/// The full hardware layout remains the landscape instrument. The upright view
/// keeps the same controls usable while the phone is held in one hand.
struct PortraitMachinePanel: View {
    let model: MachineModel
    private var parameters: [(ControlParameter, String)] {
        switch model.selectedInstrument {
        case 1: [(.level, "LEVEL"), (.tone, "TONE"), (.decay, "DECAY")]
        case 2: [(.level, "LEVEL"), (.tone, "TONE"), (.snappy, "SNAPPY")]
        case 3...5: [(.level, "LEVEL"), (.tuning, "TUNING")]
        case 9: [(.level, "LEVEL"), (.tone, "TONE"), (.decay, "DECAY")]
        case 10: [(.level, "LEVEL"), (.decay, "DECAY")]
        default: [(.level, "LEVEL")]
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Rhythm Composer").font(.system(size: 23, weight: .light, design: .rounded)).foregroundStyle(Color.eightOrange)
                            Text("TR-808").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Color.eightInk)
                        }
                        Spacer()
                        Button { model.openSheet(.help) } label: { Image(systemName: "questionmark.circle").font(.title3).foregroundStyle(Color.eightInk) }.accessibilityLabel("Instrument guide")
                    }
                    VStack(spacing: 8) {
                        let scale = (geometry.size.width - 36) / 1200
                        OriginalFascia(model: model).frame(width: 1200, height: 625).scaleEffect(scale, anchor: .topLeading).frame(width: 1200 * scale, height: 625 * scale, alignment: .topLeading).allowsHitTesting(false).accessibilityHidden(true)
                        Label("Turn sideways for the complete front panel", systemImage: "iphone.gen3.radiowaves.left.and.right")
                            .font(.system(size: 11, design: .rounded)).foregroundStyle(Color.eightInk.opacity(0.65))
                    }
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(0..<12, id: \.self) { channel in
                                Button { model.selectInstrument(channel); model.hit(channel: channel) } label: {
                                    NamePlate(name: InstrumentStrip.shortNames[channel], selected: model.selectedInstrument == channel).frame(width: 48)
                                }.buttonStyle(PhysicalPressStyle()).frame(height: 44)
                                    .accessibilityLabel(InstrumentStrip.names[channel])
                            }
                        }
                    }.scrollIndicators(.hidden)
                    VStack(spacing: 14) {
                        NamePlate(name: InstrumentStrip.names[model.selectedInstrument], selected: true).frame(width: 160)
                        HStack(spacing: 20) {
                            ForEach(parameters, id: \.0.rawValue) { parameter, name in
                                VStack(spacing: 4) {
                                    PanelPrint(text: name, size: 10)
                                    TactileKnob(value: model.knobBinding(channel: model.selectedInstrument, parameter: parameter), label: "\(InstrumentStrip.names[model.selectedInstrument]) \(name)", cap: parameter == .level ? Color.eightYellow : Color.eightInk, diameter: 48, haptics: model.hapticsEnabled)
                                }
                            }
                        }
                        if let alternate = InstrumentStrip.alternateNames[model.selectedInstrument] {
                            HStack(spacing: 12) {
                                PanelPrint(text: alternate.uppercased(), size: 9)
                                HardwareToggle(isOn: model.alternative(channel: model.selectedInstrument), label: "Alternate voice", action: { model.toggleAlternative(channel: model.selectedInstrument) }, vertical: false)
                            }
                        }
                    }.padding(.vertical, 5)
                    HStack {
                        Text(model.patternName).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(Color.eightInk)
                        Spacer()
                        Button(action: model.cycleVariation) {
                            Text(["A", "A + B", "B"][model.variation]).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(Color.eightCream).padding(.horizontal, 12).padding(.vertical, 8).background(.black.opacity(0.3), in: Capsule())
                        }.accessibilityLabel("Basic variation")
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 8), spacing: 16) {
                        ForEach(0..<16, id: \.self) { index in
                            VStack(spacing: 5) {
                                PanelPrint(text: String(index + 1), size: 10, color: Color.eightCream)
                                TactileStepKey(index: index, enabled: model.stepEnabled(index), current: model.isPlaying && model.currentStep % 16 == index, action: { model.toggleStep(index) }).frame(height: 49)
                            }
                        }
                    }
                    HStack(spacing: 16) {
                        TransportKey(title: "START\nSTOP", color: Color.eightYellow, action: model.toggleTransport).accessibilityValue(model.isPlaying ? "Playing" : "Stopped").frame(width: 77, height: 52)
                        Spacer()
                        VStack(spacing: 0) {
                            PanelPrint(text: "TEMPO", size: 9)
                            TactileKnob(value: Binding(get: { (model.tempo - 40) / 260 }, set: { model.tempo = 40 + $0 * 260 }), label: "Tempo", cap: .black, diameter: 46, haptics: model.hapticsEnabled, displayValue: { "\(Int(40 + $0 * 260)) BPM" })
                        }
                        Spacer()
                        TransportKey(title: "TAP", color: Color.eightYellow, action: model.tap).frame(width: 49, height: 49)
                    }
                }.padding(18)
            }.background { FasciaTexture().ignoresSafeArea() }
        }
    }
}
