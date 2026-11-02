-- UIKit: tiny helpers for building UI in code with one consistent theme.
-- All UI in this game is created from code (no StarterGui assets), so restyling = edit Theme.
--   UIKit.new(className, props, children?)  -> Instance (props.Parent applied last)
--   UIKit.Screen(name)                      -> ScreenGui in PlayerGui
--   UIKit.Panel(props) / Label(props) / Button(props, onClick)
--   UIKit.Corner(radius), UIKit.Stroke(color, thickness), UIKit.Padding(px)
--   UIKit.AutoScale(root)                   -> UIScale that fits a full-screen root to the screen size

local Players = game:GetService("Players")

local UIKit = {}

UIKit.Theme = {
	Font = Enum.Font.FredokaOne,
	Panel = Color3.fromRGB(20, 22, 28),
	PanelTransparency = 0.2,
	Card = Color3.fromRGB(38, 41, 50),
	Text = Color3.fromRGB(245, 245, 245),
	SubText = Color3.fromRGB(170, 175, 188),
	Cash = Color3.fromRGB(92, 224, 122), -- in-run currency: always green + "$"
	Gem = Color3.fromRGB(190, 130, 255), -- persistent currency: always purple + "◆"
	Danger = Color3.fromRGB(240, 75, 70),
	Health = Color3.fromRGB(90, 220, 110),
	Accent = Color3.fromRGB(255, 196, 60),
	Disabled = Color3.fromRGB(85, 88, 96),
}

function UIKit.new(className, props, children)
	local inst = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

local function merge(defaults, props)
	local out = table.clone(defaults)
	for k, v in props or {} do
		out[k] = v
	end
	return out
end

function UIKit.Corner(radius)
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function UIKit.Stroke(color, thickness)
	return UIKit.new("UIStroke", { Color = color or Color3.new(0, 0, 0), Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function UIKit.Padding(px)
	local u = UDim.new(0, px)
	return UIKit.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function UIKit.Screen(name)
	return UIKit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
end

-- Scales a full-screen root Frame (Position 0,0) with the screen height; layouts are designed for an
-- 800 px tall screen. A UIScale also shrinks the root itself, so the root is sized 1/s to keep covering
-- the screen. Returns the UIScale: divide screen pixels (mouse positions) by its Scale.
function UIKit.AutoScale(root)
	local scale = UIKit.new("UIScale", { Parent = root })
	local camera = workspace.CurrentCamera
	local function update()
		local s = math.clamp(camera.ViewportSize.Y / 800, 0.6, 1.5)
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	update()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	return scale
end

function UIKit.Panel(props)
	local frame = UIKit.new("Frame", merge({
		BackgroundColor3 = UIKit.Theme.Panel,
		BackgroundTransparency = UIKit.Theme.PanelTransparency,
		BorderSizePixel = 0,
	}, props))
	UIKit.Corner(12).Parent = frame
	return frame
end

function UIKit.Label(props)
	local label = UIKit.new("TextLabel", merge({
		BackgroundTransparency = 1,
		Font = UIKit.Theme.Font,
		TextColor3 = UIKit.Theme.Text,
		TextSize = 20,
		Text = "",
	}, props))
	local stroke = UIKit.new("UIStroke", { Thickness = 1.5, Transparency = 0.4 })
	stroke.Parent = label
	return label
end

function UIKit.Button(props, onClick)
	local button = UIKit.new("TextButton", merge({
		BackgroundColor3 = UIKit.Theme.Accent,
		BorderSizePixel = 0,
		Font = UIKit.Theme.Font,
		TextColor3 = Color3.fromRGB(25, 25, 30),
		TextSize = 20,
		AutoButtonColor = true,
	}, props))
	UIKit.Corner(8).Parent = button
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

return UIKit
