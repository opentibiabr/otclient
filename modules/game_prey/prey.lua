-- sponsored by kivera-global.com
-- remade by Vithrax#5814
Prey = {}
preyWindow = nil
preyButton = nil
local preyTrackerButton
local msgWindow
local bankGold = 0
local inventoryGold = 0
local rerollPrice = 0
local bonusRerolls = 0

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

local preyDescription = {}

local raceEntriesBySlot = {}
local selectedRaceEntryBySlot = {}
local selectedRaceWidgetBySlot = {}
local raceSearchTextsBySlot = {}

local refreshRaceList
local setRaceSelection
local updateRaceSelectionDisplay
local restoreRaceListItemBackground
local setWidgetTreePhantom
local updatePickSpecificPreyButton
local refreshRerollButtonState

function bonusDescription(bonusType, bonusValue, bonusGrade)
    if bonusType == PREY_BONUS_DAMAGE_BOOST then
        return 'Damage bonus (' .. bonusGrade .. '/10)'
    elseif bonusType == PREY_BONUS_DAMAGE_REDUCTION then
        return 'Damage reduction bonus (' .. bonusGrade .. '/10)'
    elseif bonusType == PREY_BONUS_XP_BONUS then
        return 'XP bonus (' .. bonusGrade .. '/10)'
    elseif bonusType == PREY_BONUS_IMPROVED_LOOT then
        return 'Loot bonus (' .. bonusGrade .. '/10)'
    else
        return 'Unknown bonus'
    end
    return 'Unknown bonus'
end

function timeleftTranslation(timeleft, forPreyTimeleft) -- in seconds
    if timeleft == 0 then
        if forPreyTimeleft then
            return tr('infinite bonus')
        end
        return tr('Free')
    end
    local hours = string.format('%02.f', math.floor(timeleft / 3600))
    local mins = string.format('%02.f', math.floor(timeleft / 60 - (hours * 60)))
    return hours .. ':' .. mins
end

function init()
    connect(g_game, {
        onGameStart = check,
        onGameEnd = onGameEnd,
        onResourcesBalanceChange = Prey.onResourcesBalanceChange,
        onPreyFreeRerolls = onPreyFreeRerolls,
        onPreyTimeLeft = onPreyTimeLeft,
        onPreyRerollPrice = onPreyRerollPrice,
        onPreyLocked = onPreyLocked,
        onPreyInactive = onPreyInactive,
        onPreyActive = onPreyActive,
        onPreySelection = onPreySelection,
        onPreySelectionChangeMonster = onPreySelectionChangeMonster,
        onPreyListSelection = onPreyListSelection,
        onPreyWildcardSelection = onPreyWildcardSelection
    })

    preyWindow = g_ui.displayUI('prey')
    preyWindow:hide()
    preyTracker = g_ui.createWidget('PreyTracker', modules.game_interface.getRightPanel())
    preyTracker:setup()
    preyTracker:setContentMaximumHeight(110)
    preyTracker:setContentMinimumHeight(70)
    preyTracker:hide()

    -- Hide buttons similar to unjustifiedpoints implementation
    local toggleFilterButton = preyTracker:recursiveGetChildById('toggleFilterButton')
    if toggleFilterButton then
        toggleFilterButton:setVisible(false)
    end

    local contextMenuButton = preyTracker:recursiveGetChildById('contextMenuButton')
    if contextMenuButton then
        contextMenuButton:setVisible(false)
    end

    local newWindowButton = preyTracker:recursiveGetChildById('newWindowButton')
    if newWindowButton then
        newWindowButton:setVisible(false)
    end

    -- Set up the miniwindow title and icon
    local titleWidget = preyTracker:getChildById('miniwindowTitle')
    if titleWidget then
        titleWidget:setText('Prey')
    else
        -- Fallback to old method if miniwindowTitle doesn't exist
        preyTracker:setText('Prey')
    end

    local iconWidget = preyTracker:getChildById('miniwindowIcon')
    if iconWidget then
        iconWidget:setImageSource('/images/game/prey/icon-prey-widget')
    end

    -- Position lockButton where toggleFilterButton was (to the left of minimize button)
    local lockButton = preyTracker:recursiveGetChildById('lockButton')
    local minimizeButton = preyTracker:recursiveGetChildById('minimizeButton')

    if lockButton and minimizeButton then
        lockButton:breakAnchors()
        lockButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
        lockButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
        lockButton:setMarginRight(7) -- Same margin as toggleFilterButton had
        lockButton:setMarginTop(0)
    end

    if g_game.isOnline() then
        check()
    end
    setUnsupportedSettings()
end

local pickSpecificPreyBonusBySlot = {}

local pickSpecificPreyDescriptionDefault =
'If you like to select another prey creature, click here to choose from all available creatures.\nThe newly selected prey will be active for 2 hours hunting time again.\nYour current bonus will not be affected.'
local pickSpecificPreyDescriptionTemplate =
'If you like to select another prey creature, click here to choose from all available creatures.\nThe newly selected prey will be active for 2 hours hunting time again.\nYour current bonus +%s%% %s will not be affected.'

local descriptionTable = {
    ['shopPermButton'] =
    'Go to the Store to purchase the Permanent Prey Slot. Once you have completed the purchase, you can activate a prey here, no matter if your character is on a free or a Premium account.',
    ['shopTempButton'] = 'You can activate this prey whenever your account has Premium Status.',
    ['preyWindow'] = '',
    ['noBonusIcon'] =
    'This prey is not available for your character yet.\nCheck the large blue button(s) to learn how to unlock this prey slot',
    ['selectPrey'] =
    'Click here to get a bonus with a higher value. The bonus for your prey will be selected randomly from one of the following: damage boost, damage reduction, bonus XP, improved loot. Your prey will be active for 2 hours hunting time again. Your prey creature will stay the same.',
    ['pickSpecificPrey'] = pickSpecificPreyDescriptionDefault,
    ['rerollButton'] =
    'If you like to select another prey crature, click here to get a new list with 9 creatures to choose from.\nThe newly selected prey will be active for 2 hours hunting time again.',
    ['preyCandidate'] = 'Select a new prey creature for the next 2 hours hunting time.',
    ['choosePreyButton'] =
    'Click on this button to confirm selected monsters as your prey creature for the next 2 hours hunting time.',
    ['automaticBonusReroll'] =
    'Do you want to enable the Automatic Bonus Reroll?\nEach time the Automatic Bonus Reroll is triggered, 1 of your Prey Wildcards will be consumed.',
    ['preyLock'] =
    'Do you want to enable the Lock Prey?\nEach time the Lock Prey is triggered, 5 of your Prey Wildcards will be consumed.'
}

local function getSlotIndexFromWidget(widget)
    while widget do
        local id = widget:getId()
        if id then
            local slotNumber = id:match('^slot(%d+)$')
            if slotNumber then
                return tonumber(slotNumber) - 1
            end
        end
        widget = widget:getParent()
    end

    return nil
end

