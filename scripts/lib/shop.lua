package.path = package.path .. ";data/scripts/lib/?.lua"
require ("galaxy")
require ("randomext")
require ("utility")
require ("stringutility")
require ("player")
require ("faction")
require ("merchantutility")
local SellableInventoryItem = require ("sellableinventoryitem")
local Dialog = require("dialogutility")

local PublicNamespace = {}

local Shop = {}
Shop.__index = Shop

local function new()
    local instance = {}

    instance.ItemWrapper = SellableInventoryItem
    instance.tax = 0.2

    -- UI
    instance.soldItemFrames = {}
    instance.soldItemNameLabels = {}
    instance.soldItemPriceLabels = {}
    instance.soldItemMaterialLabels = {}
    instance.soldItemStockLabels = {}
    instance.soldItemButtons = {}
    instance.soldItemIcons = {}

    instance.boughtItemFrames = {}
    instance.boughtItemNameLabels = {}
    instance.boughtItemPriceLabels = {}
    instance.boughtItemMaterialLabels = {}
    instance.boughtItemStockLabels = {}
    instance.boughtItemButtons = {}
    instance.boughtItemIcons = {}

    instance.pageLabel = 0

    instance.buybackItemFrames = {}
    instance.buybackItemNameLabels = {}
    instance.buybackItemPriceLabels = {}
    instance.buybackItemMaterialLabels = {}
    instance.buybackItemStockLabels = {}
    instance.buybackItemButtons = {}
    instance.buybackItemIcons = {}

    instance.itemsPerPage = 15

    instance.soldItems = {}
    instance.boughtItems = {}
    instance.buybackItems = {}

    instance.boughtItemsPage = 0

    instance.guiInitialized = false

    instance.buyTab = nil
    instance.sellTab = nil
    instance.buyBackTab = nil

    return setmetatable(instance, Shop)
end

-- this function gets called on creation of the entity the script is attached to, on client and server
function Shop:initialize(title)

    local station = Entity()
    if onServer() then
        if station.title == "" then
            station.title = title
        end

        self:addItems()
    else
        InteractionText().text = Dialog.generateStationInteractionText(station, random())
        self:requestItems()
    end
end

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
function Shop:initUI(interactionCaption, windowCaption, tabCaption)

    local menu = ScriptUI()

    if not self.shared.window then
        local size = vec2(900, 690)
        local res = getResolution()

        local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));

        window.caption = windowCaption
        window.showCloseButton = 1
        window.moveable = 1

        -- create a tabbed window inside the main window
        self.tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

        -- create sell tab
        self.sellTab = self.tabbedWindow:createTab("Sell"%_t, "data/textures/icons/coins.png", "Sell Items"%_t)
        self:buildSellGui(self.sellTab)

        self.buyBackTab = self.tabbedWindow:createTab("Buyback"%_t, "data/textures/icons/cycle.png", "Buy Back Sold Items"%_t)
        self:buildBuyBackGui(self.buyBackTab)

        self.shared.window = window
        self.shared.tabbedWindow = self.tabbedWindow
        self.shared.sellTab = self.sellTab
        self.shared.buyBackTab = self.buyBackTab

        self.manageSellAndBuyback = true
    end

    -- registers the window for this script, enabling the default window interaction calls like onShowWindow(), renderUI(), etc.
    -- if the same window is registered more than once, an interaction option will only be shown for the first registration
    menu:registerWindow(self.shared.window, interactionCaption);

    self.window = self.shared.window
    self.tabbedWindow = self.shared.tabbedWindow
    self.sellTab = self.shared.sellTab
    self.buyBackTab = self.shared.buyBackTab

    -- create buy tab
    self.buyTab = self.tabbedWindow:createTab("Buy"%_t, "data/textures/icons/purse.png", tabCaption)
    self:buildBuyGui(self.buyTab)

    self.tabbedWindow:moveTabToTheRight(self.sellTab)
    self.tabbedWindow:moveTabToTheRight(self.buyBackTab)

    self.guiInitialized = true

    self:requestItems()
end

function Shop:buildBuyGui(tab) -- client
    self:buildGui(tab, 0)
end

function Shop:buildSellGui(tab) -- client
    self:buildGui(tab, 1)
end

