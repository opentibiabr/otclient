local BUY = 1
local SELL = 2
local CURRENCY = 'gold'
local CURRENCY_DECIMAL = false
local WEIGHT_UNIT = 'oz'
local LAST_INVENTORY = 10

local npcWindow = nil
local itemsPanel = nil
local radioTabs = nil
local radioItems = nil
local searchText = nil
local setupPanel = nil
local quantity = nil
local quantityScroll = nil
local nameLabel = nil
local priceLabel = nil
local moneyLabel = nil
local weightDesc = nil
local weightLabel = nil
local capacityDesc = nil
local capacityLabel = nil
local tradeButton = nil
local buyTab = nil
local sellTab = nil
local initialized = false

local showWeight = true
local buyWithBackpack = nil
local ignoreCapacity = nil
local ignoreEquipped = nil
local showAllItems = nil
local sellAllButton = nil

local playerFreeCapacity = 0
local playerMoney = 0
local tradeItems = {[BUY] = {}, [SELL] = {}}
local playerItems = {}
local selectedItem = nil

local cancelNextRelease = nil

function controllerNpcTrader:legacy_init()
    npcWindow = g_ui.displayUI('/game_npctrader/templates/npctrade_legacy')
    npcWindow:setVisible(false)

    itemsPanel = npcWindow:recursiveGetChildById('itemsPanel')
    searchText = npcWindow:recursiveGetChildById('searchText')

    setupPanel = npcWindow:recursiveGetChildById('setupPanel')
    quantityScroll = setupPanel:getChildById('quantityScroll')
    nameLabel = setupPanel:getChildById('name')
    priceLabel = setupPanel:getChildById('price')
    moneyLabel = setupPanel:getChildById('money')
    weightDesc = setupPanel:getChildById('weightDesc')
    weightLabel = setupPanel:getChildById('weight')
    capacityDesc = setupPanel:getChildById('capacityDesc')
    capacityLabel = setupPanel:getChildById('capacity')
    tradeButton = npcWindow:recursiveGetChildById('tradeButton')

    buyWithBackpack = npcWindow:recursiveGetChildById('buyWithBackpack')
    ignoreCapacity = npcWindow:recursiveGetChildById('ignoreCapacity')
    ignoreEquipped = npcWindow:recursiveGetChildById('ignoreEquipped')
    showAllItems = npcWindow:recursiveGetChildById('showAllItems')
    sellAllButton = npcWindow:recursiveGetChildById('sellAllButton')

    buyTab = npcWindow:getChildById('buyTab')
    sellTab = npcWindow:getChildById('sellTab')

    radioTabs = UIRadioGroup.create()
    radioTabs:addWidget(buyTab)
    radioTabs:addWidget(sellTab)
    radioTabs:selectWidget(buyTab)
    radioTabs.onSelectionChange = onTradeTypeChange

    cancelNextRelease = false

    if g_game.isOnline() then
        playerFreeCapacity = g_game.getLocalPlayer():getFreeCapacity()
    end


    connect(LocalPlayer, {
        onFreeCapacityChange = onFreeCapacityChange,
        onInventoryChange = onInventoryChange
    })

    initialized = true
end

function controllerNpcTrader:legacy_terminate()
    initialized = false
    if npcWindow then
        npcWindow:destroy()
    end
    npcWindow = nil
    disconnect(LocalPlayer, {
        onFreeCapacityChange = onFreeCapacityChange,
        onInventoryChange = onInventoryChange
    })
end

function controllerNpcTrader:legacy_show()
    if g_game.isOnline() and npcWindow then
        if tradeItems[BUY] and #tradeItems[BUY] > 0 then
            radioTabs:selectWidget(buyTab)
        else
            radioTabs:selectWidget(sellTab)
        end

        npcWindow:show()
        npcWindow:raise()
        npcWindow:focus()
    end
end

function controllerNpcTrader:legacy_hide()
    npcWindow:hide()
end

