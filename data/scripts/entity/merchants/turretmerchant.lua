package.path = package.path .. ";data/scripts/lib/?.lua"
require ("galaxy")
require ("utility")
require ("randomext")
require ("faction")
require("stringutility")
local ShopAPI = require ("shop")
local TurretGenerator = require ("turretgenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TurretMerchant
TurretMerchant = {}
TurretMerchant = ShopAPI.CreateNamespace()

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function TurretMerchant.interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, 0)
end

local function comp(a, b)
    local ta = a.turret;
    local tb = b.turret;

    if ta.rarity.value == tb.rarity.value then
        if ta.material.value == tb.material.value then
            return ta.weaponPrefix < tb.weaponPrefix
        else
            return ta.material.value > tb.material.value
        end
    else
        return ta.rarity.value > tb.rarity.value
    end
end

function TurretMerchant.shop:addItems()

    -- simply init with a 'random' seed
    local station = Entity()

    -- create all turrets
    local turrets = {}

    for i = 1, 10 do
        local turret = InventoryTurret(TurretGenerator.generate(Sector():getCoordinates()))

        local pair = {}
        pair.turret = turret
        pair.amount = 1

        if turret.rarity.value == 1 then -- uncommon weapons may be more than one
            if math.random() < 0.3 then
                pair.amount = pair.amount + 1
            end
        elseif turret.rarity.value == 0 then -- common weapons may be some more than one
            if math.random() < 0.5 then
                pair.amount = pair.amount + 1
            end
            if math.random() < 0.5 then
                pair.amount = pair.amount + 1
            end
        end

        table.insert(turrets, pair)
    end

    table.sort(turrets, comp)

    for _, pair in pairs(turrets) do
        TurretMerchant.shop:add(pair.turret, pair.amount)
    end

end

function TurretMerchant.initialize()
    TurretMerchant.shop:initialize("Turret Merchant"%_t)

    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/turret.png"
    end
end

function TurretMerchant.initUI()
    TurretMerchant.shop:initUI("Trade Equipment"%_t, "Turret Merchant"%_t, "Turrets"%_t)
end
