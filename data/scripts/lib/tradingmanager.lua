
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("galaxy")
require ("utility")
require ("goods")
require ("stringutility")
require ("player")
require ("faction")
require ("merchantutility")

local TradingManager = {}
TradingManager.__index = TradingManager

local function new()
    local instance = {}

    instance.buyPriceFactor = 1
    instance.sellPriceFactor = 1
    instance.tax = 0.0 -- tax is the amount of money the owner of the entity gets from transactions
    instance.factionPaymentFactor = 1.0 -- the amount of money the owner of the entity pays or receives directly through transactions

    instance.boughtGoods = {}
    instance.soldGoods = {}

    instance.numSold = 0
    instance.numBought = 0

    instance.buyFromOthers = true
    instance.sellToOthers = true

    instance.activelyRequest = false
    instance.activelySell = false

    instance.deliveredStations = {}
    instance.deliveringStations = {}

    instance.policies =
    {
        sellsIllegal = false,
        buysIllegal = false,

        sellsStolen = false,
        buysStolen = false,

        sellsSuspicious = false,
        buysSuspicious = false,
    }

    -- UI
    instance.boughtLines = {}
    instance.soldLines = {}

    instance.guiInitialized = false
    instance.useTimeCounter = 0 -- time counter for using up bought products
    instance.useUpGoodsEnabled = true

    return setmetatable(instance, TradingManager)
end

function TradingManager:getBuysFromOthers()
    return self.buyFromOthers
end

function TradingManager:getSellsToOthers()
    return self.sellToOthers
end

function TradingManager:setBuysFromOthers(value)
    self.buyFromOthers = value
end

function TradingManager:setSellsToOthers(value)
    self.sellToOthers = value
end

-- help functions
function TradingManager:isSoldBySelf(good)
    if good.illegal and not self.policies.sellsIllegal then
        local msg = "This station doesn't sell illegal goods."%_t
        return false, msg
    end

    if good.stolen and not self.policies.sellsStolen then
        local msg = "This station doesn't sell stolen goods."%_t
        return false, msg
    end

    if good.suspicious and not self.policies.sellsSuspicious then
        local msg = "This station doesn't sell suspicious goods."%_t
        return false, msg
    end

    return true
end

function TradingManager:isBoughtBySelf(good)
    if good.illegal and not self.policies.buysIllegal then
        local msg = "This station doesn't buy illegal goods."%_t
        return false, msg
    end

    if good.stolen and not self.policies.buysStolen then
        local msg = "This station doesn't buy stolen goods."%_t
        return false, msg
    end

    if good.suspicious and not self.policies.buysSuspicious then
        local msg = "This station doesn't buy suspicious goods."%_t
        return false, msg
    end

    return true
end

function TradingManager:generateGoods(min, max)
    min = min or 10
    max = max or 15

    local numGoods = math.random(min, max)

    local bought = {}
    local sold = {}
    local existingGoods = {}

    local maxNumGoods = tablelength(goodsArray)

    for i = 1, numGoods do
        local index = math.random(1, maxNumGoods)
        local g = goodsArray[index]
        local good = g:good()

        -- don't trade potentially illegal goods
        if self:isBoughtBySelf(good) then

            if existingGoods[good.name] == nil then

                good.size = round(good.size, 2)
                good.price = round(good.price)
                table.insert(bought, good)
                existingGoods[good.name] = 1
            end

        end
    end

    for i = 1, numGoods do
        local index = math.random(1, maxNumGoods)
        local g = goodsArray[index]
        local good = g:good()

        -- don't trade potentially illegal goods
        if self:isSoldBySelf(good.name) then

            if existingGoods[good.name] == nil then
                good.size = round(good.size, 2)
                good.price = round(good.price)

                table.insert(sold, good)
                existingGoods[good.name] = 1
            end
        end
    end

    return bought, sold
end

function TradingManager:restoreTradingGoods(data)
    self.buyPriceFactor = data.buyPriceFactor
    self.sellPriceFactor = data.sellPriceFactor
    self.policies = data.policies

    self.boughtGoods = {}
    for _, g in pairs(data.boughtGoods) do
        table.insert(self.boughtGoods, tableToGood(g))
    end

    self.soldGoods = {}
    for _, g in pairs(data.soldGoods) do
        table.insert(self.soldGoods, tableToGood(g))
    end

    self.numBought = #self.boughtGoods
    self.numSold = #self.soldGoods

    if data.buyFromOthers == nil then
        self.buyFromOthers = true
    else
        self.buyFromOthers = data.buyFromOthers
    end

    if data.sellToOthers == nil then
        self.sellToOthers = true
    else
        self.sellToOthers = data.sellToOthers
    end

    self.activelyRequest = data.activelyRequest or false
    self.activelySell = data.activelySell or false

    self.deliveredStations = data.deliveredStations or {}
    self.deliveringStations = data.deliveringStations or {}
end

function TradingManager:secureTradingGoods()
    local data = {}
    data.buyPriceFactor = self.buyPriceFactor
    data.sellPriceFactor = self.sellPriceFactor
    data.policies = self.policies

    data.buyFromOthers = self.buyFromOthers
    data.sellToOthers = self.sellToOthers
    data.activelyRequest = self.activelyRequest
    data.activelySell = self.activelySell

    data.deliveredStations = self.deliveredStations
    data.deliveringStations = self.deliveringStations


    data.boughtGoods = {}
    for _, g in pairs(self.boughtGoods) do
        table.insert(data.boughtGoods, goodToTable(g))
    end

    data.soldGoods = {}
    for _, g in pairs(self.soldGoods) do
        table.insert(data.soldGoods, goodToTable(g))
    end

    return data
end

