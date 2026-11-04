-- UIKit: tiny helpers for building UI in code with one consistent theme.
-- All UI in this game is created from code (no StarterGui assets), so restyling = edit Theme.
--   UIKit.new(className, props, children?)  -> Instance (props.Parent applied last)
--   UIKit.Screen(name)                      -> ScreenGui in PlayerGui
--   UIKit.Panel(props) / Label(props) / Button(props, onClick)
--   UIKit.Corner(radius), UIKit.Stroke(color, thickness), UIKit.Padding(px)
--   UIKit.AutoScale(root)                   -> UIScale that fits a full-screen root to the screen size

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIKit = {}

UIKit.Theme = {
	Font = Enum.Font.GothamMedium, -- clean modern body face; pairs with GothamBlack display
	FontTitle = Enum.Font.GothamBlack, -- heavy display face for titles/big numbers
	-- NEUTRAL SCALE (one warm dark-grey family — everything structural uses only these)
	N950 = Color3.fromRGB(16, 16, 18), -- deepest: bar backs, chips behind fills
	N900 = Color3.fromRGB(23, 24, 27), -- panels
	N800 = Color3.fromRGB(33, 34, 39), -- cards, rows
	N700 = Color3.fromRGB(44, 46, 52), -- plates, inactive tabs
	N600 = Color3.fromRGB(58, 61, 69), -- borders, strokes, disabled
	N400 = Color3.fromRGB(155, 161, 173), -- secondary text
	N300 = Color3.fromRGB(201, 205, 214), -- body text
	N100 = Color3.fromRGB(242, 243, 245), -- primary text
	-- ACCENT SCALE (single hue: amber — the only accent; red is danger-only)
	A700 = Color3.fromRGB(122, 84, 26),
	A600 = Color3.fromRGB(176, 124, 38),
	A500 = Color3.fromRGB(232, 170, 66),
	A400 = Color3.fromRGB(244, 196, 110),
	A300 = Color3.fromRGB(252, 222, 160),
	-- SEMANTIC (desaturated to sit on the neutrals; tier colors are small chips/fills only)
	Panel = Color3.fromRGB(23, 24, 27),
	PanelImage = "rbxassetid://119762950566147", -- old 9-slice metal plate; UNUSED (its rivets read as stray "( )" glyphs)
	PanelFill = Color3.fromRGB(14, 12, 14), -- panels: the welcome screen's warm near-black tile
	PanelEdge = Color3.fromRGB(70, 56, 52), -- and its thin warm stroke
	HeaderImage = "rbxassetid://116363851713308", -- generated brushed-amber header strip
	-- one consistent monoline icon set (generated, tintable via ImageColor3) — never emoji
	Icons = {
		Damage = "rbxassetid://127054755202634",
		FireRate = "rbxassetid://123777378849589",
		Magazine = "rbxassetid://98957714317686",
		Range = "rbxassetid://118584573132763",
		Skull = "rbxassetid://76369518523172",
		Gem = "rbxassetid://126635362022019",
		Coin = "rbxassetid://102351308534850",
		Health = "rbxassetid://132007111451408",
		Bolt = "rbxassetid://111566464988970",
		Star = "rbxassetid://105043401870932",
		Compass = "rbxassetid://100188531193039",
		Medal = "rbxassetid://103984007361659",
		Gun = "rbxassetid://107416201161059",
	},
	PanelTransparency = 0.25,
	Card = Color3.fromRGB(33, 34, 39),
	Text = Color3.fromRGB(242, 243, 245),
	SubText = Color3.fromRGB(155, 161, 173),
	Cash = Color3.fromRGB(140, 200, 70), -- in-run currency: always green + "$"
	Gem = Color3.fromRGB(167, 108, 235), -- persistent currency: always purple + "◆"
	Danger = Color3.fromRGB(235, 77, 66),
	Health = Color3.fromRGB(122, 194, 82),
	Accent = Color3.fromRGB(232, 170, 66),
	Sign = Color3.fromRGB(150, 255, 90),
	Disabled = Color3.fromRGB(58, 61, 69),
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

-- A window header: accent title bar + content frame beneath it with consistent padding.
-- Returns the content frame; parent widgets to it, not to the panel.
function UIKit.Header(panel, title, accent)
	local bar = UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Color3.fromRGB(14, 14, 15),
		BorderSizePixel = 0,
		Parent = panel,
	})
	UIKit.Corner(6).Parent = bar
	UIKit.new("Frame", { -- accent keyline under the bar
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = accent or UIKit.Theme.Accent,
		BorderSizePixel = 0,
		Parent = bar,
	})
	UIKit.Label({ Text = title, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0), TextSize = 24, Font = UIKit.Theme.FontTitle, TextXAlignment = Enum.TextXAlignment.Left, Parent = bar })
	local content = UIKit.new("Frame", {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	UIKit.Padding(16).Parent = content
	return content
end

-- Drop-shadow imitation: Roblox UI has no blur, so a dark offset underlay reads as elevation.
-- Call BEFORE the panel (it renders beneath as a sibling added first).
function UIKit.Shadow(parent, props, lift)
	local shadow = UIKit.new("Frame", merge({
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
	}, props))
	if lift then -- offset down-right by `lift` px, same corner rounding as the panel above
		shadow.Position -= UDim2.fromOffset(lift, lift)
		shadow.Size += UDim2.fromOffset(lift * 2, lift * 2)
	end
	shadow.Parent = parent
	return shadow
end

-- Monoline icon from the generated set; tint with ImageColor3 (glyphs are drawn white)
function UIKit.Icon(name, props)
	return UIKit.new("ImageLabel", merge({
		Image = UIKit.Theme.Icons[name],
		ImageColor3 = UIKit.Theme.Text,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, props))
end

function UIKit.Corner(radius)
	-- sharp-corner style: small radii become 0 (square). Only circles (scope, touch buttons) keep
	-- their rounding.
	local r = radius or 3
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, if r < 20 then 0 else r) })
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
	-- a flat warm panel (the welcome-screen tile). It stays an ImageLabel so callers' props still apply, but
	-- draws no image: the old 9-slice metal texture put rivet curls at its edges that looked like stray glyphs
	local frame = UIKit.new("ImageLabel", merge({
		Image = "",
		BackgroundColor3 = UIKit.Theme.PanelFill,
		BackgroundTransparency = UIKit.Theme.PanelTransparency,
		BorderSizePixel = 0,
	}, props))
	local stroke = UIKit.Stroke(UIKit.Theme.PanelEdge, 1)
	stroke.Transparency = 0.1
	stroke.Parent = frame
	return frame
