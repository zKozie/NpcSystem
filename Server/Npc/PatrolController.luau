--!strict

local Types = require(script.Parent.Types)

local PatrolController = {}

-- Reads node positions from a folder of BaseParts named "1".."n", in order.
function PatrolController.collectNodes(folder: Folder): { Vector3 }
	local byIndex: { [number]: Vector3 } = {}
	local maxIndex = 0
	for _, child in folder:GetChildren() do
		assert(child:IsA("BasePart"), "Path node '" .. child.Name .. "' is not a BasePart")
		local order = tonumber(child.Name)
		assert(order and order >= 1 and order % 1 == 0, "Path node '" .. child.Name .. "' must be a positive integer name")
		byIndex[order] = (child :: BasePart).Position
		if order > maxIndex then maxIndex = order end
	end
	assert(maxIndex > 0, "Path folder has no nodes")
	local ordered: { Vector3 } = {}
	for index = 1, maxIndex do
		assert(byIndex[index], "Path node " .. index .. " is missing (gap in numbering)")
		ordered[index] = byIndex[index]
	end
	return ordered
end

-- Issues the next patrol leg as an intent, or nil at the end of the path.
-- nodeIndex itself advances on the client's arrival ack (NPC.onArrival), not here.
function PatrolController.issueLeg(self: Types.NpcRuntime): Types.Intent?
	local nextIndex = self.nodeIndex + 1
	if nextIndex > #self.nodes then
		return nil
	end
	self.awaitingArrival = true
	return {
		mode = "Patrol",
		targetPosition = self.nodes[nextIndex],
		speed = self.speed,
	}
end

return PatrolController
