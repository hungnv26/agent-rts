# Game design plan: Outpost Meridian

Status: **proposal, nothing implemented.** This document is the plan to turn Agent RTS from
"a base you watch" into a game with stakes, built only from what the repo already contains:
the Open RTS fork (units, structures, resources, fog of war, combat, the AI player) and the
four CC0 art packs (Kenney Space Kit, KayKit Space Base Bits, Quaternius Ultimate Space Kit,
Poly Haven terrains).

The one design rule: **the AI agents stay the real workers.** Every game system below is fed
by what Hermes actually does (tokens, cost, steps, errors, approvals, web searches). The game
never asks the player to micro-manage units during a mission. The player plans the base,
chooses what to research, approves risky steps and decides how to spend what the missions
earn. The threats and the economy give those decisions weight.

---

## 1. Inventory: what we have to build with

### 1.1 Open RTS mechanics (already in `game/source/match`)

| System | What exists | Reuse |
|---|---|---|
| Units | Worker (6 HP, carries 2), Tank (10 HP, 2 dmg / 0.75 s, ground), Helicopter (10 HP, 1 dmg / 1 s, ground + air), Scout Drone (6 HP, sight 10) | Defenders, enemies and haulers |
| Structures | Command Center (20 HP), Vehicle Factory (16), Aircraft Factory (16), Anti-ground Turret (8 HP, 2 dmg, range 8), Anti-air Turret (8 HP, 2 dmg / 0.75 s, range 8) | Base defences and production |
| Resources | Blue Crystal (1 s to mine) and Red Crystal (2 s), mined from `rock_crystals` nodes; production and construction costs | The two raw materials |
| Construction | Blueprints, placement validation, HP grows with construction progress | Build mode already uses the placement rules |
| Combat | `attack_damage`, `attack_interval`, `attack_range`, `attack_domains`, projectiles, `unit_damaged` signal | Raids on the base |
| Fog of war | Per-unit `sight_range`, units vanish in fog | Already repurposed as the shroud |
| AI player | `SimpleClairvoyantAI`: Economy, Construction, Defense, Offense and Intelligence controllers plus `AutoAttackingBattlegroup` | Drives the enemy faction |
| Maps | Plain & Simple (50×50, 4 players), Big Arena (100×100, 8 players) | Multiplayer-sized arenas for later |
| Navigation | Terrain and air navmeshes | Flying enemies vs ground enemies |

### 1.2 Agent RTS layer (already in `game/source/agent` and `adapter/`)

- 7 built-in characters plus up to 24 custom ones, each a real Hermes sub-agent.
- Agent states: `thinking`, `working`, `waiting`, `approval`, `error`, `complete`, `idle`.
- Events: `agent.state`, `task.upsert`, `mission.upsert`, `approval.upsert`, `resource.update`
  (tokens, USD cost, budget), `log`, `replay`.
- Five departments on a 3×3 district grid: Command, Research, Engineering, Knowledge, Commons.
- Base of up to 32 buildings, persisted in `.data/base.json`.
- Expeditions: web research sends an agent outside the walls and uncovers the shroud.
- Ten terrains: Grassland, Sahara, Arctic, Beach, Canyon, Mars, Moon, Venus, Europa, Titan.
- Mission replay with ghost agents, mission report, fake mission source for demos.

### 1.3 Art assets we have not used yet

| Pack | Unused pieces that unlock gameplay |
|---|---|
| Quaternius | `EnemySmall`, `EnemyLarge`, `EnemyFlying` (all with `Death`, `HitReact`, `Punch`/`Headbutt`); `Spaceship_A..D`; `Rover_B`; `RoofRadar`, `RoofAntenna`; `HousePod`, `HouseOpen`; character animations `Death`, `HitReact`, `Duck`, `Shoot_Big`, `Shoot_Small`, `Run_Gun_Shoot`, `Pickup`, `Dance`, `Kick` |
| KayKit | `drill_structure`, `terrain_mining`, `spacetruck`, `spacetruck_large`, `spacetruck_trailer`, `cargo_*_packed/stacked`, `tunnel_*`, `windturbine_low`, `roofmodule_solarpanels`, `landingpad_small`, `lander_base` |
| Kenney | `craft_miner`, `craft_cargoA/B`, `craft_speederA..D`, `craft_racer`, `rocket_*`, `satelliteDish*`, `machine_generator*`, `machine_wireless*`, `weapon_gun`, `weapon_rifle`, `turret_double/single`, `gate_complex/simple`, `bones`, `meteor*`, `crater*`, `monorail_*`, `pipe_*`, `rail*`, `hangar_*`, `alien` |
| Terrains | All ten already in; they become **sectors** of a campaign map |

