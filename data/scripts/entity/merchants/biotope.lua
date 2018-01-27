package.path = package.path .. ";data/scripts/entity/merchants/?.lua;"
package.path = package.path .. ";data/scripts/lib/?.lua;"
require ("stringutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Biotope
Biotope = require ("consumer")

Biotope.consumerName = "Biotope"%_t
Biotope.consumerIcon = "data/textures/icons/pixel/biotope.png"
Biotope.consumedGoods = {"Food", "Food Bar", "Fungus", "Wood", "Glass", "Sheep", "Cattle", "Wheat", "Corn", "Rice", "Vegetable", "Water", "Coal", "Plant"}
