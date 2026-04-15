-- Soulseal modal logic migrated from game_soulseal into TaskBoardController
local soulsealBatchLoadEvent = nil
local cachedSoulsealEntries = {}

local SOULSEAL_BATCH_SIZE = 12
local SOULSEAL_CATEGORY_LABELS = {
    [1] = 'Harmless',
    [2] = 'Trivial',
    [3] = 'Easy',
    [4] = 'Medium',
    [5] = 'Hard',
    [6] = 'Challenging'
}

local function getSoulsealBalanceValue(self)
    local player = g_game.getLocalPlayer()
    return player and (tonumber(player:getResourceBalance(ResourceTypes.SOULSEALS)) or 0) or 0
end

local function isSoulsealDone(value)
    return value == true or (tonumber(value) or 0) == 1
end

local function getSoulsealCategoryLabel(category)
    return SOULSEAL_CATEGORY_LABELS[tonumber(category) or 0] or 'Unknown'
end

local function getSoulsealDisplayData(entry)
    local raceId = tonumber(entry.raceId) or 0
    local raceData = raceId > 0 and g_things.getRaceData(raceId) or nil
    local displayName = entry.name or (raceData and raceData.name) or 'Unknown'
    displayName = tostring(displayName)
    if displayName ~= '' then
        displayName = displayName:capitalize()
    else
        displayName = 'Unknown'
    end
    return raceId, displayName, raceData and raceData.outfit or nil
end

local function getSelectedSoulsealEntry(self)
    local selectedIndex = tonumber(self.soulsealSelectedIndex) or 0
    if selectedIndex <= 0 then
        return nil
    end
    return cachedSoulsealEntries[selectedIndex]
end

function TaskBoardController:cancelSoulsealBatch()
    if soulsealBatchLoadEvent then
        removeEvent(soulsealBatchLoadEvent)
        soulsealBatchLoadEvent = nil
    end
end

function TaskBoardController:syncSoulsealCategorySelect()
    if not self.soulsealModal or not self.soulsealModal.ui then
        return
    end
    local combo = self.soulsealModal.ui:recursiveGetChildById('soulsealCategorySelect')
    if not combo then
        return
    end

    local categoryIndex = tonumber(self.soulsealCategoryIndex) or 1
    local optionText = ({
        [1] = 'All',
        [2] = 'Harmless',
        [3] = 'Trivial',
        [4] = 'Easy',
        [5] = 'Medium',
        [6] = 'Hard',
        [7] = 'Challenging'
    })[categoryIndex]

    if combo.setCurrentOptionByData then
        combo:setCurrentOptionByData(tostring(categoryIndex), true)
    end

    if optionText and combo.setCurrentOption then
        combo:setCurrentOption(optionText, true)
    end
end

function TaskBoardController:showSoulseal()
    if self.soulsealModal then
        self:rebuildSoulsealEntries()
        self:syncSoulsealCategorySelect()
        return
    end

    self.soulsealModal = self:openModal('template/html/modal_soulseal.html')
    self:rebuildSoulsealEntries()
    self:syncSoulsealCategorySelect()
end

function TaskBoardController:resetSoulsealState(clearCachedEntries)
    self.soulsealEntries = {}
    self.soulsealSearchText = ''
    self.soulsealCategoryIndex = 1
    self.soulsealSelectedIndex = 0
    self.soulsealHasSelection = false
    self.soulsealHasEntries = false
    self.soulsealSelectedName = 'No creature selected'
    self.soulsealSelectedRaceId = 0
    self.soulsealSelectedOutfit = nil
    self.soulsealSelectedPoints = '0'
    self.soulsealSelectedDone = false
    self.soulsealSelectedCanFight = false
    self.soulsealSelectedCategoryLabel = ''
    self.soulsealSelectedHint = 'Select a creature from the list.'
    self.soulsealEmptyText = 'No Soulseal creatures available.'

    if clearCachedEntries then
        cachedSoulsealEntries = {}
    end
end

function TaskBoardController:hideSoulseal()
    self:cancelSoulsealBatch()

    if self.soulsealModal then
        self:closeModal(self.soulsealModal)
        self.soulsealModal = nil
    end

    self:resetSoulsealState(false)
end

function TaskBoardController:updateSoulsealSelection()
    local entry = getSelectedSoulsealEntry(self)
    if not entry then
        self.soulsealHasSelection = false
        self.soulsealSelectedName = 'No creature selected'
        self.soulsealSelectedRaceId = 0
        self.soulsealSelectedOutfit = nil
        self.soulsealSelectedPoints = '0'
        self.soulsealSelectedDone = false
        self.soulsealSelectedCanFight = false
        self.soulsealSelectedCategoryLabel = ''
        self.soulsealSelectedHint = 'Select a creature from the list.'
        return
    end

    local raceId, displayName, outfit = getSoulsealDisplayData(entry)
    local points = tonumber(entry.soulsealPoints) or 0
    local done = isSoulsealDone(entry.done)
    local balance = getSoulsealBalanceValue(self)
    local canFight = not done and balance >= points

    self.soulsealHasSelection = true
    self.soulsealSelectedName = displayName
    self.soulsealSelectedRaceId = raceId
    self.soulsealSelectedOutfit = outfit
    self.soulsealSelectedPoints = tostring(points)
    self.soulsealSelectedDone = done
    self.soulsealSelectedCanFight = canFight
    self.soulsealSelectedCategoryLabel = getSoulsealCategoryLabel(entry.category)

    if done then
        self.soulsealSelectedHint = 'Animus Mastery already unlocked for this creature.'
    elseif canFight then
        self.soulsealSelectedHint = 'Battle the chosen creature in the Soul Pit.'
    else
        self.soulsealSelectedHint = 'You do not have enough Soulseals to fight this creature.'
    end
