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

if not XPAnalyser then
	XPAnalyser = {
		launchTime = 0,
		session = 0,

		startExp = 0,
		lastExp = 0,
		rawXPGain = 0,
		xpGain = 0,
		xpHour = 0,
		rawXpHour = 0,
		level = 0,
		target = 0,

		-- private
		window = nil,
	}
	XPAnalyser.__index = XPAnalyser
end
local targetMaxMargin = 142

function expForLevel(level)
  return math.floor((50*level*level*level)/3 - 100*level*level + (850*level)/3 - 200)
end

function expToAdvance(currentLevel, currentExp)
  return expForLevel(currentLevel+1) - currentExp
end

function XPAnalyser.create()
	XPAnalyser.window = openedWindows['xpButton']
	
	if not XPAnalyser.window then
		return
	end

	-- Hide buttons we don't want
	local toggleFilterButton = XPAnalyser.window:recursiveGetChildById('toggleFilterButton')
	if toggleFilterButton then
		toggleFilterButton:setVisible(false)
	end
	
	local newWindowButton = XPAnalyser.window:recursiveGetChildById('newWindowButton')
	if newWindowButton then
		newWindowButton:setVisible(false)
	end

	-- Position contextMenuButton where toggleFilterButton was (to the left of minimize button)
	local contextMenuButton = XPAnalyser.window:recursiveGetChildById('contextMenuButton')
	local minimizeButton = XPAnalyser.window:recursiveGetChildById('minimizeButton')
	
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
			return onXPExtra(pos)
		end
	end

	-- Position lockButton to the left of contextMenuButton
	local lockButton = XPAnalyser.window:recursiveGetChildById('lockButton')
	
	if lockButton and contextMenuButton then
		lockButton:setVisible(true)
		lockButton:breakAnchors()
		lockButton:addAnchor(AnchorTop, contextMenuButton:getId(), AnchorTop)
		lockButton:addAnchor(AnchorRight, contextMenuButton:getId(), AnchorLeft)
		lockButton:setMarginRight(2)  -- Same margin as in miniwindow style
		lockButton:setMarginTop(0)
	end

	XPAnalyser.launchTime = g_clock.millis()
	XPAnalyser.session = 0

	XPAnalyser.startExp = 0
	XPAnalyser.rawXPGain = 0
	XPAnalyser.xpGain = 0
	XPAnalyser.xpHour = 0
	XPAnalyser.rawXpHour = 0
	XPAnalyser.level = 0
	XPAnalyser.target = 0
end

function XPAnalyser:reset(allTimeDps, allTimeHps)
	XPAnalyser.launchTime = g_clock.millis()
	XPAnalyser.session = 0

	XPAnalyser.startExp = 0
	XPAnalyser.rawXPGain = 0
	XPAnalyser.xpGain = 0
	XPAnalyser.xpHour = 0
	XPAnalyser.rawXpHour = 0
	XPAnalyser.level = 0
	XPAnalyser.target = 0

	XPAnalyser.window.contentsPanel.graphPanel:clear()
	
	-- Initialize graph if it doesn't exist
	if XPAnalyser.window.contentsPanel.graphPanel:getGraphsCount() == 0 then
		XPAnalyser.window.contentsPanel.graphPanel:createGraph()
		XPAnalyser.window.contentsPanel.graphPanel:setLineWidth(1, 1)
		XPAnalyser.window.contentsPanel.graphPanel:setLineColor(1, TextColors.red) --"#f55e5e"
	end
	
	XPAnalyser.window.contentsPanel.graphPanel:addValue(1, 0)

	XPAnalyser:updateWindow()
	-- g_game.resetExperienceData() -- Function doesn't exist, removing call
end

function XPAnalyser:updateWindow(ignoreVisible)
	if not XPAnalyser.window then
		return
	end
	
	-- Always update calculations
	XPAnalyser:updateCalculations()
	
	-- Always update ALL UI elements (labels AND graphs) when XP is gained
	-- This ensures real-time updates regardless of window visibility
	XPAnalyser:updateBasicUI()
	XPAnalyser:updateExpensiveUI()
end

function XPAnalyser:setupStartExp(value)
	if XPAnalyser.startExp == 0 then
		XPAnalyser.launchTime = g_clock.millis()
		XPAnalyser.startExp = value
		XPAnalyser.lastExp = value  -- Initialize for XP gain tracking
	end
