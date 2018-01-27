package.path = package.path .. ";data/scripts/lib/?.lua"
require ("utility")

function ArmedObjectPrice(object)

    local costFactor = 1.0

    -- collect turret stats
    local dps = object.dps
    local material = object.material

    if object.coolingType == 0 and object.heatPerShot > 0 then
        dps = dps * object.shootingTime / (object.shootingTime + object.coolingTime)
    end

    dps = dps + dps * object.shieldDamageMultiplicator + dps * object.hullDamageMultiplicator

    dps = dps + object.hullRepairRate * 2.0 + object.shieldRepairRate * 3.0
    dps = dps + math.abs(object.selfForce) * 0.005 + math.abs(object.otherForce) * 0.01

    local value = dps * 0.5 * object.reach * 0.5

    -- mining laser value scales with the used material and the efficiency
    if object.stoneEfficiency > 0 then
        costFactor = 3.0

        local materialFactor = material.strengthFactor * 5.0
        local efficiencyFactor = object.stoneEfficiency * 8.0

        value = value * materialFactor
        value = value * (1.0 + efficiencyFactor)
    end

    if object.metalEfficiency > 0 then
        costFactor = 3.0

        local efficiencyFactor = object.metalEfficiency * 8.0
        value = value * (1.0 + efficiencyFactor)
    end

    -- rocket launchers gain value if they fire seeker rockets
    if object.seeker then
        value = value * 2.5
    end

    --value = value * 1.5
    local rarityFactor = 1.0 + 1.35 ^ object.rarity.value

    value = value * rarityFactor
    value = value * (1.0 + object.shieldPenetration)
    value = value * costFactor

    -- check for numerical errors that can occur by changing weapon stats to things like NaN or inf
    value = math.max(0, value)
    if value ~= value then value = 0 end
    if not (value > -math.huge and value < math.huge) then value = 0 end

    return value
end

function FighterPrice(fighter)
    local value = ArmedObjectPrice(fighter) * 3.0

    if value == 0 then
        value = 100000
    end

    -- the smaller the fighter, the more expensive
    local sizeFactor = lerp(fighter.diameter, 1, 2, 1.3, 1)
    value = value * sizeFactor

    -- durability of 100 makes the fighter twice as expensive, 200 three times etc.
    local hpFactor = fighter.durability / 150 + 1
    value = value * hpFactor

    -- speed of 20 is median, above makes it more expensive, below makes it cheaper
    local speedFactor = fighter.maxVelocity / 40
    value = value * speedFactor

    -- maneuverability of 2 is median, above makes it more expensive, below makes it cheaper
    local maneuverFactor = fighter.turningSpeed / 2
    value = value * maneuverFactor

    value = round(value)

    return value
end
