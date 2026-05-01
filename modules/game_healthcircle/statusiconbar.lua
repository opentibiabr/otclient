-- Status Icon Bar Module
-- Vertical dynamic bar for player state icons, positioned to the left of health circle.
ConditionsHUD = {}
StatusIconBar = {}

local statusIconPanel = nil
local activeIcons = {} -- conditionId -> widget
local conditionLookup = {}
local visibleConditions = {}

local config = {
    maxIcons = 8,
    iconSize = 20,
    topBottomSize = 10,
    baseMarginRight = 10,
    shrinkTime = 220,
    shrinkInterval = 30
}

local SETTINGS_FILE = '/settings_conditions_hud.json'
local DECORATIVE_CHILD_COUNT = 2
local SELECTED_COLOR = '#585858'
local ROW_COLOR_ODD = '#484848'
local ROW_COLOR_EVEN = '#414141'

local function safeCall(obj, method, ...)
    if obj and type(obj[method]) == 'function' then
        return obj[method](obj, ...)
    end
    return nil
end

local function buildConditionCache()
    conditionLookup = {}
    visibleConditions = {}

    for _, condition in ipairs(ConditionIcons or {}) do
        if condition and condition.id then
            conditionLookup[condition.id] = condition
            if not condition.hidden then
                table.insert(visibleConditions, condition)
            end
        end
    end
end

local function defaultSettings()
    return {
        ordenered = {},
        visibleHud = {},
        visibleBar = {},
        showInHud = true,
        showInBar = true
    }
end

local function normalizeSettings(settings)
    settings = settings or {}

    if type(settings.ordenered) ~= 'table' then
        settings.ordenered = {}
    end
    if type(settings.visibleHud) ~= 'table' then
        settings.visibleHud = {}
    end
    if type(settings.visibleBar) ~= 'table' then
        settings.visibleBar = {}
    end
    if type(settings.showInHud) ~= 'boolean' then
        settings.showInHud = true
    end
    if type(settings.showInBar) ~= 'boolean' then
        settings.showInBar = true
    end

    return settings
end

function ConditionsHUD.syncMissingOrderEntries()
    local order = {}
    local seen = {}

    for _, conditionId in ipairs(ConditionsHUD.settings.ordenered) do
        local condition = conditionLookup[conditionId]
        if condition and not condition.hidden and not seen[conditionId] then
            table.insert(order, conditionId)
            seen[conditionId] = true
        end
    end

    for _, condition in ipairs(visibleConditions) do
        if not seen[condition.id] then
            table.insert(order, condition.id)
        end
    end

    ConditionsHUD.settings.ordenered = order
end

function ConditionsHUD.loadSettings()
    ConditionsHUD.settings = defaultSettings()

    if g_resources.fileExists(SETTINGS_FILE) then
        local status, decoded = pcall(function()
            return json.decode(g_resources.readFileContents(SETTINGS_FILE))
        end)

        if status and type(decoded) == 'table' then
            ConditionsHUD.settings = normalizeSettings(decoded)
        else
            ConditionsHUD.settings = defaultSettings()
        end
    end

    ConditionsHUD.syncMissingOrderEntries()
end

function ConditionsHUD.saveSettings()
    local status, encoded = pcall(function()
        return json.encode(ConditionsHUD.settings, 2)
    end)
    if status and encoded then
        g_resources.writeFileContents(SETTINGS_FILE, encoded)
    end
end

function ConditionsHUD.getOrderedConditions()
    ConditionsHUD.syncMissingOrderEntries()

    local ordered = {}
    for _, conditionId in ipairs(ConditionsHUD.settings.ordenered) do
        local condition = conditionLookup[conditionId]
        if condition and not condition.hidden then
            table.insert(ordered, condition)
        end
    end

    return ordered
end

local function getConditionDefaultVisibility(condition, panel)
    if panel == 'hud' then
        return condition.visibleHud ~= false
    end
    return condition.visibleBar ~= false
end

