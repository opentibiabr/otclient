local iconTopMenu = nil

local inventoryShrink = false
local itemSlotsWithDuration = {}
local updateSlotsDurationEvent = nil
local DURATION_UPDATE_INTERVAL = 1000
local pvpModeRadioGroup = nil 
local monkMirrorItem = nil

local function getInventoryUi()
    if inventoryShrink then
        return inventoryController.ui.offPanel
    end

    return inventoryController.ui.onPanel
end

local getSlotPanelBySlot = {
    [InventorySlotHead] = function(ui) return ui.helmet, ui.helmet.helmet end,
    [InventorySlotNeck] = function(ui) return ui.amulet, ui.amulet.amulet end,
    [InventorySlotBack] = function(ui) return ui.backpack, ui.backpack.backpack end,
    [InventorySlotBody] = function(ui) return ui.armor, ui.armor.armor end,
    [InventorySlotRight] = function(ui) return ui.shield, ui.shield.shield end,
    [InventorySlotLeft] = function(ui) return ui.sword, ui.sword.sword end,
    [InventorySlotLeg] = function(ui) return ui.legs, ui.legs.legs end,
    [InventorySlotFeet] = function(ui) return ui.boots, ui.boots.boots end,
    [InventorySlotFinger] = function(ui) return ui.ring, ui.ring.ring end,
    [InventorySlotAmmo] = function(ui) return ui.tools, ui.tools.tools end
}

local function isPlayerMonk()
    local player = g_game.getLocalPlayer()
    if not player then
        return false
    end
    return player:isMonk()
end

local function updateMonkMirrorItem(leftItem)
    if not g_game.getFeature(GameVocationMonk) then
        return
    end
    if inventoryShrink then
        return
    end

    local ui = getInventoryUi()
    if not ui or not ui.shield or not ui.shield.item then
        return
    end

    local shieldSlot = ui.shield
    local shieldItemWidget = shieldSlot.item

    if not isPlayerMonk() then
        if monkMirrorItem then
            monkMirrorItem = nil
        end
        return
    end

    local player = g_game.getLocalPlayer()
    local realShieldItem = player and player:getInventoryItem(InventorySlotRight)

    if realShieldItem then
        monkMirrorItem = nil
        return
    end

    if leftItem then
        monkMirrorItem = leftItem
        shieldItemWidget:setItem(leftItem)
        shieldItemWidget:setOpacity(0.5)
        shieldItemWidget:setDraggable(false)
        shieldItemWidget:setEnabled(false)
        shieldItemWidget:setFlipDirection(FlipDirection.Horizontal)
        shieldSlot.shield:setEnabled(false)
    else
        monkMirrorItem = nil
        shieldItemWidget:setItem(nil)
        shieldItemWidget:setOpacity(1.0)
        shieldItemWidget:setDraggable(true)
        shieldItemWidget:setEnabled(true)
        shieldItemWidget:setFlipDirection(FlipDirection.None)
        shieldSlot.shield:setEnabled(true)
        if shieldItemWidget.tier then
            shieldItemWidget.tier:setVisible(false)
        end
    end
end

local function formatDuration(duration)
    return string.format("%dm%02d", duration / 60, duration % 60)
end

local function stopEvent()
    if updateSlotsDurationEvent then
        removeEvent(updateSlotsDurationEvent)
        updateSlotsDurationEvent = nil
    end
end

local function updateSlotsDuration()
    -- @ prevent :
    if not g_game.isOnline() or next(itemSlotsWithDuration) == nil then
        stopEvent()
        return
    end
    -- @

    if not modules.client_options.getOption('showExpiryInInvetory') then
        stopEvent()
        local ui = getInventoryUi()
        for slot, itemDurationReg in pairs(itemSlotsWithDuration) do
            local getSlotInfo = getSlotPanelBySlot[slot]
            if getSlotInfo then
                local slotPanel = getSlotInfo(ui)
                if slotPanel and slotPanel.item then
                    slotPanel.item.duration:setText("")
                end
            end
        end
        return
    end

    local currTime = g_clock.seconds()
    local ui = getInventoryUi()
    local hasItemsWithDuration = false

    for slot, itemDurationReg in pairs(itemSlotsWithDuration) do
        local item = itemDurationReg.item
        if item and item:getDurationTime() > 0 then
            hasItemsWithDuration = true
            local durationTimeLeft = math.max(0, itemDurationReg.timeEnd - currTime)
            local getSlotInfo = getSlotPanelBySlot[slot]
            if getSlotInfo then
                local slotPanel = getSlotInfo(ui)
                if slotPanel and slotPanel.item then
                    slotPanel.item.duration:setText(formatDuration(durationTimeLeft))
                end
            end
        end
    end

    if hasItemsWithDuration then
        updateSlotsDurationEvent = scheduleEvent(updateSlotsDuration, DURATION_UPDATE_INTERVAL)
    else
        stopEvent()
    end
