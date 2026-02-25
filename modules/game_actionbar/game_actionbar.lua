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

local function isActionBarVisible(actionBar)
    return actionBar and actionBar:isVisible()
end

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

function hasAnyActiveActionBar()
    if not g_game.isOnline() then
        return false
    end

    if rebuildActiveActionBars() then
        return true
    end

    return false
end

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
            widget = g_ui.createWidget(layout, actionbar.tabBar)
            widget:setId(n .. "." .. i)
        end
        resetButtonCache(widget)
        if g_game.isOnline() then
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
function ActionBarController:onInit()
    g_ui.importStyle("otui/style.otui")
    gameRootPanel = modules.game_interface.getRootPanel()
    mouseGrabberWidget = g_ui.createWidget('UIWidget')
    mouseGrabberWidget:setVisible(false)
    mouseGrabberWidget:setFocusable(false)
    mouseGrabberWidget.onMouseRelease = onDropActionButton
end

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

function ActionBarController:onGameStart()
    onCreateActionBars()
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
            if cache.isSpell or cache.isRuneSpell then
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
            if not cache.isRuneSpell and cache.spellData then
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

function onPassiveData(currentCooldown, maxCooldown, canDecay)
    passiveData = {
        cooldown = currentCooldown,
        max = maxCooldown
    }
    updateActionPassive()
end

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

function onUpdateLevel(localPlayer, level, levelPercent, oldLevel, oldLevelPercent)
    if level ~= oldLevel then
        onUpdateActionBarStatus()
    end
end

function onMultiUseCooldown(multiUseCooldown)
    for _, actionbar in pairs(activeActionBars) do
        for _, button in pairs(actionbar.tabBar:getChildren()) do
            updateButtonState(button)
            if multiUseCooldown and button.item and button.cache.itemId then
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

-- Export function for external modules to call when panel visibility changes
function updateVisibleWidgetsExternal()
    -- Call the updateVisibleWidgets function from ActionBarLayout.lua
    -- The function should be available globally since all logic files are loaded
    updateVisibleWidgets()
end

function selectHotkeySet(name)
    if not ApiJson or not ApiJson.setCurrentHotkeySetName then
        return false
    end

    if not ApiJson.setCurrentHotkeySetName(name) then
        return false
    end

    ApiJson.saveData()

    if #actionBars == 0 then
        return true
    end

    for _, actionbar in pairs(actionBars) do
        if actionbar and not actionbar:isDestroyed() then
            unbindActionBarEvent(actionbar)
        end
    end

    for i = 1, #actionBars do
        setupActionBar(i)
    end

    updateVisibleWidgets()
    updateActionBarEventSubscriptions()

    return true
end

function createHotkeySet(name, sourceName)
    if not ApiJson or not ApiJson.createHotkeySet then
        return false
    end

    local ok = ApiJson.createHotkeySet(name, sourceName)
    if ok then
        ApiJson.saveData()
    end
    return ok
end

function renameHotkeySet(oldName, newName)
    if not ApiJson or not ApiJson.renameHotkeySet then
        return false
    end

    local ok = ApiJson.renameHotkeySet(oldName, newName)
    if ok then
        ApiJson.saveData()
    end
    return ok
end

function removeHotkeySet(name)
    if not ApiJson or not ApiJson.removeHotkeySet then
        return false
    end

    local ok = ApiJson.removeHotkeySet(name)
    if ok then
        ApiJson.saveData()
    end
    return ok
end
