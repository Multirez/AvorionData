
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

SectorGenerator = require ("SectorGenerator")
PirateGenerator = require ("pirategenerator")
Placer = require("placer")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y)
    return 100
end

function SectorTemplate.offgrid(x, y)
    return true
end

-- this function returns whether or not a sector should have space gates
function SectorTemplate.gates(x, y)
    return false
end

-- player is the player who triggered the creation of the sector (only set in start sector, otherwise nil)
function SectorTemplate.generate(player, seed, x, y)
    math.randomseed(seed);

    local generator = SectorGenerator(x, y)

    local numFields = math.random(2, 4)

    for i = 1, numFields do
        generator:createAsteroidField();
    end

    local numAsteroids = math.random(2, 4)
    for i = 1, numAsteroids do
        generator:createBigAsteroid();
    end

    local numSmallFields = math.random(6, 10)
    for i = 1, numSmallFields do
        generator:createSmallAsteroidField()
    end

    -- create pirate ships 1
    local numShips = math.random(5, 7)

    for i = 1, numShips do
        PirateGenerator.createPirate(generator:getPositionInSector(5000))
    end

    -- create pirate ships 2
    local numShips = math.random(5, 7)

    PirateGenerator.pirateLevel = Balancing_GetPirateLevel(x, y) - 1

    for i = 1, numShips do
        PirateGenerator.createPirate(generator:getPositionInSector(5000))
    end

    local numAsteroids = math.random(1, 3)
    for i = 1, numAsteroids do
        local mat = generator:createAsteroidField()
        local asteroid = generator:createClaimableAsteroid()
        asteroid.position = mat
    end

    if math.random() < generator:getWormHoleProbability() then generator:createRandomWormHole() end

    Sector():addScript("data/scripts/sector/eventscheduler.lua", "events/pirateattack.lua")
    Sector():addScript("data/scripts/sector/respawnresourceasteroids.lua")

    generator:addOffgridAmbientEvents()
    Placer.resolveIntersections()
end

return SectorTemplate