function ConditionsHUD.isConditionVisible(conditionId, panel)
    local condition = conditionLookup[conditionId]
    if not condition then
        return false
    end

    if panel == 'hud' then
        if not ConditionsHUD.settings.showInHud then
            return false
        end
        local value = ConditionsHUD.settings.visibleHud[conditionId]
        if value == nil then
            return getConditionDefaultVisibility(condition, panel)
        end
        return value
    elseif panel == 'bar' then
        if not ConditionsHUD.settings.showInBar then
            return false
        end
        local value = ConditionsHUD.settings.visibleBar[conditionId]
        if value == nil then
            return getConditionDefaultVisibility(condition, panel)
        end
        return value
    end

    return false
end

function ConditionsHUD.changeVisibilityInHud(conditionId, checked)
    ConditionsHUD.settings.visibleHud[conditionId] = checked
    ConditionsHUD.saveSettings()
    StatusIconBar.refreshIcons()
end

function ConditionsHUD.changeVisibilityInBar(conditionId, checked)
    ConditionsHUD.settings.visibleBar[conditionId] = checked
    ConditionsHUD.saveSettings()
end

function ConditionsHUD.refreshRowStyles()
    if not ConditionsHUD.listWidget then
        return
    end

    local selected = ConditionsHUD.selectedWidget
    local childCount = ConditionsHUD.listWidget:getChildCount()
    for i = 1, childCount do
        local child = ConditionsHUD.listWidget:getChildByIndex(i)
        if child then
            if child == selected then
                child:setBackgroundColor(SELECTED_COLOR)
            else
                child:setBackgroundColor((i % 2 == 0) and ROW_COLOR_EVEN or ROW_COLOR_ODD)
            end
        end
    end
end

function ConditionsHUD.updateMoveButtons()
    if not ConditionsHUD.listWidget or not ConditionsHUD.upButton or not ConditionsHUD.downButton then
        return
    end

    local focused = ConditionsHUD.listWidget:getFocusedChild() or ConditionsHUD.selectedWidget
    if not focused or not ConditionsHUD.listWidget:hasChild(focused) then
        ConditionsHUD.upButton:setEnabled(false)
        ConditionsHUD.downButton:setEnabled(false)
        return
    end

    local index = ConditionsHUD.listWidget:getChildIndex(focused)
    local total = ConditionsHUD.listWidget:getChildCount()
    ConditionsHUD.upButton:setEnabled(index > 1)
    ConditionsHUD.downButton:setEnabled(index < total)
end

function ConditionsHUD.onFocusChanged(widget, focused)
    if not ConditionsHUD.listWidget then
        return
    end

    if focused and widget and ConditionsHUD.listWidget:hasChild(widget) then
        ConditionsHUD.selectedWidget = widget
    elseif ConditionsHUD.selectedWidget == widget then
        ConditionsHUD.selectedWidget = nil
    end

    ConditionsHUD.refreshRowStyles()
    ConditionsHUD.updateMoveButtons()
end

function ConditionsHUD.syncOrderFromList()
    if not ConditionsHUD.listWidget then
        return
    end

    local order = {}
    local childCount = ConditionsHUD.listWidget:getChildCount()
    for i = 1, childCount do
        local child = ConditionsHUD.listWidget:getChildByIndex(i)
        if child then
            local conditionId = child:getId()
            if conditionLookup[conditionId] then
                table.insert(order, conditionId)
            end
        end
    end

    ConditionsHUD.settings.ordenered = order
    ConditionsHUD.syncMissingOrderEntries()
end

function ConditionsHUD.moveSelected(delta)
    if not ConditionsHUD.listWidget then
        return
    end

    local focused = ConditionsHUD.listWidget:getFocusedChild() or ConditionsHUD.selectedWidget
    if not focused or not ConditionsHUD.listWidget:hasChild(focused) then
        return
    end

    local currentIndex = ConditionsHUD.listWidget:getChildIndex(focused)
    local targetIndex = currentIndex + delta
    if targetIndex < 1 or targetIndex > ConditionsHUD.listWidget:getChildCount() then
        return
    end

    ConditionsHUD.listWidget:moveChildToIndex(focused, targetIndex)
    ConditionsHUD.listWidget:focusChild(focused, KeyboardFocusReason)
    ConditionsHUD.selectedWidget = focused

    ConditionsHUD.syncOrderFromList()
    ConditionsHUD.saveSettings()
    ConditionsHUD.refreshRowStyles()
    ConditionsHUD.updateMoveButtons()

    StatusIconBar.refreshIcons()
end

