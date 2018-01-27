package.path = package.path .. ";data/scripts/entity/merchants/?.lua;"
package.path = package.path .. ";data/scripts/lib/?.lua;"
require ("stringutility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Casino
Casino = require ("consumer")

Casino.consumerName = "Casino"%_t
Casino.consumerIcon = "data/textures/icons/pixel/casino.png"
Casino.consumedGoods = {"Beer", "Wine", "Liquor", "Food", "Luxury Food", "Water", "Medical Supplies"}
