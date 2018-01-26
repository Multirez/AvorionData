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
local upgradeSlotCount = nil
local systemPath = "data/scripts/systems/"
local dummyPath = "data/scripts/entity/dummy.lua"
-- ChatMessageType.Information on client fires attempt to index a nil value, create own enum
local MessageType = { Normal=0, Error=1, Warning=2, Information=3, Whisp=4}

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
	print("all templates init to {}")
	local entity = Entity()
	upgradeSlotCount = processPowerToUpgradeCount(getProcessPower(entity))
	if onServer() then	
		entity:registerCallback("onSystemsChanged", "onSystemsChanged")
		print("register callback onSystemsChanged")
		chatMessage(ChatMessageType.Whisp, "System controll was initialized.")
	else -- on client
		print("client request syncWithClient")
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
	print("secure(), isClient", onClient())
	-- store activeSystems data
	local data = {}
	local systems = {}
	local systemData = {}
	for k, system in pairs(activeSystems) do
		if k and system and system.seed and system.rarity then
			systemData = {}
			systemData["script"] = system.script
			systemData["rarity"] = system.rarity.value
			systemData["seed"] = system.seed.value
			systems[k] = systemData
		else
			print("Error! secure: activeSystems containe row without system data.",
				"scriptKey:", k)
		end		
	end
	data["activeSystems"] = systems	
	-- store templates data
	for t=1, totalTemplates do
		systems = {}
		for k, system in pairs(systemTemplates[t]) do
			if k and system and system.seed and system.rarity then
				systemData = {}
				systemData["script"] = system.script
				systemData["rarity"] = system.rarity.value
				systemData["seed"] = system.seed.value
				systems[k] = systemData
			else
				print("Error! secure: Template containe row without system data.",
					"templateIndex:", t, "scriptKey:", k)
			end
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
	print("restore(), isClient", onClient())	
	if type(values) ~= "table" then
		return
	end
	-- activeSystems data	
	activeSystems = {}
	for i, systemData in pairs(values["activeSystems"]) do
		activeSystems[i] =  SystemUpgradeTemplate(systemData["script"],
			Rarity(systemData["rarity"]), Seed(systemData["seed"]))
	end
	-- restore templates data
	for t=1, totalTemplates do
		systemTemplates[t] = {}
		for i, systemData in pairs(values[tostring(t)]) do
			systemTemplates[t][i] =  SystemUpgradeTemplate(systemData["script"],
				Rarity(systemData["rarity"]), Seed(systemData["seed"]))
		end
	end
	-- print("restored templates:", tableInfo(systemTemplates))
	-- settings
	usePlayerInventory = values["usePlayerInventory"] or true
end


function updateClient(timeStep)	
	local keyboard =  Keyboard() -- Keyboard is only available on the client side

    if keyboard:keyDown("left ctrl") or keyboard:keyDown("right ctrl") then
    end
	if keyboard:keyUp("left ctrl") or keyboard:keyUp("right ctrl") then
    end
    if keyboard:keyDown("left shift") or keyboard:keyDown("right shift") then
    end
	if keyboard:keyUp("left shift") or keyboard:keyUp("right shift") then
    end
    if keyboard:keyDown("left alt") or keyboard:keyDown("right alt") then
		print("left alt down")
    end
	if keyboard:keyUp("left alt") or keyboard:keyUp("right alt") then
    end
end

function onKeyboardEvent(key, pressed)
	if key == 9 then -- Tab key
		isTabPressed = pressed
	end
	
	if isTabPressed and key > 48 and key < 60 and pressed then
		print("Tab +", key - 48, "was pressed.")
	end
end

function onSystemsChanged(shipIndex)
	local entity = Entity()
	if shipIndex == entity.index then 
		print("onSystemsChanged")
		deferredCallback(1.0, "broadcastInvokeClientFunction", "checkSystemsByProcessing")		
	end	
end

---- UI ----
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

local mainWindow = nil
local isInputCooldown = false -- blocks user input
local systemIcons = {}
local buttonToLine = {}
local usePlayerInventoryCheckBox
local isNeedRefresh = false