end

local function walkEvent()
    if modules.client_options.getOption('autoChaseOverride') then
        if g_game.isAttacking() and g_game.getChaseMode() == ChaseOpponent then
            selectPosture('stand', false)
        end
    end
end

local function combatEvent()
    if g_game.getChaseMode() == ChaseOpponent then
        selectPosture('follow', true)
    else
        selectPosture('stand', true)
    end
    
    if g_game.getFightMode() == FightOffensive then
        selectCombat('attack', true)
    elseif g_game.getFightMode() == FightBalanced then
        selectCombat('balanced', true)
    elseif g_game.getFightMode() == FightDefensive then
        selectCombat('defense', true)
    end
end

local function inventoryEvent(player, slot, item, oldItem)
    if inventoryShrink then
        return
    end

    local ui = getInventoryUi()
    local getSlotInfo = getSlotPanelBySlot[slot]
    if not getSlotInfo then
        return
    end

    if slot == InventorySlotRight and isPlayerMonk() and not item and monkMirrorItem then
        return
    end

    if slot == InventorySlotRight and item then
        local slotPanel, toggler = getSlotInfo(ui)
        slotPanel.item:setOpacity(1.0)
        slotPanel.item:setDraggable(true)
        slotPanel.item:setEnabled(true)
        slotPanel.item:setFlipDirection(FlipDirection.None)
        monkMirrorItem = nil
    end

    local slotPanel, toggler = getSlotInfo(ui)

    slotPanel.item:setItem(item)
    toggler:setEnabled(not item)
    slotPanel.item:setWidth(34)
    slotPanel.item:setHeight(34)
    slotPanel.item.duration:setText("")
    slotPanel.item.charges:setText("")
    if g_game.getFeature(GameThingClock) then
        if item and item:getDurationTime() > 0 then
            if not itemSlotsWithDuration[slot] or itemSlotsWithDuration[slot].item ~= item then
                itemSlotsWithDuration[slot] = {
                    item = item,
                    timeEnd = g_clock.seconds() + item:getDurationTime()
                }
            end
            if modules.client_options.getOption('showExpiryInInvetory') then
                if not updateSlotsDurationEvent then
                    updateSlotsDuration()
                end
            end
        else
            itemSlotsWithDuration[slot] = nil
        end
    end
    
    if modules.client_options.getOption('showExpiryInInvetory') then
        ItemsDatabase.setCharges(slotPanel.item, item)
    end
    ItemsDatabase.setTier(slotPanel.item, item)

    if slot == InventorySlotLeft then
        updateMonkMirrorItem(item)
    end
end

local function onSoulChange(localPlayer, soul)
    local ui = getInventoryUi()
    if not localPlayer then
        return
    end
    if not soul then
        return
    end

    if ui.soulPanel and ui.soulPanel.soul then
        ui.soulPanel.soul:setText(soul)
    end

    if ui.soulAndCapacity and ui.soulAndCapacity.soul then
        ui.soulAndCapacity.soul:setText(soul)
    end
end

local function onFreeCapacityChange(player, freeCapacity)
    if not player then
        return
    end

    if not freeCapacity then
        return
    end
    if freeCapacity > 99999 then
        freeCapacity = math.min(9999, math.floor(freeCapacity / 1000)) .. "k"
    elseif freeCapacity > 999 then
        freeCapacity = math.floor(freeCapacity)
    elseif freeCapacity > 99 then
        freeCapacity = math.floor(freeCapacity * 10) / 10
    end
    local ui = getInventoryUi()
    if ui.capacityPanel and ui.capacityPanel.capacity then
        ui.capacityPanel.capacity:setText(freeCapacity)
    end
    if ui.soulAndCapacity and ui.soulAndCapacity.capacity then
        ui.soulAndCapacity.capacity:setText(freeCapacity)
    end
