package.path = package.path .. ";data/scripts/lib/?.lua"
require ("stringutility")

function AddDefaultShipScripts(ship)
    ship:addScriptOnce("data/scripts/entity/startbuilding.lua")
    ship:addScriptOnce("data/scripts/entity/entercraft.lua")
    ship:addScriptOnce("data/scripts/entity/exitcraft.lua")
    ship:addScriptOnce("data/scripts/entity/invitetogroup.lua")

    ship:addScriptOnce("data/scripts/entity/craftorders.lua")
    ship:addScriptOnce("data/scripts/entity/transfercrewgoods.lua")
end

function AddDefaultStationScripts(station)
    station:addScriptOnce("data/scripts/entity/startbuilding.lua")
    station:addScriptOnce("data/scripts/entity/entercraft.lua")
    station:addScriptOnce("data/scripts/entity/exitcraft.lua")

    station:addScriptOnce("data/scripts/entity/crewboard.lua")
    station:addScriptOnce("data/scripts/entity/backup.lua")
    station:addScriptOnce("data/scripts/entity/bulletinboard.lua")
    station:addScriptOnce("data/scripts/entity/story/bulletins.lua")
    station:addScriptOnce("data/scripts/entity/regrowdocks.lua")

    station:addScriptOnce("data/scripts/entity/craftorders.lua")
    station:addScriptOnce("data/scripts/entity/transfercrewgoods.lua")
end

function EquipmentDockConsumerArguments()
    return "Equipment Dock"%_t,
        "Fuel",
        "Rocket",
        "Tools",
        "Laser Compressor",
        "Display",
        "Laser Head",
        "Power Unit",
        "Antigrav Unit",
        "Fusion Core",
        "Wire",
        "Drill",
        "Warhead",
        "Plastic"
end

function ShipyardConsumerArguments()
    return "Shipyard"%_t,
        "Energy Tube",
        "Steel",
        "Aluminium",
        "Display",
        "Metal Plate",
        "Power Unit",
        "Antigrav Unit",
        "Fusion Core",
        "Wire",
        "Solar Cell",
        "Solar Panel",
        "Plastic"
end

function RepairDockConsumerArguments()
    return "Repair Dock"%_t,
          "Energy Tube",
          "Fuel",
          "Steel",
          "Fusion Core",
          "Display",
          "Metal Plate",
          "Power Unit",
          "Antigrav Unit",
          "Nanobot",
          "Processor",
          "Solar Cell",
          "Solar Panel",
          "Plastic"
end

function MilitaryOutpostConsumerArguments()
    return "Military Outpost"%_t,
        "War Robot",
        "Body Armor",
        "Vehicle",
        "Gun",
        "Ammunition",
        "Ammunition S",
        "Ammunition M",
        "Ammunition L",
        "Medical Supplies",
        "Explosive Charge",
        "Electromagnetic Charge",
        "Food Bar",
        "Targeting System"
end

function ResearchStationConsumerArguments()
    return "Research Station"%_t,
        "Turbine",
        "High Capacity Lens",
        "Neutron Accelerator",
        "Electron Accelerator",
        "Proton Accelerator",
        "Fusion Generator",
        "Anti-Grav Generator",
        "Force Generator",
        "Teleporter",
        "Drill",
        "Satellite"
end
