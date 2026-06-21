--!strict

local Players = game:GetService("Players")

local NPC = require(script.Parent.Npc)
local SharedTypes = require(script.Parent.Parent.Shared.Types)

type Session = {
	id: number,
	npc: NPC.Npc,
}

local SessionManager = {}

local sessions: { [number]: Session } = {}
local npcsById: { [number]: NPC.Npc } = {}
local nextSessionId = 0
local nextNpcId = 0

-- Creates a session that owns one NPC shared by the given players.
function SessionManager.createSession(config: SharedTypes.NpcConfig, players: { Player }): number
	nextSessionId += 1
	nextNpcId += 1
	local npc = NPC.new(config, table.clone(players), nextNpcId)
	sessions[nextSessionId] = { id = nextSessionId, npc = npc }
	npcsById[nextNpcId] = npc
	return nextSessionId
end

-- Destroys a session and tears down its NPC.
function SessionManager.destroySession(sessionId: number)
	local session = sessions[sessionId]
	if not session then return end
	NPC.destroy(session.npc)
	npcsById[session.npc.npcId] = nil
	sessions[sessionId] = nil
end

-- Adds a player to a live session so their client builds the NPC.
function SessionManager.addPlayer(sessionId: number, player: Player)
	local session = sessions[sessionId]
	if not session then return end
	NPC.addPlayer(session.npc, player)
end

-- Removes a player; destroys the session once its last player leaves.
function SessionManager.removePlayer(sessionId: number, player: Player)
	local session = sessions[sessionId]
	if not session then return end
	local remaining = NPC.removePlayer(session.npc, player)
	if remaining > 0 then return end
	SessionManager.destroySession(sessionId)
end

-- Routes a client hit report to the matching NPC for validation.
function SessionManager.handleHit(player: Player, npcId: number)
	local npc = npcsById[npcId]
	if not npc then return end
	NPC.reportHit(npc, player)
end

-- Routes a client node-arrival report to the matching NPC.
function SessionManager.handleArrival(player: Player, npcId: number)
	local npc = npcsById[npcId]
	if not npc then return end
	NPC.onArrival(npc, player)
end

-- Connects player-leaving cleanup across all live sessions.
function SessionManager.init()
	Players.PlayerRemoving:Connect(function(player)
		local ids = {}
		for sessionId in sessions do
			table.insert(ids, sessionId)
		end
		for _, sessionId in ids do
			SessionManager.removePlayer(sessionId, player)
		end
	end)
end

return SessionManager
