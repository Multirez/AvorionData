if onServer() then

package.path = package.path .. ";data/scripts/lib/?.lua"
require ("stringutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace NeutralZone
NeutralZone = {}

function NeutralZone.initialize()
    Sector():registerCallback("onPlayerEntered", "onPlayerEntered")
    Sector().pvpDamage = 0
    Sector():setValue("neutral_zone", 1)

    Sector():removeScript("data/scripts/sector/factionwar/initfactionwar.lua")
end

function NeutralZone.onPlayerEntered(playerIndex)
    local player = Player(playerIndex)
    local msg = "You have entered a neutral zone. Player to player damage is disabled in this sector."%_T

    player:sendChatMessage("Server", 0, msg)
    player:sendChatMessage("Server", 3, msg)
end

end
