
package.path = package.path .. ";data/scripts/lib/?.lua"

require ("stringutility")
require ("faction")
local AIAction =
{
    Escort = 1,
    Attack = 2,
    FlyThroughWormhole = 3,
    FlyToPosition = 4
}

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace CraftOrders
CraftOrders = {}

-- variables for strategy state
CraftOrders.targetAction = nil
CraftOrders.targetIndex = nil
CraftOrders.targetPosition = nil


function CraftOrders.setAIAction(action, index, position)
    if onServer() then
        local owner, _, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
        if not owner then return end

        invokeClientFunction(player, "setAIAction", action, index, position)
    end

    CraftOrders.targetAction = action
    CraftOrders.targetIndex = index
    CraftOrders.targetPosition = position
end

function CraftOrders.secure()
    local strId
    if CraftOrders.targetIndex then
        strId = CraftOrders.targetIndex.string
    end
    local pos
    if CraftOrders.targetPosition then
        pos = {CraftOrders.targetPosition.x, CraftOrders.targetPosition.y, CraftOrders.targetPosition.z}
    end

    return
    {
        action = CraftOrders.targetAction,
        index = strId,
        position = pos
    }
end

function CraftOrders.restore(dataIn)
    if not dataIn then return end

    CraftOrders.targetAction = dataIn.action

    if dataIn.index then
        CraftOrders.targetIndex = Uuid(dataIn.index)
    end
    if dataIn.pos then
        CraftOrders.targetPosition = vec3(dataIn.pos.x, dataIn.pos.y, dataIn.pos.z)
    end
end

function CraftOrders.initialize()
    if onClient() then
        CraftOrders.sync()
    end
end

function CraftOrders.sync(dataIn)
    if onClient() then
        if dataIn then
            CraftOrders.targetAction = dataIn.action
            CraftOrders.targetIndex = dataIn.index
            CraftOrders.targetPosition = dataIn.position
        else
            invokeServerFunction("sync")
        end
    else
        assert(callingPlayer)

        local data = {
            action = CraftOrders.targetAction,
            index = CraftOrders.targetIndex,
            position = CraftOrders.targetPosition
        }
        invokeClientFunction(Player(callingPlayer), "sync", data)
    end
end

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function CraftOrders.interactionPossible(playerIndex, option)
    -- giving the own craft orders does not work
    if Entity().index == Player().craftIndex then
        return false
    end

    callingPlayer = Player().index
    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FlyCrafts) then
        return false
    end

    return true
end

-- create all required UI elements for the client side
function CraftOrders.initUI()

    local res = getResolution()
    local size = vec2(250, 330)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    menu:registerWindow(window, "Orders"%_t)

    window.caption = "Craft Orders"%_t
    window.showCloseButton = 1
    window.moveable = 1

    local splitter = UIHorizontalMultiSplitter(Rect(window.size), 10, 10, 7)

    window:createButton(splitter:partition(0), "Idle"%_t, "onIdleButtonPressed")
    window:createButton(splitter:partition(1), "Passive"%_t, "onPassiveButtonPressed")
    window:createButton(splitter:partition(2), "Guard This Position"%_t, "onGuardButtonPressed")
    window:createButton(splitter:partition(3), "Patrol Sector"%_t, "onPatrolButtonPressed")
    window:createButton(splitter:partition(4), "Escort Me"%_t, "onEscortMeButtonPressed")
    window:createButton(splitter:partition(5), "Attack Enemies"%_t, "onAttackEnemiesButtonPressed")
    window:createButton(splitter:partition(6), "Mine"%_t, "onMineButtonPressed")
    window:createButton(splitter:partition(7), "Salvage"%_t, "onSalvageButtonPressed")
    --window:createButton(Rect(10, 250, 230 + 10, 30 + 250), "Attack My Targets", "onWingmanButtonPressed")

end

local function checkCaptain()
    local entity = Entity()

    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.FlyCrafts) then
        return
    end

    local captains = entity:getCrewMembers(CrewProfessionType.Captain)
    if captains and captains > 0 then
        return true
    end

    local faction = Faction()
    if faction.isPlayer or faction.isAlliance then
        Player():sendChatMessage("", 1, "Your ship has no captain!"%_t)
    end
end

local function removeSpecialOrders()

    local entity = Entity()

    for index, name in pairs(entity:getScripts()) do
        if string.match(name, "data/scripts/entity/ai/") then
            entity:removeScript(index)
        end
    end
end

function CraftOrders.onIdleButtonPressed()
    if onClient() then
        invokeServerFunction("onIdleButtonPressed")
        ScriptUI():stopInteraction()
        return
    end

    if checkCaptain() then
        local ai = ShipAI()
        ai:setIdle()

        removeSpecialOrders()
    end
end

function CraftOrders.onPassiveButtonPressed()
    if onClient() then
        invokeServerFunction("onPassiveButtonPressed")
        ScriptUI():stopInteraction()
        return
    end

    if checkCaptain() then
        local ai = ShipAI()
        ai:setPassive()

        removeSpecialOrders()
    end
