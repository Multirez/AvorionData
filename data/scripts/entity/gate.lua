package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

require ("galaxy")
require ("faction")
require ("stringutility")
local SectorSpecifics = require ("sectorspecifics")

-- namespace Gate
Gate = {}

local base = 0
local gateReady

local dirs =
{
	{name = "E",		angle = math.pi * 2 * 0 / 16},
	{name = "ENE",	angle = math.pi * 2 * 1 / 16},
	{name = "NE",		angle = math.pi * 2 * 2 / 16},
	{name = "NNE",	angle = math.pi * 2 * 3 / 16},
	{name = "N",		angle = math.pi * 2 * 4 / 16},
	{name = "NNW",	angle = math.pi * 2 * 5 / 16},
	{name = "NW",	angle = math.pi * 2 * 6 / 16},
	{name = "WNW",	angle = math.pi * 2 * 7 / 16},
	{name = "W",		angle = math.pi * 2 * 8 / 16},
	{name = "WSW",	angle = math.pi * 2 * 9 / 16},
	{name = "SW",	angle = math.pi * 2 * 10 / 16},
	{name = "SSW",	angle = math.pi * 2 * 11 / 16},
	{name = "S",		angle = math.pi * 2 * 12 / 16},
	{name = "SSE",	angle = math.pi * 2 * 13 / 16},
	{name = "SE",		angle = math.pi * 2 * 14 / 16},
	{name = "ESE",	angle = math.pi * 2 * 15 / 16},
	{name = "E",		angle = math.pi * 2 * 16 / 16}
}

function Gate.getGateName()

	local x, y = Sector():getCoordinates()
	local tx, ty = WormHole():getTargetCoordinates()

	local specs = SectorSpecifics(tx, ty, getGameSeed())

	-- find "sky" direction to name the gate
	local ownAngle = math.atan2(ty - y, tx - x) + math.pi * 2
	if ownAngle > math.pi * 2 then ownAngle = ownAngle - math.pi * 2 end
	if ownAngle < 0 then ownAngle = ownAngle + math.pi * 2 end

	local dirString, iconPath = "", ""
	local min = 3.0
	for _, dir in pairs(dirs) do

		local d = math.abs(ownAngle - dir.angle)
		if d < min then
			min = d
			iconPath = "data/textures/icons/pixel/lyr/gate"..dir.name..".png"
			dirString = (dir.name .. " /*direction*/")%_t
		end
	end

	return iconPath, "${dir} Gate to ${sector}"%_t % {dir = dirString, sector = specs.name}
end

function Gate.initialize()
	local entity = Entity()
	local wormhole = entity:getWormholeComponent()

	local tx, ty = wormhole:getTargetCoordinates()
	local x, y = Sector():getCoordinates()

	local d = distance(vec2(x, y), vec2(tx, ty))

	local cx = (x + tx) / 2
	local cy = (y + ty) / 2

	base = math.ceil(d * 30 * Balancing_GetSectorRichnessFactor(cx, cy))

	if onServer() then
		-- get callbacks for sector readiness
		entity:registerCallback("destinationSectorReady", "updateTooltip")

		Gate.updateTooltip()
	else
		-- local _, gateTitle = Gate.getGateName()
		EntityIcon().icon, Entity().title = Gate.getGateName()

		-- EntityIcon().icon = "data/textures/icons/pixel/lyr/gateNA.png"
		-- Entity().title = gateTitle
		
		invokeServerFunction("updateTooltip")
		entity:registerCallback("onSelected", "updateTooltip")
	end
end


function Gate.updateTooltip(ready)
	if onServer() then
		-- on the server, check if the sector is ready,
		-- then invoke client sided tooltip update with the ready variable
		local entity = Entity()
		local transferrer = EntityTransferrer(entity.index)

		ready = transferrer.sectorReady

		if not callingPlayer then
			broadcastInvokeClientFunction("updateTooltip", ready);
		else
			invokeClientFunction(Player(callingPlayer), "updateTooltip", ready)
		end
	else
		if type(ready) == "boolean" then
			gateReady = ready
		end

		-- on the client, calculate the fee and update the tooltip
		local user = Player()
		local ship = Entity(user.craftIndex)

		-- during login/loading screen it's possible that the player still has to be placed in his drone, so ship is nil
		if not ship then return end

		local shipFaction = Faction(ship.factionIndex)
		if shipFaction then
			user = shipFaction
		end

		local fee = math.ceil(base * Gate.factor(Faction(), user))
		local tooltip = EntityTooltip(Entity().index)
		local gateIcon = EntityIcon().icon

		tooltip:setDisplayTooltip(0, "Fee"%_t, tostring(fee) .. "$")
		
		if not gateReady then
			-- if gateIcon ~= "data/textures/icons/pixel/lyr/gateNA.png" then
				-- EntityIcon().icon = "data/textures/icons/pixel/lyr/gateNA.png"
			-- end
			
			tooltip:setDisplayTooltip(1, "Not Ready"%_t, "Not Ready"%_t)
		else
			-- if gateIcon == "" or gateIcon == "data/textures/icons/pixel/lyr/gateNA.png" then
				-- EntityIcon().icon = Gate.getGateName()
			-- end
			
			tooltip:setDisplayTooltip(1, "Ready"%_t, "Ready"%_t)
		end
	end
end

function Gate.factor(providingFaction, orderingFaction)
	if orderingFaction.index == providingFaction.index then return 0 end

	local relation = 0

	relation = providingFaction:getRelations(orderingFaction.index)

	local factor = relation / 100000 -- -1 to 1

	factor = factor + 1.0 -- 0 to 2
	factor = 2.0 - factor -- 2 to 0

	-- pay extra if relations are not good
	if relation < 0 then
		factor = factor * 1.5
	end

	return factor
end

function Gate.canTransfer(index)
	local ship = Entity(index)
	local faction = Faction(ship.factionIndex)

	-- unowned objects and AI factions can always pass
	if not faction or faction.isAIFaction then
		return 1
	end

	-- when a craft has no pilot then the owner faction must pay
	local pilotIndex = ship:getPilotIndices()
	local buyer, player
	if pilotIndex then
		buyer, _, player = getInteractingFaction(pilotIndex, AlliancePrivilege.SpendResources)

		if not buyer then return 0 end
	else
		buyer = faction
		if faction.isPlayer then
			player = Player(faction.index)
		end
	end

	local fee = math.ceil(base * Gate.factor(buyer, Faction()))
	local canPay, msg, args = buyer:canPay(fee)

	if not canPay then
		if player then
			player:sendChatMessage("Gate Control"%_t, 1, msg, unpack(args))
		end

		return 0
	end

	if player then
		player:sendChatMessage("Gate Control"%_t, 3, "You paid %i credits passage fee."%_t, fee)
	end

	buyer:pay("Paid %1% credits gate passage fee."%_T, fee)

	return 1
end
