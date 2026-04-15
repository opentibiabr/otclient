-- Weekly tasks tab logic — methods added to TaskBoardController
--  Server data handler 
local function getItemServerName(itemId)
    local thingType = g_things.getThingType(itemId, ThingCategoryItem)
    if thingType then
        return thingType:getName()
    end
    return "Unknown Item"
end

local function countFinishedEntries(entries)
    local total = 0
    for _, entry in ipairs(entries or {}) do
        if entry.finished then
            total = total + 1
        end
    end
    return total
end

function TaskBoardController:refreshWeeklySummary()
    local header = self.weeklyHdr or {}
    local completedKillTasks = tonumber(header.completedKillTasks)
    if completedKillTasks == nil then
        completedKillTasks = countFinishedEntries(self.weeklyMonsters)
    end
    local completedDeliveryTasks = tonumber(header.completedDeliveryTasks) or 0
    local totalTaskSlots = tonumber(header.totalTaskSlots) or WEEKLY_DEFAULT_TASK_SLOTS
    local maxExperience = tonumber(header.maxExperience) or 0
    local maxDeliveryExperience = tonumber(header.maxDeliveryExperience) or 0
    local difficultyId = tonumber(header.difficulty) or 0
    local killTaskPoints = WEEKLY_KILL_TASK_POINTS[difficultyId] or WEEKLY_KILL_TASK_POINTS[1]
    local deliveryTaskPoints = WEEKLY_DELIVERY_TASK_POINTS
    local soulsealPointsPerTask = WEEKLY_SOULSEAL_POINTS_PER_TASK
    local totalCompleted = completedKillTasks + completedDeliveryTasks
    local pointsEarned = tonumber(header.pointsEarned) or 0
    local soulsealsEarned = tonumber(header.soulsealsEarned) or 0
    local killBase = completedKillTasks * killTaskPoints
    local deliveryBase = completedDeliveryTasks * deliveryTaskPoints
    local basePoints = killBase + deliveryBase
    local rewardMultiplier = (basePoints > 0) and math.max(1, math.floor(pointsEarned / basePoints + 0.5)) or 1

    self.weeklyHdr.completedKillTasks = completedKillTasks

    self.weeklyRewardTokens = comma_value(pointsEarned)
    self.weeklyRewardSeals = comma_value(soulsealsEarned)
    self.weeklyRemainingDays = tonumber(header.remainingDays) or 0
    self.weeklyShowExtraSlotUnlock = not ((tonumber(header.extraSlot) or 0) == 1 or header.extraSlot == true)
    self.weeklyProgressPct = self:calcProgressWidth(totalCompleted)
    self.weeklyXpText = (maxExperience > 0) and
                            tr(
            'Each kill task rewards you with %s XP and each delivery task will reward you with %s XP.',
            comma_value(maxExperience), comma_value(maxDeliveryExperience)) or ""

    self.weeklyProgressTooltip = string.format('Kill Tasks: %d\nDelivery Tasks: %d\nTotal: %d', completedKillTasks,
        completedDeliveryTasks, totalCompleted)

    self.weeklyRewardTokensTooltip = string.format(
        'Hunting Task Points:\n\n   %d * %d  (Kill Tasks)\n+ %d * %d  (Delivery Tasks)\n--------------------------------------\n= %s  base points\nx %d  reward multiplier\n= %s  Hunting Task Points',
        completedKillTasks, killTaskPoints, completedDeliveryTasks, deliveryTaskPoints,
        comma_value(killBase + deliveryBase), rewardMultiplier, comma_value(pointsEarned))

    self.weeklyRewardSealsTooltip = string.format(
        'You receive %d Soulseal for each completed task. Soulseals can be\nused in the Soulpit. Click the obelisk there, then your character to\nopen a menu where you can select a creature you want to\nchallenge on your own.',
        soulsealPointsPerTask)

    self.weeklyDifficultySummaryVisible = completedKillTasks > 0 or completedDeliveryTasks > 0
    self.weeklyDifficultyKillSummary = string.format('You have completed %d / %d kill tasks.', completedKillTasks,
        totalTaskSlots)
    self.weeklyDifficultyDeliverySummary = string.format('You have completed %d / %d delivery tasks.',
        completedDeliveryTasks, totalTaskSlots)
    self.weeklyDifficultyPointsEarned = comma_value(pointsEarned)
    self.weeklyDifficultySealsEarned = comma_value(soulsealsEarned)
