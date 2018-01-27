package.path = package.path .. ";data/scripts/lib/?.lua"

require ("galaxy")
require ("stringutility")
require ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace AntiSmuggle
AntiSmuggle = {}

local suspicion

local values = {}
values.timeOut = 60

local scannerTicker = 0
local scannerTick = 10


function AntiSmuggle.initialize()
    if onServer() then
        Sector():registerCallback("onEntityDestroyed", "onDestroyed")

        scannerTicker = random():getInt(0, scannerTick)
    end
end

function AntiSmuggle.getUpdateInterval()
    return 1.0
end

function AntiSmuggle.updateServer(timeStep)
    AntiSmuggle.updateSuspiciousShipDetection(timeStep)
    AntiSmuggle.updateSuspicionDetectedBehaviour(timeStep)
end

function AntiSmuggle.updateSuspiciousShipDetection(timeStep)

    scannerTicker = scannerTicker + timeStep

    -- scan for suspicious ships
    if scannerTicker < scannerTick then return end
    scannerTicker = 0

    if suspicion then return end

    local self = Entity()
    local sphere = self:getBoundingSphere()

    local scannerDistance = 400.0

    local selfFaction = Faction()
    sphere.radius = scannerDistance * (1.0 + 0.5 * selfFaction:getTrait("paranoid"))

    local entities = {Sector():getEntitiesByLocation(sphere)}
    for _, ship in pairs(entities) do

        if suspicion then break end
        if not ship.factionIndex then break end
        if ship.factionIndex == 0 then break end

        if ship.index ~= self.index then

            local faction = Faction(ship.factionIndex)
            if valid(faction) and not faction.isAIFaction and selfFaction:getRelations(faction.index) >= -40000 then -- TODO replace constant

                if ship:hasComponent(ComponentType.CargoBay) then

                    -- look for cargo transport licenses
                    local vanillaItems = faction:getInventory():getItemsByType(InventoryItemType.VanillaItem)

                    local licenseLevel = -2

                    for _, p in pairs(vanillaItems) do
                        local item = p.item
                        if item:getValue("isCargoLicense") == true then
                            if item:getValue("faction") == self.factionIndex then
                                licenseLevel = math.max(licenseLevel, item.rarity.value)
                            end
                        end
                    end

                    for good, amount in pairs(ship:getCargos()) do
                        local payment = 0.0

                        if good.suspicious and licenseLevel < 1 then
                            suspicion = suspicion or {type = 0}
                            payment = 1.5
                        end

                        if good.illegal and licenseLevel < 3 then
                            suspicion = suspicion or {type = 1}
                            payment = 2.0
                        end

                        if good.stolen and licenseLevel < 2 then
                            suspicion = suspicion or {type = 2}
                            payment = 3.0
                        end

                        if good.dangerous and licenseLevel < 0 then
                            suspicion = suspicion or {type = 3}
                            payment = 1.5
                        end

                        -- make sure this craft is not yet suspected by another defender
                        local suspectedBy = Sector():getValue(string.format("%s_is_under_suspicion", ship.index.string))
                        if suspectedBy then suspicion = nil end

                        if suspicion then
                            suspicion.ship = ship
                            suspicion.index = ship.index

                            local pilots = {ship:getPilotIndices()}
                            if #pilots > 0 then
                                suspicion.player = Player(pilots[1])
                            end

                            suspicion.factionIndex = ship.factionIndex
                            suspicion.fine = (suspicion.fine or 0) + (good.price * amount + 1500 * Balancing_GetSectorRichnessFactor(Sector():getCoordinates())) * payment
                            suspicion.fine = suspicion.fine * (1.0 + 0.5 * selfFaction:getTrait("greedy"))

                            suspicion.fine = math.floor(suspicion.fine / 100) * 100

                            suspicion.licenseLevel = licenseLevel
                        end
                    end
                end
            end
        end
    end

    if suspicion then
        -- register the suspicion
        Sector():setValue(string.format("%s_is_under_suspicion", suspicion.index.string), self.index.string)
    end

end

function AntiSmuggle.updateSuspicionDetectedBehaviour(timeStep)
    if not suspicion then return end

    local self = Entity()
    local sphere = self:getBoundingSphere()

    --
    if not valid(suspicion.ship) then
        local faction = Faction()
        Galaxy():changeFactionRelations(faction, Faction(suspicion.factionIndex), -25000 - (10000 * faction:getTrait("strict")), true, true)
        AntiSmuggle.resetSuspicion()
        return
    end

    -- start talking, start timer for response
    if not suspicion.talkedTo then
        suspicion.talkedTo = true
        suspicion.timeOut = values.timeOut

        local faction = Faction()
        Galaxy():changeFactionRelations(faction, Faction(suspicion.factionIndex), -2500 - (1250 * faction:getTrait("strict")), true, true)

        if valid(suspicion.player) then
            invokeClientFunction(suspicion.player, "startTalk", suspicion.type, suspicion.fine)
        end
    end

    -- if they don't respond in time, they are considered an enemy
    if not suspicion.responded then
        suspicion.timeOut = suspicion.timeOut - 1
        if suspicion.timeOut <= 0 then
            ShipAI():registerEnemyEntity(suspicion.ship.index)
        end

        if suspicion.timeOut == 0  and valid(suspicion.player) then
            invokeClientFunction(suspicion.player, "startEnemyTalk")
        end
    end

    -- fly towards the suspicious ship
    if suspicion.responded or suspicion.timeOut > 0 then

        if self:hasScript("ai/patrol.lua") then
            self:invokeFunction("ai/patrol.lua", "setWaypoints", {suspicion.ship.translationf})
        else
            ShipAI():setFly(suspicion.ship.translationf, sphere.radius + 30.0)
        end

        if suspicion.responded and self:getNearestDistance(suspicion.ship) < 80.0 then
            -- take away the cargo
            for good, amount in pairs(suspicion.ship:getCargos()) do
                if (good.dangerous and suspicion.licenseLevel < 0)
                    or (good.suspicious and suspicion.licenseLevel < 1)
                    or (good.stolen and suspicion.licenseLevel < 2)
                    or (good.illegal and suspicion.licenseLevel < 3) then

                    suspicion.ship:removeCargo(good, amount)
                end
            end

            -- case closed, suspicion removed
            AntiSmuggle.resetSuspicion()
        end
    end

