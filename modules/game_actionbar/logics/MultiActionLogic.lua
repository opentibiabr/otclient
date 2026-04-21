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
    if not multiActions then return 0 end
    local count = 0
    for i = 1, 3 do
        if type(multiActions[i]) == "table" and next(multiActions[i]) ~= nil then
            count = count + 1
        end
    end
    return count
end

local function getActionName(actionType)
    if type(actionType) == "string" then
        return actionType
    end
    for k, v in pairs(UseTypes) do
        if v == actionType then
            return k
        end
    end
    return nil
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

-- /*=============================================
-- =           Rotation engine                   =
-- =============================================*/
local function findNextAvailableAction(multiActions, currentSpellId, forceRotation)
    if not multiActions or table.empty(multiActions) then
        return nil
    end

    local bestAction = nil
    local closestCooldownAction = nil
    local closestCooldownTime = math.huge
    local firstValidAction = nil
    local onlyOneSpell = true
    local firstSpellId = nil
    local spellCount = 0

    for i, data in ipairs(multiActions) do
        if data and not table.empty(data) then
            if data["chatText"] then
                local spellData = Spells.getSpellDataByParamWords(data["chatText"]:lower())
                if spellData then
                    spellCount = spellCount + 1
                    if not firstSpellId then
                        firstSpellId = spellData.id
                    elseif firstSpellId ~= spellData.id then
                        onlyOneSpell = false
                    end

                    local canUse = playerCanUseSpellLocal(spellData)
                    if not canUse and onlyOneSpell and spellCount == 1 then
                        if not firstValidAction then
                            firstValidAction = data
                        end
                    elseif canUse then
                        if not firstValidAction then
                            firstValidAction = data
                        end
                        local inCooldown = hasActiveSpellCooldown(spellData.id)
                        if not inCooldown then
                            if not bestAction then
                                bestAction = data
                            end
                        else
                            local remaining = getSpellCooldownRemaining(spellData.id)
                            if remaining > 0 and remaining < closestCooldownTime then
                                closestCooldownTime = remaining
                                closestCooldownAction = data
                            end
                        end
                    end
                else
                    if not firstValidAction then
                        firstValidAction = data
                    end
                    if not bestAction then
                        bestAction = data
                    end
                end
            elseif data["useObject"] then
                local itemId = data["useObject"]
                local upgradeTier = data["upgradeTier"] or 0
                local itemCount = player and player:getInventoryCount(itemId, upgradeTier) or 0
                if not firstValidAction then
                    firstValidAction = data
                end

                local runeSpellData = Spells.getRuneSpellByItem(itemId)
                if runeSpellData then
                    local inCooldown = hasActiveSpellCooldown(runeSpellData.id)
                    if not inCooldown and itemCount > 0 then
                        if not bestAction then
                            bestAction = data
                        end
                    elseif itemCount > 0 then
                        local remaining = getSpellCooldownRemaining(runeSpellData.id)
                        if remaining > 0 and remaining < closestCooldownTime then
                            closestCooldownTime = remaining
                            closestCooldownAction = data
                        end
                    end
                else
                    if itemCount > 0 then
                        if not bestAction then
                            bestAction = data
                        end
                    end
                end
            end
        end
    end

    if bestAction then
        return bestAction
    elseif closestCooldownAction then
        return closestCooldownAction
    else
        return firstValidAction
    end
end

