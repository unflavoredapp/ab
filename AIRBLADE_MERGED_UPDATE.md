# AIRBLADE merged update

This archive consolidates the source files from the available AIRBLADE lobby UI, physics foundation, match HUD, and match UI follow-up patches into the full `project-airblade.zip` source tree.

Included:
- AIRBLADE/GunZ-inspired lobby UI updates and floating navigation changes.
- Shared movement tuning in `Sources/AirbladePhysics.swift`.
- Updated `Sources/TacMap.swift` from the physics patch.
- Latest available `Sources/Tactical.swift` and `Sources/TacBodycam.swift` from the match UI follow-up patch (these supersede earlier patch versions).
- All original project assets, resources, tests, and build workflow files retained.

Validation status: this merged archive has not been built with Xcode or tested on an iPhone. Run the existing CI workflow before treating it as buildable. Review compiler output carefully, especially cross-file integration between movement, match HUD, and existing game state.
