package.path = package.path .. ";data/scripts/lib/?.lua"
require ("galaxy")
require ("utility")
require ("faction")
require ("stationextensions")
require ("randomext")
require ("stringutility")
require ("merchantutility")
local Dialog = require("dialogutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RepairDock
RepairDock = {}
RepairDock.tax = 0.2

local window = 0
local planDisplayer = 0
local repairButton = 0

local repairUIVisible = false

local planShowCounter = 0

local uiMoneyCost
local uiResourceCost

local reconstructionPriceLabel
local reconstructionButton

-- if this function returns false, the script will not be listed in the interaction window on the client,
-- even though its UI may be registered
function RepairDock.interactionPossible(playerIndex, option)
    if option == 0 then
        if Player(playerIndex).craft.type == EntityType.Drone then
            return false, "We don't do drones."%_t
        end

        return CheckFactionInteraction(playerIndex, -25000)
    end

    if option == 1 then
        local msg = "We can only offer these services to people that we trust completely.\n\nCome back when your relations to our faction are better."%_t
        return CheckFactionInteraction(playerIndex, 75000, msg)
    end
end

-- this function gets called on creation of the entity the script is attached to, on client and server
function RepairDock.initialize()
    local station = Entity()

    if station.title == "" then
        station.title = "Repair Dock /* Station Title*/"%_t

        if onServer() then
            local x, y = Sector():getCoordinates()
            local seed = Server().seed

            math.randomseed(Sector().seed + Sector().numEntities)
            addConstructionScaffold(station)
            math.randomseed(appTimeMs())
        end
    end

    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/repair.png"
        InteractionText(station.index).text = Dialog.generateStationInteractionText(station, random())
    end
end

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
function RepairDock.initUI()

    local res = getResolution()
    local size = vec2(510, 560)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));
    menu:registerWindow(window, "Repair Dock /* Station Title*/"%_t);

    window.caption = "Repair Dock /* Station Title*/"%_t
    window.showCloseButton = 1
    window.moveable = 1

--    window:createFrame(Rect(10, 10, 490 + 10, 490 + 10));

    -- create the viewer
    planDisplayer = window:createPlanDisplayer(Rect(0, 0, 500, 500));
    planDisplayer.showStats = 0

    -- create the repair button
    repairButton = window:createButton(Rect(10, 510, 490 + 10, 40 + 510), "Repair /* Action */"%_t, "onRepairButtonPressed")


    -- respawning
    local size = vec2(510, 150)

    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));
    menu:registerWindow(window, "Use as Reconstruction Site /* Station Title*/"%_t);

    window.caption = "Reconstruction Site/* Station Title*/"%_t
    window.showCloseButton = 1
    window.moveable = 1

    --    window:createFrame(Rect(10, 10, 490 + 10, 490 + 10));

    -- create the repair button
    local splitter = UIHorizontalSplitter(Rect(window.size), 10, 10, 0.5)
    splitter.bottomSize = 50

    setReconstructionSiteButton = window:createButton(splitter.bottom, "Use as Reconstruction Site /* Action */"%_t, "onUseReconstructionSiteButtonPressed")

    local lister = UIVerticalLister(splitter.top, 10, 0)
    local rect = lister:nextRect(15)

    reconstructionPriceLabel = window:createLabel(rect.topLeft, "Price: "%_t, 12)

    local rect = lister:nextRect(30)
    local label = window:createLabel(rect.topLeft, "If you choose this station as your reconstruction site, then when you die, your drone will be reconstructed at this station and you will be placed in this sector."%_t, 12)
    label.fontSize = 12

end

-- this function gets called every time the window is shown on the client, ie. when a player presses F and if interactionPossible() returned 1
function RepairDock.onShowWindow(option)
    if option == 0 then
        local buyer = Player()
        local ship = buyer.craft--Entity(player.craftIndex)
        if ship.factionIndex == buyer.allianceIndex then
            buyer = buyer.alliance
        end

        -- get the plan of the player (or alliance)'s ship template
        local intact = buyer:getShipPlan(ship.name)

        -- get the plan of the player's ship
        local broken = ship:getPlan()

        -- set to display
        planDisplayer:setPlans(broken, intact)

        uiMoneyCost = RepairDock.getRepairMoneyCostAndTax(buyer, intact, broken, ship.durability / ship.maxDurability)
        uiResourceCost = RepairDock.getRepairResourcesCost(buyer, intact, broken, ship.durability / ship.maxDurability)

        local damaged = false

        if uiMoneyCost > 0 then
            damaged = true
        end

        for _, cost in pairs(uiResourceCost) do
            if cost > 0 then
                damaged = true
            end
        end

        if damaged then
            repairButton.active = true
            repairButton.tooltip = "Repair ship"%_t
        else
            repairButton.active = false
            repairButton.tooltip = "Your ship is not damaged."%_t
        end

        repairUIVisible = true
    end

    if option == 1 then
        reconstructionPriceLabel.caption = "Price: $${money}"%_t % {money = createMonetaryString(RepairDock.getReconstructionSiteChangePrice())}

        local x, y = Player():getRespawnSectorCoordinates()
        local sx, sy = Sector():getCoordinates()

        if x == sx and y == sy then
            setReconstructionSiteButton.active = false
            setReconstructionSiteButton.tooltip = "This sector is already your reconstruction sector."
        else
            setReconstructionSiteButton.active = true
            setReconstructionSiteButton.tooltip = nil
        end
    end
