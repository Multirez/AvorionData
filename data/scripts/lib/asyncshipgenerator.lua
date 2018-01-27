package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

require ("galaxy")
require ("utility")
require ("defaultscripts")
require ("goods")
local PlanGenerator = require ("plangenerator")
local FighterGenerator = require ("fightergenerator")
local ShipUtility = require ("shiputility")

local ShipGenerator = {}

-- since this local variable can be used in multiple scripts in the same lua_State, a single callback function isn't enough
-- we use a table that has a unique id per generator
local generators = {}
local AsyncShipGenerator = {}
AsyncShipGenerator.__index = AsyncShipGenerator

local function onShipCreated(generatorId, ship)
    local self = generators[generatorId]

    if self.expected > 0 then
        table.insert(self.generated, ship)
        self:tryBatchCallback()
    elseif not self.batching then -- don't callback single creations batching
        if self.callback then
            self.callback(ship)
        end
    end
end

local function finalizeShip(ship)
    ship.crew = ship.minCrew
    ship.shieldDurability = ship.shieldMaxDurability

    AddDefaultShipScripts(ship)
end



function AsyncShipGenerator:createShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncShipPlan("_ship_generator_on_ship_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onShipPlanFinished(plan, generatorId, position, factionIndex)
    local faction = Faction(factionIndex)
    local ship = Sector():createShip(faction, "", plan, position)

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createDefender(faction, position)
    position = position or Matrix()

    -- defenders should be a lot beefier than the normal ships
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates()) * 10

    PlanGenerator.makeAsyncShipPlan("_ship_generator_on_defender_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onDefenderPlanFinished(plan, generatorId, position, factionIndex)
    local faction = Faction(factionIndex)
    local ship = Sector():createShip(faction, "", plan, position)

    local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates()) * 1.5 + 3

    ShipUtility.addArmedTurretsToCraft(ship, turrets)
    ship.title = ShipUtility.getMilitaryNameByVolume(ship.volume)

    ship:addScript("ai/patrol.lua")
    ship:addScript("antismuggle.lua")
    ship:setValue("is_armed", 1)

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createCarrier(faction, position, fighters)
    position = position or Matrix()
    fighters = fighters or 10
    -- carriers should be even beefier than the defenders
    local volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncCarrierPlan("_ship_generator_on_carrier_plan_generated", {self.generatorId, position, faction.index, fighters}, faction, volume)
    self:shipCreationStarted()
end

local function onCarrierPlanFinished(plan, generatorId, position, factionIndex, fighters)
    local faction = Faction(factionIndex)
    local ship = Sector():createShip(faction, "", plan, position)

    -- add fighters
    local hangar = Hangar(ship.index)
    hangar:addSquad("Alpha")
    hangar:addSquad("Beta")
    hangar:addSquad("Gamma")

    local numFighters = 0
    for squad = 0, 2 do
        local fighter = FighterGenerator.generateArmed(faction:getHomeSectorCoordinates())
        for i = 1, 7 do
            hangar:addFighter(squad, fighter)

            numFighters = numFighters + 1
            if numFighters >= fighters then break end
        end

        if numFighters >= fighters then break end
    end

    local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates())

    ShipUtility.addArmedTurretsToCraft(ship, turrets)
    ship.title = ShipUtility.getMilitaryNameByVolume(ship.volume)

    ship:addScript("ai/patrol.lua")
    ship:setValue("is_armed", 1)

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createMilitaryShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncShipPlan("_ship_generator_on_military_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onMilitaryPlanFinished(plan, generatorId, position, factionIndex)
    local faction = Faction(factionIndex)
    local ship = Sector():createShip(faction, "", plan, position)

    local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates())

    ShipUtility.addArmedTurretsToCraft(ship, turrets)
    ship.title = ShipUtility.getMilitaryNameByVolume(ship.volume)
    ship:setValue("is_armed", 1)

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createTradingShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncShipPlan("_ship_generator_on_trader_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onTraderPlanFinished(plan, generatorId, position, factionIndex)
    local faction = Faction(factionIndex)
    local ship = Sector():createShip(faction, "", plan, position)

    if math.random() < 0.5 then
        local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates())
        ShipUtility.addArmedTurretsToCraft(ship, turrets)
    end

    ship.title = ShipUtility.getTraderNameByVolume(ship.volume)

    ship:addScript("civilship.lua")
    ship:addScript("dialogs/storyhints.lua")
    ship:setValue("is_civil", 1)

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createFreighterShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncFreighterPlan("_ship_generator_on_freighter_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onFreighterPlanFinished(plan, generatorId, position, factionIndex)
    local faction = Faction(factionIndex)
    local ship = Sector():createShip(faction, "", plan, position)

    if math.random() < 0.5 then
        local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates())

        ShipUtility.addArmedTurretsToCraft(ship, turrets)
    end

    ship.title = ShipUtility.getFreighterNameByVolume(ship.volume)

    ship:addScript("civilship.lua")
    ship:addScript("dialogs/storyhints.lua")
    ship:setValue("is_civil", 1)

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:createMiningShip(faction, position, volume)
    position = position or Matrix()
    volume = volume or Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()

    PlanGenerator.makeAsyncShipPlan("_ship_generator_on_mining_plan_generated", {self.generatorId, position, faction.index}, faction, volume)
    self:shipCreationStarted()
