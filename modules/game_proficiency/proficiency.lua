-- Weapon Proficiency Module
-- Implements the Weapon Proficiency system from Summer Update 2025

if not WeaponProficiency then
    WeaponProficiency = {}
    WeaponProficiency.__index = WeaponProficiency
    
    WeaponProficiency.window = nil
    WeaponProficiency.displayItemPanel = nil
    WeaponProficiency.perkPanel = nil
    WeaponProficiency.bonusDetailPanel = nil
    WeaponProficiency.starProgressPanel = nil
    WeaponProficiency.optionFilter = nil
    WeaponProficiency.itemListScroll = nil
    WeaponProficiency.vocationWarning = nil
    WeaponProficiency.button = nil
    
    WeaponProficiency.itemList = {}
    WeaponProficiency.cacheList = {} -- [itemId] = {experience, perks}
    
    WeaponProficiency.allProficiencyRequested = false
    WeaponProficiency.firstItemRequested = nil
    WeaponProficiency.saveWeaponMissing = false
    
    WeaponProficiency.ItemCategory = {
        Axes = 17, Clubs = 18, DistanceWeapons = 19,
        Swords = 20, WandsRods = 21, FistWeapons = 27,
    }
    
    WeaponProficiency.perkPanelsName = {
        "oneBonusIconPanel", "twoBonusIconPanel", "threeBonusIconPanel"
    }
    
    WeaponProficiency.filters = {
        ["levelButton"] = false,
        ["vocButton"] = false,
        ["oneButton"] = false,
        ["twoButton"] = false,
    }
    
    -- Search filter
    WeaponProficiency.searchFilter = nil
    
    -- Scrollable settings
    WeaponProficiency.listWidgetHeight = 34
    WeaponProficiency.listCapacity = 0
    WeaponProficiency.listMinWidgets = 0
    WeaponProficiency.listMaxWidgets = 0
    WeaponProficiency.offset = 0
    WeaponProficiency.listPool = {}
    WeaponProficiency.listData = {}
end

function init()
    
    -- Load proficiency JSON data
    ProficiencyData:loadProficiencyJson()
    
    -- Create item cache from market data
    WeaponProficiency:createItemCache()
    
    -- Connect to game events
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onWeaponProficiency = onWeaponProficiency,
        onWeaponProficiencyExperience = onWeaponProficiencyExperience
    })
    
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onWeaponProficiency = onWeaponProficiency,
        onWeaponProficiencyExperience = onWeaponProficiencyExperience
    })
    
    if WeaponProficiency.window then
        WeaponProficiency.window:destroy()
        WeaponProficiency.window = nil
    end
end

function onGameStart()
    WeaponProficiency.allProficiencyRequested = false
    WeaponProficiency.saveWeaponMissing = false
    WeaponProficiency.firstItemRequested = nil
    WeaponProficiency.cacheList = {}
    WeaponProficiency.currentEquippedExp = 0
    WeaponProficiency.currentEquippedMaxExp = 0
    
    -- Recreate item cache on each login (may have been cleared by reset())
    WeaponProficiency:createItemCache()
    
    -- Add button to main panel (only for clients that support proficiency system)
    -- Use addToggleButton for notification support (20x40 vertical image)
    if modules.game_mainpanel and g_game.getClientVersion() >= 1500 then
        WeaponProficiency.button = modules.game_mainpanel.addToggleButton(
            'ProficiencyButton', 
            tr('Open Weapon Proficiency'),
            '/images/options/button_proficiency',
            function() toggle() end, 
            false, 
            21, -- index for ordering
            true -- vertical image (20x40)
        )
        if WeaponProficiency.button then
            local btn = WeaponProficiency.button:getChildById('button')
            if btn then btn:setOn(false) end
        end
    end
    
    -- Initialize topbar proficiency widget
    initTopBarProficiency()
end

-- Initialize the proficiency widget in the top stats bar
function initTopBarProficiency()
    -- Delay initialization to ensure StatsBar is fully loaded
    scheduleEvent(function()
        -- Access StatsBar through modules.game_interface
        local StatsBarModule = modules.game_interface and modules.game_interface.StatsBar
        if not StatsBarModule then 
            scheduleEvent(initTopBarProficiency, 500)
            return 
        end
        
        local statsBar = StatsBarModule.getCurrentStatsBarWithPosition and StatsBarModule.getCurrentStatsBarWithPosition()
        if statsBar then
            local profWidget = statsBar:recursiveGetChildById('proficiencyTopBar')
            if profWidget then
                local shouldShow = g_game.getClientVersion() >= 1500
                profWidget:setVisible(shouldShow)
                
                if shouldShow then
                    -- Request proficiency data for equipped weapon
                    local player = g_game.getLocalPlayer()
                    if player then
                        local leftSlotItem = player:getInventoryItem(InventorySlotLeft)
                        if leftSlotItem and g_game.sendWeaponProficiencyAction then
                            local itemId = leftSlotItem:getId()
                            g_game.sendWeaponProficiencyAction(0, itemId)
                        end
                    end
                    updateTopBarProficiency()
                end
            end
        else
            scheduleEvent(initTopBarProficiency, 500)
        end
    end, 500) -- 500ms delay
end

-- Update the proficiency progress bar in the top bar
function updateTopBarProficiency()
    -- Access StatsBar through modules.game_interface
    local StatsBarModule = modules.game_interface and modules.game_interface.StatsBar
    if not StatsBarModule then return end
    
    local statsBar = StatsBarModule.getCurrentStatsBarWithPosition and StatsBarModule.getCurrentStatsBarWithPosition()
    if not statsBar then return end
    
    local profWidget = statsBar:recursiveGetChildById('proficiencyTopBar')
    if not profWidget then return end
    
    -- Get equipped weapon
    local player = g_game.getLocalPlayer()
    if not player then return end
    
    local leftSlotItem = player:getInventoryItem(InventorySlotLeft)
    if not leftSlotItem then
        -- No weapon equipped - show 0%
        local progressBar = profWidget:getChildById('proficiencyProgress')
        local label = profWidget:getChildById('proficiencyLabel')
        if progressBar then progressBar:setPercent(0) end
        if label then label:setText('0%') end
        return
    end
    
    local itemId = leftSlotItem:getId()
    local cacheData = WeaponProficiency.cacheList[itemId]
    
    if cacheData then
        local exp = cacheData.exp or 0
        
        -- Get thingType for calculations
        local thingType = nil
        if leftSlotItem.getThingType then
            thingType = leftSlotItem:getThingType()
        end
        
        -- Calculate percent for next level (not total)
        local percent = 0
        local currentLevel = 0
        local nextLevelExp = 0
        local currentLevelExp = 0
        
        if ProficiencyData and ProficiencyData.getCurrentLevelByExp and ProficiencyData.getLevelPercent then
            -- Get current level
            currentLevel = ProficiencyData:getCurrentLevelByExp(leftSlotItem, exp, false, thingType) or 0
            -- Get percent progress to next level
            local nextLevel = currentLevel + 1
            percent = ProficiencyData:getLevelPercent(exp, nextLevel, leftSlotItem, thingType) or 0
            
            -- Get exp values for tooltip
            if ProficiencyData.getMaxExperienceByLevel then
                currentLevelExp = currentLevel > 0 and (ProficiencyData:getMaxExperienceByLevel(currentLevel, leftSlotItem, thingType) or 0) or 0
                nextLevelExp = ProficiencyData:getMaxExperienceByLevel(nextLevel, leftSlotItem, thingType) or 0
            end
        end
        
        percent = math.min(100, math.max(0, percent))
        
        local progressBar = profWidget:getChildById('proficiencyProgress')
        local label = profWidget:getChildById('proficiencyLabel')
        local bg = profWidget:getChildById('proficiencyBg')
        
        if progressBar then progressBar:setPercent(percent) end
        if label then label:setText(percent .. '%') end
        if bg then 
            local expInLevel = exp - currentLevelExp
            local expNeeded = nextLevelExp - currentLevelExp
            bg:setTooltip(string.format("Proficiency Progress: %s / %s", tostring(expInLevel), tostring(expNeeded))) 
        end
        
        -- Show/hide highlight based on unused perk
        local highlight = profWidget:getChildById('highlightProficiencyButton')
        if highlight then
            highlight:setVisible(WeaponProficiency.hasUnusedPerk == true)
        end
        
        -- Store for reference
        WeaponProficiency.currentEquippedExp = exp
        WeaponProficiency.currentEquippedMaxExp = nextLevelExp
    else
        -- No cache data yet - request it
        if g_game.sendWeaponProficiencyAction then
            g_game.sendWeaponProficiencyAction(0, itemId)
        end
    end
end

function onGameEnd()
    if WeaponProficiency.window then
        WeaponProficiency.window:hide()
    end
    
    -- Remove button from main panel
    if WeaponProficiency.button then
        WeaponProficiency.button:destroy()
        WeaponProficiency.button = nil
    end
    
    WeaponProficiency:reset()
