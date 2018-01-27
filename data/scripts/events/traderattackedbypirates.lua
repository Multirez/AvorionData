if onServer() then

package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

require ("galaxy")
require ("randomext")
require ("stringutility")
local Placer = require("placer")
local AsyncPirateGenerator = require ("asyncpirategenerator")
local UpgradeGenerator = require ("upgradegenerator")
local TurretGenerator = require ("turretgenerator")
local ShipGenerator = require ("shipgenerator")
local ShipUtility = require ("shiputility")


local traderShip
local ships = {}
local reward = 0
local reputation = 0

local participants = {}

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TraderAttackedByPirates
TraderAttackedByPirates = {}
TraderAttackedByPirates.attackersGenerated = false


function TraderAttackedByPirates.secure()
    return {reward = reward, reputation = reputation, ships = ships}
end

function TraderAttackedByPirates.restore(data)
    ships = data.ships
    reputation = data.reputation
    reward = data.reward
end

function TraderAttackedByPirates.initialize()

    -- no pirate attacks at the very edge of the galaxy
    local x, y = Sector():getCoordinates()
    if length(vec2(x, y)) > 560 then
        print ("Too far out for pirate attacks.")
        terminate()
        return
    end

    if Sector():getValue("neutral_zone") then
        print ("No pirate attacks in neutral zones.")
        terminate()
        return
    end

    ships = {}
    participants = {}
    reward = 0
    reputation = 0

    local scaling = Sector().numPlayers
    if scaling == 0 then
        terminate()
        return
    end

    if scaling == 1 then
        local player = Sector():getPlayers()
        local hx, hy = player:getHomeSectorCoordinates()
        if hx == x and hy == y and player.playtime < 30 * 60 then
            print ("Player's playtime is below 30 minutes (%is), cancelling pirate attack.", player.playtime)
            terminate()
            return
        end
    end

    -- create ships
    local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1200

    local attackType = getInt(1, 4)

    local distance = 50

    -- create trader
    local traderPos = dir * 900
    local traderFaction = Galaxy():getNearestFaction(x + math.random(-15, 15), y + math.random(-15, 15))
    local traderDestination = -traderPos + vec3(math.random(), math.random(), math.random()) * 1000

    if math.random() < 0.5 then
        traderShip = ShipGenerator.createTradingShip(traderFaction, MatrixLookUpPosition(-dir, vec3(0, 1, 0), traderPos))
    else
        traderShip = ShipGenerator.createFreighterShip(traderFaction, MatrixLookUpPosition(-dir, vec3(0, 1, 0), traderPos))
    end
    traderShip:addScript("deleteonplayersleft.lua")
    ShipAI(traderShip.index):setPassiveShooting(true)
    traderShip:registerCallback("onDestroyed", "onTraderShipDestroyed")

    if math.random() < 0.8 then
        ShipUtility.addCargoToCraft(traderShip)
    end

    -- create attackers
    local generator = AsyncPirateGenerator(TraderAttackedByPirates, TraderAttackedByPirates.onPiratesGenerated)
    generator:startBatch()

    if attackType == 1 then
        reward = 2.0

        generator:createScaledRaider(MatrixLookUpPosition(-dir, up, pos))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * distance))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * -distance))

    elseif attackType == 2 then
        reward = 1.5

        generator:createScaledPirate(MatrixLookUpPosition(-dir, up, pos))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * distance))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * -distance))

    elseif attackType == 3 then
        reward = 1.5

        generator:createScaledPirate(MatrixLookUpPosition(-dir, up, pos))
        generator:createScaledPirate(MatrixLookUpPosition(-dir, up, pos + right * distance))
        generator:createScaledPirate(MatrixLookUpPosition(-dir, up, pos + right * -distance))
    else
        reward = 1.0

        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * distance))
        generator:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * -distance))
        generator:createScaledOutlaw(MatrixLookUpPosition(-dir, up, pos + right * -distance * 2.0))
        generator:createScaledOutlaw(MatrixLookUpPosition(-dir, up, pos + right * distance * 2.0))
    end

    generator:endBatch()

    reputation = reward * 2000
    reward = reward * 4500 * Balancing_GetSectorRichnessFactor(Sector():getCoordinates())

    Sector():broadcastChatMessage("Server"%_t, 2, "A ship in your sector is calling for help!"%_t)

    local messages =
    {
        "Mayday! Mayday! Our engines are failing and we are under attack by pirates! Help us, please!"%_t,
        "Help! Pirates are on our tail and our engines are down! We are stranded here!"%_t
    }
    Sector():broadcastChatMessage(traderShip.name, 0, messages[random():getInt(1, #messages)])
end

function TraderAttackedByPirates.getUpdateInterval()
    return 15
end

function TraderAttackedByPirates.onPiratesGenerated(generated)
    for _, ship in pairs(generated) do
        ships[ship.index.string] = true
        ship:registerCallback("onShotHit", "onShotHit")
        ship:registerCallback("onDestroyed", "onShipDestroyed")
        ShipAI(ship.index):setAttack(traderShip)
    end

    Placer.resolveIntersections(generated)
    TraderAttackedByPirates.attackersGenerated = true
end

function TraderAttackedByPirates.update(timeStep)

    if not TraderAttackedByPirates.attackersGenerated then return end

    -- check if the trader is still there
    local sector = Sector()
    if not valid(traderShip) then
        traderShip = nil
        TraderAttackedByPirates.endEvent()
        return
    end

    -- check if all ships are still there
    -- ships might have changed sector or deleted in another way, which doesn't trigger destruction callback
    for id, _ in pairs(ships) do
        local pirate = sector:getEntity(Uuid(id))
        if pirate == nil then
            ships[id] = nil
        end
    end

    -- if not -> end event
    if tablelength(ships) == 0 then
        TraderAttackedByPirates.endEvent()
        return
    end
end

function TraderAttackedByPirates.onShotHit(objectIndex, shooterIndex)
    if shooterIndex.string ~= traderShip.index.string then
        TraderAttackedByPirates.setAggressiveAndUnregister(objectIndex)
    end
end

function TraderAttackedByPirates.setAggressiveAndUnregister(id)
    -- unregister callbacks
    local pirate = Entity(Uuid(id))
    if pirate then
        pirate:unregisterCallback("onShotHit", "onShotHit")
    end
    -- set agressive
    local ai = ShipAI(Uuid(id))
    if ai then
        ai:setAggressive()
    end
end

function TraderAttackedByPirates.onShipDestroyed(shipIndex)

    ships[shipIndex.string] = nil

    local ship = Entity(shipIndex)
    local damagers = {ship:getDamageContributorPlayers()}
    for i, v in pairs(damagers) do
        participants[v] = v
    end

    -- if they're all destroyed, the event ends
    if tablelength(ships) == 0 then
        TraderAttackedByPirates.endEvent()
    end
end

function TraderAttackedByPirates.onTraderShipDestroyed(shipIndex)
    traderShip = nil

    TraderAttackedByPirates.endEvent()
end

function TraderAttackedByPirates.endEvent()
    local sector = Sector()

    if not traderShip then

        -- trader is defeated
        if math.random() < 0.5 then
            -- option 1: pirates leave
            local pirateName

            for id, _ in pairs(ships) do
                local pirate = sector:getEntity(Uuid(id))

                if pirate then
                    if not pirateName then
                        local faction = Faction(pirate.factionIndex)
                        if faction then
                            pirateName = faction.name
                        end
                    end

                    sector:deleteEntityJumped(pirate)
                end
            end

            if pirateName then
                local messages =
                {
                    "He's finished. Let's go!"%_t,
                    "Let's get out of here."%_t
                }
                sector:broadcastChatMessage(pirateName, 0, getRandomEntry(messages))
            end
        else

            -- option 2: pirates stay
            for id, _ in pairs(ships) do
                TraderAttackedByPirates.setAggressiveAndUnregister(id)
            end
        end

        terminate()
        return
    end

    -- trader survived, pirates are defeated
    local messages =
    {
        "Thank you for defending us from those pirates. You have our endless gratitude."%_t,
        "We thank you for taking care of those ships. We transferred a reward to your account."%_t,
        "Thank you for taking care of those pirates. We transferred a reward to your account."%_t,
    }

    local faction = Faction(traderShip.factionIndex)
    if faction then
        -- give payment to players who participated
        for i, v in pairs(participants) do
            local player = Player(i)

            player:sendChatMessage(faction.name, 0, getRandomEntry(messages))
            player:receive("Received %1% credits for defending a trader from pirates."%_T, reward)
            Galaxy():changeFactionRelations(player, faction, reputation)

            local x, y = Sector():getCoordinates()
            local object

            if random():getFloat() < 0.5 then
                object = InventoryTurret(TurretGenerator.generate(x, y, 0, Rarity(RarityType.Exceptional)))
            else
                UpgradeGenerator.initialize(random():createSeed())
                object = UpgradeGenerator.generateSystem(Rarity(RarityType.Exceptional))
            end

            if object then player:getInventory():add(object) end
        end
    end

    terminate()
end

end
