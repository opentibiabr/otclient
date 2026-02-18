-- using object, in the future you can open more than one window

-- Missing utility functions
local function formatMoney(value, separator)
    return comma_value(tostring(value))
end

-- Enhanced number formatting function with new K, KK suffixes
local function formatLargeNumber(value)
    if not value then
        return "0"
    end
    
    -- Ensure we have a number
    local numValue = tonumber(value)
    if not numValue or numValue == 0 then
        return "0"
    end
    
    local absValue = math.abs(numValue)
    local isNegative = numValue < 0
    local prefix = isNegative and "-" or ""
    
    if absValue >= 100000000 then
        -- Values 100,000,000+ use KK notation
        -- Example: 100,700,000 = 1,007KK, 345,666,000 = 3,456KK
        local kkValue = math.floor(absValue / 100000)
        return prefix .. comma_value(tostring(kkValue)) .. "KK"
    elseif absValue >= 10000000 then
        -- Values 10,000,000 to 99,999,999 use K notation  
        -- Example: 16,667,000 = 16,667K
        local kValue = math.floor(absValue / 1000)
        return prefix .. comma_value(tostring(kValue)) .. "K"
    else
        -- Values 1 to 9,999,999 show as is
        return prefix .. comma_value(tostring(math.floor(absValue)))
    end
end

local function tokformat(value)
    -- Legacy function - kept for compatibility, redirects to formatLargeNumber
    return formatLargeNumber(value)
end

-- Function to calculate raw XP from modified XP (removing all rate bonuses)
local function calculateRawXP(modifiedExp)
    if not modules.game_skills then
        return modifiedExp  -- Fallback if skills module not available
    end
    
    local totalMultiplier = modules.game_skills.getTotalExpRateMultiplier()
    if totalMultiplier > 0 then
        return math.floor(modifiedExp / totalMultiplier)
    else
        return modifiedExp
    end
end

local valueInSeconds = function(t)
    local d = 0
    local time = 0
    local now = g_clock.millis()
    if #t > 0 then
		local itemsToBeRemoved = 0
        for i, v in ipairs(t) do
            if now - v.tick <= 3000 then
                if time == 0 then
                    time = v.tick
                end
                d = d + v.amount
            else
				itemsToBeRemoved = itemsToBeRemoved + 1
            end
        end

		-- items are added in order, so we can safely
		-- remove only the first items
		for i = 1, itemsToBeRemoved do
			table.remove(t, 1)
		end
    end
    return math.ceil(d/((now-time)/1000))
end

if not HuntingAnalyser then
	HuntingAnalyser = {
		launchTime = 0,
		session = 0,
		startExp = 0,
		lastExp = 0,
		rawXPGain = 0,
		xpGain = 0,
		xpHour = 0,
		rawXpHour = 0,
		loot = 0,
		supplies = 0,
		balance = 0,
		damage = 0,
		damageHour = 0,
		healing = 0,
		healingHour = 0,
		killedMonsters = {},
		lootedItems = {},
		suppliesItems = {},
		healingTicks = {},
		damageTicks = {},
		lootedItemsName = {},

		-- private
		window = nil,
	}

	HuntingAnalyser.__index = HuntingAnalyser
end

function HuntingAnalyser:create()
	HuntingAnalyser.launchTime = 0
	HuntingAnalyser.session = 0
	HuntingAnalyser.startExp = 0
	HuntingAnalyser.lastExp = 0
	HuntingAnalyser.rawXPGain = 0
	HuntingAnalyser.xpGain = 0
	HuntingAnalyser.xpHour = 0
	HuntingAnalyser.rawXpHour = 0
	HuntingAnalyser.loot = 0
	HuntingAnalyser.supplies = 0
	HuntingAnalyser.balance = 0
	HuntingAnalyser.damage = 0
	HuntingAnalyser.damageHour = 0
	HuntingAnalyser.healing = 0
	HuntingAnalyser.healingHour = 0
	HuntingAnalyser.killedMonsters = {}
	HuntingAnalyser.lootedItems = {}
	HuntingAnalyser.suppliesItems = {}
	HuntingAnalyser.healingTicks = {}
	HuntingAnalyser.damageTicks = {}
	HuntingAnalyser.lootedItemsName = {}

	-- private
	HuntingAnalyser.window = openedWindows['huntingButton']
	
	if not HuntingAnalyser.window then
		return
	end

	-- Hide buttons we don't want
	local toggleFilterButton = HuntingAnalyser.window:recursiveGetChildById('toggleFilterButton')
	if toggleFilterButton then
		toggleFilterButton:setVisible(false)
	end
	
	local newWindowButton = HuntingAnalyser.window:recursiveGetChildById('newWindowButton')
	if newWindowButton then
		newWindowButton:setVisible(false)
	end

	-- Position contextMenuButton where toggleFilterButton was (to the left of minimize button)
	local contextMenuButton = HuntingAnalyser.window:recursiveGetChildById('contextMenuButton')
	local minimizeButton = HuntingAnalyser.window:recursiveGetChildById('minimizeButton')
	
	if contextMenuButton and minimizeButton then
		contextMenuButton:setVisible(true)
		contextMenuButton:breakAnchors()
		contextMenuButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
		contextMenuButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
		contextMenuButton:setMarginRight(7)  -- Same margin as toggleFilterButton had
		contextMenuButton:setMarginTop(0)
		
		-- Set up contextMenuButton click handler to show our menu
		contextMenuButton.onClick = function(widget, mousePos)
			local pos = mousePos or g_window.getMousePosition()
			return onHuntingExtra(pos)
		end
	end

	-- Position lockButton to the left of contextMenuButton
	local lockButton = HuntingAnalyser.window:recursiveGetChildById('lockButton')
	
	if lockButton and contextMenuButton then
		lockButton:setVisible(true)
		lockButton:breakAnchors()
		lockButton:addAnchor(AnchorTop, contextMenuButton:getId(), AnchorTop)
		lockButton:addAnchor(AnchorRight, contextMenuButton:getId(), AnchorLeft)
		lockButton:setMarginRight(2)  -- Same margin as in miniwindow style
		lockButton:setMarginTop(0)
	end
