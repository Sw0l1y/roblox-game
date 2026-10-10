-- Moves and scales a client-side model by re-posing every part from its recorded rest pose (relative to a
-- base CFrame). Nothing accumulates frame to frame, so long spins, pops and grows stay exact.
local Rig = {}

export type Rig = { parts: { BasePart }, rel: { CFrame }, size: { Vector3 }, scale: number }

function Rig.new(model: Instance, base: CFrame): Rig
	local r: Rig = { parts = {}, rel = {}, size = {}, scale = 1 }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local p = d :: BasePart
			table.insert(r.parts, p)
			local rel: CFrame = base:ToObjectSpace(p.CFrame)
			table.insert(r.rel, rel)
			table.insert(r.size, p.Size)
		end
	end
	return r
end

-- Place the rig at `at` with uniform scale `s` (sizes only change when the scale does).
function Rig.pose(r: Rig, at: CFrame, s: number?)
	local scale = s or r.scale
	local resize = scale ~= r.scale
	r.scale = scale
	for i, p in ipairs(r.parts) do
		if p.Parent then
			local rel = r.rel[i]
			if resize then
				p.Size = r.size[i] * scale
			end
			p.CFrame = at * CFrame.new(rel.Position * scale) * rel.Rotation
		end
	end
end

return Rig
