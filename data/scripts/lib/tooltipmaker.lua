package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

require ("utility")
require ("stringutility")
require ("cargotransportlicenseutility")
require ("inventoryitemprice")

local next, ceil = next, math.ceil

local lyr_burstCheck = 2

local iconColor = ColorRGB(0.5, 0.5, 0.5)
local fadedIconColor = ColorRGB(0.25, 0.25, 0.25)
local textColor = ColorRGB(0.9, 0.9, 0.9)
local fadedTextColor = ColorRGB(0.725, 0.725, 0.725)
local fadedCenterTextColor = ColorRGB(0.375, 0.375, 0.375)
local blackColor = ColorRGB(0, 0, 0)

local fontSize = 14 --14
local lineHeight = 17 --20	
local descriptionFontSize = 12
local descriptionLineHeight = 14
local headlineFontSize = 16
local headlineHeight = 18

local function fillWeaponTooltipData(obj, tooltip, wpn)
	local lyr = {}
	
	lyr.activeWeaponsPerTurret = obj.simultaneousShooting and obj.numWeapons > 1 and obj.numWeapons or 1
	lyr.projectilesPerTurret = lyr.activeWeaponsPerTurret * wpn.shotsFired
	lyr.damagePerProjectile = wpn.damage
	lyr.damagePerShot = lyr.projectilesPerTurret * lyr.damagePerProjectile
	lyr.shotsPerSecond = obj.fireRate
	lyr.damagePerSecond = lyr.damagePerShot * lyr.shotsPerSecond
	
	lyr.generatesHeat = obj.maxHeat > 0 and obj.heatPerShot > 0
	lyr.demandsPower = obj.coolingType == 2
	lyr.drainsEnergy = obj.coolingType == 1
	
	--lyr.isBurstFire = obj.shootingTime < lyr_burstCheck
	lyr.isMultiShot = lyr.projectilesPerTurret > 1
	
	if lyr.demandsPower or lyr.drainsEnergy then
		lyr.baseEnergyPerShot = lyr.activeWeaponsPerTurret * obj.heatPerShot
		
		if obj.energyIncreasePerSecond > 0 then
			lyr.energyNormalizationPerSecond = obj.coolingRate
			lyr.energyAccumulationPerSecond = lyr.activeWeaponsPerTurret * obj.energyIncreasePerSecond
			lyr.energyAccumulationPerShot = lyr.activeWeaponsPerTurret * (obj.energyIncreasePerSecond / lyr.shotsPerSecond)
		else
			lyr.noAccumulation = true
		end
	elseif lyr.generatesHeat then
		lyr.heatPerShot = lyr.activeWeaponsPerTurret * obj.heatPerShot
		lyr.coolingPerSecond = obj.coolingRate
		lyr.coolingPerShot = lyr.coolingPerSecond / lyr.shotsPerSecond
		
		lyr.instantlyOverheats = lyr.heatPerShot >= obj.maxHeat
		lyr.neverOverheats = not lyr.instantlyOverheats and lyr.coolingPerShot >= lyr.heatPerShot
		
		if not lyr.neverOverheats then
			lyr.accumulatedHeat = lyr.heatPerShot
			lyr.timeToCooldown = 0
			lyr.timeToOverheat = 0
			lyr.shotsToOverheat = 1
			lyr.secondsPerShot = 1/lyr.shotsPerSecond
			
			if lyr.instantlyOverheats then
				lyr.timeToCooldown = lyr.accumulatedHeat / lyr.coolingPerSecond
				
				if lyr.timeToCooldown > lyr.secondsPerShot then
					lyr.shotsPerSecond = 1/lyr.timeToCooldown
					lyr.damagePerSecond = lyr.damagePerShot * lyr.shotsPerSecond
					
					lyr.usesEDPS = true
				end
				
				lyr.isBurstFire = false
			else
				lyr.adjustedHeatPerShot = lyr.heatPerShot - lyr.coolingPerShot
				lyr.adjustedMaxHeat = obj.maxHeat - lyr.heatPerShot
				
				lyr.shotsToOverheat = ceil( lyr.adjustedMaxHeat / lyr.adjustedHeatPerShot ) +1
				lyr.accumulatedHeat = lyr.accumulatedHeat + ( lyr.shotsToOverheat -1) * lyr.adjustedHeatPerShot
				
				lyr.timeToOverheat = lyr.timeToOverheat + ( lyr.shotsToOverheat -1) * lyr.secondsPerShot
				lyr.timeToCooldown = lyr.accumulatedHeat / lyr.coolingPerSecond
				lyr.cycle = lyr.timeToCooldown + lyr.timeToOverheat
				
				lyr.projectilesPerCycle = lyr.shotsToOverheat * lyr.projectilesPerTurret
				--lyr.damagePerCycle = lyr.shotsToOverheat * lyr.damagePerShot
				lyr.damagePerCycle = lyr.projectilesPerCycle * lyr.damagePerProjectile
				lyr.damagePerSecond = lyr.damagePerCycle / lyr.cycle
				
				--lyr.isBurstFire = lyr.timeToOverheat < lyr_burstCheck
				lyr.isBurstFire = obj.shootingTime < lyr_burstCheck
				lyr.usesEDPS = true
			end
		else
			lyr.generatesHeat = false
			lyr.isBurstFire = false
		end
	end
	
	if lyr.damagePerProjectile > 0 and wpn.stoneEfficiency == 0 and wpn.metalEfficiency == 0 then
		if wpn.hullDamageMultiplicator == wpn.shieldDamageMultiplicator then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = lyr.usesEDPS and "eDPS" or "DPS" --lyr_nt
			line.rtext = round(lyr.damagePerSecond * wpn.hullDamageMultiplicator, 1).."/s"
			line.icon = "data/textures/icons/screen-impact.png";
			line.iconColor = iconColor
			tooltip:addLine(line)
			
			local line = TooltipLine(lineHeight, fontSize)
			if wpn.continuousBeam then
				line.ltext = "Tick Damage" --lyr_nt
				line.rtext = round(lyr.damagePerShot * wpn.hullDamageMultiplicator, 1)
			elseif lyr.isBurstFire then
				line.ltext = "Burst Damage" --lyr_nt
				line.rtext = lyr.projectilesPerCycle.."x"..round(lyr.damagePerProjectile * wpn.hullDamageMultiplicator, 1)
			else
				line.ltext = "Damage" --lyr_nt
				line.rtext = lyr.isMultiShot and lyr.projectilesPerTurret.."x"..round(lyr.damagePerProjectile * wpn.hullDamageMultiplicator, 1) or round(lyr.damagePerProjectile * wpn.hullDamageMultiplicator, 1)
			end
			line.icon = "data/textures/icons/screen-impact.png";
			line.lcolor = fadedTextColor
			line.rcolor = fadedTextColor
			line.iconColor = fadedIconColor
			tooltip:addLine(line)
		else
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Hull "..(lyr.usesEDPS and "eDPS" or "DPS") --lyr_nt
			line.rtext = round(lyr.damagePerSecond * wpn.hullDamageMultiplicator, 1).."/s"
			line.icon = "data/textures/icons/health-normal.png";
			line.iconColor = iconColor
			tooltip:addLine(line)
			
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Shield "..(lyr.usesEDPS and "eDPS" or "DPS") --lyr_nt
			line.rtext = round(lyr.damagePerSecond * wpn.shieldDamageMultiplicator, 1).."/s"
			line.icon = "data/textures/icons/shield.png";
			line.lcolor = fadedTextColor
			line.rcolor = fadedTextColor
			line.iconColor = fadedIconColor
			tooltip:addLine(line)
			
			local line = TooltipLine(lineHeight, fontSize)
			if wpn.continuousBeam then
				line.ltext = "Hull Tick Damage" --lyr_nt
				line.rtext = round(lyr.damagePerShot * wpn.hullDamageMultiplicator, 1)
			elseif lyr.isBurstFire then
				line.ltext = "Hull Burst Damage" --lyr_nt
				line.rtext = lyr.projectilesPerCycle.."x"..round(lyr.damagePerProjectile * wpn.hullDamageMultiplicator, 1)
			else
				line.ltext = "Hull Damage" --lyr_nt
				line.rtext = lyr.isMultiShot and lyr.projectilesPerTurret.."x"..round(lyr.damagePerProjectile * wpn.hullDamageMultiplicator, 1) or round(lyr.damagePerProjectile * wpn.hullDamageMultiplicator, 1)
			end
			line.icon = "data/textures/icons/health-normal.png";
			line.iconColor = iconColor
			tooltip:addLine(line)
			
			local line = TooltipLine(lineHeight, fontSize)
			if wpn.continuousBeam then
				line.ltext = "Shield Tick Damage" --lyr_nt
				line.rtext = round(lyr.damagePerShot * wpn.shieldDamageMultiplicator, 1)
			elseif lyr.isBurstFire then
				line.ltext = "Shield Burst Damage" --lyr_nt
				line.rtext = lyr.projectilesPerCycle.."x"..round(lyr.damagePerProjectile * wpn.shieldDamageMultiplicator, 1)
			else
				line.ltext = "Shield Damage" --lyr_nt
				line.rtext = lyr.isMultiShot and lyr.projectilesPerTurret.."x"..round(lyr.damagePerProjectile * wpn.shieldDamageMultiplicator, 1) or round(lyr.damagePerProjectile * wpn.shieldDamageMultiplicator, 1)
			end
			line.icon = "data/textures/icons/shield.png";
			line.lcolor = fadedTextColor
			line.rcolor = fadedTextColor
			line.iconColor = fadedIconColor
			tooltip:addLine(line)
		end
	elseif wpn.stoneEfficiency > 0 or wpn.metalEfficiency > 0 then		
		if wpn.stoneEfficiency > 0 then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Mining DPS" --lyr_nt
			line.rtext = round(lyr.damagePerSecond*wpn.stoneDamageMultiplicator, 1).."/s"
			line.icon = "data/textures/icons/mining.png";
			line.iconColor = iconColor
			tooltip:addLine(line)
			
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Mining Efficiency" --lyr_nt
			line.rtext = round(wpn.stoneEfficiency * 100, 1).."%"
			line.icon = "data/textures/icons/mining.png";
			line.lcolor = fadedTextColor
			line.rcolor = fadedTextColor
			line.iconColor = fadedIconColor
			tooltip:addLine(line)
		end
		
		if wpn.metalEfficiency > 0 then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Salvaging DPS" --lyr_nt
			line.rtext = round(lyr.damagePerSecond*wpn.hullDamageMultiplicator, 1).."/s"
			line.icon = "data/textures/icons/recycle.png";
			line.iconColor = iconColor
			tooltip:addLine(line)
			
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Salvaging Efficiency" --lyr_nt
			line.rtext = round(wpn.metalEfficiency * 100, 1).."%"
			line.icon = "data/textures/icons/recycle.png";
			line.lcolor = fadedTextColor
			line.rcolor = fadedTextColor
			line.iconColor = fadedIconColor
			tooltip:addLine(line)
		end
	elseif wpn.otherForce ~= 0 or wpn.selfForce ~= 0 then
		if wpn.otherForce > 0 then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Push"%_t
			line.rtext = toReadableValue(wpn.otherForce, "N")
			line.icon = "data/textures/icons/back-forth.png";
			line.iconColor = iconColor
			tooltip:addLine(line)
		elseif wpn.otherForce < 0 then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Pull"%_t
			line.rtext = toReadableValue(-wpn.otherForce, "N")
			line.icon = "data/textures/icons/back-forth.png";
			line.iconColor = iconColor
			tooltip:addLine(line)
		end
		
		if wpn.selfForce > 0 then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Self Push"%_t
			line.rtext = toReadableValue(wpn.selfForce, "N")
			line.icon = "data/textures/icons/back-forth.png";
			line.iconColor = iconColor
			tooltip:addLine(line)
		elseif wpn.selfForce < 0 then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Self Pull"%_t
			line.rtext = toReadableValue(-wpn.selfForce, "N")
			line.icon = "data/textures/icons/back-forth.png";
			line.iconColor = iconColor
			tooltip:addLine(line)
		end
	elseif wpn.hullRepair > 0 or wpn.shieldRepair > 0 then
		if wpn.hullRepair > 0 then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Hull Repair" --lyr_nt
			line.rtext = round(obj.hullRepairRate, 1).."/s"
			line.icon = "data/textures/icons/health-normal.png";
			line.iconColor = iconColor
			tooltip:addLine(line)
		end
	
		if wpn.shieldRepair > 0 then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Shield Recharge" --lyr_nt
			line.rtext = round(obj.shieldRepairRate, 1).."/s"
			line.icon = "data/textures/icons/shield.png";
			line.iconColor = iconColor
			tooltip:addLine(line)
		end
	end
	
	if wpn.continuousBeam then
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Tick Rate" --lyr_nt
		line.rtext = round(lyr.shotsPerSecond, 2).."/s"
		line.icon = "data/textures/icons/bullets.png";
		line.iconColor = iconColor
		tooltip:addLine(line)
	elseif lyr.isBurstFire then
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Burst Cycle" --lyr_nt
		line.rtext = round(lyr.cycle, 2).."s"
		line.icon = "data/textures/icons/bullets.png";
		line.iconColor = iconColor
		tooltip:addLine(line)
	else
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Fire Rate" --lyr_nt
		line.rtext = round(lyr.shotsPerSecond, 2).."/s"
		line.icon = "data/textures/icons/bullets.png";
		line.iconColor = iconColor
		tooltip:addLine(line)
	end
	
	tooltip:addLine(TooltipLine(15, 15))
	
	if wpn.name == "Railgun" or wpn.shieldPenetration > 0 then
		if wpn.name == "Railgun" then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Hull Penetration" --lyr_nt
			line.rtext = (wpn.blockPenetration+1).." blocks"
			line.icon = "data/textures/icons/drill.png";
			line.iconColor = iconColor
			tooltip:addLine(line)
		end
		
		if wpn.shieldPenetration > 0 then
			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = "Shield Penetration" --lyr_nt
			line.rtext = round(wpn.shieldPenetration*100, 1).."%"
			line.icon = "data/textures/icons/slashed-shield.png";
			line.iconColor = iconColor
			tooltip:addLine(line)
		end
		
		tooltip:addLine(TooltipLine(15, 15))
	end
	
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Accuracy"%_t
	line.rtext = (wpn.continuousBeam or wpn.accuracy == 1) and "Absolute" or round(wpn.accuracy * 100, 1).."%"
	line.icon = "data/textures/icons/reticule.png";
	line.iconColor = iconColor
	tooltip:addLine(line)

	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Velocity" --lyr_nt
	line.rtext = wpn.isBeam and "Instant" or round(wpn.pvelocity*10, 0).."m/s"
	line.icon = "data/textures/icons/blaster.png";
	line.lcolor = fadedTextColor
	line.rcolor = fadedTextColor
	line.iconColor = fadedIconColor
	tooltip:addLine(line)

	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Range"%_t
	line.rtext = (wpn.isBeam and round(wpn.blength*10/1000, 2) or round(wpn.pvelocity*wpn.pmaximumTime*10/1000, 2)).."km"
	line.icon = "data/textures/icons/target-shot.png";
	line.iconColor = iconColor
	tooltip:addLine(line)

	tooltip:addLine(TooltipLine(15, 15))
	
	if lyr.demandsPower then
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Requires Power" --lyr_nt
		line.lcolor = fadedCenterTextColor
		line.icon = "data/textures/icons/info.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Base Demand" --lyr_nt
		line.rtext = toReadableValue(lyr.baseEnergyPerShot*1000000, "W/s")
		line.icon = "data/textures/icons/electric.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Accumulation" --lyr_nt
		line.rtext = lyr.noAccumulation and "None" or "+"..toReadableValue(lyr.energyAccumulationPerSecond*1000000, "W/s")
		line.icon = "data/textures/icons/electric.png";
		line.lcolor = fadedTextColor
		line.rcolor = fadedTextColor
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
	
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Normalization" --lyr_nt
		line.rtext = lyr.noAccumulation and "-" or toReadableValue(lyr.energyNormalizationPerSecond*1000000, "W/s")
		line.icon = "data/textures/icons/electric.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		tooltip:addLine(TooltipLine(15, 15))
	elseif lyr.drainsEnergy then
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Consumes Energy" --lyr_nt
		line.lcolor = fadedCenterTextColor
		line.icon = "data/textures/icons/info.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Base Drain" --lyr_nt
		line.rtext = toReadableValue(lyr.baseEnergyPerShot*1000000, "J/shot")
		line.icon = "data/textures/icons/battery-pack-alt.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Accumulation" --lyr_nt
		line.rtext = lyr.noAccumulation and "None" or "+"..toReadableValue(lyr.energyAccumulationPerShot*1000000, "J/shot")
		line.icon = "data/textures/icons/battery-pack-alt.png";
		line.lcolor = fadedTextColor
		line.rcolor = fadedTextColor
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
	
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Normalization" --lyr_nt
		line.rtext = lyr.noAccumulation and "-" or toReadableValue(lyr.energyNormalizationPerSecond*1000000, "J/s")
		line.icon = "data/textures/icons/battery-pack-alt.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		tooltip:addLine(TooltipLine(15, 15))
	elseif lyr.generatesHeat then
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Generates Heat" --lyr_nt
		line.lcolor = fadedCenterTextColor
		line.icon = "data/textures/icons/info.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Buildup" --lyr_nt
		line.ctext = "+"..round(lyr.heatPerShot*10, 0).."%/shot"
		line.ccolor = fadedCenterTextColor
		line.rtext = lyr.instantlyOverheats and "Instant" or lyr.neverOverheats and "Never" or round(lyr.timeToOverheat, 2).."s"
		line.icon = "data/textures/icons/fire.png";
		line.iconColor = ColorRGB(0.7, 0.4, 0.4)
		tooltip:addLine(line)
		
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Dissipation" --lyr_nt
		line.ctext = "-"..round(lyr.coolingPerSecond*10, 0).."%/s"
		line.ccolor = fadedCenterTextColor
		line.rtext = lyr.neverOverheats and "-" or round(lyr.timeToCooldown, 2).."s"
		line.icon = "data/textures/icons/snowflake-2.png";
		line.iconColor = ColorRGB(0.4, 0.4, 0.7)
		tooltip:addLine(line)
		
		tooltip:addLine(TooltipLine(15, 15))
	end
	
	local addEmptyLine
	
	if wpn.shieldDamageMultiplicator == 0 then
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Ineffective against Shield" --lyr_nt
		line.lcolor = fadedCenterTextColor
		line.icon = "data/textures/icons/info.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		addEmptyLine = true
	end
	
	if wpn.stoneDamageMultiplicator == 0 then
		local line = TooltipLine(lineHeight, fontSize)
		line.ltext = "Ineffective against Stone" --lyr_nt
		line.lcolor = fadedCenterTextColor
		line.icon = "data/textures/icons/info.png";
		line.iconColor = fadedIconColor
		tooltip:addLine(line)
		
		addEmptyLine = true
	end
	
	if addEmptyLine then
		tooltip:addLine(TooltipLine(15, 15))
	end