function controllerNpcTrader:onLegacyItemBoxChecked(widget)
    if widget:isChecked() then
        local item = widget.item
        selectedItem = item
        refreshItem(item)
        tradeButton:enable()

        if getCurrentTradeType() == SELL then
            quantityScroll:setValue(quantityScroll:getMaximum())
        end
    end
end

function controllerNpcTrader:onQuantityValueChangeLegacy(quantity)
    if selectedItem then
        weightLabel:setText(string.format('%.2f', selectedItem.weight * quantity) .. ' ' .. WEIGHT_UNIT)
        priceLabel:setText(formatCurrency(getItemPrice(selectedItem)))
    end
end

function onTradeTypeChange(radioTabs, selected, deselected)
    tradeButton:setText(selected:getText())
    selected:setOn(true)
    deselected:setOn(false)

    local currentTradeType = getCurrentTradeType()
    buyWithBackpack:setVisible(currentTradeType == BUY)
    ignoreCapacity:setVisible(currentTradeType == BUY)
    ignoreEquipped:setVisible(currentTradeType == SELL)
    showAllItems:setVisible(currentTradeType == SELL)
    sellAllButton:setVisible(currentTradeType == SELL)

    refreshTradeItems()
    refreshPlayerGoods()
end

function controllerNpcTrader:onTradeClickLegacy()
    if getCurrentTradeType() == BUY then
        g_game.buyItem(selectedItem.ptr, quantityScroll:getValue(), ignoreCapacity:isChecked(),
                       buyWithBackpack:isChecked())
    else
        g_game.sellItem(selectedItem.ptr, quantityScroll:getValue(), ignoreEquipped:isChecked())
    end
end

function controllerNpcTrader:onSearchTextChangeLegacy()
    refreshPlayerGoods()
end

function itemPopup(self, mousePosition, mouseButton)
    if cancelNextRelease then
        cancelNextRelease = false
        return false
    end

    if mouseButton == MouseRightButton then
        local menu = g_ui.createWidget('PopupMenu')
        menu:setGameMenu(true)
        menu:addOption(tr('Look'), function()
            return g_game.inspectNpcTrade(self:getItem())
        end)
        menu:display(mousePosition)
        return true
    elseif ((g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton) or
        (g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton)) then
        cancelNextRelease = true
        g_game.inspectNpcTrade(self:getItem())
        return true
    end
    return false
end

function controllerNpcTrader:onBuyWithBackpackChangeLegacy()
    if selectedItem then
        refreshItem(selectedItem)
    end
end

function controllerNpcTrader:onIgnoreCapacityChangeLegacy()
    refreshPlayerGoods()
end

function controllerNpcTrader:onIgnoreEquippedChangeLegacy()
    refreshPlayerGoods()
end

function controllerNpcTrader:onShowAllItemsChangeLegacy()
    refreshPlayerGoods()
end

function setCurrency(currency, decimal)
    CURRENCY = currency
    CURRENCY_DECIMAL = decimal
end

function setShowWeight(state)
    showWeight = state
    weightDesc:setVisible(state)
    weightLabel:setVisible(state)
end

function setShowYourCapacity(state)
    capacityDesc:setVisible(state)
    capacityLabel:setVisible(state)
    ignoreCapacity:setVisible(state)
end

function clearSelectedItem()
    nameLabel:clearText()
    weightLabel:clearText()
    priceLabel:clearText()
    tradeButton:disable()
    quantityScroll:setMinimum(0)
    quantityScroll:setMaximum(0)
    if selectedItem then
        radioItems:selectWidget(nil)
        selectedItem = nil
    end
end

function getCurrentTradeType()
    if tradeButton:getText() == tr('Buy') then
        return BUY
    else
        return SELL
    end
end

function getItemPrice(item, single)
    local amount = 1
    local single = single or false
    if not single then
        amount = quantityScroll:getValue()
    end
    if getCurrentTradeType() == BUY then
        if buyWithBackpack:isChecked() then
            if item.ptr:isStackable() then
                return item.price * amount + 20
            else
                return item.price * amount + math.ceil(amount / 20) * 20
            end
        end
    end
    return item.price * amount
