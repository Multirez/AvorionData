-------------------------------------------------------------------------------
-- Allows player to create the templates (sets) of upgrades for ship systems 
-- and quickly switch its from one to another.
--
-- @author Multirez (multirez@gmail.com)
-- also there are many pieces of code I have peeked in the Internet
-------------------------------------------------------------------------------

package.path = package.path .. ";data/scripts/lib/?.lua"

require("stringutility")
require("debug")

local activeSystems = {}
local dirtySystemCount = 100500 -- number of the unaccounted systems, need to update activeSystems
local systemTemplates = {}
local isCheckSystemsSheduled = false
local usePlayerInventory = true
local totalTemplates = 5
local slotRequirements = {0, 51, 128, 320, 800, 2000, 5000, 12500, 19764, 
	31250, 43065, 59348, 78125, 107554, 148371}
local upgradeSlotCount = nil
local systemPath = "data/scripts/systems/"
local dummyPath = "mods/SystemControl/scripts/entity/dummy.lua"
local statBonuses = { 
	RadarReach = StatsBonuses.RadarReach,
	HiddenSectorRadarReach = StatsBonuses.HiddenSectorRadarReach,
	ScannerReach = StatsBonuses.ScannerReach,
	HyperspaceReach = StatsBonuses.HyperspaceReach,
	HyperspaceCooldown = StatsBonuses.HyperspaceCooldown,
	HyperspaceRechargeEnergy = StatsBonuses.HyperspaceRechargeEnergy,
	ShieldDurability = StatsBonuses.ShieldDurability,
	ShieldRecharge = StatsBonuses.ShieldRecharge,
	Velocity = StatsBonuses.Velocity,
	Acceleration = StatsBonuses.Acceleration,
	GeneratedEnergy = StatsBonuses.GeneratedEnergy,
	EnergyCapacity = StatsBonuses.EnergyCapacity,
	BatteryRecharge = StatsBonuses.BatteryRecharge,
	ArbitraryTurrets = StatsBonuses.ArbitraryTurrets,
	UnarmedTurrets = StatsBonuses.UnarmedTurrets,
	ArmedTurrets = StatsBonuses.ArmedTurrets,
	CargoHold = StatsBonuses.CargoHold,
	Engineers = StatsBonuses.Engineers,
	Mechanics = StatsBonuses.Mechanics,
	Gunners = StatsBonuses.Gunners,
	Miners = StatsBonuses.Miners,
	Security = StatsBonuses.Security,
	Attackers = StatsBonuses.Attackers,
	Sergeants = StatsBonuses.Sergeants,
	Lieutenants = StatsBonuses.Lieutenants,
	Commanders = StatsBonuses.Commanders,
	Generals = StatsBonuses.Generals,
	Captains = StatsBonuses.Captains
}

local MaxMessageLength = 500
-- ChatMessageType.Information on client fires attempt to index a nil value, create own enum
local MessageType = { Normal=0, Error=1, Warning=2, Information=3, Whisp=4}

local isInputCooldown = false -- blocks user input
local isNeedRefresh = true
local isCleverUpdateIsRunning = false
local mainWindow = nil
local systemIcons = {}
local buttonToLine = {}
local usePlayerInventoryCheckBox = nil
local infoButton = nil

---- Log ----
local LogType = { None=0, Error=1, Warning=2, Info=4, Debug=8, All=255 }
local logPrefix = { [1]="(error)", [2]="(warning)", [4]="(info)", [8]="(debug)"}
local logLevel = LogType.Warning -- sets current log level
local logSource = "SystemControl:"
local log = function(level, ...)
	if logPrefix[level] and logLevel >= level then
		print(logPrefix[level].." "..logSource, ...)
	elseif logLevel >= LogType.Info then -- info by default
		print(logSource, level, ...)
	end
end

