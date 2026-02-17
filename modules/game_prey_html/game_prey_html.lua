PreyController = Controller:new()

-- Initialize default values
PreyController.wildcards = 0
PreyController.playerGold = "0"
PreyController.rawPlayerGold = 0
PreyController.rerollGoldPrice = "Free"
PreyController.rawRerollGoldPrice = 0
PreyController.rerollBonusPrice = 1
PreyController.pickSpecificPrice = 5
PreyController.lockPreyPrice = 5
PreyController.description = ""

local RACE_LIST_CHUNK_SIZE = 30

local PREY_BONUS_DAMAGE_BOOST = 0
local PREY_BONUS_DAMAGE_REDUCTION = 1
local PREY_BONUS_XP_BONUS = 2
local PREY_BONUS_IMPROVED_LOOT = 3
local PREY_BONUS_NONE = 4

local PREY_ACTION_LISTREROLL = 0
local PREY_ACTION_BONUSREROLL = 1
local PREY_ACTION_MONSTERSELECTION = 2
local PREY_ACTION_REQUEST_ALL_MONSTERS = 3
local PREY_ACTION_CHANGE_FROM_ALL = 4
local PREY_ACTION_OPTION = 5
local PREY_OPTION_UNTOGGLE = 0
local PREY_OPTION_TOGGLE_AUTOREROLL = 1
local PREY_OPTION_TOGGLE_LOCK_PREY = 2

local SLOT_STATE_LOCKED = 0
local SLOT_STATE_INACTIVE = 1
local SLOT_STATE_ACTIVE = 2
local SLOT_STATE_SELECTION = 3
local SLOT_STATE_SELECTION_CHANGE_MONSTER = 4
local SLOT_STATE_LIST_SELECTION = 5

function PreyController:handleResources(options)
    options = options or {}

    local player = g_game.getLocalPlayer()
    if not player then return end

    if not options.skipRequest then
        g_game.preyRequest()
    end

    self.wildcards = player:getResourceBalance(ResourceTypes.PREY_WILDCARDS)
    self.bankGold = player:getResourceBalance(ResourceTypes.BANK_BALANCE)
    self.inventoryGold = player:getResourceBalance(ResourceTypes.GOLD_EQUIPPED)
    self.rawPlayerGold = player:getTotalMoney() or 0
    self.playerGold = comma_value(self.rawPlayerGold)

    self:updateSlotResourceAvailability()
end

function PreyController:updateSlotResourceAvailability()
    if not self.preyData then
        return
    end

    local rawPlayerGold = self.rawPlayerGold or 0
    local wildcards = self.wildcards or 0
    local rerollCost = self.rawRerollGoldPrice or 0
    local hasWildcardsAvailable = wildcards > 0

    for _, slot in ipairs(self.preyData) do
        if type(slot) == "table" then
            if slot.isFreeReroll ~= nil then
                local shouldDisable = not slot.isFreeReroll and rerollCost > rawPlayerGold
                if slot.disableFreeReroll ~= shouldDisable then
                    slot.disableFreeReroll = shouldDisable
                end
            end

            slot.hasWildcards = hasWildcardsAvailable
        end
    end
end

function show()
    if not PreyController.ui then
        return
    end
    PreyController:handleResources()
    PreyController.ui:show()
    PreyController.ui:raise()
    PreyController.ui:focus()
end

function toggle()
    if not PreyController.ui then
        return
    end
    if PreyController.ui:isVisible() then
        PreyController:hide()
    else
        show()
    end
end

function PreyController:hide()
    if PreyController.ui then
        PreyController.ui:hide()
    end
end

PreyController.preyData = {
    { previewMonster = { raceId = nil, outfit = nil }, slotId = 0, monsterName = "Locked", type = 0, stars = 0, preyType = "/images/game/prey/prey_bignobonus" },
    { previewMonster = { raceId = nil, outfit = nil }, slotId = 1, monsterName = "Locked", type = 0, stars = 0, preyType = "/images/game/prey/prey_bignobonus" },
    { previewMonster = { raceId = nil, outfit = nil }, slotId = 2, monsterName = "Locked", type = 0, stars = 0, preyType = "/images/game/prey/prey_bignobonus" },
}

function PreyController:clearSlotTypeHistory(slotIndex)
    local slot = self.preyData[slotIndex]
    if not slot then return end

    slot.type = nil
    slot.previewMonster = {}
    slot.raceList = {}
    slot.raceListOriginal = {}
    slot.searchValue = false
    slot.searchValueText = ''
    slot.clearButton = false
    slot.percent = nil
    slot.percentFreeReroll = nil
    slot.timeleft = nil
    slot.timeUntilFreeReroll = nil
    slot.isFreeReroll = nil
    slot.disableFreeReroll = false
    slot.preyType = nil
    slot.bonusValue = nil
    slot.bonusType = nil
    slot.description = ''
    slot.stars = 0
    slot.outfit = nil
    slot.raceId = nil
    slot.autoReroll = false
    slot.lockPrey = false

    if self._raceListPagination then
        self._raceListPagination[slotIndex] = nil
    end
