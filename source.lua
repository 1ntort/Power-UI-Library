if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Core module setup
local module = {currentInstance = nil}
local lockedModule

-- Services
local tweenService = game:GetService("TweenService")
local soundService = game:GetService("SoundService")
local players = game:GetService("Players")

-- Player references
local player = players.LocalPlayer
local character = player.Character

player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
end)

-- GUI references
local powerGUI = script["."]:Clone()
powerGUI.Enabled = false
powerGUI.Parent = player.PlayerGui
local bar = powerGUI.bar
local sounds = powerGUI.sounds

-- Module locking function
local function lockModule(t)
	return setmetatable({}, {
		__index = t,
		__newindex = function() error("This table is locked!") end,
		__metatable = "locked"
	})
end

-- Argument validation helper
local function validateArg(value, expectedType, argName)
	if typeof(value) ~= expectedType then
		error(`Invalid type for {argName}. Expected {expectedType}, got {typeof(value)}`)
	end
end

-- Sound management
local function playSound(soundName)
	validateArg(soundName, "string", "soundName")

	local sound = sounds:FindFirstChild(soundName)
	if sound then
		soundService:PlayLocalSound(sound)
	end
end

-- UI Fade System
local function getFadeProperties(instance)
	validateArg(instance, "Instance", "instance")

	if instance:IsA("Frame") then
		return { BackgroundTransparency = 1 }
	elseif instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		return {
			BackgroundTransparency = 1,
			TextTransparency = 1
		}
	elseif instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		return {
			BackgroundTransparency = 1,
			ImageTransparency = 1
		}
	elseif instance:IsA("UIStroke") then
		return { Transparency = 1 }
	end
end

local function fadeUI(instance, tweenInfo, exclude)
	validateArg(instance, "Instance", "instance")
	validateArg(tweenInfo, "TweenInfo", "tweenInfo")

	if exclude and table.find(exclude, instance) then return end

	local properties = getFadeProperties(instance)
	if not properties then return end

	local originalValues = {}
	for prop, _ in pairs(properties) do
		originalValues[prop] = instance[prop]
	end

	if tweenInfo.Time == 0 then
		for prop, value in pairs(properties) do
			instance[prop] = value
		end
	else
		tweenService:Create(instance, tweenInfo, properties):Play()
	end

	return originalValues
end

local function fade(instance, duration, exclude)
	validateArg(instance, "Instance", "instance")
	validateArg(duration, "number", "duration")

	exclude = exclude or {}
	local before = {}
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.In)

	if not table.find(exclude, instance) then
		local instBefore = fadeUI(instance, tweenInfo, exclude)
		if instBefore then
			before[instance] = instBefore
		end
	end

	for _, object in pairs(instance:GetDescendants()) do
		local instBefore = fadeUI(object, tweenInfo, exclude)
		if not instBefore then continue end
		before[object] = instBefore
	end

	return before
end

local function unFade(before, duration, exclude)
	validateArg(before, "table", "before")
	validateArg(duration, "number", "duration")

	exclude = exclude or {}
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.In)

	for inst, properties in pairs(before) do
		if table.find(exclude, inst) then continue end

		if duration == 0 then
			for index, value in pairs(properties) do
				inst[index] = value
			end
		else
			tweenService:Create(inst, tweenInfo, properties):Play()
		end
	end
end

-- Premium state
local isPremium = false
function module:setPremium(premium)
	validateArg(premium, "boolean", "premium")
	isPremium = premium
end

-- Title Management
function module:setTitle(title)
	validateArg(title, "string", "title")
	bar.content.name.name.Text = title
end

-- Hover animations
local function defaultMouseEnter(border: UIStroke)
	return function()
		playSound("on hover")
		tweenService:Create(border, TweenInfo.new(
			0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In
			), {
				Color = Color3.fromRGB(180, 71, 235),
			}):Play()
	end
end

local function defaultMouseLeave(border: UIStroke)
	local oldBorderColor = border.Color
	return function()
		playSound("off hover")
		tweenService:Create(border, TweenInfo.new(
			0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
			), {
				Color = oldBorderColor,
			}):Play()
	end
end

-- Page System
local pages = bar.pages
local pagesBar = bar.content.pages
local currentlySelected = nil
local currentlyOpenPage = nil
local pageFades = {}

