ForgeController = Controller:new()
ForgeButton = nil

local cloneValue = Helpers.cloneValue
local normalizeClassPriceEntries = Helpers.normalizeClassPriceEntries
local normalizeTierPriceEntries = Helpers.normalizeTierPriceEntries
-- Don't cache formatHistoryDate as a local since it may be updated
-- local formatHistoryDate = Helpers.formatHistoryDate

-- Store all callback references to prevent garbage collection
ForgeController.callbacks = {}

ForgeController.showResult = false
ForgeController.showBonus = false

local rightArrow = Helpers.rightArrow
local filledRightArrow = Helpers.filledRightArrow
ForgeController.result = cloneValue(Helpers.baseResult)
ForgeController.baseResult = Helpers.baseResult

function ForgeController:onGameStart()
    if g_game.getFeature(GameForgeConvergence) then -- Summer Update 2017
        self:updateResourceBalances()
        
        -- Store event callbacks to prevent garbage collection
        self.callbacks.onBrowseForgeHistory = onBrowseForgeHistory
        self.callbacks.forgeData = forgeData
        self.callbacks.onOpenForge = onOpenForge
        self.callbacks.forgeResultData = forgeResultData
        self.callbacks.onResourcesBalanceChange = function() self:updateResourceBalances() end
        
        self:registerEvents(g_game, {
            onBrowseForgeHistory = self.callbacks.onBrowseForgeHistory,
            forgeData = self.callbacks.forgeData,
            onOpenForge = self.callbacks.onOpenForge,
            onResourcesBalanceChange = self.callbacks.onResourcesBalanceChange,
            forgeResultData = self.callbacks.forgeResultData
        })

        if not ForgeButton then
            ForgeButton = modules.game_mainpanel.addToggleButton('ForgeButton', tr('Open Exaltation Forge'),
                '/images/options/button-exaltation-forge.png', function()
                    self:toggle()
                end)
        end
        self.currentTab = 'conversion'
    else
        -- Store unload callback
        self.callbacks.unloadModule = function()
            g_modules.getModule("game_forge"):unload()
        end
        scheduleEvent(self.callbacks.unloadModule, 100)
    end
end

local function resetInfo()
    ForgeController.transfer.exaltedCoresLabel = "???"
    ForgeController.transfer.selected = cloneValue(ForgeController.baseSelected)
    ForgeController.transfer.selectedTarget = cloneValue(ForgeController.baseSelected)
    ForgeController.rawPrice = 0
    ForgeController.formattedPrice = "???"
    ForgeController.transfer.canTransfer = false
    ForgeController.transfer.isConvergence = false
    ForgeController.transfer.title = "Transfer Requirements"
    ForgeController.transfer.dustLabel = ForgeController.transfer.dust
    ForgeController.transfer.currentList = cloneValue(ForgeController.transfer.items)
    ForgeController.fusion.title = "Further Items Needed For Fusion"
    ForgeController.fusion.selected = cloneValue(ForgeController.baseSelected)
    ForgeController.fusion.selectedTarget = cloneValue(ForgeController.baseSelected)
    ForgeController.fusion.isConvergence = false
    ForgeController.fusion.canTransfer = false
    ForgeController.fusion.canFusion = false
    ForgeController.fusion.chanceImprovedChecked = false
    ForgeController.fusion.reduceTierLossChecked = false
    ForgeController.fusion.dustLabel = ForgeController.fusion.dust
    ForgeController.fusion.currentList = cloneValue(ForgeController.fusion.items)
    ForgeController.showResult = false
    ForgeController.showBonus = false
    ForgeController.result = cloneValue(Helpers.baseResult)
    ForgeController.description = ""
    ForgeController.waitingForResult = false
    if ForgeController.resultTimeout then
        removeEvent(ForgeController.resultTimeout)
        ForgeController.resultTimeout = nil
    end
end

function ForgeController:handleDescription(currentType)
    Helpers.handleDescription(ForgeController, currentType)
end

function ForgeController:show(skipRequest)
    if not g_game.getFeature(GameForgeConvergence) then
        return ForgeController:hide()
    end
    resetInfo()
    local needsReload = not self.ui or self.ui:isDestroyed()
    if needsReload then
        self:loadHtml('game_forge.html')
    end

    if not self.ui then
        return
    end

    if not skipRequest then
        g_game.openPortableForgeRequest()
    end

    self.ui:centerIn('parent')
    self.ui:show()
    self.ui:raise()
    self.ui:focus()

    if ForgeButton then
        ForgeButton:setOn(true)
    end

    self:updateResourceBalances()
end

function ForgeController:hide()
    resetInfo()
    if not self.ui then
        return
    end

    self.ui:hide()

    if ForgeButton then
        ForgeButton:setOn(false)
    end
    if self.ui and not self.ui:isDestroyed() then
        self.ui:destroy()
    end
    self.ui = nil
end

function ForgeController:toggle()
    ForgeController:toggleConversionMenu()
    resetInfo()
    if ForgeController.rawData then
        forgeData(ForgeController.rawData)
    end
    if not self.ui or self.ui:isDestroyed() then
        self:show()
        return
    end

    if self.ui:isVisible() then
        self:hide()
    else
        self:show()
    end
end

ForgeController.currentDust = 0
ForgeController.currentSlivers = 0
ForgeController.currentExaltedCores = 0
ForgeController.rawCurrentGold = 0
ForgeController.currentGold = 0