end

function TaskBoardController:refreshSoulsealAffordability()
    local balance = getSoulsealBalanceValue(self)
    for i, entry in ipairs(self.soulsealEntries or {}) do
        local points = tonumber(entry.soulsealPointsValue) or 0
        self.soulsealEntries[i].canFight = (not entry.done) and balance >= points
    end
    self.soulsealEntries = self.soulsealEntries
    self:updateSoulsealSelection()
end

function TaskBoardController:_loadSoulsealBatch(filtered, startIndex)
    local balance = getSoulsealBalanceValue(self)
    local endIndex = math.min(startIndex + SOULSEAL_BATCH_SIZE - 1, #filtered)

    for i = startIndex, endIndex do
        local item = filtered[i]
        local entry = item.entry
        local raceId, displayName, outfit = getSoulsealDisplayData(entry)
        local points = tonumber(entry.soulsealPoints) or 0
        local done = isSoulsealDone(entry.done)

        table.insert(self.soulsealEntries, {
            listIndex = item.index,
            raceId = raceId,
            name = displayName,
            outfit = outfit,
            categoryLabel = getSoulsealCategoryLabel(entry.category),
            soulsealPoints = tostring(points),
            soulsealPointsValue = points,
            done = done,
            canFight = (not done) and balance >= points
        })
    end

    self.soulsealEntries = self.soulsealEntries

    if endIndex < #filtered then
        soulsealBatchLoadEvent = scheduleEvent(function()
            soulsealBatchLoadEvent = nil
            self:_loadSoulsealBatch(filtered, endIndex + 1)
        end, 10)
    else
        self:updateSoulsealSelection()
    end
end

function TaskBoardController:rebuildSoulsealEntries()
    self:cancelSoulsealBatch()

    local searchText = (self.soulsealSearchText or ''):lower()
    local categoryIndex = tonumber(self.soulsealCategoryIndex) or 1
    local filtered = {}
    local hasSelectedEntry = false

    for index, entry in ipairs(cachedSoulsealEntries) do
        local _, displayName = getSoulsealDisplayData(entry)
        local matchSearch = searchText == '' or displayName:lower():find(searchText, 1, true)
        local matchCategory = categoryIndex == 1 or (tonumber(entry.category) or 0) == (categoryIndex - 1)
        if matchSearch and matchCategory then
            table.insert(filtered, {
                index = index,
                name = displayName,
                entry = entry
            })
            if (tonumber(self.soulsealSelectedIndex) or 0) == index then
                hasSelectedEntry = true
            end
        end
    end

    if not hasSelectedEntry then
        self.soulsealSelectedIndex = 0
    end

    table.sort(filtered, function(a, b)
        local doneA = isSoulsealDone(a.entry.done)
        local doneB = isSoulsealDone(b.entry.done)
        if doneA ~= doneB then
            return not doneA
        end
        return a.name:lower() < b.name:lower()
    end)

    self.soulsealEntries = {}
    self.soulsealHasEntries = #filtered > 0

    if #filtered == 0 then
        self.soulsealEmptyText = (#cachedSoulsealEntries == 0) and 'No Soulseal creatures available.' or
                                     'No Soulseal creatures match the current filters.'
        self:updateSoulsealSelection()
        return
    end

    self.soulsealEmptyText = ''
    self:_loadSoulsealBatch(filtered, 1)
end

function TaskBoardController:onSoulsealsData(entries)
    cachedSoulsealEntries = entries or {}
    self.soulsealSearchText = ''
    self.soulsealCategoryIndex = 1
    self.soulsealSelectedIndex = 0

    self:showSoulseal()
end

function TaskBoardController:filterSoulseals(text)
    self.soulsealSearchText = text or ''
    self:rebuildSoulsealEntries()
end

function TaskBoardController:clearSoulsealSearch()
    self.soulsealSearchText = ''
    self:rebuildSoulsealEntries()
end

function TaskBoardController:changeSoulsealCategory(event)
    local categoryIndex = event and (tonumber(event.data) or tonumber(event.value)) or 1
    self.soulsealCategoryIndex = categoryIndex
    self:syncSoulsealCategorySelect()
    self:rebuildSoulsealEntries()
end

function TaskBoardController:selectSoulseal(index)
    self.soulsealSelectedIndex = tonumber(index) or 0
    self:updateSoulsealSelection()
end

function TaskBoardController:fightSoulseal()
    local entry = getSelectedSoulsealEntry(self)
    if not entry then
        return
    end

    local points = tonumber(entry.soulsealPoints) or 0
    local done = isSoulsealDone(entry.done)
    local balance = getSoulsealBalanceValue(self)
    if done or balance < points then
        return
    end

    local _, displayName = getSoulsealDisplayData(entry)
    local raceId = tonumber(entry.raceId) or 0
    local msgBox
    local function yes()
        if msgBox then
            msgBox:destroy()
            msgBox = nil
        end
        g_game.soulsealFightAction(raceId)
        self:hideSoulseal()
    end
    local function no()
        if msgBox then
            msgBox:destroy()
            msgBox = nil
        end
    end

    msgBox = displayGeneralBox(tr('Confirm'),
        tr('Are you sure you want to fight "%s" for %d Soulseal points?', displayName, points), {{
            text = tr('Ok'),
            callback = yes
        }, {
            text = tr('Cancel'),
            callback = no
        }}, yes, no)
end
