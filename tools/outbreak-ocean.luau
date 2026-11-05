-- Rebuilds the Outbreak place's ocean. It lives in the place file only, so this is its record in the repo.
-- Run in execute_luau (Edit) on the Outbreak window only, then test and publish. Guide: vault/Outbreak.md
assert(game.PlaceId == 87622086122699, "this is for the Outbreak place only")
local T = workspace.Terrain
local function fill(x0, x1, z0, z1)
	for x = x0, x1 - 1, 1000 do
		for z = z0, z1 - 1, 1000 do
			local xe, ze = math.min(x + 1000, x1), math.min(z + 1000, z1)
			T:FillBlock(CFrame.new((x + xe) / 2, -10, (z + ze) / 2), Vector3.new(xe - x, 20, ze - z), Enum.Material.Water)
			task.wait()
		end
	end
end
fill(-1000, 3000, -2200, 2200)
fill(-200, 2000, -2452, -2200)
T.WaterColor = Color3.new(0.109804, 0.243137, 0.27451)
T.WaterTransparency = 0.12
T.WaterWaveSize = 0.35
T.WaterWaveSpeed = 14
T.WaterReflectance = 0.7
-- an opaque Baseplate at sea level hides the water
local plate = workspace.Baseplate
plate.CFrame = CFrame.new(0, -21, 0)
plate.Transparency = 1
return T:CountCells()
