--- Creates the action bar UI logic
local function createActionBars()
    local bottomPanel = modules.game_interface.getBottomActionPanel()
    local leftPanel = modules.game_interface.getLeftActionPanel()
    local rightPanel = modules.game_interface.getRightActionPanel()
    -- 1-3: bottom
    -- 4-6: left
    -- 7-9: right
    for i = 1, 9 do
        local parent, index, layout, isVertical
        if i <= 3 then
            parent = bottomPanel
            index = i
            layout = '/modules/game_actionbar/otui/actionbar'
            isVertical = false
        elseif i <= 6 then
            parent = leftPanel
            index = i - 3
            layout = '/modules/game_actionbar/otui/sideactionbar'
            isVertical = true
        else
            parent = rightPanel
            index = i - 6
            layout = '/modules/game_actionbar/otui/sideactionbar'
            isVertical = true
        end

        actionBars[i] = g_ui.loadUI(layout, parent)
        actionBars[i]:setId("actionbar." .. i)
        actionBars[i].n = i
        actionBars[i].isVertical = isVertical
        parent:moveChildToIndex(actionBars[i], index)
    end
end

--- Initializes action bars on creation
function onCreateActionBars()
    if #actionBars ~= 0 then
        return true
    end
    local gameMapPanel = modules.game_interface.gameMapPanel
    if not gameMapPanel then
        return true
    end
    if #actionBars == 0 then
        createActionBars()
    end
    activeActionBars = {}
    for i = 1, #actionBars do
        local actionbar = actionBars[i]
        local barState = ApiJson.getActionBar(i) or {}
        local enabled = barState.isVisible and true or false
        actionbar:setVisible(enabled)
        actionbar:setOn(enabled)
        setupActionBar(i)
        if enabled then
            addActiveActionBar(actionbar)
        end
    end
    resizeLockButtons()
end

local function updateLockIcon(button, optionKey)
    if not button then
        return
    end
    local locked = ApiJson.getClientOption(optionKey) and true or false
    button:setIcon(locked and "/images/game/actionbar/locked" or "/images/game/actionbar/unlocked")
end

local function getFirstVisibleButton(actionBar)
    for _, button in ipairs(actionBar.tabBar:getChildren()) do
        if button:isVisible() then
            return button
        end
    end
    return nil
end

local function getPrevInvisibleButton(actionBar)
    local lastButton = nil
    for _, button in ipairs(actionBar.tabBar:getChildren()) do
        if button:isVisible() then
            return lastButton
        end
        lastButton = button
    end
    return nil
end

--- Gets the last visible button in a bar
local function getLastVisibleButton(actionBar)
    for _, button in ipairs(actionBar.tabBar:getReverseChildren()) do
        if button:isVisible() then
            return button
        end
    end
    return nil
end

--- Gets the next invisible child button
local function getNextInvisibleChild(actionBar, firstIndex)
    for i, button in ipairs(actionBar.tabBar:getChildren()) do
        if i >= firstIndex and not button:isVisible() then
            return button
        end
    end
    return nil
end

--- Resizes lock buttons based on active bars
function resizeLockButtons()
    local rightLockPanel = modules.game_interface.getRightLockPanel()
    local rightCount = getActiveRightBars()
    rightLockPanel:setVisible(true)
    updateLockIcon(rightLockPanel, "actionBarRightLocked")
    if rightCount >= 1 and rightCount <= 3 then
        rightLockPanel:setWidth(35 + (rightCount - 1) * 36 - 1)
        rightLockPanel:getParent():setWidth(((36 + (rightCount - 1) * 36)) + 1)
    else
        rightLockPanel:setWidth(0)
        rightLockPanel:getParent():setWidth(0)
        rightLockPanel:setVisible(false)
    end
    local bottomLockPanel = modules.game_interface.getBottomLockPanel()
    local bottomCount = getActiveBottomBars()
    bottomLockPanel:setVisible(true)
    updateLockIcon(bottomLockPanel, "actionBarBottomLocked")
    if bottomCount >= 1 and bottomCount <= 3 then
        bottomLockPanel:setHeight(34 + (bottomCount - 1) * 36)
    else
        bottomLockPanel:setHeight(0)
        bottomLockPanel:setVisible(false)
    end
    local leftLockPanel = modules.game_interface.getLeftLockPanel()
    local leftCount = getActiveLeftBars()
    leftLockPanel:setVisible(true)
    updateLockIcon(leftLockPanel, "actionBarLeftLocked")
    if leftCount >= 1 and leftCount <= 3 then
        leftLockPanel:setWidth(35 + (leftCount - 1) * 36 - 1)
        leftLockPanel:getParent():setWidth(((36 + (leftCount - 1) * 36)) + 1)
    else
        leftLockPanel:setWidth(0)
        leftLockPanel:getParent():setWidth(0)
        leftLockPanel:setVisible(false)
    end
end

