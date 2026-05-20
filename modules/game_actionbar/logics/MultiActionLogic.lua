-- /*=============================================
-- =         Multi-Action state globals         =
-- =============================================*/
multiPanel = nil
cacheMultiActionButtons = {}
multiActionCooldownEvents = {}

local function splitButtonId(button)
    return string.match(button:getId(), "(.*)%.(.*)")
end

local function countFilledMultiSlots(multiActions)
    if not multiActions then
        return 0
    end
    local count = 0
    for i = 1, 3 do
        if type(multiActions[i]) == "table" and next(multiActions[i]) ~= nil then
            count = count + 1
        end
    end
    return count
end

local function localGetActionName(actionType)
    if type(actionType) == "string" then
        return actionType
    end
    return getActionName(actionType)
end

local function clearSingleActionCache(button, barID, buttonID)
    button.cache.param = ""
    button.cache.sendAutomatic = false
    button.cache.itemId = 0
    button.cache.actionType = 0
    button.cache.upgradeTier = 0
    button.cache.smartMode = false

    local entry = ApiJson.getMapping(tonumber(barID), tonumber(buttonID))
    local actionsetting = entry and entry["actionsetting"]
    if actionsetting then
        actionsetting["chatText"] = nil
        actionsetting["sendAutomatically"] = nil
        actionsetting["useObject"] = nil
        actionsetting["useType"] = nil
        actionsetting["upgradeTier"] = nil
        actionsetting["useEquipSmartMode"] = nil
    end
end

local function playerCanUseSpellLocal(spellData)
    if not g_game.isOnline() or not spellData then
        return false
    end
    if spellData.needLearn and not spellListData[tostring(spellData.id)] then
        return false
    end
    if spellData.mana and player and player:getMana() < spellData.mana then
        return false
    end
    if spellData.level and player and player:getLevel() < spellData.level then
        return false
    end
    if spellData.soul and player and player:getSoul() < spellData.soul then
        return false
    end
    if spellData.vocations and player and
        not table.contains(spellData.vocations, translateVocation(player:getVocation())) then
        return false
    end
    return true
end

local function hasActiveSpellCooldown(spellId)
    local cooldownData = spellCooldownCache[spellId]
    if cooldownData and (cooldownData.startTime + cooldownData.exhaustion) > g_clock.millis() then
        return true
    end
    return false
end

local function getSpellCooldownRemaining(spellId)
    local cooldownData = spellCooldownCache[spellId]
    if not cooldownData then
        return 0
    end
    local remaining = (cooldownData.startTime + cooldownData.exhaustion) - g_clock.millis()
    return remaining > 0 and remaining or 0
end

local function getSpellGroupCooldownRemaining(spellData)
    if not spellData or not spellData.group or not spellGroupCooldownCache then
        return 0
    end

    local groupIds = spellData._cachedGroupIds or Spells.getGroupIds(spellData)
    if not groupIds then
        return 0
    end

    local maxRemaining = 0
    local now = g_clock.millis()
    for _, groupId in pairs(groupIds) do
        local groupCooldown = spellGroupCooldownCache[groupId]
        if groupCooldown then
            local remaining = (groupCooldown.startTime + groupCooldown.exhaustion) - now
            if remaining > maxRemaining then
                maxRemaining = remaining
            end
        end
    end
    return maxRemaining > 0 and maxRemaining or 0
end

local function applySpellCooldownsToButton(button, spellData)
    if not button or not spellData then
        return
    end

    checkRemainSpellCooldown(button, spellData.id)
    if not hasActiveSpellCooldown(spellData.id) then
        local groupCooldownRemaining = getSpellGroupCooldownRemaining(spellData)
        if groupCooldownRemaining > 0 then
            updateCooldown(button, groupCooldownRemaining)
            if button.cache.removeCooldownEvent then
                removeEvent(button.cache.removeCooldownEvent)
            end
            button.cache.removeCooldownEvent = scheduleEvent(function()
                removeCooldown(button)
            end, groupCooldownRemaining)
        end
    end
end