end

-- Called when server sends proficiency info (opcode 0xC4)
function onWeaponProficiency(itemId, experience, perks, marketCategory)
    -- Ensure perks is a table
    if type(perks) ~= "table" then
        perks = {}
    end
    
    -- IMPORTANT: Server sends perks in 0-indexed format, convert to 1-indexed for Lua
    -- Also filter out invalid perks (values >= 200 are clearly invalid, likely from uninitialized data)
    local convertedPerks = {}
    for _, perk in ipairs(perks) do
        if type(perk) == "table" and #perk >= 2 then
            local level = perk[1]
            local perkPos = perk[2]
            -- Filter out invalid values (255 becomes 256 after +1, which is invalid)
            -- Valid levels are 0-6 (0-indexed), valid perk positions are 0-2 (0-indexed)
            if level >= 0 and level <= 10 and perkPos >= 0 and perkPos <= 10 then
                -- Convert from 0-indexed (server) to 1-indexed (Lua)
                table.insert(convertedPerks, {level + 1, perkPos + 1})
            end
        end
    end
    
    -- Only update cache perks if server returned non-empty perks
    -- Otherwise, keep existing cache perks (they were just applied)
    local existingCache = WeaponProficiency.cacheList[itemId]
    if #convertedPerks > 0 then
        -- Server confirmed perks, use them (now in 1-indexed format)
        WeaponProficiency.cacheList[itemId] = { exp = experience, perks = convertedPerks }
    else
        -- Server returned empty perks, but we may have just applied some
        -- Keep existing perks in cache if they exist
        if existingCache and existingCache.perks and #existingCache.perks > 0 then
            WeaponProficiency.cacheList[itemId] = { exp = experience, perks = existingCache.perks }
        else
            WeaponProficiency.cacheList[itemId] = { exp = experience, perks = {} }
        end
    end
    
    local cachePerks = WeaponProficiency.cacheList[itemId].perks
    
    -- Re-sort the item list when we receive new proficiency data
    if marketCategory then
        sortWeaponProficiency(marketCategory)
        sortWeaponProficiency(MarketCategory.WeaponsAll)
    end
    
    if WeaponProficiency.window and WeaponProficiency.window:isVisible() then
        -- Refresh item list to update stars and order
        WeaponProficiency:refreshItemList()
        
        WeaponProficiency:onUpdateSelectedProficiency(itemId)
        
        -- If this is the currently selected item, update display with cached perks
        if WeaponProficiency.selectedItemId == itemId then
            WeaponProficiency:displayProficiencyData(itemId, experience, cachePerks)
        end
    end
    
    -- Update top bar proficiency display
    updateTopBarProficiency()
end

-- Called when server sends proficiency experience update (opcode 0x5C)
function onWeaponProficiencyExperience(itemId, experience, hasUnusedPerk)
    local itemCache = WeaponProficiency.cacheList[itemId]
    if not itemCache then
        WeaponProficiency.cacheList[itemId] = { exp = experience, perks = {} }
    else
        if experience > 0 then
            itemCache.exp = experience
        end
    end
    
    -- Re-sort all categories when experience changes
    sortWeaponProficiency(MarketCategory.WeaponsAll)
    for _, categoryId in pairs(WeaponProficiency.ItemCategory) do
        sortWeaponProficiency(categoryId)
    end
    
    -- Store the unused perk state globally
    WeaponProficiency.hasUnusedPerk = hasUnusedPerk
    
    -- Show/hide highlight on proficiency button based on unused perks
    updateProficiencyHighlight()
    
    -- Refresh item list if window is visible
    if WeaponProficiency.window and WeaponProficiency.window:isVisible() then
        WeaponProficiency:refreshItemList()
    end
    
    -- Update top bar proficiency display
    updateTopBarProficiency()
end

-- Update the proficiency button highlight based on unused perk state
function updateProficiencyHighlight()
    if WeaponProficiency.button then
        local highlight = WeaponProficiency.button:getChildById('highlight')
        local bright = WeaponProficiency.button:getChildById('brightButton')
        local shouldShow = WeaponProficiency.hasUnusedPerk == true
        if highlight then highlight:setVisible(shouldShow) end
        if bright then bright:setVisible(shouldShow) end
    end
end

-- Public function to open the proficiency window
function show()
    if not WeaponProficiency.window then
        createWindow()
    end
    
    -- Reset search filter and clear search text
    WeaponProficiency.searchFilter = nil
    local searchText = WeaponProficiency.window:recursiveGetChildById('searchText')
    if searchText then
        searchText:setText('')
    end
    
    -- Reset filter buttons visual state (but keep filter state)
    -- The filters persist across open/close
    
    WeaponProficiency.window:show()
    WeaponProficiency.window:raise()
    WeaponProficiency.window:focus()
    
    -- Update button state (for highlight widget, use child button)
    if WeaponProficiency.button then
        local btn = WeaponProficiency.button:getChildById('button')
        if btn then
            btn:setOn(true)
            -- For vertical images, set correct clip
            btn:setImageClip('0 20 20 20')
        end
        -- Hide highlight when window is opened
        local highlight = WeaponProficiency.button:getChildById('highlight')
        local bright = WeaponProficiency.button:getChildById('brightButton')
        if highlight then highlight:setVisible(false) end
        if bright then bright:setVisible(false) end
    end
    
    -- Refresh item list to show all items
    WeaponProficiency:refreshItemList()
    
    -- Auto-select item when window opens (equipped weapon or first in list)
    -- Use longer delay to ensure items are loaded, with retry
    WeaponProficiency.autoSelectRetries = 0
    scheduleEvent(function()
        autoSelectItem()
    end, 300)
end

-- Auto-select an item (equipped weapon or first in list)
function autoSelectItem()
    if not WeaponProficiency.window or not WeaponProficiency.window:isVisible() then
        return
    end
    
    -- Already has a selected item with perks displayed? Skip
    if WeaponProficiency.selectedMarketItem and WeaponProficiency.selectedMarketItem.displayItem then
        local perkPanel = WeaponProficiency.perkPanel
        if perkPanel and perkPanel:getChildCount() > 0 then
            return
        end
    end
    
    local targetItemId = nil
    local targetMarketItem = nil
    
    -- Get all items from all categories
    local allItems = WeaponProficiency.itemList[MarketCategory.WeaponsAll] or {}
    
    -- First, check if player has an equipped weapon
    local player = g_game.getLocalPlayer()
    if player then
        local leftSlotItem = player:getInventoryItem(InventorySlotLeft)
        if leftSlotItem then
            local equippedId = leftSlotItem:getId()
            -- Search for this item in our list
            for _, marketItem in ipairs(allItems) do
                local itemId = marketItem.originalId or (marketItem.displayItem and marketItem.displayItem:getId())
                local displayId = marketItem.displayId or itemId
                if itemId == equippedId or displayId == equippedId then
                    targetItemId = itemId
                    targetMarketItem = marketItem
                    break
                end
            end
        end
    end
    
    -- If no equipped weapon found, select first item from the allItems list
    if not targetItemId and #allItems > 0 then
        -- Just take the first item from the list
        local firstItem = allItems[1]
        if firstItem then
            targetItemId = firstItem.originalId or (firstItem.displayItem and firstItem.displayItem:getId())
            targetMarketItem = firstItem
        end
    end
    
    -- Fallback: check UI item list if allItems is empty
    if not targetItemId then
        local itemList = WeaponProficiency.window:recursiveGetChildById("itemList")
        if itemList then
            local children = itemList:getChildren()
            for _, child in ipairs(children) do
                local itemWidget = child:getChildById('item')
                if itemWidget then
                    local displayItem = itemWidget:getItem()
                    if displayItem and displayItem:getId() > 0 then
                        local displayItemId = displayItem:getId()
                        -- Find the marketItem for this display
                        for _, marketItem in ipairs(allItems) do
                            local mItemId = marketItem.originalId or (marketItem.displayItem and marketItem.displayItem:getId())
                            local mDisplayId = marketItem.displayId or mItemId
                            if mDisplayId == displayItemId or mItemId == displayItemId then
                                targetItemId = mItemId
                                targetMarketItem = marketItem
                                break
                            end
                        end
                        if targetItemId then break end
                    end
                end
            end
        end
    end
    
    -- Select the target item
    if targetItemId and targetMarketItem then
        WeaponProficiency:selectItem(targetItemId, targetMarketItem)
    else
        -- Retry if no item found yet (cache might not be ready)
        WeaponProficiency.autoSelectRetries = (WeaponProficiency.autoSelectRetries or 0) + 1
        if WeaponProficiency.autoSelectRetries < 5 then
            scheduleEvent(function()
                autoSelectItem()
            end, 200)
        end
    end
end

