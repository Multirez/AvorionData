package.path = package.path .. ";data/scripts/lib/?.lua"

require ("galaxy")
require ("randomext")
local PlanGenerator = require ("plangenerator")

local rand = random()

local FighterGenerator =  {}

function FighterGenerator.initialize(seed)
    if seed then
        rand = Random(seed)
    end
end

function FighterGenerator.generate(x, y, offset_in, rarity_in, type_in, material_in) -- server

    local offset = offset_in or 0
    local seed = rand:createSeed()
    local dps = 0
    local sector = math.floor(length(vec2(x, y))) + offset

    local weaponDPS, weaponTech = Balancing_GetSectorWeaponDPS(sector, 0)
    local miningDPS, miningTech = Balancing_GetSectorMiningDPS(sector, 0)
    local materialProbabilities = Balancing_GetMaterialProbability(sector, 0)
    local material = material_in or Material(getValueFromDistribution(materialProbabilities))
    local weaponType = type_in or getValueFromDistribution(Balancing_GetWeaponProbability(sector, 0))

    miningDPS = miningDPS * 0.5
    weaponDPS = weaponDPS * 0.3

    local tech = 0
    if weaponType == WeaponType.MiningLaser then
        dps = miningDPS
        tech = miningTech
    elseif weaponType == WeaponType.ForceGun then
        dps = random():getFloat(800, 1200); -- force
        tech = weaponTech
    else
        dps = weaponDPS
        tech = weaponTech
    end

    local rarities = {}
    rarities[5] = 0.2 -- legendary
    rarities[4] = 1 -- exotic
    rarities[3] = 4 -- exceptional
    rarities[2] = 8 -- rare
    rarities[1] = 16 -- uncommon
    rarities[0] = 64 -- common

    local rarity = rarity_in or Rarity(getValueFromDistribution(rarities))

    return GenerateFighterTemplate(seed, weaponType, dps, tech, rarity, material)
end

function FighterGenerator.generateArmed(x, y, offset_in, rarity_in, material_in) -- server

    local offset = offset_in or 0
    local sector = math.floor(length(vec2(x, y))) + offset
    local types = Balancing_GetWeaponProbability(sector, 0)

    types[WeaponType.RepairBeam] = nil
    types[WeaponType.MiningLaser] = nil
    types[WeaponType.SalvagingLaser] = nil
    types[WeaponType.ForceGun] = nil

    local weaponType = getValueFromDistribution(types)

    return FighterGenerator.generate(x, y, offset_in, rarity_in, weaponType, material_in)
end

function FighterGenerator.generateCargoShuttle(x, y, material_in) -- server

    local seed = rand:createSeed()

    local materialProbabilities = Balancing_GetMaterialProbability(x, y)
    local material = material_in or Material(getValueFromDistribution(materialProbabilities))

    local fighter = GenerateFighterTemplate(seed, nil, 0, 0, Rarity(), material)

    local plan = fighter.plan
    local container = PlanGenerator.makeContainerPlan()

    local size = 0.95 / container.radius
    container:scale(vec3(size, size, size))
    container:displace(vec3(0, -0.7, 0))
    plan:addPlan(plan.rootIndex, container, container.rootIndex)

    fighter.plan = plan
    fighter.type = FighterType.CargoShuttle

    return fighter
end

return FighterGenerator
