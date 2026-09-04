# LIVE-ECONOMY-007 â€” Godot runtime onboarding

Godot 4.7.2 is now a persistent local development dependency for the OpenVic
application layer.

## Persistent resolver

`tools/resolve-openvic-runtime.ps1` resolves:

- `OPENVIC_GODOT_EXE`, pinned to Godot 4.7.2;
- `OPENVIC_VIC2_PATH`, when a valid Victoria II compatibility data install is
  available.

Godot was installed through WinGet and its resolved executable path is stored
in the user environment.

## Victoria II dependency

The current OpenVic compatibility bootstrap still requires Victoria II base
data to load a complete legacy-backed session. Steam App ID 42960 is checked
through `appmanifest_42960.acf`.

This is an external compatibility-data dependency, not a Godot dependency and
not part of the authoritative modern economy architecture.

## Real session smoke

`game/tools/live_economy_007_smoke.gd` remains the executable proof that, once
Victoria II compatibility data is available:

1. Godot instantiates the application autoloads;
2. OpenVic loads compatibility data plus the modern overlay;
3. a real InstanceManager is created;
4. the modern live economy is configured;
5. a game session starts;
6. LiveEconomyPanel becomes visible from authoritative status.

The Godot onboarding is committed independently so external proprietary base
data cannot block the development runtime itself.