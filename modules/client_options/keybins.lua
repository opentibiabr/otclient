local actionNameLimit = 39
local changedOptions = {}
local changedKeybinds = {}
local changedHotkeys = {}
local presetWindow = nil
local actionSearchEvent
local keyEditWindow = nil
local chatModeGroup

-- controls and keybinds
function addNewPreset()
    presetWindow:setText(tr('Add hotkey preset'))

    presetWindow.info:setText(tr('Enter a name for the new preset:'))

    presetWindow.field:clearText()
    presetWindow.field:show()
    presetWindow.field:focus()

    presetWindow:setWidth(360)

    presetWindow.action = 'add'

    presetWindow:show()
    presetWindow:raise()
    presetWindow:focus()

    controller.ui:hide()
end

function copyPreset()
    presetWindow:setText(tr('Copy hotkey preset'))

    presetWindow.info:setText(tr('Enter a name for the new preset:'))

    presetWindow.field:clearText()
    presetWindow.field:show()
    presetWindow.field:focus()

    presetWindow.action = 'copy'

    presetWindow:setWidth(360)
    presetWindow:show()
    presetWindow:raise()
    presetWindow:focus()

    controller.ui:hide()
end

function renamePreset()
    presetWindow:setText(tr('Rename hotkey preset'))

    presetWindow.info:setText(tr('Enter a name for the preset:'))

    presetWindow.field:setText(panels.keybindsPanel.presets.list:getCurrentOption().text)
    presetWindow.field:setCursorPos(1000)
    presetWindow.field:show()
    presetWindow.field:focus()

    presetWindow.action = 'rename'

    presetWindow:setWidth(360)
    presetWindow:show()
    presetWindow:raise()
    presetWindow:focus()

    controller.ui:hide()
end

function removePreset()
    presetWindow:setText(tr('Warning'))

    presetWindow.info:setText(tr('Do you really want to delete the hotkey preset %s?',
        panels.keybindsPanel.presets.list:getCurrentOption().text))
    presetWindow.field:hide()
    presetWindow.action = 'remove'

    presetWindow:setWidth(presetWindow.info:getTextSize().width + presetWindow:getPaddingLeft() +
        presetWindow:getPaddingRight())
    presetWindow:show()
    presetWindow:raise()
    presetWindow:focus()

    controller.ui:hide()
end

function okPresetWindow()
    local presetName = presetWindow.field:getText():trim()
    local selectedPreset = panels.keybindsPanel.presets.list:getCurrentOption().text

    presetWindow:hide()
    show()

    if presetWindow.action == 'add' then
        Keybind.newPreset(presetName)
        if modules.game_actionbar and modules.game_actionbar.createHotkeySet then
            modules.game_actionbar.createHotkeySet(presetName, nil)
        end
        panels.keybindsPanel.presets.list:addOption(presetName)
        panels.keybindsPanel.presets.list:setCurrentOption(presetName)
    elseif presetWindow.action == 'copy' then
        if not Keybind.copyPreset(selectedPreset, presetName) then
            return
        end
        if modules.game_actionbar and modules.game_actionbar.createHotkeySet then
            modules.game_actionbar.createHotkeySet(presetName, selectedPreset)
        end
        panels.keybindsPanel.presets.list:addOption(presetName)
        panels.keybindsPanel.presets.list:setCurrentOption(presetName)
    elseif presetWindow.action == 'rename' then
        if selectedPreset ~= presetName then
            panels.keybindsPanel.presets.list:updateCurrentOption(presetName)
            if changedOptions['currentPreset'] then
                changedOptions['currentPreset'].value = presetName
            end
            Keybind.renamePreset(selectedPreset, presetName)
            if modules.game_actionbar and modules.game_actionbar.renameHotkeySet then
                modules.game_actionbar.renameHotkeySet(selectedPreset, presetName)
            end
        end
    elseif presetWindow.action == 'remove' then
        if Keybind.removePreset(selectedPreset) then
            panels.keybindsPanel.presets.list:removeOption(selectedPreset)
            if modules.game_actionbar and modules.game_actionbar.removeHotkeySet then
                modules.game_actionbar.removeHotkeySet(selectedPreset)
                if modules.game_actionbar.selectHotkeySet then
                    modules.game_actionbar.selectHotkeySet(Keybind.currentPreset)
                end
            end
        end
    end