end

function XPAnalyser:setupLevel(level, percent)
	XPAnalyser.level = level
	XPAnalyser.window.contentsPanel.percent:setPercent(math.floor(percent))
	XPAnalyser.window.contentsPanel.nextLevel:setText("-")
end

function XPAnalyser:updateNextLevel(hours, minutes)
	local text = "-"
	if XPAnalyser.xpHour == 0 then
		XPAnalyser.window.contentsPanel.nextLevel:setText(text)
		return
	end

	if hours > 0 then
		text = tr('%dh %dmin', hours, minutes)
	elseif minutes > 0 then
		text = tr('%d minutes', minutes)
	else
		text = tr('1 minute')
	end
	XPAnalyser.window.contentsPanel.nextLevel:setText(text)
end

function XPAnalyser:checkExpHour()
	-- Called by Controller timer every 1000ms
	-- This provides periodic updates to keep the analyzer current
	
	-- Always update everything - both labels and graphs
	if XPAnalyser.window then
		XPAnalyser:updateCalculations()
		XPAnalyser:updateBasicUI()
		XPAnalyser:updateExpensiveUI()
	end
end

function XPAnalyser:updateBasicUI()
	if not XPAnalyser.window then
		return
	end
	
	local contentsPanel = XPAnalyser.window.contentsPanel
	
	-- Update main XP gain displays (always update these)
	local experience = XPAnalyser.xpGain
	contentsPanel.xpGain:setText(formatMoney(experience, ","))

	local rawExperience = XPAnalyser.rawXPGain
	contentsPanel.rawXpGain:setText(formatMoney(rawExperience, ","))
	
	-- Update XP/hour displays
	if XPAnalyser.xpGain == 0 then
		contentsPanel.xpHour:setText(0)
	else
		contentsPanel.xpHour:setText(formatMoney(XPAnalyser.xpHour, ","))
	end

	if XPAnalyser.rawXPGain == 0 then
		contentsPanel.rawXpHour:setText(0)
	else
		contentsPanel.rawXpHour:setText(formatMoney(XPAnalyser.rawXpHour, ","))
	end
end

function XPAnalyser:updateExpensiveUI()
	if not XPAnalyser.window then
		return
	end
	
	local player = g_game.getLocalPlayer()
	if not player then
		return
	end
	
	local contentsPanel = XPAnalyser.window.contentsPanel

	-- Update level progress
	local nextLevelExp = modules.game_skills.expForLevel(player:getLevel()+1)
	local hoursLeft = 0
	local minutesLeft = 0
	if XPAnalyser.xpHour > 0 then
		hoursLeft = (nextLevelExp - player:getExperience()) / XPAnalyser.xpHour
		minutesLeft = math.floor((hoursLeft - math.floor(hoursLeft))*60)
		hoursLeft = math.floor(hoursLeft)
	end
	XPAnalyser:updateNextLevel(hoursLeft, minutesLeft)

	-- Update graph (expensive operation)
	XPAnalyser:updateGraph()

	-- Update level percentage
	if player then
		contentsPanel.percent:setPercent(math.floor(player:getLevelPercent()))
	else
		contentsPanel.percent:setPercent(0)
	end

	-- Update target gauge
	if XPAnalyser.target == 0 and XPAnalyser.xpHour == 0 then
		XPAnalyser.window.contentsPanel.xpBG.xpArrow:setMarginLeft(targetMaxMargin / 2)
	else
		local target = math.max(1, (XPAnalyser.target or 1))
		local current = XPAnalyser.xpHour
		local percent = (current * 71) / target
		local marginLeft = math.min(targetMaxMargin, math.ceil(percent))
		XPAnalyser.window.contentsPanel.xpBG.xpArrow:setMarginLeft(marginLeft)
	end

	-- Update tooltip
	XPAnalyser:updateTooltip()
end

