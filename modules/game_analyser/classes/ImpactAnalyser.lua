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

if not ImpactAnalyser then
	ImpactAnalyser = {
		launchTime = 0,
		session = 0,

		damageTotal = 0,
		dps = 0,
		maxDPS = 0,
		damageTicks = {},
		healingTicks = {},
		damageEffect = {},
		allTimeHightDps = 0,
		allTimeHightHps = 0,
		targetDPS = 1,
		gaugeDPSVisible = true,
		graphDPSVisible = true,
		gaugeHPSVisible = true,
		graphHPSVisible = true,
		damageTypeVisible = true,
		targetHPS = 1,

		healingTotal = 0,
		maxHPS = 0,

		-- Session data storage for 60 minutes
		sessionDamageTicks = {},
		sessionHealingTicks = {},
		sessionMode = false,
		sessionDPSMinuteData = {}, -- Array to store DPS data per minute for the graph
		sessionHPSMinuteData = {}, -- Array to store HPS data per minute for the graph
		lastMinuteUpdate = 0, -- Track when we last updated minute data

		-- private
		window = nil,
	}
	ImpactAnalyser.__index = ImpactAnalyser
end
local targetMaxMargin = 142

local imageDir = '/game_cyclopedia/images/bestiary/icons/monster-icon-%s-resist'

local effectsFiles = {
	[0] = 'physical',
	[1] = 'fire',
	[2] = 'earth',
	[3] = 'energy',
	[4] = 'ice',
	[5] = 'holy',
	[6] = 'death',
	[7] = 'healing',
	[8] = 'drowning',
	[9] = 'lifedrain',
	[10] = 'manadrain',
	[11] = 'agony',
	[12] = 'agony',
}

local valueInSeconds = function(t)
    local d = 0
    local time = 0
    local now = g_clock.millis()
    if #t > 0 then
		local itemsToBeRemoved = 0
        for i, v in ipairs(t) do
            if now - v.tick <= 10000 then
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

-- Function to handle session data for 60 minutes
local valueInSessionMode = function(t)
    local d = 0
    local time = 0
    local now = g_clock.millis()
    local sessionDuration = 60 * 60 * 1000 -- 60 minutes in milliseconds
    
    if #t > 0 then
        local itemsToBeRemoved = 0
        for i, v in ipairs(t) do
            if now - v.tick <= sessionDuration then
                if time == 0 then
                    time = v.tick
                end
                d = d + v.amount
            else
                itemsToBeRemoved = itemsToBeRemoved + 1
            end
        end

        -- Remove expired items
        for i = 1, itemsToBeRemoved do
            table.remove(t, 1)
        end
    end
    
    if time > 0 then
        return math.ceil(d/((now-time)/1000))
    else
        return 0
    end
end

function ImpactAnalyser:create()
	ImpactAnalyser.launchTime = 0
	ImpactAnalyser.session = 0

	ImpactAnalyser.damageTotal = 0
	ImpactAnalyser.dps = 0
	ImpactAnalyser.maxDPS = 0
	ImpactAnalyser.damageTicks = {}
	ImpactAnalyser.healingTicks = {}
	ImpactAnalyser.damageEffect = {}
	ImpactAnalyser.allTimeHightDps = 0
	ImpactAnalyser.allTimeHightHps = 0
	ImpactAnalyser.targetDPS = 1
	ImpactAnalyser.gaugeDPSVisible = true
	ImpactAnalyser.graphDPSVisible = true
	ImpactAnalyser.gaugeHPSVisible = true
	ImpactAnalyser.graphHPSVisible = true
	ImpactAnalyser.damageTypeVisible = true
	ImpactAnalyser.targetHPS = 1

	ImpactAnalyser.healingTotal = 0
	ImpactAnalyser.maxHPS = 0
	
	-- Initialize session tracking
	ImpactAnalyser.sessionDamageTicks = {}
	ImpactAnalyser.sessionHealingTicks = {}
	ImpactAnalyser.sessionDPSMinuteData = {}
	ImpactAnalyser.sessionHPSMinuteData = {}
	ImpactAnalyser.lastMinuteUpdate = g_clock.millis()

	-- private
	ImpactAnalyser.window = openedWindows['impactButton']
	
	if not ImpactAnalyser.window then
		return
	end

	-- Hide buttons we don't want
	local toggleFilterButton = ImpactAnalyser.window:recursiveGetChildById('toggleFilterButton')
	if toggleFilterButton then
		toggleFilterButton:setVisible(false)
	end
	
	local newWindowButton = ImpactAnalyser.window:recursiveGetChildById('newWindowButton')
	if newWindowButton then
		newWindowButton:setVisible(false)
	end

	-- Position contextMenuButton where toggleFilterButton was (to the left of minimize button)
	local contextMenuButton = ImpactAnalyser.window:recursiveGetChildById('contextMenuButton')
	local minimizeButton = ImpactAnalyser.window:recursiveGetChildById('minimizeButton')
	
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
			return onImpactExtra(pos)
		end
	end

	-- Position lockButton to the left of contextMenuButton
	local lockButton = ImpactAnalyser.window:recursiveGetChildById('lockButton')
	
	if lockButton and contextMenuButton then
		lockButton:setVisible(true)
		lockButton:breakAnchors()
		lockButton:addAnchor(AnchorTop, contextMenuButton:getId(), AnchorTop)
		lockButton:addAnchor(AnchorRight, contextMenuButton:getId(), AnchorLeft)
		lockButton:setMarginRight(2)  -- Same margin as in miniwindow style
		lockButton:setMarginTop(0)
	end