end

function getIconsPanelOn()
    return inventoryController.ui.onPanel.icons
end

function getIconsPanelOff()
    return inventoryController.ui.offPanel.icons
end

local function refreshInventory_panel()
    local player = g_game.getLocalPlayer()
    if player then
        onSoulChange(player, player:getSoul())
        onFreeCapacityChange(player, player:getFreeCapacity())
    end
    if inventoryShrink then
        return
    end

    for i = InventorySlotFirst, InventorySlotPurse do
        if g_game.isOnline() then
            inventoryEvent(player, i, player:getInventoryItem(i))
        else
            inventoryEvent(player, i, nil)
        end
    end
end

local function refreshInventorySizes()
    if inventoryShrink then
        inventoryController.ui:setOn(false)
        inventoryController.ui.onPanel:hide()
        inventoryController.ui.offPanel:show()
    else
        inventoryController.ui:setOn(true)
        inventoryController.ui.onPanel:show()
        inventoryController.ui.offPanel:hide()
        refreshInventory_panel()
    end
    combatEvent()
    walkEvent()
    modules.game_mainpanel.reloadMainPanelSizes()
end

function onSetChaseMode(self, selectedChaseModeButton)
    if selectedChaseModeButton == nil then
        return
    end
    
    local buttonId = selectedChaseModeButton:getId()
    local chaseMode
    if buttonId == 'followPosture' then
        chaseMode = ChaseOpponent
    else
        chaseMode = DontChase
    end
    g_game.setChaseMode(chaseMode)
end

inventoryController = Controller:new()
inventoryController:setUI('inventory', modules.game_interface.getMainRightPanel())

function inventoryController:onInit()
    refreshInventory_panel()
    local ui = getInventoryUi()

    connect(inventoryController.ui.onPanel.pvp, {
        onCheckChange = onSetSafeFight
    })
    connect(inventoryController.ui.offPanel.pvp, {
        onCheckChange = onSetSafeFight
    })
    connect(inventoryController.ui.onPanel.expert, {
        onCheckChange = expertMode
    })
    pvpModeRadioGroup = UIRadioGroup.create()
    pvpModeRadioGroup:addWidget(inventoryController.ui.onPanel.whiteDoveBox)
    pvpModeRadioGroup:addWidget(inventoryController.ui.onPanel.whiteHandBox)
    pvpModeRadioGroup:addWidget(inventoryController.ui.onPanel.yellowHandBox)
    pvpModeRadioGroup:addWidget(inventoryController.ui.onPanel.redFistBox)
    connect(pvpModeRadioGroup, {
        onSelectionChange = onSetPVPMode
    })
end

function inventoryController:onGameStart()
    local player = g_game.getLocalPlayer()
    if player then
        local char = g_game.getCharacterName()
        local lastCombatControls = g_settings.getNode('LastCombatControls')
        if not table.empty(lastCombatControls) then
            if lastCombatControls[char] then
                g_game.setFightMode(lastCombatControls[char].fightMode)
                g_game.setChaseMode(lastCombatControls[char].chaseMode)
                g_game.setSafeFight(lastCombatControls[char].safeFight)
                if lastCombatControls[char].pvpMode then
                    g_game.setPVPMode(lastCombatControls[char].pvpMode)
                end
            end
        end
    end
    inventoryController:registerEvents(LocalPlayer, {
        onInventoryChange = inventoryEvent,
        onSoulChange = onSoulChange,
        onFreeCapacityChange = onFreeCapacityChange
    }):execute()

    inventoryController:registerEvents(g_game, {
        onWalk = walkEvent,
        onAutoWalk = walkEvent,
        onFightModeChange = combatEvent,
        onChaseModeChange = combatEvent,
        onSafeFightChange = combatEvent,
        onPVPModeChange = combatEvent
    }):execute()

    inventoryShrink = g_settings.getBoolean('mainpanel_shrink_inventory')
    refreshInventorySizes()
    refreshInventory_panel()

    local elements = {
        {inventoryController.ui.offPanel.blessings, inventoryController.ui.onPanel.blessings},
        {inventoryController.ui.offPanel.expert, inventoryController.ui.onPanel.expert},
        {inventoryController.ui.onPanel.whiteDoveBox},
        {inventoryController.ui.onPanel.whiteHandBox},
        {inventoryController.ui.onPanel.yellowHandBox},
        {inventoryController.ui.onPanel.redFistBox}
    }
    
    local showBlessings = g_game.getClientVersion() >= 1000
    local showPVPMode = g_game.getFeature(GamePVPMode)
    
    for i, elementGroup in ipairs(elements) do
        local show = (i == 1 and showBlessings) or (i > 1 and showPVPMode)
        for _, element in ipairs(elementGroup) do
            if show then
                element:show()
            else
                element:hide()
            end
        end
    end
    inventoryController.ui.onPanel.purseButton:setVisible(g_game.getFeature(GamePurseSlot))

    if isPlayerMonk() and player then
        local leftItem = player:getInventoryItem(InventorySlotLeft)
        if leftItem then
            updateMonkMirrorItem(leftItem)
        end
    end
