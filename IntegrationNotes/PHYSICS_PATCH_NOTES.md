# AIRBLADE physics foundation update

This changed-files batch introduces the first shared physics tuning layer and height-aware horizontal collision for the current tactical movement prototype.

## Changed files

- `Sources/AirbladePhysics.swift` — centralized movement constants for player radius/height, gravity, jump impulse, wall-jump impulse, wall-run timing/speed, wall probes and lockout.
- `Sources/TacMap.swift` — `TMap.push(_:_:height:)` now uses wall/door height and approximate prop height to avoid treating every obstacle as infinitely tall while the character is above it. Map bounds remain solid.
- `Sources/Tactical.swift` — player jump/wall-run movement uses the shared tuning constants and passes the current vertical height into collision resolution.

## What this improves

- The movement prototype can now clear wall/prop collision when the player's feet rise above the obstacle's configured approximate height.
- The jump and wall-run values are centralized for tuning.
- Existing callers of `TMap.push(_: :)` remain source-compatible because `height` defaults to zero.

## Known limitations (not yet a complete 3D physics engine)

- The world still uses 2D map coordinates plus a separate player vertical offset.
- Elevated platforms, multi-level floor collision, landing on rooftops/catwalks, and vertical navmesh support still need explicit world geometry and floor/landing data.
- Swept collision for high-speed movement is not yet implemented; a sufficiently large movement step may tunnel through thin obstacles.
- Enemy vertical state and player-versus-player hit height are not yet fully unified with this player's vertical state.
- Prop heights are approximations from the current map data.

## Validation

The source changes have not been compiled or tested in an iOS runtime in this environment. Run the existing GitHub Actions workflow and test on-device before treating this as verified gameplay.