local function getPickSpecificPreyDescription(slot)
    local bonusInfo = pickSpecificPreyBonusBySlot[slot]

    if bonusInfo then
        local bonusName = getBonusDescription(bonusInfo.type)

        if bonusName then
            return string.format(pickSpecificPreyDescriptionTemplate, bonusInfo.value, bonusName)
        end
    end

    return pickSpecificPreyDescriptionDefault
end

local function setPickSpecificPreyBonus(slot, bonusType, bonusValue)
    if slot == nil then
        return
    end

    if bonusType and bonusType ~= PREY_BONUS_NONE and bonusValue ~= nil then
        pickSpecificPreyBonusBySlot[slot] = {
            type = bonusType,
            value = bonusValue
        }
    else
        pickSpecificPreyBonusBySlot[slot] = nil
    end
end

function onHover(widget)
    if type(widget) == 'string' then
        return preyWindow.description:setText(descriptionTable[widget])
    elseif type(widget) == 'number' then
        local slot = 'slot' .. (widget + 1)
        local tracker = preyTracker.contentsPanel[slot]
        local desc = tracker.time:getTooltip()
        desc = desc:sub(1, desc:len() - 46)
        return preyWindow.description:setText(desc)
    end
    if widget and widget:isVisible() then
        local id = widget:getId()
        if id == 'pickSpecificPrey' then
            local slot = getSlotIndexFromWidget(widget)
            if slot then
                preyWindow.description:setText(getPickSpecificPreyDescription(slot))
                return
            end
        end

        local desc = descriptionTable[id]
        if desc then
            preyWindow.description:setText(desc)
        end
    end
end

function terminate()
    disconnect(g_game, {
        onGameStart = check,
        onGameEnd = onGameEnd,
        onResourcesBalanceChange = Prey.onResourcesBalanceChange,
        onPreyFreeRerolls = onPreyFreeRerolls,
        onPreyTimeLeft = onPreyTimeLeft,
        onPreyRerollPrice = onPreyRerollPrice,
        onPreyLocked = onPreyLocked,
        onPreyInactive = onPreyInactive,
        onPreyActive = onPreyActive,
        onPreySelection = onPreySelection,
        onPreySelectionChangeMonster = onPreySelectionChangeMonster,
        onPreyListSelection = onPreyListSelection,
        onPreyWildcardSelection = onPreyWildcardSelection
    })

    if preyButton then
        preyButton:destroy()
    end
    if preyTrackerButton then
        preyTrackerButton:destroy()
    end
    preyWindow:destroy()
    preyTracker:destroy()
    if msgWindow then
        msgWindow:destroy()
        msgWindow = nil
    end
end

local n = 0
function setUnsupportedSettings()
    local t = { 'slot1', 'slot2', 'slot3' }
    for i, slot in pairs(t) do
        local panel = preyWindow[slot]
        for j, state in pairs({ panel.active, panel.inactive }) do
            state.select.price.text:setText('5')
        end
        panel.active.autoRerollPrice.text:setText('1')
        panel.active.lockPreyPrice.text:setText('5')
        panel.active.choose.price.text:setText(1)
    end
end

function check()
    if g_game.getFeature(GamePrey) then
        if not preyButton then
            preyButton = modules.game_mainpanel.addToggleButton('preyButton', tr('Prey Dialog'),
                '/images/options/button_preydialog', toggle)
        end
        if not preyTrackerButton then
            preyTrackerButton = modules.game_mainpanel.addToggleButton('preyTrackerButton', tr('Prey Tracker'),
                '/images/options/button_prey', toggleTracker)
        end
    elseif preyButton then
        preyButton:destroy()
        preyButton = nil
    end
end

function toggleTracker()
    if preyTracker:isVisible() then
        preyTracker:hide()
        if preyTrackerButton then
            preyTrackerButton:setOn(false)
        end
    else
        if not preyTracker:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(preyTracker, preyTracker:getMinimumHeight())
            if not panel then
                return
            end

            panel:addChild(preyTracker)
        end
        preyTracker:show()
        if preyTrackerButton then
            preyTrackerButton:setOn(true)
        end
    end
end

local function resetPreyWindowState()
    if not preyWindow then
        return
    end

    preyWindow.description:setText('')
    preyWindow.gold:setText('0')
    preyWindow.wildCards:setText('0')

    for slot = 0, 2 do
        onPreyInactive(slot, 0, 0)

        local prey = preyWindow['slot' .. (slot + 1)]
        if prey then
            if prey.title then
                prey.title:setText('')
            end

            if prey.inactive and prey.inactive.list then
                prey.inactive.list:setVisible(true)
                prey.inactive.list:destroyChildren()
            end

            if prey.inactive then
                if prey.inactive.fullList then
                    clearFullListEntries(prey.inactive.fullList)
                    prey.inactive.fullList:setVisible(false)
                end

                if prey.inactive.preview then
                    resetPreyPreviewWidget(prey.inactive.preview)
                    prey.inactive.preview:setVisible(false)
                end

                if prey.inactive.select then
                    prey.inactive.select:setVisible(true)
                end

                if prey.inactive.reroll then
                    prey.inactive.reroll:setVisible(true)
                end
            end

            if prey.active and prey.active.creatureAndBonus then
                local creatureAndBonus = prey.active.creatureAndBonus
                if creatureAndBonus.timeLeft then
                    creatureAndBonus.timeLeft:setPercent(0)
                    creatureAndBonus.timeLeft:setText('')
                end

                if creatureAndBonus.bonus and creatureAndBonus.bonus.grade then
                    creatureAndBonus.bonus.grade:destroyChildren()
                end
            end
        end
    end

    preyDescription = {}
    rerollPrice = 0
    bonusRerolls = 0
    bankGold = 0
    inventoryGold = 0
    raceEntriesBySlot = {}
    selectedRaceEntryBySlot = {}
    selectedRaceWidgetBySlot = {}
end

function onGameEnd()
    resetPreyWindowState()
    hide()
end

function hide()
    preyWindow:hide()
    if preyButton then
        preyButton:setOn(false)
    end
    if msgWindow then
        msgWindow:destroy()
        msgWindow = nil
    end
end

function show()
    if not g_game.getFeature(GamePrey) then
        return hide()
    end
    preyWindow:show()
    preyWindow:raise()
    preyWindow:focus()
    if preyButton then
        preyButton:setOn(true)
    end
    g_game.preyRequest() -- update preys, it's for tibia 12
end

function toggle()
    if preyWindow:isVisible() then
        return hide()
    end
    show()
end

function onMiniWindowOpen()
    if preyTrackerButton then
        preyTrackerButton:setOn(true)
    end
end

function onMiniWindowClose()
    if preyTrackerButton then
        preyTrackerButton:setOn(false)
    end
end

function onPreyFreeRerolls(slot, timeleft)
    local prey = preyWindow['slot' .. (slot + 1)]
    local percent = (timeleft / (20 * 60)) * 100
    local desc = timeleftTranslation(timeleft * 60)
    if not prey then
        return
    end
    for i, panel in pairs({ prey.active, prey.inactive }) do
        local progressBar = panel.reroll.button.time
        local price = panel.reroll.price.text
        progressBar:setPercent(percent)
        progressBar:setText(desc)
        if timeleft == 0 then
            price:setText('0')
        end
    end
