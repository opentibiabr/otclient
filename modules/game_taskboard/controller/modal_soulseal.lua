-- Soulseal modal logic migrated from game_soulseal into TaskBoardController
local cachedSoulsealEntries = {}
local filteredSoulsealEntries = {}
local soulsealBindRetryEvent = nil

local SOULSEAL_ROW_HEIGHT_PX = 38
local SOULSEAL_VIEWPORT_HEIGHT_PX = 200
local SOULSEAL_OVERSCAN_ROWS = 2
local SOULSEAL_BIND_RETRY_DELAY_MS = 25
local SOULSEAL_BIND_MAX_RETRIES = 20
local SOULSEAL_SPACER_SEGMENT_PX = 20000
local SOULSEAL_CATEGORY_LABELS = {
    [1] = 'Harmless',
    [2] = 'Trivial',
    [3] = 'Easy',
    [4] = 'Medium',
    [5] = 'Hard',
    [6] = 'Challenging'
}
local SOULSEAL_CATEGORY_FILTER_INDEX = {
    all = 1,
    harmless = 2,
    trivial = 3,
    easy = 4,
    medium = 5,
    hard = 6,
    challenging = 7
}

local function splitSoulsealSpacerPx(totalPx)
    local px = math.max(0, tonumber(totalPx) or 0)
    local a = math.min(px, SOULSEAL_SPACER_SEGMENT_PX)
    px = px - a
    local b = math.min(px, SOULSEAL_SPACER_SEGMENT_PX)
    local c = px - b
    return a, b, c
end

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

local function getSoulsealCategoryFilterIndex(event)
    if not event then
        return 1
    end

    local index = tonumber(event.data) or tonumber(event.value)
    if index then
        return index
    end

    local text = event.text or event.value
    if text then
        return SOULSEAL_CATEGORY_FILTER_INDEX[tostring(text):lower()] or 1
    end

    return 1
end

local function getSoulsealCategory(entry)
    if not entry then
        return 0
    end

    if entry.categoryValue ~= nil then
        return tonumber(entry.categoryValue) or 0
    end

    local category = tonumber(entry.category)
    if category ~= nil then
        return category
    end

    local raceId = tonumber(entry.raceId) or 0
    local raceData = raceId > 0 and g_things.getRaceData(raceId) or nil
    if raceData and raceData.hasCategory then
        return tonumber(raceData.category) or 0
    end

    return 0
end

local function getSoulsealDisplayData(entry)
    if entry.displayName then
        return tonumber(entry.raceId) or 0, entry.displayName, entry.outfit
    end

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

local function normalizeSoulsealEntry(entry)
    entry = entry or {}

    local raceId = tonumber(entry.raceId) or 0
    local raceData = nil
    if raceId > 0 and (not entry.outfit or entry.name == nil or entry.category == nil) then
        raceData = g_things.getRaceData(raceId)
    end

    local name = entry.name or (raceData and raceData.name) or (raceId > 0 and tostring(raceId) or 'Unknown')
    name = tostring(name)
    if name ~= '' then
        name = name:capitalize()
    else
        name = 'Unknown'
    end

    local category = tonumber(entry.category)
    if category == nil and raceData and raceData.hasCategory then
        category = tonumber(raceData.category) or 0
    end
    category = category or 0

    local points = tonumber(entry.soulsealPoints) or 0
    local done = isSoulsealDone(entry.done)
    local sortName = name:lower()

    return {
        raceId = raceId,
        name = name,
        displayName = name,
        outfit = entry.outfit or (raceData and raceData.outfit or nil),
        category = category,
        categoryValue = category,
        categoryLabel = getSoulsealCategoryLabel(category),
        soulsealPoints = tostring(points),
        soulsealPointsValue = points,
        done = done,
        searchName = sortName,
        sortName = sortName
    }
end

