-- Preferred monsters modal - methods added to TaskBoardController
-- Uses openModal/closeModal to open a secondary HTML window without
-- affecting self.ui which points to taskboard.html
local cachedRemoveCost = 0
local cachedAllRaceIds = {}
local cachedRawSlots = {}

local MONSTER_ROW_HEIGHT_PX = 44
local MONSTER_OVERSCAN_ROWS = 2
local MONSTER_BIND_RETRY_DELAY_MS = 25
local MONSTER_BIND_MAX_RETRIES = 20
local MONSTER_SPACER_SEGMENT_PX = 20000
local MONSTER_ROW_HEIGHT_MIN_PX = 36
local MONSTER_ROW_HEIGHT_MAX_PX = 72

-- Split a large pixel value across three spacer segments (max 20000px each).
-- Needed because OTClient widget heights are capped; three divs simulate tall spacers.
local function splitSpacerPx(totalPx)
    local px = math.max(0, tonumber(totalPx) or 0)
    local a = math.min(px, MONSTER_SPACER_SEGMENT_PX)
    px = px - a
    local b = math.min(px, MONSTER_SPACER_SEGMENT_PX)
    local c = px - b
    return a, b, c
end

local function clampRowHeightPx(value)
    local px = math.floor((tonumber(value) or MONSTER_ROW_HEIGHT_PX) + 0.5)
    return math.max(MONSTER_ROW_HEIGHT_MIN_PX, math.min(MONSTER_ROW_HEIGHT_MAX_PX, px))
end

local function getPreferredUnlockPrice(slotNum, serverPrice)
    local slot = tonumber(slotNum) or 0
    local price = tonumber(serverPrice) or 0
    if price > 0 then
        return price
    end
    return tonumber(PREFERRED_UNLOCK_COST and PREFERRED_UNLOCK_COST[slot]) or 0
end

local function getPreferredActionCost()
    local assignCost = tonumber(PREFERRED_SLOT_ASSIGN_COST) or 0
    if assignCost > 0 then
        return assignCost
    end
    return tonumber(cachedRemoveCost) or 0
end

local function updateCachedSlot(slotNum, key, value)
    local slot = tonumber(slotNum) or 0
    if slot <= 0 then
        return
    end

    for index, slotData in ipairs(cachedRawSlots) do
        if (tonumber(slotData.slot) or index) == slot then
            slotData[key] = value
            break
        end
    end
end

-- Modal open / close
function TaskBoardController:showPreferred()
    if self.preferredModal then return end

    self.preferredModal = self:openModal('template/html/modal_preferred.html')
    addEvent(function()
        if not self.preferredModal or not self.preferredModal.ui then return end
        self:ensurePreferredMonsterScrollBound()
        self:resetPreferredMonsterScroll()
    end)
    g_game.bountyPreferredAction(BOUNTY_PREF_ACTION_REQUEST, 0, 0)
end

function TaskBoardController:hidePreferred()
    if self._preferredBindRetryEvent then
        removeEvent(self._preferredBindRetryEvent)
        self._preferredBindRetryEvent = nil
    end

    local scrollWidget = self:getPreferredMonsterScrollWidget()
    if scrollWidget and scrollWidget.verticalScrollBar then
        local sb = scrollWidget.verticalScrollBar
        if sb._preferredValueHook then
            disconnect(sb, 'onValueChange', sb._preferredValueHook)
            sb._preferredValueHook = nil
        end
    end

    if self.preferredModal then
        self:closeModal(self.preferredModal)
        self.preferredModal = nil
    end

    self.allAvailableMonsters = {}
    self.visibleMonsters = {}
    self.availableMonsters = {}
    self.monsterTopSpacerPxA = 0
    self.monsterTopSpacerPxB = 0
    self.monsterTopSpacerPxC = 0
    self.monsterBottomSpacerPxA = 0
    self.monsterBottomSpacerPxB = 0
    self.monsterBottomSpacerPxC = 0
    self.preferredSlots = {}
    self.selectedRaceId = 0
    self.searchText = ""

    self._preferredViewportStart = 0
    self._preferredViewportEnd = 0
    self._preferredViewportRowHeight = 0
    self._preferredApplyingScrollSnap = false
    self._preferredViewportRefreshing = false
    self._preferredRowHeightPx = MONSTER_ROW_HEIGHT_PX
    self._preferredRowHeightMeasured = false

    cachedRemoveCost = 0
    cachedAllRaceIds = {}
    cachedRawSlots = {}