end

function UIKit.Label(props)
	-- outlines are for text floating over the 3D world only; text inside panels uses color
	-- hierarchy instead (clean, modern). Pass Outline = true to opt in.
	local wantsOutline = props and props.Outline or false
	local clean = table.clone(props or {})
	clean.Outline = nil
	local label = UIKit.new("TextLabel", merge({
		BackgroundTransparency = 1,
		Font = UIKit.Theme.Font,
		TextColor3 = UIKit.Theme.Text,
		TextSize = 20,
		Text = "",
	}, clean))
	if wantsOutline then
		-- colour theory: the outline is a deep SHADE of the text's own hue (same colour, much darker),
		-- not a flat black — so red text gets a dark-red rim, amber gets dark amber, etc. The outline
		-- always matches. Thickness scales with the text: hairline on small, chunk on banners.
		local function outlineColor()
			return label.TextColor3:Lerp(Color3.new(0, 0, 0), 0.75)
		end
		local stroke = UIKit.new("UIStroke", { Color = outlineColor(), Thickness = math.clamp(label.TextSize * 0.07, 1.5, 3), Transparency = label.TextTransparency })
		stroke.Parent = label
		-- the outline fades with the text, so hidden labels (TextTransparency = 1) leave no ghost
		label:GetPropertyChangedSignal("TextTransparency"):Connect(function()
			stroke.Transparency = label.TextTransparency
		end)
		-- and re-shades itself when the text colour changes (hitmarkers, banners, health warnings)
		label:GetPropertyChangedSignal("TextColor3"):Connect(function()
			stroke.Color = outlineColor()
		end)
	end
	return label
end

-- Military-diegetic corner brackets: four L-shaped accent marks framing a panel (tactical HUD look)
function UIKit.Brackets(frame, color, length, transparency)
	color = color or UIKit.Theme.N400 -- neutral by default; the accent is for action/state only
	length = length or 10
	transparency = transparency or 0.25
	local ends = {
		{ AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(0, 0), Horizontal = true },
		{ AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(0, 0), Horizontal = false },
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Horizontal = true },
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Horizontal = false },
		{ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Horizontal = true },
		{ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Horizontal = false },
		{ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Horizontal = true },
		{ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Horizontal = false },
	}
	for _, e in ends do
		UIKit.new("Frame", {
			AnchorPoint = e.AnchorPoint,
			Position = e.Position,
			Size = if e.Horizontal then UDim2.fromOffset(length, 2) else UDim2.fromOffset(2, length),
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = frame,
		})
	end
end

-- Tiny stencil-style section label: uppercase, letterspaced, dim — "STATUS", "AMMUNITION"
function UIKit.Stencil(text, props)
	local clean = table.clone(props or {})
	return UIKit.Label(merge({
		Text = text:upper():gsub(".", "%0 "):gsub("%s+$", ""),
		TextSize = 12,
		TextColor3 = UIKit.Theme.SubText,
		BackgroundTransparency = 1,
	}, clean))
end

function UIKit.Button(props, onClick)
	local button = UIKit.new("TextButton", merge({
		BackgroundColor3 = UIKit.Theme.Accent,
		BorderSizePixel = 0,
		Font = UIKit.Theme.FontTitle, -- buttons carry the heavy display face
		TextColor3 = Color3.fromRGB(28, 26, 22),
		TextSize = 20,
		AutoButtonColor = false, -- hover/press are hand-tweened below; AutoButtonColor flickers
	}, props))
	UIKit.Corner(6).Parent = button
	local bstroke = UIKit.Stroke(Color3.fromRGB(96, 98, 100), 1)
	bstroke.Transparency = 0.2
	bstroke.Parent = button
	if onClick then
		button.Activated:Connect(onClick)
	end
	-- alive buttons: hover lifts the surface, press sinks it (the #1 tell of cheap Roblox UI is
	-- buttons that ignore the mouse)
	local baseColor = button.BackgroundColor3
	local hoverColor = baseColor:Lerp(Color3.new(1, 1, 1), 0.12)
	local pressColor = baseColor:Lerp(Color3.new(0, 0, 0), 0.18)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = hoverColor }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = baseColor }):Play()
	end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(button, TweenInfo.new(0.05), { BackgroundColor3 = pressColor }):Play()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = hoverColor }):Play()
		end
	end)
	-- recolouring code (e.g. affordability) updates the hover target too
	button:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		local c = button.BackgroundColor3
		if c ~= hoverColor and c ~= pressColor then
			baseColor = c
			hoverColor = c:Lerp(Color3.new(1, 1, 1), 0.12)
			pressColor = c:Lerp(Color3.new(0, 0, 0), 0.18)
		end
	end)
	return button
end

return UIKit