function ConditionsHUD.updateRowCheckboxesState()
    if not ConditionsHUD.listWidget then
        return
    end

    local childCount = ConditionsHUD.listWidget:getChildCount()
    for i = 1, childCount do
        local child = ConditionsHUD.listWidget:getChildByIndex(i)
        if child then
            local hudCheck = child:getChildById('showInHudCheckBox')
            if hudCheck then
                hudCheck:setEnabled(ConditionsHUD.settings.showInHud)
                hudCheck:setOpacity(ConditionsHUD.settings.showInHud and 1.0 or 0.3)
            end

            local barCheck = child:getChildById('showInBarCheckBox')
            if barCheck then
                barCheck:setEnabled(ConditionsHUD.settings.showInBar)
                barCheck:setOpacity(ConditionsHUD.settings.showInBar and 1.0 or 0.3)
            end
        end
    end
end

local function setupMasterCheckboxes(hudWindow)
    local hudMasterCheckBox = hudWindow:recursiveGetChildById('hudMasterCheckBox')
    if hudMasterCheckBox then
        hudMasterCheckBox:setChecked(ConditionsHUD.settings.showInHud)
        hudMasterCheckBox.onCheckChange = function(_, checked)
            ConditionsHUD.settings.showInHud = checked
            ConditionsHUD.saveSettings()
            ConditionsHUD.updateRowCheckboxesState()
            StatusIconBar.refreshIcons()
        end
    end

    local barMasterCheckBox = hudWindow:recursiveGetChildById('barMasterCheckBox')
    if barMasterCheckBox then
        barMasterCheckBox:setChecked(ConditionsHUD.settings.showInBar)
        barMasterCheckBox.onCheckChange = function(_, checked)
            ConditionsHUD.settings.showInBar = checked
            ConditionsHUD.saveSettings()
            ConditionsHUD.updateRowCheckboxesState()
        end
    end
end

local function applyRowIcon(widget, condition)
    if condition.path then
        widget.icon:setImageSource(condition.path)
    else
        widget.icon:setImageSource('/images/game/states/player-state-flags')
        local clipIndex = condition.clip or 1
        local clipX = (clipIndex - 1) * 9
        widget.icon:setImageClip(clipX .. ' 0 9 9')
    end
end

local function createConditionRow(condition, parent)
    local widget = g_ui.createWidget('SpecialConditionLabelSettings', parent)
    widget:setId(condition.id)
    widget:setFocusable(true)
    widget.label:setText(condition.name or condition.id)
    widget:setTooltip(condition.tooltip or '')
    applyRowIcon(widget, condition)

    widget.showInHudCheckBox:setChecked(ConditionsHUD.isConditionVisible(condition.id, 'hud'))
    widget.showInBarCheckBox:setChecked(ConditionsHUD.isConditionVisible(condition.id, 'bar'))

    widget.showInHudCheckBox.onCheckChange = function(_, checked)
        ConditionsHUD.changeVisibilityInHud(condition.id, checked)
    end
    widget.showInBarCheckBox.onCheckChange = function(_, checked)
        ConditionsHUD.changeVisibilityInBar(condition.id, checked)
    end

    widget.onClick = function(self)
        if ConditionsHUD.listWidget then
            ConditionsHUD.listWidget:focusChild(self, MouseFocusReason)
        end
    end

    widget.onFocusChange = function(self, focused)
        ConditionsHUD.onFocusChanged(self, focused)
    end

    return widget
end

