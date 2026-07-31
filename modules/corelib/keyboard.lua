-- @docclass
g_keyboard = {}

local function getPlatformFlags()
    local platformType = g_window.getPlatformType() or ""
    local isMacOS = platformType:find("MACOS") ~= nil
    return isMacOS, not isMacOS
end

local function resolveKeyAlias(desc)
    if not desc then
        return nil
    end
    local key = desc:trim():lower()
    local isMacOS = getPlatformFlags()
    if key == 'cmd' or key == 'command' then
        return KeyMeta
    end
    if key == 'primary' then
        if isMacOS then
            return KeyMeta
        end
        return KeyCtrlCmd
    end
    if key == 'ctrl' then
        if isMacOS then
            return KeyMeta
        end
        return KeyCtrlCmd
    end
    if key == 'control' then
        return KeyCtrlCmd
    end
    if key == 'alt' or key == 'option' then
        return KeyAltOpt
    end
    if key == 'meta' or key == 'win' or key == 'super' then
        return KeyMeta
    end
    return nil
end

-- private functions
local function canonicalizeKeyCombo(keyCombo)
    if not keyCombo or #keyCombo == 0 then
        return keyCombo
    end
    local hasCtrl = false
    local hasMeta = false
    local hasAlt = false
    local hasShift = false
    local mainKey = nil
    for _, keyCode in ipairs(keyCombo) do
        if keyCode == KeyCtrlCmd or keyCode == KeyControl then
            hasCtrl = true
        elseif keyCode == KeyMeta then
            hasMeta = true
        elseif keyCode == KeyAltOpt then
            hasAlt = true
        elseif keyCode == KeyShift then
            hasShift = true
        else
            mainKey = keyCode
        end
    end
    local combo = {}
    if hasCtrl then
        table.insert(combo, KeyCtrlCmd)
    end
    if hasMeta then
        table.insert(combo, KeyMeta)
    end
    if hasAlt then
        table.insert(combo, KeyAltOpt)
    end
    if hasShift then
        table.insert(combo, KeyShift)
    end
    if mainKey then
        table.insert(combo, mainKey)
    end
    return combo
end

function translateKeyCombo(keyCombo)
    if not keyCombo or #keyCombo == 0 then
        return nil
    end
    local keyComboDesc = ''
    for _, v in ipairs(keyCombo) do
        local keyDesc = KeyCodeDescs[v]
        if keyDesc == nil then
            return nil
        end
        keyComboDesc = keyComboDesc .. '+' .. keyDesc
    end
    keyComboDesc = keyComboDesc:sub(2)
    return keyComboDesc
end

local function getKeyCode(key)
    local alias = resolveKeyAlias(key)
    if alias then
        return alias
    end
    for keyCode, keyDesc in pairs(KeyCodeDescs) do
        if keyDesc:lower() == key:trim():lower() then
            return keyCode
        end
    end
end

function retranslateKeyComboDesc(keyComboDesc)
    if keyComboDesc == nil then
        error('Unable to translate key combo \'' .. keyComboDesc .. '\'')
    end

    if type(keyComboDesc) == 'number' then
        keyComboDesc = tostring(keyComboDesc)
    end

    local keyCombo = {}
    for i, currentKeyDesc in ipairs(keyComboDesc:split('+')) do
        local alias = resolveKeyAlias(currentKeyDesc)
        if alias then
            table.insert(keyCombo, alias)
        else
        for keyCode, keyDesc in pairs(KeyCodeDescs) do
            if keyDesc:lower() == currentKeyDesc:trim():lower() then
                table.insert(keyCombo, keyCode)
            end
        end
        end
    end
    return translateKeyCombo(canonicalizeKeyCombo(keyCombo))
end

function determineKeyComboDesc(keyCode, keyboardModifiers)
    local isMacOS = getPlatformFlags()
    local keyCombo = {}
    if keyCode == KeyShift or keyCode == KeyAltOpt or keyCode == KeyMeta or keyCode == KeyCtrlCmd then
        table.insert(keyCombo, keyCode)
    elseif keyCode == KeyControl then
        table.insert(keyCombo, KeyCtrlCmd)
    elseif KeyCodeDescs[keyCode] ~= nil then
        local primaryPressed = bit.band(keyboardModifiers, KeyboardPrimaryModifier) ~= 0
        local ctrlPressed = bit.band(keyboardModifiers, KeyboardCtrlModifier) ~= 0
        local metaPressed = bit.band(keyboardModifiers, KeyboardMetaModifier) ~= 0

        if isMacOS then
            if ctrlPressed then
                table.insert(keyCombo, KeyCtrlCmd)
            end
            if primaryPressed or metaPressed then
                table.insert(keyCombo, KeyMeta)
            end
        else
            if ctrlPressed or primaryPressed then
                table.insert(keyCombo, KeyCtrlCmd)
            end
            if metaPressed then
                table.insert(keyCombo, KeyMeta)
            end
        end
        if bit.band(keyboardModifiers, KeyboardAltModifier) ~= 0 then
            table.insert(keyCombo, KeyAltOpt)
        end
        if bit.band(keyboardModifiers, KeyboardShiftModifier) ~= 0 then
            table.insert(keyCombo, KeyShift)
        end
        table.insert(keyCombo, keyCode)
    end
    return translateKeyCombo(keyCombo)
