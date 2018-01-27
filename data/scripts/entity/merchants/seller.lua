package.path = package.path .. ";data/scripts/lib/?.lua"
require ("galaxy")
require ("randomext")
require ("utility")
require ("faction")
require ("stringutility")
local TradingAPI = require ("tradingmanager")
local Dialog = require("dialogutility")

local window

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Seller
Seller = {}
Seller = TradingAPI:CreateNamespace()

Seller.customSellPriceFactor = nil -- set this to override the sell price factor
Seller.sellerName = ""
Seller.sellerIcon = ""
Seller.soldGoods = {}

function Seller.interactionPossible(playerIndex, option)

    if Player(playerIndex).craftIndex == Entity().index then return false end

    return CheckFactionInteraction(playerIndex, -20000)
end

function Seller.restore(values)
    Seller.restoreTradingGoods(values)
    Seller.sellerName = values.sellerName
end

function Seller.secure()
    local values = Seller.secureTradingGoods()
    values.sellerName = Seller.sellerName

    return values
end

function Seller.initialize(name_in, ...)

    local entity = Entity()

    if onServer() then
        Seller.sellerName = name_in or Seller.sellerName

        -- only use parameter goods if there are any, otherwise we prefer the goods we might already have in soldGoods
        local soldGoods_in = {...}
        if #soldGoods_in > 0 then
            Seller.soldGoods = soldGoods_in
        end

        local station = Entity()

        -- add the name as title
        if Seller.sellerName ~= "" and entity.title == "" then
            entity.title = Seller.sellerName
        end

        local seed = Sector().seed + Sector().numEntities
        math.randomseed(seed);

        -- sellers only sell
        Seller.trader.sellPriceFactor = Seller.customSellPriceFactor or math.random() * 0.2 + 0.9 -- 0.9 to 1.1

        local sold = {}

        for i, name in pairs(Seller.soldGoods) do
            local g = goods[name]
            table.insert(sold, g:good())
        end

        Seller.initializeTrading({}, sold)

        math.randomseed(appTimeMs())
    else
        Seller.requestGoods()

        if Seller.sellerIcon ~= "" and EntityIcon().icon == "" then
            EntityIcon().icon = Seller.sellerIcon
            InteractionText().text = Dialog.generateStationInteractionText(entity, random())
        end
    end

end

-- create all required UI elements for the client side
function Seller.initUI()

    local tabbedWindow = TradingAPI.CreateTabbedWindow()

    -- create buy tab
    local buyTab = tabbedWindow:createTab("Buy"%_t, "data/textures/icons/purse.png", "Buy from station"%_t)
    Seller.buildBuyGui(buyTab)

    -- create sell tab
    local sellTab = tabbedWindow:createTab("Sell"%_t, "data/textures/icons/coins.png", "Sell to station"%_t)
    Seller.buildSellGui(sellTab)

    tabbedWindow:deactivateTab(sellTab)

    Seller.trader.guiInitialized = 1

    invokeServerFunction("sendName")
    Seller.requestGoods()

end

function Seller.sendName()
    invokeClientFunction(Player(callingPlayer), "receiveName", Seller.sellerName)
end

function Seller.receiveName(name)
    if TradingAPI.window.caption ~= "" and name ~= "" then
        TradingAPI.window.caption = name%_t
    end
end

function Seller.onShowWindow()
    Seller.requestGoods()
end

function Seller.getUpdateInterval()
    return 5
end

function Seller.updateServer(timeStep)
    Seller.useUpBoughtGoods(timeStep)
    Seller.updateOrganizeGoodsBulletins(timeStep)
end

return Seller