end

function getSellQuantity(item)
    if not item or not playerItems[item:getId()] then
        return 0
    end
    local removeAmount = 0
    if ignoreEquipped:isChecked() then
        local localPlayer = g_game.getLocalPlayer()
        for i = 1, LAST_INVENTORY do
            local inventoryItem = localPlayer:getInventoryItem(i)
            if inventoryItem and inventoryItem:getId() == item:getId() then
                removeAmount = removeAmount + inventoryItem:getCount()
            end
        end
    end
    return playerItems[item:getId()] - removeAmount
end

function canTradeItem(item)
    if getCurrentTradeType() == BUY then
        return
            (ignoreCapacity:isChecked() or (not ignoreCapacity:isChecked() and playerFreeCapacity >= item.weight)) and
                playerMoney >= getItemPrice(item, true)
    else
        return getSellQuantity(item.ptr) > 0
    end
end

function refreshItem(item)
    nameLabel:setText(item.name)

    if getCurrentTradeType() == BUY then
        local capacityMaxCount = math.floor(playerFreeCapacity / item.weight)
        if ignoreCapacity:isChecked() then
            capacityMaxCount = 65535
        end
        local priceMaxCount = math.floor(playerMoney / getItemPrice(item, true))
        local finalCount = math.max(0, math.min(getMaxAmount(), math.min(priceMaxCount, capacityMaxCount)))
        quantityScroll:setMinimum(1)
        quantityScroll:setMaximum(finalCount)
    else
        quantityScroll:setMinimum(1)
        quantityScroll:setMaximum(math.max(0, math.min(getMaxAmount(), getSellQuantity(item.ptr))))
    end

    self:onQuantityValueChangeLegacy(quantityScroll:getValue())

    setupPanel:enable()
end

function refreshTradeItems()
    local layout = itemsPanel:getLayout()
    layout:disableUpdates()

    clearSelectedItem()

    searchText:clearText()
    setupPanel:disable()
    itemsPanel:destroyChildren()

    if radioItems then
        radioItems:destroy()
    end
    radioItems = UIRadioGroup.create()

    local currentTradeItems = tradeItems[getCurrentTradeType()]
    for key, item in pairs(currentTradeItems) do
        local itemBox = g_ui.createWidget('NPCItemBox', itemsPanel)
        itemBox.item = item

        local text = ''
        local name = item.name
        text = text .. name
        if showWeight then
            local weight = string.format('%.2f', item.weight) .. ' ' .. WEIGHT_UNIT
            text = text .. '\n' .. weight
        end
        local price = formatCurrency(item.price)
        text = text .. '\n' .. price
        itemBox:setText(text)

        local itemWidget = itemBox:getChildById('item')
        itemWidget:setItem(item.ptr)
        itemWidget.onMouseRelease = itemPopup

        radioItems:addWidget(itemBox)
    end

    layout:enableUpdates()
    layout:update()
end

function refreshPlayerGoods()
    if not initialized then
        return
    end

    checkSellAllTooltip()

    moneyLabel:setText(formatCurrency(playerMoney))
    capacityLabel:setText(string.format('%.2f', playerFreeCapacity) .. ' ' .. WEIGHT_UNIT)

    local currentTradeType = getCurrentTradeType()
    local searchFilter = searchText:getText():lower()
    local foundSelectedItem = false

    local items = itemsPanel:getChildCount()
    for i = 1, items do
        local itemWidget = itemsPanel:getChildByIndex(i)
        local item = itemWidget.item

        local canTrade = canTradeItem(item)
        itemWidget:setOn(canTrade)
        itemWidget:setEnabled(canTrade)

        local searchCondition = (searchFilter == '') or
                                    (searchFilter ~= '' and string.find(item.name:lower(), searchFilter) ~= nil)
        local showAllItemsCondition = (currentTradeType == BUY) or (showAllItems:isChecked()) or
                                          (currentTradeType == SELL and not showAllItems:isChecked() and canTrade)
        itemWidget:setVisible(searchCondition and showAllItemsCondition)

        if selectedItem == item and itemWidget:isEnabled() and itemWidget:isVisible() then
            foundSelectedItem = true
        end
    end

    if not foundSelectedItem then
        clearSelectedItem()
    end

    if selectedItem then
        refreshItem(selectedItem)
    end