-- /*=============================================
-- =           Rotation engine                   =
-- =============================================*/
local function findNextAvailableAction(multiActions)
    if not multiActions or table.empty(multiActions) then
        return nil
    end

    local bestAction = nil
    local closestCooldownAction = nil
    local closestCooldownTime = math.huge
    local firstValidAction = nil
    local onlyOneSpell = true
    local firstSpellData = nil
    local spellCount = 0

    for i, data in ipairs(multiActions) do
        if not data or table.empty(data) then
            goto continue
        end

        if data["chatText"] then
            local spellData = Spells.getSpellDataByParamWords(data["chatText"]:lower())
            if spellData then
                spellCount = spellCount + 1
                if not firstSpellData then
                    firstSpellData = spellData
                elseif firstSpellData.id ~= spellData.id then
                    onlyOneSpell = false
                end

                local canUse = playerCanUseSpellLocal(spellData)
                if not canUse and onlyOneSpell and spellCount == 1 then
                    firstValidAction = firstValidAction or data
                    goto continue
                end

                if not canUse then
                    goto continue
                end

                firstValidAction = firstValidAction or data
                local spellCooldownRemaining = getSpellCooldownRemaining(spellData.id)
                local groupCooldownRemaining = getSpellGroupCooldownRemaining(spellData)
                local totalCooldownRemaining = math.max(spellCooldownRemaining, groupCooldownRemaining)

                if totalCooldownRemaining <= 0 then
                    bestAction = bestAction or data
                elseif totalCooldownRemaining < closestCooldownTime then
                    closestCooldownTime = totalCooldownRemaining
                    closestCooldownAction = data
                end
            else
                firstValidAction = firstValidAction or data
                bestAction = bestAction or data
            end
        elseif data["useObject"] then
            local itemId = data["useObject"]
            local upgradeTier = data["upgradeTier"] or 0
            local itemCount = player and player:getInventoryCount(itemId, upgradeTier) or 0
            firstValidAction = firstValidAction or data

            local runeSpellData = Spells.getRuneSpellByItem(itemId)
            if runeSpellData then
                local spellCooldownRemaining = getSpellCooldownRemaining(runeSpellData.id)
                local groupCooldownRemaining = getSpellGroupCooldownRemaining(runeSpellData)
                local totalCooldownRemaining = math.max(spellCooldownRemaining, groupCooldownRemaining)

                if totalCooldownRemaining <= 0 and itemCount > 0 then
                    bestAction = bestAction or data
                elseif itemCount > 0 and totalCooldownRemaining < closestCooldownTime then
                    closestCooldownTime = totalCooldownRemaining
                    closestCooldownAction = data
                end
            elseif itemCount > 0 then
                bestAction = bestAction or data
            end
        end

        ::continue::
    end

    return bestAction or closestCooldownAction or firstValidAction
end

