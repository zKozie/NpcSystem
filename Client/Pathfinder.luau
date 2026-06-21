--!strict

local PathfindingService = game:GetService("PathfindingService")

local Pathfinder = {}

-- Computes a walkable route between two world positions for patrol legs.
-- Returns ordered waypoint positions, or { goal } as a straight-line fallback
-- when the path cannot be computed or is not a success.
function Pathfinder.computeWaypoints(start: Vector3, goal: Vector3): { Vector3 }
	local path = PathfindingService:CreatePath()
	local ok = pcall(function()
		path:ComputeAsync(start, goal)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return { goal }
	end
	local positions = {}
	for _, waypoint in path:GetWaypoints() do
		table.insert(positions, waypoint.Position)
	end
	if #positions == 0 then
		return { goal }
	end
	return positions
end

return Pathfinder
