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

## Compatibility-session dependency

The current OpenVic compatibility bootstrap still requires Victoria II base
data to load a complete legacy-backed session. Steam App ID 42960 is checked
through `appmanifest_42960.acf`.

This is an external compatibility-data dependency, not a Godot dependency and not a dependency of
the target native engine. Godot onboarding succeeded independently; the non-Victoria
OpenVic-Simulation bootstrap remains separate, unfinished convergence work.

## Real session smoke

`game/tools/live_economy_007_smoke.gd` remains an inherited compatibility-session proof that, once
Victoria II compatibility data is available:

1. Godot instantiates the application autoloads;
2. OpenVic loads compatibility data plus the modern overlay;
3. a real InstanceManager is created;
4. the modern live economy is configured;
5. a game session starts;
6. LiveEconomyPanel becomes visible from authoritative status.

The Godot onboarding is committed independently so external proprietary base
data cannot block the development runtime itself.

This smoke test remains useful migration coverage, but it does not prove the final native startup
architecture. That proof requires a future OpenVic-Simulation bootstrap which loads the project's
own rulesets/content and creates its authoritative session without Victoria II. Victoria III is
reference material only and is not a runtime dependency.
