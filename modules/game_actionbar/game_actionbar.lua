ApiJson = dofile('logics/ApiJson.lua')

player = nil --localplayer
-- @array
passiveData = {
    cooldown = 0,
    max = 0
}
hotkeyItemList = {} --[ItemPtr, desc]
spellListData = {} -- [[SpellsIdLearn]]
spellCooldownCache = {--[[     
    [SpellId] = { 
        ["startTime"] = ms,
        ["exhaustion"] = ms
    } 
]]
}
spellGroupPressed = {--[[ 
    [GroupId] = bool -- Tracks if spell group is currently pressed
]]
}
cachedItemWidget = { --[[
     [ItemID] = { 
        [SlotId] = Widget1,
        [SlotId] = Widget2,
     ]]
}
actionBars = { --[[ 
    -- ActionBarId=1-3: bottom
    -- ActionBarId=4-6: left
    -- ActionBarId=7-9: right
    [ActionBarId] = widget
]]
}
activeActionBars = {--[[ 
    [VisibleActionBarId] = widget
 ]]
}

-- @ widgets
dragButton = nil
dragItem = nil
mouseGrabberWidget = nil
gameRootPanel = nil
lastHighlightWidget = nil
-- @ boolean
isLoaded = false
local areEventsConnected = false

--- checks if action bar is visible
local function isActionBarVisible(actionBar)
    return actionBar and actionBar:isVisible()
end

--- Adds an action bar to the active list
function addActiveActionBar(actionBar)
    if not actionBar then
        return false
    end

    for _, activeBar in ipairs(activeActionBars) do
        if activeBar == actionBar then
            return false
        end
    end

    table.insert(activeActionBars, actionBar)
    return true
end
--- Rebuilds the list of active action bars
local function rebuildActiveActionBars()
    local previousCount = #activeActionBars
    local visibleCount = 0

    for _, actionBar in ipairs(actionBars) do
        if isActionBarVisible(actionBar) then
            visibleCount = visibleCount + 1
            activeActionBars[visibleCount] = actionBar
        end
    end

    for index = visibleCount + 1, previousCount do
        activeActionBars[index] = nil
    end

    return visibleCount > 0
end
--- Removes an action bar from the active list
function removeActiveActionBar(actionBar)
    if not actionBar then
        return false
    end

    local removed = false
    local index = 1
    while index <= #activeActionBars do
        if activeActionBars[index] == actionBar then
            table.remove(activeActionBars, index)
            removed = true
        else
            index = index + 1
        end
    end

    return removed
end

--- Checks if there are any active action bars
function hasAnyActiveActionBar()
    if not g_game.isOnline() then
        return false
    end

    if rebuildActiveActionBars() then
        return true
    end

    return false
end

--- Sets up an action bar by index
function setupActionBar(n)
    local actionbar = actionBars[n]
    local barState = ApiJson.getActionBar(n) or {}
    local visible = barState.isVisible and true or false
    actionbar:setVisible(visible)
    actionbar:setOn(visible)
    local locked = barState.isLocked and true or false
    actionbar.tabBar.onMouseWheel = nil
    actionbar.locked = locked
    local items = {}
    for i = 1, 50 do
        local layout = n < 4 and 'ActionButton' or 'SideActionButton'
        local widget = actionbar.tabBar:getChildById(n .. "." .. i)
        
           if not widget then
               local hasMapping = ApiJson.getMapping(n, i)
           
           if hasMapping then
               widget = g_ui.createWidget(layout, actionbar.tabBar)
               widget:setId(n .. "." .. i)
           else
               widget = g_ui.createWidget('UIWidget', actionbar.tabBar)
               widget:setId(n .. "." .. i)
               widget:setSize({width = 34, height = 34})
               widget:setMarginLeft(2)
               widget:setImageSource('/images/game/actionbar/actionbarslot')
               widget:setDraggable(false)
               
               widget.onDrop = function(self, draggedWidget, mousePos)
                    if draggedWidget and draggedWidget.currentDragThing then
                        if tryAssignActionButtonFromDrop(mousePos, draggedWidget, draggedWidget.currentDragThing) then
                            return true
                        end
                    end
               end
               
               widget.onMouseRelease = function(self, mousePos, mouseButton)
                    if mouseButton == MouseRightButton then
                        local parent = self:getParent()
                        local id = self:getId()
                        updateButton(self)
                        local newButton = parent:getChildById(id)
                        if newButton and newButton.onMouseRelease then
                            newButton.onMouseRelease(newButton, mousePos, mouseButton)
                        end
                        return true
                    end
               end
           end
        end
        
        -- Only update if it's a real button
        if widget:getChildById('item') and g_game.isOnline() then
             updateButton(widget)
        end
         
         if widget.cooldown then
             widget.cooldown:stop()
         end
         if widget.item and widget.item:getItemId() > 100 then
             table.insert(items, widget.item:getItem())
         end
    end
end

--- Gets the count of active bottom action bars
function getActiveBottomBars()
    if #actionBars == 0 then
        return 0
    end
    local count = 0
    for i = 1, 3 do
        local state = ApiJson.getActionBar(i) or {}
        if state.isVisible then
            count = count + 1
        end
    end
    return count
end

--- Gets the count of active right action bars
function getActiveRightBars()
    if #actionBars == 0 then
        return 0
    end
    local count = 0
    for i = 7, 9 do
        local state = ApiJson.getActionBar(i) or {}
        if state.isVisible then
            count = count + 1
        end
    end
    return count
end

function getActiveLeftBars()
    if #actionBars == 0 then
        return 0
    end
    local count = 0
    for i = 4, 6 do
        local state = ApiJson.getActionBar(i) or {}
        if state.isVisible then
            count = count + 1
        end
    end
    return count
end

local function onUpdateActionBarStatus()
    if #activeActionBars == 0 then
        return true
    end

    for _, actionbar in pairs(activeActionBars) do
        for _, button in pairs(actionbar.tabBar:getChildren()) do
            updateButtonState(button)
        end
    end
end

-- /*=============================================
-- =            Event             =
-- =============================================*/


--- Connects player events
local function connecting()
    if areEventsConnected then
        return
    end

    connect(LocalPlayer, {
        onManaChange = onUpdateActionBarStatus,
        onSoulChange = onUpdateActionBarStatus,
        onLevelChange = onUpdateLevel,
        onSpellsChange = onSpellsChange
    })
    connect(g_game, {
        onItemInfo = onHotkeyItems,
        onPassiveData = onPassiveData,
        onSpellCooldown = onSpellCooldown,
        onMultiUseCooldown = onMultiUseCooldown,
        onSpellGroupCooldown = onSpellGroupCooldown,
        updateInventoryItems = updateInventoryItems
    })

    areEventsConnected = true
end

--- Disconnects player events
local function disconnecting()
    if not areEventsConnected then
        return
    end

    disconnect(LocalPlayer, {
        onManaChange = onUpdateActionBarStatus,
        onSoulChange = onUpdateActionBarStatus,
        onLevelChange = onUpdateLevel,
        onSpellsChange = onSpellsChange
    })
    disconnect(g_game, {
        onItemInfo = onHotkeyItems,
        onPassiveData = onPassiveData,
        onSpellCooldown = onSpellCooldown,
        onMultiUseCooldown = onMultiUseCooldown,
        onSpellGroupCooldown = onSpellGroupCooldown,
        updateInventoryItems = updateInventoryItems
    })

    areEventsConnected = false
end

--- Updates event subscriptions based on active bars
function updateActionBarEventSubscriptions()
    if hasAnyActiveActionBar() then
        connecting()
        return
    end

    disconnecting()
end

-- /*=============================================
-- =            Controller             =
-- =============================================*/
ActionBarController = Controller:new()
--- Initializes the action bar controller
function ActionBarController:onInit()
    g_ui.importStyle("otui/style.otui")
    gameRootPanel = modules.game_interface.getRootPanel()
    mouseGrabberWidget = g_ui.createWidget('UIWidget')
    mouseGrabberWidget:setVisible(false)
    mouseGrabberWidget:setFocusable(false)
    mouseGrabberWidget.onMouseRelease = onDropActionButton
end

--- Handles termination event
function ActionBarController:onTerminate()
    ApiJson.saveData()
    for _, actionbar in pairs(actionBars) do
        if actionbar and not actionbar:isDestroyed() then
            actionbar:destroy()
        end
    end
    if mouseGrabberWidget then
        mouseGrabberWidget:destroy()
        mouseGrabberWidget = nil
    end
    if lastHighlightWidget then
        lastHighlightWidget:destroy()
        lastHighlightWidget = nil
    end
    if dragButton then
        dragButton:destroy()
        dragButton = nil
    end
    if dragItem then
        dragItem:destroy()
        dragItem = nil
    end
    actionBars = {}
    activeActionBars = {}
    disconnecting()
end

--- Handles game start event
function ActionBarController:onGameStart()
    onCreateActionBars()
    
    -- Ensure fresh cache
    if clearHotkeyCache then clearHotkeyCache() end
    updateActionBarEventSubscriptions()
    dragItem = nil
    dragButton = nil
    cachedItemWidget = {}
    player = g_game.getLocalPlayer()
    hotkeyItemList = {}
    spellGroupPressed = {}
    for i = 1, #actionBars do
        setupActionBar(i)
    end
    ActionBarController:scheduleEvent(function()
        onMultiUseCooldown()
        onUpdateActionBarStatus()
        updateActionPassive()
        updateVisibleWidgets()
        isLoaded = true
    end, 300, "update_items")
end

function ActionBarController:onGameEnd()
    isLoaded = false
    for _, actionbar in pairs(activeActionBars) do
        unbindActionBarEvent(actionbar)
    end
    activeActionBars = {}
    hotkeyItemList = {}
    if g_tooltip then
        g_tooltip.hide()
        g_tooltip.hideSpecial()
    end
    updateActionBarEventSubscriptions()
end
-- /*=============================================
-- =            Events Call            =
-- =============================================*/


--- Handles spell cooldown events
function onSpellCooldown(spellId, delay)
    local showProgress = modules.client_options.getOption("graphicalCooldown")
    local showTime = modules.client_options.getOption("cooldownSecond")
    if not showProgress and not showTime then
        return true
    end
    local isRune = Spells.isRuneSpell(spellId)
    spellCooldownCache[spellId] = {
        exhaustion = delay,
        startTime = g_clock.millis()
    }
    for _, actionbar in pairs(activeActionBars) do
        for _, button in pairs(actionbar.tabBar:getChildren()) do
            local cache = getButtonCache(button)
            if cache and (cache.isSpell or cache.isRuneSpell) then
                local shouldUpdate = true
                if cache.isRuneSpell and not isRune then
                    shouldUpdate = false
                elseif not cache.isRuneSpell and cache.spellID ~= spellId then
                    shouldUpdate = false
                elseif cache.cooldownEvent ~= nil and button.cooldown:getTimeElapsed() > delay then
                    shouldUpdate = false
                end
                if shouldUpdate then
                    updateCooldown(button, delay)
                    if cache.removeCooldownEvent then
                        removeEvent(button.cache.removeCooldownEvent)
                        button.cache.removeCooldownEvent = nil
                    end
                    button.cache.removeCooldownEvent = scheduleEvent(function()
                        removeCooldown(button)
                    end, delay)
                end
            end
        end
    end
end

function onSpellGroupCooldown(groupId, delay)
    local showProgress = modules.client_options.getOption("graphicalCooldown")
    local showTime = modules.client_options.getOption("cooldownSecond")
    if not showProgress and not showTime then
        return true
    end
    for _, actionbar in pairs(activeActionBars) do
        for _, button in pairs(actionbar.tabBar:getChildren()) do
            local cache = getButtonCache(button)
            if cache and (not cache.isRuneSpell and cache.spellData) then
                if Spells.getCooldownByGroup(cache.spellData, groupId) then
                    local resttime = button.cooldown:getDuration() - button.cooldown:getTimeElapsed()
                    if resttime < delay then
                        updateCooldown(button, delay)
                        if button.cache.removeCooldownEvent then
                            removeEvent(button.cache.removeCooldownEvent)
                            button.cache.removeCooldownEvent = nil
                        end
                        button.cache.removeCooldownEvent = scheduleEvent(function()
                            removeCooldown(button)
                        end, delay)
                        spellCooldownCache[button.cache.spellData.id] = {
                            exhaustion = delay,
                            startTime = g_clock.millis()
                        }
                    end
                end
                if Spells.getCooldownBySecondaryGroup(cache.spellData, groupId) then
                    local spellCache = spellCooldownCache[button.cache.spellData.id]
                    if not spellCache then
                        spellCache = {}
                        spellCache.startTime = 0
                    end
                    local resttime = button.cooldown:getDuration() - button.cooldown:getTimeElapsed()
                    if resttime < delay then
                        updateCooldown(button, delay)
                        if button.cache.removeCooldownEvent then
                            removeEvent(button.cache.removeCooldownEvent)
                            button.cache.removeCooldownEvent = nil
                        end
                        button.cache.removeCooldownEvent = scheduleEvent(function()
                            removeCooldown(button)
                        end, delay)
                        spellCooldownCache[button.cache.spellData.id] = {
                            exhaustion = delay,
                            startTime = g_clock.millis()
                        }
                    end
                end
            end
        end
    end
end

--- Handles passive ability data updates
function onPassiveData(currentCooldown, maxCooldown, canDecay)
    passiveData = {
        cooldown = currentCooldown,
        max = maxCooldown
    }
    updateActionPassive()
end

--- Handles spell list changes
function onSpellsChange(player, list)
    spellListData = {}
    for _, spellId in pairs(list) do
        local spell = Spells.getSpellByClientId(spellId)
        if spell then
            spellListData[tostring(spellId)] = spell
        end
    end
end

function onHotkeyItems(itemList)
    for _, data in pairs(itemList) do
        table.insert(hotkeyItemList, data)
    end
    for _, actionbar in pairs(activeActionBars) do
        for _, button in pairs(actionbar.tabBar:getChildren()) do
            if button.item:getItemId() >= 100 then
                setupButtonTooltip(button, false)
            end
        end
    end
end

--- Handles level updates
function onUpdateLevel(localPlayer, level, levelPercent, oldLevel, oldLevelPercent)
    if level ~= oldLevel then
        onUpdateActionBarStatus()
    end
end

--- Handles multi-use cooldown updates
function onMultiUseCooldown(multiUseCooldown)
    for _, actionbar in pairs(activeActionBars) do
        for _, button in pairs(actionbar.tabBar:getChildren()) do
            updateButtonState(button)
            if multiUseCooldown and button.item and button.cache and button.cache.itemId then
                local item = button.item:getItem()
                if item and item:isMultiUse() then
                    local marketArray = {MarketCategory.Potions, MarketCategory.Runes, MarketCategory.Tools}
                    if table.contains(marketArray, item:getMarketData().category) then
                        updateCooldown(button, multiUseCooldown)
                    end
                end
            end
        end
    end
end

function updateInventoryItems(_)
    for _, widgetList in pairs(cachedItemWidget) do
        for _, widget in pairs(widgetList) do
            updateButtonState(widget)
        end
    end
end

--- Updates visible widgets externally
function updateVisibleWidgetsExternal()
    updateVisibleWidgets()
end

--- Toggles cooldown display options
function toggleCooldownOption()
    for _, actionbar in pairs(activeActionBars) do
        for _, button in pairs(actionbar.tabBar:getChildren()) do
            if button.cooldown and button.cooldown:getPercent() < 100 then
                 local remaining = button.cooldown:getDuration() - button.cooldown:getTimeElapsed()
                 if remaining > 0 then
                     updateCooldown(button, remaining) 
                 end
            end
        end
    end

end

function configureActionBar(key, value)
    local map = {
        actionBarShowBottom1 = 1,
        actionBarShowBottom2 = 2,
        actionBarShowBottom3 = 3,
        actionBarShowLeft1 = 4,
        actionBarShowLeft2 = 5,
        actionBarShowLeft3 = 6,
        actionBarShowRight1 = 7,
        actionBarShowRight2 = 8,
        actionBarShowRight3 = 9
    }
    local n = map[key]
    if not n then return end
    
    local actionbar = actionBars[n]
    if actionbar then
        actionbar:setVisible(value)
        actionbar:setOn(value)
        if value then
            addActiveActionBar(actionbar)
            setupActionBar(n)
        else
            removeActiveActionBar(actionbar)
        end
        if resizeLockButtons then
            resizeLockButtons()
        end
        if ActionBarController then
            ActionBarController:scheduleEvent(onUpdateActionBarStatus)
        end
    end
end

--- Updates visible options
function updateVisibleOptions(type, value)
    for _, actionbar in pairs(activeActionBars) do
        for _, button in pairs(actionbar.tabBar:getChildren()) do
            if type == 'hotkey' and button.hotkeyLabel then
                button.hotkeyLabel:setVisible(value)
            elseif type == 'parameter' and button.parameterText then
                button.parameterText:setVisible(value)
            elseif type == 'tooltip' then
                setupButtonTooltip(button, false)
            elseif type == 'amount' then
                updateButtonState(button)
            end
        end
    end
end

--- Resets a specific action bar
function resetAction(barId)
    local actionbar = actionBars[barId]
    if not actionbar then return end
    
    for i = 1, 50 do
        ApiJson.removeAction(barId, i)
        
        local button = actionbar.tabBar:getChildById(barId .. "." .. i)
        if button then
            updateButton(button)
        end
    end
end

--- Resets all action bars
function resetActionBars()
    for i = 1, 9 do
        resetAction(i)
    end
end