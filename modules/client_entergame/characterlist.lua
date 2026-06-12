CharacterList = {}

-- private variables
local charactersWindow
local loadBox
local characterList
local errorBox
local waitingWindow
local updateWaitEvent
local resendWaitEvent
local loginEvent

-- functionality
local panelSort
local showHiddenCheckbox
local showOutfitsCheckbox
local premiumBenefitsPanel
local premiumButton
local suppressCheckCallbacks = false

local function setCheckedWithoutCallback(widget, checked)
    if not widget then return end
    suppressCheckCallbacks = true
    widget:setChecked(checked)
    suppressCheckCallbacks = false
end

local SORT_COLUMN = {
    Character = 1,
    Status = 2,
    Level = 3,
    Vocation = 4,
    World = 5
}

local SORT_BUTTON_IDS = {
    [SORT_COLUMN.Character] = 'characterSort',
    [SORT_COLUMN.Status] = 'statusSort',
    [SORT_COLUMN.Level] = 'levelSort',
    [SORT_COLUMN.Vocation] = 'vocationSort',
    [SORT_COLUMN.World] = 'worldSort'
}

local SHOW_HIDDEN_SETTING = 'characterlist-show-hidden'
local SORT_COLUMN_SETTING = 'characterlist-sort-column'
local SORT_ASCENDING_SETTING = 'characterlist-sort-ascending'
local PINNED_CHARACTERS_SETTING = 'characterlist-pinned-characters'
--[[
    Controls whether the "Premium Benefits Include" panel is visible.

    true  -> panel is displayed
    false -> panel is hidden
]]
local SHOW_PREMIUM_WIDGETS = true

-- autoReconnect Button
local autoReconnectButton
local autoReconnectEvent
local lastLogout = 0
local function removeAutoReconnectEvent() --prevent
    if autoReconnectEvent then
        removeEvent(autoReconnectEvent)
        autoReconnectEvent = nil
    end
end

local function resetUIReferences()
    characterList = nil
    panelSort = nil
    showHiddenCheckbox = nil
    showOutfitsCheckbox = nil
    premiumBenefitsPanel = nil
    premiumButton = nil
end

local function toBoolean(value, default)
    if value == nil then return default == true end
    local t = type(value)
    if t == 'boolean' then return value end
    if t == 'number' then return value ~= 0 end
    if t == 'string' then
        local v = string.lower(value)
        if v == 'true' or v == '1' then return true end
        if v == 'false' or v == '0' or v == '' then return false end
    end
    return value and true or false
end

local function shouldShowAppearance()
    return g_game.getFeature(GameEnterGameShowAppearance)
end

local function isPremiumAccount(account)
    if not account then
        return false
    end

    if account.subStatus == SubscriptionStatus.Premium then
        return true
    end

    local premDays = tonumber(account.premDays)
    return premDays ~= nil and premDays > 0
end

local function updatePremiumBenefitsVisibility(account)
    local showBenefits = shouldShowAppearance() and SHOW_PREMIUM_WIDGETS and not isPremiumAccount(account)
    if premiumBenefitsPanel then
        premiumBenefitsPanel:setVisible(showBenefits)
        if showBenefits then
            premiumBenefitsPanel:setHeight(120)
            premiumBenefitsPanel:setMarginBottom(6)
        else
            premiumBenefitsPanel:setHeight(0)
            premiumBenefitsPanel:setMarginBottom(0)
        end
    end
    if premiumButton then
        premiumButton:setVisible(showBenefits)
    end
end

local function getShowHiddenCharacters()
    return g_settings.getBoolean(SHOW_HIDDEN_SETTING, true)
end

local function setShowHiddenCharacters(value)
    g_settings.set(SHOW_HIDDEN_SETTING, value)
end

local function getShowOutfits()
    return toBoolean(modules.client_options.getOption('showOutfitsOnList'), true)
end

local function setShowOutfits(value)
    value = toBoolean(value, true)
    modules.client_options.setOption('showOutfitsOnList', value)