ForgeController.currentTab = 'conversion'
function ForgeController:updateResourceBalances()
    if not self.ui then
        return
    end

    local player = g_game.getLocalPlayer()
    self.currentDust = player:getResourceBalance(ResourceTypes.FORGE_DUST or 70)
    self.currentSlivers = player:getResourceBalance(ResourceTypes.FORGE_SLIVER)
    self.currentExaltedCores = player:getResourceBalance(ResourceTypes.FORGE_CORES)
    self.rawCurrentGold = player:getTotalMoney() or 0
    self.currentGold = comma_value(self.rawCurrentGold)
end

ForgeController.baseSelected = {
    id = -1,
    tier = 0,
    clip = {},
    imagePath = nil,
    rarityClipObject = nil,
    count = 0,
    countLabel = "0 / 1",
    key = "",
    targetTier = 0
}

function ForgeController:onInit()
end

function ForgeController:terminate()
    -- Clean up any pending events
    if ForgeController.resultTimeout then
        removeEvent(ForgeController.resultTimeout)
        ForgeController.resultTimeout = nil
    end
    
    -- Clean up all stored callbacks
    if ForgeController.callbacks then
        for key, _ in pairs(ForgeController.callbacks) do
            ForgeController.callbacks[key] = nil
        end
        ForgeController.callbacks = {}
    end
    
    -- Reset flags
    ForgeController.waitingForResult = false
    ForgeController.showResult = false
    ForgeController.showBonus = false
    
    -- Hide UI
    if self.ui and not self.ui:isDestroyed() then
        self:hide()
    end
    
    -- Remove button
    if ForgeButton then
        ForgeButton:destroy()
        ForgeButton = nil
    end
end

function ForgeController:getPrice(prices, itemId, currentTier, isConvergence, isTransfer)
    local price = 0
    local tierIndex = (tonumber(currentTier) or 0) + 1

    if isTransfer and isConvergence then
        for tier, _price in pairs(prices) do
            if isConvergence then
                tier = tier > 1 and (tier - 1) or tier
            end
            if currentTier == tier then
                price = tonumber(_price) or 0
                break
            end
        end
    elseif isConvergence then
        for tier, _price in pairs(prices) do
            if tierIndex == tier then
                price = tonumber(_price) or 0
                break
            end
        end
    else
        local itemPtr = Item.create(itemId, 1)

        local classification = itemPtr and itemPtr.getClassification and itemPtr:getClassification() or 0
        if classification <= 0 then return 0 end

        for class, tiers in pairs(prices) do
            if class == classification then
                for tier, _price in pairs(tiers) do
                    if tier == tierIndex or (isTransfer and tier == currentTier) then
                        price = tonumber(_price) or 0
                        break
                    end
                end
            end
        end
    end

    self.rawPrice = price
    self.formattedPrice = comma_value(price)
    return self.formattedPrice
end

local forgeActions = {
    FUSION = 0,
    TRANSFER = 1
}

-- Named callback functions to prevent garbage collection issues
ForgeController.callbacks.closeResultCallback = function()
    ForgeController.showResult = false
    ForgeController.showBonus = false

    ForgeController:hide()
    if ForgeController.rawOpenForgeData then
        onOpenForge(ForgeController.rawOpenForgeData)
    end
end

ForgeController.callbacks.updateBonusButton = function()
    ForgeController.result.button = "Close"
    ForgeController.result.bonusAction = ForgeController.callbacks.closeResultCallback
end

ForgeController.callbacks.showBonusCallback = function()
    ForgeController.showResult = false
    ForgeController.showBonus = true

    -- Use the stored callback
    scheduleEvent(ForgeController.callbacks.updateBonusButton, 150)
end

function ForgeController:closeResult()
    ForgeController.callbacks.closeResultCallback()
end

function ForgeController:forgeAction(isTransfer)
    local data = isTransfer and ForgeController.transfer or ForgeController.fusion
    local canDoAction = isTransfer and data.canTransfer or data.canFusion
    if data.selected.id == -1 then return end
    if data.selectedTarget.id == -1 then return end
    if not canDoAction then return end

    if ForgeController.rawPrice <= 0 then return end
    if ForgeController.rawCurrentGold < ForgeController.rawPrice then return end
    if ForgeController.currentDust < data.dust then return end

    if isTransfer then
        if ForgeController.currentExaltedCores < data.necessaryExaltedCores then return end
    end

    local actionType = isTransfer and forgeActions.TRANSFER or forgeActions.FUSION

    local chanceImproved = false
    local reduceTierLoss = false

    if not isTransfer then
        chanceImproved = data.chanceImprovedChecked
        reduceTierLoss = data.reduceTierLossChecked
    end

    -- Set a flag to indicate we're waiting for a result
    ForgeController.waitingForResult = true
    
    -- Set a timeout to show an error if no result is received
    if ForgeController.resultTimeout then
        removeEvent(ForgeController.resultTimeout)
    end
    
    -- Store the callback function to maintain a reference
    ForgeController.callbacks.timeoutCallback = function()
        if ForgeController.waitingForResult then
            ForgeController.waitingForResult = false
            -- If no result received after 5 seconds, refresh the forge window
            if ForgeController.rawOpenForgeData then
                onOpenForge(ForgeController.rawOpenForgeData)
            end
        end
    end
    
    ForgeController.resultTimeout = scheduleEvent(ForgeController.callbacks.timeoutCallback, 5000)

    g_game.forgeRequest(actionType, data.isConvergence, data.selected.id, data.selected.tier,
        data.selectedTarget.id, chanceImproved, reduceTierLoss)
