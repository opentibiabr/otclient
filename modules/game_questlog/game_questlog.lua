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
local isReceivingQuestTracker = false -- Prevent stale local cache from being sent while applying server tracker data
local questTrackerSettingsLoaded = false
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
local settingsDirectory = "/settings/"

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

local function ensureQuestTrackerState()
    if g_game.getClientVersion() < 1280 then
        return false
    end

    if not namePlayer or namePlayer == "" then
        local characterName = g_game.getCharacterName()
        if not characterName or characterName == "" then
            return false
        end

        namePlayer = characterName:lower()
    end

    if not questTrackerSettingsLoaded then
        settings = load() or {}
        questTrackerSettingsLoaded = true

        g_logger.debug(string.format(
            "[QuestTracker] loaded local cache player=%s missions=%d autoTrack=%s autoUntrack=%s",
            namePlayer,
            settings[namePlayer] and #settings[namePlayer] or 0,
            settings.autoTrackNewQuests == true and "true" or "false",
            settings.autoUntrackCompleted == true and "true" or "false"
        ))
    end

    if settings.autoTrackNewQuests == nil then
        settings.autoTrackNewQuests = false
    end
    if settings.autoUntrackCompleted == nil then
        settings.autoUntrackCompleted = false
    end
    if not settings[namePlayer] then
        settings[namePlayer] = {}
    end

    return true
end

