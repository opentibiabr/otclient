SpeakTypesSettings = {
    none = {},
    say = {
        speakType = MessageModes.Say,
        color = '#FFFF00'
    },
    whisper = {
        speakType = MessageModes.Whisper,
        color = '#FFFF00'
    },
    yell = {
        speakType = MessageModes.Yell,
        color = '#FFFF00'
    },
    broadcast = {
        speakType = MessageModes.GamemasterBroadcast,
        color = '#F55E5E'
    },
    private = {
        speakType = MessageModes.PrivateTo,
        color = '#5FF7F7',
        private = true
    },
    privateRed = {
        speakType = MessageModes.GamemasterTo,
        color = '#F55E5E',
        private = true
    },
    privatePlayerToPlayer = {
        speakType = MessageModes.PrivateTo,
        color = '#9F9DFD',
        private = true
    },
    privatePlayerToNpc = {
        speakType = MessageModes.NpcTo,
        color = '#9F9DFD',
        private = true,
        npcChat = true
    },
    privateNpcToPlayer = {
        speakType = MessageModes.NpcFrom,
        color = '#5FF7F7',
        private = true,
        npcChat = true
    },
    channelYellow = {
        speakType = MessageModes.Channel,
        color = '#FFFF00'
    },
    channelWhite = {
        speakType = MessageModes.ChannelManagement,
        color = '#FFFFFF'
    },
    channelRed = {
        speakType = MessageModes.GamemasterChannel,
        color = '#F55E5E'
    },
    channelOrange = {
        speakType = MessageModes.ChannelHighlight,
        color = '#F6A731'
    },
    monsterSay = {
        speakType = MessageModes.MonsterSay,
        color = '#FF9A57',
        hideInConsole = true
    },
    monsterYell = {
        speakType = MessageModes.MonsterYell,
        color = '#FF9A57',
        hideInConsole = true
    },
    rvrAnswerFrom = {
        speakType = MessageModes.RVRAnswer,
        color = '#FE6500'
    },
    rvrAnswerTo = {
        speakType = MessageModes.RVRAnswer,
        color = '#FE6500'
    },
    rvrContinue = {
        speakType = MessageModes.RVRContinue,
        color = '#FFFF00'
    }
}

SpeakTypes = {
    [MessageModes.Say] = SpeakTypesSettings.say,
    [MessageModes.Whisper] = SpeakTypesSettings.whisper,
    [MessageModes.Yell] = SpeakTypesSettings.yell,
    [MessageModes.GamemasterBroadcast] = SpeakTypesSettings.broadcast,
    [MessageModes.PrivateTo] = SpeakTypesSettings.private,
    [MessageModes.PrivateFrom] = SpeakTypesSettings.private,
    [MessageModes.GamemasterPrivateFrom] = SpeakTypesSettings.privateRed,
    [MessageModes.NpcTo] = SpeakTypesSettings.privatePlayerToNpc,
    [MessageModes.NpcFrom] = SpeakTypesSettings.privateNpcToPlayer,
    [MessageModes.Channel] = SpeakTypesSettings.channelYellow,
    [MessageModes.ChannelManagement] = SpeakTypesSettings.channelWhite,
    [MessageModes.GamemasterChannel] = SpeakTypesSettings.channelRed,
    [MessageModes.ChannelHighlight] = SpeakTypesSettings.channelOrange,
    [MessageModes.MonsterSay] = SpeakTypesSettings.monsterSay,
    [MessageModes.MonsterYell] = SpeakTypesSettings.monsterYell,
    [MessageModes.RVRChannel] = SpeakTypesSettings.channelWhite,
    [MessageModes.RVRContinue] = SpeakTypesSettings.rvrContinue,
    [MessageModes.RVRAnswer] = SpeakTypesSettings.rvrAnswerFrom,
    [MessageModes.NpcFromStartBlock] = SpeakTypesSettings.privateNpcToPlayer,

    -- ignored types
    [MessageModes.Spell] = SpeakTypesSettings.none,
    [MessageModes.BarkLow] = SpeakTypesSettings.none,
    [MessageModes.BarkLoud] = SpeakTypesSettings.none,
    [MessageModes.Potion] = SpeakTypesSettings.none
}

SayModes = {
    [1] = {
        speakTypeDesc = 'whisper',
        image = '/images/ui/console_whisper'
    },
    [2] = {
        speakTypeDesc = 'say',
        image = '/images/ui/console_say'
    },
    [3] = {
        speakTypeDesc = 'yell',
        image = '/images/ui/console_yell'
    }
}

ChannelEventFormats = {
    [ChannelEvent.Join] = '%s joined the channel.',
    [ChannelEvent.Leave] = '%s left the channel.',
    [ChannelEvent.Invite] = '%s has been invited to the channel.',
    [ChannelEvent.Exclude] = '%s has been removed from the channel.'
}

MAX_HISTORY = 500
MAX_LINES = 100
HELP_CHANNEL = 9

consolePanel = nil
consoleContentPanel = nil
local extendedViewButtonToggleChat = nil
local extendedViewButtonShowAlphaChat = nil
local gameBottomPanel = nil
consoleTabBar = nil
consoleTextEdit = nil
consoleToggleChat = nil
channels = nil
channelsWindow = nil
communicationWindow = nil
ownPrivateName = nil
messageHistory = {}
currentMessageIndex = 0
ignoreNpcMessages = false
defaultTab = nil
serverTab = nil
violationsChannelId = nil
violationWindow = nil
violationReportTab = nil
ignoredChannels = {}
filters = {}
local readOnlyButton = nil
local readOnlyPanel = nil
local activeactiveReadOnlyTabName = ""
local readOnlyModeEnabled = false

-- Option: show underline/dots for highlighted text in console
local showHighlightedUnderline = false

local communicationSettings = {
    useIgnoreList = true,
    useWhiteList = true,
    privateMessages = false,
    yelling = false,
    allowVIPs = false,
    ignoredPlayers = {},
    whitelistedPlayers = {}
}

function init()
    connect(g_game, {
        onTalk = onTalk,
        onChannelList = onChannelList,
        onOpenChannel = onOpenChannel,
        onOpenPrivateChannel = onOpenPrivateChannel,
        onOpenOwnPrivateChannel = onOpenOwnPrivateChannel,
        onCloseChannel = onCloseChannel,
        onRuleViolationChannel = onRuleViolationChannel,
        onRuleViolationRemove = onRuleViolationRemove,
        onRuleViolationCancel = onRuleViolationCancel,
        onRuleViolationLock = onRuleViolationLock,
        onGameStart = online,
        onGameEnd = offline,
        onChannelEvent = onChannelEvent
    })
    gameBottomPanel = modules.game_interface.getBottomPanel()
    consolePanel = g_ui.loadUI('console', gameBottomPanel)
    consoleTextEdit = consolePanel:getChildById('consoleTextEdit')
    consoleContentPanel = consolePanel:getChildById('consoleContentPanel')
    consoleTabBar = consolePanel:getChildById('consoleTabBar')
    consoleTabBar:setContentWidget(consoleContentPanel)
    channels = {}

    readOnlyPanel = consolePanel:getChildById('readOnlyPanel')
    readOnlyPanel:hide()
    consoleContentPanel:removeAnchor(AnchorRight)
    consoleContentPanel:addAnchor(AnchorRight, "parent", AnchorRight)

    consolePanel.onDragEnter = onDragEnter
    consolePanel.onDragLeave = onDragLeave
    consolePanel.onDragMove = onDragMove
    consoleTabBar.onDragEnter = onDragEnter
    consoleTabBar.onDragLeave = onDragLeave
    consoleTabBar.onDragMove = onDragMove
    consolePanel.onKeyPress = function(self, keyCode, keyboardModifiers)
        if not (g_keyboard.isPrimaryModifierOnly(keyboardModifiers) and keyCode == KeyC) then
            return false
        end

        local tab = consoleTabBar:getCurrentTab()
        if not tab then
            return false
        end

        local selection = tab.tabPanel:getChildById('consoleBuffer').selectionText
        if not selection then
            return false
        end

        g_window.setClipboardText(selection)
        return true
    end

    g_keyboard.bindKeyPress('Shift+Up', function()
        navigateMessageHistory(1)
    end, consolePanel)
    g_keyboard.bindKeyPress('Shift+Down', function()
        navigateMessageHistory(-1)
    end, consolePanel)
  
    g_keyboard.bindKeyDown('Enter', switchChatOnCall, consolePanel)
    g_keyboard.bindKeyDown('Escape', disableChatOnCall, consolePanel)
    g_keyboard.bindKeyPress('Ctrl+A', function()
        consoleTextEdit:clearText()
    end, consolePanel)

    -- apply buttom functions after loaded
    consoleTabBar:setNavigation(consolePanel:getChildById('prevChannelButton'),
        consolePanel:getChildById('nextChannelButton'))
    consoleTabBar.onTabChange = onTabChange

    -- tibia like hotkeys
    local gameRootPanel = modules.game_interface.getRootPanel()
    Keybind.new("Chat Channel", "Next Channel", "Tab", "")
    Keybind.bind("Chat Channel", "Next Channel", {
        {
          type = KEY_PRESS,
          callback = function() consoleTabBar:selectNextTab() end,
        }
      }, consolePanel)

    Keybind.new("Chat Channel", "Previous Channel", "Shift+Tab", "")
    Keybind.bind("Chat Channel", "Previous Channel", {
        {
          type = KEY_PRESS,
          callback = function() consoleTabBar:selectPrevTab() end,
        }
    }, consolePanel)
    Keybind.new("Chat", "Send current chat line", { [CHAT_MODE.ON] = "Enter", [CHAT_MODE.OFF] = "" }, "")
    Keybind.bind("Chat", "Send current chat line", {
        {
          type = KEY_DOWN,
          callback = sendCurrentMessage,
        }
      }, consolePanel)
    Keybind.new("Chat Channel", "Open Channel List", "Ctrl+O", "")
    Keybind.bind("Chat Channel", "Open Channel List", {
        {
          type = KEY_DOWN,
          callback = g_game.requestChannels,
        }
      }, gameRootPanel)
    Keybind.new("Chat Channel", "Close Current Channel", "Ctrl+E", "")

    Keybind.bind("Chat Channel", "Close Current Channel", {
      {
        type = KEY_DOWN,
        callback = removeCurrentTab,
      }
    }, gameRootPanel)

    Keybind.new("Chat Channel", "Open Help Channel", "Ctrl+H", "")
    Keybind.bind("Chat Channel", "Open Help Channel", {
        {
          type = KEY_DOWN,
          callback = openHelp,
        }
      }, consolePanel)

    -- toggle WASD
    consoleToggleChat = consolePanel:getChildById('toggleChat')
    readOnlyButton = consolePanel:getChildById("readOnlyButton")
    readOnlyPanel = consolePanel:getChildById("readOnlyPanel")
    function readOnlyButton.onMousePress(tab, mousePos, mouseButton)
		if mouseButton == MouseRightButton then
			onReadOnlyMouseClick()
			return true
		end
	end
    consoleTabBar:setDropTarget(readOnlyButton, function(target, draggedWidget)
        activateReadOnlyMode(draggedWidget:getText())
    end)
    load()

    if g_game.isOnline() then
        online()
    end