end

preyTrackerButton = nil
preyButton = nil

local descriptionTable = {
    ["shopPermButton"] =
    "Go to the Store to purchase the Permanent Prey Slot. Once you have completed the purchase, you can activate a prey here, no matter if your character is on a free or a Premium account.",
    ["shopTempButton"] = "You can activate this prey whenever your account has Premium Status.",
    ["preyWindow"] = "",
    ["noBonusIcon"] =
    "This prey is not available for your character yet.\nCheck the large blue button(s) to learn how to unlock this prey slot",
    ["selectPrey"] =
    "Click here to get a bonus with a higher value. The bonus for your prey will be selected randomly from one of the following: damage boost, damage reduction, bonus XP, improved loot. Your prey will be active for 2 hours hunting time again. Your prey creature will stay the same.",
    ["pickSpecificPrey"] =
    "If you like to select another prey creature, click here to choose from all available creatures.\nThe newly selected prey will be active for 2 hours hunting time again.",
    ["rerollButton"] =
    "If you like to select another prey creature, click here to get a new list with 9 creatures to choose from.\nThe newly selected prey will be active for 2 hours hunting time again.",
    ["rerollButtonBonus"] =
    "If you like to select another prey crature, click here to get a new list with 9 creatures to choose from.\nThe newly selected prey will be active for 2 hours hunting time again.",
    ["preyCandidate"] = "Select a new prey creature for the next 2 hours hunting time.",
    ["choosePreyButton"] =
    "Click on this button to confirm selected monsters as your prey creature for the next 2 hours hunting time.",
    ["choosePreyButtonBonus"] =
    "Click on this button to confirm %s as your prey creature for the next 2 hours hunting time.\nYou will benefit from the following bonus: %s",
    ["selectionList"] =
    "Select a new prey creature for the next 2 hours hunting time.\nYou will benefit from the following bonus: %s",
    ["rerollBonus"] =
    "Click here to get a bonus with a higher value. The bonus for your prey will be selected randomly from one of the following: damage boost, damage reduction, bonus XP, improved loot. Your prey will be active for 2 hours hunting time again. Your prey creature will stay the same.",
    ["autoRerollCheck"] =
    "If you tick this option, you will automatically roll for a new prey bonus whenever your prey is about to expire.\nThis will also extend the hunting time of your active prey creature for another 2 hours.",
    ["lockPreyCheck"] =
    "If you tick this option, you will lock your prey creature and prey bonus.\nThis means whenever your prey is about to expire its hunting time is simply extended by another 2 hours.",
    ["time"] = "You will get your next Free List Reroll in %s.\nYou get a Free List Reroll every 20 hours for each slot.",
    ["time_free"] = "Your next List Reroll is free of charge.\nYou get a Free List Reroll every 20 hours for each slot.",
    ["bonusMessage"] = "damage boost, damage reduction, bonus XP, improved loot."
}

function PreyController:clearDescription()
    self.description = ""
end

function PreyController:onHover(slotId, currentType)
    local slot = PreyController.preyData[slotId + 1]
    local description = ""
    if currentType == "pickSpecificPrey" or currentType == "rerollButton" or currentType == "preyCandidate" then
        description = descriptionTable[currentType]
        local footer = string.format("\nYour current bonus +%d%% %s will not be affected.",
            slot.bonusValue or 0,
            getBonusDescription(slot.bonusType) or "")
        description = description .. footer
    elseif currentType == "time" then
        description = string.format(description, slot.timeUntilFreeReroll or "00:00")
    elseif currentType == "selectionList" then
        description = string.format(descriptionTable[currentType], descriptionTable["bonusMessage"])
    elseif currentType == "choosePreyButtonBonus" then
        if slot.previewMonster and slot.previewMonster.name then
            description = string.format(descriptionTable[currentType], slot.previewMonster.name,
                descriptionTable["bonusMessage"])
        end
    elseif descriptionTable[currentType] then
        description = descriptionTable[currentType]
    end

    if slotId and not currentType then
        self.description = PreyController.preyData[slotId + 1].description
        return
    end

    self.description = description
end

