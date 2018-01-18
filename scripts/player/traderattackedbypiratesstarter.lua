if onServer() then

function initialize()
    -- start the pirate attack event
    Sector():addScriptOnce("traderattackedbypirates.lua")
    terminate()
end

end
