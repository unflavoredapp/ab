# AIRBLADE lobby UI replacement

This patch replaces the BattleCam-style lobby presentation with a landscape AIRBLADE / GunZ-inspired hideout interface.

## Files
- `Sources/TacLobbyRef.swift`: replaces the main lobby HUD with AIRBLADE branding, floating transparent top navigation, MRZEFV-compatible profile card, currency/level/EXP panel, left promo and clan panels, Quick Start, mode/map/difficulty selectors, and character-slot shortcuts.
- `Sources/TacBodycamLobby.swift`: replaces the former bodycam/battlefield procedural backdrop with a dark industrial hideout backdrop (rainy window/city lights, evidence board, weapon rack, workbench, crates, floor and warm lamps). Existing call sites retain `BodycamBackdrop` for source compatibility; the view itself no longer draws a bodycam-themed battlefield.
- `Sources/TacShell.swift`: changes shared lobby accent colors to blue and keeps AIRBLADE branding for secondary pages.
- `Sources/TacRank.swift`: default local username is now `mrzefv` for fresh installs; an existing saved username remains unchanged.
- `Sources/TacCamoLab.swift`: removes the stale BattleCam label from an error message.

## Integration
Copy these files over the matching paths in the project. The main lobby still routes through existing `LobbyAct` actions and existing character preview, mode/map selection, avatar, loadout and season screens.

## Validation
Swift parser check passed for the changed Swift source files using `swiftc -frontend -parse`. This is not an iOS/Xcode build; compile and test with the project's normal Xcode/GitHub Actions workflow.