end

function onHuntingExtra(mousePosition)
  if cancelNextRelease then
    cancelNextRelease = false
    return false
  end

  local rawXpVisible = HuntingAnalyser.window.contentsPanel.rawXpGain:isVisible()

	local menu = g_ui.createWidget('PopupMenu')
	menu:setGameMenu(true)
	menu:addOption(tr('Start New Session'), function() modules.game_analyser.startNewSession() return end)
	menu:addSeparator()
	menu:addCheckBox(tr('Show Raw XP'), rawXpVisible, function() HuntingAnalyser:setShowBaseXp(not rawXpVisible) end)
	menu:addSeparator()
	menu:addOption(tr('Copy to Clipboard'), function() HuntingAnalyser:clipboardData() end)
	menu:addOption(tr('Save to File'), function() HuntingAnalyser:saveToFile() end)
	menu:addOption(tr('Export to Json'), function() HuntingAnalyser:saveToJson() end)
	menu:display(mousePosition)
  return true
end

function HuntingAnalyser:reset()
	HuntingAnalyser.launchTime = g_clock.millis()
	HuntingAnalyser.session = 0
	HuntingAnalyser.startExp = 0
	HuntingAnalyser.rawXPGain = 0
	HuntingAnalyser.xpGain = 0
	HuntingAnalyser.xpHour = 0
	HuntingAnalyser.rawXpHour = 0
	HuntingAnalyser.loot = 0
	HuntingAnalyser.supplies = 0
	HuntingAnalyser.balance = 0
	HuntingAnalyser.damage = 0
	HuntingAnalyser.damageHour = 0
	HuntingAnalyser.healing = 0
	HuntingAnalyser.healingHour = 0
	HuntingAnalyser.killedMonsters = {}
	HuntingAnalyser.lootedItems = {}
	HuntingAnalyser.suppliesItems = {}
	HuntingAnalyser.healingTicks = {}
	HuntingAnalyser.damageTicks = {}
	HuntingAnalyser.lootedItemsName = {}
	
	-- Reset Input Analyser and Impact Analyser when resetting Hunting Analyser
	if InputAnalyser then
		InputAnalyser:reset()
		InputAnalyser:updateWindow(true)
	end
	
	if ImpactAnalyser then
		ImpactAnalyser:reset()
		ImpactAnalyser:updateWindow(true)
	end

	if PartyHuntAnalyser then
		local player = g_game.getLocalPlayer()
		if player then
			local playerShield = player:getShield()
			local isLeaderShield = (playerShield == ShieldYellow or playerShield == ShieldYellowSharedExp or playerShield == ShieldYellowNoSharedExpBlink)
			
			if isLeaderShield then
				-- Player is party leader - send reset to server for all members
				PartyHuntAnalyser.expectingResetResponse = true
				PartyHuntAnalyser.lastResetTime = g_clock.millis()
				g_game.sendPartyAnalyzerReset()
			else
				-- Player is not leader or not in party - reset only locally
				PartyHuntAnalyser:reset()
			end
		else
			-- No player - reset locally
			PartyHuntAnalyser:reset()
		end
	end
	
	HuntingAnalyser:updateWindow(true)  -- Pass ignoreVisible=true to force update

	-- g_game.resetExperienceData() -- Function doesn't exist, removing call
end

function HuntingAnalyser:setupStartExp(value)
	if HuntingAnalyser.startExp == 0 then
		HuntingAnalyser.launchTime = g_clock.millis()
		HuntingAnalyser.startExp = value
		HuntingAnalyser.lastExp = value  -- Initialize for XP gain tracking
	end
end

local function getPerHourValue(primary)
	local session = HuntingAnalyser.session
	if session == 0 then
		return 0
	end

    local sessionDuration = math.max(1, os.time() - session)
    if sessionDuration <= 0 then
        return 0 
    end

	if sessionDuration < 3600 then
		return primary
	end

	local hitsPerSecond = primary / sessionDuration
	local hitsPerHour = hitsPerSecond * 3600
    return math.floor(hitsPerHour + 0.5)
end

