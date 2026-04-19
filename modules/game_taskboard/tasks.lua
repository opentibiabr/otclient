TaskBoardController = Controller:new()
-- LuaFormatter off
-- tabs
TaskBoardController.TAB_BOUNTY = 1
TaskBoardController.TAB_WEEKLY = 2
TaskBoardController.TAB_SHOP   = 3

-- widget button
TaskBoardButton = nil

-- HTML-bound reactive state
-- Bounty tab
TaskBoardController.activeTab             = 1
TaskBoardController.bountyTasks           = {}
TaskBoardController.talismans             = {}
TaskBoardController.bountyDifficulty      = 1
TaskBoardController.rerollPoints          = 0
TaskBoardController.claimDailyAvailable   = false
TaskBoardController.claimDailyWarning     = false
TaskBoardController.claimDailyServerAvailable = false

-- Weekly tab
TaskBoardController.weeklyMonsters        = {}
TaskBoardController.weeklyItems           = {}
TaskBoardController.weeklyHdr             = {}
TaskBoardController.weeklyDifficultyPending = false
TaskBoardController.weeklyDifficulties    = {}
TaskBoardController.diffModalVisible      = false
TaskBoardController.weeklyRewardTokens    = 0
TaskBoardController.weeklyRewardSeals     = 0
TaskBoardController.weeklyRemainingDays   = 0
TaskBoardController.weeklyXpText          = ""
TaskBoardController.weeklyProgressPct     = 0
TaskBoardController.weeklyProgressTooltip = ""
TaskBoardController.weeklyRewardTokensTooltip = ""
TaskBoardController.weeklyRewardSealsTooltip = ""
TaskBoardController.weeklyShowExtraSlotUnlock = false
TaskBoardController.weeklyDifficultySummaryVisible = false
TaskBoardController.weeklyDifficultyKillSummary = ""
TaskBoardController.weeklyDifficultyDeliverySummary = ""
TaskBoardController.weeklyDifficultyPointsEarned = "0"
TaskBoardController.weeklyDifficultySealsEarned = "0"

-- Shop tab
TaskBoardController.shopItems             = {}
TaskBoardController.shopBalance           = 0

-- Soulseal modal
TaskBoardController.soulsealEntries       = {}
TaskBoardController.soulsealSearchText    = ""
TaskBoardController.soulsealCategoryIndex = 1
TaskBoardController.soulsealSelectedIndex = 0
TaskBoardController.soulsealSelectedName  = "No creature selected"
TaskBoardController.soulsealSelectedRaceId= 0
TaskBoardController.soulsealSelectedOutfit= nil
TaskBoardController.soulsealSelectedPoints= "0"
TaskBoardController.soulsealSelectedDone  = false
TaskBoardController.soulsealSelectedCanFight = false
TaskBoardController.soulsealSelectedCategoryLabel = ""
TaskBoardController.soulsealSelectedHint  = "Select a creature from the list."
TaskBoardController.soulsealHasSelection  = false
TaskBoardController.soulsealHasEntries    = false
TaskBoardController.soulsealEmptyText     = "No Soulseal creatures available."

-- Info bar (always visible)
TaskBoardController.bountyPoints          = 0
TaskBoardController.taskShopPoints        = 0
TaskBoardController.soulpitPoints         = 0