function Shop:buildBuyBackGui(tab) -- client
    self:buildGui(tab, 2)
end

function Shop:buildGui(window, guiType) -- client

    local buttonCaption = ""
    local buttonCallback = ""

    local size = window.size
    local pos = window.lower

--    window:createFrame(Rect(size))

    if guiType == 0 then
        buttonCaption = "Buy"%_t
        buttonCallback = "onBuyButtonPressed"
    elseif guiType == 1 then
        buttonCaption = "Sell"%_t
        buttonCallback = "onSellButtonPressed"

        window:createButton(Rect(0, 50 + 35 * 15, 70, 80 + 35 * 15), "<", "onLeftButtonPressed")
        window:createButton(Rect(size.x - 70, 50 + 35 * 15, 60 + size.x - 60, 80 + 35 * 15), ">", "onRightButtonPressed")

        self.pageLabel = window:createLabel(vec2(10, 50 + 35 * 15), "", 20)
        self.pageLabel.lower = vec2(pos.x + 10, pos.y + 50 + 35 * 15)
        self.pageLabel.upper = vec2(pos.x + size.x - 70, pos.y + 75)
        self.pageLabel.centered = 1
    else
        buttonCaption = "Buy"%_t
        buttonCallback = "onBuybackButtonPressed"
    end

    local pictureX = 20
    local nameX = 60
    local materialX = 480
    local stockX = 560
    local priceX = 600
    local buttonX = 720

    -- header
    window:createLabel(vec2(nameX, 0), "Name"%_t, 15)
    window:createLabel(vec2(materialX, 0), "Mat"%_t, 15)
    window:createLabel(vec2(priceX, 0), "Cr"%_t, 15)
    window:createLabel(vec2(stockX, 0), "#"%_t, 15)

    local y = 35

    if guiType == 1 then
        local button = window:createButton(Rect(buttonX, 0, 160 + buttonX, 30), "Sell Trash"%_t, "onSellTrashButtonPressed")
        button.maxTextSize = 15
    end

    for i = 1, self.itemsPerPage do

        local yText = y + 6

        local frame = window:createFrame(Rect(0, y, buttonX - 10, 30 + y))

        local nameLabel = window:createLabel(vec2(nameX, yText), "", 15)
        local priceLabel = window:createLabel(vec2(priceX, yText), "", 15)
        local materialLabel = window:createLabel(vec2(materialX, yText), "", 15)
        local stockLabel = window:createLabel(vec2(stockX, yText), "", 15)
        local button = window:createButton(Rect(buttonX, y, 160 + buttonX, 30 + y), buttonCaption, buttonCallback)
        local icon = window:createPicture(Rect(pictureX, yText - 5, 29 + pictureX, 29 + yText - 5), "")

        button.maxTextSize = 15
        icon.isIcon = 1

        if guiType == 0 then
            table.insert(self.soldItemFrames, frame)
            table.insert(self.soldItemNameLabels, nameLabel)
            table.insert(self.soldItemPriceLabels, priceLabel)
            table.insert(self.soldItemMaterialLabels, materialLabel)
            table.insert(self.soldItemStockLabels, stockLabel)
            table.insert(self.soldItemButtons, button)
            table.insert(self.soldItemIcons, icon)
        elseif guiType == 1 then
            table.insert(self.boughtItemFrames, frame)
            table.insert(self.boughtItemNameLabels, nameLabel)
            table.insert(self.boughtItemPriceLabels, priceLabel)
            table.insert(self.boughtItemMaterialLabels, materialLabel)
            table.insert(self.boughtItemStockLabels, stockLabel)
            table.insert(self.boughtItemButtons, button)
            table.insert(self.boughtItemIcons, icon)
        elseif guiType == 2 then
            table.insert(self.buybackItemFrames, frame)
            table.insert(self.buybackItemNameLabels, nameLabel)
            table.insert(self.buybackItemPriceLabels, priceLabel)
            table.insert(self.buybackItemMaterialLabels, materialLabel)
            table.insert(self.buybackItemStockLabels, stockLabel)
            table.insert(self.buybackItemButtons, button)
            table.insert(self.buybackItemIcons, icon)
        end

        frame:hide();
        nameLabel:hide();
        priceLabel:hide();
        materialLabel:hide();
        stockLabel:hide();
        button:hide();
        icon:hide();

        y = y + 35
    end

