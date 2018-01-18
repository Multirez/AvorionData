package.path = package.path .. ";data/scripts/lib/?.lua"
require ("utility")
require ("randomext")
require ("faction")
local ShopAPI = require ("shop")
require ("cargotransportlicenseutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace CargoTransportLicenseMerchant
CargoTransportLicenseMerchant = {}
CargoTransportLicenseMerchant = ShopAPI.CreateNamespace()

local isInitialized = false

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function CargoTransportLicenseMerchant.interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, 10000)
end

function CargoTransportLicenseMerchant.shop:addItems()
end

function CargoTransportLicenseMerchant.initialize()
    CargoTransportLicenseMerchant.shop:initialize("Trading Post"%_t)

    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/trade.png"
    end
end

function CargoTransportLicenseMerchant.updateServer()
    if isInitialized == false then
        local faction = Faction()

        if faction then
            isInitialized = true

            for i = 3, 0, -1 do
                local license = createLicense(Rarity(i), faction)
                CargoTransportLicenseMerchant.add(license, getInt(1, 2))
            end
        end
    end
end

function CargoTransportLicenseMerchant.initUI()
    CargoTransportLicenseMerchant.shop:initUI("Buy Cargo License"%_t, "Trading Post"%_t, "Licenses"%_t)
    CargoTransportLicenseMerchant.shop.tabbedWindow:deactivateTab(CargoTransportLicenseMerchant.shop.sellTab)
    CargoTransportLicenseMerchant.shop.tabbedWindow:deactivateTab(CargoTransportLicenseMerchant.shop.buyBackTab)
end