end

function CraftOrders.onGuardButtonPressed()
    if onClient() then
        invokeServerFunction("onGuardButtonPressed")
        ScriptUI():stopInteraction()
        return
    end

    if checkCaptain() then
        local ai = ShipAI()
        ai:setGuard(Entity().translationf)

        removeSpecialOrders()
    end
end


function CraftOrders.onEscortMeButtonPressed(index)
    if onClient() then
        local ship = Player().craft
        if ship == nil then return end

        invokeServerFunction("onEscortMeButtonPressed", ship.index)
        ScriptUI():stopInteraction()
        return
    end

    if checkCaptain() then
        local ai = ShipAI()
        ai:setEscort(Entity(index))

        removeSpecialOrders()
    end
end

function CraftOrders.escortEntity(index)
    if onClient() then
        invokeServerFunction("escortEntity", index)
        return
    end

    if checkCaptain() then
        local ai = ShipAI()
        ai:setEscort(Entity(index))
        CraftOrders.setAIAction(AIAction.Escort, index)

        removeSpecialOrders()
    end
end

function CraftOrders.attackEntity(index)
    if onClient() then
        invokeServerFunction("attackEntity", index);
        return
    end

    if checkCaptain() then
        local ai = ShipAI()
        ai:setAttack(Entity(index))
        CraftOrders.setAIAction(AIAction.Attack, index)

        removeSpecialOrders()
    end
end

function CraftOrders.flyToPosition(pos)
    if onClient() then
        invokeServerFunction("flyToPosition", pos);
        return
    end

    if checkCaptain() then
        removeSpecialOrders()

        local ai = ShipAI()
        ai:setFly(pos, 0)
        CraftOrders.setAIAction(AIAction.FlyToPosition, nil, pos)
    end
end

function CraftOrders.flyThroughWormhole(index)
    if onClient() then
        invokeServerFunction("flyThroughWormhole", index);
        return
    end

    if checkCaptain() then
        removeSpecialOrders()

        local ship = Entity()
        local target = Entity(index)

        if target:hasComponent(ComponentType.Plan) then
            -- gate
            local entryPos
            local flyThroughPos
            local waypoints = {}

            -- determine best direction for entering the gate
            if dot(target.look, ship.translationf - target.translationf) > 0 then
                entryPos = target.translationf + target.look * ship:getBoundingSphere().radius * 10
                flyThroughPos = target.translationf - target.look * ship:getBoundingSphere().radius * 5
            else
                entryPos = target.translationf - target.look * ship:getBoundingSphere().radius * 10
                flyThroughPos = target.translationf + target.look * ship:getBoundingSphere().radius * 5
            end
            table.insert(waypoints, entryPos)
            table.insert(waypoints, flyThroughPos)

            Entity():addScript("ai/flythroughwormhole.lua", unpack(waypoints))
        else
            -- wormhole
            ShipAI():setFly(target.translationf, 0)
        end

        CraftOrders.setAIAction(AIAction.FlyThroughWormhole, index)
    end
end

function CraftOrders.stopFlying()
    if onClient() then
        invokeServerFunction("stopFlying")
        return
    end

    if checkCaptain() then
        removeSpecialOrders()

        ShipAI():setPassive()
        CraftOrders.setAIAction()
    end
end

function CraftOrders.onAttackEnemiesButtonPressed()
    if onClient() then
        invokeServerFunction("onAttackEnemiesButtonPressed")
        ScriptUI():stopInteraction()
        return
    end

    if checkCaptain() then
        local ai = ShipAI()
        ai:setAggressive()

        removeSpecialOrders()
    end
end

function CraftOrders.onPatrolButtonPressed()
    if onClient() then
        invokeServerFunction("onPatrolButtonPressed")
        ScriptUI():stopInteraction()
        return
    end

    if checkCaptain() then
        removeSpecialOrders()
        Entity():addScript("ai/patrol.lua")
    end
end

function CraftOrders.onMineButtonPressed()
    if onClient() then
        invokeServerFunction("onMineButtonPressed")
        ScriptUI():stopInteraction()
        return
    end

    if checkCaptain() then
        removeSpecialOrders()
        Entity():addScript("ai/mine.lua")
    end
end

function CraftOrders.onSalvageButtonPressed()
    if onClient() then
        invokeServerFunction("onSalvageButtonPressed")
        ScriptUI():stopInteraction()
        return
    end

    if checkCaptain() then
        removeSpecialOrders()
        Entity():addScript("ai/salvage.lua")
    end
end


-- this function will be executed every frame both on the server and the client
--function update(timeStep)
--
--end
--
---- this function gets called every time the window is shown on the client, ie. when a player presses F
--function onShowWindow()
--
--end
--
---- this function gets called every time the window is shown on the client, ie. when a player presses F
--function onCloseWindow()
--
--end