end

-- this function gets called every time the window is shown on the client, ie. when a player presses F and if interactionPossible() returned 1
function Shop:onShowWindow()

    self.boughtItemsPage = 0

    self:updatePlayerItems()
    self:updateBuyGui()
    self:updateBuybackGui()

    self.tabbedWindow:selectTab(self.buyTab)
end

-- send a request to the server for the sold items
function Shop:requestItems() -- client
    self.soldItems = {}
    self.boughtItems = {}

    invokeServerFunction("sendItems", Player().index)
end

-- send sold items to client
function Shop:sendItems(playerIndex) -- server
    invokeClientFunction(Player(playerIndex), "receiveSoldItems", self.soldItems, self.buybackItems)
end

function Shop:receiveSoldItems(sold, buyback) -- client

    self.soldItems = sold
    for i, v in pairs(self.soldItems) do
        local item = self.ItemWrapper(v.item)
        item.amount = v.amount

        self.soldItems[i] = item
    end

    self.buybackItems = buyback
    for i, v in pairs(self.buybackItems) do
        local item = SellableInventoryItem(v.item)
        item.amount = v.amount

        self.buybackItems[i] = item
    end

    self:updatePlayerItems()
    self:updateSellGui()
    self:updateBuyGui()
    self:updateBuybackGui()
end

function Shop:updatePlayerItems() -- client only

    self.boughtItems = {}

    local player = Player()
    local ship = player.craft
    local items = {}
    local owner

    if ship.factionIndex == player.allianceIndex then
        local alliance = player.alliance

        items = alliance:getInventory():getItems()
        owner = alliance
    else
        items = player:getInventory():getItems()
        owner = player
    end

    for index, slotItem in pairs(items) do
        table.insert(self.boughtItems, SellableInventoryItem(slotItem.item, index, owner))
    end

    table.sort(self.boughtItems, SortSellableInventoryItems)
end

function Shop:updateBoughtItem(index, stock) -- client

    if index and stock then
        for i, item in pairs(self.boughtItems) do
            if item.index == index then
                if stock > 0 then
                    item.amount = stock
                else
                    self.boughtItems[i] = nil
                    self:rebuildTables()
                end

                break
            end
        end
    end

    self:updateBuyGui()
    self:updatePlayerItems()
end

-- update the buy tab (the tab where the STATION SELLS)
function Shop:updateSellGui() -- client

    if not self.guiInitialized then return end

    for i, v in pairs(self.soldItemFrames) do v:hide() end
    for i, v in pairs(self.soldItemNameLabels) do v:hide() end
    for i, v in pairs(self.soldItemPriceLabels) do v:hide() end
    for i, v in pairs(self.soldItemMaterialLabels) do v:hide() end
    for i, v in pairs(self.soldItemStockLabels) do v:hide() end
    for i, v in pairs(self.soldItemButtons) do v:hide() end
    for i, v in pairs(self.soldItemIcons) do v:hide() end

    local faction = Faction()
    local buyer = Player()
    local playerCraft = buyer.craft
    if playerCraft.factionIndex == buyer.allianceIndex then
        buyer = buyer.alliance
    end

    for index, item in pairs(self.soldItems) do

        self.soldItemFrames[index]:show()
        self.soldItemNameLabels[index]:show()
        self.soldItemPriceLabels[index]:show()
        self.soldItemMaterialLabels[index]:show()
        self.soldItemStockLabels[index]:show()
        self.soldItemButtons[index]:show()
        self.soldItemIcons[index]:show()

        self.soldItemNameLabels[index].caption = item.name
        self.soldItemNameLabels[index].color = item.rarity.color
        self.soldItemNameLabels[index].bold = false

        if item.material then
            self.soldItemMaterialLabels[index].caption = item.material.name
            self.soldItemMaterialLabels[index].color = item.material.color
        else
            self.soldItemMaterialLabels[index]:hide()
        end

        if item.icon then
            self.soldItemIcons[index].picture = item.icon
            self.soldItemIcons[index].color = item.rarity.color
        end

        local price = self:getSellPriceAndTax(item.price, faction, buyer)
        self.soldItemPriceLabels[index].caption = createMonetaryString(price)

        self.soldItemStockLabels[index].caption = item.amount

    end