end

local function getSortColumn()
    local sortColumn = g_settings.getNumber(SORT_COLUMN_SETTING, SORT_COLUMN.Character)
    if sortColumn < SORT_COLUMN.Character or sortColumn > SORT_COLUMN.World then
        sortColumn = SORT_COLUMN.Character
    end
    return sortColumn
end

local function getSortAscending()
    return g_settings.getBoolean(SORT_ASCENDING_SETTING, true)
end

local function getCharacterStatusValue(characterInfo)
    local main = characterInfo.main and 0 or 1
    local hidden = characterInfo.hidden and 0 or 1
    local dailyReward = tonumber(characterInfo.dailyreward) == 0 and 0 or 1
    return main * 100 + hidden * 10 + dailyReward
end

local function getPinnedCharacters()
    local rawPinnedCharacters = g_settings.getNode(PINNED_CHARACTERS_SETTING)
    if type(rawPinnedCharacters) ~= 'table' then
        return {}
    end

    local pinnedCharacters = {}

    -- Legacy compatibility: normalize array/string shapes into a pinKey->true map.
    for key, value in pairs(rawPinnedCharacters) do
        if type(key) == 'number' then
            if type(value) == 'string' and value ~= '' then
                pinnedCharacters[value] = true
            end
        elseif type(key) == 'string' then
            if value == true then
                pinnedCharacters[key] = true
            elseif type(value) == 'number' then
                if value ~= 0 then
                    pinnedCharacters[key] = true
                end
            elseif type(value) == 'string' then
                local normalizedValue = string.lower(value)
                if normalizedValue == 'true' or normalizedValue == '1' then
                    pinnedCharacters[key] = true
                end
            end
        end
    end

    return pinnedCharacters
end

local function setPinnedCharacters(characters)
    g_settings.setNode(PINNED_CHARACTERS_SETTING, characters)
end

local function getCharacterPinKey(characterName, worldName)
    local name = tostring(characterName or '')
    if name == '' then
        return nil
    end

    return string.format('%s|%s', name, tostring(worldName or ''))
end

local function isCharacterPinned(characterName, worldName, pinnedLookup)
    local pinKey = getCharacterPinKey(characterName, worldName)
    if not pinKey then
        return false
    end

    local pinnedCharacters = pinnedLookup or getPinnedCharacters()
    if pinnedCharacters[pinKey] == true then
        return true
    end

    -- Legacy compatibility: old entries were keyed only by character name.
    return pinnedCharacters[tostring(characterName)] == true
end

local function setCharacterPinned(characterName, worldName, isPinned)
    local pinKey = getCharacterPinKey(characterName, worldName)
    if not pinKey then
        return
    end

    local pinnedCharacters = getPinnedCharacters()
    pinnedCharacters[pinKey] = isPinned and true or nil
    pinnedCharacters[tostring(characterName)] = nil
    setPinnedCharacters(pinnedCharacters)
end

local function toLowerText(value)
    return string.lower(tostring(value or ''))
end

local function toNumberValue(value)
    if type(value) == 'number' then
        return value
    end

    local numericValue = tonumber(value)
    if numericValue then
        return numericValue
    end

    if type(value) == 'string' then
        numericValue = tonumber((value:gsub('[^%d%-%.]', '')))
        if numericValue then
            return numericValue
        end
    end

    return 0
end

local PVP_TYPE_LABELS = {
    [0] = 'Open PvP',
    [1] = 'Optional PvP',
    [2] = 'Hardcore PvP',
    [3] = 'Retro Open PvP',
    [4] = 'Retro Hardcore PvP',
}

local function getPvpTypeText(pvpType)
    if pvpType == nil then
        return nil
    end

    local label = PVP_TYPE_LABELS[tonumber(pvpType) or pvpType]
    if label then
        return tr(label)
    end

    if type(pvpType) == 'string' and pvpType ~= '' then
        return pvpType
    end

    return nil
end