end

function cancelPresetWindow()
    presetWindow:hide()
    show()
end

function editKeybindKeyDown(widget, keyCode, keyboardModifiers)
    keyEditWindow.keyCombo:setText(determineKeyComboDesc(keyCode,
        keyEditWindow.alone:isVisible() and KeyboardNoModifier or keyboardModifiers))

    local category = nil
    local action = nil

    if keyEditWindow.keybind then
        category = keyEditWindow.keybind.category
        action = keyEditWindow.keybind.action
    end

    local keyCombo = keyEditWindow.keyCombo:getText()
    local keyUsed = Keybind.isKeyComboUsed(keyCombo, category, action, getChatMode())
    if not keyUsed then
        for _, change in ipairs(changedHotkeys) do
            if change.primary == keyCombo or change.secondary == keyCombo then
                keyUsed = true
                break
            end
        end
    end

    keyEditWindow.buttons.ok:setEnabled(not keyUsed)
    keyEditWindow.used:setVisible(keyUsed)
end

function editKeybind(keybind)
    keyEditWindow.buttons.cancel.onClick = function()
        disconnect(keyEditWindow, {
            onKeyDown = editKeybindKeyDown
        })
        keyEditWindow:hide()
        keyEditWindow:ungrabKeyboard()
        show()
    end

    keyEditWindow.info:setText(tr(
        'Click \'Ok\' to assign the keybind. Click \'Clear\' to remove the keybind from \'%s: %s\'.', keybind.category,
        keybind.action))
    keyEditWindow.alone:setVisible(keybind.alone)

    connect(keyEditWindow, {
        onKeyDown = editKeybindKeyDown
    })

    keyEditWindow:show()
    keyEditWindow:raise()
    keyEditWindow:focus()
    keyEditWindow:grabKeyboard()
    hide()
end

function editKeybindPrimary(button)
    local column = button:getParent()
    local row = column:getParent()
    local index = row.category .. '_' .. row.action
    local keybind = Keybind.getAction(row.category, row.action)
    local preset = panels.keybindsPanel.presets.list:getCurrentOption().text

    keyEditWindow.keybind = {
        category = row.category,
        action = row.action
    }

    keyEditWindow:setText(tr('Edit Primary Key for \'%s\'', string.format('%s: %s', keybind.category, keybind.action)))
    keyEditWindow.keyCombo:setText(Keybind.getKeybindKeys(row.category, row.action, getChatMode(), preset).primary)

    editKeybind(keybind)

    keyEditWindow.buttons.ok.onClick = function()
        local keyCombo = keyEditWindow.keyCombo:getText()

        column:setText(keyEditWindow.keyCombo:getText())

        if not changedKeybinds[preset] then
            changedKeybinds[preset] = {}
        end
        if not changedKeybinds[preset][index] then
            changedKeybinds[preset][index] = {}
        end
        changedKeybinds[preset][index].primary = {
            category = row.category,
            action = row.action,
            keyCombo = keyCombo
        }

        disconnect(keyEditWindow, {
            onKeyDown = editKeybindKeyDown
        })
        keyEditWindow:hide()
        keyEditWindow:ungrabKeyboard()
        show()
        applyChangedOptions()
    end

    keyEditWindow.buttons.clear.onClick = function()
        if not changedKeybinds[preset] then
            changedKeybinds[preset] = {}
        end
        if not changedKeybinds[preset][index] then
            changedKeybinds[preset][index] = {}
        end
        changedKeybinds[preset][index].primary = {
            category = row.category,
            action = row.action,
            keyCombo = ''
        }

        column:setText('')

        disconnect(keyEditWindow, {
            onKeyDown = editKeybindKeyDown
        })
        keyEditWindow:hide()
        keyEditWindow:ungrabKeyboard()
        show()
        applyChangedOptions()
    end