-- /*=============================================
-- =    Shared slot rendering helper             =
-- =============================================*/
local function renderSlotOnWidget(widget, slotData, isMainButton)
    if not widget or not slotData or table.empty(slotData) then
        return
    end

    if slotData["useObject"] then
        if isMainButton then
            widget.cache.isSpell = false
            widget.cache.isRuneSpell = false
            widget.cache.spellID = 0
            widget.cache.spellData = nil
            widget.cache.primaryGroup = nil
            widget.item.text:setImageSource("")
            widget.item.text:setText("")
        end

        widget.item:setItemId(slotData["useObject"], true)
        widget.item:setOn(true)
        widget.cache.itemId = slotData["useObject"]
        widget.cache.upgradeTier = slotData["upgradeTier"] or 0
        widget.cache.smartMode = slotData["useEquipSmartMode"] or false
        local useTypeName = localGetActionName(slotData["useType"]) or "Use"
        widget.cache.actionType = UseTypes[useTypeName] or UseTypes["Use"]

        local itemCount = player and player:getInventoryCount(widget.cache.itemId, widget.cache.upgradeTier) or 0
        widget.item:setItemCount(itemCount)
        if widget.item.text and widget.item.text.gray then
            widget.item.text.gray:setVisible(itemCount == 0)
        end
        if widget.cache.actionType == UseTypes["Equip"] then
            local equipped = player and player:hasEquippedItemId(widget.cache.itemId, widget.cache.upgradeTier)
            widget.item:setChecked(itemCount ~= 0 and equipped)
        end

        local runeSpellData = Spells.getRuneSpellByItem(widget.cache.itemId)
        if runeSpellData then
            widget.cache.isRuneSpell = true
            widget.cache.spellData = runeSpellData
            local groupIds = Spells.getGroupIds(runeSpellData)
            widget.cache.primaryGroup = groupIds and groupIds[1] or nil
            applySpellCooldownsToButton(widget, runeSpellData)
        end
    elseif slotData["chatText"] then
        local spellData, param = Spells.getSpellDataByParamWords(slotData["chatText"]:lower())
        if spellData then
            local spellId = spellData.clientId
            if spellId then
                local source = SpelllistSettings['Default'].iconFile
                local clip = Spells.getImageClip(spellId, 'Default')
                widget.item.text:setText("")
                widget.item.text:setImageSource(source)
                widget.item.text:setImageClip(clip)
            end
            widget.cache.isSpell = true
            widget.cache.spellID = spellData.id
            widget.cache.spellData = spellData
            local groupIds = Spells.getGroupIds(spellData)
            widget.cache.primaryGroup = groupIds and groupIds[1] or nil

            if param then
                local formatedParam = param:gsub('"', '')
                widget.parameterText:setText(short_text('"' .. formatedParam, 4))
                widget.cache.castParam = formatedParam
            elseif isMainButton then
                widget.parameterText:setText("")
                widget.cache.castParam = nil
            end

            if widget.item.text and widget.item.text.gray then
                widget.item.text.gray:setVisible(not playerCanUseSpellLocal(spellData))
            end

            widget.cache.isRuneSpell = false
            applySpellCooldownsToButton(widget, spellData)
        else
            if isMainButton then
                widget.cache.isSpell = false
                widget.cache.isRuneSpell = false
                widget.cache.spellID = 0
                widget.cache.spellData = nil
                widget.cache.primaryGroup = nil
                widget.item.text:setImageSource("")
            end
            widget.item.text:setText(short_text(slotData["chatText"], 15))
        end
        widget.item:setOn(true)
        widget.cache.param = slotData["chatText"]
        widget.cache.sendAutomatic = slotData["sendAutomatically"]
        widget.cache.actionType = UseTypes["chatText"]
    end

    setupButtonTooltip(widget, false)
end

function updateMultiButtonState(button)
    if not button or not button.item or not player or not button.cache then
        return
    end
    if not button.cache.multiActions or table.empty(button.cache.multiActions) then
        if updateButton then
            updateButton(button)
        end
        return
    end

    local action = findNextAvailableAction(button.cache.multiActions)
    if not action then
        action = button.cache.multiActions[1]
    end
    if not action or table.empty(action) then
        return
    end

    -- Early return: already displaying this chatText action
    if action["chatText"] and button.cache.param == action["chatText"] and button.cache.sendAutomatic ==
        action["sendAutomatically"] and button.cache.actionType == UseTypes["chatText"] then
        return
    end

    -- Early return: already displaying this useObject action
    if action["useObject"] and button.cache.itemId == action["useObject"] then
        local useTypeName = localGetActionName(action["useType"]) or "Use"
        if button.cache.actionType == (UseTypes[useTypeName] or UseTypes["Use"]) then
            return
        end
    end

    removeCooldown(button)
    renderSlotOnWidget(button, action, true)

    if button.multiIcon then
        button.multiIcon:setVisible(countFilledMultiSlots(button.cache.multiActions) >= 2)
    end
    if cacheMultiActionButtons then
        cacheMultiActionButtons[button] = true
    end
end

