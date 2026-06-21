--!strict

local Pathfinder = require(script.Parent.Pathfinder)

local MovementController = {}

-- Weak-keyed so entries vanish when a humanoid is garbage-collected.
local activeWalk: { [Humanoid]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Pathfinds from the humanoid's current position to `goal` and walks it there,
-- cancelling any earlier walk. `onArrived` runs once the final waypoint is reached
-- and this walk is still the current one.
function MovementController.walkTo(humanoid: Humanoid, goal: Vector3, speed: number, onArrived: () -> ())
	humanoid.WalkSpeed = speed
	local token = (activeWalk[humanoid] or 0) + 1
	activeWalk[humanoid] = token
	task.spawn(function()
		local root = humanoid.RootPart
		if not root then return end
		local waypoints = Pathfinder.computeWaypoints(root.Position, goal)
		for _, point in waypoints do
			if activeWalk[humanoid] ~= token then return end
			if not humanoid.Parent then return end
			humanoid:MoveTo(point)
			humanoid.MoveToFinished:Wait()
		end
		if activeWalk[humanoid] ~= token then return end
		onArrived()
	end)
end

-- Invalidates the humanoid's current walk so its loop stops on the next step.
function MovementController.stop(humanoid: Humanoid)
	activeWalk[humanoid] = (activeWalk[humanoid] or 0) + 1
end

return MovementController