end

function ForgeController:resultSystemEvent()
    ForgeController.result.buttonLabel = "Close"

    if not ForgeController.ui or ForgeController.ui:isDestroyed() then
        return
    end

    if ForgeController.result.eventCount == 1 then
        ForgeController.result.arrows = {
        { arrow = Helpers.filledRightArrow, },
            { arrow = Helpers.rightArrow, },
            { arrow = Helpers.rightArrow, }

        }
    elseif ForgeController.result.eventCount == 2 then
        ForgeController.result.arrows = {
            { arrow = Helpers.filledRightArrow, },
            { arrow = Helpers.filledRightArrow, },
            { arrow = Helpers.rightArrow, }
        }
    elseif ForgeController.result.eventCount == 3 then
        ForgeController.result.arrows = {
            { arrow = Helpers.filledRightArrow, },
            { arrow = Helpers.filledRightArrow, },
            { arrow = Helpers.filledRightArrow, }

        }
    elseif ForgeController.result.eventCount == 4 then
        ForgeController.result.arrows = {
            { arrow = Helpers.rightArrow, },
            { arrow = Helpers.filledRightArrow, },
            { arrow = Helpers.filledRightArrow, }
        }
    elseif ForgeController.result.eventCount == 5 then
        ForgeController.result.arrows = {
            { arrow = Helpers.rightArrow, },
            { arrow = Helpers.rightArrow, },
            { arrow = Helpers.filledRightArrow, }
        }
    elseif ForgeController.result.eventCount == 6 then
        ForgeController.result.arrows = {
            { arrow = Helpers.rightArrow, },
            { arrow = Helpers.rightArrow, },
            { arrow = Helpers.rightArrow, }
        }
        if (ForgeController.result.bonus or 0) > 0 then
            ForgeController.result.buttonLabel = "Next"
        end

        if ForgeController.result.success then
            ForgeController.result.rightShader = "Outfit - ForgeSuccess"
            ForgeController.result.label = "Your transfer attempt was "
            ForgeController.result.labelResult = "successful."
            ForgeController.result.color = Helpers.green

            ForgeController.result.rightShader = ""
            ForgeController.result.leftItemId = -1
            ForgeController.result.leftTier = 0
        else
            ForgeController.result.label = "Your transfer attempt was "
            ForgeController.result.labelResult = "failed."
            ForgeController.result.rightShader = "Outfit - ForgeFailed"
            ForgeController.result.leftShader = ""
            ForgeController.result.color = Helpers.red

            -- Store the callback to maintain reference
            ForgeController.callbacks.clearRightItem = function()
                ForgeController.result.rightItemId = -1
                ForgeController.result.rightTier = 0
            end
            scheduleEvent(ForgeController.callbacks.clearRightItem, 1000)
        end
        return
    end

    ForgeController.result.eventCount = (ForgeController.result.eventCount or 0) + 1
    -- Store the callback to maintain reference
    ForgeController.callbacks.continueAnimation = function()
        ForgeController:resultSystemEvent()
    end
    scheduleEvent(ForgeController.callbacks.continueAnimation, 750)
end