function ConditionsHUD.setupHudList()
    local hudWindow = modules.client_options and modules.client_options.panels and modules.client_options.panels.interfaceHUD
    if not hudWindow then
        return false
    end

    local listWidget = hudWindow:recursiveGetChildById('conditionsList')
    if not listWidget then
        return false
    end

    ConditionsHUD.listWidget = listWidget
    ConditionsHUD.upButton = hudWindow:recursiveGetChildById('upButton')
    ConditionsHUD.downButton = hudWindow:recursiveGetChildById('downButton')
    ConditionsHUD.selectedWidget = nil

    listWidget:destroyChildren()

    local orderedConditions = ConditionsHUD.getOrderedConditions()
    for _, condition in ipairs(orderedConditions) do
        createConditionRow(condition, listWidget)
    end

    listWidget.onChildFocusChange = function(self, focusedChild, oldFocused, reason)
        if oldFocused then
            ConditionsHUD.onFocusChanged(oldFocused, false)
        end
        if focusedChild then
            ConditionsHUD.onFocusChanged(focusedChild, true)
        end
    end

    if ConditionsHUD.upButton then
        ConditionsHUD.upButton.onClick = function()
            ConditionsHUD.moveSelected(-1)
        end
    end

    if ConditionsHUD.downButton then
        ConditionsHUD.downButton.onClick = function()
            ConditionsHUD.moveSelected(1)
        end
    end

    setupMasterCheckboxes(hudWindow)
    ConditionsHUD.refreshRowStyles()

    local firstChild = listWidget:getChildByIndex(1)
    if firstChild then
        listWidget:focusChild(firstChild, ActiveFocusReason)
        ConditionsHUD.selectedWidget = firstChild
        ConditionsHUD.refreshRowStyles()
    end

    ConditionsHUD.updateRowCheckboxesState()
    ConditionsHUD.updateMoveButtons()
    return true
end

local function hasAnyGoshnarState(states)
    return Player.isStateActive(states, PlayerStates.GoshnarTaint1) or
        Player.isStateActive(states, PlayerStates.GoshnarTaint2) or
        Player.isStateActive(states, PlayerStates.GoshnarTaint3) or
        Player.isStateActive(states, PlayerStates.GoshnarTaint4) or
        Player.isStateActive(states, PlayerStates.GoshnarTaint5)
end

function StatusIconBar.isConditionActive(player, condition, states)
    if condition.skull then
        return player:getSkull() == condition.skull
    end

    if condition.id == 'emblem' then
        local emblem = player:getEmblem()
        if emblem == nil then
            return false
        end
        if EmblemGreen ~= nil then
            return emblem == EmblemGreen
        end
        return emblem ~= 0
    end

    if condition.id == 'condition_hungry' then
        local regenTime = safeCall(player, 'getRegenerationTime')
        if regenTime ~= nil and regenTime == 0 then
            return true
        end
    end

    if condition.id == 'condition_restingarea' then
        local resting = safeCall(player, 'getRestingAreaProtection')
        if resting ~= nil then
            return resting
        end
    end

    if condition.id == 'condition_taints' then
        local burden = safeCall(player, 'getBurden')
        if burden ~= nil then
            return burden ~= 0
        end
    end

    if condition.id == 'condition_curse' then
        return hasAnyGoshnarState(states)
    end

    if condition.state then
        return Player.isStateActive(states, condition.state)
    end

    return false
end

local function applyIconWidgetStyle(container, condition)
    local icon = container:getChildById('icon')
    if not icon then
        return
    end

    if condition.path then
        icon:setImageSource(condition.path)
    else
        icon:setImageSource('/images/game/states/player-state-flags')
        local clipIndex = condition.clip or 1
        local clipX = (clipIndex - 1) * 9
        icon:setImageClip(clipX .. ' 0 9 9')
    end
end

local function cancelWidgetEvent(widget, eventName)
    if widget and widget[eventName] then
        removeEvent(widget[eventName])
        widget[eventName] = nil
    end
end

local function setWidgetIconOpacity(widget, opacity)
    local icon = widget and widget:getChildById('icon')
    if icon then
        icon:setOpacity(opacity)
    end
end

local function removeIconWidget(widget)
    if not widget or not statusIconPanel or not statusIconPanel:hasChild(widget) then
        return
    end

    cancelWidgetEvent(widget, 'shrinkInEvent')
    cancelWidgetEvent(widget, 'shrinkOutEvent')

    if widget.conditionId then
        activeIcons[widget.conditionId] = nil
    end

    statusIconPanel:removeChild(widget)
    widget:destroy()

    if statusIconPanel:getChildCount() <= DECORATIVE_CHILD_COUNT then
        statusIconPanel:setVisible(false)
    end

    StatusIconBar.updateWidgetHeight()
end