end

-- update the sell tab (the tab where the STATION BUYS)
function Shop:updateBuyGui() -- client

    if not self.guiInitialized then return end
    if not self.manageSellAndBuyback then return end

    local numDifferentItems = #self.boughtItems

    while self.boughtItemsPage * self.itemsPerPage >= numDifferentItems do
        self.boughtItemsPage = self.boughtItemsPage - 1
    end

    if self.boughtItemsPage < 0 then
        self.boughtItemsPage = 0
    end

    for i, v in pairs(self.boughtItemFrames) do v:hide() end
    for i, v in pairs(self.boughtItemNameLabels) do v:hide() end
    for i, v in pairs(self.boughtItemPriceLabels) do v:hide() end
    for i, v in pairs(self.boughtItemMaterialLabels) do v:hide() end
    for i, v in pairs(self.boughtItemStockLabels) do v:hide() end
    for i, v in pairs(self.boughtItemButtons) do v:hide() end
    for i, v in pairs(self.boughtItemIcons) do v:hide() end

    local itemStart = self.boughtItemsPage * self.itemsPerPage + 1
    local itemEnd = math.min(numDifferentItems, itemStart + 14)

    local uiIndex = 1

    for index = itemStart, itemEnd do

        local item = self.boughtItems[index]

        if item == nil then
            break
        end

        self.boughtItemFrames[uiIndex]:show()
        self.boughtItemNameLabels[uiIndex]:show()
        self.boughtItemPriceLabels[uiIndex]:show()
        self.boughtItemMaterialLabels[uiIndex]:show()
        self.boughtItemStockLabels[uiIndex]:show()
        self.boughtItemButtons[uiIndex]:show()
        self.boughtItemIcons[uiIndex]:show()

        self.boughtItemNameLabels[uiIndex].caption = item.name
        self.boughtItemNameLabels[uiIndex].color = item.rarity.color
        self.boughtItemNameLabels[uiIndex].bold = false

        local price = Shop.getBuyPrice(item.price)
        self.boughtItemPriceLabels[uiIndex].caption = createMonetaryString(price)

        if item.material then
            self.boughtItemMaterialLabels[uiIndex].caption = item.material.name
            self.boughtItemMaterialLabels[uiIndex].color = item.material.color
        else
            self.boughtItemMaterialLabels[uiIndex]:hide()
        end

        if item.icon then
            self.boughtItemIcons[uiIndex].picture = item.icon
            self.boughtItemIcons[uiIndex].color = item.rarity.color
        end

        self.boughtItemStockLabels[uiIndex].caption = item.amount

        uiIndex = uiIndex + 1
    end

    if itemEnd < itemStart then
        itemEnd = 0
        itemStart = 0
    end

    self.pageLabel.caption = itemStart .. " - " .. itemEnd .. " / " .. numDifferentItems

end