end

function onPreyTimeLeft(slot, timeLeft)
    -- description
    preyDescription[slot] = preyDescription[slot] or {
        one = '',
        two = ''
    }
    local text = preyDescription[slot].one .. timeleftTranslation(timeLeft, true) .. preyDescription[slot].two
    -- tracker
    local percent = (timeLeft / (2 * 60 * 60)) * 100
    slot = 'slot' .. (slot + 1)
    local tracker = preyTracker.contentsPanel[slot]
    tracker.time:setPercent(percent)
    tracker.time:setTooltip(text)
    for i, element in pairs({ tracker.creatureName, tracker.creature, tracker.preyType, tracker.time }) do
        element:setTooltip(text)
        element.onClick = function()
            show()
        end
    end
    -- main window
    local prey = preyWindow[slot]
    if not prey then
        return
    end
    local progressbar = prey.active.creatureAndBonus.timeLeft
    local desc = timeleftTranslation(timeLeft, true)
    progressbar:setPercent(percent)
    progressbar:setText(desc)
end

function onPreyRerollPrice(price)
    rerollPrice = price
    local t = { 'slot1', 'slot2', 'slot3' }
    for index, slot in ipairs(t) do
        local panel = preyWindow[slot]
        if panel then
            for j, state in pairs({ panel.active, panel.inactive }) do
                if state and state.reroll and state.reroll.price and state.reroll.button then
                    local priceWidget = state.reroll.price.text
                    local progressBar = state.reroll.button.time
                    if progressBar:getText() ~= 'Free' then
                        priceWidget:setText(comma_value(rerollPrice))
                    else
                        priceWidget:setText('0')
                        progressBar:setPercent(0)
                    end
                end
            end
        end

        refreshRerollButtonState(index - 1)
    end
end

function setTimeUntilFreeReroll(slot, timeUntilFreeReroll) -- minutes
    local prey = preyWindow['slot' .. (slot + 1)]
    if not prey then
        return
    end
    local percent = (timeUntilFreeReroll / (20 * 60)) * 100
    timeUntilFreeReroll = timeUntilFreeReroll > 720000 and 0 or timeUntilFreeReroll
    local desc = timeleftTranslation(timeUntilFreeReroll)
    for i, panel in pairs({ prey.active, prey.inactive }) do
        if panel and panel.reroll and panel.reroll.button and panel.reroll.price then
            local reroll = panel.reroll.button.time
            reroll:setPercent(percent)
            reroll:setText(desc)
            local price = panel.reroll.price.text
            if timeUntilFreeReroll > 0 then
                price:setText(comma_value(rerollPrice))
            else
                price:setText('Free')
            end
        end
    end

    refreshRerollButtonState(slot)
end

function onPreyLocked(slot, unlockState, timeUntilFreeReroll, wildcards)
    setPickSpecificPreyBonus(slot)

    -- tracker
    slot = 'slot' .. (slot + 1)
    local tracker = preyTracker.contentsPanel[slot]
    if tracker then
        tracker:hide()
        preyTracker:setContentMaximumHeight(preyTracker:getHeight())
    end
    -- main window
    local prey = preyWindow[slot]
    if not prey then
        return
    end
    prey.title:setText('Locked')
    prey.inactive:hide()
    prey.active:hide()
    prey.locked:show()
end

function onPreyInactive(slot, timeUntilFreeReroll, wildcards)
    -- tracker
    local tracker = preyTracker.contentsPanel['slot' .. (slot + 1)]
    if tracker then
        tracker.creature:hide()
        tracker.noCreature:show()
        tracker.creatureName:setText('Inactive')
        tracker.time:setPercent(0)
        tracker.preyType:setImageSource('/images/game/prey/prey_no_bonus')
        for i, element in pairs({ tracker.creatureName, tracker.creature, tracker.preyType, tracker.time }) do
            element:setTooltip('Inactive Prey. \n\nClick in this window to open the prey dialog.')
            element.onClick = function()
                show()
            end
        end
    end
    -- main window
    setTimeUntilFreeReroll(slot, timeUntilFreeReroll)
    local prey = preyWindow['slot' .. (slot + 1)]
    if not prey then
        return
    end
    prey.active:hide()
    prey.locked:hide()
    prey.inactive:show()
    setInactiveMode(slot, false, prey)
    raceEntriesBySlot[slot] = nil
    selectedRaceEntryBySlot[slot] = nil
    selectedRaceWidgetBySlot[slot] = nil
    local rerollButton = prey.inactive.reroll and prey.inactive.reroll.button and
        prey.inactive.reroll.button.rerollButton
    if rerollButton then
        rerollButton.onClick = function()
            showListRerollConfirmation(slot)
        end
    end

    setPickSpecificPreyBonus(slot)
    updatePickSpecificPreyButton(slot, wildcards)
end

function setBonusGradeStars(slot, grade)
    local prey = preyWindow['slot' .. (slot + 1)]
    local gradePanel = prey.active.creatureAndBonus.bonus.grade

    gradePanel:destroyChildren()
    for i = 1, 10 do
        if i <= grade then
            local widget = g_ui.createWidget('Star', gradePanel)
            widget.onHoverChange = function(widget, hovered)
                onHover(slot)
            end
        else
            local widget = g_ui.createWidget('NoStar', gradePanel)
            widget.onHoverChange = function(widget, hovered)
                onHover(slot)
            end
        end
    end
end

function getBigIconPath(bonusType)
    local path = '/images/game/prey/'
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

function getSmallIconPath(bonusType)
    local path = '/images/game/prey/'
    if bonusType == PREY_BONUS_DAMAGE_BOOST then
        return path .. 'prey_damage'
    elseif bonusType == PREY_BONUS_DAMAGE_REDUCTION then
        return path .. 'prey_defense'
    elseif bonusType == PREY_BONUS_XP_BONUS then
        return path .. 'prey_xp'
    elseif bonusType == PREY_BONUS_IMPROVED_LOOT then
        return path .. 'prey_loot'
    end
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

function capitalFormatStr(str)
    local formatted = ''
    str = string.split(str, ' ')
    for i, word in ipairs(str) do
        formatted = formatted .. ' ' .. (string.gsub(word, '^%l', string.upper))
    end
    return formatted:trim()
end

local function getPreySlotWidget(slot)
    if not preyWindow then
        return nil
    end
    return preyWindow['slot' .. (slot + 1)]
end

local function setChoosePreyButtonEnabled(button, enabled)
    if not button then
        return
    end

    local imagePath
    if enabled then
        button:enable()
        imagePath = '/images/game/prey/prey_choose.png'
    else
        button:disable()
        imagePath = '/images/game/prey/prey_choose_blocked.png'
    end

    button:setImageSource(imagePath)
end