---

## 2. Storyline

### 2.1 Premise

**Year 2199. Outpost Meridian, a survey base on the edge of the Kepler Reach.**

Humanity's deep-space survey fleet ran on crystal: Blue Crystal powers computation and
shields, Red Crystal powers engines and weapons. Twelve years ago the survey network went
silent. The last relay, *Meridian*, kept transmitting one thing: an automated distress beacon
and a half-finished map of the Reach.

You are the new **Director** of Meridian. You arrive with a skeleton crew of seven: a mech
Commander and six specialists, astronauts and mechs. Your orders from Fleet are simple.
**Find out what happened to the survey network, map the Reach, and keep the outpost alive
long enough to report back.**

The Reach is not empty. The **Swarm** (the Quaternius enemy models) nests in the crystal
fields. They are drawn to the energy of mined crystal and to the signal of a working relay.
Every time Meridian does something useful, it gets a little louder, and the Swarm gets a
little closer.

### 2.2 The crew

| Character | Model | Role in the story |
|---|---|---|
| **Commander** | Mech_A | The outpost's AI of record. Plans every mission, delegates, writes the log. Speaks in short status lines. Afraid of nothing except an unread report. |
| **Researcher** | Astronaut_A | Field surveyor. The only one who regularly leaves the walls. Her expeditions push back the shroud and find the relics of the old network. |
| **Scout** | EnemyFlying, recoloured | A captured Swarm flyer, retrained. Fast, fragile, and the first warning of a raid. The crew doesn't fully trust it. |
| **Analyst** | Astronaut_B | Turns the Researcher's field notes into numbers. Rarely leaves the Library. Finds the patterns in the Swarm's attacks. |
| **Coder** | Mech_B | Runs the Code Factory's sandbox. Builds and repairs machines, including the turrets. |
| **Writer** | Astronaut_C | Keeps the Chronicle, the outpost's report to Fleet. The story the player reads at the end of each mission is literally her work. |
| **Reviewer** | Mech_C | Safety officer. Nothing leaves Meridian without his sign-off, and his sign-off needs yours. Waits at Human Approval. |

Custom characters the player adds become **new arrivals**: survivors picked up from other
outposts, each with a short backstory line generated from their chosen role.

### 2.3 Campaign arc: the ten sectors

The ten terrains stop being a cosmetic choice and become the **sectors of the Reach**. Each
sector is a chapter. Completing a sector's objective unlocks the next, and the base's
terrain changes because the crew physically relocates the outpost.

| # | Sector | Terrain | Chapter | Objective (mission type) | What it teaches |
|---|---|---|---|---|---|
| 1 | Landing Site | Grassland | *Arrival* | Run 1 mission, build 1 turret | Basics: missions, approval, economy |
| 2 | Dust Basin | Sahara | *First contact* | Survive 1 raid, map 40% of shroud | Raids, defence, expeditions |
| 3 | Frost Line | Arctic | *The silent relay* | Research 3 missions on one topic; find Relay Alpha | Chained missions, knowledge |
| 4 | Shoreline | Beach | *Supply run* | Keep 2 haulers alive; reach Red Crystal 200 | Economy and logistics |
| 5 | The Rift | Canyon | *Ambush* | Survive a 3-wave raid with a damaged Command Centre | Repair, prioritising |
| 6 | Red Reach | Mars | *The pattern* | Analyst mission reveals Swarm nest locations | Intelligence, the Scout |
| 7 | Dark Side | Moon | *Blackout* | A solar storm: no expeditions for 10 minutes, hold on | Resource scarcity |
| 8 | Acid Sky | Venus | *The derelict* | Recover a Spaceship wreck (Spaceship_C), repair it | Big project, many agents |
| 9 | Ice Moon | Europa | *The crystal heart* | Mine the great crystal field under constant attack | Full economy under pressure |
| 10 | Far Shore | Titan | *Report to Fleet* | Launch the rocket (Kenney `rocket_*`) with the Chronicle | Finale |

