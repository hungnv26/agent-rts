# Lantern Reach: story, rules and systems

Lantern Reach is a single-player real-time strategy game built on the Open RTS engine
(Godot 4). This document is the game's design: the story it tells, the rules it plays by, and
the systems that implement them. Where a rule is implemented, the file is named; where it is
planned, it says so.

---

## 1. Story

### 1.1 Premise

**Year 2241.** The generation ship *Lantern* carried forty thousand sleepers across the dark
towards a cluster of ten habitable worlds, the Reach. It never arrived whole. Something tore
it apart on the approach, and its landing pods fell across all ten worlds like sparks from a
dropped torch.

You command **Pod Seven**: one landing pod, its crew, and its **Lantern Core**, the reactor
that kept your sleepers alive and is now the heart of your base. The Core is loud. It burns
crystal and it broadcasts, and everything in the Reach that listens for light has heard it.

Two things listen.

**The Hollow** is a swarm. It nests in crystal fields, it hunts at night, and it is drawn to
the Lantern Core's signal the way moths are drawn to a flame. The Hollow did not come from the
Reach. It came with the *Lantern*: it is what tore the ship apart, and it fell with the pods.

**The Wardens** are the crew of Pod One. They landed first, they lost the most, and they drew a
conclusion: every lantern lit calls the Hollow down on everyone. They have decided the Reach
must stay dark, and that means putting your Core out.

Your objective across the campaign is simple to say. **Relight the ten worlds.** Find the
other pods, hold each world long enough to leave a working relay, recover the *Lantern*'s
core from the wreck, and on the last world light it: a beacon strong enough to bring Fleet,
and strong enough to bring whatever followed the *Lantern* across the dark.

### 1.2 The three factions

| Faction | Who | How they play | Models |
|---|---|---|---|
| **Pod Seven** (you) | Survivors of the *Lantern*: Engineers in suits, Troopers in mechs, a handful of vehicles | Classic base-building: mine, build, train, defend, attack | Quaternius astronauts and mechs, Kenney craft, Open RTS structures, KayKit base modules |
| **The Wardens** | Pod One's crew, the same technology as yours turned against you | The Open RTS AI player: expands, builds turrets, sends battlegroups | Same roster as yours, in their own colour |
| **The Hollow** | A swarm that nests in crystal | Never builds, never mines. Nests send waves that grow with time and at night. Burn out every nest and the swarm is gone | Quaternius enemy creatures: Mote, Brute, Wasp |

### 1.3 The crew

The crew are the voice of the campaign; they appear in the briefings and the Chronicle, not as
hero units.

| Name | Role in the story |
|---|---|
| **The Commander** | Pod Seven's acting captain. Writes the orders. Short sentences. |
| **The Analyst** | Reads the Hollow. Her readings on the Rift reveal that every nest in the Reach points at the *Lantern*'s wreck. |
| **The Coder** | Keeps the Core burning and cuts the ship's core free on Europa. |
| **The Writer** | Keeps the Chronicle, the log that ends each world's briefing. |
| **The Reviewer** | Asks, at every turn, whether lighting the Reach is the right call. On Titan the player answers. |

### 1.4 The ten worlds

Each world is a chapter and a match. The terrain is the world; the objective is the chapter's
beat. Data lives in `lantern-reach/source/campaign/Campaign.gd`.

| # | World | Terrain | Enemies | Objective | The chapter |
|---|---|---|---|---|---|
| 1 | Landing Site | Grassland | 1 nest | Gather 60 Lumen | Touchdown. Learn to mine and build before the nest wakes. |
| 2 | Dust Basin | Sahara | 2 nests | Survive 8 minutes | Pod Three is a crater. Hold the relay until its burst goes out. |
| 3 | Frost Line | Arctic | 2 nests | Burn out every nest | Pod Five is sealed under the ice behind the nests. |
| 4 | Shoreline | Beach | 1 Warden base, 1 nest | Destroy every enemy | First contact with the Wardens, who open with cannon fire. |
| 5 | The Rift | Canyon | 3 nests | Survive 10 minutes | The Analyst needs readings. The Hollow comes harder every minute. |
| 6 | Red Reach | Mars | 3 nests | Burn out every nest | The *Lantern*'s hull, and the truth: the Hollow came with us. |
| 7 | Dark Side | Moon | 2 Warden bases, 2 nests | Destroy every enemy | The Wardens make their stand in the dark. Only Scout Drones see at night. |
| 8 | Acid Sky | Venus | 3 nests | Gather 220 Lumen | Relighting the core takes more crystal than one world holds. |
| 9 | Ice Moon | Europa | 4 nests | Survive 12 minutes | The brightest crystal field in the Reach, and the Hollow's favourite. |
| 10 | Far Shore | Titan | 3 Warden bases, 4 nests | Destroy every enemy | The launch pad, the last Wardens, every nest left. Light it. |

