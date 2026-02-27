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

-- Add capitalize function to string library if it doesn't exist
if not string.capitalize then
    function string.capitalize(str)
        if not str or str == "" then
            return str
        end
        return str:gsub("(%l)(%w*)", function(first, rest)
            return first:upper() .. rest
        end)
    end
end

-- Function to truncate text to a maximum length
local function short_text(text, maxLength)
    if not text then
        return ""
    end
    if string.len(text) > maxLength then
        return text:sub(1, maxLength - 3) .. "..."
    end
    return text
end

if not InputAnalyser then
	InputAnalyser = {
		launchTime = 0,
		session = 0,

		total = 0,
		maxDPS = 0,
		monsterName = '',

		inputValues = {},
		damageTicks = {},
		damageEffect = {},

		graphVisible = true,
		typesVisible = true,
		sourceVisible = true,

		-- private
		window = nil,
	}
	InputAnalyser.__index = InputAnalyser
end

local imageDir = '/images/icons/monster-icon-%s-resist'

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

local obj = {
	launchTime = 0,
	session = 0,

	total = 0,
	maxDPS = 0,
	monsterName = '',

	inputValues = {},
	damageTicks = {},
	damageEffect = {},

	-- Session data storage for 60 minutes
	sessionDamageTicks = {},
	sessionMode = false,
	sessionMinuteData = {}, -- Array to store DPS data per minute for the graph
	lastMinuteUpdate = 0, -- Track when we last updated minute data

	graphVisible = true,
	typesVisible = true,
	sourceVisible = true,

	-- private
	window = nil,
	event = nil,
	eventGraph = nil,
}

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

function InputAnalyser:create()
	InputAnalyser.window = openedWindows['damageButton']
	
	if not InputAnalyser.window then
		return
	end

	-- Hide buttons we don't want
	local toggleFilterButton = InputAnalyser.window:recursiveGetChildById('toggleFilterButton')
	if toggleFilterButton then
		toggleFilterButton:setVisible(false)
	end
	
	local newWindowButton = InputAnalyser.window:recursiveGetChildById('newWindowButton')
	if newWindowButton then
		newWindowButton:setVisible(false)
	end

	-- Position contextMenuButton where toggleFilterButton was (to the left of minimize button)
	local contextMenuButton = InputAnalyser.window:recursiveGetChildById('contextMenuButton')
	local minimizeButton = InputAnalyser.window:recursiveGetChildById('minimizeButton')
	
	if contextMenuButton and minimizeButton then
		contextMenuButton:setVisible(true)
		contextMenuButton:breakAnchors()
		contextMenuButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
		contextMenuButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
		contextMenuButton:setMarginRight(7)  -- Same margin as toggleFilterButton had
		contextMenuButton:setMarginTop(0)
		
		-- Set up the click handler for the context menu
		contextMenuButton.onClick = function(widget, mousePosition)
			return onInputExtra(mousePosition)
		end
	end

	-- Position lockButton to the left of contextMenuButton
	local lockButton = InputAnalyser.window:recursiveGetChildById('lockButton')
	
	if lockButton and contextMenuButton then
		lockButton:setVisible(true)
		lockButton:breakAnchors()
		lockButton:addAnchor(AnchorTop, contextMenuButton:getId(), AnchorTop)
		lockButton:addAnchor(AnchorRight, contextMenuButton:getId(), AnchorLeft)
		lockButton:setMarginRight(2)  -- Same margin as in miniwindow style
		lockButton:setMarginTop(0)
	end

	InputAnalyser.launchTime = g_clock.millis()
	InputAnalyser.session = 0
	InputAnalyser.lastMinuteUpdate = g_clock.millis() -- Initialize minute tracking

	InputAnalyser.total = 0
	InputAnalyser.maxDPS = 0
	InputAnalyser.monsterName = ''
	InputAnalyser.inputValues = {}
	InputAnalyser.damageEffect = {}
	InputAnalyser.damageTicks = {}
	InputAnalyser.sessionDamageTicks = {}
	InputAnalyser.sessionMinuteData = {}
end

