--!strict

local ASSETS = script.Parent.Parent.Assets

export type BuiltNpc = {
	model: Model,
	humanoid: Humanoid,
	hitbox: BasePart,
	walkTrack: AnimationTrack,
	idleTrack: AnimationTrack,
}

local NpcBuilder = {}

-- Clones the Assets template, positions it, and prepares its Animator + hitbox.
function NpcBuilder.build(startPoint: Vector3, hitboxName: string): BuiltNpc
	local template = ASSETS:FindFirstChild("NpcModel")
	assert(template and template:IsA("Model"), "Assets.NpcModel (Model) is missing")
	local anims = ASSETS:FindFirstChild("Anims")
	assert(anims, "Assets.Anims folder is missing")
	local walkAnim = anims:FindFirstChild("Walk")
	local idleAnim = anims:FindFirstChild("Idle")
	assert(walkAnim and walkAnim:IsA("Animation"), "Assets.Anims.Walk (Animation) is missing")
	assert(idleAnim and idleAnim:IsA("Animation"), "Assets.Anims.Idle (Animation) is missing")
	local model = (template :: Model):Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "NpcModel has no Humanoid")
	local hitbox = model:FindFirstChild(hitboxName)
	assert(hitbox and hitbox:IsA("BasePart"), "NpcModel has no BasePart named '" .. hitboxName .. "'")
	model:PivotTo(CFrame.new(startPoint))
	model.Parent = workspace
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	return {
		model = model,
		humanoid = humanoid,
		hitbox = hitbox :: BasePart,
		walkTrack = animator:LoadAnimation(walkAnim :: Animation),
		idleTrack = animator:LoadAnimation(idleAnim :: Animation),
	}
end

return NpcBuilder
