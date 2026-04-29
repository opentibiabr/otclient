-- Kill tracker integration — methods added to TaskBoardController
-- This wraps the Tracker.Prey / Tracker.Bounty / Tracker.Weekly systems
-- (provided by the Prey tracker widget from another module).
-- LuaFormatter off
Tracker = Tracker or {}
Tracker.Prey   = Tracker.Prey   or {}
Tracker.Bounty = Tracker.Bounty or {}
Tracker.Weekly = Tracker.Weekly or {}
Tracker.Weekly.slots = Tracker.Weekly.slots or {}

local preyTracker       = nil
local taskboardTrackerButton = nil
local restoreEvent      = nil
local trackerStyleLoaded = false

local PREY_BONUS_DAMAGE_BOOST    = 0
local PREY_BONUS_DAMAGE_REDUCTION= 1
local PREY_BONUS_XP_BONUS        = 2
local PREY_BONUS_IMPROVED_LOOT   = 3
local SLOT_STATE_LOCKED          = 0
local SLOT_STATE_ACTIVE          = 2
-- LuaFormatter on
--  Initialization 

function TaskBoardController:initTracker()
    if preyTracker then
        local hasTaskBoardSlots = preyTracker:recursiveGetChildById('bslot1') and
                                      preyTracker:recursiveGetChildById('weeklyTasksLabel')
        if hasTaskBoardSlots then
            return
        end

        preyTracker:destroy()
        preyTracker = nil
    end

    if not trackerStyleLoaded then
        g_ui.importStyle('/modules/game_taskboard/trackers/styles/kill_tracker.otui')
        trackerStyleLoaded = true
    end

    preyTracker = g_ui.createWidget('TaskBoardKillTracker')
    preyTracker:setup()

    -- Hide buttons not needed for this tracker variant
    for _, id in ipairs({'contextMenuButton', 'newWindowButton', 'toggleFilterButton'}) do
        local w = preyTracker:recursiveGetChildById(id)
        if w then
            w:setVisible(false)
        end
    end

    -- Reposition lock button next to minimize button
    local lockBtn = preyTracker:recursiveGetChildById('lockButton')
    local minBtn = preyTracker:recursiveGetChildById('minimizeButton')
    if lockBtn and minBtn then
        lockBtn:setVisible(true)
        lockBtn:breakAnchors()
        lockBtn:addAnchor(AnchorTop, minBtn:getId(), AnchorTop)
        lockBtn:addAnchor(AnchorRight, minBtn:getId(), AnchorLeft)
        lockBtn:setMarginRight(2)
        lockBtn:setMarginTop(0)
    end

    preyTracker:setContentMaximumHeight(500)
    preyTracker:setContentMinimumHeight(47)
    preyTracker:close(true)

    Tracker.Bounty.setInactive()
    Tracker.Weekly.clearAll()

    preyTracker.onOpen = function()
        if taskboardTrackerButton then
            taskboardTrackerButton:setOn(true)
        end
    end
    preyTracker.onClose = function()
        if taskboardTrackerButton then
            taskboardTrackerButton:setOn(false)
        end
    end

    Keybind.new("Windows", "Show/Hide kill tracker", "", "")
    Keybind.bind("Windows", "Show/Hide kill tracker", {{
        type = KEY_DOWN,
        callback = function()
            self:toggleTracker()
        end
    }})

    self:checkTracker()
end

function TaskBoardController:terminateTracker()
    if restoreEvent then
        removeEvent(restoreEvent)
        restoreEvent = nil
    end
    Keybind.delete("Windows", "Show/Hide kill tracker")
    if taskboardTrackerButton then
        taskboardTrackerButton:destroy()
        taskboardTrackerButton = nil
    end
    if preyTracker then
        preyTracker:destroy()
        preyTracker = nil
    end
end

function TaskBoardController:checkTracker()
    if not g_game.getFeature(GamePrey) then
        return
    end
    if not taskboardTrackerButton then
        taskboardTrackerButton = modules.game_mainpanel.addToggleButton('taskboardTrackerButton', tr('Kill Tracker'),
            '/images/options/button_prey', function()
                self:toggleTracker()
            end, false, 9)
    end
    if restoreEvent then
        removeEvent(restoreEvent)
        restoreEvent = nil
    end
    restoreEvent = scheduleEvent(function()
        restoreEvent = nil
        if preyTracker and preyTracker.restorePosition then
            preyTracker:restorePosition()
        end
    end, 150)
