package.path = package.path .. ";data/scripts/lib/?.lua"
require ("sellableinventoryitem")

local SellableFighterItem = {}
SellableFighterItem.__index = SellableFighterItem

local function new(fighter, index, player)
    local obj = setmetatable({fighter = fighter, item = fighter, index = index}, SellableFighterItem)

    -- initialize the item
    obj.price = obj:getPrice()
    obj.rarity = obj.fighter.rarity
    obj.material = obj.fighter.material

    if fighter.type == FighterType.CargoShuttle then
        obj.name = "Cargo Shuttle"%_t
        obj.icon = "data/textures/icons/wooden-crate.png"
    elseif fighter.type == FighterType.Fighter then
        obj.name = "${weaponPrefix} Fighter"%_t % {weaponPrefix = obj.fighter.weaponPrefix}
        obj.icon = obj.fighter.weaponIcon
    end

    if player and index then
        obj.amount = player:getInventory():amount(index)
    elseif index and type(index) == "number" then
        obj.amount = index
    else
        obj.amount = 1
    end

    return obj
end

function SellableFighterItem:getTooltip()

    if self.tooltip == nil then
        self.tooltip = makeFighterTooltip(self.fighter)
    end

    return self.tooltip
end

function SellableFighterItem:getPrice()
    return FighterPrice(self.fighter)
end

function SellableFighterItem:boughtByPlayer(ship)

    local hangar = Hangar(ship.index)

    if not hangar then
        return "Your ship doesn't have a hangar."%_t, {}
    end

    -- check if there is enough space in ship
    if hangar.freeSpace < self.fighter.volume then
        return "You don't have enough space in your hangar."%_t, {}
    end

    -- find a squad that has space for a fighter
    local squads = {hangar:getSquads()}

    local squad
    for _, i in pairs(squads) do
        local fighters = hangar:getSquadFighters(i)
        local free = hangar:getSquadFreeSlots(i)

        if free > 0 then
            squad = i
            break
        end
    end

    if squad == nil then
        return "There is no free squad to place the fighter in."%_t, {}
    end

    hangar:addFighter(squad, self.fighter)
end

function SellableFighterItem:soldByPlayer(ship)

    local hangar = Hangar(ship.index)

    if not hangar then
        return "Your ship doesn't have a hangar."%_t, {}
    end

    self.fighter = hangar:getFighter(self.squadIndex, self.fighterIndex)

    if self.fighter == nil then
        return "Fighter to sell not found"%_t, {}
    end

    local price = getFighterPrice(fighter) / 8.0
    hangar:removeFighter(self.squadIndex, self.fighterIndex)

end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
