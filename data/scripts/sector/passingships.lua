if onServer() then

package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";?"

require ("galaxy")
require ("randomext")
local AsyncShipGenerator = require ("asyncshipgenerator")
local Placer = require ("placer")
local ShipUtility = require ("shiputility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace PassingShips
PassingShips = {}

-- ships passing through
local passThroughCreationCounter = 0

function PassingShips.getUpdateInterval()
    return 175 + random():getFloat(0, 5)
end

function PassingShips.update(timeStep)

    -- don't create server load when there are no players to witness it
    if Sector().numPlayers == 0 then return end

    -- not too many passing ships at one time
    local sector = Sector()
    local stations = {sector:getEntitiesByType(EntityType.Station)}

    local maxPassThroughs = #stations * 0.5 + 1

    local passingShips = {Sector():getEntitiesByScript("ai/passsector.lua")}
    if tablelength(passingShips) >= maxPassThroughs then return end


    local galaxy = Galaxy()
    local x, y = sector:getCoordinates()

    local faction = galaxy:getNearestFaction(x + math.random(-15, 15), y + math.random(-15, 15))

    -- this is the position where the trader spawns
    local dir = random():getDirection()
    local pos = dir * 1500

    -- this is the position where the trader will jump into hyperspace
    local destination = -pos + vec3(math.random(), math.random(), math.random()) * 1000
    destination = normalize(destination) * 1500

    -- create a single trader or a convoy
    local numTraders = 1
    if math.random() < 0.1 then
        numTraders = 6
    end

    local onFinished = function(ships)
        for _, ship in pairs(ships) do
            if math.random() < 0.8 then
                ShipUtility.addCargoToCraft(ship)
            end

            ship:addScript("ai/passsector.lua", destination)
        end

        Placer.resolveIntersections(ships)
    end

    local generator = AsyncShipGenerator(PassingShips, onFinished)
    generator:startBatch()

    for i = 1, numTraders do
        pos = pos + dir * 200
        local matrix = MatrixLookUpPosition(-dir, vec3(0, 1, 0), pos)

        local ship
        if math.random() < 0.5 then
            generator:createTradingShip(faction, matrix)
        else
            generator:createFreighterShip(faction, matrix)
        end
    end

    generator:endBatch()
end

end