function XPAnalyser:updateGraph()
	if not XPAnalyser.window or not XPAnalyser.window.contentsPanel or not XPAnalyser.window.contentsPanel.graphPanel then
		return
	end
	
	-- Ensure graph exists before adding value
	if XPAnalyser.window.contentsPanel.graphPanel:getGraphsCount() == 0 then
		XPAnalyser.window.contentsPanel.graphPanel:createGraph()
		XPAnalyser.window.contentsPanel.graphPanel:setLineWidth(1, 1)
		XPAnalyser.window.contentsPanel.graphPanel:setLineColor(1, TextColors.red)
	end
	XPAnalyser.window.contentsPanel.graphPanel:addValue(1, math.max(0, XPAnalyser.xpHour))
end

function XPAnalyser:updateGraphics()
	-- Update xpHour calculations first using same pattern as other analyzers
	local _duration = math.floor((g_clock.millis() - XPAnalyser.launchTime)/1000)
	
	if _duration > 0 then
		XPAnalyser.xpHour = math.floor((XPAnalyser.xpGain * 3600) / _duration)
		XPAnalyser.rawXpHour = math.floor((XPAnalyser.rawXPGain * 3600) / _duration)
	else
		XPAnalyser.xpHour = 0
		XPAnalyser.rawXpHour = 0
	end

	if XPAnalyser.xpGain == 0 then
		XPAnalyser.xpHour = 0
	end

	if XPAnalyser.rawXPGain == 0 then
		XPAnalyser.rawXpHour = 0
	end

	-- Use the new graph update method
	XPAnalyser:updateGraph()
end

function XPAnalyser:forceUpdateUI()
	if not XPAnalyser.window then
		return
	end
	
	-- Force update all calculations and UI elements regardless of visibility
	XPAnalyser:updateCalculations()
	XPAnalyser:updateBasicUI()
	XPAnalyser:updateExpensiveUI()
end

function XPAnalyser:updateCalculations()
	local player = g_game.getLocalPlayer()
	if not player then
		return
	end

	-- Calculate exp per hour
	local _duration = math.floor((g_clock.millis() - XPAnalyser.launchTime)/1000)
	
	if _duration > 0 then
		XPAnalyser.xpHour = math.floor((XPAnalyser.xpGain * 3600) / _duration)
		XPAnalyser.rawXpHour = math.floor((XPAnalyser.rawXPGain * 3600) / _duration)
	else
		XPAnalyser.xpHour = 0
		XPAnalyser.rawXpHour = 0
	end

	if XPAnalyser.xpGain == 0 then
		XPAnalyser.xpHour = 0
	end

	if XPAnalyser.rawXPGain == 0 then
		XPAnalyser.rawXpHour = 0
	end
end

function XPAnalyser:updateNextLevel(hours, minutes)
	local text = "-"
	if XPAnalyser.xpHour == 0 then
		XPAnalyser.window.contentsPanel.nextLevel:setText(text)
		return
	end

	if hours > 0 then
		text = tr('%dh %dmin', hours, minutes)
	elseif minutes > 0 then
		text = tr('%d minutes', minutes)
	else
		text = tr('1 minute')
	end
	XPAnalyser.window.contentsPanel.nextLevel:setText(text)
end

-- updaters
function XPAnalyser:addRawXPGain(value) 
	-- Calculate the actual raw XP by removing rate modifiers
	local actualRawXP = calculateRawXP(value)
	XPAnalyser.rawXPGain = XPAnalyser.rawXPGain + actualRawXP
	XPAnalyser:updateGraphics()
	XPAnalyser:updateWindow()
end

function XPAnalyser:addXpGain(value) 
	XPAnalyser.xpGain = XPAnalyser.xpGain + value
	XPAnalyser:updateGraphics()
	XPAnalyser:updateWindow()
end

function XPAnalyser:updateTooltip()
	local player = g_game.getLocalPlayer()
	if not player then
		return
	end
	local text = "Raw XP Gain: " .. formatMoney(XPAnalyser.rawXPGain, ",")
	text = text .. "\nXP Gain: " .. formatMoney(XPAnalyser.xpGain, ",")
	text = text .. "\nCurrent Raw XP Per Hour: " .. formatMoney(XPAnalyser.rawXpHour, ",")
	text = text .. "\nCurrent XP Per Hour: " .. formatMoney(XPAnalyser.xpHour, ",")
	text = text .. "\nTarget XP Per Hour: " .. formatMoney(XPAnalyser.target, ",")
	text = text .. "\n" .. formatMoney(expToAdvance(player:getLevel(), player:getExperience()), ",") .. " XP until next level."
	text = text .. "\nYou have " .. 100 - player:getLevelPercent() .. " percent to go."

	XPAnalyser.window:setTooltip(text)