local function updateChoosePreyButtonState(slot)
    local prey = getPreySlotWidget(slot)
    if not prey or not prey.inactive or not prey.inactive.choose then
        return
    end

    local button = prey.inactive.choose.choosePreyButton
    if not button then
        return
    end

    local hasSelection = false
    local list = prey.inactive.list
    if list then
        for _, child in pairs(list:getChildren()) do
            if child.isChecked and child:isChecked() then
                hasSelection = true
                break
            end
        end
    end

    if not hasSelection and selectedRaceEntryBySlot[slot] then
        hasSelection = true
    end

    setChoosePreyButtonEnabled(button, hasSelection)
end

local function getWildcardCountOrDefault(wildcards)
    local playerBalance
    local player = g_game.getLocalPlayer()
    if player and ResourceTypes and ResourceTypes.PREY_WILDCARDS then
        playerBalance = player:getResourceBalance(ResourceTypes.PREY_WILDCARDS)
    end

    if type(wildcards) == 'number' then
        if playerBalance then
            return math.max(wildcards, playerBalance)
        end
        return wildcards
    end

    return playerBalance or 0
end

local function showPreyConfirmationWindow(title, description, confirmAction)
    local confirmWindow
    local wasPreyWindowVisible = preyWindow and preyWindow:isVisible()
    local preyVisibilityRestored = false

    local function restorePreyWindowVisibility()
        if not preyVisibilityRestored and wasPreyWindowVisible and preyWindow then
            preyVisibilityRestored = true
            preyWindow:show()
            preyWindow:raise()
            preyWindow:focus()
        end
    end

    if wasPreyWindowVisible then
        preyWindow:hide()
    end

    local function closeWindow()
        if confirmWindow then
            confirmWindow:destroy()
            confirmWindow = nil
            restorePreyWindowVisibility()
        end
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
        confirmWindow.onDestroy = restorePreyWindowVisibility
    else
        restorePreyWindowVisibility()
    end
end

local function showPreyWildcardConfirmation(description, confirmAction)
    showPreyConfirmationWindow('Confirmation of Using Prey Wildcards', description, confirmAction)
end

local function showPickSpecificPreyConfirmation(slot, wildcardCount)
    local description = tr(string.format(
        'Are you sure you want to use 5 of your remaining %s Prey Wildcards?',
        tostring(wildcardCount)
    ))

    showPreyWildcardConfirmation(description, function()
        g_game.preyAction(slot, PREY_ACTION_REQUEST_ALL_MONSTERS, 0)
    end)
end

local function showBonusRerollConfirmation(slot, wildcardCount)
    local description = tr(string.format(
        'Are you sure you want to use 1 of your remaining %s Prey Wildcards?',
        tostring(wildcardCount)
    ))

    showPreyWildcardConfirmation(description, function()
        g_game.preyAction(slot, PREY_ACTION_BONUSREROLL, 0)
    end)
end

local function getPlayerTotalGold()
    local player = g_game.getLocalPlayer()
    if player and player.getTotalMoney then
        return player:getTotalMoney()
    end

    return (bankGold or 0) + (inventoryGold or 0)
end

local function getRerollPriceFromPanel(panel)
    if not panel or not panel.reroll or not panel.reroll.price then
        return nil
    end

    local priceWidget = panel.reroll.price.text
    if not priceWidget then
        return nil
    end

    local text = priceWidget:getText()
    if not text or text == '' then
        return nil
    end

    if text:lower() == 'free' then
        return 0
    end

    local digits = text:gsub('[^%d]', '')
    if digits == '' then
        return nil
    end

    return tonumber(digits)
end

local function getDisplayedRerollPrice(slot)
    local prey = getPreySlotWidget(slot)
    if not prey then
        return rerollPrice
    end

    local function getPrice(panel, requireVisibility)
        if not panel then
            return nil
        end

        if requireVisibility and panel.isVisible and not panel:isVisible() then
            return nil
        end

        return getRerollPriceFromPanel(panel)
    end

    local price = getPrice(prey.active, true) or getPrice(prey.inactive, true)
    if price ~= nil then
        return price
    end

    price = getPrice(prey.active, false) or getPrice(prey.inactive, false)
    if price ~= nil then
        return price
    end

    return rerollPrice
end

function refreshRerollButtonState(slot)
    local prey = getPreySlotWidget(slot)
    if not prey then
        return
    end

    local totalGold = getPlayerTotalGold()

    local function updatePanel(panel)
        if not panel or not panel.reroll or not panel.reroll.button then
            return
        end

        local button = panel.reroll.button.rerollButton
        if not button then
            return
        end

        local price = getRerollPriceFromPanel(panel)
        if price == nil then
            price = rerollPrice
        end

        local isFree = price == nil or price <= 0
        local canAfford = isFree or totalGold >= price

        if canAfford then
            button:setImageSource('/images/game/prey/prey_reroll')
            button:enable()
        else
            button:setImageSource('/images/game/prey/prey_reroll_blocked')
            button:disable()
        end
    end

    updatePanel(prey.active)
    updatePanel(prey.inactive)
end

local function showListRerollConfirmation(slot)
    local price = getDisplayedRerollPrice(slot)

    if price == nil then
        price = rerollPrice or 0
    end

    if price <= 0 then
        g_game.preyAction(slot, PREY_ACTION_LISTREROLL, 0)
        return
    end

    local totalGold = getPlayerTotalGold()
    local description = tr(string.format(
        'Do you want to spend %s gold for a List Reroll?\nYou current have %s gold available for the purchase.',
        comma_value(price),
        comma_value(totalGold)
    ))

    showPreyConfirmationWindow('Confirmation of Using List Reroll', description, function()
        g_game.preyAction(slot, PREY_ACTION_LISTREROLL, 0)
    end)
end

function updatePickSpecificPreyButton(slot, wildcards)
    local prey = getPreySlotWidget(slot)
    if not prey then
        return
    end

    local wildcardCount = getWildcardCountOrDefault(wildcards)
    local hasWildcardsAvailable = wildcardCount > 5

    local function refreshButton(panel)
        if not panel or not panel.select or not panel.select.pickSpecificPrey then
            return
        end

        local button = panel.select.pickSpecificPrey

        button:setTooltip(getPickSpecificPreyDescription(slot))

        if hasWildcardsAvailable then
            button:setImageSource('/images/game/prey/prey_select')
            button:enable()
            button.onClick = function()
                showPickSpecificPreyConfirmation(slot, wildcardCount)
            end
        else
            button:setImageSource('/images/game/prey/prey_select_blocked')
            button:disable()
            button.onClick = nil
        end
    end

    refreshButton(prey.active)
    refreshButton(prey.inactive)
end

function resetPreyPreviewWidget(preview)
    if not preview then
        return
    end

    if preview.placeholder then
        preview.placeholder:setVisible(true)
    end

    if preview.creature then
        preview.creature:setVisible(false)
    end
end

setWidgetTreePhantom = function(widget, phantom)
    if not widget or widget:isDestroyed() then
        return
    end

    widget:setPhantom(phantom)

    for _, child in pairs(widget:getChildren()) do
        setWidgetTreePhantom(child, phantom)
    end
end

