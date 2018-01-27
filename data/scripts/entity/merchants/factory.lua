
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("randomext")
require ("galaxy")
require ("utility")
require ("goods")
require ("productions")
require ("faction")
require ("stationextensions")
require ("stringutility")
local TradingUtility = require ("tradingutility")
local TradingAPI = require ("tradingmanager")
local Dialog = require("dialogutility")
local UICollection = require("uicollection")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Factory
Factory = {}
Factory = TradingAPI:CreateNamespace()

local tabbedWindow = nil


local production = nil

local factorySize = 1

local maxDuration = 15
local currentProductions = {}

local deliveryShuttles
local deliveredStations = {}
local deliveringStations = {}

local buyTab
local sellTab
local configTab

local marginLabel
local marginSlider
local allowBuyCheckBox
local allowSellCheckBox
local activelyRequestCheckBox
local activelySellCheckBox
local upgradePriceLabel
local upgradeButton
local productionErrorSign

local productionError
local newProductionError

local deliveredStationsCombos = {}
local deliveringStationsCombos = {}

local deliveredStationsErrorLabels = {}
local deliveringStationsErrorLabels = {}

local deliveredStationsErrors = {}
local deliveringStationsErrors = {}

local newDeliveredStationsErrors = {}
local newDeliveringStationsErrors = {}

Factory.MinimumCapacity = 100
Factory.PlanCapacityFactor = 1.0
Factory.MinimumTimeToProduce = 15.0

Factory.timeToProduce = Factory.MinimumTimeToProduce
Factory.productionCapacity = Factory.MinimumCapacity
Factory.maxNumProductions = 2

Factory.lowestPriceFactor = 0.7
Factory.highestPriceFactor = 1.3
Factory.traderRequestCooldown = random():getFloat(30, 150)

-- this is only important for initialization, won't be used afterwards
Factory.minLevel = nil
Factory.maxLevel = nil

-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
function Factory.interactionPossible(playerIndex, option)
    -- if Player(playerIndex).craftIndex == Entity().index then return false end

    return CheckFactionInteraction(playerIndex, -10000)
end


function Factory.restore(data)
    Factory.maxNumProductions = data.maxNumProductions
    maxDuration = data.maxDuration
    factorySize = data.maxNumProductions - 1
    production = data.production
    currentProductions = data.currentProductions
    Factory.restoreTradingGoods(data.tradingData)

    Factory.refreshProductionTime()
end

function Factory.secure()
    local data = {}
    data.maxDuration = maxDuration
    data.maxNumProductions = Factory.maxNumProductions
    data.production = production
    data.currentProductions = currentProductions
    data.tradingData = Factory.secureTradingGoods()
    return data
end


-- this function gets called on creation of the entity the script is attached to, on client and server
function Factory.initialize(producedGood, productionIndex, size)

    if onServer() then
        local self = Entity()
        local productionInitialized = self:getValue("factory_production_initialized")

        if producedGood or productionIndex or size or not productionInitialized then
            Factory.initializeProduction(producedGood, productionIndex, size)
        end

        self:registerCallback("onFighterLanded", "onFighterLanded")
        self:registerCallback("onBlockPlanChanged", "onBlockPlanChanged")

        -- execute the callback for initialization, to be sure
        Factory.onBlockPlanChanged(self.id, true)
    else
        Factory.requestProductionStats()
        Factory.requestGoods()
        Factory.sync()
    end

end

function Factory.initializeProduction(producedGood, productionIndex, size)
    local station = Entity()
    station:setValue("factory_production_initialized", true)

    local seed = Sector().seed + Sector().numEntities
    math.randomseed(seed)

    -- determine the ratio with which the factory will set its sell/buy prices
    Factory.setBuySellFactor(math.random() * (Factory.highestPriceFactor - Factory.lowestPriceFactor) + Factory.lowestPriceFactor)

    if producedGood and productionIndex == nil then

        if producedGood == "nothing" then
            return
        end

        local numProductions = tablelength(productionsByGood[producedGood])
        if numProductions == nil or numProductions == 0 then
            -- good is not produced, skip and choose randomly
            print("No productions found for " .. producedGood .. ", choosing production at random")

            producedGood = nil
        else
            productionIndex = 1
        end
    end

    if producedGood == nil or productionIndex == nil then
        -- choose a production by evaluating importance
        Factory.minLevel = Factory.minLevel or 0
        Factory.maxLevel = Factory.maxLevel or 10000

        -- choose a product by level
        -- read all levels of all products
        local potentialGoods = {}
        local highestLevel = 0

        for _, good in pairs(goodsArray) do
            if good.level ~= nil then -- if it has no level, it is not produced
                if good.level >= Factory.minLevel and good.level <= Factory.maxLevel then

                    table.insert(potentialGoods, good)

                    -- increase max level
                    if highestLevel < good.level then
                        highestLevel = good.level
                    end
                end
            end
        end

        -- calculate the probability that a certain production is chosen
        local probabilities = {}
        for i, good in pairs(potentialGoods) do
            -- highestlevel - good.level makes sure the higher goods have a smaller probability of being chosen
            -- +3 to add a little more randomness, so not only the "important" factories are created
            probabilities[i] = (highestLevel - good.level) + good.importance + 3
        end

        -- choose produced good
        local numProductions = nil

        while ((numProductions == nil) or (numProductions == 0)) do

            -- choose produced good at random from probability table
            local i = getValueFromDistribution(probabilities)
            producedGood = potentialGoods[i].name

            -- choose a production type, a good may be produced in multiple factories
            numProductions = tablelength(productionsByGood[producedGood])

            if numProductions == nil or numProductions == 0 then
                -- good is not produced, skip and take next
                -- print("product is invalid: " .. product .. "\n")
                probabilities[i] = nil
            end
        end

        productionIndex = math.random(1, numProductions)
    end

    if size == nil then
        local distanceFromCenter = length(vec2(Sector():getCoordinates()))
        local probabilities = {}

        probabilities[1] = 1.0

        if distanceFromCenter < 450 then
            probabilities[2] = 0.5
        end

        if distanceFromCenter < 400 then
            probabilities[3] = 0.35
        end

        if distanceFromCenter < 350 then
            probabilities[4] = 0.25
        end

        if distanceFromCenter < 300 then
            probabilities[5] = 0.15
        end

        size = getValueFromDistribution(probabilities)
    end

    local chosenProduction = productionsByGood[producedGood][productionIndex]
    if chosenProduction then
        Factory.setProduction(chosenProduction, size)
    end

    math.randomseed(appTimeMs())
