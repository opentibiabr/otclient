-- Global variables
local binaryTree = {}
local battleButtons = {}
local battleWindow, battleButton, battlePanel, mouseWidget, filterPanel, toggleFilterButton
local lastBattleButtonSwitched, lastCreatureSelected
local hideButtons = {}
local eventOnCheckCreature = nil
local eventsConnected = false

-- Forward declarations
local onBattleButtonHoverChange, onBattleButtonMouseRelease
BattleListInstance = nil
BattleButtonPool = nil

-- Utility functions
function tableCopy(t)
    if type(t) ~= "table" then return t end
    local meta = getmetatable(t)
    local target = {}
    for k, v in pairs(t) do
        target[k] = type(v) == "table" and tableCopy(v) or v
    end
    setmetatable(target, meta)
    return target
end

-- Default filter settings
local BATTLE_FILTERS = {
    ["sortAscByDisplayTime"] = true,
    ["sortDescByDisplayTime"] = false,
    ["sortAscByDistance"] = false,
    ["sortDescByDistance"] = false,
    ["sortAscByHitPoints"] = false,
    ["sortDescByHitPoints"] = false,
    ["sortAscByName"] = false,
    ["sortDescByName"] = false
}

-- Battle List Manager
local BattleListManager = {
    instances = {},
    nextId = 1,
    autoSaveEvent = nil,
    isRestoring = false
}

function BattleListManager:saveInstancesState()
    local instancesData = {}
    for id, instance in pairs(self.instances) do
        if id ~= 0 then
            local windowPos = instance.window and instance.window:getPosition()
            local windowSize = instance.window and instance.window:getSize()
            local isLocked = false
            local isMinimized = false
            if instance.window then
                isLocked = instance.window:getSettings('locked') or false
                local lockButton = instance.window:getChildById('lockButton')
                if lockButton then
                    isLocked = lockButton:isOn()
                end
                -- Check if window is minimized (visible but collapsed)
                if instance.window:isVisible() then
                    isMinimized = instance.window:isOn()
                end
            end
            instancesData[id] = {
                id = instance.id,
                name = instance:getName(),
                isOpen = instance.window and instance.window:isVisible(),
                isMinimized = isMinimized,
                windowPos = windowPos,
                windowSize = windowSize,
                isHidingFilters = instance:isHidingFilters(),
                isLocked = isLocked
            }
            instance:saveFilters()
            instance:saveHideButtonStates()
            instance:saveLockState()
        end
    end
    
    local mainInstance = self.instances[0]
    if mainInstance then
        mainInstance:saveLockState()
        mainInstance:saveFilters()
        mainInstance:saveHideButtonStates()
    end
    
    g_settings.mergeNode('BattleListInstances', instancesData)
end

function BattleListManager:restoreInstancesState()
    local instancesData = g_settings.getNode('BattleListInstances')
    if not instancesData then return end
    
    local hasExistingInstances = false
    for id, instance in pairs(self.instances) do
        if id ~= 0 then
            hasExistingInstances = true
            break
        end
    end
    
    if hasExistingInstances then
        g_settings.mergeNode('BattleListInstances', {})
        return
    end
    
    self.isRestoring = true
    for id, data in pairs(instancesData) do
        if tonumber(id) and tonumber(id) > 0 then
            if data.isOpen then
                local oldSettingsKey = 'BattleList_' .. id
                local oldSettings = g_settings.getNode(oldSettingsKey)
                local shouldRestoreSettings = oldSettings ~= nil
                
                local customName = data.name and data.name ~= tr('Battle List') and data.name or nil
                local instance = self:createNewInstance(customName)
                
                if instance and instance.window then
                    if shouldRestoreSettings and oldSettings then
                        local newSettingsKey = instance:getSettingsKey()
                        local settingsToRestore = tableCopy(oldSettings)
                        settingsToRestore.customName = data.name
                        
                        g_settings.mergeNode(newSettingsKey, settingsToRestore)
                        
                        instance.name = data.name
                        instance:updateTitle()
                        
                        scheduleEvent(function()
                            instance:loadHideButtonStates()
                            instance:loadFilters()
                            instance:loadLockState()
                        end, 50)
                    end
                    
                    if data.windowPos then
                        instance.window:setPosition(data.windowPos)
                    end
                    if data.windowSize then
                        instance.window:setSize(data.windowSize)
                    end
                    
                    if data.isLocked then
                        instance.window:lock(true)
                    else
                        instance.window:unlock(true)
                    end
                    
                    -- Restore minimized state if window was minimized
                    if data.isMinimized then
                        scheduleEvent(function()
                            instance.window:minimize(true)
                        end, 150)
                    end
                    
                    scheduleEvent(function()
                        if not instance.filterPanel.originalHeight then
                            instance.filterPanel.originalHeight = instance.filterPanel:getHeight()
                        end
                        
                        if data.isHidingFilters then
                            instance:hideFilterPanel()
                        else
                            instance:showFilterPanel()
                        end
                    end, 200)
                    
                    g_settings.set(oldSettingsKey, nil)
                end
            else
                local oldSettingsKey = 'BattleList_' .. id
                g_settings.set(oldSettingsKey, nil)
            end
        end
    end
    
    local allSettings = g_settings.getNode() or {}
    for key, _ in pairs(allSettings) do
        if type(key) == 'string' and key:match('^BattleList_%d+$') then
            local instanceId = tonumber(key:match('%d+'))
            if instanceId and instanceId > 0 then
                g_settings.set(key, nil)
            end
        end
    end
    
    g_settings.mergeNode('BattleListInstances', {})
    self.isRestoring = false
end

function BattleListManager:getMainInstance()
    return self.instances[0]
end

function BattleListManager:createNewInstance(customName)
    local instance = BattleListInstance:new(self.nextId, customName)
    self.instances[self.nextId] = instance
    self.nextId = self.nextId + 1
    self:createWindowForInstance(instance)
    return instance
end

function BattleListManager:createWindowForInstance(instance)
    local newWindow = g_ui.loadUI('battle')
    instance.window = newWindow
    newWindow:setId('battleWindow_' .. instance.id)

    -- Define resize restriction function
    local function restrictResize()
        local originalOnResize = newWindow.onResize
        newWindow.onResize = function(...)
            if originalOnResize then
                originalOnResize(...)
            end
            
            local minHeight = 80
            if not instance:isHidingFilters() then
                minHeight = minHeight + 60
            end
            if newWindow:getHeight() < minHeight then
                newWindow:setHeight(minHeight)
            end
        end
    end

    -- Change icon for battle list instances (not the main battle list)
    if instance.id ~= 0 then
        local miniwindowIcon = newWindow:recursiveGetChildById('miniwindowIcon')
        if miniwindowIcon then
            miniwindowIcon:setImageSource('/images/game/battle/icon-battlelist-secondary-widget')
        end
    end
    
    instance.panel = newWindow:recursiveGetChildById('battlePanel')
    instance.filterPanel = newWindow:recursiveGetChildById('filterPanel')
    instance.toggleFilterButton = newWindow:recursiveGetChildById('toggleFilterButton')
    
    -- Setup scrollbar for this instance - use default MiniWindow behavior
    local scrollbar = newWindow:getChildById('miniwindowScrollBar')
    if scrollbar then
        scrollbar:mergeStyle({ ['$!on'] = {} })
    end
    
    if not instance.toggleFilterButton then
        g_logger.info("Battle: toggleFilterButton not found in battle instance " .. instance.id .. " UI")
    end
    
    instance:updateTitle()
    
    local hideButtons = {}
    local options = { 'hidePlayers', 'hideNPCs', 'hideMonsters', 'hideSkulls', 'hideParty', 'hideKnights', 'hidePaladins', 'hideDruids', 'hideSorcerers', 'hideMonks', 'hideSummons', 'hideMembersOwnGuild' }
    for i, v in ipairs(options) do
        hideButtons[v] = newWindow:recursiveGetChildById(v)
        if hideButtons[v] then
            hideButtons[v].onClick = function(button)
                instance:onFilterButtonClick(button)
            end
        end
    end
    instance.hideButtons = hideButtons
    
    instance:loadHideButtonStates()
    
    local contextMenuButton = newWindow:recursiveGetChildById('contextMenuButton')
    if contextMenuButton then
        contextMenuButton.onClick = function(widget, mousePos, mouseButton)
            return instance:showContextMenu(widget, mousePos, mouseButton)
        end
    end
    
    local newWindowButton = newWindow:recursiveGetChildById('newWindowButton')
    if newWindowButton then
        newWindowButton.onClick = function()
            BattleListManager:createNewInstance()
        end
    end
    
    if instance.toggleFilterButton then
        instance.toggleFilterButton.onClick = function()
            instance:toggleFilterPanel()
            restrictResize()
            
            local minHeight = 80
            if not instance:isHidingFilters() then
                minHeight = minHeight + 60
            end
            if newWindow:getHeight() < minHeight then
                newWindow:setHeight(minHeight)
            end
        end
    end
    
    newWindow.onOpen = function()
        instance:onOpen()
    end
    
    newWindow.onClose = function()
        instance:onClose()
        if instance.id ~= 0 then
            instance:destroy(false)
        end
    end
    
    newWindow.onGeometryChange = function()
        if instance.id ~= 0 and not BattleListManager.isRestoring then
            BattleListManager:saveInstancesState()
        end
    end
    
    local lockButton = newWindow:getChildById('lockButton')
    if lockButton then
        local originalOnClick = lockButton.onClick
        lockButton.onClick = function()
            if originalOnClick then
                originalOnClick()
            end
            if not BattleListManager.isRestoring then
                scheduleEvent(function()
                    instance:saveLockState()
                    if instance.id ~= 0 then
                        BattleListManager:saveInstancesState()
                    end
                end, 10)
            end
        end
    end
    
    newWindow.onMousePress = function(widget, mousePos, button)
        if button == MouseRightButton then
            local menu = g_ui.createWidget('PopupMenu')
            menu:addOption('Edit Name', function() instance:openEditNameDialog() end)
            menu:addOption('Create New Battle List', function() BattleListManager:createNewInstance() end)
            if instance.id ~= 0 then
                menu:addOption('Clear Configurations', function() instance:clearAllConfigurations() end)
                menu:addOption('Close Battle List', function() instance:destroy(false) end)
            end
            menu:display(mousePos)
            return true
        end
        return false
    end
    
    newWindow:setContentMinimumHeight(80)

    restrictResize()
    
    local originalOnMinimize = newWindow.onMinimize
    local originalOnMaximize = newWindow.onMaximize
    
    newWindow.onMinimize = function(...)
        if originalOnMinimize then originalOnMinimize(...) end
        newWindow.onResize = nil
    end
    
    newWindow.onMaximize = function(...)
        if originalOnMaximize then originalOnMaximize(...) end
        restrictResize()
    end
    
    newWindow:setup()
    
    local panel = modules.game_interface.findContentPanelAvailable(newWindow, newWindow:getMinimumHeight())
    if panel then
        panel:addChild(newWindow)
        newWindow:open()
    end
    
    -- Set initial scrollbar position for new instances (filters visible by default)
    local scrollbar = newWindow:getChildById('miniwindowScrollBar')
    if scrollbar then
        -- Header (16px) + filterPanel height (46px) + spacing panel (18px) + separator (2px)
        scrollbar:setMarginTop(82) -- 16 + 46 + 18 + 2 = 82
    end
    
    if g_game.isOnline() then
        instance:checkCreatures()
    end