end

-- Server data
function TaskBoardController:onPreferredServerData(slots, removeCost, availableRaceIds)
    cachedRawSlots = slots or {}
    cachedRemoveCost = tonumber(removeCost) or 0
    cachedAllRaceIds = availableRaceIds or {}

    self:rebuildPreferredSlots()
    self:rebuildAvailableMonsters()
end

-- Slots
function TaskBoardController:rebuildPreferredSlots()
    local result = {}
    local actionCost = getPreferredActionCost()
    local selectedRaceId = tonumber(self.selectedRaceId) or 0
    local player = g_game.getLocalPlayer()
    local balance = player and player:getResourceBalance(ResourceTypes.BOUNTY_POINTS) or 0

    for index, slotData in ipairs(cachedRawSlots) do
        local slotNum = tonumber(slotData.slot) or index
        local unlocked = index == 1 or tonumber(slotData.locked) ~= 1
        local preferredId = tonumber(slotData.preferred) or 0
        local unwantedId = tonumber(slotData.unwanted) or 0
        local lockPrice = getPreferredUnlockPrice(slotNum, slotData.price)

        local prefName, prefOutfit, unwName, unwOutfit
        if preferredId > 0 then
            local rd = g_things.getRaceData(preferredId)
            prefName = rd and rd.name and rd.name:capitalize() or 'Unknown'
            prefOutfit = rd and rd.outfit or nil
        else
            prefName = 'Empty'
        end
        if unwantedId > 0 then
            local rd = g_things.getRaceData(unwantedId)
            unwName = rd and rd.name and rd.name:capitalize() or 'Unknown'
            unwOutfit = rd and rd.outfit or nil
        else
            unwName = 'Empty'
        end

        local hasPreferred = preferredId > 0
        local hasUnwanted = unwantedId > 0
        local canAssign = selectedRaceId ~= 0

        table.insert(result, {
            slotNum = slotNum,
            slotTitle = slotNum == 1 and 'Main Slot' or 'Additional Slots',
            unlocked = unlocked and 1 or 0,
            locked = unlocked and 0 or 1,
            lockPrice = lockPrice,
            canUnlock = lockPrice > 0 and balance >= lockPrice,
            preferredId = preferredId,
            preferredName = prefName,
            preferredOutfit = prefOutfit,
            showPreferredCreature = hasPreferred and 1 or 0,
            showPreferredPlaceholder = hasPreferred and 0 or 1,
            showPreferredAssign = hasPreferred and 0 or 1,
            showPreferredClear = hasPreferred and 1 or 0,
            unwantedId = unwantedId,
            unwantedName = unwName,
            unwantedOutfit = unwOutfit,
            showUnwantedCreature = hasUnwanted and 1 or 0,
            showUnwantedPlaceholder = hasUnwanted and 0 or 1,
            showUnwantedAssign = hasUnwanted and 0 or 1,
            showUnwantedClear = hasUnwanted and 1 or 0,
            actionCost = actionCost,
            preferredButtonText = hasPreferred and 'Clear' or 'Assign',
            unwantedButtonText = hasUnwanted and 'Clear' or 'Assign',
            preferredAction = hasPreferred and 'clearPreferred' or 'assignPreferred',
            unwantedAction = hasUnwanted and 'clearUnwanted' or 'assignUnwanted',
            canPreferredAct = hasPreferred or canAssign,
            canUnwantedAct = hasUnwanted or canAssign,
            clearCost = actionCost,
            canClear = balance >= actionCost
        })
    end
    self.preferredSlots = result
end

-- Monster list
function TaskBoardController:getPreferredMonsterScrollWidget()
    if not self.preferredModal or not self.preferredModal.ui then return nil end
    return self.preferredModal.ui:querySelector("#monsterListScroll")
