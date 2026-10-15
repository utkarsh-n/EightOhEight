import SwiftUI
import RhythmCore

struct MachineRoot: View {
    @Bindable var model: MachineModel
    @Environment(\.scenePhase) private var phase

    var body: some View {
        skinPanel
            .background(Color(red: 0.045, green: 0.045, blue: 0.04))
            .overlay(alignment: .topTrailing) {
                InstrumentOptionsButton(model: model).padding(6)
            }
            .sheet(item: $model.sheet) { destination in
                if destination == .export, let url = model.exportURL {
                    ShareRhythm(url: url)
                } else {
                    MachineUtilitySheet(model: model, destination: destination)
                        .presentationDetents([.large])
                }
            }
            .onChange(of: phase) { _, newPhase in
                if newPhase != .active { model.saveNow() }
            }
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    @ViewBuilder private var skinPanel: some View {
        switch model.skin {
        case .original: MachinePanel(model: model)
        case .studio: PerformanceMachinePanel(model: model)
        case .glass:
            if #available(iOS 26.0, *) { GlassMachinePanel(model: model) }
            else { PerformanceMachinePanel(model: model) }
        }
    }
}

struct InstrumentOptionsButton: View {
    let model: MachineModel
    private var supportsGlass: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    @ViewBuilder var body: some View {
        if #available(iOS 26.0, *), model.skin == .glass {
            menu
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        } else {
            menu.buttonStyle(.plain)
        }
    }

    private var menu: some View {
        Menu {
            Menu("Skins", systemImage: "paintpalette") {
                ForEach(MachineSkin.allCases) { skin in
                    Button {
                        model.skin = skin
                    } label: {
                        Label(skin.title, systemImage: model.skin == skin ? "checkmark" : skin.symbol)
                    }
                    .disabled(skin == .glass && !supportsGlass)
                    .accessibilityIdentifier("skin-\(skin.rawValue)")
                    .accessibilityValue(model.skin == skin ? "Selected" : "")
                }
            }
            Button("Rhythm memory", systemImage: "square.grid.2x2") { model.openSheet(.library) }
            Button("Rhythm tracks", systemImage: "list.bullet.rectangle") { model.openSheet(.track) }
            Button("Play the machine", systemImage: "questionmark.circle") { model.openSheet(.help) }
            Button("Session", systemImage: "slider.horizontal.3") { model.openSheet(.settings) }
            if model.skin == .glass {
                Button("Export four bars", systemImage: "square.and.arrow.up") { model.export() }
                    .disabled(model.exporting)
                Button(model.isPowered ? "Power off" : "Power on", systemImage: "power") { model.togglePower() }
            }
        } label: {
            optionsLabel
        }
        .accessibilityLabel("Instrument options")
        .accessibilityIdentifier("machine-options")
    }

