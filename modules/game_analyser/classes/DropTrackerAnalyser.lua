-- Add capitalize function to string library (force override)
function string.capitalize(str)
    if not str or str == "" then
        return str
    end
    
    -- Split by spaces, capitalize each word, then join back
    local words = {}
    for word in str:gmatch("%S+") do
        if word:len() > 0 then
            -- Convert word to lowercase, then capitalize first letter
            local lowerWord = word:lower()
            local capitalizedWord = lowerWord:sub(1, 1):upper() .. lowerWord:sub(2)
            table.insert(words, capitalizedWord)
        end
    end
    
    return table.concat(words, " ")
end

-- Missing utility functions
local function formatMoney(value, separator)
    return comma_value(tostring(value))
end

local function getItemServerName(itemId)
    local thingType = g_things.getThingType(itemId, ThingCategoryItem)
    if thingType then
        return thingType:getName()
    end
    return "Unknown Item"
end

-- Helper function to get item color based on value
local function getItemColor(itemId)
    local thingType = g_things.getThingType(itemId, ThingCategoryItem)
    if thingType then
        local price = thingType:getMeanPrice() or 0
        if price >= 1000000 then
            return "#ffff00"  -- yellow
        elseif price >= 100000 then
            return "#ff00ff"  -- purple/magenta
        elseif price >= 10000 then
            return "#0080ff"  -- blue
        elseif price >= 1000 then
            return "#00ff00"  -- green
        elseif price >= 50 then
            return "#808080"  -- grey
        else
            return "#ffffff"  -- white
        end
    end
    return "#ffffff"  -- default white
end

-- Helper function to append colored text to a table
local function setStringColor(textTable, text, color)
    table.insert(textTable, "{" .. text .. ", " .. color .. "}")
end

if not DropTrackerAnalyser then
	DropTrackerAnalyser = {
		launchTime = 0,
		session = 0,

		trackedItems = {},

		autoTrackAboveValue = 0,

		-- private
		window = nil,
	}
	DropTrackerAnalyser.__index = DropTrackerAnalyser
end

function DropTrackerAnalyser:create()
	DropTrackerAnalyser.window = openedWindows['dropButton']
	
	if not DropTrackerAnalyser.window then
		return
	end

	-- Hide buttons we don't want
	local toggleFilterButton = DropTrackerAnalyser.window:recursiveGetChildById('toggleFilterButton')
	if toggleFilterButton then
		toggleFilterButton:setVisible(false)
	end
	
	local newWindowButton = DropTrackerAnalyser.window:recursiveGetChildById('newWindowButton')
	if newWindowButton then
		newWindowButton:setVisible(false)
	end

	-- Position contextMenuButton where toggleFilterButton was (to the left of minimize button)
	local contextMenuButton = DropTrackerAnalyser.window:recursiveGetChildById('contextMenuButton')
	local minimizeButton = DropTrackerAnalyser.window:recursiveGetChildById('minimizeButton')
	
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
			return onDropTrackerExtra(pos)
		end
	end

	-- Position lockButton to the left of contextMenuButton
	local lockButton = DropTrackerAnalyser.window:recursiveGetChildById('lockButton')
	
	if lockButton and contextMenuButton then
		lockButton:setVisible(true)
		lockButton:breakAnchors()
		lockButton:addAnchor(AnchorTop, contextMenuButton:getId(), AnchorTop)
		lockButton:addAnchor(AnchorRight, contextMenuButton:getId(), AnchorLeft)
		lockButton:setMarginRight(2)  -- Same margin as in miniwindow style
		lockButton:setMarginTop(0)
	end

	DropTrackerAnalyser.launchTime = g_clock.millis()
	DropTrackerAnalyser.session = 0
	DropTrackerAnalyser.autoTrackAboveValue = 0

	DropTrackerAnalyser.trackedItems = {}
end

function DropTrackerAnalyser:managerDropItem(itemId, shouldTrack)
	if shouldTrack then
		-- Add item to tracking
		if not DropTrackerAnalyser.trackedItems[itemId] then
			DropTrackerAnalyser.trackedItems[itemId] = {
				monsterDrop = {},
				recordStartTimestamp = os.time(),
				dropCount = 0,
				persistent = true
			}
		else
			-- Make sure existing tracked item is persistent
			DropTrackerAnalyser.trackedItems[itemId].persistent = true
		end
	else
		-- Remove item from tracking
		if DropTrackerAnalyser.trackedItems[itemId] then
			DropTrackerAnalyser.trackedItems[itemId] = nil
		end
	end
	
	-- Update the display
	DropTrackerAnalyser:updateWindow(true)
	
	-- Save the configuration
	DropTrackerAnalyser:saveConfigJson()
