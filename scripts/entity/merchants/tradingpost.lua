package.path = package.path .. ";data/scripts/lib/?.lua"
require ("randomext")
require ("galaxy")
require ("faction")
require ("utility")
require ("stringutility")
require ("stationextensions")
local TradingAPI = require ("tradingmanager")
local Dialog = require("dialogutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TradingPost
TradingPost = {}
TradingPost = TradingAPI:CreateNamespace()
TradingPost.trader.tax = 0.2
TradingPost.trader.factionPaymentFactor = 0.0

-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
function TradingPost.interactionPossible(playerIndex, option)
    if Player(playerIndex).craftIndex == Entity().index then return false end

    return CheckFactionInteraction(playerIndex, -45000)
end

function TradingPost.restore(data)
    TradingPost.restoreTradingGoods(data)
end

function TradingPost.secure()
    return TradingPost.secureTradingGoods()
end

-- this function gets called on creation of the entity the script is attached to, on client and server
function TradingPost.initialize()
    local station = Entity()

    if station.title == "" then
        station.title = "Trading Post"%_t

        if onServer() then
            local count = getInt(2, 3)
            addCargoStorage(station, count)
        end
    end

    if onServer() then
        math.randomseed(Sector().seed + Sector().numEntities);

        -- make lists of all items that will be sold/bought
        local bought, sold = TradingPost.generateGoods(13, 15) -- generate both at the same time, this won't create duplicates

        TradingPost.trader.buyPriceFactor = math.random() * 0.2 + 0.9 -- 0.9 to 1.1
        TradingPost.trader.sellPriceFactor = math.random() * 0.2 + 0.9 -- 0.9 to 1.1

        TradingPost.initializeTrading(bought, sold)

        math.randomseed(appTimeMs())
    else
        TradingPost.requestGoods()

        if EntityIcon().icon == "" then
            EntityIcon().icon = "data/textures/icons/pixel/trade.png"
            InteractionText(station.index).text = Dialog.generateStationInteractionText(station, random())
        end

    end

    station:addScriptOnce("data/scripts/entity/merchants/cargotransportlicensemerchant.lua")
end

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
function TradingPost.initUI()
    local tabbedWindow = TradingAPI.CreateTabbedWindow("Trading Post"%_t)

    -- create buy tab
    local buyTab = tabbedWindow:createTab("Buy"%_t, "data/textures/icons/purse.png", "Buy from station"%_t)
    TradingPost.buildBuyGui(buyTab)

    -- create sell tab
    local sellTab = tabbedWindow:createTab("Sell"%_t, "data/textures/icons/coins.png", "Sell to station"%_t)
    TradingPost.buildSellGui(sellTab)

    TradingPost.trader.guiInitialized = true

    TradingPost.requestGoods()
end

-- this functions gets called when the indicator of the station is rendered on the client
--function renderUIIndicator(px, py, size)
--
--end
--
---- this function gets called every time the window is shown on the client, ie. when a player presses F and if interactionPossible() returned 1
function TradingPost.onShowWindow()
    TradingPost.requestGoods()
end
--
---- this function gets called every time the window is closed on the client
--function onCloseWindow()
--
--end
--
---- this function gets called once each frame, on client and server
--function update(timeStep)
--
--end
--
---- this function gets called once each frame, on client only
--function updateClient(timeStep)
--
--end

function TradingPost.getUpdateInterval()
    return 5
end

---- this function gets called once each frame, on server only
function updateServer(timeStep)
    TradingPost.useUpBoughtGoods(timeStep)

    TradingPost.updateOrganizeGoodsBulletins(timeStep)
    TradingPost.updateDeliveryBulletins(timeStep)
end
--
---- this function gets called whenever the ui window gets rendered, AFTER the window was rendered (client only)
--function renderUI()
--
--end