function InputAnalyser:reset()
	InputAnalyser.launchTime = g_clock.millis()
	InputAnalyser.session = 0

	InputAnalyser.total = 0
	InputAnalyser.maxDPS = 0
	InputAnalyser.monsterName = ''
	InputAnalyser.inputValues = {}
	InputAnalyser.damageEffect = {}
	InputAnalyser.damageTicks = {}
	InputAnalyser.sessionDamageTicks = {}
	InputAnalyser.sessionMinuteData = {}
	InputAnalyser.lastMinuteUpdate = g_clock.millis()

	InputAnalyser.window.contentsPanel.graphPanel:clear()
	
	-- Initialize graph if it doesn't exist
	if InputAnalyser.window.contentsPanel.graphPanel:getGraphsCount() == 0 then
		InputAnalyser.window.contentsPanel.graphPanel:createGraph()
		InputAnalyser.window.contentsPanel.graphPanel:setLineWidth(1, 1)
		InputAnalyser.window.contentsPanel.graphPanel:setLineColor(1, "#f75f5f")
	end
	
	InputAnalyser.window.contentsPanel.graphPanel:addValue(1, 0)

	InputAnalyser:toggleDamageSource(false)
	InputAnalyser:updateWindow()

	-- Damage types
	local contentsPanel = InputAnalyser.window.contentsPanel
	contentsPanel.dmgTypes:destroyChildren()
	local widget = g_ui.createWidget('NoDataLabel', contentsPanel.dmgTypes)
	widget:setId("nodata")
	contentsPanel.dmgTypes:setHeight(15)

	-- Damage sources
	contentsPanel.dmgSrc:destroyChildren()
	widget = g_ui.createWidget('NoDataLabel', contentsPanel.dmgSrc)
	widget:setId("nodata")
	contentsPanel.dmgSrc:setHeight(15)
end

function InputAnalyser:updateWindow(ignoreVisible)
	if not InputAnalyser.window then
		return
	end

	if not InputAnalyser.window:isVisible() and not ignoreVisible then
		return
	end
	InputAnalyser:checkAnchos()
	local contentsPanel = InputAnalyser.window.contentsPanel

	local dps = tonumber(InputAnalyser.maxDPS) or 1
	contentsPanel.rcvDmg:setText(formatMoney(InputAnalyser.total, ","))
	contentsPanel.maxDps:setText(formatMoney(dps, ","))

	-------------- DAMAGE TYPE
	local count = 1
	local widgets = {}

	for effect, damage in pairs(InputAnalyser.damageEffect) do
		local widget = contentsPanel.dmgTypes:recursiveGetChildById(tostring(effect))
		if not widget then
			widget = g_ui.createWidget('DamagePanel', contentsPanel.dmgTypes)
		end
	
		local percent = (damage * 100) / InputAnalyser.total
		widget:setId(effect)
		widget.icon:setImageSource(string.format(imageDir, effectsFiles[effect]))
		widget.icon:setTooltip(getCombatName(effect))
		widget.desc:setText(formatMoney(damage, ",") .. " (" .. string.format("%.1f", percent) .. "%)")
	
		count = count + 1
		table.insert(widgets, {widget = widget, percent = percent})
	end

	table.sort(widgets, function(a, b)
		return a.percent > b.percent
	end)

	for index, item in ipairs(widgets) do
		contentsPanel.dmgTypes:moveChildToIndex(item.widget, index)
	end

	contentsPanel.dmgTypes:setHeight(15 * count)
	if count > 1 then
		local noData = contentsPanel.dmgTypes:recursiveGetChildById("nodata")
		if noData then
			noData:destroy()
		end
	end

	-------------- DAMAGE SOURCE
	count = 1
	widgets = {}
	for monsterName, damageInfo in pairs(InputAnalyser.inputValues) do
		local damageMonster = 0
		for effect, damage in pairs(damageInfo) do
			damageMonster = damageMonster + damage
		end

		local widget = contentsPanel.dmgSrc:recursiveGetChildById(monsterName)
		if not widget then
			widget = g_ui.createWidget('DamageSourcePanel', contentsPanel.dmgSrc)
		end

		count = count + 1
		widget:setId(monsterName)
		widget.name:setText(short_text(string.capitalize(monsterName), 15))
		widget:setTooltip(string.capitalize(monsterName))
		local percent = (damageMonster * 100) / InputAnalyser.total
		widget.desc:setText(string.format("%.1f", percent) .. "%")
		widget.onClick = function()
			if InputAnalyser.monsterName == monsterName then
				InputAnalyser.monsterName = ''
				InputAnalyser:toggleDamageSource(false)
			else
				InputAnalyser.monsterName = monsterName
				InputAnalyser:toggleDamageSource(true)
			end
		end

		table.insert(widgets, {widget = widget, percent = percent})
	end

	table.sort(widgets, function(a, b)
		return a.percent > b.percent
	end)

	for index, item in ipairs(widgets) do
		contentsPanel.dmgSrc:moveChildToIndex(item.widget, index)
	end

	contentsPanel.dmgSrc:setHeight(15 + (10 * count))
	if count > 1 then
		local noData = contentsPanel.dmgSrc:recursiveGetChildById("nodata")
		if noData then
			noData:destroy()
		end
	end

	----------------- MONSTER LABEL
	contentsPanel.dmgSourceTypes:destroyChildren()
	if InputAnalyser.inputValues[InputAnalyser.monsterName] then
		local count = 1
		for effect, damage in pairs(InputAnalyser.inputValues[InputAnalyser.monsterName]) do
			local widget = g_ui.createWidget('DamagePanel', contentsPanel.dmgSourceTypes)
			count = count + 1
			widget.icon:setImageSource(string.format(imageDir, effectsFiles[effect]))
			widget.icon:setTooltip(getCombatName(effect))
			local percent = (damage * 100) / InputAnalyser.total
			widget.desc:setText(formatMoney(damage, ",") .. " (" .. string.format("%.1f", percent) .. "%)")
		end
		contentsPanel.dmgSourceTypes:setHeight(15 * count)
	elseif table.empty(InputAnalyser.inputValues) then
		local widget = g_ui.createWidget('NoDataLabel', contentsPanel.dmgSourceTypes)
		contentsPanel.dmgSourceTypes:setHeight(15)
	end