end

function editKeybindSecondary(button)
    local column = button:getParent()
    local row = column:getParent()
    local index = row.category .. '_' .. row.action
    local keybind = Keybind.getAction(row.category, row.action)
    local preset = panels.keybindsPanel.presets.list:getCurrentOption().text

    keyEditWindow.keybind = {
        category = row.category,
        action = row.action
    }

    keyEditWindow:setText(tr('Edit Secondary Key for \'%s\'', string.format('%s: %s', keybind.category, keybind.action)))
    keyEditWindow.keyCombo:setText(Keybind.getKeybindKeys(row.category, row.action, getChatMode(), preset).secondary)

    editKeybind(keybind)

    keyEditWindow.buttons.ok.onClick = function()
        local keyCombo = keyEditWindow.keyCombo:getText()

        column:setText(keyEditWindow.keyCombo:getText())

        if not changedKeybinds[preset] then
            changedKeybinds[preset] = {}
        end
        if not changedKeybinds[preset][index] then
            changedKeybinds[preset][index] = {}
        end
        changedKeybinds[preset][index].secondary = {
            category = row.category,
            action = row.action,
            keyCombo = keyCombo
        }

        disconnect(keyEditWindow, {
            onKeyDown = editKeybindKeyDown
        })
        keyEditWindow:hide()
        keyEditWindow:ungrabKeyboard()
        show()
        applyChangedOptions()
    end

    keyEditWindow.buttons.clear.onClick = function()
        if not changedKeybinds[preset] then
            changedKeybinds[preset] = {}
        end
        if not changedKeybinds[preset][index] then
            changedKeybinds[preset][index] = {}
        end
        changedKeybinds[preset][index].secondary = {
            category = row.category,
            action = row.action,
            keyCombo = ''
        }

        column:setText('')

        disconnect(keyEditWindow, {
            onKeyDown = editKeybindKeyDown
        })
        keyEditWindow:hide()
        keyEditWindow:ungrabKeyboard()
        show()
        applyChangedOptions()
    end
end

function resetActions()
    changedOptions['resetKeybinds'] = {
        value = panels.keybindsPanel.presets.list:getCurrentOption().text
    }
    updateKeybinds()
    applyChangedOptions()
end

function updateKeybinds()
    panels.keybindsPanel.tablePanel.keybinds:clearData()

    local sortedKeybinds = {}

    for index, _ in pairs(Keybind.defaultKeybinds) do
        table.insert(sortedKeybinds, index)
    end

    table.sort(sortedKeybinds, function(a, b)
        local keybindA = Keybind.defaultKeybinds[a]
        local keybindB = Keybind.defaultKeybinds[b]

        if keybindA.category ~= keybindB.category then
            return keybindA.category < keybindB.category
        end
        return keybindA.action < keybindB.action
    end)


    local comboBox = panels.keybindsPanel.presets.list:getCurrentOption()
    if not comboBox then
        return
    end
    for _, index in ipairs(sortedKeybinds) do
        local keybind = Keybind.defaultKeybinds[index]
        local keys = Keybind.getKeybindKeys(keybind.category, keybind.action, getChatMode(), comboBox.text,
            changedOptions['resetKeybinds'])
        addKeybind(keybind.category, keybind.action, keys.primary, keys.secondary)
    end
end

function updateHotkeys()
    panels.keybindsPanel.tablePanel.keybinds:clearData()

    local chatMode = getChatMode()
    local preset = panels.keybindsPanel.presets.list:getCurrentOption().text
    if Keybind.hotkeys[chatMode][preset] then
        for _, hotkey in ipairs(Keybind.hotkeys[chatMode][preset]) do
            addHotkey(hotkey.hotkeyId, hotkey.action, hotkey.data, hotkey.primary, hotkey.secondary)
        end
    end
end