function setInactiveMode(slot, showFullList, prey)
    prey = prey or getPreySlotWidget(slot)
    if not prey or not prey.inactive then
        return prey
    end

    local inactive = prey.inactive

    if inactive.list then
        inactive.list:setVisible(not showFullList)
        setWidgetTreePhantom(inactive.list, showFullList)
    end

    if inactive.fullList then
        inactive.fullList:setVisible(showFullList)
    end

    if inactive.preview then
        inactive.preview:setVisible(showFullList)
        if not showFullList or not selectedRaceEntryBySlot[slot] then
            resetPreyPreviewWidget(inactive.preview)
        end
    end

    if inactive.select then
        inactive.select:setVisible(not showFullList)
    end

    if inactive.reroll then
        inactive.reroll:setVisible(not showFullList)
    end

    return prey
end

local function isDescendantOf(widget, ancestor)
    if not widget or not ancestor then
        return false
    end
    local current = widget
    while current do
        if current == ancestor then
            return true
        end
        current = current:getParent()
    end
    return false
end

local function getFullListEntriesContainer(fullList)
    if not fullList then
        return nil
    end

    local entries = fullList.entries
    if not entries then
        return nil
    end

    if entries.entriesContainer then
        return entries.entriesContainer
    end

    if entries.getChildById then
        local contents = entries:getChildById('entriesContainer') or entries:getChildById('contentsPanel')
        if contents then
            entries.entriesContainer = contents
            return contents
        end
    end

    entries.entriesContainer = entries
    return entries
end

function clearFullListEntries(fullList)
    local container = getFullListEntriesContainer(fullList)
    if container then
        container:destroyChildren()
    end

    if fullList and fullList.entries and fullList.entries.verticalScrollBar then
        local scrollbar = fullList.entries.verticalScrollBar
        if scrollbar.getMinimum and scrollbar.setValue then
            scrollbar:setValue(scrollbar:getMinimum())
        end
    end
end

local suppressSearchTextHandler = false

local function setSearchTextSilently(widget, text)
    if not widget or widget:getText() == text then
        return
    end

    suppressSearchTextHandler = true
    widget:setText(text)
    suppressSearchTextHandler = false
end

local function updateRaceSearchClearButton(slot)
    local prey = getPreySlotWidget(slot)
    if not prey or not prey.inactive or not prey.inactive.fullList then
        return
    end

    local fullList = prey.inactive.fullList
    local clearButton = fullList.searchClearButton
    if not clearButton then
        return
    end

    local text = raceSearchTextsBySlot[slot]
    clearButton:setVisible(text and text:len() > 0)
end

local function updateRaceSearchUI(slot)
    local prey = getPreySlotWidget(slot)
    if not prey or not prey.inactive or not prey.inactive.fullList then
        return
    end

    local fullList = prey.inactive.fullList
    local searchEdit = fullList.searchEdit
    local clearButton = fullList.searchClearButton
    local text = raceSearchTextsBySlot[slot] or ''

    if searchEdit then
        searchEdit.preySlot = slot
        setSearchTextSilently(searchEdit, text)
        searchEdit:setCursorPos(-1)
    end

    if clearButton then
        clearButton.preySlot = slot
        clearButton.searchEdit = searchEdit
    end

    updateRaceSearchClearButton(slot)
end

local function uncheckChildrenExcept(parent, except)
    if not parent then
        return
    end
    for _, child in pairs(parent:getChildren()) do
        if child ~= except and child.setChecked then
            if not child:isDestroyed() then
                child:setChecked(false)
                restoreRaceListItemBackground(child)
            end
        end
        uncheckChildrenExcept(child, except)
    end
end

function onItemBoxChecked(widget)
    for _, slotId in ipairs({ 'slot1', 'slot2', 'slot3' }) do
        local slotWidget = preyWindow[slotId]
        if slotWidget and slotWidget.inactive then
            local list = slotWidget.inactive.list
            if list and isDescendantOf(widget, list) then
                uncheckChildrenExcept(list, widget)
                widget:setChecked(true)
                local slotIndex = tonumber(slotId:match('slot(%d+)'))
                if slotIndex then
                    updateChoosePreyButtonState(slotIndex - 1)
                end
                return
            end
            local fullList = slotWidget.inactive.fullList
            if fullList then
                local entriesContainer = getFullListEntriesContainer(fullList) or fullList
                if entriesContainer and isDescendantOf(widget, entriesContainer) then
                    uncheckChildrenExcept(entriesContainer, widget)
                    widget:setChecked(true)
                    local slotIndex = tonumber(slotId:match('slot(%d+)'))
                    if slotIndex then
                        updateChoosePreyButtonState(slotIndex - 1)
                    end
                    return
                end
            end
        end
    end
    widget:setChecked(true)
end

local function setWidgetTextToFit(widget, text, formatter)
    if not widget then
        return ''
    end

    text = text or ''
    formatter = formatter or function(value) return value end

    local ellipsis = '...'
    local paddingLeft = widget.getPaddingLeft and widget:getPaddingLeft() or 0
    local paddingRight = widget.getPaddingRight and widget:getPaddingRight() or 0
    local availableWidth = widget:getWidth() - paddingLeft - paddingRight

    if availableWidth <= 0 then
        local formatted = formatter(text)
        widget:setText(formatted)
        return formatted
    end

    local function setAndCheck(value)
        local formattedValue = formatter(value)
        widget:setText(formattedValue)
        local textSize = widget:getTextSize()
        return textSize.width <= availableWidth, formattedValue
    end

    local fits, formatted = setAndCheck(text)
    if fits then
        return formatted
    end

    local bestFormatted
    local left, right = 0, #text
    while left <= right do
        local mid = math.floor((left + right) / 2)
        local candidate = text:sub(1, mid) .. ellipsis
        local candidateFits, candidateFormatted = setAndCheck(candidate)
        if candidateFits then
            bestFormatted = candidateFormatted
            left = mid + 1
        else
            right = mid - 1
        end
    end

    if bestFormatted then
        widget:setText(bestFormatted)
        return bestFormatted
    end

    local _, ellipsisFormatted = setAndCheck(ellipsis)
    widget:setText(ellipsisFormatted)
    return ellipsisFormatted
end

local function buildRaceEntry(raceId)
    local raceData = g_things.getRaceData(raceId)
    local name = raceData and raceData.name or nil

    if name and name ~= '' then
        name = capitalFormatStr(name)
    else
        name = tr('Unknown Creature (%d)', raceId)
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
        realSize = realSize
    }
end

restoreRaceListItemBackground = function(widget)
    if not widget or widget:isDestroyed() then
        return
    end

    if widget:isChecked() then
        if widget.checkedBackground then
            widget:setBackgroundColor(widget.checkedBackground)
        end
        if widget.checkedTextColor then
            widget:setColor(widget.checkedTextColor)
        end
        return
    end

    if widget.baseBackground then
        widget:setBackgroundColor(widget.baseBackground)
    end
    if widget.baseTextColor then
        widget:setColor(widget.baseTextColor)
    end
end

