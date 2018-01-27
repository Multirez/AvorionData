package.path = package.path .. ";data/scripts/lib/?.lua"

function execute(sender, commandName, entityId)
    local player = Player()

    local self = player.craft
    if not self then
        return 1, "", "You're not in a ship!"
    end

    local craft = self.selectedObject or self

    if not craft.crew then
        return 1, "", "This craft doesn't have a crew!"
    end

    craft.crew = craft.minCrew
    craft:addCrew(1, CrewMan(CrewProfessionType.Captain))

    return 0, "", ""
end

function getDescription()
    return "Sets the current crew of a ship to the minimum required crew"
end

function getHelp()
    return "Sets the crew of the selected craft, or the own craft, if none selected. Usage: /addcrew"
end