end

function DropTrackerAnalyser:checkTracker()
	local needUpdate = false
	for itemId, config in pairs(DropTrackerAnalyser.trackedItems) do
		if not config.persistent and (os.time() - config.recordStartTimestamp > 120) then
			DropTrackerAnalyser.trackedItems[itemId] = nil
			needUpdate = true
		else
			-- check monstertracker
			for id, mInfo in ipairs(config.monsterDrop) do
				if (os.time() - mInfo.time) > 45 then
					needUpdate = true
				end
			end
		end
	end

	if needUpdate then
		DropTrackerAnalyser:updateWindow(true)
	end
end

function DropTrackerAnalyser:reset(isLogin)
	DropTrackerAnalyser.launchTime = g_clock.millis()
	DropTrackerAnalyser.session = 0
	if not isLogin then
		DropTrackerAnalyser.autoTrackAboveValue = 0
	end

	for itemId, config in pairs(DropTrackerAnalyser.trackedItems) do
		if config.monsterDrop then
			config.monsterDrop = {}
		end
		-- Reset drop count and update timestamp for new session
		config.dropCount = 0
		config.recordStartTimestamp = os.time()
	end

	DropTrackerAnalyser:updateWindow(true)
end

function DropTrackerAnalyser:updateWindow(ignoreVisible)
	if not DropTrackerAnalyser.window:isVisible() and not ignoreVisible then
		return
	end

	local contentsPanel = DropTrackerAnalyser.window.contentsPanel
	-- lets loop through all the items and flag them for removal
	for _, widget in pairs(contentsPanel.dropItems:getChildren()) do
		widget.toBeRemoved = true
		for _, monsterWidget in pairs(widget.dropMonster:getChildren()) do
			monsterWidget.toBeRemoved = true
		end
	end

	for itemId, config in pairs(DropTrackerAnalyser.trackedItems) do
		local widget = contentsPanel.dropItems:getChildById("ItemPanel_" .. itemId)
		if not widget then
			-- unable to find the item, then it most likely is a
			-- new item being tracked, so lets create it
			widget = g_ui.createWidget('ItemPanel', contentsPanel.dropItems)
			widget:setId("ItemPanel_" .. itemId)
			widget.itemSlot:setItemId(itemId)
			widget.itemName:setText(string.capitalize(short_text(getItemServerName(itemId), 13)))
			widget.drops:setText(formatMoney(config.dropCount, ","))

			-- Add right-click context menu
			widget.onMousePress = function(self, mousePos, mouseButton)
				if mouseButton == MouseRightButton then
					DropTrackerAnalyser:showItemContextMenu(self, mousePos, itemId)
					return true
				end
				return false
			end

			for _, monsterDrop in ipairs(config.monsterDrop) do
				local monsterWidget = g_ui.createWidget('MonsterPanel', widget.dropMonster)
				monsterWidget.monster:setOutfit(monsterDrop.outfit)
				local capitalizedName = string.capitalize(monsterDrop.monsterName)
				monsterWidget.name:setText(capitalizedName)
				monsterWidget.drops:setText("(" ..formatMoney(monsterDrop.count, ",") .. ")")
				monsterDrop.widget = monsterWidget
			end

			widget:updateItemPanelSize()
		else
			-- if we found the item, and applied updates to it, must must
			-- check it to not be removed
			widget.drops:setText(formatMoney(config.dropCount, ","))
			widget.toBeRemoved = nil

			-- Ensure right-click context menu is available
			if not widget.onMousePress then
				widget.onMousePress = function(self, mousePos, mouseButton)
					if mouseButton == MouseRightButton then
						DropTrackerAnalyser:showItemContextMenu(self, mousePos, itemId)
						return true
					end
					return false
				end
			end

			local toBeRemoved = {}
			for id, monsterDrop in ipairs(config.monsterDrop) do
				local monsterWidget = monsterDrop.widget
				if not monsterWidget then
					-- if there is no monsterWidget set, then we need to create it
					local monsterWidget = g_ui.createWidget('MonsterPanel', widget.dropMonster)
					monsterWidget.monster:setOutfit(monsterDrop.outfit)
					local capitalizedName = string.capitalize(monsterDrop.monsterName)
					monsterWidget.name:setText(capitalizedName)
					monsterWidget.drops:setText("(" ..formatMoney(monsterDrop.count, ",") .. ")")
					-- we also save the reference for later on use
					monsterDrop.widget = monsterWidget
				else
					-- if the monsterWidget is already set, then we must check
					-- if it needs to be removed (time > 45s)
					if (os.time() - monsterDrop.time) > 45 then
						-- this is already being done in the
						-- initial part of this function
						-- monsterWidget.toBeRemoved = true

						-- but lets keep track of the ids to
						-- be removed later on (outside of this
						-- loop)
						table.insert(toBeRemoved, id)
					else
						monsterWidget.toBeRemoved = nil
					end
				end
			end

			if #toBeRemoved == 0 then
				-- dont need to do the update of the heights
				-- now, since it will be done later on during
				-- the widget removal
				widget:updateItemPanelSize()
			end

			-- there is no need to keep it on monsterDrop
			-- table if its removal was already scheduled
			-- and by keeping it, it would be re-added eventually
			for _, id in ipairs(toBeRemoved) do
				table.remove(config.monsterDrop, id)
			end
		end
	end

	for _, widget in pairs(contentsPanel.dropItems:getChildren()) do
		if widget.toBeRemoved then
			widget:destroy()
		end

		if widget.dropMonster then
			local destroyedAtLeastOne = false
			for _, monsterWidget in pairs(widget.dropMonster:getChildren()) do
				if monsterWidget.toBeRemoved then
					monsterWidget:destroy()
					destroyedAtLeastOne = true
				end
			end

			if destroyedAtLeastOne then
				widget:updateItemPanelSize()
			end
		end
	end