function HuntingAnalyser:updateWindow(ignoreVisible)
	if not HuntingAnalyser.window then
		return
	end

	local player = g_game.getLocalPlayer()
	if not player then
		return
	end

	local contentsPanel = HuntingAnalyser.window.contentsPanel
	local session = HuntingAnalyser.session
	if session == 0 then
		contentsPanel.session:setText("00:00h")
	else
		local duration = math.max(1, os.time() - session)
		local hours = math.floor(duration / 3600)
		local minutes = math.floor((duration % 3600) / 60)
		local sessionTimeStr = string.format("%02d:%02dh", hours, minutes)
		if sessionTimeStr ~= contentsPanel.session:getText() then
			contentsPanel.session:setText(sessionTimeStr)
		end
	end

	local experience = HuntingAnalyser.xpGain
	if not contentsPanel.xpGain.lastExperience or contentsPanel.xpGain.lastExperience ~= experience then
		if experience > 1000000 then
			contentsPanel.xpGain:setText(formatMoney(tokformat(experience), ","))
		else
			contentsPanel.xpGain:setText(formatMoney(experience, ","))
		end
		contentsPanel.xpGain.lastExperience = experience
	end

	-- exp per hour
	local _duration = math.floor((g_clock.millis() - HuntingAnalyser.launchTime)/1000)
	if _duration > 0 then
		HuntingAnalyser.xpHour = math.floor((HuntingAnalyser.xpGain * 3600) / _duration)
	else
		HuntingAnalyser.xpHour = 0
	end

	if HuntingAnalyser.xpHour ~= HuntingAnalyser.xpHour then
		HuntingAnalyser.xpHour = 0
	end

	if not contentsPanel.xpHour.lastValue or contentsPanel.xpHour.lastValue ~= HuntingAnalyser.xpHour then
		if HuntingAnalyser.xpHour > 10000000 then
			contentsPanel.xpHour:setText(formatMoney(tokformat(HuntingAnalyser.xpHour), ","))
		else
			contentsPanel.xpHour:setText(formatMoney(HuntingAnalyser.xpHour, ","))
		end
		contentsPanel.xpHour.lastValue = HuntingAnalyser.xpHour
	end

	local rawExperience = HuntingAnalyser.rawXPGain
	if _duration > 0 then
		HuntingAnalyser.rawXpHour = math.floor((HuntingAnalyser.rawXPGain * 3600) / _duration)
	else
		HuntingAnalyser.rawXpHour = 0
	end

	if not contentsPanel.rawXpGain.lastValue or contentsPanel.rawXpGain.lastValue ~= rawExperience then
		if rawExperience > 10000000 then
			contentsPanel.rawXpGain:setText(formatMoney(tokformat(rawExperience), ","))
		else
			contentsPanel.rawXpGain:setText(formatMoney(rawExperience, ","))
		end
		contentsPanel.rawXpGain.lastValue = rawExperience
	end

	if not contentsPanel.rawXpHour.lastValue or contentsPanel.rawXpHour.lastValue ~= HuntingAnalyser.rawXpHour then
		if HuntingAnalyser.rawXpHour > 10000000 then
			contentsPanel.rawXpHour:setText(formatMoney(tokformat(HuntingAnalyser.rawXpHour), ","))
		else
			contentsPanel.rawXpHour:setText(formatMoney(HuntingAnalyser.rawXpHour, ","))
		end
		contentsPanel.rawXpHour.lastValue = HuntingAnalyser.rawXpHour
	end

	-- supplies
	if not contentsPanel.loot.lastValue or contentsPanel.loot.lastValue ~= HuntingAnalyser.loot then
		if HuntingAnalyser.loot > 1000000 then
			contentsPanel.loot:setText(formatMoney(tokformat(HuntingAnalyser.loot), ","))
		else
			contentsPanel.loot:setText(formatMoney(HuntingAnalyser.loot, ","))
		end
		contentsPanel.loot.lastValue = HuntingAnalyser.loot
	end

	if not contentsPanel.supplies.lastValue or contentsPanel.supplies.lastValue ~= HuntingAnalyser.supplies then
		if HuntingAnalyser.supplies > 1000000 then
			contentsPanel.supplies:setText(formatMoney(tokformat(HuntingAnalyser.supplies), ","))
		else
			contentsPanel.supplies:setText(formatMoney(HuntingAnalyser.supplies, ","))
		end
		contentsPanel.supplies.lastValue = HuntingAnalyser.supplies
	end

	HuntingAnalyser:checkBalance()
	if not contentsPanel.balance.lastValue or contentsPanel.balance.lastValue ~= HuntingAnalyser.balance then
		if HuntingAnalyser.balance > 1000000 then
			contentsPanel.balance:setText(formatMoney(tokformat(HuntingAnalyser.balance), ","))
		else
			contentsPanel.balance:setText(comma_value(HuntingAnalyser.balance))
		end
		contentsPanel.balance.lastValue = HuntingAnalyser.balance
	end


	contentsPanel.balance:setColor(HuntingAnalyser.balance >= 0 and '#00EB00' or '#f36500')

	if not contentsPanel.damage.lastValue or contentsPanel.damage.lastValue ~= HuntingAnalyser.damage then
		if HuntingAnalyser.damage > 1000000 then
			contentsPanel.damage:setText(formatMoney(tokformat(HuntingAnalyser.damage), ","))
		else
			contentsPanel.damage:setText(formatMoney(HuntingAnalyser.damage, ","))
		end
		contentsPanel.damage.lastValue = HuntingAnalyser.damage
	end

	local currentDamagePerHour = getPerHourValue(HuntingAnalyser.damage)
	
	-- Calculate damage per hour like XP/h (continuously updating)
	local _duration = math.floor((g_clock.millis() - HuntingAnalyser.launchTime)/1000)
	if _duration > 0 then
		HuntingAnalyser.damageHour = math.floor((HuntingAnalyser.damage * 3600) / _duration)
	else
		HuntingAnalyser.damageHour = 0
	end
	
	if HuntingAnalyser.damageHour ~= HuntingAnalyser.damageHour then
		HuntingAnalyser.damageHour = 0
	end
	
	if not contentsPanel.damageHour.lastValue or contentsPanel.damageHour.lastValue ~= HuntingAnalyser.damageHour then
		if HuntingAnalyser.damageHour > 1000000 then
			contentsPanel.damageHour:setText(formatMoney(tokformat(HuntingAnalyser.damageHour), ","))
		else
			contentsPanel.damageHour:setText(formatMoney(HuntingAnalyser.damageHour, ","))
		end
		contentsPanel.damageHour.lastValue = HuntingAnalyser.damageHour
	end

	if not contentsPanel.healing.lastValue or contentsPanel.healing.lastValue ~= HuntingAnalyser.healing then
		if HuntingAnalyser.healing > 1000000 then
			contentsPanel.healing:setText(formatMoney(tokformat(HuntingAnalyser.healing), ","))
		else
			contentsPanel.healing:setText(formatMoney(HuntingAnalyser.healing, ","))
		end
		contentsPanel.healing.lastValue = HuntingAnalyser.healing
	end

	local curHPS = valueInSeconds(HuntingAnalyser.healingTicks)
	
	-- Calculate healing per hour like XP/h (continuously updating)
	if _duration > 0 then
		HuntingAnalyser.healingHour = math.floor((HuntingAnalyser.healing * 3600) / _duration)
	else
		HuntingAnalyser.healingHour = 0
	end
	
	if HuntingAnalyser.healingHour ~= HuntingAnalyser.healingHour then
		HuntingAnalyser.healingHour = 0
	end

	if not contentsPanel.healHour.lastValue or contentsPanel.healHour.lastValue ~= HuntingAnalyser.healingHour then
		if HuntingAnalyser.healingHour > 1000000 then
			contentsPanel.healHour:setText(formatMoney(tokformat(HuntingAnalyser.healingHour), ","))
		else
			contentsPanel.healHour:setText(formatMoney(HuntingAnalyser.healingHour, ","))
		end
		contentsPanel.healHour.lastValue = HuntingAnalyser.healingHour
	end

	-- kill
	if table.empty(HuntingAnalyser.killedMonsters) then
		contentsPanel.killedMonsters.monster:setText('None')
		contentsPanel.killedMonsters.monster:setHeight(20)
		contentsPanel.killedMonsters:setHeight(20)
	else
		local _count = 0
		local text = '';
		for monster, count in pairs(HuntingAnalyser.killedMonsters) do
			_count = _count + 1
			if text == '' then
				text = string.format("%dx %s", count, monster)
			else
				text = string.format("%s\n%dx %s", text, count, monster)
			end
		end
		contentsPanel.killedMonsters.monster:setText(text)
		contentsPanel.killedMonsters.monster:setHeight(15 * _count)
		contentsPanel.killedMonsters:setHeight(15 * (_count))
	end

	-- looted
	if table.empty(HuntingAnalyser.lootedItemsName) then
		contentsPanel.lootedItems.loot:setText('None')
		contentsPanel.lootedItems.loot:setHeight(20)
		contentsPanel.lootedItems:setHeight(20)
	else
		local _count = 0
		local text = '';
		for name, count in pairs(HuntingAnalyser.lootedItemsName) do
			_count = _count + 1
			if text == '' then
				text = string.format("%dx %s", count, short_text(name, 10))
			else
				text = string.format("%s\n%dx %s", text, count, name)
			end
		end
		contentsPanel.lootedItems.loot:setText(text)
		contentsPanel.lootedItems.loot:setHeight(15 * _count)
		contentsPanel.lootedItems:setHeight(15 * (_count))
	end