end

function Factory.setBuySellFactor(factor)
    Factory.trader.buyPriceFactor = factor
    Factory.trader.sellPriceFactor = Factory.trader.buyPriceFactor * (math.random() * 0.2 + 1.0) -- this is coupled to the buy factor with variation 1.0 to 1.2
end

function Factory.setProduction(production_in, size)

    factorySize = size or 1
    Factory.maxNumProductions = 1 + factorySize
    production = production_in

    -- make lists of all items that will be sold/bought
    local bought = {}

    -- ingredients are bought
    for i, ingredient in pairs(production.ingredients) do
        local g = goods[ingredient.name]
        table.insert(bought, g:good())
    end

    -- results and garbage are sold
    local sold = {}

    for i, result in pairs(production.results) do
        local g = goods[result.name]
        table.insert(sold, g:good())
    end

    for i, garbage in pairs(production.garbages) do
        local g = goods[garbage.name]
        table.insert(sold, g:good())
    end

    local station = Entity()

    -- set title
    if station.title == "" then
        Factory.updateTitle()
        Factory.addPlanExtensions()
    end

    Factory.refreshProductionTime()

    Factory.initializeTrading(bought, sold)
end

function Factory.updateTitle()
    local station = Entity()
    station.title = "Factory"%_t

    local size = ""
    if factorySize == 1 then size = "S /* Size, as in S, M, L, XL etc.*/"%_t
    elseif factorySize == 2 then size = "M /* Size, as in S, M, L, XL etc.*/"%_t
    elseif factorySize == 3 then size = "L /* Size, as in S, M, L, XL etc.*/"%_t
    elseif factorySize == 4 then size = "XL /* Size, as in S, M, L, XL etc.*/"%_t
    elseif factorySize == 5 then size = "XXL /* Size, as in S, M, L, XL etc.*/"%_t
    end

    local name, args = formatFactoryName(production, size)

    local station = Entity()
    station:setTitle(name, args)
end

function Factory.addPlanExtensions()
    local station = Entity()
    local arms = factorySize

    if string.match(production.factory, "Solar") then
        addSolarPanels(station, arms)
    end

    if string.match(production.factory, "Mine") or string.match(production.factory, "Oil Rig") then
        addAsteroid(station)

        station:addScriptOnce("data/scripts/entity/merchants/consumer.lua", "Mine"%_t,
                      "Mining Robot",
                      "Medical Supplies",
                      "Antigrav Unit",
                      "Fusion Generator",
                      "Acid",
                      "Drill")

    end

    if string.match(production.factory, "Farm") or string.match(production.factory, "Ranch") then

        local x = 4 + math.floor(factorySize * 2.5)
        local y = 5 + factorySize * 4

        addFarmingCenters(station, arms, x, y)
    end

    if string.match(production.factory, "Factory")
        or string.match(production.factory, "Manufacturer")
        or string.match(production.factory, "Extractor") then

        local x = 4 + math.floor(factorySize * 1.5)
        local y = 5 + factorySize * 2

        addProductionCenters(station, arms, x, y)
    end

    if string.match(production.factory, "Collector") then
        addCollectors(station, arms)
    end
end

function Factory.sync(data)
    if onClient() then
        if not data then
            invokeServerFunction("sync")
        else
            maxDuration = data.maxDuration
            Factory.maxNumProductions = data.maxNumProductions
            factorySize = data.maxNumProductions - 1
            production = data.production

            InteractionText().text = Dialog.generateStationInteractionText(Entity(), random())

            Factory.onShowWindow()
        end
    else
        local data = {}
        data.maxDuration = maxDuration
        data.maxNumProductions = Factory.maxNumProductions
        data.factorySize = factorySize
        data.production = production

        invokeClientFunction(Player(callingPlayer), "sync", data)
    end
end

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
function Factory.initUI()

    tabbedWindow = TradingAPI.CreateTabbedWindow("Factory"%_t)

    -- create buy tab
    buyTab = tabbedWindow:createTab("Buy"%_t, "data/textures/icons/purse.png", "Buy from factory"%_t)
    Factory.buildBuyGui(buyTab)

    -- create sell tab
    sellTab = tabbedWindow:createTab("Sell"%_t, "data/textures/icons/coins.png", "Sell to factory"%_t)
    Factory.buildSellGui(sellTab)

    configTab = tabbedWindow:createTab("Configure"%_t, "data/textures/icons/cog.png", "Factory configuration"%_t)
    Factory.buildConfigUI(configTab)

    Factory.trader.guiInitialized = true

    Factory.requestGoods()
end