end

function InputAnalyser:checkDPS()
	local curDPS = 0
	if InputAnalyser.sessionMode then
		curDPS = valueInSessionMode(InputAnalyser.sessionDamageTicks)
	else
		curDPS = valueInSeconds(InputAnalyser.damageTicks)
	end
	
	if not curDPS or not tonumber(curDPS) then curDPS = 0 end
	InputAnalyser.curDPS = curDPS
	local lastDps = tonumber(InputAnalyser.maxDPS) or 1
	InputAnalyser.maxDPS = InputAnalyser.maxDPS > curDPS and InputAnalyser.maxDPS or curDPS
	if not tonumber(InputAnalyser.maxDPS) then
		InputAnalyser.maxDPS = lastDps
	end

	InputAnalyser.window.contentsPanel.maxDps:setText(formatMoney(InputAnalyser.maxDPS, ","))
	
	-- Ensure graph exists before adding value
	if InputAnalyser.window.contentsPanel.graphPanel:getGraphsCount() == 0 then
		InputAnalyser.window.contentsPanel.graphPanel:createGraph()
		InputAnalyser.window.contentsPanel.graphPanel:setLineWidth(1, 1)
		InputAnalyser.window.contentsPanel.graphPanel:setLineColor(1, "#f75f5f")
	end
	
	-- Only add current DPS to graph if in normal mode
	-- Session mode will rebuild the entire graph when switched
	if not InputAnalyser.sessionMode then
		InputAnalyser.window.contentsPanel.graphPanel:addValue(1, InputAnalyser.curDPS)
	end
	
	-- Update minute data for session tracking
	InputAnalyser:updateMinuteData()
end

function InputAnalyser:updateMinuteData()
	local now = g_clock.millis()
	local minuteInMs = 60 * 1000
	
	-- Initialize if first time
	if InputAnalyser.lastMinuteUpdate == 0 then
		InputAnalyser.lastMinuteUpdate = now
		return
	end
	
	-- Check if a minute has passed
	if now - InputAnalyser.lastMinuteUpdate >= minuteInMs then
		-- Calculate DPS for the past minute using session data
		local minuteDPS = 0
		local minuteStart = InputAnalyser.lastMinuteUpdate
		local totalDamage = 0
		
		for _, tick in ipairs(InputAnalyser.sessionDamageTicks) do
			if tick.tick >= minuteStart and tick.tick < now then
				totalDamage = totalDamage + tick.amount
			end
		end
		
		minuteDPS = totalDamage / 60 -- Damage per second for that minute
		
		-- Add to minute data array
		table.insert(InputAnalyser.sessionMinuteData, {
			timestamp = now,
			dps = minuteDPS
		})
		
		-- Keep only last 60 minutes of data
		while #InputAnalyser.sessionMinuteData > 60 do
			table.remove(InputAnalyser.sessionMinuteData, 1)
		end
		
		-- Update the graph if we're in session mode
		if InputAnalyser.sessionMode then
			InputAnalyser.window.contentsPanel.graphPanel:addValue(1, minuteDPS)
		end
		
		InputAnalyser.lastMinuteUpdate = now
	end