end

function BattleListManager:getMainInstance()
    return self.instances[0]
end

function BattleListManager:getInstance(id)
    return self.instances[id]
end

function BattleListManager:getAllInstances()
    return self.instances
end

function BattleListManager:destroyInstance(id)
    local instance = self.instances[id]
    if instance then
        instance:destroy(false)
        self:removeSavedInstanceState(id)
    end
end

function BattleListManager:removeSavedInstanceState(id)
    local instancesData = g_settings.getNode('BattleListInstances') or {}
    if instancesData[tostring(id)] then
        instancesData[tostring(id)] = nil
        g_settings.mergeNode('BattleListInstances', instancesData)
    end
end

function BattleListManager:startPeriodicSave()
    self:stopPeriodicSave()
    self.autoSaveEvent = scheduleEvent(function()
        if g_game.isOnline() and not self.isRestoring then
            self:saveInstancesState()
            self:startPeriodicSave()
        end
    end, 30000)
end

function BattleListManager:stopPeriodicSave()
    if self.autoSaveEvent then
        removeEvent(self.autoSaveEvent)
        self.autoSaveEvent = nil
    end
end

-- Battle List Instance Class
BattleListInstance = {
    id = nil,
    window = nil,
    panel = nil,
    filterPanel = nil,
    toggleFilterButton = nil,
    binaryTree = {},
    battleButtons = {},
    lastBattleButtonSwitched = nil,
    settings = {},
    name = "Battle List"
}

function BattleListInstance:new(id, customName)
    local instance = {}
    setmetatable(instance, {__index = self})
    
    instance.id = id or BattleListManager.nextId
    instance.binaryTree = {}
    instance.battleButtons = {}
    instance.lastBattleButtonSwitched = nil
    instance.lastAge = 0
    instance.name = customName or tr('Battle List')
    instance.settings = {
        filters = tableCopy(BATTLE_FILTERS),
        sortType = 'name',
        sortOrder = 'A',
        hidingFilters = false,
        customName = instance.name
    }
    
    return instance
end

function BattleListInstance:getSettingsKey()
    return 'BattleList_' .. self.id
end

function BattleListInstance:loadFilters()
    local settings = g_settings.getNode(self:getSettingsKey())
    if not settings or not settings['filters'] then
        return tableCopy(BATTLE_FILTERS)
    end
    return settings['filters']
end

function BattleListInstance:saveFilters()
    local currentFilters = self:loadFilters()
    g_settings.mergeNode(self:getSettingsKey(), { ['filters'] = currentFilters })
end

function BattleListInstance:saveHideButtonStates()
    if not self.hideButtons then return end
    
    local hideButtonStates = {}
    for buttonName, button in pairs(self.hideButtons) do
        if button then
            hideButtonStates[buttonName] = button:isChecked()
        end
    end
    g_settings.mergeNode(self:getSettingsKey(), { ['hideButtons'] = hideButtonStates })
end

function BattleListInstance:saveLockState()
    if self.window then
        local isLocked = self.window:getSettings('locked') or false
        local lockButton = self.window:getChildById('lockButton')
        if lockButton then
            isLocked = lockButton:isOn()
        end
        g_settings.mergeNode(self:getSettingsKey(), { ['isLocked'] = isLocked })
    end
end

function BattleListInstance:loadLockState()
    if not self.window then
        return false
    end
    
    local settings = g_settings.getNode(self:getSettingsKey())
    if settings and settings['isLocked'] ~= nil then
        local isLocked = settings['isLocked']
        local lockButton = self.window:getChildById('lockButton')
        if isLocked then
            self.window:lock(true)
            if lockButton then
                lockButton:setOn(true)
            end
        else
            self.window:unlock(true)
            if lockButton then
                lockButton:setOn(false)
            end
        end
        return isLocked
    end
    return false
end
function BattleListInstance:loadHideButtonStates()
    if not self.hideButtons then return end
    
    local settings = g_settings.getNode(self:getSettingsKey())
    if settings and settings['hideButtons'] then
        for buttonName, isChecked in pairs(settings['hideButtons']) do
            local button = self.hideButtons[buttonName]
            if button then
                button:setChecked(isChecked)
            end
        end
    end
end

function BattleListInstance:getFilter(filter)
    local filters = self:loadFilters()
    local value = filters[filter]
    if value ~= nil then
        return value
    end
    return BATTLE_FILTERS[filter] or false
end

function BattleListInstance:setFilter(filter)
    local filters = self:loadFilters()
    local value = filters[filter]
    
    if value == nil then
        value = BATTLE_FILTERS[filter]
        if value == nil then
            return false
        end
    end
    
    if filter:find("sortAscBy") or filter:find("sortDescBy") then
        for filterName, _ in pairs(BATTLE_FILTERS) do
            if filterName ~= filter and (filterName:find("sortAscBy") or filterName:find("sortDescBy")) then
                filters[filterName] = false
            end
        end
    end
    
    filters[filter] = not value
    g_settings.mergeNode(self:getSettingsKey(), { ['filters'] = filters })
    
    scheduleEvent(function()
        self:checkCreatures()
    end, 50)
    
    return true
end

function BattleListInstance:getSortType()
    local filters = self:loadFilters()
    
    for filterName, isActive in pairs(filters) do
        if isActive and (filterName:find("sortAscBy") or filterName:find("sortDescBy")) then
            if filterName:find("DisplayTime") then
                return 'age'
            elseif filterName:find("Distance") then
                return 'distance'
            elseif filterName:find("HitPoints") then
                return 'health'
            elseif filterName:find("Name") then
                return 'name'
            end
        end
    end
    
    return 'name'
end

function BattleListInstance:setSortType(state, oldSortType)
    g_settings.mergeNode(self:getSettingsKey(), { ['sortType'] = state })
    local order = self:getSortOrder()
    self:reSort(oldSortType, state, order, order)
end

function BattleListInstance:getSortOrder()
    local filters = self:loadFilters()
    
    for filterName, isActive in pairs(filters) do
        if isActive and (filterName:find("sortAscBy") or filterName:find("sortDescBy")) then
            return filterName:find("sortAscBy") and 'A' or 'D'
        end
    end
    
    return 'A'
end

function BattleListInstance:setSortOrder(state, oldSortOrder)
    g_settings.mergeNode(self:getSettingsKey(), { ['sortOrder'] = state })
    self:reSort(false, false, oldSortOrder, state)
end

function BattleListInstance:isSortAsc()
    return self:getSortOrder() == 'A'
end

function BattleListInstance:isSortDesc()
    return self:getSortOrder() == 'D'
end

function BattleListInstance:getName()
    local settings = g_settings.getNode(self:getSettingsKey())
    if settings and settings['customName'] then
        return settings['customName']
    end
    return tr('Battle List')
end

function BattleListInstance:setName(name)
    local settings = g_settings.getNode(self:getSettingsKey()) or {}
    settings['customName'] = (name == nil or name == '') and tr('Battle List') or name
    g_settings.mergeNode(self:getSettingsKey(), settings)
    self:updateTitle()
    
    if self.id ~= 0 and not BattleListManager.isRestoring then
        BattleListManager:saveInstancesState()
    end
end

function BattleListInstance:updateTitle()
    if self.window then
        local titleLabel = self.window:recursiveGetChildById('miniwindowTitle')
        if titleLabel then
            local title = self:getName()
            -- Limit title to 11 characters, replace last 3 with "..." if longer
            if string.len(title) > 11 then
                title = string.sub(title, 1, 8) .. "..."
            end
            titleLabel:setText(title)
        end
    end
end