end

function clearSelection(consoleBuffer)
    for _, label in pairs(consoleBuffer:getChildren()) do
        label:clearSelection()
    end
    consoleBuffer.selectionText = nil
    consoleBuffer.selection = nil
end

function selectAll(consoleBuffer)
    clearSelection(consoleBuffer)
    if consoleBuffer:getChildCount() > 0 then
        local text = {}
        for _, label in pairs(consoleBuffer:getChildren()) do
            label:selectAll()
            table.insert(text, label:getSelection())
        end
        consoleBuffer.selectionText = table.concat(text, '\n')
        consoleBuffer.selection = {
            first = consoleBuffer:getChildIndex(consoleBuffer:getFirstChild()),
            last = consoleBuffer:getChildIndex(consoleBuffer:getLastChild())
        }
    end
end

function toggleChat()
    if modules.game_interface.isInternalLocked() then
        return
    end
    
    consoleToggleChat.isChecked = not consoleToggleChat.isChecked
    if consoleToggleChat.isChecked then
        consoleToggleChat:setText(tr('Chat Off'))
    else
        consoleToggleChat:setText(tr('Chat On'))
    end
    
    updateChatMode()
end

-- id of object first and then action
function updateChatMode()
    switchChat(not consoleToggleChat.isChecked)
end

local function unbindMovingKeys()
    local gameWalk = modules.game_walk
    gameWalk.unbindWalkKey('W')
    gameWalk.unbindWalkKey('D')
    gameWalk.unbindWalkKey('S')
    gameWalk.unbindWalkKey('A')

    gameWalk.unbindWalkKey('E')
    gameWalk.unbindWalkKey('Q')
    gameWalk.unbindWalkKey('C')
    gameWalk.unbindWalkKey('Z')

    gameWalk.unbindTurnKey('Control+W')
    gameWalk.unbindTurnKey('Control+D')
    gameWalk.unbindTurnKey('Control+S')
    gameWalk.unbindTurnKey('Control+A')
end

local function bindMovingKeys()
    local gameWalk = modules.game_walk
    gameWalk.bindWalkKey('W', North)
    gameWalk.bindWalkKey('D', East)
    gameWalk.bindWalkKey('S', South)
    gameWalk.bindWalkKey('A', West)

    gameWalk.bindWalkKey('E', NorthEast)
    gameWalk.bindWalkKey('Q', NorthWest)
    gameWalk.bindWalkKey('C', SouthEast)
    gameWalk.bindWalkKey('Z', SouthWest)

    gameWalk.bindTurnKey('Control+W', North)
    gameWalk.bindTurnKey('Control+D', East)
    gameWalk.bindTurnKey('Control+S', South)
    gameWalk.bindTurnKey('Control+A', West)
end

function switchChat(enabled)
    -- enabled should be true if we enabling the chat and false if disabling it
    -- consoleToggleChat:setChecked(not consoleToggleChat.isChecked)
    if not (enabled and consoleTextEdit:isVisible()) then
        consoleTextEdit:setVisible(enabled)
        consoleTextEdit:setText('')
    end

    if enabled then
        unbindMovingKeys()
        consoleToggleChat:setTooltip(tr('Disable chat mode, allow to walk using WASD'))
        Keybind.setChatMode(CHAT_MODE.ON)
    else
        bindMovingKeys()
        consoleToggleChat:setTooltip(tr('Enable chat mode'))
        Keybind.setChatMode(CHAT_MODE.OFF)
    end
end

function switchChatOnCall()
    if not g_game.isOnline() or modules.game_hotkeys.areHotkeysDisabled() then
        return
    end

    if isChatEnabled() and consoleToggleChat.isChecked then
        toggleChat()
    else
        local message = consoleTextEdit:getText()
        if message == '' then
            if not isChatEnabled() or modules.client_options.getOption('returnDisablesChat') then
                toggleChat()
            end
        end
    end
end

function disableChatOnCall()
    if not g_game.isOnline() or modules.game_hotkeys.areHotkeysDisabled() then
        return
    end

    if isChatEnabled() and not consoleToggleChat.isChecked then
        toggleChat()
    end
end

function isChatEnabled()
    return consoleTextEdit:isVisible()
end

function terminate()
    save()
    disconnect(g_game, {
        onTalk = onTalk,
        onChannelList = onChannelList,
        onOpenChannel = onOpenChannel,
        onOpenPrivateChannel = onOpenPrivateChannel,
        onOpenOwnPrivateChannel = onOpenPrivateChannel,
        onCloseChannel = onCloseChannel,
        onRuleViolationChannel = onRuleViolationChannel,
        onRuleViolationRemove = onRuleViolationRemove,
        onRuleViolationCancel = onRuleViolationCancel,
        onRuleViolationLock = onRuleViolationLock,
        onGameStart = online,
        onGameEnd = offline,
        onChannelEvent = onChannelEvent
    })

    if g_game.isOnline() then
        clear()
    end

    Keybind.delete("Chat Channel", "Close Current Channel")
    Keybind.delete("Chat Channel", "Next Channel")
    Keybind.delete("Chat Channel", "Previous Channel")
    Keybind.delete("Chat Channel", "Open Channel List")
    Keybind.delete("Chat Channel", "Open Help Channel")
    Keybind.delete("Chat", "Send current chat line")
    saveCommunicationSettings()
    clearReadOnlyTab()
    if readOnlyModeEnabled then
        toggleReadOnlyMode()
    end
    if readOnlyButton then
        readOnlyButton:destroy()
        readOnlyButton = nil
    end
    if readOnlyPanel then
        readOnlyPanel:destroy()
        readOnlyPanel = nil
    end
    if channelsWindow then
        channelsWindow:destroy()
    end

    if communicationWindow then
        communicationWindow:destroy()
    end

    if violationWindow then
        violationWindow:destroy()
    end

    consoleTabBar = nil
    consoleContentPanel = nil
    consoleToggleChat = nil
    consoleTextEdit = nil

    consolePanel:destroy()
    consolePanel = nil
    ownPrivateName = nil
    gameBottomPanel = nil
    Console = nil
end

function save()
    local settings = {}
    settings.messageHistory = messageHistory
    settings.wasdMode = consoleToggleChat.isChecked
    settings.showHighlightedUnderline = showHighlightedUnderline
    g_settings.setNode('game_console', settings)
end

function load()
    local settings = g_settings.getNode('game_console')
    if settings then
        messageHistory = settings.messageHistory or {}
        consoleToggleChat.isChecked = settings.wasdMode or false
        showHighlightedUnderline = settings.showHighlightedUnderline or false
        if consoleToggleChat.isChecked then
            consoleToggleChat:setText(tr('Chat Off'))
        else
            consoleToggleChat:setText(tr('Chat On'))
        end
        -- Only update chat mode if game is online to avoid binding issues during initialization
        if g_game.isOnline() then
            updateChatMode()
        end
    end
    loadCommunicationSettings()
end

function setShowHighlightedUnderline(value)
    showHighlightedUnderline = value
end

function isEnabledWASD()
    return consoleToggleChat.isChecked --note: testing required
end

function onTabChange(tabBar, tab)
    local player = g_game.getLocalPlayer()
    local message = consoleTextEdit:getText()
    if tab == defaultTab or tab == serverTab then
        consolePanel:getChildById('closeChannelButton'):disable()
        if player then
            player:setTyping(message ~= "")
        end
    else
        consolePanel:getChildById('closeChannelButton'):enable()
        player:setTyping(false)
    end

    if tab.isOnRedMessage then
        tab:setColor('#dfdfdfff')
        tab.isOnRedMessage = false
    end

    if tab.newMessageEvent ~= nil then
        tab:setColor('#dfdfdfff')
        removeEvent(tab.newMessageEvent)
        tab.newMessageEvent = nil
    end
end

function clear()
    -- save last open channels
    local lastChannelsOpen = g_settings.getNode('lastChannelsOpen') or {}
    local char = g_game.getCharacterName()
    local savedChannels = {}
    local set = false
    for channelId, channelName in pairs(channels) do
        if type(channelId) == 'number' then
            savedChannels[channelName] = channelId
            set = true
        end
    end
    if set then
        lastChannelsOpen[char] = savedChannels
    else
        lastChannelsOpen[char] = nil
    end
    g_settings.setNode('lastChannelsOpen', lastChannelsOpen)
    if extendedViewButtonToggleChat and not gameBottomPanel:isVisible() then
        returnChat()
    end
    -- close channels
    for _, channelName in pairs(channels) do
        local tab = consoleTabBar:getTab(channelName)
        consoleTabBar:removeTab(tab)
    end
    channels = {}

    consoleTabBar:removeTab(defaultTab)
    defaultTab = nil
    consoleTabBar:removeTab(serverTab)
    serverTab = nil

    local npcTab = consoleTabBar:getTab('NPCs')
    if npcTab then
        consoleTabBar:removeTab(npcTab)
        npcTab = nil
    end

    if violationReportTab then
        consoleTabBar:removeTab(violationReportTab)
        violationReportTab = nil
    end

    consoleTextEdit:clearText()

    if violationWindow then
        violationWindow:destroy()
        violationWindow = nil
    end

    if channelsWindow then
        channelsWindow:destroy()
        channelsWindow = nil
    end
    if g_game.getClientVersion() < 862 then
        Keybind.delete("Dialogs", "Open Rule Violation")
    end

    if readOnlyModeEnabled then
        toggleReadOnlyMode()
    end