-- /*=============================================
-- =         Cooldown event scheduling           =
-- =============================================*/
function scheduleMultiActionCooldownEvent(button, eventKey, delay)
    if not button or not eventKey or not delay then
        return
    end

    local buttonId = button:getId()
    if not multiActionCooldownEvents[buttonId] then
        multiActionCooldownEvents[buttonId] = {}
    end

    if multiActionCooldownEvents[buttonId][eventKey] then
        removeEvent(multiActionCooldownEvents[buttonId][eventKey])
    end

    local eventId = scheduleEvent(function()
        if button and not button:isDestroyed() then
            updateMultiButtonState(button)
        end
        if multiActionCooldownEvents[buttonId] then
            multiActionCooldownEvents[buttonId][eventKey] = nil
        end
    end, delay + 100)

    multiActionCooldownEvents[buttonId][eventKey] = eventId
end

function registerMultiActionCooldownEvents(button)
    if not button or not button.cache or not button.cache.multiActions or table.empty(button.cache.multiActions) then
        return
    end

    local buttonId = button:getId()
    if multiActionCooldownEvents[buttonId] then
        for _, eventId in pairs(multiActionCooldownEvents[buttonId]) do
            removeEvent(eventId)
        end
        multiActionCooldownEvents[buttonId] = nil
    end

    for _, actionData in pairs(button.cache.multiActions) do
        if actionData and actionData["chatText"] then
            local spellData = Spells.getSpellDataByParamWords(actionData["chatText"]:lower())
            if spellData then
                local remaining = math.max(getSpellCooldownRemaining(spellData.id),
                    getSpellGroupCooldownRemaining(spellData))
                if remaining > 0 then
                    local eventKey = "spell_" .. spellData.id
                    scheduleMultiActionCooldownEvent(button, eventKey, remaining)
                end
            end
        elseif actionData and actionData["useObject"] then
            local runeSpellData = Spells.getRuneSpellByItem(actionData["useObject"])
            if runeSpellData then
                local remaining = math.max(getSpellCooldownRemaining(runeSpellData.id),
                    getSpellGroupCooldownRemaining(runeSpellData))
                if remaining > 0 then
                    local eventKey = "rune_" .. runeSpellData.id
                    scheduleMultiActionCooldownEvent(button, eventKey, remaining)
                end
            end
        end
    end
end

function clearMultiActionCooldownEvents(buttonId)
    if not buttonId or not multiActionCooldownEvents[buttonId] then
        return
    end
    for _, eventId in pairs(multiActionCooldownEvents[buttonId]) do
        removeEvent(eventId)
    end
    multiActionCooldownEvents[buttonId] = nil
end

-- /*=============================================
-- =         Multi-action slot dialogs           =
-- =============================================*/
function assignMultiActionSpell(button, multiButtonIndex)
    assignSpell(button, multiButtonIndex)
end

function assignMultiText(button, multiButtonIndex)
    assignText(button, multiButtonIndex)
end

function assignMultiItem(button, multiButtonIndex, itemId, itemTier, dragEvent)
    assignItem(button, itemId, itemTier or 0, dragEvent, multiButtonIndex)
end

-- /*=============================================
-- =         Popup layout / position             =
-- =============================================*/
function getMultiActionLayout(barN)
    barN = tonumber(barN) or 1
    if barN >= 1 and barN <= 3 then
        return "BottomMultiAction"
    elseif barN >= 4 and barN <= 6 then
        return "LeftMultiAction"
    elseif barN >= 7 and barN <= 9 then
        return "RightMultiAction"
    end
    return "BottomMultiAction"
end

function getMultiActionPosition(button)
    local actionbar = button:getParent():getParent()
    local barN = actionbar and actionbar.n or 1

    if barN >= 1 and barN <= 3 then
        return topoint(string.format("%s %s", button:getX() - 29, button:getY() - 116))
    elseif barN >= 4 and barN <= 6 then
        return topoint(string.format("%s %s", button:getX() + 34, button:getY() - 29))
    elseif barN >= 7 and barN <= 9 then
        return topoint(string.format("%s %s", button:getX() - 116, button:getY() - 29))
    end
    return button:getPosition()
end