function initUI()
	print("initUI")
    local size = vec2(960, 600)
    local res = getResolution()

    local menu = ScriptUI()
    mainWindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    menu:registerWindow(mainWindow, "System control"%_t)
	
    mainWindow.caption = "System control"%_t
    mainWindow.showCloseButton = 1
    mainWindow.moveable = 1

	local window = mainWindow
	local scale = 0.82*size.y
	local labelHeight = 0.06*scale
	local buttonWidth = 0.2*scale
	local iconSize = 0.1*scale
	local margin = 0.016*scale
	local padding = 0.25*labelHeight 
	local pos = vec2(4*margin, 2*margin)
	local label, button
	local hotButtonName	= "Tab"
	local maxSystemCount = tableCount(slotRequirements)
	local labelFontSize = math.floor(labelHeight*0.6)
	--local getTempList = function() r = {} for n = 1, 15 do table.insert(r, n) end return r end
	--chatMessage(tableInfo(getTempList()))
		
	label = window:createLabel(pos + vec2(0, padding), "Current"%t, labelFontSize)
	button = window:createButton(
		Rect(pos.x + buttonWidth + margin, pos.y, pos.x + 2*buttonWidth, pos.y + labelHeight),
		"Clear"%t, "onClearButton")
	usePlayerInventoryCheckBox = window:createCheckBox(
		Rect(pos.x + 2*buttonWidth + margin, pos.y + padding, pos.x + 4*buttonWidth, pos.y + labelHeight),
		"Use player inventory:"%t, "onUsePlayerInventory")
	usePlayerInventoryCheckBox.checked = usePlayerInventory
	pos.y = pos.y + labelHeight
		
	systemIcons[0] = createUISystemList(window, pos, iconSize, maxSystemCount)
	pos.y = pos.y + iconSize + 2*margin
	
	for i=1, totalTemplates do
		label = window:createLabel(pos + vec2(0, padding),
			hotButtonName.." + "..tostring(i), labelFontSize)
		button = window:createButton(
			Rect(pos.x + buttonWidth + margin, pos.y, pos.x + 2*buttonWidth, pos.y + labelHeight),
			"Update"%t, "onUpdateButton")
		buttonToLine[button.index] = i
		button = window:createButton(
			Rect(pos.x + 2*buttonWidth + margin, pos.y, pos.x + 3*buttonWidth, pos.y + labelHeight),
			"Use"%t, "onUseButton")
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
end

local isTabPressed = false
function createUISystemList(window, posVector, size, count, padding, borderWidth)
	padding = padding or 6
	borderWidth = borderWidth or 2
	local pos = vec2(posVector.x, posVector.y)
	local picture, frame
	local buttonSize = vec2(size - borderWidth, size - borderWidth)
	local border = vec2(borderWidth, borderWidth)
	local result = {}
	for i=1, count do
		local systemIcon = {}
		systemIcon["border"], systemIcon["frame"] = createBorder(window, 
			Rect(pos, pos + buttonSize + border), borderWidth - 1, ColorRGB(0, 0, 0))
		systemIcon["picture"] = window:createPicture(Rect(pos + border, pos + buttonSize), "")
		systemIcon["picture"].isIcon = true
		pos.x = pos.x + size + padding
		
		table.insert(result, i, systemIcon)
	end
	
	return result
end

function createBorder(uiContainer, posRect, borderWidth, borderColor)
	borderColor = borderColor or ColorRGB(0.1, 0.1, 0.1)
	
	local border = vec2(borderWidth, borderWidth)
	local borderFrame = uiContainer:createFrame(posRect)
	borderFrame.backgroundColor = borderColor
	local backFrame = uiContainer:createFrame(Rect(posRect.topLeft + border, posRect.bottomRight - border))
	backFrame.backgroundColor = ColorARGB(0.95, 0.1, 0.1, 0.1)
	
	return borderFrame, backFrame
end

-- Client Function: This function is only called on the client.
function updateUI() 	
	if isNeedRefresh then refreshUI() end
end

-- this function gets called whenever the ui window gets rendered, AFTER the window was rendered (client only)
function renderUI()	
	if mainWindow.visible then -- render UI calls only if window is visible
		-- draw tooltip
		for l=0, totalTemplates do
			for _, icon in pairs(systemIcons[l]) do
				if icon["tooltip"] and icon["border"].mouseOver then
					local renderer = TooltipRenderer(icon["tooltip"])
					renderer:drawMouseTooltip(Mouse().position)
				end
			end
		end
	end
end