function BattleListInstance:clearAllConfigurations()
    local settingsKey = self:getSettingsKey()
    local settings = g_settings.getNode(settingsKey)
    if settings then
        g_settings.mergeNode(settingsKey, {
            filters = nil,
            sortType = nil,
            sortOrder = nil,
            hidingFilters = nil,
            customName = nil,
            hideButtons = nil,
            isLocked = nil
        })
    end
    
    self.settings = {
        filters = tableCopy(BATTLE_FILTERS),
        sortType = 'name',
        sortOrder = 'A',
        hidingFilters = false,
        customName = tr('Battle List')
    }
    
    if self.hideButtons then
        for _, button in pairs(self.hideButtons) do
            if button then
                button:setChecked(false)
            end
        end
    end
    
    self:updateTitle()
    
    if self.filterPanel and not self.filterPanel:isVisible() then
        self:showFilterPanel()
    end
    
    if self.window then
        self.window:unlock()
    end
    
    self:checkCreatures()
end

function BattleListInstance:destroy(saveSettings)
    if not saveSettings then
        local settingsKey = self:getSettingsKey()
        local settings = g_settings.getNode(settingsKey)
        if settings then
            g_settings.mergeNode(settingsKey, {
                filters = nil,
                sortType = nil,
                sortOrder = nil,
                hidingFilters = nil,
                customName = nil,
                hideButtons = nil,
                isLocked = nil
            })
        end
        
        if self.id ~= 0 then
            BattleListManager:removeSavedInstanceState(self.id)
        end
    else
        self:saveFilters()
        self:saveHideButtonStates()
        self:saveLockState()
    end
    
    for i, v in pairs(self.battleButtons) do
        BattleButtonPool:release(v)
    end
    
    self.binaryTree = {}
    self.battleButtons = {}
    self.settings = nil
    self.lastBattleButtonSwitched = nil
    
    if self.window and self.id ~= 0 then
        self.window:destroy()
        self.window = nil
    end
    
    self.panel = nil
    self.filterPanel = nil
    self.toggleFilterButton = nil
    self.hideButtons = nil
    
    BattleListManager.instances[self.id] = nil
end

-- Instance-specific methods
function BattleListInstance:onFilterButtonClick(button)
    button:setChecked(not button:isChecked())
    self:saveHideButtonStates()
    self:checkCreatures()
end

function BattleListInstance:showContextMenu(widget, mousePos, mouseButton)
    local menu = g_ui.createWidget('BattleListSubMenu')
    menu:setGameMenu(true)
    for _, choice in ipairs(menu:getChildren()) do
        local choiceId = choice:getId()
        if choiceId and choiceId ~= 'HorizontalSeparator' then
            if choiceId == 'editBattleListName' or choiceId == 'openNewBattleList' then
                choice.onClick = function()
                    self:onMenuAction(choiceId)
                    menu:destroy()
                end
            else
                local filterValue = self:getFilter(choiceId)
                choice:setChecked(filterValue)
                choice.onCheckChange = function()
                    self:onMenuAction(choiceId)
                    menu:destroy()
                end
            end
        end
    end
    
    local buttonPos = widget:getPosition()
    local buttonSize = widget:getSize()
    local menuWidth = menu:getWidth()
    
    local buttonCenterX = buttonPos.x + buttonSize.width / 2
    local buttonCenterY = buttonPos.y + buttonSize.height / 2
    
    local menuX = buttonCenterX - menuWidth
    local menuY = buttonCenterY
    
    menu:display({x = menuX, y = menuY})
    return true
end

function BattleListInstance:onMenuAction(actionId)
    if actionId == 'editBattleListName' then
        self:openEditNameDialog()
    elseif actionId == 'openNewBattleList' then
        BattleListManager:createNewInstance()
    else
        self:setFilter(actionId)
    end
end

function BattleListInstance:openEditNameDialog()
    local currentName = self:getName()
    if currentName == tr('Battle List') then
        currentName = ""
    end
    
    local changeListNameWindow = g_ui.displayUI('style/changeListName')
    changeListNameWindow:show()
    
    local nameInput = changeListNameWindow:getChildById('newBattleListName')
    nameInput:setText(currentName)
    nameInput:focus()
    nameInput:selectAll()
    
    local function closeWindow()
        nameInput:setText('')
        changeListNameWindow:setVisible(false)
        changeListNameWindow:destroy()
    end
    
    changeListNameWindow.buttonOk.onClick = function()
        local newName = nameInput:getText()
        self:setName(newName)
        closeWindow()
    end
    
    changeListNameWindow.closeButton.onClick = closeWindow
    changeListNameWindow.onEscape = closeWindow
    
    nameInput.onKeyDown = function(widget, keyCode, keyboardModifiers)
        if keyCode == KeyReturn or keyCode == KeyEnter then
            changeListNameWindow.buttonOk.onClick()
            return true
        elseif keyCode == KeyEscape then
            closeWindow()
            return true
        end
        return false
    end
end

function BattleListInstance:toggleFilterPanel()
    if self.filterPanel:isVisible() then
        self:hideFilterPanel()
    else
        self:showFilterPanel()
    end
end

function BattleListInstance:hideFilterPanel()
    self.filterPanel.originalHeight = self.filterPanel:getHeight()
    self.filterPanel:setHeight(0)
    if self.toggleFilterButton then
        self.toggleFilterButton:getParent():setMarginTop(0)
        self.toggleFilterButton:setOn(false)
    end
    self:setHidingFilters(true)
    local HorizontalSeparator = self.window:recursiveGetChildById('HorizontalSeparator')
    if HorizontalSeparator then HorizontalSeparator:setVisible(false) end
    self.filterPanel:setVisible(false)
    local contentsPanel = self.window:recursiveGetChildById('contentsPanel')
    -- Reduce margin by the full filter panel space: 46px (filter) + 18px (spacing) + 2px (separator) + 6px (margin) = 72px
    if contentsPanel then contentsPanel:setMarginTop(-23) end
    
    -- Adjust scrollbar to start at header bottom when filter is hidden
    local scrollbar = self.window:getChildById('miniwindowScrollBar')
    if scrollbar then
        scrollbar:setMarginTop(16) -- Default header height
    end
    
    -- Update resize restrictions
    if self.window.onResize then
        local function restrictResize()
            self.window.onResize = function()
                local minHeight = 80 -- Base minimum height
                if not self:isHidingFilters() then
                    minHeight = minHeight + 60 -- Add extra height for visible filters
                end
                if self.window:getHeight() < minHeight then
                    self.window:setHeight(minHeight)
                end
            end
        end
        restrictResize()
    end
end

function BattleListInstance:showFilterPanel()
    if self.toggleFilterButton then
        self.toggleFilterButton:getParent():setMarginTop()
        self.toggleFilterButton:setOn(true)
    end
    -- Ensure originalHeight is set, fallback to a default height
    if not self.filterPanel.originalHeight then
        self.filterPanel.originalHeight = 40  -- Default filter panel height
    end
    self.filterPanel:setHeight(self.filterPanel.originalHeight)
    self:setHidingFilters(false)
    local HorizontalSeparator = self.window:recursiveGetChildById('HorizontalSeparator')
    if HorizontalSeparator then HorizontalSeparator:setVisible(true) end
    self.filterPanel:setVisible(true)
    local contentsPanel = self.window:recursiveGetChildById('contentsPanel')
    if contentsPanel then contentsPanel:setMarginTop(0) end
    
    -- Adjust scrollbar to start at filter panel bottom when filter is visible
    local scrollbar = self.window:getChildById('miniwindowScrollBar')
    if scrollbar then
        -- Header (16px) + filterPanel height + spacing panel (18px) + separator (2px)
        local totalMargin = 16 + self.filterPanel.originalHeight + 18 + 2
        scrollbar:setMarginTop(totalMargin)
    end
    
    -- Update resize restrictions
    if self.window.onResize then
        local function restrictResize()
            self.window.onResize = function()
                local minHeight = 80 -- Base minimum height
                if not self:isHidingFilters() then
                    minHeight = minHeight + 60 -- Add extra height for visible filters
                end
                if self.window:getHeight() < minHeight then
                    self.window:setHeight(minHeight)
                end
            end
        end
        restrictResize()
    end
end

function BattleListInstance:setHidingFilters(state)
    local settings = {}
    settings['hidingFilters'] = state
    g_settings.mergeNode(self:getSettingsKey(), settings)
end

function BattleListInstance:isHidingFilters()
    local settings = g_settings.getNode(self:getSettingsKey())
    if not settings then
        return false
    end
    return settings['hidingFilters']
end

function BattleListInstance:onOpen()
    -- Ensure events are connected when opening any battle list instance
    if g_game.isOnline() then
        connecting()
    end
    
    -- Ensure default filters are applied for new instances
    local filters = self:loadFilters()
    local hasAnySortFilter = false
    
    -- Check if any sort filter is already active
    for filterName, isActive in pairs(filters) do
        if isActive and (filterName:find("sortAscBy") or filterName:find("sortDescBy")) then
            hasAnySortFilter = true
            break
        end
    end
    
    -- If no sort filter is active, apply the default
    if not hasAnySortFilter then
        filters["sortAscByDisplayTime"] = true
        g_settings.mergeNode(self:getSettingsKey(), { ['filters'] = filters })
        scheduleEvent(function()
            self:checkCreatures()
        end, 100)
    end
end

function BattleListInstance:onClose()
    -- Don't clear instance configurations when window is closed during normal operation
    -- Only clear when explicitly requested through clearAllConfigurations()
    
    -- Check if we need to disconnect global events when this instance closes
    scheduleEvent(function()
        -- Check if main battle list is closed and no other instances are open
        local mainInstance = BattleListManager.instances[0]
        local isMainClosed = not mainInstance or not mainInstance.window or not mainInstance.window:isVisible()
        
        if isMainClosed then
            local hasOpenInstances = false
            for id, instance in pairs(BattleListManager.instances) do
                if id ~= 0 and instance.window and instance.window:isVisible() then
                    hasOpenInstances = true
                    break
                end
            end
            
            if not hasOpenInstances then
                disconnecting()
            end
        end
    end, 10) -- Small delay to ensure window state is updated
