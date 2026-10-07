# Lantern Reach (Godot project)

The game itself. Open it with Godot 4.3 or newer:

```bash
godot --path .        # play
godot --path . -e     # edit
```

What's where:

- `source/main-menu/` title, Campaign, Skirmish, Options, Credits
- `source/campaign/` the ten worlds, saved progress, in-match objectives
- `source/match/` the Open RTS core (match, navigation, fog of war, HUD, AI player) and
  every unit; new here: Trooper, Mech Forge, Solar Array, the Hollow creatures, nest and
  swarm player, animated characters
- `source/world/` terrain texture sets, lighting, scenery, day and night
- `tests/manual/` Open RTS test scenes, `tests/smoke/` a headless smoke test

The story, rules and numbers are in [`../docs/design.md`](../docs/design.md).

## Built on Open RTS

This project started as a fork of [Open RTS](https://github.com/lampe-games/godot-open-rts)
by Pawel Lampe (Lampe Games), MIT, which provides the RTS engine: units, structures,
resources, navigation, fog of war, the HUD and the AI player. The original licence is in
`LICENSE`. Open RTS's own README and changelog are kept in `CHANGELOG.md` for the engine's
history. The Lampe Games logo is not included: it is all rights reserved and not for use in
derived projects.

Code style follows Open RTS: `make lint` and `make format-check` (gdlint, gdformat).