local function getCharacterWorldLabel(characterInfo)
    local worldName = tostring(characterInfo.worldName or '')
    if worldName == '' then
        return worldName
    end

    local pvpTypeText = getPvpTypeText(characterInfo.pvptype)
    if not pvpTypeText or pvpTypeText == '' then
        return worldName
    end

    return string.format('%s\n(%s)', worldName, pvpTypeText)
end

local function compareCharacters(a, b, sortColumn, sortAscending, pinnedLookup)
    local prioritizePinned = sortColumn ~= SORT_COLUMN.Level
    if prioritizePinned then
        local aPinned = isCharacterPinned(a.name, a.worldName, pinnedLookup)
        local bPinned = isCharacterPinned(b.name, b.worldName, pinnedLookup)
        if aPinned ~= bPinned then return aPinned end
    end

    local aValue, bValue
    if sortColumn == SORT_COLUMN.Character then
        aValue, bValue = toLowerText(a.name), toLowerText(b.name)
    elseif sortColumn == SORT_COLUMN.Status then
        aValue, bValue = getCharacterStatusValue(a), getCharacterStatusValue(b)
    elseif sortColumn == SORT_COLUMN.Level then
        aValue, bValue = toNumberValue(a.level), toNumberValue(b.level)
    elseif sortColumn == SORT_COLUMN.Vocation then
        aValue, bValue = toLowerText(a.vocation), toLowerText(b.vocation)
    else
        aValue, bValue = toLowerText(a.worldName), toLowerText(b.worldName)
    end

    if aValue == bValue then
        aValue, bValue = toLowerText(a.name), toLowerText(b.name)
        if aValue == bValue then
            aValue, bValue = toLowerText(a.worldName), toLowerText(b.worldName)
        end
    end

    if sortAscending then return aValue < bValue end
    return aValue > bValue
end

local function updateSortButtons()
    if not panelSort or not shouldShowAppearance() then
        return
    end

    local sortColumn = getSortColumn()
    local sortAscending = getSortAscending()
    for column = SORT_COLUMN.Character, SORT_COLUMN.World do
        local button = panelSort:getChildById(SORT_BUTTON_IDS[column])
        if button then
            local isSelected = column == sortColumn
            button:setOn(isSelected)
            button:setChecked(isSelected and sortAscending or false, true)
        end
    end
end

local function buildCharacters(pinnedLookup)
    local characters = {}
    if not G.characters then
        return characters
    end

    local showAppearance = shouldShowAppearance()
    local showHidden = not showAppearance or getShowHiddenCharacters()
    for _, characterInfo in ipairs(G.characters) do
        if showHidden or not characterInfo.hidden then
            table.insert(characters, characterInfo)
        end
    end

    if showAppearance then
        local sortColumn = getSortColumn()
        local sortAscending = getSortAscending()
        table.sort(characters, function(a, b)
            return compareCharacters(a, b, sortColumn, sortAscending, pinnedLookup)
        end)
    end

    return characters
end

-- private functions
local function tryLogin(charInfo, tries)
    tries = tries or 1

    if tries > 50 then
        return
    end

    if g_game.isOnline() then
        if tries == 1 then
            g_game.safeLogout()
			if loginEvent then
				removeEvent(loginEvent)
				loginEvent = nil
			end
        end
        loginEvent = scheduleEvent(function()
            tryLogin(charInfo, tries + 1)
        end, 100)
        return
    end

    CharacterList.hide()

    g_game.loginWorld(G.account, G.password, charInfo.worldName, charInfo.worldHost, charInfo.worldPort,
                      charInfo.characterName, G.authenticatorToken, G.sessionKey)

    loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to game server...'))
    connect(loadBox, {
        onCancel = function()
            loadBox = nil
            g_game.cancelLogin()
            CharacterList.show()
        end
    })

    -- save last used character
    g_settings.set('last-used-character', charInfo.characterName)
    g_settings.set('last-used-world', charInfo.worldName)
    removeAutoReconnectEvent()
end

