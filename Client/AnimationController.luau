--!strict

local AnimationController = {}

export type AnimationState = {
	walkTrack: AnimationTrack,
	idleTrack: AnimationTrack,
	moving: boolean,
}

-- Creates an animation state starting in idle.
function AnimationController.new(walkTrack: AnimationTrack, idleTrack: AnimationTrack): AnimationState
	walkTrack.Priority = Enum.AnimationPriority.Movement
	idleTrack.Priority = Enum.AnimationPriority.Idle
	idleTrack.Looped = true
	walkTrack.Looped = true
	idleTrack:Play()
	return { walkTrack = walkTrack, idleTrack = idleTrack, moving = false }
end

-- Switches tracks only on a real movement-state change (no per-waypoint flicker).
function AnimationController.setMoving(self: AnimationState, moving: boolean)
	if self.moving == moving then return end
	self.moving = moving
	if moving then
		self.idleTrack:Stop(0.1)
		self.walkTrack:Play(0.1)
		return
	end
	self.walkTrack:Stop(0.1)
	self.idleTrack:Play(0.1)
end

return AnimationController
