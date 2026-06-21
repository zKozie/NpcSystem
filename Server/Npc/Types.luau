--!strict

local SharedTypes = require(script.Parent.Parent.Parent.Shared.Types)

-- Internal mutable runtime state for a single server NPC (brain only — no position,
-- no pathfinding). Owned by NpcSystem.Server.Npc. `nodeIndex` is the last node the
-- client confirmed reaching (0 = still at startPoint). `zoneA`/`zoneB` are the
-- eligibility segment frozen at chase entry. `awaitingArrival` is true while a patrol
-- leg has been issued and the client has not yet acked reaching the node.
export type NpcRuntime = {
	npcId: number,
	config: SharedTypes.NpcConfig,
	players: { Player },
	nodes: { Vector3 },
	state: SharedTypes.NpcState,
	nodeIndex: number,
	speed: number,
	awaitingArrival: boolean,
	spawnClock: number,
	lockedTarget: Player?,
	zoneA: Vector3?,
	zoneB: Vector3?,
	hitPlayers: { [Player]: boolean },
	currentIntent: Intent?,
	onHit: SharedTypes.OnHitHook?,
	alive: boolean,
	heartbeat: RBXScriptConnection?,
}

-- A movement intent the server hands to the session's clients. Patrol carries the
-- node position to walk to; Chase carries the locked player's UserId. The client
-- performs the actual movement and interception.
export type Intent = {
	mode: SharedTypes.NpcState,
	targetPosition: Vector3?,
	targetUserId: number?,
	speed: number,
}

return {}