Worlds unlock in order. Winning a world saves it as relit (`user://lantern_reach_campaign.cfg`).
Every world is also playable as a skirmish on any terrain with any number of Wardens and nests.

---

## 2. Rules

### 2.1 Resources

Two crystals, mined by Engineers from crystal nodes and carried back to the Lantern Core.

| Resource | Colour | Mining time per unit | Used for |
|---|---|---|---|
| **Lumen** | blue | 1 s | Everything: units, structures, and the campaign's harvest objectives |
| **Ember** | red | 2 s | Weapons and engines: Tanks, Gunships, turrets, the Hangar |

An Engineer carries 2 crystal at a time. A **Solar Array** adds 1 Lumen every 8 seconds of
daylight without an Engineer, so a base whose fields are gone can still build, slowly.

### 2.2 Units

| Unit | HP | Attack | Range | Hits | Speed | Cost (Lumen / Ember) | Time | From |
|---|---|---|---|---|---|---|---|---|
| Engineer | 6 | none | | | 2.5 | 2 / 0 | 3 s | Lantern Core |
| Scout Drone | 6 | none | | | fast, air | 2 / 0 | 3 s | Hangar |
| Trooper | 8 | 1 every 0.6 s | 4 | ground and air | 3.0 | 2 / 1 | 4 s | Mech Forge |
| Tank | 12 | 2 every 0.75 s | 5 | ground | 2.75 | 3 / 2 | 6 s | Vehicle Bay |
| Gunship | 10 | 1 every 1.0 s | 5 | ground and air | air | 1 / 3 | 6 s | Hangar |

Sight ranges: Engineer 5, Tank, Gunship and Trooper 8, Scout Drone 12.

### 2.3 Structures

| Structure | HP | Cost (Lumen / Ember) | Does |
|---|---|---|---|
| Lantern Core | 30 | 8 / 8 | Trains Engineers, receives crystal. Lose your last one and the world is lost. |
| Vehicle Bay | 16 | 6 / 0 | Builds Tanks |
| Hangar | 16 | 4 / 4 | Builds Gunships and Scout Drones |
| Mech Forge | 16 | 4 / 2 | Builds Troopers |
| Solar Array | 8 | 3 / 0 | 1 Lumen per 8 s of daylight |
| Cannon Post | 8 | 2 / 2 | 2 damage every 1.0 s at range 8, ground targets |
| Flak Post | 8 | 2 / 2 | 2 damage every 0.75 s at range 8, air targets |

Structures are placed by Engineers, cost their crystal up front, and are built at 30% per
second of Engineer time. A structure under construction has 1 HP and gains HP as it is built.

### 2.4 The Hollow

| Creature | HP | Attack | Range | Hits | Speed | Domain |
|---|---|---|---|---|---|---|
| Mote | 4 | 1 every 1.0 s | 1.6 | ground and air | 3.5 | air |
| Brute | 14 | 2 every 1.5 s | 1.8 | ground | 2.0 | ground |
| Wasp | 6 | 1 every 0.8 s | 1.6 | ground and air | 4.0 | air |
| Nest | 30 | none | | | | structure |

The Hollow player starts with its nests (one per spawn point it is given, the rest on free
spawn points) and one guard Mote per nest. Then:

- The first wave comes after **150 s ÷ difficulty**. Each later wave comes sooner: the
  interval shrinks by 8% per wave, down to **45 s ÷ difficulty**.
- Wave size is **(2 + wave number) × difficulty**, times **1.6 at night**, capped at 24.
  From wave 2 a third of the wave can be Brutes, from wave 3 a third can be Wasps, the rest
  are Motes.
- A wave forms into one battlegroup that hunts the nearest enemy unit it can reach, then the
  next, switching players when one has nothing left to attack.
- Waves come only from living nests. **Burn out every nest and the waves stop.** The Hollow
  player is out of the match when its last creature dies.

Difficulty is set per campaign world (0.6 on Landing Site, 1.8 on Far Shore). Skirmish uses 1.0.

### 2.5 Day and night

A day lasts **8 minutes**; the last **30%** is night. At night:

- The sun dims to a blue glow and the base lights are all you see.
- Every unit's sight range drops to 60%, except the Scout Drone, which sees in the dark.
- Hollow waves are 1.6× bigger.
- Solar Arrays stop producing.

### 2.6 Winning and losing