local function updateWait(timeStart, timeEnd)
    if waitingWindow then
        local time = g_clock.seconds()
        if time <= timeEnd then
            local percent = ((time - timeStart) / (timeEnd - timeStart)) * 100
            local timeStr = string.format('%.0f', timeEnd - time)

            local progressBar = waitingWindow:getChildById('progressBar')
            progressBar:setPercent(percent)

            local label = waitingWindow:getChildById('timeLabel')
            label:setText(tr('Trying to reconnect in %s seconds.', timeStr))

            updateWaitEvent = scheduleEvent(function()
                updateWait(timeStart, timeEnd)
            end, 1000 * progressBar:getPercentPixels() / 100 * (timeEnd - timeStart))
            return true
        end
    end

    if updateWaitEvent then
        updateWaitEvent:cancel()
        updateWaitEvent = nil
    end
end

local function resendWait()
    if waitingWindow then
        waitingWindow:destroy()
        waitingWindow = nil

        if updateWaitEvent then
            updateWaitEvent:cancel()
            updateWaitEvent = nil
        end

        if charactersWindow then
            local selected = characterList:getFocusedChild()
            if selected then
                local charInfo = {
                    worldHost = selected.worldHost,
                    worldPort = selected.worldPort,
                    worldName = selected.worldName,
                    characterName = selected.characterName,
                    characterLevel = selected.characterLevel,
                    main = selected.main,
                    dailyreward = selected.dailyreward,
                    hidden = selected.hidden,
                    outfitid = selected.outfitid,
                    headcolor = selected.headcolor,
                    torsocolor = selected.torsocolor,
                    legscolor = selected.legscolor,
                    detailcolor = selected.detailcolor,
                    addonsflags = selected.addonsflags,
                    characterVocation = selected.characterVocation
                }
                tryLogin(charInfo)
            end
        end
    end
end

local function onLoginWait(message, time)
    CharacterList.destroyLoadBox()

    waitingWindow = g_ui.displayUI('waitinglist')

    local label = waitingWindow:getChildById('infoLabel')
    label:setText(message)

    updateWaitEvent = scheduleEvent(function()
        updateWait(g_clock.seconds(), g_clock.seconds() + time)
    end, 0)
    resendWaitEvent = scheduleEvent(resendWait, time * 1000)
end

function onGameLoginError(message)
    CharacterList.destroyLoadBox()
    errorBox = displayErrorBox(tr('Login Error'), message)
    errorBox.onOk = function()
        errorBox = nil
        CharacterList.showAgain()
    end
end

function onGameSessionEnd(reason)
    CharacterList.destroyLoadBox()
    CharacterList.showAgain()
end

function onGameConnectionError(message, code)
    CharacterList.destroyLoadBox()
    local text = translateNetworkError(code, g_game.getProtocolGame() and g_game.getProtocolGame():isConnecting(),
                                       message)
    errorBox = displayErrorBox(tr('Connection Error'), text)
    errorBox.onOk = function()
        errorBox = nil
        CharacterList.showAgain()
    end
end

function onGameUpdateNeeded(signature)
    CharacterList.destroyLoadBox()
    errorBox = displayErrorBox(tr('Update needed'), tr('Enter with your account again to update your client.'))
    errorBox.onOk = function()
        errorBox = nil
        CharacterList.showAgain()
    end
end

function onSortButtonClick(button, columnIndex)
    if not shouldShowAppearance() then
        return
    end

    local sortColumn = getSortColumn()
    local sortAscending = getSortAscending()
    if sortColumn == columnIndex then
        sortAscending = not sortAscending
    else
        sortColumn = columnIndex
        sortAscending = true
    end

    g_settings.set(SORT_COLUMN_SETTING, sortColumn)
    g_settings.set(SORT_ASCENDING_SETTING, sortAscending)
    CharacterList.rebuildCharactersList()
end

function onShowHiddenCharacters(widget, isChecked)
    if suppressCheckCallbacks then return end
    setShowHiddenCharacters(isChecked)
    CharacterList.rebuildCharactersList()