---- API functions ----
function initialize()
	log(LogType.Debug, "Init templates to {}")
	for i=1, totalTemplates do
		systemTemplates[i] = {}
	end
	local entity = Entity()
	upgradeSlotCount = processPowerToUpgradeCount(getProcessPower(entity))
	if onServer() then	
		entity:registerCallback("onSystemsChanged", "onSystemsChanged")
		log(LogType.Debug, "register callback onSystemsChanged")
		entity:registerCallback("onDestroyed", "onDestroyed")
		log(LogType.Debug, "register callback onDestroyed")
		chatMessage(ChatMessageType.Whisp, "SystemControl was initialized.")
	else -- on client
		log(LogType.Debug, "client request syncWithClient")
		invokeServerFunction("syncWithClient", Player().index)			
	end
end

function onRemove()
	log(LogType.Debug, "onRemove, invetory faction:", getFaction())
	if onServer() then
		toInventory(getFaction(), getSystems()) -- need to clear current systems, that was be uncorect registered
	end
end

function secure()
	log(LogType.Debug, "secure(), isClient", onClient())
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
			log(LogType.Error, "secure: activeSystems containe row without system data.",
				"scriptKey:", k)
		end		
	end
	data["activeSystems"] = systems		
	data["dirtySystemCount"] = dirtySystemCount
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
				log(LogType.Error, "secure: Template containe row without system data.",
					"templateIndex:", t, "scriptKey:", k)
			end
		end
		data[tostring(t)] = systems
	end
	-- settings
	data["usePlayerInventory"] = usePlayerInventory
	
	return data
end

function restore(values)
	log(LogType.Debug, "restore(), isClient", onClient())	
	if type(values) ~= "table" then
		return
	end
	-- activeSystems data	
	activeSystems = {}
	for i, systemData in pairs(values["activeSystems"]) do
		activeSystems[i] =  SystemUpgradeTemplate(systemData["script"],
			Rarity(systemData["rarity"]), Seed(systemData["seed"]))
	end
	dirtySystemCount = values["dirtySystemCount"] or dirtySystemCount
	-- restore templates data
	for t=1, totalTemplates do
		systemTemplates[t] = {}
		for i, systemData in pairs(values[tostring(t)]) do
			systemTemplates[t][i] =  SystemUpgradeTemplate(systemData["script"],
				Rarity(systemData["rarity"]), Seed(systemData["seed"]))
		end
	end
	-- log(LogType.Debug, "restored templates:", tableInfo(systemTemplates))
	-- settings
	usePlayerInventory = values["usePlayerInventory"] or true
end

function onIndexChanged(old, id) -- server side
	dirtySystemCount = dirtySystemCount + 1 -- system indices was changed too
end

function updateClient(timeStep)	
	if interactionPossible(Player().index) then	
		local keyboard =  Keyboard()
		if keyboard:keyPressed("left alt") then
			for i=0, totalTemplates do
				if keyboard:keyDown(tostring(i)) then
					onKeyboardInput(i)
				end
			end
		end
	end
end

function onKeyboardInput(inputIndex)
	if inputIndex == 0 then -- clear
		chatMessage(MessageType.Whisp, "SystemControl: clear command activated.")
		onClearButton()
		return
	end	
	-- select template
	if isInputCooldown then return end -- blocks user input
	isInputCooldown = true
	chatMessage(MessageType.Whisp, "SystemControl: apply template #"..tostring(inputIndex))
	applyTemplate(systemTemplates[inputIndex])
end

function onDestroyed(index, lastDamageInflictor)
	if onServer() and index == Entity().index then		
		log(LogType.Debug, "onDestroyed, invetory faction:", getFaction())
		toInventory(getFaction(), getSystems()) -- need to clear current systems, that was be uncorect registered
	end
end

function onSystemsChanged(shipIndex)
	if isCleverUpdateIsRunning then return end -- exit if clever update
	
	local entity = Entity()
	if shipIndex == entity.index then 
		log(LogType.Debug, "onSystemsChanged")
		if not isCheckSystemsSheduled then
			isCheckSystemsSheduled = true
			deferredCallback(0.5, "delayedSystemCheck")
		end
	end	
end

function delayedSystemCheck()
	isCheckSystemsSheduled = false
	player = Player(Entity():getPilotIndices())
	if player then
		invokeClientFunction(player, "checkSystemsByProcessing", Entity():getScripts())
	else 
		dirtySystemCount = dirtySystemCount + 1 -- sets state to "dirty"
	end