function forgeResultData(rawData)
    -- Clear the waiting flag and timeout
    ForgeController.waitingForResult = false
    if ForgeController.resultTimeout then
        removeEvent(ForgeController.resultTimeout)
        ForgeController.resultTimeout = nil
    end
    
    -- Ensure UI is loaded before showing results
    if not ForgeController.ui or ForgeController.ui:isDestroyed() then
        ForgeController:show(true)
    end
    
    if not ForgeController.ui then
        -- UI failed to load, abort
        return
    end
    
    ForgeController.result = cloneValue(Helpers.baseResult)
    ForgeController.showResult = true
    ForgeController.showBonus = false
    local data = cloneValue(rawData)
    if type(data) == 'table' then
        for key, value in pairs(data) do
            ForgeController.result[key] = value
        end
    end

    if ForgeController.result.leftTier > 0 then
        ForgeController.result.leftClip = ItemsDatabase.getTierClip(ForgeController.result.leftTier)
    end

    if ForgeController.result.rightTier > 0 then
        ForgeController.result.rightClip = ItemsDatabase.getTierClip(ForgeController.result.rightTier)
    end

    ForgeController.result.arrows = {
        { arrow = Helpers.filledRightArrow, },
        { arrow = Helpers.rightArrow, },
        { arrow = Helpers.rightArrow, }
    }
    ForgeController.result.buttonLabel = "Close"
    ForgeController.result.bonusLabel = "-"


    ForgeController.result.label = ""
    if ForgeController.fusion.selected and ForgeController.fusion.selected.id ~= -1 then
        if ForgeController.fusion.isConvergence then
            ForgeController.result.title = "Convergence Fusion Result"
        else
            ForgeController.result.title = "Fusion Result"
        end
    end
    if ForgeController.transfer.selected and ForgeController.transfer.selected.id ~= -1 then
        if ForgeController.transfer.isConvergence then
            ForgeController.result.title = "Convergence Transfer Result"
        else
            ForgeController.result.title = "Transfer Result"
        end
    end
    if ForgeController.result.bonus == 0 then
        ForgeController.result.bonusAction = ForgeController.callbacks.closeResultCallback
    else
        ForgeController.result.buttonLabel = "Next"

        local isConvergence = ForgeController.transfer.selected == -1 and ForgeController.fusion.isConvergence
        if ForgeController.result.bonus == 1 then
            ForgeController.result.bonusItem = 37160
            local dust = isConvergence and ForgeController.fusion.convergenceDust or ForgeController.transfer.dust
            ForgeController.result.bonusLabel = string.format("Near! The used %s where not consumed.", dust)
        elseif ForgeController.result.bonus == 2 then
            if ForgeController.fusion.chanceImprovedChecked or ForgeController.fusion.reduceTierLossChecked then
                ForgeController.result.bonusItem = 37110
                ForgeController.result.bonusLabel = string.format("Fantastic! The used %s where not consumed.",
                    ForgeController.result.coreCount)
            end
        elseif ForgeController.result.bonus == 3 then
            ForgeController.result.bonusItem = 3031
            ForgeController.result.bonusLabel = string.format("Awesome! The used %s where not consumed.",
                comma_value(ForgeController.rawPrice))
        elseif ForgeController.result.bonus == 4 then
            ForgeController.result.bonusItem = ForgeController.result.leftItemId
            if ForgeController.result.rightTier >= 2 then
                ForgeController.result.bonusTier = ForgeController.result.rightTier - 1
                ForgeController.result.bonusItemClip = ItemsDatabase.getTierClip(ForgeController.result.bonusTier)
            end
            ForgeController.result.bonusLabel = "What luck! Your item only lost one tier instead of being\nconsumed."
        end

        ForgeController.result.bonusAction = ForgeController.callbacks.showBonusCallback
    end

    ForgeController.result.leftShader = "Outfit - ForgeDonor"
    ForgeController.result.rightShader = "Outfit - cyclopedia-black"
    ForgeController.result.eventCount = 1
    ForgeController.callbacks.startResultAnimation = function()
        ForgeController:resultSystemEvent()
    end
    scheduleEvent(ForgeController.callbacks.startResultAnimation, 750)
end

local buttonClip = { x = 0, y = 0, width = 43, height = 20 }
local buttonClipPressed = { x = 0, y = 20, width = 43, height = 20 }
-- FUSION MENU
ForgeController.fusion = {
    prices = {},
    convergencePrices = {},
    grades = {},
    dust = 100,
    convergenceDust = 130,
    reduceTierLoss = 50,
    reduceTierLossLabel = "100%",
    reduceTierLossButtonClip = buttonClip,
    reduceTierLossChecked = false,
    reduceTierLossBase = 100,
    chanceImprovedLabel = "50%",
    chanceImprovedButtonClip = buttonClip,
    chanceImprovedChecked = false,
    chanceImproved = 15,
    chanceBase = 50,
    dustLabel = 100,
    hasConvergence = false,
    isConvergence = false,
    title = "Further Items Needed For Fusion",

    clip = { x = 0, y = 0, width = 116, height = 34 },
    items = {},
    selected = cloneValue(ForgeController.baseSelected),
    selectedTarget = cloneValue(ForgeController.baseSelected),
    canFusion = false,
    currentList = {},
}

-- Store callback in ForgeController to prevent garbage collection
ForgeController.fusion.handleSelect = function(item)
    ForgeController.fusion.selectedTarget = cloneValue(ForgeController.baseSelected)
    ForgeController:handleSelect(ForgeController.fusion, item, false)
end

-- Store callback in ForgeController to prevent garbage collection
ForgeController.fusion.exaltedCoreImprovements = function(currentType)
    if currentType == 'improve-chance' then
        ForgeController.fusion.chanceImprovedChecked = not ForgeController.fusion.chanceImprovedChecked
        if ForgeController.fusion.chanceImprovedChecked then
            ForgeController.fusion.chanceImprovedButtonClip = buttonClipPressed
            ForgeController.fusion.chanceImprovedLabel = tostring(ForgeController.fusion.chanceBase +
                ForgeController.fusion.chanceImproved) .. "%"
        else
            ForgeController.fusion.chanceImprovedButtonClip = buttonClip
            ForgeController.fusion.chanceImprovedLabel = tostring(ForgeController.fusion.chanceBase) .. "%"
        end
    elseif currentType == 'reduce-loss' then
        ForgeController.fusion.reduceTierLossChecked = not ForgeController.fusion.reduceTierLossChecked
        if ForgeController.fusion.reduceTierLossChecked then
            ForgeController.fusion.reduceTierLossButtonClip = buttonClipPressed
            ForgeController.fusion.reduceTierLossLabel = tostring(ForgeController.fusion.reduceTierLoss) .. "%"
        else
            ForgeController.fusion.reduceTierLossButtonClip = buttonClip
            ForgeController.fusion.reduceTierLossLabel = tostring(ForgeController.fusion.reduceTierLossBase) .. "%"
        end
    end
end

function ForgeController:toggleFusionMenu()
    self:resetTabsClip()
    self.currentTab = 'fusion'
    self.fusion.clip = { x = 0, y = 34, width = 116, height = 34 }
end