-- update the sell tab (the tab where the STATION BUYS)
function Shop:updateBuybackGui() -- client

    if not self.guiInitialized then return end
    if not self.manageSellAndBuyback then return end

    for i, v in pairs(self.buybackItemFrames) do v:hide() end
    for i, v in pairs(self.buybackItemNameLabels) do v:hide() end
    for i, v in pairs(self.buybackItemPriceLabels) do v:hide() end
    for i, v in pairs(self.buybackItemMaterialLabels) do v:hide() end
    for i, v in pairs(self.buybackItemStockLabels) do v:hide() end
    for i, v in pairs(self.buybackItemButtons) do v:hide() end
    for i, v in pairs(self.buybackItemIcons) do v:hide() end

    for index = 1, math.min(15, #self.buybackItems) do

        local item = self.buybackItems[index]

        self.buybackItemFrames[index]:show()
        self.buybackItemNameLabels[index]:show()
        self.buybackItemPriceLabels[index]:show()
        self.buybackItemMaterialLabels[index]:show()
        self.buybackItemStockLabels[index]:show()
        self.buybackItemButtons[index]:show()
        self.buybackItemIcons[index]:show()

        self.buybackItemNameLabels[index].caption = item.name
        self.buybackItemNameLabels[index].color = item.rarity.color
        self.buybackItemNameLabels[index].bold = false

        local price = Shop.getBuyPrice(item.price)
        self.buybackItemPriceLabels[index].caption = createMonetaryString(price)

        if item.material then
            self.buybackItemMaterialLabels[index].caption = item.material.name
            self.buybackItemMaterialLabels[index].color = item.material.color
        else
            self.buybackItemMaterialLabels[index]:hide()
        end

        if item.icon then
            self.buybackItemIcons[index].picture = item.icon
            self.buybackItemIcons[index].color = item.rarity.color
        end

        self.buybackItemStockLabels[index].caption = item.amount
    end

end

function Shop:onLeftButtonPressed()
    self.boughtItemsPage = self.boughtItemsPage - 1
    self:updateBuyGui()
end

function Shop:onRightButtonPressed()
    self.boughtItemsPage = self.boughtItemsPage + 1
    self:updateBuyGui()
end

function Shop:onBuyButtonPressed(button) -- client
    local itemIndex = 0
    for i, b in pairs(self.soldItemButtons) do
        if button.index == b.index then
            itemIndex = i
        end
    end

    invokeServerFunction("sellToPlayer", itemIndex)
end

function Shop:onSellButtonPressed(button) -- client
    local itemIndex = 0
    for i, b in pairs(self.boughtItemButtons) do
        if button.index == b.index then
            itemIndex = self.boughtItemsPage * self.itemsPerPage + i
        end
    end

    invokeServerFunction("buyFromPlayer", self.boughtItems[itemIndex].index)
end

function Shop:onSellTrashButtonPressed(button)
    invokeServerFunction("buyTrashFromPlayer")
end

function Shop:onBuybackButtonPressed(button) -- client
    local itemIndex = 0
    for i, b in pairs(self.buybackItemButtons) do
        if button.index == b.index then
            itemIndex = i
        end
    end

    invokeServerFunction("sellBackToPlayer", itemIndex)
end


function Shop:add(item_in, amount)
    amount = amount or 1

    local item = self.ItemWrapper(item_in)

    item.name = item.name or ""
    item.price = item.price or 0
    item.amount = amount

    table.insert(self.soldItems, item)

end

function Shop:addFront(item_in, amount)
    local items = self.soldItems
    self.soldItems = {}

    self:add(item_in, amount)

    for _, item in pairs(items) do
        table.insert(self.soldItems, item)
    end

end

function Shop:sellToPlayer(itemIndex) -- server

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources, AlliancePrivilege.AddItems)
    if not buyer then return end

    local station = Entity()

    local item = self.soldItems[itemIndex]
    if item == nil then
        player:sendChatMessage(station.title, 1, "Item to buy not found"%_t)
        return
    end

    local canPay, msg, args = buyer:canPay(item.price)
    if not canPay then
        player:sendChatMessage(station.title, 1, msg, unpack(args))
        return
    end

    -- test the docking last so the player can know what he can buy from afar already
    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to buy items."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to buy items."%_T
    if not CheckPlayerDocked(player, station, errors) then
        return
    end

    local msg, args = item:boughtByPlayer(ship)
    if msg and msg ~= "" then
        player:sendChatMessage(station.title, 1, msg, unpack(args))
        return
    end

    receiveTransactionTax(station, item.price * self.tax)

    buyer:pay("Bought an item for %1% credits."%_T, item.price)

    -- remove item
    item.amount = item.amount - 1
    if item.amount == 0 then
        self.soldItems[itemIndex] = nil
        self:rebuildTables()
    end

    Galaxy():changeFactionRelations(buyer, Faction(), GetRelationChangeFromMoney(item.price))

    -- do a broadcast to all clients that the item is sold out/changed
    broadcastInvokeClientFunction("receiveSoldItems", self.soldItems, self.buybackItems)
end

