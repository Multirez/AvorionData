if onServer() then

package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/sector/factionwar/?.lua"
require("factionwarutility")
require("randomext")

local searchTries = 0
local retryScheduled = false

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace InitFactionWar
InitFactionWar = {}

function InitFactionWar.initialize()
    Sector():registerCallback("onPlayerEntered", "onPlayerEntered")
end

function InitFactionWar.onPlayerEntered()
    InitFactionWar.tryStartBattle()
end

function InitFactionWar.retry()
    retryScheduled = false
    InitFactionWar.tryStartBattle()
end

function InitFactionWar.scheduleRetry(time)
    if not retryScheduled then
        deferredCallback(time, "retry") -- try again later
        retryScheduled = true
    end
end

function InitFactionWar.tryStartBattle()

    -- print ("try starting faction battle")

    local faction, enemyFaction = InitFactionWar.getLocalEnemies()
    if not faction or not enemyFaction then
        InitFactionWar.scheduleRetry(30.0)
        return
    end

    -- check if there are players who don't participate in the war
    local unwitnessedPlayers, players = InitFactionWar.hasUnwitnessedPlayers(faction)

    -- don't schedule retries if there are no players in the sector
    -- don't use resources when we don't have to
    if players == 0 then return end

    local startEvent = false
    -- definitely schedule a battle if there are players who don't know about the war yet
    if unwitnessedPlayers then startEvent = true end

    -- otherwise, try starting the event with a certain chance
    if random():test(0.15) then startEvent = true end

    if startEvent then
        -- print ("starting event: battle between factions " .. faction.name .. " and " .. enemyFaction.name)
        deferredCallback(30.0, "startBattle", faction.index, enemyFaction.index)
        Galaxy():setFactionRelations(faction, enemyFaction, -100000)

        -- no retry callback here on purpose
        -- don't reattack the same sector over and over
        -- battles will still be scheduled again when the sector gets unloaded and reloaded
    else
        -- print ("randomly not successful or no players")
        -- print ("players: %i", players)

        -- didn't work out, try again in a few minutes
        InitFactionWar.scheduleRetry(60 * 10)
    end

end

function InitFactionWar.hasUnwitnessedPlayers(faction)
    local key = getFactionWarSideVariableName(faction)
    local players = {Sector():getPlayers()}
    for _, player in pairs(players) do
        if not player:getValue(key) then
            return true, #players
        end
    end

    return false, #players
end

function InitFactionWar.getLocalEnemies()
    local sector = Sector()
    local x, y = sector:getCoordinates()

    local faction = Galaxy():getControllingFaction(x, y)
    if not faction or not faction.isAIFaction then
        -- print ("no local AI faction found")
        return
    end

    -- if the faction doesn't have an enemy yet, find one at random
    local enemyFaction
    local enemyFactionIndex = faction:getValue("enemy_faction")
    if enemyFactionIndex and enemyFactionIndex == -1 then
        -- print ("faction does not participate in faction wars")
        return
    end

    if not enemyFactionIndex then
        searchTries = searchTries + 1

        if searchTries > 5 then
            -- if there have already been too many tries, just stop
            return
        end

        -- check if there's a controlling AI faction nearby
        for i = 1, 20 do
            local dir = random():get2DDirection() * random():getFloat(15, 25)
            local ox, oy = x + dir.x, y + dir.y

            local enemy = Galaxy():getControllingFaction(ox, oy)
            if enemy
                and enemy.index ~= faction.index
                and not enemy.isPlayer
                and not enemy:getValue("enemy_faction") then

                enemyFactionIndex = enemy.index
                break
            end
        end

        -- check if there's a AI faction living nearby
        if not enemyFactionIndex then
            for i = 1, 20 do
                local dir = random():get2DDirection() * random():getFloat(15, 25)
                local ox, oy = x + dir.x, y + dir.y

                local enemy = Galaxy():getLocalFaction(ox, oy)
                if enemy
                    and enemy.index ~= faction.index
                    and not enemy.isPlayer
                    and not enemy:getValue("enemy_faction") then

                    enemyFactionIndex = enemy.index
                    break
                end
            end
        end

        if not enemyFactionIndex then
            -- print ("no enemy faction found")
            return
        end

        enemyFaction = Faction(enemyFactionIndex)
        if not enemyFaction then
            -- print ("enemy not a faction?")
            return
        end

        -- at least one of the factions must be aggressive
        if faction:getTrait("aggressive") < 0.9 and enemyFaction:getTrait("aggressive") < 0.9 then
            -- print ("none of the factions is aggressive")
            return
        end

        enemyFaction:setValue("enemy_faction", faction.index)
        faction:setValue("enemy_faction", enemyFaction.index)
    else
        enemyFaction = Faction(enemyFactionIndex)
    end

    return faction, enemyFaction
end

function InitFactionWar.startBattle(defenders, attackers)
    Sector():addScriptOnce("factionwar/factionwarbattle.lua", defenders, attackers)
end















end