end

function onXPExtra(mousePosition)
  if cancelNextRelease then
    cancelNextRelease = false
    return false
  end

  local rawXpVisible = XPAnalyser.window.contentsPanel.rawXpLabel:isVisible()
  local gaugeVisible = XPAnalyser.window.contentsPanel.xpBG:isVisible()
  local graphVisible = XPAnalyser.window.contentsPanel.xpGraphBG:isVisible()

	local menu = g_ui.createWidget('PopupMenu')
	menu:setGameMenu(true)
	menu:addOption(tr('Reset Data'), function() XPAnalyser:reset(); return end)
	menu:addSeparator()
	menu:addCheckBox(tr('Show Raw XP'), rawXpVisible, function() XPAnalyser:setRawXPVisible(not rawXpVisible) end)
	menu:addSeparator()
	menu:addOption(tr('Set XP Per Hour Target'), function() XPAnalyser:openTargetConfig() return end)
	menu:addCheckBox(tr('XP Per Hour Gauge'), gaugeVisible, function() XPAnalyser:setGaugeVisible(not gaugeVisible) end)
	menu:addCheckBox(tr('XP Per Hour Graph'), graphVisible, function() XPAnalyser:setGraphVisible(not graphVisible) end)
	menu:display(mousePosition)
  return true
end

function XPAnalyser:checkAnchos()
	if XPAnalyser.window.contentsPanel.rawXpLabel:isVisible() then
		XPAnalyser.window.contentsPanel.xpLabel:setMarginTop(2)
		XPAnalyser.window.contentsPanel.xpLabel:addAnchor(AnchorTop, 'rawXpLabel', AnchorBottom)
		XPAnalyser.window.contentsPanel.xpGain:addAnchor(AnchorTop, 'rawXpGain', AnchorBottom)
	else
		XPAnalyser.window.contentsPanel.xpLabel:setMarginTop(0)
		XPAnalyser.window.contentsPanel.xpLabel:addAnchor(AnchorTop, 'topParent', AnchorBottom)
		XPAnalyser.window.contentsPanel.xpGain:addAnchor(AnchorTop, 'topParent', AnchorBottom)
	end

	if XPAnalyser.window.contentsPanel.rawXpHourLabel:isVisible() then
		XPAnalyser.window.contentsPanel.xpHourLabel:setMarginTop(2)
		XPAnalyser.window.contentsPanel.xpHour:setMarginTop(2)
		XPAnalyser.window.contentsPanel.xpHourLabel:addAnchor(AnchorTop, 'rawXpHourLabel', AnchorBottom)
		XPAnalyser.window.contentsPanel.xpHour:addAnchor(AnchorTop, 'xpHourLabel', AnchorTop)
	else
		XPAnalyser.window.contentsPanel.xpHourLabel:setMarginTop(2)
		XPAnalyser.window.contentsPanel.xpHour:setMarginTop(2)
		XPAnalyser.window.contentsPanel.xpHourLabel:addAnchor(AnchorTop, 'xpLabel', AnchorBottom)
		XPAnalyser.window.contentsPanel.xpHour:addAnchor(AnchorTop, 'xpHourLabel', AnchorTop)
	end

	if XPAnalyser.window.contentsPanel.xpBG:isVisible() then
		XPAnalyser.window.contentsPanel.xpGraphBG:addAnchor(AnchorTop, 'separatorGauge', AnchorBottom)
	else
		XPAnalyser.window.contentsPanel.xpGraphBG:addAnchor(AnchorTop, 'separatorPercent', AnchorBottom)
	end
end

function XPAnalyser:setRawXPVisible(value)
	XPAnalyser.window.contentsPanel.rawXpLabel:setVisible(value)
	XPAnalyser.window.contentsPanel.rawXpGain:setVisible(value)
	XPAnalyser.window.contentsPanel.rawXpHourLabel:setVisible(value)
	XPAnalyser.window.contentsPanel.rawXpHour:setVisible(value)

	XPAnalyser.rawXpVisible = value
	XPAnalyser:checkAnchos()
	
	-- Adjust window maximum height based on raw XP visibility
	if value then
		XPAnalyser.window:setContentMaximumHeight(255)  -- Show Raw XP active (taller)
		XPAnalyser.window:setHeight(255)
	else
		XPAnalyser.window:setContentMaximumHeight(225)  -- Show Raw XP inactive (shorter)
		XPAnalyser.window:setHeight(225)
	end