-- /*=============================================
-- =         Cleanup                             =
-- =============================================*/
function closeCurrentMultiActionPanel()
    if dragButton and dragItem then
        local reparentedDragItem = false
        if dragButton.multiButtonIndex and dragButton.parentButton then
            if dragItem and not dragItem:isDestroyed() then
                dragItem:setPhantom(false)
                dragItem:setParent(dragButton)
                dragItem:fill('parent')
                reparentedDragItem = true
            end
            if dragButton.cooldown then
                dragButton.cooldown:setBorderWidth(0)
            end
            if dragButton.cache then
                dragButton.cache.isDragging = false
            end
        end
        if not reparentedDragItem and dragItem and not dragItem:isDestroyed() then
            dragItem:destroy()
        end
        dragButton = nil
        dragItem = nil
    end

    if multiPanel then
        local refButton = multiPanel.button
        if refButton then
            refButton.onGeometryChange = nil
            refButton.onVisibilityChange = nil
            refButton.multiPanel = nil
        end
        if gameRootPanel then
            gameRootPanel.onMouseRelease = multiPanel.prevMouseReleaseHandler
        end
        if not multiPanel:isDestroyed() then
            multiPanel:destroy()
        end
        multiPanel = nil
    end
end

-- /*=============================================
-- =         Right-click menu inside panel       =
-- =============================================*/
function onMultiActionButtonMouseRelease(actionButton, mousePos, mouseButton, parentButton, data)
    if mouseButton ~= MouseRightButton then
        return
    end

    local multiButtonIndex = tonumber(string.match(actionButton:getId(), "actionButton(.*)"))
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)

    menu:addOption(actionButton.cache and actionButton.cache.isSpell and tr('Edit Spell') or tr('Assign Spell'),
        function()
            assignMultiActionSpell(parentButton, multiButtonIndex)
        end)

    if actionButton.item and actionButton.item:getItemId() > 100 then
        menu:addOption(tr('Edit Object'), function()
            assignMultiItem(parentButton, multiButtonIndex, actionButton.item:getItemId(), 0, false)
        end)
    else
        menu:addOption(tr('Assign Object'), function()
            assignItemEvent(parentButton, multiButtonIndex)
        end)
    end

    local hasText = actionButton.item and actionButton.item.text and actionButton.item.text:getText():len() > 0
    menu:addOption(hasText and tr('Edit Text') or tr('Assign Text'), function()
        assignMultiText(parentButton, multiButtonIndex)
    end)

    if data and not table.empty(data) then
        menu:addSeparator()
        menu:addOption(tr("Clear Action"), function()
            if parentButton.cache.multiActions and parentButton.cache.multiActions[multiButtonIndex] then
                local barID, buttonID = splitButtonId(parentButton)
                ApiJson.removeMultiAction(tonumber(barID), tonumber(buttonID), multiButtonIndex)
                parentButton.cache.multiActions[multiButtonIndex] = {}

                if not hasMultiActions(parentButton.cache.multiActions) then
                    parentButton.cache.multiActions = {{}, {}, {}}
                    if parentButton.multiIcon then
                        parentButton.multiIcon:setVisible(false)
                    end
                    cacheMultiActionButtons[parentButton] = nil
                    clearMultiActionCooldownEvents(parentButton:getId())
                    closeCurrentMultiActionPanel()
                    clearButton(parentButton, false)
                else
                    assignMultiAction(parentButton, true)
                    updateMultiButtonState(parentButton)
                end
            end
        end)
    end
    menu:display(mousePos)
end

-- /*=============================================
-- =         Popup creation / refresh            =
-- =============================================*/
local function resetMultiPanelButton(slotButton)
    if not slotButton then
        return
    end
    if slotButton.item then
        if slotButton.item:getItemId() ~= 0 then
            slotButton.item:setItemId(0)
        end
        if slotButton.item:isOn() then
            slotButton.item:setOn(false)
        end
        if slotButton.item:isChecked() then
            slotButton.item:setChecked(false)
        end
        if slotButton.item.text then
            slotButton.item.text:setImageSource("")
            slotButton.item.text:setText("")
            if slotButton.item.text.gray then
                slotButton.item.text.gray:setVisible(false)
            end
        end
        slotButton.item:setDraggable(true)
    end
    if slotButton.parameterText then
        slotButton.parameterText:setText("")
    end
    slotButton.cache = {}
    setupButtonTooltip(slotButton, true)
end