local function save()
    if not namePlayer or namePlayer == "" then
        g_logger.debug("[QuestTracker] skipped local cache save without player name")
        return false
    end

    local status, result = pcall(function()
        return json.encode(settings, 2)
    end)
    if not status then
        g_logger.error("Error while saving quest tracker settings. Data won't be saved. Details: " .. result)
        return false
    end
    if result:len() > 100 * 1024 * 1024 then
        g_logger.error("Something went wrong, quest tracker settings file is above 100MB, won't be saved")
        return false
    end

    if not g_resources.directoryExists(settingsDirectory) then
        g_resources.makeDir(settingsDirectory)
    end
    
    local writeStatus, writeResult = pcall(function()
        return g_resources.writeFileContents(file, result)
    end)
    
    if not writeStatus then
        g_logger.error("Could not save quest tracker settings: " .. tostring(writeResult))
        return false
    end

    if not writeResult then
        g_logger.error("Could not save quest tracker settings: writeFileContents returned false")
        return false
    end

    g_logger.debug(string.format(
        "[QuestTracker] saved local cache player=%s missions=%d autoTrack=%s autoUntrack=%s",
        namePlayer or "",
        namePlayer and settings[namePlayer] and #settings[namePlayer] or 0,
        settings.autoTrackNewQuests == true and "true" or "false",
        settings.autoUntrackCompleted == true and "true" or "false"
    ))

    return true
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
    if not ensureQuestTrackerState() then
        g_logger.debug("[QuestTracker] skipped 0xD0 send before local cache was loaded")
        return
    end

    local missionIds = {}
    local added = {}

    for _, entry in ipairs(listToMap or {}) do
        local missionId = tonumber(entry[1])
        if missionId and not added[missionId] then
            missionIds[#missionIds + 1] = missionId
            added[missionId] = true

            if #missionIds >= 255 then
                break
            end
        end
    end

    local extra = math.random(0, 0xff)

    g_logger.debug(string.format(
        "[QuestTracker] sending 0xD0 payload count=%d autoTrack=%s autoUntrack=%s extra=0x%02X",
        #missionIds,
        settings.autoTrackNewQuests == true and "true" or "false",
        settings.autoUntrackCompleted == true and "true" or "false",
        extra
    ))

    g_game.sendRequestTrackerQuestLog(
        missionIds,
        settings.autoTrackNewQuests == true,
        settings.autoUntrackCompleted == true,
        extra
    )
end

local function rebuildTrackerFromSettings()
    if not trackerMiniWindow or not settings[namePlayer] then
        return
    end
    
    trackerMiniWindow.contentsPanel.list:destroyChildren()
    
    for i, entry in ipairs(settings[namePlayer]) do
        local missionId, missionName, missionDescription, questId = unpack(entry)
        
        if not questId or questId == 0 then
            questId = missionToQuestMap[tonumber(missionId)] or 0
        end
        
        local trackerLabel = g_ui.createWidget('QuestTrackerLabel', trackerMiniWindow.contentsPanel.list)
        trackerLabel:setId(tostring(missionId))
        trackerLabel.questId = questId
        trackerLabel.missionId = missionId
        trackerLabel.description:setText(missionDescription or missionName)
    end
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
    if buttonQuestLogTrackerButton then
        buttonQuestLogTrackerButton:setOn(true)
    end
end

function onCloseTracker()
    if buttonQuestLogTrackerButton then
        buttonQuestLogTrackerButton:setOn(false)
    end
end

local function isCompletedMissionText(text)
    if not text then
        return false
    end

    return string.find(string.lower(text), "%(completed%)") ~= nil
end

local function ensureQuestTrackerButton()
    if buttonQuestLogTrackerButton then
        return
    end

    buttonQuestLogTrackerButton = modules.game_mainpanel.addToggleButton("QuestLogTracker",
        tr("Open QuestLog Tracker"), "/images/options/button_questlog_tracker", function()
            questLogController:toggleMiniWindowsTracker()
        end, false, 1001)
end

local function showQuestTracker()
    ensureQuestTrackerButton()

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
                    save()
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
                end
            end)
            menu:addOption('Remove completed quests', function()
                if not settings[namePlayer] then
                    return
                end

                local removedMissionIds = {}

                for i = #settings[namePlayer], 1, -1 do
                    local missionId, missionName, missionDescription = unpack(settings[namePlayer][i])
                    local trackerLabel = trackerMiniWindow.contentsPanel.list:getChildById(tostring(missionId))
                    local trackerText = trackerLabel and trackerLabel.description and trackerLabel.description:getText() or nil

                    if isCompletedMissionText(missionName) or isCompletedMissionText(missionDescription) or isCompletedMissionText(trackerText) then
                        removedMissionIds[#removedMissionIds + 1] = missionId
                        table.remove(settings[namePlayer], i)
                        missionToQuestMap[tonumber(missionId)] = nil

                        if trackerLabel then
                            trackerLabel:destroy()
                        end
                    end
                end

                if #removedMissionIds == 0 then
                    return
                end

                if questLogController.ui and questLogController.ui:isVisible() and UITextList.questLogLine and UITextList.questLogLine:hasChildren() then
                    local focusedChild = UITextList.questLogLine:getFocusedChild()
                    if focusedChild then
                        local currentMissionId = tonumber(focusedChild:getId())
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

                trackerMiniWindow.contentsPanel.list:getLayout():enableUpdates()
                trackerMiniWindow.contentsPanel.list:getLayout():update()

                save()
                sendQuestTracker(settings[namePlayer])
            end)
            menu:addSeparator()
            menu:addCheckBox('Automatically track new quests', settings.autoTrackNewQuests or false, function(widget, checked)
                settings.autoTrackNewQuests = checked
                save()
                sendQuestTracker(settings[namePlayer] or {})
            end)
            menu:addCheckBox('Automatically untrack completed quests', settings.autoUntrackCompleted or false, function(widget, checked)
                settings.autoUntrackCompleted = checked
                save()
                sendQuestTracker(settings[namePlayer] or {})
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
    if not isReceivingQuestTracker and settings[namePlayer] and #settings[namePlayer] > 0 then
        rebuildTrackerFromSettings()
    end
    
    toggleTracker()

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
    if not ensureQuestTrackerState() then
        return
    end

    if not trackerMiniWindow then
        isReceivingQuestTracker = true
        showQuestTracker()
        isReceivingQuestTracker = false
    end

    trackerMiniWindow.contentsPanel.list:destroyChildren()
    table.clear(settings[namePlayer])
    table.clear(missionToQuestMap)

    if not missions then
        save()
        return
    end

    for _, mission in ipairs(missions) do
        local questId, missionId, questName, missionName, missionDesc = unpack(mission)
        questId = tonumber(questId) or 0
        missionId = tonumber(missionId)

        if missionId then
            missionToQuestMap[missionId] = questId
            settings[namePlayer][#settings[namePlayer] + 1] = {missionId, missionName, missionDesc or missionName, questId}

            local trackerLabel = g_ui.createWidget('QuestTrackerLabel', trackerMiniWindow.contentsPanel.list)
            trackerLabel:setId(tostring(missionId))
            trackerLabel.questId = questId
            trackerLabel.missionId = missionId
            trackerLabel.description:setText(missionDesc or missionName)
        end
    end

    save()
end

local function onUpdateQuestTracker(questId, missionId, questName, missionName, missionDesc)
    if not ensureQuestTrackerState() then
        return
    end

    if not trackerMiniWindow then
        isReceivingQuestTracker = true
        showQuestTracker()
        isReceivingQuestTracker = false
    end

    questId = tonumber(questId) or 0
    missionId = tonumber(missionId)
    if not missionId then
        return
    end

    missionToQuestMap[missionId] = questId

    local trackerLabel = trackerMiniWindow.contentsPanel.list:getChildById(tostring(missionId))
    if not trackerLabel then
        trackerLabel = g_ui.createWidget('QuestTrackerLabel', trackerMiniWindow.contentsPanel.list)
        trackerLabel:setId(tostring(missionId))
    end

    trackerLabel.questId = questId
    trackerLabel.missionId = missionId
    trackerLabel.description:setText(missionDesc or missionName)

    local updated = false
    for i, entry in ipairs(settings[namePlayer]) do
        if entry[1] == missionId then
            settings[namePlayer][i] = {missionId, missionName, missionDesc or missionName, questId}
            updated = true
            break
        end
    end

    if not updated then
        settings[namePlayer][#settings[namePlayer] + 1] = {missionId, missionName, missionDesc or missionName, questId}
    end

    save()
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

    if not ensureQuestTrackerState() then
        return
    end
    
    -- Make sure tracker window exists
    if not trackerMiniWindow then
        showQuestTracker()
        if not trackerMiniWindow then
            return
        end
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
    save()
    if settings[namePlayer] then
        sendQuestTracker(settings[namePlayer])
    end
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
        save()
        if settings[namePlayer] then
            sendQuestTracker(settings[namePlayer])
        end
        widget:getParent():destroy()
        
        -- Also remove from the mapping
        if missionToQuestMap[tonumber(missionId)] then
            missionToQuestMap[tonumber(missionId)] = nil
        end
        
        -- Update the checkbox in the quest log if that mission is currently selected
        if UITextList.questLogLine:hasChildren() and UITextList.questLogLine:getFocusedChild() then
            local currentId = UITextList.questLogLine:getFocusedChild():getId()
            if tostring(currentId) == tostring(missionId) then
                isUpdatingCheckbox = true
                UICheckBox.showInQuestTracker:setChecked(false)
                isUpdatingCheckbox = false
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
        if not ensureQuestTrackerState() then
            return
        end

        ensureQuestTrackerButton()

        if trackerMiniWindow then
            trackerMiniWindow:setupOnStart()
            -- Rebuild tracker from saved settings
            rebuildTrackerFromSettings()
        end

        -- Send local tracker cache on login, matching the official client behavior.
        -- The server reconciles this payload during the initial sync window.
        sendQuestTracker(settings[namePlayer])
    else
        UICheckBox.showInQuestTracker:setVisible(false)
        questLogController.ui.buttonsPanel.trackerButton:setVisible(false)
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
    questTrackerSettingsLoaded = false
    namePlayer = ""
end