end

-- Getters
function HuntingAnalyser:getLaunchTime() return HuntingAnalyser.launchTime end
function HuntingAnalyser:getSession() return HuntingAnalyser.session end
function HuntingAnalyser:getStartExp() return HuntingAnalyser.startExp end
function HuntingAnalyser:getRawXPGain() return HuntingAnalyser.rawXPGain end
function HuntingAnalyser:getXpGain() return HuntingAnalyser.xpGain end
function HuntingAnalyser:getXpHour() return HuntingAnalyser.xpHour end
function HuntingAnalyser:getLoot() return HuntingAnalyser.loot end
function HuntingAnalyser:getSupplies() return HuntingAnalyser.supplies end
function HuntingAnalyser:getBalance() return HuntingAnalyser.balance end
function HuntingAnalyser:getDamage() return HuntingAnalyser.damage end
function HuntingAnalyser:getDamageHour() return HuntingAnalyser.damageHour end
function HuntingAnalyser:getHealing() return HuntingAnalyser.healing end
function HuntingAnalyser:getHealingHour() return HuntingAnalyser.healingHour end
function HuntingAnalyser:getKilledMonsters() return HuntingAnalyser.killedMonsters end
function HuntingAnalyser:getLootedItems() return HuntingAnalyser.lootedItems end
function HuntingAnalyser:getSuppliesItems() return HuntingAnalyser.suppliesItems end
function HuntingAnalyser:getHealingTicks() return HuntingAnalyser.healingTicks end
function HuntingAnalyser:getDamageTicks() return HuntingAnalyser.damageTicks end

-- Setters
function HuntingAnalyser:setLaunchTime(value) HuntingAnalyser.launchTime = value end
function HuntingAnalyser:setSession(value) HuntingAnalyser.session = value end
function HuntingAnalyser:setStartExp(value) HuntingAnalyser.startExp = value end
function HuntingAnalyser:setRawXPGain(value) HuntingAnalyser.rawXPGain = value end
function HuntingAnalyser:setXpGain(value) HuntingAnalyser.xpGain = value end
function HuntingAnalyser:setXpHour(value) HuntingAnalyser.xpHour = value end
function HuntingAnalyser:setLoot(value) HuntingAnalyser.loot = value end
function HuntingAnalyser:setSupplies(value) HuntingAnalyser.supplies = value end
function HuntingAnalyser:setBalance(value) HuntingAnalyser.balance = value end
function HuntingAnalyser:setDamage(value) HuntingAnalyser.damage = value end
function HuntingAnalyser:setDamageHour(value) HuntingAnalyser.damageHour = value end
function HuntingAnalyser:setHealing(value) HuntingAnalyser.healing = value end
function HuntingAnalyser:setHealingHour(value) HuntingAnalyser.healingHour = value end
function HuntingAnalyser:setKilledMonsters(value) HuntingAnalyser.killedMonsters = value end
function HuntingAnalyser:setLootedItems(value) HuntingAnalyser.lootedItems = value end
function HuntingAnalyser:setSuppliesItems(value) HuntingAnalyser.suppliesItems = value end
function HuntingAnalyser:setHealingTicks(value) HuntingAnalyser.healingTicks = value end
function HuntingAnalyser:setDamageTicks(value) HuntingAnalyser.damageTicks = value end