--- Updates visibility of widgets in action bars
function updateVisibleWidgets()
    for _, actionBar in pairs(actionBars) do
        if actionBar:isVisible() then
            local tabBar = actionBar.tabBar
            local children = tabBar:getChildren()
            local dimension = actionBar.isVertical and tabBar:getHeight() or tabBar:getWidth()
            local visibleCount = math.max(1, math.floor(dimension / 36))
            local firstIndex = actionBar.firstVisibleIndex or 1
            local totalChildren = #children
            
            -- If we can show all buttons, start from the beginning
            if visibleCount >= totalChildren then
                firstIndex = 1
            else
                -- Check if we're currently at or past the end
                local currentLastVisible = firstIndex + visibleCount - 1
                
                if currentLastVisible > totalChildren then
                    -- We're past the end, pull back to show the last N buttons
                    firstIndex = math.max(1, totalChildren - visibleCount + 1)
                elseif currentLastVisible < totalChildren then
                    -- We're not at the end yet, but check if window got bigger
                    -- and we can show more buttons by moving forward
                    local optimalFirstIndex = math.max(1, totalChildren - visibleCount + 1)
                    
                    -- If we were previously at the end and window got bigger,
                    -- or if we can move forward to show more without losing current view
                    if firstIndex > optimalFirstIndex then
                        -- Keep current position, we have space ahead
                    else
                        -- Try to show more at the end if we have space
                        local newFirstIndex = math.min(firstIndex, optimalFirstIndex)
                        firstIndex = newFirstIndex
                    end
                end

                -- Final bounds check
                firstIndex = math.max(1, math.min(firstIndex, totalChildren - visibleCount + 1))
            end
            
            -- Update the action bar's stored indices
            actionBar.firstVisibleIndex = firstIndex
            
            -- Apply visibility to buttons
            for i, button in ipairs(children) do
                if i >= firstIndex and i < firstIndex + visibleCount then
                    button:setVisible(true)
                    actionBar.lastVisibleIndex = i
                else
                    button:setVisible(false)
                end
            end
            -- Update navigation button states
            local prevEnabled = firstIndex > 1
            local nextEnabled = (firstIndex + visibleCount - 1) < totalChildren
            
            if actionBar.prevPanel then
                if actionBar.prevPanel.prev then actionBar.prevPanel.prev:setOn(prevEnabled) end
                if actionBar.prevPanel.first then actionBar.prevPanel.first:setOn(prevEnabled) end
            end
            if actionBar.nextPanel then
                if actionBar.nextPanel.next then actionBar.nextPanel.next:setOn(nextEnabled) end
                if actionBar.nextPanel.last then actionBar.nextPanel.last:setOn(nextEnabled) end
            end
        end
    end
end

--- Handles action button scrolling movement
function moveActionButtons(widget)
    local dir = widget:getId()
    local actionBar = widget:getParent():getParent()
    local scroll = actionBar.actionScroll
    local tabBar = actionBar.tabBar
    local buttons = {actionBar.prevPanel.prev, actionBar.prevPanel.first, actionBar.nextPanel.next,
                     actionBar.nextPanel.last}
    local children = tabBar:getChildren()
    local reverseChildren = tabBar.getReverseChildren and tabBar:getReverseChildren() or {}
    local dimension = actionBar.isVertical and tabBar:getHeight() or tabBar:getWidth()
    local visibleCount = math.max(1, math.floor(dimension / 36))
    if dir == "next" then
        local firstVisible = getFirstVisibleButton(actionBar)
        if not firstVisible then
            return
        end
        local firstIndex = tabBar:getChildIndex(firstVisible)
        local nextInvisible = getNextInvisibleChild(actionBar, firstIndex)
        if not nextInvisible then
            return
        end
        firstVisible:setVisible(false)
        nextInvisible:setVisible(true)
        scroll:increment(36)
        actionBar.firstVisibleIndex = tabBar:getChildIndex(firstVisible) + 1
        actionBar.lastVisibleIndex = tabBar:getChildIndex(nextInvisible)
    elseif dir == "prev" then
        local prevInvisible = getPrevInvisibleButton(actionBar)
        local lastVisible = getLastVisibleButton(actionBar)
        if not prevInvisible then
            return
        end
        prevInvisible:setVisible(true)
        lastVisible:setVisible(false)
        scroll:decrement(36)
        actionBar.firstVisibleIndex = tabBar:getChildIndex(prevInvisible)
        actionBar.lastVisibleIndex = tabBar:getChildIndex(lastVisible) - 1
    elseif dir == "first" then
        for i, button in ipairs(children) do
            button:setVisible(i <= visibleCount)
        end
        actionBar.firstVisibleIndex = 1
        actionBar.lastVisibleIndex = tabBar:getChildIndex(getLastVisibleButton(actionBar))
        scroll:setValue(scroll:getMinimum())
    elseif dir == "last" then
        for i, button in ipairs(reverseChildren) do
            button:setVisible(i <= visibleCount)
        end
        actionBar.firstVisibleIndex = tabBar:getChildIndex(getFirstVisibleButton(actionBar))
        actionBar.lastVisibleIndex = #children
        scroll:setValue(scroll:getMaximum())
    end

    local prevEnabled = actionBar.firstVisibleIndex ~= 1
    local nextEnabled = actionBar.lastVisibleIndex ~= #children
    buttons[1]:setOn(prevEnabled)
    buttons[2]:setOn(prevEnabled)
    buttons[3]:setOn(nextEnabled)
    buttons[4]:setOn(nextEnabled)
end

--- Toggles the lock status of action bars
function changeLockStatus(button, barType)
    local barData = {
        ["Bottom"] = {
            option = "actionBarBottomLocked",
            startPos = 1,
            endPos = 3
        },
        ["Left"] = {
            option = "actionBarLeftLocked",
            startPos = 4,
            endPos = 6
        },
        ["Right"] = {
            option = "actionBarRightLocked",
            startPos = 7,
            endPos = 9
        }
    }
    local data = barData[barType]
    if not data then
        return true
    end
    ApiJson.toggleLockGroup(data.option, data.startPos, data.endPos)
    for i = data.startPos, data.endPos do
        actionBars[i].locked = ApiJson.isBarLocked(i)
    end
    updateLockIcon(button, data.option)
end

function unbindActionBarEvent(actionbar)
    for _, button in pairs(actionbar.tabBar:getChildren()) do
        if button.cache and button.cache.hotkey then
            unbindHotkey(button.cache.hotkey)
        end
        if button.cache and button.cache.cooldownEvent then
            removeEvent(button.cache.cooldownEvent)
        end
        resetButtonCache(button)
    end
end

