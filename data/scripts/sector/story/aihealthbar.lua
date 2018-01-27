
-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AIHealthBar
AIHealthBar = {}

local ais = {}
local fakeEndboss

local maxHealth = 1;
local health = 0;
local maxShield = 1;
local shield = 0;

if onClient() then

function AIHealthBar.getUpdateInterval()
    return 0.15
end


function AIHealthBar.initialize()

end

function AIHealthBar.updateClient(timePassed)

    health = 0
    shield = 0

    local maxHealthSum = 0
    local maxShieldSum = 0

    local entities = {Sector():getEntitiesByType(EntityType.Ship)}
    for _, entity in pairs(entities) do
        if entity:hasScript("aibehaviour.lua") then

            health = health + entity.durability
            shield = shield + entity.shieldDurability

            maxHealthSum = maxHealthSum + entity.maxDurability
            maxShieldSum = maxShieldSum + entity.shieldMaxDurability
        end
    end

    maxHealth = math.max(maxHealth, maxHealthSum)
    maxShield = math.max(maxShield, maxShieldSum)

    if health > 0 or shield > 0 then
        registerBoss(Uuid())
        setBossHealth(Uuid(), health, maxHealth, shield, maxShield)
    else
        unregisterBoss(Uuid())
        invokeServerFunction("terminateServer")
    end
end

end

function AIHealthBar.terminateServer()
    terminate()
end