end

function TaskBoardController:onWeeklyServerData(header, monsters, items)
    -- Update tracker regardless of UI state
    if Tracker and Tracker.Weekly then
        Tracker.Weekly.loadFromServerData(monsters)
    end

    local playerLevel = tonumber(header.currentPlayerLevel) or
                            (g_game.getLocalPlayer() and g_game.getLocalPlayer():getLevel() or 0)
    local data = {
        difficulty = tonumber(header.difficulty) or 0,
        remainingDays = tonumber(header.remainingDays) or 7,
        totalTaskSlots = tonumber(header.totalTaskSlots) or WEEKLY_DEFAULT_TASK_SLOTS,
        maxExperience = tonumber(header.maxExperience) or 0,
        maxDeliveryExperience = tonumber(header.maxDeliveryExperience) or 0,
        completedKillTasks = tonumber(header.completedKillTasks) or 0,
        completedDeliveryTasks = tonumber(header.completedDeliveryTasks) or 0,
        pointsEarned = tonumber(header.pointsEarned) or 0,
        soulsealsEarned = tonumber(header.soulsealsEarned) or 0,
        extraSlot = (tonumber(header.extraSlot) or 0) == 1
    }

    -- Build weeklyMonsters list
    local monsterList = {}
    for _, m in ipairs(monsters) do
        local raceId = tonumber(m.raceId) or 0
        local raceData = raceId > 0 and g_things.getRaceData(raceId) or nil
        local fullName = raceId == 0 and 'Any Creature' or ((raceData and raceData.name) or 'Unknown')
        if raceId > 0 then
            fullName = fullName:capitalize()
        end
        local shortName = fullName
        if #shortName > 20 then
            shortName = shortName:sub(1, 17) .. '...'
        end
        local finished = (tonumber(m.state) or 0) == 1
        table.insert(monsterList, {
            raceId = raceId,
            name = shortName,
            fullName = fullName,
            outfit = raceData and raceData.outfit or nil,
            current = tonumber(m.current) or 0,
            total = tonumber(m.total) or 0,
            finished = finished,
            showProgress = not finished,
            anyCreature = raceId == 0
        })
    end
    self.weeklyMonsters = monsterList

    -- Build weeklyItems list
    local itemList = {}
    for i, it in ipairs(items) do
        local itemId = tonumber(it.itemId) or 0
        local itemName = itemId > 0 and (getItemServerName(itemId) or tostring(itemId)) or
                             "Unknown Item"
        local current = tonumber(it.current) or 0
        local total = tonumber(it.total) or 0
        local delivered = (tonumber(it.claimed) or 0) == 1
        local finished = (tonumber(it.state) or 0) == 1
        local canDeliver = finished and not delivered
        table.insert(itemList, {
            itemId = itemId,
            itemName = itemName,
            current = current,
            total = total,
            delivered = delivered,
            finished = finished,
            slotIndex = tonumber(it.slotIndex) or (i - 1),
            canDeliver = canDeliver,
            showProgress = not delivered
        })
    end
    self.weeklyItems = itemList

    -- Build difficulties list for modal (from client-side constant — server does not send it)
    local diffList = {}
    for _, d in ipairs(WEEKLY_DIFFICULTIES) do
        local canSelect = playerLevel >= d.minLevel
        table.insert(diffList, {
            id = d.id,
            name = d.name,
            minLevel = d.minLevel,
            canSelect = canSelect,
            imgPath = string.format('/game_taskboard/assets/images/%s-large-button', d.name:lower()),
            tooltip = (not canSelect) and
                string.format('The minimum level to start this difficulty is %d', d.minLevel) or nil
        })
    end
    self.weeklyDifficulties = diffList

    self.weeklyHdr = data
    self:refreshWeeklySummary()

    -- Difficulty modal
    self.weeklyDifficultyPending = data.difficulty == 0
    self.diffModalVisible = false

    self:onWeeklyTabSelected()