end

function TaskBoardController:toggleTracker()
    if not preyTracker then
        return
    end
    if preyTracker:isVisible() then
        preyTracker:close()
    else
        if not preyTracker:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(preyTracker, preyTracker:getMinimumHeight())
            if not panel then
                return
            end
            preyTracker:setParent(panel)
        end
        preyTracker:open()
    end
end

--  Prey slot widget helper 

function Tracker.Prey.getSmallIconPath(bonusType)
    local path = "/images/game/prey/"
    if bonusType == PREY_BONUS_DAMAGE_BOOST then
        return path .. "prey_damage"
    elseif bonusType == PREY_BONUS_DAMAGE_REDUCTION then
        return path .. "prey_defense"
    elseif bonusType == PREY_BONUS_XP_BONUS then
        return path .. "prey_xp"
    elseif bonusType == PREY_BONUS_IMPROVED_LOOT then
        return path .. "prey_loot"
    end
    return path .. "prey_no_bonus"
end

function Tracker.Prey.getExtendIcon(lockType)
    local path = "/images/game/prey/"
    local player = g_game.getLocalPlayer()
    if not player then
        return path .. "prey-auto-extend-disabled"
    end
    local balance = player:getResourceBalance(ResourceTypes.PREY_WILDCARDS)
    if lockType == 1 then
        return balance < 1 and (path .. "prey-auto-reroll-enabled-failing") or (path .. "prey-auto-reroll-enabled")
    elseif lockType == 2 then
        return balance < 5 and (path .. "prey-lock-prey-enabled-failing") or (path .. "prey-lock-prey-enabled")
    end
    return path .. "prey-auto-extend-disabled"
end

function Tracker.Prey.timeleftTranslation(timeleft)
    if timeleft == 0 then
        return "Free"
    end
    local hours = string.format('%02.f', math.floor(timeleft / 3600))
    local mins = string.format('%02.f', math.floor(timeleft / 60 - (hours * 60)))
    return hours .. ':' .. mins
end

function Tracker.Prey.updateWidget(slot, state, currentHolderOutfit, preySlot, showCallback)
    if not preyTracker then
        return
    end
    local trackerSlot = preyTracker.contentsPanel["slot" .. (slot + 1)]
    if not trackerSlot then
        return
    end

    if state == SLOT_STATE_LOCKED then
        trackerSlot:setVisible(false)
        return
    end

    if slot == 2 then
        trackerSlot:setVisible(true)
        preyTracker:setContentMaximumHeight(195)
    end

    if state == SLOT_STATE_ACTIVE then
        local creatureAndBonus = preySlot.active.creatureAndBonus
        trackerSlot.creature:setOutfit(currentHolderOutfit)
        trackerSlot.creatureName:setText(short_text(preySlot.title:getText(), 12))
        trackerSlot.time:setPercent(creatureAndBonus.timeLeft:getPercent())
        trackerSlot.preyType:setImageSource(Tracker.Prey.getSmallIconPath(preySlot.bonusType))
        trackerSlot.preyAutoExtend:setImageSource(Tracker.Prey.getExtendIcon(preySlot.lockType))
        trackerSlot.creature:show()
        trackerSlot.noCreature:hide()
        trackerSlot.onClick = function()
            showCallback()
        end
    else
        trackerSlot.creature:hide()
        trackerSlot.noCreature:show()
        trackerSlot.creatureName:setText("Inactive")
        trackerSlot.time:setPercent(0)
        trackerSlot.preyAutoExtend:setImageSource(Tracker.Prey.getExtendIcon(preySlot.lockType))
        trackerSlot.preyType:setImageSource(Tracker.Prey.getSmallIconPath(preySlot.bonusType))
        trackerSlot.onClick = function()
            showCallback()
        end
    end
end

