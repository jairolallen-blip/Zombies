-- Store: what the Robux shop sells (vault: Store.md). PURE DATA. Server/Services/StoreService grants it,
-- Client/Controllers/StoreController shows it (the SHOP button in the lobby, or the TRADER stall).
--
-- ProductId / PassId come from the Creator Dashboard (Monetization > Developer Products / Passes).
-- 0 = not created yet: the card shows "SOON" and can't be bought. Prices are read from Roblox at runtime;
-- Price here is only the fallback shown before that (or while the id is 0).
-- Products (Developer Products, buy again any time): Gem packs.
-- Passes (Game Passes, owned forever, one per account): their effect is keyed by Id (StoreService.HasPass).
-- A pass with Gems / Classes is a bundle: StoreService pays those once per account, then sets the profile
-- flag named by Flag (the Starter Pack is a pass so Roblox itself stops a second purchase).

local Store = {}

Store.Products = {
	{ Id = "Gems500", ProductId = 3727641376, Price = 49, Name = "HANDFUL OF GEMS", Gems = 500 },
	{ Id = "Gems1200", ProductId = 3727642064, Price = 99, Name = "POUCH OF GEMS", Gems = 1200, Tag = "+20%" },
	{ Id = "Gems3000", ProductId = 3727642574, Price = 229, Name = "CRATE OF GEMS", Gems = 3000, Tag = "+30%" },
	{ Id = "Gems7500", ProductId = 3727642816, Price = 499, Name = "VAULT OF GEMS", Gems = 7500, Tag = "BEST VALUE" },
}

Store.Passes = {
	{
		Id = "Starter",
		PassId = 2066970957,
		Price = 49,
		Name = "STARTER PACK",
		Gems = 1000,
		Classes = { "Medic" },
		Flag = "StarterPack", -- profile flag: set once the bundle has been paid
		Featured = true,
		Desc = "The Medic class and 1,000 Gems. Once per survivor.",
	},
	{ Id = "DoubleGems", PassId = 2066934945, Price = 199, Name = "2x GEMS", Featured = true, Desc = "Double the Gems from every run, forever." },
	{ Id = "VIP", PassId = 2066784963, Price = 149, Name = "VIP", Desc = "A gold VIP tag in the safehouse and +50% daily rations." },
}

Store.ById = {}
for _, entry in Store.Products do
	Store.ById[entry.Id] = entry
end
for _, entry in Store.Passes do
	Store.ById[entry.Id] = entry
end

return Store