end

function inventoryController:onGameEnd()
    stopEvent()
    monkMirrorItem = nil

    local lastCombatControls = g_settings.getNode('LastCombatControls')
    if not lastCombatControls then
        lastCombatControls = {}
    end
    local player = g_game.getLocalPlayer()
    if player then
        local char = g_game.getCharacterName()
        lastCombatControls[char] = {
            fightMode = g_game.getFightMode(),
            chaseMode = g_game.getChaseMode(),
            safeFight = g_game.isSafeFight()
        }
        if g_game.getFeature(GamePVPMode) then
            lastCombatControls[char].pvpMode = g_game.getPVPMode()
        end
        g_settings.setNode('LastCombatControls', lastCombatControls)
    end
end

function inventoryController:onTerminate()
    if iconTopMenu then
        iconTopMenu:destroy()
        iconTopMenu = nil
    end
    if pvpModeRadioGroup then
        disconnect(pvpModeRadioGroup, {
            onSelectionChange = onSetPVPMode
        })
        pvpModeRadioGroup:destroy()
        pvpModeRadioGroup = nil
    end
end

function onSetSafeFight(self, checked)
    if not checked then
        inventoryController.ui.onPanel.pvp:setChecked(false)
        inventoryController.ui.offPanel.pvp:setChecked(false)
      else
        inventoryController.ui.onPanel.pvp:setChecked(true)  
        inventoryController.ui.offPanel.pvp:setChecked(true)  
      end
    g_game.setSafeFight(not checked)
    if not checked then
        g_game.cancelAttack()
    end
end

function selectPosture(key, ignoreUpdate)
    local ui = getInventoryUi()
    if key == 'stand' then
        ui.standPosture:setEnabled(false)
        ui.followPosture:setEnabled(true)
        if not ignoreUpdate then
            g_game.setChaseMode(DontChase)
        end
    elseif key == 'follow' then
        ui.standPosture:setEnabled(true)
        ui.followPosture:setEnabled(false)
        if not ignoreUpdate then
            g_game.setChaseMode(ChaseOpponent)
        end
    end
end

function selectCombat(combat, ignoreUpdate)
    local ui = getInventoryUi()
    if combat == 'attack' then
        ui.attack:setEnabled(false)
        ui.balanced:setEnabled(true)
        ui.defense:setEnabled(true)
        if not ignoreUpdate then
            g_game.setFightMode(FightOffensive)
        end
    elseif combat == 'balanced' then
        ui.attack:setEnabled(true)
        ui.balanced:setEnabled(false)
        ui.defense:setEnabled(true)
        if not ignoreUpdate then
            g_game.setFightMode(FightBalanced)
        end
    elseif combat == 'defense' then
        ui.attack:setEnabled(true)
        ui.balanced:setEnabled(true)
        ui.defense:setEnabled(false)
        if not ignoreUpdate then
            g_game.setFightMode(FightDefensive)
        end
    end
end

function expertMode(self, checked)
    local ui = getInventoryUi()

    ui.whiteDoveBox:setVisible(checked)
    ui.whiteHandBox:setVisible(checked)
    ui.yellowHandBox:setVisible(checked)
    ui.redFistBox:setVisible(checked)
end