end

local function fillDescriptions(obj, tooltip, isFighter)
	
	local extraLines =  0
	local ignoreList = {["Ionized Projectiles"] = true, ["Burst Fire"] = true, ["Consumes Energy"] = true, ["Overheats"] = true, ["%s%% Chance of penetrating shields"] = true}
	local additional = {}
	local descriptions = obj:getDescriptions()
	
	if not isFighter and obj.automatic then
		additional[#additional+1] = {
			ltext = "Independent Targeting", --lyr_nt
			lcolor = ColorRGB(0.6, 1.0, 0.0),
			icon = "data/textures/icons/processor.png",
			iconColor = iconColor
		}; extraLines = extraLines + 1
	end
	
	if obj.simultaneousShooting and obj.numWeapons > 1 then
		additional[#additional+1] = {
			ltext = "Synchronized Weapons", --lyr_nt
			lcolor = ColorRGB(0.45, 1.0, 0.15),
			icon = "data/textures/icons/missile-pod.png",
			iconColor = iconColor
		}; extraLines = extraLines + 1
	end
	
	if obj.shotsPerFiring > 1 then
		additional[#additional+1] = {
			ltext = "Multiple Projectiles", --lyr_nt
			lcolor = ColorRGB(0.30, 1.0, 0.3),
			icon = "data/textures/icons/missile-swarm.png",
			iconColor = iconColor
		}; extraLines = extraLines + 1
	end
	
	if obj.shootingTime < lyr_burstCheck and obj.shootingTime > 0 then
		additional[#additional+1] = {
			ltext = "Burst Fire", --lyr_nt
			lcolor = ColorRGB(0.15, 1.0, 0.45),
			icon = "data/textures/icons/bullets.png",
			iconColor = iconColor
		}; extraLines = extraLines + 1
	end
	
	if obj.seeker then
		additional[#additional+1] = {
			ltext = "Guided Missiles", --lyr_nt
			lcolor = ColorRGB(0.0, 1.0, 0.6),
			icon = "data/textures/icons/rocket-thruster.png",
			iconColor = iconColor
		}; extraLines = extraLines + 1
	end
	
	if descriptions["Ionized Projectiles"] then
		additional[#additional+1] = {
			ltext = "Ionized Projectiles", --lyr_nt
			lcolor = ColorRGB(0.0, 0.6, 1.0),
			icon = "data/textures/icons/slashed-shield.png",
			iconColor = iconColor
		}; extraLines = extraLines + 1
	end

	for desc, value in next, descriptions do
		if not ignoreList[desc] then
			extraLines = extraLines + 1
		end
	end

	if obj.flavorText ~= "" or not nil then
		local line = TooltipLine(descriptionLineHeight, descriptionFontSize)
		line.ltext = obj.flavorText
		line.lcolor = ColorRGB(1.0, 0.7, 0.7)
		tooltip:addLine(line)
		extraLines = extraLines + 1
	end

	for i = 1, 4 - extraLines do
		tooltip:addLine(TooltipLine(descriptionLineHeight, descriptionFontSize))
	end

	for desc, value in next, descriptions do
		if not ignoreList[desc] then
			local line = TooltipLine(descriptionLineHeight, descriptionFontSize)
			
			if value == "" then
				line.ltext = desc % _t
			else
				line.ltext = string.format(desc % _t, value)
			end
			
			tooltip:addLine(line)
		end
	end
	
	for _, additionalLine in next, additional do
		local line = TooltipLine(lineHeight+2, fontSize+2)
		line.ltext = additionalLine.ltext
		line.lcolor = additionalLine.lcolor
		--line.icon = additionalLine.icon
		line.iconColor = additionalLine.iconColor
		tooltip:addLine(line)
	end