-- updaters
function HuntingAnalyser:addRawXPGain(value) 
	-- Calculate the actual raw XP by removing rate modifiers
	local actualRawXP = calculateRawXP(value)
	HuntingAnalyser.rawXPGain = HuntingAnalyser.rawXPGain + actualRawXP
	HuntingAnalyser:updateWindow()
end

function HuntingAnalyser:addXpGain(value) 
	HuntingAnalyser.xpGain = HuntingAnalyser.xpGain + value
	HuntingAnalyser:updateWindow()
end

function HuntingAnalyser:addLootedItems(item, name)
	local itemId = item:getId()
	local count = item:getCount()
	local data = HuntingAnalyser.lootedItems[itemId]
	if not data then
		local price = 0
	
		-- Special handling for coins - they have fixed inherent values
		if itemId == 3031 then  -- Gold coin
			price = 1
		elseif itemId == 3035 then  -- Platinum coin (worth 100 gold)
			price = 100
		elseif itemId == 3043 then  -- Crystal coin (worth 10,000 gold)
			price = 10000
		else
			-- Get all pricing values for non-coin items
			local npcBuyValue = 0
			local npcSellValue = 0
			local meanPrice = 0
			local avgMarketValue = 0
			local defaultBuyPrice = 0
			local cyclopediaValue = 0
			
			-- NPC Buy Value (what NPCs pay us for the item)
			if modules.game_cyclopedia and modules.game_cyclopedia.Cyclopedia and modules.game_cyclopedia.Cyclopedia.Items and modules.game_cyclopedia.Cyclopedia.Items.getNpcValue then
				npcBuyValue = modules.game_cyclopedia.Cyclopedia.Items.getNpcValue(item, true)
			end
			
			-- NPC Sell Value (what NPCs charge us for the item)
			if modules.game_cyclopedia and modules.game_cyclopedia.Cyclopedia and modules.game_cyclopedia.Cyclopedia.Items and modules.game_cyclopedia.Cyclopedia.Items.getNpcValue then
				npcSellValue = modules.game_cyclopedia.Cyclopedia.Items.getNpcValue(item, false)
			end
						
			-- Market Mean Price
			if item.getMeanPrice then
				local success, result = pcall(function() return item:getMeanPrice() end)
				if success and result then
					meanPrice = result
				end
			end
			
			-- Average Market Value using getMarketOfferAverages
			local itemId = item:getId()
			if itemId and modules.game_cyclopedia and modules.game_cyclopedia.Cyclopedia and 
			   modules.game_cyclopedia.Cyclopedia.Items and modules.game_cyclopedia.Cyclopedia.Items.getMarketOfferAverages then
				avgMarketValue = modules.game_cyclopedia.Cyclopedia.Items.getMarketOfferAverages(itemId)
			else
				-- Fallback: getMarketOfferAverages method not available
				print(string.format("[LOOT DEBUG] DEBUG: getMarketOfferAverages method not available"))
			end
			
			-- Default Buy Price
			if item.getDefaultBuyPrice then
				local success, result = pcall(function() return item:getDefaultBuyPrice() end)
				if success and result then
					defaultBuyPrice = result
				end
			end
			
			-- Cyclopedia Current Item Value
			if modules.game_cyclopedia and modules.game_cyclopedia.Cyclopedia and modules.game_cyclopedia.Cyclopedia.Items and modules.game_cyclopedia.Cyclopedia.Items.getCurrentItemValue then
				cyclopediaValue = modules.game_cyclopedia.Cyclopedia.Items.getCurrentItemValue(item)
			end			
			-- Use Cyclopedia value as the final price
			price = cyclopediaValue
		end
		
		HuntingAnalyser.loot = HuntingAnalyser.loot + (price * count)
		HuntingAnalyser.lootedItems[itemId] = {itemId = itemId, name = name, count = count, price = price}
	else
		data.count = data.count + count
		HuntingAnalyser.loot = HuntingAnalyser.loot + (data.price * count)
	end

	if not HuntingAnalyser.lootedItemsName[name] then
		HuntingAnalyser.lootedItemsName[name] = 0
	end

	HuntingAnalyser.lootedItemsName[name] = HuntingAnalyser.lootedItemsName[name] + count
end