end

local function onWidgetKeyDown(widget, keyCode, keyboardModifiers)
    if keyCode == KeyUnknown then
        return false
    end
    local callback
    if keyboardModifiers == KeyboardNoModifier then
        callback = widget.boundAloneKeyDownCombos[determineKeyComboDesc(keyCode, KeyboardNoModifier)]
        signalcall(callback, widget, keyCode)
    end
    callback = widget.boundKeyDownCombos[determineKeyComboDesc(keyCode, keyboardModifiers)]
    return signalcall(callback, widget, keyCode)
end

local function onWidgetKeyUp(widget, keyCode, keyboardModifiers)
    if keyCode == KeyUnknown then
        return false
    end
    local callback = widget.boundAloneKeyUpCombos[determineKeyComboDesc(keyCode, KeyboardNoModifier)]
    signalcall(callback, widget, keyCode)
    callback = widget.boundKeyUpCombos[determineKeyComboDesc(keyCode, keyboardModifiers)]
    return signalcall(callback, widget, keyCode)
end

local function onWidgetKeyPress(widget, keyCode, keyboardModifiers, autoRepeatTicks)
    if keyCode == KeyUnknown then
        return false
    end
    if not widget.boundKeyPressCombos then
        return false
    end
    local callback = widget.boundKeyPressCombos[determineKeyComboDesc(keyCode, keyboardModifiers)]
    return signalcall(callback, widget, keyCode, autoRepeatTicks)
end

local function connectKeyDownEvent(widget)
    if widget.boundKeyDownCombos then
        return
    end
    connect(widget, {
        onKeyDown = onWidgetKeyDown
    })
    widget.boundKeyDownCombos = {}
    widget.boundAloneKeyDownCombos = {}
end

local function connectKeyUpEvent(widget)
    if widget.boundKeyUpCombos then
        return
    end
    connect(widget, {
        onKeyUp = onWidgetKeyUp
    })
    widget.boundKeyUpCombos = {}
    widget.boundAloneKeyUpCombos = {}
end

local function connectKeyPressEvent(widget)
    if widget.boundKeyPressCombos then
        return
    end
    connect(widget, {
        onKeyPress = onWidgetKeyPress
    })
    widget.boundKeyPressCombos = {}
end

function g_keyboard.setKeyDelay(key, delay)
    g_window.setKeyDelay(getKeyCode(key), delay);
end

-- public functions
function g_keyboard.bindKeyDown(keyComboDesc, callback, widget, alone)
    widget = widget or rootWidget
    connectKeyDownEvent(widget)
    local keyComboDesc = retranslateKeyComboDesc(keyComboDesc)
    if alone then
        connect(widget.boundAloneKeyDownCombos, keyComboDesc, callback)
    else
        connect(widget.boundKeyDownCombos, keyComboDesc, callback)
    end
end

function g_keyboard.bindKeyUp(keyComboDesc, callback, widget, alone)
    widget = widget or rootWidget
    connectKeyUpEvent(widget)
    local keyComboDesc = retranslateKeyComboDesc(keyComboDesc)
    if alone then
        connect(widget.boundAloneKeyUpCombos, keyComboDesc, callback)
    else
        connect(widget.boundKeyUpCombos, keyComboDesc, callback)
    end
end

function g_keyboard.bindKeyPress(keyComboDesc, callback, widget)
    widget = widget or rootWidget
    connectKeyPressEvent(widget)
    local keyComboDesc = retranslateKeyComboDesc(keyComboDesc)
    connect(widget.boundKeyPressCombos, keyComboDesc, callback)
end

local function getUnbindArgs(arg1, arg2)
    local callback
    local widget
    if type(arg1) == 'function' then
        callback = arg1
    elseif type(arg2) == 'function' then
        callback = arg2
    end
    if type(arg1) == 'userdata' then
        widget = arg1
    elseif type(arg2) == 'userdata' then
        widget = arg2
    end
    widget = widget or rootWidget
    return callback, widget