function updateMultiButtonState(button, forceRotation)
    if not button or not button.item or not player or not button.cache then
        return
    end
    if not button.cache.multiActions or table.empty(button.cache.multiActions) then
        if updateButton then
            updateButton(button)
        end
        return
    end

    local currentSpellId = nil
    if forceRotation and button.cache.isSpell and button.cache.spellID then
        currentSpellId = button.cache.spellID
    elseif button.cache.isSpell and button.cache.spellID and hasActiveSpellCooldown(button.cache.spellID) then
        currentSpellId = button.cache.spellID
    end

    local action = findNextAvailableAction(button.cache.multiActions, currentSpellId, forceRotation)
    if not action then
        action = button.cache.multiActions[1]
    end
    if not action or table.empty(action) then
        return
    end

    if action["chatText"] and button.cache.param == action["chatText"] and
        button.cache.sendAutomatic == action["sendAutomatically"] and
        button.cache.actionType == UseTypes["chatText"] then
        return
    end

    removeCooldown(button)

    if action["useObject"] then
        button.cache.isSpell = false
        button.cache.spellID = 0
        button.cache.spellData = nil
        button.cache.primaryGroup = nil
        button.item.text:setImageSource("")
        button.item.text:setText("")

        button.item:setItemId(action["useObject"], true)
        button.item:setOn(true)
        button.cache.itemId = action["useObject"]
        button.cache.upgradeTier = action["upgradeTier"] or 0
        button.cache.smartMode = action["useEquipSmartMode"] or false
        local useTypeName = getActionName(action["useType"]) or "Use"
        button.cache.actionType = UseTypes[useTypeName] or UseTypes["Use"]
        setupButtonTooltip(button, false)

        local itemCount = player and player:getInventoryCount(button.cache.itemId, button.cache.upgradeTier) or 0
        button.item:setItemCount(itemCount)
        if button.item.text and button.item.text.gray then
            button.item.text.gray:setVisible(itemCount == 0)
        end
        if button.cache.actionType == UseTypes["Equip"] then
            local equipped = player and player:hasEquippedItemId(button.cache.itemId, button.cache.upgradeTier)
            button.item:setChecked(itemCount ~= 0 and equipped)
        end
    elseif action["chatText"] then
        local spellData, param = Spells.getSpellDataByParamWords(action["chatText"]:lower())
        if spellData then
            local spellId = spellData.clientId
            if spellId then
                local source = SpelllistSettings['Default'].iconFile
                local clip = Spells.getImageClip(spellId, 'Default')
                button.item.text:setText("")
                button.item.text:setImageSource(source)
                button.item.text:setImageClip(clip)
            end
            button.cache.isSpell = true
            button.cache.spellID = spellData.id
            button.cache.spellData = spellData
            button.cache.primaryGroup = spellData.group and Spells.getGroupIds(spellData) and
                                            Spells.getGroupIds(spellData)[1] or nil

            if param then
                local formatedParam = param:gsub('"', '')
                button.parameterText:setText(short_text('"' .. formatedParam, 4))
                button.cache.castParam = formatedParam
            else
                button.parameterText:setText("")
                button.cache.castParam = nil
            end

            if button.item.text and button.item.text.gray then
                button.item.text.gray:setVisible(not playerCanUseSpellLocal(spellData))
            end

            checkRemainSpellCooldown(button, spellData.id)
        else
            button.cache.isSpell = false
            button.cache.spellID = 0
            button.cache.spellData = nil
            button.cache.primaryGroup = nil
            button.item.text:setImageSource("")
            button.item.text:setText(short_text(action["chatText"], 15))
        end
        button.item:setOn(true)
        button.cache.param = action["chatText"]
        button.cache.sendAutomatic = action["sendAutomatically"]
        button.cache.actionType = UseTypes["chatText"]
        setupButtonTooltip(button, false)
    end

    if button.multiIcon then
        button.multiIcon:setVisible(countFilledMultiSlots(button.cache.multiActions) >= 2)
    end
    if cacheMultiActionButtons and not table.contains(cacheMultiActionButtons, button) then
        table.insert(cacheMultiActionButtons, button)
    end
end

