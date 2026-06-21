--!strict

local Net = require(script.Parent.Parent.Parent.Shared.Net)
local Types = require(script.Parent.Types)

local Replicator = {}

local remotes: Net.NetRemotes? = nil

-- Lazily resolves the server remotes the first time replication is needed.
local function getRemotes(): Net.NetRemotes
	if not remotes then
		remotes = Net.ensureServer()
	end
	return remotes
end

-- Tells the given players to build a new local NPC.
function Replicator.created(players: { Player }, npcId: number, startPoint: Vector3, hitboxName: string)
	local payload = { npcId = npcId, startPoint = startPoint, hitboxName = hitboxName }
	for _, player in players do
		getRemotes().Created:FireClient(player, payload)
	end
end

-- Sends the current movement intent (patrol node or chase target) to the players.
function Replicator.intent(players: { Player }, intent: Types.Intent, npcId: number)
	local payload = {
		npcId = npcId,
		mode = intent.mode,
		targetPosition = intent.targetPosition,
		targetUserId = intent.targetUserId,
		speed = intent.speed,
	}
	for _, player in players do
		getRemotes().Intent:FireClient(player, payload)
	end
end

-- Tells the given players to remove their local NPC.
function Replicator.destroyed(players: { Player }, npcId: number)
	local payload = { npcId = npcId }
	for _, player in players do
		getRemotes().Destroyed:FireClient(player, payload)
	end
end

return Replicator
