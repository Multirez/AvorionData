package.path = package.path .. ";data/scripts/lib/?.lua"
require("stringutility")
require("utility")
require("randomext")

function receiveTransactionTax(station, amount)
    if not amount then return end
    amount = round(amount)
    if amount == 0 then return end

    local stationOwner = Faction(station.factionIndex)
    local x, y = Sector():getCoordinates()

    if stationOwner then
        local msg = Format("\\s(%1%:%2%) %3%: Gained %4% credits transaction tax."%_T,
            x,
            y,
            station.title)

        stationOwner:receive(msg, amount)
    end

end


function getTurretFactorySoldGoods()
    local goods =
    {
        "Servo", "Steel Tube", "Ammunition S", "Steel", "Aluminium", "Lead",
        "Servo", "High Pressure Tube", "Ammunition M", "Explosive Charge", "Steel", "Aluminium",
        "Laser Head", "Laser Compressor", "High Capacity Lens", "Laser Modulator", "Steel", "Crystal",
        "Plasma Cell", "Energy Tube", "Conductor", "Energy Container", "Steel", "Crystal",
        "Servo", "Warhead", "High Pressure Tube", "Explosive Charge", "Steel", "Wire",
        "Servo", "Rocket", "High Pressure Tube", "Fuel", "Targeting Card", "Steel", "Wire",
        "Servo", "Electromagnetic Charge", "Electro Magnet", "Gauss Rail", "High Pressure Tube", "Steel", "Copper",
        "Nanobot", "Transformator", "Laser Modulator", "Conductor", "Gold",  "Steel",
        "Laser Compressor", "Laser Modulator", "High Capacity Lens", "Conductor", "Steel",
        "Laser Compressor", "Laser Modulator", "High Capacity Lens",  "Conductor", "Steel",
        "Force Generator", "Energy Inverter", "Energy Tube", "Conductor", "Steel", "Zinc",
        "Industrial Tesla Coil", "Electromagnetic Charge", "Energy Inverter", "Conductor", "Copper", "Energy Cell",
        "Military Tesla Coil", "High Capacity Lens", "Electromagnetic Charge", "Conductor", "Copper", "Energy Cell",
    }

    local selected = {}
    for i = 1, 15 do
        selected[randomEntry(random(), goods)] = true
    end

    local used = {}

    for good, _ in pairs(selected) do
        table.insert(used, good)
    end

    return used
end
