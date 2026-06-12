local window = nil
local selectedEntry = nil
local consoleEvent = nil
local taskButton

function init()
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = destroy
    })

    window = g_ui.displayUI('tasks')
    window:setVisible(false)

    Keybind.new('Windows', 'show/hide Tasks Windows', 'Ctrl+A', '')
    Keybind.bind('Windows', 'show/hide Tasks Windows', {
      {
        type = KEY_DOWN,
        callback = toggleWindow,
       }
    })

    g_keyboard.bindKeyDown('Escape', hideWindowzz)
	taskButton = modules.client_topmenu.addLeftGameButton('taskButton', tr('Tasks'), '/modules/game_tasks/images/taskIcon', toggleWindow)
    ProtocolGame.registerExtendedJSONOpcode(215, parseOpcode)
end

function terminate()
    disconnect(g_game, {
        onGameEnd = destroy
    })
    ProtocolGame.unregisterExtendedJSONOpcode(215, parseOpcode)
    taskButton:destroy()
    destroy()
    Keybind.delete('Windows', 'show/hide Tasks Windows')
end

function onGameStart()
    if (window) then
        window:destroy()
        window = nil
    end

    window = g_ui.displayUI('tasks')
    window:setVisible(false)
    window.listSearch.search.onKeyPress = onFilterSearch
end

function destroy()
    if (window) then
        window:destroy()
        window = nil
    end
end

function parseOpcode(protocol, opcode, data)
    updateTasks(data)
end

function sendOpcode(data)
    local protocolGame = g_game.getProtocolGame()

    if protocolGame then
        protocolGame:sendExtendedJSONOpcode(215, data)
    end
end

function onItemSelect(list, focusedChild, unfocusedChild, reason)
    if focusedChild then
        selectedEntry = tonumber(focusedChild:getId())

        if (not selectedEntry) then
            return true
        end

        window.finishButton:hide()
        window.startButton:hide()
        window.abortButton:hide()
        local children = window.selectionList:getChildren()

        for _, child in ipairs(children) do
            local id = tonumber(child:getId())

            if (selectedEntry == id) then
                local kills = child.kills:getText()

                if (child.progress:getWidth() == 159) then
                    window.finishButton:show()
                elseif (kills:find('/')) then
                    window.abortButton:show()
                else
                    window.startButton:show()
                end
            end
        end
    end
end

function onFilterSearch()
    addEvent(function()
        local searchText = window.listSearch.search:getText():lower():trim()
        local children = window.selectionList:getChildren()

        if (searchText:len() >= 1) then
            for _, child in ipairs(children) do
                local text = child.name:getText():lower()

                if (text:find(searchText)) then
                    child:show()
                else
                    child:hide()
                end
            end
        else
            for _, child in ipairs(children) do
                child:show()
            end
        end
    end)
end

function start()
    if (not selectedEntry) then
        return not setTaskConsoleText("Please select monster from monster list.", "red")
    end

    sendOpcode({
        action = 'start',
        entry = selectedEntry
    })
end

function finish()
    if (not selectedEntry) then
        return not setTaskConsoleText("Please select monster from monster list.", "red")
    end

    sendOpcode({
        action = 'finish',
        entry = selectedEntry
    })
end

function abort()
    local cancelConfirm = nil

    if (cancelConfirm) then
        cancelConfirm:destroy()
        cancelConfirm = nil
    end

    if (not selectedEntry) then
        return not setTaskConsoleText("Please select monster from monster list.", "red")
    end

    local yesFunc = function()
        cancelConfirm:destroy()
        cancelConfirm = nil
        sendOpcode({
            action = 'cancel',
            entry = selectedEntry
        })
    end

    local noFunc = function()
        cancelConfirm:destroy()
        cancelConfirm = nil
    end

    cancelConfirm = displayGeneralBox(tr('Tasks'), tr("Do you really want to abort this task?"), {
        {
            text = tr('Yes'),
            callback = yesFunc
        },
        {
            text = tr('No'),
            callback = noFunc
        },
        anchor = AnchorHorizontalCenter
    }, yesFunc, noFunc)
end

function updateTasks(data)
    if (data['message']) then
        return setTaskConsoleText(data['message'], data['color'])
    end

    local selectionList = window.selectionList
    selectionList.onChildFocusChange = onItemSelect
    selectionList:destroyChildren()
    local playerTaskIds = {}

    for _, task in ipairs(data['playerTasks']) do
        local button = g_ui.createWidget("SelectionButton", window.selectionList)
        button:setId(task.id)
        table.insert(playerTaskIds, task.id)
        button.creature:setOutfit(task.looktype)
        button.name:setText(task.name)
        button.kills:setText('Kills: ' .. task.done .. '/' .. task.kills)
        button.reward:setText('Reward: ' .. task.exp .. ' exp')
        if not (task.taskPoints == nil) then
          button.rewardTaskPoints:setText('Task Points: ' .. task.taskPoints .. '')
        else
          button.rewardTaskPoints:setText('Task Points: 0')
        end
        local progress = 159 * task.done / task.kills
        button.progress:setWidth(progress)
        selectionList:focusChild(button)
    end

    for _, task in ipairs(data['allTasks']) do
        if (not table.contains(playerTaskIds, task.id)) then
            local button = g_ui.createWidget("SelectionButton", window.selectionList)
            button:setId(task.id)
            button.creature:setOutfit(task.looktype)
            button.name:setText(task.name)
            button.kills:setText('Kills: ' .. task.kills)
            button.reward:setText('Reward: ' .. task.exp .. ' exp')
            if not (task.taskPoints == nil) then
              button.rewardTaskPoints:setText('Task Points: ' .. task.taskPoints .. '')
            else
              button.rewardTaskPoints:setText('Task Points: 0')
            end
            button.progress:setWidth(0)
            selectionList:focusChild(button)
        end
    end

    selectionList:focusChild(selectionList:getFirstChild())
    onFilterSearch()
end

function toggleWindow()
    if (not g_game.isOnline()) then
        return
    end

    if (window:isVisible()) then
        sendOpcode({
            action = 'hide'
        })
        window:setVisible(false)
    else
        sendOpcode({
            action = 'info'
        })
        window:setVisible(true)
    end
end

function hideWindowzz()
    if (not g_game.isOnline()) then
        return
    end

    if (window:isVisible()) then
        sendOpcode({
            action = 'hide'
        })
        window:setVisible(false)
    end
end

function setTaskConsoleText(text, color)
    if (not color) then
        color = 'white'
    end

    window.info:setText(text)
    window.info:setColor(color)

    if consoleEvent then
        removeEvent(consoleEvent)
        consoleEvent = nil
    end

    consoleEvent = scheduleEvent(function()
        window.info:setText('')
    end, 5000)

    return true
end
