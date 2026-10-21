AIRBLADE MATCH HUD PATCH

Files changed:
- Sources/TacBodycam.swift: replaced the bodycam-style health readout with a compact translucent AIRBLADE HP/armor HUD and added AirbladeScoreboard.
- Sources/Tactical.swift: added a floating top-center timer/kills/scoreboard button and overlay presentation state.

Scoreboard columns are based on real current engine fields: player handle/name, team relationship, kills, and alive/down status. It intentionally does not invent deaths, ping, or damage values because those are not currently tracked per player in TPlayer.

Validation: source edits were applied to project-airblade.zip. No Xcode/iOS build or on-device gameplay test was run in this environment.