function StatusIconBar.shrinkIn(widget, time)
    if not widget or not statusIconPanel or not statusIconPanel:hasChild(widget) then
        return
    end

    cancelWidgetEvent(widget, 'shrinkInEvent')
    cancelWidgetEvent(widget, 'shrinkOutEvent')

    widget.realHeight = widget.realHeight or widget:getHeight()
    local progress = math.min(1, math.max(0, time / config.shrinkTime))
    local height = math.max(1, math.floor(widget.realHeight * progress))

    widget:setHeight(height)
    setWidgetIconOpacity(widget, progress)

    if progress >= 1 then
        cancelWidgetEvent(widget, 'shrinkInEvent')
        widget:setHeight(widget.realHeight)
        setWidgetIconOpacity(widget, 1.0)
        StatusIconBar.updateWidgetHeight()
        return
    end

    widget.shrinkInEvent = scheduleEvent(function()
        StatusIconBar.shrinkIn(widget, time + config.shrinkInterval)
    end, config.shrinkInterval)

    StatusIconBar.updateWidgetHeight()
end

function StatusIconBar.shrinkOut(widget, time)
    if not widget or not statusIconPanel or not statusIconPanel:hasChild(widget) then
        return
    end

    cancelWidgetEvent(widget, 'shrinkInEvent')
    cancelWidgetEvent(widget, 'shrinkOutEvent')

    widget.realHeight = widget.realHeight or widget:getHeight()
    local opacity = time / config.shrinkTime
    local height = math.floor(widget.realHeight * math.min((time / config.shrinkTime) * 1.5, 1))

    if opacity <= 0 or height <= 0 then
        removeIconWidget(widget)
        return
    end

    setWidgetIconOpacity(widget, opacity)
    widget:setHeight(height)

    widget.shrinkOutEvent = scheduleEvent(function()
        StatusIconBar.shrinkOut(widget, time - config.shrinkInterval)
    end, config.shrinkInterval)

    StatusIconBar.updateWidgetHeight()
end

function StatusIconBar.clearAll()
    for _, container in pairs(activeIcons) do
        cancelWidgetEvent(container, 'shrinkInEvent')
        cancelWidgetEvent(container, 'shrinkOutEvent')
        if statusIconPanel and statusIconPanel:hasChild(container) then
            container:destroy()
        end
    end
    activeIcons = {}

    if statusIconPanel then
        statusIconPanel:setVisible(false)
    end
end

function StatusIconBar.updatePosition()
    if not statusIconPanel or not healthCircle or not g_game.isOnline() then
        return
    end

    local healthX = healthCircle:getX()
    local healthY = healthCircle:getY()
    local healthHeight = imageSizeBroad or 0

    local panelWidth = statusIconPanel:getWidth()
    local panelHeight = statusIconPanel:getHeight()

    local x = healthX - panelWidth - config.baseMarginRight
    local y = healthY + (healthHeight / 2) - (panelHeight / 2)

    statusIconPanel:setX(x)
    statusIconPanel:setY(y)
end

function StatusIconBar.updateWidgetHeight()
    if not statusIconPanel then
        return
    end

    local height = 0
    local childCount = statusIconPanel:getChildCount()
    for i = 1, childCount do
        local child = statusIconPanel:getChildByIndex(i)
        if child then
            height = height + child:getHeight()
            if i > 1 then
                height = height + 1
            end
        end
    end

    statusIconPanel:setHeight(height)
    StatusIconBar.updatePosition()
end