function Tracker.Prey.updateTimeLeft(slot, timeLeft)
    if not preyTracker then
        return
    end
    local trackerSlot = preyTracker.contentsPanel["slot" .. (slot + 1)]
    if not trackerSlot then
        return
    end
    local updated = string.gsub(trackerSlot:getTooltip(), "[^\n]*Duration: [^\n]*\n?",
        "Duration: " .. Tracker.Prey.timeleftTranslation(timeLeft) .. "\n")
    trackerSlot:setTooltip(updated)
    local percent = (timeLeft / (2 * 60 * 60)) * 100
    trackerSlot.time:setPercent(percent)
end

function Tracker.Prey.getWidget()
    return preyTracker
end
function Tracker.Prey.getButton()
    return taskboardTrackerButton
end

--  Bounty tracker slot 

local function getBountySlot()
    return preyTracker and preyTracker.contentsPanel and preyTracker.contentsPanel["bslot1"]
end

function Tracker.Bounty.setInactive()
    local slot = getBountySlot()
    if not slot then
        return
    end
    slot.creature:hide()
    slot.noCreature:show()
    slot.creatureName:setText("Inactive")
    slot.time:setPercent(0)
    slot.time:setBackgroundColor("#555555")
    slot:setTooltip("No active Bounty Task.\n\nClick to open the Bounty Task panel.")
    slot.onClick = function()
        TaskBoardController:toggle()
    end
end

function Tracker.Bounty.setActive(name, outfit, killCount, killTarget)
    local slot = getBountySlot()
    if not slot then
        return
    end
    slot.creature:setOutfit(outfit)
    slot.creature:show()
    slot.noCreature:hide()
    slot.creatureName:setText(short_text(name, 12))
    local percent = killTarget > 0 and (killCount / killTarget) * 100 or 0
    slot.time:setPercent(percent)
    slot.time:setBackgroundColor("#C28400")
    slot:setTooltip(tr("Bounty Task: %s\nProgress: %d/%d kills\n\nClick to open the Bounty Task panel.", name, killCount,
        killTarget))
    slot.onClick = function()
        TaskBoardController:toggle()
    end
end

function Tracker.Bounty.setCompleted(name, outfit, killCount, killTarget)
    local slot = getBountySlot()
    if not slot then
        return
    end
    slot.creature:setOutfit(outfit)
    slot.creature:show()
    slot.noCreature:hide()
    slot.creatureName:setText(short_text(name, 12))
    slot.time:setPercent(100)
    slot.time:setBackgroundColor("#00AA00")
    slot:setTooltip(tr("Bounty Task: %s\nProgress: %d/%d kills\nCompleted! Click to claim your reward.", name, killCount,
        killTarget))
    slot.onClick = function()
        TaskBoardController:toggle()
    end
end

function Tracker.Bounty.onKillUpdate(raceId, currentKills, totalKills, isCompleted)
    local raceData = g_things.getRaceData(raceId)
    local name = raceData and raceData.name or 'Unknown'
    name = name:capitalize()
    local outfit = raceData and raceData.outfit or {}
    if isCompleted == 1 then
        Tracker.Bounty.setCompleted(name, outfit, currentKills, totalKills)
    else
        Tracker.Bounty.setActive(name, outfit, currentKills, totalKills)
    end
end

--  Weekly tracker slots 

local function getWeeklySlot(index)
    return preyTracker and preyTracker.contentsPanel and preyTracker.contentsPanel["wslot" .. index]
end

function Tracker.Weekly.setSectionVisible(visible)
    if not preyTracker then
        return
    end
    local label = preyTracker.contentsPanel:recursiveGetChildById('weeklyTasksLabel')
    if label then
        label:setVisible(visible)
    end
    local sep = preyTracker.contentsPanel:recursiveGetChildById('weeklyTasksSeparator')
    if sep then
        sep:setVisible(visible)
    end
end

function Tracker.Weekly.setSlotInactive(index)
    local slot = getWeeklySlot(index)
    if not slot then
        return
    end
    slot.creature:hide()
    slot.anyCreatureIcon:hide()
    slot.noCreature:show()
    slot.creatureName:setText("Inactive")
    slot.time:setPercent(0)
    slot.time:setBackgroundColor("#555555")
    slot:setVisible(false)
end