function hide()
    if not WeaponProficiency.window then return end
    
    -- Check if there are pending selections
    local hasPending = WeaponProficiency.pendingSelections and next(WeaponProficiency.pendingSelections) ~= nil
    
    if hasPending then
        -- For now, just apply and close (we can add dialog later)
        WeaponProficiency:applyPendingSelections()
    end
    
    -- Close window
    WeaponProficiency.window:hide()
    
    -- Update button state (for highlight widget, use child button)
    if WeaponProficiency.button then
        local btn = WeaponProficiency.button:getChildById('button')
        if btn then
            btn:setOn(false)
            -- For vertical images, restore normal clip
            btn:setImageClip('0 0 20 20')
        end
    end
    
    -- Re-show highlight if there are still unused perks
    updateProficiencyHighlight()
    
    -- Reset selected item state so auto-select works on next open
    WeaponProficiency.selectedItemId = nil
    WeaponProficiency.selectedDisplayId = nil
    WeaponProficiency.selectedMarketItem = nil
end

function toggle()
    if WeaponProficiency.window and WeaponProficiency.window:isVisible() then
        hide()
    else
        requestOpenWindow()
    end
end

-- Request to open proficiency window with optional item redirect
function requestOpenWindow(redirectItem)
    local category = "Weapons: All"
    local targetItemId = nil
    
    -- Check left hand slot for equipped weapon
    local player = g_game.getLocalPlayer()
    if player then
        local leftSlotItem = player:getInventoryItem(InventorySlotLeft)
        if leftSlotItem then
            local weaponType = leftSlotItem.getWeaponType and leftSlotItem:getWeaponType() or 0
            if weaponType > 0 then
                category = getWeaponCategoryString(weaponType)
                targetItemId = leftSlotItem:getId()
            end
        end
    end
    
    if redirectItem then
        local weaponType = redirectItem.getWeaponType and redirectItem:getWeaponType() or 0
        if weaponType > 0 then
            category = getWeaponCategoryString(weaponType)
            targetItemId = redirectItem:getId()
        end
    end
    
    -- Request all proficiencies from server
    if not WeaponProficiency.allProficiencyRequested then
        g_game.sendWeaponProficiencyAction(1) -- Request all weapons
        WeaponProficiency.allProficiencyRequested = true
        WeaponProficiency.firstItemRequested = redirectItem
    end
    
    show()
end

-- Helper function to get weapon category string
function getWeaponCategoryString(weaponType)
    local categoryMap = {
        [1] = "Weapons: Clubs",     -- WEAPON_CLUB
        [2] = "Weapons: Axes",      -- WEAPON_AXE
        [3] = "Weapons: Swords",    -- WEAPON_SWORD
        [4] = "Weapons: Wands",     -- WEAPON_WANDROD
        [7] = "Weapons: Distance",  -- WEAPON_BOW
        [8] = "Weapons: Distance",  -- WEAPON_THROW
        [9] = "Weapons: Distance",  -- WEAPON_CROSSBOW
        [0] = "Weapons: Fist",      -- WEAPON_FIST
    }
    return categoryMap[weaponType] or "Weapons: All"
end

-- Create the proficiency window
function createWindow()
    WeaponProficiency.window = g_ui.displayUI('proficiency')
    WeaponProficiency.window:hide()
    
    WeaponProficiency.displayItemPanel = WeaponProficiency.window:recursiveGetChildById("itemPanel")
    WeaponProficiency.perkPanel = WeaponProficiency.window:recursiveGetChildById("bonusProgressBackground")
    WeaponProficiency.bonusDetailPanel = WeaponProficiency.window:recursiveGetChildById("bonusDetailBackground")
    WeaponProficiency.optionFilter = WeaponProficiency.window:recursiveGetChildById("classFilter")
    WeaponProficiency.starProgressPanel = WeaponProficiency.window:recursiveGetChildById("starsPanelBackground")
    WeaponProficiency.itemListScroll = WeaponProficiency.window:recursiveGetChildById("itemListScroll")
    WeaponProficiency.vocationWarning = WeaponProficiency.window:recursiveGetChildById("vocationWarning")
    
    -- Debug: verify panels are found
    
    -- Setup category dropdown options
    if WeaponProficiency.optionFilter then
        WeaponProficiency.optionFilter:clearOptions()
        WeaponProficiency.optionFilter:addOption("Weapons: All")
        WeaponProficiency.optionFilter:addOption("Weapons: Swords")
        WeaponProficiency.optionFilter:addOption("Weapons: Axes")
        WeaponProficiency.optionFilter:addOption("Weapons: Clubs")
        WeaponProficiency.optionFilter:addOption("Weapons: Distance")
        WeaponProficiency.optionFilter:addOption("Weapons: Wands")
        WeaponProficiency.optionFilter:addOption("Weapons: Fist")
        WeaponProficiency.optionFilter.onOptionChange = function(widget, option)
            WeaponProficiency:refreshItemList()
        end
    end
    
    -- Setup search text handler
    local searchText = WeaponProficiency.window:recursiveGetChildById('searchText')
    if searchText then
        searchText.onTextChange = function(widget, text)
            WeaponProficiency.searchFilter = text
    WeaponProficiency:refreshItemList()
end
    end
    
    -- Setup clear search button
    local clearButton = WeaponProficiency.window:recursiveGetChildById('clearSearchButton')
    if clearButton then
        clearButton.onClick = function()
            local searchWidget = WeaponProficiency.window:recursiveGetChildById('searchText')
            if searchWidget then
                searchWidget:setText('')
                WeaponProficiency.searchFilter = nil
                WeaponProficiency:refreshItemList()
        end
    end
end

    -- Initialize item list
    WeaponProficiency:refreshItemList()
end


-- Reset proficiency data
function WeaponProficiency:reset()
    self.cacheList = {}
    self.allProficiencyRequested = false
    self.itemList = {}
end

-- Create item cache from proficiency things
function WeaponProficiency:createItemCache()
    self.itemList[MarketCategory.WeaponsAll] = {}
    for _, v in pairs(self.ItemCategory) do
        self.itemList[v] = {}
    end
    
    -- Weapon categories that support proficiency
    local weaponCategories = {
        [MarketCategory.Axes] = true,
        [MarketCategory.Clubs] = true,
        [MarketCategory.DistanceWeapons] = true,
        [MarketCategory.Swords] = true,
        [MarketCategory.WandsRods] = true,
        [MarketCategory.FistWeapons] = true,
    }
    
    -- Get all item types and filter by weapon categories
    local allItems = g_things.getThingTypes(ThingCategoryItem)
    
    for _, itemType in pairs(allItems) do
        local marketData = itemType.getMarketData and itemType:getMarketData() or {}
        
        -- Check if item has market data and is a weapon category
        if marketData and marketData.name and marketData.name ~= "" then
            local category = marketData.category
            
            -- Only process weapon categories
            if weaponCategories[category] then
                local originalId = itemType:getId()
                local item = Item.create(originalId)
                
                if not self.itemList[category] then
                    category = getUnknownMarketCategory(itemType)
                end
                
                -- Use showAs for display, but fall back to originalId if showAs is 0 or nil
                local showAs = marketData.showAs
                if not showAs or showAs == 0 then
                    showAs = originalId
                end
                item:setId(showAs)
                
                -- Store both originalId (server uses this for cache) and showAs (display ID)
                local marketItem = { 
                    displayItem = item, 
                    thingType = itemType, 
                    marketData = marketData,
                    originalId = originalId,  -- The server uses this ID for proficiency data
                    displayId = showAs        -- The display/showAs ID (never 0)
                }
                if self.itemList[category] then
                    table.insert(self.itemList[category], marketItem)
                end
                table.insert(self.itemList[MarketCategory.WeaponsAll], marketItem)
            end
        end
    end
    
    -- Sort by name initially
    local function sortByName(a, b)
        local nameA = (a.marketData.name or ""):lower()
        local nameB = (b.marketData.name or ""):lower()
        return nameA < nameB
    end
    
    for _, v in pairs(self.itemList) do
        table.sort(v, sortByName)
    end
    
end

-- Sort weapons by experience (highest first), then by name
function sortWeaponProficiency(marketCategory)
    local itemList = WeaponProficiency.itemList[marketCategory]
    if not itemList then return end
    
    table.sort(itemList, function(a, b)
        -- Use showAs (marketData.showAs) for cache lookup - this is what the server uses
        local idA = a.marketData.showAs or a.displayId or a.originalId
        local idB = b.marketData.showAs or b.displayId or b.originalId
        
        local expA = WeaponProficiency.cacheList[idA] and WeaponProficiency.cacheList[idA].exp or 0
        local expB = WeaponProficiency.cacheList[idB] and WeaponProficiency.cacheList[idB].exp or 0
        
        if expA == expB then
            local nameA = (a.marketData.name or ""):lower()
            local nameB = (b.marketData.name or ""):lower()
            return nameA < nameB
        end
        return expA > expB
    end)
end

