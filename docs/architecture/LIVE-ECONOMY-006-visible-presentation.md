# LIVE-ECONOMY-006 â€” Visible economy presentation

This slice makes the OpenVic-Simulation live economy visible in the OpenVic/Godot application. Its
`InstanceManager` ownership is part of the intended native-engine authority convergence. The
existing Victoria-backed session used to demonstrate this slice is a compatibility path, not the
target native bootstrap.

## Boundary

The UI remains presentation-only:

```text
LiveEconomyRuntime / InstanceManager
             â†“
GameSingleton::get_live_economy_status()
             â†“
Godot Dictionary snapshot
             â†“
LiveEconomyPanel
```

The panel owns no simulation state and issues no economy commands.

## Visible status

The compact session overlay displays:

- completed daily economy ticks;
- upstream primary-steel output;
- desired and actual industrial-machinery output;
- whether downstream production is input-limited;
- source and destination intermediate inventories;
- final machinery inventory;
- corridor bottleneck capacity;
- currently deliverable intermediate quantity;
- intermediate market price;
- prior-day supply, demand, and traded quantity.

## Lifecycle

`LiveEconomyPanel.gd` is an application autoload. It subscribes to
`GameSingleton.gamestate_updated` and hides itself whenever no live modern
economy is configured.

The autoload is presentation infrastructure, not an authoritative runtime.

## Why this is intentionally small

This is the first legibility slice, not the final economy UI. It proves that a
real user-facing Godot surface can observe the modern runtime while preserving
the engine/application boundary.

Future economy UI should graduate from this diagnostic overlay into normal
country/industry/market views rather than making this debug panel permanent.