end

function BattleListInstance:checkCreatures()
    if not self.panel or not g_game.isOnline() then
        return false
    end
    
    self.panel:disableUpdateTemporarily()
    
    local player = g_game.getLocalPlayer()
    if not player then
        return false
    end
    
    local position = player:getPosition()
    if not position then
        return false
    end
    
    self:removeAllCreatures()
    
    local spectators = modules.game_interface.getMapPanel():getSpectators()
    local sortType = self:getSortType()
    local sortOrder = self:getSortOrder()
    
    for _, creature in ipairs(spectators) do
        if self:doCreatureFitFilters(creature) then
            self:addCreature(creature, sortType)
        end
    end
end

function BattleListInstance:doCreatureFitFilters(creature)
    if creature:isLocalPlayer() then
        return false
    end
    
    if creature:isDead() then
        return false
    end
    
    local pos = creature:getPosition()
    if not pos then
        return false
    end
    
    local localPlayer = g_game.getLocalPlayer()
    if not localPlayer then
        return false
    end
    
    local position = localPlayer:getPosition()
    if not position then
        return false
    end
    
    if pos.z ~= localPlayer:getPosition().z or not creature:canBeSeen() then
        return false
    end
    
    for i, v in pairs(self.hideButtons or {}) do
        if v:isChecked() then
            if (i == 'hidePlayers' and creature:isPlayer()) or 
               (i == 'hideNPCs' and creature:isNpc()) or
               (i == 'hideMonsters' and creature:isMonster()) or
               (i == 'hideSkulls' and (creature:isPlayer() and creature:getSkull() == SkullNone)) or
               (i == 'hideParty' and creature:isPlayer() and (function()
                   local shield = creature:getShield()
                   return shield and (shield == ShieldYellow or 
                                    shield == ShieldYellowSharedExp or 
                                    shield == ShieldYellowNoSharedExp or 
                                    shield == ShieldBlue or 
                                    shield == ShieldBlueNoSharedExpBlink or 
                                    shield == ShieldBlueSharedExp or 
                                    shield == ShieldYellowNoSharedExpBlink)
               end)()) or
               (i == 'hideKnights' and creature:isPlayer() and creature:isKnight()) or
               (i == 'hidePaladins' and creature:isPlayer() and creature:isPaladin()) or
               (i == 'hideDruids' and creature:isPlayer() and creature:isDruid()) or
               (i == 'hideSorcerers' and creature:isPlayer() and creature:isSorcerer()) or
               (i == 'hideMonks' and creature:isPlayer() and creature:isMonk()) or
               (i == 'hideSummons' and creature:isMonster() and (function()
                   local masterId = creature:getMasterId()
                   return masterId and masterId > 0
               end)()) or
               (i == 'hideMembersOwnGuild' and creature:isPlayer() and creature:getEmblem() == localPlayer:getEmblem() and creature:getEmblem() ~= EmblemNone) then
                return false
            end
        end
    end
    
    return true
end

