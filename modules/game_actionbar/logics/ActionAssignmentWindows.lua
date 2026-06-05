-- /*=============================================
-- =            Spells html Windows             =
-- =============================================*/
local function string_empty(str)
    return #str == 0
end

function ActionBarController:onSearchTextChange(event)
    for _, child in pairs(ActionBarController:findWidget("#spellList"):getChildren()) do
        local name = child:getText():lower()
        if name:find(event.value:lower()) or event.value == '' or #event.value < 3 then
            child:setVisible(true)
        else
            child:setVisible(false)
        end
    end
end

function ActionBarController:onClearSearchText()
    local search = ActionBarController:findWidget("#searchText")
    search:setText('')
end

function assignSpell(button, multiSlotIndex)
    local dev = true
    local actionbar = button:getParent():getParent()
    if actionbar.locked then
        alert('Action bar is locked')
        return
    end
    local radio = UIRadioGroup.create()
    if ActionBarController.ui then
        ActionBarController:unloadHtml()
    end
    ActionBarController:loadHtml('html/spells.html')
    ActionBarController.ui:show()
    ActionBarController.ui:raise()
    local titleSuffix = multiSlotIndex and (" (Slot " .. multiSlotIndex .. ")") or ""
    ActionBarController.ui:setTitle("Assign Spell to Action Button " .. button:getId() .. titleSuffix)
    local spellList = ActionBarController:findWidget("#spellList")
    local previewWidget = ActionBarController:findWidget("#preview")
    local imageWidget = ActionBarController:findWidget("#image")
    local paramLabel = ActionBarController:findWidget("#paramLabel")
    local paramText = ActionBarController:findWidget("#paramText")
    ActionBarController:findWidget("#dev"):setVisible(dev)
    local playerVocation = translateVocation(player:getVocation())
    local playerLevel = player:getLevel()
    local spells = modules.gamelib.SpellInfo['Default']
    local defaultIconsFolder = SpelllistSettings['Default'].iconFile
    local showAllSpells = (playerVocation == 0)
    for spellName, spellData in pairs(spells) do
        if showAllSpells or table.contains(spellData.vocations, playerVocation) then
            local widget = g_ui.createWidget('SpellPreview', spellList)
            local spellId = spellData.clientId
            local clip = Spells.getImageClip(spellId)
            radio:addWidget(widget)
            widget:setId(spellData.id)
            widget:setText(spellName .. "\n" .. spellData.words)
            widget.voc = spellData.vocations
            widget.param = spellData.parameter
            widget.source = defaultIconsFolder
            widget.clip = clip
            widget.image:setImageSource(widget.source)
            widget.image:setImageClip(widget.clip)
            if spellData.level then
                widget.levelLabel:setVisible(true)
                widget.levelLabel:setText(string.format("Level: %d", spellData.level))
                widget.image.gray:setVisible(playerLevel < spellData.level)
            end
            local primaryGroup = Spells.getPrimaryGroup(spellData)
            if primaryGroup ~= -1 then
                local offSet = (primaryGroup == 2 and 20) or (primaryGroup == 3 and 40) or 0
                widget.imageGroup:setImageClip(offSet .. " 0 20 20")
                widget.imageGroup:setVisible(true)
            end
        end
    end
    local widgets = spellList:getChildren()
    table.sort(widgets, function(a, b)
        return a:getText() < b:getText()
    end)
    for i, widget in ipairs(widgets) do
        spellList:moveChildToIndex(widget, i)
    end
    local preselectSpellData = nil
    local preselectCastParam = nil
    if multiSlotIndex and button.cache and button.cache.multiActions then
        local slot = button.cache.multiActions[multiSlotIndex]
        if slot and slot["chatText"] then
            local spellData, param = Spells.getSpellDataByParamWords(slot["chatText"]:lower())
            if spellData then
                preselectSpellData = spellData
                if param then
                    preselectCastParam = param:gsub('"', '')
                end
            end
        end
    elseif button.cache.spellData and not button.cache.isRuneSpell then
        preselectSpellData = button.cache.spellData
        preselectCastParam = button.cache.castParam
    end

    if preselectSpellData then
        local spellData = preselectSpellData
        local spellId = spellData.clientId
        if not spellId then
            print("Warning Spell ID not found L81 modules/game_actionbar/logics/ActionAssignmentWindows.lua")
            return
        end
        local clip = Spells.getImageClip(spellId, 'Default')
        imageWidget:setImageSource(defaultIconsFolder)
        imageWidget:setImageClip(clip)
        paramLabel:setOn(spellData.parameter)
        paramText:setEnabled(spellData.parameter)
        if spellData.parameter and preselectCastParam then
            paramText:setText(preselectCastParam)
            paramText:setCursorPos(#preselectCastParam)
        end
        for i, k in ipairs(widgets) do
            if k:getId() == tostring(spellData.id) then
                radio:selectWidget(k)
                spellList:ensureChildVisible(k)
                break
            end
        end
    end
    radio.onSelectionChange = function(widget, selected)
        if selected then
            previewWidget:setText(selected:getText())
            imageWidget:setImageSource(selected.source)
            imageWidget:setImageClip(selected.clip)
            paramLabel:setOn(selected.param)
            paramText:setEnabled(selected.param)
            paramText:clearText()
            if selected:getText():lower():find("levitate") then
                paramText:setText("up|down")
            end
        end
    end
    if #widgets > 0 and not preselectSpellData then
        radio:selectWidget(widgets[1])
    end
    local function cancelFunc()
        ActionBarController:unloadHtml()
    end

    local function okFunc(destroy)
        local selected = radio:getSelectedWidget()
        if not selected then
            cancelFunc()
            return
        end

        local barID, buttonID = string.match(button:getId(), "(.*)%.(.*)")
        local param = string.match(selected:getText(), "\n(.*)")
        local paramValue = paramText:getText()
        local check = param .. " " .. paramValue
        if check:find("utevo res ina") then
            param = "utevo res ina"
            paramValue = paramValue:gsub("ina ", "")
        end
        if paramValue:lower():find("up|down") then
            paramValue = ""
        end
        if not string_empty(paramValue) then
            param = param .. ' "' .. paramValue:gsub('"', '') .. '"'
        end
        if multiSlotIndex then
            if not button.cache.multiActions then button.cache.multiActions = {{}, {}, {}} end
            button.cache.multiActions[multiSlotIndex] = {chatText = param, sendAutomatically = true}
            ApiJson.createOrUpdateMultiText(tonumber(barID), tonumber(buttonID), multiSlotIndex, param, true)
            if updateMultiButtonState then updateMultiButtonState(button) end
            if assignMultiAction then assignMultiAction(button, true) end
        else
            ApiJson.createOrUpdateText(tonumber(barID), tonumber(buttonID), param, true)
            updateButton(button)
        end

        if destroy then
            ActionBarController:unloadHtml()
        end
    end
    ActionBarController:findWidget("#buttonOk").onClick = function()
        okFunc(true)
    end
    ActionBarController:findWidget("#buttonApply").onClick = function()
        okFunc(false)
    end
    ActionBarController:findWidget("#buttonClose").onClick = cancelFunc
    ActionBarController:findWidget("#dev").onClick = function()
        spellList:destroyChildren()
        for spellName, spellData in pairs(spells) do
            local widget = g_ui.createWidget('SpellPreview', spellList)
            local spellId = spellData.clientId
            local clip = Spells.getImageClip(spellId)
            radio:addWidget(widget)
            widget:setId(spellData.id)
            widget:setText(spellName .. "\n" .. spellData.words)
            widget.voc = spellData.vocations
            widget.param = spellData.parameter
            widget.source = defaultIconsFolder
            widget.clip = clip
            widget.image:setImageSource(widget.source)
            widget.image:setImageClip(widget.clip)
            if spellData.level then
                widget.levelLabel:setVisible(true)
                widget.levelLabel:setText(string.format("Level: %d", spellData.level))
                widget.image.gray:setVisible(playerLevel < spellData.level)
            end
            local primaryGroup = Spells.getPrimaryGroup(spellData)
            if primaryGroup ~= -1 then
                local offSet = (primaryGroup == 2 and 20) or (primaryGroup == 3 and 40) or 0
                widget.imageGroup:setImageClip(offSet .. " 0 20 20")
                widget.imageGroup:setVisible(true)
            end
        end
        local newWidgets = spellList:getChildren()
        table.sort(newWidgets, function(a, b)
            return a:getText() < b:getText()
        end)
        for i, widget in ipairs(newWidgets) do
            spellList:moveChildToIndex(widget, i)
        end
    end
end
-- /*=============================================
-- =            SetText html Windows             =
-- =============================================*/
function assignText(button, multiSlotIndex)
    local actionbar = button:getParent():getParent()
    if actionbar.locked then
        alert('Action bar is locked')
        return
    end
    if ActionBarController.ui then
        ActionBarController:unloadHtml()
    end
    ActionBarController:loadHtml('html/text.html')
    local ui = ActionBarController.ui
    ActionBarController:scheduleEvent(function()
        ui:centerIn('parent')
    end, 1, "lazyHtml")
    ui:show()
    ui:raise()
    ui:focus()
    local titleSuffix = multiSlotIndex and (" (Slot " .. multiSlotIndex .. ")") or ""
    ui:setTitle("Assign Text to Action Button " .. button:getId() .. titleSuffix)
    local textWidget = ActionBarController:findWidget("#text")
    local tickWidget = ActionBarController:findWidget("#tick")
    local param = ''
    local sendAuto = false
    if multiSlotIndex and button.cache and button.cache.multiActions then
        local slot = button.cache.multiActions[multiSlotIndex]
        if slot and slot["chatText"] then
            param = slot["chatText"]
            sendAuto = slot["sendAutomatically"] or false
        end
    else
        param = button.cache.param or ''
        sendAuto = button.cache.sendAutomatic or false
    end
    textWidget:setText(param)
    textWidget:setCursorPos(#param)
    local hasText = #param > 0
    tickWidget:setChecked(hasText and sendAuto or false)
    local function saveText(closeAfter)
        local autoSay = tickWidget:isChecked()
        local text = textWidget:getText()
        local formattedText = Spells.getSpellFormatedName(text)
        local barID, buttonID = string.match(button:getId(), "(.*)%.(.*)")
        if multiSlotIndex then
            if not button.cache.multiActions then button.cache.multiActions = {{}, {}, {}} end
            button.cache.multiActions[multiSlotIndex] = {chatText = formattedText, sendAutomatically = autoSay}
            ApiJson.createOrUpdateMultiText(tonumber(barID), tonumber(buttonID), multiSlotIndex, formattedText, autoSay)
            if updateMultiButtonState then updateMultiButtonState(button) end
            if assignMultiAction then assignMultiAction(button, true) end
        else
            ApiJson.createOrUpdateText(tonumber(barID), tonumber(buttonID), formattedText, autoSay)
            updateButton(button)
        end
        if closeAfter then
            ActionBarController:unloadHtml()
        end
    end
    ActionBarController:findWidget("#buttonOk").onClick = function()
        saveText(true)
    end
    ActionBarController:findWidget("#buttonApply").onClick = function()
        saveText(false)
    end
    local function cancelFunc()
        ActionBarController:unloadHtml()
    end
    ActionBarController:findWidget("#buttonClose").onClick = cancelFunc
end

function ActionBarController:updateAssignTextState(event)
    local hasText = event.value:len() > 0
    ActionBarController:findWidget("#buttonApply"):setEnabled(hasText)
    ActionBarController:findWidget("#buttonOk"):setEnabled(hasText)
end
-- /*=============================================
-- =            SetObject html Windows             =
-- =============================================*/
local function canEquipItem(item)
    if item:isContainer() then
        return false
    end
    if not g_game.getFeature(GameEnterGameShowAppearance) then -- old protocol
        return true
    end
    if item:getClothSlot() == 0 and (item:getClassification() > 0 or item:isAmmo()) then
        return true
    end

    if item:getClothSlot() > 0 or (item:getClothSlot() == 0 and item:hasWearout()) then
        return true
    end
    return false
end

function assignItem(button, itemId, itemTier, dragEvent, multiSlotIndex)
    if not isLoaded then
        return true
    end
    if not button.item then
        local parent = button:getParent()
        local id = button:getId()
        updateButton(button)
        button = parent:getChildById(id)
        if not button or not button.item then
            return
        end
    end
    local item = button.item:getItem()
    local actionbar = button:getParent():getParent()
    if dragEvent and actionbar.locked or actionbar.locked then
        updateButton(button)
        return
    end
    if dragEvent and not multiSlotIndex then
        updateButton(button)
        return
    end
    if ActionBarController.ui then
        ActionBarController:unloadHtml()
    end
    ActionBarController:loadHtml('html/object.html')
    local ui = ActionBarController.ui
    ActionBarController:scheduleEvent(function()
        ui:centerIn('parent')
    end, 1, "lazyHtml")
    ui:show()
    ui:raise()
    ui:focus()
    local titleSuffix = multiSlotIndex and (" (Slot " .. multiSlotIndex .. ")") or ""
    ui:setTitle("Assign Object to Action Button " .. button:getId() .. titleSuffix)
    local itemWidget = ui:querySelector("#item")
    local selectButton = ui:querySelector("button[text='Select Object']")
    local checkbox1 = ui:querySelector("#UseOnYourself")
    local checkbox2 = ui:querySelector("#UseOnTarget")
    local checkbox3 = ui:querySelector("#UseAtCursorPosition")
    local checkbox4 = ui:querySelector("#SelectUseTarget")
    local checkbox5 = ui:querySelector("#Equip")
    local checkbox6 = ui:querySelector("#Use")
    local buttonOk = ui:querySelector("#buttonOk")
    local buttonApply = ui:querySelector("#buttonApply")
    local buttonClose = ui:querySelector("#buttonClose")
    if selectButton then
        selectButton.onClick = function()
            ActionBarController:unloadHtml()
            assignItemEvent(button, multiSlotIndex)
        end
    end
    local preselectActionType = nil
    local preselectItemId = nil
    if multiSlotIndex and button.cache and button.cache.multiActions then
        local slot = button.cache.multiActions[multiSlotIndex]
        if slot and slot["useObject"] then
            preselectItemId = slot["useObject"]
            preselectActionType = slot["useType"]
        end
    end
    local fromSelect
    if multiSlotIndex then
        fromSelect = preselectItemId and preselectItemId ~= itemId or false
    else
        fromSelect = button.item:getItemId() > 0 and button.item:getItemId() ~= itemId
    end
    itemWidget:setItemId(itemId)
    if not item or item:getId() == 0 then
        item = itemWidget:getItem()
    end
    if item:getClassification() == 0 then
        itemTier = 0
    end
    if itemWidget:getItem() then
        ItemsDatabase.setTier(itemWidget, itemTier, false)
    end
    local checkboxWidgets = {{
        widget = checkbox1,
        useType = "UseOnYourself"
    }, {
        widget = checkbox2,
        useType = "UseOnTarget"
    }, {
        widget = checkbox3,
        useType = "UseAtCursorPosition"
    }, {
        widget = checkbox4,
        useType = "SelectUseTarget"
    }, {
        widget = checkbox5,
        useType = "Equip"
    }, {
        widget = checkbox6,
        useType = "Use"
    }}

    local activeActionType = multiSlotIndex and preselectActionType or button.cache.actionType
    local selectedCheckbox = nil
    for _, cbData in ipairs(checkboxWidgets) do
        if cbData.widget then
            cbData.widget:setEnabled(false)
            cbData.widget:setChecked(false)
        end
    end

    -- UseTypes: UseOnYourself=1, UseOnTarget=2, SelectUseTarget=3, UseAtCursorPosition=9
    if item:isMultiUse() then
        for _, cbData in ipairs(checkboxWidgets) do
            local useTypeIndex = UseTypes[cbData.useType]
            if (useTypeIndex <= UseTypes["SelectUseTarget"] or useTypeIndex == UseTypes["UseAtCursorPosition"]) and
                cbData.widget then
                cbData.widget:setEnabled(true)

                if not selectedCheckbox and
                    not (item:getClothSlot() > 0 or (item:getClothSlot() == 0 and item:getClassification() > 0)) then
                    if fromSelect or activeActionType == 0 or activeActionType == cbData.useType or
                        activeActionType == UseTypes[cbData.useType] then
                        selectedCheckbox = cbData.widget
                    end
                end
            end
        end
    end

    -- UseTypes: Equip=4
    if canEquipItem(item) then
        checkbox5:setEnabled(true)

        if not selectedCheckbox then
            if fromSelect or activeActionType == 0 or activeActionType == "Equip" or
                activeActionType == UseTypes["Equip"] then
                selectedCheckbox = checkbox5
            end
        end
    end

    -- UseTypes: Use=5 (items usables no-multiuso)
    if (item:isUsable() and not item:isMultiUse()) or item:isContainer() then
        checkbox6:setEnabled(true)

        if not selectedCheckbox then
            if fromSelect or activeActionType == 0 or activeActionType == "Use" or activeActionType ==
                UseTypes["Use"] then
                selectedCheckbox = checkbox6
            end
        end
    end
    buttonOk:setEnabled(item and item:getId() > 100)
    buttonApply:setEnabled(item and item:getId() > 100)
    if not selectedCheckbox then
        for _, cbData in ipairs(checkboxWidgets) do
            if cbData.widget and cbData.widget:isEnabled() then
                selectedCheckbox = cbData.widget
                break
            end
        end
    end
    if selectedCheckbox then
        selectedCheckbox:setChecked(true)
    end
    for _, cbData in ipairs(checkboxWidgets) do
        if cbData.widget then
            cbData.widget.onCheckChange = function(widget, checked)
                if checked then
                    for _, otherCbData in ipairs(checkboxWidgets) do
                        if otherCbData.widget and otherCbData.widget ~= widget and otherCbData.widget:isChecked() then
                            otherCbData.widget:setChecked(false)
                        end
                    end
                end
            end
        end
    end
    local function okFunc(destroy)
        local selected = nil
        for _, cbData in ipairs(checkboxWidgets) do
            if cbData.widget and cbData.widget:isChecked() then
                selected = cbData.useType
                break
            end
        end
        if not selected then
            return
        end
        local barID, buttonID = string.match(button:getId(), "^(%d+)%.(%d+)$")
        if not barID or not buttonID then
            return
        end
        local cache = getButtonCache(button)
        local cachedItem = cachedItemWidget[cache.itemId]
        if cachedItem then
            for index, widget in pairs(cachedItem) do
                if button == widget then
                    table.remove(cachedItem, index)
                    break
                end
            end
        end
        if multiSlotIndex then
            if not button.cache.multiActions then button.cache.multiActions = {{}, {}, {}} end
            button.cache.multiActions[multiSlotIndex] = {useObject = itemId, useType = selected, upgradeTier = itemTier, useEquipSmartMode = false}
            ApiJson.createOrUpdateMultiAction(tonumber(barID), tonumber(buttonID), multiSlotIndex, selected, itemId, itemTier, false)
            if updateMultiButtonState then updateMultiButtonState(button) end
            if assignMultiAction then assignMultiAction(button, true) end
        else
            ApiJson.createOrUpdateAction(tonumber(barID), tonumber(buttonID), selected, itemId, itemTier)
            updateButton(button)
        end

        if destroy then
            ActionBarController:unloadHtml()
        end
    end
    buttonOk.onClick = function()
        okFunc(true)
    end
    buttonApply.onClick = function()
        okFunc(false)
    end
    buttonClose.onClick = function()
        updateButton(button)
        ActionBarController:unloadHtml()
    end
    ui.onEnter = function()
        okFunc(true)
    end
    ui.onEscape = function()
        updateButton(button)
        ActionBarController:unloadHtml()
    end
    if actionbar.locked then
        ActionBarController:unloadHtml()
    end
end
-- /*=============================================
-- =            Passive html Windows          =
-- =============================================*/

function assignPassive(button)
    local actionbar = button:getParent():getParent()
    if actionbar.locked then
        alert('Action bar is locked')
        return
    end
    local radio = UIRadioGroup.create()
    if ActionBarController.ui then
        ActionBarController:unloadHtml()
    end
    ActionBarController:loadHtml('html/passive.html')
    local ui = ActionBarController.ui
    ui:show()
    ui:raise()
    ui:setTitle("Assign Passive to Action Button " .. button:getId())
    local passiveList = ActionBarController:findWidget("#passiveList")
    local previewWidget = ActionBarController:findWidget("#preview")
    local image = ActionBarController:findWidget("#image")
    for id, passiveData in pairs(PassiveAbilities) do
        local widget = g_ui.createWidget('PassivePreview', passiveList)
        radio:addWidget(widget)
        widget:setId(id)
        widget:setText(passiveData.name)
        widget.image:setImageSource(passiveData.icon)
        widget.source = passiveData.icon
    end
    radio.onSelectionChange = function(widget, selected)
        if selected then
            previewWidget:setText(selected:getText())
            image:setImageSource(selected.source)
            passiveList:ensureChildVisible(widget)
        end
    end
    local passiveChildren = passiveList:getChildren()
    if #passiveChildren > 0 then
        radio:selectWidget(passiveChildren[1])
    end
    local function okFunc(destroy)
        local selected = radio:getSelectedWidget()
        if not selected then
            return
        end
        local barID, buttonID = string.match(button:getId(), "(.*)%.(.*)")
        ApiJson.createOrUpdatePassive(tonumber(barID), tonumber(buttonID), tonumber(selected:getId()))
        updateButton(button)
        if destroy then
            ActionBarController:unloadHtml()
        end
    end
    local function cancelFunc()
        ActionBarController:unloadHtml()
    end
    ActionBarController:findWidget("#buttonOk").onClick = function()
        okFunc(true)
    end
    ActionBarController:findWidget("#buttonApply").onClick = function()
        okFunc(false)
    end
    ActionBarController:findWidget("#buttonClose").onClick = cancelFunc
    ui.onEnter = function()
        okFunc(true)
    end
end

function assignSpecialAction(button, mousePos)
    local actionbar = button:getParent():getParent()
    if actionbar.locked then
        alert('Action bar is locked')
        return
    end

    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)

    for _, specialAction in ipairs(ActionBarSpecialActions) do
        menu:addOption(specialAction.text, function()
            local barID, buttonID = string.match(button:getId(), "(.*)%.(.*)")
            ApiJson.createOrUpdateSpecialAction(tonumber(barID), tonumber(buttonID), specialAction.id)
            updateButton(button)
        end)
    end

    if button.cache and button.cache.specialAction then
        menu:addSeparator()
        menu:addOption(tr("Clear Assigned Action"), function()
            clearButton(button, true)
        end)
    end

    menu:display(mousePos)
end

-- /*=============================================
-- =            item Event external          =
-- =============================================*/
function onDropActionButton(self, mousePosition, mouseButton)
    if not g_ui.isMouseGrabbed() then
        return
    end
    -- Restore cursor
    if modules.client_options and modules.client_options.getOption('nativeCursor') then
        g_window.restoreMouseCursor()
    else
        g_mouse.popCursor('target')
    end
    self:ungrabMouse()
end

function assignItemEvent(button, multiSlotIndex)
    mouseGrabberWidget:grabMouse()
    -- Use native cursor when enabled, otherwise use custom cursor
    if modules.client_options and modules.client_options.getOption('nativeCursor') then
        g_window.setSystemCursor('cross')
    else
        g_mouse.pushCursor('target')
    end
    mouseGrabberWidget.onMouseRelease = function(self, mousePosition, mouseButton)
        onAssignItem(self, mousePosition, mouseButton, button, multiSlotIndex)
    end
end

function onAssignItem(self, mousePosition, mouseButton, button, multiSlotIndex)
    mouseGrabberWidget:ungrabMouse()
    -- Restore cursor
    if modules.client_options and modules.client_options.getOption('nativeCursor') then
        g_window.restoreMouseCursor()
    else
        g_mouse.popCursor('target')
    end
    mouseGrabberWidget.onMouseRelease = onDropActionButton

    local clickedWidget = gameRootPanel:recursiveGetChildByPos(mousePosition, false)
    if not clickedWidget then
        return true
    end

    local itemId = 0
    local itemTier = 0
    if clickedWidget:getClassName() == 'UIItem' and not clickedWidget:isVirtual() and clickedWidget:getItem() then
        itemId = clickedWidget:getItem():getId()
        itemTier = clickedWidget:getItem():getTier()
    elseif clickedWidget:getClassName() == 'UIGameMap' then
        local tile = clickedWidget:getTile(mousePosition)
        if tile then
            itemId = tile:getTopUseThing():getId()
        end
    end

    local itemType = g_things.getThingType(itemId, ThingCategoryItem)
    if not itemType or not itemType:isPickupable() then
        modules.game_textmessage.displayFailureMessage(tr('Invalid object'))
        return true
    end
    assignItem(button, itemId, itemTier, false, multiSlotIndex)
end

-- /*=============================================
-- =            Windows hotkeys html             =
-- =============================================*/
-- in modules\game_actionbar\html\hotkeys.html