-- Initialize page templates
for _, inst in pairs(bar:GetDescendants()) do
	if string.sub(inst.Name, 1, 2) == "__" then
		inst.Visible = false
	end
end

local function closePage(identifier)
	validateArg(identifier, "string", "identifier")

	local page = pages:FindFirstChild(identifier)
	if page then
		currentlyOpenPage = nil
		pageFades[identifier] = fade(page, 0.5)

		tweenService:Create(page, TweenInfo.new(
			0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
			), {
				Position = UDim2.new(0.5, 0, 0, 450),
				Size = UDim2.new(1, 0, 0, 0)
			}):Play()
	end
end

local function openPage(identifier)
	validateArg(identifier, "string", "identifier")

	local page = pages:FindFirstChild(identifier)
	if page then
		if currentlyOpenPage then
			closePage(currentlyOpenPage.Name)
		end

		currentlyOpenPage = page

		if pageFades[identifier] then
			page.Visible = true
		else
			pageFades[identifier] = fade(page, 0)
			page.Visible = true
		end

		unFade(pageFades[identifier], 0.5)
		tweenService:Create(page, TweenInfo.new(
			0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
			), {
				Position = UDim2.new(0.5, 0, 0, 0),
				Size = UDim2.new(1, 0, 0, 350)
			}):Play()
	end
end

local clickCooldown = false
local function pageMouseDown(obj, border, name)
	return function()
		if clickCooldown then return end
		clickCooldown = true

		openPage(obj.Parent.Name)

		if currentlySelected then
			local oldObj = currentlySelected
			local oldBorder = oldObj.border
			local oldName = oldObj.name

			local background = 0.95
			local color = Color3.fromRGB(180, 71, 235)
			if oldObj:FindFirstChild("image") then
				background = 0.5
				color = Color3.fromRGB(25, 229, 230)
			end

			oldBorder.Transparency = 0
			tweenService:Create(oldObj, TweenInfo.new(
				0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
				), {
					BackgroundTransparency = background
				}):Play()

			tweenService:Create(oldName, TweenInfo.new(
				0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
				), {
					TextColor3 = color
				}):Play()
		end

		playSound("click")
		if currentlySelected == obj then
			currentlySelected = nil
			closePage(obj.Parent.Name)
		else
			currentlySelected = obj

			local background = 0.25
			local color = Color3.fromRGB(25, 229, 230)

			border.Transparency = 1
			tweenService:Create(obj, TweenInfo.new(
				0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In
				), {
					BackgroundTransparency = background
				}):Play()

			tweenService:Create(name, TweenInfo.new(
				0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In
				), {
					TextColor3 = color
				}):Play()
		end

		task.delay(0.6, function()
			clickCooldown = false
		end)
	end
end

function module:makePage(identifier, displayName, premium)
	validateArg(identifier, "string", "identifier")
	validateArg(displayName, "string", "displayName")

	if #identifier > 50 then
		error(`Identifier is too long! ({#identifier} characters)`)
	end
	if #displayName > 20 then
		error(`DisplayName is too long! ({#displayName} characters)`)
	end

	local pageButton = pagesBar.__example
	if premium == true then
		pageButton = pagesBar.__premium
	end

	pageButton = pageButton:Clone()
	local content = pageButton.content
	pageButton.Name = identifier
	content.name.Text = displayName

	pageButton.Parent = pagesBar
	if content.name.TextFits == false then
		for i = 1, 50 do
			pageButton.Size += UDim2.new(0, 2, 0, 0)
			if content.name.TextFits ~= false then
				break
			end
		end
	end

	local button, border, name = content.button, content.border, content.name
	if (premium and isPremium) or not premium then
		button.MouseButton1Down:Connect(pageMouseDown(content, border, name))
	end
	button.MouseEnter:Connect(defaultMouseEnter(border))
	button.MouseLeave:Connect(defaultMouseLeave(border))

	pageButton.Visible = true

	local page = pages.__example:Clone()
	page.Name = identifier
	page.topbar.name.Text = displayName

	page.Position = UDim2.new(0.5, 0, 0, 450)
	page.Size = UDim2.new(1, 0, 0, 0)

	page.Parent = pages
	if page.topbar.name.TextFits == false then
		for i = 1, 50 do
			page.topbar.name.Size += UDim2.new(0, 2, 0, 0)
			if page.topbar.name.TextFits ~= false then
				break
			end
		end
	end

	if premium then
		page.topbar.image.Visible = true
	end

	page.Visible = false

	local newModule = table.clone(module)
	newModule.currentInstance = {
		name = identifier,
		instance = page,
		type = "page"
	}
	return lockModule(newModule)