end

-- this function gets called every time the window is closed on the client
function RepairDock.onCloseWindow()
    repairUIVisible = false
end

-- this function gets called whenever the ui window gets rendered, AFTER the window was rendered (client only)
function RepairDock.renderUI()
    if repairUIVisible then
        renderPrices(window.lower + 15, "Repair Costs:"%_t, uiMoneyCost, uiResourceCost)
    end
end

function RepairDock.onRepairButtonPressed()
    invokeServerFunction("repairCraft")
end

function RepairDock.onUseReconstructionSiteButtonPressed()
    invokeServerFunction("setAsReconstructionSite")
end

function RepairDock.transactionComplete()
    ScriptUI():stopInteraction()
end

function RepairDock.repairCraft()

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not buyer then return end

    local station = Entity()
    local seller = Faction()

    local dist = station:getNearestDistance(ship)
    if dist > 100 then
        player:sendChatMessage(station.title, 1, "You can't be more than 1km away to repair your ship."%_t)
        return
    end

    -- this function is executed on the server
    local perfectPlan = buyer:getShipPlan(ship.name)
    local damagedPlan = ship:getPlan()

    local requiredMoney, tax = RepairDock.getRepairMoneyCostAndTax(buyer, perfectPlan, damagedPlan, ship.durability / ship.maxDurability)
    local requiredResources = RepairDock.getRepairResourcesCost(buyer, perfectPlan, damagedPlan, ship.durability / ship.maxDurability)

    local canPay, msg, args = buyer:canPay(requiredMoney, unpack(requiredResources))

    if not canPay then
        player:sendChatMessage(station.title, 1, msg, unpack(args))
        return
    end

    receiveTransactionTax(station, tax)

    buyer:pay(requiredMoney, unpack(requiredResources))

    perfectPlan:resetDurability()
    ship:setMovePlan(perfectPlan)
    ship.durability = ship.maxDurability

    -- relations of the player to the faction owning the repair dock get better
    local relationsChange = requiredMoney / 40

    for i = 1, NumMaterials() do
        relationsChange = relationsChange + requiredResources[i] / 4
    end

    Galaxy():changeFactionRelations(buyer, Faction(), relationsChange)

    invokeClientFunction(player, "onShowWindow", 0)
    invokeClientFunction(player, "transactionComplete")

end

function RepairDock.setAsReconstructionSite()
    local player = Player(callingPlayer)

    local x, y = Sector():getCoordinates()
    local rx, ry = player:getRespawnSectorCoordinates()

    if x == rx and y == ry then
        player:sendChatMessage("Server", 1, "This sector is already your reconstruction sector."%_t)
        return
    end

    local requiredMoney = RepairDock.getReconstructionSiteChangePrice()

    local ok, msg, args = player:canPay(requiredMoney)
    if not ok then
        player:sendChatMessage("Server", 1, msg, unpack(args))
        return
    end

    player:pay("Paid %1% credits to set a new reconstruction site."%_T, requiredMoney)
    player:setRespawnSectorCoordinates(x, y)

    invokeClientFunction(player, "onShowWindow", 1)
end

function RepairDock.getRepairResourcesCost(orderingFaction, perfectPlan, damagedPlan, durabilityPercentage)

    -- value of blockplan template
    local templateValue = {perfectPlan:getResourceValue()}
    -- value of player's craft blockplan
    local craftValue = {damagedPlan:getResourceValue()}
    local diff = {}

    -- calculate difference
    for i = 1, NumMaterials() do
        local value = templateValue[i] - craftValue[i]
        value = value + templateValue[i] * (1.0 - durabilityPercentage)
        value = value / 2

        local fee = RepairDock.getRepairFactor()

        table.insert(diff, i, value * fee)
    end

    return diff

end

function RepairDock.getRepairMoneyCostAndTax(orderingFaction, perfectPlan, damagedPlan, durabilityPercentage)

    local value = perfectPlan:getMoneyValue() - damagedPlan:getMoneyValue();
    value = value + perfectPlan:getMoneyValue() * (1.0 - durabilityPercentage)
    value = value / 2

    local fee = RepairDock.getRepairFactor() + GetFee(Faction(), orderingFaction)
    local price = value * fee
    local tax = round(price * RepairDock.tax)

    if Faction().index == orderingFaction.index then
        price = price - tax
        -- don't pay out for the second time
        tax = 0
    end

    return price, tax
end

function RepairDock.getReconstructionSiteChangePrice()
    local x, y = Sector():getCoordinates()

    local d = length(vec2(x, y))

    local factor = 1.0 + (1.0 - math.min(1, d / 450)) * 250

    local price = factor * 100000

    -- round to 1000's
    price = round(price / 1000) * 1000

    return price
end

function RepairDock.getRepairFactor()
    return 0.75 -- Completely repairing a ship would cost 0.75x the ship's value
end
