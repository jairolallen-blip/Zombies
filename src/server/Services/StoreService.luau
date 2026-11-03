-- StoreService: Robux purchases (vault: Store.md; catalogue in Shared/Config/Store).
--   Developer Products: MarketplaceService.ProcessReceipt -> :Grant. Each receipt pays exactly once: its
--     PurchaseId goes into the profile's Receipts list with the reward, and Roblox is only told
--     PurchaseGranted after that save succeeds. If the save fails we answer NotProcessedYet and Roblox retries;
--     the retry finds the receipt already in the profile (same server) or the reward missing (after a crash)
--     and does the right thing either way.
--   Gifts: a Gem pack can be bought for another player in the server. The buyer picks them first
--     (Remotes.SetGift), then buys as usual; the next receipt within GIFT_WINDOW pays the friend instead.
--     The receipt's recipient is remembered, so a retry pays the same person; if they've left, the buyer.
--   Game Passes: checked on join and after a purchase; owned passes become player attributes Pass_<Id>
--     (MatchService doubles run Gems with DoubleGems; DailyService and LobbyService read VIP).

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Store = require(Shared.Config.Store)
local Remotes = require(Shared.Remotes)

local StoreService = {}
local Services

local MAX_RECEIPTS = 100 -- receipts remembered per profile (Roblox only retries recent ones)
local GIFT_WINDOW = 120 -- seconds a picked gift recipient waits for the purchase

local giftFor = {} -- [buyer Player] = { UserId, At }
local recipientOf = {} -- [PurchaseId] = Player the receipt pays (so retries pay the same person)

function StoreService:Init(services)
	Services = services
	MarketplaceService.ProcessReceipt = function(receipt)
		return self:_processReceipt(receipt)
	end
	Remotes.SetGift.OnServerEvent:Connect(function(player, userId)
		local friend = type(userId) == "number" and Players:GetPlayerByUserId(userId)
		giftFor[player] = if friend and friend ~= player then { UserId = userId, At = os.clock() } else nil
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _, bought)
		local buyer = Players:GetPlayerByUserId(userId)
		if buyer and not bought then
			giftFor[buyer] = nil -- cancelled: the next purchase is for themselves again
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		giftFor[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		if bought then
			self:_refreshPasses(player)
		end
	end)
end

function StoreService:Start()
	Services.DataService.ProfileLoaded:Connect(function(player, profile)
		self:_refreshPasses(player)
		player:SetAttribute("StarterBought", profile.StarterPack == true)
	end)
end

function StoreService.HasPass(player, id)
	return player:GetAttribute("Pass_" .. id) == true
end

function StoreService:_refreshPasses(player)
	for _, pass in Store.Passes do
		if pass.PassId ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.PassId)
			if ok and owns and not player:GetAttribute("Pass_" .. pass.Id) then
				player:SetAttribute("Pass_" .. pass.Id, true)
				Remotes.Notify:FireClient(player, pass.Name .. " is active. Thank you!", "Good")
			end
		end
	end
end

function StoreService:_processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local entry
	for _, product in Store.Products do
		if product.ProductId ~= 0 and product.ProductId == receipt.ProductId then
			entry = product
		end
	end
	if not player or not entry then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- left, or a product this build doesn't know
	end
	local recipient = recipientOf[receipt.PurchaseId]
	if not recipient then
		local gift = giftFor[player]
		giftFor[player] = nil
		local friend = gift and os.clock() - gift.At < GIFT_WINDOW and not entry.Classes and Players:GetPlayerByUserId(gift.UserId)
		recipient = friend or player
		recipientOf[receipt.PurchaseId] = recipient
	end
	if not recipient.Parent then
		recipient = player -- the friend left before it went through: the buyer keeps it
	end
	local granted = self:Grant(recipient, entry.Id, receipt.PurchaseId)
	if granted and recipient ~= player then
		Remotes.Notify:FireClient(recipient, player.DisplayName .. " gifted you " .. entry.Name .. "!", "Good")
		Remotes.Notify:FireClient(player, "Gift sent to " .. recipient.DisplayName .. ". What a hero.", "Good")
	end
	return if granted then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

-- pays product `id` to `player` once per receiptId; true when it's granted and saved
function StoreService:Grant(player, id, receiptId)
	local DataService = Services.DataService
	local profile = DataService:Get(player)
	local entry = Store.ById[id]
	if not profile or not entry then
		return false
	end
	if not table.find(profile.Receipts, receiptId) then
		local gems = entry.Gems or 0
		if entry.OneTime and profile.StarterPack then
			-- a second Starter Pack (the button hides once owned): its Gems only, the class is already theirs
		else
			for _, classId in entry.Classes or {} do
				profile.OwnedClasses[classId] = true
			end
			if entry.OneTime then
				profile.StarterPack = true
			end
		end
		profile.Gems += gems
		table.insert(profile.Receipts, receiptId)
		if #profile.Receipts > MAX_RECEIPTS then
			table.remove(profile.Receipts, 1)
		end
		DataService:Replicate(player)
		player:SetAttribute("StarterBought", profile.StarterPack == true)
		Remotes.Notify:FireClient(player, entry.Name .. ": +◆" .. gems .. ". Thank you!", "Good")
	end
	return DataService:Save(player)
end

return StoreService