-- TRANSFER MENU
ForgeController.transfer = {
    prices = {},
    convergencePrices = {},
    grades = {},
    dust = 100,
    convergenceDust = 160,
    hasConvergence = false,
    title = "Transfer Requirements",
    dustLabel = 100,
    exaltedCoresLabel = "???",
    necessaryExaltedCores = 0,
    clip = { x = 0, y = 0, width = 116, height = 34 },
    isConvergence = false,
    items = {
        donors = {},
        receivers = {}
    },
    convergenceItems = {
        donors = {},
        receivers = {}
    },
    currentList = {
        donors = {},
        receivers = {}
    },
    selected = cloneValue(ForgeController.baseSelected),
    selectedTarget = cloneValue(ForgeController.baseSelected),
    canTransfer = false
}
function ForgeController:toggleTransferMenu()
    self:resetTabsClip()
    self.currentTab = 'transfer'
    self.transfer.clip = { x = 0, y = 34, width = 116, height = 34 }
end

local function handleFusionItems(data)
    local currentList = {}

    for i, item in pairs(data) do
        item.key = ("%d_%d"):format(item.id, item.tier)
        if item.tier > 0 then
            item.clip = ItemsDatabase.getTierClip(item.tier)
        end

        local _, imagePath, rarityClipObject = ItemsDatabase.getClipAndImagePath(item.id)
        if imagePath then
            item.imagePath = imagePath
            item.rarityClipObject = rarityClipObject
        end

        item.countLabel = string.format("%d / %d", item.count, 1)
        table.insert(currentList, item)
    end

    table.sort(currentList, function(a, b)
        if a.tier == b.tier then
            return a.id < b.id
        end
        return a.tier > b.tier
    end)

    return currentList
end

function ForgeController:handleSelect(data, item, isTransfer)
    data.selected = cloneValue(ForgeController.baseSelected)
    data.selectedTarget = cloneValue(ForgeController.baseSelected)
    data.canFusion = false
    data.canTransfer = false
    local isConvergence = data.isConvergence

    if isTransfer then
        data.selected = item
        local targetTier = isConvergence and item.tier or (item.tier - 1)
        for _, values in pairs(data.grades) do
            if values.tier == targetTier then
                data.exaltedCoresLabel = values.exaltedCores
                data.necessaryExaltedCores = values.exaltedCores
                break
            end
        end

        local list = isConvergence and data.convergenceItems or data.items
        local receivers = {}
        for _, _item in pairs(list.receivers) do
            if item.id ~= _item.id then
                table.insert(receivers, _item)
            end
        end

        data.currentList.receivers = receivers
    else
        data.selected = cloneValue(item)
        data.selected.targetTier = data.selected.tier + 1
        data.selected.targetClip = ItemsDatabase.getTierClip(data.selected.targetTier)
        local _, imagePath, rarityClipObject = ItemsDatabase.getClipAndImagePath(data.selected.id)
        if imagePath then
            data.selected.imagePath = imagePath
            data.selected.rarityClipObject = rarityClipObject
        end

        if not isConvergence then
            data.selectedTarget = cloneValue(item)
            data.selectedTarget.targetTier = data.selectedTarget.tier + 1
            data.selectedTarget.targetClip = ItemsDatabase.getTierClip(data.selectedTarget.targetTier)
            local _, imagePath, rarityClipObject = ItemsDatabase.getClipAndImagePath(data.selectedTarget.id)
            if imagePath then
                data.selectedTarget.imagePath = imagePath
                data.selectedTarget.rarityClipObject = rarityClipObject
            end
        end
    end

    local prices = isConvergence and data.convergencePrices or data.prices
    ForgeController:getPrice(prices, item.id, data.selected.tier, isConvergence, isTransfer)

    if ForgeController.rawPrice > 0 and ForgeController.rawCurrentGold >= ForgeController.rawPrice then
        if ForgeController.currentDust >= ForgeController.fusion.dust then
            if isConvergence then return end
            ForgeController.fusion.canFusion = true
        end
    end
end

-- Store callback in ForgeController to prevent garbage collection
ForgeController.transfer.handleSelect = function(item)
    ForgeController.transfer.exaltedCoresLabel = "???"
    if not item then
        return
    end
    ForgeController:handleSelect(ForgeController.transfer, item, true)
end

function ForgeController:handleSelectTarget(item, isTransfer)
    local data = isTransfer and ForgeController.transfer or ForgeController.fusion
    data.selectedTarget = cloneValue(ForgeController.baseSelected)

    ForgeController.transfer.canTransfer = false
    ForgeController.fusion.canFusion = false
    if not item then
        return
    end

    data.selectedTarget = cloneValue(item)
    local targetTier = 0
    if isTransfer then
        targetTier = data.isConvergence and data.selected.tier or (data.selected.tier - 1)
    else
        targetTier = data.selected.tier + 1
    end

    data.selectedTarget.targetTier = targetTier
    data.selectedTarget.clip = ItemsDatabase.getTierClip(data.selectedTarget.targetTier)
    local _, imagePath, rarityClipObject = ItemsDatabase.getClipAndImagePath(item.id)
    if imagePath then
        data.selectedTarget.imagePath = imagePath
        data.selectedTarget.rarityClipObject = rarityClipObject
    end

    if ForgeController.currentDust < data.dust then return end

    if ForgeController.rawPrice > 0 and ForgeController.rawCurrentGold >= ForgeController.rawPrice then
        if isTransfer then
            if ForgeController.currentExaltedCores < ForgeController.transfer.necessaryExaltedCores then
                return
            end
            data.canTransfer = true
        else
            -- For convergence fusion, we need at least 2 items of the same type
            if data.isConvergence then
                if item.count >= 2 then
                    data.canFusion = true
                end
            else
                data.canFusion = true
            end
        end
    end