end

-- Toggle System
local toggleCooldowns, toggleToggled = {}, {}
local function toggleMouseDown(obj, func)
	return function()
		if toggleCooldowns[obj] then return end
		toggleCooldowns[obj] = true

		playSound("click")
		local toggle = toggleToggled[obj]

		if toggle then
			tweenService:Create(obj, TweenInfo.new(
				0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
				), {
					Position = UDim2.new(1, -21, 0.5, 0),
				}):Play()
		else
			tweenService:Create(obj, TweenInfo.new(
				0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
				), {
					Position = UDim2.new(0, 0, 0.5, 0),
				}):Play()
		end

		toggleToggled[obj] = not toggle
		task.delay(0.5, function()
			toggleCooldowns[obj] = false
		end)

		func(toggle)
	end
end

function module:addToggle(displayName, func, description, default)
	validateArg(displayName, "string", "displayName")
	validateArg(func, "function", "func")

	if self.currentInstance == nil or self.currentInstance.type ~= "page" then
		error("addToggle must be called on a page")
	end

	local page = self.currentInstance.instance
	local toggle = page.content.__toggle:Clone()
	toggle.Name = "toggle-"..displayName

	toggleToggled[toggle.content.toggle.indicator] = true

	if default == true then
		toggleToggled[toggle.content.toggle.indicator] = false
	end

	toggle.content.name.name.Text = displayName

	if description then
		validateArg(description, "string", "description")
		toggle.content.name.description.Text = description
	else
		toggle.content.name.description.Visible = false
	end
	
	local button = toggle.content.button
	local border = toggle.content.border
	local indicator = toggle.content.toggle.indicator

	button.MouseButton1Down:Connect(toggleMouseDown(indicator, func))
	button.MouseEnter:Connect(defaultMouseEnter(border))
	button.MouseLeave:Connect(defaultMouseLeave(border))

	toggle.Parent = page.content
	toggle.Visible = true
	page.content.CanvasSize += UDim2.new(0, 0, 0, 55)
	
	return self
end

local buttonCooldowns = {}
local function buttonMouseDown(obj: Frame, func: (nil) -> any)
	return function()
		if buttonCooldowns[obj] then return end
		buttonCooldowns[obj] = true
		
		playSound("click")
		func()
		
		task.delay(0.5, function()
			buttonCooldowns[obj] = false
		end)
	end
end

function module:addButton(displayName, func, description)
	validateArg(displayName, "string", "displayName")
	validateArg(func, "function", "func")

	if self.currentInstance == nil or self.currentInstance.type ~= "page" then
		error("addButton must be called on a page")
	end

	local page: Frame = self.currentInstance.instance
	local button: Frame = page.content.__button:Clone()
	button.Name = "button-"..displayName
	button.content.name.name.Text = displayName

	if description then
		validateArg(description, "string", "description")
		button.content.name.description.Text = description
	else
		button.content.name.description.Visible = false
	end

	local clickButton: TextButton = button.content.button
	local border: UIStroke = button.content.border

	clickButton.MouseButton1Down:Connect(buttonMouseDown(button, func))
	clickButton.MouseEnter:Connect(defaultMouseEnter(border))
	clickButton.MouseLeave:Connect(defaultMouseLeave(border))

	button.Parent = page.content
	button.Visible = true
	page.content.CanvasSize += UDim2.new(0, 0, 0, 55)

	return self
end

local function textMouseDown(obj: TextBox)
	return function()
		playSound("click")
		obj:CaptureFocus()
		obj.Text = ""
	end
end

local function textFocusLost(obj: TextBox, func: (string) -> any)
	return function()
		local text = obj.Text
		func(text)
	end
end

