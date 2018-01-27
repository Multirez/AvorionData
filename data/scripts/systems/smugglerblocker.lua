package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("basesystem")
require ("utility")

-- optimization so that energy requirement doesn't have to be read every frame
FixedEnergyRequirement = true

function onInstalled()
    if onClient() then
        Player():registerCallback("onStartDialog", "onStartDialog")
    end
end

function onStartDialog(entityId)
    local entity = Entity(entityId)
    if entity:hasScript("story/smuggler.lua") then
        ScriptUI(entityId):addDialogOption("[Destroy Hyperspace Drive]"%_t, "onBlock")
    end
end

function onBlock(entityId)
    if onClient() then
        invokeServerFunction("onBlock", entityId)

        local dialog = {}

        dialog.text = "Charging ..."%_t
        dialog.followUp = {text = "The hyperspace engine has been destroyed."%_t}

        ScriptUI(entityId):showDialog(dialog)
        return
    end

    local entity = Entity(entityId)
    entity:invokeFunction("story/smuggler.lua", "blockHyperspace")

end

function onUninstalled(seed, rarity)
end

function getName(seed, rarity)
    return "Hyperspace Overloader"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/smugglerblock.png"
end

function getEnergy(seed, rarity)
    return 250 * 1000 * 1000
end

function getPrice(seed, rarity)
    return 5000
end

function getTooltipLines(seed, rarity)
    return
    {
--        {ltext = "All Turrets", rtext = "+" .. getNumTurrets(seed, rarity), icon = "data/textures/icons/turret.png"}
    }
end

function getDescriptionLines(seed, rarity)
    return
    {
        {ltext = "This system was built by Bottan's chief engineer."%_t, rtext = "", icon = ""},
        {ltext = "It's configured to destroy Bottan's hyperspace drive."%_t, rtext = "", icon = ""}
    }
end