-- Preferred modal state
TaskBoardController.availableMonsters     = {}
TaskBoardController.allAvailableMonsters  = {}
TaskBoardController.visibleMonsters       = {}
TaskBoardController.monsterTopSpacerPx    = 0
TaskBoardController.monsterBottomSpacerPx = 0
TaskBoardController.monsterTopSpacerPxA   = 0
TaskBoardController.monsterTopSpacerPxB   = 0
TaskBoardController.monsterTopSpacerPxC   = 0
TaskBoardController.monsterBottomSpacerPxA = 0
TaskBoardController.monsterBottomSpacerPxB = 0
TaskBoardController.monsterBottomSpacerPxC = 0
TaskBoardController.preferredSlots        = {}
TaskBoardController.searchText            = ""
TaskBoardController.selectedRaceId        = 0
TaskBoardController.preferredModal        = nil
TaskBoardController.soulsealModal         = nil
-- LuaFormatter on
function TaskBoardController:resetSessionState()
    self.activeTab = self.TAB_BOUNTY

    self.bountyTasks = {}
    self.talismans = {}
    self.bountyDifficulty = 1
    self.rerollPoints = 0
    self.claimDailyAvailable = false
    self.claimDailyWarning = false
    self.claimDailyServerAvailable = false

    self.weeklyMonsters = {}
    self.weeklyItems = {}
    self.weeklyHdr = {}
    self.weeklyDifficultyPending = false
    self.weeklyDifficulties = {}
    self.diffModalVisible = false
    self.weeklyRewardTokens = 0
    self.weeklyRewardSeals = 0
    self.weeklyRemainingDays = 0
    self.weeklyXpText = ""
    self.weeklyProgressPct = 0
    self.weeklyProgressTooltip = ""
    self.weeklyRewardTokensTooltip = ""
    self.weeklyRewardSealsTooltip = ""
    self.weeklyShowExtraSlotUnlock = false
    self.weeklyDifficultySummaryVisible = false
    self.weeklyDifficultyKillSummary = ""
    self.weeklyDifficultyDeliverySummary = ""
    self.weeklyDifficultyPointsEarned = "0"
    self.weeklyDifficultySealsEarned = "0"

    self.shopItems = {}
    self.shopBalance = 0

    self.availableMonsters = {}
    self.allAvailableMonsters = {}
    self.visibleMonsters = {}
    self.monsterTopSpacerPx = 0
    self.monsterBottomSpacerPx = 0
    self.monsterTopSpacerPxA = 0
    self.monsterTopSpacerPxB = 0
    self.monsterTopSpacerPxC = 0
    self.monsterBottomSpacerPxA = 0
    self.monsterBottomSpacerPxB = 0
    self.monsterBottomSpacerPxC = 0
    self.preferredSlots = {}
    self.searchText = ""
    self.selectedRaceId = 0

    if self.resetSoulsealState then
        self:resetSoulsealState(true)
    end

    self.bountyPoints = 0
    self.taskShopPoints = 0
    self.soulpitPoints = 0
end

--  Lifecycle

function TaskBoardController:onInit()
end

function TaskBoardController:onGameStart()
    local version = g_game.getClientVersion()
    if version < 1512 then
    --Delete this in the future if the PR #1475 (minClientVersion) is merged
        TaskBoardController:scheduleEvent(function()
            g_modules.getModule("game_taskboard"):unload()
        end, 100, "unloadModule")
        return
    end
-- LuaFormatter off
    self:registerEvents(g_game, {
        onResourcesBalanceChange = function(...) self:onResourceBalance(...) end,
        onTaskHuntingShopData    = function(...) self:onShopData(...) end,
        onTaskHuntingShopResult  = function(...) self:onShopResult(...) end,
        onWeeklyTaskData         = function(...) self:onWeeklyServerData(...) end,
        onBountyTaskData         = function(...) self:onBountyServerData(...) end,
        onBountyKillUpdate       = function(...) self:onBountyKillUpdate(...) end,
        onWeeklyKillUpdate       = function(...) self:onWeeklyKillUpdate(...) end,
        onBountyPreferredData    = function(...) self:onPreferredServerData(...) end,
        onSoulsealsData          = function(...) pdump(...) self:onSoulsealsData(...) end,
    })
-- LuaFormatter on
    if not TaskBoardButton then
        TaskBoardButton = modules.game_mainpanel.addToggleButton("taskHuntButton", tr("Task Hunt"),
            "/images/options/button_taskboard", function()
                self:toggle()
            end, false, 1006)
    end

    self:initTracker()
    self:syncResourceBalances()
end

function TaskBoardController:onGameEnd()
    self:hide()
    if self.hideSoulseal then
        self:hideSoulseal()
    end
    self:resetSessionState()
    self:terminateTracker()
end

function TaskBoardController:onTerminate()
    if TaskBoardButton then
        TaskBoardButton:destroy()
        TaskBoardButton = nil
    end
    self:hidePreferred()
    if self.hideSoulseal then
        self:hideSoulseal()
    end
    if self.ui then
        self:unloadHtml()
    end
end

--  Window management

function TaskBoardController:show()
    if not self.ui then
        self:loadHtml('template/html/main_taskboard.html')
    end
    self:syncResourceBalances()
    self.ui:show()
    self.ui:raise()
    self.ui:focus()
    --TaskBoardButton.highlight:show()
    if TaskBoardButton then
        TaskBoardButton:setOn(true)
    end
    local tabToShow = self.weeklyDifficultyPending and self.TAB_WEEKLY or self.activeTab
    self:selectTab(tabToShow)
    self:syncBountyDifficultySelect()
