package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

require ("utility")

function getNameByRarity(rarity)
    if rarity.value == 0 then
        return "Dangerous Cargo Transport License"%_t
    elseif rarity.value == 1 then
        return "Suspious Cargo Transport License"%_t
    elseif rarity.value == 2 then
        return "Stolen Cargo Transport License"%_t
    elseif rarity.value == 3 then
        return "Illegal Cargo Transport License"%_t
    end
end

function getTooltipDescriptionByRarity(rarity)
    if rarity.value == 0 then
        return "License for transporting dangerous cargo"%_t
    elseif rarity.value == 1 then
        return "License for transporting suspicious cargo"%_t
    elseif rarity.value == 2 then
        return "License for transporting stolen cargo"%_t
    elseif rarity.value == 3 then
        return "License for transporting illegal cargo"%_t
    end
end

function getAdditionalDescriptionByRarity(rarity)
    if rarity.value == 1 then
        return "Also allows transporting dangerous cargo"%_t
    elseif rarity.value == 2 then
        return "Also allows transporting dangerous and suspicious cargo"%_t
    elseif rarity.value == 3 then
        return "Also allows transporting dangerous, suspicious and stolen cargo"%_t
    end
end

function makeVanillaItemTooltip(item)
    local tooltip = Tooltip()

    tooltip.icon = item.icon

    local factionIndex = item:getValue("faction")
    local name = Faction(factionIndex).name

    local title = getNameByRarity(item.rarity)
    local description1 = getTooltipDescriptionByRarity(item.rarity)
    local description2 = "in ${factionName}'s sectors"%_t % {factionName = name}
    local description3 = getAdditionalDescriptionByRarity(item.rarity)

    local headLineSize = 25
    local headLineFont = 15
    local line = TooltipLine(headLineSize, headLineFont)
    line.ctext = title
    line.ccolor = item.rarity.color
    tooltip:addLine(line)

    tooltip:addLine(TooltipLine(18, 14))
    if not description3 then
        tooltip:addLine(TooltipLine(18, 14))
    end

    local dLine1 = TooltipLine(18, 14)
    dLine1.ltext = description1
    tooltip:addLine(dLine1)

    local dLine2 = TooltipLine(18, 14)
    dLine2.ltext = description2
    tooltip:addLine(dLine2)

    if description3 then
        local dLine3 = TooltipLine(18, 14)
        dLine3.ltext = description3
        tooltip:addLine(dLine3)
    end

    return tooltip
end


function createLicense(rarity, faction)
    local license = VanillaInventoryItem()
    if rarity.value == 0 then
        license.name = "Dangerous Cargo Transport License"%_t
        license.price = 100 * 1000
    elseif rarity.value == 1 then
        license.name = "Suspious Cargo Transport License"%_t
        license.price = 500 * 1000
    elseif rarity.value == 2 then
        license.name = "Stolen Cargo Transport License"%_t
        license.price = 1000 * 1000
    elseif rarity.value == 3 then
        license.name = "Illegal Cargo Transport License"%_t
        license.price = 2000 * 1000
    end

    license.rarity = rarity
    license:setValue("isCargoLicense", true)
    license:setValue("faction", faction.index)
    license.icon = "data/textures/icons/wooden-crate.png"
    license.iconColor = rarity.color
    license:setTooltip(makeVanillaItemTooltip(license))

    return license
end