end

--  Kill update 

function TaskBoardController:onWeeklyKillUpdate(raceId, currentKills, totalKills, isCompleted)
    if Tracker and Tracker.Weekly then
        Tracker.Weekly.onKillUpdate(raceId, currentKills, totalKills, isCompleted)
    end

    -- Update matching entry in weeklyMonsters
    local completionChanged = false
    for i, m in ipairs(self.weeklyMonsters) do
        if m.raceId == raceId then
            completionChanged = m.finished ~= (isCompleted == 1)
            self.weeklyMonsters[i].current = currentKills
            self.weeklyMonsters[i].total = totalKills
            self.weeklyMonsters[i].finished = isCompleted == 1
            self.weeklyMonsters[i].showProgress = isCompleted ~= 1
            self.weeklyMonsters = self.weeklyMonsters
            break
        elseif raceId == 0 and m.anyCreature then
            completionChanged = m.finished ~= (isCompleted == 1)
            self.weeklyMonsters[i].current = currentKills
            self.weeklyMonsters[i].total = totalKills
            self.weeklyMonsters[i].finished = isCompleted == 1
            self.weeklyMonsters[i].showProgress = isCompleted ~= 1
            self.weeklyMonsters = self.weeklyMonsters
            break
        end
    end

    local completedKillTasks = countFinishedEntries(self.weeklyMonsters)
    self.weeklyHdr.completedKillTasks = completedKillTasks
    self:refreshWeeklySummary()

    if completionChanged and g_game.weeklyTaskAction then
        g_game.weeklyTaskAction(WEEKLY_ACTION_REFRESH_DATA, 0)
    end
end

--  Tab selection 

function TaskBoardController:onWeeklyTabSelected()
    if not self.ui or not self.ui:isVisible() then
        return
    end
    self.diffModalVisible = self.activeTab == self.TAB_WEEKLY and self.weeklyDifficultyPending
end

--  Actions 

function TaskBoardController:selectDifficulty(diffId)
    local parsedId = tonumber(diffId) or 0
    if parsedId <= 0 then
        return
    end
    g_game.weeklyTaskAction(WEEKLY_ACTION_SELECT_DIFFICULTY, parsedId)
    self.weeklyDifficultyPending = false
    self.diffModalVisible = false
end

function TaskBoardController:deliverItem(itemId, slotIndex)
    local parsedItemId = tonumber(itemId) or 0
    local itemName = parsedItemId > 0 and
                         (getItemServerName(parsedItemId) or tostring(parsedItemId)) or
                         "Unknown Item"
    local msgBox
    local function yes()
        if msgBox then
            msgBox:destroy();
            msgBox = nil
        end
        g_game.weeklyTaskAction(WEEKLY_ACTION_DELIVER_ITEM, tonumber(slotIndex) or 0)
    end
    local function no()
        if msgBox then
            msgBox:destroy();
            msgBox = nil
        end
    end
    msgBox = displayGeneralBox(tr('Deliver Item'), tr('Do you want to deliver %s?', itemName), {{
        text = tr('Yes'),
        callback = yes
    }, {
        text = tr('No'),
        callback = no
    }}, yes, no)
end

--  Progress bar helper 

function TaskBoardController:calcProgressWidth(completedTasks)
    local sectionIndex = 0
    for i = 1, WEEKLY_SECTIONS do
        if completedTasks >= WEEKLY_THRESHOLDS[i + 1] then
            sectionIndex = i
        else
            break
        end
    end

    local sectionWidth = 100 / WEEKLY_SECTIONS

    if sectionIndex >= WEEKLY_SECTIONS then
        return 100
    end

    local sectionStart = WEEKLY_THRESHOLDS[sectionIndex + 1]
    local sectionEnd = WEEKLY_THRESHOLDS[sectionIndex + 2]
    local fraction = (completedTasks - sectionStart) / (sectionEnd - sectionStart)
    return math.min(math.floor((sectionIndex + fraction) * sectionWidth), 100)
end