function Factory.buildConfigUI(tab)
    local hsplit = UIHorizontalSplitter(Rect(tab.size), 10, 5, 0.65)
    local vsplit = UIVerticalMultiSplitter(hsplit.top, 10, 0, 2)
    local lister = UIVerticalLister(vsplit:partition(0), 5, 0)

    marginLabel = tab:createLabel(Rect(), "Buy/Sell price margin %"%_t, 12)
    lister:placeElementTop(marginLabel)
    marginLabel.centered = true

    marginSlider = tab:createSlider(Rect(), -50, 50, 100, "", "onMarginSliderChanged")
    lister:placeElementTop(marginSlider)
    marginSlider:setValueNoCallback(0)
    marginSlider.unit = "%"
    marginSlider.tooltip = "Sets the price margin of goods bought and sold by this station. Low prices attract more buyers, high prices attract more sellers."%_t

    lister:nextRect(15)

    allowBuyCheckBox = tab:createCheckBox(Rect(), "Buy goods from others"%_t, "onAllowBuyChecked")
    lister:placeElementTop(allowBuyCheckBox)
    allowBuyCheckBox:setCheckedNoCallback(true)
    allowBuyCheckBox.tooltip = "If checked, the station will buy goods from traders from other factions than you."%_t

    allowSellCheckBox = tab:createCheckBox(Rect(), "Sell goods to others"%_t, "onAllowSellChecked")
    lister:placeElementTop(allowSellCheckBox)
    allowSellCheckBox:setCheckedNoCallback(true)
    allowSellCheckBox.tooltip = "If checked, the station will sell goods to traders from other factions than you."%_t

    lister:nextRect(10)

    activelyRequestCheckBox = tab:createCheckBox(Rect(), "Actively request goods"%_t, "onActivelyRequestChecked")
    lister:placeElementTop(activelyRequestCheckBox)
    activelyRequestCheckBox:setCheckedNoCallback(true)
    activelyRequestCheckBox.tooltip = "If checked, the station will request traders to deliver goods when it's empty."%_t

    activelySellCheckBox = tab:createCheckBox(Rect(), "Actively sell goods"%_t, "onActivelySellChecked")
    lister:placeElementTop(activelySellCheckBox)
    activelySellCheckBox:setCheckedNoCallback(true)
    activelySellCheckBox.tooltip = "If checked, the station will request traders that will buy its goods when it's full."%_t

    lister:nextRect(10)


    -- delivery UI
    local lister = UIVerticalLister(vsplit:partition(1), 8, 0)
    local label = tab:createLabel(Rect(), "Deliver goods to stations:"%_t, 12)
    lister:placeElementTop(label)
    label.centered = true

    lister:nextRect(5)

    local combo = tab:createValueComboBox(Rect(), "sendConfig")
    lister:placeElementTop(combo)
    table.insert(deliveredStationsCombos, combo)

    local combo = tab:createValueComboBox(Rect(), "sendConfig")
    lister:placeElementTop(combo)
    table.insert(deliveredStationsCombos, combo)

    local combo = tab:createValueComboBox(Rect(), "sendConfig")
    lister:placeElementTop(combo)
    table.insert(deliveredStationsCombos, combo)

    lister:nextRect(50)


    local label = tab:createLabel(Rect(), "Fetch goods from stations:"%_t, 12)
    lister:placeElementTop(label)
    label.centered = true

    lister:nextRect(5)

    local combo = tab:createValueComboBox(Rect(), "sendConfig")
    lister:placeElementTop(combo)
    table.insert(deliveringStationsCombos, combo)

    local combo = tab:createValueComboBox(Rect(), "sendConfig")
    lister:placeElementTop(combo)
    table.insert(deliveringStationsCombos, combo)

    local combo = tab:createValueComboBox(Rect(), "sendConfig")
    lister:placeElementTop(combo)
    table.insert(deliveringStationsCombos, combo)

    -- error labels
    local lister = UIVerticalLister(vsplit:partition(2), 15, 0)
    local label = tab:createLabel(Rect(), ""%_t, 6)
    lister:placeElementTop(label)
    label.centered = true
    lister:nextRect(0)

    local label = tab:createLabel(Rect(), "No more shuttles!", 14)
    lister:placeElementTop(label)
    table.insert(deliveredStationsErrorLabels, label)

    local label = tab:createLabel(Rect(), "No more shuttles!", 14)
    lister:placeElementTop(label)
    table.insert(deliveredStationsErrorLabels, label)

    local label = tab:createLabel(Rect(), "No more shuttles!", 14)
    lister:placeElementTop(label)
    table.insert(deliveredStationsErrorLabels, label)

    lister:nextRect(32)


    local label = tab:createLabel(Rect(), ""%_t, 12)
    lister:placeElementTop(label)
    label.centered = true

    lister:nextRect(5)

    local label = tab:createLabel(Rect(), "No more shuttles!", 14)
    lister:placeElementTop(label)
    table.insert(deliveringStationsErrorLabels, label)

    local label = tab:createLabel(Rect(), "No more shuttles!", 14)
    lister:placeElementTop(label)
    table.insert(deliveringStationsErrorLabels, label)

    local label = tab:createLabel(Rect(), "No more shuttles!", 14)
    lister:placeElementTop(label)
    table.insert(deliveringStationsErrorLabels, label)

    for _, labels in pairs({deliveringStationsErrorLabels, deliveredStationsErrorLabels}) do
        for _, label in pairs(labels) do
            label.caption = ""
            label.color = ColorRGB(1, 1, 0)
        end
    end


    -- upgrade UI
    local vsplit = UIVerticalMultiSplitter(hsplit.bottom, 10, 0, 2)
    local lister = UIVerticalLister(vsplit:partition(0), 15, 0)

    upgradePriceLabel = tab:createLabel(Rect(), "", 14)
    lister:placeElementTop(upgradePriceLabel)

    upgradeButton = tab:createButton(Rect(), "Upgrade"%_t, "onUpgradeFactoryButtonPressed")
    lister:placeElementTop(upgradeButton)

    -- error label for production problems
    productionErrorSign = UICollection()

    local hsplit = UIHorizontalSplitter(Rect(tab.size), 10, 0, 0.9)
    hsplit.bottomSize = 50
    local frame = tab:createFrame(hsplit.bottom)

    hsplit:setPadding(15, 15, 15, 15)

    local label = tab:createLabel(hsplit.bottom, "Station can't produce because ingredients are missing!", 14)
    label.color = ColorRGB(1, 1, 0)
    label.centered = true

    local vsplit = UIVerticalSplitter(hsplit.bottom, 0, 0, 0.5)
    vsplit:setLeftQuadratic()

    local icon = tab:createPicture(vsplit.left, "data/textures/icons/hazard-sign.png")
    icon.isIcon = true
    icon.color = ColorRGB(1, 1, 0)
    icon.lower = icon.lower - vec2(5, 5)
    icon.upper = icon.upper + vec2(5, 5)

    productionErrorSign:insert(label)
    productionErrorSign:insert(icon)
    productionErrorSign:insert(frame)
    productionErrorSign.label = label

    productionErrorSign:hide()
end

