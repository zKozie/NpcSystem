# NpcSystem

A standalone, session-scoped patrol/chase NPC.

The **server is a positionless brain** — it runs the state machine, picks targets, decides
chase start/end, drives node progression, and validates hits. It never moves anything; it sends
each session's clients a high-level **intent** (`patrol → node N` or `chase → player X`).

Each **client owns all movement** — it builds the NPC model locally, pathfinds patrol legs,
runs straight-`MoveTo` interception for chases, and self-reports node arrivals and hits.

The server holds exactly one authoritative truth: the **On-Hit hook**. A player can only ever
report their own hit, and the server validates it before firing the hook.

---

## Requirements

- **Rojo** (this repo pins `rojo 7.7.0-rc.1` in `aftman.toml`).
- The module must live in a **replicated container** (e.g. `ReplicatedStorage`) so clients can
  clone `Assets` and require the `Client`/`Shared` modules. Server code lives here too — see
  [Security](#security).
- An NPC rig template (`Assets.NpcModel`) with:
  - a `Humanoid`,
  - `PrimaryPart` set (the `HumanoidRootPart`),
  - a `BasePart` child whose name matches `config.hitboxName` (default `"Hitbox"`).
- `Walk` and `Idle` `Animation` instances whose `AnimationId`s match the rig type (R6 vs R15).

---

## Layout (DataModel)

```
ReplicatedStorage.Shared.NpcSystem  (ModuleScript — facade: InitServer / InitClient)
├─ Assets            (Folder, ignoreUnknownInstance — you fill this in Studio)
│  ├─ NpcModel       (Model: Humanoid + hitbox BasePart "Hitbox", PrimaryPart = HumanoidRootPart)
│  └─ Anims          (Folder)
│     ├─ Walk        (Animation)
│     └─ Idle        (Animation)
├─ Shared
│  ├─ Types          (NpcConfig + network payload types)
│  └─ Net            (RemoteEvent folder + typed accessors)
├─ Server            (ModuleScript)
│  ├─ SessionManager (sessions, membership, report routing)
│  └─ Npc            (ModuleScript)
│     ├─ init        (NPC class: lifecycle, step, hit/arrival, setOnHit)
│     ├─ StateMachine    (Patrol ⇄ Chase transitions; emits intents)
│     ├─ PatrolController (collectNodes; issues patrol legs)
│     ├─ Eligibility      (slab zone test, target acquire, lock-held)
│     ├─ HitValidator     (locked-target + Chase-state check)
│     ├─ Replicator       (created / intent / destroyed → clients)
│     └─ Types            (internal NpcRuntime + Intent)
└─ Client            (ModuleScript)
   ├─ NpcBuilder        (clone Assets, resolve hitbox, load Animator)
   ├─ Pathfinder        (PathfindingService wrapper, patrol legs only)
   ├─ MovementController (pathfind + MoveTo a node; ack arrival)
   ├─ ChasePursuer      (per-tick straight-MoveTo interception)
   ├─ HitReporter       (padded overlap query → ReportHit)
   └─ AnimationController(walk/idle crossfade)
```

`Assets` uses `init.meta.json` with `ignoreUnknownInstance: true`, so the `NpcModel` / `Anims`
you drop in via Studio are **not** wiped by Rojo two-way sync.

---

## Config reference

`config` is a `Shared.Types.NpcConfig`:

| Field         | Type                   | Required | Meaning |
|---------------|------------------------|----------|---------|
| `path`        | `Folder`               | yes      | Folder of node parts (see [Path setup](#path-setup)). |
| `startPoint`  | `Vector3`              | yes      | Where the NPC spawns; it idles here, then walks to node 1. |
| `nodeSpeeds`  | `{[number]: number}`   | yes      | Node index → `Humanoid.WalkSpeed` applied on **passing** that node. |
| `startDelay`  | `number`               | yes      | Seconds idling at `startPoint` before patrol begins. |
| `hitboxName`  | `string?`              | no       | Name of the hitbox child in the rig (default `"Hitbox"`). |
| `onHit`       | `(player: Player)->()` | no       | Fired once on a validated hit. Also settable at runtime via `setOnHit`. |

**Speed rule.** Before any node is passed the NPC uses a default WalkSpeed of `16`. Passing
node `N` sets the speed to `nodeSpeeds[N]` if present, otherwise the previous speed carries.
A **chase reuses the current node speed** — there is no separate chase speed, so for the NPC to
actually catch a player it must be faster than them (mind the default `16` on the first segment).

---

## Path setup

- `config.path` is a **`Folder` of `BasePart`s named numerically** `"1"`, `"2"`, `"3"`, … The
  module sorts by `tonumber(Name)` and **asserts on gaps or non-integer names**.
- Only each part's **`.Position`** is read (its center is the node point). Size/shape are yours.
- **Make node parts non-collidable.** Chase movement is straight `MoveTo`, so a solid node part
  would block the NPC. Walls/markers should be `CanCollide = false`.
- The eligibility "zone" of a segment is the **slab between the two node planes** (normal =
  node→node). A player is eligible while their projection onto that axis is between the two nodes
  — no perpendicular threshold, so the walls themselves define the corridor width.

The demo path (`Workspace.Path`, five wall nodes) is defined as real instances in
`default.project.json` and synced by Rojo.

---

## Behavior

- **Patrol** walks nodes `1 → n` in order and **stops at the last node** (one-shot until the
  session is destroyed and recreated). Progression is **strict**: the server issues one leg and
  does not advance until the client confirms arrival (no node-skipping).
- **Chase eligibility** is **current-segment only** — between the node just passed and the next.
- **Targeting**: the in-zone player **closest to the next node**, **locked until lost**.
  (The server is positionless, hence "closest to next node" rather than "closest to NPC".)
- **Chase end**: the target leaves the frozen segment **or** is hit. The NPC then **resumes
  linearly** — straight to the next node, never the "nearest" one.
- **Interception**: the client aims a configurable distance **ahead** of the target along its
  sampled movement direction (never at its exact position), so a faster NPC overlaps/cuts off
  rather than tailing.
- **On-Hit**: validated server-side (`lockedTarget == reporter` and state is `Chase`), fires the
  hook **once**, immediately drops the chase, and **excludes that player** from re-acquisition
  for the NPC's lifetime — so the hook is never spammed.

---

## API

```lua
local NpcSystem = require(ReplicatedStorage.Shared.NpcSystem)

-- Server (once):
local server = NpcSystem.InitServer()

local sessionId = server.createSession(config, { playerA, playerB })
server.addPlayer(sessionId, playerC)         -- builds the NPC on their client too
server.removePlayer(sessionId, playerC)      -- destroys the NPC when the last player leaves
server.setOnHit(sessionId, function(player)  -- swap the hook at runtime
    -- ...
end)
server.destroySession(sessionId)             -- full teardown; call createSession again to restart

-- Client (once, in a LocalScript):
NpcSystem.InitClient()
```

- A **session** is a group of players sharing **one** NPC; many sessions run concurrently.
- **Reset = destroy.** There is no in-place reset — `destroySession` (or the last player leaving)
  tears the NPC down; create a new session to restart.
- `onHit` may be supplied in `config` or set later with `server.setOnHit`.

---

## Networking

One `RemoteEvent` folder, `ReplicatedStorage.NpcRemotes`:

| Remote          | Direction       | Purpose |
|-----------------|-----------------|---------|
| `Created`       | server → client | Build a local NPC (startPoint, hitbox name). |
| `Intent`        | server → client | Current intent: `Patrol`+node position, or `Chase`+target UserId. |
| `Destroyed`     | server → client | Remove the local NPC. |
| `ReportHit`     | client → server | "My own character is in the hitbox." Server validates. |
| `ReportArrival` | client → server | "I reached the current patrol node." Drives progression. |

- Intents are sent **only on change** (and replayed to a late-joining session member).
- For a **shared session**, the **first player in the session is the movement authority** — only
  their `ReportArrival` advances the node; others just render their own copy.
- Clients never send authoritative position/velocity; they only self-report arrivals and hits.

---

## Tuning

| Constant         | File                       | Effect |
|------------------|----------------------------|--------|
| `MIN_LEAD`       | `Client/ChasePursuer`      | Studs aimed ahead of the target even at close range (the main "overlap" lever). |
| `MAX_LEAD`       | `Client/ChasePursuer`      | Upper bound on lead distance for far/fast targets. |
| `CHASE_TICK`     | `Client/ChasePursuer`      | Seconds between aim updates / direction samples. |
| `HIT_PADDING`    | `Client/HitReporter`       | Studs added to the hitbox so detection bridges the body-collision gap. |
| `POLL_INTERVAL`  | `Client/HitReporter`       | How often the overlap query runs. |
| `REPORT_COOLDOWN`| `Client/HitReporter`       | Minimum seconds between hit reports. |
| `IDLE_GRACE`     | `Client/init`              | Delay before idling, so per-node gaps don't flicker the walk anim. |
| `DEFAULT_SPEED`  | `Server/Npc/init`          | WalkSpeed before the first node is passed. |

---

## Gotchas & limitations

- **Speed:** no amount of leading beats being slower — the NPC must out-pace the player (it
  reuses the current node speed, which is `16` until node 1 is passed).
- **Chase ignores obstacles:** chase is straight `MoveTo` (only patrol legs pathfind). Keep
  chase arenas open, or switch chase to pathfinding if you need avoidance.
- **No true physical overlap:** two Humanoids collide, so the NPC tails right behind rather than
  merging. The hit is detected by a **padded overlap query**, not `.Touched`. For visual
  pass-through you'd add collision groups (not included — it changes character collision
  game-wide).
- **Hit exclusion is permanent** for the NPC's lifetime; a hit player isn't chased again until
  the session is recreated.
- **Shared sessions** render an independent copy per client driven by the same intents; expect
  minor visual divergence between members under latency.

---

## Security

The module keeps server code in `ReplicatedStorage` so the whole system is one drop-in folder.
The source is therefore readable by clients, but all **authority (hit validation) stays
server-side and is not bypassable** — a client can only report its own hit, and the server checks
it against the locked target. Move `Server/` to `ServerScriptService` if you want the source
hidden.

---

## Studio quickstart

1. `rojo serve` and connect the Studio plugin so the tree syncs.
2. Under `ReplicatedStorage.Shared.NpcSystem.Assets`, add:
   - `NpcModel` (a rig Model) — set its `PrimaryPart`, add a `BasePart` child named `Hitbox`.
   - `Anims` folder with `Walk` and `Idle` `Animation`s (set their `AnimationId`s).
3. Press Play. `Workspace.Path` (five wall nodes) syncs from `default.project.json`;
   `src/server/NpcBootstrap` spawns a private session per player and `src/client/NpcBootstrap`
   starts the client listener.
4. Walk into the corridor between the node the NPC just passed and the next node to start the
   chase. On a confirmed hit the demo prints `[NpcSystem] On-Hit confirmed for <name>` and zeroes
   your health.