end

function ForgeController:toggleConvergence(isTransfer)
    local data = isTransfer and ForgeController.transfer or ForgeController.fusion
    data.isConvergence = not data.isConvergence
    data.selected = cloneValue(ForgeController.baseSelected)
    data.selectedTarget = cloneValue(ForgeController.baseSelected)
    ForgeController.formattedPrice = "???"
    ForgeController.rawPrice = 0

    if isTransfer then
        data.canTransfer = false
        if not data.isConvergence then
            data.currentList = cloneValue(data.items)
            data.title = "Transfer Requirements"
            data.dustLabel = data.dust
        else
            data.currentList = cloneValue(data.convergenceItems)
            data.title = "Convergence Transfer Requirements"
            data.dustLabel = data.convergenceDust
        end
    else
        data.canFusion = false
        if not data.isConvergence then
            data.currentList = cloneValue(data.items)
            data.title = "Further Items Needed For Fusion"
            data.dustLabel = data.dust
        else
            data.dustLabel = data.convergenceDust
            data.currentList = cloneValue(data.convergenceItems)
            data.title = "Further Items Needed For Convergence Fusion"
        end
    end
end

-- TRANSFER MENU

local function handleTransferItems(data)
    local currentList = {
        donors = {},
        receivers = {}
    }
    for slot, currentType in pairs(data) do
        for transferType in pairs(currentType) do
            for __, item in pairs(currentType[transferType]) do
                item.key = string.format("%d_%d", item.id, item.tier)
                item.slot = slot
                if item.tier > 0 then
                    item.clip = ItemsDatabase.getTierClip(item.tier)
                end
                local _, imagePath, rarityClipObject = ItemsDatabase.getClipAndImagePath(item.id)
                if imagePath then
                    item.imagePath = imagePath
                    item.rarityClipObject = rarityClipObject
                end
                item.countLabel = string.format("%d / %d", item.count, 1)
                table.insert(currentList[transferType], item)
            end
        end
    end

    table.sort(currentList.donors, function(a, b)
        if a.tier == b.tier then
            return a.id < b.id
        end
        return a.tier > b.tier
    end)


    return currentList
end

local function handleParseConvergenceFusionItems(data)
    local parsedItemsBySlot = {}
    for slot, sloItems in pairs(data) do
        for _, item in pairs(sloItems) do
            item.key = ("%d_%d"):format(item.id, item.tier)
            item.slot = slot
            if item.tier > 0 then
                item.clip = ItemsDatabase.getTierClip(item.tier)
            end

            local _, imagePath, rarityClipObject = ItemsDatabase.getClipAndImagePath(item.id)
            if imagePath then
                item.imagePath = imagePath
                item.rarityClipObject = rarityClipObject
            end

            table.insert(parsedItemsBySlot, item)
        end
    end

    return data, parsedItemsBySlot
end

function onOpenForge(data)
    ForgeController.rawOpenForgeData = data
    
    -- Don't update if we're showing the result animation or waiting for result
    if ForgeController.showResult or ForgeController.showBonus or ForgeController.waitingForResult then
        return
    end
    
    ForgeController.fusion.chanceImprovedChecked = false
    ForgeController.fusion.reduceTierLossChecked = false
    ForgeController.conversion.dustMax = data.dustLevel or ForgeController.conversion.dustMax or 100

    -- FUSION ITEMS
    local items = cloneValue(data.fusionItems or {})
    local fusionItems = handleFusionItems(items)
    ForgeController.fusion.items = fusionItems
    ForgeController.fusion.currentList = cloneValue(fusionItems)
    local convergenceFusion = cloneValue(data.convergenceFusion or {})
    local _, convergenceItemsBySlot = handleParseConvergenceFusionItems(convergenceFusion)
    ForgeController.fusion.convergenceItems = convergenceItemsBySlot
    -- FUSION ITEMS

    -- TRANSFER ITEMS
    local transfers = cloneValue(data.transfers or {})
    local transferItems = handleTransferItems(transfers)
    ForgeController.transfer.items = transferItems
    ForgeController.transfer.currentList = cloneValue(transferItems)

    local convergenceTransfers = cloneValue(data.convergenceTransfers or {})
    local convergenceTransferItems = handleTransferItems(convergenceTransfers)
    ForgeController.transfer.convergenceItems = convergenceTransferItems
    -- TRANSFER ITEMS

    local shouldShow = not ForgeController.ui or ForgeController.ui:isDestroyed() or not ForgeController.ui:isVisible()
    if shouldShow then
        ForgeController:show(true)
        ForgeController:toggleFusionMenu()
    end
end