function Factory.sendConfig()
    local config = {}
    if onClient() then
        -- read new config from ui elements
        config.priceFactor = 1.0 + marginSlider.value / 100.0
        config.activelyRequest = activelyRequestCheckBox.checked
        config.activelySell = activelySellCheckBox.checked
        config.buyFromOthers = allowBuyCheckBox.checked
        config.sellToOthers = allowSellCheckBox.checked

        config.deliveringStations = {}
        config.deliveredStations = {}

        for _, combo in pairs(deliveredStationsCombos) do
            local id = combo.selectedValue

            if id then
                local trades = deliveredStations[id] or {}
                config.deliveredStations[id] = trades
            end
        end

        for _, combo in pairs(deliveringStationsCombos) do
            local id = combo.selectedValue

            if id then
                local trades = deliveringStations[id] or {}
                config.deliveringStations[id] = trades
            end
        end

        invokeServerFunction("setConfig", config)
    else
        -- read config from factory settings
        config.priceFactor = Factory.trader.buyPriceFactor

        config.buyFromOthers = Factory.trader.buyFromOthers
        config.sellToOthers = Factory.trader.sellToOthers
        config.activelyRequest = Factory.trader.activelyRequest
        config.activelySell = Factory.trader.activelySell
        config.deliveredStations = Factory.trader.deliveredStations
        config.deliveringStations = Factory.trader.deliveringStations

        invokeClientFunction(Player(callingPlayer), "setConfig", config)
    end
end

function Factory.setConfig(config)
    if onClient() then
        -- apply config to UI elements
        marginSlider:setValueNoCallback(round((config.priceFactor - 1.0) * 100.0))
        marginLabel.tooltip = "This station will buy and sell its goods for ${percentage}% of the normal price."%_t % {percentage = round(config.priceFactor * 100.0)}

        allowBuyCheckBox:setCheckedNoCallback(config.buyFromOthers)
        allowSellCheckBox:setCheckedNoCallback(config.sellToOthers)
        activelyRequestCheckBox:setCheckedNoCallback(config.activelyRequest)
        activelySellCheckBox:setCheckedNoCallback(config.activelySell)

        local i = 1
        for id, trades in pairs(config.deliveredStations) do
            deliveredStationsCombos[i]:setSelectedValueNoCallback(id)
            i = i + 1
        end

        for a = i, 3 do
            deliveredStationsCombos[a]:setSelectedIndexNoCallback(0)
        end

        local i = 1
        for id, trades in pairs(config.deliveringStations) do
            deliveringStationsCombos[i]:setSelectedValueNoCallback(id)
            i = i + 1
        end

        for a = i, 3 do
            deliveringStationsCombos[a]:setSelectedIndexNoCallback(0)
        end
    else
        -- apply config to factory settings
        local owner, station, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
        if not owner then return end

        Factory.trader.buyPriceFactor = config.priceFactor
        Factory.trader.sellPriceFactor = config.priceFactor + 0.2

        Factory.trader.buyFromOthers = config.buyFromOthers
        Factory.trader.sellToOthers = config.sellToOthers
        Factory.trader.activelyRequest = config.buyFromOthers and config.activelyRequest
        Factory.trader.activelySell = config.sellToOthers and config.activelySell
        Factory.trader.deliveredStations = config.deliveredStations or {}
        Factory.trader.deliveringStations = config.deliveringStations or {}

        Factory.sendConfig()
    end
end

-- this functions gets called when the indicator of the station is rendered on the client
function Factory.renderUIIndicator(px, py, size)

    x = px - size / 2
    y = py + size / 2

    local index = 0
    for i, progress in pairs(currentProductions) do
        index = index + 1

        -- outer rect
        dx = x
        dy = y + index * 5

        sx = size + 2
        sy = 4

        drawRect(Rect(dx, dy, sx + dx, sy + dy), ColorRGB(0, 0, 0))

        -- inner rect
        dx = dx + 1
        dy = dy + 1

        sx = sx - 2
        sy = sy - 2

        sx = sx * progress

        drawRect(Rect(dx, dy, sx + dx, sy + dy), ColorRGB(0.66, 0.66, 1.0))
    end

end

-- this function gets called every time the window is shown on the client, ie. when a player presses F and if interactionPossible() returned 1
function Factory.onShowWindow()

    local station = Entity()
    local player = Player()

    if buyTab then
        if #Factory.trader.soldGoods == 0 or player.craftIndex == station.index then
            tabbedWindow:deactivateTab(buyTab)
        else
            tabbedWindow:activateTab(buyTab)
        end
    end

    if sellTab then
        if #Factory.trader.boughtGoods == 0 or player.craftIndex == station.index then
            tabbedWindow:deactivateTab(sellTab)
        else
            tabbedWindow:activateTab(sellTab)
        end
    end

    if configTab then
        local faction = Faction()

        if player.index == faction.index or player.allianceIndex == faction.index then
            tabbedWindow:activateTab(configTab)
            Factory.refreshConfigUI()
            Factory.refreshConfigCombos()
            Factory.refreshConfigErrors()

            invokeServerFunction("sendConfig")
            invokeServerFunction("sendShuttleErrors")
        else
            tabbedWindow:deactivateTab(configTab)
        end
    end

    Factory.requestGoods()

end

function Factory.refreshConfigUI()
    if not production then return end

    if factorySize < 5 then

        local price = createMonetaryString(getFactoryUpgradeCost(production, factorySize + 1))
        upgradePriceLabel.caption = "Upgrade Price: ${price} Cr"%_t % {price = price}

        upgradeButton.visible = true
        upgradePriceLabel.visible = true

        upgradeButton.tooltip = "Upgrade to allow up to ${amount} parallel productions."%_t % {amount = factorySize + 2}
    else
        upgradePriceLabel.visible = false
        upgradeButton.visible = true
        upgradeButton.active = false
    end
end

