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

-- Function to get item name by ID
local function getItemServerName(itemId)
    local thingType = g_things.getThingType(itemId, ThingCategoryItem)
    if thingType then
        return thingType:getName()
    end
    return "Unknown Item"
end

if not SupplyAnalyser then
	SupplyAnalyser = {
		launchTime = 0,
		session = 0,
		goldValue = 0,
		goldHour = 0,
		target = 0,
		gaugeVisible = true,
		graphVisible = true,
		items = {},
		-- private
		window = nil,
	}

	SupplyAnalyser.__index = SupplyAnalyser
end

local targetMaxMargin = 142

function SupplyAnalyser:create()
	SupplyAnalyser.launchTime = g_clock.millis()
	SupplyAnalyser.session = 0
	SupplyAnalyser.goldValue = 0
	SupplyAnalyser.goldHour = 0
	SupplyAnalyser.target = 0
	SupplyAnalyser.gaugeVisible = true
	SupplyAnalyser.graphVisible = true
	SupplyAnalyser.items = {}
	SupplyAnalyser.forceUpdateBalance = false
	SupplyAnalyser.updateBalance = true

	SupplyAnalyser.window = openedWindows['supplyButton']
	
	if not SupplyAnalyser.window then
		return
	end

	-- Hide buttons we don't want
	local toggleFilterButton = SupplyAnalyser.window:recursiveGetChildById('toggleFilterButton')
	if toggleFilterButton then
		toggleFilterButton:setVisible(false)
	end
	
	local newWindowButton = SupplyAnalyser.window:recursiveGetChildById('newWindowButton')
	if newWindowButton then
		newWindowButton:setVisible(false)
	end

	-- Position contextMenuButton where toggleFilterButton was (to the left of minimize button)
	local contextMenuButton = SupplyAnalyser.window:recursiveGetChildById('contextMenuButton')
	local minimizeButton = SupplyAnalyser.window:recursiveGetChildById('minimizeButton')
	
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
			return onSupplyExtra(pos)
		end
	end

	-- Position lockButton to the left of contextMenuButton
	local lockButton = SupplyAnalyser.window:recursiveGetChildById('lockButton')
	
	if lockButton and contextMenuButton then
		lockButton:setVisible(true)
		lockButton:breakAnchors()
		lockButton:addAnchor(AnchorTop, contextMenuButton:getId(), AnchorTop)
		lockButton:addAnchor(AnchorRight, contextMenuButton:getId(), AnchorLeft)
		lockButton:setMarginRight(2)  -- Same margin as in miniwindow style
		lockButton:setMarginTop(0)
	end
end

-- Function to get supply price based on user's Cyclopedia preference (similar to loot values)
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

function onSupplyExtra(mousePosition)
  if cancelNextRelease then
    cancelNextRelease = false
    return false
  end

  local gaugeVisible = SupplyAnalyser.window.contentsPanel.targetLabel:isVisible()
  local graphVisible = SupplyAnalyser.window.contentsPanel.graphPanel:isVisible()

	local menu = g_ui.createWidget('PopupMenu')
	menu:setGameMenu(true)
	menu:addOption(tr('Reset Data'), function() SupplyAnalyser:reset() return end)
	menu:addSeparator()
	menu:addOption(tr('Set Supply Per Hour Target'), function() SupplyAnalyser:openTargetConfig() return end)
	menu:addCheckBox(tr('Supply Per Hour Gauge'), gaugeVisible, function() SupplyAnalyser:setSupplyPerHourGauge(not gaugeVisible) end)
	menu:addCheckBox(tr('Supply Per Hour Graph'), graphVisible, function() SupplyAnalyser:setSupplyPerHourGraph(not graphVisible) end)
	menu:display(mousePosition)
  return true
end

function SupplyAnalyser:reset()
	-- Reset all data values
	SupplyAnalyser.launchTime = g_clock.millis()
	SupplyAnalyser.session = 0
	SupplyAnalyser.goldValue = 0
	SupplyAnalyser.goldHour = 0
	SupplyAnalyser.target = 0
	SupplyAnalyser.items = {}
	SupplyAnalyser.forceUpdateBalance = false
	SupplyAnalyser.updateBalance = true

	-- Clear and reset the graph
	if SupplyAnalyser.window and SupplyAnalyser.window.contentsPanel and SupplyAnalyser.window.contentsPanel.graphPanel then
		SupplyAnalyser.window.contentsPanel.graphPanel:clear()
		
		-- Initialize graph if it doesn't exist
		if SupplyAnalyser.window.contentsPanel.graphPanel:getGraphsCount() == 0 then
			SupplyAnalyser.window.contentsPanel.graphPanel:createGraph()
			SupplyAnalyser.window.contentsPanel.graphPanel:setLineWidth(1, 1)
			SupplyAnalyser.window.contentsPanel.graphPanel:setLineColor(1, TextColors.red)
		end
		
		SupplyAnalyser.window.contentsPanel.graphPanel:addValue(1, 0)
	end
	
	-- Update all UI elements immediately to reflect the reset (like HuntingAnalyser does)
	SupplyAnalyser:updateWindow(true, true)  -- updateScroll=true, ignoreVisible=true