function TradingManager:initializeTrading(boughtGoodsIn, soldGoodsIn, policiesIn)

    local entity = Entity()
    entity:waitUntilAsyncWorkFinished()

    self.policies = policiesIn or self.policies

    -- generate goods only once, this adds physical goods to the entity
    local generated = entity:getValue("goods_generated")
    if not generated or generated ~= 1 then
        entity:setValue("goods_generated", 1)
        generated = false
    else
        generated = true
    end

    boughtGoodsIn = boughtGoodsIn or {}
    soldGoodsIn = soldGoodsIn or {}

    self.numBought = #boughtGoodsIn
    self.numSold = #soldGoodsIn

    self.boughtGoods = {}

    for i, v in ipairs(boughtGoodsIn) do
        if not generated then
            local maxStock = self:getMaxStock(v.size)
            if maxStock > 0 then

                -- generate a random amount of things
                local amount
                if math.random() < 0.65 then -- what they buy is most likely not available
                    amount = 0
                else
                    amount = math.random(1, maxStock)

                    -- limit to a max value
                    local maxValue = 300 * 1000 * Balancing_GetSectorRichnessFactor(Sector():getCoordinates())
                    amount = math.min(maxStock, math.floor(maxValue / v.price))

                    -- but have at least 7 - 10
                    amount = math.max(amount, math.random(7, 10))

                    -- ... if max stock allows it
                    amount = math.min(amount, maxStock)
                end

                entity:addCargo(v, amount)
            end
        end

        table.insert(self.boughtGoods, v)
    end

    self.soldGoods = {}

    for i, v in ipairs(soldGoodsIn) do
        if not generated then
            local maxStock = self:getMaxStock(v.size)
            if maxStock > 0 then

                -- generate a random amount of things
                local amount = 0
                if math.random() < 0.35 then -- what they sell is most likely available
                    amount = 0
                else
                    amount = math.random(1, maxStock)

                    -- limit to 500k value at max
                    local maxValue = 500 * 1000
                    amount = math.min(maxStock, math.floor(maxValue / v.price))

                    -- but have at least a few
                    amount = math.max(amount, math.random(2, 5))

                    -- ... if max stock allows it
                    amount = math.min(amount, maxStock)
                end

                entity:addCargo(v, amount)
            end
        end

        table.insert(self.soldGoods, v)
    end

    self.numBought = #self.boughtGoods
    self.numSold = #self.soldGoods

end

function TradingManager:requestGoods()
    self.boughtGoods = {}
    self.soldGoods = {}

    self.numBought = 0
    self.numSold = 0

    invokeServerFunction("sendGoods", Player().index)
end

function TradingManager:sendGoods(playerIndex)

    local player = Player(playerIndex)

    invokeClientFunction(player, "receiveGoods", self.buyPriceFactor, self.sellPriceFactor, self.boughtGoods, self.soldGoods, self.policies)
end

function TradingManager:receiveGoods(buyFactor, sellFactor, boughtGoods_in, soldGoods_in, policies_in)

    self.buyPriceFactor = buyFactor
    self.sellPriceFactor = sellFactor

    self.policies = policies_in

    self.boughtGoods = boughtGoods_in
    self.soldGoods = soldGoods_in

    self.numBought = #self.boughtGoods
    self.numSold = #self.soldGoods

    local player = Player()
    local playerCraft = player.craft
    if playerCraft.factionIndex == player.allianceIndex then
        player = player.alliance
    end

    for i, good in ipairs(self.boughtGoods) do
        self:updateBoughtGoodGui(i, good, self:getBuyPrice(good.name, player.index))
    end

    for i, good in ipairs(self.soldGoods) do
        self:updateSoldGoodGui(i, good, self:getSellPrice(good.name, player.index))
    end

end

function TradingManager:updateBoughtGoodGui(index, good, price)

    if not self.guiInitialized then return end

    local maxAmount = self:getMaxStock(good.size)
    local amount = self:getNumGoods(good.name)

    local line = self.boughtLines[index]

    line.name.caption = good.displayName
    line.stock.caption = amount .. "/" .. maxAmount
    line.price.caption = createMonetaryString(price)
    line.size.caption = round(good.size, 2)
    line.icon.picture = good.icon

    local ownCargo = 0
    local ship = Entity(Player().craftIndex)
    if ship then
        ownCargo = ship:getCargoAmount(good) or 0
    end
    if ownCargo == 0 then ownCargo = "-" end
    line.you.caption = tostring(ownCargo)

    line:show()
end

function TradingManager:updateSoldGoodGui(index, good, price)

    if not self.guiInitialized then return end

    local maxAmount = self:getMaxStock(good.size)
    local amount = self:getNumGoods(good.name)

    local line = self.soldLines[index]

    line.icon.picture = good.icon
    line.name.caption = good.displayName
    line.stock.caption = amount .. "/" .. maxAmount
    line.price.caption = createMonetaryString(price)
    line.size.caption = round(good.size, 2)

    for i, good in pairs(self.soldGoods) do
        local line = self.soldLines[i]

        local ownCargo = 0
        local ship = Entity(Player().craftIndex)
        if ship then
            ownCargo = math.floor((ship.freeCargoSpace or 0) / good.size)
        end

        if ownCargo == 0 then ownCargo = "-" end
        line.you.caption = tostring(ownCargo)
    end

    line:show()

end

function TradingManager:updateBoughtGoodAmount(index)

    local good = self.boughtGoods[index];

    if good ~= nil then -- it's possible that the production may start before the initialization of the client version of the factory
        local player = Player()
        local playerCraft = player.craft
        if playerCraft.factionIndex == player.allianceIndex then
            player = player.alliance
        end

        self:updateBoughtGoodGui(index, good, self:getBuyPrice(good.name, player.index))
    end

end

function TradingManager:updateSoldGoodAmount(index)

    local good = self.soldGoods[index];

    if good ~= nil then -- it's possible that the production may start before the initialization of the client version of the factory
        local player = Player()
        local playerCraft = player.craft
        if playerCraft.factionIndex == player.allianceIndex then
            player = player.alliance
        end

        self:updateSoldGoodGui(index, good, self:getSellPrice(good.name, player.index))
    end
end

function TradingManager:buildBuyGui(window)
    self:buildGui(window, 1)
end

function TradingManager:buildSellGui(window)
    self:buildGui(window, 0)
end

function TradingManager:buildGui(window, guiType)

    local buttonCaption = ""
    local buttonCallback = ""
    local textCallback = ""

    if guiType == 1 then
        buttonCaption = "Buy"%_t
        buttonCallback = "onBuyButtonPressed"
        textCallback = "onBuyTextEntered"
    else
        buttonCaption = "Sell"%_t
        buttonCallback = "onSellButtonPressed"
        textCallback = "onSellTextEntered"
    end

    local size = window.size

