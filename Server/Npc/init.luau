--!strict

local RunService = game:GetService("RunService")

local Types = require(script.Types)
local StateMachine = require(script.StateMachine)
local PatrolController = require(script.PatrolController)
local HitValidator = require(script.HitValidator)
local Replicator = require(script.Replicator)
local SharedTypes = require(script.Parent.Parent.Shared.Types)

local DEFAULT_SPEED = 16
local DEFAULT_HITBOX_NAME = "Hitbox"

export type Npc = Types.NpcRuntime

local NPC = {}

-- Advances the brain one tick; replicates a new intent only when state changes.
function NPC.step(self: Npc)
	if not self.alive then return end
	local intent = StateMachine.step(self)
	if not intent then return end
	self.currentIntent = intent
	Replicator.intent(self.players, intent, self.npcId)
end

-- Creates a server NPC for a session and starts its Heartbeat brain loop.
function NPC.new(config: SharedTypes.NpcConfig, players: { Player }, npcId: number): Npc
	assert(#players > 0, "NPC requires at least one session player")
	local hitboxName = config.hitboxName or DEFAULT_HITBOX_NAME
	local self: Npc = {
		npcId = npcId,
		config = config,
		players = players,
		nodes = PatrolController.collectNodes(config.path),
		state = "Patrol",
		nodeIndex = 0,
		speed = DEFAULT_SPEED,
		awaitingArrival = false,
		spawnClock = os.clock(),
		lockedTarget = nil,
		zoneA = nil,
		zoneB = nil,
		hitPlayers = {},
		currentIntent = nil,
		onHit = config.onHit,
		alive = true,
		heartbeat = nil,
	}
	Replicator.created(players, npcId, config.startPoint, hitboxName)
	self.heartbeat = RunService.Heartbeat:Connect(function()
		NPC.step(self)
	end)
	return self
end

-- Advances linear patrol when the movement-authority client confirms node arrival.
-- The authority is the first session player; other players' acks are ignored.
function NPC.onArrival(self: Npc, player: Player)
	if self.state ~= "Patrol" then return end
	if not self.awaitingArrival then return end
	if self.players[1] ~= player then return end
	self.awaitingArrival = false
	self.nodeIndex += 1
	local nodeSpeed = self.config.nodeSpeeds[self.nodeIndex]
	if nodeSpeed then self.speed = nodeSpeed end
end

-- Validates a client hit report, drops the chase, excludes the player from future
-- re-acquisition (so the hook is not spammed), then fires the hook once.
function NPC.reportHit(self: Npc, player: Player)
	if not HitValidator.validate(self, player) then return end
	self.hitPlayers[player] = true
	StateMachine.exitChase(self)
	if not self.onHit then return end
	self.onHit(player)
end

-- Replaces the hook called on a validated hit.
function NPC.setOnHit(self: Npc, hook: SharedTypes.OnHitHook)
	self.onHit = hook
end

-- Adds a player, builds the NPC on their client, and replays the current intent.
function NPC.addPlayer(self: Npc, player: Player)
	if table.find(self.players, player) then return end
	table.insert(self.players, player)
	local hitboxName = self.config.hitboxName or DEFAULT_HITBOX_NAME
	Replicator.created({ player }, self.npcId, self.config.startPoint, hitboxName)
	if self.currentIntent then
		Replicator.intent({ player }, self.currentIntent, self.npcId)
	end
end

-- Removes a player, tears down their client copy, and returns the remaining count.
function NPC.removePlayer(self: Npc, player: Player): number
	local index = table.find(self.players, player)
	if index then
		table.remove(self.players, index)
		self.hitPlayers[player] = nil
		Replicator.destroyed({ player }, self.npcId)
	end
	return #self.players
end

-- Stops the brain and tells every session player to remove their copy.
function NPC.destroy(self: Npc)
	if not self.alive then return end
	self.alive = false
	if self.heartbeat then
		self.heartbeat:Disconnect()
		self.heartbeat = nil
	end
	Replicator.destroyed(self.players, self.npcId)
end

return NPC