end

local function onMiningPlanFinished(plan, generatorId, position, factionIndex)
    local faction = Faction(factionIndex)
    local ship = Sector():createShip(faction, "", plan, position)

    local turrets = Balancing_GetEnemySectorTurrets(Sector():getCoordinates())

    ShipUtility.addUnarmedTurretsToCraft(ship, turrets)
    ship.title = ShipUtility.getMinerNameByVolume(ship.volume)

    ship:addScript("civilship.lua")
    ship:addScript("dialogs/storyhints.lua")
    ship:setValue("is_civil", 1)

    finalizeShip(ship)
    onShipCreated(generatorId, ship)
end



function AsyncShipGenerator:startBatch()
    self.batching = true
    self.generated = {}
    self.expected = 0
end

function AsyncShipGenerator:endBatch()
    self.batching = false

    -- it's possible all callbacks happened already before endBatch() is called
    self:tryBatchCallback()
end

function AsyncShipGenerator:shipCreationStarted()
    if self.batching then
        self.expected = self.expected + 1
    end
end

function AsyncShipGenerator:tryBatchCallback()

    -- don't callback while batching or when no ships were generated (yet)
    if not self.batching and self.expected > 0 and #self.generated == self.expected then
        if self.callback then
            self.callback(self.generated)
        end
    end

end


local function new(namespace, onGeneratedCallback)
    local instance = {}
    instance.generatorId = random():getInt()
    instance.expected = 0
    instance.batching = false
    instance.generated = {}
    instance.callback = onGeneratedCallback

    while generators[instance.generatorId] do
        instance.generatorId = random():getInt()
    end

    generators[instance.generatorId] = instance

    if namespace then
        assert(type(namespace) == "table")
    end

    if onGeneratedCallback then
        assert(type(onGeneratedCallback) == "function")
    end

    -- use a completely different naming schedule with underscores to increase probability that this is never used by anything else
    if namespace then
        namespace._ship_generator_on_ship_plan_generated = onShipPlanFinished
        namespace._ship_generator_on_defender_plan_generated = onDefenderPlanFinished
        namespace._ship_generator_on_carrier_plan_generated = onCarrierPlanFinished
        namespace._ship_generator_on_freighter_plan_generated = onFreighterPlanFinished
        namespace._ship_generator_on_military_plan_generated = onMilitaryPlanFinished
        namespace._ship_generator_on_trader_plan_generated = onTraderPlanFinished
        namespace._ship_generator_on_mining_plan_generated = onMiningPlanFinished
    else
        -- use global variables
        _ship_generator_on_ship_plan_generated = onShipPlanFinished
        _ship_generator_on_defender_plan_generated = onDefenderPlanFinished
        _ship_generator_on_carrier_plan_generated = onCarrierPlanFinished
        _ship_generator_on_freighter_plan_generated = onFreighterPlanFinished
        _ship_generator_on_military_plan_generated = onMilitaryPlanFinished
        _ship_generator_on_trader_plan_generated = onTraderPlanFinished
        _ship_generator_on_mining_plan_generated = onMiningPlanFinished
    end

    return setmetatable(instance, AsyncShipGenerator)
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