-- Function to get supply price based on user's Cyclopedia preference (same as SupplyAnalyser)
local function getCurrentPrice(itemPtr)
	if not itemPtr then
		return 0
	end
	
	-- Try to get price from Cyclopedia module if available (respects user preference)
	if Cyclopedia and Cyclopedia.Items and Cyclopedia.Items.getCurrentItemValue then
		-- For supplies, we need to modify the logic slightly:
		-- When user selects "NPC Buy Value", we should use NPC sale price (what we pay for supplies)
		-- When user selects "Market Average Value", we should use market average price
		
		-- Get market average price
		local avgMarket = 0
		if itemPtr.getMeanPrice then
			local success, result = pcall(function() return itemPtr:getMeanPrice() end)
			if success and result then
				avgMarket = result
			end
		elseif itemPtr.getId then
			-- Use getMarketOfferAverages for market data
			local itemId = itemPtr:getId()
			if itemId and modules.game_cyclopedia and modules.game_cyclopedia.Cyclopedia and 
			   modules.game_cyclopedia.Cyclopedia.Items and modules.game_cyclopedia.Cyclopedia.Items.getMarketOfferAverages then
				avgMarket = modules.game_cyclopedia.Cyclopedia.Items.getMarketOfferAverages(itemId)
			end
		end
		
		-- Get NPC sale price (what NPCs charge us for supplies)
		local npcSalePrice = 0
		if itemPtr.getNpcSaleData then
			local success, npcSaleData = pcall(function() return itemPtr:getNpcSaleData() end)
			if success and npcSaleData and #npcSaleData > 0 then
				-- Get the highest sale price from NPCs (most expensive option for supplies)
				for _, npcData in ipairs(npcSaleData) do
					if npcData.salePrice and npcData.salePrice > npcSalePrice then
						npcSalePrice = npcData.salePrice
					end
				end
			end
		end
		
		-- If no NPC sale price found, fallback to market price
		if npcSalePrice == 0 then
			npcSalePrice = avgMarket
		end
		
		-- Use getCurrentItemValue to check user preference, then adapt for supplies
		local currentValue = Cyclopedia.Items.getCurrentItemValue(itemPtr)
		
		-- If the current value equals market price, user prefers market pricing
		if currentValue == avgMarket then
			return avgMarket
		else
			-- User prefers NPC values, but for supplies we need sale price instead of buy price
			return npcSalePrice
		end
	else
		-- Fallback implementation when Cyclopedia module is not available
		local npcSalePrice = 0
		
		-- Try to get NPC sale data (what NPCs sell to players)
		if itemPtr.getNpcSaleData then
			local success, npcSaleData = pcall(function() return itemPtr:getNpcSaleData() end)
			if success and npcSaleData and #npcSaleData > 0 then
				-- Get the highest sale price from NPCs (most expensive option that NPCs charge us for the item)
				for _, npcData in ipairs(npcSaleData) do
					if npcData.salePrice and npcData.salePrice > npcSalePrice then
						npcSalePrice = npcData.salePrice
					end
				end
			end
		end
		
		-- If no NPC sale price found, try market price as fallback
		if npcSalePrice == 0 then
			if itemPtr.getMeanPrice then
				local success, result = pcall(function() return itemPtr:getMeanPrice() end)
				if success and result then
					npcSalePrice = result
				end
			elseif itemPtr.getId then
				-- Use getMarketOfferAverages for market data
				local itemId = itemPtr:getId()
				if itemId and modules.game_cyclopedia and modules.game_cyclopedia.Cyclopedia and 
				   modules.game_cyclopedia.Cyclopedia.Items and modules.game_cyclopedia.Cyclopedia.Items.getMarketOfferAverages then
					npcSalePrice = modules.game_cyclopedia.Cyclopedia.Items.getMarketOfferAverages(itemId)
				end
			end
		end
		
		return npcSalePrice
	end
end

function HuntingAnalyser:addSuppliesItems(itemId)
	local supplyItemInfo = HuntingAnalyser.suppliesItems[itemId]
	if not HuntingAnalyser.suppliesItems[itemId] then
		-- only at the first time a supply item is added, it will
		-- have to create a dummy item in order to retrieve the
		-- item price value

		local itemPtr = Item.create(itemId, 1)
		local price = getCurrentPrice(itemPtr)
		HuntingAnalyser.suppliesItems[itemId] = { count = 0, price = price }
		supplyItemInfo = HuntingAnalyser.suppliesItems[itemId]
		itemPtr = nil
	end

	supplyItemInfo.count = supplyItemInfo.count + 1
	HuntingAnalyser.supplies = HuntingAnalyser.supplies + supplyItemInfo.price
end

function HuntingAnalyser:updateLootedItemValue(itemId, newPrice)
	local itemData = HuntingAnalyser.lootedItems[itemId]
	if not itemData then
		return
	end

	local oldTotalValue = itemData.price * itemData.count
	local newTotalValue = newPrice * itemData.count
	HuntingAnalyser.loot = HuntingAnalyser.loot - oldTotalValue + newTotalValue

	itemData.price = newPrice
end

function HuntingAnalyser:checkBalance()
	HuntingAnalyser.balance = HuntingAnalyser.loot + (HuntingAnalyser.supplies * -1)
end

