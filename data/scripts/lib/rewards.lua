package.path = package.path .. ";data/scripts/lib/?.lua"
require ("randomext")
require ("stringutility")
TurretGenerator = require ("turretgenerator")
UpgradeGenerator = require ("upgradegenerator")

local Rewards = {}

local messages1 =
{
    "Thank you."%_T,
    "Thank you so much."%_T,
    "We thank you."%_T,
    "Thank you for helping us."%_T,
}

local messages2 =
{
    "You have our endless gratitude."%_T,
    "We transferred a reward to your account."%_T,
    "We have a reward for you."%_T,
    "Please take this as a sign of our gratitude."%_T,
}

function standard(player, faction, msg, money, reputation, turret, system)

    msg = msg or messages1[random():getInt(1, #messages1)] .. " " .. messages2[random():getInt(1, #messages2)]

    -- give payment to players who participated
    player:sendChatMessage(faction.name, 0, msg)
    player:receive("Received a reward of %1% credits."%_T, money)
    Galaxy():changeFactionRelations(player, faction, reputation)

    local x, y = Sector():getCoordinates()
    local object

    if system and random():getFloat() < 0.5 then
        UpgradeGenerator.initialize(random():createSeed())
        object = UpgradeGenerator.generateSystem(Rarity(RarityType.Uncommon))
    elseif turret then
        object = InventoryTurret(TurretGenerator.generate(Sector():getCoordinates()))
    end

    if object then player:getInventory():add(object) end

end

Rewards.standard = standard

return Rewards