end

function SupplyAnalyser:checkBalance()
	local oldBalance = SupplyAnalyser.goldValue
	local itemList = {}
	for index, itemInfo in pairs(SupplyAnalyser.items) do
		if itemInfo.time + 3600 < os.time() then
			SupplyAnalyser.items[index] = nil
			SupplyAnalyser:decreaseWidget(itemInfo.itemId)
		else
			if not itemList[itemInfo.itemId] then
				itemList[itemInfo.itemId] = {count = 1}
			else
				itemList[itemInfo.itemId].count = itemList[itemInfo.itemId].count + 1
			end
		end
	end

	SupplyAnalyser.forceUpdateBalance = false

	if SupplyAnalyser.updateBalance or oldBalance ~= SupplyAnalyser.goldValue then
		SupplyAnalyser:updateWindow(false)
		SupplyAnalyser.updateBalance = false
	end
end

function SupplyAnalyser:updateWindow(updateScroll, ignoreVisible)
	if not SupplyAnalyser.window:isVisible() and not ignoreVisible then
		return
	end

	local target = SupplyAnalyser.target or 0
	local goldHour = SupplyAnalyser.goldHour or 0
	local goldValue = SupplyAnalyser.goldValue or 0

	local contentsPanel = SupplyAnalyser.window.contentsPanel
	contentsPanel.gold:setText(formatMoney(goldValue, ","))
	contentsPanel.goldHour:setText(formatLargeNumber(math.floor(goldHour)))
	contentsPanel.goldTarget:setText(formatMoney(target, ","))

	if target == 0 and goldHour == 0 then
		SupplyAnalyser.window.contentsPanel.supplyTargetBG.supplyArrow:setMarginLeft(targetMaxMargin / 2)
	else
		local targetValue = math.max(1, target)
		local current = goldHour
		local percent = (current * 71) / targetValue
		SupplyAnalyser.window.contentsPanel.supplyTargetBG.supplyArrow:setMarginLeft(math.min(targetMaxMargin, math.ceil(percent)))
	end

	SupplyAnalyser.window.contentsPanel.supplyTargetBG:setTooltip(string.format("Current: %d\nTarget: %d", goldHour, target))

	if not updateScroll then
		return
	end

	local numOfItems = 0
	local numOfLines = 0
	
	-- Clear the items panel if items table is empty (similar to LootAnalyser)
	if table.empty(SupplyAnalyser.items) and #contentsPanel.lootedItems:getChildren() > 0 then
		contentsPanel.lootedItems:destroyChildren()
		contentsPanel.lootedItems:setVisible(false)
		contentsPanel.separatorLootedItems:setVisible(false)
	else
		-- Process existing items and create/update widgets
		local itemCounts = {}
		for _, itemInfo in pairs(SupplyAnalyser.items) do
			if not itemCounts[itemInfo.itemId] then
				itemCounts[itemInfo.itemId] = 1
			else
				itemCounts[itemInfo.itemId] = itemCounts[itemInfo.itemId] + 1
			end
		end
		
		for itemId, count in pairs(itemCounts) do
			local widget = contentsPanel.lootedItems:getChildById(tostring(itemId))
			if not widget then
				widget = g_ui.createWidget('LootItem', contentsPanel.lootedItems)
				widget:setId(itemId)
				widget:setItemId(itemId)
			end
			
			widget:setItemCount(count)
			local itemPtr = Item.create(itemId, 1)
			local value = getCurrentPrice(itemPtr)
			widget:setTooltip(string.format("%s (Value: %sgp, Sum: %sgp)", getItemServerName(itemId), formatMoney(value, ","), formatMoney(value * count, ",")))
			
			numOfItems = numOfItems + 1
			if numOfItems == 4 then
				numOfItems = 0
				numOfLines = numOfLines + 1
			end
		end
		
		if numOfItems > 0 or numOfLines > 0 then
			contentsPanel.lootedItems:setVisible(true)
			contentsPanel.separatorLootedItems:setVisible(true)
		end
	end

	numOfLines = not table.empty(SupplyAnalyser.items) and numOfLines + 1 or 0
	contentsPanel.lootedItems:setHeight(35 * numOfLines)
