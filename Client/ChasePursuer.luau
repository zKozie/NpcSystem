--!strict

local RunService = game:GetService("RunService")

-- Seconds between aim updates / target-position samples.
local CHASE_TICK = 0.1
-- Ignore sub-jitter speeds so a near-still target is aimed at directly.
local MIN_TARGET_SPEED = 1
-- Minimum studs ahead of the target to aim while it moves. This is a floor that does
-- NOT shrink with distance, so when the NPC is right on the target it still aims past
-- it (overlapping/cutting off) instead of settling on the target's exact position.
local MIN_LEAD = 8
-- Upper bound on the lead so a far/fast target is not aimed at absurdly far ahead.
local MAX_LEAD = 60

local ChasePursuer = {}

-- Continuously steers the humanoid to a point AHEAD of the target via straight MoveTo.
-- Direction comes from sampling the target's position locally (no velocity/walkspeed API);
-- the lead distance blends a distance-based interception term with a flat minimum so the
-- NPC always aims past the target and overlaps it rather than trailing its exact position.
-- Returns the driving connection for the caller to disconnect when the chase ends.
function ChasePursuer.start(humanoid: Humanoid, target: Player, speed: number): RBXScriptConnection
	humanoid.WalkSpeed = speed
	local lastSampleClock = os.clock()
	local lastTargetPosition: Vector3? = nil
	local lastMoveClock = 0
	return RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastMoveClock < CHASE_TICK then return end
		local root = humanoid.RootPart
		local character = target.Character
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and targetRoot and targetRoot:IsA("BasePart")) then return end
		lastMoveClock = now
		local targetPosition = targetRoot.Position
		local velocity = Vector3.zero
		local sampleDelta = now - lastSampleClock
		if lastTargetPosition and sampleDelta > 0 then
			velocity = (targetPosition - lastTargetPosition) / sampleDelta
		end
		lastTargetPosition = targetPosition
		lastSampleClock = now
		local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		local targetSpeed = horizontalVelocity.Magnitude
		if targetSpeed <= MIN_TARGET_SPEED then
			humanoid:MoveTo(targetPosition)
			return
		end
		local interceptLead = targetSpeed * ((targetPosition - root.Position).Magnitude / math.max(speed, 1))
		local lead = math.clamp(interceptLead, MIN_LEAD, MAX_LEAD)
		humanoid:MoveTo(targetPosition + (horizontalVelocity / targetSpeed) * lead)
	end)
end

return ChasePursuer