end

function ImpactAnalyser:reset(allTimeDps, allTimeHps)
	ImpactAnalyser.launchTime = g_clock.millis()
	ImpactAnalyser.session = 0

	ImpactAnalyser.damageTotal = 0
	ImpactAnalyser.dps = 0
	ImpactAnalyser.maxDPS = 0
	ImpactAnalyser.maxHPS = 0
	if allTimeDps then
		ImpactAnalyser.allTimeHightDps = 0
	end
	if allTimeHps then
		ImpactAnalyser.allTimeHightHps = 0
	end
	ImpactAnalyser.targetDPS = 1
	ImpactAnalyser.targetHPS = 1
	ImpactAnalyser.damageTicks = {}
	ImpactAnalyser.healingTicks = {}
	ImpactAnalyser.damageEffect = {}
	
	-- Reset session data
	ImpactAnalyser.sessionDamageTicks = {}
	ImpactAnalyser.sessionHealingTicks = {}
	ImpactAnalyser.sessionDPSMinuteData = {}
	ImpactAnalyser.sessionHPSMinuteData = {}
	ImpactAnalyser.lastMinuteUpdate = g_clock.millis()

	ImpactAnalyser.healingTotal = 0

	ImpactAnalyser.window.contentsPanel.graphDpsPanel:clear()
	
	-- Initialize DPS graph if it doesn't exist
	if ImpactAnalyser.window.contentsPanel.graphDpsPanel:getGraphsCount() == 0 then
		ImpactAnalyser.window.contentsPanel.graphDpsPanel:createGraph()
		ImpactAnalyser.window.contentsPanel.graphDpsPanel:setLineWidth(1, 1)
		ImpactAnalyser.window.contentsPanel.graphDpsPanel:setLineColor(1, "#f75f5f")
	end
	
	ImpactAnalyser.window.contentsPanel.graphDpsPanel:addValue(1, 0)

	ImpactAnalyser.window.contentsPanel.graphHealPanel:clear()
	
	-- Initialize Heal graph if it doesn't exist
	if ImpactAnalyser.window.contentsPanel.graphHealPanel:getGraphsCount() == 0 then
		ImpactAnalyser.window.contentsPanel.graphHealPanel:createGraph()
		ImpactAnalyser.window.contentsPanel.graphHealPanel:setLineWidth(1, 1)
		ImpactAnalyser.window.contentsPanel.graphHealPanel:setLineColor(1, "#f75f5f")
	end
	
	ImpactAnalyser.window.contentsPanel.graphHealPanel:addValue(1, 0)

	ImpactAnalyser:updateWindow()
end

