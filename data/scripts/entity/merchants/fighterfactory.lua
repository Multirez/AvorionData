package.path = package.path .. ";data/scripts/lib/?.lua"

require ("stringutility")
require ("randomext")
require ("player")
require ("merchantutility")
local SellableFighter = require("sellablefighter")
local Dialog = require("dialogutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace FighterFactory
FighterFactory = {}

FighterFactory.tax = 0.2

local planSelection
local turretSelection
local planDisplayer
local remainingPointsLabel
local pointsLabels
local statsLabels
local buildButton
local window
local typeCombo

local lastRarity
local selectedType = FighterType.Fighter

local maxPoints = 9
local remainingPoints = 0
local sizePoints = 0
local durabilityPoints = 0
local turningSpeedPoints = 0
local velocityPoints = 0

local buttons = {}

local function CargoShuttleRarity()
    return Rarity(2)
end

local function getMostUsedMaterial(plan)
    local material = Material()

    local numBlocks = plan.numBlocks
    local materials = {}
    for i = 0, numBlocks - 1 do
        local block = plan:getNthBlock(i)
        local materialIndex = block.material.value
        local amount = materials[materialIndex] or 0
        amount = amount + 1
        materials[materialIndex] = amount
    end

    local highest = 0
    for index, amount in pairs(materials) do
        if amount > highest then
            material = Material(index)
            highest = amount
        end
    end

    return material
end

function FighterFactory.interactionPossible(playerIndex, option)
    return CheckFactionInteraction(playerIndex, 10000)
end

function FighterFactory.initialize()

    if onServer() then
        local station = Entity()

        if station.title == "" then
            station.title = "Fighter Factory"%_t
        end
    end

    if onClient() and EntityIcon().icon == "" then
        EntityIcon().icon = "data/textures/icons/pixel/fighter.png"
        InteractionText().text = Dialog.generateStationInteractionText(Entity(), random())
    end


end

function FighterFactory.initUI()

    local res = getResolution()
    local size = vec2(900, 500)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "Fighter Factory"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Build Fighters /*window title*/"%_t);

    local vsplit = UIVerticalMultiSplitter(Rect(size), 10, 10, 2)

    planSelection = window:createSelection(vsplit:partition(0), 4)
    turretSelection = window:createInventorySelection(vsplit:partition(2), 5)

    local hlsplit = UIHorizontalSplitter(vsplit:partition(1), 10, 0, 0.5)
    hlsplit.bottomSize = 40

    buildButton = window:createButton(hlsplit.bottom, "Create"%_t, "onCreatePressed")

    local hmsplit = UIHorizontalSplitter(hlsplit.top, 10, 0, 0.7)
    local hmsplit2 = UIHorizontalSplitter(hmsplit.top, 10, 0, 0.8)
    local hmsplit3 = UIHorizontalSplitter(hmsplit2.bottom, 10, 0, 0.5)

    planDisplayer = window:createPlanDisplayer(hmsplit2.top)
    planDisplayer.showStats = false
    planSelection.onSelectedFunction = "onPlanSelected"
    turretSelection.onSelectedFunction = "onTurretSelected"
    turretSelection.onDeselectedFunction = "disableUI"

    -- fighter type combo
    typeCombo = window:createValueComboBox(hmsplit3.top, "onFighterTypeSelected")
    typeCombo:addEntry(FighterType.Fighter, "Combat Fighter"%_t)
    typeCombo:addEntry(FighterType.CargoShuttle, "Cargo Shuttle"%_t)

    -- remaining points label
    window:createLabel(hmsplit3.bottom, "Remaining Points: "%_t, 14)
    remainingPointsLabel = window:createLabel(hmsplit3.bottom, "", 14)
    remainingPointsLabel:setRightAligned()

    -- Caption labels
    local labelLister = UIVerticalLister(hmsplit.bottom, 5, 0)

    local sizeLabel = window:createLabel(vec2(), "Size: "%_t, 14)
    local durabilityLabel = window:createLabel(vec2(), "Durability: "%_t, 14)
    local turningSpeedLabel = window:createLabel(vec2(), "Maneuverability: "%_t, 14)
    local maxVelocityLabel = window:createLabel(vec2(), "Speed: "%_t, 14)
    local priceLabel = window:createLabel(vec2(), "Price: "%_t, 14)

    sizeLabel.size = vec2(hmsplit.inner.width, 15)
    durabilityLabel.size = vec2(hmsplit.inner.width, 15)
    turningSpeedLabel.size = vec2(hmsplit.inner.width, 15)
    maxVelocityLabel.size = vec2(hmsplit.inner.width, 15)
    priceLabel.size = vec2(hmsplit.inner.width, 15)

    labelLister:placeElementCenter(sizeLabel)
    labelLister:placeElementCenter(durabilityLabel)
    labelLister:placeElementCenter(turningSpeedLabel)
    labelLister:placeElementCenter(maxVelocityLabel)

    labelLister:nextRect(20)
    labelLister:placeElementCenter(priceLabel)

    -- Value labels
    local labelLister = UIVerticalLister(hmsplit.bottom, 5, 0)
    labelLister.marginRight = 150

    local sizeLabel = window:createLabel(vec2(), "-", 14)
    local durabilityLabel = window:createLabel(vec2(), "-", 14)
    local turningSpeedLabel = window:createLabel(vec2(), "-", 14)
    local maxVelocityLabel = window:createLabel(vec2(), "-", 14)
    local priceLabel = window:createLabel(vec2(), "-", 14)

    sizeLabel.size = vec2(hmsplit.inner.width, 15)
    durabilityLabel.size = vec2(hmsplit.inner.width, 15)
    turningSpeedLabel.size = vec2(hmsplit.inner.width, 15)
    maxVelocityLabel.size = vec2(hmsplit.inner.width, 15)
    priceLabel.size = vec2(hmsplit.inner.width, 15)

    statsLabels = {}
    statsLabels[1] = sizeLabel
    statsLabels[2] = durabilityLabel
    statsLabels[3] = turningSpeedLabel
    statsLabels[4] = maxVelocityLabel
    statsLabels[5] = priceLabel

    sizeLabel:setTopRightAligned()
    durabilityLabel:setTopRightAligned()
    turningSpeedLabel:setTopRightAligned()
    maxVelocityLabel:setTopRightAligned()
    priceLabel:setTopRightAligned()

    labelLister:placeElementCenter(sizeLabel)
    labelLister:placeElementCenter(durabilityLabel)
    labelLister:placeElementCenter(turningSpeedLabel)
    labelLister:placeElementCenter(maxVelocityLabel)

    labelLister.marginRight = 0
    labelLister:nextRect(20)
    labelLister:placeElementCenter(priceLabel)

    -- buttons + point labels
    local labelLister = UIVerticalLister(hmsplit.bottom, 1, 0)

    local addFunctions = {}
    local subtractFunctions = {}
    pointsLabels = {}

    addFunctions[1] = "onSizeAdded"
    addFunctions[2] = "onDurabilityAdded"
    addFunctions[3] = "onTurningSpeedAdded"
    addFunctions[4] = "onVelocityAdded"

    subtractFunctions[1] = "onSizeRemoved"
    subtractFunctions[2] = "onDurabilityRemoved"
    subtractFunctions[3] = "onTurningSpeedRemoved"
    subtractFunctions[4] = "onVelocityRemoved"

    for i = 1, 4 do
        local vsplit = UIVerticalSplitter(labelLister:nextRect(19), 1, 0, 2); vsplit.rightSize = 60
        local vmsplit = UIVerticalMultiSplitter(vsplit.right, 1, 0, 2)

        local plus = window:createButton(vmsplit:partition(2), "+", addFunctions[i])
        local minus = window:createButton(vmsplit:partition(0), "-", subtractFunctions[i])
        plus.textSize = 15
        minus.textSize = 15

        table.insert(buttons, plus)
        table.insert(buttons, minus)

        local rect = vmsplit:partition(1)
        rect.lower = vec2(rect.lower.x - 20, rect.lower.y)

        local label = window:createLabel(rect, "-", 12)
        label:setTopRightAligned()
        label.fontSize = 12

        pointsLabels[i] = label
    end

    FighterFactory.refreshPointLabels()
    FighterFactory.disableUI()
end

function FighterFactory.fillPlans()
    for i = 1, 50 do
        turretSelection:addEmpty()
        planSelection:addEmpty()
    end

    planSelection:clear()
    for _, path in pairs({getWorkshopShips()}) do
        local item = PlanSelectionItem(path)
        item.isSubscribedPlan = true

        planSelection:add(item)
    end

    for _, path in pairs({getSavedShips()}) do
        planSelection:add(PlanSelectionItem(path))
    end

end

function FighterFactory.fillTurrets()
    local player = Player()
    local ship = player.craft
    local alliance = player.alliance

    if alliance and ship.factionIndex == player.allianceIndex then
        turretSelection:fill(alliance.index, InventoryItemType.Turret, InventoryItemType.TurretTemplate)
    else
        turretSelection:fill(player.index, InventoryItemType.Turret, InventoryItemType.TurretTemplate)
    end
end

function FighterFactory.onShowWindow()

    FighterFactory.fillPlans()
    FighterFactory.fillTurrets()
    --FighterFactory.refreshPointLabels()
    -- players might consecutively interact as self or alliance
    -- disable ui to get new calculated price and different turrets
    FighterFactory.disableUI()

end

function FighterFactory.refreshUI()
    FighterFactory.fillTurrets()
    FighterFactory.refreshPointLabels()
end

function FighterFactory.refreshPointLabels(plan, turret)

    plan = plan or FighterFactory.getPlan()
    turret = turret or FighterFactory.getTurret()
    if not plan then return end

    local material = Material()

    if selectedType == FighterType.Fighter then
        if not turret then return end

        material = turret.material
    else
        material = getMostUsedMaterial(plan)
    end

    local modifiedSize, modifiedDurability, modifiedTurningSpeed, modifiedVelocity = FighterFactory.addMaterialBonuses(material, sizePoints, durabilityPoints, turningSpeedPoints, velocityPoints)

    remainingPointsLabel.caption = tostring(remainingPoints)

    pointsLabels[1].caption = tostring(modifiedSize)
    pointsLabels[2].caption = tostring(modifiedDurability)
    pointsLabels[3].caption = tostring(modifiedTurningSpeed)
    pointsLabels[4].caption = tostring(modifiedVelocity)

    if modifiedSize ~= sizePoints then
        pointsLabels[1].color = ColorRGB(0, 1, 0)
        pointsLabels[1].tooltip = "This property gets increased points due to the turret's material."%_t
    else
        pointsLabels[1].color = ColorRGB(1, 1, 1)
        pointsLabels[1].tooltip = nil
    end

    if modifiedDurability ~= durabilityPoints then
        pointsLabels[2].color = ColorRGB(0, 1, 0)
        pointsLabels[2].tooltip = "This property gets increased points due to the turret's material."%_t
    else
        pointsLabels[2].color = ColorRGB(1, 1, 1)
        pointsLabels[2].tooltip = nil
    end

    if modifiedTurningSpeed ~= turningSpeedPoints then
        pointsLabels[3].color = ColorRGB(0, 1, 0)
        pointsLabels[3].tooltip = "This property gets increased points due to the turret's material."%_t
    else
        pointsLabels[3].color = ColorRGB(1, 1, 1)
        pointsLabels[3].tooltip = nil
    end

    if modifiedVelocity ~= velocityPoints then
        pointsLabels[4].color = ColorRGB(0, 1, 0)
        pointsLabels[4].tooltip = "This property gets increased points due to the turret's material."%_t
    else
        pointsLabels[4].color = ColorRGB(1, 1, 1)
        pointsLabels[4].tooltip = nil
    end


    local fighter = FighterFactory.makeFighter(selectedType, plan, turret, sizePoints, durabilityPoints, turningSpeedPoints, velocityPoints)

    statsLabels[1].caption = tostring(round(fighter.volume, 1))
    statsLabels[2].caption = tostring(round(fighter.durability, 1))
    statsLabels[3].caption = tostring(round(fighter.turningSpeed, 1))
    statsLabels[4].caption = tostring(round(fighter.maxVelocity * 10, 1))

    local boughtFighter = SellableFighter(fighter)

    local buyer = Player()
    local playerCraft = buyer.craft
    if playerCraft.factionIndex == buyer.allianceIndex then
        buyer = buyer.alliance
    end

    local price = FighterFactory.getPriceAndTax(boughtFighter, Faction(), buyer)

    statsLabels[5].caption = "${price} Cr"%_t % {price = createMonetaryString(price)}
end

function FighterFactory.disableUI()
    buildButton.active = false

    for _, button in pairs(buttons) do
        button.active = false
    end

    remainingPointsLabel.caption = ""

    for _, label in pairs(statsLabels) do
        label.caption = "-"
        label.color = ColorRGB(1, 1, 1)
    end
    for _, label in pairs(pointsLabels) do
        label.caption = "-"
        label.color = ColorRGB(1, 1, 1)
    end

end

function FighterFactory.enableUI()
    buildButton.active = true

    for _, button in pairs(buttons) do
        button.active = true
    end
end

function FighterFactory.renderUI()

    if not planDisplayer.mouseOver then return end

    local plan = FighterFactory.getPlan()
    local turret = FighterFactory.getTurret()

    if not plan then return end
    if selectedType == FighterType.Fighter and not turret then return end

    local fighter = FighterFactory.makeFighter(selectedType, plan, turret, sizePoints, durabilityPoints, turningSpeedPoints, velocityPoints)

    local renderer = TooltipRenderer(makeFighterTooltip(fighter))
    renderer:drawMouseTooltip(Mouse().position)
end

function FighterFactory.onSizeAdded()
    if sizePoints == 9 then return end
    if remainingPoints == 0 then return end

    sizePoints = sizePoints + 1
    remainingPoints = remainingPoints - 1

    FighterFactory.refreshPointLabels()
end

function FighterFactory.onDurabilityAdded()
    if durabilityPoints == maxPoints then return end
    if remainingPoints == 0 then return end

    durabilityPoints = durabilityPoints + 1
    remainingPoints = remainingPoints - 1

    FighterFactory.refreshPointLabels()
end

function FighterFactory.onTurningSpeedAdded()
    if turningSpeedPoints == maxPoints then return end
    if remainingPoints == 0 then return end

    turningSpeedPoints = turningSpeedPoints + 1
    remainingPoints = remainingPoints - 1

    FighterFactory.refreshPointLabels()
end

function FighterFactory.onVelocityAdded()
    if velocityPoints == maxPoints then return end
    if remainingPoints == 0 then return end

    velocityPoints = velocityPoints + 1
    remainingPoints = remainingPoints - 1

    FighterFactory.refreshPointLabels()
end


function FighterFactory.onSizeRemoved()
    if sizePoints == 0 then return end

    remainingPoints = remainingPoints + 1
    sizePoints = sizePoints - 1

    FighterFactory.refreshPointLabels()
end

function FighterFactory.onDurabilityRemoved()
    if durabilityPoints == 0 then return end

    remainingPoints = remainingPoints + 1
    durabilityPoints = durabilityPoints - 1

    FighterFactory.refreshPointLabels()
end

function FighterFactory.onTurningSpeedRemoved()
    if turningSpeedPoints == 0 then return end

    remainingPoints = remainingPoints + 1
    turningSpeedPoints = turningSpeedPoints - 1

    FighterFactory.refreshPointLabels()
end

function FighterFactory.onVelocityRemoved()
    if velocityPoints == 0 then return end

    remainingPoints = remainingPoints + 1
    velocityPoints = velocityPoints - 1

    FighterFactory.refreshPointLabels()
end

function FighterFactory.onPlanSelected()

    local plan = FighterFactory.getPlan()
    if not plan then
        FighterFactory.disableUI()
        return
    end

    if plan.numBlocks > 200 then
        displayChatMessage("Only plans with 200 blocks or less allowed."%_t, "Fighter Factory"%_t, 1)
        return
    end

    local diameter = 1.0
    local scale = diameter / plan:getBoundingSphere().radius

    plan:scale(vec3(scale, scale, scale))
    planDisplayer.plan = plan

    local turret = FighterFactory.getTurret()

    if selectedType == FighterType.Fighter and not turret then
        FighterFactory.disableUI()
        return
    end

    FighterFactory.onFighterPartsSelected(plan, turret)
end

function FighterFactory.onTurretSelected()
    local turret = FighterFactory.getTurret()
    if not turret then
        FighterFactory.disableUI()
        return
    end

    local plan = FighterFactory.getPlan()
    if not plan then
        FighterFactory.disableUI()
        return
    end

    FighterFactory.onFighterPartsSelected(plan, turret)
end

function FighterFactory.onFighterPartsSelected(plan, turret)

    FighterFactory.enableUI()

    local rarity = Rarity()

    if selectedType == FighterType.Fighter then
        if not turret then
            print ("Error: Parts selected callback for combat fighter without turret!")
            return
        end

        rarity = turret.rarity
    elseif selectedType == FighterType.CargoShuttle then
        rarity = CargoShuttleRarity()
    end

    if not lastRarity or lastRarity ~= rarity then
        lastRarity = rarity
    end

    maxPoints = FighterFactory.getMaxInvestablePoints(rarity)
    remainingPoints = FighterFactory.getMaxAvailablePoints(rarity)

    sizePoints = 0
    durabilityPoints = 0
    turningSpeedPoints = 0
    velocityPoints = 0

    FighterFactory.refreshPointLabels(plan, turret)
end

function FighterFactory.onFighterTypeSelected(comboBoxIndex, value, selectedIndex)
    selectedType = value

    turretSelection:unselect()
    planSelection:unselect()
    planDisplayer.plan = BlockPlan()

    FighterFactory.disableUI()

    if value == FighterType.Fighter then
        turretSelection.entriesHighlightable = true
        turretSelection.entriesSelectable = true
    elseif value == FighterType.CargoShuttle then
        turretSelection.entriesHighlightable = false
        turretSelection.entriesSelectable = false
    end

end

function FighterFactory.onCreatePressed()

    local inventoryItemIndex = nil

    if selectedType == FighterType.Fighter then
        local inventoryItem = turretSelection.selected
        if not inventoryItem then
            displayChatMessage("You have no turret selected."%_t, "Fighter Factory"%_t, 1)
            return
        end

        inventoryItemIndex = inventoryItem.index
    end

    local planItem = planSelection.selected
    if not planItem then
        displayChatMessage("You have no plan selected."%_t, "Fighter Factory"%_t, 1)
        return
    end

    local plan = planItem.plan
    if not plan then return end

    if plan.numBlocks > 200 then
        displayChatMessage("Only plans with 200 blocks or less allowed."%_t, "Fighter Factory"%_t, 1)
        return
    end

    invokeServerFunction("createFighter", selectedType, planItem.plan, inventoryItemIndex, sizePoints, durabilityPoints, turningSpeedPoints, velocityPoints)
end

function FighterFactory.getPlan()
    local planItem = planSelection.selected
    if not planItem then return end

    return planItem.plan
end

function FighterFactory.getTurret()
    local turretItem = turretSelection.selected
    if not turretItem then return end

    return turretItem.item
end

function FighterFactory.addMaterialBonuses(material, sizePoints, durabilityPoints, turningSpeedPoints, velocityPoints)

    if material.value == MaterialType.Iron then

        -- iron grants extra size points
        sizePoints = sizePoints + 4

    elseif material.value == MaterialType.Titanium then

        -- titanium grants additional maneuverability and durability
        durabilityPoints = durabilityPoints + 1
        turningSpeedPoints = turningSpeedPoints + 2
        velocityPoints = velocityPoints + 1

    elseif material.value == MaterialType.Naonite then

        -- naonite grants a little of everything
        durabilityPoints = durabilityPoints + 2
        turningSpeedPoints = turningSpeedPoints + 1
        velocityPoints = velocityPoints + 1

    elseif material.value == MaterialType.Trinium then

        -- trinium grants additional maneuverability
        turningSpeedPoints = turningSpeedPoints + 3
        velocityPoints = velocityPoints + 1

    elseif material.value == MaterialType.Xanion then

        -- xanion grants additional velocity
        durabilityPoints = durabilityPoints + 1
        velocityPoints = velocityPoints + 3

    elseif material.value == MaterialType.Ogonite then

        -- xanion grants additional durability
        durabilityPoints = durabilityPoints + 5

    elseif material.value == MaterialType.Avorion then

        -- avorion grants a little of everything
        sizePoints = sizePoints + 2
        durabilityPoints = durabilityPoints + 2
        turningSpeedPoints = turningSpeedPoints + 2
        velocityPoints = velocityPoints + 2
    end

    return sizePoints, durabilityPoints, turningSpeedPoints, velocityPoints
end

function FighterFactory.getStats(rarity, material, sizePoints, durabilityPoints, turningSpeedPoints, velocityPoints)

    sizePoints, durabilityPoints, turningSpeedPoints, velocityPoints = FighterFactory.addMaterialBonuses(material, sizePoints, durabilityPoints, turningSpeedPoints, velocityPoints)

    local size = round(lerp(sizePoints, 0, 9, 2.0, 1.0), 1)

    local durability = round(lerp(durabilityPoints, 0, 13, 5, 35, true), 1)
    local turningSpeed = round(lerp(turningSpeedPoints, 0, 13, 1.0, 3.5, true), 1)
    local maxVelocity = round(lerp(velocityPoints, 0, 13, 12.5, 45, true), 1)

    return size, durability, turningSpeed, maxVelocity
end

function FighterFactory.getMaxAvailablePoints(rarity)
    return 10 + rarity.value * 5
end

function FighterFactory.getMaxInvestablePoints(rarity)
    return 8 + rarity.value
end

function FighterFactory.makeFighter(type, plan, turret, sizePoints, durabilityPoints, turningSpeedPoints, velocityPoints)
    local material = Material()
    local rarity = Rarity()

    if turret then
        material = turret.material
        rarity = turret.rarity
    else
        material = getMostUsedMaterial(plan)
        rarity = CargoShuttleRarity()
    end

    local fighter = FighterTemplate()

    local diameter = 1.0
    local scale = diameter / plan:getBoundingSphere().radius

    plan:scale(vec3(scale, scale, scale))
    fighter.plan = plan

    local size, durability, turningSpeed, maxVelocity = FighterFactory.getStats(rarity, material, sizePoints, durabilityPoints, turningSpeedPoints, velocityPoints)

    fighter.crew = 1
    fighter.diameter = size
    fighter.durability = durability * material.strengthFactor
    fighter.turningSpeed = turningSpeed
    fighter.maxVelocity = maxVelocity
    fighter.type = type

    if turret then
        local fireRateFactor = 1.0
        if turret.coolingType == 0 and turret.heatPerShot > 0 then
            fireRateFactor = turret.shootingTime / (turret.shootingTime + turret.coolingTime)
        end

        for _, weapon in pairs({turret:getWeapons()}) do
            weapon.damage = weapon.damage * 0.3
            weapon.fireRate = weapon.fireRate * fireRateFactor
            fighter:addWeapon(weapon)
        end

        for desc, value in pairs(turret:getDescriptions()) do
            fighter:addDescription(desc, value)
        end
    end

    return fighter
end

function FighterFactory.createFighter(type, plan, turretIndex, sizePoints, durabilityPoints, turningSpeedPoints, velocityPoints)

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources)
    if not buyer then return end

    if plan.numBlocks > 200 then
        player:sendChatMessage("Fighter Factory"%_t, ChatMessageType.Error, "Only plans with 200 blocks or less allowed."%_t)
        return
    end

    local turret
    local rarity = Rarity()
    if type == FighterType.Fighter then
        turret = buyer:getInventory():find(turretIndex)
        if not turret then return end

        rarity = turret.rarity
    elseif type == FighterType.CargoShuttle then
        rarity = CargoShuttleRarity()
    end

    -- make sure the player doesn't cheat
    local availablePoints = FighterFactory.getMaxAvailablePoints(rarity)
    if sizePoints + durabilityPoints + turningSpeedPoints + velocityPoints > availablePoints then
        player:sendChatMessage("Fighter Factory"%_t, ChatMessageType.Error, "Invalid fighter stats."%_t)
        return
    end

    local maxInvestablePoints = FighterFactory.getMaxInvestablePoints(rarity)
    if sizePoints > maxInvestablePoints
        or durabilityPoints > maxInvestablePoints
        or turningSpeedPoints > maxInvestablePoints
        or velocityPoints > maxInvestablePoints  then

        player:sendChatMessage("Fighter Factory"%_t, ChatMessageType.Error, "Invalid fighter stats."%_t)
        return
    end

    local fighter = FighterFactory.makeFighter(type, plan, turret, sizePoints, durabilityPoints, turningSpeedPoints, velocityPoints)
    local boughtFighter = SellableFighter(fighter)

    local price, tax = FighterFactory.getPriceAndTax(boughtFighter, Faction(), buyer)

    local canPay, msg, args = buyer:canPay(price)
    if not canPay then
        player:sendChatMessage("Fighter Factory"%_t, ChatMessageType.Error, msg, unpack(args))
        return
    end

    local station = Entity()
    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to build fighters."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to build fighters."%_T
    if not CheckPlayerDocked(player, station, errors) then
        return
    end

    local error = boughtFighter:boughtByPlayer(ship)

    if error then
        player:sendChatMessage("Fighter Factory"%_t, ChatMessageType.Error, error)
        return
    end

    if turret then
        buyer:getInventory():remove(turretIndex)
    end

    receiveTransactionTax(station, tax)

    buyer:pay("Paid %1% credits to build a fighter."%_T, price)

    invokeClientFunction(player, "refreshUI")
end

function FighterFactory.getPriceAndTax(fighter, stationFaction, buyerFaction)
    local price = fighter:getPrice()
    local tax = price * FighterFactory.tax

    if stationFaction.index == buyerFaction.index then
        price = price - tax
        -- don't pay out for the second time
        tax = 0
    end

    return price, tax
end