function preAddHotkey(action, data)
    local preset = panels.keybindsPanel.presets.list:getCurrentOption().text
    local chatMode = getChatMode()
    local hotkeyId = #changedHotkeys + 1

    if Keybind.hotkeys[chatMode] and Keybind.hotkeys[chatMode][preset] then
        hotkeyId = hotkeyId + #Keybind.hotkeys[chatMode][preset]
    end

    table.insert(changedHotkeys, {
        hotkeyId = hotkeyId,
        action = action,
        data = data,
        new = true
    })

    addHotkey(hotkeyId, action, data)
end

function addKeybind(category, action, primary, secondary)
    local rawText = string.format('%s: %s', category, action)
    local text = string.format('[color=#ffffff]%s:[/color] %s', category, action)
    local tooltip = nil

    if rawText:len() > actionNameLimit then
        tooltip = rawText
        -- 15 and 8 are length of color codes
        text = text:sub(1, actionNameLimit + 15 + 8) .. '...'
    end

    local row = panels.keybindsPanel.tablePanel.keybinds:addRow({ {
        coloredText = {
            text = text,
            color = '#c0c0c0'
        },
        width = 286
    }, {
        style = 'VerticalSeparator'
    }, {
        style = 'EditableKeybindsTableColumn',
        text = primary,
        width = 100
    }, {
        style = 'VerticalSeparator'
    }, {
        style = 'EditableKeybindsTableColumn',
        text = secondary,
        width = 90
    } })

    row.category = category
    row.action = action

    if tooltip then
        row:setTooltip(tooltip)
    end

    row:getChildByIndex(3).edit.onClick = editKeybindPrimary
    row:getChildByIndex(5).edit.onClick = editKeybindSecondary
end

function clearHotkey(row)
    table.insert(changedHotkeys, {
        hotkeyId = row.hotkeyId,
        remove = true
    })
    panels.keybindsPanel.tablePanel.keybinds:removeRow(row)
end

function editHotkeyKey(text)
    keyEditWindow.buttons.cancel.onClick = function()
        disconnect(keyEditWindow, {
            onKeyDown = editKeybindKeyDown
        })
        keyEditWindow:hide()
        keyEditWindow:ungrabKeyboard()
        show()
    end

    keyEditWindow.info:setText(tr(
        'Click \'Ok\' to assign the keybind. Click \'Clear\' to remove the keybind from \'%s\'.', text))
    keyEditWindow.alone:setVisible(false)

    connect(keyEditWindow, {
        onKeyDown = editKeybindKeyDown
    })

    keyEditWindow:show()
    keyEditWindow:raise()
    keyEditWindow:focus()
    keyEditWindow:grabKeyboard()
    hide()
end

function editHotkeyPrimary(button)
    local column = button:getParent()
    local row = column:getParent()
    local text = row:getChildByIndex(1):getText()
    local hotkeyId = row.hotkeyId
    local preset = panels.keybindsPanel.presets.list:getCurrentOption().text

    keyEditWindow:setText(tr('Edit Primary Key for \'%s\'', text))
    keyEditWindow.keyCombo:setText(Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).primary)

    editHotkeyKey(text)

    keyEditWindow.buttons.ok.onClick = function()
        local keyCombo = keyEditWindow.keyCombo:getText()

        column:setText(keyEditWindow.keyCombo:getText())

        local changed = table.findbyfield(changedHotkeys, 'hotkeyId', hotkeyId)
        if changed then
            changed.primary = keyCombo
            if not changed.secondary then
                changed.secondary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).secondary
            end
            changed.editKey = true
        else
            table.insert(changedHotkeys, {
                hotkeyId = hotkeyId,
                primary = keyCombo,
                secondary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).secondary,
                editKey = true
            })
        end

        disconnect(keyEditWindow, {
            onKeyDown = editKeybindKeyDown
        })
        keyEditWindow:hide()
        keyEditWindow:ungrabKeyboard()
        show()
    end

    keyEditWindow.buttons.clear.onClick = function()
        column:setText('')

        local changed = table.findbyfield(changedHotkeys, 'hotkeyId', hotkeyId)
        if changed then
            changed.primary = nil
            if not changed.secondary then
                changed.secondary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).secondary
            end
            changed.editKey = true
        else
            table.insert(changedHotkeys, {
                hotkeyId = hotkeyId,
                secondary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).secondary,
                editKey = true
            })
        end

        disconnect(keyEditWindow, {
            onKeyDown = editKeybindKeyDown
        })
        keyEditWindow:hide()
        keyEditWindow:ungrabKeyboard()
        show()
    end