end


function InputAnalyser:addInputDamage(amount, effect, target)
	if not InputAnalyser.inputValues[target] then
		InputAnalyser.inputValues[target] = {}
	end
	if not InputAnalyser.inputValues[target][effect] then
		InputAnalyser.inputValues[target][effect] = 0
	end

	InputAnalyser.inputValues[target][effect] = InputAnalyser.inputValues[target][effect] + amount
	InputAnalyser.total = InputAnalyser.total + amount

	local currentTime = g_clock.millis()
	InputAnalyser.damageTicks[#InputAnalyser.damageTicks + 1] = {amount = amount, tick = currentTime}
	InputAnalyser.sessionDamageTicks[#InputAnalyser.sessionDamageTicks + 1] = {amount = amount, tick = currentTime}

	if not InputAnalyser.damageEffect[effect] then
		InputAnalyser.damageEffect[effect] = 0
	end

	InputAnalyser.damageEffect[effect] = InputAnalyser.damageEffect[effect] + amount
end

function InputAnalyser:toggleDamageSource(bool)
	InputAnalyser.window.contentsPanel.separatorDmgSrc:setVisible(bool)
	InputAnalyser.window.contentsPanel.damageSourceName:setVisible(bool)
	InputAnalyser.window.contentsPanel.dmgSourceTypes:setVisible(bool)

	InputAnalyser.window.contentsPanel.damageSourceName:setText(string.capitalize(InputAnalyser.monsterName))
	InputAnalyser.window.contentsPanel.dmgSourceTypes:destroyChildren()
	if InputAnalyser.inputValues[InputAnalyser.monsterName] then
		local count = 1
		for effect, damage in pairs(InputAnalyser.inputValues[InputAnalyser.monsterName]) do
			local widget = g_ui.createWidget('DamagePanel', InputAnalyser.window.contentsPanel.dmgSourceTypes)
			count = count + 1
			widget.icon:setImageSource(string.format(imageDir, effectsFiles[effect]))
			widget.icon:setTooltip(getCombatName(effect))
			local percent = (damage * 100) / InputAnalyser.total
			widget.desc:setText(formatMoney(damage, ",") .. " (" .. string.format("%.1f", percent) .. "%)")
		end
		InputAnalyser.window.contentsPanel.dmgSourceTypes:setHeight(15 * count)
	elseif table.empty(InputAnalyser.inputValues) then
		local widget = g_ui.createWidget('NoDataLabel', InputAnalyser.window.contentsPanel.dmgSourceTypes)
		InputAnalyser.window.contentsPanel.dmgSourceTypes:setHeight(15)
	end
end

function onInputExtra(mousePosition)
  if cancelNextRelease then
    cancelNextRelease = false
    return false
  end

  local graphVisible = InputAnalyser.window.contentsPanel.dpsGraphBG:isVisible()
  local typesVisible = InputAnalyser.window.contentsPanel.damageTypeLabel:isVisible()
  local sourceVisible = InputAnalyser.window.contentsPanel.damageSource:isVisible()

	local menu = g_ui.createWidget('PopupMenu')
	menu:setGameMenu(true)
	menu:addOption(tr('Reset Data'), function() InputAnalyser:reset() return end)
	
	-- Toggle between "Show Session Values" and "Show Current Values" based on current mode
	local sessionOptionText = InputAnalyser.sessionMode and tr('Show Current Values') or tr('Show Session Values')
	menu:addOption(sessionOptionText, function()
		InputAnalyser:toggleSessionMode()
	end)
	
	menu:addSeparator()
	menu:addCheckBox(tr('Show Damage Graph'), graphVisible, function()
		InputAnalyser:setDamageGraph(not graphVisible, true)
	end)
	menu:addCheckBox(tr('Show Damage Types'), typesVisible, function()
		InputAnalyser:setDamageTypes(not typesVisible, true)
	end)
	menu:addCheckBox(tr('Show Damage Sources'), sourceVisible, function()
		InputAnalyser:setDamageSource(not sourceVisible, true)
	end)
	menu:addSeparator()
	menu:addOption(tr('Copy to Clipboard'), function() InputAnalyser:clipboardData() return end)
	menu:display(mousePosition)
  return true
end

function InputAnalyser:checkAnchos()
	if InputAnalyser.window.contentsPanel.dpsGraphBG:isVisible() then
		InputAnalyser.window.contentsPanel.damageTypeLabel:addAnchor(AnchorTop, 'separatorGraph', AnchorBottom)
	else
		InputAnalyser.window.contentsPanel.damageTypeLabel:addAnchor(AnchorTop, 'separatorMaxDps', AnchorBottom)
	end

	if InputAnalyser.window.contentsPanel.damageTypeLabel:isVisible() then
		InputAnalyser.window.contentsPanel.damageSource:addAnchor(AnchorTop, 'separatorDmgType', AnchorBottom)
	elseif InputAnalyser.window.contentsPanel.dpsGraphBG:isVisible() then
		InputAnalyser.window.contentsPanel.damageSource:addAnchor(AnchorTop, 'separatorGraph', AnchorBottom)
	else
		InputAnalyser.window.contentsPanel.damageSource:addAnchor(AnchorTop, 'separatorMaxDps', AnchorBottom)
	end
end

function InputAnalyser:setDamageGraph(value, check)
	InputAnalyser.window.contentsPanel.dpsGraphBG:setVisible(value)
	InputAnalyser.window.contentsPanel.graphPanel:setVisible(value)
	InputAnalyser.window.contentsPanel.horizontalGraph:setVisible(value)
	InputAnalyser.window.contentsPanel.separatorGraph:setVisible(value)

	InputAnalyser.graphVisible = value

	if check then
		InputAnalyser:checkAnchos()
	end
end

function InputAnalyser:setDamageTypes(value, check)
	InputAnalyser.window.contentsPanel.damageTypeLabel:setVisible(value)
	InputAnalyser.window.contentsPanel.dmgTypes:setVisible(value)
	InputAnalyser.window.contentsPanel.separatorDmgType:setVisible(value)

	InputAnalyser.typesVisible = value

	if check then
		InputAnalyser:checkAnchos()
	end
end


function InputAnalyser:setDamageSource(value, check)
	InputAnalyser.window.contentsPanel.damageSource:setVisible(value)
	InputAnalyser.window.contentsPanel.dmgSrc:setVisible(value)

	InputAnalyser.sourceVisible = value

	InputAnalyser:toggleDamageSource(value)

	if check then
		InputAnalyser:checkAnchos()
	end
end

function InputAnalyser:toggleSessionMode()
	InputAnalyser.sessionMode = not InputAnalyser.sessionMode
	
	local horizontalGraph = InputAnalyser.window.contentsPanel.horizontalGraph
	
	if InputAnalyser.sessionMode then
		-- Switch to session mode: change image and show minute-by-minute data
		horizontalGraph:setImageSource('/images/game/analyzer/graphHorizontal')
		
		-- Clear and rebuild graph with session data
		InputAnalyser.window.contentsPanel.graphPanel:clear()
		if InputAnalyser.window.contentsPanel.graphPanel:getGraphsCount() == 0 then
			InputAnalyser.window.contentsPanel.graphPanel:createGraph()
			InputAnalyser.window.contentsPanel.graphPanel:setLineWidth(1, 1)
			InputAnalyser.window.contentsPanel.graphPanel:setLineColor(1, "#f75f5f")
		end
		
		InputAnalyser.window.contentsPanel.graphPanel:setCapacity(3600) -- 60 minutes worth of data points
		
		-- Add all historical minute data to graph
		for _, minuteData in ipairs(InputAnalyser.sessionMinuteData) do
			InputAnalyser.window.contentsPanel.graphPanel:addValue(1, minuteData.dps)
		end
		
		-- If no session data exists yet, add current DPS to start the graph properly
		if #InputAnalyser.sessionMinuteData == 0 then
			local currentDPS = valueInSeconds(InputAnalyser.damageTicks) or 0
			InputAnalyser.window.contentsPanel.graphPanel:addValue(1, currentDPS)
		end
	else
		-- Switch back to normal mode: restore original image and continue with existing graph
		horizontalGraph:setImageSource('/images/game/analyzer/graphDpsHorizontal')
		InputAnalyser.window.contentsPanel.graphPanel:setCapacity(400) -- Default capacity
		
		-- Don't clear the graph - let it continue from where it was before session mode
		-- The checkDPS() function will continue adding values automatically
	end
end

function InputAnalyser:clipboardData()

	local text = "Received Damage"
	text = text .. "\nTotal: " .. formatMoney(InputAnalyser.total, ",")
	text = text .. "\nMax-DPS: " .. formatMoney(InputAnalyser.maxDPS, ",")
	text = text .. "\nDamage Types"
	if table.empty(InputAnalyser.inputValues) then
		text = text .. "\n\tNo Data"
	else
		local count = 1
		for effect, damage in pairs(InputAnalyser.damageEffect) do
			local percent = (damage * 100) / InputAnalyser.total
			text = text .. "\n\t" .. getCombatName(effect) .. " " .. formatMoney(damage, ",") .. " (".. string.format("%.1f", percent) .."%)"
		end
	end
	text = text .. "\nDamage Sources"
	if table.empty(InputAnalyser.inputValues) then
		text = text .. "\n\tNo Data"
	else
		for monsterName, damageInfo in pairs(InputAnalyser.inputValues) do
			local damageMonster = 0
			for effect, damage in pairs(damageInfo) do
				damageMonster = damageMonster + damage
			end

			local percent = (damageMonster * 100) / InputAnalyser.total
			text = text .. "\n\t" .. string.capitalize(monsterName) .. " " .. formatMoney(damageMonster, ",") .. " (" .. string.format("%.1f", percent) .. "%)"
		end
	end
	if InputAnalyser.inputValues[InputAnalyser.monsterName] and InputAnalyser.window.contentsPanel.separatorDmgSrc:isVisible() then
		text = text .. "\n" .. string.capitalize(InputAnalyser.monsterName)
		for effect, damage in pairs(InputAnalyser.inputValues[InputAnalyser.monsterName]) do
			local percent = (damage * 100) / InputAnalyser.total
			text = text .. "\n\t" .. getCombatName(effect) .. " " .. formatMoney(damage, ",") .. " (".. string.format("%.1f", percent) .."%)"
		end
	end
	g_window.setClipboardText(text)
end

function InputAnalyser:damageGraphIsVisible() return InputAnalyser.graphVisible end
function InputAnalyser:damageTypesIsVisible() return InputAnalyser.typesVisible end
function InputAnalyser:damageSourceIsVisible() return InputAnalyser.sourceVisible end

function InputAnalyser:loadConfigJson()
	local config = {
		showDamageGraph = true,
		showDamageSources = true,
		showDamageTypes = true,
		showSessionValues = false,
	}
	local player = g_game.getLocalPlayer()
	if not player then return end
	local file = "/characterdata/" .. player:getId() .. "/damageinputanalyser.json"
	if g_resources.fileExists(file) then
		local status, result = pcall(function()
			return json.decode(g_resources.readFileContents(file))
		end)

		if not status then
			return g_logger.error("Error while reading characterdata file. Details: " .. result)
		end

		config = result
	end

	InputAnalyser:setDamageGraph(config.showDamageGraph, false)
	InputAnalyser:setDamageSource(config.showDamageSources, false)
	InputAnalyser:setDamageTypes(config.showDamageTypes, false)
	
	-- Load session mode state
	if config.showSessionValues then
		InputAnalyser.sessionMode = false -- Start false so toggle works correctly
		InputAnalyser:toggleSessionMode()
	end

	InputAnalyser:checkAnchos()
end

function InputAnalyser:saveConfigJson()
	local player = g_game.getLocalPlayer()
	if not player then return end
	
	-- Ensure the characterdata directory exists
	local characterDir = "/characterdata/" .. player:getId()
	pcall(function() g_resources.makeDir("/characterdata") end)
	pcall(function() g_resources.makeDir(characterDir) end)
	
	local config = {
		showDamageGraph = InputAnalyser:damageGraphIsVisible(),
		showDamageSources = InputAnalyser:damageSourceIsVisible(),
		showDamageTypes = InputAnalyser:damageTypesIsVisible(),
		showSessionValues = InputAnalyser.sessionMode,
	}

	local file = "/characterdata/" .. player:getId() .. "/damageinputanalyser.json"
	local status, result = pcall(function() return json.encode(config, 2) end)
	if not status then
		return g_logger.error("Error while saving profile itemsData. Data won't be saved. Details: " .. result)
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
		g_logger.debug("Could not save InputAnalyser config during logout: " .. tostring(writeError))
	end
end
