package.path = package.path .. ";data/scripts/lib/?.lua"

require ("stringutility")
require ("player")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace CrewTransport
CrewTransport = {}

local data = {}

function CrewTransport.interactionPossible(player, option)
    if not data.reserved then
        return false
    end

    if data.reserved ~= Player().craftIndex.string then
        return false
    end

    return true
end

function CrewTransport.initialize(reservedFor, crew_in)
    if onServer() and reservedFor then
        local self = Entity()
        self.title = "Crew Transport"%_t

        local reservee = Entity(reservedFor)
        if not reservee then
            CrewTransport.finish()
            return
        end

        data.reserved = reservedFor.string
        data.crew = {}
        for profession, amount in pairs(crew_in) do
            data.crew[profession.value] = amount
        end

        Sector():broadcastChatMessage(self.title, ChatMessageType.Normal, "Crew transport for %1% is here. Please remain where you are, we'll fly to your current location."%_t, reservee.name)

        if reservee.isShip then
            ShipAI():setFollow(reservee)
        else
            self:addScriptOnce("ai/docktostation.lua", reservee.index.string)
        end

    elseif onClient() then
        CrewTransport.sync()
    end
end

function CrewTransport.initUI()
    ScriptUI():registerInteraction("Transfer Crew", "onTransferCrew")
end

function CrewTransport.sync(syncData)
    if onClient() then
        if not syncData then
            invokeServerFunction("sync")
        else
            data = syncData
        end
    else
        invokeClientFunction(Player(callingPlayer), "sync", data)
    end
end

function CrewTransport.onTransferCrew()
    if onClient() then
        invokeServerFunction("onTransferCrew")
        return
    end

    local player = Player(callingPlayer)
    local self = Entity()

    local errors = {}
    errors[EntityType.Station] = "You must be docked to the station to transfer the crew to your ship."%_T
    errors[EntityType.Ship] = "You must be closer to the ship to transfer the crew to your ship."%_T
    if not CheckPlayerDocked(player, self, errors) then
        return
    end

    -- stock up crew
    local craft = player.craft

    for profession, amount in pairs(data.crew) do
        craft:addCrew(amount, CrewMan(CrewProfession(profession), false, 1))
    end

    player:sendChatMessage(self.title, ChatMessageType.Normal, "Pleasure doing business with you."%_t)

    CrewTransport.finish()
end

function CrewTransport.finish()
    ShipAI():setIdle()
    Entity():addScriptOnce("entity/ai/passsector.lua")
    terminate()
end

function CrewTransport.secure()
    return data
end

function CrewTransport.restore(data_in)
    data = data_in
end
