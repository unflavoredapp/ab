AIRBLADE MATCH UI FOLLOW-UP

Changed files:
- Sources/TacBodycam.swift
  - Adds a compact, translucent top-right kill feed using the engine's existing e.feed records.
  - Restyles the weapon/ammo switch panel into a floating bottom-right weapon card, with ammo/reload state and tap-to-swap behavior.
- Sources/Tactical.swift
  - Moves the weapon card to the bottom-right without replacing the current touch controls.
  - Adds a compact final standings table to the existing match result screen, sorted by actual kills and showing player name, kills, and alive/down status.
  - Keeps the existing in-match AirbladeScoreboard overlay and existing result reward/exit flow.

Validation:
- Both changed Swift files passed `swiftc -frontend -parse` in this environment.
- A complete Xcode build and on-device gameplay test have not been run.
- No fabricated ping, deaths, or damage statistics were added because the current player model does not track those values.

Apply these files over the matching files from the previous AIRBLADE match HUD patch / project source.
