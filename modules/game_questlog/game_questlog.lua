questLogController = Controller:new()

-- @ todo
-- test tracker onUpdateQuestTracker
-- test 14.10
-- questLogController:bindKeyPress('Down' // 'up') focusNextChild // focusPreviousChild
-- PopMenu Miniwindows "Remove completed quests // Automatically track new quests // Automatically untrack completed quests"

-- @  windows
local trackerMiniWindow = nil
local questLogButton = nil
local buttonQuestLogTrackerButton = nil

-- @widgets
local UICheckBox = {
    showComplete = nil,
    showShidden = nil,
    showInQuestTracker = nil
}

local UIlabel = {
    numberQuestComplete = nil,
    numberQuestHidden = nil
}

local UITextList = {
    questLogList = nil,
    questLogLine = nil,
    questLogInfo = nil
}

local UITextEdit = {
    search = nil
}

-- variable
local settings = {}
local namePlayer = ""
local currentQuestId = nil  -- Track the currently selected quest ID
local missionToQuestMap = {} -- Map missionId to questId for navigation
local isNavigating = false   -- Flag to prevent checkbox events during navigation
local isUpdatingCheckbox = false  -- Flag to prevent recursive checkbox events
local questLogCache = {
    items = {},
    completed = 0,
    hidden = 0,
    visible = 0
}

-- const
local COLORS = {
    BASE_1 = "#484848",
    BASE_2 = "#414141",
    SELECTED = "#585858"
}
local file = "/settings/questtracking.json"

--[[=================================================
=               Local Functions                     =
=================================================== ]] --

local function isIdInTracker(key, id)
    if not settings[key] then
        return false
    end
    return table.findbyfield(settings[key], 1, tonumber(id)) ~= nil
end

local function addUniqueIdQuest(key, questId, missionId, missionName, missionDescription)
    if not settings[key] then
        settings[key] = {}
    end

    if not isIdInTracker(key, missionId) then
        table.insert(settings[key], {tonumber(missionId), missionName, missionDescription or missionName, tonumber(questId)})
    end
end

local function removeNumber(key, id)
    if settings[key] then
        table.remove_if(settings[key], function(_, v)
            return v[1] == tonumber(id)
        end)
    end
end

-- Auto-untrack completed quests by checking all tracked quests
local function autoUntrackCompletedQuests()
    if not settings.autoUntrackCompleted or not settings[namePlayer] or not trackerMiniWindow then
        return
    end
    
    local removedMissionIds = {}
    
    -- Check all tracked missions for completion status
    if trackerMiniWindow.contentsPanel and trackerMiniWindow.contentsPanel.list then
        for i = trackerMiniWindow.contentsPanel.list:getChildCount(), 1, -1 do
            local trackerLabel = trackerMiniWindow.contentsPanel.list:getChildByIndex(i)
            if trackerLabel and trackerLabel.description then
                local description = trackerLabel.description:getText()
                local missionId = tonumber(trackerLabel:getId())
                
                -- Check if the mission is completed based on description text
                local isCompleted = description and (
                    string.find(string.lower(description), "%(completed%)") or
                    (string.find(string.lower(description), "complete") and 
                     (string.find(string.lower(description), "quest") or string.find(string.lower(description), "mission")))
                )
                
                if isCompleted then
                    table.insert(removedMissionIds, missionId)
                    
                    -- Remove from settings
                    removeNumber(namePlayer, missionId)
                    
                    -- Remove from tracker display
                    trackerLabel:destroy()
                end
            end
        end
    end
    
    if #removedMissionIds > 0 then
        -- Update tracker layout
        if trackerMiniWindow.contentsPanel and trackerMiniWindow.contentsPanel.list then
            trackerMiniWindow.contentsPanel.list:getLayout():update()
        end
        
        -- Save the updated settings
        save()
    end
end

local function load()
    if g_resources.fileExists(file) then
        local status, result = pcall(function()
            return json.decode(g_resources.readFileContents(file))
        end)
        if not status then
            return g_logger.error(
                "Error while reading profiles file. To fix this problem you can delete storage.json. Details: " ..
                    result)
        end
        return result or {}
    end
end

local function save()
    local status, result = pcall(function()
        return json.encode(settings, 2)
    end)
    if not status then
        return g_logger.error("Error while saving profile settings. Data won't be saved. Details: " .. result)
    end
    if result:len() > 100 * 1024 * 1024 then
        return g_logger.error("Something went wrong, file is above 100MB, won't be saved")
    end
    
    -- Safely attempt to write the file, ignoring errors during logout
    local writeStatus, writeError = pcall(function()
        return g_resources.writeFileContents(file, result)
    end)
    
    if not writeStatus then
        -- Log the error but don't spam the console during normal logout
        g_logger.debug("Could not save quest log settings during logout: " .. tostring(writeError))
    end
end

local sortFunctions = {
    ["Alphabetically (A-Z)"] = function(a, b)
        return a:getText() < b:getText()
    end,
    ["Alphabetically (Z-A)"] = function(a, b)
        return a:getText() > b:getText()
    end,
    ["Completed on Top"] = function(a, b)
        local aCompleted = a.isComplete or false
        local bCompleted = b.isComplete or false

        if aCompleted and not bCompleted then
            return true
        elseif not aCompleted and bCompleted then
            return false
        else
            return a:getText() < b:getText()
        end
    end,
    ["Completed on Bottom"] = function(a, b)
        local aCompleted = a.isComplete or false
        local bCompleted = b.isComplete or false

        if aCompleted and not bCompleted then
            return false
        elseif not aCompleted and bCompleted then
            return true
        else
            return a:getText() < b:getText()
        end
    end
}

local function sendQuestTracker(listToMap)
    local map = {}
    for _, entry in ipairs(listToMap) do
        map[entry[1]] = entry[2]
    end
    g_game.sendRequestTrackerQuestLog(map)
end

local function rebuildTrackerFromSettings()
    if not trackerMiniWindow or not settings[namePlayer] then
        return
    end
    
    -- Clear existing tracker items
    trackerMiniWindow.contentsPanel.list:destroyChildren()
    
    -- Recreate tracker items from our settings
    for i, entry in ipairs(settings[namePlayer]) do
        local missionId, missionName, missionDescription, questId = unpack(entry)
        
        -- Try to get questId from our mapping if not in settings
        if not questId or questId == 0 then
            questId = missionToQuestMap[tonumber(missionId)] or 0
        end
        
        local trackerLabel = g_ui.createWidget('QuestTrackerLabel', trackerMiniWindow.contentsPanel.list)
        trackerLabel:setId(tostring(missionId))
        trackerLabel.questId = questId  -- Store questId for navigation
        trackerLabel.missionId = missionId   -- Store missionId for navigation
        -- Use description if available, fallback to name
        trackerLabel.description:setText(missionDescription or missionName)
        
        -- If we don't have questId, request quest tracker to get updated data from server
        if not questId or questId == 0 then
            -- Missing questId, will be updated by server
        end
    end
    
    -- Request server to send complete tracker data to fill in missing questIds
    if settings[namePlayer] and #settings[namePlayer] > 0 then
        sendQuestTracker(settings[namePlayer])
    end
    
    -- Check for completed quests to auto-untrack
    scheduleEvent(autoUntrackCompletedQuests, 1000) -- Delay to ensure tracker is fully loaded
end

local function findQuestIdForMission(missionId)
    -- Try to find the questId by looking through all quest items and their missions
    if not UITextList.questLogList then
        return nil
    end
    
    for i = 1, UITextList.questLogList:getChildCount() do
        local questItem = UITextList.questLogList:getChildByIndex(i)
        local questId = questItem:getId()
        
        -- We'd need to request each quest line to check, but that would be too expensive
        -- For now, return nil and rely on server data
    end
    
    return nil
end

local function debugTrackerLabels()
    if not trackerMiniWindow or not trackerMiniWindow.contentsPanel or not trackerMiniWindow.contentsPanel.list then
        return
    end
    
    local childCount = trackerMiniWindow.contentsPanel.list:getChildCount()
    
    for i = 1, childCount do
        local child = trackerMiniWindow.contentsPanel.list:getChildByIndex(i)
        local questId = child.questId
        local missionId = child.missionId
        local widgetId = child:getId()
        local description = child.description:getText()
    end
end

local function destroyWindows(windows)
    if type(windows) == "table" then
        for _, window in pairs(windows) do
            if window and not window:isDestroyed() then
                window:destroy()
            end
        end
    else
        if windows and not windows:isDestroyed() then
            windows:destroy()
        end
    end
    return nil
end

local function resetItemCategorySelection(list)
    for _, child in pairs(list:getChildren()) do
        child:setChecked(false)
        child:setBackgroundColor(child.BaseColor)
        if child.iconShow then
            child.iconShow:setVisible(child.isHiddenQuestLog)
        end
        if child.iconPin then
            child.iconPin:setVisible(child.isPinned)
        end
    end
end

local function createQuestItem(parent, id, text, color, icon)
    local item = g_ui.createWidget("QuestLogLabel", parent)
    item:setId(id)
    item:setText(text)
    item:setBackgroundColor(color)
    item:setPhantom(false)
    item:setFocusable(true)
    item.BaseColor = color
    item.isPinned = false
    item.isComplete = false
    if icon then
        item:setIcon(icon)
    end
    if parent == UITextList.questLogList then
        table.insert(questLogCache.items, item)
        if icon ~= "" then
            item.isComplete = true
            questLogCache.completed = questLogCache.completed + 1
        end
    end
    return item
end

local function updateQuestCounter()
    UIlabel.numberQuestComplete:setText(questLogCache.completed)
    UIlabel.numberQuestHidden:setText(questLogCache.hidden)
end

local function recolorVisibleItems()
    local categoryColor = COLORS.BASE_1
    local visibleIndex = 0

    for _, item in pairs(questLogCache.items) do
        if item:isVisible() then
            visibleIndex = visibleIndex + 1
            item:setBackgroundColor(visibleIndex % 2 == 1 and COLORS.BASE_1 or COLORS.BASE_2)
            item.BaseColor = item:getBackgroundColor()
        end
    end
end

local function sortQuestList(questList, sortOrder)
    questLogController.currentSortOrder = sortOrder
    local pinnedItems = {}
    local regularItems = {}
    for _, child in pairs(questLogCache.items) do
        if child.isPinned then
            table.insert(pinnedItems, child)
        else
            table.insert(regularItems, child)
        end
    end
    local sortFunc = sortFunctions[sortOrder]
    if sortFunc then
        table.sort(regularItems, sortFunc)
    end
    questLogCache.items = {}
    local index = 1
    for _, item in ipairs(pinnedItems) do
        questList:moveChildToIndex(item, index)
        table.insert(questLogCache.items, item)
        index = index + 1
    end
    for _, item in ipairs(regularItems) do
        questList:moveChildToIndex(item, index)
        table.insert(questLogCache.items, item)
        index = index + 1
    end
    recolorVisibleItems()
    updateQuestCounter()
end


local function setupQuestItemClickHandler(item, isQuestList)
    function item:onClick()
        local list = isQuestList and UITextList.questLogList or UITextList.questLogLine
        resetItemCategorySelection(list)
        self:setChecked(true)
        self:setBackgroundColor(COLORS.SELECTED)
        if isQuestList then
            g_game.requestQuestLine(self:getId())
            self.iconShow:setVisible(true)
            self.iconPin:setVisible(true)
            questLogController.ui.panelQuestLineSelected:setText(self:getText())
        else
            UITextList.questLogInfo:setText(self.description)
            -- Update the tracker checkbox state for the selected mission (but not during navigation)
            if not isNavigating then
                local playerName = namePlayer or g_game.getCharacterName():lower()
                local missionId = tonumber(self:getId())
                
                -- Simple check: is this specific mission ID in our tracked list?
                local isThisMissionTracked = false
                if settings[playerName] and settings[playerName] then
                    for _, entry in ipairs(settings[playerName]) do
                        if entry[1] == missionId then
                            isThisMissionTracked = true
                            break
                        end
                    end
                end
                
                -- Set checkbox state WITHOUT triggering events
                isUpdatingCheckbox = true
                UICheckBox.showInQuestTracker:setChecked(isThisMissionTracked)
                isUpdatingCheckbox = false
            else
                -- Skipping checkbox update during navigation
            end
        end
    end

    if isQuestList then
        function item.iconPin:onClick(mousePos)
            local parent = self:getParent()
            parent.isPinned = not parent.isPinned
            if parent.isPinned then
                self:setImageColor("#00ff00")
                local list = UITextList.questLogList
                list:removeChild(parent)
                list:insertChild(1, parent)

                table.removevalue(questLogCache.items, parent)
                table.insert(questLogCache.items, 1, parent)
                recolorVisibleItems()
            else
                self:setImageColor("#ffffff")
                self:setVisible(false)
                sortQuestList(UITextList.questLogList, questLogController.currentSortOrder or "Alphabetically (A-Z)")
            end
            return true
        end

        function item.iconShow:onClick(mousePos, mouseButton)
            local parent = self:getParent()
            parent.isHiddenQuestLog = not parent.isHiddenQuestLog
            if parent.isHiddenQuestLog then
                questLogCache.hidden = questLogCache.hidden + 1
                self:setImageColor("#ff0000")
                if not UICheckBox.showShidden:isChecked() then
                    parent:setVisible(false)
                    questLogCache.visible = questLogCache.visible - 1
                end
            else
                questLogCache.hidden = questLogCache.hidden - 1
                self:setImageColor("#ffffff")
                if UICheckBox.showShidden:isChecked() then
                    parent:setVisible(false)
                    questLogCache.visible = questLogCache.visible - 1
                else
                    local isCompleted = parent.isComplete
                    local shouldBeVisible = UICheckBox.showComplete:isChecked() or not isCompleted
                    parent:setVisible(shouldBeVisible)
                    if shouldBeVisible then
                        questLogCache.visible = questLogCache.visible + 1
                    end
                end
            end

            if parent.iconShow then
                parent.iconShow:setVisible(parent.isHiddenQuestLog)
            end
            if parent.iconPin then
                parent.iconPin:setVisible(parent.isPinned)
            end

            updateQuestCounter()
            recolorVisibleItems()
            return true
        end
    end
end

--[[=================================================
=                        Windows                     =
=================================================== ]] --
local function hide()
    if not questLogController.ui then
        return
    end
    questLogController.ui:hide()
end

function show()
    if not questLogController.ui then
        return
    end
    g_game.requestQuestLog()
    questLogController.ui:show()
    questLogController.ui:raise()
    questLogController.ui:focus()
end

local function toggle()
    if not questLogController.ui then
        return
    end
    if questLogController.ui:isVisible() then
        return hide()
    end
    show()
end

local function toggleTracker()
    if trackerMiniWindow:isOn() then
        trackerMiniWindow:close()
    else
        if not trackerMiniWindow:getParent() then
            local panel = modules.game_interface
                              .findContentPanelAvailable(trackerMiniWindow, trackerMiniWindow:getMinimumHeight())
            if not panel then
                return
            end
            panel:addChild(trackerMiniWindow)
        end
        trackerMiniWindow:open()
    end
end
--[[=================================================
=                        miniWindows                     =
=================================================== ]] --
function onOpenTracker()
    buttonQuestLogTrackerButton:setOn(true)
end

function onCloseTracker()
    buttonQuestLogTrackerButton:setOn(false)
end

local function showQuestTracker()
    if trackerMiniWindow then
        toggleTracker()
        return
    end
    trackerMiniWindow = g_ui.createWidget('QuestLogTracker')
    
    -- Hide all standard miniwindow buttons that we don't want
    local toggleFilterButton = trackerMiniWindow:recursiveGetChildById('toggleFilterButton')
    if toggleFilterButton then
        toggleFilterButton:setVisible(false)
    end
    
    -- Hide the custom menuButton since we'll use the standard contextMenuButton
    local menuButton = trackerMiniWindow:getChildById('menuButton')
    if menuButton then
        menuButton:setVisible(false)
    end
    
    -- Set up the miniwindow title and icon
    local titleWidget = trackerMiniWindow:getChildById('miniwindowTitle')
    if titleWidget then
        titleWidget:setText('Quest Tracker')
    else
        -- Fallback to old method if miniwindowTitle doesn't exist
        trackerMiniWindow:setText('Quest Tracker')
    end
    
    local iconWidget = trackerMiniWindow:getChildById('miniwindowIcon')
    if iconWidget then
        iconWidget:setImageSource('/images/topbuttons/icon-questtracker-widget')
    end
    
    -- Position contextMenuButton where toggleFilterButton was (to the left of minimize button)
    local contextMenuButton = trackerMiniWindow:recursiveGetChildById('contextMenuButton')
    local minimizeButton = trackerMiniWindow:recursiveGetChildById('minimizeButton')
    
    if contextMenuButton and minimizeButton then
        contextMenuButton:setVisible(true)
        contextMenuButton:breakAnchors()
        contextMenuButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
        contextMenuButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
        contextMenuButton:setMarginRight(7)  -- Same margin as toggleFilterButton had
        contextMenuButton:setMarginTop(0)
        contextMenuButton:setSize({width = 12, height = 12})
    end
    
    -- Position newWindowButton to the left of contextMenuButton
    local newWindowButton = trackerMiniWindow:recursiveGetChildById('newWindowButton')
    
    if newWindowButton and contextMenuButton then
        newWindowButton:setVisible(true)
        newWindowButton:breakAnchors()
        newWindowButton:addAnchor(AnchorTop, contextMenuButton:getId(), AnchorTop)
        newWindowButton:addAnchor(AnchorRight, contextMenuButton:getId(), AnchorLeft)
        newWindowButton:setMarginRight(2)  -- Same margin as other buttons
        newWindowButton:setMarginTop(0)
    end
    
    -- Position lockButton to the left of newWindowButton
    local lockButton = trackerMiniWindow:recursiveGetChildById('lockButton')
    
    if lockButton and newWindowButton then
        lockButton:breakAnchors()
        lockButton:addAnchor(AnchorTop, newWindowButton:getId(), AnchorTop)
        lockButton:addAnchor(AnchorRight, newWindowButton:getId(), AnchorLeft)
        lockButton:setMarginRight(2)  -- Same margin as other buttons
        lockButton:setMarginTop(0)
    end

    -- Set up contextMenuButton click handler (moved from menuButton)
    if contextMenuButton then
        contextMenuButton.onClick = function(widget, mousePos)
            local menu = g_ui.createWidget('PopupMenu')
            menu:setGameMenu(true)
            menu:addOption('Remove All quest', function()
                if settings[namePlayer] then
                    -- Store the mission IDs that are being removed for checkbox updates
                    local removedMissionIds = {}
                    for _, entry in ipairs(settings[namePlayer]) do
                        local missionId = entry[1]
                        table.insert(removedMissionIds, missionId)
                    end
                    
                    -- Clear the settings and mapping
                    table.clear(settings[namePlayer])
                    table.clear(missionToQuestMap)  -- Clear the mapping as well
                    sendQuestTracker(settings[namePlayer])
                    
                    -- Clear the tracker display
                    trackerMiniWindow.contentsPanel.list:destroyChildren()
                    
                    -- Update the checkbox in Quest Log window if it's open and a mission is selected
                    if questLogController.ui and questLogController.ui:isVisible() then
                        if UITextList.questLogLine and UITextList.questLogLine:hasChildren() then
                            -- Update checkbox for any currently selected mission
                            if UITextList.questLogLine:getFocusedChild() then
                                local currentMissionId = tonumber(UITextList.questLogLine:getFocusedChild():getId())
                                isUpdatingCheckbox = true
                                UICheckBox.showInQuestTracker:setChecked(false)
                                isUpdatingCheckbox = false
                            end
                            
                            -- Force refresh of checkbox state for all visible missions
                            -- This ensures that when user navigates to other missions, they show correct state
                        end
                    end
                    
                    -- Update layouts
                    trackerMiniWindow.contentsPanel.list:getLayout():enableUpdates()
                    trackerMiniWindow.contentsPanel.list:getLayout():update()
                    -- Save the cleared settings
                    save()
                end
            end)
            menu:addOption('Remove completed quests', function()
                if settings[namePlayer] then
                    -- Store the mission IDs that are being removed for checkbox updates
                    local removedMissionIds = {}
                    local completedMissionIds = {}
                    
                    -- Check for completed missions by looking for "(completed)" in their names/descriptions
                    -- and also check the isComplete property if available
                    for i, entry in ipairs(settings[namePlayer]) do
                        local missionId, missionName, missionDescription, questId = unpack(entry)
                        
                        local isCompleted = false
                        
                        -- Method 1: Check for "(completed)" string in mission name
                        if missionName and string.find(string.lower(missionName), "%(completed%)") then
                            isCompleted = true
                        end
                        
                        -- Method 2: Check for "(completed)" string in mission description
                        if not isCompleted and missionDescription and string.find(string.lower(missionDescription), "%(completed%)") then
                            isCompleted = true
                        end
                        
                        -- Method 3: Check tracker label text for "(completed)"
                        if not isCompleted and trackerMiniWindow and trackerMiniWindow.contentsPanel and trackerMiniWindow.contentsPanel.list then
                            local trackerLabel = trackerMiniWindow.contentsPanel.list:getChildById(tostring(missionId))
                            if trackerLabel and trackerLabel.description then
                                local trackerText = trackerLabel.description:getText()
                                if trackerText and string.find(string.lower(trackerText), "%(completed%)") then
                                    isCompleted = true
                                end
                            end
                        end
                        
                        -- Method 4: Check if we can find the mission in the quest log and check its completion status
                        if not isCompleted and questId and UITextList.questLogList then
                            local questItem = UITextList.questLogList:getChildById(tostring(questId))
                            if questItem then
                                -- Temporarily click the quest to load its missions
                                questItem:onClick()
                                
                                -- Check if mission is loaded and has isComplete property
                                scheduleEvent(function()
                                    if UITextList.questLogLine and UITextList.questLogLine:hasChildren() then
                                        local missionItem = UITextList.questLogLine:getChildById(tostring(missionId))
                                        if missionItem then
                                            -- Check mission text for "(completed)"
                                            local missionText = missionItem:getText()
                                            if missionText and string.find(string.lower(missionText), "%(completed%)") then
                                                table.insert(removedMissionIds, missionId)
                                                table.insert(completedMissionIds, missionId)
                                            elseif missionItem.isComplete then
                                                table.insert(removedMissionIds, missionId)
                                                table.insert(completedMissionIds, missionId)
                                            end
                                        end
                                    end
                                    
                                    -- Process removal after checking all missions
                                    if i == #settings[namePlayer] then
                                        scheduleEvent(function()
                                            processCompletedMissionRemoval()
                                        end, 100)
                                    end
                                end, 50)
                            end
                        end
                        
                        -- If we found completion through methods 1-3, mark for removal immediately
                        if isCompleted then
                            table.insert(removedMissionIds, missionId)
                            table.insert(completedMissionIds, missionId)
                        end
                    end
                    
                    -- If we found completed missions without needing to load quest data, process removal
                    if #removedMissionIds > 0 then
                        scheduleEvent(function()
                            processCompletedMissionRemoval()
                        end, 100)
                    else
                    end
                    
                    -- Function to process the actual removal
                    function processCompletedMissionRemoval()
                        if #removedMissionIds > 0 then
                            -- Remove completed missions from settings
                            for j = #settings[namePlayer], 1, -1 do
                                local checkMissionId = settings[namePlayer][j][1]
                                for _, removedId in ipairs(removedMissionIds) do
                                    if checkMissionId == removedId then
                                        table.remove(settings[namePlayer], j)
                                        break
                                    end
                                end
                            end
                            
                            -- Remove from mission mapping
                            for _, missionId in ipairs(removedMissionIds) do
                                if missionToQuestMap[tonumber(missionId)] then
                                    missionToQuestMap[tonumber(missionId)] = nil
                                end
                            end
                            
                            -- Send updated tracker state to server
                            sendQuestTracker(settings[namePlayer])
                            
                            -- Remove completed missions from tracker display
                            for _, missionId in ipairs(removedMissionIds) do
                                local trackerLabel = trackerMiniWindow.contentsPanel.list:getChildById(tostring(missionId))
                                if trackerLabel then
                                    trackerLabel:destroy()
                                end
                            end
                            
                            -- Update the checkbox in Quest Log window if it's open and a completed mission is selected
                            if questLogController.ui and questLogController.ui:isVisible() then
                                if UITextList.questLogLine and UITextList.questLogLine:hasChildren() then
                                    -- Update checkbox for any currently selected mission if it was a completed one
                                    if UITextList.questLogLine:getFocusedChild() then
                                        local currentMissionId = tonumber(UITextList.questLogLine:getFocusedChild():getId())
                                        for _, removedId in ipairs(removedMissionIds) do
                                            if currentMissionId == removedId then
                                                isUpdatingCheckbox = true
                                                UICheckBox.showInQuestTracker:setChecked(false)
                                                isUpdatingCheckbox = false
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                            
                            -- Update layouts
                            trackerMiniWindow.contentsPanel.list:getLayout():enableUpdates()
                            trackerMiniWindow.contentsPanel.list:getLayout():update()
                            
                            -- Save the updated settings
                            save()
                        end
                    end
                end
            end)
            menu:addSeparator()
            menu:addCheckBox('Automatically track new quests', settings.autoTrackNewQuests or false, function(widget, checked)
                settings.autoTrackNewQuests = checked
                save()
            end)
            menu:addCheckBox('Automatically untrack completed quests', settings.autoUntrackCompleted or false, function(widget, checked)
                settings.autoUntrackCompleted = checked
                save()
                
                -- Start/stop periodic auto-untrack check
                if checked then
                    -- Start periodic check
                    scheduleEvent(function()
                        local function periodicAutoUntrack()
                            autoUntrackCompletedQuests()
                            -- Schedule next check
                            if settings.autoUntrackCompleted then
                                scheduleEvent(periodicAutoUntrack, 30000) -- 30 seconds
                            end
                        end
                        periodicAutoUntrack()
                    end, 1000) -- Start after 1 second
                end
            end)

            menu:display(mousePos)
            return true
        end
    end
    
    -- Set up newWindowButton click handler to open Quest Log window
    if newWindowButton then
        newWindowButton.onClick = function()
            show()
            return true
        end
    end
    
    trackerMiniWindow:setContentMinimumHeight(80)
    trackerMiniWindow:setup()
    
    -- Rebuild tracker from saved settings when first created
    if settings[namePlayer] and #settings[namePlayer] > 0 then
        rebuildTrackerFromSettings()
    end
    
    toggleTracker()
    
    -- Set up periodic auto-untrack check (every 30 seconds)
    if settings.autoUntrackCompleted then
        scheduleEvent(function()
            local function periodicAutoUntrack()
                autoUntrackCompletedQuests()
                -- Schedule next check
                if settings.autoUntrackCompleted then
                    scheduleEvent(periodicAutoUntrack, 30000) -- 30 seconds
                end
            end
            periodicAutoUntrack()
        end, 5000) -- Start after 5 seconds
    end
end

--[[=================================================
=                      onParse                      =
=================================================== ]] --
local function onQuestLog(questList)
    UITextList.questLogList:destroyChildren()

    questLogCache = {
        items = {},
        completed = 0,
        hidden = 0,
        visible = #questList
    }

    local categoryColor = COLORS.BASE_1
    for _, data in pairs(questList) do
        local id, questName, questCompleted = unpack(data)
        if _ == 2 and true then
            questCompleted = false
        end
        local icon = questCompleted and "/game_cyclopedia/images/checkmark-icon" or ""
        local itemCat = createQuestItem(UITextList.questLogList, id, questName, categoryColor, icon)
        setupQuestItemClickHandler(itemCat, true)
        categoryColor = categoryColor == COLORS.BASE_1 and COLORS.BASE_2 or COLORS.BASE_1
    end
    sortQuestList(UITextList.questLogList, "Alphabetically (A-Z)")
    updateQuestCounter()
end

local function onQuestLine(questId, questMissions)
    currentQuestId = questId  -- Store the current quest ID
    UITextList.questLogLine:destroyChildren()
    
    -- Always start with checkbox unchecked when loading a new quest line
    isUpdatingCheckbox = true
    UICheckBox.showInQuestTracker:setChecked(false)
    isUpdatingCheckbox = false
    
    local categoryColor = COLORS.BASE_1
    for _, data in pairs(questMissions) do
        local missionName, missionDescription, missionId = unpack(data)
        local itemCat = createQuestItem(UITextList.questLogLine, missionId, missionName, categoryColor)
        itemCat.description = missionDescription
        setupQuestItemClickHandler(itemCat, false)
        categoryColor = categoryColor == COLORS.BASE_1 and COLORS.BASE_2 or COLORS.BASE_1
        
        -- Auto-track new quests if the setting is enabled
        if settings.autoTrackNewQuests and not isIdInTracker(namePlayer, missionId) then
            -- Check if this mission appears to be new (not completed)
            local isCompleted = missionDescription and (
                string.find(string.lower(missionDescription), "%(completed%)") or
                string.find(string.lower(missionDescription), "complete") and string.find(string.lower(missionDescription), "quest")
            )
            
            if not isCompleted then
                -- Add the mission to tracker
                addUniqueIdQuest(namePlayer, questId, missionId, missionName, missionDescription)
                save()
                
                -- Rebuild tracker to show the new quest
                rebuildTrackerFromSettings()
            end
        end
    end
    
    -- Auto-select the first mission but prevent checkbox updates during this automatic selection
    if UITextList.questLogLine:hasChildren() then
        local firstChild = UITextList.questLogLine:getChildByIndex(1)
        if firstChild then
            -- Set navigation flag to prevent checkbox updates during automatic selection
            isNavigating = true
            firstChild:onClick()  -- This will show the mission description but won't update checkbox
            -- Reset navigation flag after a brief delay
            scheduleEvent(function()
                isNavigating = false
            end, 100)
        end
    end
end

local function onQuestTracker(remainingQuests, missions)
    if not trackerMiniWindow then
        showQuestTracker()
    end
    
    -- Don't clear the tracker if we have locally tracked quests
    -- The server response might not include all our tracked quests
    if not missions or type(missions[1]) ~= "table" then
        -- If server sends empty response, rebuild from our local settings
        if settings[namePlayer] and #settings[namePlayer] > 0 then
            -- Keep existing tracker items that match our local settings
            return
        end
        trackerMiniWindow.contentsPanel.list:destroyChildren()
        return
    end
    
    -- Only update tracker items that are actually in our local tracked list
    for index, mission in ipairs(missions) do
        local questId, missionId, questName, missionName, missionDesc = unpack(mission)
        
        -- Update the mission to quest mapping (always update this)
        missionToQuestMap[tonumber(missionId)] = tonumber(questId)
        
        -- Check if this mission is actually being tracked by the user
        local isTracked = false
        if settings[namePlayer] then
            for _, entry in ipairs(settings[namePlayer]) do
                if entry[1] == tonumber(missionId) then
                    isTracked = true
                    break
                end
            end
        end
        
        if isTracked then
            local trackerLabel = trackerMiniWindow.contentsPanel.list:getChildById(tostring(missionId))
            
            if not trackerLabel then
                -- Create new tracker label if it doesn't exist and is tracked
                trackerLabel = g_ui.createWidget('QuestTrackerLabel', trackerMiniWindow.contentsPanel.list)
                trackerLabel:setId(tostring(missionId))
            else
                -- Updating existing tracker label
            end
            
            -- Store navigation data (always update with server data)
            trackerLabel.questId = questId
            trackerLabel.missionId = missionId
            
            -- Update the description from server data
            trackerLabel.description:setText(missionDesc or missionName)
            
            -- Update our local settings with the full description and questId
            for i, entry in ipairs(settings[namePlayer]) do
                if entry[1] == tonumber(missionId) then
                    -- Update the stored description and questId with server data
                    settings[namePlayer][i] = {tonumber(missionId), missionName, missionDesc or missionName, questId}
                    break
                end
            end
            save() -- Save the updated data
        else
            -- Ignoring non-tracked mission from server
        end
    end
    
    -- Check for completed quests to auto-untrack after processing all missions
    if settings.autoUntrackCompleted then
        scheduleEvent(autoUntrackCompletedQuests, 500) -- Short delay to ensure all updates are processed
    end
end

local function onUpdateQuestTracker(questId, missionId, questName, missionName, missionDesc)
    if not trackerMiniWindow then
        return
    end
    
    local trackerLabel = trackerMiniWindow.contentsPanel.list:getChildById(tostring(missionId))
    if trackerLabel then
        trackerLabel.description:setText(missionDesc or missionName)
        
        -- Ensure navigation data is set
        trackerLabel.questId = questId
        trackerLabel.missionId = missionId
        
        -- Update our local settings with the updated description
        if settings[namePlayer] then
            for i, entry in ipairs(settings[namePlayer]) do
                if entry[1] == tonumber(missionId) then
                    settings[namePlayer][i] = {tonumber(missionId), missionName, missionDesc or missionName, questId}
                    save() -- Save the updated description
                    break
                end
            end
        end
        
        -- Auto-untrack completed quests if the setting is enabled
        if settings.autoUntrackCompleted then
            local isCompleted = missionDesc and (
                string.find(string.lower(missionDesc), "%(completed%)") or
                (string.find(string.lower(missionDesc), "complete") and 
                 (string.find(string.lower(missionDesc), "quest") or string.find(string.lower(missionDesc), "mission")))
            )
            
            if isCompleted then
                -- Remove from settings
                removeNumber(namePlayer, missionId)
                save()
                
                -- Remove from tracker display
                trackerLabel:destroy()
                
                -- Update tracker layout
                trackerMiniWindow.contentsPanel.list:getLayout():update()
            end
        end
    end
end
--[[=================================================
=               onCall otui / html                  =
=================================================== ]] --
function filterQuestList(searchText)
    local showComplete = UICheckBox.showComplete:isChecked()
    local showHidden = UICheckBox.showShidden:isChecked()
    local searchPattern = searchText and string.lower(searchText) or nil
    questLogCache.visible = 0
    for _, child in pairs(questLogCache.items) do
        local isCompleted = child.isComplete
        local isHidden = child.isHiddenQuestLog
        local text = child:getText()
        local visible = true
        if searchPattern and text then
            visible = string.find(string.lower(text), searchPattern) ~= nil
        end
        if not showComplete and isCompleted then
            visible = false
        end
        if showHidden then
            visible = visible and isHidden
        else
            visible = visible and not isHidden
        end
        child:setVisible(visible)
        if visible then
            questLogCache.visible = questLogCache.visible + 1
        end
        if child.iconShow then
            child.iconShow:setVisible(child.isHiddenQuestLog)
        end
    end
    recolorVisibleItems()
end

function questLogController:onCheckChangeQuestTracker(event)
    -- Ignore checkbox changes during navigation or when we're just updating the display
    if isNavigating then
        return
    end
    
    if isUpdatingCheckbox then
        return
    end
    
    -- Make sure we have a player name
    if not namePlayer or namePlayer == "" then
        namePlayer = g_game.getCharacterName():lower()
    end
    
    -- Make sure tracker window exists
    if not trackerMiniWindow then
        showQuestTracker()
        return
    end
    
    -- Make sure we have a selected mission
    if not UITextList.questLogLine:hasChildren() or not UITextList.questLogLine:getFocusedChild() then
        return
    end
    
    local focusedChild = UITextList.questLogLine:getFocusedChild()
    local missionId = tonumber(focusedChild:getId())
    local missionName = focusedChild:getText()
    local missionDescription = focusedChild.description or missionName
    
    -- Make sure we have a valid currentQuestId
    if not currentQuestId or currentQuestId == 0 then
        if UITextList.questLogList and UITextList.questLogList:getFocusedChild() then
            currentQuestId = tonumber(UITextList.questLogList:getFocusedChild():getId())
        end
        
        if not currentQuestId or currentQuestId == 0 then
            return
        end
    end
    
    if event.checked then
        -- User wants to TRACK this mission
        
        -- Update the mission to quest mapping
        missionToQuestMap[missionId] = currentQuestId
        
        -- Ensure tracker window is visible
        if not trackerMiniWindow:isVisible() then
            showQuestTracker()
        end
        
        -- Add to our settings
        addUniqueIdQuest(namePlayer, currentQuestId, missionId, missionName, missionDescription)
        
        -- Add to tracker display (if not already there)
        local existingLabel = trackerMiniWindow.contentsPanel.list:getChildById(tostring(missionId))
        if not existingLabel then
            local trackerLabel = g_ui.createWidget('QuestTrackerLabel', trackerMiniWindow.contentsPanel.list)
            trackerLabel:setId(tostring(missionId))
            trackerLabel.questId = currentQuestId
            trackerLabel.missionId = missionId
            trackerLabel.description:setText(missionDescription)
        else
            -- Update existing label
            existingLabel.questId = currentQuestId
            existingLabel.missionId = missionId
            existingLabel.description:setText(missionDescription)
        end
        
    else
        -- User wants to UNTRACK this mission
        
        -- Remove from our settings
        removeNumber(namePlayer, missionId)
        
        -- Remove from tracker display
        local trackerLabel = trackerMiniWindow.contentsPanel.list:getChildById(tostring(missionId))
        if trackerLabel then
            trackerLabel:destroy()
        end
        
        -- Remove from mapping
        missionToQuestMap[missionId] = nil
    end
    
    -- Send updated tracker state to server and save
    if settings[namePlayer] then
        sendQuestTracker(settings[namePlayer])
    end
    save()
end

function questLogController:onFilterQuestLog(event)
    if sortFunctions[event.text] then
        sortQuestList(UITextList.questLogList, event.text)
    end
end

function questLogController:close()
    hide()
end

function questLogController:toggleMiniWindowsTracker()
    if not trackerMiniWindow then
        showQuestTracker()
        return
    end
    if trackerMiniWindow:isVisible() then
        if buttonQuestLogTrackerButton then
            buttonQuestLogTrackerButton:setOn(false)
        end
        return trackerMiniWindow:hide()
    end
    if buttonQuestLogTrackerButton then
        buttonQuestLogTrackerButton:setOn(true)
    end
    showQuestTracker()
end

function questLogController:filterQuestListShowComplete()
    filterQuestList()
end

function questLogController:filterQuestListShowHidden()
    filterQuestList()
end

function onSearchTextChange(text)
    if text and text:len() > 0 then
        filterQuestList(text)
    else
        filterQuestList()
    end
end

function onQuestLogMousePress(widget, mousePos, mouseButton)
    if mouseButton ~= MouseRightButton then
        return
    end
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption(tr('remove'), function()
        local missionId = widget:getParent():getId()  -- This is actually the missionId, not questId
        removeNumber(namePlayer, missionId)
        if settings[namePlayer] then
            sendQuestTracker(settings[namePlayer])
        end
        widget:getParent():destroy()
        -- Save the settings after removal
        save()
        
        -- Also remove from the mapping
        if missionToQuestMap[tonumber(missionId)] then
            missionToQuestMap[tonumber(missionId)] = nil
        end
        
        -- Update the checkbox in the quest log if that mission is currently selected
        if UITextList.questLogLine:hasChildren() and UITextList.questLogLine:getFocusedChild() then
            local currentId = UITextList.questLogLine:getFocusedChild():getId()
            if tostring(currentId) == tostring(missionId) then
                UICheckBox.showInQuestTracker:setChecked(false)
            end
        end
    end)
    menu:display(mousePos)
    return true
end

function onQuestTrackerDescriptionClick(widget, mousePos, mouseButton)
    if mouseButton == MouseRightButton then
        -- Handle right-click for context menu (same as before)
        return onQuestLogMousePress(widget, mousePos, mouseButton)
    elseif mouseButton == MouseLeftButton then
        -- Handle left-click to open Quest Log and navigate to the quest
        local trackerLabel = widget:getParent()
        local questId = trackerLabel.questId
        local missionId = trackerLabel.missionId
        
        -- Try to get questId from mapping if not available on the label
        if (not questId or questId == 0) and missionId then
            questId = missionToQuestMap[tonumber(missionId)]
            if questId then
                -- Update the label for future use
                trackerLabel.questId = questId
            end
        end
        
        local labelIndex = trackerLabel:getParent():getChildIndex(trackerLabel)
        
        -- Always open the Quest Log window
        show()
        
        if questId and questId ~= 0 and missionId then
            -- We have both quest ID and mission ID - do full navigation
            -- Create a function to check if quest list is populated and navigate
            local function attemptNavigation(attempts)
                attempts = attempts or 0
                if attempts > 20 then  -- Max 2 seconds of attempts
                    return
                end
                
                scheduleEvent(function()
                    if UITextList.questLogList and UITextList.questLogList:getChildCount() > 0 then
                        -- Quest list is populated, try to find our quest
                        
                        local questItem = UITextList.questLogList:getChildById(tostring(questId))
                        if questItem then
                            -- Found the quest, click it to load missions
                            questItem:onClick()
                            
                            -- Now wait for the mission list to be populated
                            local function attemptMissionSelection(missionAttempts)
                                missionAttempts = missionAttempts or 0
                                if missionAttempts > 10 then  -- Max 1 second for mission selection
                                    return
                                end
                                
                                scheduleEvent(function()
                                    if UITextList.questLogLine and UITextList.questLogLine:getChildCount() > 0 then
                                        
                                        local missionItem = UITextList.questLogLine:getChildById(tostring(missionId))
                                        if missionItem then
                                            -- Clear the navigation flag temporarily to allow checkbox update
                                            isNavigating = false
                                            missionItem:onClick()  -- Select the specific mission and update checkbox
                                            
                                            -- Since this mission is from the tracker, ensure checkbox is checked
                                            scheduleEvent(function()
                                                isUpdatingCheckbox = true
                                                UICheckBox.showInQuestTracker:setChecked(true)
                                                isUpdatingCheckbox = false
                                            end, 50)
                                        else
                                            -- Mission not found yet, try again
                                            attemptMissionSelection(missionAttempts + 1)
                                        end
                                    else
                                        -- Mission list not populated yet, try again
                                        attemptMissionSelection(missionAttempts + 1)
                                    end
                                end, 100)
                            end
                            
                            -- Start attempting mission selection
                            attemptMissionSelection()
                        else
                            attemptNavigation(attempts + 1)
                        end
                    else
                        -- Quest list not populated yet, try again
                        attemptNavigation(attempts + 1)
                    end
                end, 100)
            end
            
            -- Start attempting navigation
            attemptNavigation()
        else
            -- Fallback: just open the Quest Log (maybe for old tracked quests without quest ID)
        end
        return true
    end
    return false
end

--[[=================================================
=               Controller                     =
=================================================== ]] --
function questLogController:onInit()
    g_ui.importStyle("styles/game_questlog.otui")
    questLogController:loadHtml('game_questlog.html')
    hide()

    UITextList.questLogList = questLogController.ui.panelQuestLog.areaPanelQuestList.questList
    UITextList.questLogLine = questLogController.ui.panelQuestLineSelected.ScrollAreaQuestList.questList
    UITextList.questLogInfo = questLogController.ui.panelQuestLineSelected.panelQuestInfo.questList
    UITextList.questLogInfo:setBackgroundColor('#363636')

    UITextEdit.search = questLogController.ui.panelQuestLog.textEditSearchQuest
    UIlabel.numberQuestComplete = questLogController:findWidget("#lblCompleteNumber")
    UIlabel.numberQuestHidden = questLogController:findWidget("#lblHiddenNumber")
    UICheckBox.showComplete = questLogController:findWidget("#checkboxShowComplete")
    UICheckBox.showShidden = questLogController:findWidget("#checkboxShowHidden")
    UICheckBox.showInQuestTracker = questLogController.ui.panelQuestLineSelected.checkboxShowInQuestTracker

    questLogController:registerEvents(g_game, {
        onQuestLog = onQuestLog,
        onQuestLine = onQuestLine,
        onQuestTracker = onQuestTracker,
        onUpdateQuestTracker = onUpdateQuestTracker
    })

    questLogButton = modules.game_mainpanel.addToggleButton('questLogButton', tr('Quest Log'),
        '/images/options/button_questlog', function()
            toggle()
        end, false, 1000)
    Keybind.new("Windows", "Show/hide quest Log", "", "")
    Keybind.bind("Windows", "Show/hide quest Log", {{
        type = KEY_DOWN,
        callback = function()
            show()
        end
    }})
end

function questLogController:onTerminate()
    questLogButton, trackerMiniWindow, buttonQuestLogTrackerButton = destroyWindows(
        {questLogButton, trackerMiniWindow, buttonQuestLogTrackerButton})
    Keybind.delete("Windows", "Show/hide quest Log")
end

function questLogController:onGameStart()
    if g_game.getClientVersion() >= 1280 then
        namePlayer = g_game.getCharacterName():lower()
        settings = load() or {}
        
        -- Initialize default auto-tracking settings if they don't exist
        if settings.autoTrackNewQuests == nil then
            settings.autoTrackNewQuests = false
        end
        if settings.autoUntrackCompleted == nil then
            settings.autoUntrackCompleted = false
        end
        
        -- Initialize the player's settings if they don't exist
        if not settings[namePlayer] then
            settings[namePlayer] = {}
        end
        
        if settings[namePlayer] then
            sendQuestTracker(settings[namePlayer])
        end
        if not buttonQuestLogTrackerButton then
            buttonQuestLogTrackerButton = modules.game_mainpanel.addToggleButton("QuestLogTracker",
                tr("Open QuestLog Tracker"), "/images/options/button_questlog_tracker", function()
                    questLogController:toggleMiniWindowsTracker()
                end, false, 1001)
        end
        if trackerMiniWindow then
            trackerMiniWindow:setupOnStart()
            -- Rebuild tracker from saved settings
            rebuildTrackerFromSettings()
        end
    else
        UICheckBox.showInQuestTracker:setVisible(false)
        questLogController.ui.buttonsPanel.trackerButton:setVisible(false)
        if buttonQuestLogTrackerButton then
            buttonQuestLogTrackerButton:destroy()
            buttonQuestLogTrackerButton = nil
        end
    end
end

function questLogController:onGameEnd()
    if g_game.getClientVersion() >= 1280 then
        save()
    end
    hide()
    if trackerMiniWindow then
        trackerMiniWindow:setParent(nil, true)
    end
    -- Clear the mission to quest mapping
    missionToQuestMap = {}
end