- **Destroy every enemy** (the default): the last enemy unit or structure dies. Nests count.
- **Survive**: the timer runs out while you still have units.
- **Gather Lumen**: your total mined Lumen reaches the target (refunds don't count).
- **Burn out every nest**: no Hollow nest is left standing.
- **Defeat**: you have no units or structures left.

Winning a campaign world unlocks the next one. The in-match objective bar at the top of the
screen shows the current objective, the survive countdown, the Lumen tally or the nests left,
and flashes night, dawn and each incoming wave.

---

## 3. Systems

### 3.1 Where things are

```
lantern-reach/
  project.godot                 Godot 4.3+ project, main scene source/Main.tscn
  source/
    Main.tscn, Logos            title card, then the main menu
    main-menu/                  Skirmish (Play), Campaign, Options, Credits, Loading
    campaign/
      Campaign.gd               autoload: the ten worlds, progress, match settings builder
      Objectives.gd/.tscn       objective tracking and the top-of-screen bar
    match/                      Open RTS core: Match, navigation, fog of war, HUD, handlers
      MatchConstants.gd         every number in section 2
      units/                    unit and structure scenes; Trooper, MechForge, SolarArray,
                                HollowMote/Brute/Wasp/Nest are new, Worker is the Engineer
      units/traits/CharacterAnimator.gd   plays Quaternius animations from unit state
      players/hollow/           the Hollow swarm player
      players/simple-clairvoyant-ai/      the Wardens (Open RTS AI)
    world/
      World.gd                  terrain textures, lighting, scenery, day cycle (per match)
      Terrains.gd, Scenery.gd   the ten terrain presets and the scenery around the map
  assets/                       Kenney, KayKit, Quaternius models; Poly Haven terrains; icons
  tests/manual/                 Open RTS test scenes
  tests/smoke/                  headless smoke test (see below)
```

### 3.2 Match flow

1. The main menu's **Campaign** page lists the worlds; **Skirmish** picks a map, a world
   (terrain), the players and a number of Hollow nests.
2. Both build a `MatchSettings` resource (players, terrain, objective, nests, difficulty) and
   hand it to the Loading page, which preloads every unit scene and instances `Match.tscn`.
3. `Match` spawns each player's starting units. A normal player gets a Lantern Core, a Scout
   Drone and two Engineers; a player with `spawn_initial_units()` (the Hollow) spawns its own.
4. `World` (a child of Match) swaps the map's ground material for the terrain's baked texture
   set, adds a backdrop and scenery beyond the map's edge, sets the sun and ambient light,
   and runs the day clock.
5. `Objectives` tracks the objective and emits `objective_completed`; `MatchEndHandler`
   turns that, or the last enemy dying, into victory and tells `Campaign` to save progress.

### 3.3 Signals added to Open RTS

`MatchSignals` gained `day_started`, `night_started`, `hollow_wave_started(player, size)`,
`objective_progressed(text)` and `objective_completed`. Everything else is Open RTS's own
signal set.

### 3.4 Headless smoke test

Godot can run a world without a screen and report script errors:

```
godot --headless --path lantern-reach res://tests/smoke/Smoke.tscn -- --world=basin --frames=300
godot --headless --path lantern-reach res://tests/smoke/Smoke.tscn -- --world=basin --frames=500 --time-scale=60 --difficulty=3
godot --headless --path lantern-reach res://tests/smoke/Smoke.tscn -- --world=landing --objective=survive:2
```

The second reaches the Hollow's waves and the night in seconds; the third wins the world and
writes the campaign save.

---

## 4. What is built and what is next

Built and smoke-tested headless (not yet played with a screen in this pass):

- The three factions, the full roster above, the Hollow waves, nests and battlegroups.
- Day and night with its effects on sight, waves and solar income.
- The ten worlds, their objectives, briefings and saved progress; the campaign and skirmish
  pages; the objective bar.
- The ten terrains applied to the match map with scenery and a backdrop.
- Animated characters (Engineer, Trooper, the Hollow) with a death animation.

Next, in order of value:

1. **Play it.** Facing of the Quaternius models (rotated 180° on the assumption they face +Z),
   scales, camera distance and turret ranges all need a real screen.
2. **Balance.** Every number in section 2 is a first pass.
3. **Wardens with Troopers.** The Open RTS AI builds Tanks and Gunships only; teaching it the
   Mech Forge makes world 4 and world 7 feel like fighting your own crew.
4. **Hollow nest growth.** Nests that spawn a new nest after N waves, so a passive player
   loses ground.
5. **The Titan choice.** The Reviewer's final question as a real decision with two endings.
6. **Sound.** Open RTS's voice lines remain; the Hollow needs its own.
