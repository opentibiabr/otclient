-- /*=============================================
-- =            util             =
-- =============================================*/
local function string_empty(str)
    return #str == 0
end

local function lineBreaks(input, lineLength, spaceCount)
    spaceCount = spaceCount or 0
    local result = {}
    local space = string.rep(" ", spaceCount)
    local inputLen = #input
    for pos = 1, inputLen, lineLength do
        local endPos = math.min(pos + lineLength - 1, inputLen)
        result[#result + 1] = input:sub(pos, endPos)
        if endPos < inputLen then
            result[#result + 1] = "\n" .. space
        end
    end
    return table.concat(result)
end

local function getButtonById(id)
    if not id then
        return nil
    end
    for _, actionbar in pairs(actionBars) do
        for _, button in pairs(actionbar.tabBar:getChildren()) do
            if button:getId() == id then
                return button
            end
        end
    end
    return nil
end

local function buttonIsEmpty(button)
    return button.item:getItemId() == 0 and string_empty(button.item.text:getText()) and
               string_empty(button.item.text:getImageSource())
end
local function getActionName(actionType)
    for k, v in pairs(UseTypes) do
        if v == actionType then
            return k
        end
    end
end
local function getItemNameById(itemId)
    for _, k in pairs(hotkeyItemList) do
        local item = k[1]
        if item:getId() == itemId then
            return k[2]
        end
    end
    return "this object"
end

local function playerCanUseSpell(spellData)
    if not g_game.isOnline() then
        return
    end

    if not spellData then
        return false
    end

    if spellData.needLearn and not spellListData[tostring(spellData.id)] then
        return false
    end

    if spellData.mana and (player:getMana() < spellData.mana) then
        return false
    end

    if spellData.level and (player:getLevel() < spellData.level) then
        return false
    end

    if spellData.soul and (player:getSoul() < spellData.soul) then
        return false
    end

    if spellData.vocations and (not table.contains(spellData.vocations, translateVocation(player:getVocation()))) then
        return false
    end

    return true
end
-- /*=============================================
-- =            Hotkeys             =
-- =============================================*/
local function onCheckKeyUp(button)
    local cache = getButtonCache(button)
    if cache.isSpell then
        spellGroupPressed[tostring(button.cache.primaryGroup)] = nil
    end
end
local function bindHotkey(button, hotkey)
    if not gameRootPanel or not button or not hotkey or string_empty(hotkey) then
        return
    end

    local combo = hotkey
    g_keyboard.bindKeyPress(combo, function()
        if not modules.game_hotkeys.canPerformKeyCombo(combo) then
            return
        end
        onExecuteAction(button, true)
    end, gameRootPanel)

    g_keyboard.bindKeyDown(combo, function()
        if not modules.game_hotkeys.canPerformKeyCombo(combo) then
            return
        end
        onExecuteAction(button, false)
    end, gameRootPanel)

    g_keyboard.bindKeyUp(combo, function()
        if not modules.game_hotkeys.canPerformKeyCombo(combo) then
            return
        end
        onCheckKeyUp(button)
    end, gameRootPanel)
end

local function setupHotkeyButton(button)
    if not ApiJson.hasCurrentHotkeySet() then
        return
    end

    local chatMode = modules.game_console.isChatEnabled() and 'chatOn' or 'chatOff'
    for _, data in pairs(ApiJson.getHotkeyEntries(chatMode)) do
        if data["actionsetting"] then
            if data["actionsetting"]["action"] == "TriggerActionButton_" .. button:getId() then
                local keySequence = data["keysequence"]
                if keySequence and not string_empty(keySequence) then
                    if not data["secondary"] then
                        button.cache.hotkey = keySequence
                    end

                    unbindHotkey(keySequence)
                    bindHotkey(button, keySequence)
                end
            end
        end
    end
end
-- /*=============================================
-- =            button behavior             =
-- =============================================*/
function onExecuteAction(button, isPress)
    local cache = getButtonCache(button)
    if cache.lastClick > g_clock.millis() then
        return true
    end

    if modules.game_interface.getMainRightPanel():isFocusable() or modules.game_interface.getLeftPanel():isFocusable() then
        return true
    end

    if not isPress then
        button.cache.nextDownKey = g_clock.millis() + 500
    end

    if isPress and button.cache.nextDownKey > g_clock.millis() then
        return true
    end

    local cooldown = isPress and 600 or 150
    button.cache.lastClick = g_clock.millis() + cooldown
    local action = button.cache.actionType
    if action == 0 then
        return true
    end

    if action == UseTypes["Equip"] and button.item then
        local tier = 0
        if g_game.getFeature(GameThingUpgradeClassification) then
            tier = button.cache.upgradeTier
        end
        if player:getInventoryCount(button.cache.itemId, tier) == 0 then
            return
        end
        g_game.equipItemId(button.cache.itemId, tier)
    end

    if action == UseTypes["Use"] and button.item then
        if (button.item:getItem():isContainer()) then
            g_game.closeContainerByItemId(button.item:getItemId())
        else
            g_game.useInventoryItem(button.item:getItemId())
        end
    end

    if action == UseTypes["UseOnYourself"] and button.item then
        g_game.useInventoryItemWith(button.item:getItemId(), player, button.item:getItemSubType() or -1)
        if not g_game.getFeature(GameEnterGameShowAppearance) then -- temp old protocol
            updateInventoryItems()
        end
    end

    if button.item then
        if action == UseTypes["SelectUseTarget"] then
            modules.game_interface.startUseWith(button.item:getItem(), button.item:getItemSubType() or -1)
        end

        if action == UseTypes["UseOnTarget"] then
            local attackingCreature = g_game.getAttackingCreature()
            if not attackingCreature then
                modules.game_interface.startUseWith(button.item:getItem(), button.item:getItemSubType() or -1)
            else
                g_game.useWith(button.item:getItem(), attackingCreature, button.item:getItemSubType() or -1)
            end
        end
    end

    if action == UseTypes["chatText"] and button.cache.sendAutomatic then
        if button.cache.isSpell then
            spellGroupPressed[tostring(button.cache.primaryGroup)] = true
            g_game.talk(button.cache.param)
        else
            modules.game_console.sendMessage(button.cache.param)
        end

        modules.game_console.getConsole():setText('')
    elseif action == UseTypes["chatText"] then
        modules.game_console.getConsole():setText(button.cache.param)
        modules.game_console.getConsole():setCursorPos(#button.cache.param)
    end
end

local function translateDisplayHotkey(text)
    if HotkeyShortcuts[text] then
        text = HotkeyShortcuts[text]
    elseif string.len(text) > 5 then
        text = "..." .. string.sub(text, string.len(text) - 2, string.len(text))
    end
    return text
end

function clearButton(button, removeAction)
    local hotkey = button.cache.hotkey

    if button.cache.cooldownEvent then
        removeEvent(button.cache.cooldownEvent)
    end

    removeCooldown(button)
    resetButtonCache(button)

    if hotkey then
        button.cache.hotkey = hotkey
        button.hotkeyLabel:setText(translateDisplayHotkey(button.cache.hotkey))
    end

    setupButtonTooltip(button, true)
    if removeAction then
        local barID, buttonID = string.match(button:getId(), "(.*)%.(.*)")
        ApiJson.removeAction(tonumber(barID), tonumber(buttonID))
    end
end

function updateButtonState(button)
    if not button then
        return
    end

    if not player then
        player = g_game.getLocalPlayer()
    end

    if not player then
        return
    end
    if not button.item then
        return
    end

    button:recursiveGetChildById('activeSpell'):setVisible(false)
    if button.cache.isSpell then
        setupButtonTooltip(button, false)
        button.item.text.gray:setVisible(not playerCanUseSpell(button.cache.spellData))
        local spellId = 0
        button:recursiveGetChildById('activeSpell'):setVisible(button.cache.spellData.id == spellId)
    elseif button.cache.itemId ~= 0 then
        local tier = 0
        if g_game.getFeature(GameThingUpgradeClassification) then
            tier = button.cache.upgradeTier
        end
        local isItemEquipped = player:hasEquippedItemId(button.cache.itemId, tier)
        local itemCount = player:getInventoryCount(button.cache.itemId, tier)

        if g_game.getFeature(GameEnterGameShowAppearance) then -- fix old protocol
            if button.cache.actionType == UseTypes["Equip"] then
                button.item:setChecked(itemCount ~= 0 and isItemEquipped)
            end

            button.item.gray:setVisible(itemCount == 0)
        end
        button.item:setItemCount(itemCount)
        setupButtonTooltip(button, false)
    end
end

function getButtonCache(button)
    if not button then
        return {
            cooldownEvent = nil,
            cooldownTime = 0,
            isSpell = false,
            isRuneSpell = false,
            isPassive = false,
            spellID = 0,
            spellData = nil,
            param = "",
            sendAutomatic = false,
            actionType = 0,
            upgradeTier = 0,
            hotkey = nil,
            lastClick = 0,
            nextDownKey = 0,
            isDragging = false,
            buttonIndex = 0,
            buttonParent = nil,
            itemId = 0
        }
    end

    if not button.cache then
        button.cache = {
            cooldownEvent = nil,
            cooldownTime = 0,
            isSpell = false,
            isRuneSpell = false,
            isPassive = false,
            spellID = 0,
            spellData = nil,
            param = "",
            sendAutomatic = false,
            actionType = 0,
            upgradeTier = 0,
            hotkey = nil,
            lastClick = 0,
            nextDownKey = 0,
            isDragging = false,
            buttonIndex = 0,
            buttonParent = nil,
            itemId = 0
        }
    end

    return button.cache
end

function resetButtonCache(button)
    if button.cache and button.cache.itemId > 0 then
        local cachedItem = cachedItemWidget[button.cache.itemId]
        if cachedItem then
            for index, widget in pairs(cachedItem) do
                if button == widget then
                    table.remove(cachedItem, index)
                end
            end
        end
    end

    if button.item then
        button.item:setItemId(0)
        button.item:setOn(false)
        button.item:setChecked(false)
        button.item:setDraggable(false)
        ItemsDatabase.setTier(button.item, 0)
        if button.item.gray then
            button.item.gray:setVisible(false)
        end
        if button.item.text then
            button.item.text.gray:setVisible(false)
            button.item.text:setImageSource('')
            button.item.text:setText('')
        end
    end

    if button.hotkeyLabel then
        button.hotkeyLabel:setText('')
    end
    if button.parameterText then
        button.parameterText:setText('')
    end
    if button.cooldown then
        button.cooldown:setPercent(100)
        button.cooldown:setText("")
    end

    if button.cache then
        if button.cache.removeCooldownEvent then
            removeEvent(button.cache.removeCooldownEvent)
            button.cache.removeCooldownEvent = nil
        end
    end

    button.cache = {
        cooldownEvent = nil,
        cooldownTime = 0,
        isSpell = false,
        isRuneSpell = false,
        isPassive = false,
        spellID = 0,
        spellData = nil,
        primaryGroup = nil,
        param = "",
        sendAutomatic = false,
        actionType = 0,
        upgradeTier = 0,
        hotkey = nil,
        lastClick = 0,
        nextDownKey = 0,
        isDragging = false,
        buttonIndex = 0,
        buttonParent = nil,
        itemId = 0
    }
end
-- /*=============================================
-- =       Tooltip    =
-- =============================================*/
function setupButtonTooltip(button, isEmpty)
    if not g_game.isOnline() then
        return true
    end

    local cache = getButtonCache(button)
    if isEmpty then
        local tooltip = "Action Button " .. button:getId()
        local hotkeyDesc = cache.hotkey ~= nil and cache.hotkey or "None"
        tooltip = tooltip .. "\n\nAction:  " .. "None"
        tooltip = tooltip .. "\nHotkeys:  " .. hotkeyDesc
        if button.item then
            button.item:setTooltip(tooltip)
        end
        return true
    end

    local actionDesc = ""
    local spellData = cache.spellData

    if cache.actionType == UseTypes["chatText"] then
        if not cache.isSpell then
            actionDesc = 'Say: "' .. lineBreaks(cache.param, 44, 36) .. '"\n'
            actionDesc = actionDesc .. "Auto sent:  " .. (cache.sendAutomatic and "Yes" or "No")
        else
            actionDesc = "Cast " .. Spells.getSpellNameByWords(spellData.words) .. "\n"
            actionDesc = actionDesc .. "   Formula:  " .. cache.param .. "\n"
        end
    elseif cache.actionType == UseTypes["passiveAbility"] then
        actionDesc = "Gift of Life"
    else
        actionDesc = UseTypesTip[cache.actionType]
        if actionDesc == nil then
            actionDesc = "Use %s"
        end

        if cache.actionType == UseTypes["Equip"] then
            local itemName = getItemNameById(button.item:getItem():getId()) ..
                                 ((cache.upgradeTier and cache.upgradeTier > 0) and " (Tier " .. cache.upgradeTier ..
                                     ")" or "")
            actionDesc = tr(actionDesc, (button.item:isChecked() and "Unequip" or "Equip"), itemName)
        elseif button.item:getItem() then
            actionDesc = tr(actionDesc, getItemNameById(button.item:getItem():getId()))
        end

        local itemCount = player:getInventoryCount(button.cache.itemId, button.cache.upgradeTier)
        actionDesc = actionDesc .. "\n    Amount:  " .. itemCount
    end

    local hotkeyDesc = cache.hotkey ~= nil and cache.hotkey or "None"
    local tooltip = "Action Button " .. button:getId()

    if cache.actionType == UseTypes["passiveAbility"] then
        tooltip = tooltip .. "\n\n Passive Ability:  " .. actionDesc
        tooltip = tooltip .. "\n            Hotkeys:  " .. hotkeyDesc
    else
        tooltip = tooltip .. "\n\n       Action:  " .. actionDesc
        tooltip = tooltip .. "\n   Hotkeys:  " .. hotkeyDesc
    end

    button.item:setTooltip(tooltip)
end

-- /*=============================================
-- =       Animation Cooldown    =
-- =============================================*/
function checkRemainSpellCooldown(button, spellId)
    if not modules.client_options.getOption("graphicalCooldown") and
        not modules.client_options.getOption("cooldownSecond") then
        return true
    end

    local cooldownData = spellCooldownCache[spellId]
    if not cooldownData then
        return
    end

    if (cooldownData.startTime + cooldownData.exhaustion) < g_clock.millis() then
        return
    end

    button.cache = getButtonCache(button)
    local remainTime = (cooldownData.startTime + cooldownData.exhaustion) - g_clock.millis()

    updateCooldown(button, remainTime)
    if button.cache.removeCooldownEvent then
        removeEvent(button.cache.removeCooldownEvent)
        button.cache.removeCooldownEvent = nil
    end
    button.cache.removeCooldownEvent = scheduleEvent(function()
        removeCooldown(button)
    end, remainTime)
end

function removeCooldown(button)
    if not button or not button.cache then
        return true
    end

    button.cache.removeCooldownEvent = nil
    if button.cooldown then
        button.cooldown:stop()
        button.cooldown:setPercent(100)
        button.cooldown:setText("")
    end
end

function updateCooldown(button, timeMs)
    button.cooldown:showTime(modules.client_options.getOption("cooldownSecond"))
    button.cooldown:showProgress(modules.client_options.getOption("graphicalCooldown"))
    button.cooldown:setDuration(timeMs)
    button.cooldown:start()
end

function updateActionPassive(button)
    if not modules.client_options.getOption("graphicalCooldown") and
        not modules.client_options.getOption("cooldownSecond") then
        return true
    end

    if not button then
        for _, actionbar in pairs(activeActionBars) do
            for _, button in pairs(actionbar.tabBar:getChildren()) do
                local cache = button.cache
                if cache.isPassive then
                    button.item.text.gray:setVisible(passiveData.max == 0)
                    if cache.cooldownEvent == nil then
                        updateCooldown(button, passiveData.cooldown * 1000)
                        if cache.removeCooldownEvent then
                            removeEvent(cache.removeCooldownEvent)
                            cache.removeCooldownEvent = nil
                        end
                        cache.removeCooldownEvent = scheduleEvent(function()
                            removeCooldown(button)
                        end, passiveData.cooldown * 1000)
                    end
                end
            end
        end
        return true
    else
        if button.cache.isPassive then
            button.item.text.gray:setVisible(passiveData.max == 0)
        end
    end

    if passiveData.max > 0 then
        if button.cache.removeCooldownEvent then
            removeEvent(button.cache.removeCooldownEvent)
            button.cache.removeCooldownEvent = nil
        end
        updateCooldown(button, passiveData.cooldown * 1000)
        button.cache.removeCooldownEvent = scheduleEvent(function()
            removeCooldown(button)
        end, passiveData.cooldown * 1000)
    end
end

-- /*=============================================
-- =       right button in an action bar slot    =
-- =============================================*/
function configureButtonMouseRelease(button)
    button.onMouseRelease = function(button, mousePos, mouseButton)
        button.cache = getButtonCache(button)
        if mouseButton == MouseRightButton then
            local menu = g_ui.createWidget('PopupMenu')
            menu:setGameMenu(true)
            menu:addOption(button.cache.isSpell and tr('Edit Spell') or tr('Assign Spell'), function()
                assignSpell(button)
            end)
            if button.item and button.item:getItemId() > 100 then
                menu:addOption(tr('Edit Object'), function()
                    assignItem(button, button.item:getItemId())
                end)
            else
                menu:addOption(tr('Assign Object'), function()
                    assignItemEvent(button)
                end)
            end

            local buttonText = ""
            if button.item then
                buttonText = button.item.text:getText()
            end

            menu:addOption(buttonText:len() > 0 and tr('Edit Text') or tr('Assign Text'), function()
                assignText(button)
            end)
            menu:addOption(button.cache.isPassive and tr('Edit Passive Ability') or tr('Assign Passive Ability'),
                function()
                    assignPassive(button)
                end)
            menu:addOption(button.cache.hotkey and tr('Edit Hotkey') or tr('Assign Hotkey'), function()
                assignHotkey(button)
            end)
            if button.cache.actionType > 0 then
                menu:addSeparator()
                menu:addOption(tr('Clear Action'), function()
                    clearButton(button, true)
                end)
            end
            if button.item and button.item:getItemId() > 100 then
                if modules.game_bot then
                    menu:addSeparator()
                    local useThingId = button.item:getItemId()
                    menu:addOption("ID: " .. useThingId, function() g_window.setClipboardText(useThingId) end)
                end
            end
            menu:display(mousePos)
        end
    end
end
-- /*=============================================
-- =       click left in the action bar slot    =
-- =============================================*/
function updateButton(button)
    if not player then
        player = g_game.getLocalPlayer()
    end

    local barID, buttonID = string.match(button:getId(), "(%d+)%.(%d+)")
    local barIndex = tonumber(barID)
    local buttonIndex = tonumber(buttonID)
    local buttonData = nil

    if not button.item then
        local actionId, buttonId = button:getId():match("([^.]+)%.([^.]+)")
        button:destroy()
        local actionbar = actionBars[tonumber(actionId)]
        local layout = tonumber(actionId) < 4 and 'ActionButton' or 'SideActionButton'
        local widget = g_ui.createWidget(layout, actionbar.tabBar)
        actionbar.tabBar:moveChildToIndex(widget, tonumber(buttonId))
        widget:setId(actionId .. "." .. buttonId)
        updateButton(widget)
        return
    end

    buttonData = ApiJson.getMapping(barIndex, buttonIndex)

    resetButtonCache(button)
    button.item.text:setTextOffset("0 0")

    button.cache = getButtonCache(button)
    if button.item.getItemId and not button.cache.actionType then
        button.item:setItemId(0, true)
        button.item:setOn(false)
    end

    setupHotkeyButton(button)
    if button.cache.hotkey then
        button.item.text:setTextOffset("0 8")
        button.hotkeyLabel:setText(translateDisplayHotkey(button.cache.hotkey))
    end

    if not buttonData or not buttonData["actionsetting"] then
        setupButtonTooltip(button, true)
        button.item:setDraggable(false)
        configureButtonMouseRelease(button)
        return true
    end

    local useAction = buttonData["actionsetting"]["useObject"]
    local sendText = buttonData["actionsetting"]["chatText"]
    local passiveAbility = buttonData["actionsetting"]["passiveAbility"]

    if useAction then
        button.item:setItemId(useAction, true)
        button.item:setOn(true)
        local cached = cachedItemWidget[useAction]
        if cached then
            table.insert(cached, button)
        else
            cachedItemWidget[useAction] = {}
            table.insert(cachedItemWidget[useAction], button)
        end
        local spellData = Spells.getRuneSpellByItem(useAction)
        if spellData then
            button.cache.isRuneSpell = true
            button.cache.spellData = spellData
            if spellData.vocations and not table.contains(spellData.vocations, translateVocation(player:getVocation())) then
                button.item.gray:setVisible(true)
            end
        end

        button.cache.itemId = button.item:getItemId()
        button.cache.upgradeTier = buttonData["actionsetting"]["upgradeTier"]
        local useTypeName = buttonData["actionsetting"]["useType"]
        button.cache.actionType = UseTypes[useTypeName] or UseTypes["Use"]
        ItemsDatabase.setTier(button.item, button.cache.upgradeTier)
        updateButtonState(button)
    end

    if sendText then
        local spellData, param = Spells.getSpellDataByParamWords(sendText:lower())
        if spellData then
            local spellId = spellData.clientId
            if not spellId then
                print("Warning Spell ID not found L734 modules/game_actionbar/logics/ActionButtonLogic.lua")
                return
            end
            local source = SpelllistSettings['Default'].iconFile
            local clip = Spells.getImageClip(spellId, 'Default')

            button.item.text:setImageSource(source)
            button.item.text:setImageClip(clip)
            button.cache.isSpell = true
            button.cache.spellID = spellData.id
            button.cache.spellData = spellData
            button.cache.primaryGroup = spellData.group and Spells.getGroupIds(spellData)[1] or nil

            if param then
                local formatedParam = param:gsub('"', '')
                button.parameterText:setText(short_text('"' .. formatedParam, 4))
                button.cache.castParam = formatedParam
            end

            if not playerCanUseSpell(spellData) then
                button.item.text.gray:setVisible(true)
            end

            checkRemainSpellCooldown(button, spellData.id)
        else
            button.item.text:setText(short_text(sendText, 15))
        end

        button.item:setOn(true)
        button.cache.param = sendText
        button.cache.sendAutomatic = buttonData["actionsetting"]["sendAutomatically"]
        button.cache.actionType = UseTypes["chatText"]
    end

    if passiveAbility then
        local passive = PassiveAbilities[passiveAbility]
        button.item.text:setImageSource(passive.icon)
        button.item.text:setImageClip("0 0 32 32")
        button.cache.actionType = UseTypes["passiveAbility"]
        button.cache.isPassive = true
        updateActionPassive(button)
    end

    button.item:setDraggable(true)
    setupButtonTooltip(button, false)

    local parentButton = button:getParent()
    if parentButton then
        button.cache.buttonIndex = parentButton:getChildIndex(button)
        button.cache.buttonParent = parentButton
    end

    button.item.onDragEnter = function(self, mousePos)
        if ApiJson.isBarLocked(barIndex) then
            return false
        end

        button.cooldown:setBorderWidth(1)
        button.cache.isDragging = true
        dragButton = button
        dragItem = self
        return true
    end
    button.item.onDragMove = function(self, mousePos)
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
        if not clickedWidget or not clickedWidget:backwardsGetWidgetById("tabBar") then
            return true
        end

        lastHighlightWidget = clickedWidget
        lastHighlightWidget:setBorderWidth(1)
        lastHighlightWidget:setBorderColor('white')
    end

    button.item.onDragLeave = function(self, widget, mousePos)
        if not button.cache.isDragging then
            return false
        end
        isLoaded = false
        button.cache.isDragging = false
        onDragItemLeave(self, mousePos, button)
        isLoaded = true
        dragButton = nil
        dragItem = nil
    end

    button.item.onClick = function()
        onExecuteAction(button)
    end
    button.item.text.onClick = function()
        onExecuteAction(button)
    end
    configureButtonMouseRelease(button)
    ActionBarController:scheduleEvent(function()
        onMultiUseCooldown()
    end, 100)
end
-- /*=============================================
-- =            Mouse Drag Event             =
-- =============================================*/
-- item in UIMap or UIWidget(UIItem) drop in slot actionbar
local function getButtonFromWidget(widget)
    if not widget then
        return nil
    end

    local widgetId = widget:getId()
    if widgetId and widget.item and widgetId:match("^%d+%.%d+$") then
        return widget
    end

    return getButtonFromWidget(widget:getParent())
end

local function resolveDroppedItemData(draggedWidget, item)
    if type(item) == 'number' then
        local itemTier = 0
        if draggedWidget and draggedWidget.getItem then
            local draggedItem = draggedWidget:getItem()
            if draggedItem and draggedItem.getTier then
                itemTier = draggedItem:getTier() or 0
            end
        end
        return item, itemTier
    end

    if item and item.getId then
        local itemId = item:getId()
        local itemTier = item.getTier and (item:getTier() or 0) or 0
        return itemId, itemTier
    end

    return nil, 0
end

function tryAssignActionButtonFromDrop(mousePos, draggedWidget, item)
    if not hasAnyActiveActionBar() or not item then
        return false
    end
    if dragButton or not draggedWidget or not gameRootPanel then
        return false
    end

    local className = draggedWidget:getClassName()
    if className ~= 'UIItem' and className ~= 'UIGameMap' then
        return false
    end

    if className == 'UIItem' then
        local parentWidget = draggedWidget:getParent()
        if parentWidget and parentWidget:getId() == 'actionBarPanel' then
            return false
        end
    end

    local clickedWidget = gameRootPanel:recursiveGetChildByPos(mousePos, false)
    if not clickedWidget then
        return false
    end

    local tabBar = clickedWidget:backwardsGetWidgetById("tabBar")
    if not tabBar or not tabBar:isVisible() then
        return false
    end

    local button = getButtonFromWidget(clickedWidget)
    if not button or not button:isVisible() then
        return false
    end

    local actionBar = tabBar:getParent()
    if not actionBar or not actionBar:isVisible() then
        return false
    end

    local itemId, itemTier = resolveDroppedItemData(draggedWidget, item)
    if not itemId then
        return false
    end

    local thingType = g_things.getThingType(itemId, ThingCategoryItem)
    if not thingType or not thingType:isPickupable() then
        return false
    end

    assignItem(button, itemId, itemTier)
    return true
end

-- move button to other slot bar 
function resetDragWidget(self, button)
    button.cache = getButtonCache(button)
    local cachedItem = cachedItemWidget[button.cache.itemId]
    if cachedItem then
        for index, widget in pairs(cachedItem) do
            if button == widget then
                table.remove(cachedItem, index)
            end
        end
    end

    self:destroy()
    local barID, buttonID = string.match(button:getId(), "(.*)%.(.*)")
    local style = tonumber(barID) > 3 and "SideActionButton" or "ActionButton"

    button:destroy()

    local destBar = actionBars[tonumber(barID)].tabBar
    local widget = g_ui.createWidget(style, destBar)

    if destBar then
        destBar:moveChildToIndex(widget, buttonID)
    end
    widget:setId(barID .. "." .. buttonID)
    updateButton(widget)
end

function onDragItemLeave(self, mousePos, button)
    if lastHighlightWidget then
        lastHighlightWidget:setBorderWidth(0)
        lastHighlightWidget:setBorderColor('alpha')
    end

    local clickedWidget = gameRootPanel:recursiveGetChildByPos(mousePos, false)
    if not clickedWidget or not clickedWidget:backwardsGetWidgetById("tabBar") then
        resetDragWidget(self, button)
        return true
    end

    local destButton = getButtonById(clickedWidget:getParent():getId())
    if not destButton then
        resetDragWidget(self, button)
        return true
    end

    local destButtonCache = destButton.cache

    button.cache = getButtonCache(button)
    local itemId = button.cache.itemId
    local destBarID, destButtonID = string.match(destButton:getId(), "(.*)%.(.*)")
    local draggedBarID, draggedButtonID = string.match(button:getId(), "(.*)%.(.*)")

    local cachedItem = cachedItemWidget[itemId]
    if cachedItem then
        for index, widget in pairs(cachedItem) do
            if button == widget then
                table.remove(cachedItem, index)
            end
        end
    end

    local cachedItem = cachedItemWidget[destButtonCache.itemId]
    if cachedItem then
        for index, widget in pairs(cachedItem) do
            if button == widget then
                table.remove(cachedItem, index)
            end
        end
    end
    local isButtonEmpty = buttonIsEmpty(destButton)
    if button.cache.actionType == UseTypes["chatText"] then
        ApiJson.createOrUpdateText(tonumber(destBarID), tonumber(destButtonID), button.cache.param,
            button.cache.sendAutomatic)
    elseif itemId ~= 0 then
        ApiJson.createOrUpdateAction(tonumber(destBarID), tonumber(destButtonID),
            getActionName(button.cache.actionType), itemId, button.cache.upgradeTier)
    elseif button.cache.isPassive then
        ApiJson.createOrUpdatePassive(tonumber(destBarID), tonumber(destButtonID), 1)
    end
    updateButton(destButton)
    if isButtonEmpty then
        ApiJson.removeAction(tonumber(draggedBarID), tonumber(draggedButtonID))
        removeCooldown(destButton)
        resetDragWidget(self, button)
    else
        if destButtonCache.actionType == UseTypes["chatText"] then
            ApiJson.createOrUpdateText(tonumber(draggedBarID), tonumber(draggedButtonID), destButtonCache.param,
                destButtonCache.sendAutomatic)
        elseif destButtonCache.itemId ~= 0 then
            ApiJson.createOrUpdateAction(tonumber(draggedBarID), tonumber(draggedButtonID),
                getActionName(destButtonCache.actionType), destButtonCache.itemId, destButtonCache.upgradeTier)
        elseif destButtonCache.isPassive then
            ApiJson.createOrUpdatePassive(tonumber(draggedBarID), tonumber(draggedButtonID), 1)
        end

        removeCooldown(destButton)
        resetDragWidget(self, button)
    end
    self:setBorderColor('alpha')
end