end

function clearChannel(consoleTabBar)
    local currentTab = consoleTabBar:getCurrentTab()
    local currentTabName = currentTab:getText()
    currentTab.tabPanel:getChildById('consoleBuffer'):destroyChildren()
    
    if readOnlyModeEnabled and currentTabName == activeactiveReadOnlyTabName then
        readOnlyPanel:getChildById('panel'):destroyChildren()
    end
end

function setTextEditText(text)
    consoleTextEdit:setText(text)
    consoleTextEdit:setCursorPos(-1)
end

function openHelp()
    local helpChannel = 9
    if g_game.getClientVersion() <= 810 then
        helpChannel = 8
    end
    g_game.joinChannel(helpChannel)
end

function openPlayerReportRuleViolationWindow()
    if violationWindow or violationReportTab then
        return
    end
    violationWindow = g_ui.loadUI('violationwindow', rootWidget)
    violationWindow.onEscape = function()
        violationWindow:destroy()
        violationWindow = nil
    end
    violationWindow.onEnter = function()
        local text = violationWindow:getChildById('text'):getText()
        g_game.talkChannel(MessageModes.RVRChannel, 0, text)
        violationReportTab = addTab(tr('Report Rule') .. '...', true)
        addTabText(tr('Please wait patiently for a gamemaster to reply') .. '.', SpeakTypesSettings.privateRed,
            violationReportTab)
        addTabText(applyMessagePrefixies(g_game.getCharacterName(), 0, text), SpeakTypesSettings.say,
            violationReportTab, g_game.getCharacterName())
        violationReportTab.locked = true
        violationWindow:destroy()
        violationWindow = nil
    end
end

function addTab(name, focus)
    local tab = getTab(name)
    if tab then -- is channel already open
        if not focus then
            focus = true
        end
    else
        tab = consoleTabBar:addTab(name, nil, processChannelTabMenu)
    end
    if focus then
        consoleTabBar:selectTab(tab)
    end

    tab.onHoverChange = function()
        if consoleTabBar:getId() ~= tab then
            if tab.isOnRedMessage then
                tab:setColor('#f75f5fff')
            end
            if tab.newMessageEvent ~= nil then
                tab:setColor('#dfdfdfff')
            end
        end
    end

    return tab
end

function removeTab(tab)
    if type(tab) == 'string' then
        tab = consoleTabBar:getTab(tab)
    end

    if tab == defaultTab or tab == serverTab then
        return
    end

    if tab == violationReportTab then
        g_game.cancelRuleViolation()
        violationReportTab = nil
    elseif tab.violationChatName then
        g_game.closeRuleViolation(tab.violationChatName)
    elseif tab.channelId then
        -- notificate the server that we are leaving the channel
        for k, v in pairs(channels) do
            if (k == tab.channelId) then
                channels[k] = nil
            end
        end
        g_game.leaveChannel(tab.channelId)
    elseif tab:getText() == 'NPCs' then
        g_game.closeNpcChannel()
    end

    if getCurrentTab() == tab then
        consoleTabBar:selectTab(defaultTab)
    end
    consoleTabBar:removeTab(tab)
end

function removeCurrentTab()
    removeTab(consoleTabBar:getCurrentTab())
end

function getTab(name)
    return consoleTabBar:getTab(name)
end

function getChannelTab(channelId)
    local channel = channels[channelId]
    if channel then
        return getTab(channel)
    end
    return nil
end

function getRuleViolationsTab()
    if violationsChannelId then
        return getChannelTab(violationsChannelId)
    end
    return nil
end

function getCurrentTab()
    return consoleTabBar:getCurrentTab()
end

function addChannel(name, id)
    channels[id] = name
    local focus = not table.find(ignoredChannels, id)
    local tab = addTab(name, focus)
    tab.channelId = id
    return tab
end

function addPrivateChannel(receiver)
    channels[receiver] = receiver
    return addTab(receiver, true)
end

function addPrivateText(text, speaktype, name, isPrivateCommand, creatureName)
    local focus = false
    if speaktype.npcChat then
        name = 'NPCs'
        focus = true
    end

    local privateTab = getTab(name)
    if privateTab == nil then
        if (modules.client_options.getOption('showPrivateMessagesInConsole') and not focus) or
            (isPrivateCommand and not privateTab) then
            privateTab = defaultTab
        else
            privateTab = addTab(name, focus)
            channels[name] = name
        end
        privateTab.npcChat = speaktype.npcChat
    elseif focus then
        consoleTabBar:selectTab(privateTab)
    end
    addTabText(text, speaktype, privateTab, creatureName)
end

function addText(text, speaktype, tabName, creatureName)
    local tab = getTab(tabName)
    if tab ~= nil then
        addTabText(text, speaktype, tab, creatureName)
    end
end

-- Contains letter width for font "verdana-11px-antialised" as console is based on it
local letterWidth = { -- New line (10) and Space (32) have width 1 because they are printed and not replaced with spacer
    [10] = 1,
    [32] = 1,
    [33] = 3,
    [34] = 6,
    [35] = 8,
    [36] = 7,
    [37] = 13,
    [38] = 9,
    [39] = 3,
    [40] = 5,
    [41] = 5,
    [42] = 6,
    [43] = 8,
    [44] = 4,
    [45] = 5,
    [46] = 3,
    [47] = 8,
    [48] = 7,
    [49] = 6,
    [50] = 7,
    [51] = 7,
    [52] = 7,
    [53] = 7,
    [54] = 7,
    [55] = 7,
    [56] = 7,
    [57] = 7,
    [58] = 3,
    [59] = 4,
    [60] = 8,
    [61] = 8,
    [62] = 8,
    [63] = 6,
    [64] = 10,
    [65] = 9,
    [66] = 7,
    [67] = 7,
    [68] = 8,
    [69] = 7,
    [70] = 7,
    [71] = 8,
    [72] = 8,
    [73] = 5,
    [74] = 5,
    [75] = 7,
    [76] = 7,
    [77] = 9,
    [78] = 8,
    [79] = 8,
    [80] = 7,
    [81] = 8,
    [82] = 8,
    [83] = 7,
    [84] = 8,
    [85] = 8,
    [86] = 8,
    [87] = 12,
    [88] = 8,
    [89] = 8,
    [90] = 7,
    [91] = 5,
    [92] = 8,
    [93] = 5,
    [94] = 9,
    [95] = 8,
    [96] = 5,
    [97] = 7,
    [98] = 7,
    [99] = 6,
    [100] = 7,
    [101] = 7,
    [102] = 5,
    [103] = 7,
    [104] = 7,
    [105] = 3,
    [106] = 4,
    [107] = 7,
    [108] = 3,
    [109] = 11,
    [110] = 7,
    [111] = 7,
    [112] = 7,
    [113] = 7,
    [114] = 6,
    [115] = 6,
    [116] = 5,
    [117] = 7,
    [118] = 8,
    [119] = 10,
    [120] = 8,
    [121] = 8,
    [122] = 6,
    [123] = 7,
    [124] = 4,
    [125] = 7,
    [126] = 8,
    [127] = 1,
    [128] = 7,
    [129] = 6,
    [130] = 3,
    [131] = 7,
    [132] = 6,
    [133] = 11,
    [134] = 7,
    [135] = 7,
    [136] = 7,
    [137] = 13,
    [138] = 7,
    [139] = 4,
    [140] = 11,
    [141] = 6,
    [142] = 6,
    [143] = 6,
    [144] = 6,
    [145] = 4,
    [146] = 3,
    [147] = 7,
    [148] = 6,
    [149] = 6,
    [150] = 7,
    [151] = 10,
    [152] = 7,
    [153] = 10,
    [154] = 6,
    [155] = 5,
    [156] = 11,
    [157] = 6,
    [158] = 6,
    [159] = 8,
    [160] = 4,
    [161] = 3,
    [162] = 7,
    [163] = 7,
    [164] = 7,
    [165] = 8,
    [166] = 4,
    [167] = 7,
    [168] = 6,
    [169] = 10,
    [170] = 6,
    [171] = 8,
    [172] = 8,
    [173] = 16,
    [174] = 10,
    [175] = 8,
    [176] = 5,
    [177] = 8,
    [178] = 5,
    [179] = 5,
    [180] = 6,
    [181] = 7,
    [182] = 7,
    [183] = 3,
    [184] = 5,
    [185] = 6,
    [186] = 6,
    [187] = 8,
    [188] = 12,
    [189] = 12,
    [190] = 12,
    [191] = 6,
    [192] = 9,
    [193] = 9,
    [194] = 9,
    [195] = 9,
    [196] = 9,
    [197] = 9,
    [198] = 11,
    [199] = 7,
    [200] = 7,
    [201] = 7,
    [202] = 7,
    [203] = 7,
    [204] = 5,
    [205] = 5,
    [206] = 6,
    [207] = 5,
    [208] = 8,
    [209] = 8,
    [210] = 8,
    [211] = 8,
    [212] = 8,
    [213] = 8,
    [214] = 8,
    [215] = 8,
    [216] = 8,
    [217] = 8,
    [218] = 8,
    [219] = 8,
    [220] = 8,
    [221] = 8,
    [222] = 7,
    [223] = 7,
    [224] = 7,
    [225] = 7,
    [226] = 7,
    [227] = 7,
    [228] = 7,
    [229] = 7,
    [230] = 11,
    [231] = 6,
    [232] = 7,
    [233] = 7,
    [234] = 7,
    [235] = 7,
    [236] = 3,
    [237] = 4,
    [238] = 4,
    [239] = 4,
    [240] = 7,
    [241] = 7,
    [242] = 7,
    [243] = 7,
    [244] = 7,
    [245] = 7,
    [246] = 7,
    [247] = 9,
    [248] = 7,
    [249] = 7,
    [250] = 7,
    [251] = 7,
    [252] = 7,
    [253] = 8,
    [254] = 7,
    [255] = 8
}