function ImpactAnalyser:updateWindow(ignoreVisible)
	if not ImpactAnalyser.window:isVisible() and not ignoreVisible then
		return
	end
	ImpactAnalyser:checkAnchos()
	local contentsPanel = ImpactAnalyser.window.contentsPanel

	contentsPanel.dmg:setText(formatMoney(ImpactAnalyser.damageTotal, ","))
	contentsPanel.allTimeHigh:setText(formatMoney(ImpactAnalyser.allTimeHightDps, ","))
	
	local curDPS = 0
	if ImpactAnalyser.sessionMode then
		curDPS = valueInSessionMode(ImpactAnalyser.sessionDamageTicks)
	else
		curDPS = valueInSeconds(ImpactAnalyser.damageTicks)
	end
	
	if not curDPS then curDPS = 0 end
	ImpactAnalyser.maxDPS = ImpactAnalyser.maxDPS > curDPS and ImpactAnalyser.maxDPS or curDPS

	contentsPanel.maxDps:setText(formatMoney(ImpactAnalyser.maxDPS, ","))
	contentsPanel.dps:setText(formatMoney(curDPS, ","))

	contentsPanel.targetDps:setText(formatMoney(ImpactAnalyser.targetDPS, ","))
	-- movido pro check de 15s
	-- Ensure DPS graph exists before adding value
	if contentsPanel.graphDpsPanel:getGraphsCount() == 0 then
		contentsPanel.graphDpsPanel:createGraph()
		contentsPanel.graphDpsPanel:setLineWidth(1, 1)
		contentsPanel.graphDpsPanel:setLineColor(1, "#f75f5f")
	end
	
	-- Only add current DPS to graph if in normal mode
	if not ImpactAnalyser.sessionMode then
		contentsPanel.graphDpsPanel:addValue(1, curDPS)
	end

	if ImpactAnalyser.targetDPS == 1 and ImpactAnalyser.curHPS == 0 then
		ImpactAnalyser.window.contentsPanel.dpsBG.dpsArrow:setMarginLeft(targetMaxMargin / 2)
	else
		local target = math.max(1, ImpactAnalyser.targetDPS)
		local current = curDPS
		local percent = (current * 71) / target
		ImpactAnalyser.window.contentsPanel.dpsBG.dpsArrow:setMarginLeft(math.min(targetMaxMargin, math.ceil(percent)))
	end

	ImpactAnalyser.window.contentsPanel.dpsBG:setTooltip(string.format("Current: %d\nTarget: %d", curDPS, ImpactAnalyser.targetDPS))

	----------------------- DAMAGE TYPE -----------------------------
	for _, child in pairs(contentsPanel.dmgTypes:getChildren()) do
		child.toBeRemoved = true
	end

	if table.empty(ImpactAnalyser.damageEffect) then
		if contentsPanel.dmgTypes:getChildCount() > 0 then
			contentsPanel.dmgTypes:destroyChildren()
		end

		g_ui.createWidget('NoDataLabel', contentsPanel.dmgTypes)
	else
		for effect, damage in pairs(ImpactAnalyser.damageEffect) do
			local widget = contentsPanel.dmgTypes:getChildById("DamageEffect_" .. effect)
			if not widget then
				widget = g_ui.createWidget('DamagePanel', contentsPanel.dmgTypes)
				widget:setId("DamageEffect_" .. effect)
				widget.icon:setImageSource(string.format(imageDir, effectsFiles[effect]))
				widget.icon:setTooltip(getCombatName(effect))
			end

			local percent = (damage * 100) / ImpactAnalyser.damageTotal
			widget.desc:setText(formatMoney(damage, ",") .. " (" .. string.format("%.1f", percent) .. "%)")
			widget.toBeRemoved = false
		end
	end

	for _, child in pairs(contentsPanel.dmgTypes:getChildren()) do
		if child.toBeRemoved then
			child:destroy()
		end
	end

	---------------------------- Healing -------------------------------

	contentsPanel.hpsTotal:setText(formatMoney(ImpactAnalyser.healingTotal, ","))
	contentsPanel.allTimeHighHealing:setText(formatMoney(ImpactAnalyser.allTimeHightHps, ","))

	local curHPS = 0
	if ImpactAnalyser.sessionMode then
		curHPS = valueInSessionMode(ImpactAnalyser.sessionHealingTicks)
	else
		curHPS = valueInSeconds(ImpactAnalyser.healingTicks)
	end
	
	if not curHPS then curHPS = 0 end
	ImpactAnalyser.maxHPS = ImpactAnalyser.maxHPS > curHPS and ImpactAnalyser.maxHPS or curHPS

	contentsPanel.maxHps:setText(formatMoney(ImpactAnalyser.maxHPS, ","))
	contentsPanel.hps:setText(formatMoney(curHPS, ","))

	contentsPanel.targetHps:setText(formatMoney(ImpactAnalyser.targetHPS, ","))
	-- movido pro check de 15s
	-- Ensure Heal graph exists before adding value
	if contentsPanel.graphHealPanel:getGraphsCount() == 0 then
		contentsPanel.graphHealPanel:createGraph()
		contentsPanel.graphHealPanel:setLineWidth(1, 1)
		contentsPanel.graphHealPanel:setLineColor(1, "#f75f5f")
	end
	
	-- Only add current HPS to graph if in normal mode
	if not ImpactAnalyser.sessionMode then
		contentsPanel.graphHealPanel:addValue(1, curHPS)
	end

	if ImpactAnalyser.targetHPS == 1 and ImpactAnalyser.curHPS == 0 then
		ImpactAnalyser.window.contentsPanel.hpsBG.hpsArrow:setMarginLeft(targetMaxMargin / 2)
	else
		local target = math.max(1, ImpactAnalyser.targetHPS)
		local current = curHPS
		local percent = (current * 71) / target
		ImpactAnalyser.window.contentsPanel.hpsBG.hpsArrow:setMarginLeft(math.min(targetMaxMargin, math.ceil(percent)))
	end

	ImpactAnalyser.window.contentsPanel.hpsBG:setTooltip(string.format("Current: %d\nTarget: %d", curHPS, ImpactAnalyser.targetHPS))
	
	-- Update minute data for session tracking
	ImpactAnalyser:updateMinuteData()