end

function SupplyAnalyser:updateGraphics()
	-- Update goldHour calculations first using same pattern as LootAnalyser
	local _duration = math.floor((g_clock.millis() - SupplyAnalyser.launchTime)/1000)
	
	if _duration > 0 then
		SupplyAnalyser.goldHour = math.floor((SupplyAnalyser.goldValue * 3600) / _duration)
	else
		SupplyAnalyser.goldHour = 0
	end

	if SupplyAnalyser.goldValue == 0 then
		SupplyAnalyser.goldHour = 0
	end

	-- Use the new graph update method
	SupplyAnalyser:updateGraph()
end

function SupplyAnalyser:checkSupplyHour()
	-- Called by Controller timer every 1000ms
	-- This provides periodic updates to keep the analyzer current
	
	if not SupplyAnalyser.window then
		return
	end
	
	-- Update goldHour calculations using the same pattern as LootAnalyser
	local _duration = math.floor((g_clock.millis() - SupplyAnalyser.launchTime)/1000)
	
	if _duration > 0 then
		SupplyAnalyser.goldHour = math.floor((SupplyAnalyser.goldValue * 3600) / _duration)
	else
		SupplyAnalyser.goldHour = 0
	end

	if SupplyAnalyser.goldValue == 0 then
		SupplyAnalyser.goldHour = 0
	end
	
	-- Always update UI elements and graph (like LootAnalyser does)
	SupplyAnalyser:updateBasicUI()
	SupplyAnalyser:updateGraph()
end

function SupplyAnalyser:updateBasicUI()
	if not SupplyAnalyser.window or not SupplyAnalyser.window.contentsPanel then
		return
	end
	
	local contentsPanel = SupplyAnalyser.window.contentsPanel
	
	-- Update the Per Hour display
	if contentsPanel.goldHour then
		contentsPanel.goldHour:setText(formatLargeNumber(math.floor(SupplyAnalyser.goldHour)))
	end
	
	-- Update target gauge
	if contentsPanel.supplyTargetBG and contentsPanel.supplyTargetBG.supplyArrow then
		if SupplyAnalyser.target == 0 and SupplyAnalyser.goldHour == 0 then
			contentsPanel.supplyTargetBG.supplyArrow:setMarginLeft(targetMaxMargin / 2)
		else
			local target = math.max(1, SupplyAnalyser.target)
			local current = SupplyAnalyser.goldHour
			local percent = (current * 71) / target
			contentsPanel.supplyTargetBG.supplyArrow:setMarginLeft(math.min(targetMaxMargin, math.ceil(percent)))
		end

		-- Update tooltip
		contentsPanel.supplyTargetBG:setTooltip(string.format("Current: %d\nTarget: %d", SupplyAnalyser.goldHour, SupplyAnalyser.target))
	end
end

function SupplyAnalyser:updateGraph()
	if not SupplyAnalyser.window or not SupplyAnalyser.window.contentsPanel or not SupplyAnalyser.window.contentsPanel.graphPanel then
		return
	end
	
	-- Ensure graph exists before adding value
	if SupplyAnalyser.window.contentsPanel.graphPanel:getGraphsCount() == 0 then
		SupplyAnalyser.window.contentsPanel.graphPanel:createGraph()
		SupplyAnalyser.window.contentsPanel.graphPanel:setLineWidth(1, 1)
		SupplyAnalyser.window.contentsPanel.graphPanel:setLineColor(1, TextColors.red)
	end
	SupplyAnalyser.window.contentsPanel.graphPanel:addValue(1, math.max(0, SupplyAnalyser.goldHour))
end

function SupplyAnalyser:getItemCount(itemId)
	local count = 0
	for _, item in pairs(SupplyAnalyser.items) do
		if item.itemId == itemId then
			count = count + 1
		end
	end
	return count
end

function SupplyAnalyser:checkDecrease()
end

