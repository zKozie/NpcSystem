--!strict

local Types = require(script.Parent.Types)

local HitValidator = {}

-- True only when the reporting player is the locked target of an active chase.
-- The player argument is Roblox-authenticated, so a player can only report their own touch.
function HitValidator.validate(self: Types.NpcRuntime, player: Player): boolean
	if self.state ~= "Chase" then return false end
	if self.lockedTarget ~= player then return false end
	return true
end

return HitValidator