-- Return information about start, end in the string and the highlighted words
function getHighlightedText(text, color, highlightColor)
    color = color or "white"
    highlightColor = highlightColor or "#1f9ffe"
    local firstBrace = text:find("{", 1, true)
    if not firstBrace then
        return string.format("{%s, %s}", text, color)
    end
    local parts = {}
    local lastPos = 1
    if firstBrace > 1 then
        parts[#parts + 1] = string.format("{%s, %s}", text:sub(1, firstBrace - 1), color)
    end
    for startPos, content, endPos in text:gmatch("()%{([^}]*)%}()") do
        local textPart = content:match("([^,]+)") or content
        local trimmed = textPart:match("^%s*(.-)%s*$")
        local highlighted = trimmed
        -- always wrap with text-event to preserve click/hover functionality
        if showHighlightedUnderline then
            highlighted = string.format("[text-event]%s[/text-event]", trimmed)
        else
            -- prefix with marker (0x01) to indicate "no underline" to UI widget
            highlighted = string.format("[text-event]%s%s[/text-event]", string.char(1), trimmed)
        end
        parts[#parts + 1] = string.format("{%s, %s}", highlighted, highlightColor)
        local nextBrace = text:find("{", endPos, true)
        local afterText = text:sub(endPos, (nextBrace or 0) - 1)
        if afterText ~= "" then
            parts[#parts + 1] = string.format("{%s, %s}", afterText, color)
        end
        lastPos = endPos
    end
    return table.concat(parts)
end

local function changeNewNessageColor(tab)
    if tab.newMessageEvent ~= nil or tab.isOnRedMessage then
        return
    end

    tab:setColor('#dfdfdfff')
    tab.newMessageEvent = scheduleEvent(function()
        tab:setColor('#f75f5fff')
        tab.isOnRedMessage = true
        tab.newMessageEvent = nil
    end, 1000)
end

function onConsoleTextClicked(widget, text)
    local npcTab = consoleTabBar:getTab("NPCs")
    if npcTab then
        sendMessage(text, npcTab)
    end
end

function onConsoleTextHovered(widget, text, hovered)
    if hovered then
        g_mouse.pushCursor("pointer")
    else
       g_mouse.popCursor("pointer")
    end
end

function addTabText(text, speaktype, tab, creatureName)
    if not tab or tab.locked or not text or #text == 0 then
        return
    end

    if modules.client_options.getOption('showTimestampsInConsole') then
        text = os.date('%H:%M') .. ' ' .. text
    end

    local panel = consoleTabBar:getTabPanel(tab)
    local consoleBuffer = panel:getChildById('consoleBuffer')
    local label = g_ui.createWidget('ConsoleLabel', consoleBuffer)
    label:setId('consoleLabel' .. consoleBuffer:getChildCount())

    -- Overlay for consoleBuffer which shows highlighted words only
    if speaktype.npcChat and (g_game.getCharacterName() ~= creatureName or g_game.getCharacterName() == 'Account Manager') then
        local highlightData = getHighlightedText(text, speaktype.color, "#1f9ffe")
        label:setColoredText(highlightData)
        label.coloredData = highlightData
        if not label:hasEventListener(EVENT_TEXT_CLICK) and not label:hasEventListener(EVENT_TEXT_HOVER) then
            label:setEventListener(EVENT_TEXT_CLICK)
            label:setEventListener(EVENT_TEXT_HOVER)
            connect(label, {
                onTextClick = onConsoleTextClicked,
                onTextHoverChange = onConsoleTextHovered
            })
        end
    else
        if speaktype.colored then
            label:setColoredText(text)
            label.coloredData = text
        else
            label:setText(text)
        end
    end
    label:setColor(speaktype.color)
    if readOnlyModeEnabled and activeactiveReadOnlyTabName == tab:getText() then
        local readOnlyBuffer = readOnlyPanel:getChildById('panel')
        local readOnlyLabel = g_ui.createWidget('ConsoleLabel', readOnlyBuffer)
        readOnlyLabel:setId('consoleLabel' .. readOnlyBuffer:getChildCount())
        if speaktype.npcChat and (g_game.getCharacterName() ~= creatureName or g_game.getCharacterName() == 'Account Manager') then
            local highlightData = getHighlightedText(text, speaktype.color, "#1f9ffe")
            readOnlyLabel:setColoredText(highlightData)
            readOnlyLabel:setEventListener(EVENT_TEXT_CLICK)
            readOnlyLabel:setEventListener(EVENT_TEXT_HOVER)
            connect(readOnlyLabel, {
                onTextClick = onConsoleTextClicked,
                onTextHoverChange = onConsoleTextHovered
            })
        elseif speaktype.colored then
            readOnlyLabel:setColoredText(text)
        else
            readOnlyLabel:setText(text)
        end
        readOnlyLabel:setColor(speaktype.color)
    end
    if consoleTabBar:getCurrentTab() ~= tab then
        if not (readOnlyModeEnabled and activeactiveReadOnlyTabName == tab:getText()) then
            changeNewNessageColor(tab)
        end
    end
    label.name = creatureName
    consoleBuffer.onMouseRelease = function(self, mousePos, mouseButton)
        processMessageMenu(mousePos, mouseButton, nil, nil, nil, tab)
    end

    label.onMouseRelease = function(self, mousePos, mouseButton)
        if mouseButton == MouseRightButton then
            processMessageMenu(mousePos, mouseButton, creatureName, text, self, tab)
        end
    end
    label.onMousePress = function(self, mousePos, button)
        if button == MouseLeftButton then
            clearSelection(consoleBuffer)
        end
    end
    label.onDragEnter = function(self, mousePos)
        clearSelection(consoleBuffer)
        return true
    end
    label.onDragLeave = function(self, droppedWidget, mousePos)
        local text = {}
        for selectionChild = consoleBuffer.selection.first, consoleBuffer.selection.last do
            local label = self:getParent():getChildByIndex(selectionChild)
            table.insert(text, label:getSelection())
        end
        consoleBuffer.selectionText = table.concat(text, '\n')
        return true
    end
    label.onDragMove = function(self, mousePos, mouseMoved)
        local parent = self:getParent()
        local parentRect = parent:getPaddingRect()
        local selfIndex = parent:getChildIndex(self)
        local child = parent:getChildByPos(mousePos)

        -- find bonding children
        if not child then
            if mousePos.y < self:getY() then
                for index = selfIndex - 1, 1, -1 do
                    local label = parent:getChildByIndex(index)
                    if label:getY() + label:getHeight() > parentRect.y then
                        if (mousePos.y >= label:getY() and mousePos.y <= label:getY() + label:getHeight()) or index == 1 then
                            child = label
                            break
                        end
                    else
                        child = parent:getChildByIndex(index + 1)
                        break
                    end
                end
            elseif mousePos.y > self:getY() + self:getHeight() then
                for index = selfIndex + 1, parent:getChildCount(), 1 do
                    local label = parent:getChildByIndex(index)
                    if label:getY() < parentRect.y + parentRect.height then
                        if (mousePos.y >= label:getY() and mousePos.y <= label:getY() + label:getHeight()) or index ==
                            parent:getChildCount() then
                            child = label
                            break
                        end
                    else
                        child = parent:getChildByIndex(index - 1)
                        break
                    end
                end
            else
                child = self
            end
        end

        if not child then
            return false
        end

        local childIndex = parent:getChildIndex(child)

        -- remove old selection
        clearSelection(consoleBuffer)

        -- update self selection
        local textBegin = self:getTextPos(self:getLastClickPosition())
        local textPos = self:getTextPos(mousePos)
        self:setSelection(textBegin, textPos)

        consoleBuffer.selection = {
            first = math.min(selfIndex, childIndex),
            last = math.max(selfIndex, childIndex)
        }

        -- update siblings selection
        if child ~= self then
            for selectionChild = consoleBuffer.selection.first + 1, consoleBuffer.selection.last - 1 do
                parent:getChildByIndex(selectionChild):selectAll()
            end

            local textPos = child:getTextPos(mousePos)
            if childIndex > selfIndex then
                child:setSelection(0, textPos)
            else
                child:setSelection(string.len(child:getText()), textPos)
            end
        end

        return true
    end

    if consoleBuffer:getChildCount() > MAX_LINES then
        local child = consoleBuffer:getFirstChild()
        clearSelection(consoleBuffer)
        child:destroy()
    end
end

function removeTabLabelByName(tab, name)
    local panel = consoleTabBar:getTabPanel(tab)
    local consoleBuffer = panel:getChildById('consoleBuffer')
    for _, label in pairs(consoleBuffer:getChildren()) do
        if label.name == name then
            label:destroy()
        end
    end
end

function processChannelTabMenu(tab, mousePos, mouseButton)
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)

    local worldName = g_game.getWorldName()
    local characterName = g_game.getCharacterName()
    channelName = tab:getText()
    if tab ~= defaultTab and tab ~= serverTab then
        menu:addOption(tr('Close'), function()
            removeTab(channelName)
        end)
        menu:addSeparator()
    end
    if readOnlyModeEnabled and activeactiveReadOnlyTabName == channelName then
        menu:addOption(tr("Close read-only"), function()
            clearReadOnlyTab()
            toggleReadOnlyMode()
        end)
    else
        menu:addOption(tr("Open read-only"), function()
            activateReadOnlyMode(channelName)
        end)
    end
    if consoleTabBar:getCurrentTab() == tab then
        menu:addOption(tr('Clear Messages'), function()
            clearChannel(consoleTabBar)
        end)
        menu:addOption(tr('Save Messages'), function()
            saveChannelMessages(tab, worldName, characterName, channelName)
        end)
    end

    menu:display(mousePos)
end

function processMessageMenu(mousePos, mouseButton, creatureName, text, label, tab)
    if mouseButton == MouseRightButton then
        local menu = g_ui.createWidget('PopupMenu')
        menu:setGameMenu(true)
        if creatureName and #creatureName > 0 then
            if creatureName ~= g_game.getCharacterName() then
                menu:addOption(tr('Message to ' .. creatureName), function()
                    g_game.openPrivateChannel(creatureName)
                end)
                if not g_game.getLocalPlayer():hasVip(creatureName) then
                    menu:addOption(tr('Add to VIP list'), function()
                        g_game.addVip(creatureName)
                    end)
                end
                if modules.game_console.getOwnPrivateTab() then
                    menu:addSeparator()
                    menu:addOption(tr('Invite to private chat'), function()
                        g_game.inviteToOwnChannel(creatureName)
                    end)
                    menu:addOption(tr('Exclude from private chat'), function()
                        g_game.excludeFromOwnChannel(creatureName)
                    end)
                end
                if isIgnored(creatureName) then
                    menu:addOption(tr('Unignore') .. ' ' .. creatureName, function()
                        removeIgnoredPlayer(creatureName)
                    end)
                else
                    menu:addOption(tr('Ignore') .. ' ' .. creatureName, function()
                        addIgnoredPlayer(creatureName)
                    end)
                end
                menu:addSeparator()
            end
            if modules.game_ruleviolation.hasWindowAccess() then
                menu:addOption(tr('Rule Violation'), function()
                    modules.game_ruleviolation.show(creatureName, text:match('.+%:%s(.+)'))
                end)
                menu:addSeparator()
            end

            menu:addOption(tr('Copy name'), function()
                g_window.setClipboardText(creatureName)
            end)
        end
        local selection = tab.tabPanel:getChildById('consoleBuffer').selectionText
        if selection and #selection > 0 then
            menu:addOption(tr('Copy'), function()
                g_window.setClipboardText(selection)
            end, '(Ctrl+C)')
        end
        if text then
            menu:addOption(tr('Copy message'), function()
                g_window.setClipboardText(text)
            end)
        end
        menu:addOption(tr('Select all'), function()
            selectAll(tab.tabPanel:getChildById('consoleBuffer'))
        end)
        if tab.violations and creatureName then
            menu:addSeparator()
            menu:addOption(tr('Process') .. ' ' .. creatureName, function()
                processViolation(creatureName, text)
            end)
            menu:addOption(tr('Remove') .. ' ' .. creatureName, function()
                g_game.closeRuleViolation(creatureName)
            end)
        end
        menu:display(mousePos)
    end
end

function sendCurrentMessage()
    local message = consoleTextEdit:getText()
    if #message == 0 then
        return
    end
    if not isChatEnabled() then
        return
    end
    consoleTextEdit:clearText()

    -- send message
    sendMessage(message)
end

function addFilter(filter)
    table.insert(filters, filter)
end

function removeFilter(filter)
    table.removevalue(filters, filter)
end

function sendMessage(message, tab)
    local tab = tab or getCurrentTab()
    if not tab then
        return
    end

    for k, func in pairs(filters) do
        if func(message) then
            return true
        end
    end

    -- when talking on server log, the message goes to default channel
    local name = tab:getText()
    if tab == serverTab or tab == getRuleViolationsTab() then
        tab = defaultTab
        name = defaultTab:getText()
    end

    -- handling chat commands
    local channel = tab.channelId
    local originalMessage = message
    local chatCommandSayMode
    local chatCommandPrivate
    local chatCommandPrivateReady
    local chatCommandMessage

    -- player used yell command
    chatCommandMessage = message:match('^%#[y|Y] (.*)')
    if chatCommandMessage ~= nil then
        chatCommandSayMode = 'yell'
        channel = 0
        message = chatCommandMessage
    end

    -- player used whisper
    chatCommandMessage = message:match('^%#[w|W] (.*)')
    if chatCommandMessage ~= nil then
        chatCommandSayMode = 'whisper'
        message = chatCommandMessage
        channel = 0
    end

    -- player say
    chatCommandMessage = message:match('^%#[s|S] (.*)')
    if chatCommandMessage ~= nil then
        chatCommandSayMode = 'say'
        message = chatCommandMessage
        channel = 0
    end

    -- player red talk on channel
    chatCommandMessage = message:match('^%#[c|C] (.*)')
    if chatCommandMessage ~= nil then
        chatCommandSayMode = 'channelRed'
        message = chatCommandMessage
    end

    -- player broadcast
    chatCommandMessage = message:match('^%#[b|B] (.*)')
    if chatCommandMessage ~= nil then
        chatCommandSayMode = 'broadcast'
        message = chatCommandMessage
        channel = 0
    end

    local findIni, findEnd, chatCommandInitial, chatCommandPrivate, chatCommandEnd, chatCommandMessage = message:find(
        '([%*%@])(.+)([%*%@])(.*)')
    if findIni ~= nil and findIni == 1 then -- player used private chat command
        if chatCommandInitial == chatCommandEnd then
            chatCommandPrivateRepeat = false
            if chatCommandInitial == '*' then
                setTextEditText('*' .. chatCommandPrivate .. '* ')
            end
            message = chatCommandMessage:trim()
            chatCommandPrivateReady = true
        end
    end

    message = message:gsub('^(%s*)(.*)', '%2') -- remove space characters from message init
    if #message == 0 then
        return
    end

    -- add new command to history
    currentMessageIndex = 0
    if #messageHistory == 0 or messageHistory[#messageHistory] ~= originalMessage then
        table.insert(messageHistory, originalMessage)
        if #messageHistory > MAX_HISTORY then
            table.remove(messageHistory, 1)
        end
    end

    local speaktypedesc
    if (channel or tab == defaultTab) and not chatCommandPrivateReady then
        if tab == defaultTab then
            speaktypedesc = chatCommandSayMode or
                                SayModes[consolePanel:getChildById('sayModeButton').sayMode].speakTypeDesc
            if speaktypedesc ~= 'say' then
                sayModeChange(2)
            end -- head back to say mode
        else
            speaktypedesc = chatCommandSayMode or 'channelYellow'
        end

        g_game.talkChannel(SpeakTypesSettings[speaktypedesc].speakType, channel, message)
        return
    else
        local isPrivateCommand = false
        local priv = true
        local tabname = name
        local dontAdd = false
        if chatCommandPrivateReady then
            speaktypedesc = 'privatePlayerToPlayer'
            name = chatCommandPrivate
            isPrivateCommand = true
        elseif tab.npcChat then
            speaktypedesc = 'privatePlayerToNpc'
        elseif tab == violationReportTab then
            if violationReportTab.locked then
                modules.game_textmessage.displayFailureMessage('Wait for a gamemaster reply.')
                dontAdd = true
            else
                speaktypedesc = 'rvrContinue'
                tabname = tr('Report Rule') .. '...'
            end
        elseif tab.violationChatName then
            speaktypedesc = 'rvrAnswerTo'
            name = tab.violationChatName
            tabname = tab.violationChatName .. '\'...'
        else
            speaktypedesc = 'privatePlayerToPlayer'
        end

        local speaktype = SpeakTypesSettings[speaktypedesc]
        local player = g_game.getLocalPlayer()
        g_game.talkPrivate(speaktype.speakType, name, message)
        if not dontAdd then
            message = applyMessagePrefixies(g_game.getCharacterName(), player:getLevel(), message)
            addPrivateText(message, speaktype, tabname, isPrivateCommand, g_game.getCharacterName())
        end
    end
end

function sayModeChange(sayMode)
    local buttom = consolePanel:getChildById('sayModeButton')
    if sayMode == nil then
        sayMode = buttom.sayMode + 1
    end

    if sayMode > #SayModes then
        sayMode = 1
    end

    buttom:setImageSource(SayModes[sayMode].image)
    buttom.sayMode = sayMode
end

function getOwnPrivateTab()
    if not ownPrivateName then
        return
    end
    return getTab(ownPrivateName)
end

function setIgnoreNpcMessages(ignore)
    ignoreNpcMessages = ignore
end

function navigateMessageHistory(step)
    if not isChatEnabled() then
        return
    end
    local numCommands = #messageHistory
    if numCommands > 0 then
        currentMessageIndex = math.min(math.max(currentMessageIndex + step, 0), numCommands)
        if currentMessageIndex > 0 then
            local command = messageHistory[numCommands - currentMessageIndex + 1]
            setTextEditText(command)
        else
            consoleTextEdit:clearText()
        end
    end
    local player = g_game.getLocalPlayer()
    if player then
        player:lockWalk(200) -- lock walk for 200 ms to avoid walk during release of shift
    end
end

function applyMessagePrefixies(name, level, message)
    if name and #name > 0 then
        if modules.client_options.getOption('showLevelsInConsole') and level > 0 then
            message = name .. ' [' .. level .. ']: ' .. message
        else
            message = name .. ': ' .. message
        end
    end
    return message
end

function onTalk(name, level, mode, message, channelId, creaturePos)
    if mode == MessageModes.GamemasterBroadcast then
        modules.game_textmessage.displayBroadcastMessage(name .. ': ' .. message)
        return
    end

    local isNpcMode = (mode == MessageModes.NpcFromStartBlock or mode == MessageModes.NpcFrom)

    if ignoreNpcMessages and isNpcMode then
        return
    end

    speaktype = SpeakTypes[mode]

    if not speaktype then
        perror('unhandled onTalk message mode ' .. mode .. ': ' .. message)
        return
    end

    local localPlayer = g_game.getLocalPlayer()
    if name ~= g_game.getCharacterName() and isUsingIgnoreList() and not (isUsingWhiteList()) or
        (isUsingWhiteList() and not (isWhitelisted(name)) and not (isAllowingVIPs() and localPlayer:hasVip(name))) then
        if mode == MessageModes.Yell and isIgnoringYelling() then
            return
        elseif speaktype.private and isIgnoringPrivate() and not isNpcMode then
            return
        elseif isIgnored(name) then
            return
        end
    end

    if mode == MessageModes.RVRChannel then
        channelId = violationsChannelId
    end

    if (mode == MessageModes.Say or mode == MessageModes.Whisper or mode == MessageModes.Yell or mode == MessageModes.Spell or
        mode == MessageModes.MonsterSay or mode == MessageModes.MonsterYell or mode == MessageModes.NpcFrom or mode ==
        MessageModes.BarkLow or mode == MessageModes.BarkLoud or mode == MessageModes.NpcFromStartBlock) and creaturePos then
        local staticText = StaticText.create()
        local staticMessage = message
        if isNpcMode then
            local highlightedText = getHighlightedText(staticMessage, speaktype.color, "#1f9ffe")

            local processedText = staticMessage
            local colorPattern = "{([^,]+),[ ]*[^}]+}"
            for textContent in highlightedText:gmatch(colorPattern) do
                local plainText = textContent:gsub("%[text%-event%](.-)%[/text%-event%]", "%1")
                -- remove possible no-underline marker (0x01) inserted by getHighlightedText
                if plainText:sub(1,1) == string.char(1) then
                    plainText = plainText:sub(2)
                end
                processedText = processedText:gsub("{" .. textContent .. "}", plainText)
            end
            processedText = processedText:gsub("{([^}]+)}", "%1")
            staticMessage = processedText
            staticText:setColor(speaktype.color)
        end

        staticText:addMessage(name, mode, staticMessage)
        g_map.addStaticText(staticText, creaturePos)
    end

    local defaultMessage = mode <= 3 and true or false

    if speaktype == SpeakTypesSettings.none then
        return
    end

    if speaktype.hideInConsole then
        return
    end

    local composedMessage = applyMessagePrefixies(name, level, message)

    if mode == MessageModes.RVRAnswer then
        violationReportTab.locked = false
        addTabText(composedMessage, speaktype, violationReportTab, name)
    elseif mode == MessageModes.RVRContinue then
        addText(composedMessage, speaktype, name .. '\'...', name)
    elseif speaktype.private then
        addPrivateText(composedMessage, speaktype, name, false, name)
        if modules.client_options.getOption('showPrivateMessagesOnScreen') and speaktype ~=
            SpeakTypesSettings.privateNpcToPlayer then
            modules.game_textmessage.displayPrivateMessage(name .. ':\n' .. message)
        end
    else
        local channel = tr('Local Chat')
        if not defaultMessage then
            channel = channels[channelId]
        end

        if channel then
            addText(composedMessage, speaktype, channel, name)
        else
            -- server sent a message on a channel that is not open
            pwarning('message in channel id ' .. channelId ..
                         ' which is unknown, this is a server bug, relogin if you want to see messages in this channel')
        end
    end
end

function onOpenChannel(channelId, channelName)
    addChannel(channelName, channelId)
end

function onOpenPrivateChannel(receiver)
    addPrivateChannel(receiver)
end

function onOpenOwnPrivateChannel(channelId, channelName)
    local privateTab = getTab(channelName)
    if privateTab == nil then
        addChannel(channelName, channelId)
    end
    ownPrivateName = channelName
end

function onCloseChannel(channelId)
    local channel = channels[channelId]
    if channel then
        local tab = getTab(channel)
        if tab then
            consoleTabBar:removeTab(tab)
        end
        for k, v in pairs(channels) do
            if (k == tab.channelId) then
                channels[k] = nil
            end
        end
    end
end

function processViolation(name, text)
    local tabname = name .. '\'...'
    local tab = addTab(tabname, true)
    channels[tabname] = tabname
    tab.violationChatName = name
    g_game.openRuleViolation(name)
    addTabText(text, SpeakTypesSettings.say, tab, name)
end

function onRuleViolationChannel(channelId)
    violationsChannelId = channelId
    local tab = addChannel(tr('Rule Violations'), channelId)
    tab.violations = true
end

function onRuleViolationRemove(name)
    local tab = getRuleViolationsTab()
    if not tab then
        return
    end
    removeTabLabelByName(tab, name)
end

function onRuleViolationCancel(name)
    local tab = getTab(name .. '\'...')
    if not tab then
        return
    end
    addTabText(tr('%s has finished the request', name) .. '.', SpeakTypesSettings.privateRed, tab)
    tab.locked = true
end

function onRuleViolationLock()
    if not violationReportTab then
        return
    end
    violationReportTab.locked = false
    addTabText(tr('Your request has been closed') .. '.', SpeakTypesSettings.privateRed, violationReportTab)
    violationReportTab.locked = true
end

function doChannelListSubmit()
    local channelListPanel = channelsWindow:getChildById('channelList')
    local openPrivateChannelWith = channelsWindow:getChildById('openPrivateChannelWith'):getText()
    if openPrivateChannelWith ~= '' then
        if openPrivateChannelWith:lower() ~= g_game.getCharacterName():lower() then
            g_game.openPrivateChannel(openPrivateChannelWith)
        else
            modules.game_textmessage.displayFailureMessage('You cannot create a private chat channel with yourself.')
        end
    else
        local selectedChannelLabel = channelListPanel:getFocusedChild()
        if not selectedChannelLabel then
            return
        end
        if selectedChannelLabel.channelId == 0xFFFF then
            g_game.openOwnChannel()
        else
            g_game.leaveChannel(selectedChannelLabel.channelId)
            g_game.joinChannel(selectedChannelLabel.channelId)
        end
    end

    channelsWindow:destroy()
end

function onChannelList(channelList)
    if channelsWindow then
        channelsWindow:destroy()
    end
    channelsWindow = g_ui.displayUI('channelswindow')
    local channelListPanel = channelsWindow:getChildById('channelList')
    channelsWindow.onEnter = doChannelListSubmit
    channelsWindow.onDestroy = function()
        channelsWindow = nil
    end
    g_keyboard.bindKeyPress('Down', function()
        channelListPanel:focusNextChild(KeyboardFocusReason)
    end, channelsWindow)
    g_keyboard.bindKeyPress('Up', function()
        channelListPanel:focusPreviousChild(KeyboardFocusReason)
    end, channelsWindow)

    for k, v in pairs(channelList) do
        local channelId = v[1]
        local channelName = v[2]

        if #channelName > 0 then
            local label = g_ui.createWidget('ChannelListLabel', channelListPanel)
            label.channelId = channelId
            label:setText(channelName)

            label:setPhantom(false)
            label.onDoubleClick = doChannelListSubmit
        end
    end
end

function loadCommunicationSettings()
    communicationSettings.whitelistedPlayers = {}
    communicationSettings.ignoredPlayers = {}

    local ignoreNode = g_settings.getNode('IgnorePlayers')
    if ignoreNode then
        for _, player in pairs(ignoreNode) do
            table.insert(communicationSettings.ignoredPlayers, player)
        end
    end

    local whitelistNode = g_settings.getNode('WhitelistedPlayers')
    if whitelistNode then
        for _, player in pairs(whitelistNode) do
            table.insert(communicationSettings.whitelistedPlayers, player)
        end
    end

    communicationSettings.useIgnoreList = g_settings.getBoolean('UseIgnoreList')
    communicationSettings.useWhiteList = g_settings.getBoolean('UseWhiteList')
    communicationSettings.privateMessages = g_settings.getBoolean('IgnorePrivateMessages')
    communicationSettings.yelling = g_settings.getBoolean('IgnoreYelling')
    communicationSettings.allowVIPs = g_settings.getBoolean('AllowVIPs')
end

function saveCommunicationSettings()
    local tmpIgnoreList = {}
    local ignoredPlayers = getIgnoredPlayers()
    for i = 1, #ignoredPlayers do
        table.insert(tmpIgnoreList, ignoredPlayers[i])
    end

    local tmpWhiteList = {}
    local whitelistedPlayers = getWhitelistedPlayers()
    for i = 1, #whitelistedPlayers do
        table.insert(tmpWhiteList, whitelistedPlayers[i])
    end

    g_settings.set('UseIgnoreList', communicationSettings.useIgnoreList)
    g_settings.set('UseWhiteList', communicationSettings.useWhiteList)
    g_settings.set('IgnorePrivateMessages', communicationSettings.privateMessages)
    g_settings.set('IgnoreYelling', communicationSettings.yelling)
    g_settings.setNode('IgnorePlayers', tmpIgnoreList)
    g_settings.setNode('WhitelistedPlayers', tmpWhiteList)
end

function getIgnoredPlayers()
    return communicationSettings.ignoredPlayers
end

function getWhitelistedPlayers()
    return communicationSettings.whitelistedPlayers
end

function isUsingIgnoreList()
    return communicationSettings.useIgnoreList
end

function isUsingWhiteList()
    return communicationSettings.useWhiteList
end

function isIgnored(name)
    return table.find(communicationSettings.ignoredPlayers, name, true)
end

function addIgnoredPlayer(name)
    if isIgnored(name) then
        return
    end
    table.insert(communicationSettings.ignoredPlayers, name)
    communicationSettings.useIgnoreList = true
end

function removeIgnoredPlayer(name)
    table.removevalue(communicationSettings.ignoredPlayers, name)
end

function isWhitelisted(name)
    return table.find(communicationSettings.whitelistedPlayers, name, true)
end

function addWhitelistedPlayer(name)
    if isWhitelisted(name) then
        return
    end
    table.insert(communicationSettings.whitelistedPlayers, name)
end

function removeWhitelistedPlayer(name)
    table.removevalue(communicationSettings.whitelistedPlayers, name)
end

function isIgnoringPrivate()
    return communicationSettings.privateMessages
end

function isIgnoringYelling()
    return communicationSettings.yelling
end

function isAllowingVIPs()
    return communicationSettings.allowVIPs
end

function onClickIgnoreButton()
    if communicationWindow then
        return
    end
    communicationWindow = g_ui.displayUI('communicationwindow')
    local ignoreListPanel = communicationWindow:getChildById('ignoreList')
    local whiteListPanel = communicationWindow:getChildById('whiteList')
    communicationWindow.onDestroy = function()
        communicationWindow = nil
    end

    local useIgnoreListBox = communicationWindow:getChildById('checkboxUseIgnoreList')
    useIgnoreListBox:setChecked(communicationSettings.useIgnoreList)
    local useWhiteListBox = communicationWindow:getChildById('checkboxUseWhiteList')
    useWhiteListBox:setChecked(communicationSettings.useWhiteList)

    local removeIgnoreButton = communicationWindow:getChildById('buttonIgnoreRemove')
    removeIgnoreButton:disable()
    ignoreListPanel.onChildFocusChange = function()
        removeIgnoreButton:enable()
    end
    removeIgnoreButton.onClick = function()
        local selection = ignoreListPanel:getFocusedChild()
        if selection then
            ignoreListPanel:removeChild(selection)
            selection:destroy()
        end
        removeIgnoreButton:disable()
    end

    local removeWhitelistButton = communicationWindow:getChildById('buttonWhitelistRemove')
    removeWhitelistButton:disable()
    whiteListPanel.onChildFocusChange = function()
        removeWhitelistButton:enable()
    end
    removeWhitelistButton.onClick = function()
        local selection = whiteListPanel:getFocusedChild()
        if selection then
            whiteListPanel:removeChild(selection)
            selection:destroy()
        end
        removeWhitelistButton:disable()
    end

    local newlyIgnoredPlayers = {}
    local addIgnoreName = communicationWindow:getChildById('ignoreNameEdit')
    local addIgnoreButton = communicationWindow:getChildById('buttonIgnoreAdd')
    local addIgnoreFunction = function()
        local newEntry = addIgnoreName:getText()
        if newEntry == '' then
            return
        end
        if table.find(getIgnoredPlayers(), newEntry) then
            return
        end
        if table.find(newlyIgnoredPlayers, newEntry) then
            return
        end
        local label = g_ui.createWidget('IgnoreListLabel', ignoreListPanel)
        label:setText(newEntry)
        table.insert(newlyIgnoredPlayers, newEntry)
        addIgnoreName:setText('')
    end
    addIgnoreButton.onClick = addIgnoreFunction

    local newlyWhitelistedPlayers = {}
    local addWhitelistName = communicationWindow:getChildById('whitelistNameEdit')
    local addWhitelistButton = communicationWindow:getChildById('buttonWhitelistAdd')
    local addWhitelistFunction = function()
        local newEntry = addWhitelistName:getText()
        if newEntry == '' then
            return
        end
        if table.find(getWhitelistedPlayers(), newEntry) then
            return
        end
        if table.find(newlyWhitelistedPlayers, newEntry) then
            return
        end
        local label = g_ui.createWidget('WhiteListLabel', whiteListPanel)
        label:setText(newEntry)
        table.insert(newlyWhitelistedPlayers, newEntry)
        addWhitelistName:setText('')
    end
    addWhitelistButton.onClick = addWhitelistFunction

    communicationWindow.onEnter = function()
        if addWhitelistName:isFocused() then
            addWhitelistFunction()
        elseif addIgnoreName:isFocused() then
            addIgnoreFunction()
        end
    end

    local ignorePrivateMessageBox = communicationWindow:getChildById('checkboxIgnorePrivateMessages')
    ignorePrivateMessageBox:setChecked(communicationSettings.privateMessages)
    local ignoreYellingBox = communicationWindow:getChildById('checkboxIgnoreYelling')
    ignoreYellingBox:setChecked(communicationSettings.yelling)
    local allowVIPsBox = communicationWindow:getChildById('checkboxAllowVIPs')
    allowVIPsBox:setChecked(communicationSettings.allowVIPs)

    local saveButton = communicationWindow:recursiveGetChildById('buttonSave')
    saveButton.onClick = function()
        communicationSettings.ignoredPlayers = {}
        for i = 1, ignoreListPanel:getChildCount() do
            addIgnoredPlayer(ignoreListPanel:getChildByIndex(i):getText())
        end

        communicationSettings.whitelistedPlayers = {}
        for i = 1, whiteListPanel:getChildCount() do
            addWhitelistedPlayer(whiteListPanel:getChildByIndex(i):getText())
        end

        communicationSettings.useIgnoreList = useIgnoreListBox:isChecked()
        communicationSettings.useWhiteList = useWhiteListBox:isChecked()
        communicationSettings.yelling = ignoreYellingBox:isChecked()
        communicationSettings.privateMessages = ignorePrivateMessageBox:isChecked()
        communicationSettings.allowVIPs = allowVIPsBox:isChecked()
        communicationWindow:destroy()
    end

    local cancelButton = communicationWindow:recursiveGetChildById('buttonCancel')
    cancelButton.onClick = function()
        communicationWindow:destroy()
    end

    local ignoredPlayers = getIgnoredPlayers()
    for i = 1, #ignoredPlayers do
        local label = g_ui.createWidget('IgnoreListLabel', ignoreListPanel)
        label:setText(ignoredPlayers[i])
    end

    local whitelistedPlayers = getWhitelistedPlayers()
    for i = 1, #whitelistedPlayers do
        local label = g_ui.createWidget('WhiteListLabel', whiteListPanel)
        label:setText(whitelistedPlayers[i])
    end
end

function online()
    defaultTab = addTab(tr('Local Chat'), true)
    serverTab = addTab(tr('Server Log'), false)

    if g_game.getClientVersion() >= 820 then
        local tab = addTab('NPCs', false)
        tab.npcChat = true
    end
    if g_game.getClientVersion() < 862 then
        Keybind.new("Dialogs", "Open Rule Violation", "Ctrl+R", "")
        local gameRootPanel = modules.game_interface.getRootPanel()
        Keybind.bind("Dialogs", "Open Rule Violation", {
          {
            type = KEY_DOWN,
            callback = openPlayerReportRuleViolationWindow,
          }
        }, gameRootPanel)
    end
    
    -- Update chat mode when game comes online to ensure proper key binding
    updateChatMode()
    
    -- open last channels
    local lastChannelsOpen = g_settings.getNode('lastChannelsOpen')
    if lastChannelsOpen then
        local savedChannels = lastChannelsOpen[g_game.getCharacterName()]
        if savedChannels then
            for channelName, channelId in pairs(savedChannels) do
                channelId = tonumber(channelId)
                if channelId ~= -1 and channelId < 100 then
                    if not table.find(channels, channelId) then
                        g_game.joinChannel(channelId)
                        table.insert(ignoredChannels, channelId)
                    end
                end
            end
        end
    end
    scheduleEvent(function()
        ignoredChannels = {}
    end, 3000)
end

function offline()
    clear()
end

function onChannelEvent(channelId, name, type)
    local fmt = ChannelEventFormats[type]
    if not fmt then
        print(('Unknown channel event type (%d).'):format(type))
        return
    end

    local channel = channels[channelId]
    if channel then
        local tab = getTab(channel)
        if tab then
            addTabText(fmt:format(name), SpeakTypesSettings.channelOrange, tab)
        end
    end
end

function onTextChange(text)
    local player = g_game.getLocalPlayer()
    local tab = tab or getCurrentTab()
    if tab == defaultTab or tab == serverTab then
        if player then
            player:setTyping(text ~= "")
        end
    else
        player:setTyping(false)
    end
end

function setExtendedView(bool)
    if bool then
        consolePanel:setMarginRight(10)
        consolePanel:setMarginBottom(10)
        consolePanel:getChildById('extendedViewDraggable'):show()
        consolePanel:getChildById('extendedViewHide'):show()
        consolePanel:getChildById('extendedViewHide'):setChecked(not gameBottomPanel:isVisible())
    else
        consolePanel:setMarginRight(0)
        consolePanel:setMarginBottom(0)
        consolePanel:getChildById('extendedViewDraggable'):hide()
        consolePanel:getChildById('extendedViewHide'):hide()
        gameBottomPanel:show(true)
        destroyButtonChat()
    end
    gameBottomPanel:setDraggable(not bool)
end

function extendedViewDraggable(bool)
    gameBottomPanel:setDraggable(not bool)
end

function extendedViewCanSee(bool)
    local consoleTabBar = gameBottomPanel:getChildById('consolePanel'):getChildById('consoleTabBar')
    local consoleBuffer = consoleTabBar:getCurrentTab().tabPanel:getChildById('consoleBuffer')

    local children = gameBottomPanel:getChildren()
    if bool then
        for _, child in pairs(children) do
            child:setVisible(false)
        end
        consoleBuffer:setVisible(true)
        gameBottomPanel:setPhantom(true)
        gameBottomPanel:setVisible(true)
        gameBottomPanel:getChildById('consolePanel'):setVisible(true)
        for _, child in pairs(gameBottomPanel:getChildById('consolePanel'):getChildren()) do
            if child:getId() == "consoleContentPanel" then
                child:disable()
                child:setVisible(true)
                child.tabPanel.consoleScrollBar:setVisible(false)
            else
                child:setVisible(false)
            end
        end
        consoleTabBar:getCurrentTab().tabPanel:getChildById('consoleBuffer'):setImageSource("")
        gameBottomPanel:setImageSource("")
    else
        for _, child in pairs(gameBottomPanel:getChildById('consolePanel'):getChildren()) do
            if child:getId() == "consoleContentPanel" then
                child:enable()
                child:setVisible(false)
            end
        end
    end
end

function returnChat()
    local consoleTabBar = gameBottomPanel:getChildById('consolePanel'):getChildById('consoleTabBar')
    local consoleBuffer = consoleTabBar:getCurrentTab().tabPanel:getChildById('consoleBuffer')

    local children = gameBottomPanel:getChildren()
    for _, child in pairs(children) do
        if child:getId() == "cooldownWindow" then
            child:setVisible(modules.client_options.getOption('showSpellGroupCooldowns'))
        else
            child:setVisible(true)
        end
    end
    gameBottomPanel:getChildById('consolePanel'):setVisible(true)
    for _, child in pairs(gameBottomPanel:getChildById('consolePanel'):getChildren()) do
        if child:getId() ~= "consoleTextEdit" then
            child:setVisible(true)
        else
            child:setVisible(not consoleToggleChat.isChecked)
        end
    end
    consoleTabBar:getCurrentTab().tabPanel:getChildById('consoleBuffer'):setImageSource(
        "/images/ui/3pixel_frame_borderimage")
    gameBottomPanel:setImageSource("/images/ui/background_dark")
    gameBottomPanel:setPhantom(false)
end

function extendedViewHide(bool)
    if bool then
        gameBottomPanel:hide()
        createButtonChat()
        extendedViewCanSee(extendedViewButtonShowAlphaChat:isOn())
    else
        consolePanel:getChildById('extendedViewHide'):setChecked(false)
        gameBottomPanel:show(true)
        extendedViewCanSee(false)
        returnChat()
        if extendedViewButtonShowAlphaChat then
            extendedViewButtonShowAlphaChat:setOn(false)
        end
        destroyButtonChat()
    end
end

function createButtonChat()
    if extendedViewButtonToggleChat then
        return
    end
    local mapPanel = modules.game_interface.getMapPanel()
    local stringNameMobileOrPc = g_platform.isMobile() and "GameAction" or "MainToggleButton"
    extendedViewButtonToggleChat = g_ui.createWidget(stringNameMobileOrPc, mapPanel)
    extendedViewButtonToggleChat:setId("test")
    local hightMobileWidget = 0
    if g_platform.isMobile() then
        hightMobileWidget = modules.game_joystick.getPanel():getHeight()
        extendedViewButtonToggleChat.image:setImageSource("/images/game/mobile/chat")
        extendedViewButtonToggleChat:addAnchor(AnchorRight, "parent", AnchorRight)
        extendedViewButtonToggleChat:setMarginBottom(hightMobileWidget)
        extendedViewButtonToggleChat:setMarginRight(15)
        extendedViewButtonToggleChat:setMarginBottom(hightMobileWidget)
        extendedViewButtonToggleChat:setSize("60 60")
    else
        extendedViewButtonToggleChat:setIcon("/images/game/npcicons/icon_chat")
        extendedViewButtonToggleChat:setMarginBottom(10)
        extendedViewButtonToggleChat:setSize("30 23")
        extendedViewButtonToggleChat:addAnchor(AnchorLeft, "parent", AnchorLeft)
    end
    extendedViewButtonToggleChat:addAnchor(AnchorBottom, "parent", AnchorBottom)
    extendedViewButtonToggleChat.onClick = function(a, b)
        extendedViewHide(modules.game_interface.currentViewMode ~= 2)
    end
    extendedViewButtonShowAlphaChat = g_ui.createWidget(stringNameMobileOrPc, mapPanel)
    extendedViewButtonShowAlphaChat:setIcon("/images/game/npcicons/icon_chat")
    extendedViewButtonShowAlphaChat:addAnchor(AnchorBottom, "parent", AnchorBottom)
    if g_platform.isMobile() then
        extendedViewButtonShowAlphaChat:setMarginBottom(hightMobileWidget)
        extendedViewButtonShowAlphaChat:setSize("60 60")
        extendedViewButtonShowAlphaChat:addAnchor(AnchorRight, "test", AnchorLeft)
    else
        extendedViewButtonShowAlphaChat:setSize("30 23")
        extendedViewButtonShowAlphaChat:addAnchor(AnchorLeft, "test", AnchorRight)
        extendedViewButtonShowAlphaChat:setMarginBottom(10)
    end
    extendedViewButtonShowAlphaChat:setMarginLeft(5)
    extendedViewButtonShowAlphaChat.onClick = function(a, b)
        if extendedViewButtonShowAlphaChat:isOn() then
            extendedViewButtonShowAlphaChat:setOn(false)
        else
            extendedViewButtonShowAlphaChat:setOn(true)
        end
        extendedViewCanSee(extendedViewButtonShowAlphaChat:isOn())
    end
end

function destroyButtonChat()
    if extendedViewButtonToggleChat and not extendedViewButtonToggleChat:isDestroyed() then
        extendedViewButtonToggleChat:destroy()
        extendedViewButtonToggleChat = nil
    end
    if extendedViewButtonShowAlphaChat and not extendedViewButtonShowAlphaChat:isDestroyed() then
        extendedViewButtonShowAlphaChat:destroy()
        extendedViewButtonShowAlphaChat = nil
    end
end

function activateReadOnlyMode(channelName)
    activeactiveReadOnlyTabName = channelName
    readOnlyButton:setText(activeactiveReadOnlyTabName)
    if activeactiveReadOnlyTabName:len() > 13 then
        readOnlyButton:setWidth(readOnlyButton:getTextSize().width + 10)
    else
        readOnlyButton:setWidth(readOnlyButton.tabWidth)
    end
    copyMessagesToReadOnlyPanel(channelName)
    local tab = consoleTabBar:getTab(channelName)
    if tab then
        if tab.newMessageEvent then
            removeEvent(tab.newMessageEvent)
            tab.newMessageEvent = nil
        end
        if tab.isOnRedMessage then
            if consoleTabBar:getCurrentTab() == tab then
                tab:setColor('#dfdfdfff')
            else
                tab:setColor('#7f7f7fff')
            end
            tab.isOnRedMessage = false
        end
    end
    if not readOnlyModeEnabled then
        toggleReadOnlyMode()
    end
end

function onReadOnlyMouseClick()
    local contextMenu = g_ui.createWidget("PopupMenu")
    contextMenu:setGameMenu(true)
    if readOnlyModeEnabled and activeactiveReadOnlyTabName ~= "" then
        local sourceTab = consoleTabBar:getTab(activeactiveReadOnlyTabName)
        if sourceTab then
            addClonedMenuOptions(sourceTab, contextMenu, {
                readonly = true,
                close = true
            })
            contextMenu:addSeparator()
        end
        contextMenu:addOption(tr("Close Read-Only Tab"), function()
            clearReadOnlyTab()
            toggleReadOnlyMode()
        end)
    else
        for _, tab in pairs(consoleTabBar.tabs) do
            local tabName = tab:getText()
            contextMenu:addOption(tr("Show " .. tabName), function()
                activateReadOnlyMode(tabName)
            end)
        end
    end
    contextMenu:display(mousePos)
end

function copyMessagesToReadOnlyPanel(channelName)
    local sourceTab = consoleTabBar:getTab(channelName)
    if not sourceTab then
        return
    end
    local readOnlyBuffer = readOnlyPanel:getChildById('panel')
    for _, child in pairs(readOnlyBuffer:getChildren()) do
        if child then
            child:destroy()
            child = nil
        end
    end
    local sourcePanel = consoleTabBar:getTabPanel(sourceTab)
    local sourceBuffer = sourcePanel:getChildById('consoleBuffer')
    for _, sourceLabel in pairs(sourceBuffer:getChildren()) do
        local clonedLabel = g_ui.createWidget('ConsoleLabel', readOnlyBuffer)
        clonedLabel:setId('consoleLabel' .. readOnlyBuffer:getChildCount())
        if sourceLabel.coloredData then
            clonedLabel:setColoredText(sourceLabel.coloredData)
        else
            clonedLabel:setText(sourceLabel:getText())
        end
        clonedLabel:setColor(sourceLabel:getColor())
        if sourceLabel:hasEventListener(EVENT_TEXT_CLICK) then
            clonedLabel:setEventListener(EVENT_TEXT_CLICK)
            connect(clonedLabel, {
                onTextClick = onConsoleTextClicked
            })
        end
        if sourceLabel:hasEventListener(EVENT_TEXT_HOVER) then
            clonedLabel:setEventListener(EVENT_TEXT_HOVER)
            connect(clonedLabel, {
                onTextHoverChange = onConsoleTextHovered
            })
        end
    end
end

function clearReadOnlyTab()
    for _, child in pairs(readOnlyPanel:getChildById('panel'):getChildren()) do
        if child then
            child:destroy()
            child = nil
        end
    end
    readOnlyButton:setIcon("")
    activeactiveReadOnlyTabName = ""
end

function toggleReadOnlyMode()
    if readOnlyModeEnabled then
        consoleContentPanel:removeAnchor(AnchorRight)
        consoleContentPanel:addAnchor(AnchorRight, "parent", AnchorRight)
        readOnlyPanel:hide()
        readOnlyButton:setText("")
        readOnlyButton:setIcon("/images/game/console/readOnly")
        readOnlyButton:setImageSource("")
        activeactiveReadOnlyTabName = ""
        readOnlyButton:setWidth(readOnlyButton.tabWidth)
    else
        consoleContentPanel:removeAnchor(AnchorRight)
        consoleContentPanel:addAnchor(AnchorRight, "parent", AnchorHorizontalCenter)
        readOnlyPanel:show()
        readOnlyPanel:removeAnchor(AnchorLeft)
        readOnlyPanel:removeAnchor(AnchorRight)
        readOnlyPanel:addAnchor(AnchorLeft, "parent", AnchorHorizontalCenter)
        readOnlyPanel:addAnchor(AnchorRight, "parent", AnchorRight)
        readOnlyButton:removeAnchor(AnchorLeft)
        readOnlyButton:setIcon("")
        readOnlyButton:setImageSource("/images/ui/console_button")
    end
    readOnlyModeEnabled = not readOnlyModeEnabled
end

function addClonedMenuOptions(sourceTab, targetMenu, excludedOptions)
    -- todo improve or move to \modules\corelib\ui\uipopupmenu.lua
    excludedOptions = excludedOptions or {}
    local currentWorldName = g_game.getWorldName()
    local currentCharacterName = g_game.getCharacterName()
    local currentChannelName = sourceTab:getText()
    if not excludedOptions["close"] then
        targetMenu:addOption(tr('Close'), function()
            removeTab(currentChannelName)
        end)
    end
    if not excludedOptions["readonly"] then
        if readOnlyModeEnabled and activeactiveReadOnlyTabName == currentChannelName then
            targetMenu:addOption(tr("Close read-only"), function()
                clearReadOnlyTab()
                toggleReadOnlyMode()
            end)
        else
            targetMenu:addOption(tr("Open read-only"), function()
                activateReadOnlyMode(currentChannelName)
            end)
        end
    end
    if not excludedOptions["separator1"] then
        targetMenu:addSeparator()
    end
    if not excludedOptions["clear"] then
        targetMenu:addOption(tr('Clear Messages'), function()
            if readOnlyModeEnabled and activeactiveReadOnlyTabName == currentChannelName then
                clearTabByName(currentChannelName)
                copyMessagesToReadOnlyPanel(currentChannelName)
            else
                clearChannel(consoleTabBar)
            end
        end)
    end
    if not excludedOptions["save"] then
        targetMenu:addOption(tr('Save Messages'), function()
            saveChannelMessages(sourceTab, currentWorldName, currentCharacterName, currentChannelName)
        end)
    end
end

function saveChannelMessages(tab, worldName, characterName, channelName)
    local tabPanel = consoleTabBar:getTabPanel(tab)
    local consoleBuffer = tabPanel:getChildById('consoleBuffer')
    local messageLines = {}
    for _, label in pairs(consoleBuffer:getChildren()) do
        table.insert(messageLines, label:getText())
    end
    local fileName = worldName .. ' - ' .. characterName .. ' - ' .. channelName .. '.txt'
    local filePath = '/' .. fileName
    table.insert(messageLines, 1, os.date('\nChannel saved at %a %b %d %H:%M:%S %Y'))
    if g_resources.fileExists(filePath) then
        local existingContent = protectedcall(g_resources.readFileContents, filePath) or ''
        table.insert(messageLines, 1, existingContent)
    end
    g_resources.writeFileContents(filePath, table.concat(messageLines, '\n'))
    modules.game_textmessage.displayStatusMessage(tr('Channel appended to %s', fileName))
end

function clearTabByName(tabName)
    local tab = getTab(tabName)
    if tab then
        local panel = consoleTabBar:getTabPanel(tab)
        local consoleBuffer = panel:getChildById('consoleBuffer')
        consoleBuffer:destroyChildren()
    end
end

function getConsole()
    return consoleTextEdit
end