end

local function fillObjectTooltipHeader(obj, tooltip, title, isValidObject, typ)
	local line = TooltipLine(headlineHeight, headlineFontSize)
	line.ctext = title
	line.ccolor = obj.rarity.color
	tooltip:addLine(line)
	
	local line = TooltipLine(5, 12)
	line.ltext = "Tech: "..round(obj.averageTech, 1)  --lyr_nt
	line.ctext = tostring(obj.rarity)
	line.rtext = obj.material.name
	line.ccolor = obj.rarity.color
	line.rcolor = obj.material.color
	tooltip:addLine(line)
	
	tooltip:addLine(TooltipLine(25,15))
	
	if not isValidObject then 
		local line = TooltipLine(lineHeight, fontSize)
		line.ccolor = ColorRGB(0.775, 0.225, 0.225)
		line.ctext = ""; tooltip:addLine(line)
		line.ctext = "WARNING: INVALID OBJECT"; tooltip:addLine(line)
		line.citalic = true
		line.ctext = "this "..typ.." has no weapons"; tooltip:addLine(line)
		line.ctext = typ.."s must have at least one"; tooltip:addLine(line)
		line.ctext = "skipping DTT mod calculations"; tooltip:addLine(line)
		line.ctext = ""; tooltip:addLine(line)
	end;
