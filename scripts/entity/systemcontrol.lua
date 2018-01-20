package.path = package.path .. ";data/scripts/lib/?.lua"

--require("utility")
--require("stringutility")
--require("faction")
require("debug")
require("class")

local activeSystems = {}

-- This function is always the very first function that is called in a script, and only once during
-- the lifetime of the script. The function is always called on the server first, before client
-- instances are available, so invoking client functions will never work. This function is both
-- called when a script gets newly attached to an object, and when the object is loaded from the
-- database during a load from disk operation. During a load from disk operation, no parameters
-- are passed to the function. 
function initialize()	
	if onServer() then
		installFromInventory(3)
		chatMessage(tableInfo(Entity():getScripts()))
	end
	
	
	--[[ --Add ship system
	--TODO check ship processing power
	local random = Random(Server().seed)
	local seed = random:createSeed()
	local rarity = Rarity(RarityType.Exotic)
	
	AddSystem(nil, seed, rarity)
	
	chatMessage("scripts: "..tableInfo(Entity():getScripts())) ]]

	--[[ --Ship Plan
	local plan = Entity():getMovePlan()
	local planStats = plan:getStats()
	Entity():setMovePlan(plan) ]]
	
	-- chatMessage("plan stats: "..classInfo(planStats))
	
	-- local faction = Faction(Entity().factionIndex)
	-- local player = Player(faction.index)
	-- chatMessage(tableInfo(faction))	
	
	-- if onServer() then
		-- chatMessage("Inventory from " .. faction.name .. ":")
		-- local inventory = faction:getInventory()
		-- chatMessage(classInfo(inventory:getItems()))	
	-- end
	
	
	-- print("isShip: " .. tostring(Entity().isShip))
	
	-- print("entity processing power:")
	-- printTable(Entity():getPlan())
end

-- Called when the script is about to be removed from the object, before the removal. 
function onRemove()
    -- if inventoryItem then
		-- Player():getInventory():add(inventoryItem, inventoryItem.recent)
		-- inventoryItem = nil
	-- end
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
	for i, system in pairs(activeSystems) do
		local systemData = {}
		systemData["script"] = system.script
		systemData["rarity"] = system.rarity.value
		systemData["seed"] = system.seed.value
		data[i] = systemData
	end
	
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
	
	for i, systemData in pairs(values) do
		activeSystems[i] =  SystemUpgradeTemplate(systemData["script"],
			Rarity(systemData["rarity"]), Seed(systemData["seed"]))
	end
end

-- Removes system upgrade from inventory and install it.
function installFromInventory(inventoryIndex)
	-- Check and take system from inventory
	local inventory = Player():getInventory();
	local inventoryItem = inventory:find(inventoryIndex)
	if not inventoryItem or inventoryItem.itemType == InventoryItemType.SystemUpgrade then
		chatMessage("Error: Can't to find SystemUpgrade in the inventory at index: ", inventoryIndex)
		return
	end
		
	local systemUpgrade = inventory:take(inventoryIndex)
	chatMessage(inventoryItemInfo(systemUpgradeTemplate))
	
	-- TODO: seek the right way to install ship system 
	local installResult = Entity():addScript(systemUpgrade.script, 
		systemUpgrade.seed, systemUpgrade.rarity)
	if installResult ~= 0 then
		chatMessage("Error: Can't to install system at current Entity()")
		inventory:add(systemUpgrade, systemUpgrade.recent)
		return
	else
		chatMessage(systemUpgrade.name, "was installed successfully.")
		table.insert(activeSystems, systemUpgrade)
	end	
end

--[[ function AddSystem(systemType, seed, rarity)
	local entity = Entity()
	
	if not entity().isShip then
		chatMessage("You must be in ship to use system control.")
	end
	
	--TODO get system path fron systemType
	local scriptPath = "energybooster"
	
	entity:addScript(scriptPath, seed, rarity)
end ]]

-- Utilities
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
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
      end
      return iter
    end

local MaxMessageLength = 500
function chatMessage(message, ...)
	for i,v in ipairs(arg) do
		message = message .. " " .. tostring(v)
	end	
	local length = #message
	local player = Player(Entity().factionIndex)
	
	if length < MaxMessageLength then
		player:sendChatMessage("", 0, message)
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
			player:sendChatMessage("", 0, subMessage)
			subMessage = ""
		end
	end
	if #subMessage > 0 then 
		player:sendChatMessage("", 0, subMessage)
	end	
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
