package.path = package.path .. ";data/scripts/lib/?.lua"
require ("utility")
require ("randomext")
require ("faction")
local ShopAPI = require ("shop")
local UpgradeGenerator = require("upgradegenerator")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace EquipmentDock
EquipmentDock = {}
EquipmentDock = ShopAPI.CreateNamespace()

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function EquipmentDock.interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, -10000)
end

local function sortSystems(a, b)
    if a.rarity.value == b.rarity.value then
        return a.price > b.price
    end

    return a.rarity.value > b.rarity.value
end

function EquipmentDock.shop:addItems()

    UpgradeGenerator.initialize()

    local counter = 0
    local systems = {}
    while counter < 12 do

        local x, y = Sector():getCoordinates()
        local rarities, weights = UpgradeGenerator.getSectorProbabilities(x, y)

        weights[6] = weights[6] * 0.25 -- strongly reduced probability for normal high rarity equipment
        weights[7] = 0 -- no legendaries in equipment dock

        local system = UpgradeGenerator.generateSystem(nil, weights)

        if system.rarity.value >= 0 or math.random() < 0.25 then
            table.insert(systems, system)
            counter = counter + 1
        end
    end

    table.sort(systems, sortSystems)

    for _, system in pairs(systems) do
        EquipmentDock.shop:add(system, getInt(1, 2))
    end

end

function EquipmentDock.initialize()
    EquipmentDock.shop:initialize("Equipment Dock"%_t)

    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/sdwhite.png"
    end
end

function EquipmentDock.initUI()
    EquipmentDock.shop:initUI("Trade Equipment"%_t, "Equipment Dock"%_t, "Upgrades"%_t)
end