end

function g_keyboard.unbindKeyDown(keyComboDesc, arg1, arg2)
    local callback, widget = getUnbindArgs(arg1, arg2)
    if widget.boundKeyDownCombos == nil then
        return
    end
    local keyComboDesc = retranslateKeyComboDesc(keyComboDesc)
    disconnect(widget.boundKeyDownCombos, keyComboDesc, callback)
end

function g_keyboard.unbindKeyUp(keyComboDesc, arg1, arg2)
    local callback, widget = getUnbindArgs(arg1, arg2)
    if widget.boundKeyUpCombos == nil then
        return
    end
    local keyComboDesc = retranslateKeyComboDesc(keyComboDesc)
    disconnect(widget.boundKeyUpCombos, keyComboDesc, callback)
end

function g_keyboard.unbindKeyPress(keyComboDesc, arg1, arg2)
    local callback, widget = getUnbindArgs(arg1, arg2)
    if widget.boundKeyPressCombos == nil then
        return
    end
    local keyComboDesc = retranslateKeyComboDesc(keyComboDesc)
    disconnect(widget.boundKeyPressCombos, keyComboDesc, callback)
end

function g_keyboard.getModifiers()
    return g_window.getKeyboardModifiers()
end

function g_keyboard.isKeyPressed(key)
    if type(key) == 'string' then
        key = getKeyCode(key)
    end
    return g_window.isKeyPressed(key)
end

function g_keyboard.isKeySetPressed(keys, all)
    all = all or false
    local result = {}
    for k, v in pairs(keys) do
        if type(v) == 'string' then
            v = getKeyCode(v)
        end
        if g_window.isKeyPressed(v) then
            if not all then
                return true
            end
            table.insert(result, true)
        end
    end
    return #result == #keys
end

function g_keyboard.isInUse()
    for i = FirstKey, LastKey do
        if g_window.isKeyPressed(key) then
            return true
        end
    end
    return false
end

function g_keyboard.isCtrlPressed()
    if (g_platform.isMobile()) then
        return false
    else
        return bit.band(g_window.getKeyboardModifiers(), KeyboardPrimaryModifier) ~= 0
    end
end

function g_keyboard.isPrimaryPressed()
    if (g_platform.isMobile()) then
        return false
    else
        return bit.band(g_window.getKeyboardModifiers(), KeyboardPrimaryModifier) ~= 0
    end
end

function g_keyboard.isAltPressed()
    if (g_platform.isMobile()) then
        return false
    else
        return bit.band(g_window.getKeyboardModifiers(), KeyboardAltModifier) ~= 0
    end
end

function g_keyboard.isShiftPressed()
    if (g_platform.isMobile()) then
        return false
    else
        return bit.band(g_window.getKeyboardModifiers(), KeyboardShiftModifier) ~= 0
    end
end

function g_keyboard.isControlPressed()
    if (g_platform.isMobile()) then
        return false
    else
        return bit.band(g_window.getKeyboardModifiers(), KeyboardCtrlModifier) ~= 0
    end
end

function g_keyboard.isMetaPressed()
    if (g_platform.isMobile()) then
        return false
    else
        return bit.band(g_window.getKeyboardModifiers(), KeyboardMetaModifier) ~= 0
    end
end

local function hasOnlyModifiers(modifiers, requiredMask, allowedMask)
    return bit.band(modifiers, requiredMask) == requiredMask and bit.band(modifiers, allowedMask) == modifiers
end

local function primaryAllowedMask()
    local _, primaryIsCtrl = getPlatformFlags()
    if primaryIsCtrl then
        return bit.bor(KeyboardPrimaryModifier, KeyboardCtrlModifier)
    end
    return KeyboardPrimaryModifier
end

function g_keyboard.isPrimaryModifierOnly(keyboardModifiers)
    if (g_platform.isMobile()) then
        return false
    end
    local allowedMask = primaryAllowedMask()
    return hasOnlyModifiers(keyboardModifiers, KeyboardPrimaryModifier, allowedMask)
end

function g_keyboard.isPrimaryShiftModifierOnly(keyboardModifiers)
    if (g_platform.isMobile()) then
        return false
    end
    local requiredMask = bit.bor(KeyboardPrimaryModifier, KeyboardShiftModifier)
    local allowedMask = requiredMask
    local _, primaryIsCtrl = getPlatformFlags()
    if primaryIsCtrl then
        allowedMask = bit.bor(allowedMask, KeyboardCtrlModifier)
    end
    return hasOnlyModifiers(keyboardModifiers, requiredMask, allowedMask)
end