end

function onShowOutfits(widget, isChecked)
    if suppressCheckCallbacks then return end
    setShowOutfits(isChecked)
    CharacterList.updateCharactersAppearances(isChecked)
end

function onPinCharacter(widget, isChecked)
    if suppressCheckCallbacks then return end
    if not shouldShowAppearance() then return end

    local parentWidget = widget and widget:getParent()
    if not parentWidget or not parentWidget.characterName then
        return
    end

    setCharacterPinned(parentWidget.characterName, parentWidget.worldName, toBoolean(isChecked, false))
    CharacterList.rebuildCharactersList()
end

function onPremiumButtonClick(widget)
    if Services and Services.getCoinsUrl and Services.getCoinsUrl ~= '' then
        g_platform.openUrl(Services.getCoinsUrl)
        return
    end
    local info = debug.getinfo(1, "Slfn")
    local filename = info.short_src or "unknown_file"
    local line = info.currentline or 0
    local funcname = info.name or "unknown_function"
    displayInfoBox(
        tr('Information'),
        string.format(
            "[%s:%d - %s] Premium URL not configured. Please contact the server administrator.",
            filename,
            line,
            funcname
        )
    )
end

-- public functions
function CharacterList.init()
    connect(g_game, {
        onLoginError = onGameLoginError
    })
    connect(g_game, {
        onSessionEnd = onGameSessionEnd
    })
    connect(g_game, {
        onUpdateNeeded = onGameUpdateNeeded
    })
    connect(g_game, {
        onConnectionError = onGameConnectionError
    })
    connect(g_game, {
        onGameStart = CharacterList.destroyLoadBox
    })
    connect(g_game, {
        onLoginWait = onLoginWait
    })
    connect(g_game, {
        onGameEnd = CharacterList.showAgain
    })
    connect(g_game, {
        onLogout = onLogout
    })

    if G.characters then
        CharacterList.create(G.characters, G.characterAccount)
    end
end

function CharacterList.terminate()
    disconnect(g_game, {
        onLoginError = onGameLoginError
    })
    disconnect(g_game, {
        onSessionEnd = onGameSessionEnd
    })
    disconnect(g_game, {
        onUpdateNeeded = onGameUpdateNeeded
    })
    disconnect(g_game, {
        onConnectionError = onGameConnectionError
    })
    disconnect(g_game, {
        onGameStart = CharacterList.destroyLoadBox
    })
    disconnect(g_game, {
        onLoginWait = onLoginWait
    })
    disconnect(g_game, {
        onGameEnd = CharacterList.showAgain
    })
    disconnect(g_game, {
        onLogout = onLogout
    })

    if charactersWindow then
        resetUIReferences()
        charactersWindow:destroy()
        charactersWindow = nil
    end

    if loadBox then
        g_game.cancelLogin()
        loadBox:destroy()
        loadBox = nil
    end

    if waitingWindow then
        waitingWindow:destroy()
        waitingWindow = nil
    end

    if updateWaitEvent then
        removeEvent(updateWaitEvent)
        updateWaitEvent = nil
    end

    if resendWaitEvent then
        removeEvent(resendWaitEvent)
        resendWaitEvent = nil
    end

    if loginEvent then
        removeEvent(loginEvent)
        loginEvent = nil
    end

    removeAutoReconnectEvent()
    destroyCreateAccount()

    CharacterList = nil
end