function Factory.refreshConfigCombos()
    if not production then return end
    if not production.ingredients then return end
    if not production.results then return end
    if not production.garbages then return end

    local stations = {Sector():getEntitiesByType(EntityType.Station)}

    deliveredStations = {}
    deliveringStations = {}

    for _, station in pairs(stations) do
        for _, ingredient in pairs(production.ingredients) do
            local good = ingredient.name
            local script = TradingUtility.getEntitySellsGood(station, good)
            if script then
                local trades = deliveringStations[station.id.string] or {}
                table.insert(trades, {good = good, script = script})

                deliveringStations[station.id.string] = trades
            end
        end

        for _, result in pairs(production.results) do
            local good = result.name
            local script = TradingUtility.getEntityBuysGood(station, good)
            if script then
                local trades = deliveredStations[station.id.string] or {}
                table.insert(trades, {good = good, script = script})

                deliveredStations[station.id.string] = trades
            end
        end

        for _, garbage in pairs(production.garbages) do
            local good = garbage.name
            local script = TradingUtility.getEntityBuysGood(station, good)
            if script then
                local trades = deliveredStations[station.id.string] or {}
                table.insert(trades, {good = good, script = script})

                deliveredStations[station.id.string] = trades
            end
        end
    end

    for _, combo in pairs(deliveredStationsCombos) do
        combo:clear()
        combo:addEntry(nil, "- None -"%_t)

        for id, _ in pairs(deliveredStations) do
            local station = Entity(id)
            local name = station.translatedTitle .. " " .. station.name

            local faction = Faction(station.factionIndex)
            if faction then
                name = name .. "(" .. faction.translatedName .. ")"
            end

            combo:addEntry(id, name)
        end
    end

    for _, combo in pairs(deliveringStationsCombos) do
        combo:clear()
        combo:addEntry(nil, "- None -"%_t)

        for id, _ in pairs(deliveringStations) do
            local station = Entity(id)
            local name = station.translatedTitle .. " - " .. station.name

            local faction = Faction(station.factionIndex)
            if faction then
                name = name .. " - (" .. faction.translatedName .. ")"
            end

            combo:addEntry(id, name)
        end
    end

end

function Factory.refreshConfigErrors()
    if not Factory.trader.guiInitialized then return end

    for _, labels in pairs({deliveringStationsErrorLabels, deliveredStationsErrorLabels}) do
        for _, label in pairs(labels) do
            label.caption = ""
            label.color = ColorRGB(1, 1, 0)
        end
    end

    for index, error in pairs(deliveredStationsErrors) do
        if index and error then
            deliveredStationsErrorLabels[index].caption = GetLocalizedString(error)
        end
    end

    for index, error in pairs(deliveringStationsErrors) do
        if index and error then
            deliveringStationsErrorLabels[index].caption = GetLocalizedString(error)
        end
    end

    if not productionError or productionError == "" then
        productionErrorSign:hide()
    else
        productionErrorSign:show()
        productionErrorSign.label.caption = productionError or ""
    end
end


function Factory.onMarginSliderChanged() Factory.sendConfig() end
function Factory.onAllowBuyChecked() Factory.sendConfig() end
function Factory.onAllowSellChecked() Factory.sendConfig() end
function Factory.onActivelyRequestChecked() Factory.sendConfig() end
function Factory.onActivelySellChecked() Factory.sendConfig() end
function Factory.onDeliveringStationsChanged() Factory.sendConfig() end

function Factory.onUpgradeFactoryButtonPressed()
    if onClient() then
        invokeServerFunction("onUpgradeFactoryButtonPressed")
        return
    end

    local buyer, _, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources, AlliancePrivilege.ManageStations)
    if not buyer then return end

    if factorySize >= 5 then
        player:sendChatMessage("Server"%_t, ChatMessageType.Error, "This factory is already at its highest level."%_t)
        return
    end

    local price = getFactoryUpgradeCost(production, factorySize + 1)

    local canPay, msg, args = buyer:canPay(price)
    if not canPay then -- if there was an error, print it
        player:sendChatMessage(station.title, 1, msg, unpack(args))
        return
    end

    buyer:pay(price)

    local newSize = factorySize + 1
    factorySize = newSize
    Factory.maxNumProductions = factorySize + 1
    Factory.updateTitle()

    Factory.sync()
    invokeClientFunction(player, "refreshConfigUI")
end

-- this function gets called every time the window is closed on the client
--function onCloseWindow()
--
--end

function Factory.startProduction(timeStep)

    table.insert(currentProductions, timeStep / Factory.timeToProduce)

    if onServer() then
        broadcastInvokeClientFunction("startProduction", timeStep)
    end
end

local interval = random():getFloat(0.98, 1.02)
function Factory.getUpdateInterval()

    if onServer() and ReadOnlySector().numPlayers == 0 then
        -- only update every 5 seconds when no players are around
        -- this is also used to balance fighter delivery a little
        -- since otherwise delivery fighters would start every second,
        -- leading to goods being transferred every second,
        -- since no delivery shuttles actually start without players in the sector
        return interval + 4
    else
        return interval
    end
end

function Factory.updateParallelSelf(timeStep)
    local numProductions = 0
    for i, duration in pairs(currentProductions) do
        duration = duration + timeStep / Factory.timeToProduce
        -- print ("duration: " .. duration)

        if duration >= 1.0 then
            -- production finished
            currentProductions[i] = nil

            if onServer() then
                for i, result in pairs(production.results) do
                    Factory.increaseGoods(result.name, result.amount)
                end

                for i, garbage in pairs(production.garbages) do
                    Factory.increaseGoods(garbage.name, garbage.amount)
                end
            end
        else
            currentProductions[i] = duration

            numProductions = numProductions + 1
        end
    end

    if onServer() then
        Factory.updateProduction(timeStep)
    end
end

-- function Factory.updateParallelRead(timeStep)
    -- print ("parallel update, read")
-- end

function Factory.updateClient(timeStep)
    if EntityIcon().icon == "" then

        local title = Entity().title

        if string.match(title, "Mine") then
            EntityIcon().icon = "data/textures/icons/pixel/mine.png"
        elseif string.match(title, "Ranch") then
            EntityIcon().icon = "data/textures/icons/pixel/ranch.png"
        elseif string.match(title, "Farm") then
            EntityIcon().icon = "data/textures/icons/pixel/farm.png"
        else
            EntityIcon().icon = "data/textures/icons/pixel/factory.png"
        end
    end

    Factory.updateStepDone = true
end

function Factory.updateUI()
    if Factory.updateStepDone then
        Factory.updateStepDone = false
        Factory.requestGoods()
    end
