-- Store: what the Robux shop sells (vault: Store.md). PURE DATA. Server/Services/StoreService grants it,
-- Client/Controllers/StoreController shows it (the SHOP button in the lobby, or the TRADER stall).
--
-- ProductId / PassId come from the Creator Dashboard (Monetization > Developer Products / Passes).
-- 0 = not created yet: the card shows "SOON" and can't be bought. Prices are read from Roblox at runtime;
-- Price here is only the fallback shown before that (or while the id is 0).
-- Products (Developer Products, buy again any time): Gems, or a bundle (Gems + Classes, OneTime per account).
-- Passes (Game Passes, owned forever): their effect is keyed by Id (StoreService.HasPass).

local Store = {}

Store.Products = {
	{ Id = "Gems500", ProductId = 0, Price = 49, Name = "HANDFUL OF GEMS", Gems = 500 },
	{ Id = "Gems1200", ProductId = 0, Price = 99, Name = "POUCH OF GEMS", Gems = 1200, Tag = "+20%" },
	{ Id = "Gems3000", ProductId = 0, Price = 229, Name = "CRATE OF GEMS", Gems = 3000, Tag = "+30%" },
	{ Id = "Gems7500", ProductId = 0, Price = 499, Name = "VAULT OF GEMS", Gems = 7500, Tag = "BEST VALUE" },
	{
		Id = "Starter",
		ProductId = 0,
		Price = 49,
		Name = "STARTER PACK",
		Gems = 1000,
		Classes = { "Medic" },
		OneTime = true,
		Featured = true,
		Desc = "The Medic class and 1,000 Gems. Once per survivor.",
	},
}

Store.Passes = {
	{ Id = "DoubleGems", PassId = 0, Price = 199, Name = "2x GEMS", Featured = true, Desc = "Double the Gems from every run, forever." },
	{ Id = "VIP", PassId = 0, Price = 149, Name = "VIP", Desc = "A gold VIP tag in the safehouse and +50% daily rations." },
}

Store.ById = {}
for _, entry in Store.Products do
	Store.ById[entry.Id] = entry
end
for _, entry in Store.Passes do
	Store.ById[entry.Id] = entry
end

return Store
