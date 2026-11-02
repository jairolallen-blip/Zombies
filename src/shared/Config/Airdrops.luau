-- Airdrops: mid-run supply crates (Server/Services/AirdropService, Client/Controllers/AirdropController).
-- From FirstWave on, each wave has Chance of one crate parachuting onto a street away from the squad,
-- marked with red smoke, a light pillar and an on-screen marker. Guards rise around it as it lands;
-- hold G to open it (E is the class ability). The reward goes to every living squad member within ShareRadius of the crate.
-- PURE DATA.

local Airdrops = {
	FirstWave = 2,
	Chance = 0.65, -- per wave
	Delay = { 8, 20 }, -- seconds into the wave before it drops
	FallTime = 7, -- seconds from the sky to the ground
	DropHeight = 140,
	Guards = 4, -- zombies rising around the crate as it lands (+1 every GuardsEvery waves)
	GuardsEvery = 2,
	OpenTime = 2.5, -- seconds holding G
	ShareRadius = 30,

	-- Kind: Damage (gun damage x Mult), Speed (walk speed x Mult, plus a full heal), Ult (+Amount
	-- ultimate charge), Cash (+PerWave x wave), Gems (+Amount, saved). Weight = relative odds.
	Rewards = {
		{ Id = "Overcharge", Name = "OVERCHARGE", Desc = "+50% gun damage", Kind = "Damage", Mult = 1.5, Duration = 30, Weight = 3, Color = Color3.fromRGB(255, 120, 60) },
		{ Id = "Adrenaline", Name = "ADRENALINE", Desc = "+35% speed and full heal", Kind = "Speed", Mult = 1.35, Duration = 30, Weight = 3, Color = Color3.fromRGB(110, 235, 140) },
		{ Id = "UltSurge", Name = "ULT SURGE", Desc = "+50% ultimate charge", Kind = "Ult", Amount = 50, Weight = 2, Color = Color3.fromRGB(120, 200, 255) },
		{ Id = "CashStash", Name = "CASH STASH", Desc = "Bonus cash", Kind = "Cash", PerWave = 120, Weight = 2, Color = Color3.fromRGB(120, 255, 120) },
		{ Id = "GemCache", Name = "GEM CACHE", Desc = "+25 Gems", Kind = "Gems", Amount = 25, Weight = 2, Color = Color3.fromRGB(190, 120, 255) },
	},
}

Airdrops.ById = {}
for _, reward in Airdrops.Rewards do
	Airdrops.ById[reward.Id] = reward
end

return Airdrops
