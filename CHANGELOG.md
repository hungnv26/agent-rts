# Changelog

## Lantern Reach 0.1.0

The project becomes a standalone game. Everything below this section is Open RTS's own
history, kept for the engine.

### New
 - Story and campaign: ten worlds (one per terrain), each with a briefing, enemies and an
   objective (destroy all, survive, gather Lumen, burn out nests); progress is saved
 - The Hollow: a swarm player with nests that send growing waves (Mote, Brute, Wasp),
   bigger at night; burn out every nest to stop them
 - Day and night: an 8-minute day, shorter sight at night (Scout Drones excepted), solar
   income only by day
 - Units and structures: Engineer (animated astronaut), Trooper and the Mech Forge,
   Solar Array; Lantern Core, Vehicle Bay, Hangar, Cannon Post and Flak Post are the
   renamed Open RTS structures
 - Worlds: the ten Poly Haven terrains on any map, with scenery and a backdrop beyond
   the map edge
 - Skirmish page: pick a world and a number of Hollow nests
 - Headless smoke test (tests/smoke)

### Changed
 - Project renamed; main scene is the title card and menu
 - Translations are English only
 - Match end handling and the start-up logos are on again

### Removed
 - The AI-agent world (Hermes Synapse, Mission Control and the adapter) and everything
   bound to it
 - The Lampe Games logo (all rights reserved, not for derived projects)

## [main]

### New features
 - Added structure rally points

### Changed
 - Godot 4.1 support added instead of Godot 4.0 (4.0 support is still present on branch)

## [0.9.0]

### New features
 - Added 'loading page' translations
 - Added ability to use custom maps
 - Added 2 new maps
 - Added match setup page

### Changed
 - Performed various refactorings
 - Simplified turret's rotation algorithm
 - Removed redundant unit groups
 - Extracted generic `MouseClickAnimation`
 - Improved `assert()` calls
 - Renamed `buildings` to - more generic - `structures`
 - Made `SimpleClairvoyantAI` being able to attach units in runtime

## [0.8.1]

### New features
 - Added resource tooltips
 - Added unit production/construction tooltips
 - Added main menu background
 - Added match loading page
 - Added diagnostic FPS monitor

### Changed
 - Increased units HP by a factor of 2

## [0.8.0]

### New features
 - Added animated logo sequence on startup
 - Added basic main menu with options etc.
 - Added match with hardcoded map and features such as:
   - Settings
   - Isometric 3D camera
   - Fog of war
   - Terrain/Air navigation
   - Units & structures
   - Resources (blue/red crystals)
   - UI (unit selection mechanism)
   - HUD (resource counters, unit management panels)
   - Menu
   - Dynamically created human/AI players
   - Debug utilities (God mode etc.)
