package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

SectorGenerator = require ("SectorGenerator")
Placer = require("placer")
require("stringutility")

local SectorTemplate = {}

-- must be defined, will be used to get the probability of this sector
function SectorTemplate.getProbabilityWeight(x, y)
    return 75
end

function SectorTemplate.offgrid(x, y)
    return true
end

-- this function returns whether or not a sector should have space gates
function SectorTemplate.gates(x, y)
    return false
end

local leaderName = { "Priest"%_t, "Father"%_t, "Bishop"%_t, "Abbot"%_t, "Apostle"%_t, "Elder"%_t, "Pastor"%_t, "Abhyasi"%_t,
"Bhagat"%_t, "Guru"%_t, "Saint"%_t, "Ayatollah"%_t, "Imam"%_t, "Rabbi"%_t, "Druid"%_t}

-- player is the player who triggered the creation of the sector (only set in start sector, otherwise nil)
function SectorTemplate.generate(player, seed, x, y)
    math.randomseed(seed);

    local generator = SectorGenerator(x, y)

    local language = Language(Seed(makeFastHash(seed.value, x, y)))
    local factionName = language:getFactionName()

    local faction = Galaxy():findFaction(factionName)
    if not faction then
        faction = Galaxy():createFaction(factionName, x / 2, y / 2)
    end

    -- create big asteroid in the center
    local matrix = generator:getPositionInSector(1000);
    local asteroid = generator:createBigAsteroid(matrix)

    -- create asteroid rings
    local radius = 300
    local angle = 0

    for i = 1, getInt(1, 3) do
        radius = radius + getFloat(300, 500)
        local ringMatrix = generator:getUniformPositionInSector(0)
        ringMatrix.pos = matrix.pos

        for i = 0, (getInt(70, 100)) do
            local size = getFloat(5, 15)
            local asteroidPos = vec3(math.cos(angle), math.sin(angle), 0) * (radius + getFloat(0, 10))
            asteroidPos = ringMatrix:transformCoord(asteroidPos)

            generator:createSmallAsteroid(asteroidPos, size, 0, generator:getAsteroidType())
            angle = angle + getFloat(1, 2)
        end
    end

    -- create cultist ships
    local cultistCount = getInt(6, 12)
    local cultistRadius = getFloat(200, 600)
    local cultists = {}

    for i = 1, cultistCount do
        local angle = 2 * math.pi * i / cultistCount
        local cultistLook = vec3(math.cos(angle), math.sin(angle), 0)
        local cultistMatrix = MatrixLookUpPosition(-cultistLook, matrix.up,
                                                   matrix.pos + cultistLook * cultistRadius)

        local volume = Balancing_GetSectorShipVolume(Sector():getCoordinates()) * Balancing_GetShipVolumeDeviation()
        local ship
        if i == 1 then
            ship = ShipGenerator.createMilitaryShip(faction, cultistMatrix, volume * 3)
            ship:addScript("dialogs/encounters/cultistleader.lua")
            ship.title = leaderName[getInt(1, #leaderName)]
        else
            ship = ShipGenerator.createMilitaryShip(faction, cultistMatrix, volume)
        end

        table.insert(cultists, ship.index.string)
    end


    Sector():addScript("data/scripts/sector/eventscheduler.lua", "events/pirateattack.lua")
    Sector():addScript("data/scripts/sector/cultistbehavior.lua", matrix, asteroid.index.string, unpack(cultists))

    generator:addOffgridAmbientEvents()
    Placer.resolveIntersections()
end

return SectorTemplate
