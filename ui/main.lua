local CoreGui = game:GetService("CoreGui")
local UserInput = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Interface = import("rbxassetid://11389137937")

if oh.Cache["ui/main"] then
	return Interface
end

import("ui/controls/TabSelector")
local MessageBox, MessageType = import("ui/controls/MessageBox")

local RemoteSpy
local ClosureSpy
local ScriptScanner
local ModuleScanner
local UpvalueScanner
local ConstantScanner

xpcall(function()
	RemoteSpy = import("ui/modules/RemoteSpy")
	ClosureSpy = import("ui/modules/ClosureSpy")
	ScriptScanner = import("ui/modules/ScriptScanner")
	ModuleScanner = import("ui/modules/ModuleScanner")
	UpvalueScanner = import("ui/modules/UpvalueScanner")
	ConstantScanner = import("ui/modules/ConstantScanner")
end, function(err)
	local message
	if err:find("valid member") then
		message = "The UI has updated, please rejoin and restart. If you get this message more than once, screenshot this message and report it in the Hydroxide+ server.\n\n" .. err
	else
		message = "Report this error in Hydroxide+'s server:\n\n" .. err
	end

	MessageBox.Show("An error has occurred", message, MessageType.OK, function()
		Interface:Destroy() 
	end)
end)

local Open = Interface.Open
local Base = Interface.Base
local Drag = Base.Drag
local Status = Base.Status
local Collapse = Drag.Collapse

local constants = {
	opened = UDim2.new(0.5, -325, 0.5, -175),
	closed = UDim2.new(0.5, -325, 0, -400),
	reveal = UDim2.new(0.5, -15, 0, 20),
	conceal = UDim2.new(0.5, -15, 0, -75)
}

local MINIMUM_SCALE = 0.4
local MAXIMUM_SCALE = 2
local MAXIMUM_AUTOMATIC_SCALE = 1
local VIEWPORT_PADDING = 32
local designSize = Vector2.new(Base.Size.X.Offset, Base.Size.Y.Offset)
local baseScale = Instance.new("UIScale")
local openScale = Instance.new("UIScale")
local ResizeHandle = Instance.new("TextButton")
local scaleOverride
local currentScale = 1
local collapsed = false

baseScale.Name = "ResponsiveScale"
baseScale.Parent = Base
openScale.Name = "ResponsiveScale"
openScale.Parent = Open

ResizeHandle.Name = "ResizeHandle"
ResizeHandle.AnchorPoint = Vector2.new(1, 1)
ResizeHandle.Position = UDim2.new(1, -3, 1, -3)
ResizeHandle.Size = UDim2.new(0, 28, 0, 28)
ResizeHandle.BackgroundTransparency = 1
ResizeHandle.Text = "◢"
ResizeHandle.TextColor3 = Color3.fromRGB(0, 225, 225)
ResizeHandle.TextSize = 22
ResizeHandle.Font = Enum.Font.SourceSansBold
ResizeHandle.TextXAlignment = Enum.TextXAlignment.Right
ResizeHandle.TextYAlignment = Enum.TextYAlignment.Bottom
ResizeHandle.AutoButtonColor = false
ResizeHandle.Active = true
ResizeHandle.ZIndex = 100
ResizeHandle.Parent = Base

local function scaledPosition(position)
	return UDim2.new(
		position.X.Scale,
		position.X.Offset * currentScale,
		position.Y.Scale,
		position.Y.Offset * currentScale
	)
end

local function automaticScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local availableWidth = math.max(viewport.X - VIEWPORT_PADDING, 1)
	local availableHeight = math.max(viewport.Y - VIEWPORT_PADDING, 1)

	return math.clamp(math.min(availableWidth / designSize.X, availableHeight / designSize.Y), MINIMUM_SCALE, MAXIMUM_AUTOMATIC_SCALE)
end