function Tracker.Weekly.setSlotActive(index, raceId, name, outfit, currentKills, totalKills)
    local slot = getWeeklySlot(index)
    if not slot then
        return
    end
    if raceId == 0 then
        slot.creature:hide()
        slot.anyCreatureIcon:show()
        slot.noCreature:hide()
        slot.creatureName:setText("Any Creature")
    else
        slot.creature:setOutfit(outfit)
        slot.creature:show()
        slot.anyCreatureIcon:hide()
        slot.noCreature:hide()
        slot.creatureName:setText(short_text(name, 12))
    end
    local percent = totalKills > 0 and (currentKills / totalKills) * 100 or 0
    slot.time:setPercent(percent)
    slot.time:setBackgroundColor("#C28400")
    slot:setTooltip(tr("Weekly Task: %s\nProgress: %d/%d kills", name, currentKills, totalKills))
    slot:setVisible(true)
    slot.onClick = function()
        TaskBoardController:show()
        TaskBoardController:selectTab(TaskBoardController.TAB_WEEKLY)
    end
end

function Tracker.Weekly.setSlotCompleted(index, raceId, name, outfit, currentKills, totalKills)
    local slot = getWeeklySlot(index)
    if not slot then
        return
    end
    if raceId == 0 then
        slot.creature:hide()
        slot.anyCreatureIcon:show()
        slot.noCreature:hide()
        slot.creatureName:setText("Any Creature")
    else
        slot.creature:setOutfit(outfit)
        slot.creature:show()
        slot.anyCreatureIcon:hide()
        slot.noCreature:hide()
        slot.creatureName:setText(short_text(name, 12))
    end
    slot.time:setPercent(100)
    slot.time:setBackgroundColor("#00AA00")
    slot:setTooltip(tr("Weekly Task: %s\nProgress: %d/%d kills\nCompleted!", name, currentKills, totalKills))
    slot:setVisible(true)
    slot.onClick = function()
        TaskBoardController:show()
        TaskBoardController:selectTab(TaskBoardController.TAB_WEEKLY)
    end
end

function Tracker.Weekly.clearAll()
    Tracker.Weekly.slots = {}
    for i = 1, MAX_WEEKLY_TRACKER_SLOTS do
        Tracker.Weekly.setSlotInactive(i)
    end
    Tracker.Weekly.setSectionVisible(false)
end

function Tracker.Weekly.loadFromServerData(monsters)
    Tracker.Weekly.slots = {}
    if not monsters or #monsters == 0 then
        Tracker.Weekly.clearAll()
        return
    end
    Tracker.Weekly.setSectionVisible(true)
    for i, m in ipairs(monsters) do
        if i > MAX_WEEKLY_TRACKER_SLOTS then
            break
        end
        local raceId = tonumber(m.raceId) or 0
        local current = tonumber(m.current) or 0
        local total = tonumber(m.total) or 0
        local finished = (tonumber(m.state) or 0) == 1
        local name = "Any Creature"
        local outfit = {}
        if raceId > 0 then
            local rd = g_things.getRaceData(raceId)
            name = rd and rd.name or 'Unknown'
            name = name:capitalize()
            outfit = rd and rd.outfit or {}
        end
        Tracker.Weekly.slots[i] = {
            raceId = raceId,
            name = name,
            outfit = outfit
        }
        if finished then
            Tracker.Weekly.setSlotCompleted(i, raceId, name, outfit, current, total)
        else
            Tracker.Weekly.setSlotActive(i, raceId, name, outfit, current, total)
        end
    end
    for i = #monsters + 1, MAX_WEEKLY_TRACKER_SLOTS do
        local slot = getWeeklySlot(i)
        if slot then
            slot:setVisible(false)
        end
    end
end

function Tracker.Weekly.onKillUpdate(raceId, currentKills, totalKills, isCompleted)
    for i, data in pairs(Tracker.Weekly.slots) do
        if data.raceId == raceId then
            if isCompleted == 1 then
                Tracker.Weekly.setSlotCompleted(i, raceId, data.name, data.outfit, currentKills, totalKills)
            else
                Tracker.Weekly.setSlotActive(i, raceId, data.name, data.outfit, currentKills, totalKills)
            end
            return
        end
    end
end
