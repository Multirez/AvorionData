package.path = package.path .. ";data/scripts/lib/?.lua"

--require("utility")
require("stringutility")
--require("faction")
require("debug")
--require("class")

local activeSystems = {}
local systemTemplates = {}
local usePlayerInventory = true
local totalTemplates = 5
local slotRequirements = {0, 51, 128, 320, 800, 2000, 5000, 12500, 19764, 
	31250, 43065, 59348, 78125, 107554, 148371}
local systemPath = "data/scripts/systems/"
local dummyPath = "data/scripts/entity/dummy.lua"

---- API functions ----
-- This function is always the very first function that is called in a script, and only once during
-- the lifetime of the script. The function is always called on the server first, before client
-- instances are available, so invoking client functions will never work. This function is both
-- called when a script gets newly attached to an object, and when the object is loaded from the
-- database during a load from disk operation. During a load from disk operation, no parameters
-- are passed to the function. 
function initialize()
	for i=1, totalTemplates do
		systemTemplates[i] = {}
	end
	entity = Entity()	
	if onServer() then			
		entity:registerCallback("onSystemsChanged", "onSystemsChanged")
		-- entity:registerCallback("onPlanModifiedByBuilding", "onPlanModifiedByBuilding")
		entity:registerCallback("onBlockPlanChanged", "onBlockPlanChanged")
		
		-- installFromInventory(6)
		-- chatMessage(tableInfo(Entity():getScripts()))
		
		-- local random = Random(Server().seed)
		-- local seed = random:createSeed()
		-- local rarity = Rarity(RarityType.Exotic)
	else
		invokeServerFunction("syncWithClient", Player().index)
	end
end

-- Called when the script is about to be removed from the object, before the removal. 
function onRemove()	
	toInventory(getFaction(), getSystems()) -- need to clear current systems, that was be uncorect registered
end

-- Called to secure values from the script. This function is called when the object is unloaded
-- from the server. It's called at other times as well to refresh data, or when objects are copied
-- or during regular saves. The table returned by this function will be passed to the restore()
-- function when the object is loaded and read from disk. All values that are in the table must
-- be numbers, strings or other tables. Values that aren't of the above types will be converted
-- to nil and an error message will be printed.
function secure()
	-- store activeSystems data
	local data = {}
	local systems = {}
	local systemData = {}
	for i, system in pairs(activeSystems) do
		systemData = {}
		systemData["script"] = system.script
		systemData["rarity"] = system.rarity.value
		systemData["seed"] = system.seed.value
		systems[i] = systemData
	end
	data["activeSystems"] = systems	
	-- store templates data
	for t=1, totalTemplates do
		systems = {}
		for i, system in pairs(systemTemplates[t]) do
			systemData = {}
			systemData["script"] = system.script
			systemData["rarity"] = system.rarity.value
			systemData["seed"] = system.seed.value
			systems[i] = systemData
		end
		data[tostring(t)] = systems
	end
	-- settings
	data["usePlayerInventory"] = usePlayerInventory
	
	return data
end

-- Called to restore previously secured values for the script. Receives the values that were gathered
-- from the last called to the secure() function. This function is called when the object is read
-- from disk and restored, after initialize() was called.
function restore(values)
	activeSystems = {}
	
	if type(values) ~= "table" then
		return
	end
	-- activeSystems data
	for i, systemData in pairs(values["activeSystems"]) do
		activeSystems[i] =  SystemUpgradeTemplate(systemData["script"],
			Rarity(systemData["rarity"]), Seed(systemData["seed"]))
	end
	-- restore templates data
	for t=1, totalTemplates do
		for i, systemData in pairs(values[tostring(t)]) do
			systemTemplates[t][i] =  SystemUpgradeTemplate(systemData["script"],
				Rarity(systemData["rarity"]), Seed(systemData["seed"]))
		end
	end
	-- print("restored templates:", tableInfo(systemTemplates))
	-- settings
	usePlayerInventory = values["usePlayerInventory"] or true
end


-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
function interactionPossible(playerIndex, option)

    local player = Player()
    if Entity().index == player.craftIndex then
        return true
    end

    return false
end

function getIcon()
    return "data/textures/icons/circuitry.png"
end