function CharacterList.create(characters, account, otui)
    if not otui then
        otui = 'characterlist'
    end

    if charactersWindow then
        charactersWindow:destroy()
    end

    charactersWindow = g_ui.displayUI(otui)
    characterList = charactersWindow:getChildById('characters')
    panelSort = charactersWindow:getChildById('characterTable')
    autoReconnectButton = charactersWindow:getChildById('autoReconnect')
    showHiddenCheckbox = charactersWindow:recursiveGetChildById('checkBoxHidden')
    showOutfitsCheckbox = charactersWindow:recursiveGetChildById('checkBoxOutfit')
    premiumBenefitsPanel = charactersWindow:getChildById('premiumBenefitsPanel')
    premiumButton = charactersWindow:getChildById('premiumButton')

    characterList.onChildFocusChange = function(self, focusedChild, oldFocusedChild)
        removeAutoReconnectEvent()
        if oldFocusedChild then oldFocusedChild:updateOnStates() end
        if focusedChild then
            focusedChild:updateOnStates()
            self:ensureChildVisible(focusedChild)
        end
    end

    -- characters
    G.characters = characters
    G.characterAccount = account

    local accountStatusLabel = charactersWindow:getChildById('accountStatusLabel')
    local accountStatusIcon = nil
    if shouldShowAppearance() then
        accountStatusIcon = charactersWindow:getChildById('accountStatusIcon')
    end

    if showHiddenCheckbox then
        setCheckedWithoutCallback(showHiddenCheckbox, getShowHiddenCharacters())
    end

    if showOutfitsCheckbox then
        setCheckedWithoutCallback(showOutfitsCheckbox, getShowOutfits())
    end

    -- account
    local status = ''
    if account.status == AccountStatus.Frozen then
        status = tr(' (Frozen)')
    elseif account.status == AccountStatus.Suspended then
        status = tr(' (Suspended)')
    end

    if account.subStatus == SubscriptionStatus.Free then
        accountStatusLabel:setText(('%s%s'):format(tr('Free Account'), status))
        if accountStatusIcon then
            accountStatusIcon:setImageSource('/images/game/entergame/nopremium')
        end
    elseif account.subStatus == SubscriptionStatus.Premium then
        if account.premDays == 0 or account.premDays == 65535 then
            accountStatusLabel:setText(('%s%s'):format(tr('Gratis Premium Account'), status))
        else
            accountStatusLabel:setText(('%s%s'):format(tr('Premium Account (%s days left)', account.premDays), status))
        end
        if accountStatusIcon then
            accountStatusIcon:setImageSource('/images/game/entergame/premium')
        end
    end

    if account.premDays > 0 and account.premDays <= 7 then
        accountStatusLabel:setOn(true)
    else
        accountStatusLabel:setOn(false)
    end

    updatePremiumBenefitsVisibility(account)

    CharacterList.rebuildCharactersList()

    autoReconnectButton.onClick = function(widget)
        local autoReconnect = not g_settings.getBoolean('autoReconnect', false)
        autoReconnectButton:setOn(autoReconnect)
        g_settings.set('autoReconnect', autoReconnect)
        local statusText = autoReconnect and 'Auto reconnect: On' or 'Auto reconnect: off'
        if not shouldShowAppearance() then
            statusText = autoReconnect and 'Auto reconnect:\n On' or 'Auto reconnect:\n off'
        end

        autoReconnectButton:setText(statusText)
    end
end

