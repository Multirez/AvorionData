if onServer() then

package.path = package.path .. ";data/scripts/lib/?.lua"

ShipGenerator = require ("shipgenerator")
NamePool = require ("namepool")
require ("randomext")
require ("stringutility")
local SectorSpecifics = require("sectorspecifics")

local merchants = {}
table.insert(merchants, {name = "Mobile Equipment Merchant", script = "data/scripts/entity/merchants/equipmentdock.lua"})
table.insert(merchants, {name = "Mobile Resource Merchant", script = "data/scripts/entity/merchants/resourcetrader.lua"})
table.insert(merchants, {name = "Mobile Merchant", script = "data/scripts/entity/merchants/tradingpost.lua"})
table.insert(merchants, {name = "Mobile Turret Merchant", script = "data/scripts/entity/merchants/turretmerchant.lua"})
table.insert(merchants, {name = "Mobile Planetary Merchant", script = "data/scripts/entity/merchants/planetarytradingpost.lua"})

function initialize()

    -- create the merchant
    local pos = random():getDirection() * 1500
    local matrix = MatrixLookUpPosition(normalize(-pos), vec3(0, 1, 0), pos)
    local faction = Galaxy():getNearestFaction(Sector():getCoordinates())

    local ship = ShipGenerator.createTradingShip(faction, matrix)

    local index = random():getInt(1, #merchants)
    local merchant = merchants[index]
    local argument

    -- planetary merchant possible?
    if merchant.script == "data/scripts/entity/merchants/planetarytradingpost.lua" then
        local x, y = Sector():getCoordinates()
        local specs = SectorSpecifics(x, y, Server().seed)
        local planets = {specs:generatePlanets()}

        if #planets == 0 then
            -- choose other merchant
            while merchant.script == "data/scripts/entity/merchants/planetarytradingpost.lua" do
                index = random():getInt(1, #merchants)
                merchant = merchants[index]
            end
        else
            argument = planets[1]
        end
    end

    ship.title = merchant.name
    ship:addScript(merchant.script, argument)
    ship:addScript("data/scripts/entity/merchants/travellingmerchant.lua")
    NamePool.setShipName(ship)

    if index == 1 and math.random() < 0.5 then
        ship:invokeFunction("equipmentdock", "addFront", SystemUpgradeTemplate("data/scripts/systems/teleporterkey4.lua", Rarity(RarityType.Legendary), random():createSeed()), 1)
    end

    Sector():broadcastChatMessage("${title} ${name}"%_t % ship, 0, "Hello Everybody! %s %s here. I'll be here for the next 15 minutes. Come look at my merchandise!"%_t, ship.title, ship.name)

    terminate()
end

end