local systemIcons = {}
local buttonToLine = {}
local usePlayerInventoryCheckBox

function initUI()
    local size = vec2(960, 600)
    local res = getResolution()

    local menu = ScriptUI()
    local mainWindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));
    menu:registerWindow(mainWindow, "System control"%_t);

    mainWindow.caption = "System control"%_t
    mainWindow.showCloseButton = 1
    mainWindow.moveable = 1

	local window = mainWindow
	local scale = 0.9*size.y
	local labelHeight = 0.06*scale
	local buttonWidth = 0.2*scale
	local iconSize = 0.1*scale
	local margin = 0.01*scale
	local pos = vec2(4*margin, 2*margin)
	local label, button
	local hotButtonName	= "Tab"
	local maxSystemCount = #slotRequirements
	--local getTempList = function() r = {} for n = 1, 15 do table.insert(r, n) end return r end
	--chatMessage(tableInfo(getTempList()))
		
	label = window:createLabel(pos,	"Current"%t, math.floor(labelHeight*0.5))
	button = window:createButton(
		Rect(pos.x + buttonWidth + margin, pos.y, pos.x + 2*buttonWidth, pos.y + labelHeight),
		"Clear"%t, "onClearButton")
	usePlayerInventoryCheckBox = window:createCheckBox(
		Rect(pos.x + 2*buttonWidth + margin, pos.y, pos.x + 4*buttonWidth, pos.y + labelHeight),
		"Use player inventory:"%t, "onUsePlayerInventory")
	usePlayerInventoryCheckBox.checked = usePlayerInventory
	pos.y = pos.y + labelHeight
		
	systemIcons[0] = createUISystemList(window, pos, iconSize, maxSystemCount)
	pos.y = pos.y + iconSize + 2*margin
	
	for i=1, totalTemplates do
		label = window:createLabel(pos + vec2(0, margin),
			hotButtonName.." + "..tostring(i), math.floor(labelHeight*0.5))
		button = window:createButton(
			Rect(pos.x + buttonWidth + margin, pos.y, pos.x + 2*buttonWidth, pos.y + labelHeight),
			"Use"%t, "onUseButton")
		buttonToLine[button.index] = i
		button = window:createButton(
			Rect(pos.x + 2*buttonWidth + margin, pos.y, pos.x + 3*buttonWidth, pos.y + labelHeight),
			"Update"%t, "onUpdateButton")		
		pos.y = pos.y + labelHeight
		buttonToLine[button.index] = i
		
		systemIcons[i] = createUISystemList(window, pos, iconSize, maxSystemCount)
		pos.y = pos.y + iconSize + 2*margin
	end	
end

function onShowWindow()
	-- reinstall current systems to get activeList
	-- TODO: get active list without reinstall
	activeSystems = {}
	local systemList = getSystems() --get current list
	installSystems(systemList) --reinstall current
	
    refreshUI()
end

local isTabPressed = false

function onKeyboardEvent(key, pressed) 
	if key == 9 then -- Tab key
		isTabPressed = pressed
	end
	
	if isTabPressed and key > 48 and key < 60 and pressed then
		print("Tab +", key - 48, "was pressed.")
	end
end

function onSystemsChanged(shipIndex) 
	print("onSystemsChanged, shipIndex:", shipIndex, "my index:", Entity().index)
end

--[[function onPlanModifiedByBuilding(shipIndex) 
	print("onPlanModifiedByBuilding", shipIndex)
end]]

function onBlockPlanChanged(objectIndex, allBlocksChanged) 
	print("onBlockPlanChanged, objectIndex:", objectIndex, "my index:", Entity().index)
end


---- UI create ----
function createUISystemList(window, posVector, size, count, padding, borderWidth)
	padding = padding or 6
	borderWidth = borderWidth or 2
	local pos = vec2(posVector.x, posVector.y)
	local picture, frame
	local buttonSize = vec2(size - borderWidth, size - borderWidth)
	local border = vec2(borderWidth, borderWidth)
	local result = {}
	for i=1, count do
		result[i] = {}
		result[i]["border"], result[i]["frame"] = 
			createBorder(window, Rect(pos, pos + buttonSize + border), borderWidth - 1)
		result[i]["picture"] = window:createPicture(Rect(pos + border, pos + buttonSize), "")
		result[i]["picture"].isIcon = true
		--picture.picture = "data/textures/icons/circuitry.png"
		pos.x = pos.x + size + padding
	end
	
	return result