end

function TaskBoardController:bindPreferredMonsterScroll()
    local scrollWidget = self:getPreferredMonsterScrollWidget()
    if not scrollWidget then return end
    if scrollWidget._preferredVirtualized then return end

    scrollWidget._preferredVirtualized = true
    scrollWidget._skipScrollLayoutRecalc = true
    scrollWidget._preferredOriginalUpdateScrollBars = scrollWidget.updateScrollBars
    scrollWidget.updateScrollBars = function() end

    -- Without AutoFocusNone, OTClient calls focusPreviousChild() automatically when a
    -- focused row widget is destroyed during virtual-scroll re-renders (uiwidget.cpp
    -- removeChild), shifting focus to an adjacent row without any user interaction.
    scrollWidget:setAutoFocusPolicy(AutoFocusNone)

    -- Fallback for when there is no vertical scrollbar (setVirtualOffset path).
    -- When a scrollbar exists, onValueChange below handles all scroll events.
    scrollWidget.onScrollChange = function(widget, virtualOffset)
        if self._preferredApplyingScrollSnap or scrollWidget.verticalScrollBar then return end
        self:refreshMonsterViewport((virtualOffset and virtualOffset.y) or 0)
    end

    if scrollWidget.verticalScrollBar then
        local sb = scrollWidget.verticalScrollBar
        sb:setStep(self:getPreferredMonsterRowHeight(scrollWidget))
        if not sb._preferredValueHook then
            sb._preferredValueHook = function(_, value)
                if self._preferredApplyingScrollSnap then return end
                self:refreshMonsterViewport(value)
            end
            connect(sb, 'onValueChange', sb._preferredValueHook)
        end
    end
end

function TaskBoardController:ensurePreferredMonsterScrollBound(retryCount)
    local scrollWidget = self:getPreferredMonsterScrollWidget()
    if scrollWidget and scrollWidget.verticalScrollBar then
        self:bindPreferredMonsterScroll()
        self:refreshMonsterViewport(tonumber(scrollWidget.verticalScrollBar:getValue()) or 0)
        return true
    end

    retryCount = tonumber(retryCount) or 0
    if retryCount >= MONSTER_BIND_MAX_RETRIES then
        g_logger.warning('[taskboard/preferred] failed to bind monster scroll: vertical scrollbar not ready')
        return false
    end

    if self._preferredBindRetryEvent then
        removeEvent(self._preferredBindRetryEvent)
        self._preferredBindRetryEvent = nil
    end

    self._preferredBindRetryEvent = scheduleEvent(function()
        self._preferredBindRetryEvent = nil
        if self.preferredModal then
            self:ensurePreferredMonsterScrollBound(retryCount + 1)
        end
    end, MONSTER_BIND_RETRY_DELAY_MS)

    return false
end

function TaskBoardController:updatePreferredMonsterScrollRange(totalRows, viewportHeight, rowHeight)
    local scrollWidget = self:getPreferredMonsterScrollWidget()
    rowHeight = math.max(1, math.floor((tonumber(rowHeight) or self:getPreferredMonsterRowHeight(scrollWidget)) + 0.5))
    local visibleRows = math.max(1, math.floor(viewportHeight / rowHeight))
    local maxScroll = math.max((math.max(1, totalRows - visibleRows + 1) - 1) * rowHeight, 0)

    if scrollWidget and scrollWidget.verticalScrollBar then
        local sb = scrollWidget.verticalScrollBar
        sb:setMinimum(0)
        sb:setMaximum(maxScroll)
        sb:setStep(rowHeight)

        if (tonumber(sb:getValue()) or 0) > maxScroll then
            self._preferredApplyingScrollSnap = true
            sb:setValue(maxScroll)
            self._preferredApplyingScrollSnap = false
        end
    end

    return maxScroll, visibleRows
end

