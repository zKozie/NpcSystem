--!strict

-- Public configuration and network contract for the NpcSystem.
-- Owned by NpcSystem; consumed by both the Server and Client layers.

-- Maps a 1-based node index to the Humanoid WalkSpeed applied once the NPC
-- passes (arrives at) that node during patrol. Missing indices carry the prior speed.
export type NodeSpeedMap = { [number]: number }

-- The two mutually exclusive NPC behaviours.
export type NpcState = "Patrol" | "Chase"

-- Called on the server when a client's self-reported hit is validated.
-- `player` is the authenticated player whose own hitbox touch was confirmed.
export type OnHitHook = (player: Player) -> ()

-- Per-NPC configuration handed to NPC.new (via SessionManager) on the server.
-- `path` is a Folder of BaseParts named "1".."n"; only their positions are read.
-- A player is chase-eligible while between the two node planes of the active
-- segment. `onHit` is optional and may also be set later through NPC.setOnHit.
export type NpcConfig = {
	path: Folder,             -- folder of numerically-named node parts
	startPoint: Vector3,      -- spawn position before walking to node 1
	nodeSpeeds: NodeSpeedMap, -- node index -> WalkSpeed on passing (also used while chasing)
	startDelay: number,       -- idle seconds at spawn before patrol begins
	hitboxName: string?,      -- model child used for touch (default "Hitbox")
	onHit: OnHitHook?,        -- fired on a validated hit
}

-- Server -> client: a new NPC exists for this session member; build it locally.
export type CreatedPayload = {
	npcId: number,
	startPoint: Vector3,
	hitboxName: string,
}

-- Server -> client: the current movement intent for an NPC. Patrol carries the
-- node position to walk to; Chase carries the target player's UserId. The client
-- owns all pathfinding, movement, and chase interception.
export type IntentPayload = {
	npcId: number,
	mode: NpcState,
	targetPosition: Vector3?,
	targetUserId: number?,
	speed: number,
}

-- Server <-> client: identifies a single NPC (destroy notice / hit report).
export type IdPayload = {
	npcId: number,
}

return {}