function SupplyAnalyser:updateWidget(itemId)
	local itemPtr = Item.create(itemId, 1)
	local contentsPanel = SupplyAnalyser.window.contentsPanel
	local widget = contentsPanel.lootedItems:getChildById(tostring(itemId))
	if not widget then
		widget = g_ui.createWidget('LootItem', contentsPanel.lootedItems)
		widget:setId(itemId)
		widget:setItemId(itemId)
	end

	local count = SupplyAnalyser:getItemCount(itemId)
	widget:setItemCount(count)

	local value = getCurrentPrice(itemPtr)
	widget:setTooltip(string.format("%s (Value: %sgp, Sum: %sgp)", getItemServerName(itemId), formatMoney(value, ","), formatMoney(value * count, ",")))
end

function SupplyAnalyser:decreaseWidget(itemId)
	local contentsPanel = SupplyAnalyser.window.contentsPanel
	local count = SupplyAnalyser:getItemCount(itemId)
	local widget = contentsPanel.lootedItems:getChildById(tostring(itemId))
	if count < 1 then
		widget:destroy()
		SupplyAnalyser:updateWindow(true)
		return
	end

	local itemPtr = Item.create(itemId, 1)
	local value = getCurrentPrice(itemPtr)
	widget:setItemCount(count)
	widget:setTooltip(string.format("%s (Value: %sgp, Sum: %sgp)", getItemServerName(itemId), formatMoney(value, ","), formatMoney(value * count, ",")))
end

function SupplyAnalyser:addSuppliesItems(itemId)
	SupplyAnalyser.items[#SupplyAnalyser.items + 1] = {itemId = itemId, time = os.time()}

	local itemPtr = Item.create(itemId, 1)
	local value = getCurrentPrice(itemPtr)

	-- update balance
	SupplyAnalyser.goldValue = SupplyAnalyser.goldValue + value
	SupplyAnalyser.updateBalance = true

	SupplyAnalyser:updateWidget(itemId)
	SupplyAnalyser:checkBalance()
	SupplyAnalyser:updateWindow(true)
end

function SupplyAnalyser:setSupplyPerHourGauge(value)
	SupplyAnalyser.window.contentsPanel.targetLabel:setVisible(value)
	SupplyAnalyser.window.contentsPanel.goldLabelIcon:setVisible(value)
	SupplyAnalyser.window.contentsPanel.goldTarget:setVisible(value)
	SupplyAnalyser.window.contentsPanel.supplyTargetBG:setVisible(value)
	SupplyAnalyser.window.contentsPanel.separatorGauge:setVisible(value)

	SupplyAnalyser.gaugeVisible = value

	if value then
		SupplyAnalyser.window.contentsPanel.supplyGraphBG:addAnchor(AnchorTop, 'separatorGauge', AnchorBottom)
	else
		SupplyAnalyser.window.contentsPanel.supplyGraphBG:addAnchor(AnchorTop, 'separatorLootedItems', AnchorBottom)
	end
end

function SupplyAnalyser:setSupplyPerHourGraph(value)
	SupplyAnalyser.window.contentsPanel.supplyGraphBG:setVisible(value)
	SupplyAnalyser.window.contentsPanel.graphPanel:setVisible(value)
	SupplyAnalyser.window.contentsPanel.graphHorizontal:setVisible(value)

	SupplyAnalyser.graphVisible = value
end

function SupplyAnalyser:gaugeIsVisible()
	return SupplyAnalyser.gaugeVisible
end
function SupplyAnalyser:graphIsVisible()
	return SupplyAnalyser.graphVisible
end
function SupplyAnalyser:getTarget()
	return SupplyAnalyser.target
end
function SupplyAnalyser:setTarget(value)
	SupplyAnalyser.target = tonumber(value) or 0
	SupplyAnalyser.window.contentsPanel.goldTarget:setText(formatMoney(SupplyAnalyser.target, ","))
end

function SupplyAnalyser:openTargetConfig()
	local window = configPopupWindow["lootButton"]
	window:show()
	window:setText('Set Supply Target')
	window.contentPanel.text:setImageSource('/images/game/analyzer/labels/supply')

	window.onEnter = function()
		local value = window.contentPanel.lootTarget:getText()
		SupplyAnalyser.target = tonumber(value)
		window:hide()
	end
	window.contentPanel.lootTarget:setText(tonumber(SupplyAnalyser.target) or '0')

	window.contentPanel.ok.onClick = function()
		local value = window.contentPanel.lootTarget:getText()
		SupplyAnalyser.target = tonumber(value)
		window:hide()
	end
	window.contentPanel.cancel.onClick = function()
		window:hide()
	end
end
