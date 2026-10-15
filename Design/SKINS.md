# Eight Oh Eight skins

All three skins present the same `MachineModel`, rhythm memory, original voice parameters, and audio engine. A skin changes presentation. Switching skins preserves the selected voice, A/B notes, tempo, and running transport; the preference saves on the phone.

## Original 808

Retain the researched hardware panel for its complete spatial layout and historical controls. The full-panel fit necessarily produces small controls on a phone; pinch zoom and the existing focused portrait layout remain available. The additional skins are the comfortable phone interfaces.

## Studio 808

Keep the charcoal instrument, warm cream labels, orange accents, and the red/orange/yellow/cream step groups. Reorganize around the editing task: select a voice, shape only that voice's sound, and edit its 16 steps. Larger rotary controls retain vertical drag and precise numeric feedback. Separate pattern, variation, part, and timing choices prevent the original panel's tiny legends from carrying the whole interaction.

Voice and step keys, transport, TAP, and Options have at least 44 × 44 point targets. Steps use one row when sixteen keys fit comfortably and two rows of eight on narrower screens. Their ordered color groups remain recognizable. This applies Apple's [touch-target and layout guidance](https://developer.apple.com/design/tips/).

## Digital 808

Use system typography, native sliders, pickers, menus, and buttons in a dark workspace with warm 808 accents and system secondary labels. The native skin follows iOS 27's system appearance using the available SwiftUI Liquid Glass APIs, introduced in iOS 26. On earlier systems, the Skins menu disables Digital; any previously selected Digital skin displays Studio instead.

The step matrix and voice parameters are the content. Keep their backing surfaces opaque or standard material. Reserve Liquid Glass for a distinct transport/navigation layer and native interactive controls, avoiding glass surfaces nested inside glass surfaces. Apple distinguishes this functional layer from content and recommends restrained custom effects in its [Materials guidance](https://developer.apple.com/design/human-interface-guidelines/materials). Use native glass styles and a shared `GlassEffectContainer` for related custom glass controls, following [SwiftUI's custom glass documentation](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views).

Use color for the active step, selected voice, and primary transport action. Keep other glass control backgrounds neutral; Apple's [color guidance](https://developer.apple.com/design/human-interface-guidelines/color) recommends selective emphasis. Numbers, selection outlines/icons, and accessible On/Off or Playing/Stopped values communicate state alongside color, following Apple's [accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility).

## Review and verification

Skin tests launch deterministic factory rhythm state, verify the 12 voice targets and 16 step targets remain visible and tappable in landscape, check the 44 point target floor, edit a note, operate transport, and adjust a native voice slider. Studio's mode, pattern, variation, part, timing, clear, and fine-tempo controls receive the same target checks. Digital's mode, pattern, length, pre-scale, fill, clear, and audition controls also receive them. UIKit controls submenu row dimensions; those rows are checked for existence, tappability, and successful selection instead of an app-owned frame size. Native skin-menu rows are located by their visible titles. A separate test switches through all skins while playback runs and checks the edited note remains present. Studio and Digital screenshots attach to the test result for visual review.

Source review must check system accessibility adaptations: larger text can scroll rather than clip; native materials respond to Reduce Transparency; Reduce Motion suppresses decorative motion; selected controls and step state have meaningful labels and values. These review items are distinct from a full on-device VoiceOver audit and measured color-contrast certification.

### Verified on October 10, 2026

Tested on the existing Nano Studio simulator, iPhone 17 Pro with iOS 27.0. All four Original interaction cases passed in the baseline run. Following native button sizing fixes, Studio passed in 47.102 seconds, live skin switching passed in 50.296 seconds, and Digital passed its final expanded check in 61.050 seconds. The final Digital run exited successfully with a complete XCTest result bundle. The earlier failing runs' case logs retain the other pass evidence; their verbose diagnostic collection was stopped after the cases finished.

The 44 point checks apply to app-owned targets, with a half-point allowance for frame rounding. UIKit's native menu rows are checked by actual selection and tappability. Visible menu titles are used where UIKit does not export SwiftUI identifiers. The skin-switch test preserves both an edited note and Playing state through Digital, Original, and Studio.

Complete, unmodified runtime captures are saved as `studio-simulator-runtime.png` and `digital-simulator-runtime.png`. Their pixels are portrait-oriented with the full landscape interface turned sideways. XCTest's app-only screenshots were cropped by the simulator capture path, so they were replaced with full `simctl` screen captures. No generated visuals are used for this verification.

The final Digital foreground-color pass was rebuilt and launched successfully on the same simulator. Visual inspection confirms dark labels on the selected orange voice chip, yellow Play control, and enabled yellow or cream steps. The updated complete Digital capture records this change. Geometry, accessibility values, and behavior remain covered by the preceding interaction tests; this final color-only pass did not repeat them.