function TaskBoardController:getPreferredMonsterRowHeight(scrollWidget)
    local measured = clampRowHeightPx(self._preferredRowHeightPx)
    if self._preferredRowHeightMeasured then return measured end

    scrollWidget = scrollWidget or self:getPreferredMonsterScrollWidget()
    if not scrollWidget or not scrollWidget.querySelectorAll then return measured end

    local rows = scrollWidget:querySelectorAll(".monsterRow")
    local h = 0
    if rows and #rows >= 2 then
        local delta = math.abs((tonumber(rows[#rows]:getY()) or 0) - (tonumber(rows[1]:getY()) or 0))
        local pitch = delta / (#rows - 1)
        if pitch > 0 then h = pitch end
    elseif rows and #rows == 1 then
        h = tonumber(rows[1]:getHeight()) or 0
        if rows[1].getMarginTop and rows[1].getMarginBottom then
            h = h + (tonumber(rows[1]:getMarginTop()) or 0) + (tonumber(rows[1]:getMarginBottom()) or 0)
        end
    end

    if h > 0 then
        local rounded = math.floor(h + 0.5)
        if rounded >= MONSTER_ROW_HEIGHT_MIN_PX and rounded <= MONSTER_ROW_HEIGHT_MAX_PX then
            self._preferredRowHeightPx = rounded
            self._preferredRowHeightMeasured = true
            return rounded
        end
    end

    return measured
end

function TaskBoardController:resetPreferredMonsterScroll()
    local scrollWidget = self:getPreferredMonsterScrollWidget()
    if not scrollWidget or not scrollWidget.verticalScrollBar then
        self:ensurePreferredMonsterScrollBound()
        scrollWidget = self:getPreferredMonsterScrollWidget()
    end

    if scrollWidget and scrollWidget.verticalScrollBar then
        self._preferredApplyingScrollSnap = true
        scrollWidget.verticalScrollBar:setValue(0)
        self._preferredApplyingScrollSnap = false
    elseif scrollWidget then
        scrollWidget:setVirtualOffset({ x = 0, y = 0 })
    end

    self:refreshMonsterViewport(0)
end

function TaskBoardController:refreshMonsterViewport(scrollValue)
    if self._preferredViewportRefreshing then return end
    self._preferredViewportRefreshing = true

    local list = self.allAvailableMonsters or {}
    local total = #list
    local viewportHeight = 400

    local scrollWidget = self:getPreferredMonsterScrollWidget()
    local rowHeight = self:getPreferredMonsterRowHeight(scrollWidget)
    if scrollWidget and scrollWidget.getPaddingRect then
        local paddingRect = scrollWidget:getPaddingRect()
        if paddingRect and paddingRect.height and paddingRect.height > 0 then
            viewportHeight = paddingRect.height
        end
    end

    if total == 0 then
        self.visibleMonsters = {}
        self.availableMonsters = self.visibleMonsters
        self.monsterTopSpacerPxA, self.monsterTopSpacerPxB, self.monsterTopSpacerPxC = 0, 0, 0
        self.monsterBottomSpacerPxA, self.monsterBottomSpacerPxB, self.monsterBottomSpacerPxC = 0, 0, 0
        self._preferredViewportStart = 0
        self._preferredViewportEnd = 0
        self._preferredViewportRowHeight = rowHeight
        self._preferredViewportRefreshing = false
        return
    end

    local y = tonumber(scrollValue) or 0
    local maxScroll, visibleRows = self:updatePreferredMonsterScrollRange(total, viewportHeight, rowHeight)
    y = math.max(0, math.min(y, maxScroll))

    local snappedY = math.min(math.floor(y / rowHeight) * rowHeight, maxScroll)

    if scrollWidget and scrollWidget.verticalScrollBar and not self._preferredApplyingScrollSnap then
        local currentY = scrollWidget.verticalScrollBar:getValue()
        if currentY ~= snappedY then
            self._preferredApplyingScrollSnap = true
            scrollWidget.verticalScrollBar:setValue(snappedY)
            self._preferredApplyingScrollSnap = false
            y = snappedY
        else
            y = currentY
        end
    end

    local firstVisibleIndex = math.min(
        math.floor(y / rowHeight) + 1,
        math.max(1, total - visibleRows + 1)
    )
    local startIndex = math.max(1, firstVisibleIndex - MONSTER_OVERSCAN_ROWS)
    local endIndex = math.min(total, firstVisibleIndex + visibleRows + MONSTER_OVERSCAN_ROWS - 1)

    if self._preferredViewportStart == startIndex and
       self._preferredViewportEnd == endIndex and
       self._preferredViewportRowHeight == rowHeight then
        self._preferredViewportRefreshing = false
        return
    end

    local visible = {}
    for i = startIndex, endIndex do
        visible[#visible + 1] = list[i]
    end

    self.visibleMonsters = visible
    self.availableMonsters = visible
    self.monsterTopSpacerPxA, self.monsterTopSpacerPxB, self.monsterTopSpacerPxC =
        splitSpacerPx((startIndex - 1) * rowHeight)
    self.monsterBottomSpacerPxA, self.monsterBottomSpacerPxB, self.monsterBottomSpacerPxC =
        splitSpacerPx((total - endIndex) * rowHeight)
    self._preferredViewportStart = startIndex
    self._preferredViewportEnd = endIndex
    self._preferredViewportRowHeight = rowHeight
    self._preferredViewportRefreshing = false
end

function TaskBoardController:rebuildAvailableMonsters()
    local usedIds = {}
    for _, slotData in ipairs(cachedRawSlots) do
        local prefId = tonumber(slotData.preferred) or 0
        local unwId = tonumber(slotData.unwanted) or 0
        if prefId > 0 then usedIds[prefId] = true end
        if unwId > 0 then usedIds[unwId] = true end
    end

    local filter = (self.searchText or ""):lower()

    local sorted = {}
    for _, raceId in ipairs(cachedAllRaceIds) do
        if not usedIds[raceId] then
            local rd = g_things.getRaceData(raceId)
            local name = rd and rd.name or 'Unknown'
            name = name:capitalize()
            if filter == '' or name:lower():find(filter, 1, true) then
                table.insert(sorted, { raceId = raceId, name = name, outfit = rd and rd.outfit or nil })
            end
        end
    end

    table.sort(sorted, function(a, b) return a.name < b.name end)

    self.allAvailableMonsters = sorted
    self._preferredViewportStart = 0
    self._preferredViewportEnd = 0
    self._preferredViewportRowHeight = 0
    self._preferredRowHeightMeasured = false
    self._preferredRowHeightPx = MONSTER_ROW_HEIGHT_PX
    self:ensurePreferredMonsterScrollBound()
    self:resetPreferredMonsterScroll()
end

-- HTML event handlers
function TaskBoardController:filterMonsters(text)
    self.searchText = text or ""
    self:rebuildAvailableMonsters()
end

function TaskBoardController:selectMonster(raceId)
    self.selectedRaceId = tonumber(raceId) or 0
    self:rebuildPreferredSlots()
end

function TaskBoardController:isRaceAssigned(raceId, targetSlotNum, targetField)
    local targetRaceId = tonumber(raceId) or 0
    local targetSlot = tonumber(targetSlotNum) or 0
    if targetRaceId == 0 then
        return false
    end

    for index, slotData in ipairs(cachedRawSlots) do
        local slotNum = tonumber(slotData.slot) or index
        local preferredId = tonumber(slotData.preferred) or 0
        local unwantedId = tonumber(slotData.unwanted) or 0

        if preferredId == targetRaceId and not (slotNum == targetSlot and targetField == 'preferred') then
            return true
        end

        if unwantedId == targetRaceId and not (slotNum == targetSlot and targetField == 'unwanted') then
            return true
        end
    end

    return false
end

function TaskBoardController:onPreferredSlotAction(slotNum, action, cost)
    if action == 'assignPreferred' then
        self:assignPreferred(slotNum)
    elseif action == 'assignUnwanted' then
        self:assignUnwanted(slotNum)
    elseif action == 'clearPreferred' then
        self:clearPreferred(slotNum, cost)
    elseif action == 'clearUnwanted' then
        self:clearUnwanted(slotNum, cost)
    end
end

function TaskBoardController:assignPreferred(slotNum)
    if self.selectedRaceId == 0 then return end
    local parsedSlot = tonumber(slotNum) or 0
    if parsedSlot == 0 then return end
    if self:isRaceAssigned(self.selectedRaceId, parsedSlot, 'preferred') then return end

    g_game.bountyPreferredAction(BOUNTY_PREF_ACTION_SET_PREFERRED, parsedSlot, self.selectedRaceId)
    updateCachedSlot(parsedSlot, 'preferred', self.selectedRaceId)
    self.selectedRaceId = 0
    self:rebuildPreferredSlots()
    self:rebuildAvailableMonsters()
end

function TaskBoardController:assignUnwanted(slotNum)
    if self.selectedRaceId == 0 then return end
    local parsedSlot = tonumber(slotNum) or 0
    if parsedSlot == 0 then return end
    if self:isRaceAssigned(self.selectedRaceId, parsedSlot, 'unwanted') then return end

    g_game.bountyPreferredAction(BOUNTY_PREF_ACTION_SET_UNWANTED, parsedSlot, self.selectedRaceId)
    updateCachedSlot(parsedSlot, 'unwanted', self.selectedRaceId)
    self.selectedRaceId = 0
    self:rebuildPreferredSlots()
    self:rebuildAvailableMonsters()
end

function TaskBoardController:clearPreferred(slotNum, cost)
    local parsedSlot = tonumber(slotNum) or 0
    if parsedSlot == 0 then return end
    local parsedCost = tonumber(cost) or getPreferredActionCost()

    local msgBox
    local function yes()
        if msgBox then msgBox:destroy(); msgBox = nil end
        g_game.bountyPreferredAction(BOUNTY_PREF_ACTION_REMOVE_PREFERRED, parsedSlot, 0)
        updateCachedSlot(parsedSlot, 'preferred', 0)
        self:rebuildPreferredSlots()
        self:rebuildAvailableMonsters()
    end
    local function cancel()
        if msgBox then msgBox:destroy(); msgBox = nil end
    end
    msgBox = displayGeneralBox(tr('Clear Preferred'),
        tr('Remove preferred monster? This costs %d Bounty Task Points.', parsedCost),
        {{ text = tr('Yes'), callback = yes }, { text = tr('Cancel'), callback = cancel }}, yes, cancel)
end

function TaskBoardController:clearUnwanted(slotNum, cost)
    local parsedSlot = tonumber(slotNum) or 0
    if parsedSlot == 0 then return end
    local parsedCost = tonumber(cost) or getPreferredActionCost()

    local msgBox
    local function yes()
        if msgBox then msgBox:destroy(); msgBox = nil end
        g_game.bountyPreferredAction(BOUNTY_PREF_ACTION_REMOVE_UNWANTED, parsedSlot, 0)
        updateCachedSlot(parsedSlot, 'unwanted', 0)
        self:rebuildPreferredSlots()
        self:rebuildAvailableMonsters()
    end
    local function cancel()
        if msgBox then msgBox:destroy(); msgBox = nil end
    end
    msgBox = displayGeneralBox(tr('Clear Unwanted'),
        tr('Remove unwanted monster? This costs %d Bounty Task Points.', parsedCost),
        {{ text = tr('Yes'), callback = yes }, { text = tr('Cancel'), callback = cancel }}, yes, cancel)
end

function TaskBoardController:buyPreferredSlot(slotNum, price)
    local parsedSlot = tonumber(slotNum) or 0
    if parsedSlot == 0 then return end
    local parsedPrice = tonumber(price) or getPreferredUnlockPrice(parsedSlot, 0)

    local msgBox
    local function yes()
        if msgBox then msgBox:destroy(); msgBox = nil end
        g_game.bountyPreferredAction(BOUNTY_PREF_ACTION_BUY_SLOT, parsedSlot, 0)
    end
    local function cancel()
        if msgBox then msgBox:destroy(); msgBox = nil end
    end
    msgBox = displayGeneralBox(tr('Unlock Slot'),
        tr('Unlock this preferred slot for %d Bounty Task Points?', parsedPrice),
        {{ text = tr('Yes'), callback = yes }, { text = tr('Cancel'), callback = cancel }}, yes, cancel)
end