function CharacterList.rebuildCharactersList()
    if not characterList then
        return
    end

    local showAppearance = shouldShowAppearance()
    local showOutfits = showAppearance and getShowOutfits()
    local oddRowColor = showAppearance and '#484848' or '#565656'
    local evenRowColor = showAppearance and '#414141' or '#4f4f4f'
    local focused = characterList:getFocusedChild()
    local focusName = focused and focused.characterName or g_settings.get('last-used-character')
    local focusWorld = focused and focused.worldName or g_settings.get('last-used-world')
    local pinnedLookup = showAppearance and getPinnedCharacters() or {}

    if showHiddenCheckbox then
        setCheckedWithoutCallback(showHiddenCheckbox, getShowHiddenCharacters())
    end

    if showOutfitsCheckbox then
        setCheckedWithoutCallback(showOutfitsCheckbox, showOutfits)
    end

    local characters = buildCharacters(pinnedLookup)
    local focusLabel
    characterList:destroyChildren()

    for i, characterInfo in ipairs(characters) do
        local widget = g_ui.createWidget('CharacterWidget', characterList)
        local rowColor = (i % 2 == 0) and evenRowColor or oddRowColor
        widget.rowColor = rowColor
        widget:setBackgroundColor(rowColor)
        widget.characterInfo = characterInfo
        for key, value in pairs(characterInfo) do
            local subWidget = widget:getChildById(key)
            if subWidget then
                if key == 'outfit' then -- it's an exception
                    subWidget:setOutfit(value)
                elseif key == 'worldName' and showAppearance then
                    subWidget:setText(getCharacterWorldLabel(characterInfo))
                else
                    local text = value
                    if subWidget.baseText and subWidget.baseTranslate then
                        text = tr(subWidget.baseText, text)
                    elseif subWidget.baseText then
                        text = string.format(subWidget.baseText, text)
                    end
                    subWidget:setText(text)
                end
            end
        end

        if showAppearance then
            CharacterList.updateCharactersAppearance(widget, characterInfo, showOutfits)
        end

        -- these are used by login
        widget.characterName = characterInfo.name
        widget.worldName = characterInfo.worldName
        widget.worldHost = characterInfo.worldIp
        widget.worldPort = characterInfo.worldPort

        local pinButton = widget:getChildById('pin')
        if pinButton then
            setCheckedWithoutCallback(pinButton, isCharacterPinned(widget.characterName, widget.worldName, pinnedLookup))
        end

        connect(widget, {
            onDoubleClick = function()
                CharacterList.doLogin()
                return true
            end
        })

        if (focusName and focusWorld and focusName == widget.characterName and focusWorld == widget.worldName) or
            (i == 1 and not focusLabel) then
            focusLabel = widget
        end
        widget:updateOnStates()
    end

    if focusLabel then
        characterList:focusChild(focusLabel, KeyboardFocusReason)
        addEvent(function()
            characterList:ensureChildVisible(focusLabel)
        end)
    end
    updateSortButtons()
end

function CharacterList.destroy()
    CharacterList.hide(true)

    if charactersWindow then
        resetUIReferences()
        charactersWindow:destroy()
        charactersWindow = nil
    end
end

function CharacterList.show()
    if loadBox or errorBox or not charactersWindow then
        return
    end
    charactersWindow:show()
    charactersWindow:raise()
    charactersWindow:focus()

    if showHiddenCheckbox then
        setCheckedWithoutCallback(showHiddenCheckbox, getShowHiddenCharacters())
    end
    if showOutfitsCheckbox then
        setCheckedWithoutCallback(showOutfitsCheckbox, getShowOutfits())
    end

    updatePremiumBenefitsVisibility(G.characterAccount)
    updateSortButtons()

    local autoReconnect = g_settings.getBoolean('autoReconnect', false)
    autoReconnectButton:setOn(autoReconnect)
    local reconnectStatus = autoReconnect and 'On' or 'Off'
    if not shouldShowAppearance() then
        autoReconnectButton:setText('Auto reconnect:\n ' .. reconnectStatus)
    else
        autoReconnectButton:setText('Auto reconnect: ' .. reconnectStatus)
    end
end

function CharacterList.hide(showLogin)
    removeAutoReconnectEvent()
    charactersWindow:hide()

    if showLogin and EnterGame and not g_game.isOnline() then
        EnterGame.show()
    end
end

function CharacterList.showAgain()
    if characterList and characterList:hasChildren() then
        CharacterList.show()
        scheduleAutoReconnect()
    end
end

function CharacterList.isVisible()
    if charactersWindow and charactersWindow:isVisible() then
        return true
    end
    return false
end

function CharacterList.doLogin()
    removeAutoReconnectEvent()
    local selected = characterList:getFocusedChild()
    if selected then
        local charInfo = {
            worldHost = selected.worldHost,
            worldPort = selected.worldPort,
            worldName = selected.worldName,
            characterName = selected.characterName
        }
        charactersWindow:hide()
        if loginEvent then
            removeEvent(loginEvent)
            loginEvent = nil
        end
        tryLogin(charInfo)
    else
        displayErrorBox(tr('Error'), tr('You must select a character to login!'))
    end