end

function createBorder(uiContainer, posRect, borderWidth, borderColor)
	borderColor = borderColor or ColorRGB(1, 1, 1)
	
	local border = vec2(borderWidth, borderWidth)
	local borderFrame = uiContainer:createFrame(posRect)
	borderFrame.backgroundColor = ColorRGB(1, 1, 1)
	local backFrame = uiContainer:createFrame(Rect(posRect.topLeft + border, posRect.bottomRight - border))
	backFrame.backgroundColor = ColorRGB(0.1, 0.1, 0.1)
	
	return borderFrame, backFrame
end

---- UI callbacks ----
function onUsePlayerInventory()	
	if usePlayerInventoryCheckBox.checked ~= usePlayerInventory then
		usePlayerInventory = usePlayerInventoryCheckBox.checked
		invokeServerFunction("restore", secure()) -- share with server
	end
	
	local useText	
	if usePlayerInventoryCheckBox.checked then
		useText = "Will be used player inventory."%t
	else
		useText = "Will be used alliance inventory."%t
	end	
	chatMessage("SystemControl:", useText)
end

function onUseButton(button)
	local lineIndex = buttonToLine[button.index]	
	chatMessage("Use button pressed, line index:  ", lineIndex, "Not implemented yet.")
	applyTemplate(systemTemplates[lineIndex])
	
	invokeServerFunction("restore", secure()) -- share with server
	refreshUI()
end

function onUpdateButton(button)
	local lineIndex = buttonToLine[button.index]	
	chatMessage("Update button pressed, line index: ", lineIndex)
	systemTemplates[lineIndex] = { table.unpack(activeSystems) } -- new table
	invokeServerFunction("restore", secure()) -- share with server
	refreshUI()
end

function onClearButton()
	toInventory(getFaction(), getSystems())
	activeSystems = {}
	invokeServerFunction("restore", secure()) -- share with server
	refreshUI()
end

---- UI update ----
function refreshUI()
	local upgradeSlotCount = processPowerToUpgradeCount(getProcessPower(Entity()))
	updateUISystemList(systemIcons[0], activeSystems, upgradeSlotCount)
	
	for i=1, totalTemplates do
		updateUISystemList(systemIcons[i], systemTemplates[i], upgradeSlotCount)
	end
end

function updateUISystemList(iconList, systemList, availableTotal)
	local iconIndex = 1
	local iconPicture, iconBorder	
	for i, system in pairs(systemList) do		
		iconPicture = iconList[iconIndex].picture
		iconPicture.picture = system.icon
		iconPicture.color = system.rarity.color
		-- convert tooltip to string
		local stringTooltip = ""
		local l = 11
		local concatFunc = function() 
			stringTooltip = stringTooltip .. system.tooltip:getLine(l).ltext .. "\n"
		end
		-- chatMessage(classInfo(system.tooltip))
		-- while pcall(concatFunc) do 
			-- l = l + 1 
		-- end
		
		-- for l=1, system.tooltip:size() do
			-- stringTooltip = stringTooltip .. system.tooltip:getLine(l).ltext .. "\n"
		-- end
		iconPicture.tooltip = stringTooltip
		
		iconBorder = iconList[iconIndex].border
		if iconIndex > availableTotal then
			iconBorder.backgroundColor = ColorRGB(0, 0, 0)
		else
			iconBorder.backgroundColor = system.rarity.color
		end	
			
		iconIndex = iconIndex + 1
	end
	
	for i=iconIndex, #iconList do 
		iconList[i].picture.picture = ""
		if i > availableTotal then
			iconList[i].border.backgroundColor = ColorRGB(0, 0, 0)
		else
			iconList[i].border.backgroundColor = ColorRGB(0.8, 0.8, 0.8)
		end
	end
end


---- Functions ----
-- share settings and templates with player
function syncWithClient(playerIndex) -- server side
	invokeClientFunction(Player(playerIndex), "restore", secure())