function Shop:buyFromPlayer(itemIndex) -- server

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.AddResources, AlliancePrivilege.SpendItems)
    if not buyer then return end

    local station = Entity()

    -- test the docking last so the player can know what he can buy from afar already
    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to sell items."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to sell items."%_T
    if not CheckPlayerDocked(player, station, errors) then
        return
    end

    local iitem = buyer:getInventory():find(itemIndex)
    if iitem == nil then
        player:sendChatMessage(station.title, 1, "Item to sell not found."%_t)
        return
    end

    local item = SellableInventoryItem(iitem, itemIndex, buyer)
    item.amount = 1

    local msg, args = item:soldByPlayer(ship)
    if msg and msg ~= "" then
        player:sendChatMessage(station.title, 1, msg, unpack(args))
        return
    end

    -- no transaction tax here since it could be abused by 2 players working together
    -- receiveTransactionTax(station, item.price * 0.25 * self.tax)
    local price = Shop.getBuyPrice(item.price)
    buyer:receive("Sold an item for %1% credits."%_T, price)

    -- insert the item into buyback list
    for i = 14, 1, -1 do
        self.buybackItems[i + 1] = self.buybackItems[i]
    end
    self.buybackItems[1] = item

    broadcastInvokeClientFunction("updateBoughtItem", item.index, item.amount - 1)
    broadcastInvokeClientFunction("receiveSoldItems", self.soldItems, self.buybackItems)
end

function Shop:buyTrashFromPlayer() -- server

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.AddResources, AlliancePrivilege.SpendItems)
    if not buyer then return end

    local station = Entity()

    -- test the docking last so the player can know what he can buy from afar already
    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to sell items."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to sell items."%_T
    if not CheckPlayerDocked(player, station, errors) then
        return
    end

    local items = buyer:getInventory():getItems()

    for index, slotItem in pairs(items) do

        local iitem = slotItem.item
        if iitem == nil then goto continue end
        if not iitem.trash then goto continue end

        local item = SellableInventoryItem(iitem, index, buyer)
        item.amount = 1

        for i = 1, slotItem.amount do
            local msg, args = item:soldByPlayer(ship)
            if msg and msg ~= "" then
                player:sendChatMessage(station.title, 1, msg, unpack(args))
                return
            end

            local price = Shop.getBuyPrice(item.price)
            buyer:receive("Sold an item for %1% credits."%_T, price)

            -- insert the item into buyback list
            for i = 14, 1, -1 do
                self.buybackItems[i + 1] = self.buybackItems[i]
            end
            self.buybackItems[1] = item

            table.insert(self.boughtItems, SellableInventoryItem(slotItem.item, index, owner))
        end

        ::continue::
    end

    broadcastInvokeClientFunction("updateBoughtItem")
    broadcastInvokeClientFunction("receiveSoldItems", self.soldItems, self.buybackItems)
end


function Shop:sellBackToPlayer(itemIndex) -- server

    local buyer, ship, player = getInteractingFaction(callingPlayer, AlliancePrivilege.SpendResources, AlliancePrivilege.AddItems)
    if not buyer then return end

    local station = Entity()

    local item = self.buybackItems[itemIndex]
    if item == nil then
        player:sendChatMessage(station.title, 1, "Item to buy not found"%_t)
        return
    end

    local price = Shop.getBuyPrice(item.price)
    local canPay, msg, args = buyer:canPay(price)
    if not canPay then
        player:sendChatMessage(station.title, 1, msg, unpack(args))
        return
    end

    -- test the docking last so the player can know what he can buy from afar already
    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to buy items."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to buy items."%_T
    if not CheckPlayerDocked(player, station, errors) then
        return
    end

    local msg, args = item:boughtByPlayer(ship)
    if msg and msg ~= "" then
        player:sendChatMessage(station.title, 1, msg, unpack(args))
        return
    end

    -- no transaction tax here since it could be abused by 2 players working together
    -- receiveTransactionTax(station, item.price * 0.25 * self.tax)

    buyer:pay("Bought back an item for %1% credits."%_T, price)

    -- remove item
    item.amount = item.amount - 1
    if item.amount == 0 then
        self.buybackItems[itemIndex] = nil
        self:rebuildTables()
    end

    -- do a broadcast to all clients that the item is sold out/changed
    broadcastInvokeClientFunction("receiveSoldItems", self.soldItems, self.buybackItems)

end

function Shop:rebuildTables() -- server + client
    -- rebuild sold table
    local temp = self.soldItems
    self.soldItems = {}
    for i, item in pairs(temp) do
        table.insert(self.soldItems, item)
    end

    local temp = self.boughtItems
    self.boughtItems = {}
    for i, item in pairs(temp) do
        table.insert(self.boughtItems, item)
    end

    local temp = self.buybackItems
    self.buybackItems = {}
    for i, item in pairs(temp) do
        table.insert(self.buybackItems, item)
    end