end

function makeTurretTooltip(turret)
	local wpn = turret:getWeapons()
	
	local tooltip = Tooltip()

	-- title & tooltip icon
	local title = ""
	tooltip.icon = turret.weaponIcon

	local weapon = turret.weaponPrefix .. " /* Weapon Prefix*/"
	weapon = weapon % _t

	local tbl = {material = turret.material.name, weaponPrefix = weapon}

	if turret.numVisibleWeapons == 1 then
		title = "${weaponPrefix} Turret"%_t % tbl
	elseif turret.numVisibleWeapons == 2 then
		title = "Double ${weaponPrefix} Turret"%_t % tbl
	elseif turret.numVisibleWeapons == 3 then
		title = "Triple ${weaponPrefix} Turret"%_t % tbl
	elseif turret.numVisibleWeapons == 4 then
		title = "Quad ${weaponPrefix} Turret"%_t % tbl
	else
		title = "Multi ${weaponPrefix} Turret"%_t % tbl
	end
	
	-- fill header area and weapon data /lyr
	fillObjectTooltipHeader(turret, tooltip, title, wpn and true or false,"turret")
	if wpn then fillWeaponTooltipData(turret, tooltip, wpn) end
	
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Size"%_t
	line.rtext = round(turret.size, 1)
	line.icon = "data/textures/icons/shotgun.png";
	line.iconColor = iconColor
	tooltip:addLine(line)
	
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Tracking Speed" --lyr_nt
	line.rtext = round(turret.turningSpeed, 1)
	line.icon = "data/textures/icons/clockwise-rotation.png";
	line.lcolor = fadedTextColor
	line.rcolor = fadedTextColor
	line.iconColor = fadedIconColor
	tooltip:addLine(line)
	
	-- crew requirements
	local crew = turret:getCrew()

	for crewman, amount in next, crew:getMembers() do
		if amount > 0 then
			local profession = crewman.profession

			local line = TooltipLine(lineHeight, fontSize)
			line.ltext = profession.name
			line.rtext = round(amount)
			line.icon = profession.icon;
			line.iconColor = iconColor
			tooltip:addLine(line)
		end
	end
	
	tooltip:addLine(TooltipLine(15, 15)) --is this necessary?

	fillDescriptions(turret, tooltip, false)

	return tooltip