end

function editHotkeySecondary(button)
    local column = button:getParent()
    local row = column:getParent()
    local text = row:getChildByIndex(1):getText()
    local hotkeyId = row.hotkeyId
    local preset = panels.keybindsPanel.presets.list:getCurrentOption().text

    keyEditWindow:setText(tr('Edit Secondary Key for \'%s\'', text))
    keyEditWindow.keyCombo:setText(Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).secondary)

    editHotkeyKey(text)

    keyEditWindow.buttons.ok.onClick = function()
        local keyCombo = keyEditWindow.keyCombo:getText()

        column:setText(keyEditWindow.keyCombo:getText())

        if changedHotkeys[hotkeyId] then
            if not changedHotkeys[hotkeyId].primary then
                changedHotkeys[hotkeyId].primary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).primary
            end
            changedHotkeys[hotkeyId].secondary = keyCombo
            changedHotkeys[hotkeyId].editKey = true
        else
            table.insert(changedHotkeys, {
                hotkeyId = hotkeyId,
                primary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).primary,
                secondary = keyCombo,
                editKey = true
            })
        end

        disconnect(keyEditWindow, {
            onKeyDown = editKeybindKeyDown
        })
        keyEditWindow:hide()
        keyEditWindow:ungrabKeyboard()
        show()
    end

    keyEditWindow.buttons.clear.onClick = function()
        column:setText('')

        if changedHotkeys[hotkeyId] then
            if not changedHotkeys[hotkeyId].primary then
                changedHotkeys[hotkeyId].primary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).primary
            end
            changedHotkeys[hotkeyId].secondary = nil
            changedHotkeys[hotkeyId].editKey = true
        else
            table.insert(changedHotkeys, {
                hotkeyId = hotkeyId,
                primary = Keybind.getHotkeyKeys(hotkeyId, preset, getChatMode()).primary,
                editKey = true
            })
        end

        disconnect(keyEditWindow, {
            onKeyDown = editKeybindKeyDown
        })
        keyEditWindow:hide()
        keyEditWindow:ungrabKeyboard()
        show()
    end
end

function searchActions(field, text, oldText)
    if actionSearchEvent then
        removeEvent(actionSearchEvent)
    end

    actionSearchEvent = scheduleEvent(performeSearchActions, 200)
end

function performeSearchActions()
    local searchText = panels.keybindsPanel.search.field:getText():trim():lower():gsub("%+", "%%+")

    local rows = panels.keybindsPanel.tablePanel.keybinds.dataSpace:getChildren()
    if searchText:len() > 0 then
        for _, row in ipairs(rows) do
            row:hide()
        end

        for _, row in ipairs(rows) do
            local actionText = row:getChildByIndex(1):getText():lower()
            local primaryText = row:getChildByIndex(3):getText():lower()
            local secondaryText = row:getChildByIndex(5):getText():lower()
            if actionText:find(searchText) or primaryText:find(searchText) or secondaryText:find(searchText) then
                row:show()
            end
        end
    else
        for _, row in ipairs(rows) do
            row:show()
        end
    end

    removeEvent(actionSearchEvent)
    actionSearchEvent = nil
end

function chatModeChange()
    changedHotkeys = {}
    changedKeybinds = {}

    panels.keybindsPanel.search.field:clearText()

    updateKeybinds()
end

function getChatMode()
    if chatModeGroup:getSelectedWidget() == panels.keybindsPanel.panel.chatMode.on then
        return CHAT_MODE.ON
    end

    return CHAT_MODE.OFF
end