-- Check if mastery is achieved for an item
function isMasteryAchieved(displayItem, cacheId, thingType)
    if not displayItem then
        return false
    end
    
    local itemId = cacheId or displayItem:getId()
    local weaponEntry = WeaponProficiency.cacheList[itemId]
    local currentExperience = weaponEntry and weaponEntry.exp or 0
    
    -- Get proficiency data
    local tt = thingType or (displayItem.getThingType and displayItem:getThingType())
    local proficiencyId = ProficiencyData:getProficiencyIdForItem(displayItem, tt)
    local perkCount = ProficiencyData:getPerkLaneCount(proficiencyId)
    local maxExperience = ProficiencyData:getMaxExperience(perkCount, displayItem, tt)
    
    return currentExperience >= maxExperience
end

-- Get unknown market category for item
function getUnknownMarketCategory(itemType)
    local weaponType = itemType.getWeaponType and itemType:getWeaponType() or 0
    return UnknownCategories[weaponType] or MarketCategory.WeaponsAll
end

-- Update selected proficiency display
function WeaponProficiency:onUpdateSelectedProficiency(itemId)
    if not self.displayItemPanel then 
        return 
    end
    
    -- Check if the itemId matches the currently selected item's originalId
    local selectedOriginalId = self.selectedMarketItem and self.selectedMarketItem.originalId
    if not selectedOriginalId or selectedOriginalId ~= itemId then
        return
    end
    
    -- Get display item from selected market item
    local displayItem = self.selectedMarketItem and self.selectedMarketItem.displayItem
    if not displayItem then 
        return 
    end
    
    local currentData = self.cacheList[itemId] or {exp = 0, perks = {}}
    self:updateExperienceProgress(currentData.exp, displayItem)
end

-- Update experience progress display
function WeaponProficiency:updateExperienceProgress(currentExp, displayItem)
    if not self.window then return end
    if not displayItem then return end
    
    local experienceWidget = self.window:recursiveGetChildById("progressDescription")
    local experienceLeftWidget = self.window:recursiveGetChildById("nextLevelDescription")
    local totalProgressWidget = self.window:recursiveGetChildById("proficiencyProgress")
    
    if not experienceWidget or not experienceLeftWidget then return end
    
    local thingType = self.selectedMarketItem and self.selectedMarketItem.thingType
    local marketData = self.selectedMarketItem and self.selectedMarketItem.marketData
    local proficiencyId = ProficiencyData:getProficiencyIdForItem(displayItem, thingType, marketData)
    local perkCount = ProficiencyData:getPerkLaneCount(proficiencyId)
    local currentCeilExperience = ProficiencyData:getCurrentCeilExperience(currentExp, displayItem, thingType)
    local maxExperience = ProficiencyData:getMaxExperience(perkCount, displayItem, thingType)
    local masteryAchieved = currentExp >= maxExperience
    
    
    experienceWidget:setText(string.format("%s / %s", comma_value(currentExp), comma_value(currentCeilExperience)))
    
    if masteryAchieved then
        experienceLeftWidget:setText("Mastery achieved")
    else
        experienceLeftWidget:setText(string.format("%s XP for next level", comma_value(currentCeilExperience - currentExp)))
    end
    
    if totalProgressWidget then
        totalProgressWidget:setPercent(ProficiencyData:getTotalPercent(currentExp, perkCount, displayItem, thingType))
    end
end

