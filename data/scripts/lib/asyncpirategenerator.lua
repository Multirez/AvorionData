package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

require ("galaxy")
require ("stringutility")
local PlanGenerator = require ("plangenerator")
local ShipUtility = require ("shiputility")

-- since this local variable can be used in multiple scripts in the same lua_State, a single callback function isn't enough
-- we use a table that has a unique id per generator
local generators = {}
local AsyncPirateGenerator = {}
AsyncPirateGenerator.__index = AsyncPirateGenerator

local function onPlanGenerated(plan, generatorId, position, factionIndex, turretFactor, title)

    local faction = Faction(factionIndex)
    local ship = Sector():createShip(faction, "", plan, position)

    -- turrets should also scale with pirate strength, but every pirate must have at least 1 turret
    local turrets = math.max(2, math.floor(Balancing_GetEnemySectorTurrets(x, y) * turretFactor))

    ShipUtility.addArmedTurretsToCraft(ship, turrets)

    ship.crew = ship.minCrew
    ship.title = title
    ship.shieldDurability = ship.shieldMaxDurability

    ShipAI(ship.index):setAggressive()

    ship:setValue("is_pirate", 1)

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

    -- use a completely different naming scheme with underscores to increase probability that this is never used by anything else
    if namespace then
        namespace._pirate_generator_on_plan_generated = onPlanGenerated
    else
        -- assign a global variable
        _pirate_generator_on_plan_generated = onPlanGenerated
    end

    return setmetatable(instance, AsyncPirateGenerator)
end

function AsyncPirateGenerator:create(position, volumeFactor, turretFactor, title)

    if self.batching then
        self.expected = self.expected + 1
    end

    position = position or Matrix()
    local x, y = Sector():getCoordinates()
    self.pirateLevel = self.pirateLevel or Balancing_GetPirateLevel(x, y)

    local faction = Galaxy():getPirateFaction(self.pirateLevel)
    local volume = Balancing_GetSectorShipVolume(x, y) * volumeFactor;

    PlanGenerator.makeAsyncShipPlan("_pirate_generator_on_plan_generated", {self.generatorId, position, faction.index, turretFactor, title}, faction, volume)
end

function AsyncPirateGenerator:startBatch()
    self.batching = true
    self.generated = {}
    self.expected = 0
end

function AsyncPirateGenerator:endBatch()
    self.batching = false

    -- it's possible all callbacks happened already before endBatch() is called
    self:tryBatchCallback()
end

function AsyncPirateGenerator:tryBatchCallback()

    -- don't callback while batching or when no ships were generated (yet)
    if not self.batching and self.expected > 0 and #self.generated == self.expected then
        if self.callback then
            self.callback(self.generated)
        end
    end

end

function AsyncPirateGenerator:createScaledOutlaw(position)
    local scaling = self:getScaling()
    return self:create(position, 0.75 * scaling, 0.25, "Outlaw"%_t)
end

function AsyncPirateGenerator:createScaledBandit(position)
    local scaling = self:getScaling()
    return self:create(position, 1.0 * scaling, 0.5, "Bandit"%_t)
end

function AsyncPirateGenerator:createScaledPirate(position)
    local scaling = self:getScaling()
    return self:create(position, 1.5 * scaling, 0.65, "Pirate"%_t)
end

function AsyncPirateGenerator:createScaledMarauder(position)
    local scaling = self:getScaling()
    return self:create(position, 2.0 * scaling, 0.75, "Marauder"%_t)
end

function AsyncPirateGenerator:createScaledRaider(position)
    local scaling = self:getScaling()
    return self:create(position, 4.0 * scaling, 1.0, "Raider"%_t)
end

function AsyncPirateGenerator:createScaledBoss(position)
    local scaling = self:getScaling()
    return self:create(position, 30.0 * scaling, 1.5, "Pirate Mothership"%_t)
end


function AsyncPirateGenerator:createOutlaw(position)
    return self:create(position, 0.75, 0.5, "Outlaw"%_t)
end

function AsyncPirateGenerator:createBandit(position)
    return self:create(position, 1.0, 1.0, "Bandit"%_t)
end

function AsyncPirateGenerator:createPirate(position)
    return self:create(position, 1.5, 1.0, "Pirate"%_t)
end

function AsyncPirateGenerator:createMarauder(position)
    return self:create(position, 2.0, 1.25, "Marauder"%_t)
end

function AsyncPirateGenerator:createRaider(position)
    return self:create(position, 4.0, 1.5, "Raider"%_t)
end

function AsyncPirateGenerator:createBoss(position)
    return self:create(position, 30.0, 2.0, "Pirate Mothership"%_t)
end

function AsyncPirateGenerator:getScaling()
    local scaling = Sector().numPlayers

    if scaling == 0 then scaling = 1 end
    return scaling
end

function AsyncPirateGenerator:getPirateFaction()
    local x, y = Sector():getCoordinates()
    self.pirateLevel = self.pirateLevel or Balancing_GetPirateLevel(x, y)
    return Galaxy():getPirateFaction(self.pirateLevel)
end

return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})
