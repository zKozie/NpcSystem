# NpcSystem

Standalone, session-scoped chaser NPC. Server is a positionless brain (state machine,
targeting, chase start/end, node progression, hit validation) and sends only a high-level
intent: "patrol to node N" or "chase player X". Each session client builds the model and does
ALL movement locally — pathfinding for patrol legs, straight-MoveTo interception for chases —
and self-reports node arrivals and hits. Server holds the only authoritative truth: the On-Hit hook.

## Layout (DataModel)

```
ReplicatedStorage.Shared.NpcSystem  (ModuleScript — facade: InitServer / InitClient)
├─ Assets            (Folder, ignoreUnknownInstance — you fill this in Studio)
│  ├─ NpcModel       (Model: Humanoid + a hitbox BasePart named "Hitbox", PrimaryPart = HumanoidRootPart)
│  └─ Anims          (Folder)
│     ├─ Walk        (Animation)
│     └─ Idle        (Animation)
├─ Shared            (Types, Net)
├─ Server            (init, SessionManager, Npc/{init, StateMachine, PatrolController, Eligibility, HitValidator, Replicator, Types})
└─ Client            (init, NpcBuilder, Pathfinder, MovementController, ChasePursuer, HitReporter, AnimationController)
```

`Assets` uses `init.meta.json` with `ignoreUnknownInstance: true`, so the NpcModel / Anims you
drop in via Studio are NOT wiped by Rojo two-way sync.

## Studio test setup

1. `rojo serve` and connect the Studio plugin so the tree syncs.
2. Under `ReplicatedStorage.Shared.NpcSystem.Assets`, add:
   - `NpcModel` (a rig Model) — set its `PrimaryPart`, and add a BasePart child named `Hitbox`.
   - `Anims` folder with `Walk` and `Idle` Animation objects (set their `AnimationId`).
3. Press Play. `Workspace.Path` (5 wall nodes) is synced from `default.project.json`;
   `src/server/NpcBootstrap` spawns a private NPC session per player and `src/client/NpcBootstrap`
   starts the client listener.
4. Walk into the corridor between the node the NPC just passed and the next node to trigger the chase.
   On a confirmed touch the demo prints `[NpcSystem] On-Hit confirmed for <name>` and zeroes health.

## API

```lua
local NpcSystem = require(ReplicatedStorage.Shared.NpcSystem)
local server = NpcSystem.InitServer()        -- server only, once

local sessionId = server.createSession(config, { playerA, playerB })
server.addPlayer(sessionId, playerC)
server.removePlayer(sessionId, playerC)      -- destroys the NPC when the last player leaves
server.destroySession(sessionId)             -- reset = full teardown; call createSession again to restart
```

`config` is a `Shared.Types.NpcConfig`. Set `onHit` in the config or later via `NPC.setOnHit`.

Note: this module keeps server code in ReplicatedStorage so the whole system is one drop-in
folder. The source is readable by clients, but all authority (hit validation) stays server-side
and is not bypassable. Move `Server/` to ServerScriptService if you want the source hidden.
