local ApiJson = {}
local state = {
    actionBar = {},
    actionBarMappings = {},
    clientOptions = {},
    chatOptions = {},
    isChatOnEnabled = false,
    bootstrapComplete = false
}

local DEFAULT_SETTINGS_FILE = "/settings/clientoptions.json"
local DEFAULT_OPTIONS_FILE = "/modules/game_actionbar/json/cipsoft-default-options-minimal.json"

local SAVED_TOP_LEVEL_KEYS = {
    chatOptions = true,
    hotkeyOptions = true,
    options = true,
    profiles = true
}

local function isSequentialArray(value)
    local count = 0
    local maxIndex = 0

    for key in pairs(value) do
        if type(key) ~= 'number' or key <= 0 or key % 1 ~= 0 then
            return false, 0
        end

        if key > maxIndex then
            maxIndex = key
        end

        count = count + 1
    end

    return count == maxIndex, maxIndex
end

local function sanitizeValue(value, visited)
    local valueType = type(value)
    if valueType ~= 'table' then
        if valueType == 'number' or valueType == 'string' or valueType == 'boolean' or value == nil then
            return value
        end
        return nil
    end

    visited = visited or {}
    if visited[value] then
        return visited[value]
    end

    local isArray, maxIndex = isSequentialArray(value)
    local sanitized = {}
    visited[value] = sanitized

    if isArray then
        for index = 1, maxIndex do
            local entry = sanitizeValue(value[index], visited)
            if entry ~= nil then
                sanitized[#sanitized + 1] = entry
            end
        end
    else
        for key, entry in pairs(value) do
            local keyType = type(key)
            if keyType == 'string' or keyType == 'number' then
                local sanitizedEntry = sanitizeValue(entry, visited)
                if sanitizedEntry ~= nil then
                    sanitized[keyType == 'number' and tostring(key) or key] = sanitizedEntry
                end
            end
        end
    end

    return sanitized
end

local function sanitizeTopLevelArray(array)
    if type(array) ~= 'table' then
        array = {}
    end

    local sanitized = {}
    for key in pairs(SAVED_TOP_LEVEL_KEYS) do
        local value = array[key]
        if value ~= nil then
            sanitized[key] = sanitizeValue(value, {})
        end
    end

    sanitized.options = sanitized.options or {}
    sanitized.chatOptions = sanitized.chatOptions or {}
    sanitized.hotkeyOptions = sanitized.hotkeyOptions or {}
    sanitized.hotkeyOptions.hotkeySets = sanitizeValue(sanitized.hotkeyOptions.hotkeySets or {}, {})

    sanitized.profiles = sanitizeValue(sanitized.profiles or {}, {})

    return sanitized
end

local replace = {
    ["Ins"] = "Insert",
    ["Del"] = "Delete",
    ["PgUp"] = "PageUp",
    ["PgDown"] = "PageDown",
    ["Num+1"] = "N1",
    ["Num+2"] = "N2",
    ["Num+3"] = "N3",
    ["Num+4"] = "N4",
    ["Num+5"] = "N5",
    ["Num+6"] = "N6",
    ["Num+7"] = "N7",
    ["Num+8"] = "N8",
    ["Num+9"] = "N9",
    ["Num+0"] = "N0",
    ["Return"] = "Enter",
    ["Alt+Return"] = "Alt+Enter",
    ["Shift+Return"] = "Shift+Enter",
    ["Ctrl+Return"] = "Ctrl+Enter",
    ["Alt+PgUp"] = "Alt+PageUp",
    ["Alt+PgDown"] = "Alt+PageDown"
}

local function ensureState()
    state.actionBar = state.actionBar or {}
    state.actionBarMappings = state.actionBarMappings or {}
    state.clientOptions = state.clientOptions or {}
    state.chatOptions = state.chatOptions or {}
    return state
end

local function readJsonFile(file)
    if not g_resources.fileExists(file) then
        return nil
    end

    local status, result = pcall(function()
        return json.decode(g_resources.readFileContents(file))
    end)

    if not status then
        return nil
    end

    return result
end

local function getDefaultProfileFromFile(name)
    local default = readJsonFile(DEFAULT_OPTIONS_FILE)
    if not default then
        return nil
    end

    local hotkeyOptions = default.hotkeyOptions
    if not hotkeyOptions or not hotkeyOptions.hotkeySets then
        return nil
    end

    return hotkeyOptions.hotkeySets[name]
end

local function sanitizeHotkeyAssignments()
    local options = ensureState()
    local array = options.array
    if not array then
        return
    end

    local hotkeyOptions = array.hotkeyOptions
    if not hotkeyOptions or not hotkeyOptions.hotkeySets then
        return
    end
end

local function rebuildStateFromArray()
    local options = ensureState()
    options.actionBarMappingsIndex = nil
    local array = options.array

    if not array then
        options.actionBar = {}
        options.actionBarMappings = {}
        options.clientOptions = {}
        options.chatOptions = {}
        options.hotkeySets = nil
        options.profiles = nil
        options.currentHotkeySet = nil
        options.currentHotkeySetName = nil
        options.isChatOnEnabled = false
        return false
    end

    options.profiles = array.profiles

    local hotkeyOptions = array.hotkeyOptions or {}
    array.hotkeyOptions = hotkeyOptions

    options.hotkeySets = hotkeyOptions.hotkeySets or {}
    hotkeyOptions.hotkeySets = options.hotkeySets

    if not options.profiles then
        options.profiles = {}
        array.profiles = options.profiles
        for profileName in pairs(options.hotkeySets) do
            table.insert(options.profiles, profileName)
        end
    end

    local hotkeySetName = options.currentHotkeySetName or hotkeyOptions.currentHotkeySetName
    options.currentHotkeySet = nil

    if hotkeySetName and options.hotkeySets then
        options.currentHotkeySetName = hotkeySetName
        options.currentHotkeySet = options.hotkeySets[hotkeySetName]
    end

    if not options.currentHotkeySet and options.profiles and #options.profiles > 0 then
        options.currentHotkeySetName = options.profiles[1]
        hotkeyOptions.currentHotkeySetName = options.currentHotkeySetName
        options.currentHotkeySet = options.hotkeySets[options.currentHotkeySetName]
    end

    if not options.currentHotkeySet then
        return false
    end

    options.actionBarOptions = options.currentHotkeySet.actionBarOptions
    if not options.actionBarOptions then
        options.actionBarOptions = {}
        options.currentHotkeySet.actionBarOptions = options.actionBarOptions
    end

    options.actionBarMappings = options.actionBarOptions.mappings
    if not options.actionBarMappings then
        options.actionBarMappings = {}
        options.actionBarOptions.mappings = options.actionBarMappings
    end

    options.clientOptions = array.options or {}
    array.options = options.clientOptions

    local actionBar = {}
    local lockedBottom = g_settings.getBoolean("actionBarBottomLocked") or false
    for i = 1, 3 do
        local isVisible = g_settings.getBoolean("actionBarShowBottom" .. i)
        if isVisible == nil then
            isVisible = (i == 1) -- Default: only first bar visible
        end
        actionBar[#actionBar + 1] = {
            isVisible = isVisible,
            isLocked = lockedBottom and true or false
        }
    end

    local lockedLeft = g_settings.getBoolean("actionBarLeftLocked") or false
    for i = 1, 3 do
        local isVisible = g_settings.getBoolean("actionBarShowLeft" .. i)
        if isVisible == nil then
            isVisible = false
        end
        actionBar[#actionBar + 1] = {
            isVisible = isVisible,
            isLocked = lockedLeft and true or false
        }
    end

    local lockedRight = g_settings.getBoolean("actionBarRightLocked") or false
    for i = 1, 3 do
        local isVisible = g_settings.getBoolean("actionBarShowRight" .. i)
        if isVisible == nil then
            isVisible = false
        end
        actionBar[#actionBar + 1] = {
            isVisible = isVisible,
            isLocked = lockedRight and true or false
        }
    end

    options.actionBar = actionBar

    options.chatOptions = array.chatOptions or {}
    array.chatOptions = options.chatOptions
    options.isChatOnEnabled = options.chatOptions.chatModeOn and true or false

    sanitizeHotkeyAssignments()
    return true
end

local function validateHotkeySet()
    ApiJson.bootstrap()
    local options = ensureState()

    if options.currentHotkeySet then
        return options.currentHotkeySet
    end

    local array = options.array
    if not array then
        return nil
    end

    local hotkeyOptions = array.hotkeyOptions
    if not hotkeyOptions or not hotkeyOptions.hotkeySets then
        return nil
    end

    local setName = options.currentHotkeySetName or hotkeyOptions.currentHotkeySetName
    if setName then
        options.currentHotkeySetName = setName
        options.currentHotkeySet = hotkeyOptions.hotkeySets[setName]
    end

    return options.currentHotkeySet
end

local function getCurrentHotkeyEntries(chatMode)
    local set = validateHotkeySet()
    if not set then
        return nil
    end

    chatMode = chatMode or (ensureState().isChatOnEnabled and 'chatOn' or 'chatOff')
    return set[chatMode]
end

local function ensureActionBars()
    ApiJson.bootstrap()
    return ensureState().actionBar
end

local function getMappingKey(barId, buttonId)
    if not barId or not buttonId then
        return nil
    end

    return string.format('%d:%d', barId, buttonId)
end

local function ensureMappingIndex(options)
    options = options or ensureState()

    if options.actionBarMappingsIndex then
        return options.actionBarMappingsIndex
    end

    local index = {}
    local mappings = options.actionBarMappings or {}
    for _, entry in pairs(mappings) do
        local barId = tonumber(entry["actionBar"])
        local buttonId = tonumber(entry["actionButton"])
        if barId and buttonId then
            entry["actionBar"] = barId
            entry["actionButton"] = buttonId
            local key = getMappingKey(barId, buttonId)
            index[key] = entry
        end
    end

    options.actionBarMappingsIndex = index
    return index
end

local function ensureMappings()
    ApiJson.bootstrap()
    local options = ensureState()
    if not options.actionBarMappings then
        options.actionBarMappings = {}
        if options.actionBarOptions then
            options.actionBarOptions.mappings = options.actionBarMappings
        end
    end

    ensureMappingIndex(options)
    return options.actionBarMappings
end

local function findMappingEntry(mappings, barId, buttonId)
    barId = tonumber(barId)
    buttonId = tonumber(buttonId)
    if not barId or not buttonId then
        return nil
    end

    local index = ensureMappingIndex()
    local key = getMappingKey(barId, buttonId)
    local entry = index[key]
    if entry then
        return entry
    end

    for _, candidate in pairs(mappings) do
        local candidateBar = tonumber(candidate["actionBar"])
        local candidateButton = tonumber(candidate["actionButton"])
        if candidateBar and candidateButton then
            candidate["actionBar"] = candidateBar
            candidate["actionButton"] = candidateButton
            if candidateBar == barId and candidateButton == buttonId then
                index[key] = candidate
                return candidate
            end
        end
    end
end

local function getOrCreateMappingEntry(barId, buttonId)
    barId = tonumber(barId)
    buttonId = tonumber(buttonId)
    if not barId or not buttonId then
        return nil
    end

    local mappings = ensureMappings()
    local entry = findMappingEntry(mappings, barId, buttonId)
    if not entry then
        entry = {
            ["actionBar"] = barId,
            ["actionButton"] = buttonId
        }
        mappings[#mappings + 1] = entry
        local index = ensureMappingIndex()
        index[getMappingKey(barId, buttonId)] = entry
    end

    return entry
end

local function isCustomAction(data)
    return not data["actionsetting"] or not data["actionsetting"]["action"]
end

local function isHotkeyConflicting(keyCombo)
    if not keyCombo or keyCombo == "" then
        return false
    end
    if modules.game_hotkeys and modules.game_hotkeys.isHotkeyUsedByManager then
        if modules.game_hotkeys.isHotkeyUsedByManager(keyCombo) then
            return true
        end
    end
    if Keybind and Keybind.isKeyComboUsed then
        if Keybind.isKeyComboUsed(keyCombo, nil, nil, CHAT_MODE.ON) then
            return true
        end
        if Keybind.isKeyComboUsed(keyCombo, nil, nil, CHAT_MODE.OFF) then
            return true
        end
    end
    return false
end

local function removeConflictingDefaultHotkeys(defaultData)
    if not defaultData or not defaultData.hotkeyOptions or not defaultData.hotkeyOptions.hotkeySets then
        return defaultData
    end
    local hotkeySets = defaultData.hotkeyOptions.hotkeySets
    for profileName, profile in pairs(hotkeySets) do
        if profile.chatOff then
            local filtered = {}
            for _, entry in ipairs(profile.chatOff) do
                if entry.keysequence then
                    if not isHotkeyConflicting(entry.keysequence) then
                        table.insert(filtered, entry)
                    else
                        g_logger.debug(string.format(
                            "[ActionBar] Skipping default hotkey '%s' for profile '%s' (chatOff) - already in use",
                            entry.keysequence, profileName))
                    end
                else
                    table.insert(filtered, entry)
                end
            end
            profile.chatOff = filtered
        end
        if profile.chatOn then
            local filtered = {}
            for _, entry in ipairs(profile.chatOn) do
                if entry.keysequence then
                    if not isHotkeyConflicting(entry.keysequence) then
                        table.insert(filtered, entry)
                    else
                        g_logger.debug(string.format(
                            "[ActionBar] Skipping default hotkey '%s' for profile '%s' (chatOn) - already in use",
                            entry.keysequence, profileName))
                    end
                else
                    table.insert(filtered, entry)
                end
            end
            profile.chatOn = filtered
        end
    end
    return defaultData
end

function ApiJson.loadData(file)
    local result = readJsonFile(file)
    if not result then
        return false
    end

    state.array = sanitizeTopLevelArray(result)
    state.actionBarMappingsIndex = nil
    state.bootstrapComplete = false
    return true
end

function ApiJson.saveData()
    if not state.array then
        ApiJson.bootstrap()
    end

    if not state.array then
        return
    end

    local data = sanitizeTopLevelArray(state.array)
    local status, result = pcall(function()
        return json.encode(data)
    end)

    if not status then
        return onError("Error while saving general options settings. Data won't be saved. Details: " .. result)
    end

    if result:len() > 100 * 1024 * 1024 then
        return onError("Something went wrong, file is above 100MB, won't be saved")
    end

    if not g_resources.directoryExists("/settings/") then
        g_resources.makeDir("/settings/")
    end

    g_resources.writeFileContents(DEFAULT_SETTINGS_FILE, result)
end

function ApiJson.createDefaultSettings()
    if not g_resources.directoryExists("/settings/") then
        g_resources.makeDir("/settings/")
    end

    local defaultData = readJsonFile(DEFAULT_OPTIONS_FILE)
    if defaultData then
        defaultData = removeConflictingDefaultHotkeys(defaultData)
        state.array = sanitizeTopLevelArray(defaultData)
        state.actionBarMappingsIndex = nil
        state.bootstrapComplete = false
        ApiJson.saveData()
    end
end

function ApiJson.refreshState()
    state.bootstrapComplete = rebuildStateFromArray()
    return state.bootstrapComplete
end

function ApiJson.bootstrap()
    if state.bootstrapComplete then
        return true
    end

    if not state.array then
        if not ApiJson.loadData(DEFAULT_SETTINGS_FILE) then
            ApiJson.createDefaultSettings()
        end
    end

    if not state.array then
        g_logger.error("Failed to load clientoptions.json")
        state.bootstrapComplete = false
        return false
    end

    return ApiJson.refreshState()
end

function ApiJson.getClientOptions()
    ApiJson.bootstrap()
    return ensureState().clientOptions
end

function ApiJson.getMappings()
    return ensureMappings()
end

function ApiJson.getMapping(barId, buttonId)
    barId = tonumber(barId)
    buttonId = tonumber(buttonId)
    if not barId or not buttonId then
        return nil
    end

    return findMappingEntry(ApiJson.getMappings(), barId, buttonId)
end

function ApiJson.createOrUpdateText(barId, buttonId, text, sendAutomatic)
    barId = tonumber(barId)
    buttonId = tonumber(buttonId)
    if not barId or not buttonId then
        return
    end

    local entry = getOrCreateMappingEntry(barId, buttonId)
    entry["actionsetting"] = {
        ["chatText"] = text,
        ["sendAutomatically"] = sendAutomatic
    }
end

function ApiJson.createOrUpdateAction(barId, buttonId, useMode, itemId, itemTier)
    barId = tonumber(barId)
    buttonId = tonumber(buttonId)
    if not barId or not buttonId then
        return
    end

    local entry = getOrCreateMappingEntry(barId, buttonId)
    entry["actionsetting"] = {
        ["upgradeTier"] = itemTier,
        ["useObject"] = itemId,
        ["useType"] = useMode
    }
end

function ApiJson.createOrUpdatePassive(barId, buttonId, passiveId)
    barId = tonumber(barId)
    buttonId = tonumber(buttonId)
    if not barId or not buttonId then
        return
    end

    local entry = getOrCreateMappingEntry(barId, buttonId)
    entry["actionsetting"] = {
        ["passiveAbility"] = passiveId
    }
end

function ApiJson.removeAction(barId, buttonId)
    barId = tonumber(barId)
    buttonId = tonumber(buttonId)
    if not barId or not buttonId then
        return
    end

    local mappings = ApiJson.getMappings()
    local key = getMappingKey(barId, buttonId)
    for index = #mappings, 1, -1 do
        local entry = mappings[index]
        if entry["actionBar"] == barId and entry["actionButton"] == buttonId then
            table.remove(mappings, index)
            if key then
                local mappingIndex = ensureMappingIndex()
                mappingIndex[key] = nil
            end
            break
        end
    end
end

function ApiJson.removeHotkey(buttonId)
    buttonId = tonumber(buttonId)
    if not buttonId then
        return
    end

    local chatMode = modules.game_console.isChatEnabled() and 'chatOn' or 'chatOff'
    local entries = getCurrentHotkeyEntries(chatMode)
    if not entries then
        return
    end

    for index, data in ipairs(entries) do
        if data["actionsetting"] and data["actionsetting"]["action"] and data["actionsetting"]["action"] ==
            "TriggerActionButton_" .. buttonId then
            table.remove(entries, index)
            break
        end
    end
end

function ApiJson.clearHotkey(hotkey)
    if not hotkey or hotkey == "" then
        return
    end

    local chatMode = modules.game_console.isChatEnabled() and 'chatOn' or 'chatOff'
    local entries = getCurrentHotkeyEntries(chatMode)
    if not entries then
        return
    end

    for index = #entries, 1, -1 do
        local data = entries[index]
        if isCustomAction(data) then
            if data.keysequence == hotkey then
                data.keysequence = ""
            end
            if data.secondarySequence == hotkey then
                data.secondarySequence = ""
            end
        elseif data.keysequence == hotkey then
            table.remove(entries, index)
        end
    end
end

function ApiJson.updateActionBarHotkey(actionName, hotkey)
    if not actionName then
        return
    end

    local chatMode = modules.game_console.isChatEnabled() and 'chatOn' or 'chatOff'
    local entries = getCurrentHotkeyEntries(chatMode)
    if not entries then
        return
    end

    local found = false
    for _, data in pairs(entries) do
        if data["actionsetting"] and data["actionsetting"]["action"] == actionName then
            data["keysequence"] = hotkey
            found = true
            break
        end
    end

    if not found then
        entries[#entries + 1] = {
            ["actionsetting"] = {
                ["action"] = actionName
            },
            ["keysequence"] = hotkey
        }
    end
end

function ApiJson.getActionBar(barIndex)
    barIndex = tonumber(barIndex)
    if not barIndex then
        return nil
    end

    local actionBars = ensureActionBars()
    return actionBars[barIndex]
end

function ApiJson.isBarLocked(barIndex)
    local bar = ApiJson.getActionBar(barIndex)
    return bar and bar.isLocked or false
end

function ApiJson.setBarLocked(barIndex, locked)
    local bar = ApiJson.getActionBar(barIndex)
    if bar then
        bar.isLocked = locked and true or false
    end
end

function ApiJson.setBarVisibility(barIndex, optionKey, visible, markCreated)
    visible = visible and true or false
    local bar = ApiJson.getActionBar(barIndex)
    if bar then
        bar.isVisible = visible
        if markCreated then
            bar.created = true
        end
    end

    g_settings.set(optionKey, visible)
end

function ApiJson.getClientOption(optionKey)
    return g_settings.getBoolean(optionKey)
end

function ApiJson.setClientOption(optionKey, value)
    g_settings.set(optionKey, value)
end

function ApiJson.setCurrentHotkeySetName(name)
    if not name or name == "" then
        return false
    end

    ApiJson.bootstrap()
    local options = ensureState()
    local array = options.array
    if not array then
        return false
    end

    local hotkeyOptions = array.hotkeyOptions or {}
    array.hotkeyOptions = hotkeyOptions

    local hotkeySets = hotkeyOptions.hotkeySets or options.hotkeySets or {}
    hotkeyOptions.hotkeySets = hotkeySets

    if not hotkeySets[name] then
        return false
    end

    hotkeyOptions.currentHotkeySetName = name
    options.currentHotkeySetName = name
    options.currentHotkeySet = hotkeySets[name]

    options.actionBarOptions = options.currentHotkeySet.actionBarOptions
    if not options.actionBarOptions then
        options.actionBarOptions = {}
        options.currentHotkeySet.actionBarOptions = options.actionBarOptions
    end

    options.actionBarMappings = options.actionBarOptions.mappings
    if not options.actionBarMappings then
        options.actionBarMappings = {}
        options.actionBarOptions.mappings = options.actionBarMappings
    end

    options.actionBarMappingsIndex = nil
    return true
end

function ApiJson.createHotkeySet(name, sourceName)
    if not name or name == "" then
        return false
    end

    ApiJson.bootstrap()
    local options = ensureState()
    local array = options.array
    if not array then
        return false
    end

    local hotkeyOptions = array.hotkeyOptions or {}
    array.hotkeyOptions = hotkeyOptions

    local hotkeySets = hotkeyOptions.hotkeySets or options.hotkeySets or {}
    hotkeyOptions.hotkeySets = hotkeySets
    options.hotkeySets = hotkeySets

    if hotkeySets[name] then
        return false
    end

    local source = nil
    if sourceName then
        source = hotkeySets[sourceName]
        if not source then
            return false
        end
    end

    local newSet = source and table.recursivecopy(source) or {
        actionBarOptions = {
            mappings = {}
        },
        chatOn = {},
        chatOff = {}
    }

    hotkeySets[name] = newSet

    local profiles = array.profiles or options.profiles or {}
    array.profiles = profiles
    options.profiles = profiles
    if not table.contains(profiles, name) then
        table.insert(profiles, name)
    end

    return true
end

function ApiJson.renameHotkeySet(oldName, newName)
    if not oldName or oldName == "" or not newName or newName == "" then
        return false
    end

    ApiJson.bootstrap()
    local options = ensureState()
    local array = options.array
    if not array then
        return false
    end

    local hotkeyOptions = array.hotkeyOptions or {}
    array.hotkeyOptions = hotkeyOptions

    local hotkeySets = hotkeyOptions.hotkeySets or options.hotkeySets or {}
    hotkeyOptions.hotkeySets = hotkeySets
    options.hotkeySets = hotkeySets

    if not hotkeySets[oldName] or hotkeySets[newName] then
        return false
    end

    hotkeySets[newName] = hotkeySets[oldName]
    hotkeySets[oldName] = nil

    local profiles = array.profiles or options.profiles or {}
    array.profiles = profiles
    options.profiles = profiles
    for i, profileName in ipairs(profiles) do
        if profileName == oldName then
            profiles[i] = newName
            break
        end
    end

    local currentName = options.currentHotkeySetName or hotkeyOptions.currentHotkeySetName
    if currentName == oldName then
        hotkeyOptions.currentHotkeySetName = newName
        options.currentHotkeySetName = newName
        options.currentHotkeySet = hotkeySets[newName]
        options.actionBarOptions = options.currentHotkeySet.actionBarOptions or {}
        options.currentHotkeySet.actionBarOptions = options.actionBarOptions
        options.actionBarMappings = options.actionBarOptions.mappings or {}
        options.actionBarOptions.mappings = options.actionBarMappings
        options.actionBarMappingsIndex = nil
    end

    return true
end

function ApiJson.removeHotkeySet(name)
    if not name or name == "" then
        return false
    end

    ApiJson.bootstrap()
    local options = ensureState()
    local array = options.array
    if not array then
        return false
    end

    local hotkeyOptions = array.hotkeyOptions or {}
    array.hotkeyOptions = hotkeyOptions

    local hotkeySets = hotkeyOptions.hotkeySets or options.hotkeySets or {}
    hotkeyOptions.hotkeySets = hotkeySets
    options.hotkeySets = hotkeySets

    if not hotkeySets[name] then
        return false
    end

    hotkeySets[name] = nil

    local profiles = array.profiles or options.profiles or {}
    array.profiles = profiles
    options.profiles = profiles
    table.removevalue(profiles, name)

    local currentName = options.currentHotkeySetName or hotkeyOptions.currentHotkeySetName
    if currentName == name then
        local fallback = nil
        for _, profileName in ipairs(profiles) do
            if hotkeySets[profileName] then
                fallback = profileName
                break
            end
        end
        if not fallback then
            for profileName, _ in pairs(hotkeySets) do
                fallback = profileName
                break
            end
        end
        hotkeyOptions.currentHotkeySetName = fallback
        options.currentHotkeySetName = fallback
        options.currentHotkeySet = fallback and hotkeySets[fallback] or nil
        if options.currentHotkeySet then
            options.actionBarOptions = options.currentHotkeySet.actionBarOptions or {}
            options.currentHotkeySet.actionBarOptions = options.actionBarOptions
            options.actionBarMappings = options.actionBarOptions.mappings or {}
            options.actionBarOptions.mappings = options.actionBarMappings
        else
            options.actionBarOptions = nil
            options.actionBarMappings = nil
        end
        options.actionBarMappingsIndex = nil
    end

    return true
end

function ApiJson.toggleLockGroup(optionKey, rangeStart, rangeEnd)
    local newState = not ApiJson.getClientOption(optionKey)
    ApiJson.setClientOption(optionKey, newState)

    if rangeStart and rangeEnd then
        for index = rangeStart, rangeEnd do
            ApiJson.setBarLocked(index, newState)
        end
    end

    return newState
end

function ApiJson.hasCurrentHotkeySet()
    return validateHotkeySet() ~= nil
end

function ApiJson.getHotkeyEntries(chatMode)
    local entries = getCurrentHotkeyEntries(chatMode)
    if not entries then
        return {}
    end

    return entries
end

return ApiJson