function HuntingAnalyser:addHealing(value)
	HuntingAnalyser.healing = HuntingAnalyser.healing + value
	HuntingAnalyser.healingTicks[#HuntingAnalyser.healingTicks + 1] = {amount = value, tick = g_clock.millis()}
end

function HuntingAnalyser:addDealDamage(value)
	HuntingAnalyser.damage = HuntingAnalyser.damage + value
	HuntingAnalyser.damageTicks[#HuntingAnalyser.damageTicks + 1] = {amount = value, tick = g_clock.millis()}
end

function HuntingAnalyser:addMonsterKilled(monsterName)
	if not HuntingAnalyser.killedMonsters[monsterName] then
		HuntingAnalyser.killedMonsters[monsterName] = 0
	end

	HuntingAnalyser.killedMonsters[monsterName] = HuntingAnalyser.killedMonsters[monsterName] + 1
end

----------------- others functions
function HuntingAnalyser:clipboardData()

	local duration = math.max(1, os.time() - HuntingAnalyser.session )
	local hours = math.floor(duration / 3600)
	local minutes = math.floor((duration % 3600) / 60)

	local text = "Session data: From " .. os.date('%Y-%m-%d, %H:%M:%S', HuntingAnalyser.session) .." to ".. os.date('%Y-%m-%d, %H:%M:%S')
	text = text .. "\nSession: " .. string.format("%02d:%02dh", hours, minutes)
	text = text .. "\nRaw XP Gain: " .. formatMoney(HuntingAnalyser.rawXPGain, ",")
	text = text .. "\nXP Gain: " .. formatMoney(HuntingAnalyser.xpGain, ",")
	text = text .. "\nXP/h: " .. formatMoney(HuntingAnalyser.xpHour, ",")
	text = text .. "\nRaw XP/h: " .. formatMoney(HuntingAnalyser.rawXpHour, ",")
	text = text .. "\nLoot: " .. formatMoney(HuntingAnalyser.loot, ",")
	text = text .. "\nSupplies: " .. formatMoney(HuntingAnalyser.supplies, ",")
	text = text .. "\nBalance: " .. formatMoney(HuntingAnalyser.balance, ",")
	text = text .. "\nDamage: " .. formatMoney(HuntingAnalyser.damage, ",")
	text = text .. "\nDamage/h: " .. formatMoney(HuntingAnalyser.damageHour, ",")
	text = text .. "\nHealing: " .. formatMoney(HuntingAnalyser.healing, ",")
	text = text .. "\nHealing/h: " .. formatMoney(HuntingAnalyser.healingHour, ",")
	text = text .. "\nKilled Monsters: "
	if table.empty(HuntingAnalyser.killedMonsters) then
		text = text .. "\n\tNone"
	else
		local _text = '';
		for monster, count in pairs(HuntingAnalyser.killedMonsters) do
			if _text == '' then
				_text = string.format("\t%dx %s", count, monster)
			else
				_text = string.format("%s\n\t%dx %s", _text, count, monster)
			end
		end
		text = text .. "\n" .. _text
	end
	text = text .. "\nLooted Items: "
	if table.empty(HuntingAnalyser.lootedItemsName) then
		text = text .. "\n\tNone"
	else
		local _text = '';
		for name, count in pairs(HuntingAnalyser.lootedItemsName) do
			if _text == '' then
				_text = string.format("\t%dx %s", count, name)
			else
				_text = string.format("%s\n\t%dx %s", _text, count, name)
			end
		end
		text = text .. "\n" .. _text
	end
	g_window.setClipboardText(text)
end

function HuntingAnalyser:saveToFile()

	local duration = math.max(1, os.time() - HuntingAnalyser.session )
	local hours = math.floor(duration / 3600)
	local minutes = math.floor((duration % 3600) / 60)

	local text = "Session data: From " .. os.date('%Y-%m-%d, %H:%M:%S', HuntingAnalyser.session) .." to ".. os.date('%Y-%m-%d, %H:%M:%S')
	text = text .. "\nSession: " .. string.format("%02d:%02dh", hours, minutes)
	text = text .. "\nRaw XP Gain: " .. formatMoney(HuntingAnalyser.rawXPGain, ",")
	text = text .. "\nXP Gain: " .. formatMoney(HuntingAnalyser.xpGain, ",")
	text = text .. "\nXP/h: " .. formatMoney(HuntingAnalyser.xpHour, ",")
	text = text .. "\nRaw XP/h: " .. formatMoney(HuntingAnalyser.rawXpHour, ",")
	text = text .. "\nLoot: " .. formatMoney(HuntingAnalyser.loot, ",")
	text = text .. "\nSupplies: " .. formatMoney(HuntingAnalyser.supplies, ",")
	text = text .. "\nBalance: " .. formatMoney(HuntingAnalyser.balance, ",")
	text = text .. "\nDamage: " .. formatMoney(HuntingAnalyser.damage, ",")
	text = text .. "\nDamage/h: " .. formatMoney(HuntingAnalyser.damageHour, ",")
	text = text .. "\nHealing: " .. formatMoney(HuntingAnalyser.healing, ",")
	text = text .. "\nHealing/h: " .. formatMoney(HuntingAnalyser.healingHour, ",")
	text = text .. "\nKilled Monsters: "
	if table.empty(HuntingAnalyser.killedMonsters) then
		text = text .. "\n\tNone"
	else
		local _text = '';
		for monster, count in pairs(HuntingAnalyser.killedMonsters) do
			if _text == '' then
				_text = string.format("\t%dx %s", count, monster)
			else
				_text = string.format("%s\n\t%dx %s", _text, count, monster)
			end
		end
		text = text .. "\n" .. _text
	end
	text = text .. "\nLooted Items: "
	if table.empty(HuntingAnalyser.lootedItemsName) then
		text = text .. "\n\tNone"
	else
		local _text = '';
		for name, count in pairs(HuntingAnalyser.lootedItemsName) do
			if _text == '' then
				_text = string.format("\t%dx %s", count, name)
			else
				_text = string.format("%s\n\t%dx %s", _text, count, name)
			end
		end
		text = text .. "\n" .. _text
	end

	local filename = 'Hunting_Session_' .. os.date('%Y-%m-%d', HuntingAnalyser.session) .. '_' .. HuntingAnalyser.session/1000 .. '.txt'
	local filepath = filename

	g_resources.writeFileContents(filepath, text)
	modules.game_textmessage.displayStatusMessage(tr('Hunting Session data has been saved to location \'%s\'', filename))
end

function HuntingAnalyser:saveToJson()
	local huntingData = {}

	huntingData.Balance = formatMoney(HuntingAnalyser.balance, ",")
	huntingData.Damage = formatMoney(HuntingAnalyser.damage, ",")
	huntingData.DamageHour = formatMoney(HuntingAnalyser.damageHour, ",")
	huntingData.Healing = formatMoney(HuntingAnalyser.healing, ",")
	huntingData.HealingHour = formatMoney(HuntingAnalyser.healingHour, ",")
	huntingData.KilledMonsters = {}
	if not table.empty(HuntingAnalyser.killedMonsters) then
		for monster, count in pairs(HuntingAnalyser.killedMonsters) do
			huntingData.KilledMonsters[#huntingData.KilledMonsters + 1] = {Count = count, Name = monster}
		end
	end
	huntingData.Loot = formatMoney(HuntingAnalyser.loot, ",")
	huntingData.LootedItems = {}
	if not table.empty(HuntingAnalyser.lootedItemsName) then
		for name, count in pairs(HuntingAnalyser.lootedItemsName) do
			huntingData.LootedItems[#huntingData.LootedItems + 1] = {Count = count, Name = name}
		end
	end
	huntingData.RawXPGain = formatMoney(HuntingAnalyser.rawXPGain, ",")
	huntingData.SessionEnd = os.date('%Y-%m-%d, %H:%M:%S')
	local duration = math.max(1, os.time() - HuntingAnalyser.session )
	local hours = math.floor(duration / 3600)
	local minutes = math.floor((duration % 3600) / 60)
	huntingData.SessionLength = string.format("%02d:%02dh", hours, minutes)
	huntingData.SessionStart = os.date('%Y-%m-%d, %H:%M:%S', HuntingAnalyser.session)
	huntingData.Supplies = formatMoney(HuntingAnalyser.supplies, ",")
	huntingData.XPGain = formatMoney(HuntingAnalyser.xpGain, ",")
	huntingData.XPGainHour = formatMoney(HuntingAnalyser.xpHour, ",")
	huntingData.RawXPGainHour = formatMoney(HuntingAnalyser.rawXpHour, ",")


	local filename = 'Hunting_Session_' .. os.date('%Y-%m-%d', HuntingAnalyser.session) .. '_' .. HuntingAnalyser.session/1000 .. '.json'
	local filepath = filename

	local status, result = pcall(function() return json.encode(huntingData, 2) end)
	if not status then
		return g_logger.error("Error while saving hunting analyzer profile settings. Data won't be saved. Details: " .. result)
 	end
	if result:len() > 100 * 1024 * 1024 then
		return g_logger.error("Something went wrong, file is above 100MB, won't be saved")
	end
	g_resources.writeFileContents(filepath, result)
	modules.game_textmessage.displayStatusMessage(tr('Hunting Session data has been saved to location \'%s\'', filename))

end

function HuntingAnalyser:setShowBaseXp(value)
	HuntingAnalyser.window.contentsPanel.rawXpLabel:setVisible(value)
	HuntingAnalyser.window.contentsPanel.rawXpGain:setVisible(value)
	HuntingAnalyser.showBaseXp = value

	if HuntingAnalyser.showBaseXp then
		HuntingAnalyser.window.contentsPanel.xpGain:addAnchor(AnchorTop, 'rawXpGain', AnchorBottom)
		HuntingAnalyser.window.contentsPanel.xpLabel:addAnchor(AnchorTop, 'rawXpLabel', AnchorBottom)
	else
		HuntingAnalyser.window.contentsPanel.xpGain:addAnchor(AnchorTop, 'session', AnchorBottom)
		HuntingAnalyser.window.contentsPanel.xpLabel:addAnchor(AnchorTop, 'sessionLabel', AnchorBottom)
	end

	HuntingAnalyser.window.contentsPanel.rawXpHourLabel:setVisible(value)
	HuntingAnalyser.window.contentsPanel.rawXpHour:setVisible(value)

	if HuntingAnalyser.showBaseXp then
		HuntingAnalyser.window.contentsPanel.xpHour:addAnchor(AnchorTop, 'rawXpHour', AnchorBottom)
		HuntingAnalyser.window.contentsPanel.xpHourLabel:addAnchor(AnchorTop, 'rawXpHourLabel', AnchorBottom)
	else
		HuntingAnalyser.window.contentsPanel.xpHour:addAnchor(AnchorTop, 'xpGain', AnchorBottom)
		HuntingAnalyser.window.contentsPanel.xpHourLabel:addAnchor(AnchorTop, 'xpLabel', AnchorBottom)
	end

end

function HuntingAnalyser:loadConfigJson()
	local player = g_game.getLocalPlayer()
	if not player then
		return
	end

	-- Set default configuration
	local config = {
		showBaseXp = false
	}

	local file = "/characterdata/" .. player:getId() .. "/huntingsessionanalyser.json"
	if g_resources.fileExists(file) then
		local status, result = pcall(function()
			return json.decode(g_resources.readFileContents(file))
		end)

		if not status then
			return g_logger.error("Error while reading characterdata file. Details: " .. result)
		end

		config = result
	end

	HuntingAnalyser.showBaseXp = config.showBaseXp
	HuntingAnalyser:setShowBaseXp(HuntingAnalyser.showBaseXp)
end

function HuntingAnalyser:saveConfigJson()
	local config = {
		showBaseXp = HuntingAnalyser.showBaseXp
	}

	local player = g_game.getLocalPlayer()
	if not player then return end
	
	-- Ensure the characterdata directory exists
	local characterDir = "/characterdata/" .. player:getId()
	pcall(function() g_resources.makeDir("/characterdata") end)
	pcall(function() g_resources.makeDir(characterDir) end)
	
	local file = "/characterdata/" .. player:getId() .. "/huntingsessionanalyser.json"
	local status, result = pcall(function() return json.encode(config, 2) end)
	if not status then
		return g_logger.error("Error while saving profile HuntingAnalyzer. Data won't be saved. Details: " .. result)
	end

	if result:len() > 100 * 1024 * 1024 then
		return g_logger.error("Something went wrong, file is above 100MB, won't be saved")
	end
	
	-- Safely attempt to write the file, ignoring errors during logout
	local writeStatus, writeError = pcall(function()
		return g_resources.writeFileContents(file, result)
	end)
	
	if not writeStatus then
		-- Log the error but don't spam the console during normal logout
		g_logger.debug("Could not save HuntingAnalyser config during logout: " .. tostring(writeError))
	end
end