end

function ImpactAnalyser:updateMinuteData()
	local now = g_clock.millis()
	local minuteInMs = 60 * 1000
	
	-- Initialize if first time
	if ImpactAnalyser.lastMinuteUpdate == 0 then
		ImpactAnalyser.lastMinuteUpdate = now
		return
	end
	
	-- Check if a minute has passed
	if now - ImpactAnalyser.lastMinuteUpdate >= minuteInMs then
		-- Calculate DPS for the past minute using session data
		local minuteDPS = 0
		local minuteHPS = 0
		local minuteStart = ImpactAnalyser.lastMinuteUpdate
		local totalDamage = 0
		local totalHealing = 0
		
		for _, tick in ipairs(ImpactAnalyser.sessionDamageTicks) do
			if tick.tick >= minuteStart and tick.tick < now then
				totalDamage = totalDamage + tick.amount
			end
		end
		
		for _, tick in ipairs(ImpactAnalyser.sessionHealingTicks) do
			if tick.tick >= minuteStart and tick.tick < now then
				totalHealing = totalHealing + tick.amount
			end
		end
		
		minuteDPS = totalDamage / 60 -- Damage per second for that minute
		minuteHPS = totalHealing / 60 -- Healing per second for that minute
		
		-- Add to minute data arrays
		table.insert(ImpactAnalyser.sessionDPSMinuteData, {
			timestamp = now,
			dps = minuteDPS
		})
		
		table.insert(ImpactAnalyser.sessionHPSMinuteData, {
			timestamp = now,
			hps = minuteHPS
		})
		
		-- Keep only last 60 minutes of data
		while #ImpactAnalyser.sessionDPSMinuteData > 60 do
			table.remove(ImpactAnalyser.sessionDPSMinuteData, 1)
		end
		
		while #ImpactAnalyser.sessionHPSMinuteData > 60 do
			table.remove(ImpactAnalyser.sessionHPSMinuteData, 1)
		end
		
		-- Update the graphs if we're in session mode
		if ImpactAnalyser.sessionMode then
			ImpactAnalyser.window.contentsPanel.graphDpsPanel:addValue(1, minuteDPS)
			ImpactAnalyser.window.contentsPanel.graphHealPanel:addValue(1, minuteHPS)
		end
		
		ImpactAnalyser.lastMinuteUpdate = now
	end
end

function ImpactAnalyser:updateGraphics()
	-- desativado
	if true then
		return
	end
	local curHPS = valueInSeconds(ImpactAnalyser.damageTicks)
	if not curHPS then curHPS = 0 end
	ImpactAnalyser.maxDPS = ImpactAnalyser.maxDPS > curHPS and ImpactAnalyser.maxDPS or curHPS
	-- Ensure DPS graph exists before adding value
	if ImpactAnalyser.window.contentsPanel.graphDpsPanel:getGraphsCount() == 0 then
		ImpactAnalyser.window.contentsPanel.graphDpsPanel:createGraph()
		ImpactAnalyser.window.contentsPanel.graphDpsPanel:setLineWidth(1, 1)
		ImpactAnalyser.window.contentsPanel.graphDpsPanel:setLineColor(1, "#f75f5f")
	end
	ImpactAnalyser.window.contentsPanel.graphDpsPanel:addValue(1, curHPS)


	local curHPS = valueInSeconds(ImpactAnalyser.healingTicks)
	if not curHPS then curHPS = 0 end
	ImpactAnalyser.maxHPS = ImpactAnalyser.maxHPS > curHPS and ImpactAnalyser.maxHPS or curHPS
	-- Ensure Heal graph exists before adding value
	if ImpactAnalyser.window.contentsPanel.graphHealPanel:getGraphsCount() == 0 then
		ImpactAnalyser.window.contentsPanel.graphHealPanel:createGraph()
		ImpactAnalyser.window.contentsPanel.graphHealPanel:setLineWidth(1, 1)
		ImpactAnalyser.window.contentsPanel.graphHealPanel:setLineColor(1, "#f75f5f")
	end
	ImpactAnalyser.window.contentsPanel.graphHealPanel:addValue(1, curHPS)
end