end

function makeFighterTooltip(fighter)
	local wpn
	local isValidObject

	local tooltip = Tooltip()

	-- title & icon
	local title; if fighter.type == FighterType.Fighter then
		wpn = fighter:getWeapons()
		isValidObject = wpn and true or false
		
		title = "${weaponPrefix} Fighter"%_t % fighter
		tooltip.icon = fighter.weaponIcon
	elseif fighter.type == FighterType.CargoShuttle then
		isValidObject = true
		
		title = "Cargo Shuttle"%_t
		tooltip.icon = "data/textures/icons/wooden-crate.png"
	elseif fighter.type == FighterType.CrewShuttle then
		isValidObject = true
		
		title = "Crew Shuttle"%_t
		tooltip.icon = "data/textures/icons/backup.png"
	end
	
	-- fill header area and weapon data /lyr
	fillObjectTooltipHeader(fighter, tooltip, title, isValidObject, "fighter")
	if wpn then fillWeaponTooltipData(fighter, tooltip, wpn) end
	
	-- durability
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Durability"%_t
	line.rtext = round(fighter.durability)
	line.icon = "data/textures/icons/health-normal.png";
	line.iconColor = iconColor
	tooltip:addLine(line)

	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Shield"%_t
	line.rtext = fighter.shield > 0 and round(fighter.durability) or "None"
	line.icon = "data/textures/icons/shield.png";
	line.iconColor = iconColor
	tooltip:addLine(line)

	tooltip:addLine(TooltipLine(15, 15))

	-- size
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Size"%_t
	line.rtext = round(fighter.volume) --what's the unit?
	line.icon = "data/textures/icons/fighter.png";
	line.iconColor = iconColor
	tooltip:addLine(line)

	-- maneuverability
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Maneuverability"%_t
	line.rtext = round(fighter.turningSpeed, 2) --what's the unit?
	line.icon = "data/textures/icons/dodge.png";
	line.lcolor = fadedTextColor
	line.rcolor = fadedTextColor
	line.iconColor = fadedIconColor
	tooltip:addLine(line)
	
	-- velocity
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Speed"%_t
	line.rtext = round(fighter.maxVelocity * 10.0).."m/s" --lyr_nt
	line.icon = "data/textures/icons/afterburn.png";
	line.iconColor = iconColor
	tooltip:addLine(line)
	
	tooltip:addLine(TooltipLine(15, 15))

	-- crew requirements
	local pilot = CrewProfession(CrewProfessionType.Pilot)

	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = pilot.name
	line.rtext = round(fighter.crew)
	line.icon = pilot.icon
	line.lcolor = fadedTextColor
	line.rcolor = fadedTextColor
	line.iconColor = fadedIconColor
	tooltip:addLine(line)
	
	local num, postfix = getReadableNumber(FighterPrice(fighter))
	local line = TooltipLine(lineHeight, fontSize)
	line.ltext = "Prod. Effort"%_t
	line.rtext = "${num} ${amount}"%_t % {num = tostring(num), amount = postfix}
	line.icon = "data/textures/icons/cog.png";
	line.iconColor = iconColor
	tooltip:addLine(line)

	tooltip:addLine(TooltipLine(15, 15))

	fillDescriptions(fighter, tooltip, true)

	return tooltip
end