end

function XPAnalyser:setGaugeVisible(value)
	XPAnalyser.window.contentsPanel.xpBG:setVisible(value)
	XPAnalyser.window.contentsPanel.separatorGauge:setVisible(value)

	XPAnalyser.gaugeVisible = value
	XPAnalyser:checkAnchos()
end

function XPAnalyser:setGraphVisible(value)
	XPAnalyser.window.contentsPanel.xpGraphBG:setVisible(value)
	XPAnalyser.window.contentsPanel.graphPanel:setVisible(value)
	XPAnalyser.window.contentsPanel.graphHorizontal:setVisible(value)

	XPAnalyser.graphVisible = value
	XPAnalyser:checkAnchos()
end

function XPAnalyser:openTargetConfig()
	local window = configPopupWindow["xpButton"]
	window:show()
	window:setText('Set XP Per Hour Target')
	window.contentPanel.text:setImageSource('/images/game/analyzer/labels/xp')

	window.onEnter = function()
		local value = window.contentPanel.xpTarget:getText()
		XPAnalyser.target = tonumber(value)
		window:hide()
	end
	window.contentPanel.xpTarget:setText(tonumber(XPAnalyser.target) or '0')

	window.contentPanel.ok.onClick = function()
		local value = window.contentPanel.xpTarget:getText()
		XPAnalyser.target = tonumber(value)
		window:hide()
	end
	window.contentPanel.cancel.onClick = function()
		window:hide()
	end
end

function XPAnalyser:gaugeIsVisible()
	return XPAnalyser.gaugeVisible
end
function XPAnalyser:graphIsVisible()
	return XPAnalyser.graphVisible
end
function XPAnalyser:rawXPIsVisible()
	return XPAnalyser.rawXpVisible
end
function XPAnalyser:getTarget()
	return XPAnalyser.target
end

function XPAnalyser:loadConfigJson()
	local config = {
		desiredExperienceGaugeVisible = true,
		desiredXPGraphVisible = true,
		experienceGaugeTargetValue = 0,
		showBaseXp = false,
	}

	local player = g_game.getLocalPlayer()
	local file = "/characterdata/" .. player:getId() .. "/xpanalyser.json"
	if g_resources.fileExists(file) then
		local status, result = pcall(function()
			return json.decode(g_resources.readFileContents(file))
		end)

		if not status then
			return g_logger.error("Error while reading characterdata file. Details: " .. result)
		end

		config = result
	end

	XPAnalyser:setRawXPVisible(config.showBaseXp)
	XPAnalyser:setGaugeVisible(config.desiredExperienceGaugeVisible)
	XPAnalyser:setGraphVisible(config.desiredXPGraphVisible)
	XPAnalyser.target = config.experienceGaugeTargetValue
	XPAnalyser:checkAnchos()
end

function XPAnalyser:saveConfigJson()
	local config = {
		desiredExperienceGaugeVisible = XPAnalyser:gaugeIsVisible(),
		desiredXPGraphVisible = XPAnalyser:graphIsVisible(),
		experienceGaugeTargetValue = XPAnalyser:getTarget(),
		showBaseXp = XPAnalyser:rawXPIsVisible(),
	}

	local player = g_game.getLocalPlayer()
	if not player then return end
	
	-- Ensure the characterdata directory exists
	local characterDir = "/characterdata/" .. player:getId()
	pcall(function() g_resources.makeDir("/characterdata") end)
	pcall(function() g_resources.makeDir(characterDir) end)
	
	local file = "/characterdata/" .. player:getId() .. "/xpanalyser.json"
	local status, result = pcall(function() return json.encode(config, 2) end)
	if not status then
		return g_logger.error("Error while saving profile XP Analyzer data. Data won't be saved. Details: " .. result)
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
		g_logger.debug("Could not save XPAnalyser config during logout: " .. tostring(writeError))
	end
end