function assignMultiAction(button, skipPrefill)
    if not button then
        return
    end

    local actionbar = button:getParent() and button:getParent():getParent()
    local barN = actionbar and actionbar.n or 1

    if not multiPanel or multiPanel:isDestroyed() or multiPanel.button ~= button then
        if multiPanel and not multiPanel:isDestroyed() then
            if multiPanel.button then
                multiPanel.button.onGeometryChange = nil
                multiPanel.button.onVisibilityChange = nil
                multiPanel.button.multiPanel = nil
            end
            if gameRootPanel then
                gameRootPanel.onMouseRelease = multiPanel.prevMouseReleaseHandler
            end
            multiPanel:destroy()
        end

        multiPanel = g_ui.createWidget(getMultiActionLayout(barN), gameRootPanel)
        button.multiPanel = multiPanel
        multiPanel.button = button

        local prevHandler = gameRootPanel.onMouseRelease
        multiPanel.prevMouseReleaseHandler = prevHandler
        gameRootPanel.onMouseRelease = function(self, mousePos, mouseButton)
            if mouseButton == MouseRightButton then
                if prevHandler then
                    return prevHandler(self, mousePos, mouseButton)
                end
                return false
            end
            if multiPanel and not multiPanel:isDestroyed() and not multiPanel:containsPoint(mousePos) then
                closeCurrentMultiActionPanel()
            end
            if prevHandler then
                return prevHandler(self, mousePos, mouseButton)
            end
            return false
        end

        button.onGeometryChange = function()
            if not multiPanel or multiPanel:isDestroyed() then
                button.onGeometryChange = nil
                button.onVisibilityChange = nil
                return
            end
            multiPanel:setPosition(getMultiActionPosition(button))
        end
        button.onVisibilityChange = function()
            if not multiPanel or multiPanel:isDestroyed() then
                button.onVisibilityChange = nil
                return
            end
            if not button:isVisible() then
                closeCurrentMultiActionPanel()
            end
        end
        multiPanel:setPosition(getMultiActionPosition(button))
    end

    button.cache = getButtonCache(button)
    if not button.cache.multiActions or table.empty(button.cache.multiActions) then
        button.cache.multiActions = {{}, {}, {}}
    end

    local barID, buttonID = splitButtonId(button)

    if not skipPrefill then
        local multiActionsEmpty = true
        for i = 1, 3 do
            if not table.empty(button.cache.multiActions[i] or {}) then
                multiActionsEmpty = false
                break
            end
        end

        if multiActionsEmpty then
            local prefilled = false
            if button.cache.param and button.cache.param ~= "" then
                local param = button.cache.param
                local sendAutomatic = button.cache.sendAutomatic
                button.cache.multiActions[1] = {
                    chatText = param,
                    sendAutomatically = sendAutomatic
                }
                ApiJson.createOrUpdateMultiText(tonumber(barID), tonumber(buttonID), 1, param, sendAutomatic)
                clearSingleActionCache(button, barID, buttonID)
                prefilled = true
            elseif button.cache.itemId and button.cache.itemId > 100 then
                local itemId = button.cache.itemId
                local useType = getActionName(button.cache.actionType) or "Use"
                local upgradeTier = button.cache.upgradeTier or 0
                local smartMode = button.cache.smartMode or false
                button.cache.multiActions[1] = {
                    useObject = itemId,
                    useType = useType,
                    upgradeTier = upgradeTier,
                    useEquipSmartMode = smartMode
                }
                ApiJson.createOrUpdateMultiAction(tonumber(barID), tonumber(buttonID), 1, useType, itemId, upgradeTier,
                    smartMode)
                clearSingleActionCache(button, barID, buttonID)
                prefilled = true
            end
            if prefilled then
                cacheMultiActionButtons[button] = true
            end
        end
    end

    for k = 1, 3 do
        local actionButton = multiPanel:recursiveGetChildById("actionButton" .. k)
        if actionButton then
            local data = button.cache.multiActions[k] or {}

            actionButton.onMouseRelease = function(self, mousePos, mouseBtn)
                local current = button.cache.multiActions[k]
                onMultiActionButtonMouseRelease(self, mousePos, mouseBtn, button, current)
            end

            resetMultiPanelButton(actionButton)
            actionButton.cache = getButtonCache(actionButton)
            actionButton.multiButtonIndex = k
            actionButton.parentButton = button
            if actionButton.item then
                actionButton.item:setDraggable(true)
                actionButton.item.onDragEnter = function(self, mousePos)
                    local current = button.cache.multiActions[k]
                    if not current or table.empty(current) then
                        return false
                    end
                    if actionButton.cooldown then
                        actionButton.cooldown:setBorderWidth(1)
                    end
                    actionButton.cache.isDragging = true
                    dragButton = actionButton
                    dragItem = self
                    return true
                end
                actionButton.item.onDragMove = function(self, mousePos)
                    self:setPhantom(true)
                    self:setParent(gameRootPanel)
                    self:setX(mousePos.x)
                    self:setY(mousePos.y)
                    self:setBorderColor('white')
                    if lastHighlightWidget then
                        lastHighlightWidget:setBorderWidth(0)
                        lastHighlightWidget:setBorderColor('alpha')
                    end
                    local clickedWidget = gameRootPanel:recursiveGetChildByPos(mousePos, false)
                    if not clickedWidget then
                        return true
                    end
                    lastHighlightWidget = clickedWidget
                    lastHighlightWidget:setBorderWidth(1)
                    lastHighlightWidget:setBorderColor('white')
                end
                actionButton.item.onDragLeave = function(self, widget, mousePos)
                    if not actionButton.cache or not actionButton.cache.isDragging then
                        return false
                    end
                    actionButton.cache.isDragging = false
                    onDragMultiActionItemLeave(self, mousePos, actionButton)
                    dragButton = nil
                    dragItem = nil
                end
            end

            if not table.empty(data) then
                renderSlotOnWidget(actionButton, data, false)
            end
        end
    end