end
-- Removes system upgrade from inventory and install it.
function installFromInventory(inventoryIndex) -- client side
	-- Check and take system from inventory
	local inventory = Player():getInventory();
	local inventoryItem = inventory:find(inventoryIndex)
	if not inventoryItem or inventoryItem.itemType ~= InventoryItemType.SystemUpgrade then
		chatMessage("Error: Can't to find SystemUpgrade in the inventory at index: ", inventoryIndex)
		if inventoryItem then
			chatMessage(inventoryItem.name, " has InventoryItemType :", inventoryItem.itemType, 
				" but must be: ", InventoryItemType.SystemUpgrade)
		end
		return
	end
		
	local systemUpgrade = inventory:take(inventoryIndex)
	chatMessage(inventoryItemInfo(systemUpgrade))
	
	-- TODO: seek the right way to install ship system 
	local installResult = Entity():addScript(systemUpgrade.script, 
		systemUpgrade.seed, systemUpgrade.rarity)
	if installResult ~= 0 then
		chatMessage("Error: Can't to install system at current Entity().",
			"Error code: ", installResult)
		inventory:add(systemUpgrade, systemUpgrade.recent)
		return
	else
		chatMessage(systemUpgrade.name, "was installed successfully.")
		table.insert(activeSystems, systemUpgrade)
	end	
end

-- returns player or allience faction index based on usePlayerInventory value.
function getFaction()	
	if not usePlayerInventory then 
		return Entity().factionIndex
	end
	if onClient() then
		return Player().index
	end
	-- server call for player inventory
	if callingPlayer then 
		return callingPlayer.index
	end		
	return Entity().factionIndex
end

-- uninstall systems that are not in template and try to install missing from inventory
function applyTemplate(templateList) -- client side
	-- TODO: checks is template length < slot count, or use sub template
	local installList
	activeSystems, installList = checkSystemsByTemplate(templateList)
	installList = takeFromInventory(installList)
	installSystems(installList)
end

