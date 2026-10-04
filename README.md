# Agent RTS

**A strategy-game interface for orchestrating AI agents.**

Give a mission and watch a team of seven AI agents carry it out on the map. Every vehicle
is a real Hermes agent, and everything that lights up or moves reflects real work:

| Agent (vehicle) | Real job in Hermes |
|---|---|
| Commander (cargo ship) | the orchestrator: plans, coordinates each step, writes the final synthesis |
| Researcher (rover) | deep research: searches the web and reads sources |
| Scout (speeder) | quick scan of the latest news |
| Analyst (miner) | extracts facts, numbers and trends |
| Coder (speeder) | runs code in the sandbox (calculations, charts) |
| Writer (speeder) | drafts the report from the findings |
| Reviewer (racer) | checks the result, then waits at Human Approval for your sign-off |

The base sits on the Martian sand of the original Open RTS, kept deliberately plain: no
neon, no moving lights. Agents drive along dirt roads to the building that matches their
tool (Research Lab, Code Factory, Knowledge Library), and each building's label says who is
working inside. A failed step sends the agent to the striped Repair Bay, agents blocked on
others wait in the painted Rally Point ring, and Human Approval reads "Waiting for you"
when you're needed. Every mission, step, agent
status and cost is mirrored into Mission Control for the operational view.

![The Reviewer waits at Human Approval](docs/screenshots/human-approval.png)

The game is the interface; the work is real. It is built from three open-source projects that
stay loosely coupled through one small adapter:

| Layer | Project | Role |
|---|---|---|
| Visual world | [lampe-games/godot-open-rts](https://github.com/lampe-games/godot-open-rts) (MIT), forked into `game/` | The map, units, movement, selection, minimap |
| Agent brain | [pauloberezini/hermes-synapse](https://github.com/pauloberezini/hermes-synapse) (MIT) | An orchestrator that plans and delegates to sub-agents, with web search and a code sandbox |
| Operations | [builderz-labs/mission-control](https://github.com/builderz-labs/mission-control) (MIT) | Tasks, agents, cost tracking, activity feed, approvals |
| Glue | `adapter/` (this repo) | Translates Hermes ⇄ the world contract ⇄ Mission Control |

See [docs/architecture.md](docs/architecture.md) for how it fits together and
[docs/phase0-findings.md](docs/phase0-findings.md) for what we learned about each foundation.

## Quick start (macOS, Apple Silicon)

```bash
scripts/setup.sh      # once: fetch pinned foundations, local model, images, deps (~10 min)
scripts/start.sh      # Hermes + Mission Control + adapter, then opens the game
```

Type a mission into the command bar (e.g. *Research the Australian EV market*) and press
**Deploy**. When the Reviewer walks to Human Approval, click **Approve** (or click the Human
Approval building). When the mission ends, a short replay plays (holographic agents re-run
the mission at high speed) and then the report opens. Click **View report** to skip
ahead, or **▶ Replay** in the report to watch it again.

- **Mission Control:** http://127.0.0.1:3000. The login is in `.env` (`MC_ADMIN_USER` / `MC_ADMIN_PASS`).
  Pending approvals appear as tasks in *review*; approving one there approves it in the game.
- **Demo mode without any LLM:** `scripts/start.sh --fake` plays scripted missions that use every
  agent state.
- **Stop:** `scripts/stop.sh`.

Prerequisites: Docker (Colima with 6 GB is enough), Node 23.6+ (the adapter runs TypeScript
natively), pnpm, Godot 4.4+ (`brew install --cask godot`) and Ollama.

### Settings

**Settings** (top right) changes display mode (window or fullscreen), window resolution
(1280×720 up to 3840×2160 / 4K), 3D render resolution (50–100%, lower is faster on 4K/5K
screens), anti-aliasing, menu text size (70–120%), map label size (names above characters and buildings, 30–80%), and map zoom. Changes apply immediately and are saved for next time
(`~/Library/Application Support/Godot/app_userdata/Agent RTS/agent_rts_settings.cfg`).

### Controls

| | |
|---|---|
| Pan | WASD or screen edges |
| Zoom | Mouse wheel |
| Select an agent | Click it, or click its card in the roster (centres the camera) |
| Approve | The dialog, or click the Human Approval building |
| Abort a mission | **Abort** next to Deploy |

| Agents at work | Mission replay (ghost agents + timeline) | Mission complete, with a sourced report |
|---|---|---|
| ![](docs/screenshots/agents-working.png) | ![](docs/screenshots/mission-replay.png) | ![](docs/screenshots/mission-complete.png) |

## Models

The default is fully local and free: `agentrts-qwen3` (Qwen3 4B instruct with a 16K context)
on Ollama. A mission takes 2–5 minutes on an M1 Pro. Small local models give rough reports, and
Hermes skips its final synthesis when a model call times out (45 s per call). For better
results, point Hermes at any OpenAI-compatible endpoint in `infra/hermes.env`:

```bash
LLM_API_BASE=https://openrouter.ai/api/v1
OPENROUTER_API_KEY=sk-or-...
LLM_MODEL=anthropic/claude-haiku-4.5   # and the AGENT_MODEL_* / LLM_FALLBACK_MODEL lines
```

Then run `scripts/stop.sh && scripts/start.sh`. Set `ADAPTER_COST_BUDGET_USD` in `.env` to
change the budget shown in the HUD. Hermes itself does not enforce budgets.

## Repository layout

```
adapter/            world contract, Hermes source, Mission Control sink, fake source, tests
game/               Godot project (Open RTS fork); new code in game/source/agent/
infra/              Hermes compose override, Hermes plugin, Ollama Modelfile, SearXNG, pins
scripts/            setup / start / stop / run-mission / gen-env
docs/               architecture and phase 0 findings
vendor/             Hermes Synapse + Mission Control (+ Open RTS upstream), gitignored, pinned
```

## Development

```bash
cd adapter && npm test                         # contract, fake source, Hermes translator (real captured frames), MC sink
cd adapter && npm run demo                     # adapter alone with looping scripted missions
godot --path game                              # the game (connects to ws://127.0.0.1:8770/world)
scripts/run-mission.sh "Your mission" --approve   # drive a mission headless and print agent states
```

Visual checks: `godot --path game -- --capture-dir=/tmp/shots --capture-at=5,20 --quit-after-capture`
saves screenshots at those seconds.

## Known limitations

- **Cancelling a mission only cancels it in the game.** Hermes has no cancel API, so the current
  step keeps running server-side, and its activity can briefly overlap the next mission's.
- Token counts are estimates (Hermes counts characters ÷ 4). Costs come from Hermes' price table.
- Hermes' auth uses its built-in local dev token. Keep its port bound to localhost, as configured.
- Mission Control also lists any local Claude Code or Codex agents it discovers on this machine.
- macOS only so far (start and setup scripts). The Godot project itself is cross-platform.

## Licences

Agent RTS code is MIT. The game is a fork of Open RTS (MIT, Pawel Lampe) with Kenney's Space
Kit (CC0); see `game/LICENSE` and `game/LOGO_LICENSES.md`. Hermes Synapse and Mission Control
are MIT and are fetched unmodified into `vendor/`.
