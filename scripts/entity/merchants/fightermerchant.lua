package.path = package.path .. ";data/scripts/lib/?.lua"
require ("galaxy")
require ("utility")
require ("randomext")
require ("faction")
require ("sellableinventoryitem")
require ("stringutility")
local FighterGenerator = require("fightergenerator")
local Dialog = require("dialogutility")
local ShopAPI = require ("shop")
local SellableFighter = require ("sellablefighter")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace FighterMerchant
FighterMerchant = {}
FighterMerchant = ShopAPI.CreateNamespace()

-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
function FighterMerchant.interactionPossible(playerIndex, option)
    local player = Player(playerIndex)
    local ship = player.craft
    if not ship then return false end
    if not ship:hasComponent(ComponentType.Hangar) then return false end

    return CheckFactionInteraction(playerIndex, 0)
end

local function comp(a, b)
    local ta = a.fighter;
    local tb = b.fighter;

    if ta.type == tb.type then
        if ta.rarity.value == tb.rarity.value then
            if ta.material.value == tb.material.value then
                return ta.weaponPrefix < tb.weaponPrefix
            else
                return ta.material.value > tb.material.value
            end
        else
            return ta.rarity.value > tb.rarity.value
        end
    else
        return ta.type < tb.type
    end
end

function FighterMerchant.shop:addItems()

    local station = Entity()

    if station.title == "" then
        station.title = "Fighter Merchant"%_t
    end

    -- create all fighters
    local allFighters = {}

    for i = 1, 6 do
        local fighter = FighterGenerator.generate(Sector():getCoordinates())

        local pair = {}
        pair.fighter = fighter
        pair.amount = 1

        if fighter.rarity.value == RarityType.Exceptional then
            pair.amount = getInt(1, 3)
        elseif fighter.rarity.value == RarityType.Rare then
            pair.amount = getInt(3, 5)
        elseif fighter.rarity.value == RarityType.Uncommon then
            pair.amount = getInt(5, 8)
        elseif fighter.rarity.value == RarityType.Common then
            pair.amount = getInt(8, 12)
        end

        table.insert(allFighters, pair)
    end

    for i = 1, 3 do
        local fighter = FighterGenerator.generateCargoShuttle(Sector():getCoordinates())

        local pair = {}
        pair.fighter = fighter
        pair.amount = getInt(8, 12)

        table.insert(allFighters, pair)
    end

    table.sort(allFighters, comp)

    for _, pair in pairs(allFighters) do
        FighterMerchant.shop:add(pair.fighter, pair.amount)
    end

end

function FighterMerchant.initialize()
    FighterMerchant.shop:initialize("Fighter Merchant"%_t)
end

function FighterMerchant.initUI()
    FighterMerchant.shop:initUI("Trade Equipment"%_t, "Fighter Merchant"%_t, "Fighters"%_t)
end

FighterMerchant.shop.ItemWrapper = SellableFighter
FighterMerchant.shop.SortFunction = comp



