-- ReadyFx: makes a ready Ability / Ultimate hard to miss without shouting (owner 2026-11-03: "I always forget
-- or don't notice"; then: no sound, no big text mid-screen, keep it on the slots, any text subtle).
-- HUDController calls ReadyFx.Update(slot, ready, opts) every frame for each slot
-- (slot = { Frame = <slot panel> }; opts = { Color, Key, Big = true for the ultimate }).
--   becomes ready   the slot pops, a ring bursts off it, a small "READY · F" tag rises off its top edge
--   while ready     a glow outline breathes around the slot and a light sweeps across it
--   left unused     every REMIND seconds the pop, ring and tag come back as a reminder

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ReadyFx = {}

local REMIND = 15 -- seconds a ready slot may sit unused before it nudges again
local state = {} -- [slot.Frame] = { Ready, Since, Stroke, Sheen, Scale }

local function new(className, props)
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function setup(frame, color)
	local s = { Ready = nil, Since = 0 }
	-- glow: a hollow frame just outside the slot whose stroke breathes while ready
	local glow = new("Frame", { Name = "ReadyGlow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 6, 1, 6), BackgroundTransparency = 1, ZIndex = 4, Parent = frame })
	s.Stroke = new("UIStroke", { Color = color, Thickness = 2, Transparency = 1, Parent = glow })
	-- sheen: a soft white band that sweeps across the slot while ready
	local clip = new("Frame", { Name = "ReadySheen", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 4, Parent = frame })
	s.Sheen = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(-0.3, 0), Size = UDim2.new(0, 34, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4, Parent = clip })
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) }), Parent = s.Sheen })
	s.Scale = frame:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = frame })
	state[frame] = s
	return s
end

-- small tag that rises off the slot's top edge and fades
local function tag(frame, text, color)
	local label = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(140, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = text, TextSize = 13, TextColor3 = color, TextTransparency = 1, ZIndex = 6, Parent = frame })
	local stroke = new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 1, Parent = label })
	local rise = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, rise, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0, -4) }):Play()
	TweenService:Create(stroke, rise, { Transparency = 0.4 }):Play()
	task.delay(1.6, function()
		local out = TweenInfo.new(0.5)
		TweenService:Create(label, out, { TextTransparency = 1, Position = UDim2.new(0.5, 0, 0, -12) }):Play()
		TweenService:Create(stroke, out, { Transparency = 1 }):Play()
		task.delay(0.55, label.Destroy, label)
	end)
end

local function ring(frame, color)
	local burst = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = frame })
	local stroke = new("UIStroke", { Color = color, Thickness = 5, Parent = burst })
	local info = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(burst, info, { Size = UDim2.new(1, 60, 1, 60) }):Play()
	TweenService:Create(stroke, info, { Thickness = 1, Transparency = 1 }):Play()
	task.delay(0.6, burst.Destroy, burst)
end

local function announce(frame, opts, s)
	s.Since = os.clock()
	s.Scale.Scale = 1.22
	TweenService:Create(s.Scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	ring(frame, opts.Color)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	tag(frame, if touch then "READY" else "READY  ·  " .. opts.Key, opts.Color)
end

function ReadyFx.Update(slot, ready, opts)
	local frame = slot.Frame
	local s = state[frame] or setup(frame, opts.Color)
	if ready and s.Ready == false then
		announce(frame, opts, s)
	elseif ready and s.Ready and os.clock() - s.Since > REMIND and Players.LocalPlayer:GetAttribute("InRun") then
		announce(frame, opts, s) -- still unused: nudge again
	end
	s.Ready = ready
	if ready then
		local t = os.clock() - s.Since
		local pulse = 0.5 + 0.5 * math.sin(t * (if opts.Big then 6 else 4.5))
		s.Stroke.Transparency = 0.45 - 0.4 * pulse
		s.Stroke.Thickness = 2 + (if opts.Big then 3 else 2) * pulse
		s.Sheen.Position = UDim2.fromScale(-0.3 + ((t % 2.2) / 2.2) * 1.6, 0) -- one pass every 2.2s
		s.Sheen.BackgroundTransparency = 0
	else
		s.Stroke.Transparency = 1
		s.Sheen.BackgroundTransparency = 1
	end
end

return ReadyFx