end

function CharacterList.destroyLoadBox()
    if loadBox then
        loadBox:destroy()
        loadBox = nil
    end
    destroyCreateAccount()
end

function CharacterList.cancelWait()
    if waitingWindow then
        waitingWindow:destroy()
        waitingWindow = nil
    end

    if updateWaitEvent then
        removeEvent(updateWaitEvent)
        updateWaitEvent = nil
    end

    if resendWaitEvent then
        removeEvent(resendWaitEvent)
        resendWaitEvent = nil
    end

    CharacterList.destroyLoadBox()
    CharacterList.showAgain()
end

function CharacterList.updateCharactersAppearance(widget, characterInfo, showOutfits)
    if not shouldShowAppearance() then
        return
    end

    if showOutfits == nil then
        showOutfits = getShowOutfits()
    end

    local creatureDisplay = widget:getChildById('outfitCreatureBox')
    local nameLabel = widget:getChildById('name')
    local mainCharacter = widget:getChildById('mainCharacter')
    local statusDailyReward = widget:getChildById('statusDailyReward')
    local statusHidden = widget:getChildById('statusHidden')

    if creatureDisplay then
        creatureDisplay:setVisible(showOutfits)
        if showOutfits then
            creatureDisplay:setSize('64 64')
            local creature = widget.cachedOutfitCreature
            if not creature then
                creature = Creature.create()
                widget.cachedOutfitCreature = creature
            end
            local outfit = {
                type = characterInfo.outfitid or 0,
                head = characterInfo.headcolor or 0,
                body = characterInfo.torsocolor or 0,
                legs = characterInfo.legscolor or 0,
                feet = characterInfo.detailcolor or 0,
                addons = characterInfo.addonsflags or 0
            }
            creature:setOutfit(outfit)
            creature:setDirection(2)
            creatureDisplay:setCreature(creature)
            creatureDisplay:setPadding(0)
        end
    end

    if nameLabel then
        nameLabel:setMarginLeft(showOutfits and 65 or 5)
    end

    widget:setHeight(showOutfits and 64 or 29)

    if mainCharacter then
        mainCharacter:setImageSource(characterInfo.main and '/images/game/entergame/maincharacter' or '')
    end

    if statusDailyReward then
        local dailyRewardCollected = tonumber(characterInfo.dailyreward) == 0
        statusDailyReward:setImageSource(dailyRewardCollected and '/images/game/entergame/dailyreward_collected' or
            '/images/game/entergame/dailyreward_notcollected')
    end

    if statusHidden then
        statusHidden:setImageSource(characterInfo.hidden and '/images/game/entergame/hidden' or '')
    end
end

function CharacterList.updateCharactersAppearances(showOutfits)
    if not shouldShowAppearance() or not characterList then
        return
    end

    if showOutfits == nil then
        showOutfits = getShowOutfits()
    end

    if showOutfitsCheckbox and showOutfits ~= showOutfitsCheckbox:isChecked() then
        setCheckedWithoutCallback(showOutfitsCheckbox, showOutfits)
    end

    if not(characterList) or #(characterList:getChildren()) == 0 then
        return
    end

    for _, widget in ipairs(characterList:getChildren()) do
        if widget.characterInfo then
            CharacterList.updateCharactersAppearance(widget, widget.characterInfo, showOutfits)
        end
    end
end

function onLogout()
    lastLogout = g_clock.millis()
end

function scheduleAutoReconnect()
    if not g_settings.getBoolean('autoReconnect') or lastLogout + 2000 > g_clock.millis() then
        return
    end

    removeAutoReconnectEvent()
    autoReconnectEvent = scheduleEvent(executeAutoReconnect, 2500)
end

function executeAutoReconnect()
    if not g_settings.getBoolean('autoReconnect') then
        return
    end

    if errorBox then
        errorBox:destroy()
        errorBox = nil
    end
    CharacterList.doLogin()
end
