# Eight Oh Eight

A native, tactile iPhone recreation of the original Roland TR-808 Rhythm Composer, with three interchangeable skins sharing one sound engine and rhythm memory.

## Skins

Open **Options (•••) → Skins**, or choose a skin in Session. Your choice saves locally; switching keeps the selected voice, rhythm edits, and playback running.

- **Original 808** retains the complete researched hardware face. Pinch to zoom into its controls.
- **Studio 808** keeps the charcoal texture, cream labels, rotary knobs, and colored physical keys, arranged around the selected voice with larger touch targets. Sixteen steps fit across wider phones; smaller layouts use two rows of eight. Voice alternatives are in the Voice / Timing menu.
- **Digital 808** uses native Liquid Glass buttons, colored glass step pads, system sliders, segmented pickers, and glass transport controls. It retains the original palette and synthesis parameters. It uses the iOS 27 SDK and APIs available from iOS 26; older systems show Studio 808.

Studio is the initial skin when no preference has been saved. See [Design/SKINS.md](Design/SKINS.md) for design guidance and accessibility choices.

## Play

The machine opens in **PATTERN WRITE / 1st PART** with an editable demonstration rhythm. Press START / STOP. Choose a channel using INSTRUMENT SELECT or its printed name, then light the steps you want. Drag knobs up or down to shape the sound. The app plays through silent mode and saves your rhythms locally.

The eleven sound channels synthesize sixteen sounds: bass drum, snare, three toms or congas, rimshot or claves, handclap or maracas, cowbell, cymbal, and open / closed hi-hats. Accent emphasizes all notes on selected steps. Sound comes from oscillators, envelopes, resonators, and filtered noise rather than recorded samples.

Use MANUAL PLAY to select basic rhythms with keys 1–12 and intro / fills with keys 13–16. BASIC VARIATION selects A, AB, or B; I/F VARIATION selects fill A or B. TAP queues a fill at a measure boundary or arms an intro while stopped. AUTO FILL IN inserts fills at 2, 4, 8, 12, or 16 measure intervals.

First and second parts can each have up to sixteen steps. Session provides precise part lengths and pre-scale selection; the panel provides the original controls. COMPOSE records performed pattern choices into one of twelve tracks. Each track holds up to sixty-four measures. PLAY loops the selected track. Automatic continuation across track banks, used by the hardware for longer songs, is not implemented.

MEMORY opens the sixteen pattern slots. SESSION contains optional haptics, rhythm controls, volume, and four-bar WAV export. The original manual is linked from HELP.

## Build

Requires Xcode and XcodeGen. Run `xcodegen generate` in this folder, then build the EightOhEight scheme. The app uses automatic signing and the configured development team. Core DSP and sequencing tests run with `swift test`. The Xcode scheme includes simulator interaction tests.

See [VERIFICATION.md](VERIFICATION.md) for core and skin interaction tests, native previews, and signed iPhone installation and launch evidence.

Audio timing runs per sample in an `AVAudioSourceNode`; UI updates only display telemetry. Sound work uses preallocated render storage. Pattern changes and fills switch at rhythm boundaries. Closed hats choke open hats. A debounced atomic JSON write preserves patterns, voice parameters, and tracks.

## Research and fidelity

See [Design/RESEARCH.md](Design/RESEARCH.md) for primary Roland references and the control specification. This is an independent recreation, not a Roland product. The layout and operating rules follow the hardware; the audio is an original analog-style DSP model. It has not been measured or calibrated against an original TR-808 and does not reproduce transistor-level circuitry. Modern utilities live outside the main panel. No Roland sample recordings are included.


## Public snapshot

See [PUBLICATION.md](PUBLICATION.md) for publication exclusions and setup requirements.