local function normalizeSoulsealEntries(entries)
    local normalized = {}
    for _, entry in ipairs(entries or {}) do
        normalized[#normalized + 1] = normalizeSoulsealEntry(entry)
    end
    return normalized
end

local function getSelectedSoulsealEntry(self)
    local selectedIndex = tonumber(self.soulsealSelectedIndex) or 0
    if selectedIndex <= 0 then
        return nil
    end
    return cachedSoulsealEntries[selectedIndex]
end

function TaskBoardController:cancelSoulsealBatch()
    if soulsealBindRetryEvent then
        removeEvent(soulsealBindRetryEvent)
        soulsealBindRetryEvent = nil
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

function TaskBoardController:getSoulsealScrollWidget()
    if not self.soulsealModal or not self.soulsealModal.ui then
        return nil
    end
    return self.soulsealModal.ui:querySelector("#soulsealListScroll")
end

function TaskBoardController:onSoulsealScrollChange(widget, virtualOffset)
    if self._soulsealApplyingScrollSnap then
        return
    end
    self:refreshSoulsealViewport((virtualOffset and virtualOffset.y) or 0)
end

function TaskBoardController:bindSoulsealScroll()
    local scrollWidget = self:getSoulsealScrollWidget()
    if not scrollWidget then
        return
    end
    if scrollWidget._soulsealVirtualized then
        return
    end

    scrollWidget._soulsealVirtualized = true
    scrollWidget._skipScrollLayoutRecalc = true
    scrollWidget._soulsealOriginalUpdateScrollBars = scrollWidget.updateScrollBars
    scrollWidget.updateScrollBars = function()
    end
    scrollWidget:setAutoFocusPolicy(AutoFocusNone)

    scrollWidget.onScrollChange = function(widget, virtualOffset)
        self:onSoulsealScrollChange(widget, virtualOffset)
    end

    if scrollWidget.verticalScrollBar then
        local sb = scrollWidget.verticalScrollBar
        sb:setStep(SOULSEAL_ROW_HEIGHT_PX)
    end
end

function TaskBoardController:ensureSoulsealScrollBound(retryCount)
    local scrollWidget = self:getSoulsealScrollWidget()
    if scrollWidget and scrollWidget.verticalScrollBar then
        self:bindSoulsealScroll()
        self:refreshSoulsealViewport(tonumber(scrollWidget.verticalScrollBar:getValue()) or 0)
        return true
    end

    retryCount = tonumber(retryCount) or 0
    if retryCount >= SOULSEAL_BIND_MAX_RETRIES then
        g_logger.warning('[taskboard/soulseal] failed to bind soulseal scroll: vertical scrollbar not ready')
        return false
    end

    if soulsealBindRetryEvent then
        removeEvent(soulsealBindRetryEvent)
        soulsealBindRetryEvent = nil
    end

    soulsealBindRetryEvent = scheduleEvent(function()
        soulsealBindRetryEvent = nil
        if self.soulsealModal then
            self:ensureSoulsealScrollBound(retryCount + 1)
        end
    end, SOULSEAL_BIND_RETRY_DELAY_MS)

    return false
end

function TaskBoardController:updateSoulsealScrollRange(totalRows, viewportHeight, rowHeight)
    local scrollWidget = self:getSoulsealScrollWidget()
    rowHeight = math.max(1, math.floor((tonumber(rowHeight) or SOULSEAL_ROW_HEIGHT_PX) + 0.5))
    local visibleRows = math.max(1, math.floor(viewportHeight / rowHeight))
    local maxScroll = math.max((math.max(1, totalRows - visibleRows + 1) - 1) * rowHeight, 0)

    if scrollWidget and scrollWidget.verticalScrollBar then
        local sb = scrollWidget.verticalScrollBar
        sb:setMinimum(0)
        sb:setMaximum(maxScroll)
        sb:setStep(rowHeight)

        if (tonumber(sb:getValue()) or 0) > maxScroll then
            self._soulsealApplyingScrollSnap = true
            sb:setValue(maxScroll)
            self._soulsealApplyingScrollSnap = false
        end
    end

    return maxScroll, visibleRows
end

function TaskBoardController:resetSoulsealScroll()
    local scrollWidget = self:getSoulsealScrollWidget()
    if not scrollWidget or not scrollWidget.verticalScrollBar then
        self:ensureSoulsealScrollBound()
        scrollWidget = self:getSoulsealScrollWidget()
    end

    if scrollWidget and scrollWidget.verticalScrollBar then
        self._soulsealApplyingScrollSnap = true
        scrollWidget.verticalScrollBar:setValue(0)
        self._soulsealApplyingScrollSnap = false
    elseif scrollWidget then
        scrollWidget:setVirtualOffset({
            x = 0,
            y = 0
        })
    end

    self:refreshSoulsealViewport(0)
end

function TaskBoardController:refreshSoulsealViewport(scrollValue)
    if self._soulsealViewportRefreshing then
        return
    end
    self._soulsealViewportRefreshing = true

    local list = filteredSoulsealEntries
    local total = #list
    local rowHeight = SOULSEAL_ROW_HEIGHT_PX
    local viewportHeight = SOULSEAL_VIEWPORT_HEIGHT_PX
    local scrollWidget = self:getSoulsealScrollWidget()
    if scrollWidget and scrollWidget.getPaddingRect then
        local paddingRect = scrollWidget:getPaddingRect()
        if paddingRect and paddingRect.height and paddingRect.height > 0 then
            viewportHeight = paddingRect.height
        end
    end

    if total == 0 then
        local visible = self.soulsealEntries or {}
        table.clear(visible)
        self.soulsealEntries = visible
        self.soulsealTopSpacerPxA, self.soulsealTopSpacerPxB, self.soulsealTopSpacerPxC = 0, 0, 0
        self.soulsealBottomSpacerPxA, self.soulsealBottomSpacerPxB, self.soulsealBottomSpacerPxC = 0, 0, 0
        self._soulsealViewportStart = 0
        self._soulsealViewportEnd = 0
        self:updateSoulsealScrollRange(0, viewportHeight, rowHeight)
        self._soulsealViewportRefreshing = false
        return
    end

    local y = tonumber(scrollValue) or 0
    local maxScroll, visibleRows = self:updateSoulsealScrollRange(total, viewportHeight, rowHeight)
    y = math.max(0, math.min(y, maxScroll))

    local snappedY = math.min(math.floor(y / rowHeight) * rowHeight, maxScroll)
    if scrollWidget and scrollWidget.verticalScrollBar and not self._soulsealApplyingScrollSnap then
        local currentY = scrollWidget.verticalScrollBar:getValue()
        if currentY ~= snappedY then
            self._soulsealApplyingScrollSnap = true
            scrollWidget.verticalScrollBar:setValue(snappedY)
            self._soulsealApplyingScrollSnap = false
            y = snappedY
        else
            y = currentY
        end
    end

    local firstVisibleIndex = math.min(math.floor(y / rowHeight) + 1, math.max(1, total - visibleRows + 1))
    local startIndex = math.max(1, firstVisibleIndex - SOULSEAL_OVERSCAN_ROWS)
    local endIndex = math.min(total, firstVisibleIndex + visibleRows + SOULSEAL_OVERSCAN_ROWS - 1)

    if self._soulsealViewportStart == startIndex and self._soulsealViewportEnd == endIndex then
        self._soulsealViewportRefreshing = false
        return
    end

    local visible = self.soulsealEntries or {}
    table.clear(visible)
    for i = startIndex, endIndex do
        visible[#visible + 1] = list[i]
    end

    self.soulsealEntries = visible
    self.soulsealTopSpacerPxA, self.soulsealTopSpacerPxB, self.soulsealTopSpacerPxC =
        splitSoulsealSpacerPx((startIndex - 1) * rowHeight)
    self.soulsealBottomSpacerPxA, self.soulsealBottomSpacerPxB, self.soulsealBottomSpacerPxC = splitSoulsealSpacerPx(
        (total - endIndex) * rowHeight)
    self._soulsealViewportStart = startIndex
    self._soulsealViewportEnd = endIndex
    self._soulsealViewportRefreshing = false
end

function TaskBoardController:showSoulseal()
    if self.soulsealModal then
        self:rebuildSoulsealEntries()
        self:syncSoulsealCategorySelect()
        return
    end

    self.soulsealModal = self:openModal('template/html/modal_soulseal.html', {
        mode = 'html'
    })
    self:rebuildSoulsealEntries()
    self:syncSoulsealCategorySelect()
end

function TaskBoardController:resetSoulsealState(clearCachedEntries)
    self.soulsealEntries = {}
    filteredSoulsealEntries = {}
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
    self.soulsealTopSpacerPxA = 0
    self.soulsealTopSpacerPxB = 0
    self.soulsealTopSpacerPxC = 0
    self.soulsealBottomSpacerPxA = 0
    self.soulsealBottomSpacerPxB = 0
    self.soulsealBottomSpacerPxC = 0
    self._soulsealViewportStart = 0
    self._soulsealViewportEnd = 0
    self._soulsealViewportRefreshing = false
    self._soulsealApplyingScrollSnap = false

    if clearCachedEntries then
        cachedSoulsealEntries = {}
    end
end

function TaskBoardController:hideSoulseal()
    self:cancelSoulsealBatch()

    local scrollWidget = self:getSoulsealScrollWidget()
    if scrollWidget and scrollWidget.verticalScrollBar then
        local sb = scrollWidget.verticalScrollBar
        if sb._soulsealValueHook then
            disconnect(sb, 'onValueChange', sb._soulsealValueHook)
            sb._soulsealValueHook = nil
        end
    end

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
    local points = tonumber(entry.soulsealPointsValue) or tonumber(entry.soulsealPoints) or 0
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
    self.soulsealSelectedCategoryLabel = getSoulsealCategoryLabel(getSoulsealCategory(entry))

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
    for i, entry in ipairs(filteredSoulsealEntries) do
        local points = tonumber(entry.soulsealPointsValue) or 0
        filteredSoulsealEntries[i].canFight = (not entry.done) and balance >= points
    end
    self:updateSoulsealSelection()
end

function TaskBoardController:buildSoulsealDisplayEntries(filtered)
    local balance = getSoulsealBalanceValue(self)

    table.clear(filteredSoulsealEntries)
    for i = 1, #filtered do
        local item = filtered[i]
        local entry = item.entry
        local points = tonumber(entry.soulsealPointsValue) or tonumber(entry.soulsealPoints) or 0
        local done = isSoulsealDone(entry.done)

        filteredSoulsealEntries[#filteredSoulsealEntries + 1] = {
            listIndex = item.index,
            raceId = tonumber(entry.raceId) or 0,
            name = entry.displayName or entry.name,
            outfit = entry.outfit,
            categoryLabel = entry.categoryLabel or getSoulsealCategoryLabel(getSoulsealCategory(entry)),
            soulsealPoints = entry.soulsealPoints or tostring(points),
            soulsealPointsValue = points,
            done = done,
            canFight = (not done) and balance >= points
        }
    end
end

function TaskBoardController:rebuildSoulsealEntries()
    self:cancelSoulsealBatch()

    local searchText = (self.soulsealSearchText or ''):lower()
    local categoryIndex = tonumber(self.soulsealCategoryIndex) or 1
    local filtered = {}
    local hasSelectedEntry = false

    for index, entry in ipairs(cachedSoulsealEntries) do
        local searchName = entry.searchName
        if not searchName then
            local _, displayName = getSoulsealDisplayData(entry)
            searchName = displayName:lower()
        end

        local matchSearch = searchText == '' or searchName:find(searchText, 1, true)
        local matchCategory = categoryIndex == 1 or getSoulsealCategory(entry) == (categoryIndex - 1)
        if matchSearch and matchCategory then
            table.insert(filtered, {
                index = index,
                sortName = entry.sortName or searchName,
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
        if a.sortName ~= b.sortName then
            return a.sortName < b.sortName
        end
        return (tonumber(a.entry.raceId) or 0) < (tonumber(b.entry.raceId) or 0)
    end)

    self.soulsealEntries = self.soulsealEntries or {}
    table.clear(self.soulsealEntries)
    self.soulsealHasEntries = #filtered > 0
    self.soulsealTopSpacerPxA, self.soulsealTopSpacerPxB, self.soulsealTopSpacerPxC = 0, 0, 0
    self.soulsealBottomSpacerPxA, self.soulsealBottomSpacerPxB, self.soulsealBottomSpacerPxC = 0, 0, 0
    self._soulsealViewportStart = 0
    self._soulsealViewportEnd = 0

    if #filtered == 0 then
        table.clear(filteredSoulsealEntries)
        self.soulsealEmptyText = (#cachedSoulsealEntries == 0) and 'No Soulseal creatures available.' or
                                     'No Soulseal creatures match the current filters.'
        self:updateSoulsealSelection()
        return
    end

    self.soulsealEmptyText = ''
    self:buildSoulsealDisplayEntries(filtered)
    self:ensureSoulsealScrollBound()
    self:resetSoulsealScroll()
    self:updateSoulsealSelection()
end

function TaskBoardController:onSoulsealsData(entries)
    cachedSoulsealEntries = normalizeSoulsealEntries(entries)
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
    self.soulsealCategoryIndex = getSoulsealCategoryFilterIndex(event)
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

    local points = tonumber(entry.soulsealPointsValue) or tonumber(entry.soulsealPoints) or 0
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