function onSetPVPMode(self, selectedPVPButton)
    if selectedPVPButton == nil then
        return
    end

    local buttonId = selectedPVPButton:getId()
    local pvpMode = PVPWhiteDove

    if buttonId == 'whiteDoveBox' then
        pvpMode = PVPWhiteDove
    elseif buttonId == 'whiteHandBox' then
        pvpMode = PVPWhiteHand
    elseif buttonId == 'yellowHandBox' then
        pvpMode = PVPYellowHand
    elseif buttonId == 'redFistBox' then
        pvpMode = PVPRedFist
    end
    g_game.setPVPMode(pvpMode)
end

function changeInventorySize()
    inventoryShrink = not inventoryShrink
    g_settings.set('mainpanel_shrink_inventory', inventoryShrink)
    refreshInventorySizes()
    modules.game_mainpanel.reloadMainPanelSizes()
    local player = g_game.getLocalPlayer()
    if player and g_game.isOnline() then
        onFreeCapacityChange(player, player:getFreeCapacity())
        onSoulChange(player, player:getSoul())
    end
end

function getSlot5()
    return inventoryController.ui.onPanel.shield
end

function reloadInventory()
    if modules.client_options.getOption('showExpiryInInvetory') then
        updateSlotsDuration()
    end
    
    for slot, getSlotInfo in pairs(getSlotPanelBySlot) do
        local ui = getInventoryUi()
        local slotPanel, toggler = getSlotInfo(ui)
        if slotPanel then
            local player = g_game.getLocalPlayer()
            if player then
                inventoryEvent(player, slot, player:getInventoryItem(slot))
            end
        end
    end
end

function extendedView(extendedView)
    if extendedView then
        if not iconTopMenu then
            iconTopMenu = modules.client_topmenu.addTopRightToggleButton('inventory', tr('Show inventory'),
                '/images/topbuttons/inventory', toggle)
            iconTopMenu:setOn(inventoryController.ui:isVisible())
            inventoryController.ui:setBorderColor('black')
            inventoryController.ui:setBorderWidth(2)
        end
    else
        if iconTopMenu then
            iconTopMenu:destroy()
            iconTopMenu = nil
        end
        inventoryController.ui:setBorderColor('alpha')
        inventoryController.ui:setBorderWidth(0)
        local mainRightPanel = modules.game_interface.getMainRightPanel()
        if not mainRightPanel:hasChild(inventoryController.ui) then
            mainRightPanel:insertChild(3, inventoryController.ui)
        end
        inventoryController.ui:show()
    end
    inventoryController.ui.moveOnlyToMain = not extendedView

end

function toggle()
    if iconTopMenu:isOn() then
        inventoryController.ui:hide()
        iconTopMenu:setOn(false)
    else
        inventoryController.ui:show()
        iconTopMenu:setOn(true)
    end
end

function toggleAdventurerStyle(hasBlessing)
    for slot, getSlotInfo in pairs(getSlotPanelBySlot) do
        local ui = getInventoryUi()
        local slotPanel, toggler = getSlotInfo(ui)
        if slotPanel then
            slotPanel:setOn(hasBlessing)
        end
    end
end

function onBlessingsChange(blessings, blessVisualState)
    toggleAdventurerStyle(blessings == 1)
    local blessedButton = getInventoryUi().blessings
--[[     local tooltip = 'You are protected by the following blessings:'
        tooltip = tooltip .. '\nTwist of Fate'
        tooltip = tooltip .. '\nWisdom of Solitude'
        tooltip = tooltip .. '\nSpark of the Phoenix'
        tooltip = tooltip .. '\nFire of the Suns'
        tooltip = tooltip .. '\nSpiritual Shielding'
        tooltip = tooltip .. '\nEmbrace of Tibia'
        tooltip = tooltip .. '\nHeart of the Mountain'
        tooltip = tooltip .. '\nBlood of the Mountain'
        blessedButton:setTooltip(tooltip) ]]
    if blessVisualState == 1 then
        blessedButton:setImageSource('/images/inventory/button_blessings_grey')
    elseif blessVisualState == 2 then
        blessedButton:setImageSource('/images/inventory/button_blessings_gold')
    elseif blessVisualState == 3 then
        blessedButton:setImageSource('/images/inventory/button_blessings_green')
    end
end
