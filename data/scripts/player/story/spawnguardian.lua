if onServer() then

package.path = package.path .. ";data/scripts/lib/?.lua"
local Xsotan = require("story/xsotan")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace SpawnGuardian
SpawnGuardian = {}

function SpawnGuardian.initialize()
    Player():registerCallback("onSectorEntered", "onSectorEntered")
end

function SpawnGuardian.onSectorEntered(player, x, y)
    if not (x == 0 and y == 0) then return end

    local respawnTime = Server():getValue("guardian_respawn_time")
    if respawnTime then return end

    -- only spawn him once
    local sector = Sector()
    if Sector():getEntitiesByScript("data/scripts/entity/story/wormholeguardian.lua") then return end

    -- clear everything that's not player owned
    local entities = {sector:getEntities()}
    for _, entity in pairs(entities) do
        if not entity.factionIndex or (not Player(entity.factionIndex) and not Faction(entity.factionIndex).isAlliance) then
            sector:deleteEntity(entity)
        end
    end

    Xsotan.createGuardian()
end

end
