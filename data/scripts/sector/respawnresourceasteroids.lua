if onServer() then

package.path = package.path .. ";data/scripts/lib/?.lua"
local SectorGenerator = require("SectorGenerator")
local Placer = require("placer")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace RespawnResourceAsteroids
RespawnResourceAsteroids = {}

function RespawnResourceAsteroids.initialize()

    local richAsteroids = {Sector():getEntitiesByComponent(ComponentType.MineableMaterial)}
    if #richAsteroids >= 5 then return end

    -- respawn them
    local asteroids = {Sector():getEntitiesByType(EntityType.Asteroid)}
    local generator = SectorGenerator(Sector():getCoordinates())

    local spawned = {}

    for _, asteroid in pairs(asteroids) do

        local sphere = Sphere(asteroid.translationf, 200.0)
        local others = {Sector():getEntitiesByLocation(sphere)}

        local numEmptyAsteroids = 0
        if #others >= 20 then
            for _, entity in pairs(others) do
                if entity:hasComponent(ComponentType.MineableMaterial) then
                    numEmptyAsteroids = 0
                    break
                end

                if entity.type == EntityType.Asteroid then
                    numEmptyAsteroids = numEmptyAsteroids + 1
                end
            end
        end

        if numEmptyAsteroids >= 20 then
            local translation = sphere.center + random():getDirection() * sphere.radius
            local size = random():getFloat(5.0, 15.0)

            local asteroid = generator:createSmallAsteroid(translation, size, true, generator:getAsteroidType())

            table.insert(spawned, asteroid)
        end
    end

    Placer.resolveIntersections(spawned)
end


end