end

function DropTrackerAnalyser:sendDropedItems(consoleMessage)
    -- Now that textmessage.lua handles colored formatting for ValuableLoot,
    -- we can use the same colored message for both screen and console
    if g_game.isOnline() then
        modules.game_textmessage.displayMessage(MessageModes.ValuableLoot, consoleMessage)
    end
end

function DropTrackerAnalyser:tryAddingMonsterDrop(item, monsterName, monsterOutfit, dropItems, dropedItems)
	local itemId = item:getId()
	local tracker = DropTrackerAnalyser.trackedItems[itemId]
	local itemPrice = item:getMeanPrice() and item:getMeanPrice() or 0
	
	-- Check if item is explicitly tracked
	if tracker then
		-- Item is explicitly being tracked
		dropedItems[#dropedItems + 1] = itemId
		tracker.dropCount = tracker.dropCount + item:getCount()
		tracker.recordStartTimestamp = os.time()
		tracker.monsterDrop[#tracker.monsterDrop + 1] = {monsterName = monsterName, outfit = monsterOutfit, time = os.time(), count = item:getCount()}
		return
	end
	
	-- Check if item should be auto-tracked based on value
	if DropTrackerAnalyser.autoTrackAboveValue > 0 and itemPrice >= DropTrackerAnalyser.autoTrackAboveValue then
		-- Auto-track this valuable item (non-persistent)
		DropTrackerAnalyser.trackedItems[itemId] = {monsterDrop = {}, recordStartTimestamp = os.time(), dropCount = 0, persistent = false}
		tracker = DropTrackerAnalyser.trackedItems[itemId]
		
		dropedItems[#dropedItems + 1] = itemId
		tracker.dropCount = tracker.dropCount + item:getCount()
		tracker.recordStartTimestamp = os.time()
		tracker.monsterDrop[#tracker.monsterDrop + 1] = {monsterName = monsterName, outfit = monsterOutfit, time = os.time(), count = item:getCount()}
	end
end

function DropTrackerAnalyser:checkMonsterKilled(monsterName, monsterOutfit, dropItems)
	if table.empty(DropTrackerAnalyser.trackedItems) and DropTrackerAnalyser.autoTrackAboveValue == 0 then
		return true
	end

	local dropedItems = {}
	for _, item in pairs(dropItems) do
		DropTrackerAnalyser:tryAddingMonsterDrop(item, monsterName, monsterOutfit, dropItems, dropedItems)
	end

	if #dropedItems ~= 0 then
		local consoleMessage = "{Valuable loot:, #f0b400}"
		
		local first = true
		for _, itemId in pairs(dropedItems) do
			local name = getItemServerName(itemId)
			-- Ensure we have valid data before processing
			if not name or name == "" then
				name = "Unknown Item"
			end
			if not itemId or itemId == 0 then
				itemId = 0
			end
			
			if not first then
				consoleMessage = consoleMessage .. "{,, #f0b400}"
			else
				first = false
			end
			
			-- Use the server loot message format that ItemsDatabase.setColorLootMessage expects
			consoleMessage = consoleMessage .. "{ , #f0b400}{" .. itemId .. "|" .. name .. "}"
		end

		consoleMessage = consoleMessage .. "{ dropped by " .. monsterName .. "!, #f0b400}"
		
		DropTrackerAnalyser:sendDropedItems(consoleMessage)
	end

	if not table.empty(dropedItems) then
		DropTrackerAnalyser:updateWindow(true)
	end

	return true
end

function DropTrackerAnalyser:isInDropTracker(itemId)
	local tracker = DropTrackerAnalyser.trackedItems[itemId]
	return tracker and tracker.persistent
end

function DropTrackerAnalyser:removeItem(itemId)
	-- Remove item from our tracking
	if DropTrackerAnalyser.trackedItems[itemId] then
		DropTrackerAnalyser.trackedItems[itemId] = nil
	end
	
	-- Update Cyclopedia using direct helper functions (avoiding circular dependency)
	-- Try both access patterns to find the correct one
	local cyclopediaItems = nil
	if Cyclopedia and Cyclopedia.Items then
		cyclopediaItems = Cyclopedia.Items
	elseif modules.game_cyclopedia and modules.game_cyclopedia.Items then
		cyclopediaItems = modules.game_cyclopedia.Items
	elseif modules.game_cyclopedia and modules.game_cyclopedia.Cyclopedia and modules.game_cyclopedia.Cyclopedia.Items then
		cyclopediaItems = modules.game_cyclopedia.Cyclopedia.Items
	end
	
	if cyclopediaItems and cyclopediaItems.removeFromDropTrackerDirectly then
		cyclopediaItems.removeFromDropTrackerDirectly(itemId)
		
		-- Also refresh the current item display if available
		if cyclopediaItems.refreshCurrentItem then
			cyclopediaItems.refreshCurrentItem()
		end
	end
	
	-- Update the display
	DropTrackerAnalyser:updateWindow(true)
	
	-- Save the configuration
	DropTrackerAnalyser:saveConfigJson()
end

function DropTrackerAnalyser:removeAllItems()
	-- Get all tracked item IDs for individual visual feedback if needed
	local itemIds = {}
	for itemId, _ in pairs(DropTrackerAnalyser.trackedItems) do
		table.insert(itemIds, itemId)
	end
	
	-- Clear all tracked items
	DropTrackerAnalyser.trackedItems = {}
	
	-- Update Cyclopedia using direct helper functions (avoiding circular dependency)
	-- Use the same access pattern that worked for removeItem
	local cyclopediaItems = nil
	if Cyclopedia and Cyclopedia.Items then
		cyclopediaItems = Cyclopedia.Items
	elseif modules.game_cyclopedia and modules.game_cyclopedia.Items then
		cyclopediaItems = modules.game_cyclopedia.Items
	elseif modules.game_cyclopedia and modules.game_cyclopedia.Cyclopedia and modules.game_cyclopedia.Cyclopedia.Items then
		cyclopediaItems = modules.game_cyclopedia.Cyclopedia.Items
	end
	
	if cyclopediaItems and cyclopediaItems.removeAllFromDropTrackerDirectly then
		cyclopediaItems.removeAllFromDropTrackerDirectly()
		
		-- Also refresh the current item display if available
		if cyclopediaItems.refreshCurrentItem then
			cyclopediaItems.refreshCurrentItem()
		end
	end
	
	-- Update the display
	DropTrackerAnalyser:updateWindow(true)
	
	-- Save the configuration
	DropTrackerAnalyser:saveConfigJson()
end

function DropTrackerAnalyser:showItemContextMenu(widget, mousePos, itemId)
	local menu = g_ui.createWidget('PopupMenu')
	
	menu:addOption('Remove', function()
		DropTrackerAnalyser:removeItem(itemId)
	end)
	
	menu:addOption('Remove All', function()
		DropTrackerAnalyser:removeAllItems()
	end)
	
	menu:display(mousePos)
end

function onDropTrackerExtra(mousePosition)
	local window = configPopupWindow["dropButton"]
	window:show()
	window:setText('Drop Tracker Configuration')
	window.contentPanel.text:setImageSource('/images/game/analyzer/labels/loot-track')

	window.onEnter = function()
		local value = window.contentPanel.target:getText()
		DropTrackerAnalyser.autoTrackAboveValue = tonumber(value)
		window:hide()
	end
	window.contentPanel.target:setText(tonumber(DropTrackerAnalyser.autoTrackAboveValue) or '0')

	window.contentPanel.ok.onClick = function()
		local value = window.contentPanel.target:getText()
		DropTrackerAnalyser.autoTrackAboveValue = tonumber(value)
		window:hide()
	end
	window.contentPanel.cancel.onClick = function()
		window:hide()
	end
end


function DropTrackerAnalyser:loadConfigJson()
	local config = {
		autoTrackAboveValue = 0,
		trackedItems = {},
	}

	local player = g_game.getLocalPlayer()
	if not player then 
		return 
	end

	local playerId = player:getId()
	local file = "/characterdata/" .. playerId .. "/itemtracking.json"
	if g_resources.fileExists(file) then
		local status, result = pcall(function()
			return json.decode(g_resources.readFileContents(file))
		end)

		if not status then
			return g_logger.error("Error while reading characterdata file. Details: " .. result)
		end

		config = result
	end

  table.clear(DropTrackerAnalyser.trackedItems)
	for _, i in pairs(config.trackedItems) do
		DropTrackerAnalyser.trackedItems[i.objectType] = {monsterDrop = {}, recordStartTimestamp = i.recordStartTimestamp, dropCount = i.dropCount, persistent = true}
	end

	-- Load tracked items from Cyclopedia configuration
	local cyclopediaFile = "/characterdata/" .. playerId .. "/itemprices.json"
	if g_resources.fileExists(cyclopediaFile) then
		local status, result = pcall(function()
			return json.decode(g_resources.readFileContents(cyclopediaFile))
		end)

		if status and result and result["dropTrackerItems"] then
			-- Add items marked for tracking in Cyclopedia that aren't already tracked
			for itemIdStr, isTracked in pairs(result["dropTrackerItems"]) do
				if isTracked then
					local itemId = tonumber(itemIdStr)
					if itemId and not DropTrackerAnalyser.trackedItems[itemId] then
						-- Add item as persistent tracked item
						DropTrackerAnalyser.trackedItems[itemId] = {
							monsterDrop = {}, 
							recordStartTimestamp = os.time(), 
							dropCount = 0, 
							persistent = true
						}
					end
				end
			end
		end
	end

	DropTrackerAnalyser.autoTrackAboveValue = config.autoTrackAboveValue
	DropTrackerAnalyser:updateWindow(true)
end

function DropTrackerAnalyser:saveConfigJson()
	local config = {
		autoTrackAboveValue = DropTrackerAnalyser.autoTrackAboveValue,
		trackedItems = {},
	}

	for itemId, insta in pairs(DropTrackerAnalyser.trackedItems) do
		if insta.persistent then
			config.trackedItems[#config.trackedItems + 1] = {
				dropCount = insta.dropCount,
				objectType = itemId,
				recordStartTimestamp = insta.recordStartTimestamp,
			}
		end
	end

	local player = g_game.getLocalPlayer()
	if not player then 
		return 
	end

	-- Ensure the characterdata directory exists
	local characterDir = "/characterdata/" .. player:getId()
	pcall(function() g_resources.makeDir("/characterdata") end)
	pcall(function() g_resources.makeDir(characterDir) end)

	local file = "/characterdata/" .. player:getId() .. "/itemtracking.json"
	local status, result = pcall(function() return json.encode(config, 2) end)
	if not status then
		return g_logger.error("Error while saving profile DropTracker data. Data won't be saved. Details: " .. result)
	end

	if result:len() > 100 * 1024 * 1024 then
		return g_logger.error("Something went wrong, file is above 100MB, won't be saved")
	end

	local writeStatus, writeError = pcall(function()
		return g_resources.writeFileContents(file, result)
	end)
	
	if not writeStatus then
		-- Silently handle write errors during logout
	end
end