---- UI callbacks ----
function onUsePlayerInventory()	
	if isInputCooldown then -- blocks user input
		usePlayerInventoryCheckBox.checked = usePlayerInventory
		return 
	end 
	isInputCooldown = true
	if usePlayerInventoryCheckBox.checked ~= usePlayerInventory then
		usePlayerInventory = usePlayerInventoryCheckBox.checked
		invokeServerFunction("restore", secure()) -- share with server
				
		local useText	
		if usePlayerInventoryCheckBox.checked then
			useText = "Will be used player inventory."%t
		else
			useText = "Will be used alliance inventory."%t
		end	
		chatMessage("SystemControl:", useText)
	end	
	isInputCooldown = false
end

function onUseButton(button)
	if isInputCooldown then return end -- blocks user input
	isInputCooldown = true
	local lineIndex = buttonToLine[button.index]	
	chatMessage(MessageType.Whisp, "Use button pressed, template index:", lineIndex)
	applyTemplate(systemTemplates[lineIndex])
end

function onUpdateButton(button)	
	if isInputCooldown then return end -- blocks user input
	isInputCooldown = true
	local lineIndex = buttonToLine[button.index]	
	chatMessage(MessageType.Whisp, "Update button pressed, template index: ", lineIndex)
	systemTemplates[lineIndex] = tableCopy(activeSystems) -- new table
	invokeServerFunction("restore", secure()) -- share with server
	isNeedRefresh = true
end

function onClearButton()
	if isInputCooldown then return end -- blocks user input
	isInputCooldown = true 
	toInventory(getFaction(), getSystems())
	activeSystems = {}
	invokeServerFunction("restore", secure()) -- share with server
	isNeedRefresh = true
end

---- UI update ----
function refreshUI()
	updateUISystemList(systemIcons[0], activeSystems, upgradeSlotCount)
	
	for i=1, totalTemplates do
		updateUISystemList(systemIcons[i], systemTemplates[i], upgradeSlotCount)
	end
	
	isInputCooldown = false
	isNeedRefresh = false
end

function updateUISystemList(iconList, systemList, availableTotal)
	local iconIndex = 1
	local iconPicture, iconBorder	
	for _, system in pairsByKeys(systemList) do		
		iconPicture = iconList[iconIndex].picture		
		iconPicture.picture = system.icon
		iconPicture.color = system.rarity.color
		iconPicture.visible = true
			
		iconBorder = iconList[iconIndex].border
		if iconIndex > availableTotal then
			iconBorder.backgroundColor = ColorRGB(0, 0, 0)
		else
			iconBorder.backgroundColor = system.rarity.color
		end		
		
		iconList[iconIndex].tooltip = system.tooltip	
		
		iconIndex = iconIndex + 1
	end
	
	for i=iconIndex, #iconList do 
		iconList[i].picture.visible = false
		if i > availableTotal then
			iconList[i].border.backgroundColor = ColorRGB(0, 0, 0)
		else
			iconList[i].border.backgroundColor = ColorRGB(0.8, 0.8, 0.8)
		end
		iconList[i].tooltip = nil
	end
end


---- Functions ----
-- share settings and templates with player
function syncWithClient(playerIndex) -- server side
	print("send to client secure data")
	invokeClientFunction(Player(playerIndex), "restore", secure())
end

-- recalculate available slots and remove extra updates
function checkSystemsByProcessing()
	local entity = Entity()
	upgradeSlotCount = processPowerToUpgradeCount(getProcessPower(entity))
	-- TODO remove last if not enough slots
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
	-- checks is template length < slot count, or use sub template	
	local installList = tableSub(templateList, 1 , upgradeSlotCount)	
	print("----templateList:", systemListInfo(installList))
	
	activeSystems, installList = checkSystemsByTemplate(installList)
	print("already in activeSystems:", systemListInfo(activeSystems))
	print("installList count:", tableCount(installList), systemListInfo(installList))
	if tableCount(installList) > 0 then
		installFromInventory(installList)
	else		
		invokeServerFunction("restore", secure()) -- share state with server
		isNeedRefresh = true
	end
end