updateRaceSelectionDisplay = function(slot)
    local prey = getPreySlotWidget(slot)
    if not prey or not prey.inactive or not prey.inactive.fullList then
        return
    end

    local entry = selectedRaceEntryBySlot[slot]

    if prey.title then
        if entry then
            setWidgetTextToFit(prey.title, entry.name, function(value)
                return tr('Selected: %s', value)
            end)
        else
            prey.title:setText(tr('Select your prey creature'))
        end
    end

    local preview = prey.inactive and prey.inactive.preview
    if preview then
        local creatureWidget = preview.creature
        local placeholder = preview.placeholder
        if entry and entry.outfit and creatureWidget then
            local spriteSize = g_gameConfig.getSpriteSize()
            if spriteSize <= 0 then
                spriteSize = 32
            end
            local widgetSize = math.min(creatureWidget:getWidth(), creatureWidget:getHeight())
            local referenceSize = math.max(entry.realSize or spriteSize * 2, spriteSize * 2)
            local targetSize = widgetSize > 0 and widgetSize or spriteSize * 2
            local scale = math.floor((targetSize / referenceSize) * 100)

            if scale < 1 then
                scale = 1
            elseif scale > 100 then
                scale = 100
            end
            creatureWidget:setCreatureSize(size)
            creatureWidget:setOutfit(entry.outfit)
            creatureWidget:setVisible(true)
            if placeholder then
                placeholder:setVisible(false)
            end
        else
            if creatureWidget then
                creatureWidget:setVisible(false)
            end
            if placeholder then
                placeholder:setVisible(true)
            end
        end
    end

    local chooseButton = prey.inactive.choose and prey.inactive.choose.choosePreyButton
    if chooseButton then
        setChoosePreyButtonEnabled(chooseButton, entry ~= nil)
    end
end

setRaceSelection = function(slot, widget, skipUncheck)
    local previousWidget = selectedRaceWidgetBySlot[slot]
    if widget and widget:isDestroyed() then
        widget = nil
    end

    if widget and not skipUncheck then
        onItemBoxChecked(widget)
    elseif not widget and previousWidget and not previousWidget:isDestroyed() and previousWidget.setChecked then
        previousWidget:setChecked(false)
        restoreRaceListItemBackground(previousWidget)
    elseif widget and skipUncheck then
        if previousWidget and previousWidget ~= widget and not previousWidget:isDestroyed() and previousWidget.setChecked then
            previousWidget:setChecked(false)
            restoreRaceListItemBackground(previousWidget)
        end
        if not widget:isChecked() then
            widget:setChecked(true)
        end
    end

    if previousWidget and previousWidget ~= widget then
        restoreRaceListItemBackground(previousWidget)
    end

    selectedRaceWidgetBySlot[slot] = widget
    selectedRaceEntryBySlot[slot] = widget and widget.raceData or nil

    if widget then
        restoreRaceListItemBackground(widget)
    end

    updateRaceSelectionDisplay(slot)
    updateChoosePreyButtonState(slot)
end

refreshRaceList = function(slot)
    local prey = getPreySlotWidget(slot)
    if not prey or not prey.inactive or not prey.inactive.fullList then
        return
    end

    local fullList = prey.inactive.fullList
    clearFullListEntries(fullList)

    local entriesPanel = getFullListEntriesContainer(fullList)
    if not entriesPanel then
        return
    end

    local currentSelectionId = selectedRaceEntryBySlot[slot] and selectedRaceEntryBySlot[slot].raceId or nil
    local selectionRestored = false

    local backgroundA = '#484848'
    local backgroundB = '#414141'
    local useAlternate = false

    local searchFilter = raceSearchTextsBySlot[slot]
    if searchFilter and searchFilter:len() > 0 then
        searchFilter = searchFilter:lower()
    else
        searchFilter = nil
    end

    for _, entry in ipairs(raceEntriesBySlot[slot] or {}) do
        if not searchFilter or (entry.searchName and entry.searchName:find(searchFilter, 1, true)) then
            local item = g_ui.createWidget('PreyCreatureListItem', entriesPanel)
            setWidgetTextToFit(item, entry.name)
            item:setTooltip(entry.name)
            item.raceData = entry
            item.preySlot = slot
            item.baseBackground = useAlternate and backgroundB or backgroundA
            item.checkedBackground = '#585858'
            item.baseTextColor = '#c0c0c0'
            item.checkedTextColor = '#ffffff'
            item:setBackgroundColor(item.baseBackground)
            item:setColor(item.baseTextColor)
            item.onCheckChange = function(widget)
                restoreRaceListItemBackground(widget)
            end
            restoreRaceListItemBackground(item)

            useAlternate = not useAlternate

            if currentSelectionId and entry.raceId == currentSelectionId then
                setRaceSelection(slot, item, true)
                selectionRestored = true
            end
        end
    end

    if not selectionRestored and currentSelectionId then
        setRaceSelection(slot, nil, true)
    elseif not currentSelectionId then
        updateRaceSelectionDisplay(slot)
    end

    updateChoosePreyButtonState(slot)
end

function onRaceSearchTextChanged(widget)
    if not widget or not widget.preySlot then
        return
    end

    if suppressSearchTextHandler then
        updateRaceSearchClearButton(widget.preySlot)
        return
    end

    local slot = widget.preySlot
    local text = widget:getText() or ''
    local trimmed = text:trim()

    if text ~= trimmed then
        setSearchTextSilently(widget, trimmed)
        widget:setCursorPos(-1)
        text = trimmed
    end

    if trimmed:len() == 0 then
        raceSearchTextsBySlot[slot] = nil
    else
        raceSearchTextsBySlot[slot] = trimmed
    end

    updateRaceSearchClearButton(slot)
    refreshRaceList(slot)
end

function onRaceSearchClearClicked(widget)
    if not widget or not widget.preySlot then
        return
    end

    local slot = widget.preySlot
    local searchEdit = widget.searchEdit

    if not searchEdit or searchEdit:isDestroyed() then
        local prey = getPreySlotWidget(slot)
        if prey and prey.inactive and prey.inactive.fullList then
            searchEdit = prey.inactive.fullList.searchEdit
        end
    end

    raceSearchTextsBySlot[slot] = nil

    if searchEdit and not searchEdit:isDestroyed() then
        setSearchTextSilently(searchEdit, '')
        searchEdit:setCursorPos(0)
    end

    updateRaceSearchClearButton(slot)
    refreshRaceList(slot)
end

function onPreyRaceListItemClicked(widget)
    if not widget or not widget.preySlot then
        return
    end
    setRaceSelection(widget.preySlot, widget, false)
end

function onPreyRaceListItemHoverChange(widget, hovered)
    if not widget or widget:isDestroyed() then
        return
    end

    restoreRaceListItemBackground(widget)
end

local suppressOptionCheckHandler = false

local function setOptionCheckedSilently(checkbox, checked)
    if checkbox:isChecked() == checked then
        return
    end
    suppressOptionCheckHandler = true
    checkbox:setChecked(checked)
    suppressOptionCheckHandler = false
end

local function getToggleCheckboxes(slot)
    local prey = preyWindow and preyWindow['slot' .. (slot + 1)]
    if not prey or not prey.active then
        return nil, nil
    end

    local autoCheckbox = prey.active.autoReroll and prey.active.autoReroll.autoRerollCheck
    local lockCheckbox = prey.active.lockPrey and prey.active.lockPrey.lockPreyCheck

    return autoCheckbox, lockCheckbox