function check()
    if g_game.getFeature(GamePrey) then
        if not preyButton then
            preyButton = modules.game_mainpanel.addToggleButton('preyButton', tr('Prey Dialog'),
                '/images/options/button_preydialog', toggle)
        end
        -- if not preyTrackerButton then
        --     preyTrackerButton = modules.game_mainpanel.addToggleButton('preyTrackerButton', tr('Prey Tracker'),
        --         '/images/options/button_prey', toggleTracker)
        -- end
    elseif preyButton then
        preyButton:destroy()
        preyButton = nil
    end
end

local function onResourcesBalanceChange()
    PreyController:handleResources()
end

function PreyController:onInit()
    PreyController:loadHtml('prey_html.html')
    if PreyController.ui then
        PreyController.ui:hide()
    end
    check()

    self:registerEvents(g_game, {
        onPreyActive = onPreyActive,
        onPreyRerollPrice = onPreyRerollPrice,
        onPreyListSelection = onPreyListSelection,
        onPreySelection = onPreySelection,
        onPreyInactive = onPreyInactive,
        onPreySelectionChangeMonster = onPreySelectionChangeMonster,
        onPreyLocked = onPreyLocked,
        onResourcesBalanceChange = onResourcesBalanceChange,
    })
end

local Helper = {}

function Helper.handleFormatPrice(price)
    local priceText = "Free"
    if price > 0 then
        if price >= 1000000 then
            local millions = math.floor(price / 1000000)
            local remainder = price % 1000000
            if remainder >= 500000 then
                priceText = string.format('%d.5 M', millions)
            elseif remainder >= 100000 then
                priceText = string.format('%d M', millions)
            else
                priceText = string.format('%d M', math.max(1, millions))
            end
        elseif price >= 100000 then
            local thousands = math.floor(price / 1000)
            local remainder = price % 1000
            if remainder >= 500 then
                priceText = string.format('%d.5 k', thousands)
            elseif remainder >= 100 then
                priceText = string.format('%d k', thousands)
            else
                priceText = string.format('%d k', math.max(1, thousands))
            end
        else
            priceText = tostring(price)
        end
    end

    return priceText
end

local function clamp(x, a, b) return math.max(a, math.min(b, x)) end
local function round(x) return math.floor(x + 0.5) end
Helper.freeRerollBarWidth = 60
Helper.freeRerollHours = 20
Helper.activePreyBarWidth = 205
Helper.activePreyHours = 2
function Helper.getProgress(timeleft, hours, maxWidth)
    if timeleft == 0 then return 0 end
    local total = hours * 60 * 60
    timeleft = timeleft > total and 0 or timeleft
    local width = clamp((timeleft / total) * maxWidth, 0, maxWidth)

    return round(width)
end

function onPreyLocked(slot, unlockState, timeUntilFreeReroll, wildcards)
    local slotId = slot + 1
    PreyController:clearSlotTypeHistory(slotId)
    PreyController.preyData[slotId].type = SLOT_STATE_LOCKED
    PreyController.preyData[slotId].stars = 0
    PreyController.preyData[slotId].monsterName = "Locked"
    PreyController.preyData[slotId].preyType = getBigIconPath(nil, true)
    PreyController:handleResources({ skipRequest = true })
end

function Helper.fillTinyMonsterList(slotId, names, outfits)
    local raceList = {}

    for i = 1, 9 do
        table.insert(raceList, {
            name = names[i],
            outfit = outfits[i],
            raceId = outfits[i].type,
            slotId = slotId,
            index = i,
        })
    end

    return raceList
end