function StatusIconBar.refreshIcons()
    if not statusIconPanel then
        return
    end

    if not g_game.isOnline() then
        StatusIconBar.clearAll()
        return
    end

    local player = g_game.getLocalPlayer()
    if not player then
        StatusIconBar.clearAll()
        return
    end

    local states = player:getStates() or 0
    local activeConditions = {}

    for _, condition in ipairs(ConditionsHUD.getOrderedConditions()) do
        if ConditionsHUD.isConditionVisible(condition.id, 'hud') and
            StatusIconBar.isConditionActive(player, condition, states) then
            table.insert(activeConditions, condition)
            if #activeConditions >= config.maxIcons then
                break
            end
        end
    end

    local activeById = {}
    for _, condition in ipairs(activeConditions) do
        activeById[condition.id] = condition
    end

    for conditionId, container in pairs(activeIcons) do
        if not activeById[conditionId] then
            if not container.shrinkOutEvent and statusIconPanel:hasChild(container) then
                StatusIconBar.shrinkOut(container, config.shrinkTime)
            end
        elseif container.shrinkOutEvent then
            cancelWidgetEvent(container, 'shrinkOutEvent')
            local currentHeight = container:getHeight()
            local currentTime = math.floor((currentHeight / math.max(container.realHeight or 1, 1)) * config.shrinkTime)
            StatusIconBar.shrinkIn(container, currentTime)
        end
    end

    for _, condition in ipairs(activeConditions) do
        local container = activeIcons[condition.id]
        if not container then
            container = g_ui.createWidget('StatusIconContainer', statusIconPanel)
            container:setId('stateicon_' .. condition.id)
            container.conditionId = condition.id
            container.realHeight = container:getHeight()
            container:setHeight(1)
            setWidgetIconOpacity(container, 0.0)
            activeIcons[condition.id] = container
            StatusIconBar.shrinkIn(container, 0)
        else
            container.realHeight = container.realHeight or container:getHeight()
        end

        container:setTooltip(condition.tooltip or '')
        applyIconWidgetStyle(container, condition)
    end

    for index, condition in ipairs(activeConditions) do
        local container = activeIcons[condition.id]
        if container then
            statusIconPanel:moveChildToIndex(container, index + 1)
        end
    end

    statusIconPanel:setVisible(statusIconPanel:getChildCount() > DECORATIVE_CHILD_COUNT)
    StatusIconBar.updateWidgetHeight()
end

local function ensureHudSetup(retries)
    retries = retries or 0
    if ConditionsHUD.setupHudList() then
        return
    end

    if retries > 0 then
        scheduleEvent(function()
            ensureHudSetup(retries - 1)
        end, 200)
    end
end

function StatusIconBar.onStatesChange()
    StatusIconBar.refreshIcons()
end

function StatusIconBar.onSkullChange()
    StatusIconBar.refreshIcons()
end

function StatusIconBar.onEmblemChange()
    StatusIconBar.refreshIcons()
end

function StatusIconBar.onRegenerationChange()
    StatusIconBar.refreshIcons()
end

function StatusIconBar.onGameStart()
    StatusIconBar.refreshIcons()
    StatusIconBar.updatePosition()
end

function StatusIconBar.onGameEnd()
    StatusIconBar.clearAll()
end

function StatusIconBar.init()
    g_ui.importStyle('statusiconbar')
    buildConditionCache()
    ConditionsHUD.loadSettings()

    if not statusIconPanel then
        statusIconPanel = g_ui.createWidget('StatusIconPanel', mapPanel)
        g_ui.createWidget('StatusIconTop', statusIconPanel)
        g_ui.createWidget('StatusIconBottom', statusIconPanel)
        statusIconPanel:setVisible(false)
        statusIconPanel:setHeight(config.topBottomSize * 2 + 1)
        StatusIconBar.updatePosition()
    end

    connect(LocalPlayer, {
        onStatesChange = StatusIconBar.onStatesChange,
        onSkullChange = StatusIconBar.onSkullChange,
        onEmblemChange = StatusIconBar.onEmblemChange,
        onRegenerationChange = StatusIconBar.onRegenerationChange
    })

    connect(g_game, {
        onGameStart = StatusIconBar.onGameStart,
        onGameEnd = StatusIconBar.onGameEnd
    })

    ensureHudSetup(15)

    if g_game.isOnline() then
        StatusIconBar.onGameStart()
    end
end

function StatusIconBar.terminate()
    disconnect(LocalPlayer, {
        onStatesChange = StatusIconBar.onStatesChange,
        onSkullChange = StatusIconBar.onSkullChange,
        onEmblemChange = StatusIconBar.onEmblemChange,
        onRegenerationChange = StatusIconBar.onRegenerationChange
    })

    disconnect(g_game, {
        onGameStart = StatusIconBar.onGameStart,
        onGameEnd = StatusIconBar.onGameEnd
    })

    StatusIconBar.clearAll()

    if statusIconPanel then
        statusIconPanel:destroy()
        statusIconPanel = nil
    end

    ConditionsHUD.listWidget = nil
    ConditionsHUD.upButton = nil
    ConditionsHUD.downButton = nil
    ConditionsHUD.selectedWidget = nil
end

function StatusIconBar.getPanel()
    return statusIconPanel
end

function StatusIconBar.isVisible()
    return statusIconPanel and statusIconPanel:isVisible()
end