--    window:createFrame(Rect(size))

    local pictureX = 270
    local nameX = 10
    local stockX = 310
    local volX = 460
    local priceX = 530
    local youX = 630
    local textBoxX = 720
    local buttonX = 790

    local buttonSize = 70

    -- header
    window:createLabel(vec2(nameX, 0), "Name"%_t, 15)
    window:createLabel(vec2(stockX, 0), "Stock"%_t, 15)
    window:createLabel(vec2(priceX, 0), "Cr"%_t, 15)
    window:createLabel(vec2(volX, 0), "Vol"%_t, 15)

    if guiType == 1 then
        window:createLabel(vec2(youX, 0), "Max"%_t, 15)
    else
        window:createLabel(vec2(youX, 0), "You"%_t, 15)
    end

    local y = 25
    for i = 1, 15 do

        local yText = y + 6

        local frame = window:createFrame(Rect(0, y, textBoxX - 10, 30 + y))

        local icon = window:createPicture(Rect(pictureX, yText - 5, 29 + pictureX, 29 + yText - 5), "")
        local nameLabel = window:createLabel(vec2(nameX, yText), "", 15)
        local stockLabel = window:createLabel(vec2(stockX, yText), "", 15)
        local priceLabel = window:createLabel(vec2(priceX, yText), "", 15)
        local sizeLabel = window:createLabel(vec2(volX, yText), "", 15)
        local youLabel = window:createLabel(vec2(youX, yText), "", 15)
        local numberTextBox = window:createTextBox(Rect(textBoxX, yText - 6, 60 + textBoxX, 30 + yText - 6), textCallback)
        local button = window:createButton(Rect(buttonX, yText - 6, window.size.x, 30 + yText - 6), buttonCaption, buttonCallback)

        button.maxTextSize = 16

        numberTextBox.text = "0"
        numberTextBox.allowedCharacters = "0123456789"
        numberTextBox.clearOnClick = 1

        icon.isIcon = 1

        local show = function (self)
            self.icon:show()
            self.frame:show()
            self.name:show()
            self.stock:show()
            self.price:show()
            self.size:show()
            self.number:show()
            self.button:show()
            self.you:show()
        end
        local hide = function (self)
            self.icon:hide()
            self.frame:hide()
            self.name:hide()
            self.stock:hide()
            self.price:hide()
            self.size:hide()
            self.number:hide()
            self.button:hide()
            self.you:hide()
        end

        local line = {icon = icon, frame = frame, name = nameLabel, stock = stockLabel, price = priceLabel, you = youLabel, size = sizeLabel, number = numberTextBox, button = button, show = show, hide = hide}
        line:hide()

        if guiType == 1 then
            table.insert(self.soldLines, line)
        else
            table.insert(self.boughtLines, line)
        end

        y = y + 35
    end

end