end

local function sendOption(slot, option)
    g_game.preyAction(slot, PREY_ACTION_OPTION, option)
end

local function handleToggleOptions(checkbox, slot, currentOption, checked)
    if suppressOptionCheckHandler then
        return
    end

    local autoCheckbox, lockCheckbox = getToggleCheckboxes(slot)
    local otherCheckbox = currentOption == PREY_OPTION_TOGGLE_AUTOREROLL and lockCheckbox or autoCheckbox

    if checked then
        local confirmWindow
        local wasPreyWindowVisible = preyWindow and preyWindow:isVisible()
        local preyVisibilityRestored = false

        local function restorePreyWindowVisibility()
            if not preyVisibilityRestored and wasPreyWindowVisible and preyWindow then
                preyVisibilityRestored = true
                preyWindow:show()
                preyWindow:raise()
                preyWindow:focus()
            end
        end

        if wasPreyWindowVisible then
            preyWindow:hide()
        end

        local function closeWindow()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                restorePreyWindowVisibility()
            end
        end

        local function confirm()
            if otherCheckbox and otherCheckbox:isChecked() then
                setOptionCheckedSilently(otherCheckbox, false)
                sendOption(slot, PREY_OPTION_UNTOGGLE)
            end

            setOptionCheckedSilently(checkbox, true)
            sendOption(slot, currentOption)
            closeWindow()
        end

        local function cancel()
            setOptionCheckedSilently(checkbox, false)
            closeWindow()
        end

        local description = currentOption == PREY_OPTION_TOGGLE_AUTOREROLL and
            tr(descriptionTable['automaticBonusReroll']) or tr(descriptionTable['preyLock'])

        confirmWindow = displayGeneralBox(tr('Confirmation of Using Prey Wildcards'), description, {
            {
                text = tr('No'),
                callback = cancel
            },
            {
                text = tr('Yes'),
                callback = confirm
            },
        }, confirm, cancel)

        if confirmWindow then
            confirmWindow.onDestroy = restorePreyWindowVisibility
        end

        return
    end

    sendOption(slot, PREY_OPTION_UNTOGGLE)
end

function onPreyActive(slot, currentHolderName, currentHolderOutfit, bonusType, bonusValue, bonusGrade, timeLeft,
                      timeUntilFreeReroll, wildcards, option) -- locktype always 0 for protocols <12
    
    local tracker = preyTracker.contentsPanel['slot' .. (slot + 1)]
    currentHolderName = capitalFormatStr(currentHolderName)
    local percent = (timeLeft / (2 * 60 * 60)) * 100
    if tracker then
        tracker.creature:show()
        tracker.noCreature:hide()
        tracker.creatureName:setText(currentHolderName)
        tracker.creature:setOutfit(currentHolderOutfit)
        tracker.preyType:setImageSource(getSmallIconPath(bonusType))
        tracker.time:setPercent(percent)
        preyDescription[slot] = preyDescription[slot] or {}
        preyDescription[slot].one = 'Creature: ' .. currentHolderName .. '\nDuration: '
        preyDescription[slot].two =
            '\nValue: ' .. bonusGrade .. '/10' .. '\nType: ' .. getBonusDescription(bonusType) .. '\n' ..
            getTooltipBonusDescription(bonusType, bonusValue) .. '\n\nClick in this window to open the prey dialog.'
        for i, element in pairs({ tracker.creatureName, tracker.creature, tracker.preyType, tracker.time }) do
            element:setTooltip(preyDescription[slot].one .. timeleftTranslation(timeLeft, true) ..
                preyDescription[slot].two)
            element.onClick = function()
                show()
            end
        end
    end
    local prey = preyWindow['slot' .. (slot + 1)]
    if not prey then
        return
    end
    prey.inactive:hide()
    prey.locked:hide()
    prey.active:show()
    prey.title:setText(currentHolderName)
    local creatureAndBonus = prey.active.creatureAndBonus
    creatureAndBonus.creature:setOutfit(currentHolderOutfit)
    setTimeUntilFreeReroll(slot, timeUntilFreeReroll)
    creatureAndBonus.bonus.icon:setImageSource(getBigIconPath(bonusType))
    creatureAndBonus.bonus.icon.onHoverChange = function(widget, hovered)
        onHover(slot)
    end
    setBonusGradeStars(slot, bonusGrade)
    creatureAndBonus.timeLeft:setPercent(percent)
    creatureAndBonus.timeLeft:setText(timeleftTranslation(timeLeft))
    -- bonus reroll
    local wildcardCount = getWildcardCountOrDefault(wildcards)
    setPickSpecificPreyBonus(slot, bonusType, bonusValue)
    prey.active.choose.selectPrey.onClick = function()
        showBonusRerollConfirmation(slot, wildcardCount)
    end
    -- creature reroll
    prey.active.reroll.button.rerollButton.onClick = function()
        showListRerollConfirmation(slot)
    end

    setOptionCheckedSilently(prey.active.autoReroll.autoRerollCheck, option == PREY_OPTION_TOGGLE_AUTOREROLL)
    prey.active.autoReroll.autoRerollCheck.onCheckChange = function(widget, checked)
        handleToggleOptions(widget, slot, PREY_OPTION_TOGGLE_AUTOREROLL, checked)
    end

    setOptionCheckedSilently(prey.active.lockPrey.lockPreyCheck, option == PREY_OPTION_TOGGLE_LOCK_PREY)
    prey.active.lockPrey.lockPreyCheck.onCheckChange = function(widget, checked)
        handleToggleOptions(widget, slot, PREY_OPTION_TOGGLE_LOCK_PREY, checked)
    end

    updatePickSpecificPreyButton(slot, wildcards)
end

function onPreySelection(slot, names, outfits, timeUntilFreeReroll, wildcards, option)
    -- tracker
    local tracker = preyTracker.contentsPanel['slot' .. (slot + 1)]
    if tracker then
        tracker.creature:hide()
        tracker.noCreature:show()
        tracker.creatureName:setText('Inactive')
        tracker.time:setPercent(0)
        tracker.preyType:setImageSource('/images/game/prey/prey_no_bonus')
        for i, element in pairs({ tracker.creatureName, tracker.creature, tracker.preyType, tracker.time }) do
            element:setTooltip('Inactive Prey. \n\nClick in this window to open the prey dialog.')
            element.onClick = function()
                show()
            end
        end
    end
    -- main window
    local prey = preyWindow['slot' .. (slot + 1)]
    setTimeUntilFreeReroll(slot, timeUntilFreeReroll)
    if not prey then
        return
    end
    prey.active:hide()
    prey.locked:hide()
    prey.inactive:show()
    setInactiveMode(slot, false, prey)
    raceEntriesBySlot[slot] = nil
    selectedRaceEntryBySlot[slot] = nil
    selectedRaceWidgetBySlot[slot] = nil
    setPickSpecificPreyBonus(slot)
    prey.title:setText(tr('Select monster'))
    local rerollButton = prey.inactive.reroll and prey.inactive.reroll.button and
        prey.inactive.reroll.button.rerollButton
    if rerollButton then
        rerollButton.onClick = function()
            showListRerollConfirmation(slot)
        end
    end
    local list = prey.inactive.list
    list:destroyChildren()
    for i, name in ipairs(names) do
        local box = g_ui.createWidget('PreyCreatureBox', list)
        name = capitalFormatStr(name)
        box:setTooltip(name)
        box.creature:setOutfit(outfits[i])
        local backgroundColor = (i % 2 == 1) and '#484848' or '#414141'
        box:setBackgroundColor(backgroundColor)
    end
    prey.inactive.choose.choosePreyButton.onClick = function()
        for i, child in pairs(list:getChildren()) do
            if child:isChecked() then
                return g_game.preyAction(slot, PREY_ACTION_MONSTERSELECTION, i - 1)
            end
        end
        return showMessage(tr('Error'), tr('Select monster to proceed.'))
    end

    updateChoosePreyButtonState(slot)
    updatePickSpecificPreyButton(slot, wildcards)
