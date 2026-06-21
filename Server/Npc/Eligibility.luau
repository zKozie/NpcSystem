--!strict

local Eligibility = {}

-- True when `point` lies in the slab between the two node planes (normal = a->b).
-- Projects onto the node-to-node axis; inside means the player is between the two
-- walls along the path. No perpendicular bound — the walls define the corridor.
local function isInZone(point: Vector3, a: Vector3, b: Vector3): boolean
	local axis = b - a
	local lengthSq = axis:Dot(axis)
	if lengthSq <= 0 then return false end
	local t = (point - a):Dot(axis) / lengthSq
	return t >= 0 and t <= 1
end

-- Returns a player's HumanoidRootPart, or nil when not currently spawned.
function Eligibility.rootOf(player: Player): BasePart?
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	return nil
end

-- Picks the in-zone player closest to `reference` (the next node), or nil if none.
-- Skips any player in `excluded` (already hit). The server is positionless, so it
-- ranks by distance to the next node rather than to the NPC.
function Eligibility.acquire(players: { Player }, excluded: { [Player]: boolean }, reference: Vector3, a: Vector3, b: Vector3): Player?
	local closestPlayer: Player? = nil
	local closestDistance = math.huge
	for _, player in players do
		if excluded[player] then continue end
		local root = Eligibility.rootOf(player)
		if not root then continue end
		if not isInZone(root.Position, a, b) then continue end
		local distance = (root.Position - reference).Magnitude
		if distance >= closestDistance then continue end
		closestDistance = distance
		closestPlayer = player
	end
	return closestPlayer
end

-- True while the locked target remains inside the frozen eligibility zone.
function Eligibility.isLockHeld(target: Player, a: Vector3, b: Vector3): boolean
	local root = Eligibility.rootOf(target)
	if not root then return false end
	return isInZone(root.Position, a, b)
end

return Eligibility
