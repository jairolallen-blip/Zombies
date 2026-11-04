-- JoinCover: covers the screen from the first frame of a join, so nobody glimpses the world (their
-- character standing in the lobby) before the welcome screen is built. It is drawn in the welcome
-- screen's own dusk colours and letterbox, so the hand-off reads as one scene.
-- Client/Controllers/WelcomeController fades it out: once the welcome screen is up, or as soon as the
-- character exists when there's no welcome screen (new players, match servers). Gone after 25s regardless.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "JoinCover"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 70 -- above the welcome screen (60): it fades away to reveal it

local cover = Instance.new("Frame")
cover.Name = "Cover"
cover.Size = UDim2.fromScale(1, 1)
cover.BackgroundColor3 = Color3.new(1, 1, 1)
cover.BorderSizePixel = 0
cover.Parent = gui
local dusk = Instance.new("UIGradient") -- WelcomeController's sky
dusk.Rotation = 90
dusk.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 22, 30)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(110, 52, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 18, 18)),
})
dusk.Parent = cover

for _, top in { true, false } do -- letterbox bars, like the welcome screen
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
	bar.Position = UDim2.fromScale(0, if top then 0 else 1)
	bar.Size = UDim2.new(1, 0, 0.07, 0)
	bar.BackgroundColor3 = Color3.fromRGB(8, 6, 8)
	bar.BorderSizePixel = 0
	bar.Parent = cover
end

local kicker = Instance.new("TextLabel")
kicker.Name = "Kicker"
kicker.AnchorPoint = Vector2.new(1, 1)
kicker.Position = UDim2.new(1, -48, 0.93, -24)
kicker.Size = UDim2.fromOffset(500, 18)
kicker.BackgroundTransparency = 1
kicker.Font = Enum.Font.GothamBold
kicker.TextSize = 15
kicker.TextColor3 = Color3.fromRGB(255, 170, 90)
kicker.TextXAlignment = Enum.TextXAlignment.Right
kicker.Text = "SAFEHOUSE  //  PORT HARROW"
kicker.Parent = cover

gui.Parent = player:WaitForChild("PlayerGui")
task.delay(25, function()
	if gui.Parent then
		gui:Destroy()
	end
end)
