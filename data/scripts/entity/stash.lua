
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

require ("randomext")
require ("galaxy")
require ("stringutility")
require ("faction")
UpgradeGenerator = require ("upgradegenerator")
TurretGenerator = require ("turretgenerator")

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex, option)

    local player = Player(playerIndex)
    local self = Entity()

    local craft = player.craft
    if craft == nil then return false end

    local dist = craft:getNearestDistance(self)

    if dist < 20.0 then
        return true
    end

    return false, "You're not close enough to open the object."%_t
end

function initialize()
    local entity = Entity()

    if entity.title == "" then entity.title = "Smuggler's Cache"%_t end

end

-- create all required UI elements for the client side
function initUI()

    local res = getResolution()
    local size = vec2(800, 600)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(vec2(0, 0), vec2(0, 0)))

    menu:registerWindow(window, "Open"%_t);
end

function onShowWindow()
    invokeServerFunction("claim")
    ScriptUI():stopInteraction()
end

function receiveMoney(faction)

    local x, y = Sector():getCoordinates()
    local money = 5500 * Balancing_GetSectorRichnessFactor(x, y)

    faction:receive("Found %1% credits in a stash."%_T, money)
end

function receiveTurret(faction)

    local x, y = Sector():getCoordinates()

    local rarity = Rarity(RarityType.Uncommon)

    if random():getFloat() < 0.3 then
        rarity = Rarity(RarityType.Exceptional)
    elseif random():getFloat() < 0.7 then
        rarity = Rarity(RarityType.Rare)
    end

    local turret = InventoryTurret(TurretGenerator.generate(x, y, 0, rarity))

    faction:getInventory():add(turret)
end

function receiveUpgrade(faction)

    local rarity = Rarity(RarityType.Uncommon)

    if random():getFloat() < 0.3 then
        rarity = Rarity(RarityType.Exceptional)
    elseif random():getFloat() < 0.7 then
        rarity = Rarity(RarityType.Rare)
    end

    local x, y = Sector():getCoordinates()

    UpgradeGenerator.initialize(random():createSeed())
    local upgrade = UpgradeGenerator.generateSystem(rarity)
    faction:getInventory():add(upgrade)
end

function claim()

    local receiver, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.AddItems, AlliancePrivilege.AddResources)
    if not receiver then return end

    local dist = ship:getNearestDistance(Entity())
    if dist > 20.0 then
        player:sendChatMessage("", ChatMessageType.Error, "You're not close enough to open the object."%_t)
        return
    end

    receiveMoney(receiver)

    if random():getFloat() < 0.5 then
        receiveTurret(receiver)
    else
        receiveUpgrade(receiver)
    end

    if random():getFloat() < 0.5 then
        if random():getFloat() < 0.5 then
            receiveTurret(receiver)
        else
            receiveUpgrade(receiver)
        end
    end

    terminate()
end