function forgeData(data)
    ForgeController.rawData = data
    ForgeController:updateResourceBalances()
    -- FUSION
    local classPrices = normalizeClassPriceEntries(data.classPrices)
    if next(classPrices) then
        ForgeController.fusion.prices = classPrices
    end

    local convergenceFusion = normalizeTierPriceEntries(data.convergenceFusionPrices)
    if next(convergenceFusion) then
        ForgeController.fusion.convergencePrices = convergenceFusion
    end

    ForgeController.fusion.grades = data.fusionGrades or {}
    ForgeController.fusion.convergenceDust = data.convergenceFusionDust or 130
    ForgeController.fusion.dust = data.normalDustFusion or 100
    ForgeController.fusion.reduceTierLoss = data.fusionReduceTierLoss or 50
    ForgeController.fusion.chanceImproved = data.fusionChanceImproved or 15
    ForgeController.fusion.chanceBase = data.fusionChanceBase or 50
    ForgeController.fusion.hasConvergence = data.hasConvergence or false
    ForgeController.fusion.dustLabel = ForgeController.fusion.dust
    -- FUSION

    -- TRANSFER
    ForgeController.transfer.prices = ForgeController.fusion.prices or {}
    local convergenceTransfer = normalizeTierPriceEntries(data.convergenceTransferPrices)
    if next(convergenceTransfer) then
        ForgeController.transfer.convergencePrices = convergenceTransfer
    end
    ForgeController.transfer.convergenceDust = data.convergenceDustTransfer or 160
    ForgeController.transfer.dust = data.normalDustTransfer or 100
    ForgeController.transfer.hasConvergence = data.hasConvergence or false
    ForgeController.transfer.dustLabel = ForgeController.transfer.dust
    ForgeController.transfer.grades = data.fusionGrades or {}
    -- TRANSFER

    -- CONVERSION
    ForgeController.conversion.necessaryDustToSliver = 60
    ForgeController.conversion.dustToSilver = data.dustToSilver or 3
    ForgeController.conversion.dustToSilverLabel = string.format("Generate %d", ForgeController.conversion.dustToSilver)
    ForgeController.conversion.sliverToCore = data.sliverToCore or 50
    ForgeController.conversion.sliverToCoreLabel = "Generate 1"
    ForgeController.conversion.dustCap = data.maxDustCap or 225
    local dustMax = data.maxDustLevel or 100
    ForgeController.conversion.dustMax = dustMax
    ForgeController.conversion.dustMaxIncreaseCost = dustMax - 75
    ForgeController.conversion:handleButtons()
    -- CONVERSION
end

function ForgeController:getColor(currentType)
    ForgeController.conversion:handleButtons()
    local red = Helpers.red
    local base = Helpers.grey
    local green = Helpers.green

    if currentType == "dustToSilver" then
        if self.currentDust >= self.conversion.necessaryDustToSliver then
            return base
        else
            return red
        end
    end

    if currentType == "sliverToCore" then
        if self.currentSlivers >= self.conversion.sliverToCore then
            return base
        else
            return red
        end
    end

    if currentType == "increaseDustLimit" then
        if self.currentDust >= self.conversion.dustMaxIncreaseCost then
            return base
        else
            return red
        end
    end

    if currentType == "fusion-preview-count-label" then
        if self.fusion.selected.id == -1 then
            return red
        end
    end

    if currentType == "transfer-preview-count-label" then
        if self.transfer.selected.id == -1 then
            return red
        end
    end

    if currentType == "fusion-dust" then
        local necessaryDust = self.fusion.isConvergence and self.fusion.convergenceDust or self.fusion.dust
        if self.fusion.dustLabel ~= necessaryDust then
            self.fusion.dustLabel = necessaryDust
        end

        if self.currentDust < necessaryDust then
            return red
        end
    end

    if currentType == "transfer-dust" or currentType == "transfer-exalted" then
        if self.transfer.selected.id == -1 then
            return red
        end

        if currentType == "transfer-dust" then
            local necessaryDust = self.transfer.isConvergence and self.transfer.convergenceDust or self.transfer.dust
            if self.transfer.dustLabel ~= necessaryDust then
                self.transfer.dustLabel = necessaryDust
            end
            if self.currentDust < necessaryDust then
                return red
            end
        end
        if currentType == "transfer-exalted" then
            if self.currentExaltedCores < self.transfer.necessaryExaltedCores then
                return red
            end
        end
    end

    if currentType == "price" then
        if self.rawPrice == 0 or self.rawPrice > self.rawCurrentGold then
            return red
        end
    end

    if currentType == "improve-chance" then
        if not self.fusion.chanceImprovedChecked then
            return red
        else
            return green
        end
    end

    if currentType == "reduce-loss" then
        if not self.fusion.reduceTierLossChecked then
            return red
        else
            return green
        end
    end

    if currentType == "improve-chance-cost" then
        if self.currentExaltedCores <= 0 then return red end

        if self.fusion.reduceTierLossChecked and self.currentExaltedCores == 1 then return red end
    end

    if currentType == "reduce-loss-cost" then
        if self.currentExaltedCores <= 0 then return red end

        if self.fusion.chanceImprovedChecked and self.currentExaltedCores == 1 then return red end
    end

    return base
end

-- CONVERSION MENU
ForgeController.conversion = {
    fusionPrices = {},
    dustCap = 225,
    dustMax = 100,
    necessaryDustToSliver = 60,
    dustToSliver = 3,
    sliverToCore = 50,
    dustMaxIncreaseCost = 100,
    dustToSilverLabel = "Generate 3",
    sliverToCoreLabel = "Generate 1",
    dustMaxLabel = "Raise limit from\n100 to 101",
    disableDustConversion = true,
    disableSliverConversion = true,
    disableIncreaseDustLimit = true,
    clip = { x = 0, y = 0, width = 118, height = 34 },
    types = {
        DUST2SLIVER = 2,
        SLIVER2CORE = 3,
        INCREASE_DUST_LIMIT = 4
    },
}