end

-- this function gets called whenever the ui window gets rendered, AFTER the window was rendered (client only)
function Shop:renderUI()

    local mouse = Mouse().position

    if self.tabbedWindow:getActiveTab().index == self.buyTab.index then
        for i, frame in pairs(self.soldItemFrames) do

            if self.soldItems[i] ~= nil then
                if frame.visible then

                    local l = frame.lower
                    local u = frame.upper

                    if mouse.x >= l.x and mouse.x <= u.x then
                    if mouse.y >= l.y and mouse.y <= u.y then
                        local renderer = TooltipRenderer(self.soldItems[i]:getTooltip())
                        renderer:drawMouseTooltip(Mouse().position)
                    end
                    end
                end
            end
        end

    elseif self.tabbedWindow:getActiveTab().index == self.sellTab.index then

        for i, frame in pairs(self.boughtItemFrames) do

            local index = i + self.boughtItemsPage * self.itemsPerPage

            if self.boughtItems[index] ~= nil then
                if frame.visible then

                    local l = frame.lower
                    local u = frame.upper

                    if mouse.x >= l.x and mouse.x <= u.x then
                    if mouse.y >= l.y and mouse.y <= u.y then
                        local renderer = TooltipRenderer(self.boughtItems[index]:getTooltip())
                        renderer:drawMouseTooltip(Mouse().position)
                    end
                    end
                end
            end
        end

    elseif self.tabbedWindow:getActiveTab().index == self.buyBackTab.index then

        for i, frame in pairs(self.buybackItemFrames) do

            if self.buybackItems[i] ~= nil then
                if frame.visible then

                    local l = frame.lower
                    local u = frame.upper

                    if mouse.x >= l.x and mouse.x <= u.x then
                    if mouse.y >= l.y and mouse.y <= u.y then
                        local renderer = TooltipRenderer(self.buybackItems[i]:getTooltip())
                        renderer:drawMouseTooltip(Mouse().position)
                    end
                    end
                end
            end
        end

    end
end

function Shop:getSellPriceAndTax(price, stationFaction, buyerFaction)
    local taxAmount = round(price * self.tax)

    if stationFaction.index == buyerFaction.index then
        price = price - taxAmount
        -- don't pay out for the second time
        taxAmount = 0
    end

    return price, taxAmount
end

function Shop.getBuyPrice(price)
    -- buying items from players yields no tax income for the buying station
    return price * 0.25
end

PublicNamespace.CreateShop = setmetatable({new = new}, {__call = function(_, ...) return new(...) end})

function PublicNamespace.CreateNamespace()
    local result = {}

    local shop = PublicNamespace.CreateShop()

    shop.shared = PublicNamespace
    result.shop = shop
    result.onShowWindow = function(...) return shop:onShowWindow(...) end
    result.sendItems = function(...) return shop:sendItems(...) end
    result.receiveSoldItems = function(...) return shop:receiveSoldItems(...) end
    result.sellToPlayer = function(...) return shop:sellToPlayer(...) end
    result.buyFromPlayer = function(...) return shop:buyFromPlayer(...) end
    result.buyTrashFromPlayer = function(...) return shop:buyTrashFromPlayer(...) end
    result.sellBackToPlayer = function(...) return shop:sellBackToPlayer(...) end
    result.updateBoughtItem = function(...) return shop:updateBoughtItem(...) end
    result.onLeftButtonPressed = function(...) return shop:onLeftButtonPressed(...) end
    result.onRightButtonPressed = function(...) return shop:onRightButtonPressed(...) end
    result.onBuyButtonPressed = function(...) return shop:onBuyButtonPressed(...) end
    result.onSellButtonPressed = function(...) return shop:onSellButtonPressed(...) end
    result.onSellTrashButtonPressed = function(...) return shop:onSellTrashButtonPressed(...) end
    result.onBuybackButtonPressed = function(...) return shop:onBuybackButtonPressed(...) end
    result.renderUI = function(...) return shop:renderUI(...) end
    result.add = function(...) return shop:add(...) end
    result.addFront = function(...) return shop:addFront(...) end

    return result
end

return PublicNamespace