end

function onPreySelectionChangeMonster(slot, names, outfits, bonusType, bonusValue, bonusGrade, timeUntilFreeReroll,
                                      wildcards, option)
    -- tracker
    local tracker = preyTracker.contentsPanel['slot' .. (slot + 1)]
    if tracker then
        tracker.creature:hide()
        tracker.noCreature:show()
        tracker.creatureName:setText('Inactive')
        tracker.time:setPercent(0)
        tracker.preyType:setImageSource('/images/game/prey/prey_no_bonus')
        for i, element in pairs({ tracker.creatureName, tracker.creature, tracker.preyType, tracker.time }) do
            element:setTooltip('Inactive Prey. \n\nClick in this window to open the prey dialog.')
            element.onClick = function()
                show()
            end
        end
    end
    -- main window
    local prey = preyWindow['slot' .. (slot + 1)]
    setTimeUntilFreeReroll(slot, timeUntilFreeReroll)
    if not prey then
        return
    end
    prey.active:hide()
    prey.locked:hide()
    prey.inactive:show()
    setInactiveMode(slot, false, prey)
    raceEntriesBySlot[slot] = nil
    selectedRaceEntryBySlot[slot] = nil
    selectedRaceWidgetBySlot[slot] = nil
    setPickSpecificPreyBonus(slot)
    prey.title:setText(tr('Select monster'))
    local rerollButton = prey.inactive.reroll and prey.inactive.reroll.button and
        prey.inactive.reroll.button.rerollButton
    if rerollButton then
        rerollButton.onClick = function()
            showListRerollConfirmation(slot)
        end
    end
    local list = prey.inactive.list
    list:destroyChildren()
    for i, name in ipairs(names) do
        local box = g_ui.createWidget('PreyCreatureBox', list)
        name = capitalFormatStr(name)
        box:setTooltip(name)
        box.creature:setOutfit(outfits[i])
        local backgroundColor = (i % 2 == 1) and '#484848' or '#414141'
        box:setBackgroundColor(backgroundColor)
    end
    prey.inactive.choose.choosePreyButton.onClick = function()
        for i, child in pairs(list:getChildren()) do
            if child:isChecked() then
                return g_game.preyAction(slot, PREY_ACTION_MONSTERSELECTION, i - 1)
            end
        end
        return showMessage(tr('Error'), tr('Select monster to proceed.'))
    end

    updateChoosePreyButtonState(slot)
    updatePickSpecificPreyButton(slot, wildcards)
end

function onPreyListSelection(slot, races, nextFreeReroll, wildcards, option)
    setTimeUntilFreeReroll(slot, nextFreeReroll)

    local prey = getPreySlotWidget(slot)
    if not prey then
        return
    end

    prey.active:hide()
    prey.locked:hide()
    prey.inactive:show()
    setPickSpecificPreyBonus(slot)
    selectedRaceEntryBySlot[slot] = nil
    selectedRaceWidgetBySlot[slot] = nil

    setInactiveMode(slot, true, prey)

    local fullList = prey.inactive.fullList
    if not fullList then
        return
    end

    prey.title:setText(tr('Select your prey creature'))

    clearFullListEntries(fullList)

    local preview = prey.inactive.preview
    if preview then
        resetPreyPreviewWidget(preview)
    end

    raceEntriesBySlot[slot] = {}
    for _, raceId in ipairs(races) do
        table.insert(raceEntriesBySlot[slot], buildRaceEntry(raceId))
    end
    table.sort(raceEntriesBySlot[slot], function(a, b)
        return a.name < b.name
    end)

    raceSearchTextsBySlot[slot] = nil
    updateRaceSearchUI(slot)

    local chooseButton = prey.inactive.choose and prey.inactive.choose.choosePreyButton
    if chooseButton then
        setChoosePreyButtonEnabled(chooseButton, false)
        chooseButton.onClick = function()
            local selected = selectedRaceEntryBySlot[slot]
            if not selected then
                return showMessage(tr('Error'), tr('Select monster to proceed.'))
            end
            g_game.preyAction(slot, PREY_ACTION_CHANGE_FROM_ALL, selected.raceId)
        end
    end

    refreshRaceList(slot)

    updateChoosePreyButtonState(slot)

    local rerollButton = prey.inactive.reroll and prey.inactive.reroll.button and
        prey.inactive.reroll.button.rerollButton
    if rerollButton then
        rerollButton.onClick = function()
            showListRerollConfirmation(slot)
        end
    end

    updateChoosePreyButtonState(slot)
    updatePickSpecificPreyButton(slot, wildcards)
end

function onPreyWildcardSelection(slot, races, nextFreeReroll, wildcards, option)
    updatePickSpecificPreyButton(slot, wildcards)
end

function Prey.onResourcesBalanceChange(balance, oldBalance, type)
    if type == ResourceTypes.BANK_BALANCE then       -- bank gold
        bankGold = balance
    elseif type == ResourceTypes.GOLD_EQUIPPED then  -- inventory gold
        inventoryGold = balance
    elseif type == ResourceTypes.PREY_WILDCARDS then -- bonus rerolls
        bonusRerolls = balance
        for slot = 0, 2 do
            updatePickSpecificPreyButton(slot, balance)
        end
    end
    local player = g_game.getLocalPlayer()
    g_logger.debug('' .. tostring(type) .. ', ' .. tostring(balance))
    if player then
        preyWindow.wildCards:setText(tostring(player:getResourceBalance(ResourceTypes.PREY_WILDCARDS)))
        preyWindow.gold:setText(comma_value(player:getTotalMoney()))
    end

    if type == ResourceTypes.BANK_BALANCE or type == ResourceTypes.GOLD_EQUIPPED then
        for slot = 0, 2 do
            refreshRerollButtonState(slot)
        end
    end
end

function showMessage(title, message)
    if msgWindow then
        msgWindow:destroy()
    end

    msgWindow = displayInfoBox(title, message)
    msgWindow:show()
    msgWindow:raise()
    msgWindow:focus()
end
