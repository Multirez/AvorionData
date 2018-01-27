package.path = package.path .. ";data/scripts/lib/?.lua"
require ("defaultscripts")
require ("stringutility")

local nameTextBox = nil

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex, option)
    local entity = Entity()

    if entity.factionIndex == playerIndex then
        return true
    end

    return false
end

function getIcon(seed, rarity)
    return "data/textures/icons/holy-grail.png"
end

function initUI()
    local res = getResolution()
    local size = vec2(350, 155)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    window.caption = "Rename Ship"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Rename Ship"%_t);

    local hmsplit = UIHorizontalMultiSplitter(Rect(size), 10, 10, 3)

    local label = window:createLabel(hmsplit:partition(0).lower, "Enter the new name of your ship:"%_t, 14);
    label.size = vec2(size.x - 20, 40)
    label.centered = true

    nameTextBox = window:createTextBox(hmsplit:partition(1), "")
    nameTextBox.maxCharacters = 35
    nameTextBox:forbidInvalidFilenameChars()
    nameTextBox.text = Entity().name

    -- button at the bottom
    local button = window:createButton(hmsplit:partition(3), "OK"%_t, "onRenameButtonPress");
    button.textSize = 14    
end

function onRenameButtonPress()
    newName = nameTextBox.text
    invokeServerFunction("renameShip", newName)
end

function renameShip(newName)
    Entity().name = newName
end