function applyChangedOptions()
    local needKeybindsUpdate = false
    local needHotkeysUpdate = false

    for key, option in pairs(changedOptions) do
        if key == 'resetKeybinds' then
            Keybind.resetKeybindsToDefault(option.value, option.chatMode)
            needKeybindsUpdate = true
        end
    end
    changedOptions = {}

    for preset, keybinds in pairs(changedKeybinds) do
        for index, keybind in pairs(keybinds) do
            if keybind.primary then
                if Keybind.setPrimaryActionKey(keybind.primary.category, keybind.primary.action, preset,
                        keybind.primary.keyCombo, getChatMode()) then
                    needKeybindsUpdate = true
                end
            elseif keybind.secondary then
                if Keybind.setSecondaryActionKey(keybind.secondary.category, keybind.secondary.action, preset,
                        keybind.secondary.keyCombo, getChatMode()) then
                    needKeybindsUpdate = true
                end
            end
        end
    end
    changedKeybinds = {}

    if needKeybindsUpdate then
        updateKeybinds()
    end
    g_settings.save()
end

function presetOption(widget, key, value, force)
    if not controller.ui:isVisible() then
        return
    end

    changedOptions[key] = { widget = widget, value = value, force = force }
    if key == "currentPreset" then
        Keybind.selectPreset(value)
        panels.keybindsPanel.presets.list:setCurrentOption(value, true)
    end
end

function init_binds()
    chatModeGroup = UIRadioGroup.create()
    chatModeGroup:addWidget(panels.keybindsPanel.panel.chatMode.on)
    chatModeGroup:addWidget(panels.keybindsPanel.panel.chatMode.off)
    chatModeGroup.onSelectionChange = chatModeChange
    chatModeGroup:selectWidget(panels.keybindsPanel.panel.chatMode.on)

    keyEditWindow = g_ui.displayUI("styles/controls/key_edit")
    keyEditWindow:hide()
    presetWindow = g_ui.displayUI("styles/controls/preset")
    presetWindow:hide()
    panels.keybindsPanel.presets.add.onClick = addNewPreset
    panels.keybindsPanel.presets.copy.onClick = copyPreset
    panels.keybindsPanel.presets.rename.onClick = renamePreset
    panels.keybindsPanel.presets.remove.onClick = removePreset
    panels.keybindsPanel.buttons.newAction:disable()
    panels.keybindsPanel.buttons.newAction.onClick = newHotkeyAction
    panels.keybindsPanel.buttons.reset.onClick = resetActions
    panels.keybindsPanel.search.field.onTextChange = searchActions
    panels.keybindsPanel.search.clear.onClick = function() panels.keybindsPanel.search.field:clearText() end
    presetWindow.onEnter = okPresetWindow
    presetWindow.onEscape = cancelPresetWindow
    presetWindow.buttons.ok.onClick = okPresetWindow
    presetWindow.buttons.cancel.onClick = cancelPresetWindow
    if g_platform.isMobile() then
        panels.keybindsPanel.tablePanel:hide()
    end
end

function terminate_binds()
    if presetWindow then
        presetWindow:destroy()
        presetWindow = nil
    end

    if chatModeGroup then
        chatModeGroup:destroy()
        chatModeGroup = nil
    end

    if keyEditWindow then
        if keyEditWindow:isVisible() then
            keyEditWindow:ungrabKeyboard()
            disconnect(keyEditWindow, { onKeyDown = editKeybindKeyDown })
        end
        keyEditWindow:destroy()
        keyEditWindow = nil
    end

    actionSearchEvent = nil
end

function listKeybindsComboBox(value)
    local widget = panels.keybindsPanel.presets.list
    presetOption(widget, 'currentPreset', value, false)
    if modules.game_actionbar and modules.game_actionbar.selectHotkeySet then
        modules.game_actionbar.selectHotkeySet(value)
    end
    changedKeybinds = {}
    changedHotkeys = {}
    applyChangedOptions()
    updateKeybinds()
end

function debug()
    local currentOptionText = Keybind.currentPreset
    local chatMode = Keybind.chatMode
    local chatModeText = (chatMode == 1) and "Chat mode ON" or (chatMode == 2) and "Chat mode OFF" or "Unknown chat mode"
    print(string.format("The current configuration is: %s, and the mode is: %s", currentOptionText, chatModeText))
end
