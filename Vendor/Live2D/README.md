# Joi Cubism Runtime

Joi Map uses Live2D Cubism SDK for Native 5 R5 with the Metal renderer. The
checked-in XCFramework is generated from the official SDK package and exposes
only `JoiCubismView` to Swift.

Rebuild after downloading the official SDK and accepting its licenses:

```bash
scripts/build_live2d_runtime.sh /path/to/CubismSdkForNative-5-r.5
```

The build script combines the redistributable iOS Cubism Core library, the
open Cubism Native Framework, and the Joi-specific Objective-C++ bridge. The
original licenses and notices are kept next to this document.

## Current character pack

The checked-in Joi pack currently contains only the compiled model, texture,
and display metadata. It does not yet provide Cubism motions, expressions,
physics, or pose data. The runtime therefore supplies restrained procedural
idle movement, blinking, gaze, mood parameters, and TTS lip sync as a stable
fallback.

When the finished character pack is available, keep the existing SwiftUI and
TTS integration and replace the contents of `AIGuide/Resources/JoiCharacter`.
Then extend `JoiCubismModel` to load the pack's `Motions`, `Expressions`,
`Physics`, and `Pose` entries from `joi.model3.json`. The renderer calculates
drawable bounds at runtime, so ordinary canvas-padding changes do not require
new avatar framing constants.

This Joi-specific runtime currently supports the Cubism 5.2-compatible normal,
additive, and multiplicative blend modes used by the model. It intentionally
rejects packs that require Cubism 5.3 advanced blend modes instead of rendering
them incorrectly.