**The twist at sector 6.** The Analyst's data shows the Swarm is not hunting the crew. It is
hunting the crystal signal because the old survey network *was built from Swarm-derived
technology*. The network didn't go silent because it was destroyed. It went silent because
the last Director turned it off to stop the Swarm. The player has to decide at sector 10
whether to launch the rocket (report everything, bring Fleet back, and the Swarm with it) or
to send a doctored report (the Writer's branch). Both are endings; the mission report is
different, and the Reviewer's final approval dialog is the choice.

### 2.4 Free play

After the campaign, or at any time via a toggle, **Free play** is the current product: pick a
terrain, run missions, watch. Raids and the economy can each be switched off. Nothing in the
plan removes the "calm observatory" mode that exists today.

---

## 3. Health and damage

### 3.1 Agent health

Each agent has **HP** (uses the Open RTS `hp`/`hp_max` on `Unit.gd`) and **Stamina**.

| Character type | HP | Stamina | Notes |
|---|---|---|---|
| Astronaut (Researcher, Analyst, Writer, custom astronauts) | 6 | 100 | Open RTS Worker baseline |
| Mech (Commander, Coder, Reviewer, custom mechs) | 10 | 100 | Open RTS Tank baseline |
| Scout (flyer) | 6 | 100 | Open RTS Drone baseline |

**What damages HP:**

- Raids: Swarm melee (1 dmg per hit, `Punch`/`Headbutt`), Swarm large (2 dmg).
- Hazards on expeditions: a tile of the shroud has a 10% chance of being a hazard
  (meteor field, acid pool, crevasse, drawn with the existing `hazard.gdshader`). Walking
  through costs 1 HP. The Researcher's sight range reveals hazards before stepping on them,
  so the risk is only real in unmapped territory.
- Failed steps: an `error` state costs 1 HP. This is the only link from Hermes failure to
  damage, and it is deliberate: an agent that keeps failing is visibly worn down.

**What restores HP:** standing at the Repair Bay (1 HP / 3 s) or the Medical Pod (new
building, `HousePod`, 1 HP / 1.5 s). The `error` state already sends agents to the Repair
Bay, so repair is a thing the player sees happening without doing anything.

**At 0 HP** an agent is **downed**, not dead. It plays `Death`, lies where it fell, and
cannot take steps until a mech carries it back (`Pickup` animation on the mech). The
adapter marks the Hermes sub-agent unavailable, so the Commander must plan around it. A
mission that needs a downed specialist becomes slower or fails a step. Permanent death
exists only on **Ironman** difficulty.

**Stamina** drains 1 per 10 s while `working` and 3 per 10 s on an expedition; it refills at
home. Under 20 stamina the agent walks instead of runs and plays `Duck` on arrival. It has
no effect on the real Hermes step, only on how fast the agent gets to its building, so it
never slows the mission by more than a few seconds. It exists to make long missions look
like effort.

### 3.2 Building health

| Building | HP | Source |
|---|---|---|
| Command Centre | 40 | 2× Open RTS |
| Factories, Research Lab, Library, Code Factory | 16 | Open RTS factory |
| Turrets | 8 | Open RTS |
| Walls and gate | 12 per segment | new |
| Decor buildings (dome, houses, solar) | 10 | new |

A damaged building works at reduced rate (see economy). At 0 HP it is a **ruin**: it keeps
its footprint, shows the `bones`/`meteor_half` debris, and the agents that live there sleep
at the Rally Point until the Coder rebuilds it (a real Hermes step: the adapter injects a
"repair" task into the next mission's plan, costing crystal).

**If the Command Centre falls** the sector is lost. The crew evacuates in Spaceship_A, the
base layout is kept, and the sector restarts with the shroud reset. On Ironman the campaign
ends.

### 3.3 Enemy health

| Swarm unit | Model | HP | Damage | Speed | Domain |
|---|---|---|---|---|---|
| Drone | EnemySmall | 4 | 1 / 1.0 s | fast | air |
| Brute | EnemyLarge | 12 | 2 / 1.5 s | slow | ground |
| Wasp | EnemyFlying | 6 | 1 / 0.8 s | fast | air |
| Nest | `rock_crystalsLargeB` + `HouseOpen` recoloured | 30 | spawns | static | ground |

Turrets use the Open RTS anti-ground and anti-air split, so a mixed raid needs both. The
Anti-air Turret is the only thing that stops Wasps.

---

## 4. Economy

### 4.1 The three currencies

| Currency | Comes from | Spent on | Mirrors |
|---|---|---|---|
| **Blue Crystal** (compute) | Mined from blue nodes by haulers; **earned by completed mission steps** | Buildings, research, running missions | tokens used, inverted: work *earns* crystal |
| **Red Crystal** (power) | Mined from red nodes by haulers | Turrets, repairs, walls, vehicles | USD cost: the budget bar in `resource.update` |
| **Signal** | Grows with every mission, expedition and relay found | Nothing; it is the threat meter | Mission count |

**Why work earns crystal.** The real cost of a mission is tokens and dollars, which the
adapter already reports. Charging the player crystal for the same thing would double-count
it and punish using the product. Instead, each *completed* step pays out Blue Crystal
(2 per step, 10 per mission, doubled when the Reviewer approves on first pass) and each
expedition that reveals new shroud pays Red Crystal (1 per 5% uncovered). Failure pays
nothing. The economy rewards good missions, not expensive ones.

**Budget as hard cap.** The USD budget from `resource.update` becomes the **Power ceiling**.
When the mission's cost reaches 80% of budget, the base lights dim (existing `lights` model
and the shader's emission). At 100% the Commander stops delegating and the mission ends,
exactly as the adapter already enforces. The game just shows it.

### 4.2 Mining and logistics

- Crystal nodes (`rock_crystals`, `rock_crystalsLargeA/B`) spawn in the shroud, 6 to 10 per
  sector, visible only once mapped. Nodes deplete (blue: 60 units, red: 40 units).
- **Haulers** (KayKit `spacetruck`, Kenney `craft_miner` for the flying variant) are the
  Open RTS Worker with a new model. They need no agent; the player buys them at the Vehicle
  Factory (3 Blue). They auto-mine the nearest known node and return to a **Cargo Depot**
  (`cargodepot_A`). Capacity 2, as in Open RTS. Haulers outside the walls are raid targets.
- A **Drill** (`drill_structure` on `terrain_mining`) can be built on a node to mine it
  without haulers at half speed, safe from everything but Brutes.
- The **Monorail** (already assembled) becomes functional: a track from the depot to the
  Command Centre doubles delivery speed once built.

### 4.3 Costs (first pass, tuned later)

| Item | Blue | Red | Build time |
|---|---|---|---|
| Hauler | 3 | 0 | 3 s |
| Drill | 4 | 2 | 10 s |
| Anti-ground Turret | 2 | 2 | 6 s (Open RTS) |
| Anti-air Turret | 2 | 2 | 6 s |
| Wall segment | 1 | 0 | 2 s |
| Gate | 2 | 1 | 4 s |
| Medical Pod | 4 | 2 | 8 s |
| Radar (RoofRadar) | 3 | 3 | 8 s |
| Repair a ruined building | half its original cost | | Coder's step |
| New custom character | 8 | 4 | 1 mission (the "arrival" story step) |
| Research project | 6 to 20 | 0 | 1 real mission |

### 4.4 Research tree

Research is the bridge between the game and Hermes. A research project **is a real
mission** with a fixed title the player cannot edit, and the mission result is the
unlock's lore text. The Hermes answer is genuinely useful (it's a real web research task),
and the game gets a progression system for free.

```
Field survey I   →  Field survey II  →  Deep survey      (expedition range +25% each)
Shield lattice   →  Hardened walls   →  Dome shield      (building HP +25% each)
Turret optics    →  Twin barrels     →  Rail turret      (turret range +1, dmg +1, dmg +1)
Hauler drives    →  Convoy logic     →  Monorail         (hauler speed, two per node, track)
Triage protocol  →  Medical pod      →  Field repair     (repair rate, new building, mechs heal others)
Signal masking   →  Decoy beacon     →  Dark relay       (threat growth −20% each)
```

Each project costs Blue Crystal and one mission slot. The mission runs through the normal
agents, so the Researcher goes on an expedition for "Field survey", the Coder works for
"Turret optics", the Analyst for "Signal masking". Research reports appear in the Missions
list like any other mission.

---

## 5. Threat and raids

### 5.1 Signal

Signal is a 0 to 100 meter in the HUD, drawn as the existing radar sweep.

- +5 per mission started, +1 per expedition step, +10 per relay found, +2 per hauler trip.
- −1 per 30 s of calm, −20 when a Decoy beacon is spent.
- Radar building reveals the Signal value exactly and shows the next raid's direction 60 s
  early; without it, the player sees only Low / Medium / High.

### 5.2 Raids

A raid triggers when Signal crosses 40, 70 and 100, or on the sector's scripted beats.
Composition scales with sector number and Signal:

| Signal band | Wave | From |
|---|---|---|
| 40 | 3 Drones | nearest nest |
| 70 | 4 Drones + 1 Brute | two nests |
| 100 | 6 Drones + 2 Brutes + 3 Wasps | all nests, the Command Centre is the target |

The raid uses Open RTS's `AutoAttackingBattlegroup` with the `SimpleClairvoyantAI` Offense
controller aimed at the player's Command Centre. Enemies target, in order: haulers outside
the walls, turrets, the nearest agent, buildings. Agents inside a building are safe while
the building stands.

**The crew fights back a little.** Mechs with the "Field repair" research carry a gun
(`weapon_gun` attached to the hand bone; `Shoot_Small` animation) and deal 1 dmg at range 3
while idle at home. Astronauts never fight; they `Duck` and run inside. This keeps the focus
on building defences rather than controlling units.

**During a raid the real mission keeps running.** Hermes doesn't know about the raid. The
adapter only learns the outcome: agents downed, buildings ruined. That feeds the next plan
as unavailable sub-agents and repair tasks. Raids therefore never corrupt a running mission,
they only make the base weaker for the next one.

### 5.3 Nests

Nests spawn in the shroud at sector start, 2 to 4 per sector. Mapping one via expedition
reveals it. A revealed nest can be destroyed by a **Strike** mission: the Scout and two
haulers refitted as `craft_speederA` with `turret_single` attack it. This is the only
offensive action in the game and it is a real mission (the Scout's Hermes step is "assess
the target", the result is the strike report). Destroying every nest in a sector clears
raids for that sector and grants the sector's bonus (a Spaceship wreck to salvage: 20 Blue,
20 Red).

---

## 6. Day cycle and weather

Tied to the existing lighting (phase 2 "warmer lighting"):

- A **day** is 8 real minutes. Night lasts 2 of them. At night, sight ranges halve, Wasps
  spawn, and the base `lights` and building emission turn on. Solar panels
  (`solarpanel`, `SolarPanelStructure`, `roofmodule_solarpanels`) produce 1 Red per minute
  only in daylight; wind turbines (`windturbine_*`) produce 1 Red per 2 minutes always.
- Each sector has one **weather event** from the chapter table (dust storm on Sahara, solar
  storm on the Moon, acid rain on Venus). Weather is a cosmetic shader plus one rule
  (no expeditions / halved mining / Wasps grounded).

---

## 7. Interface changes

Everything stays on the existing HUD; nothing is modal.

| Area | Addition |
|---|---|
| Top bar | Blue, Red and Signal counters next to tokens and cost |
| Roster card | HP and Stamina bars under each character; a downed character shows a red cross |
| Building panel | HP, repair button, production queue (haulers at the Vehicle Factory) |
| Build menu | New tab "Defence" (turrets, walls, gate, radar) and "Logistics" (hauler, drill, depot, monorail track, solar, wind) |
| Missions panel | A "Research" tab with the tree; a "Strike" button on revealed nests |
| Shroud | Hazards drawn as the hazard shader; crystal nodes as glowing points; nests as red pulses |
| Mission report | A "Sector log" footer: crystal earned, damage taken, raids repelled |
| Campaign | A sector map (the ten terrains as a constellation) with the current chapter and objective; the Chronicle as a scrolling log of the Writer's reports |
| Dialog | Chapter intros and the sector-6 reveal as Commander status lines in the feed, not cutscenes |

---

## 8. Where each system lives

| System | Game (`game/source/agent`) | Adapter (`adapter/src`) | Hermes |
|---|---|---|---|
| HP, stamina, raids, enemies, turrets, mining, day cycle | **All simulation here**, built on Open RTS `Unit.gd`, `Structure.gd`, the AI controllers | Only learns outcomes | Never knows |
| Crystal income from steps, budget ceiling | Displays | **Computes** from `task.upsert` and `resource.update` | — |
| Downed agents, ruined buildings | Reports via a new `world.damage` command | Marks the sub-agent unavailable; injects repair tasks into the team list | Sees a smaller team and a repair step |
| Research tree, strikes, arrivals | Buttons | **Owns**: creates fixed-title missions, parses the result into an unlock | Runs the real mission |
| Campaign state (sector, objectives, Chronicle) | Displays the sector map | **Persists** in `.data/campaign.json` next to `base.json` | — |
| Fake source | — | Extended with raids and research so `--fake` demos the whole game | — |

The rule of the architecture doc holds: the game draws, the adapter owns state, Hermes
thinks. The only new direction of traffic is the game telling the adapter about damage,
which is one command type and one persisted dictionary.

---

## 9. Build order

Each phase is a playable state, each is shippable alone, and the current product keeps
working at every step because every system has an off switch in Settings.

| Phase | Deliverable | Depends on | Size |
|---|---|---|---|
| **A. Health** | HP and stamina on agents and buildings, hazards in the shroud, Repair Bay heals, `error` costs HP, downed state and mech pickup, `world.damage` command | nothing | 1 week |
| **B. Economy** | Blue and Red counters, crystal from steps and expeditions, nodes in the shroud, haulers, depot, drill, costs on the Build menu, solar and wind | A | 1 week |
| **C. Threat** | Signal meter, nests, raids with the three enemy types, turrets firing (Open RTS combat), walls and gate, radar, day and night | A, B | 2 weeks |
| **D. Research** | The six-track tree as fixed-title missions, unlock parsing, research tab, the Strike mission | B, C | 1 week |
| **E. Campaign** | Ten sectors with objectives, chapter intros, the Chronicle, the sector-6 reveal, two endings, Free play toggle, Ironman | A to D | 2 weeks |
| **F. Polish** | Weather events, monorail logistics, mech guns, arrival stories for custom characters, sector log in the report, balance pass on every number in this document | E | 1 week |

Total about eight weeks for one person at the pace of the git log so far. Phase A alone makes
the current product visibly more alive (worn agents, repairs, hazards on expeditions) with no
risk to missions, which is why it goes first.

---

## 10. Open decisions for you

1. **How much should raids be able to hurt a running mission?** This plan says never
   (damage only affects the *next* mission). The alternative is that a downed agent fails its
   current step. More dramatic, but a real Hermes step would be wasted.
2. **Real research missions or scripted ones?** This plan runs real Hermes missions for
   research, so each unlock costs real tokens. The alternative is scripted text from the fake
   source, free but hollow.
3. **The ending.** Two endings as written, or one? The Writer's "doctored report" branch is
   the most story-heavy piece and the most work.
4. **Difficulty.** Three settings (Calm = no raids, Standard, Ironman) or just a raid toggle?
5. **Should the Scout really be a captured Swarm flyer?** It gives the alien model a reason
   to be on the team. If it feels wrong, the Scout stays an `EnemyFlying` recolour with a
   drone backstory.

---

## 11. Asset-to-feature map (for the build phases)

| Feature | Models | Animations / shaders |
|---|---|---|
| Swarm Drone / Brute / Wasp | `EnemySmall`, `EnemyLarge`, `EnemyFlying` | `Fast_Flying`, `Run`, `Punch`, `Headbutt`, `HitReact`, `Death` |
| Nest | `rock_crystalsLargeB` + `HouseOpen` tinted | hazard shader pulse |
| Hauler (ground / air) | `spacetruck`, `spacetruck_trailer` / `craft_miner`, `craft_cargoA` | Open RTS Worker movement |
| Drill | `drill_structure`, `terrain_mining` | emission flicker |
| Cargo Depot | `cargodepot_A`, `cargo_A_stacked` grows with stock | — |
| Walls, gate | `corridor_wall`, `gate_complex`, `gate_simple`, `supports_low` | — |
| Radar | `RoofRadar` on `structure_low`, `satelliteDish_large` | rotation |
| Medical Pod | `HousePod` | — |
| Power | `solarpanel`, `SolarPanelStructure`, `windturbine_low/tall`, `machine_generatorLarge` | turbine spin |
| Strike craft | `craft_speederA` + `turret_single` | Open RTS projectile |
| Downed / pickup | — | `Death`, `Pickup`, `HitReact`, `Duck` |
| Mech guns | `weapon_gun` on hand bone | `Shoot_Small`, `Idle_Gun`, `Run_Gun_Shoot` |
| Evacuation | `Spaceship_A` | lift-off tween |
| Derelict (sector 8) | `Spaceship_C`, `bones` | — |
| Finale rocket | `rocket_baseA`, `rocket_fuelA`, `rocket_sidesA`, `rocket_finsA`, `rocket_topA` on `landingpad_large` | launch tween, existing Fx |
| Hazards | `meteor_detailed`, `crater`, `rock_crystals` | `hazard.gdshader` |
| Monorail logistics | existing composite + `monorail_track*`, `monorail_trainCargo` | existing train tween |
