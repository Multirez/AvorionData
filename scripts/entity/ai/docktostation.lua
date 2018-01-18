
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/entity/?.lua"

require ("stringutility")
local DockAI = require ("ai/dock")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AIDockToStation
AIDockToStation = {}

local data = {}
data.docking = true
data.station = ""

function AIDockToStation.getUpdateInterval()
    return 2
end

function AIDockToStation.initialize(station, docking)
    if onServer() and station then
        data.station = station
        if docking ~= nil then data.docking = docking end
    end
end

-- this function will be executed every frame on the server only
function AIDockToStation.updateServer(timeStep)
    local ship = Entity()

    if ship.playerOwned or ship.allianceOwned then
        if ship.hasPilot or ship:getCrewMembers(CrewProfessionType.Captain) then
            AIDockToStation.finalize()
            return
        end
    end

    AIDockToStation.updateDocking(timeStep)
end

function AIDockToStation.updateDocking(timeStep)
    local ship = Entity()
    local station = Entity(data.station)

    -- in case the station doesn't exist any more, stop
    if not station then
        AIDockToStation.finalize()
        return
    end

    local pos, dir = station:getDockingPositions()

    -- stages
    if not pos or not dir or not valid(station) then
        -- something is not right, abort
        AIDockToStation.finalize()
        return
    else

        if data.docking then
            -- if we're docking, fly to the dock
            if DockAI.flyToDock(ship, station) then
                AIDockToStation.finalize()
            end
        else
            -- otherwise, fly away from the dock
            if DockAI.flyAwayFromDock(ship, station) then
                AIDockToStation.finalize()
            end
        end
    end

end

function AIDockToStation.finalize()
    ShipAI():setIdle()
    terminate()
end

function AIDockToStation.secure()
    return data
end

function AIDockToStation.restore(data_in)
    data = data_in
end

---- this function will be executed every frame on the client only
--function updateClient(timeStep)
--
--    if valid(minedWreckage) then
--        drawDebugSphere(minedWreckage:getBoundingSphere(), ColorRGB(1, 0, 0))
--    end
--end