end

function controllerNpcTrader:onOpenNpcTradeLegacy(items)
    tradeItems[BUY] = {}
    tradeItems[SELL] = {}

    for key, item in pairs(items) do
        if item[4] > 0 then
            local newItem = {}
            newItem.ptr = item[1]
            newItem.name = item[2]
            newItem.weight = item[3] / 100
            newItem.price = item[4]
            table.insert(tradeItems[BUY], newItem)
        end

        if item[5] > 0 then
            local newItem = {}
            newItem.ptr = item[1]
            newItem.name = item[2]
            newItem.weight = item[3] / 100
            newItem.price = item[5]
            table.insert(tradeItems[SELL], newItem)
        end
    end

    refreshTradeItems()
    self:legacy_show()
end

function closeNpcTrade()
    g_game.closeNpcTrade()
    controllerNpcTrader:legacy_hide()
end

function controllerNpcTrader:onCloseNpcTradeLegacy()
    controllerNpcTrader:legacy_hide()
end

function controllerNpcTrader:onPlayerGoodsLegacy(money, items)
    playerMoney = money

    playerItems = {}
    for key, item in pairs(items) do
        local id = item[1]:getId()
        if not playerItems[id] then
            playerItems[id] = item[2]
        else
            playerItems[id] = playerItems[id] + item[2]
        end
    end

    refreshPlayerGoods()
end

function onFreeCapacityChange(localPlayer, freeCapacity, oldFreeCapacity)
    playerFreeCapacity = freeCapacity

    if npcWindow:isVisible() then
        refreshPlayerGoods()
    end
end

function onInventoryChange(inventory, item, oldItem)
    refreshPlayerGoods()
end

function getTradeItemData(id, type)
    if table.empty(tradeItems[type]) then
        return false
    end

    if type then
        for key, item in pairs(tradeItems[type]) do
            if item.ptr and item.ptr:getId() == id then
                return item
            end
        end
    else
        for _, items in pairs(tradeItems) do
            for key, item in pairs(items) do
                if item.ptr and item.ptr:getId() == id then
                    return item
                end
            end
        end
    end
    return false
end

function checkSellAllTooltip()
    sellAllButton:setEnabled(true)
    sellAllButton:removeTooltip()

    local total = 0
    local info = ''
    local first = true

    for key, amount in pairs(playerItems) do
        local data = getTradeItemData(key, SELL)
        if data then
            amount = getSellQuantity(data.ptr)
            if amount > 0 then
                if data and amount > 0 then
                    info = info .. (not first and '\n' or '') .. amount .. ' ' .. data.name .. ' (' .. data.price *
                               amount .. ' gold)'

                    total = total + (data.price * amount)
                    if first then
                        first = false
                    end
                end
            end
        end
    end
    if info ~= '' then
        info = info .. '\nTotal: ' .. total .. ' gold'
        sellAllButton:setTooltip(info)
    else
        sellAllButton:setEnabled(false)
    end
end

function formatCurrency(amount)
    if CURRENCY_DECIMAL then
        return string.format('%.02f', amount / 100.0) .. ' ' .. CURRENCY
    else
        return amount .. ' ' .. CURRENCY
    end
end

function getMaxAmount()
    if getCurrentTradeType() == SELL and g_game.getFeature(GameDoubleShopSellAmount) then
        return 10000
    end
    return 100
end

function controllerNpcTrader:sellAllLegacy()
    for itemid, item in pairs(playerItems) do
        local item = Item.create(itemid)
        local amount = getSellQuantity(item)
        if amount > 0 then
            g_game.sellItem(item, amount, ignoreEquipped:isChecked())
        end
    end
end