function checkSystemsByTemplate(templateList) -- client side
	-- chatMessage("checkSystemsByTemplate")	
	local entity = Entity()
	local fillIndex, dummiesTotal = fillEmptyWithDummies(entity)	
	local installedSystems = {}
	local notInstalledList = tableCopy(templateList)
	local uninstalledList = {}
	local lastByPath = {}
	local es, seed, er, rarity
	local scripts = entity:getScripts()
	for i, s in pairs(scripts) do
		-- work only with scripts from systems folder
		if s:sub(0, #systemPath) == systemPath then
			if lastByPath[s] then --move up previous to invoke current
				moveSystemUp(lastByPath[s].system)				
				dummiesTotal = dummiesTotal + 1
				fillIndex = fillIndex + 1
				while scripts[fillIndex] do fillIndex = fillIndex + 1 end -- to empty
				installedSystems[fillIndex] = lastByPath[s].system
				installSystems[lastByPath[s].index] = nil
			end
			lastByPath[s] = nil			
			es, rarity = entity:invokeFunction(s, "getRarity")			
			er, seed = entity:invokeFunction(s, "getSeed")
			if es == 0 and er == 0 then
				-- check is use or uninstall
				local systemUpgrade = SystemUpgradeTemplate(s, rarity, seed)
				local isRemain, tIndex = tableContaine(notInstalledList, systemUpgrade, isSystemsEqual)
				if isRemain then
					notInstalledList[tIndex] = nil
					installedSystems[i] = systemUpgrade
					lastByPath[s] = { system = systemUpgrade, index = i }
				else
					unInstall(entity.index, s)
					uninstalledList[i] = systemUpgrade
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
	if tableCount(uninstalledList) > 0 then -- return uninstalled systems to faction inventory
		toInventory(getFaction(), uninstalledList) 
	end
	
	return installedSystems, notInstalledList
end

function fillEmptyWithDummies(entity)
	local scripts = entity:getScripts() -- TODO must to be the script list from server
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

-- Removes systems from inventory and install its.
function installFromInventory(requestList, factionIndex, playerIndex)
	if onClient() then
		print("installFromInventory RequestList:", systemListInfo(requestList))
		invokeServerFunction("installFromInventory", requestList, getFaction(), Player().index)
		return
	end	
	-- chatMessage("installFromInventory RequestList:", systemListInfo(requestList))
	local result = {}
	-- prepare
	local inventory = Faction(factionIndex):getInventory()
	local entries = inventory:getItemsByType(InventoryItemType.SystemUpgrade)
	-- table.sort(entries, inventoryComparer) -- TODO: it's broke item index after sorting
	-- seek 
	local fakeSystem = SystemUpgradeTemplate("basesystem", Rarity(0), Seed(111111))
	for r, requestSystem in pairs(requestList)do
		for i, inventoryEntry in pairs(entries) do
			if inventoryEntry and isSystemsEqual(requestSystem, inventoryEntry.item) then
				-- chatMessage("select ", i, " with rarity: ", inventoryEntry.item.rarity, 
					-- "seed:", inventoryEntry.item.rarity)
				result[r] = inventory:take(i) -- take from inventory
				entries[i] = { amount = 1, item = fakeSystem }
				break
			end
		end
	end
	
	invokeClientFunction(Player(playerIndex), "installSystems",  Entity():getScripts(), result)
end

function inventoryComparer(entryA, entryB)
	if entryA then
		if entryB then 
			return systemComparer(entryA.item, entryB.item)
		else
			return true
		end
	end

	return false
end

function systemComparer(systemA, systemB)
	
	if systemA.favorite ~= systemB.favorite then 
		return systemA.favorite
	end
	
	return systemA.rarity.value > systemB.rarity.value
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
				-- local key = type(i) == "string" and i or tostring(i)
				result[i] = SystemUpgradeTemplate(s, rarity, seed)
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
		Entity(entityIndex):removeScript(script) -- uninsttall on client too, to not wait for server sync
		invokeServerFunction("unInstall", entityIndex, script)
		return
	end
	
	Entity(entityIndex):removeScript(script)
end

-- for share server entity scripts with client
function sendEntityScriptList(targetPlayerIndex, targetClientFunctionName, ...) -- server side
	if onClient() then
		print("Error! Try to sendEntityScriptList from client.",
			"You must invoke this function only on server side.",
			"Callback name:", targetClientFunctionName)
		return
	end
	-- chatMessage("sendEntityScriptList: send scripList to", targetClientFunctionName)
	invokeClientFunction(Player(targetPlayerIndex), targetClientFunctionName, 
		Entity():getScripts(), ...)
end

function installSystems(scriptList, systemList) -- client side
	if not systemList then -- function called with one argument
		systemList = scriptList
		scriptList = nil		
		if not systemList then -- error
			print("Error! installSystems: systemList can't be nil.")
			
			invokeServerFunction("restore", secure()) -- share state with server
			isNeedRefresh = true
			return
		end
	end
	if tableCount(systemList) > 0 then	
		if not scriptList then	
			-- chatMessage("installSystems: Try to get server script list.")
			invokeServerFunction("sendEntityScriptList", Player().index, "installSystems", systemList)
			return
		end	
		print("installSystems list:", systemListInfo(systemList))
		
		local entity = Entity()
		local scriptIndex = 1
		for k, st in pairsByKeys(systemList) do
			-- find empty index
			while scriptList[scriptIndex] do scriptIndex = scriptIndex + 1 end
			if k and st then -- install
				activeSystems[scriptIndex] = st -- add to active list
				install(entity.index, st.script, st.seed.int32, st.rarity)
				scriptIndex = scriptIndex + 1
			end
		end
	end
	
	print("installSystems done, activeSystems:", systemListInfo(activeSystems))
	invokeServerFunction("restore", secure()) -- share state with server
	isNeedRefresh = true
end

function install(entityIndex, script, seed_int32, rarity)
	if onClient() then
		-- Entity(entityIndex):addScript(script, seed_int32, rarity)
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
	for i, requiredPP in ipairs(slotRequirements) do
		if requiredPP > processingPower then			
			print("process power:", processingPower, "slots:", (i - 1))
			return (i - 1)
		end
	end
	
	return tableCount(slotRequirements)
end

function isSystemsEqual(systemA, systemB)
	return (systemA and systemB and
		systemA.script == systemB.script and
		systemA.seed == systemB.seed and
		systemA.rarity == systemB.rarity)
end

function tableContaine(tb, value, equalityFunc)
	if not equalityFunc then
		equalityFunc = function(a,b) return a==b end
	end
	for i, v in pairs(tb) do
		if equalityFunc(v, value) then
			return true, i
		end
	end
	return false
end

function tableSub(tb, firstIndex, lastIndex)
	local index = 0
	local result = {}
	for k, v in pairs(tb) do 
		index = index + 1
		if firstIndex <= index and index <= lastIndex then
			result[k] = v
		end
	end
	
	return result
end

function tableCopy(tb)
	local result = {}
	for k, v in pairs(tb) do 
		result[k] = v
	end
	return result
end

function tableCount(tb)
	local count = 0
	for _ in pairs(tb) do 
		count = count + 1
	end
	
	return count
end

-- for testing purposes
function test()
	
	--[[ local componentType = ComponentType.Scripts
	local entity = Entity()
	print(entity.name, "has", componentType, ":", entity:hasComponent(componentType))
	if entity:hasComponent(componentType) then		
	end ]]	
					
	--[[ local random = Random(Server().seed)
	local seed = random:createSeed()
	local rarity = Rarity(RarityType.Exotic) ]]
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

function systemListInfo(systemList)
	result = ""
	for k, s in pairs(systemList) do
		if k and s and s.seed then 
			result = result .. "\n" .. tostring(k) .. " : " .. s.script ..
				" rarity "..tostring(s.rarity).." seed "..tostring(s.seed.value)
		else
			result = result.."Error! systemListInfo: systemList containe row without system data."..
				" scriptKey: "..tostring(k)
			print("Error! systemListInfo: systemList containe row without system data.",
				"scriptKey:", k)
		end
	end	
	return result
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
function chatMessage(messageType, ...)
	local message = ""
	if not tableContaine(MessageType, messageType) then
		message = tostring(messageType)
		messageType = MessageType.Normal
	end
	message = table.concat({message, ...}, " ")
	local length = #message
	
	local sendMessage = function(msg)
		if onServer() then
			local pilot = { Entity():getPilotIndices() }
			for i=1, #pilot do
				if pilot[i] then
					Player(pilot[i]):sendChatMessage("Server "..Entity().name, messageType, msg)
				end
			end
		else
			displayChatMessage(msg, Entity().name, messageType)
		end
	end
	
	if length < MaxMessageLength then
		sendMessage(message)
		return
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

-- Returns table<int:index, string:name> with function parameters
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