end

function AntiSmuggle.onDestroyed(index)
    if suspicion and valid(suspicion.ship) and suspicion.ship.index == index then
        AntiSmuggle.resetSuspicion()
    end
end

function AntiSmuggle.resetSuspicion()
    if suspicion then
        -- remove the suspicion
        Sector():setValue(string.format("%s_is_under_suspicion", suspicion.index.string), nil)
    end

    suspicion = nil
    local self = Entity()
    if self:hasScript("ai/patrol.lua") then
        self:invokeFunction("ai/patrol.lua", "setWaypoints", nil)
    else
        ShipAI():setIdle()
    end
end

function AntiSmuggle.makeSuspiciousDialog(fine)
    values.fine = fine

    local dialog0 = {}
    dialog0.text = "Hello. This is a routine scan. Please remain calm.\n\nYour cargo will be confiscated and we will have to fine you ${fine} credits.\n\nYou have ${timeOut} seconds to respond."%_t % values

    dialog0.answers = {
        {answer = "Comply"%_t, onSelect = "onComply", text = "Thank you for your cooperation.\n\nRemain where you are. We will now approach you and confiscate your cargo."%_t},
        {answer = "[Ignore]"%_t, onSelect = "onIgnore"}
    }

    return dialog0
end

function AntiSmuggle.makeIllegalDialog(fine)
    values.fine = fine

    local dialog0 = {}
    dialog0.text = "Hold on. Our scanners show illegal cargo on your ship.\n\nYour cargo will be confiscated and you are fined ${fine} credits.\n\nYou have ${timeOut} seconds to respond."%_t % values

    dialog0.answers = {
        {answer = "Comply"%_t, onSelect = "onComply", text = "Thank you for your cooperation.\n\nRemain where you are. We will now approach you and confiscate your cargo."%_t},
        {answer = "[Ignore]"%_t, onSelect = "onIgnore"}
    }

    return dialog0
end

function AntiSmuggle.makeStolenDialog(fine)
    values.fine = fine

    local dialog0 = {}
    dialog0.text = "Hold on. Our scanners show stolen cargo on your ship.\n\nYour cargo will be confiscated and you are fined ${fine} credits.\n\nYou have ${timeOut} seconds to respond."%_t % values

    dialog0.answers = {
        {answer = "Comply"%_t, onSelect = "onComply", text = "Thank you for your cooperation.\n\nRemain where you are. We will now approach you and confiscate your cargo."%_t},
        {answer = "[Ignore]"%_t, onSelect = "onIgnore"}
    }

    return dialog0
end

function AntiSmuggle.makeDangerousDialog(fine)
    values.fine = fine

    local dialog0 = {}
    dialog0.text = "Hold on. Our scanners show dangerous cargo on your ship.\n\nAccording to our records, you don't have transportation permit for dangerous cargo in our area.\n\nYour cargo will be confiscated and you are fined ${fine} credits.\n\nYou have ${timeOut} seconds to respond."%_t % values

    dialog0.answers = {
        {answer = "Comply"%_t, onSelect = "onComply", text = "Thank you for your cooperation.\n\nRemain where you are. We will now approach you and confiscate your cargo."%_t},
        {answer = "[Ignore]"%_t, onSelect = "onIgnore"}
    }

    return dialog0
end


function AntiSmuggle.startTalk(type, fine)
    local dialog = nil

    fine = createMonetaryString(fine)

    if type == 0 then
        dialog = AntiSmuggle.makeSuspiciousDialog(fine)
    elseif type == 1 then
        dialog = AntiSmuggle.makeIllegalDialog(fine)
    elseif type == 2 then
        dialog = AntiSmuggle.makeStolenDialog(fine)
    elseif type == 3 then
        dialog = AntiSmuggle.makeDangerousDialog(fine)
    end

    ScriptUI():interactShowDialog(dialog, 0)
end

function AntiSmuggle.startEnemyTalk(type)
    local dialog = {text = "Your non-responsiveness is considered a hostile act."%_t}

    ScriptUI():interactShowDialog(dialog, 0)
end


function AntiSmuggle.onComply()
    if onClient() then
        invokeServerFunction("onComply")
        return
    end

if suspicion and suspicion.factionIndex and suspicion.player and suspicion.player.index == callingPlayer then
        suspicion.responded = true
        Faction(suspicion.factionIndex):pay("Paid a fine of %1% credits."%_T, suspicion.fine)
    end
end

function AntiSmuggle.onIgnore()
end

-- test helper functions
function AntiSmuggle.getIsSuspicious()
    return suspicion ~= nil
end