function ImpactAnalyser:addDealDamage(amount, effect)
	if amount > ImpactAnalyser.allTimeHightDps then
		ImpactAnalyser.allTimeHightDps = amount
	end
	ImpactAnalyser.damageTotal = ImpactAnalyser.damageTotal + amount
	
	local currentTime = g_clock.millis()
	ImpactAnalyser.damageTicks[#ImpactAnalyser.damageTicks + 1] = {amount = amount, tick = currentTime}
	ImpactAnalyser.sessionDamageTicks[#ImpactAnalyser.sessionDamageTicks + 1] = {amount = amount, tick = currentTime}
	
	if not ImpactAnalyser.damageEffect[effect] then
		ImpactAnalyser.damageEffect[effect] = 0
	end

	ImpactAnalyser.damageEffect[effect] = ImpactAnalyser.damageEffect[effect] + amount
end

function ImpactAnalyser:addHealing(amount)
	if amount > ImpactAnalyser.allTimeHightHps then
		ImpactAnalyser.allTimeHightHps = amount
	end
	ImpactAnalyser.healingTotal = ImpactAnalyser.healingTotal + amount
	
	local currentTime = g_clock.millis()
	ImpactAnalyser.healingTicks[#ImpactAnalyser.healingTicks + 1] = {amount = amount, tick = currentTime}
	ImpactAnalyser.sessionHealingTicks[#ImpactAnalyser.sessionHealingTicks + 1] = {amount = amount, tick = currentTime}
end


function onImpactExtra(mousePosition)
  if cancelNextRelease then
    cancelNextRelease = false
    return false
  end

  local dpsGaugeVisible = ImpactAnalyser.window.contentsPanel.targetDpsLabel:isVisible()
  local dpsGraphVisible = ImpactAnalyser.window.contentsPanel.dpsGraphBG:isVisible()
  local damageTypesVisible = ImpactAnalyser.window.contentsPanel.damageTypeLabel:isVisible()
  local hpsGaugeVisible = ImpactAnalyser.window.contentsPanel.targetHpsLabel:isVisible()
  local hpsGraphVisible = ImpactAnalyser.window.contentsPanel.hpsGraphBG:isVisible()

	local menu = g_ui.createWidget('PopupMenu')
	menu:setGameMenu(true)
	menu:addOption(tr('Reset Data'), function() ImpactAnalyser:reset(false) return end)
	menu:addOption(tr('Reset All-Time High'), function() ImpactAnalyser:setAllTimeHightDps(0);ImpactAnalyser:setAllTimeHightHps(0) end)
	
	-- Toggle between "Show Session Values" and "Show Current Values" based on current mode
	local sessionOptionText = ImpactAnalyser.sessionMode and tr('Show Current Values') or tr('Show Session Values')
	menu:addOption(sessionOptionText, function()
		ImpactAnalyser:toggleSessionMode()
	end)
	
	menu:addSeparator()
	menu:addOption(tr('Set DPS target'), function() ImpactAnalyser:openTargetConfig(true) end)
	menu:addCheckBox(tr('DPS gauge'), dpsGaugeVisible, function()
		ImpactAnalyser:setDPSGauge(not dpsGaugeVisible, true)
	end)
	menu:addCheckBox(tr('DPS graph'), dpsGraphVisible, function()
		ImpactAnalyser:setDPSGraph(not dpsGraphVisible, true)
	end)
	menu:addSeparator()
	menu:addCheckBox(tr('Damage Types'), damageTypesVisible, function()
		ImpactAnalyser:setDamageType(not damageTypesVisible, true)
	end)
	menu:addSeparator()
	menu:addOption(tr('Set HPS target'), function() ImpactAnalyser:openTargetConfig(false) end)
	menu:addCheckBox(tr('HPS gauge'), hpsGaugeVisible, function()
		ImpactAnalyser:setHPSGauge(not hpsGaugeVisible, true)
	end)
	menu:addCheckBox(tr('HPS graph'), hpsGraphVisible, function()
		ImpactAnalyser:setHPSGraph(not hpsGraphVisible, true)
	end)
	menu:display(mousePosition)
  return true
end

function ImpactAnalyser:toggleSessionMode()
	ImpactAnalyser.sessionMode = not ImpactAnalyser.sessionMode
	
	local horizontalGraphDPS = ImpactAnalyser.window.contentsPanel.graphHorizontal
	local horizontalGraphHPS = ImpactAnalyser.window.contentsPanel.graphHPSHorizontal
	
	if ImpactAnalyser.sessionMode then
		-- Switch to session mode: change images and show minute-by-minute data
		horizontalGraphDPS:setImageSource('/images/game/analyzer/graphHorizontal')
		horizontalGraphHPS:setImageSource('/images/game/analyzer/graphHorizontal')
		
		-- Clear and rebuild graphs with session data
		ImpactAnalyser.window.contentsPanel.graphDpsPanel:clear()
		ImpactAnalyser.window.contentsPanel.graphHealPanel:clear()
		
		if ImpactAnalyser.window.contentsPanel.graphDpsPanel:getGraphsCount() == 0 then
			ImpactAnalyser.window.contentsPanel.graphDpsPanel:createGraph()
			ImpactAnalyser.window.contentsPanel.graphDpsPanel:setLineWidth(1, 1)
			ImpactAnalyser.window.contentsPanel.graphDpsPanel:setLineColor(1, "#f75f5f")
		end
		
		if ImpactAnalyser.window.contentsPanel.graphHealPanel:getGraphsCount() == 0 then
			ImpactAnalyser.window.contentsPanel.graphHealPanel:createGraph()
			ImpactAnalyser.window.contentsPanel.graphHealPanel:setLineWidth(1, 1)
			ImpactAnalyser.window.contentsPanel.graphHealPanel:setLineColor(1, "#f75f5f")
		end
		
		ImpactAnalyser.window.contentsPanel.graphDpsPanel:setCapacity(3600) -- 60 minutes worth of data points
		ImpactAnalyser.window.contentsPanel.graphHealPanel:setCapacity(3600) -- 60 minutes worth of data points
		
		-- Add all historical minute data to graphs
		for _, minuteData in ipairs(ImpactAnalyser.sessionDPSMinuteData) do
			ImpactAnalyser.window.contentsPanel.graphDpsPanel:addValue(1, minuteData.dps)
		end
		
		for _, minuteData in ipairs(ImpactAnalyser.sessionHPSMinuteData) do
			ImpactAnalyser.window.contentsPanel.graphHealPanel:addValue(1, minuteData.hps)
		end
		
		-- If no session data exists yet, add current DPS/HPS to start the graphs properly
		if #ImpactAnalyser.sessionDPSMinuteData == 0 then
			local currentDPS = valueInSeconds(ImpactAnalyser.damageTicks) or 0
			ImpactAnalyser.window.contentsPanel.graphDpsPanel:addValue(1, currentDPS)
		end
		
		if #ImpactAnalyser.sessionHPSMinuteData == 0 then
			local currentHPS = valueInSeconds(ImpactAnalyser.healingTicks) or 0
			ImpactAnalyser.window.contentsPanel.graphHealPanel:addValue(1, currentHPS)
		end
	else
		-- Switch back to normal mode: restore original images and continue with existing graphs
		horizontalGraphDPS:setImageSource('/images/game/analyzer/graphDpsHorizontal')
		horizontalGraphHPS:setImageSource('/images/game/analyzer/graphDpsHorizontal')
		
		ImpactAnalyser.window.contentsPanel.graphDpsPanel:setCapacity(400) -- Default capacity
		ImpactAnalyser.window.contentsPanel.graphHealPanel:setCapacity(400) -- Default capacity
		
		-- Don't clear the graphs - let them continue from where they were before session mode
		-- The updateWindow() function will continue adding values automatically
	end
end

function ImpactAnalyser:openTargetConfig(isDps)
	local window = configPopupWindow["impactButton"]
	window:show()
	window:setText('Set '.. (isDps and 'DPS' or 'HPS') ..' Target')
	window.contentPanel.dps.target:setText(ImpactAnalyser.targetDPS)
	window.contentPanel.hps.target:setText(ImpactAnalyser.targetHPS)
	window.contentPanel.dps:setVisible(isDps)
	window.contentPanel.hps:setVisible(not isDps)

	window.onEnter = function()
		if isDps then
			local value = window.contentPanel.dps.target:getText()
			ImpactAnalyser.targetDPS = tonumber(value)
		else
			local value = window.contentPanel.hps.target:getText()
			ImpactAnalyser.targetHPS = tonumber(value)
		end
		window:hide()
	end

	window.contentPanel.ok.onClick = function()
		if isDps then
			local value = window.contentPanel.dps.target:getText()
			ImpactAnalyser.targetDPS = tonumber(value)
		else
			local value = window.contentPanel.hps.target:getText()
			ImpactAnalyser.targetHPS = tonumber(value)
		end
		window:hide()
	end
	window.contentPanel.cancel.onClick = function()
		window:hide()
	end
end

function ImpactAnalyser:setDPSGauge(value, check)
	ImpactAnalyser.window.contentsPanel.targetDpsLabel:setVisible(value)
	ImpactAnalyser.window.contentsPanel.targetDps:setVisible(value)
	ImpactAnalyser.window.contentsPanel.dpsBG:setVisible(value)
	ImpactAnalyser.window.contentsPanel.dpsLabel:setVisible(value)
	ImpactAnalyser.window.contentsPanel.dps:setVisible(value)
	ImpactAnalyser.window.contentsPanel.separatorDps:setVisible(value)

	ImpactAnalyser.gaugeDPSVisible = value

	if check then
		ImpactAnalyser:checkAnchos()
	end
end

function ImpactAnalyser:setDPSGraph(value, check)
	ImpactAnalyser.window.contentsPanel.dpsGraphBG:setVisible(value)
	ImpactAnalyser.window.contentsPanel.graphDpsPanel:setVisible(value)
	ImpactAnalyser.window.contentsPanel.graphHorizontal:setVisible(value)
	ImpactAnalyser.window.contentsPanel.separatorGraphHorizontalDps:setVisible(value)


	ImpactAnalyser.graphDPSVisible = value

	if check then
		ImpactAnalyser:checkAnchos()
	end
end

function ImpactAnalyser:setDamageType(value, check)
	ImpactAnalyser.window.contentsPanel.damageTypeLabel:setVisible(value)
	ImpactAnalyser.window.contentsPanel.dmgTypes:setVisible(value)
	ImpactAnalyser.window.contentsPanel.separatorDmgType:setVisible(value)


	ImpactAnalyser.damageTypeVisible = value

	if check then
		ImpactAnalyser:checkAnchos()
	end
end

function ImpactAnalyser:setHPSGauge(value, check)
	ImpactAnalyser.window.contentsPanel.targetHpsLabel:setVisible(value)
	ImpactAnalyser.window.contentsPanel.targetHps:setVisible(value)
	ImpactAnalyser.window.contentsPanel.hpsBG:setVisible(value)
	ImpactAnalyser.window.contentsPanel.hpsLabelGauge:setVisible(value)
	ImpactAnalyser.window.contentsPanel.hps:setVisible(value)
	ImpactAnalyser.window.contentsPanel.separatorHps:setVisible(value)

	ImpactAnalyser.gaugeHPSVisible = value

	if check then
		ImpactAnalyser:checkAnchos()
	end
end

function ImpactAnalyser:setHPSGraph(value, check)
	ImpactAnalyser.window.contentsPanel.hpsGraphBG:setVisible(value)
	ImpactAnalyser.window.contentsPanel.graphHealPanel:setVisible(value)
	ImpactAnalyser.window.contentsPanel.graphHPSHorizontal:setVisible(value)

	ImpactAnalyser.graphHPSVisible = value

	if check then
		ImpactAnalyser:checkAnchos()
	end
end

function ImpactAnalyser:checkAnchos()
	-- TODO: this is most likely why sometimes when logging in this bugs anchors
	-- should be done in the otui file, and in case they depend on other widgets
	-- update them when the other widgets visibility are updated - also, this is
	-- also weird once the anchors don't seem to be breaking anytime...
	if ImpactAnalyser.window.contentsPanel.targetDpsLabel:isVisible() then
		ImpactAnalyser.window.contentsPanel.dpsGraphBG:addAnchor(AnchorTop, 'separatorDps', AnchorBottom)
	else
		ImpactAnalyser.window.contentsPanel.dpsGraphBG:addAnchor(AnchorTop, 'separatorAllTimeHigh', AnchorBottom)
	end

	-- dps graph
	if ImpactAnalyser.window.contentsPanel.dpsGraphBG:isVisible() then
		ImpactAnalyser.window.contentsPanel.damageTypeLabel:addAnchor(AnchorTop, 'separatorGraphHorizontalDps', AnchorBottom)
	elseif ImpactAnalyser.window.contentsPanel.targetDpsLabel:isVisible() then
		ImpactAnalyser.window.contentsPanel.damageTypeLabel:addAnchor(AnchorTop, 'separatorDps', AnchorBottom)
	else
		ImpactAnalyser.window.contentsPanel.damageTypeLabel:addAnchor(AnchorTop, 'separatorAllTimeHigh', AnchorBottom)
	end

	-- damage type
	if ImpactAnalyser.window.contentsPanel.damageTypeLabel:isVisible() then
		ImpactAnalyser.window.contentsPanel.healingLabel:addAnchor(AnchorTop, 'separatorDmgType', AnchorBottom)
	elseif ImpactAnalyser.window.contentsPanel.dpsGraphBG:isVisible() then
		ImpactAnalyser.window.contentsPanel.healingLabel:addAnchor(AnchorTop, 'separatorGraphHorizontalDps', AnchorBottom)
	elseif ImpactAnalyser.window.contentsPanel.targetDpsLabel:isVisible() then
		ImpactAnalyser.window.contentsPanel.healingLabel:addAnchor(AnchorTop, 'separatorDps', AnchorBottom)
	else
		ImpactAnalyser.window.contentsPanel.healingLabel:addAnchor(AnchorTop, 'separatorAllTimeHigh', AnchorBottom)
	end

	-- heal gauge
	if ImpactAnalyser.window.contentsPanel.targetHpsLabel:isVisible() then
		ImpactAnalyser.window.contentsPanel.hpsGraphBG:addAnchor(AnchorTop, 'separatorHps', AnchorBottom)
	else
		ImpactAnalyser.window.contentsPanel.hpsGraphBG:addAnchor(AnchorTop, 'separatorAllTimeHighHealing', AnchorBottom)
	end
end

-- getters
function ImpactAnalyser:getAllTimeHightDps() return ImpactAnalyser.allTimeHightDps end
function ImpactAnalyser:gaugeDPSIsVisible() return ImpactAnalyser.gaugeDPSVisible end
function ImpactAnalyser:graphDPSIsVisible() return ImpactAnalyser.graphDPSVisible end
function ImpactAnalyser:gaugeHPSIsVisible() return ImpactAnalyser.gaugeHPSVisible end
function ImpactAnalyser:graphHPSIsVisible() return ImpactAnalyser.graphHPSVisible end
function ImpactAnalyser:damageTypeIsVisible() return ImpactAnalyser.damageTypeVisible end

-- setters
function ImpactAnalyser:setAllTimeHightDps(value) ImpactAnalyser.allTimeHightDps = value end
function ImpactAnalyser:setAllTimeHightHps(value) ImpactAnalyser.allTimeHightHps = value end

function ImpactAnalyser:loadConfigJson()
	local config = {
		desiredDamageTypesVisible = true,
		desiredDpsGaugeVisible = true,
		desiredDpsGraphVisible = true,
		desiredHpsGaugeVisible = true,
		desiredHpsGraphVisible = true,
		dpsGaugeTargetValue = 1,
		hpsGaugeTargetValue = 1,
		maxDamageImpact = 0,
		maxHealingImpact = 0,
		showSessionValues = false,
	}

	local player = g_game.getLocalPlayer()
	local file = "/characterdata/" .. player:getId() .. "/impactanalyser.json"
	if g_resources.fileExists(file) then
		local status, result = pcall(function()
			return json.decode(g_resources.readFileContents(file))
		end)

		if not status then
			return g_logger.error("Error while reading characterdata file. Details: " .. result)
		end

		config = result
	end

	ImpactAnalyser:setDPSGauge(config.desiredDpsGaugeVisible, false)
	ImpactAnalyser:setDPSGraph(config.desiredDpsGraphVisible, false)
	ImpactAnalyser:setDamageType(config.desiredDamageTypesVisible, false)
	ImpactAnalyser:setHPSGauge(config.desiredHpsGaugeVisible, false)
	ImpactAnalyser:setHPSGraph(config.desiredHpsGraphVisible, false)
	ImpactAnalyser.allTimeHightDps = config.maxDamageImpact
	ImpactAnalyser.allTimeHightHps = config.maxHealingImpact
	ImpactAnalyser.targetDPS = config.dpsGaugeTargetValue
	ImpactAnalyser.targetHPS = config.hpsGaugeTargetValue
	
	-- Load session mode state
	if config.showSessionValues then
		ImpactAnalyser.sessionMode = false -- Start false so toggle works correctly
		ImpactAnalyser:toggleSessionMode()
	end

	ImpactAnalyser:checkAnchos()
end

function ImpactAnalyser:saveConfigJson()
	local function checkFinite(value)
		if value == math.huge or value == -math.huge or type(value) ~= "number" then
			return 0
		end
		return value
	end

	local config = {
		desiredDamageTypesVisible = ImpactAnalyser:damageTypeIsVisible(),
		desiredDpsGaugeVisible = ImpactAnalyser:gaugeDPSIsVisible(),
		desiredDpsGraphVisible = ImpactAnalyser:graphDPSIsVisible(),
		desiredHpsGaugeVisible = ImpactAnalyser:gaugeHPSIsVisible(),
		desiredHpsGraphVisible = ImpactAnalyser:graphHPSIsVisible(),
		dpsGaugeTargetValue = checkFinite(ImpactAnalyser.targetDPS),
		hpsGaugeTargetValue = checkFinite(ImpactAnalyser.targetHPS),
		maxDamageImpact = checkFinite(ImpactAnalyser.allTimeHightDps),
		maxHealingImpact = checkFinite(ImpactAnalyser.allTimeHightHps),
		showSessionValues = ImpactAnalyser.sessionMode,
	}

	local player = g_game.getLocalPlayer()
	if not player then return end

	-- Ensure the characterdata directory exists
	local characterDir = "/characterdata/" .. player:getId()
	pcall(function() g_resources.makeDir("/characterdata") end)
	pcall(function() g_resources.makeDir(characterDir) end)

	local file = "/characterdata/" .. player:getId() .. "/impactanalyser.json"
	local status, result = pcall(function() return json.encode(config, 2) end)
	if not status then
		return g_logger.error("Error while saving profile ImpactAnalyzer data. Data won't be saved. Details: " .. result)
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
		g_logger.debug("Could not save ImpactAnalyser config during logout: " .. tostring(writeError))
	end
end

