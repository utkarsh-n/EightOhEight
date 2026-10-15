# Original TR-808 research

This private iPhone recreation takes the original TR-808 panel and operating rules as its reference. Digital synthesis can reproduce its voice principles; matching a particular physical unit would require audio measurements and component-level calibration.

## Sources

- [Roland original owner's manual](https://cdn.roland.com/assets/media/pdf/TR-808_OM.pdf): printed pages 2-5, 11-20.
- [Roland original specifications](https://support.roland.com/hc/en-us/articles/201963539-TR-808-Technical-Specifications).
- [Roland original service notes, June 15, 1981](https://www.florian-anwander.de/roland_tr808/roland_TR-808_service-manual.pdf): printed pages 5-6; archived scan of Roland's document.
- [Roland historical panel photograph](https://static.roland.com/promos/global_events/808day_2019/images/tr-808_sequencer.jpg), linked from [Roland's history](https://www.roland.com/global/promos/roland_tr-808/).
- [Complete original panel photograph](https://commons.wikimedia.org/wiki/File:Roland_TR-808_(large).jpg): Brandon Daniel; crop by Clusternote; [CC BY-SA 2.0](https://creativecommons.org/licenses/by-sa/2.0/). Used for visual inspection, not bundled as application art.
- [Roland TR-08 specifications](https://www.roland.com/global/products/tr-08/) distinguish later features from the original.

## Panel and voices

Columns run AC, BD, SD, LT/LC, MT/MC, HT/HC, RS/CL, CP/MA, CB, CY, OH, CH. The five paired voices share their physical channel and programmed lane. Every sound channel has level; Accent controls the common emphasis. Bass Drum adds tone/decay, Snare tone/snappy, each Tom/Conga tuning, Cymbal tone/decay, Open Hat decay. Closed Hat, Cowbell, Rim/Claves and Clap/Maracas have no further front-panel sound controls.

The dark panel uses cream voice labels and orange machine lettering. Level knobs have colored caps; other sound controls have pale caps. Step keys form four groups: red 1-4, orange 5-8, yellow 9-12, cream 13-16. The left controls comprise Mode, Instrument/Track, Clear, Tempo, Fine and Auto Fill; transport and Basic Variation sit below. I/F Variation and Tap occupy the right edge. There is no original digital tempo display.

## Original operating rules

Mode positions clockwise: Pattern Clear, Write 1st Part, Write 2nd Part, Manual Play, Track Play, Compose.

Manual Play keys 1-12 select basic rhythms; 13-16 select intro/fill rhythms. Basic A/AB/B plays A, alternating A then B, or B. I/F has A/B only. Changes wait for the measure boundary. Tap stopped arms a one-shot intro; Tap playing schedules a fill next measure, returning to basic afterward. Auto-fill counts 2/4/8/12/16 measures, excluding the intro.

Write keys toggle the selected instrument; Tap enters that instrument in real time. Pre-scale 1/2/3/4 divides a quarter into 3/6/4/8 steps. Clear plus a key specifies part length. A/B share corresponding lengths and scales. Clear resets first part to 16 and second to zero; enabled parts concatenate and may have unequal lengths. Clear affects the chosen variation; AB clears both.

Instrument/Track chooses the song track in Play/Compose. Compose records performed pattern choices by measure. Variation is applied live during playback, rather than saved with each track measure. Tracks hold 64 measures and may continue into the next track. Printed page 20 also describes different scales across first/second parts.

## Analog voice principles

Service notes describe damped bridged-T resonators for drum bodies, snare resonator mixing plus noise, pitched tom resonators with a noise tail, and a cleaner conga selection. Clap combines repeated noise transients with reverberation; maracas gate white noise. Cowbell filters two square oscillators. Cymbal and hats share a six-square-oscillator metallic source. A closed-hat trigger terminates the open-hat envelope.

Memory is 12 basic and four intro/fill positions, each A/B, with up to 32 steps; 12 tracks provide 768 measures. Tempo spans 40-300 quarter notes per minute.

## Fidelity boundary

Haptics, a readable status strip, accessibility, local persistence and WAV sharing are phone conveniences. Swing, flams, substeps, extra pitch controls, pan, gain and compression belong to later recreations and are excluded from the original face. The physical instrument's size and mechanical travel cannot be duplicated by a phone screen.

The current implementation loops each of twelve separate 64-measure tracks. It does not yet continue automatically across track banks for a 768-measure song. Voice models follow the synthesis principles above but are not a component-by-component electrical simulation or a measured match to a particular original unit.