function onPreySelectionChangeMonster(slot, names, outfits, bonusType, bonusValue, bonusGrade, timeUntilFreeReroll,
                                      wildcards, option)
    g_logger.info(("SLOT_STATE_SELECTION_CHANGE_MONSTER > Slot %d, timeUntilFreeReroll %d, wildcards %d, monsterNames %d, monsterLookTypes %d")
        :format(slot, timeUntilFreeReroll,
            wildcards, #names, #outfits))

    local slotId = slot + 1
    PreyController:clearSlotTypeHistory(slotId)
    PreyController.preyData[slotId].raceList = Helper.fillTinyMonsterList(slot, names, outfits)

    PreyController.preyData[slotId].slotId = slot
    PreyController.preyData[slotId].monsterName = "Select your prey creature"
    PreyController.preyData[slotId].type = SLOT_STATE_SELECTION_CHANGE_MONSTER
    timeUntilFreeReroll = timeUntilFreeReroll > 720000 and 0 or timeUntilFreeReroll
    PreyController.preyData[slotId].percentFreeReroll = Helper.getProgress(timeUntilFreeReroll, Helper.freeRerollHours,
        Helper.freeRerollBarWidth)
    PreyController.preyData[slotId].timeUntilFreeReroll = timeleftTranslation(timeUntilFreeReroll)
    local isFreeReroll = timeUntilFreeReroll == 0
    PreyController.preyData[slotId].isFreeReroll = isFreeReroll
    PreyController.preyData[slotId].disableFreeReroll = PreyController.rawRerollGoldPrice > PreyController.rawPlayerGold and
        not isFreeReroll
    PreyController:handleResources({ skipRequest = true })
end

function onPreyInactive(slot, timeUntilFreeReroll, wildcards)
    g_logger.info("SLOT_STATE_INACTIVE > Slot " ..
        slot .. ", timeUntilFreeReroll " .. timeUntilFreeReroll .. ", wildcards " .. wildcards)
    PreyController:handleResources({ skipRequest = true })
end

function onPreyRerollPrice(rerollGoldPrice, rerollBonusPrice, pickSpecificPrice)
    rerollGoldPrice = rerollGoldPrice or 0
    pickSpecificPrice = pickSpecificPrice or 5
    PreyController.rawRerollGoldPrice = rerollGoldPrice or 0
    PreyController.rerollGoldPrice = Helper.handleFormatPrice(rerollGoldPrice)
    PreyController.rerollBonusPrice = rerollBonusPrice or 1
    PreyController.pickSpecificPrice = pickSpecificPrice
    PreyController.lockPreyPrice = pickSpecificPrice
    PreyController:handleResources({ skipRequest = true })
end

local function buildRaceEntry(raceId, slotId, index)
    local raceData = g_things.getRaceData(raceId)
    local name = raceData and raceData.name or nil

    if name and name ~= '' then
        name = capitalFormatStr(name)
    else
        name = string.format('Unknown Creature (%d)', raceId)
    end

    local outfit = raceData and raceData.outfit or nil
    local realSize

    if outfit and outfit.type then
        local creatureType = g_things.getThingType(outfit.type, ThingCategoryCreature)
        realSize = creatureType and creatureType:getRealSize() or nil
    end

    return {
        raceId = raceId,
        name = name,
        searchName = name:lower(),
        outfit = outfit,
        realSize = realSize,
        slotId = slotId,
        index = index,
        selected = false,
    }
end

function PreyController:handleSelect(slot, race)
    PreyController.preyData[slot + 1].previewMonster = {
        raceId = race.raceId,
        outfit = race.outfit,
        name = race.name,
        index = race.index
    }
    self.preyData[slot + 1].monsterName = ("Selected: %s"):format(race.name)

    for i = 1, #self.preyData[slot + 1].raceList do
        if self.preyData[slot + 1].raceList[i].index == race.index then
            self.preyData[slot + 1].raceList[i].selected = true
        else
            self.preyData[slot + 1].raceList[i].selected = false
        end
    end
end

-- a unique table for all debounce timers in the module
PreyController._debounceTimers = PreyController._debounceTimers or {}

PreyController._raceListPagination = PreyController._raceListPagination or {}

-- simple key-based debounce utility
function PreyController:debounce(key, waitMs, fn)
    waitMs = waitMs or 300
    local t = self._debounceTimers[key]
    if t then removeEvent(t) end
    self._debounceTimers[key] = scheduleEvent(function()
        self._debounceTimers[key] = nil
        fn()
    end, waitMs)
end

local function getSlotIndex(slotId)
    return (slotId or 0) + 1
end

function PreyController:getRaceListPagination(slotId)
    local slotIndex = getSlotIndex(slotId)
    self._raceListPagination[slotIndex] = self._raceListPagination[slotIndex] or {
        chunkSize = RACE_LIST_CHUNK_SIZE,
        loaded = 0,
        source = nil
    }
    local pagination = self._raceListPagination[slotIndex]
    pagination.chunkSize = pagination.chunkSize or RACE_LIST_CHUNK_SIZE
    return pagination
end

function PreyController:resetRaceListView(slotId, sourceList)
    local slotIndex = getSlotIndex(slotId)
    local slot = self.preyData[slotIndex]
    if not slot then return end

    local pagination = self:getRaceListPagination(slotId)
    pagination.loaded = 0
    pagination.source = sourceList or slot.raceListOriginal or {}

    slot.raceList = {}
    self:appendRaceListChunk(slotId)
end

function PreyController:appendRaceListChunk(slotId)
    local slotIndex = getSlotIndex(slotId)
    local slot = self.preyData[slotIndex]
    if not slot then return false end

    local pagination = self:getRaceListPagination(slotId)
    local source = pagination.source or slot.raceListOriginal or {}
    local current = slot.raceList or {}

    if pagination.loaded >= #source then
        slot.raceList = current
        return false
    end

    local chunkSize = pagination.chunkSize or RACE_LIST_CHUNK_SIZE
    local startIndex = pagination.loaded + 1
    local endIndex = math.min(startIndex + chunkSize - 1, #source)

    for i = startIndex, endIndex do
        local data = source[i]
        if data then
            data.index = i
            table.insert(current, data)
        end
    end

    pagination.loaded = endIndex
    slot.raceList = current

    return pagination.loaded < #source
end

function PreyController:shouldLoadMoreRaces(slotId, hoveredIndex)
    local slotIndex = getSlotIndex(slotId)
    local slot = self.preyData[slotIndex]
    if not slot then return false end

    local pagination = self:getRaceListPagination(slotId)
    local source = pagination.source or slot.raceListOriginal or {}

    if pagination.loaded >= #source then
        return false
    end

    if not hoveredIndex then
        return true
    end

    local chunkSize = pagination.chunkSize or RACE_LIST_CHUNK_SIZE
    local threshold = math.max(1, pagination.loaded - math.floor(chunkSize / 2))
    return hoveredIndex >= threshold
end

-- clear timers on terminate to prevent leaks
function PreyController:onTerminate()
    if self._debounceTimers then
        for _, ev in pairs(self._debounceTimers) do
            if ev then removeEvent(ev) end
        end
        self._debounceTimers = {}
    end

    self._raceListPagination = {}

    if preyButton then
        preyButton:destroy()
        preyButton = nil
    end
    if preyTrackerButton then
        preyTrackerButton:destroy()
        preyTrackerButton = nil -- to be safely garbage collected
    end

    if self.ui then
        self:unloadHtml()
    end
end

function PreyController:onSearchMonster(slotId, value)
    value = value or ''
    local slot = self.preyData[slotId + 1]
    if slot.previewMonster and slot.previewMonster.index then
        local previewIndex = slot.previewMonster.index
        local currentList = self.preyData[slotId + 1].raceList or {}
        if currentList[previewIndex] then
            currentList[previewIndex].selected = false
        elseif slot.raceListOriginal and slot.raceListOriginal[previewIndex] then
            slot.raceListOriginal[previewIndex].selected = false
        end
    end
    self.preyData[slotId + 1].previewMonster = {}
    self.preyData[slotId + 1].monsterName = "Select your prey creature"
    local raceListOriginal = self.preyData[slotId + 1].raceListOriginal

    if #value <= 0 then
        self.preyData[slotId + 1].searchValue = false
        self.preyData[slotId + 1].searchValueText = ''
        local k = 'search:' .. tostring(slotId)
        local t = self._debounceTimers[k]
        if t then
            removeEvent(t); self._debounceTimers[k] = nil
        end

        self:resetRaceListView(slotId, raceListOriginal)
        self.preyData[slotId + 1].clearButton = false
        return
    end
    self.preyData[slotId + 1].searchValue = true
    self:debounce('search:' .. tostring(slotId), 300, function()
        local searchValue = value:lower()
        self.preyData[slotId + 1].searchValueText = searchValue
        local filtered = {}
        for _, race in ipairs(raceListOriginal) do
            local name = (race.name or ''):lower()
            if name:find(searchValue, 1, true) then
                table.insert(filtered, race)
            end
        end
        self:resetRaceListView(slotId, filtered)
    end)
end

function onPreyListSelection(slot, raceList, nextFreeReroll, wildcards)
    g_logger.info(("SLOT_STATE_LIST_SELECTION > Slot %d, nextFreeReroll %d, wildcards %d"):format(slot, nextFreeReroll,
        wildcards))

    local slotId = slot + 1
    PreyController:clearSlotTypeHistory(slotId)
    local activeRaceIds = {}
    for _, preySlot in ipairs(PreyController.preyData) do
        if preySlot and preySlot.type == SLOT_STATE_ACTIVE and preySlot.monsterName then
            activeRaceIds[preySlot.monsterName] = true
        end
    end

    for i, raceId in ipairs(raceList) do
        local race = buildRaceEntry(raceId, slot, i)
        if not activeRaceIds[race.name] then
            table.insert(PreyController.preyData[slotId].raceListOriginal, race)
        end
    end

    table.sort(PreyController.preyData[slotId].raceListOriginal, function(a, b)
        return a.name < b.name
    end)

    for i = 1, #PreyController.preyData[slotId].raceListOriginal do
        local data = PreyController.preyData[slotId].raceListOriginal[i]
        data.index = i
    end

    PreyController:resetRaceListView(slot, PreyController.preyData[slotId].raceListOriginal)

    PreyController.preyData[slotId].slotId = slot
    PreyController.preyData[slotId].monsterName = "Select your prey creature"
    PreyController.preyData[slotId].type = SLOT_STATE_LIST_SELECTION
    PreyController:handleResources({ skipRequest = true })
end

function onPreySelection(slot, names, outfits, timeUntilFreeReroll, wildcards)
    g_logger.info(("SLOT_STATE_SELECTION > Slot %d, nextFreeReroll %d, wildcards %d, monsterNames %d, monsterLookTypes %d")
        :format(slot, timeUntilFreeReroll,
            wildcards, #names, #outfits))
    local slotId = slot + 1
    PreyController:clearSlotTypeHistory(slotId)

    timeUntilFreeReroll = timeUntilFreeReroll > 720000 and 0 or timeUntilFreeReroll
    PreyController.preyData[slotId].raceList = Helper.fillTinyMonsterList(slot, names, outfits)
    PreyController.preyData[slotId].monsterName = "Select your prey creature"
    PreyController.preyData[slotId].slotId = slot
    PreyController.preyData[slotId].percentFreeReroll = Helper.getProgress(timeUntilFreeReroll, Helper.freeRerollHours,
        Helper.freeRerollBarWidth)
    PreyController.preyData[slotId].timeUntilFreeReroll = timeleftTranslation(timeUntilFreeReroll)
    PreyController.preyData[slotId].type = SLOT_STATE_SELECTION
    PreyController.preyData[slotId].monsterName = "Select your prey creature"
    local isFreeReroll = timeUntilFreeReroll == 0
    PreyController.preyData[slotId].isFreeReroll = isFreeReroll
    PreyController.preyData[slotId].disableFreeReroll = PreyController.rawRerollGoldPrice > PreyController.rawPlayerGold and
        not isFreeReroll
    PreyController:handleResources({ skipRequest = true })
end

function PreyController:onGameStart()
    if g_game.getFeature(GamePrey) then
        check()
    else
        PreyController:scheduleEvent(function()
            g_modules.getModule("game_prey_html"):unload()
        end, 100, "unloadModule")
    end
end

function capitalFormatStr(str)
    local formatted = ''
    str = string.split(str, ' ')
    for i, word in ipairs(str) do
        formatted = formatted .. ' ' .. (string.gsub(word, '^%l', string.upper))
    end
    return formatted:trim()
end

function getBonusDescription(bonusType)
    if bonusType == PREY_BONUS_DAMAGE_BOOST then
        return 'Damage Boost'
    elseif bonusType == PREY_BONUS_DAMAGE_REDUCTION then
        return 'Damage Reduction'
    elseif bonusType == PREY_BONUS_XP_BONUS then
        return 'XP Bonus'
    elseif bonusType == PREY_BONUS_IMPROVED_LOOT then
        return 'Improved Loot'
    end
end

function timeleftTranslation(timeleft)
    if timeleft == 0 then
        return "Free"
    end
    local hours = string.format('%02.f', math.floor(timeleft / 3600))
    local mins = string.format('%02.f', math.floor(timeleft / 60 - (hours * 60)))
    return hours .. ':' .. mins
end

function getTooltipBonusDescription(bonusType, bonusValue)
    if bonusType == PREY_BONUS_DAMAGE_BOOST then
        return 'You deal +' .. bonusValue .. '% extra damage against your prey creature.'
    elseif bonusType == PREY_BONUS_DAMAGE_REDUCTION then
        return 'You take ' .. bonusValue .. '% less damage from your prey creature.'
    elseif bonusType == PREY_BONUS_XP_BONUS then
        return 'Killing your prey creature rewards +' .. bonusValue .. '% extra XP.'
    elseif bonusType == PREY_BONUS_IMPROVED_LOOT then
        return 'Your creature has a +' .. bonusValue .. '% chance to drop additional loot.'
    end
end

PreyController.description = ""

function getBigIconPath(bonusType, locked)
    local path = '/images/game/prey/'

    if locked then
        return path .. 'prey_bignobonus'
    end

    if bonusType == PREY_BONUS_DAMAGE_BOOST then
        return path .. 'prey_bigdamage'
    elseif bonusType == PREY_BONUS_DAMAGE_REDUCTION then
        return path .. 'prey_bigdefense'
    elseif bonusType == PREY_BONUS_XP_BONUS then
        return path .. 'prey_bigxp'
    elseif bonusType == PREY_BONUS_IMPROVED_LOOT then
        return path .. 'prey_bigloot'
    end
end

function onPreyActive(slot, currentHolderName, currentHolderOutfit, bonusType, bonusValue, bonusGrade, rawTimeleft,
                      rawTimeUntilFreeReroll, wildcards, option)
    local slotId = slot + 1
    PreyController:clearSlotTypeHistory(slotId)
    local timeleft = timeleftTranslation(rawTimeleft)
    rawTimeUntilFreeReroll = rawTimeUntilFreeReroll > 720000 and 0 or rawTimeUntilFreeReroll

    local description = ("Creature: %s\nDuration: %s\nValue: %d/10\nType: %s\n%s")
        :format(
            currentHolderName,
            timeleft,
            bonusGrade,
            getBonusDescription(bonusType),
            getTooltipBonusDescription(bonusType, bonusValue)
        )

    PreyController.preyData[slotId].slotId = slot
    PreyController.preyData[slotId].monsterName = capitalFormatStr(currentHolderName)
    PreyController.preyData[slotId].raceId = currentHolderOutfit.type
    PreyController.preyData[slotId].outfit = currentHolderOutfit
    PreyController.preyData[slotId].autoReroll = option == 1
    PreyController.preyData[slotId].lockPrey = option == 2
    PreyController.preyData[slotId].description = description
    PreyController.preyData[slotId].stars = bonusGrade
    PreyController.preyData[slotId].percent = Helper.getProgress(rawTimeleft, Helper.activePreyHours,
        Helper.activePreyBarWidth)
    PreyController.preyData[slotId].percentFreeReroll = Helper.getProgress(rawTimeUntilFreeReroll, Helper
        .freeRerollHours,
        Helper.freeRerollBarWidth)
    PreyController.preyData[slotId].timeleft = timeleft
    PreyController.preyData[slotId].type = SLOT_STATE_ACTIVE
    PreyController.preyData[slotId].preyType = getBigIconPath(bonusType)
    PreyController.preyData[slotId].bonusValue = bonusValue
    PreyController.preyData[slotId].bonusType = bonusType
    PreyController.preyData[slotId].timeUntilFreeReroll = timeleftTranslation(rawTimeUntilFreeReroll)
    local isFreeReroll = rawTimeUntilFreeReroll == 0
    PreyController.preyData[slotId].isFreeReroll = isFreeReroll
    PreyController.preyData[slotId].disableFreeReroll = PreyController.rawRerollGoldPrice > PreyController.rawPlayerGold and
        not isFreeReroll
    PreyController:handleResources({ skipRequest = true })
end

function PreyController:onMouseWheel(slotId, hoveredIndex)
    if not self:shouldLoadMoreRaces(slotId, hoveredIndex) then
        return
    end

    self:debounce(('scroll:' .. tostring(slotId)), 60, function()
        self:appendRaceListChunk(slotId)
    end)
end

local confirmWindow
local function showPreyConfirmationWindow(title, description, confirmAction, afterCloseAction, cancelAction)
    local function closeWindow()
        if cancelAction and type(cancelAction) == "function" then
            cancelAction()
        end
        if confirmWindow then
            confirmWindow:destroy()
            confirmWindow = nil
            PreyController:handleResources()
            if afterCloseAction then
                afterCloseAction()
                afterCloseAction = nil
            end
        end
    end
    if confirmWindow then
        closeWindow()
    end

    local function confirm()
        if confirmAction then
            confirmAction()
        end
        closeWindow()
    end

    confirmWindow = displayGeneralBox(tr(title), description, {
        {
            text = tr('No'),
            callback = closeWindow
        },
        {
            text = tr('Yes'),
            callback = confirm
        },
    }, confirm, closeWindow)

    if confirmWindow then
        confirmWindow.onDestroy = function()
            PreyController:handleResources()
            if afterCloseAction then
                afterCloseAction()
                afterCloseAction = nil
            end
        end
    else
        PreyController:handleResources()
        if afterCloseAction then
            afterCloseAction()
            afterCloseAction = nil
        end
    end
end

function PreyController:handleRerollBonus(slotId)
    local description = tr(string.format(
        'Are you sure you want to use %s of your remaining %s Prey Wildcards?',
        self.rerollBonusPrice, self.wildcards
    ))

    local wasVisible = self.ui and self.ui:isVisible()

    local function restorePreyWindow()
        if wasVisible and self.ui then
            self.ui:show()
            self.ui:raise()
            self.ui:focus()
        end
    end

    showPreyConfirmationWindow('Confirmation of Using Prey Wildcards', description, function()
        g_game.preyAction(slotId, PREY_ACTION_BONUSREROLL, 0)
    end, restorePreyWindow)
end

function PreyController:handlePickSpecific(slotId)
    local description = tr(string.format(
        'Are you sure you want to use %s of your remaining %s Prey Wildcards?',
        self.pickSpecificPrice, self.wildcards
    ))

    local wasVisible = self.ui and self.ui:isVisible()

    local function restorePreyWindow()
        if wasVisible and self.ui then
            self.ui:show()
            self.ui:raise()
            self.ui:focus()
        end
    end

    showPreyConfirmationWindow('Confirmation of Using Prey Wildcards', description, function()
        g_game.preyAction(slotId, PREY_ACTION_REQUEST_ALL_MONSTERS, 0)
    end, restorePreyWindow)
end

function PreyController:openStore(offerId)
    if self.ui and self.ui:isVisible() then
        self:hide()
    end

    -- offerId = 0 > Permanent slot
    -- offerId = 1 > wildcards

    modules.game_mainpanel.toggleStore()
    PreyController:scheduleEvent(function()
        g_game.sendRequestUsefulThings(offerId)
    end, 25, "LazyHtml")
end

function PreyController:onChooseMonster(slotId)
    local slot = self.preyData[slotId + 1]
    local previewMonster = slot.previewMonster
    if not previewMonster or not previewMonster.raceId then return end

    if slot.type == SLOT_STATE_LIST_SELECTION then
        g_game.preyAction(slotId, PREY_ACTION_CHANGE_FROM_ALL, previewMonster.raceId)
    elseif slot.type == SLOT_STATE_SELECTION or slot.type == SLOT_STATE_SELECTION_CHANGE_MONSTER then
        g_game.preyAction(slotId, PREY_ACTION_MONSTERSELECTION, previewMonster.index - 1)
    end
end

function PreyController:listReroll(slotId)
    local slot = self.preyData[slotId + 1]

    local description = ""

    if slot.timeUntilFreeReroll == "Free" then
        description = "Are you sure you want to use the Free List Reroll?"
    else
        description = string.format(
            "Do you want to spend %s gold for a List Reroll?\nYou currently have %s gold available for the purchase.",
            comma_value(self.rawRerollGoldPrice),
            self.playerGold
        )
    end

    local wasVisible = self.ui and self.ui:isVisible()

    local function restorePreyWindow()
        if wasVisible and self.ui then
            self.ui:show()
            self.ui:raise()
            self.ui:focus()
        end
    end

    showPreyConfirmationWindow('Confirmation of Using List Reroll', description, function()
        g_game.preyAction(slotId, PREY_ACTION_LISTREROLL, 0)
    end, restorePreyWindow)
end

function PreyController:autoOptions(slotId, option)
    local field = ""
    if option == PREY_OPTION_TOGGLE_AUTOREROLL then
        field = "autoReroll"
    else
        field = "lockPrey"
    end

    if self.preyData[slotId + 1][field] then
        self.preyData[slotId + 1][field] = false
        g_game.preyAction(slotId, PREY_ACTION_OPTION, PREY_OPTION_UNTOGGLE)
        return
    end

    local description = ""

    if option == PREY_OPTION_TOGGLE_AUTOREROLL then
        description = string.format(
            "Do you want to enable the Automatic Bonus Reroll?\nEach time the Automatic Bonus Reroll is triggered, %d of your Prey Wildcards will be consumed.",
            self.rerollBonusPrice, self.wildcards)
    elseif option == PREY_OPTION_TOGGLE_LOCK_PREY then
        description = string.format(
            "Do you want to enable the Lock Prey?\nEach time the Lock Prey is triggered, %d of your Prey Wildcards will be consumed.",
            self.lockPreyPrice, self.wildcards)
    end

    local shouldRestoreWindow = self.ui and self.ui:isVisible()
    if shouldRestoreWindow then
        self:hide()
    end

    local function restorePreyWindow()
        if shouldRestoreWindow then
            show()
        end
    end

    showPreyConfirmationWindow('Confirmation of Using List Reroll', description, function()
        self.preyData[slotId + 1][field] = not self.preyData[slotId + 1][field]

        if self.preyData[slotId + 1][field] then
            if field == "autoReroll" then
                self.preyData[slotId + 1]["lockPrey"] = false
            else
                self.preyData[slotId + 1]["autoReroll"] = false
            end
        end
        g_game.preyAction(slotId, PREY_ACTION_OPTION, option)
    end, restorePreyWindow, function()
        self.preyData[slotId + 1][field] = self.preyData[slotId + 1][field]
    end)
end

function PreyController:getColor(slot, currentType)
    if currentType == "gold" then
        if slot.isFreeReroll then
            return "#707070"
        end

        if slot.disableFreeReroll then
            return "#d33c3c"
        end
        return "#c0c0c0"
    end

    if currentType == "pickSpecificPrice" then
        if self.pickSpecificPrice > self.wildcards then
            return "#d33c3c"
        end
    end

    if currentType == "rerollBonusPrice" then
        if self.rerollBonusPrice > self.wildcards then
            return "#d33c3c"
        end
    end

    return "#c0c0c0"
end