function TradingManager:onBuyTextEntered(textBox)

    local enteredNumber = tonumber(textBox.text)
    if enteredNumber == nil then
        enteredNumber = 0
    end

    local newNumber = enteredNumber

    local goodIndex = nil
    for i, line in pairs(self.soldLines) do
        if line.number.index == textBox.index then
            goodIndex = i
            break
        end
    end

    if goodIndex == nil then return end

    local good = self.soldGoods[goodIndex]

    if not good then
        print ("good with index " .. goodIndex .. " isn't sold.")
        printEntityDebugInfo()
        return
    end

    -- make sure the player can't buy more than the station has in stock
    local stock = self:getNumGoods(good.name)

    if stock < newNumber then
        newNumber = stock
    end

    local player = Player()
    local ship = player.craft
    local shipFaction
    if ship.factionIndex == player.allianceIndex then
        shipFaction = player.alliance
    end
    if shipFaction == nil then
        shipFaction = player
    end
    if ship.freeCargoSpace == nil then return end --> no cargo bay

    -- make sure the player does not buy more than he can have in his cargo bay
    local maxShipHold = math.floor(ship.freeCargoSpace / good.size)
    local msg

    if maxShipHold < newNumber then
        newNumber = maxShipHold
        if newNumber == 0 then
            msg = "Not enough space in your cargo bay!"%_t
        else
            msg = "You can only store ${amount} of this good!"%_t % {amount = newNumber}
        end
    end

    -- make sure the player does not buy more than he can afford (if this isn't his station)
    if Faction().index ~= shipFaction.index then
        local maxAffordable = math.floor(shipFaction.money / self:getSellPrice(good.name, shipFaction.index))
        if shipFaction.infiniteResources then maxAffordable = math.huge end

        if maxAffordable < newNumber then
            newNumber = maxAffordable

            if newNumber == 0 then
                msg = "You can't afford any of this good!"%_t
            else
                msg = "You can only afford ${amount} of this good!"%_t % {amount = newNumber}
            end
        end
    end

    if msg then
        self:sendError(nil, msg)
    end

    if newNumber ~= enteredNumber then
        textBox.text = newNumber
    end
end

function TradingManager:onSellTextEntered(textBox)

    local enteredNumber = tonumber(textBox.text)
    if enteredNumber == nil then
        enteredNumber = 0
    end

    local newNumber = enteredNumber

    local goodIndex = nil
    for i, line in pairs(self.boughtLines) do
        if line.number.index == textBox.index then
            goodIndex = i
            break
        end
    end
    if goodIndex == nil then return end

    local good = self.boughtGoods[goodIndex]
    if not good then
        print ("good with index " .. goodIndex .. " isn't bought")
        printEntityDebugInfo();
        return
    end

    local stock = self:getNumGoods(good.name)

    local maxAmountPlaceable = self:getMaxStock(good.size) - stock;
    if maxAmountPlaceable < newNumber then
        newNumber = maxAmountPlaceable
    end


    local ship = Player().craft

    local msg

    -- make sure the player does not sell more than he has in his cargo bay
    local amountOnPlayerShip = ship:getCargoAmount(good)
    if amountOnPlayerShip == nil then return end --> no cargo bay

    if amountOnPlayerShip < newNumber then
        newNumber = amountOnPlayerShip
        if newNumber == 0 then
            msg = "You don't have any of this!"%_t
        end
    end

    if msg then
        self:sendError(nil, msg)
    end

    -- maximum number of sellable things is the amount the player has on his ship
    if newNumber ~= enteredNumber then
        textBox.text = newNumber
    end
end

function TradingManager:onBuyButtonPressed(button)

    local shipIndex = Player().craftIndex
    local goodIndex = nil

    for i, line in ipairs(self.soldLines) do
        if line.button.index == button.index then
            goodIndex = i
        end
    end

    if goodIndex == nil then
        print("internal error, good matching 'Buy' button doesn't exist.")
        return
    end

    local amount = self.soldLines[goodIndex].number.text
    if amount == "" then
        amount = 0
    else
        amount = tonumber(amount)
    end

    local good = self.soldGoods[goodIndex]
    if not good then
        print ("internal error, good with index " .. goodIndex .. " of buy button not found.")
        printEntityDebugInfo()
        return
    end

    invokeServerFunction("sellToShip", shipIndex, good.name, amount)
end

function TradingManager:onSellButtonPressed(button)

    local shipIndex = Player().craftIndex
    local goodIndex = nil

    for i, line in ipairs(self.boughtLines) do
        if line.button.index == button.index then
            goodIndex = i
        end
    end

    if goodIndex == nil then
        return
    end

    local amount = self.boughtLines[goodIndex].number.text
    if amount == "" then
        amount = 0
    else
        amount = tonumber(amount)
    end

    local good = self.boughtGoods[goodIndex]
    if not good then
        print ("internal error, good with index " .. goodIndex .. " of sell button not found.")
        printEntityDebugInfo()
        return
    end

    invokeServerFunction("buyFromShip", shipIndex, good.name, amount)

end

function TradingManager:sendError(faction, msg, ...)
    if onServer() then
        if faction.isPlayer then
            Player(faction.index):sendChatMessage(Entity().title, 1, msg, ...)
        end
    elseif onClient() then
        displayChatMessage(msg, Entity().title, 1)
    end
end

function TradingManager:transferMoney(owner, from, to, amount, fromDescription, toDescription)
    if from.index == to.index then return end

    local ownerMoney = amount * self.factionPaymentFactor

    if owner.index == from.index then
        from:pay(fromDescription or "", ownerMoney)
        to:receive(toDescription or "", amount)
    elseif owner.index == to.index then
        from:pay(fromDescription or "", amount)
        to:receive(toDescription or "", ownerMoney)
    else
        from:pay(fromDescription or "", amount)
        to:receive(toDescription or "", amount)
    end

    receiveTransactionTax(Entity(), amount * self.tax)
end

function TradingManager:buyFromShip(shipIndex, goodName, amount, noDockCheck)

    -- check if the good can be bought
    if not self:getBoughtGoodByName(goodName) == nil then
        self:sendError(shipFaction, "%s isn't bought."%_t, goodName)
        return
    end

    local shipFaction, ship = getInteractingFactionByShip(shipIndex, callingPlayer, AlliancePrivilege.SpendResources)
    if not shipFaction then return end

    if ship.freeCargoSpace == nil then
        self:sendError(shipFaction, "Your ship has no cargo bay!"%_t)
        return
    end

    -- check if the specific good from the player can be bought (ie. it's not illegal or something like that)
    local cargos = ship:findCargos(goodName)
    local good = nil
    local msg = "You don't have any %s that the station buys!"%_t
    local args = {goodName}

    for g, amount in pairs(cargos) do
        local ok
        ok, msg = self:isBoughtBySelf(g)
        args = {}
        if ok then
            good = g
            break
        end
    end

    if not good then
        self:sendError(shipFaction, msg, unpack(args))
        return
    end

    local station = Entity()
    local stationFaction = Faction()

    -- make sure the ship can not sell more than the station can have in stock
    local maxAmountPlaceable = self:getMaxStock(good.size) - self:getNumGoods(good.name);

    if maxAmountPlaceable < amount then
        amount = maxAmountPlaceable

        if maxAmountPlaceable == 0 then
            self:sendError(shipFaction, "This station is not able to take any more %s."%_t, good.translatablePlural)
        end
    end

    -- make sure the player does not sell more than he has in his cargo bay
    local amountOnShip = ship:getCargoAmount(good)

    if amountOnShip < amount then
        amount = amountOnShip

        if amountOnShip == 0 then
            self:sendError(shipFaction, "You don't have any %s on your ship"%_t, good.translatablePlural)
        end
    end

    if amount <= 0 then
        return
    end

    -- begin transaction
    -- calculate price. if the seller is the owner of the station, the price is 0
    local price = self:getBuyPrice(good.name, shipFaction.index) * amount

    local canPay, msg, args = stationFaction:canPay(price);
    if not canPay then
        self:sendError(shipFaction, "This station's faction doesn't have enough money."%_t)
        return
    end

    if not noDockCheck then
        -- test the docking last so the player can know what he can buy from afar already
        local errors = {}
        errors[EntityType.Station] = "You must be docked to the station to trade."%_T
        errors[EntityType.Ship] = "You must be closer to the ship to trade."%_T
        if not CheckShipDocked(shipFaction, ship, station, errors) then
            return
        end
    end

    local x, y = Sector():getCoordinates()
    local fromDescription = Format("\\s(%1%:%2%) %3% bought %4% %5% for %6% credits."%_T, x, y, station.translatedTitle, math.floor(amount), good.translatablePlural, createMonetaryString(price))
    local toDescription = Format("\\s(%1%:%2%) %3% sold %4% %5% for %6% credits."%_T, x, y, ship.name, math.floor(amount), good.translatablePlural, createMonetaryString(price))

    -- give money to ship faction
    self:transferMoney(stationFaction, stationFaction, shipFaction, price, fromDescription, toDescription)

    -- remove goods from ship
    ship:removeCargo(good, amount)

    -- trading (non-military) ships get higher relation gain
    local relationsChange = GetRelationChangeFromMoney(price)
    if ship:getNumArmedTurrets() <= 1 then
        relationsChange = relationsChange * 1.5
    end

    Galaxy():changeFactionRelations(shipFaction, stationFaction, relationsChange)

    -- add goods to station, do this last so the UI update that comes with the sync already has the new relations
    self:increaseGoods(good.name, amount)
end

function TradingManager:sellToShip(shipIndex, goodName, amount, noDockCheck)

    local good = self:getSoldGoodByName(goodName)
    if good == nil then return end

    local shipFaction, ship = getInteractingFactionByShip(shipIndex, callingPlayer, AlliancePrivilege.SpendResources)
    if not shipFaction then return end

    if ship.freeCargoSpace == nil then
        self:sendError(shipFaction, "Your ship has no cargo bay!"%_t)
        return
    end

    local station = Entity()
    local stationFaction = Faction()

    -- make sure the player can not buy more than the station has in stock
    local amountBuyable = self:getNumGoods(goodName)

    if amountBuyable < amount then
        amount = amountBuyable

        if amountBuyable == 0 then
             self:sendError(shipFaction, "This station has no more %s to sell."%_t, good.translatablePlural)
        end
    end

    -- make sure the player does not buy more than he can have in his cargo bay
    local maxShipHold = math.floor(ship.freeCargoSpace / good.size)

    if maxShipHold < amount then
        amount = maxShipHold

        if maxShipHold == 0 then
            self:sendError(shipFaction, "Your ship can not take more %s."%_t, good.translatablePlural)
        end
    end

    if amount <= 0 then
        return
    end

    -- begin transaction
    -- calculate price. if the owner of the station wants to buy, the price is 0
    local price = self:getSellPrice(good.name, shipFaction.index) * amount

    local canPay, msg, args = shipFaction:canPay(price);
    if not canPay then
        self:sendError(shipFaction, msg, unpack(args))
        return
    end

    if not noDockCheck then
        -- test the docking last so the player can know what he can buy from afar already
        local errors = {}
        errors[EntityType.Station] = "You must be docked to the station to trade."%_T
        errors[EntityType.Ship] = "You must be closer to the ship to trade."%_T
        if not CheckShipDocked(shipFaction, ship, station, errors) then
            return
        end
    end

    local x, y = Sector():getCoordinates()
    local fromDescription = Format("\\s(%1%:%2%) %3% bought %4% %5% for %6% credits."%_T, x, y, ship.translatedTitle, math.floor(amount), good.translatablePlural, createMonetaryString(price))
    local toDescription = Format("\\s(%1%:%2%) %3% sold %4% %5% for %6% credits."%_T, x, y, station.name, math.floor(amount), good.translatablePlural, createMonetaryString(price))

    -- make player pay
    self:transferMoney(stationFaction, shipFaction, stationFaction, price, fromDescription, toDescription)

    -- give goods to player
    ship:addCargo(good, amount)

    -- trading (non-military) ships get higher relation gain
    local relationsChange = GetRelationChangeFromMoney(price)
    if ship:getNumArmedTurrets() <= 1 then
        relationsChange = relationsChange * 1.5
    end

    Galaxy():changeFactionRelations(shipFaction, stationFaction, relationsChange)

    -- remove goods from station, do this last so the UI update that comes with the sync already has the new relations
    self:decreaseGoods(good.name, amount)

end

-- convenience function for buying goods from another faction, meant to be called from external. They're not removed from another ship, they just appear
function TradingManager:buyGoods(good, amount, otherFactionIndex, monetaryTransactionOnly)

    -- check if the good is even bought by the station
    if not self:getBoughtGoodByName(good.name) == nil then return 1 end

    local ok = self:isBoughtBySelf(good)
    if not ok then return 4 end

    local stationFaction = Faction()
    local otherFaction = Faction(otherFactionIndex)

    -- make sure the transaction can not sell more than the station can have in stock
    local buyable = self:getMaxStock(good.size) - self:getNumGoods(good.name);
    amount = math.min(buyable, amount)
    if amount <= 0 then return 2 end

    -- begin transaction
    -- calculate price. if the seller is the owner of the station, the price is 0
    local price = self:getBuyPrice(good.name, otherFactionIndex) * amount

    local canPay, msg, args = stationFaction:canPay(price);
    if not canPay then return 3 end

    local x, y = Sector():getCoordinates()
    local fromDescription = Format("\\s(%1%:%2%) %3% bought %4% %5% for %6% credits."%_T, x, y, Entity().translatedTitle, math.floor(amount), good.translatablePlural, createMonetaryString(price))
    local toDescription = Format("\\s(%1%:%2%): sold %3% %4% for %5% credits."%_T, x, y, math.floor(amount), good.translatablePlural, createMonetaryString(price))

    -- give money to other faction
    self:transferMoney(stationFaction, stationFaction, otherFaction, price, fromDescription, toDescription)

    local relationsChange = GetRelationChangeFromMoney(price)
    Galaxy():changeFactionRelations(otherFaction, stationFaction, relationsChange)

    if not monetaryTransactionOnly then
        -- add goods to station, do this last so the UI update that comes with the sync already has the new relations
        self:increaseGoods(good.name, amount)
    end

    return 0
end

-- convenience function for selling goods to another faction. They're not added to another ship, they just disappear
function TradingManager:sellGoods(good, amount, otherFactionIndex, monetaryTransactionOnly)

    local stationFaction = Faction()
    local otherFaction = Faction(otherFactionIndex)

    local sellable = self:getNumGoods(good.name)
    amount = math.min(sellable, amount)
    if amount <= 0 then return 1 end

    local price = self:getSellPrice(good.name, otherFactionIndex) * amount
    local canPay = otherFaction:canPay(price);
    if not canPay then return 2 end

    local x, y = Sector():getCoordinates()
    local toDescription = Format("\\s(%1%:%2%) %3% sold %4% %5% for %6% credits."%_T, x, y, Entity().translatedTitle, math.floor(amount), good.translatablePlural, createMonetaryString(price))
    local fromDescription = Format("\\s(%1%:%2%): Bought %3% %4% for %5% credits."%_T, x, y, math.floor(amount), good.translatablePlural, createMonetaryString(price))

    -- make other faction pay
    self:transferMoney(stationFaction, otherFaction, stationFaction, price, fromDescription, toDescription)

    local relationsChange = GetRelationChangeFromMoney(price)
    Galaxy():changeFactionRelations(otherFaction, stationFaction, relationsChange)

    if not monetaryTransactionOnly then
        -- remove goods from station, do this last so the UI update that comes with the sync already has the new relations
        self:decreaseGoods(good.name, amount)
    end

    return 0
end

function TradingManager:increaseGoods(name, delta)

    local entity = Entity()

    for i, good in pairs(self.soldGoods) do
        if good.name == name then
            -- increase
            local current = entity:getCargoAmount(good)
            delta = math.min(delta, self:getMaxStock(good.size) - current)
            delta = math.max(delta, 0)

            entity:addCargo(good, delta)

            broadcastInvokeClientFunction("updateSoldGoodAmount", i)
        end
    end

    for i, good in pairs(self.boughtGoods) do
        if good.name == name then
            -- increase
            local current = entity:getCargoAmount(good)
            delta = math.min(delta, self:getMaxStock(good.size) - current)
            delta = math.max(delta, 0)

            entity:addCargo(good, delta)

            broadcastInvokeClientFunction("updateBoughtGoodAmount", i)
        end
    end

end

function TradingManager:decreaseGoods(name, amount)

    local entity = Entity()

    for i, good in pairs(self.soldGoods) do
        if good.name == name then
            entity:removeCargo(good, amount)

            broadcastInvokeClientFunction("updateSoldGoodAmount", i)
        end
    end

    for i, good in pairs(self.boughtGoods) do
        if good.name == name then
            entity:removeCargo(good, amount)

            broadcastInvokeClientFunction("updateBoughtGoodAmount", i)
        end
    end

end

function TradingManager:useUpBoughtGoods(timeStep)

    if not self.useUpGoodsEnabled then return end

    self.useTimeCounter = self.useTimeCounter + timeStep

    if self.useTimeCounter > 5 then
        self.useTimeCounter = 0

        if math.random () < 0.5 then

            local amount = math.random(1, 6)
            local good = self.boughtGoods[math.random(1, #self.boughtGoods)]

            if good ~= nil then
                self:decreaseGoods(good.name, amount)
            end
        end
    end

end

function TradingManager:getBoughtGoods()
    local result = {}

    for i, good in pairs(self.boughtGoods) do
        table.insert(result, good.name)
    end

    return unpack(result)
end

function TradingManager:getSoldGoods()
    local result = {}

    for i, good in pairs(self.soldGoods) do
        table.insert(result, good.name)
    end

    return unpack(result)
end

function TradingManager:getStock(name)
    return self:getNumGoods(name), self:getMaxGoods(name)
end

function TradingManager:getNumGoods(name)
    local entity = Entity()

    local g = goods[name]
    if not g then return 0 end

    local good = g:good()
    if not good then return 0 end

    return entity:getCargoAmount(good)
end

function TradingManager:getMaxGoods(name)
    local amount = 0

    for i, good in pairs(self.soldGoods) do
        if good.name == name then
            return self:getMaxStock(good.size)
        end
    end

    for i, good in pairs(self.boughtGoods) do
        if good.name == name then
            return self:getMaxStock(good.size)
        end
    end

    return amount
end

function TradingManager:getGoodSize(name)

    for i, good in pairs(self.soldGoods) do
        if good.name == name then
            return good.size
        end
    end

    for i, good in pairs(self.boughtGoods) do
        if good.name == name then
            return good.size
        end
    end

    print ("error: " .. name .. " is neither bought nor sold")
end

function TradingManager:getMaxStock(goodSize)

    local entity = Entity()

    local space = entity.maxCargoSpace
    local slots = self.numBought + self.numSold

    if slots > 0 then space = space / slots end

    if space / goodSize > 100 then
        -- round to 100
        return math.min(25000, round(space / goodSize / 100) * 100)
    else
        -- not very much space already, don't round
        return math.floor(space / goodSize)
    end
end

function TradingManager:getBoughtGoodByName(name)
    for _, good in pairs(self.boughtGoods) do
        if good.name == name then
            return good
        end
    end
end

function TradingManager:getSoldGoodByName(name)
    for _, good in pairs(self.soldGoods) do
        if good.name == name then
            return good
        end
    end
end

function TradingManager:getGoodByName(name)
    for _, good in pairs(self.boughtGoods) do
        if good.name == name then
            return good
        end
    end

    for _, good in pairs(self.soldGoods) do
        if good.name == name then
            return good
        end
    end
end

-- price for which goods are bought by this from others
function TradingManager:getBuyPrice(goodName, sellingFaction)

    local good = self:getBoughtGoodByName(goodName)
    if not good then return 0 end

    -- empty stock -> higher price
    local maxStock = self:getMaxStock(good.size)
    local factor = 1

    if maxStock > 0 then
        factor = self:getNumGoods(goodName) / maxStock -- 0 to 1 where 1 is 'full stock'
        factor = 1 - factor -- 1 to 0 where 0 is 'full stock'
        factor = factor * 0.4 -- 0.4 to 0
        factor = factor + 0.8 -- 1.2 to 0.8; 'no goods' to 'full'
    end

    local relationFactor = 1
    if sellingFaction then
        local sellerIndex = nil
        if type(sellingFaction) == "number" then
            sellerIndex = sellingFaction
        else
            sellerIndex = sellingFaction.index
        end

        if sellerIndex then
            local relations = Faction():getRelations(sellerIndex)

            if relations < -10000 then
                -- bad relations: faction pays less for the goods
                -- 10% to 100% from -100.000 to -10.000
                relationFactor = lerp(relations, -100000, -10000, 0.1, 1.0)
            elseif relations >= 50000 then
                -- very good relations: factions pays MORE for the goods
                -- 100% to 120% from 80.000 to 100.000
                relationFactor = lerp(relations, 80000, 100000, 1.0, 1.15)
            end

            if Faction().index == sellerIndex then relationFactor = 0 end
        end
    end

    local basePrice = round(good.price * self.buyPriceFactor)
    local price = round(good.price * relationFactor * factor * self.buyPriceFactor)

    return price, basePrice
end

-- price for which goods are sold from this to others
function TradingManager:getSellPrice(goodName, buyingFaction)

    local good = self:getSoldGoodByName(goodName)
    if not good then return 0 end

    -- empty stock -> higher price
    local maxStock = self:getMaxStock(good.size)
    local factor = 1

    if maxStock > 0 then
        factor = self:getNumGoods(goodName) / maxStock -- 0 to 1 where 1 is 'full stock'
        factor = 1 - factor -- 1 to 0 where 0 is 'full stock'
        factor = factor * 0.4 -- 0.4 to 0
        factor = factor + 0.8 -- 1.2 to 0.8; 'no goods' to 'full'
    end

    local relationFactor = 1
    if buyingFaction then
        local sellerIndex = nil
        if type(buyingFaction) == "number" then
            sellerIndex = buyingFaction
        else
            sellerIndex = buyingFaction.index
        end

        if sellerIndex then
            local relations = Faction():getRelations(sellerIndex)

            if relations < -10000 then
                -- bad relations: faction wants more for the goods
                -- 200% to 100% from -100.000 to -10.000
                relationFactor = lerp(relations, -100000, -10000, 2.0, 1.0)
            elseif relations > 30000 then
                -- good relations: factions start giving player better prices
                -- 100% to 80% from 30.000 to 90.000
                relationFactor = lerp(relations, 30000, 90000, 1.0, 0.8)
            end

            if Faction().index == sellerIndex then relationFactor = 0 end
        end

    end

    local price = round(good.price * relationFactor * factor * self.sellPriceFactor)
    local basePrice = round(good.price * self.sellPriceFactor)

    return price, basePrice
end


local r = Random(Seed(os.time()))

local organizeUpdateFrequency
local organizeUpdateTime

local organizeDescription = [[
Organize ${amount} ${good.displayPlural} in 30 Minutes.

You will be paid the double of the usual price, plus a bonus.

Time Limit: 30 minutes
Reward: $${reward}
]]%_t

function TradingManager:updateOrganizeGoodsBulletins(timeStep)

    if not organizeUpdateFrequency then
        -- more frequent updates when there are more ingredients
        organizeUpdateFrequency = math.max(60 * 8, 60 * 60 - (#self.boughtGoods * 7.5 * 60))
    end

    if not organizeUpdateTime then
        -- by adding half the time here, we have a chance that a factory immediately has a bulletin
        organizeUpdateTime = 0

        local minutesSimulated = r:getInt(10, 80)
        for i = 1, minutesSimulated do -- simulate bulletin posting / removing
            self:updateOrganizeGoodsBulletins(60)
        end
    end

    organizeUpdateTime = organizeUpdateTime + timeStep

    -- don't execute the following code if the time hasn't exceeded the posting frequency
    if organizeUpdateTime < organizeUpdateFrequency then return end
    organizeUpdateTime = organizeUpdateTime - organizeUpdateFrequency

    -- choose a random ingredient
    local good = self.boughtGoods[r:getInt(1, #self.boughtGoods)]
    if not good then return end

    local cargoVolume = 50 + r:getFloat(0, 200)
    local amount = math.min(math.floor(100 / good.size), 150)
    local reward = good.price * amount * 2.0 + 20000
    local x, y = Sector():getCoordinates()

    local bulletin =
    {
        brief = "Resource Shortage: ${amount} ${good.displayPlural}"%_T,
        description = organizeDescription,
        difficulty = "Easy"%_T,
        reward = string.format("$${reward}"%_T, createMonetaryString(reward)),
        script = "missions/organizegoods.lua",
        arguments = {good.name, amount, Entity().index, x, y, reward},
        formatArguments = {amount = amount, good = good, reward = createMonetaryString(reward)}
    }

    -- since in this case "add" can override "remove", adding a bulletin is slightly more probable
    local add = r:getFloat() < 0.5
    local remove = r:getFloat() < 0.5

    if not add and not remove then
        if r:getFloat() < 0.5 then
            add = true
        else
            remove = true
        end
    end

    if add then
        -- randomly add bulletins
        Entity():invokeFunction("bulletinboard", "postBulletin", bulletin)
    elseif remove then
        -- randomly remove bulletins
        Entity():invokeFunction("bulletinboard", "removeBulletin", bulletin.brief)
    end

end


local deliveryDescription = [[
Deliver ${amount} ${good.displayPlural} to a station near this location in 20 minutes.

You will have to make a deposit of $${deposit},
which will be reimbursed when the goods are delivered.

Deposit: $${deposit}
Time Limit: 20 minutes
Reward: $${reward}
]]%_t

local deliveryUpdateFrequency
local deliveryUpdateTime

function TradingManager:updateDeliveryBulletins(timeStep)

    if not deliveryUpdateFrequency then
        -- more frequent updates when there are more ingredients
        deliveryUpdateFrequency = math.max(60 * 8, 60 * 60 - (#self.soldGoods * 7.5 * 60))
    end

    if not deliveryUpdateTime then
        -- by adding half the time here, we have a chance that a factory immediately has a bulletin
        deliveryUpdateTime = 0

        local minutesSimulated = r:getInt(10, 80)
        for i = 1, minutesSimulated do -- simulate 1 hour of bulletin posting / removing
            self:updateDeliveryBulletins(60)
        end
    end

    deliveryUpdateTime = deliveryUpdateTime + timeStep

    -- don't execute the following code if the time hasn't exceeded the posting frequency
    if deliveryUpdateTime < deliveryUpdateFrequency then return end
    deliveryUpdateTime = deliveryUpdateTime - deliveryUpdateFrequency

    -- choose a sold good
    local good = self.soldGoods[r:getInt(1, #self.soldGoods)]
    if not good then return end

    local cargoVolume = 50 + r:getFloat(0, 200)
    local amount = math.min(math.floor(cargoVolume / good.size), 150)
    local reward = good.price * amount
    local x, y = Sector():getCoordinates()

    -- add a maximum of earnable money
    local maxEarnable = 20000 * Balancing_GetSectorRichnessFactor(x, y)
    if reward > maxEarnable then
        amount = math.floor(maxEarnable / good.price)
        reward = good.price * amount
    end

    if amount == 0 then return end

    reward = reward * 0.5 + 5000
    local deposit = math.floor(good.price * amount * 0.75 / 100) * 100
    local reward = math.floor(reward / 100) * 100

    -- todo: localization of entity titles
    local bulletin =
    {
        brief = "Delivery: ${good.displayPlural}"%_T,
        description = deliveryDescription,
        difficulty = "Easy"%_T,
        reward = string.format("$%s", createMonetaryString(reward)),
        formatArguments = {good = good, amount = amount, deposit = createMonetaryString(deposit), reward = createMonetaryString(reward)},

        script = "missions/delivery.lua",
        arguments = {good.name, amount, Entity().index, deposit + reward},

        checkAccept = [[
            local self, player = ...
            local ship = Entity(player.craftIndex)
            local space = ship.freeCargoSpace or 0
            if space < self.good.size * self.amount then
                player:sendChatMessage(self.sender, 1, self.msgCargo)
                return 0
            end
            if not Entity():isDocked(ship) then
                player:sendChatMessage(self.sender, 1, self.msgDock)
                return 0
            end
            local canPay = player:canPay(self.deposit)
            if not canPay then
                player:sendChatMessage(self.sender, 1, self.msgMoney)
                return 0
            end
            return 1
            ]],
        onAccept = [[
            local self, player = ...
            player:pay(self.deposit)
            local ship = Entity(player.craftIndex)
            ship:addCargo(goods[self.good.name]:good(), self.amount)
            ]],

        cargoVolume = cargoVolume,
        amount = amount,
        good = good,
        deposit = deposit,
        sender = "Client"%_T,
        msgCargo = "Not enough cargo space on your ship."%_T,
        msgDock = "You have to be docked to the station."%_T,
        msgMoney = "You don't have enough money for the deposit."%_T
    }

    -- since in this case "add" can override "remove", adding a bulletin is slightly more probable
    local add = r:getFloat() < 0.5
    local remove = r:getFloat() < 0.5

    if not add and not remove then
        if r:getFloat() < 0.5 then
            add = true
        else
            remove = true
        end
    end

    if add then
        -- randomly add bulletins
        Entity():invokeFunction("bulletinboard", "postBulletin", bulletin)
    elseif remove then
        -- randomly remove bulletins
        Entity():invokeFunction("bulletinboard", "removeBulletin", bulletin.brief)
    end

end

function TradingManager:getBuyGoodsErrorMessage(code)
    if code == 0 then
        return "No error."%_T
    elseif code == 1 then
        return "Good isn't bought."%_T
    elseif code == 2 then
        return "No more space."%_T
    elseif code == 3 then
        return "Not enough money."%_T
    elseif code == 4 then
        return "Good isn't bought."%_T
    end

    return "Unknown error."%_T
end

function TradingManager:getSellGoodsErrorMessage(code)
    if code == 0 then
        return "No error."%_T
    elseif code == 1 then
        return "No more goods."%_T
    elseif code == 2 then
        return "Not enough money."%_T
    end

    return "Unknown error."%_T
end


local PublicNamespace = {}
PublicNamespace.CreateTradingManager = setmetatable({new = new}, {__call = function(_, ...) return new(...) end})

function PublicNamespace.CreateTabbedWindow(caption)
    local menu = ScriptUI()

    if not PublicNamespace.tabbedWindow then
        local res = getResolution()
        local size = vec2(950, 650)

        local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));

        window.caption = caption or ""
        window.showCloseButton = 1
        window.moveable = 1

        -- create a tabbed window inside the main window
        PublicNamespace.tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))
        PublicNamespace.window = window
    end

    -- registers the window for this script, enabling the default window interaction calls like onShowWindow(), renderUI(), etc.
    -- if the same window is registered more than once, an interaction option will only be shown for the first registration
    menu:registerWindow(PublicNamespace.window, "Trade Goods"%_t);

    return PublicNamespace.tabbedWindow
end

function PublicNamespace.CreateNamespace()
    local result = {}

    local trader = PublicNamespace.CreateTradingManager()
    result.trader = trader
    result.updateDeliveryBulletins = function(...) return trader:updateDeliveryBulletins(...) end
    result.updateOrganizeGoodsBulletins = function(...) return trader:updateOrganizeGoodsBulletins(...) end
    result.getSellPrice = function(...) return trader:getSellPrice(...) end
    result.getBuyPrice = function(...) return trader:getBuyPrice(...) end
    result.getGoodByName = function(...) return trader:getGoodByName(...) end
    result.getSoldGoodByName = function(...) return trader:getSoldGoodByName(...) end
    result.getBoughtGoodByName = function(...) return trader:getBoughtGoodByName(...) end
    result.getMaxStock = function(...) return trader:getMaxStock(...) end
    result.getGoodSize = function(...) return trader:getGoodSize(...) end
    result.getMaxGoods = function(...) return trader:getMaxGoods(...) end
    result.getNumGoods = function(...) return trader:getNumGoods(...) end
    result.getStock = function(...) return trader:getStock(...) end
    result.getSoldGoods = function(...) return trader:getSoldGoods(...) end
    result.getBoughtGoods = function(...) return trader:getBoughtGoods(...) end
    result.useUpBoughtGoods = function(...) return trader:useUpBoughtGoods(...) end
    result.decreaseGoods = function(...) return trader:decreaseGoods(...) end
    result.increaseGoods = function(...) return trader:increaseGoods(...) end
    result.sellToShip = function(...) return trader:sellToShip(...) end
    result.buyFromShip = function(...) return trader:buyFromShip(...) end
    result.onSellButtonPressed = function(...) return trader:onSellButtonPressed(...) end
    result.onBuyButtonPressed = function(...) return trader:onBuyButtonPressed(...) end
    result.onSellTextEntered = function(...) return trader:onSellTextEntered(...) end
    result.onBuyTextEntered = function(...) return trader:onBuyTextEntered(...) end
    result.buildGui = function(...) return trader:buildGui(...) end
    result.buildSellGui = function(...) return trader:buildSellGui(...) end
    result.buildBuyGui = function(...) return trader:buildBuyGui(...) end
    result.updateSoldGoodAmount = function(...) return trader:updateSoldGoodAmount(...) end
    result.updateBoughtGoodAmount = function(...) return trader:updateBoughtGoodAmount(...) end
    result.receiveGoods = function(...) return trader:receiveGoods(...) end
    result.sendGoods = function(...) return trader:sendGoods(...) end
    result.requestGoods = function(...) return trader:requestGoods(...) end
    result.initializeTrading = function(...) return trader:initializeTrading(...) end
    result.secureTradingGoods = function(...) return trader:secureTradingGoods(...) end
    result.restoreTradingGoods = function(...) return trader:restoreTradingGoods(...) end
    result.generateGoods = function(...) return trader:generateGoods(...) end
    result.sendError = function(...) return trader:sendError(...) end
    result.buyGoods = function(...) return trader:buyGoods(...) end
    result.sellGoods = function(...) return trader:sellGoods(...) end
    result.getBuysFromOthers = function(...) return trader:getBuysFromOthers(...) end
    result.getSellsToOthers = function(...) return trader:getSellsToOthers(...) end
    result.setBuysFromOthers = function(...) return trader:setBuysFromOthers(...) end
    result.setSellsToOthers = function(...) return trader:setSellsToOthers(...) end

    result.setUseUpGoodsEnabled = function(enabled) trader.useUpGoodsEnabled = enabled end
    result.getBuyGoodsErrorMessage = function(enabled) trader.getBuyGoodsErrorMessage = enabled end
    result.getSellGoodsErrorMessage = function(enabled) trader.getSellGoodsErrorMessage = enabled end

    return result
end

return PublicNamespace