function module:addText(displayName, func, description)
	validateArg(displayName, "string", "displayName")
	validateArg(func, "function", "func")

	if self.currentInstance == nil or self.currentInstance.type ~= "page" then
		error("addText must be called on a page")
	end

	local page: Frame = self.currentInstance.instance
	local text: Frame = page.content.__text:Clone()
	text.Name = "text-"..displayName
	text.content.name.name.Text = displayName

	if description then
		validateArg(description, "string", "description")
		text.content.name.description.Text = description
	else
		text.content.name.description.Visible = false
	end

	local textButton: TextButton = text.content.button
	local textBox: TextBox = text.content.text.text
	local border: UIStroke = text.content.border
	
	textButton.MouseButton1Down:Connect(textMouseDown(textBox))
	textButton.MouseEnter:Connect(defaultMouseEnter(border))
	textButton.MouseLeave:Connect(defaultMouseLeave(border))
	textBox.FocusLost:Connect(textFocusLost(textBox, func))

	text.Parent = page.content
	text.Visible = true
	page.content.CanvasSize += UDim2.new(0, 0, 0, 55)

	return self
end

local dropdownCooldowns, dropdownToggles = {}, {}
local function dropdownMouseDown(obj: Frame)
	local text = obj.text
	local symbol = obj.symbol
	local items = obj.content.items
	
	return function()
		if dropdownCooldowns[obj] then return end
		dropdownCooldowns[obj] = true
		
		if dropdownToggles[obj] then
			dropdownToggles[obj] = false
			tweenService:Create(symbol, TweenInfo.new(
				0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
				), {
					Rotation = 180
				}):Play()
			tweenService:Create(items, TweenInfo.new(
				0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
				), {
					Position = UDim2.new(0.5, 0, -1, 25)
				}):Play()
		else
			dropdownToggles[obj] = true
			tweenService:Create(symbol, TweenInfo.new(
				0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
				), {
					Rotation = 0
				}):Play()
			items.Visible = true
			tweenService:Create(items, TweenInfo.new(
				0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
				), {
					Position = UDim2.new(0.5, 0, 0, 25)
				}):Play()
		end
		
		task.delay(0.5, function()
			dropdownCooldowns[obj] = false
			if dropdownToggles[obj] == false then
				items.Visible = false
			end
		end)
	end
end

local dropdownItemSelected = {}
local function dropdownItemMouseDown(obj: Frame, item: Frame, func: (nil) -> any)
	local text = obj.text
	local itemText = item.text
	
	return function()
		if not dropdownToggles[obj] then return end
		
		if dropdownItemSelected[obj] == item then
			dropdownItemSelected[obj] = nil
			text.Text = "tap to edit"
			tweenService:Create(item, TweenInfo.new(
				0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
				), {
					BackgroundColor3 = Color3.fromRGB(32, 38, 50)
				}):Play()
			tweenService:Create(itemText, TweenInfo.new(
				0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
				), {
					TextColor3 = Color3.fromRGB(60, 72, 94)
				}):Play()
			func(nil)
		else
			if dropdownItemSelected[obj] ~= nil then
				local item = dropdownItemSelected[obj]
				local itemText = item.text
				tweenService:Create(item, TweenInfo.new(
					0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
					), {
						BackgroundColor3 = Color3.fromRGB(32, 38, 50)
					}):Play()
				tweenService:Create(itemText, TweenInfo.new(
					0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
					), {
						TextColor3 = Color3.fromRGB(60, 72, 94)
					}):Play()
			end
			dropdownItemSelected[obj] = item
			text.Text = itemText.Text
			tweenService:Create(item, TweenInfo.new(
				0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
				), {
					BackgroundColor3 = Color3.fromRGB(60, 72, 94)
				}):Play()
			tweenService:Create(itemText, TweenInfo.new(
				0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
				), {
					TextColor3 = Color3.fromRGB(25, 229, 230)
				}):Play()
			func(itemText.Text)
		end
	end
end