end

function TaskBoardController:hide()
    self:hidePreferred()
    self.shopItems = {}
    if self.ui then
        self:unloadHtml()
    end
    if TaskBoardButton then
        TaskBoardButton:setOn(false)
    end
end

function TaskBoardController:toggle()
    if self.ui and self.ui:isVisible() then
        self:hide()
    else
        self:show()
    end
end

--  Tab switching

function TaskBoardController:selectTab(n)
    if self.weeklyDifficultyPending and n ~= self.TAB_WEEKLY then
        return
    end
    self.activeTab = n
    local tabDaily = self:findWidget("#tabDaily")
    local tabWeekly = self:findWidget("#tabWeekly")
    local tabShop = self:findWidget("#tabShop")
    if tabDaily then
        tabDaily:setChecked(n == self.TAB_BOUNTY)
    end
    if tabWeekly then
        tabWeekly:setChecked(n == self.TAB_WEEKLY)
    end
    if tabShop then
        tabShop:setChecked(n == self.TAB_SHOP)
    end
    if n == self.TAB_BOUNTY and g_game.bountyTaskAction then
        g_game.bountyTaskAction(BOUNTY_ACTION_REQUEST, 0)
        self:syncBountyDifficultySelect()
    elseif n == self.TAB_WEEKLY and g_game.weeklyTaskAction then
        g_game.weeklyTaskAction(WEEKLY_ACTION_REFRESH_DATA, 0)
        self:onWeeklyTabSelected()
    elseif n == self.TAB_SHOP and g_game.taskHuntingShopRequest then
        g_game.taskHuntingShopRequest()
    end
end

function TaskBoardController:syncBountyDifficultySelect()
    local combo = self:findWidget("#dailyDifficultySelect")
    if not combo then
        return
    end

    local optionText = ({
        [1] = 'Beginner',
        [2] = 'Adept',
        [3] = 'Expert',
        [4] = 'Master'
    })[tonumber(self.bountyDifficulty) or 1]

    if combo.setCurrentOptionByData then
        combo:setCurrentOptionByData(tostring(self.bountyDifficulty), true)
    end

    if optionText and combo.setCurrentOption then
        combo:setCurrentOption(optionText, true)
    end
end

function TaskBoardController:openTaskStore()
    modules.game_store.toggle()
    g_game.sendRequestUsefulThings(StoreConst.TASKHUNTING_THIRDSLOT)
end

function TaskBoardController:syncResourceBalances()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    self.taskShopPoints = comma_value(tonumber(player:getResourceBalance(ResourceTypes.TASK_HUNTING)) or 0)
    self.soulpitPoints = comma_value(tonumber(player:getResourceBalance(ResourceTypes.SOULSEALS)) or 0)
    self.bountyPoints = comma_value(tonumber(player:getResourceBalance(ResourceTypes.BOUNTY_POINTS)) or 0)

    local rerollBalance = tonumber(self.rerollPoints) or 0
    self.rerollPoints = rerollBalance
    self.claimDailyWarning = rerollBalance >= REROLL_TOKEN_CAP
    self.claimDailyAvailable = self.claimDailyServerAvailable and rerollBalance < REROLL_TOKEN_CAP

    if self.preferredModal then
        self:rebuildPreferredSlots()
    end

    self:updateShopBalance(tonumber(player:getResourceBalance(ResourceTypes.TASK_HUNTING)) or 0)
end

--  Resource balance handler

function TaskBoardController:onResourceBalance(balance, oldBalance, resourceType)
    if not self.ui or not self.ui:isVisible() then
        return
    end
    if resourceType == nil then
        return
    end

    if resourceType == ResourceTypes.TASK_HUNTING then
        self.taskShopPoints = comma_value(balance)
        self:updateShopBalance(balance)
    elseif resourceType == ResourceTypes.SOULSEALS then
        self.soulpitPoints = comma_value(balance)
        if self.refreshSoulsealAffordability then
            self:refreshSoulsealAffordability()
        end
    elseif resourceType == ResourceTypes.BOUNTY_POINTS then
        self.bountyPoints = comma_value(balance)
        if self.preferredModal then
            self:rebuildPreferredSlots()
        end
    end
end
