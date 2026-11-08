# Linux release stage-picker focus workaround

The first current diagnostic pack passed all 212 probe assertions but was rejected
because opening/closing the stage picker logged nonexistent/duplicate `focus_entered`
and `tree_exited` connections on the root window. The error gate was not loosened.

A reduced probe on the same official Linux release runtime and unchanged pack opens
and selects the picker three times on each map:

| Diagnostic change | Result |
| --- | --- |
| original picker | stage selections work, engine focus errors reproduce |
| force root to embed subwindows | same errors; rejected hypothesis |
| force the picker native, keep viewport-directed keys | no focus errors, stage selection fails; rejected input adapter |
| native picker, keys addressed to its actual window id | all stage selections and checks pass, no engine errors, Quit 0 |

These are labelled diagnostic property overrides, not final-pack acceptance. Logs,
probe sources and frozen runtime/pack hashes are in outer
`checkpoints/spillway/r14/popup-diagnosis/`; the original full rejection remains in
`delivery-takeover/current-diagnostic.log`. The retained scripts reproduce the reduction.

The product now requests a native stage-picker popup only on Linux release templates
when subwindows are supported. Editor, headless and other platforms retain their
defaults. The packed verifier sends ordinary key events with the popup's actual
`window_id`, matching how display events reach a native subwindow. It still checks the
selected stage, authored pose, practice status and clean R restart. No movement, record
key, geometry or timing rule changes.

The symptom matches Godot's [reported release OptionButton issue](https://github.com/godotengine/godot/issues/89657).
The downloaded 4.7.2 [Popup implementation](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/gui/popup.cpp)
connects these parent signals on its embedded path. This evidence supports avoiding
that path; it does not isolate the compiler-level cause discussed in the issue.
The documented [Window.force_native](https://docs.godotengine.org/en/4.7/classes/class_window.html#class-window-property-force-native)
is the scoped workaround. Final acceptance requires the unmodified production popup
in a fresh export, not merely the successful diagnostic override.
