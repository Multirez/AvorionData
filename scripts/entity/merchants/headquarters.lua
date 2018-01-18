package.path = package.path .. ";data/scripts/lib/?.lua"
require ("stringutility")

function initialize()

    if onClient() then
        if EntityIcon().icon == "" then
            EntityIcon().icon = "data/textures/icons/pixel/headquarters.png"
        end
    else
        if Entity().title == "" then
            local faction = Faction(Entity().factionIndex)

            if faction then
                local name = faction.name
                if name:starts("The ") then
                    name = name:sub(5)
                end

                Entity():setTitle("${faction} Headquarters"%_t, {faction = name})
            else
                Entity().title = "Headquarters"%_t
            end
        end
    end

end