    @ViewBuilder private var optionsLabel: some View {
        if #available(iOS 26.0, *), model.skin == .glass {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
        } else {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.eightInk)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct MachineUtilitySheet: View {
    @Bindable var model: MachineModel
    let destination: MachineSheet
    @Environment(\.dismiss) private var dismiss
    private let orange = Color(red: 0.98, green: 0.36, blue: 0.16)

    var title: String {
        switch destination {
        case .library: return "Rhythm memory"
        case .help: return "Play the machine"
        case .settings: return "Session"
        case .track: return "Rhythm tracks"
        case .export: return "Export"
        }
    }
    var body: some View {
        NavigationStack {
            Group {
                switch destination {
                case .library: library
                case .help: help
                case .settings: settings
                case .track: tracks
                case .export: Text("Preparing WAV…")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .tint(orange)
        }
    }
    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("12 BASIC RHYTHMS  /  4 INTRO & FILL-INS")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                    ForEach(0..<16, id: \.self) { index in
                        Button {
                            model.state.selectedPattern = index
                            model.mode = .first
                            model.synchronize()
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(index < 12 ? String(format: "%02d", index + 1) : "F\(index - 11)")
                                        .font(.system(.title2, design: .monospaced).bold())
                                    Spacer()
                                    if model.patternIndex == index { Image(systemName: "checkmark.circle.fill") }
                                }
                                Text(index < 12 ? "Basic rhythm" : "Intro / fill-in").font(.caption)
                                HStack(spacing: 3) {
                                    ForEach(0..<16, id: \.self) { step in
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(patternHasHit(index: index, step: step) ? orange : Color.gray.opacity(0.25))
                                            .frame(height: 12)
                                    }
                                }
                                Text("A + B · \(model.state.pattern(for: index, variation: .a).firstPartLength) steps")
                                    .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(model.patternIndex == index ? orange.opacity(0.15) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                    }
                }
                Text("Edits save automatically on this phone. A and B hold separate notes and share their length and pre-scale, like the original.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(24)
        }
    }
    private func patternHasHit(index: Int, step: Int) -> Bool {
        let p = model.state.pattern(for: index, variation: .a)
        return Instrument.allCases.filter { $0 != .accent }.contains { p.hit($0, step: step) }
    }
    private var settings: some View {
        Form {
            Section("Skin") {
                Picker("Instrument skin", selection: $model.skin) {
                    ForEach(MachineSkin.allCases) { skin in
                        Text(skin.title).tag(skin)
                    }
                }
                Text(model.skin.detail).font(.footnote).foregroundStyle(.secondary)
            }
            Section("Touch") {
                Toggle("Control haptics", isOn: $model.hapticsEnabled)
                Text(model.skin == .glass
                     ? "Use the native sliders to shape each voice. The colored pads program steps; the play control starts your rhythm."
                     : model.skin == .studio
                     ? "Select a voice to reveal its enlarged knobs. Drag a knob vertically to turn it. The colored keys program steps."
                     : "Drag a knob vertically for precise adjustment. Pinch the panel to get closer; double-tap empty panel space to fit it again.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Rhythm") {
                HStack { Text("Tempo"); Slider(value: $model.tempo, in: 40...300, step: 1); Text("\(Int(model.tempo)) BPM").monospacedDigit() }
                Picker("Pre-scale", selection: $model.prescale) {
                    Text("1 · Eighth triplet").tag(0)
                    Text("2 · Sixteenth triplet").tag(1)
                    Text("3 · Sixteenth").tag(2)
                    Text("4 · Thirty-second").tag(3)
                }
                Stepper("\(model.mode == .second ? "Second" : "First") part: \(model.length) steps", value: $model.length, in: 1...16)
                Toggle("Enable second part", isOn: Binding(get: { model.secondPartEnabled }, set: { _ in model.toggleSecondPart() }))
                Picker("Auto fill-in", selection: $model.autoFill) {
                    Text("Manual").tag(0)
                    ForEach([2, 4, 8, 12, 16], id: \.self) { Text("Every \($0) measures").tag($0) }
                }
            }
            Section("Output") {
                HStack { Text("Master volume"); Slider(value: $model.master); Text("\(Int(model.master * 100))%").monospacedDigit() }
                Button(model.exporting ? "Rendering…" : "Export four bars as WAV") { dismiss(); model.export() }.disabled(model.exporting)
                Text("Synthesized locally with oscillators, envelopes, and filtered noise. Use headphones to hear the low bass. Silent mode does not mute the instrument.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Memory") {
                Button("Load factory rhythms", role: .destructive) { model.loadDemo() }
            }
        }
    }
    private var help: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                guide("00", "Choose your instrument skin", "Open the options button and choose Skins. Original 808 shows the complete hardware face. Studio 808 enlarges the selected voice's controls for your phone. Digital 808 uses native Liquid Glass pads, sliders, and transport controls. Your rhythms and playback continue across skin changes.")
                guide("01", "Write a rhythm", "Turn MODE to 1st PART. Turn INSTRUMENT / TRACK to a voice, then press the colored steps. START / STOP plays the loop. Select another voice to add its steps while the rhythm runs.")
                guide("02", "Shape the sound", "Drag a knob up or down. LEVEL sets each voice's volume. TONE, DECAY, TUNING, and SNAPPY follow the original channel controls. The five switches swap toms for congas, rimshot for claves, and handclap for maracas.")
                guide("03", "Accent and second part", "Select AC and light a step to emphasize every voice playing there. MODE 2nd PART edits the rest of a rhythm up to 32 steps. Set the length of each part in Session, or hold CLEAR and press its final step.")
                guide("04", "Play A / B and fills", "MANUAL PLAY makes the first 12 keys choose basic rhythms and the last four choose a fill. BASIC VARIATION selects A, AB, or B. TAP queues a fill for the next measure; while stopped, it arms an intro. AUTO FILL-IN adds fills at the selected measure interval.")
                guide("05", "Tap and clear", "In PATTERN WRITE, TAP auditions the selected voice and records at the current step when running. CLEAR erases that voice. PATTERN CLEAR + CLEAR erases the chosen variation; AB clears both. Your edits save automatically.")
                guide("06", "Compose a track", "Turn MODE to COMPOSE and select a track with INSTRUMENT / TRACK. Press START, then choose rhythms with the colored keys. Each performed measure is written to the track. Use TRACK to view or remove measures. PLAY runs the selected track; a track holds up to 64 measures.")
                Link("Original Roland TR-808 owner's manual", destination: URL(string: "https://cdn.roland.com/assets/media/pdf/TR-808_OM.pdf")!)
                Text("Eight Oh Eight is an independent recreation for personal use. The layout follows the original TR-808. The sound is an original digital model of analog drum synthesis; it has not been calibrated against an original unit.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(24)
        }
    }
    private func guide(_ number: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number).font(.system(.title3, design: .monospaced).bold()).foregroundStyle(orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private var tracks: some View {
        Form {
            Section {
                Picker("Track memory", selection: Binding(get: { model.state.selectedTrack }, set: { model.state.selectedTrack = $0; model.synchronize() })) {
                    ForEach(0..<12, id: \.self) { Text("Track \($0 + 1)").tag($0) }
                }
                HStack {
                    Button("Compose") { model.mode = .compose; dismiss() }
                    Spacer()
                    Button("Play track") { model.mode = .trackPlay; if !model.isPlaying { model.toggleTransport() }; dismiss() }
                }
            }
            Section("\(model.state.tracks[model.state.selectedTrack].count) / 64 measures") {
                if model.state.tracks[model.state.selectedTrack].isEmpty {
                    Text("Turn MODE to COMPOSE, press START, then perform pattern changes with the rhythm keys.").foregroundStyle(.secondary)
                }
                ForEach(Array(model.state.tracks[model.state.selectedTrack].enumerated()), id: \.offset) { item in
                    HStack {
                        Text(String(format: "%02d", item.offset + 1)).monospacedDigit().foregroundStyle(.secondary)
                        Text(item.element.pattern < 12 ? "Basic \(item.element.pattern + 1)" : "Fill \(item.element.pattern - 11)")
                        Text(item.element.variation == .a ? "A" : "B").foregroundStyle(orange)
                        Spacer()
                        Button { model.removeTrackMeasure(item.offset) } label: { Image(systemName: "minus.circle") }
                    }
                }
            }
        }
    }
}

struct ShareRhythm: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
