--!strict

local Players = game:GetService("Players")

local Net = require(script.Parent.Shared.Net)
local SharedTypes = require(script.Parent.Shared.Types)
local NpcBuilder = require(script.NpcBuilder)
local MovementController = require(script.MovementController)
local ChasePursuer = require(script.ChasePursuer)
local HitReporter = require(script.HitReporter)
local AnimationController = require(script.AnimationController)

-- Grace before idling, so the round-trip gap between patrol legs (arrival ack ->
-- next intent) does not flicker the walk animation back to idle.
local IDLE_GRACE = 0.3

local NpcClient = {}

type LocalNpc = {
	model: Model,
	humanoid: Humanoid,
	hitConnection: RBXScriptConnection,
	animation: AnimationController.AnimationState,
	chaseConnection: RBXScriptConnection?,
	moveGeneration: number,
}

local localNpcs: { [number]: LocalNpc } = {}
local netRemotes: Net.NetRemotes? = nil

-- Cancels whatever movement is currently driving a local NPC (patrol walk or chase).
local function stopMovement(localNpc: LocalNpc)
	MovementController.stop(localNpc.humanoid)
	if localNpc.chaseConnection then
		localNpc.chaseConnection:Disconnect()
		localNpc.chaseConnection = nil
	end
end

-- Builds and tracks a local NPC from a server 'created' payload.
function NpcClient.onCreated(payload: SharedTypes.CreatedPayload)
	if localNpcs[payload.npcId] then return end
	local built = NpcBuilder.build(payload.startPoint, payload.hitboxName)
	localNpcs[payload.npcId] = {
		model = built.model,
		humanoid = built.humanoid,
		hitConnection = HitReporter.connect(built.hitbox, payload.npcId),
		animation = AnimationController.new(built.walkTrack, built.idleTrack),
		chaseConnection = nil,
		moveGeneration = 0,
	}
end

-- Applies a movement intent: chase pursues locally; patrol pathfinds + walks + acks.
function NpcClient.onIntent(payload: SharedTypes.IntentPayload)
	local localNpc = localNpcs[payload.npcId]
	if not localNpc then return end
	stopMovement(localNpc)
	localNpc.moveGeneration += 1
	local generation = localNpc.moveGeneration
	AnimationController.setMoving(localNpc.animation, true)
	if payload.mode == "Chase" then
		local target = if payload.targetUserId then Players:GetPlayerByUserId(payload.targetUserId) else nil
		if target then
			localNpc.chaseConnection = ChasePursuer.start(localNpc.humanoid, target, payload.speed)
		end
		return
	end
	local goal = payload.targetPosition
	if not goal then return end
	MovementController.walkTo(localNpc.humanoid, goal, payload.speed, function()
		if netRemotes then
			netRemotes.ReportArrival:FireServer({ npcId = payload.npcId })
		end
		task.delay(IDLE_GRACE, function()
			if localNpc.moveGeneration ~= generation then return end
			AnimationController.setMoving(localNpc.animation, false)
		end)
	end)
end

-- Removes a local NPC on a server 'destroyed' message.
function NpcClient.onDestroyed(payload: SharedTypes.IdPayload)
	local localNpc = localNpcs[payload.npcId]
	if not localNpc then return end
	stopMovement(localNpc)
	localNpc.hitConnection:Disconnect()
	localNpc.model:Destroy()
	localNpcs[payload.npcId] = nil
end

-- Subscribes to the server NPC lifecycle remotes.
function NpcClient.Init()
	local remotes = Net.awaitClient()
	netRemotes = remotes
	remotes.Created.OnClientEvent:Connect(function(payload)
		NpcClient.onCreated(payload)
	end)
	remotes.Intent.OnClientEvent:Connect(function(payload)
		NpcClient.onIntent(payload)
	end)
	remotes.Destroyed.OnClientEvent:Connect(function(payload)
		NpcClient.onDestroyed(payload)
	end)
end

return NpcClient
