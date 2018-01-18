package.path = package.path .. ";data/scripts/lib/?.lua;data/scripts/entity/merchants/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua;"
require ("stringutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Habitat
Habitat = require ("consumer")

Habitat.consumerName = "Habitat"%_t
Habitat.consumerIcon = "data/textures/icons/pixel/habitat.png"
Habitat.consumedGoods = {"Beer", "Wine", "Liquor", "Food", "Tea", "Luxury Food", "Spices", "Vegetable", "Fruit", "Cocoa", "Coffee", "Wood", "Meat", "Water"}