end

function Factory.updateServer(timeStep)
    local profiler = Profiler("Factory.updateServer: " .. Entity().name)

    Factory.requestTraders(timeStep)

    Factory.refreshDeliveryShuttles()
    Factory.recallDeliveryShuttles()

    Factory.updateDeliveryShuttleStarts(timeStep)
    Factory.updateFetchingShuttleStarts(timeStep)

    Factory.updateOrganizeGoodsBulletins(timeStep)
    Factory.updateDeliveryBulletins(timeStep)

    Factory.sendShuttleErrors()
    Factory.sendProductionError()
end

function Factory.sendShuttleErrors()

    if not Owner().isPlayer then return end

    local messages = {}
    local send = false

    for i = 1, 3 do
        local error = deliveredStationsErrors[i]
        local newError = newDeliveredStationsErrors[i]

        if error ~= newError then
            send = true
        end
    end

    deliveredStationsErrors = newDeliveredStationsErrors
    newDeliveredStationsErrors = {}

    for i = 1, 3 do
        local error = deliveringStationsErrors[i]
        local newError = newDeliveringStationsErrors[i]

        if error ~= newError then
            send = true
        end
    end

    deliveringStationsErrors = newDeliveringStationsErrors
    newDeliveringStationsErrors = {}

    if send then
        local player = Player()
        local x, y = Sector():getCoordinates()
        local px, py = Player():getSectorCoordinates()

        if x == px and y == py then
            invokeClientFunction(player, "receiveShuttleErrors", deliveredStationsErrors, deliveringStationsErrors)
        end
    end

end

function Factory.receiveShuttleErrors(delivered, delivering)
    deliveredStationsErrors = delivered
    deliveringStationsErrors = delivering

    Factory.refreshConfigErrors()
end

function Factory.sendProductionError()

    if not Owner().isPlayer then return end

    local send = false

    if productionError ~= newProductionError then
        send = true
    end

    productionError = newProductionError

    if send and productionError then
        local player = Player()
        local x, y = Sector():getCoordinates()
        local px, py = player:getSectorCoordinates()

        if x == px and y == py then
            invokeClientFunction(Player(), "receiveProductionError", productionError)
        end
    end

end

function Factory.receiveProductionError(error)
    productionError = error or ""

    Factory.refreshConfigErrors()
end


function Factory.refreshDeliveryShuttles()

    if deliveryShuttles then
        if tablelength(deliveryShuttles) > 0 then return end
        if #Factory.trader.deliveredStations == 0 then return end
        if #Factory.trader.deliveringStations == 0 then return end
    else
        deliveryShuttles = {}
    end

    local id = Entity().id
    local fighters = {Sector():getEntitiesByType(EntityType.Fighter)}

    for _, entity in pairs(fighters) do
        local ai = FighterAI(entity.id)

        if ai.mothershipId == id and entity:hasComponent(ComponentType.CargoBay) then
            deliveryShuttles[entity.id] = entity
        end
    end
end

function Factory.recallDeliveryShuttles()

    for key, shuttle in pairs(deliveryShuttles) do
        if not valid(shuttle) then
            deliveryShuttles[key] = nil
            goto continue
        end

        local ai = FighterAI(shuttle.id)
        if ai.orders == FighterOrders.Attack or ai.orders == FighterOrders.Defend then
            ai:setOrders(FighterOrders.Return, Uuid())
            ai:clearFeedback()
        end

        if ai.reachedTarget then
            -- order them to come back
            ai:setOrders(FighterOrders.Return, Uuid())
            ai:clearFeedback()

            local otherId = shuttle:getValue("cargo_recipient")
            if otherId then
                -- make sure that the shuttle actually carries cargo
                local good, amount = shuttle:getCargo(0)
                if not good or not amount then goto continue end

                -- make sure the receiver exists
                local receiver = Entity(otherId)
                if not receiver then goto continue end

                receiver:addCargo(good, amount)
                shuttle:removeCargo(good, amount)
            else
                local otherId = shuttle:getValue("cargo_giver")
                if not otherId then
                    print ("no other id")
                    goto continue
                end

                -- make sure the giver exists
                local giver = Entity(otherId)
                if not giver then
                    print ("no other station")
                    goto continue
                end

                local script = shuttle:getValue("cargo_giver_script")
                if not script then
                    print ("no other script")
                    goto continue
                end

                local goodName = shuttle:getValue("cargo_requested")
                if not goodName then goto continue end

                local good = goods[goodName]:good()
                if not good then goto continue end

                local error1, error2 = giver:invokeFunction(script, "sellGoods", good, 1, shuttle.factionIndex)
                if error1 ~= 0 or error2 ~= 0 then
                    print ("error1: " .. error1 .. ", error2: " .. error2)
                    goto continue
                end

                shuttle:addCargo(good, 1)
            end
        end

        ::continue::
    end
end