function ForgeController.conversion.handleButtons()
    local dustMax = ForgeController.conversion.dustMax or 100
    ForgeController.conversion.disableDustConversion = ForgeController.currentDust <
        ForgeController.conversion.necessaryDustToSliver
    ForgeController.conversion.disableSliverConversion = ForgeController.currentSlivers <
        ForgeController.conversion.sliverToCore
    ForgeController.conversion.disableIncreaseDustLimit = ForgeController.currentDust <
        ForgeController.conversion.dustMaxIncreaseCost
    ForgeController.currentDustAndMaxLabel = string.format("%d/%d", ForgeController.currentDust,
        dustMax)
    if dustMax >= ForgeController.conversion.dustCap then
        ForgeController.conversion.dustMaxLabel = "Maximum Reached"
        ForgeController.conversion.disableIncreaseDustLimit = true
    else
        ForgeController.conversion.dustMaxLabel = string.format("Raise limit from\n%d to %d", dustMax, dustMax + 1)
    end
end

function ForgeController.conversion.toggle(conversionType)
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    if conversionType == ForgeController.conversion.types.DUST2SLIVER then
        local dustBalance = player:getResourceBalance(ResourceTypes.FORGE_DUST) or 0
        if dustBalance <= ForgeController.conversion.necessaryDustToSliver then
            return
        end
        g_game.forgeRequest(conversionType)
        return
    end

    if conversionType == ForgeController.conversion.types.SLIVER2CORE then
        local sliverBalance = player:getResourceBalance(ResourceTypes.FORGE_SLIVER) or 0
        if sliverBalance <= ForgeController.conversion.sliverToCore then
            return
        end
        g_game.forgeRequest(conversionType)
        return
    end

    if conversionType == ForgeController.conversion.types.INCREASE_DUST_LIMIT then
        local dustBalance = player:getResourceBalance(ResourceTypes.FORGE_DUST) or 0
        local currentNecessaryDust = ForgeController.conversion.dustMaxIncreaseCost
        local maxDustCap = ForgeController.conversion.dustCap
        local maxDustLevel = ForgeController.conversion.dustMax

        if maxDustCap > 0 and maxDustLevel >= maxDustCap then
            return
        end

        if dustBalance < currentNecessaryDust then
            return
        end
        g_game.forgeRequest(conversionType)
    end
end

function ForgeController:resetTabsClip()
    self.fusion.clip = { x = 0, y = 0, width = 116, height = 34 }
    self.transfer.clip = { x = 0, y = 0, width = 116, height = 34 }
    self.conversion.clip = { x = 0, y = 0, width = 116, height = 34 }
    self.history.clip = { x = 0, y = 0, width = 118, height = 34 }
end

function ForgeController:toggleConversionMenu()
    self:resetTabsClip()
    self.currentTab = 'conversion'
    self.conversion.clip = { x = 0, y = 34, width = 116, height = 34 }
end

-- CONVERSION MENU

-- HISTORY MENU
ForgeController.history = {
    currentPage = 0,
    lastPage = 0,
    showPreviousButton = false,
    showNextButton = false,
    list = {},
    clip = { x = 0, y = 0, width = 118, height = 34 }
}
function ForgeController:toggleHistoryMenu()
    self:resetTabsClip()
    self.currentTab = 'history'
    g_game.sendForgeBrowseHistoryRequest(0)
    self.history.clip = { x = 0, y = 34, width = 118, height = 34 }
end

local historyActionLabels = {
    [0] = 'Fusion',
    [1] = 'Transfer',
    [2] = 'Conversion',
    [3] = 'Conversion',
    [4] = 'Conversion'
}

function onBrowseForgeHistory(page, lastPage, currentCount, historyList)
    page = math.max(tonumber(page) or 0, 1)
    lastPage = math.max(tonumber(lastPage) or page, 1)
    currentCount = tonumber(currentCount) or 0
    lastPage = lastPage > 1 and lastPage - 1 or lastPage


    ForgeController.history.currentPage = page
    ForgeController.history.lastPage = lastPage

    ForgeController.history.showPreviousButton = page > 1
    ForgeController.history.showNextButton = page < lastPage

    for _, entry in ipairs(historyList) do
        entry.createdAt = Helpers.formatHistoryDate(entry.createdAt)
        -- Convert actionType to number if it's a string, then look up the label
        local actionTypeNum = tonumber(entry.actionType) or entry.actionType
        entry.actionType = historyActionLabels[actionTypeNum] or 'Unknown'
        entry.description = entry.description or ''
        if entry.actionType == historyActionLabels[0] or entry.actionType == historyActionLabels[1] then
            local firstSpaceIndex = string.find(entry.description, " ")
            if firstSpaceIndex then
                entry.description = string.sub(entry.description, 1, firstSpaceIndex - 1)
            end
        end
    end
    ForgeController.history.list = historyList or {}
end

function ForgeController.history.onHistoryPreviousPage()
    local currentPage = ForgeController.history.currentPage or 0
    if currentPage <= 1 then
        return
    end

    g_game.sendForgeBrowseHistoryRequest(currentPage - 1)
end

function ForgeController.history.onHistoryNextPage()
    local currentPage = ForgeController.history.currentPage or 0
    local lastPage = ForgeController.history.lastPage or currentPage

    if currentPage >= lastPage then
        return
    end

    g_game.sendForgeBrowseHistoryRequest(currentPage + 1)
end
