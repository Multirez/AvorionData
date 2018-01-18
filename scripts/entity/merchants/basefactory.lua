package.path = package.path .. ";data/scripts/lib/?.lua;data/scripts/entity/merchants/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace BaseFactory
BaseFactory = require ("factory")

BaseFactory.minLevel = 0
BaseFactory.maxLevel = 0

BaseFactory.maxNumProductions = 1

BaseFactory.lowestPriceFactor = 0.5
BaseFactory.highestPriceFactor = 0.75