function Factory.updateDeliveryShuttleStarts(timeStep)
    if tablelength(deliveryShuttles) >= 20 then return end

    local sector = Sector()
    local self = Entity()
    local controller = FighterController()

    local ids = {}
    for id, trades in pairs(Factory.trader.deliveredStations) do
        if #trades > 0 then
            table.insert(ids, id)
        end
    end

    shuffle(random(), ids)

    for index, id in pairs(ids) do
        local trades = Factory.trader.deliveredStations[id]
        local trade = randomEntry(random(), trades)

        local station = Entity(id)
        if not station then
            newDeliveredStationsErrors[index] = "Error with partner station!"%_T
            goto continue
        end

        -- make sure that a fighter of the type we want can actually start
        local errorCode = controller:getFighterTypeStartError(FighterType.CargoShuttle)
        if errorCode then
            newDeliveredStationsErrors[index] = Factory.getFighterStartErrorMessage(errorCode)
            goto continue
        end

        local amount = self:getCargoAmount(trade.good)
        if amount == 0 then
            newDeliveredStationsErrors[index] = "No more goods!"%_T
            goto continue
        end

        local good = Factory.getSoldGoodByName(trade.good)
        if not good then
            newDeliveredStationsErrors[index] = "Partner station doesn't buy this!"%_T
            goto continue
        end

        -- do the transaction, use 1 good
        local errorCode1, errorCode2 = station:invokeFunction(trade.script, "buyGoods", good, 1, self.factionIndex, true)
        if errorCode1 ~= 0 then
            newDeliveredStationsErrors[index] = "Error with partner station!"%_T
            goto continue
        end

        if errorCode2 ~= 0 then
            newDeliveredStationsErrors[index] = Factory.getBuyGoodsErrorMessage(errorCode2)
            goto continue
        end

        if Sector().numPlayers > 0 then
            -- start a shuttle
            local shuttle, errorCode = controller:startFighterOfType(FighterType.CargoShuttle)
            if not shuttle then
                newDeliveredStationsErrors[index] = Factory.getFighterStartErrorMessage(errorCode)
                print ("FATAL error starting fighter: " .. errorCode)
                goto continue
            end

            -- assign cargo
            local ai = FighterAI(shuttle.id)
            ai.ignoreMothershipOrders = true
            ai.clearFeedbackEachTick = false
            ai:setOrders(FighterOrders.FlyToLocation, station.id)

            shuttle:setValue("cargo_recipient", station.id.string)
            shuttle:setValue("cargo_recipient_script", trade.script)

            shuttle:addCargo(good, 1)
            deliveryShuttles[shuttle.id] = shuttle
        else
            station:addCargo(good, 1)
        end

        Factory.decreaseGoods(trade.good, 1)

        if true then return end -- lua grammar doesn't allow statements in a block after a 'return'
        ::continue::

    end

end

function Factory.updateFetchingShuttleStarts(timeStep)
    if tablelength(deliveryShuttles) >= 20 then return end

    local sector = Sector()
    local self = Entity()
    local controller = FighterController()

    local ids = {}
    for id, trades in pairs(Factory.trader.deliveringStations) do
        if #trades > 0 then
            table.insert(ids, id)
        end
    end

    shuffle(random(), ids)

    for index, id in pairs(ids) do
        local trades = Factory.trader.deliveringStations[id]
        local trade = randomEntry(random(), trades)

        local station = Entity(id)
        if not station then goto continue end

        -- make sure that a fighter of the type we want can actually start exists
        local errorCode = controller:getFighterTypeStartError(FighterType.CargoShuttle)
        if errorCode then
            newDeliveringStationsErrors[index] = Factory.getFighterStartErrorMessage(errorCode)
            goto continue
        end

        local errorCode, amount, maxAmount = station:invokeFunction(trade.script, "getStock", trade.good)
        if errorCode ~= 0 then
            newDeliveringStationsErrors[index] = "Error with partner station!"%_T
            print ("error requesting goods from other station: " .. errorCode .. " " .. station.title)
            goto continue
        end

        if amount == 0 then
            newDeliveringStationsErrors[index] = "No more goods on partner station!"%_T
            goto continue
        end

        local amount, maxAmount = Factory.getStock(trade.good)
        if amount >= maxAmount then
            newDeliveringStationsErrors[index] = "Station at full capacity!"%_T
            goto continue
        end

        local good = goods[trade.good]:good()
        if not good then return end

        if self.freeCargoSpace < good.size then
            newDeliveringStationsErrors[index] = "Station at full capacity!"%_T
            goto continue
        end

        if Sector().numPlayers > 0 then
            -- start a shuttle
            local shuttle, errorCode = controller:startFighterOfType(FighterType.CargoShuttle)
            if not shuttle then
                newDeliveringStationsErrors[index] = Factory.getFighterStartErrorMessage(errorCode)
                goto continue
            end

            -- assign cargo
            local ai = FighterAI(shuttle.id)
            ai.ignoreMothershipOrders = true
            ai.clearFeedbackEachTick = false
            ai:setOrders(FighterOrders.FlyToLocation, station.id)

            shuttle:setValue("cargo_requested", trade.good)
            shuttle:setValue("cargo_giver", station.id.string)
            shuttle:setValue("cargo_giver_script", trade.script)

            deliveryShuttles[shuttle.id] = shuttle
        else
            local error1, error2 = station:invokeFunction(trade.script, "sellGoods", good, 1, self.factionIndex)
            if error1 ~= 0 then
                newDeliveringStationsErrors[index] = "Error with partner station!"%_T
                goto continue
            end

            if error2 ~= 0 then
                newDeliveringStationsErrors[index] = Factory.getSellGoodsErrorMessage(error2)
                goto continue
            end

            self:addCargo(good, 1)
        end

        if true then return end -- lua grammar doesn't allow statements in a block after a 'return'
        ::continue::

    end

end

function Factory.onFighterLanded(entityId, squad, fighterId)
    if not deliveryShuttles then return end
    deliveryShuttles[fighterId] = nil
end

function Factory.onBlockPlanChanged(entityId, allBlocks)
    Factory.productionCapacity = Plan():getStats().productionCapacity * Factory.PlanCapacityFactor
    Factory.productionCapacity = math.max(Factory.MinimumCapacity, Factory.productionCapacity)

    Factory.refreshProductionTime()
end

function Factory.refreshProductionTime()
    if not production then return end

    local value = 0
    for _, result in pairs(production.results) do
        local good = goods[result.name]
        if good then
            value = value + good.price * result.amount * math.max(1, good.level)
        end
    end

    if production.garbages then
        for i, garbage in pairs(production.garbages) do
            local good = goods[garbage.name]
            if good then
                value = value + good.price * garbage.amount
            end
        end
    end

    Factory.timeToProduce = math.max(Factory.MinimumTimeToProduce, value / Factory.productionCapacity)
end

function Factory.requestProductionStats()
    invokeServerFunction("sendProductionStats")
end

function Factory.sendProductionStats()
    invokeClientFunction(Player(callingPlayer), "receiveProductionStats", Factory.timeToProduce)
end

function Factory.receiveProductionStats(timeToProduce)
    Factory.timeToProduce = timeToProduce
end

