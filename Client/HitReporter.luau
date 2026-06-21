--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(script.Parent.Parent.Shared.Net)

local localPlayer = Players.LocalPlayer
local REPORT_COOLDOWN = 0.5
local POLL_INTERVAL = 0.1
-- Studs added to the hitbox so detection bridges the character-collision gap that
-- otherwise keeps the NPC body from truly overlapping the target.
local HIT_PADDING = 4

local HitReporter = {}

-- Polls whether the local player's OWN character overlaps the (padded) NPC hitbox and
-- reports a hit. An active overlap query is used instead of .Touched because two
-- colliding Humanoids never physically penetrate, so .Touched on a centred hitbox
-- never fires. Only the local character is tested, so a player can only report their own hit.
function HitReporter.connect(hitbox: BasePart, npcId: number): RBXScriptConnection
	local remotes = Net.awaitClient()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local lastReport = 0
	local lastPoll = 0
	return RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastPoll < POLL_INTERVAL then return end
		lastPoll = now
		if now - lastReport < REPORT_COOLDOWN then return end
		local character = localPlayer.Character
		if not character then return end
		params.FilterDescendantsInstances = { character }
		local size = hitbox.Size + Vector3.new(HIT_PADDING, HIT_PADDING, HIT_PADDING)
		if #Workspace:GetPartBoundsInBox(hitbox.CFrame, size, params) == 0 then return end
		lastReport = now
		remotes.ReportHit:FireServer({ npcId = npcId })
	end)
end

return HitReporter