end

-- /*=============================================
-- =         Drag/drop from multi slots          =
-- =============================================*/
local function cancelMultiDrag(self, actionButton)
    if self and not self:isDestroyed() then
        self:setPhantom(false)
        self:setParent(actionButton)
        self:fill('parent')
    end
    if actionButton and actionButton.cooldown then
        actionButton.cooldown:setBorderWidth(0)
    end
end

function onDragMultiActionItemLeave(self, mousePos, actionButton)
    if lastHighlightWidget then
        lastHighlightWidget:setBorderWidth(0)
        lastHighlightWidget:setBorderColor('alpha')
        lastHighlightWidget = nil
    end

    local parentButton = actionButton.parentButton
    local sourceIndex = actionButton.multiButtonIndex
    if not parentButton or not sourceIndex then
        cancelMultiDrag(self, actionButton)
        return
    end

    local clickedWidget = gameRootPanel:recursiveGetChildByPos(mousePos, false)

    if clickedWidget and clickedWidget:getParent() then
        local parentId = clickedWidget:getParent():getId() or ""
        local targetIndex = tonumber(string.match(parentId, "actionButton(%d)"))
        if targetIndex and targetIndex >= 1 and targetIndex <= 3 then
            local panel = clickedWidget:getParent():getParent()
            if panel and panel.button then
                local targetParent = panel.button
                local barID, buttonID = splitButtonId(targetParent)
                if targetParent == parentButton then
                    local sourceData = parentButton.cache.multiActions[sourceIndex]
                    local targetData = parentButton.cache.multiActions[targetIndex]

                    cancelMultiDrag(self, actionButton)

                    parentButton.cache.multiActions[sourceIndex] = targetData or {}
                    parentButton.cache.multiActions[targetIndex] = sourceData or {}

                    persistMultiSlot(tonumber(barID), tonumber(buttonID), sourceIndex, targetData)
                    persistMultiSlot(tonumber(barID), tonumber(buttonID), targetIndex, sourceData)

                    updateMultiButtonState(parentButton)
                    assignMultiAction(parentButton, true)
                    return true
                end

                local targetButton = panel.button
                local tBarID, tButtonID = splitButtonId(targetButton)
                local sBarID, sButtonID = splitButtonId(parentButton)
                local sourceData = parentButton.cache.multiActions[sourceIndex]

                persistMultiSlot(tonumber(tBarID), tonumber(tButtonID), targetIndex, sourceData)

                ApiJson.removeMultiAction(tonumber(sBarID), tonumber(sButtonID), sourceIndex)
                parentButton.cache.multiActions[sourceIndex] = {}

                cancelMultiDrag(self, actionButton)
                updateMultiButtonState(targetButton)
                updateMultiButtonState(parentButton)
                assignMultiAction(targetButton, true)
                assignMultiAction(parentButton, true)
                return true
            end
        end
    end

    if not clickedWidget or not clickedWidget:backwardsGetWidgetById("tabBar") then
        cancelMultiDrag(self, actionButton)
        return
    end

    local destButton = nil
    for _, actionbar in pairs(actionBars) do
        for _, btn in pairs(actionbar.tabBar:getChildren()) do
            if btn:getId() == clickedWidget:getParent():getId() then
                destButton = btn
                break
            end
        end
        if destButton then
            break
        end
    end

    if not destButton then
        cancelMultiDrag(self, actionButton)
        return
    end

    if destButton.cache and hasMultiActions(destButton.cache.multiActions) then
        cancelMultiDrag(self, actionButton)
        return
    end

    local barID, buttonID = splitButtonId(parentButton)
    local dBarID, dButtonID = splitButtonId(destButton)
    local sourceData = parentButton.cache.multiActions[sourceIndex]

    if actionButton.cooldown then
        actionButton.cooldown:setBorderWidth(0)
        actionButton.cooldown:setBorderColor('alpha')
    end

    local destHasAction = false
    if destButton.cache.itemId and destButton.cache.itemId > 100 then
        destHasAction = true
        local actionTypeName = localGetActionName(destButton.cache.actionType)
        if actionTypeName then
            ApiJson.createOrUpdateMultiAction(tonumber(barID), tonumber(buttonID), sourceIndex, actionTypeName,
                destButton.cache.itemId, destButton.cache.upgradeTier or 0, destButton.cache.smartMode or false)
            parentButton.cache.multiActions[sourceIndex] = {
                useObject = destButton.cache.itemId,
                useType = actionTypeName,
                upgradeTier = destButton.cache.upgradeTier or 0,
                useEquipSmartMode = destButton.cache.smartMode or false
            }
        end
    elseif destButton.cache.param and destButton.cache.param ~= "" then
        destHasAction = true
        ApiJson.createOrUpdateMultiText(tonumber(barID), tonumber(buttonID), sourceIndex, destButton.cache.param,
            destButton.cache.sendAutomatic)
        parentButton.cache.multiActions[sourceIndex] = {
            chatText = destButton.cache.param,
            sendAutomatically = destButton.cache.sendAutomatic
        }
    end

    if sourceData and not table.empty(sourceData) then
        if sourceData["chatText"] then
            ApiJson.createOrUpdateText(tonumber(dBarID), tonumber(dButtonID), sourceData["chatText"],
                sourceData["sendAutomatically"])
        elseif sourceData["useObject"] then
            local actionTypeName = localGetActionName(sourceData["useType"]) or "Use"
            ApiJson.createOrUpdateAction(tonumber(dBarID), tonumber(dButtonID), actionTypeName, sourceData["useObject"],
                sourceData["upgradeTier"] or 0)
        end
    end

    if not destHasAction then
        ApiJson.removeMultiAction(tonumber(barID), tonumber(buttonID), sourceIndex)
        parentButton.cache.multiActions[sourceIndex] = {}

        if not hasMultiActions(parentButton.cache.multiActions) then
            parentButton.cache.itemId = 0
            parentButton.cache.param = ""
            parentButton.cache.actionType = 0
            if parentButton.multiIcon then
                parentButton.multiIcon:setVisible(false)
            end
            cacheMultiActionButtons[parentButton] = nil
            clearMultiActionCooldownEvents(parentButton:getId())
        end
    end

    cancelMultiDrag(self, actionButton)
    updateButton(destButton)
    updateMultiButtonState(parentButton)
    assignMultiAction(parentButton, true)
end