-- /*=============================================
-- =         Cooldown event scheduling           =
-- =============================================*/
function registerMultiActionCooldownEvents(button)
    if not button or not button.cache or not button.cache.multiActions or
        table.empty(button.cache.multiActions) then
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
                local cooldownData = spellCooldownCache[spellData.id]
                if cooldownData then
                    local remaining = (cooldownData.startTime + cooldownData.exhaustion) - g_clock.millis()
                    if remaining > 0 then
                        if not multiActionCooldownEvents[buttonId] then
                            multiActionCooldownEvents[buttonId] = {}
                        end
                        local eventKey = "spell_" .. spellData.id
                        local eventId = scheduleEvent(function()
                            updateMultiButtonState(button, true)
                            if multiActionCooldownEvents[buttonId] then
                                multiActionCooldownEvents[buttonId][eventKey] = nil
                            end
                        end, remaining + 100)
                        multiActionCooldownEvents[buttonId][eventKey] = eventId
                    end
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
        if dragButton.multiButtonIndex and dragButton.parentButton then
            if dragItem and not dragItem:isDestroyed() then
                dragItem:setPhantom(false)
                dragItem:setParent(dragButton)
                dragItem:fill('parent')
            end
            if dragButton.cooldown then
                dragButton.cooldown:setBorderWidth(0)
            end
            if dragButton.cache then
                dragButton.cache.isDragging = false
            end
        end
        if dragItem and not dragItem:isDestroyed() then
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
        gameRootPanel.onMouseRelease = multiPanel.prevMouseReleaseHandler
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

                local allEmpty = true
                for i = 1, 3 do
                    if not table.empty(parentButton.cache.multiActions[i] or {}) then
                        allEmpty = false
                        break
                    end
                end

                if allEmpty then
                    parentButton.cache.multiActions = {{}, {}, {}}
                    if parentButton.multiIcon then
                        parentButton.multiIcon:setVisible(false)
                    end
                    table.removevalue(cacheMultiActionButtons, parentButton)
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
            end
            gameRootPanel.onMouseRelease = multiPanel.prevMouseReleaseHandler
            multiPanel:destroy()
        end

        multiPanel = g_ui.createWidget(getMultiActionLayout(barN), gameRootPanel)
        button.multiPanel = multiPanel
        multiPanel.button = button

        local prevHandler = gameRootPanel.onMouseRelease
        multiPanel.prevMouseReleaseHandler = prevHandler
        gameRootPanel.onMouseRelease = function(self, mousePos, mouseButton)
            if mouseButton == MouseRightButton then
                if prevHandler then return prevHandler(self, mousePos, mouseButton) end
                return false
            end
            if multiPanel and not multiPanel:isDestroyed() and not multiPanel:containsPoint(mousePos) then
                closeCurrentMultiActionPanel()
            end
            if prevHandler then return prevHandler(self, mousePos, mouseButton) end
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
                button.cache.multiActions[1] = {
                    chatText = button.cache.param,
                    sendAutomatically = button.cache.sendAutomatic
                }
                ApiJson.createOrUpdateMultiText(tonumber(barID), tonumber(buttonID), 1, button.cache.param,
                    button.cache.sendAutomatic)
                prefilled = true
            elseif button.cache.itemId and button.cache.itemId > 100 then
                button.cache.multiActions[1] = {
                    useObject = button.cache.itemId,
                    useType = getActionName(button.cache.actionType) or "Use",
                    upgradeTier = button.cache.upgradeTier or 0,
                    useEquipSmartMode = button.cache.smartMode or false
                }
                ApiJson.createOrUpdateMultiAction(tonumber(barID), tonumber(buttonID), 1,
                    getActionName(button.cache.actionType) or "Use", button.cache.itemId,
                    button.cache.upgradeTier or 0, button.cache.smartMode or false)
                prefilled = true
            end
            if prefilled then
                if not table.contains(cacheMultiActionButtons, button) then
                    table.insert(cacheMultiActionButtons, button)
                end
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
                if data["useObject"] and player then
                    actionButton.item:setItemId(data["useObject"], true)
                    actionButton.item:setOn(true)

                    local itemCount = player:getInventoryCount(data["useObject"], data["upgradeTier"] or 0)
                    actionButton.item:setItemCount(itemCount)
                    if actionButton.item.text and actionButton.item.text.gray then
                        actionButton.item.text.gray:setVisible(itemCount == 0)
                    end
                    local useTypeName = getActionName(data["useType"]) or "Use"
                    actionButton.cache.actionType = UseTypes[useTypeName] or UseTypes["Use"]
                    actionButton.cache.itemId = data["useObject"]
                    actionButton.cache.upgradeTier = data["upgradeTier"] or 0
                    actionButton.cache.smartMode = data["useEquipSmartMode"] or false
                    if actionButton.cache.actionType == UseTypes["Equip"] then
                        local equipped = player:hasEquippedItemId(data["useObject"], data["upgradeTier"] or 0)
                        actionButton.item:setChecked(itemCount ~= 0 and equipped)
                    end
                elseif data["chatText"] then
                    local spellData, param = Spells.getSpellDataByParamWords(data["chatText"]:lower())
                    if spellData then
                        local spellId = spellData.clientId
                        if spellId then
                            local source = SpelllistSettings['Default'].iconFile
                            local clip = Spells.getImageClip(spellId, 'Default')
                            actionButton.item.text:setImageSource(source)
                            actionButton.item.text:setImageClip(clip)
                        end
                        actionButton.cache.isSpell = true
                        actionButton.cache.spellID = spellData.id
                        actionButton.cache.spellData = spellData
                        actionButton.cache.primaryGroup = spellData.group and Spells.getGroupIds(spellData) and
                                                              Spells.getGroupIds(spellData)[1] or nil
                        if param then
                            local formatedParam = param:gsub('"', '')
                            actionButton.parameterText:setText(short_text('"' .. formatedParam, 4))
                            actionButton.cache.castParam = formatedParam
                        end
                        if actionButton.item.text.gray then
                            actionButton.item.text.gray:setVisible(not playerCanUseSpellLocal(spellData))
                        end
                        checkRemainSpellCooldown(actionButton, spellData.id)
                    else
                        actionButton.item.text:setText(short_text(data["chatText"], 15))
                    end
                    actionButton.item:setOn(true)
                    actionButton.cache.param = data["chatText"]
                    actionButton.cache.sendAutomatic = data["sendAutomatically"]
                    actionButton.cache.actionType = UseTypes["chatText"]
                end
                setupButtonTooltip(actionButton, false)
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

                    ApiJson.removeMultiAction(tonumber(barID), tonumber(buttonID), sourceIndex)
                    ApiJson.removeMultiAction(tonumber(barID), tonumber(buttonID), targetIndex)

                    if targetData and not table.empty(targetData) then
                        if targetData["chatText"] then
                            ApiJson.createOrUpdateMultiText(tonumber(barID), tonumber(buttonID), sourceIndex,
                                targetData["chatText"], targetData["sendAutomatically"])
                        elseif targetData["useObject"] then
                            ApiJson.createOrUpdateMultiAction(tonumber(barID), tonumber(buttonID), sourceIndex,
                                getActionName(targetData["useType"]) or "Use", targetData["useObject"],
                                targetData["upgradeTier"] or 0, targetData["useEquipSmartMode"] or false)
                        end
                    end
                    if sourceData and not table.empty(sourceData) then
                        if sourceData["chatText"] then
                            ApiJson.createOrUpdateMultiText(tonumber(barID), tonumber(buttonID), targetIndex,
                                sourceData["chatText"], sourceData["sendAutomatically"])
                        elseif sourceData["useObject"] then
                            ApiJson.createOrUpdateMultiAction(tonumber(barID), tonumber(buttonID), targetIndex,
                                getActionName(sourceData["useType"]) or "Use", sourceData["useObject"],
                                sourceData["upgradeTier"] or 0, sourceData["useEquipSmartMode"] or false)
                        end
                    end

                    updateMultiButtonState(parentButton)
                    assignMultiAction(parentButton, true)
                    return true
                end

                if panel and panel.button then
                    local targetButton = panel.button
                    local tBarID, tButtonID = splitButtonId(targetButton)
                    local sBarID, sButtonID = splitButtonId(parentButton)
                    local sourceData = parentButton.cache.multiActions[sourceIndex]

                    if sourceData and not table.empty(sourceData) then
                        if sourceData["chatText"] then
                            ApiJson.createOrUpdateMultiText(tonumber(tBarID), tonumber(tButtonID), targetIndex,
                                sourceData["chatText"], sourceData["sendAutomatically"])
                        elseif sourceData["useObject"] then
                            ApiJson.createOrUpdateMultiAction(tonumber(tBarID), tonumber(tButtonID), targetIndex,
                                getActionName(sourceData["useType"]) or "Use", sourceData["useObject"],
                                sourceData["upgradeTier"] or 0, sourceData["useEquipSmartMode"] or false)
                        end
                    end

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

    if destButton.cache and destButton.cache.multiActions then
        local destHasMulti = false
        for i = 1, 3 do
            if not table.empty(destButton.cache.multiActions[i] or {}) then
                destHasMulti = true
                break
            end
        end
        if destHasMulti then
            cancelMultiDrag(self, actionButton)
            return
        end
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
        local actionTypeName = getActionName(destButton.cache.actionType)
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
            local actionTypeName = getActionName(sourceData["useType"]) or "Use"
            ApiJson.createOrUpdateAction(tonumber(dBarID), tonumber(dButtonID), actionTypeName,
                sourceData["useObject"], sourceData["upgradeTier"] or 0)
        end
    end

    if not destHasAction then
        ApiJson.removeMultiAction(tonumber(barID), tonumber(buttonID), sourceIndex)
        parentButton.cache.multiActions[sourceIndex] = {}

        local allEmpty = true
        for i = 1, 3 do
            if not table.empty(parentButton.cache.multiActions[i] or {}) then
                allEmpty = false
                break
            end
        end
        if allEmpty then
            parentButton.cache.itemId = 0
            parentButton.cache.param = ""
            parentButton.cache.actionType = 0
            if parentButton.multiIcon then
                parentButton.multiIcon:setVisible(false)
            end
            table.removevalue(cacheMultiActionButtons, parentButton)
            clearMultiActionCooldownEvents(parentButton:getId())
        end
    end

    cancelMultiDrag(self, actionButton)
    updateButton(destButton)
    updateMultiButtonState(parentButton)
    assignMultiAction(parentButton, true)
end