function Factory.requestTraders(timeStep)
    Factory.traderRequestCooldown = Factory.traderRequestCooldown - timeStep
    if Factory.traderRequestCooldown > 0 then
        -- print ("cooldown: " .. Factory.traderRequestCooldown)
        return
    end

    -- if the result isn't there yet, can't call for new goods or buyers
    if not production then
        -- print ("no productions")
        return
    end

    local self = Entity()
    if TradingUtility.hasTraders(self) then
        -- print ("has traders")
        return
    end

    local sector = Sector()
    local immediate = sector.numPlayers == 0

    -- call for buyers first
    -- this decreases the time until the factory generates profit
    if Factory.trader.activelySell then
        for _, result in pairs(production.results) do
            Factory.trySpawnBuyer(self, result, immediate)
        end

        for _, garbage in pairs(production.garbages) do
            Factory.trySpawnBuyer(self, garbage, immediate)
        end
    end

    -- then call for ingredients
    if Factory.trader.activelyRequest then
        for _, ingredient in pairs(production.ingredients) do
            Factory.trySpawnSeller(self, ingredient, immediate)
        end
    end
end

function Factory.trySpawnSeller(self, good, immediate)
    if Factory.traderRequestCooldown > 0 then return end

    -- we only have to check buy price factor since sell price factor is directly coupled to buy price factor
    -- high prices for goods make it more likely for sellers to show up since they earn more money
    local probability = lerp(Factory.trader.buyPriceFactor, 0.5, 1.5, 0.3, 1.0)
    if not random():test(probability) then
        Factory.traderRequestCooldown = 90
        return
    end

    local have = Factory.getNumGoods(good.name)
    if have < good.amount then
        local maximum = Factory.getMaxGoods(good.name)

        maximum = math.min(maximum, 500)

        local amount = maximum - have
        if immediate then amount = round(amount * 0.3) end

        TradingUtility.spawnSeller(self.id, getScriptPath(), good.name, amount, Factory, immediate)
        Factory.traderRequestCooldown = 90
    end
end

function Factory.trySpawnBuyer(self, good, immediate)
    if Factory.traderRequestCooldown > 0 then return end

    -- low prices for goods make it more likely for buyers to show up since they can save money here
    local probability = lerp(Factory.trader.buyPriceFactor, 0.5, 1.5, 1.0, 0.3)
    if not random():test(probability) then
        Factory.traderRequestCooldown = 90
        return
    end

    local newAmount = Factory.getNumGoods(good.name) + good.amount
    local maxGoods = Factory.getMaxGoods(good.name)

    local value = newAmount * goods[good.name].price

    -- print("newAmount: " .. newAmount .. ", maxGoods: " .. maxGoods .. ", value: " .. value)

    -- spawn a trader when stocks are almost full, or when the value of the produced stocks exceeds 100.000k
    if newAmount > maxGoods * 0.8 or (value > 100 * 1000 and random():test(0.3)) then
        TradingUtility.spawnBuyer(self.id, getScriptPath(), good.name, Factory, immediate)
        Factory.traderRequestCooldown = 90
    end
end

function Factory.updateProduction(timeStep)
    -- if the result isn't there yet, don't produce
    if not production then return end

    -- if not yet fully used, start producing
    local numProductions = tablelength(currentProductions)
    local canProduce = true

    if numProductions >= Factory.maxNumProductions then
        canProduce = false
        -- print("can't produce as there are no more slots free for production")
    end

    -- only start if there are actually enough ingredients for producing
    for i, ingredient in pairs(production.ingredients) do
        if ingredient.optional == 0 and Factory.getNumGoods(ingredient.name) < ingredient.amount then
            canProduce = false
            newProductionError = "Factory can't produce because ingredients are missing!"%_T
            -- print("can't produce due to missing ingredients: " .. ingredient.amount .. " " .. ingredient.name .. ", have: " .. Factory.getNumGoods(ingredient.name))
            break
        end
    end

    local station = Entity()
    for i, garbage in pairs(production.garbages) do
        local newAmount = Factory.getNumGoods(garbage.name) + garbage.amount
        local size = Factory.getGoodSize(garbage.name)

        if newAmount > Factory.getMaxStock(size) or station.freeCargoSpace < garbage.amount * size then
            canProduce = false
            newProductionError = "Factory can't produce because there is not enough cargo space for products!"%_T
            -- print("can't produce due to missing room for garbage")
            break
        end
    end

    for _, result in pairs(production.results) do
        local newAmount = Factory.getNumGoods(result.name) + result.amount
        local size = Factory.getGoodSize(result.name)

        if newAmount > Factory.getMaxStock(size) or station.freeCargoSpace < result.amount * size then
            canProduce = false
            newProductionError = "Factory can't produce because there is not enough cargo space for products!"%_T
            -- print("can't produce due to missing room for result")
            break
        end
    end

    if canProduce then
        for i, ingredient in pairs(production.ingredients) do
            Factory.decreaseGoods(ingredient.name, ingredient.amount)
        end

        newProductionError = ""
        -- print("start production")

        -- start production
        Factory.startProduction(timeStep)
    end

end

function Factory.getBuysFromOthers()
    return Factory.trader.buyFromOthers
end

function Factory.getSellsToOthers()
    return Factory.trader.sellToOthers
end

function Factory.getFighterStartErrorMessage(code)

    if code == FighterStartError.NoError then
        return "No error."%_T
    elseif code == FighterStartError.NoHangar then
        return "No hangar!"%_T
    elseif code == FighterStartError.SquadNotFound then
        return "Squad not found!"%_T
    elseif code == FighterStartError.SquadEmpty then
        return "Squad empty!"%_T
    elseif code == FighterStartError.NoStartPosition then
        return "No start position!"%_T
    elseif code == FighterStartError.MaximumFightersStarted then
        return "Maximum fighters started!"%_T
    elseif code == FighterStartError.MaximumFightersStarted then
        return "Fighter not found!"%_T
    elseif code == FighterStartError.NoPilots then
        return "Not enough pilots!"%_T
    elseif code == FighterStartError.NoFighterFound then
        return "No cargo shuttles!"%_T
    end

    return "Unknown error"%_T
end


---- this function gets called whenever the ui window gets rendered, AFTER the window was rendered (client only)
--function renderUI()
--
--end

return Factory