local lastAge = 0
function BattleListInstance:addCreature(creature, sortType)
    local creatureId = creature:getId()
    local battleButton = self.battleButtons[creatureId]
    if battleButton then
        -- Safety check: don't update if creature is nil
        if battleButton.creature then
            battleButton:update()
        end
    else
        if creature:getPosition() == nil then
            return
        end
        
        local newCreature = {}
        newCreature.id = creatureId
        newCreature.name = creature:getName():lower()
        newCreature.healthpercent = creature:getHealthPercent()
        newCreature.distance = getDistanceBetween(g_game.getLocalPlayer():getPosition(), creature:getPosition())
        newCreature.age = self.lastAge + 1
        self.lastAge = self.lastAge + 1
        
        local newIndex = binaryInsert(self.binaryTree, newCreature, BSComparatorSortType, sortType, true)
        
        battleButton = BattleButtonPool:get()
        battleButton:setup(creature, true)
        
        battleButton.data = {}
        for i, v in pairs(newCreature) do
            battleButton.data[i] = v
        end
        
        self.battleButtons[creatureId] = battleButton
        
        if creature == g_game.getAttackingCreature() then
            battleButton.isTarget = true
            if battleButton.creature then
                battleButton:update()
            end
        end
        
        if creature == g_game.getFollowingCreature() then
            battleButton.isFollowed = true
            if battleButton.creature then
                battleButton:update()
            end
        end
        
        if self:isSortAsc() then
            self.panel:insertChild(newIndex, battleButton)
        else
            self.panel:insertChild((#self.binaryTree - newIndex + 1), battleButton)
        end
    end
    
    battleButton:setVisible(canBeSeen(creature))
    self.panel:getLayout():update()
end

function BattleListInstance:removeAllCreatures()
    self:removeCreature(false, true)
end

function BattleListInstance:removeCreature(creature, all)
    if all then
        self.binaryTree = {}
        self.lastBattleButtonSwitched = nil
        for i, v in pairs(self.battleButtons) do
            BattleButtonPool:release(v)
        end
        self.battleButtons = {}
        return true
    end
    
    local creatureId = creature:getId()
    local battleButton = self.battleButtons[creatureId]
    
    if battleButton then
        if self.lastBattleButtonSwitched == battleButton then
            self.lastBattleButtonSwitched = nil
        end
        
        local sortType = self:getSortType()
        local valuetoSearch = self:getAttributeByOrderType(battleButton, sortType)
        assert(valuetoSearch, 'Could not find information (data) in sent battleButton')
        valuetoSearch.id = creatureId
        
        local index = binarySearch(self.binaryTree, valuetoSearch, BSComparatorSortType, sortType, creatureId)
        if index ~= nil and creatureId == self.binaryTree[index].id then
            local creatureListSize = #self.binaryTree
            if index < creatureListSize then
                for i = index, creatureListSize - 1 do
                    -- Swap elements in instance binary tree
                    local tmp = self.binaryTree[i]
                    self.binaryTree[i] = self.binaryTree[i + 1]
                    self.binaryTree[i + 1] = tmp
                end
            end
            self.binaryTree[creatureListSize] = nil
            BattleButtonPool:release(battleButton)
            self.battleButtons[creatureId] = nil
            return true
        end
    end
    return false
end

function BattleListInstance:getAttributeByOrderType(battleButton, orderType)
    if battleButton.data then
        local battleButton = battleButton.data
        if orderType == 'distance' then
            return {
                distance = battleButton.distance
            }
        elseif orderType == 'health' then
            return {
                healthpercent = battleButton.healthpercent
            }
        elseif orderType == 'age' then
            return {
                age = battleButton.age
            }
        else
            return {
                name = battleButton.name
            }
        end
    end
    return false
end

function BattleListInstance:correctBattleButtons(sortOrder)
    self.panel:disableUpdateTemporarily()
    
    local sortOrder = sortOrder or self:getSortOrder()
    
    local start = sortOrder == 'A' and 1 or #self.binaryTree
    local finish = #self.binaryTree - start + 1
    local increment = start <= finish and 1 or -1
    
    local index = 1
    for i = start, finish, increment do
        local v = self.binaryTree[i]
        if v ~= nil and v.id ~= nil then
            local battleButton = self.battleButtons[v.id]
            if battleButton ~= nil then
                self.panel:moveChildToIndex(battleButton, index)
                index = index + 1
            end
        end
    end
    return true
end

function BattleListInstance:reSort(oldSortType, newSortType, oldSortOrder, newSortOrder)
    if #self.binaryTree > 1 then
        if newSortType and newSortType ~= oldSortType then
            self:checkCreatures()
        end
        
        if newSortOrder then
            self:correctBattleButtons(newSortOrder)
        end
    end
    
    return true
end

function BattleListInstance:swap(index, newIndex) -- Swap indexes of a given table
    local highest = newIndex
    local lowest = index

    if index > newIndex then
        highest = index
        lowest = newIndex
    end

    local tmp = self.binaryTree[lowest]
    self.binaryTree[lowest] = self.binaryTree[highest]
    self.binaryTree[highest] = tmp
end

-- Global legacy functions for backward compatibility
function loadFilters()
    local settings = g_settings.getNode("BattleList")
    if not settings or not settings['filters'] then
        return BATTLE_FILTERS
    end
    return settings['filters']
end

function saveFilters()
    g_settings.mergeNode('BattleList', { ['filters'] = loadFilters() })
end

function getBattleListName()
    local settings = g_settings.getNode('BattleList')
    if settings and settings['customName'] then
        return settings['customName']
    end
    return tr('Battle List')
end

function setBattleListName(name)
    local settings = g_settings.getNode('BattleList') or {}
    settings['customName'] = (name == nil or name == '') and tr('Battle List') or name
    g_settings.mergeNode('BattleList', settings)
    updateBattleListTitle()
end

function updateBattleListTitle()
    if battleWindow then
        local titleLabel = battleWindow:recursiveGetChildById('miniwindowTitle')
        if titleLabel then
            local title = getBattleListName()
            -- Limit title to 11 characters, replace last 3 with "..." if longer
            if string.len(title) > 11 then
                title = string.sub(title, 1, 8) .. "..."
            end
            titleLabel:setText(title)
        end
    end
end

function getFilter(filter)
    local mainInstance = BattleListManager:getMainInstance()
    if mainInstance then
        return mainInstance:getFilter(filter)
    end
    local filters = loadFilters()
    return filters[filter] ~= nil and filters[filter] or (BATTLE_FILTERS[filter] or false)
end

function setFilter(filter)
    local filters = loadFilters()
    local value = filters[filter]
    
    if value == nil then
        value = BATTLE_FILTERS[filter]
        if value == nil then
            return false
        end
    end
    
    if filter:find("sortAscBy") or filter:find("sortDescBy") then
        for filterName, _ in pairs(BATTLE_FILTERS) do
            if filterName ~= filter and (filterName:find("sortAscBy") or filterName:find("sortDescBy")) then
                filters[filterName] = false
            end
        end
    end
    
    filters[filter] = not value
    g_settings.mergeNode('BattleList', { ['filters'] = filters })
    
    return true
end

-- Game event handlers
function connecting()
    if eventsConnected then
        return true
    end
    
    connect(LocalPlayer, { onPositionChange = onCreaturePositionChange })
    connect(Creature, {
        onSkullChange = updateCreatureSkull,
        onEmblemChange = updateCreatureEmblem,
        onOutfitChange = onCreatureOutfitChange,
        onHealthPercentChange = onCreatureHealthPercentChange,
        onPositionChange = onCreaturePositionChange,
        onAppear = onCreatureAppear,
        onDisappear = onCreatureDisappear
    })
    connect(UIMap, { onZoomChange = onZoomChange })
    
    eventsConnected = true
    
    for _, instance in pairs(BattleListManager.instances) do
        instance:checkCreatures()
    end
    return true
end

function disconnecting(gameEvent)
    if not eventsConnected then
        return true
    end
    
    disconnect(LocalPlayer, { onPositionChange = onCreaturePositionChange })
    disconnect(Creature, {
        onSkullChange = updateCreatureSkull,
        onEmblemChange = updateCreatureEmblem,
        onOutfitChange = onCreatureOutfitChange,
        onHealthPercentChange = onCreatureHealthPercentChange,
        onPositionChange = onCreaturePositionChange,
        onAppear = onCreatureAppear,
        onDisappear = onCreatureDisappear
    })
    disconnect(UIMap, { onZoomChange = onZoomChange })
    
    eventsConnected = false
    return true
end

function init()
    -- Initialize Battle Button Pool
    if not ObjectPool then
        BattleButtonPool = {
            get = function()
                local widget = g_ui.createWidget('BattleButton')
                widget:show()
                widget:setOn(true)
                widget.onHoverChange = onBattleButtonHoverChange
                widget.onMouseRelease = onBattleButtonMouseRelease
                widget.onMousePress = function(self, mousePos, mouseButton)
                    return mouseButton == MouseRightButton
                end
                return widget
            end,
            release = function(obj)
                if obj and obj:getParent() then
                    obj:getParent():removeChild(obj)
                end
            end
        }
    else
        BattleButtonPool = ObjectPool.new(
            function()
                local widget = g_ui.createWidget('BattleButton')
                widget:show()
                widget:setOn(true)
                widget.onHoverChange = onBattleButtonHoverChange
                widget.onMouseRelease = onBattleButtonMouseRelease
                widget.onMousePress = function(self, mousePos, mouseButton)
                    return mouseButton == MouseRightButton
                end
                return widget
            end,
            function(obj)
                if obj.data then obj.data = nil end
            
                if lastBattleButtonSwitched == obj then
                    lastBattleButtonSwitched = nil
                end
                if lastCreatureSelected and obj.creature == lastCreatureSelected then
                    lastCreatureSelected = nil
                end

                obj:resetState()
                
                local parent = obj:getParent()
                if parent then
                    parent:removeChild(obj)
                end
            end)
    end
    
    g_ui.importStyle('battlebutton')
    battleButton = modules.game_mainpanel.addToggleButton('battleButton', tr('Battle') .. ' (Ctrl+B)',
        '/images/options/button_battlelist', toggle, false, 2)
    battleButton:setOn(true)
    battleWindow = g_ui.loadUI('battle')

    -- Initialize main instance
    BattleListManager.nextId = 1
    local mainInstance = BattleListInstance:new(0, tr('Battle List'))
    mainInstance.window = battleWindow
    mainInstance.panel = battleWindow:recursiveGetChildById('battlePanel')
    mainInstance.filterPanel = battleWindow:recursiveGetChildById('filterPanel')
    mainInstance.toggleFilterButton = battleWindow:recursiveGetChildById('toggleFilterButton')
    
    if not mainInstance.toggleFilterButton then
        g_logger.info("Battle: toggleFilterButton not found in battle window UI")
    end
    
    BattleListManager.instances[0] = mainInstance
    
    -- Store references for backward compatibility
    battlePanel = mainInstance.panel
    filterPanel = mainInstance.filterPanel
    toggleFilterButton = mainInstance.toggleFilterButton

    -- Setup keybind
    Keybind.new("Windows", "Show/hide battle list", "Ctrl+B", "")
    Keybind.bind("Windows", "Show/hide battle list", {{ type = KEY_DOWN, callback = toggle }})

    -- Setup scrollbar - use default MiniWindow behavior
    local scrollbar = battleWindow:getChildById('miniwindowScrollBar')
    if scrollbar then
        scrollbar:mergeStyle({ ['$!on'] = {} })
    end

    HorizontalSeparator = battleWindow:recursiveGetChildById('HorizontalSeparator')
    contentsPanel = battleWindow:recursiveGetChildById('contentsPanel')
    miniwindowScrollBar = battleWindow:getChildById('miniwindowScrollBar')

    -- Setup filter panel
    local settings = g_settings.getNode(mainInstance:getSettingsKey())
    if settings and settings['hidingFilters'] then
        mainInstance:hideFilterPanel()
    else
        -- Set initial scrollbar position when filters are visible
        local scrollbar = battleWindow:getChildById('miniwindowScrollBar')
        if scrollbar then
            -- Header (16px) + filterPanel height (46px) + spacing panel (18px) + separator (2px) + margin (6px)
            scrollbar:setMarginTop(88) -- 16 + 46 + 18 + 2 + 6 = 88
        end
    end

    -- Setup filter buttons
    local options = { 'hidePlayers', 'hideNPCs', 'hideMonsters', 'hideSkulls', 'hideParty', 'hideKnights', 'hidePaladins', 'hideDruids', 'hideSorcerers', 'hideMonks', 'hideSummons', 'hideMembersOwnGuild' }
    for i, v in ipairs(options) do
        hideButtons[v] = battleWindow:recursiveGetChildById(v)
    end
    
    mainInstance.hideButtons = hideButtons
    mainInstance:loadHideButtonStates()
    mainInstance:loadLockState()
    
    -- Setup lock button
    local mainLockButton = battleWindow:getChildById('lockButton')
    if mainLockButton then
        local originalOnClick = mainLockButton.onClick
        mainLockButton.onClick = function()
            if originalOnClick then originalOnClick() end
            scheduleEvent(function() mainInstance:saveLockState() end, 10)
        end
    end

    -- Setup mouse widget
    mouseWidget = g_ui.createWidget('UIButton')
    mouseWidget:setVisible(false)
    mouseWidget:setFocusable(false)
    mouseWidget.cancelNextRelease = false

    connect(g_game, {
        onAttackingCreatureChange = onAttack,
        onFollowingCreatureChange = onFollow,
        onGameEnd = onGameEnd,
        onGameStart = onGameStart
    })

    -- Setup context menu
    local contextMenuButton = battleWindow:recursiveGetChildById('contextMenuButton')
    if contextMenuButton then
        contextMenuButton.onClick = function(widget, mousePos, mouseButton)
            return mainInstance:showContextMenu(widget, mousePos, mouseButton)
        end
    end
    
    local newWindowButton = battleWindow:recursiveGetChildById('newWindowButton')
    if newWindowButton then
        newWindowButton.onClick = function()
            BattleListManager:createNewInstance()
        end
    end
    
    battleWindow:setContentMinimumHeight(80)
    
    -- Define resize restriction function
    local function restrictResize()
        local originalOnResize = battleWindow.onResize
        battleWindow.onResize = function(...)
            if originalOnResize then
                originalOnResize(...)
            end
            
            local minHeight = 80
            if not mainInstance:isHidingFilters() then
                minHeight = minHeight + 60
            end
            if battleWindow:getHeight() < minHeight then
                battleWindow:setHeight(minHeight)
            end
        end
    end
    
    -- Setup toggleFilterButton onClick handler for main instance
    if mainInstance.toggleFilterButton then
        mainInstance.toggleFilterButton.onClick = function()
            mainInstance:toggleFilterPanel()
            restrictResize()
            
            local minHeight = 80
            if not mainInstance:isHidingFilters() then
                minHeight = minHeight + 60
            end
            if battleWindow:getHeight() < minHeight then
                battleWindow:setHeight(minHeight)
            end
        end
    end
    restrictResize()
    
    local originalOnMinimize = battleWindow.onMinimize
    local originalOnMaximize = battleWindow.onMaximize
    
    battleWindow.onMinimize = function(...)
        if originalOnMinimize then originalOnMinimize(...) end
        battleWindow.onResize = nil
    end
    
    battleWindow.onMaximize = function(...)
        if originalOnMaximize then originalOnMaximize(...) end
        restrictResize()
    end
    
    battleWindow:setup()
    updateBattleListTitle()
    
    battleWindow.onMousePress = function(widget, mousePos, button)
        if button == MouseRightButton then
            local menu = g_ui.createWidget('PopupMenu')
            menu:addOption('Edit Name', function() mainInstance:onMenuAction('editBattleListName') end)
            menu:display(mousePos)
            return true
        end
        return false
    end
    
    if g_game.isOnline() then
        battleWindow:setupOnStart()
    end
end

-- Binary Search and utility functions
function BSComparator(a, b)
    return a > b and -1 or (a < b and 1 or 0)
end

function BSComparatorSortType(a, b, sortType, id)
    local comparatorA, comparatorB
    if sortType == 'distance' then
        comparatorA, comparatorB = a.distance, (type(b) == 'table' and b.distance or b)
    elseif sortType == 'health' then
        comparatorA, comparatorB = a.healthpercent, type(b) == 'table' and b.healthpercent or b
    elseif sortType == 'age' then
        comparatorA, comparatorB = a.age, type(b) == 'table' and b.age or b
    elseif sortType == 'name' then
        comparatorA, comparatorB = (a.name):lower(), type(b) == 'table' and (b.name):lower() or b
    end

    if comparatorA == nil or comparatorB == nil then
        return 0
    end

    if comparatorA > comparatorB then
        return -1
    elseif comparatorA < comparatorB then
        return 1
    else
        if id and b and b.id then
            return a.id > b.id and -1 or (a.id < b.id and 1 or 0)
        end
        return 0
    end
end

function binarySearch(tbl, value, comparator, ...)
    comparator = comparator or BSComparator
    local mini, maxi = 1, #tbl

    while mini <= maxi do
        local mid = math.floor((maxi + mini) / 2)
        local tmp_value = comparator(tbl[mid], value, ...)

        if tmp_value == 0 then
            return mid
        elseif tmp_value < 0 then
            maxi = mid - 1
        else
            mini = mid + 1
        end
    end
    return nil
end

function binaryInsert(tbl, value, comparator, ...)
    comparator = comparator or BSComparator
    local mini, maxi = 1, #tbl
    local state, mid = 0, 1

    while mini <= maxi do
        mid = math.floor((maxi + mini) / 2)
        if comparator(tbl[mid], value, ...) < 0 then
            maxi, state = mid - 1, 0
        else
            mini, state = mid + 1, 1
        end
    end
    table.insert(tbl, mid + state, value)
    return mid + state
end

function onGameStart()
    battleWindow:setupOnStart() -- load character window configuration

    -- Update battle list title in case it was customized
    updateBattleListTitle()
    
    -- Load main instance lock state (in case it wasn't loaded during init)
    local mainInstance = BattleListManager.instances[0]
    if mainInstance then
        mainInstance:loadLockState()
    end

    -- Initialize all battle list instances
    for _, instance in pairs(BattleListManager.instances) do
        if instance.window then
            instance.window:setupOnStart()
        end
        instance:updateTitle()
    end

    -- Restore saved battle list instances
    BattleListManager:restoreInstancesState()

    -- Set up periodic auto-save to prevent data loss
    BattleListManager:startPeriodicSave()

    -- Initialize creatures for all instances (including main instance ID 0)
    scheduleEvent(function()
        for _, instance in pairs(BattleListManager.instances) do
            instance:checkCreatures()
        end
    end, 500) -- Increased delay to ensure restored instances are fully set up
end

function onGameEnd()
    -- Stop periodic auto-save
    BattleListManager:stopPeriodicSave()
    
    battleWindow:setParent(nil, true)
    removeAllCreatures()
    saveFilters()

    -- Save state and clean up all battle list instances without clearing their configurations
    BattleListManager:saveInstancesState() -- This now saves all settings including filters and hide buttons
    for _, instance in pairs(BattleListManager.instances) do
        instance:removeAllCreatures()
        -- Settings are already saved by saveInstancesState(), just clean up UI elements
        if instance.id ~= 0 and instance.window then
            instance.window:setParent(nil, true)
        end
    end

    disconnecting()
end

-- Sort Type Methods
function getSortType() -- Return the current sort type (distance, age, name, health)
    local settings = g_settings.getNode('BattleList')
    if not settings or not settings['sortType'] then
        return 'name'
    end
    return settings['sortType']
end

function setSortType(state, oldSortType) -- Setting the current sort type (distance, age, name, health)
    -- Only update global settings for backwards compatibility
    local settings = {}
    settings['sortType'] = state
    g_settings.mergeNode('BattleList', settings)

    -- Update main instance (ID 0) for backward compatibility, but don't affect other instances
    local mainInstance = BattleListManager.instances[0]
    if mainInstance then
        local order = mainInstance:getSortOrder()
        mainInstance:reSort(oldSortType, state, order, order)
    end
end

function onZoomChange()
    removeEvent(eventOnCheckCreature)
    eventOnCheckCreature = scheduleEvent(function()
        -- Update all battle list instances
        for _, instance in pairs(BattleListManager.instances) do
            instance:checkCreatures()
        end
    end, 1000)
end

function onChangeSortType(comboBox, option) -- Callback when change the sort type (distance, age, name, health)
    local loption = option:lower()
    local oldType = getSortType()

    if loption ~= oldType then
        setSortType(loption, oldType)
    end
end

-- Sort Order Methods
function getSortOrder() -- Return the current sort ordenation (asc/desc)
    local settings = g_settings.getNode('BattleList')
    if not settings then
        return 'A'
    end
    return settings['sortOrder']
end

function setSortOrder(state, oldSortOrder) -- Setting the current sort ordenation (desc/asc)
    -- Only update global settings for backwards compatibility
    local settings = {}
    settings['sortOrder'] = state
    g_settings.mergeNode('BattleList', settings)

    -- Update main instance (ID 0) for backward compatibility, but don't affect other instances
    local mainInstance = BattleListManager.instances[0]
    if mainInstance then
        mainInstance:reSort(false, false, oldSortOrder, state)
    end
end

function isSortAsc() -- Return true if sorted Asc
    return getSortOrder() == 'A'
end

function isSortDesc() -- Return true if sorted Desc
    return getSortOrder() == 'D'
end

function onChangeSortOrder(comboBox, option) -- Callback when change the sort ordenation
    local soption = option:sub(1, 1)
    local oldOrder = getSortOrder()

    if soption ~= oldOrder then
        setSortOrder(option:sub(1, 1), oldOrder)
    end
end

-- Initially checking creatures
function checkCreatures() -- Function that initially populates our tree once the module is initialized
    eventOnCheckCreature = nil

    if not g_game.isOnline() then
        return false
    end

    local player = g_game.getLocalPlayer()
    if not player then
        return false
    end

    local position = player:getPosition()
    if not position then
        return false
    end

    -- Update all battle list instances
    for _, instance in pairs(BattleListManager.instances) do
        if instance.panel then
            instance:checkCreatures()
        end
    end
end

function doCreatureFitFilters(creature) -- Check if creature fit current applied filters (By changing the filter we will call checkCreatures(true) to recreate the tree)
    -- Use main instance for global calls
    local mainInstance = BattleListManager.instances[0]
    if mainInstance then
        return mainInstance:doCreatureFitFilters(creature)
    end
    return false
end

function onFilterButtonClick(button)
    button:setChecked(not button:isChecked())
    
    -- Save hide button states for main instance
    local mainInstance = BattleListManager.instances[0]
    if mainInstance then
        mainInstance:saveHideButtonStates()
    end
    
    -- Update all battle list instances
    for _, instance in pairs(BattleListManager.instances) do
        instance:checkCreatures()
    end
end

function canBeSeen(creature)
    return creature and creature:canBeSeen() and creature:getPosition() and
        modules.game_interface.getMapPanel():isInRange(creature:getPosition())
end

function getDistanceBetween(p1, p2) -- Calculate distance
    if p2 == nil then
        p2 = {
            x = 0,
            y = 0
        }
    end

    local xd = math.abs(p1.x - p2.x);
    local yd = math.abs(p1.y - p2.y);

    if xd > 0 then
        xd = xd - 1
    end
    if yd > 0 then
        yd = yd - 1
    end

    return xd + yd
end

-- Adding and Removing creatures
local function getAttributeByOrderType(battleButton, orderType) -- Return the attribute of battleButton based on the orderType
    if battleButton.data then
        local battleButton = battleButton.data
        if orderType == 'distance' then
            return {
                distance = battleButton.distance
            }
        elseif orderType == 'health' then
            return {
                healthpercent = battleButton.healthpercent
            }
        elseif orderType == 'age' then
            return {
                age = battleButton.age
            }
        else
            return {
                name = battleButton.name
            }
        end
    end
    return false
end

local lastAge = 0
function addCreature(creature, sortType) -- Insert a creature in our binary tree
    -- Delegate to main instance
    local mainInstance = BattleListManager.instances[0]
    if mainInstance then
        mainInstance:addCreature(creature, sortType)
    end
end

function removeAllCreatures() -- Remove all creatures from our binary tree
    -- Delegate to main instance
    local mainInstance = BattleListManager.instances[0]
    if mainInstance then
        mainInstance:removeAllCreatures()
    end
end

function removeCreature(creature, all) -- Remove a single creature or all
    -- Delegate to main instance
    local mainInstance = BattleListManager.instances[0]
    if mainInstance then
        return mainInstance:removeCreature(creature, all)
    end
    return false
end

-- Hide/Show Filter Options
function isHidingFilters() -- Return true if filters are hidden
    local settings = g_settings.getNode('BattleList')
    if not settings then
        return false
    end
    return settings['hidingFilters']
end

function setHidingFilters(state) -- Setting hiding filters
    settings = {}
    settings['hidingFilters'] = state
    g_settings.mergeNode('BattleList', settings)
end

function hideFilterPanel() -- Hide Filter panel
    local mainInstance = BattleListManager:getMainInstance()
    if mainInstance then
        mainInstance:hideFilterPanel()
    end
end

function showFilterPanel() -- Show Filter panel
    local mainInstance = BattleListManager:getMainInstance()
    if mainInstance then
        mainInstance:showFilterPanel()
    end
end

function toggleFilterPanel() -- Switching modes of filter panel (hide/show)
    local mainInstance = BattleListManager:getMainInstance()
    if mainInstance then
        mainInstance:toggleFilterPanel()
    end
end

function attackNext(previous)
    local foundTarget = false
    local firstElement = nil
    local lastElement = nil
    local prevElement = nil
    local nextElement = nil

    local mainInstance = BattleListManager.instances[0]
    if not mainInstance or not mainInstance.panel then
        return
    end

    local children = mainInstance.panel:getChildren()

    for _, battleButton in pairs(mainInstance.panel:getChildren()) do
        if battleButton:isVisible() then
            -- select visible first child
            if not firstElement then
                firstElement = battleButton
            end
            lastElement = battleButton

            if battleButton.isTarget then
                foundTarget = true
            elseif foundTarget and not nextElement then
                nextElement = battleButton
            elseif not foundTarget then
                prevElement = battleButton
            end
        end
    end

    if foundTarget then
        if previous then
            if prevElement then
                g_game.attack(prevElement.creature)
            else
                g_game.attack(lastElement.creature)
            end
        else
            if nextElement then
                g_game.attack(nextElement.creature)
            else
                g_game.attack(firstElement.creature)
            end
        end
    elseif firstElement then
        g_game.attack(firstElement.creature)
    else
        return false
    end
    return true
end

-- Connector Callbacks
function onAttack(creature) -- Update battleButton once you're attacking a target
    if lastCreatureSelected then
        lastCreatureSelected:hideStaticSquare()
        lastCreatureSelected = nil
    end

    local foundBattleButton = false
    
    -- Update all battle list instances
    for _, instance in pairs(BattleListManager.instances) do
        if instance.window and instance.window:isVisible() then
            if creature then
                -- Setting a new target
                local battleButton = instance.battleButtons[creature:getId()]
                if battleButton then
                    battleButton.isTarget = true
                    updateBattleButton(battleButton)
                    foundBattleButton = true
                end
            else
                -- No target (attack cancelled), clear all target flags
                for _, battleButton in pairs(instance.battleButtons) do
                    if battleButton.isTarget then
                        battleButton.isTarget = false
                        updateBattleButton(battleButton)
                    end
                end
            end
        end
    end

    -- If no battle button was found in any instance, show static square on creature
    if not foundBattleButton and creature then
        creature:showStaticSquare(UICreatureButton.getCreatureButtonColors().onTargeted.notHovered)
    end

    lastCreatureSelected = creature
end

function onFollow(creature) -- Update battleButton once you're following a target
    if lastCreatureSelected then
        lastCreatureSelected:hideStaticSquare()
        lastCreatureSelected = nil
    end

    local foundBattleButton = false
    
    -- Update all battle list instances
    for _, instance in pairs(BattleListManager.instances) do
        if instance.window and instance.window:isVisible() then
            if creature then
                local battleButton = creature and instance.battleButtons[creature:getId()] or nil
                if battleButton then
                    battleButton.isFollowed = creature and true or false
                    updateBattleButton(battleButton)
                    foundBattleButton = true
                    -- Don't break here - continue to update other instances
                end
            else
                -- No follow (follow cancelled), clear all follow flags
                for _, battleButton in pairs(instance.battleButtons) do
                    if battleButton.isFollowed then
                        battleButton.isFollowed = false
                        updateBattleButton(battleButton)
                    end
                end
            end
        end
    end

    -- If no battle button was found in any instance, show static square on creature
    if not foundBattleButton and creature then
        creature:showStaticSquare(UICreatureButton.getCreatureButtonColors().onFollowed.notHovered)
    end
    
    lastCreatureSelected = creature
end

function onCreatureOutfitChange(creature, outfit, oldOutfit) -- Insert/Remove creature when it becomes visible/invisible
    -- Update all battle list instances
    for _, instance in pairs(BattleListManager.instances) do
        local battleButton = instance.battleButtons[creature:getId()]
        local fit = instance:doCreatureFitFilters(creature)

        if battleButton ~= nil and not fit then
            instance:removeCreature(creature)
        elseif battleButton == nil and fit then
            instance:addCreature(creature)
        end
    end
end

function updateCreatureSkull(creature, skullId) -- Update skull
    -- Update all battle list instances
    for _, instance in pairs(BattleListManager.instances) do
        local battleButton = instance.battleButtons[creature:getId()]
        if battleButton then
            battleButton:updateSkull(skullId)
        end
    end
end

function updateCreatureEmblem(creature, emblemId) -- Update emblem
    -- Update all battle list instances
    for _, instance in pairs(BattleListManager.instances) do
        local battleButton = instance.battleButtons[creature:getId()]
        if battleButton then
            battleButton:updateEmblem(emblemId)
        end
    end
end

local function rebuildBattleList(instance)
  scheduleEvent(function()
    if not instance.panel or not g_game.isOnline() then return end

    instance.panel:disableUpdateTemporarily()

    local player = g_game.getLocalPlayer()
    local pos = player and player:getPosition()
    if not pos then return end

    instance:removeAllCreatures()

    local spectators = g_map.getSpectators(pos, false, true) or {}

    if #spectators == 0 then
      spectators = modules.game_interface.getMapPanel():getSpectators() or {}
    end

    local sortType = instance:getSortType()

    for _, creature in ipairs(spectators) do
      if instance:doCreatureFitFilters(creature) then
        instance:addCreature(creature, sortType)
      end
    end

    instance:correctBattleButtons()

    for id, btn in pairs(instance.battleButtons) do
      local mob = btn.creature or g_map.getCreatureById(id)
      if mob and mob:getPosition() then
        btn:setVisible(canBeSeen(mob))
      end
    end

    if instance.panel.enableUpdate then
      instance.panel:enableUpdate()
    end
  end)
end

function onCreaturePositionChange(creature, newPos, oldPos) -- Update battleButton once you or monsters move
    local localPlayer = g_game.getLocalPlayer()
    if not localPlayer then
        return false
    end

    local position = localPlayer:getPosition()
    if not position then
        return false
    end

    -- Update all battle list instances
    for _, instance in pairs(BattleListManager.instances) do
        if instance.panel then
            instance.panel:disableUpdateTemporarily()
            
            local sortType = instance:getSortType()
            -- If it's the local player moving
            if creature:isLocalPlayer() then
                if oldPos and newPos and newPos.z ~= oldPos.z then
                    rebuildBattleList(instance)
                elseif oldPos and newPos and (newPos.x ~= oldPos.x or newPos.y ~= oldPos.y) then
                    -- Distance will change when moving, recalculate and move to correct index
                    if #instance.binaryTree > 0 and sortType == 'distance' then
                        -- TODO: If the amount of creatures is higher than a given number, instead of using this approach we simply recalculate each 200ms.
                        for i, v in ipairs(instance.binaryTree) do
                            local oldDistance = v.distance
                            local battleButton = instance.battleButtons[v.id]
                            local mob = battleButton.creature or g_map.getCreatureById(v.id)
                            local newDistance = getDistanceBetween(newPos, mob:getPosition())
                            if oldDistance ~= newDistance then
                                v.distance = newDistance
                                battleButton.data.distance = newDistance
                            end
                        end
                        table.sort(instance.binaryTree, function(a, b)
                            return BSComparatorSortType(a, b, 'distance', true) == 1
                        end)
                        instance:correctBattleButtons()
                    end

                    for i, v in pairs(instance.battleButtons) do
                        local mob = v.creature
                        if mob and mob:getPosition() then
                            v:setVisible(canBeSeen(mob))
                        end
                    end
                end
            else
                -- If it's a creature moving
                local creatureId = creature:getId()
                local battleButton = instance.battleButtons[creatureId]
                local fit = instance:doCreatureFitFilters(creature)

                if battleButton == nil then
                    if fit then
                        instance:addCreature(creature, sortType)
                    end
                else
                    if not fit and newPos then -- if there's no newPos the creature is dead, let onCreatureDisappear handles that.
                        instance:removeCreature(creature)
                    elseif fit then
                        if oldPos and newPos and (newPos.x ~= oldPos.x or newPos.y ~= oldPos.y) then
                            if sortType == 'distance' then
                                local localPlayer = g_game.getLocalPlayer()
                                local newDistance = getDistanceBetween(localPlayer:getPosition(), newPos)
                                local oldDistance = battleButton.data.distance

                                local index = binarySearch(instance.binaryTree, {
                                    distance = oldDistance,
                                    id = creatureId
                                }, BSComparatorSortType, 'distance', true)

                                if index ~= nil and creatureId == instance.binaryTree[index].id then -- Safety first :)
                                    instance.binaryTree[index].distance = newDistance
                                    battleButton.data.distance = newDistance
                                    if newDistance > oldDistance then
                                        if index < #instance.binaryTree then
                                            for i = index, #instance.binaryTree - 1 do
                                                local a = instance.binaryTree[i]
                                                local b = instance.binaryTree[i + 1]
                                                if a.distance > b.distance or (a.distance == b.distance and a.id > b.id) then
                                                    instance:swap(i, i + 1)
                                                end
                                            end
                                        end
                                    elseif newDistance < oldDistance then
                                        battleButton:setVisible(canBeSeen(creature))

                                        if lastCreatureSelected == creature and not battleButton:isVisible() then
                                            lastCreatureSelected:hideStaticSquare()
                                            lastCreatureSelected = nil
                                        end

                                        if index > 1 then
                                            for i = index, 2, -1 do
                                                local a = instance.binaryTree[i - 1]
                                                local b = instance.binaryTree[i]
                                                if a.distance > b.distance or (a.distance == b.distance and a.id > b.id) then
                                                    instance:swap(i - 1, i)
                                                end
                                            end
                                        end
                                    end
                                    instance:correctBattleButtons()
                                else
                                    assert(index ~= nil,
                                        'Not able to update Position Change. Creature: ' .. creature:getName() .. ' id ' ..
                                        creatureId .. ' not found in binary search using ' .. sortType .. ' to find value ' ..
                                        oldDistance .. '.\n')
                                end
                            end
                        end
                        instance:addCreature(creature) -- should check if creature visibility has changed
                    end
                end
            end
        end
    end
end

function onCreatureHealthPercentChange(creature, healthPercent, oldHealthPercent) -- Update battleButton mobs lose/gain health
    -- Update all battle list instances
    for _, instance in pairs(BattleListManager.instances) do
        local creatureId = creature:getId()
        local battleButton = instance.battleButtons[creatureId]
        if battleButton then
            local sortType = instance:getSortType()
            if battleButton.setLifeBarPercent then
                battleButton:setLifeBarPercent(healthPercent)
            end
            if battleButton.data then
                battleButton.data.healthpercent = healthPercent
            end
            local skipInstance = false
            if sortType == 'health' then
                if healthPercent == oldHealthPercent then
                    skipInstance = true -- Skip this instance
                end
                if not skipInstance and healthPercent == 0 then
                    skipInstance = true -- Let onCreatureDisappear handle this
                end

                if not skipInstance then
                    local index = binarySearch(instance.binaryTree, {
                        healthpercent = oldHealthPercent,
                        id = creatureId
                    }, BSComparatorSortType, 'health', true)
                    if index ~= nil and creatureId == instance.binaryTree[index].id then
                        instance.binaryTree[index].healthpercent = healthPercent
                        battleButton.data.healthpercent = healthPercent
                        if healthPercent > oldHealthPercent then
                            if index < #instance.binaryTree then
                                for i = index, #instance.binaryTree - 1 do
                                    local a = instance.binaryTree[i]
                                    local b = instance.binaryTree[i + 1]
                                    if a.healthpercent > b.healthpercent or (a.healthpercent == b.healthpercent and a.id > b.id) then
                                        local tmp = instance.binaryTree[i]
                                        instance.binaryTree[i] = instance.binaryTree[i + 1]
                                        instance.binaryTree[i + 1] = tmp
                                    end
                                end
                            end
                        else
                            if index > 1 then
                                for i = index, 2, -1 do
                                    local a = instance.binaryTree[i - 1]
                                    local b = instance.binaryTree[i]
                                    if a.healthpercent > b.healthpercent or (a.healthpercent == b.healthpercent and a.id > b.id) then
                                        local tmp = instance.binaryTree[i - 1]
                                        instance.binaryTree[i - 1] = instance.binaryTree[i]
                                        instance.binaryTree[i] = tmp
                                    end
                                end
                            end
                        end
                        instance:correctBattleButtons()
                    end
                end
            end
            if not skipInstance and battleButton.creature then
                battleButton:update()
            end
        end
    end
end

function onCreatureAppear(creature) -- Update battleButton once a creature appear (add)
    if creature:isLocalPlayer() then
        addEvent(updateStaticSquare)
    end

    -- Update all battle list instances (including main instance ID 0)
    for _, instance in pairs(BattleListManager.instances) do
        local sortType = instance:getSortType()
        if instance:doCreatureFitFilters(creature) then
            instance:addCreature(creature, sortType)
        end
    end
end

function onCreatureDisappear(creature) -- Update battleButton once a creature disappear (remove/dead)
    -- Update all battle list instances (including main instance ID 0)
    for _, instance in pairs(BattleListManager.instances) do
        instance:removeCreature(creature)
    end
end

-- BattleWindow controllers
function onBattleButtonMouseRelease(self, mousePosition, mouseButton) -- Interactions with mouse (right, left, right + left and shift interactions)
    if mouseWidget.cancelNextRelease then
        mouseWidget.cancelNextRelease = false
        return false
    end

    if ((g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton) or
            (g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton)) then
        mouseWidget.cancelNextRelease = true
        g_game.look(self.creature, true)
        return true
    elseif mouseButton == MouseLeftButton and g_keyboard.isShiftPressed() then
        g_game.look(self.creature, true)
        return true
    elseif mouseButton == MouseRightButton and not g_mouse.isPressed(MouseLeftButton) then
        modules.game_interface.createThingMenu(mousePosition, nil, nil, self.creature)
        return true
    elseif mouseButton == MouseLeftButton and not g_mouse.isPressed(MouseRightButton) then
        if self.isTarget then
            g_game.cancelAttack()
        else
            g_game.attack(self.creature)
        end
        return true
    end
    return false
end

function updateStaticSquare(battleButton) -- Update all static squares upon appearing the screen (login)
    -- Update all battle list instances
    for _, instance in pairs(BattleListManager.instances) do
        for _, battleButton in pairs(instance.battleButtons) do
            if battleButton.isTarget and battleButton.creature then
                battleButton:update()
            end
        end
    end
end

function updateBattleButton(battleButton) -- Update battleButton with attack/follow squares
    -- Safety check: don't update if creature is nil
    if not battleButton or not battleButton.creature then
        return
    end
    
    battleButton:update()
    
    if battleButton.isTarget then
        -- Clear target flag from all other battle buttons representing DIFFERENT creatures in all instances
        local currentCreatureId = battleButton.creature:getId()
        for _, instance in pairs(BattleListManager.instances) do
            for _, otherBattleButton in pairs(instance.battleButtons) do
                if otherBattleButton ~= battleButton and otherBattleButton.isTarget and 
                   otherBattleButton.creature and otherBattleButton.creature:getId() ~= currentCreatureId then
                    otherBattleButton.isTarget = false
                    otherBattleButton:update()
                end
            end
        end
        lastBattleButtonSwitched = battleButton
    end
    
    if battleButton.isFollowed then
        -- Clear follow flag from all other battle buttons representing DIFFERENT creatures in all instances
        local currentCreatureId = battleButton.creature:getId()
        for _, instance in pairs(BattleListManager.instances) do
            for _, otherBattleButton in pairs(instance.battleButtons) do
                if otherBattleButton ~= battleButton and otherBattleButton.isFollowed and
                   otherBattleButton.creature and otherBattleButton.creature:getId() ~= currentCreatureId then
                    otherBattleButton.isFollowed = false
                    otherBattleButton:update()
                end
            end
        end
        lastBattleButtonSwitched = battleButton
    end
    
    -- Clear lastBattleButtonSwitched if it's a released button
    if lastBattleButtonSwitched and not lastBattleButtonSwitched.creature then
        lastBattleButtonSwitched = nil
    end
end

function onBattleButtonHoverChange(battleButton, hovered) -- Interaction with mouse (hovering)
    if battleButton.isBattleButton then
        battleButton.isHovered = hovered
        updateBattleButton(battleButton)
    end
end

function onOpen()
    battleButton:setOn(true)
    connecting()
    
    -- Ensure default filters are applied for the main battle list
    local mainInstance = BattleListManager.instances[0]
    if mainInstance then
        local filters = mainInstance:loadFilters()
        local hasAnySortFilter = false
        
        -- Check if any sort filter is already active
        for filterName, isActive in pairs(filters) do
            if isActive and (filterName:find("sortAscBy") or filterName:find("sortDescBy")) then
                hasAnySortFilter = true
                break
            end
        end
        
        -- If no sort filter is active, apply the default
        if not hasAnySortFilter then
            filters["sortAscByDisplayTime"] = true
            g_settings.mergeNode(mainInstance:getSettingsKey(), { ['filters'] = filters })
            scheduleEvent(function()
                mainInstance:checkCreatures()
            end, 100)
        end
    end
end

function onClose()
    battleButton:setOn(false)
    
    -- Only disconnect global events if there are no other battle list instances open
    local hasOpenInstances = false
    for id, instance in pairs(BattleListManager.instances) do
        if id ~= 0 and instance.window and instance.window:isVisible() then
            hasOpenInstances = true
            break
        end
    end
    
    if not hasOpenInstances then
        disconnecting()
    end
end


function toggle() -- Close/Open the battle window or Pressing Ctrl + B
    if battleButton:isOn() then
        battleWindow:close()
    else
        -- Ensure events are connected when opening the main battle window
        if g_game.isOnline() then
            connecting()
        end
        
        if not battleWindow:getParent() then
            local panel = modules.game_interface
                .findContentPanelAvailable(battleWindow, battleWindow:getMinimumHeight())
            if not panel then
                return
            end

            panel:addChild(battleWindow)
        end
        battleWindow:open()
    end
end

function terminate() -- Terminating the Module (unload)
    -- Save battle list instances state before destroying
    BattleListManager:saveInstancesState()
    
    -- Explicitly save main instance settings as well
    local mainInstance = BattleListManager.instances[0]
    if mainInstance then
        mainInstance:saveLockState()
        mainInstance:saveFilters()
        mainInstance:saveHideButtonStates()
    end
    
    -- Destroy all battle list instances (preserving settings for next session)
    for _, instance in pairs(BattleListManager.instances) do
        instance:destroy(true) -- Preserve settings during module termination
    end
    BattleListManager.instances = {}
    
    binaryTree = {}
    battleButtons = {}
    hideButtons = {}

    if battleButton then
        battleButton:destroy()
        battleButton = nil
    end
    
    if battleWindow then
        battleWindow:destroy()
        battleWindow = nil
    end
    
    if mouseWidget then
        mouseWidget:destroy()
        mouseWidget = nil
    end

    lastCreatureSelected = nil

    battlePanel = nil
    battleButton = nil
    battleWindow = nil
    mouseWidget = nil
    filterPanel = nil
    toggleFilterButton = nil

    Keybind.delete("Windows", "Show/hide battle list")

    disconnect(g_game, {
        onAttackingCreatureChange = onAttack,
        onFollowingCreatureChange = onFollow,
        onGameEnd = onGameEnd,
        onGameStart = onGameStart
    })
    disconnecting()
    
    -- Reset connection state
    eventsConnected = false
end