function module:addDropdown(displayName, items, func, description)
	validateArg(displayName, "string", "displayName")
	validateArg(items, "table", "items")
	validateArg(func, "function", "func")

	if self.currentInstance == nil or self.currentInstance.type ~= "page" then
		error("addToggle must be called on a page")
	end

	local page = self.currentInstance.instance
	local dropdown = page.content.__dropdown:Clone()
	dropdown.Name = "dropdown-"..displayName
	dropdown.content.name.name.Text = displayName

	if description then
		validateArg(description, "string", "description")
		dropdown.content.name.description.Text = description
	else
		dropdown.content.name.description.Visible = false
	end

	local button = dropdown.content.button
	local border = dropdown.content.border
	local dropdownButton = dropdown.content.dropdown
	
	button.MouseButton1Down:Connect(dropdownMouseDown(dropdownButton))
	button.MouseEnter:Connect(defaultMouseEnter(border))
	button.MouseLeave:Connect(defaultMouseLeave(border))
	
	local exampleItem = dropdownButton.content.items.__example
	for _, itemName in ipairs(items) do
		local newItem = exampleItem:Clone()
		newItem.Name = itemName
		newItem.text.Text = itemName
		
		newItem.button.MouseButton1Down:Connect(dropdownItemMouseDown(dropdownButton, newItem, func))
		
		newItem.Parent = dropdownButton.content.items
		newItem.Visible = true
		dropdownButton.content.items.CanvasSize += UDim2.new(0, 0, 0, 27)
	end
	
	dropdownButton.content.items.Position = UDim2.new(0.5, 0, -1, 25)

	dropdown.Parent = page.content
	dropdown.Visible = true
	page.content.CanvasSize += UDim2.new(0, 0, 0, 55)

	return self
end

-- Bar System
local links = bar.content.links.content
local hide = bar.hide

-- Initialize bar state
links.__example.Visible = false
bar.Position = UDim2.new(0.5, 0, 1, 80)
hide.Rotation = 180
hide.Position = UDim2.new(0.5, 0, 0, -50)

local barOpen, barCooldown = false, false

local function closeBar()
	barOpen, barCooldown = false, true

	if currentlySelected then
		local obj = currentlySelected
		local border = obj.border
		local name = obj.name

		border.Transparency = 0
		tweenService:Create(obj, TweenInfo.new(
			0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
			), {
				BackgroundTransparency = 0.95
			}):Play()

		tweenService:Create(name, TweenInfo.new(
			0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out
			), {
				TextColor3 = Color3.fromRGB(180, 71, 235)
			}):Play()

		closePage(currentlyOpenPage.Name)
		currentlySelected = nil
	end

	task.delay(0.6, function()
		clickCooldown = false
	end)

	tweenService:Create(bar, TweenInfo.new(
		0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In
		), {
			Position = UDim2.new(0.5, 0, 1, 80)
		}):Play()

	tweenService:Create(hide, TweenInfo.new(
		0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.In
		), {
			Rotation = 180,
			Position = UDim2.new(0.5, 0, 0, -50)
		}):Play()

	task.delay(1, function()
		barCooldown = false
	end)
end

local function openBar()
	barOpen, barCooldown = true, true

	tweenService:Create(bar, TweenInfo.new(
		1, Enum.EasingStyle.Back, Enum.EasingDirection.Out
		), {
			Position = UDim2.new(0.5, 0, 1, -12)
		}):Play()

	tweenService:Create(hide, TweenInfo.new(
		0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.In
		), {
			Rotation = 0,
			Position = UDim2.new(0.5, 0, 0, -35)
		}):Play()

	task.delay(1, function()
		barCooldown = false
	end)
end

local function toggleBar()
	if barOpen then
		closeBar()
	else
		openBar()
	end
end

local hideButtonCooldown = false
local function hideMouseDown()
	if hideButtonCooldown then return end
	hideButtonCooldown = true

	playSound("click")
	toggleBar()

	task.delay(1, function()
		hideButtonCooldown = false
	end)
end

local function hideMouseEnter()
	playSound("on hover")
end

local function hideMouseLeave()
	playSound("off hover")
end

-- Connect bar UI events
hide.button.MouseButton1Click:Connect(hideMouseDown)
hide.button.MouseEnter:Connect(hideMouseEnter)
hide.button.MouseLeave:Connect(hideMouseLeave)

function module:finishSetup()
	powerGUI.Enabled = true
	for _, page in pairs(pages:GetChildren()) do
		if page:IsA("Frame") and string.sub(page.Name, 1, 2) ~= "__" then
			pageFades[page.Name] = fade(page, 0)
		end
	end
	openBar()
end

function module:addLink(name, link, icon)
	validateArg(name, "string", "name")
	validateArg(link, "string", "link")
	validateArg(icon, "string", "icon")

	local newLink = links.__example:Clone()
	newLink.Name = name
	newLink.Image = icon

	newLink.Parent = links
	newLink.Visible = true
end

-- Initialize and lock module
lockedModule = lockModule(module)
return lockedModule
