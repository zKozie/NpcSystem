--!strict

local Types = require(script.Parent.Types)
local Eligibility = require(script.Parent.Eligibility)
local PatrolController = require(script.Parent.PatrolController)

local StateMachine = {}

-- Returns the active patrol segment: from the last node (or spawn) to the next.
function StateMachine.currentSegment(self: Types.NpcRuntime): (Vector3, Vector3?)
	local from = if self.nodeIndex == 0 then self.config.startPoint else self.nodes[self.nodeIndex]
	return from, self.nodes[self.nodeIndex + 1]
end

-- Locks a target and freezes the eligibility segment for the chase.
function StateMachine.enterChase(self: Types.NpcRuntime, target: Player, from: Vector3, to: Vector3)
	self.state = "Chase"
	self.lockedTarget = target
	self.zoneA = from
	self.zoneB = to
	self.awaitingArrival = false
end

-- Drops the target and returns to patrol; nodeIndex is left intact for linear resume.
function StateMachine.exitChase(self: Types.NpcRuntime)
	self.state = "Patrol"
	self.lockedTarget = nil
	self.zoneA = nil
	self.zoneB = nil
	self.awaitingArrival = false
end

-- Steps patrol: acquire a target on the active segment (chase takes priority), else
-- issue the next patrol leg when not already walking one.
function StateMachine.stepPatrol(self: Types.NpcRuntime): Types.Intent?
	if os.clock() - self.spawnClock < self.config.startDelay then
		return nil
	end
	local from, to = StateMachine.currentSegment(self)
	if to then
		local target = Eligibility.acquire(self.players, self.hitPlayers, to, from, to)
		if target then
			StateMachine.enterChase(self, target, from, to)
			return { mode = "Chase", targetUserId = target.UserId, speed = self.speed }
		end
	end
	if self.awaitingArrival then
		return nil
	end
	return PatrolController.issueLeg(self)
end

-- Steps chase: stay locked while the target is in the frozen zone, else resume patrol.
function StateMachine.stepChase(self: Types.NpcRuntime): Types.Intent?
	local target = self.lockedTarget
	local zoneA = self.zoneA
	local zoneB = self.zoneB
	if target and zoneA and zoneB and Eligibility.isLockHeld(target, zoneA, zoneB) then
		return nil
	end
	StateMachine.exitChase(self)
	return PatrolController.issueLeg(self)
end

-- Routes a tick to the active state's stepper; returns an intent only on a change.
function StateMachine.step(self: Types.NpcRuntime): Types.Intent?
	if self.state == "Chase" then
		return StateMachine.stepChase(self)
	end
	return StateMachine.stepPatrol(self)
end

return StateMachine
