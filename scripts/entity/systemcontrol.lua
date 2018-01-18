package.path = package.path .. ";data/scripts/lib/?.lua"

--require("utility")
--require("stringutility")
--require("faction")
require("debug")

function initialize()	
	local faction = Faction(Entity().factionIndex)
	local player = Player(faction.index)
	-- chatMessage(tableInfo(faction))
	
	if onServer() then
		chatMessage("Inventory from " .. faction.name .. ":")
		local inventory = faction:getInventory()
		chatMessage(classInfo(inventory:getItems()))
		
		--local tempClass = {"tableInfo" = tableInfo, "classInfo" = classInfo}
		local s = "hello"
		print(classInfo(s))
	end
	
	-- print("scripts:")
	-- printTable(Entity():getScripts())
	
	-- print("isShip: " .. tostring(Entity().isShip))
	
	-- print("entity processing power:")
	-- printTable(Entity():getPlan())
end



-- Utilities
function classInfo(class)
	return (tableInfo(class) .. tableInfo(getmetatable(class)))
end

function tableInfo(tbl, prefix)
    if prefix and string.len(prefix) > 100 then return "" end	
	if type(tbl) ~= "table" then return "" end
		
    prefix = prefix or "\n"
	local result = prefix .. "---------------------"
    for k, v in pairsByKeys(tbl) do
		if type(v) == "function" then
			result = result .. prefix .. tostring(k) .. " function"
			--result = result .. tableInfo(getArgs(v), prefix .. " | ")
        else
			result = result .. 
				prefix .. tostring(k) .. " -> " .. tostring(v)
		end	
		
        if type(v) == "table" then
            result = result .. tableInfo(v, prefix .. " | ")
        end	
		
		if getmetatable(v) and (type(v)=="table" or type(v)=="userdata" or type(v)=="function" ) then
			result = result .. tableInfo(getmetatable(v), prefix .. " | ")
		end
    end
	result = result .. prefix .. "---------------------"
	
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