function checkSystemsByTemplate(templateList) -- client side
	print("checkSystemsByTemplate", "Not implemented yet.")	
	local entity = Entity()
	local fillIndex, dummiesTotal = fillEmptyWithDummies(entity)	
	local installedSystems = {}
	local notInstalledList = {unpack(templateList)}
	local uninstalledList = {}
	local lastByPath = {}
	local es, seed, er, rarity
	local scripts = entity:getScripts()
	for i, s in pairs(scripts) do
		-- work only with scripts from systems folder
		if s:sub(0, #systemPath) == systemPath then
			if lastByPath[s] then --move up previous to invoke current
				moveSystemUp(lastByPath[s])
				dummiesTotal = dummiesTotal + 1
			end
			lastByPath[s] = nil			
			es, rarity = entity:invokeFunction(s, "getRarity")			
			er, seed = entity:invokeFunction(s, "getSeed")
			if es == 0 and er == 0 then
				-- check is use or uninstall
				local systemUpgrade = SystemUpgradeTemplate(s, rarity, seed)
				local isRemain, index = table.containe(notInstalledList, systemUpgrade, isSystemsEqual)
				if isRemain then
					table.remove(notInstalledList, index)
					table.insert(installedSystems, i, systemUpgrade)
					lastByPath[s] = systemUpgrade
				else
					unInstall(entity.index, s)
					table.insert(uninstalledList, i, systemUpgrade)
				end
			else
				chatMessage("Error! Can't get systemUpgrade values for ", s, ". I will to delete it.")
				unInstall(entity.index, s) -- delete upgrade with errors
			end	
		end
	end
	-- remove dummies
	for i=1, dummiesTotal do
		unInstall(entity.index, dummyPath)
	end
	-- return uninstalled systems to faction inventory
	toInventory(getFaction(), uninstalledList) 
	
	return installedSystems, notInstalledList
end

function fillEmptyWithDummies(entity)
	local scripts = entity:getScripts()
	local fillToIndex = 0
	local countByPath = {}
	for i, s in pairs(scripts) do -- prepare countByPath
		if s:sub(0, #systemPath) == systemPath then
			countByPath[s] = (countByPath[s] or 0) + 1
			if countByPath[s] > 1 then
				fillToIndex = i
			end
		end
	end
	
	local totalDummies = 0
	for i=1, fillToIndex do
		if scripts[i] == nil then -- fill with dummies empty space
			install(entity.index, dummyPath, 0, 0)
			totalDummies = totalDummies + 1
		end
	end
	
	return fillToIndex, totalDummies
end

-- moves system up and replace it by dummy to invokeFunction on other
function moveSystemUp(system) -- client side
	entity = Entity()
	-- add copy
	install(entity.index, system.script, system.seed.int32, system.rarity)
	-- remove
	unInstall(entity.index, system.script)
	-- and replace by dummy
	install(entity.index, dummyPath, 0, 0)
end

function takeFromInventory(requestList) -- client side
	print("takeFromInventory", "Not implemented yet. RequestList:", tableInfo(requestList))
	
	return {}
end

-- UNINSTALL all upgrades, returns table<int, SystemUpgradeTemplate>
-- also remove dummies scripts
function getSystems() -- client side
	local entity = Entity()
	local scripts = entity:getScripts()
	local seed, rarity
	local result = {}
	for i, s in pairs(scripts) do
		if s:sub(0, #systemPath) == systemPath then
			e, rarity = entity:invokeFunction(s, "getRarity")
			e, seed = entity:invokeFunction(s, "getSeed")
			if seed ~= nil and rarity ~= nil then
				print(i, ":", s, "rarity", rarity.value, "seed", seed.value)
				table.insert(result, SystemUpgradeTemplate(s, rarity, seed))
				unInstall(entity.index, s)
			else
				print("Error! Can't get systemUpgrade values.")
			end			
		end
		if s == dummyPath then
			unInstall(entity.index, s)
		end
	end
	
	return result
end

-- UNINSTALL an upgrade with the valid name
function unInstall(entityIndex, script) 
	if onClient() then
		Entity(entityIndex):removeScript(script)
		invokeServerFunction("unInstall", entityIndex, script)
		return
	end
	
	Entity(entityIndex):removeScript(script)
end

function installSystems(systemList) -- client side
	local entity = Entity()
	for i, st in pairs(systemList) do
		table.insert(activeSystems, st) -- add to active list
		install(entity.index, st.script, st.seed.int32, st.rarity)
	end
end

function install(entityIndex, script, seed_int32, rarity)
	if onClient() then
		Entity(entityIndex):addScript(script, seed_int32, rarity)
		invokeServerFunction("install", entityIndex, script, seed_int32, rarity)		
		return
	end
	
	Entity(entityIndex):addScript(script, seed_int32, rarity)
end

function toInventory(factionIndex, systemList)
	if onClient() then
		invokeServerFunction("toInventory", factionIndex, systemList)
		return
	end

	inventory = Faction(factionIndex):getInventory()
	for i, v in pairs(systemList) do
		v.favorite = true
		inventory:add(v, false)
	end
end

function getProcessPower(entity)
	local blockPlan = entity:getMovePlan()
	local blockStatistic = blockPlan:getStats()
	entity:setMovePlan(blockPlan)
	
	return blockStatistic.processingPower
end

function processPowerToUpgradeCount(processingPower)
	print("process power:", processingPower)
	for i, requiredPP in ipairs(slotRequirements) do
		if requiredPP > processingPower then
			return (i - 1)
		end
	end
	
	return #slotRequirements
end

function isSystemsEqual(systemA, systemB)
	return systemA.script == systemB.script and
		systemA.seed == systemB.seed and
		systemA.rarity == systemB.rarity	
end

function table.containe(tb, value, equalityFunc)
	for i, v in pairs(tb) do
		if equalityFunc(v, value) then
			return true, i
		end
	end
	return false
end

-- for testing purposes
function test()
	-- if onClient() then
		-- invokeServerFunction("test")
		-- return
	-- end
	
	--[[ local componentType = ComponentType.Scripts
	local entity = Entity()
	print(entity.name, "has", componentType, ":", entity:hasComponent(componentType))
	if entity:hasComponent(componentType) then		
	end ]]
end


---- Utilities ----
-- Returns string class values and meta
function classInfo(class)
	local result = "----class info----" .. tableInfo(class)
	if getmetatable(class) then
		result = result .. "\n----meta----" .. tableInfo(getmetatable(class))
	end
	return result .. "\n----end----"
end

function inventoryItemInfo(inventoryItem)
	local info = "name: " .. inventoryItem.name
	.. "\n| rarity: " .. inventoryItem.rarity.name	
	.. "\n| favorite: " .. tostring(inventoryItem.favorite)
	.. "\n| trash: " .. tostring(inventoryItem.trash)
	.. "\n| recent: " .. tostring(inventoryItem.recent)
	.. "\n| icon: " .. inventoryItem.icon
	--.. "\n| iconColor: " .. tostring(inventoryItem.iconColor)
	.. "\n| price: " .. tostring(inventoryItem.price)
	.. "\n| itemType: " .. tostring(inventoryItem.itemType)
	.. "\n| stackable: " .. tostring(inventoryItem.stackable)
	if inventoryItem.itemType == InventoryItemType.SystemUpgrade then
		info = info 
		.. "\n| script: " .. inventoryItem.script
		.. "\n| seed: " .. tostring(inventoryItem.seed)
	end
	return info
end

-- Returns string formatted values from table
function tableInfo(tbl, prefix)
    if prefix and string.len(prefix) > 100 then return "" end	
	if type(tbl) ~= "table" then return "" end
		
    prefix = prefix or "\n| "
	local result = "" --prefix .. "---------------------"
    for k, v in pairsByKeys(tbl) do
		if type(v) == "function" then
			result = result .. prefix .. tostring(k) .. " function "
			if debug.getinfo(v)["nparams"] > 0 then
				result = result .. tableInfo(getArgs(v), prefix .. " | ") --debug.getinfo(v)["nparams"] .. " params"
			end
        else
			result = result .. 
				prefix .. tostring(k) .. " -> " .. tostring(v)
		end	
		
        if type(v) == "table" and v ~= tbl then
            result = result .. tableInfo(v, prefix .. " | ")
        end	
		
		if getmetatable(v) and (type(v)=="table" or type(v)=="userdata" or type(v)=="function" ) then
			if getmetatable(v).__avoriontype then
				result = result .. " " .. getmetatable(v).__avoriontype --tableInfo(getmetatable(v), prefix .. " | ")
			end
		end
    end
	--result = result .. prefix .. "---------------------"
	
	return result
end

-- sorted by key enumeration
function pairsByKeys(t, f)
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a, f)
	local i = 0      -- iterator variable
	local iter = function ()   -- iterator function
		i = i + 1
		if a[i] == nil then 
			return nil
		else 
			return a[i], t[a[i]]
		end
	end
	return iter
end

local MaxMessageLength = 500

function chatMessage(message, ...)
	local arg = {...}
	for i,v in ipairs(arg) do
		message = message .. " " .. tostring(v)
	end
	local length = #message
	local sendMessage = function(msg)
		if onServer() then
			Player(Entity().factionIndex):sendChatMessage(Entity().name, 0, msg)
		else
			Player():sendChatMessage(msg)
		end
	end
	
	if length < MaxMessageLength then
		sendMessage(message)
		return
	end
	
	if onClient() then
		local mail = Mail()
		mail.sender = "Big chat message"%_t
		mail.header = "This message is to big to show it via chat."%_t
		mail.text = message

		sendMail(Player().index, mail)
	end
	
	local from = 0
	local to = 0
	local subMessage = ""
	while to + 1 < length do
		to = string.find(message, "\n", from + 1)
		to = to or length + 1
		subMessage = subMessage .. message:sub(from, to - 1)
		from = to
		if #subMessage > (MaxMessageLength * 0.5) then
			sendMessage(subMessage)
			subMessage = ""
		end
	end
	if #subMessage > 0 then 
		sendMessage(subMessage)
	end	
end

function sendMail(playerIndex, mail)
	if onClient() then
		invokeServerFunction("sendMail", playerIndex, mail)
		return
	end
	
	Player(playerIndex):addMail(mail)
end

-- Returns table with function (index = name) parameters
function getArgs(fun)
	local args = {}
	local hook = debug.gethook()

	local argHook = function( ... )
		local info = debug.getinfo(3)
		if 'pcall' ~= info.name then return end

		for i = 1, math.huge do
			local name, value = debug.getlocal(2, i)
			if '(*temporary)' == name then
				debug.sethook(hook)
				error('')
				return
			end
			table.insert(args,name)
		end
	end

	debug.sethook(argHook, "c")
	pcall(fun)

	return args
end
