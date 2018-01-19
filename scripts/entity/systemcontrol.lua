package.path = package.path .. ";data/scripts/lib/?.lua"

--require("utility")
--require("stringutility")
--require("faction")
require("debug")
require("class")

function initialize()	
	player = Player(Entity().factionIndex)
	--chatMessage(player.name.." is a Player: "..tostring(getmetatable(player) == Player)..classInfo(getmetatable(Player)))
	TestClass = class(function (a, name)
					a.name = name
				end)
	function TestClass:speak()
		return "My name is " .. self.name
	end
	
	classInstance = TestClass("InstanceName")
	chatMessage(classInstance:speak())
	chatMessage(classInfo(classInstance))
	--[[ --Add ship system
	--TODO check ship processing power
	--TODO find and get system from inventory
	local random = Random(Server().seed)
	local seed = random:createSeed()
	local rarity = Rarity(RarityType.Exotic)
	
	AddSystem(nil, seed, rarity)
	
	local scripts = Entity():getScripts()
	chatMessage("scripts: "..tableInfo(scripts)) ]]

	--[[ --Ship Plan
	local plan = Entity():getMovePlan()
	local planStats = plan:getStats()
	Entity():setMovePlan(plan)
	
	chatMessage("plan stats: "..classInfo(planStats)) ]]
	
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

function AddSystem(systemType, seed, rarity)
	local entity = Entity()
	
	if not entity().isShip then
		chatMessage("You must be in ship to use system control.")
	end
	
	--TODO get system path fron systemType
	local scriptPath = "data/scripts/systems/tradingoverview.lua"
	
	entity:addScript(scriptPath, seed, rarity)
end

-- Utilities
function classInfo(class)
	local result = "----class info----" .. tableInfo(class)
	if getmetatable(class) then
		result = result .. "\n----meta----" .. tableInfo(getmetatable(class))
	end
	return result .. "\n----end----"
end

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
function chatMessage(message)
	local player = Player(Entity().factionIndex)
	local length = #message
	
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
