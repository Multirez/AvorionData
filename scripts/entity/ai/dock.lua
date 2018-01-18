
local DockAI = {}

DockAI.usedDock = nil
DockAI.dockStage = 0

function DockAI.flyToDock(ship, station)

    DockAI.dockStage = DockAI.dockStage or 0

    local ai = ShipAI(ship)
    local docks = DockingPositions(station)

    if DockAI.dockStage == 0 then

        -- no dock chosen yet -> find one
        if not DockAI.usedDock then
            -- if there are no docks on the station at all, we can't do anything
            if not docks:getDockingPositions() then
                return false
            end

            -- find a free dock
            local freeDock = docks:getFreeDock(ship)
            if freeDock then
                DockAI.usedDock = freeDock
            end
        end

        if DockAI.usedDock then
            if not docks:isDockFree(DockAI.usedDock, ship) then
                -- if the dock is not free, reset it and look for another one
                DockAI.usedDock = nil
                ai:setPassive() -- reset the fly state so that new fly states will be accepted later on
            end
        end

        -- still no free dock found? nothing we can do
        if not DockAI.usedDock then return end

        -- fly towards the light line of the dock
        local pos, dir = docks:getDockingPosition(DockAI.usedDock)
        local target = station.position:transformCoord(pos + dir * 250)

        if ai.state ~= AIState.Fly then
            ai:setFly(target, 0)
        end

        if docks:inLightArea(ship, DockAI.usedDock) then
            -- when the light area was reached, start stage 1 of the docking process
            DockAI.dockStage = 1
            return false
        end
    end

    -- stage 1 is flying towards the dock inside the light-line
    if DockAI.dockStage == 1 then
        -- if docking doesn't work, go back to stage 0 and find a free dock
        if not docks:startDocking(ship, DockAI.usedDock) then
            DockAI.dockStage = 0
            return false
        else
            -- docking worked: set AI to passive to allow tractor beams to grab it
            DockAI.dockStage = 2
            ai:setPassive()
        end
    end

    if DockAI.dockStage == 2 then
        -- once the ship is at the dock, wait
        if station:isDocked(ship) then
            ai:setPassive()
            return true
        end
    end

    return false
end

DockAI.undockStage = 0

function DockAI.flyAwayFromDock(ship, station)

    local ai = ShipAI(ship.index)
    local docks = DockingPositions(station)

    if DockAI.undockStage == 0 then
        docks:startUndocking(ship)
        ai:setPassive()
        DockAI.undockStage = 1
    elseif DockAI.undockStage == 1 then

        if not docks:isUndocking(ship) then
            DockAI.undockStage = 0
            return true
        end

        ai:setPassive()
    end

    return false
end

function DockAI.secure(data)
    data.DockAI = {}
    data.DockAI.usedDock = DockAI.usedDock
    data.DockAI.dockStage = DockAI.dockStage
    data.DockAI.undockStage = DockAI.undockStage
end

function DockAI.restore(data)
    if not data.DockAI then return end

    DockAI.usedDock = data.DockAI.usedDock
    DockAI.dockStage = data.DockAI.dockStage or 0
    DockAI.undockStage = data.DockAI.undockStage or 0
end

return DockAI