-- Helper function to format numbers with comma separators
function comma_value(n)
    if not n then return "0" end
    local left, num, right = string.match(tostring(n), '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

-- Toggle filter option (Level, Voc, 1H, 2H buttons)
function WeaponProficiency:toggleFilterOption(button)
    if not button then return end
    
    local buttonId = button:getId()
    self.filters[buttonId] = not self.filters[buttonId]
    
    -- Update button visual state
    if self.filters[buttonId] then
        button:setOn(true)
    else
        button:setOn(false)
    end
    
    -- Refresh item list with new filters
    self:refreshItemList()
end

-- Refresh item list based on current filters and category
function WeaponProficiency:refreshItemList()
    if not self.window then return end
    
    local itemList = self.window:recursiveGetChildById('itemList')
    if not itemList then return end
    
    -- Get current category from dropdown
    local categoryDropdown = self.window:recursiveGetChildById('classFilter')
    local currentCategory = MarketCategory.WeaponsAll
    
    if categoryDropdown then
        local selectedText = categoryDropdown:getText()
        currentCategory = WeaponStringToCategory[selectedText] or MarketCategory.WeaponsAll
    end
    
    -- Sort items by experience (highest first)
    sortWeaponProficiency(currentCategory)
    
    -- Get items for current category
    local items = self.itemList[currentCategory] or {}
    
    -- Apply filters
    items = self:applyLevelFilter(items)
    items = self:applyVocationFilter(items)
    
    -- Apply 1H/2H filters
    local oneActive = self.filters["oneButton"]
    local twoActive = self.filters["twoButton"]
    
    if oneActive and not twoActive then
        -- Only show one-handed weapons
        local filteredItems = {}
        for _, item in ipairs(items) do
            local thingType = item.thingType
            if thingType then
                local slotType = thingType.getClothSlot and thingType:getClothSlot() or 0
                if slotType ~= 2 then -- Not two-handed (slotType 2 is two-handed)
                    table.insert(filteredItems, item)
                end
            else
                table.insert(filteredItems, item)
            end
        end
        items = filteredItems
    elseif twoActive and not oneActive then
        -- Only show two-handed weapons
        local filteredItems = {}
        for _, item in ipairs(items) do
            local thingType = item.thingType
            if thingType then
                local slotType = thingType.getClothSlot and thingType:getClothSlot() or 0
                if slotType == 2 then -- Two-handed
                    table.insert(filteredItems, item)
                end
            end
        end
        items = filteredItems
    end
    -- If both active or neither, show all
    
    -- Apply search text filter
    if self.searchFilter and self.searchFilter ~= '' then
        local searchLower = string.lower(self.searchFilter)
        local filteredItems = {}
        for _, item in ipairs(items) do
            local itemName = item.marketData and item.marketData.name or ""
            if string.find(string.lower(itemName), searchLower, 1, true) then
                table.insert(filteredItems, item)
            end
        end
        items = filteredItems
    end
    
    -- Clear existing items
    local children = itemList:getChildren()
    for _, child in ipairs(children) do
        local itemWidget = child:getChildById('item')
        if itemWidget then
            itemWidget:setItemId(0)
        end
        -- Clear stars
        local starPanel = child:getChildById('starsBackground')
        if starPanel then
            starPanel:destroyChildren()
        end
        -- Remove old click callback
        child.onClick = nil
    end
    
    -- Populate items with click handlers
    local index = 1
    for _, marketItem in ipairs(items) do
        local child = itemList:getChildByIndex(index)
        if child then
            local itemWidget = child:getChildById('item')
            if itemWidget and marketItem.displayItem then
                -- Use stored displayId (guaranteed non-zero) instead of displayItem:getId()
                local displayId = marketItem.displayId or marketItem.originalId
                -- Use showAs (displayId) as cache key - this is what the server uses
                local cacheId = marketItem.marketData.showAs or displayId
                itemWidget:setItemId(displayId)
                
                -- Add tooltip with item name
                child:setTooltip(marketItem.marketData.name or "")
                
                -- Add stars based on proficiency level
                local starPanel = child:getChildById('starsBackground')
                if starPanel then
                    starPanel:destroyChildren()
                    
                    -- Get experience and calculate level
                    local cacheEntry = self.cacheList[cacheId]
                    local exp = cacheEntry and cacheEntry.exp or 0
                    local weaponLevel = ProficiencyData:getCurrentLevelByExp(marketItem.displayItem, exp, false, marketItem.thingType) or 0
                    
                    -- Create star widgets for each level achieved
                    if weaponLevel > 0 then
                        local mastery = isMasteryAchieved(marketItem.displayItem, cacheId, marketItem.thingType)
                        for i = 1, weaponLevel do
                            local star = g_ui.createWidget("MiniStar", starPanel)
                            if star then
                                if mastery then
                                    star:setImageSource("/images/game/proficiency/icon-star-tiny-gold")
                                end
                            end
                        end
                    end
                end
                
                -- Add click handler
                child.onClick = function()
                    WeaponProficiency:selectItem(displayId, marketItem)
                end
            end
            index = index + 1
        end
        
        if index > 45 then break end -- Max 45 items visible
    end
end

-- Handle category change from dropdown
function WeaponProficiency:onCategoryChange(dropdown)
    self:refreshItemList()
end

-- Select an item from the list
function WeaponProficiency:selectItem(itemId, marketItem)
    if not self.window then return end
    
    -- Use originalId for cache lookups (server uses this ID)
    local cacheId = marketItem.originalId or itemId
    
    self.selectedItemId = cacheId  -- Use cacheId for proficiency data lookup
    self.selectedDisplayId = itemId  -- Keep display ID for UI
    self.selectedMarketItem = marketItem
    
    
    -- Get the item panel
    local itemPanel = self.window:recursiveGetChildById('itemPanel')
    if not itemPanel then 
        return 
    end
    
    -- Update item display panel
    local itemNameLabel = itemPanel:getChildById('itemNameTitle')
    local itemIconWidget = itemPanel:recursiveGetChildById('item')
    local displayItem = marketItem.displayItem
    
    -- Ensure displayItem has a valid ID (fix for items where showAs was 0)
    local actualDisplayId = marketItem.displayId or marketItem.originalId
    if displayItem and displayItem:getId() == 0 and actualDisplayId > 0 then
        displayItem:setId(actualDisplayId)
    end
    
    
    if itemNameLabel and marketItem then
        itemNameLabel:setText(marketItem.marketData.name or "Unknown Item")
    end
    
    -- Set item using setItem method
    if itemIconWidget and displayItem then
        itemIconWidget:setItem(displayItem)
    end
    
    -- Destroy and recreate perk panels for fresh display
    if self.perkPanel then
        self.perkPanel:destroyChildren()
    end
    if self.bonusDetailPanel then
        self.bonusDetailPanel:destroyChildren()
    end
    if self.starProgressPanel then
        self.starProgressPanel:destroyChildren()
    end
    
    -- Use cacheId (originalId) for cache lookups since server sends proficiency data with originalId
    local cacheId = marketItem.originalId or itemId
    
    -- Initialize cache entry if not exists
    if not self.cacheList[cacheId] then
        self.cacheList[cacheId] = { exp = 0, perks = {} }
    end
    
    local currentData = self.cacheList[cacheId]
    
    -- Get proficiency ID using wrapper function, passing thingType and marketData for proper category lookup
    local thingType = marketItem.thingType
    local marketData = marketItem.marketData
    local proficiencyId = ProficiencyData:getProficiencyIdForItem(displayItem, thingType, marketData)
    local profEntry = ProficiencyData:getContentById(proficiencyId)
    
    
    if profEntry then
        -- Update experience display
        self:updateExperienceProgress(currentData.exp, displayItem)
        
        -- Create star widgets
        for i = 1, #profEntry.Levels do
            local starWidget = g_ui.createWidget('StarWidget', self.starProgressPanel)
            if starWidget then
                starWidget:setId('starWidget' .. i)
            end
        end
        
        -- Create perk column panels
        for i, levelData in ipairs(profEntry.Levels) do
            local perkColumn = g_ui.createWidget('BonusSelectPanel', self.perkPanel)
            if perkColumn then
                perkColumn:setId('perkColumn_' .. i)
                local progress = perkColumn:getChildById('bonusSelectProgress')
                if progress then
                    progress:setWidth(0)
                end
            end
            
            local bonusDetail = g_ui.createWidget('BonusDetailPanel', self.bonusDetailPanel)
            if bonusDetail then
                bonusDetail:setId('bonusDetail_' .. i)
            end
        end
        
        -- Load saved perks into pendingSelections for UI display
        self.pendingSelections = {}
        if currentData.perks and #currentData.perks > 0 then
            for i, perk in ipairs(currentData.perks) do
                if type(perk) == "table" and #perk >= 2 then
                    local level = perk[1]
                    local perkPos = perk[2]
                    self.pendingSelections[level] = perkPos
                end
            end
        end
        
        -- Display perks and update UI
        self:displayPerks(cacheId, currentData.perks, displayItem)
    else
        -- Fallback: show basic info without perks
        self:updateExperienceProgress(currentData.exp, displayItem)
    end
    
    -- Request proficiency info from server if needed - use cacheId (originalId)
    if g_game.sendWeaponProficiencyAction then
        g_game.sendWeaponProficiencyAction(0, cacheId)
    end
end

-- Display proficiency data for selected item
function WeaponProficiency:displayProficiencyData(itemId, experience, perks)
    if not self.window then return end
    if self.selectedItemId ~= itemId then return end
    
    local displayItem = self.selectedMarketItem and self.selectedMarketItem.displayItem
    local thingType = self.selectedMarketItem and self.selectedMarketItem.thingType
    if not displayItem then return end
    
    -- Update experience display
    self:updateExperienceProgress(experience, displayItem)
    
    -- Get proficiency content using wrapper function (with thingType and marketData)
    local marketData = self.selectedMarketItem and self.selectedMarketItem.marketData
    local proficiencyId = ProficiencyData:getProficiencyIdForItem(displayItem, thingType, marketData)
    local profEntry = ProficiencyData:getContentById(proficiencyId)
    
    if not profEntry then return end
    
    local levels = profEntry.Levels or {}
    local currentLevel = ProficiencyData:getCurrentLevelByExp(displayItem, experience, false, thingType)
    local maxExperience = ProficiencyData:getMaxExperience(#levels, displayItem, thingType)
    local masteryAchieved = experience >= maxExperience
    
    -- Update perk columns for each level
    for i, levelData in ipairs(levels) do
        local perkColumn = self.perkPanel:getChildById('perkColumn_' .. i)
        local starWidget = self.starProgressPanel:getChildById('starWidget' .. i)
        
        if perkColumn then
            self:updatePerkColumn(perkColumn, levelData, i, currentLevel, perks, experience, displayItem, masteryAchieved, thingType)
        end
        
        if starWidget then
            self:updateStarWidget(starWidget, i, currentLevel, experience, displayItem, masteryAchieved, thingType)
        end
    end
    
    -- Update bonus detail panels
    self:updateBonusDetails(profEntry, perks)
    
    -- Update item frame
    self:updateItemAddons(experience, displayItem, masteryAchieved, thingType)
end

-- Display perks in the perk panel
function WeaponProficiency:displayPerks(itemId, perks, displayItem)
    if not self.window or not self.perkPanel then 
        return 
    end
    
    if not displayItem then
        return
    end
    
    -- Get proficiency content using wrapper function (with thingType and marketData for proper category lookup)
    local thingType = self.selectedMarketItem and self.selectedMarketItem.thingType
    local marketData = self.selectedMarketItem and self.selectedMarketItem.marketData
    local proficiencyId = ProficiencyData:getProficiencyIdForItem(displayItem, thingType, marketData)
    local proficiencyContent = ProficiencyData:getContentById(proficiencyId)
    
    if not proficiencyContent then
        return
    end
    
    -- Use cacheId (originalId) for cache lookups
    local cacheId = self.selectedMarketItem and self.selectedMarketItem.originalId or itemId
    
    
    local levels = proficiencyContent.Levels or {}
    local experience = self.cacheList[cacheId] and self.cacheList[cacheId].exp or 0
    
    -- Calculate current level based on experience (starts at 0 if no experience)
    local currentLevel = ProficiencyData:getCurrentLevelByExp(displayItem, experience, false, thingType)
    
    -- Check if mastery is achieved
    local maxExperience = ProficiencyData:getMaxExperience(#levels, displayItem, thingType)
    local masteryAchieved = experience >= maxExperience
    
    -- Update perk columns for each level
    for i, levelData in ipairs(levels) do
        local perkColumn = self.perkPanel:getChildById('perkColumn_' .. i)
        local starWidget = self.starProgressPanel:getChildById('starWidget' .. i)
        
        if perkColumn and levelData then
            self:updatePerkColumn(perkColumn, levelData, i, currentLevel, perks, experience, displayItem, masteryAchieved, thingType)
        end
        
        -- Update star widget
        if starWidget then
            self:updateStarWidget(starWidget, i, currentLevel, experience, displayItem, masteryAchieved, thingType)
        end
    end
    
    -- Update bonus detail panels
    self:updateBonusDetails(proficiencyContent, perks)
    
    -- Update item frame/addons based on level
    self:updateItemAddons(experience, displayItem, masteryAchieved)
end


-- Update a single star widget - matching RTC implementation
function WeaponProficiency:updateStarWidget(starWidget, levelIndex, currentLevel, experience, displayItem, masteryAchieved, thingType)
    if not starWidget then return end
    
    local starProgress = starWidget:getChildById('starProgress')
    local starIcon = starWidget:getChildById('star')
    
    if starProgress then
        -- Calculate percent for this level (same as perk column)
        local percent = ProficiencyData:getLevelPercent(experience or 0, levelIndex, displayItem, thingType)
        starProgress:setPercent(percent)
        
        -- Set tooltip with experience info
        local maxLevelExp = ProficiencyData:getMaxExperienceByLevel(levelIndex, displayItem, thingType)
        starProgress:setTooltip(string.format("%s / %s", comma_value(experience or 0), comma_value(maxLevelExp or 0)))
    end
    
    -- Update star icon color based on completion (100% = complete)
    if starIcon then
        local percent = ProficiencyData:getLevelPercent(experience or 0, levelIndex, displayItem, thingType)
        if percent >= 100 then
            -- Level complete - show gold or silver star
            local iconType = masteryAchieved and "gold" or "silver"
            starIcon:setImageSource('/images/game/proficiency/icon-star-tiny-' .. iconType)
        else
            -- Level not complete - show dark star
            starIcon:setImageSource('/images/game/proficiency/icon-star-dark')
                    end
                end
end

-- Update item frame/addons based on weapon level
function WeaponProficiency:updateItemAddons(currentExp, displayItem, masteryAchieved, thingType)
    if not self.window then return end
    if not displayItem then return end
    
    local weaponLevel = math.min(7, ProficiencyData:getCurrentLevelByExp(displayItem, currentExp, false, thingType) or 0)
    local iconLevelWidget = self.window:recursiveGetChildById("iconMasteryLevel")
    local weaponLevelWidget = self.window:recursiveGetChildById("itemMasteryLevel")
    
    if iconLevelWidget then
        iconLevelWidget:setImageSource("/images/game/proficiency/icon-masterylevel-" .. weaponLevel)
    end
    
    if weaponLevelWidget then
        weaponLevelWidget:setVisible(weaponLevel > 0)
        if weaponLevel > 0 then
            local color = masteryAchieved and "gold" or "silver"
            weaponLevelWidget:setImageSource(string.format("/images/game/proficiency/icon-masterylevel-%d-%s", weaponLevel, color))
        end
    end
end

-- Update a single perk column
function WeaponProficiency:updatePerkColumn(perkColumn, levelData, levelIndex, currentLevel, selectedPerks, experience, displayItem, masteryAchieved, thingType)
    if not perkColumn or not levelData then return end
    
    local perksData = levelData.Perks or {}
    local perkCount = #perksData
    
    -- Show appropriate panel based on perk count
    local oneBonusPanel = perkColumn:getChildById('oneBonusIconPanel')
    local twoBonusPanel = perkColumn:getChildById('twoBonusIconPanel')
    local threeBonusPanel = perkColumn:getChildById('threeBonusIconPanel')
    
    if oneBonusPanel then oneBonusPanel:setVisible(perkCount == 1) end
    if twoBonusPanel then twoBonusPanel:setVisible(perkCount == 2) end
    if threeBonusPanel then threeBonusPanel:setVisible(perkCount == 3) end
    
    -- Determine which panel to use
    local activePanel = nil
    if perkCount == 1 and oneBonusPanel then
        activePanel = oneBonusPanel
    elseif perkCount == 2 and twoBonusPanel then
        activePanel = twoBonusPanel
    elseif perkCount == 3 and threeBonusPanel then
        activePanel = threeBonusPanel
    end
    
    if not activePanel then return end
    
    -- Store currentPerkPanel reference for later use
    perkColumn.currentPerkPanel = activePanel
    
    -- Level is unlocked if we have enough experience
    local isLevelUnlocked = levelIndex <= currentLevel
    
    -- Update progress bar for this column - use height for vertical fill effect
    local progressBar = perkColumn:getChildById('bonusSelectProgress')
    if progressBar then
        local percent = ProficiencyData:getLevelPercent(experience or 0, levelIndex, displayItem, thingType)
        
        -- Set progress bar width (horizontal fill from left to right)
        -- Max width is 106 (108 panel width - 2 margin)
        local maxWidth = 106
        local fillWidth = math.floor((percent / 100) * maxWidth)
        progressBar:setWidth(fillWidth)
        
        -- Unlock perks if this level is complete (100%)
        if percent >= 100 then
            for _, widget in pairs(activePanel:getChildren()) do
                if widget.blocked then
                    widget.blocked = false
                end
            end
        end
    end
    
    -- Update each perk icon
    for perkIndex, perkData in ipairs(perksData) do
        local bonusIcon = activePanel:getChildById('bonusIcon' .. (perkIndex - 1))
        if bonusIcon then
            -- Get image source and clip
            local imagePath, imageClip = ProficiencyData:getImageSourceAndClip(perkData)
            local iconWidget = bonusIcon:getChildById('icon')
            local iconGreyWidget = bonusIcon:getChildById('icon-grey')
            local lockedWidget = bonusIcon:getChildById('locked-perk')
            local borderWidget = bonusIcon:getChildById('border')
            local highlightWidget = bonusIcon:getChildById('highlight')
            
            -- Check if this perk is selected
            local isSelected = false
            if selectedPerks and type(selectedPerks) == "table" then
                -- Format 1: Array format from server/cache: {{level, perkPos}, ...} (1-indexed)
                if #selectedPerks > 0 and type(selectedPerks[1]) == "table" then
                for _, perk in ipairs(selectedPerks) do
                        if type(perk) == "table" and #perk >= 2 and perk[1] == levelIndex and perk[2] == perkIndex then
                        isSelected = true
                        break
                    end
                    end
                -- Format 2: Indexed format from pendingSelections: {[levelIndex] = perkIndex} (1-indexed)
                elseif selectedPerks[levelIndex] ~= nil then
                    isSelected = (selectedPerks[levelIndex] == perkIndex)
                end
            end
            
            -- Set icon images
            local clipX, clipY = imageClip:match("(%d+)%s+(%d+)")
            clipX = tonumber(clipX) or 0
            clipY = tonumber(clipY) or 0
            
            if iconWidget then
                iconWidget:setImageSource(imagePath)
                iconWidget:setImageClip({x = clipX, y = clipY, width = 64, height = 64})
            end
            
            -- Handle grey icon - spell augments use separate -off image, others use Y+64 offset
            if iconGreyWidget then
                if perkData.Type == PERK_SPELL_AUGMENT then
                    -- Spell augments have a separate -off image source
                    iconGreyWidget:setImageSource(imagePath .. "-off")
                    iconGreyWidget:setImageClip({x = clipX, y = clipY, width = 64, height = 64})
                else
                    -- Other perks use Y+64 for grey version
                iconGreyWidget:setImageSource(imagePath)
                    iconGreyWidget:setImageClip({x = clipX, y = clipY + 64, width = 64, height = 64})
                end
            end
            
            -- Handle augment overlay icons for spell augments
            local iconPerks = bonusIcon:getChildById('iconPerks')
            local iconPerksGrey = bonusIcon:getChildById('iconPerks-grey')
            if perkData.Type == PERK_SPELL_AUGMENT and perkData.AugmentType then
                local augmentClip = ProficiencyData:getAugmentIconClip(perkData)
                local augX = tonumber(augmentClip:match("(%d+)")) or 0
                if iconPerks then
                    iconPerks:setVisible(true)
                    iconPerks:setImageClip({x = augX, y = 0, width = 32, height = 32})
                end
                if iconPerksGrey then
                    iconPerksGrey:setVisible(true)
                    iconPerksGrey:setImageClip({x = augX, y = 32, width = 32, height = 32})
                end
            else
                if iconPerks then iconPerks:setVisible(false) end
                if iconPerksGrey then iconPerksGrey:setVisible(false) end
            end
            
            -- Show/hide based on unlock state and selection
            local showColorIcon = isLevelUnlocked and isSelected
            local showGreyIcon = not isLevelUnlocked or (isLevelUnlocked and not isSelected)
            
            if iconWidget then
                iconWidget:setVisible(showColorIcon)
            end
            
            if iconGreyWidget then
                iconGreyWidget:setVisible(showGreyIcon)
                iconGreyWidget:setOpacity(1.0)
            end
            
            -- Handle augment overlay icons visibility for spell augments
            local iconPerks = bonusIcon:getChildById('iconPerks')
            local iconPerksGrey = bonusIcon:getChildById('iconPerks-grey')
            if perkData.Type == PERK_SPELL_AUGMENT then
                if iconPerks then
                    iconPerks:setVisible(showColorIcon)
                end
                if iconPerksGrey then
                    iconPerksGrey:setVisible(showGreyIcon)
                    iconPerksGrey:setOpacity(1.0)
                end
            end
            
            -- Show locked icon if level not reached
            if lockedWidget then
                lockedWidget:setVisible(not isLevelUnlocked)
            end
            
            -- Update border based on state
            if borderWidget then
                if isSelected and isLevelUnlocked then
                    borderWidget:setImageSource('/images/game/proficiency/border-weaponmasterytreeicons-active')
                else
                    borderWidget:setImageSource('/images/game/proficiency/border-weaponmasterytreeicons-inactive')
                end
            end
            
            -- Highlight selected perk
            if highlightWidget then
                highlightWidget:setVisible(isSelected and isLevelUnlocked)
            end
            
            -- Set tooltip
            local bonusName, bonusTooltip = ProficiencyData:getBonusNameAndTooltip(perkData)
            bonusIcon:setTooltip(string.format("%s\n\n%s", bonusName, bonusTooltip))
            
            -- Store perk data for later use
            bonusIcon.perkData = perkData
            bonusIcon.blocked = not isLevelUnlocked
            bonusIcon.locked = false
            bonusIcon.active = isSelected
            bonusIcon.levelIndex = levelIndex
            bonusIcon.perkIndex = perkIndex
            
            -- Add click handler for selecting perk
            bonusIcon.onClick = function(widget)
                if widget.blocked then
                    return
                end
                WeaponProficiency:onPerkClick(widget)
            end
        end
    end
end

-- Handle perk icon click
function WeaponProficiency:onPerkClick(bonusIcon)
    if not bonusIcon then return end
    
    local levelIndex = bonusIcon.levelIndex
    local perkIndex = bonusIcon.perkIndex
    
    
    -- Initialize pending selections if not exists
    if not self.pendingSelections then
        self.pendingSelections = {}
    end
    
    -- Get currently saved perk for this level from cache
    local savedPerk = nil
    if self.selectedItemId and self.cacheList[self.selectedItemId] then
        local cachedPerks = self.cacheList[self.selectedItemId].perks or {}
        for _, perk in ipairs(cachedPerks) do
            if type(perk) == "table" and perk[1] == levelIndex then
                savedPerk = perk[2]
                break
            end
        end
    end
    
    -- Determine if this click changes from saved state
    local currentSelection = self.pendingSelections[levelIndex] or savedPerk
    
    if currentSelection == perkIndex then
        -- Clicking on already selected perk - check if we should deselect or revert to saved
        if savedPerk == perkIndex then
            -- This is the saved perk, clicking it again does nothing (can't deselect saved perks)
        else
            -- This was a pending selection, deselect it (revert to saved or none)
            self.pendingSelections[levelIndex] = nil
        end
    else
        -- Selecting a different perk for this level
        if perkIndex == savedPerk then
            -- Reverting to saved perk - remove from pending
            self.pendingSelections[levelIndex] = nil
        else
            -- New selection different from saved
            self.pendingSelections[levelIndex] = perkIndex
        end
    end
    
    -- Update visual state for all perks in this level column
    self:updatePerkVisualState(levelIndex)
    
    -- Update button states
    self:updateApplyButtonState()
end

-- Update visual state for perks in a level column
function WeaponProficiency:updatePerkVisualState(levelIndex)
    local perkColumn = self.perkPanel:getChildById('perkColumn_' .. levelIndex)
    if not perkColumn or not perkColumn.currentPerkPanel then return end
    
    -- Get pending selection first, then fall back to cached perk
    local selectedPerkIndex = self.pendingSelections and self.pendingSelections[levelIndex]
    
    -- If no pending selection, check cached perks
    if not selectedPerkIndex and self.selectedItemId and self.cacheList[self.selectedItemId] then
        local cachedPerks = self.cacheList[self.selectedItemId].perks or {}
        for _, perk in ipairs(cachedPerks) do
            if type(perk) == "table" and perk[1] == levelIndex then
                selectedPerkIndex = perk[2]
                break
            end
        end
    end
    
    -- Update each perk icon in this column
    for perkIdx = 0, 2 do
        local bonusIcon = perkColumn.currentPerkPanel:getChildById('bonusIcon' .. perkIdx)
        if bonusIcon then
            local isSelected = (selectedPerkIndex == (perkIdx + 1))
            local isLevelUnlocked = not bonusIcon.blocked
            
            local iconWidget = bonusIcon:getChildById('icon')
            local iconGreyWidget = bonusIcon:getChildById('icon-grey')
            local borderWidget = bonusIcon:getChildById('border')
            local highlightWidget = bonusIcon:getChildById('highlight')
            
            -- Show color icon only if unlocked AND selected
            if iconWidget then
                iconWidget:setVisible(isLevelUnlocked and isSelected)
            end
            
            if iconGreyWidget then
                iconGreyWidget:setVisible(not isSelected or not isLevelUnlocked)
            end
            
            -- Update border
            if borderWidget then
                if isSelected and isLevelUnlocked then
                    borderWidget:setImageSource('/images/game/proficiency/border-weaponmasterytreeicons-active')
                else
                    borderWidget:setImageSource('/images/game/proficiency/border-weaponmasterytreeicons-inactive')
        end
    end
            
            -- Highlight selected
            if highlightWidget then
                highlightWidget:setVisible(isSelected and isLevelUnlocked)
            end
            
            bonusIcon.active = isSelected
        end
    end
    
    -- Update bonus detail panel
    self:updateBonusDetailForLevel(levelIndex)
end

-- Update bonus detail panel for a specific level
function WeaponProficiency:updateBonusDetailForLevel(levelIndex)
    local bonusDetailPanel = self.window:recursiveGetChildById('bonusDetailBackground')
    if not bonusDetailPanel then return end
    
    local detailPanel = bonusDetailPanel:getChildById('bonusDetail_' .. levelIndex)
    if not detailPanel then return end
    
    local bonusNameWidget = detailPanel:getChildById('bonusName')
    if not bonusNameWidget then return end
    
    local selectedPerkIndex = self.pendingSelections and self.pendingSelections[levelIndex]
    
    if selectedPerkIndex then
        -- Get perk data from the perk column
        local perkColumn = self.perkPanel:getChildById('perkColumn_' .. levelIndex)
        if perkColumn and perkColumn.currentPerkPanel then
            local bonusIcon = perkColumn.currentPerkPanel:getChildById('bonusIcon' .. (selectedPerkIndex - 1))
            if bonusIcon and bonusIcon.perkData then
                local bonusName, tooltip = ProficiencyData:getBonusNameAndTooltip(bonusIcon.perkData)
                bonusNameWidget:setText(tooltip)
                bonusNameWidget:setTooltip(tooltip)
                bonusNameWidget:setImageSource("")
                return
            end
        end
    end
    
    -- No selection - show lock icon
    bonusNameWidget:setText("")
    bonusNameWidget:setImageSource("/images/game/proficiency/icon-lock-grey")
end

-- Update bonus detail panels at the bottom
function WeaponProficiency:updateBonusDetails(proficiencyContent, selectedPerks)
    local bonusDetailPanel = self.window:recursiveGetChildById('bonusDetailBackground')
    if not bonusDetailPanel then return end
    
    local levels = proficiencyContent.Levels or {}
    
    for i = 1, #levels do
        local detailPanel = bonusDetailPanel:getChildById('bonusDetail_' .. i)
        if detailPanel then
            local bonusNameWidget = detailPanel:getChildById('bonusName')
            local levelData = levels[i]
            
            if bonusNameWidget and levelData then
                -- Find selected perk for this level
                local selectedPerkIndex = nil
                if selectedPerks and type(selectedPerks) == "table" then
                    -- Check array format first: {{level, perkPos}, ...} (from cache/server)
                    local isArrayFormat = false
                    if #selectedPerks > 0 and type(selectedPerks[1]) == "table" then
                        isArrayFormat = true
                    for _, perk in ipairs(selectedPerks) do
                            if type(perk) == "table" and #perk >= 2 and perk[1] == i then
                                selectedPerkIndex = perk[2] -- Already 1-indexed from cache
                            break
                            end
                        end
                    end
                    
                    -- Check indexed format: {[levelIndex] = perkIndex} (from pendingSelections)
                    if not isArrayFormat and not selectedPerkIndex then
                        local key = i -- pendingSelections uses 1-indexed level
                        if selectedPerks[key] ~= nil then
                            local value = selectedPerks[key]
                            if type(value) == "number" then
                                selectedPerkIndex = value -- Already 1-indexed from pendingSelections
                            end
                        end
                    end
                end
                
                if selectedPerkIndex then
                    local perksData = levelData.Perks or {}
                    local perkData = perksData[selectedPerkIndex]
                    if perkData then
                        local bonusName, tooltip = ProficiencyData:getBonusNameAndTooltip(perkData)
                        bonusNameWidget:setText(tooltip)
                        bonusNameWidget:setTooltip(tooltip)
                        bonusNameWidget:setImageSource("") -- Hide lock icon
                    else
                        bonusNameWidget:setText("")
                        bonusNameWidget:setImageSource("/images/game/proficiency/icon-lock-grey")
                    end
                else
                    bonusNameWidget:setText("")
                    bonusNameWidget:setImageSource("/images/game/proficiency/icon-lock-grey")
                end
            elseif bonusNameWidget then
                bonusNameWidget:setText("")
                bonusNameWidget:setImageSource("/images/game/proficiency/icon-lock-grey")
            end
        end
    end
end

-- Handle item box click in the list
function WeaponProficiency:onItemBoxClick(widget)
    if not widget then return end
    
    local itemWidget = widget:getChildById('item')
    if not itemWidget then return end
    
    local itemId = itemWidget:getItemId()
    if not itemId or itemId == 0 then return end
    
    -- Find the market item data
    local categoryDropdown = self.window:recursiveGetChildById('classFilter')
    local currentCategory = MarketCategory.WeaponsAll
    
    if categoryDropdown then
        local selectedText = categoryDropdown:getText()
        currentCategory = WeaponStringToCategory[selectedText] or MarketCategory.WeaponsAll
    end
    
    local items = self.itemList[currentCategory] or {}
    local marketItem = nil
    
    for _, item in ipairs(items) do
        if item.displayItem and item.displayItem:getId() == itemId then
            marketItem = item
            break
        end
    end
    
    if marketItem then
        self:selectItem(itemId, marketItem)
    end
end

-- Apply filter for Level button
function WeaponProficiency:applyLevelFilter(items)
    if not self.filters["levelButton"] then return items end
    
    local player = g_game.getLocalPlayer()
    if not player then return items end
    
    local playerLevel = player:getLevel()
    local filteredItems = {}
    
    for _, item in ipairs(items) do
        local requiredLevel = item.marketData.requiredLevel or 0
        if playerLevel >= requiredLevel then
            table.insert(filteredItems, item)
        end
    end
    
    return filteredItems
end

-- Apply filter for Vocation button
function WeaponProficiency:applyVocationFilter(items)
    if not self.filters["vocButton"] then return items end
    
    local player = g_game.getLocalPlayer()
    if not player then return items end
    
    local playerVocation = player:getVocation()
    local filteredItems = {}
    
    for _, item in ipairs(items) do
        local restrictVocation = item.marketData.restrictVocation or 0
        -- If no restriction (0), show item - any vocation can use it
        if restrictVocation == 0 then
            table.insert(filteredItems, item)
        else
            -- Check if player's vocation bit is set in the restriction mask
            -- restrictVocation is a bitmask: bit N is set if vocation N can use the item
            -- playerVocation is 1-based (1=Knight, 2=Paladin, etc.)
            -- The bitmask uses 2^(vocation-1) for each vocation
            local vocBit = math.pow(2, playerVocation - 1)
            if bit32 then
                -- Use bit32 library if available
                if bit32.band(restrictVocation, vocBit) ~= 0 then
            table.insert(filteredItems, item)
        end
            else
                -- Fallback: use modulo arithmetic for bitwise AND
                local shifted = math.floor(restrictVocation / vocBit)
                if shifted % 2 == 1 then
                    table.insert(filteredItems, item)
                end
            end
        end
    end
    
    return filteredItems
end

-- Apply filter for 1H (one-handed) weapons
function WeaponProficiency:applyOneHandedFilter(items)
    if not self.filters["oneButton"] then return items end
    
    local filteredItems = {}
    for _, item in ipairs(items) do
        local thingType = item.thingType
        if thingType then
            -- Check if weapon is one-handed (not two-handed slot)
            local slotType = thingType.getClothSlot and thingType:getClothSlot() or 0
            if slotType ~= 2 then -- Not two-handed
                table.insert(filteredItems, item)
            end
        else
            table.insert(filteredItems, item)
        end
    end
    return filteredItems
end

-- Apply filter for 2H (two-handed) weapons
function WeaponProficiency:applyTwoHandedFilter(items)
    if not self.filters["twoButton"] then return items end
    
    local filteredItems = {}
    for _, item in ipairs(items) do
        local thingType = item.thingType
        if thingType then
            local slotType = thingType.getClothSlot and thingType:getClothSlot() or 0
            if slotType == 2 then -- Two-handed
                table.insert(filteredItems, item)
            end
        end
    end
    return filteredItems
end

-- Apply button click handler
function WeaponProficiency:onApplyClick()
    local success, err = pcall(function()
        self:applyPendingSelections()
    end)
    if not success then
        -- Clear pending selections on error to allow closing
        self.pendingSelections = {}
        self:updateApplyButtonState()
    end
end

-- Ok button click handler
function WeaponProficiency:onOkClick()
    -- Apply pending selections if any
    if self.pendingSelections and next(self.pendingSelections) ~= nil then
        local success, err = pcall(function()
            self:applyPendingSelections()
        end)
        if not success then
            -- Clear on error to allow closing
            self.pendingSelections = {}
        end
    end
    -- Always close window, even if there was an error
    hide()
end

-- Reset button click handler
function WeaponProficiency:onResetClick()
    self.pendingSelections = {}
    
    -- Send empty perks list to server to clear all perks
    -- This is more reliable than using action type 2 (reset)
    if g_game.sendWeaponProficiencyApply and self.selectedItemId then
        -- Send empty arrays to clear all perks
        g_game.sendWeaponProficiencyApply(self.selectedItemId, {}, {})
    end
    
    -- Clear local cache and refresh display
    if self.selectedItemId and self.selectedMarketItem then
        local displayItem = self.selectedMarketItem.displayItem
        local cacheData = self.cacheList[self.selectedItemId]
        if displayItem and cacheData then
            -- Clear cached perks since we reset them
            cacheData.perks = {}
            self:displayPerks(self.selectedItemId, cacheData.perks, displayItem)
        end
    end
    
    self:updateApplyButtonState()
end

-- Apply pending perk selections to server
function WeaponProficiency:applyPendingSelections()
    if not self.selectedItemId then
        return
    end
    
    -- Build complete perk selection list for server
    -- Start with cached perks (already saved on server)
    local allPerks = {} -- {[levelIndex] = perkIndex} in 1-indexed format
    
    -- First, load existing cached perks
    if self.cacheList[self.selectedItemId] and self.cacheList[self.selectedItemId].perks then
        for _, perk in ipairs(self.cacheList[self.selectedItemId].perks) do
            if type(perk) == "table" and #perk >= 2 then
                allPerks[perk[1]] = perk[2]  -- level -> perkIndex (1-indexed)
            end
        end
    end
    
    -- Then, merge with pending selections (these override cached perks)
    if self.pendingSelections then
        for levelIndex, perkIndex in pairs(self.pendingSelections) do
            allPerks[levelIndex] = perkIndex  -- level -> perkIndex (1-indexed)
        end
    end
    
    -- Convert to array format for sending: {level (0-indexed), perkPosition (0-indexed)}
    local selections = {}
    for levelIndex, perkIndex in pairs(allPerks) do
        table.insert(selections, {levelIndex - 1, perkIndex - 1})
    end
    
    -- Sort by level for consistency
    table.sort(selections, function(a, b) return a[1] < b[1] end)
    
    if #selections == 0 then
        return
    end
    
    
    -- Build two parallel arrays for C++ (levels and perkPositions)
    local levels = {}
    local perkPositions = {}
    
    -- Log selection details (0-indexed in Lua, will be converted to 1-indexed in C++)
    for i, sel in ipairs(selections) do
        table.insert(levels, sel[1])
        table.insert(perkPositions, sel[2])
    end
    
    -- Send to server using the protocol function with two parallel arrays
    -- g_game.sendWeaponProficiencyApply(itemId, levelsArray, perkPositionsArray)
    if g_game.sendWeaponProficiencyApply then
        g_game.sendWeaponProficiencyApply(self.selectedItemId, levels, perkPositions)
        
        -- Update cache with ALL applied perks (convert back to server format: 1-indexed)
        -- This includes both cached perks and new pending selections
        if self.cacheList[self.selectedItemId] then
            local appliedPerks = {}
            for _, sel in ipairs(selections) do
                table.insert(appliedPerks, {sel[1] + 1, sel[2] + 1}) -- Convert back to 1-indexed for cache
            end
            self.cacheList[self.selectedItemId].perks = appliedPerks
            
            -- Clear pendingSelections - perks are now saved in cache, no longer "pending"
            self.pendingSelections = {}
            
            -- Update UI immediately with applied perks (using cache format)
            -- This keeps the visual selection active
            if self.selectedMarketItem and self.selectedMarketItem.displayItem then
                self:displayPerks(self.selectedItemId, appliedPerks, self.selectedMarketItem.displayItem)
            end
        end
        
        -- Update button states (Apply should be disabled since we just applied)
        self:updateApplyButtonState()
        
        -- Clear the hasUnusedPerk flag and hide highlight after applying
        -- The user has now used their perks, so no notification needed
        self.hasUnusedPerk = false
        updateProficiencyHighlight()
        
        -- Request updated proficiency info from server to confirm
        scheduleEvent(function()
            if g_game.sendWeaponProficiencyAction and self.selectedItemId then
                g_game.sendWeaponProficiencyAction(0, self.selectedItemId)
            end
        end, 200)
    end
    
    -- Pending selections already cleared above
end

-- Update Apply/Ok/Reset button enabled state based on pending selections
function WeaponProficiency:updateApplyButtonState()
    if not self.window then return end
    
    local applyBtn = self.window:getChildById('apply')
    local okBtn = self.window:getChildById('ok')
    local resetBtn = self.window:getChildById('reset')
    
    local hasPendingSelections = self.pendingSelections and next(self.pendingSelections) ~= nil
    
    -- Check if there are applied perks in cache
    local hasAppliedPerks = false
    if self.selectedItemId and self.cacheList[self.selectedItemId] then
        local cachedPerks = self.cacheList[self.selectedItemId].perks
        hasAppliedPerks = cachedPerks and #cachedPerks > 0
    end
    
    -- Apply/Ok: enabled when there are pending selections (changes to apply)
    if applyBtn then
        applyBtn:setEnabled(hasPendingSelections)
    end
    if okBtn then
        okBtn:setEnabled(true) -- Always enabled to allow closing
    end
    
    -- Reset: enabled when there are applied perks
    if resetBtn then
        resetBtn:setEnabled(hasAppliedPerks)
    end
end