local function applyScale(preservePosition)
	currentScale = scaleOverride or automaticScale()
	baseScale.Scale = currentScale
	openScale.Scale = currentScale

	if not preservePosition then
		Base.Position = scaledPosition(collapsed and constants.closed or constants.opened)
		Open.Position = scaledPosition(collapsed and constants.reveal or constants.conceal)
	end
end

function oh.setScale(scale)
	if scale == nil then
		scaleOverride = nil
	else
		assert(type(scale) == "number", "scale must be a number or nil")
		scaleOverride = math.clamp(scale, MINIMUM_SCALE, MAXIMUM_SCALE)
	end

	applyScale()
	return currentScale
end

function oh.getScale()
	return currentScale
end

local function watchCamera()
	if oh.Events.ViewportScale then
		oh.Events.ViewportScale:Disconnect()
		oh.Events.ViewportScale = nil
	end

	local camera = workspace.CurrentCamera
	if camera then
		oh.Events.ViewportScale = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
	end

	applyScale()
end

oh.Events.CurrentCameraScale = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

function oh.setStatus(text)
	Status.Text = '• Status: ' .. text
end

function oh.getStatus()
	return Status.Text:gsub('• Status: ', '')
end

local dragging
local dragStart
local startPos
local resizing
local resizeInput
local resizeStart
local resizeStartScale

Drag.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local dragEnded 

		dragging = true
		dragStart = input.Position
		startPos = Base.Position

		dragEnded = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				dragEnded:Disconnect()
			end
		end)
	end
end)

ResizeHandle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local resizeEnded

		resizing = true
		resizeInput = input
		resizeStart = input.Position
		resizeStartScale = currentScale
		scaleOverride = currentScale

		resizeEnded = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				resizing = false
				resizeInput = nil
				resizeEnded:Disconnect()
			end
		end)
	end
end)

oh.Events.Drag = UserInput.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
		local delta = input.Position - dragStart
		Base.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

oh.Events.Resize = UserInput.InputChanged:Connect(function(input)
	local isMouseMovement = input.UserInputType == Enum.UserInputType.MouseMovement
	local isTrackedTouch = input.UserInputType == Enum.UserInputType.Touch and input == resizeInput

	if resizing and (isMouseMovement or isTrackedTouch) then
		local delta = input.Position - resizeStart
		local width = designSize.X
		local height = designSize.Y
		local scaleDelta = (delta.X * width + delta.Y * height) / (width * width + height * height)

		scaleOverride = math.clamp(resizeStartScale + scaleDelta, MINIMUM_SCALE, MAXIMUM_SCALE)
		applyScale(true)
	end
end)

Open.MouseButton1Click:Connect(function()
	collapsed = false
	Open:TweenPosition(scaledPosition(constants.conceal), "Out", "Quad", 0.15)
	Base:TweenPosition(scaledPosition(constants.opened), "Out", "Quad", 0.15)
end)

Collapse.MouseButton1Click:Connect(function()
	collapsed = true
	Base:TweenPosition(scaledPosition(constants.closed), "Out", "Quad", 0.15)
	Open:TweenPosition(scaledPosition(constants.reveal), "Out", "Quad", 0.15)
end)

Interface.Name = HttpService:GenerateGUID(false)
Interface.DisplayOrder = 2147483647
Interface.IgnoreGuiInset = true

if setHiddenProperty then
	for _, property in ipairs({ "OnTopOfCoreBlur", "IgnoresTitleBarReservation" }) do
		local ok, success, reason = pcall(setHiddenProperty, Interface, property, true)

		if not ok then
			warn(("[Hydroxide+] Could not set %s: %s"):format(property, tostring(success)))
		elseif not success then
			warn(("[Hydroxide+] Could not set %s%s"):format(property, reason and ": " .. tostring(reason) or ""))
		end
	end
end

if getHui then
	Interface.Parent = getHui()
else
	Interface.Parent = CoreGui
end

return Interface