end

---- UI ----
-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
function interactionPossible(playerIndex, option)
	local entity = Entity()
    return entity.index == Player(playerIndex).craftIndex and entity.isShip -- only on ship
end

function getIcon()
    return "data/textures/icons/circuitry.png"
end

function initUI()
	log(LogType.Debug, "initUI")
    local size = vec2(960, 600)
    local res = getResolution()

    local menu = ScriptUI()
    mainWindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    menu:registerWindow(mainWindow, "System controlR"%_t)
	
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
	local hotButtonName	= "Alt"
	local maxSystemCount = tableCount(slotRequirements)
	local labelFontSize = math.floor(labelHeight*0.6)
	--local getTempList = function() r = {} for n = 1, 15 do table.insert(r, n) end return r end
	--chatMessage(tableInfo(getTempList()))
		
	label = window:createLabel(pos + vec2(0, padding), "Current"%t, labelFontSize)
	infoButton = window:createButton(
		Rect(pos.x + 1*buttonWidth + margin, pos.y, pos.x + 2*buttonWidth, pos.y + labelHeight),
		"Update"%t, "onCurrentUpdateButton")
	button = window:createButton(
		Rect(pos.x + 2*buttonWidth + margin, pos.y, pos.x + 3*buttonWidth, pos.y + labelHeight),
		"Clear"%t, "onClearButton")
	usePlayerInventoryCheckBox = window:createCheckBox(
		Rect(pos.x + 3*buttonWidth + margin, pos.y + padding, pos.x + 5*buttonWidth, pos.y + labelHeight),
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
	if dirtySystemCount ~= 0 then -- will update activeSystems
		log(LogType.Debug, "dirtySystemCount:", dirtySystemCount)
		-- clever update system list
		if not isCleverUpdateIsRunning then
			cleverUpdateSystems(nil, "onShowWindow")
		else
			sendChatMessage(MessageType.Error, "SystemControl: Wait for the previous update task is done.")
		end
		-- activeSystems = {}
		-- dirtySystemCount = 0
		-- local systemList = getSystems() -- get current list, this will uninstall all
		-- installSystems(systemList) -- reinstall current
	else
		invokeServerFunction("sendEntityScriptList", Player().index, "checkActiveList")
		updateInfoText()
	end
end

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


---- UI update ----
function refreshUI()
	updateUISystemList(systemIcons[0], activeSystems, upgradeSlotCount)
	
	for i=1, totalTemplates do
		updateUISystemList(systemIcons[i], systemTemplates[i], upgradeSlotCount)
	end
	
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

function updateInfoText()
	infoButton.tooltip = "Current bonuses:"%t .. entityBonusesInfo(Entity())
end

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
	isInputCooldown = false
	isNeedRefresh = true
end

function onClearButton()
	if isInputCooldown then return end -- blocks user input
	isInputCooldown = true 
	toInventory(getFaction(), getSystems())
	activeSystems = {}
	dirtySystemCount = 0
	invokeServerFunction("restore", secure()) -- share with server
	isInputCooldown = false
	isNeedRefresh = true
end

function onCurrentUpdateButton()
	if isInputCooldown then return end -- blocks user input
	log(LogType.Debug, "onCurrentUpdateButton")
	-- clever update system list
	if not isCleverUpdateIsRunning then
		cleverUpdateSystems(nil, "onShowWindow")
	else
		sendChatMessage(MessageType.Error, "SystemControl: Wait for the previous update task is done.")
	end
end


---- Functions ----
function checkActiveList(scripts)
	log(LogType.Debug, "Check activeSystems start.")
	for k, v in pairs(activeSystems) do
		if scripts[k] ~= v.script then
			log(LogType.Error, "Check active systems failed. At ", k, "must be", v.script, "but in fact there is", scripts[k])
			dirtySystemCount = dirtySystemCount + 1 -- active list is "dirty"
		end
	end
	log(LogType.Debug, "Check activeSystems complete.")
end

-- share settings and templates with player
function syncWithClient(playerIndex) -- server side
	log(LogType.Debug, "send to client secure data")
	invokeClientFunction(Player(playerIndex), "restore", secure())
end

-- recalculate available slots and remove extra updates
function checkSystemsByProcessing(serverScripts) -- client side
	if not serverScripts then
		invokeServerFunction("sendEntityScriptList", Player().index, "checkSystemsByProcessing")
		return
	end
	isInputCooldown = true
	-- calc the number of slots
	local entity = Entity()
	upgradeSlotCount = processPowerToUpgradeCount(getProcessPower(entity))
	-- count upgrades
	local entityUpgradesCount = 0
	for i, s in pairs(serverScripts) do
		if s:sub(0, #systemPath) == systemPath then 
			entityUpgradesCount = entityUpgradesCount + 1
		end		
	end
	
	local totalExtraUpgrades = entityUpgradesCount - upgradeSlotCount
	dirtySystemCount = math.max(entityUpgradesCount - tableCount(activeSystems), dirtySystemCount + 1)
	if totalExtraUpgrades > 0 then -- remove last if not enough slots	
		local totalToRemove = math.min(tableCount(activeSystems), totalExtraUpgrades)
		if totalToRemove > 0 then
			local removeIter = pairsByKeys(activeSystems, function(a, b) return a > b end)
			local inventoryList = {}
			for i=1, totalToRemove do
				sIndex, system = removeIter()
				inventoryList[sIndex] = system
				unInstallByIndex(entity.index, sIndex)							
				activeSystems[sIndex] = nil	
			end
			toInventory(getFaction(), inventoryList)
			invokeServerFunction("restore", secure()) -- share data with server	
			chatMessage(MessageType.Whisp, 
				"SytemControl: Extra systems was removed, count:", totalToRemove)
		end
	end	
	
	isInputCooldown = false
	isNeedRefresh = true
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
	local playerIndex = Entity():getPilotIndices()	
	return playerIndex or Entity().factionIndex
end

-- update the list of active systems with the help of smart reinstalling
-- also can to call some function after update
function cleverUpdateSystems(playerIndex, onUpdateFuncName, ...) -- server side
	if onClient() then
		isCleverUpdateIsRunning = true
		isInputCooldown = true
		activeSystems = {}
		dirtySystemCount = 0
		log(LogType.Debug, "Clever update: create map")
		invokeServerFunction("cleverUpdateSystems", playerIndex or Player().index, 
			onUpdateFuncName, ...)
		return
	end
	
	isCleverUpdateIsRunning = true -- on server
	log(LogType.Debug, "Clever update: create map")
	local entity = Entity()
	local scripts = entity:getScripts()
	local fillIndex, dummiesTotal = fillEmptyWithDummies(scripts, false)
	local es, seed, er, rarity, systemUpgrade, isSystem
	local lastByPath = {} -- { path = { system = SystemUpgrade, index = currentIndex } }
	local result = {} -- { currentIndex = { system = SystemUpgrade, index = startIndex } }		
	-- try to get list -- sequence must to be saved
	for i, s in pairs(scripts) do
		-- work only with scripts from systems folder
		if s:sub(0, #systemPath) == systemPath then
			if lastByPath[s] then --move up previous to invokeFunction on current
				moveSystemUp(entity, lastByPath[s].system)				
				dummiesTotal = dummiesTotal + 1
				fillIndex = fillIndex + 1
				while scripts[fillIndex] do fillIndex = fillIndex + 1 end -- to empty
				result[fillIndex] = result[lastByPath[s].index]
				result[lastByPath[s].index] = nil
			end
			lastByPath[s] = nil
			
			er, rarity = entity:invokeFunction(s, "getRarity")			
			es, seed = entity:invokeFunction(s, "getSeed")
			if er ~= 0 or es ~= 0 then
				log(LogType.Error, "Can't get systemUpgrade values for ", s, 
					"I will create a replacement with a common rarity.")
			end
			systemUpgrade = SystemUpgradeTemplate(s, rarity or Rarity(0), seed or Seed(111111))
			
			result[i] = { system = systemUpgrade, index = i }
			lastByPath[s] = { system = systemUpgrade, index = i }
		end
	end
	
	for s, system in pairs(lastByPath) do -- compleately remove systems from vanima
		moveSystemUp(entity, lastByPath[s].system)				
		dummiesTotal = dummiesTotal + 1
		fillIndex = fillIndex + 1
		while scripts[fillIndex] do fillIndex = fillIndex + 1 end -- to empty
		result[fillIndex] = result[lastByPath[s].index]
		result[lastByPath[s].index] = nil
	end
	
	-- remove dummies
	for i=1, dummiesTotal do
		entity:removeScript(dummyPath)
	end 		
	
	invokeClientFunction(Player(playerIndex), 
		"arrageByMap", entity:getScripts(), result, onUpdateFuncName, ...)
	isCleverUpdateIsRunning = false -- on server
end

function arrageByMap(scripts, activeMap, onUpdateFuncName, ...) -- client side
	log(LogType.Debug, "Check map identity...")
	local isCorrupted = false
	for index, mapValue in pairs(activeMap) do
		if scripts[index] ~= mapValue.system.script then
			log(LogType.Error, "activeMap is corrupted at", index,
				"must be:", mapValue.system.script, "but in fact:", scripts[index])
			isCorrupted = true
		end
	end
	if isCorrupted then
		activeSystems = getSystems()
		dirtySystemCount = 0
		mapData = {}
		isDone = true
	end
	log(LogType.Debug, "Arrangement by activeMap")
	local unInstallList = {}
	local installList = {}
	local scriptIndex = 0
	local scriptPath = scripts[scriptIndex]
	local isDone = true -- will be setted to false if work is not accomplished
	local mapComparer = function(a, b) return a.index < b.index end -- sort map by value.index
	local sortedMapIter = pairsSorted(activeMap, mapComparer)
	local currentIndex, mapData = sortedMapIter()
	while currentIndex and mapData do
		repeat
			scriptIndex = scriptIndex + 1
			scriptPath = scripts[scriptIndex]
		until not(scriptPath) or scriptPath:sub(0, #systemPath) == systemPath
		if scriptPath then -- installed system -- check the map
			if scriptIndex == currentIndex then
				if scriptIndex == mapData.index then
					log(LogType.Debug, scriptIndex, " = ", currentIndex, "(", mapData.index, ")")
					activeSystems[currentIndex] = mapData.system
					-- all is ok, go to next mapData
				else -- shift map
					local shift = currentIndex - mapData.index
					log(LogType.Debug, "shift from ", mapData.index, "by", shift)
					repeat
						mapData.index = mapData.index + shift
						currentIndex, mapData = sortedMapIter()
					until not mapData
					isDone = false
					break
				end
			else 
				if activeMap[scriptIndex] then -- install like an empty index		
					local scriptData = activeMap[scriptIndex]
					local emptyScriptIndex = scriptIndex -- to find emptyScriptIndex
					while scripts[emptyScriptIndex] do emptyScriptIndex = emptyScriptIndex + 1 end			
					
					installList[emptyScriptIndex] = scriptData.system
					activeMap[emptyScriptIndex] = scriptData
					unInstallList[scriptIndex] = scriptData.system
					activeMap[scriptIndex] = nil
					log(LogType.Debug, scriptIndex, "(", scriptData.index, ") ->", 
						emptyScriptIndex, "(", scriptData.index, ")", scriptData.system.script)
				end				
				log(LogType.Debug, "need make install work to continue, stop at ", currentIndex, "(", mapData.index, ")",
					"script", scriptIndex, "->", scriptPath)
				isDone = false
				break
			end
		else -- empty script index
			if mapData[currentIndex] then
				log(LogType.Error, "Map is corrupted -> stops map work, uninstall all.")
				isInputCooldown = false
				onClearButton()
				return
			end
			installList[scriptIndex] = mapData.system
			activeMap[scriptIndex] = mapData
			unInstallList[currentIndex] = mapData.system
			activeMap[currentIndex] = nil
			log(LogType.Debug, currentIndex, "(", mapData.index, ") ->", scriptIndex, "(", mapData.index, ")")
		end
		currentIndex, mapData = sortedMapIter() -- goto next map data
	end
	-- log(LogType.Debug, "Clever update: install work, to install:", tableCount(installList))
	local entityIndex = Entity().index
	for installIndex, system in pairsByKeys(installList) do
		-- log(LogType.Debug, "Clever update: install", installIndex, "<-", system.script)
		activeSystems[installIndex] = system
		install(entityIndex, system.script, system.seed.int32, system.rarity)
	end
	-- log(LogType.Debug, "Clever update: unInstall work, to uninstall:", tableCount(unInstallList))
	for uninstallIndex, system in pairs(unInstallList) do
		-- log(LogType.Debug, "Clever update: uninstall", uninstallIndex, "X->", system.script)
		unInstallByIndex(entityIndex, uninstallIndex)
	end
	isNeedRefresh = true
	
	if isDone then
		log(LogType.Debug, "Clever update is done")
		invokeServerFunction("restore", secure()) -- share state with server
		isInputCooldown = false
		isCleverUpdateIsRunning = false
		if onUpdateFuncName then
			log(LogType.Debug, "Try to run function: "..onUpdateFuncName.."(...)")
			_G[onUpdateFuncName](...) -- assert(, "error, while try to run function: "..onUpdateFuncName))
		end
	else -- do map work
		invokeServerFunction("sendEntityScriptList", Player().index, "arrageByMap",
			activeMap, onUpdateFunc, ...)
	end
end

-- uninstall systems that are not in template and try to install missing from inventory
function applyTemplate(templateList) -- client side
	-- checks is template length < slot count, or use sub template	
	local installList = tableSub(templateList, 1 , upgradeSlotCount)	
	log(LogType.Debug, "----templateList:", systemListInfo(installList))
	if dirtySystemCount > 0 then
		log(LogType.Debug, "dirtySystemCount:", dirtySystemCount,"-> need to update")
		cleverUpdateSystems(nil, "checkSystemsByTemplate", nil, installList)
	else
		invokeServerFunction("sendEntityScriptList", Player().index, "checkSystemsByTemplate", installList)
	end
end

function checkSystemsByTemplate(scripts, templateList) -- client side
	if not scripts then
		invokeServerFunction("sendEntityScriptList", Player().index, "checkSystemsByTemplate", templateList)
		return
	end
	-- chatMessage("checkSystemsByTemplate")	
	local entity = Entity()
	local installedSystems = {}
	local installList = tableCopy(templateList)	
	local uninstalledList = {}
	for i, system in pairsByKeys(activeSystems) do
		local isRemain, tIndex = tableContaine(installList, system, isSystemsEqual)
		if isRemain then
			installList[tIndex] = nil
			installedSystems[i] = system
		else
			unInstallByIndex(entity.index, i)
			uninstalledList[i] = system
		end
	end
	
	activeSystems = installedSystems
	dirtySystemCount = 0
	log(LogType.Debug, "already in activeSystems:", systemListInfo(activeSystems), "\ninstallList count:", tableCount(installList))
	
	if tableCount(uninstalledList) > 0 then -- return uninstalled systems to faction inventory
		toInventory(getFaction(), uninstalledList) 
	end
	
	if tableCount(installList) > 0 then
		installFromInventory(installList)
	else		
		invokeServerFunction("restore", secure()) -- share state with server
		updateInfoText()
		isInputCooldown = false
		isNeedRefresh = true
	end
end

function fillEmptyWithDummies(scripts, isSmartFill) -- server side
	local fillToIndex = 0
	if isSmartFill then
		local countByPath = {}
		for i, s in pairs(scripts) do -- prepare countByPath
			if s:sub(0, #systemPath) == systemPath then
				countByPath[s] = (countByPath[s] or 0) + 1
				if countByPath[s] > 1 then
					fillToIndex = i
				end
			end
		end
	else -- fill to last system script
		for i, s in pairs(scripts) do -- prepare countByPath
			if s:sub(0, #systemPath) == systemPath then
				fillToIndex = i
			end
		end
	end
	
	local entity = Entity()	
	local totalDummies = 0
	for i=1, fillToIndex do
		if scripts[i] == nil then -- fill with dummies empty space
			entity:addScript(dummyPath)
			totalDummies = totalDummies + 1
		end
	end
	
	return fillToIndex, totalDummies
end

-- moves system up and replace it by dummy to invokeFunction on other
function moveSystemUp(entity, system) -- server side
	-- add copy
	entity:addScript(system.script, system.seed.int32, system.rarity)
	-- remove
	entity:removeScript(system.script)
	-- and replace by dummy
	entity:addScript(dummyPath)
end

-- Removes systems from inventory and install its.
function installFromInventory(requestList, factionIndex, playerIndex)
	if onClient() then
		log(LogType.Debug, "installFromInventory RequestList:", systemListInfo(requestList))
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

function isSystemsEqual(systemA, systemB)
	return (systemA ~= nil and systemB ~= nil and
		systemA.script == systemB.script and
		systemA.seed.int32 == systemB.seed.int32 and
		systemA.rarity == systemB.rarity)
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
function getSystems()
	local entity = Entity()
	local scripts = entity:getScripts()
	local seed, rarity
	local result = {}
	for i, s in pairs(scripts) do
		if s:sub(0, #systemPath) == systemPath then
			e, rarity = entity:invokeFunction(s, "getRarity")
			e, seed = entity:invokeFunction(s, "getSeed")
			if seed ~= nil and rarity ~= nil then
				log(LogType.Debug, i, ":", s, "rarity", rarity.value, "seed", seed.value)
				-- local key = type(i) == "string" and i or tostring(i)
				result[i] = SystemUpgradeTemplate(s, rarity, seed)
				unInstall(entity.index, s)
			else
				log(LogType.Error, "Can't get systemUpgrade values.")
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
		Entity(entityIndex):removeScript(script) -- uninsttall on client too
		invokeServerFunction("unInstall", entityIndex, script)
		return
	end
	
	Entity(entityIndex):removeScript(script)
end

-- UNINSTALL an upgrade by script index
function unInstallByIndex(entityIndex, scriptIndex) 
	if onClient() then
		log(LogType.Debug, "unInstallByIndex, scriptIndex:", scriptIndex)
		Entity():removeScript(tonumber(scriptIndex))
		invokeServerFunction("unInstallByIndex", entityIndex, scriptIndex)
		return
	end
	log(LogType.Debug, "unInstallByIndex, scriptIndex:", scriptIndex)
	Entity():removeScript(tonumber(scriptIndex))
end

-- for share server entity scripts with client
function sendEntityScriptList(targetPlayerIndex, targetClientFunctionName, ...) -- server side
	if onClient() then
		log(LogType.Error, "Try to sendEntityScriptList from client.",
			"You must invoke this function only on server side.",
			"Callback name:", targetClientFunctionName)
		return
	end
	log(LogType.Debug, "sendEntityScriptList: send scripList to", targetClientFunctionName)
	invokeClientFunction(Player(targetPlayerIndex), targetClientFunctionName, 
		Entity():getScripts(), ...)
end

function printEntityScripts(entityIndex) -- server side
	log(LogType.Debug, "scripts of entity, index:", entityIndex, tableInfo(Entity(entityIndex):getScripts()))
end

function installSystems(scriptList, systemList) -- client side
	if not systemList then -- function called with one argument
		systemList = scriptList
		scriptList = nil		
		if not systemList then -- error
			log(LogType.Error, "installSystems: systemList can't be nil.")
			
			invokeServerFunction("restore", secure()) -- share state with server
			isInputCooldown = false
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
		-- log(LogType.Debug, "installSystems list:", systemListInfo(systemList))
		
		local entity = Entity()
		local scriptIndex = 1
		for k, st in pairsByKeys(systemList) do
			-- find empty index
			while scriptList[scriptIndex] do scriptIndex = scriptIndex + 1 end
			if k and st then -- install
				log(LogType.Debug, "install at ", scriptIndex, "<-", systemInfo(st))
				activeSystems[scriptIndex] = st -- add to active list
				install(entity.index, st.script, st.seed.int32, st.rarity)
				scriptIndex = scriptIndex + 1
			end
		end
	end
	
	invokeServerFunction("restore", secure()) -- share state with server
	updateInfoText()
	isInputCooldown = false
	isNeedRefresh = true
	invokeServerFunction("sendEntityScriptList", Player().index, "checkActiveList") -- cheks result
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
	log(LogType.Debug, "toInventory, faction:", Faction(factionIndex), systemListInfo(systemList))
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
			log(LogType.Debug, "process power:", processingPower, "slots:", (i - 1))
			return (i - 1)
		end
	end
	
	return tableCount(slotRequirements)
end

-- for testing purposes
function test()
	
	--[[ local componentType = ComponentType.Scripts
	local entity = Entity()
	log(LogType.Debug, entity.name, "has", componentType, ":", entity:hasComponent(componentType))
	if entity:hasComponent(componentType) then		
	end ]]	
					
	--[[ local random = Random(Server().seed)
	local seed = random:createSeed()
	local rarity = Rarity(RarityType.Exotic) ]]
end


---- Table ----
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
	for k, v in pairsByKeys(tb) do 
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

function pairsSorted(tb, valueComparer)
	local array = {}
	for k, v in pairs(tb) do table.insert(array, {key=k, value=v}) end
	local arrayComparer = function(a, b) return valueComparer(a.value, b.value) end
	table.sort(array, arrayComparer)
	local i = 0      -- iterator variable
	local iter = function ()   -- iterator function
		i = i + 1
		if array[i] == nil then 
			return nil
		else 
			return array[i].key, array[i].value
		end
	end
	return iter
end


---- Info ---
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

function systemInfo(systemUpgrade)
	return systemUpgrade.script ..
		" rarity " .. tostring(systemUpgrade.rarity) ..
		" seed " .. tostring(systemUpgrade.seed.value)
end

function systemListInfo(systemList)
	result = ""
	for k, s in pairsByKeys(systemList) do
		if k and s and s.seed then 
			result = result .. "\n" .. tostring(k) .. " : " .. systemInfo(s)
		else
			result = result.."Error! systemListInfo: systemList containe row without system data."..
				" scriptKey: "..tostring(k)
			log(LogType.Error, "systemListInfo: systemList containe row without system data.",
				"scriptKey:", k)
		end
	end	
	return result
end

-- Returns string with current entity bonuses
function entityBonusesInfo(entity)
	local result = ""
	local bonus, absolute, multiplier = nil, nil, nil
	local minValue, maxValue = 0.01, 1000
	local minDelta = minValue * 0.001 --  0.1% from minValue
	local roundedString = function(v, step)
	    step = step or 1
	    assert(step > 0, "Invalid round step, step must be > 0.")
	    return tostring(math.floor((v + step/2) / step ) * step)
	end
	for k, v in pairs(statBonuses) do
		bonus = entity:getBoostedValue(v, minValue) - minValue
		if bonus and bonus > minDelta then
			multiplier = (entity:getBoostedValue(v, maxValue) - (bonus + maxValue)) / maxValue
			absolute = bonus - minValue * multiplier
			if absolute > 0 then
				absolute = " +"..roundedString(absolute, 0.1)
			else
				absolute = " "..roundedString(absolute, 0.1)
			end
			if multiplier > 0 then
				multiplier = " +"..roundedString(multiplier * 100, 0.1).."%"
			else
				multiplier = " "..roundedString(multiplier * 100, 0.1).."%"
			end			
			result = result .."\n".. k .. absolute .. multiplier
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

function chatMessage(messageType, ...)
	local message = ""
	if not tableContaine(MessageType, messageType) then
		message = tostring(messageType)
		messageType = MessageType.Normal
	end
	message = table.concat({message, ...}, " ")
	local length = #message
	
	local sendMessage = function(msg)
		log(LogType.Info, "chatMessage("..messageType..")", msg)
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
	log(LogType.Info, "sendMail:", mail.sender, "->", mail.receiver.name, mail.header, 
		mail.text:sub(1, math.min(200, #(mail.text))))
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
