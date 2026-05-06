function onOpenNpcTrade(items, currencyId, currencyName)
    local ui = controllerNpcTrader.ui
    if not ui or not ui:isVisible() then
        controllerNpcTrader:initNpcWindow()
    end
    local isNewSession = not controllerNpcTrader.isTradeOpen
    if isNewSession then
        controllerNpcTrader.isTradeOpen = true
        controllerNpcTrader.widthConsole = controllerNpcTrader.TRADE_CONSOLE_WIDTH
        controllerNpcTrader.buyItems = {}
        controllerNpcTrader.sellItems = {}
        controllerNpcTrader.currencyId = currencyId or controllerNpcTrader.DEFAULT_CURRENCY_ID
        controllerNpcTrader.currencyName = currencyName or controllerNpcTrader.DEFAULT_CURRENCY_NAME
    else
        if currencyId then
            controllerNpcTrader.currencyId = currencyId
        end
        if currencyName then
            controllerNpcTrader.currencyName = currencyName
        end
    end

    if items and type(items) == "table" then
        controllerNpcTrader.buyItems = {}
        controllerNpcTrader.sellItems = {}
        controllerNpcTrader.selectedItem = nil
        for _, itemData in ipairs(items) do
            local ptr = itemData[1]
            local name = itemData[2]
            local weight = itemData[3] / 100
            local buyPrice = itemData[4]
            local sellPrice = itemData[5]
            if buyPrice > 0 then
                table.insert(controllerNpcTrader.buyItems, {
                    ptr = ptr,
                    name = name,
                    weight = weight,
                    price = buyPrice,
                    count = 1
                })
            end
            if sellPrice > 0 then
                table.insert(controllerNpcTrader.sellItems, {
                    ptr = ptr,
                    name = name,
                    weight = weight,
                    price = sellPrice,
                    count = 1
                })
            end
        end
    end

    local currencyLabel = controllerNpcTrader:findWidget(".tradeCurrencyName")
    if currencyLabel then
        currencyLabel:setText(controllerNpcTrader.currencyName)
    end
    local currencyIcon = controllerNpcTrader:findWidget(".tradeCurrencyIcon")
    if currencyIcon then
        local item = Item.create(controllerNpcTrader.currencyId)
        if item then
            currencyIcon:setItem(item)
        else
            currencyIcon:setItemId(controllerNpcTrader.currencyId)
        end
    end

    if isNewSession then
        -- Initial State
        local initialMode = controllerNpcTrader.BUY
        if #controllerNpcTrader.buyItems > 0 then
            initialMode = controllerNpcTrader.BUY
        elseif #controllerNpcTrader.sellItems > 0 then
            initialMode = controllerNpcTrader.SELL
        end

        controllerNpcTrader.tradeMode = initialMode
        controllerNpcTrader.searchText = ""
        controllerNpcTrader.itemBatchSize = controllerNpcTrader.ITEM_BATCH_SIZE
        controllerNpcTrader.loadedItems = 0
        controllerNpcTrader.currentList = {}

        -- Settings & Sorting
        controllerNpcTrader.sortBy = controllerNpcTrader.DEFAULT_SORT_BY
        controllerNpcTrader.ignoreCapacity = controllerNpcTrader.DEFAULT_IGNORE_CAPACITY
        controllerNpcTrader.buyWithBackpack = controllerNpcTrader.DEFAULT_BUY_WITH_BACKPACK
        controllerNpcTrader.ignoreEquipped = controllerNpcTrader.DEFAULT_IGNORE_EQUIPPED

        controllerNpcTrader:setTradeMode(initialMode)
    else
        controllerNpcTrader.allTradeItems = (controllerNpcTrader.tradeMode == controllerNpcTrader.BUY) and
                                                controllerNpcTrader.buyItems or controllerNpcTrader.sellItems
        controllerNpcTrader:filterTradeList(controllerNpcTrader.searchText or "")
        controllerNpcTrader:refreshPlayerGoods(true)
    end
end

function controllerNpcTrader:setTradeMode(mode)
    self.tradeMode = mode
    self.selectedItem = nil

    local buyTab = self:findWidget("#tabBuy")
    local sellTab = self:findWidget("#tabSell")

    if buyTab then
        buyTab:setEnabled(mode ~= controllerNpcTrader.BUY)
    end
    if sellTab then
        sellTab:setEnabled(mode ~= controllerNpcTrader.SELL)
    end
    local toggleButton = self:findWidget("#toggleButton")
    if toggleButton then
        toggleButton:setText(mode == controllerNpcTrader.BUY and "Buy" or "Sell")
    end

    self.shouldFocusFirst = true
    self:updateListSource()
    self:refreshPlayerGoods(true)
end

function controllerNpcTrader:updateListSource()
    if self.tradeMode == controllerNpcTrader.BUY then
        self.allTradeItems = self.buyItems
    else
        self.allTradeItems = self.sellItems
    end
    self:filterTradeList(self.searchText or "")
end

function controllerNpcTrader:loadNextBatch()
    if not self.currentList then
        return
    end

    local total = #self.currentList
    local current = self.loadedItems
    if current >= total then
        return
    end

    local limit = math.min(total, current + self.itemBatchSize)
    for i = current + 1, limit do
        table.insert(self.tradeItems, self.currentList[i])
    end
    self.loadedItems = limit
end

function controllerNpcTrader:onTradeScroll(widget, offset)
    if self.loadedItems >= #self.currentList then
        return
    end
    local rowHeight = controllerNpcTrader.ITEM_ROW_HEIGHT
    local contentHeight = self.loadedItems * rowHeight
    local viewportHeight = widget:getHeight()
    local maxScroll = math.max(0, contentHeight - viewportHeight)
    local value = offset.y
    if value >= maxScroll - controllerNpcTrader.SCROLL_THRESHOLD then
        self:loadNextBatch()
    end
end

function controllerNpcTrader:onTradeListRendered()
    local list = self:findWidget("#tradeListScroll")
    if list then
        if not list.onScrollEventConnected then
            list.onScrollChange = function(widget, offset)
                self:onTradeScroll(widget, offset)
            end
            list.onScrollEventConnected = true
        end
        for i = 1, list:getChildCount() do
            local child = list:getChildByIndex(i)
            local item = child.tradeItem
            if item then
                local canTrade = self:canTradeItem(item)
                local color = canTrade and '#c0c0c0' or '#707070'
                local infoBlock = child:getChildByIndex(2)
                if infoBlock then
                    local nameLabel = infoBlock:getChildById("nameLabel")
                    local infoLabel = infoBlock:getChildById("infoLabel")
                    if nameLabel then nameLabel:setColor(color) end
                    if infoLabel then infoLabel:setColor(color) end
                end

                child.onMouseRelease = function(widget, mousePos, mouseButton)
                    self:onTradeItemMouseRelease(item, widget, mousePos, mouseButton)
                end
            end
        end
        if self.shouldFocusFirst then
            local firstChild = list:getChildByIndex(1)
            if firstChild then
                self:selectTradeItem(self.tradeItems[1], firstChild)
            end
            self.shouldFocusFirst = false
        elseif self.selectedItem then
            for i = 1, list:getChildCount() do
                local child = list:getChildByIndex(i)
                if child.tradeItem == self.selectedItem then
                    child:focus()
                    break
                end
            end
        end
    end
end

function controllerNpcTrader:onTradeItemMouseRelease(item, widget, mousePos, mouseButton)
    if mouseButton == MouseRightButton then
        local menu = g_ui.createWidget('PopupMenu')
        menu:setGameMenu(true)
        menu:addOption("Look", function()
            g_game.inspectNpcTrade(item.ptr)
        end)
        menu:addOption("Inspect", function()
            print("TODO create module InspectionObject in html")
        end)
        menu:display(mousePos)
        return true
    elseif mouseButton == MouseLeftButton then
        self:selectTradeItem(item, widget)
        return true
    end
    return false
end

function controllerNpcTrader:selectTradeItem(item, widget)
    self.selectedItem = item
    if widget then
        widget:focus()
    end
    self:updateAmount(1)

    local scroll = self:findWidget("#amountScrollBar")
    if scroll then
        scroll:enable()
        scroll:setValue(1)
    end
end

function controllerNpcTrader:updateAmount(amount)
    amount = tonumber(amount) or 1
    if self.selectedItem then
        local maxAmount = controllerNpcTrader.MAX_AMOUNT_NORMAL
        if self.tradeMode == controllerNpcTrader.BUY then
            local playerMoney = self:getPlayerMoney()
            local maxByMoney = math.floor(playerMoney / self.selectedItem.price)
            maxAmount = math.max(controllerNpcTrader.MIN_AMOUNT,
                math.min(controllerNpcTrader.MAX_AMOUNT_NORMAL, maxByMoney))
            if self.selectedItem.ptr and self.selectedItem.ptr:isStackable() then
                maxAmount = math.max(controllerNpcTrader.MIN_AMOUNT,
                    math.min(controllerNpcTrader.MAX_AMOUNT_STACKABLE, maxByMoney))
            end
        else
            local sellable = self:getSellQuantity(self.selectedItem.ptr)
            maxAmount = math.max(controllerNpcTrader.MIN_AMOUNT, sellable)
        end
        if amount > maxAmount then
            amount = maxAmount
        end
        if amount < controllerNpcTrader.MIN_AMOUNT then
            amount = controllerNpcTrader.MIN_AMOUNT
        end
        local scroll = self:findWidget("#amountScrollBar")
        if scroll then
            scroll:setMaximum(maxAmount)
            scroll:setMinimum(controllerNpcTrader.MIN_AMOUNT)
            if scroll:getValue() ~= amount then
                scroll:setValue(amount)
            end
        end
    end
    self.amount = amount
    if self.selectedItem then
        self.totalPrice = self.selectedItem.price * amount
        self.totalWeight = string.format("%.2f", self.selectedItem.weight * amount)
    else
        self.totalPrice = 0
        self.totalWeight = "0.00"
    end
end

function controllerNpcTrader:onAmountScrollBarChange(value)
    self:updateAmount(value)
end

function controllerNpcTrader:onAmountInputChange(event)
    local input = event.target
    local text = input:getText()
    local cleanText = text:gsub("[^%d]", "")
    if cleanText ~= text then
        input:setText(cleanText)
        text = cleanText
    end
    if text == "" then
        text = "1"
    end
    local amount = tonumber(text) or 1
    self:updateAmount(amount)
    local scroll = self:findWidget("#amountScrollBar")
    if scroll then
        if amount ~= self.amount then
            input:setText(tostring(self.amount))
        end
        scroll:setValue(self.amount)
    end
end

function controllerNpcTrader:getPlayerMoney()
    if self.playerMoney ~= nil then
        return self.playerMoney
    end
    local player = g_game.getLocalPlayer()
    if not player then
        return 0
    end
    return player:getTotalMoney()
end

function controllerNpcTrader:getSellQuantity(itemPtr)
    if not itemPtr then
        return 0
    end
    local id = itemPtr:getId()
    local subType = itemPtr:getSubType()
    local key = id .. "_" .. subType
    local inventoryTotal = self.playerItems and self.playerItems[key] or 0

    if self.ignoreEquipped then
        local player = g_game.getLocalPlayer()
        local equippedCount = 0
        for i = 1, 10 do
            local item = player:getInventoryItem(i)
            if item and item:getId() == id and item:getSubType() == subType then
                equippedCount = equippedCount + item:getCount()
            end
        end
        return math.max(0, inventoryTotal - equippedCount)
    end

    return inventoryTotal
end

function controllerNpcTrader:canTradeItem(item)
    if self.tradeMode == controllerNpcTrader.BUY then
        local playerMoney = self:getPlayerMoney()
        -- Add capacity check if needed, but for now we'll just check price
        return playerMoney >= item.price
    else
        return self:getSellQuantity(item.ptr) > 0
    end
end

function controllerNpcTrader:onPlayerGoods(money, items)
    if not items or type(items) ~= "table" then
        return
    end
    self.playerMoney = money
    local newPlayerItems = {}
    for _, itemData in ipairs(items) do
        local ptr = itemData[1]
        local key = ptr:getId() .. "_" .. ptr:getSubType()
        local count = itemData[2]
        newPlayerItems[key] = (newPlayerItems[key] or 0) + count
    end
    self.playerItems = newPlayerItems
    self:refreshPlayerGoods()
end

function controllerNpcTrader:refreshPlayerGoods(skipFilter)
    local money = self:getPlayerMoney()
    local display = self:findWidget("#playerMoneyDisplay")
    if display then
        display:setText(tostring(money))
    end
    if not skipFilter and self.tradeMode == controllerNpcTrader.SELL then
        self:filterTradeList(self.searchText or "")
    end
    if self.selectedItem then
        self:updateAmount(self.amount)
    end
end

function controllerNpcTrader:executeTrade()
    if not self.selectedItem then
        return
    end
    if self.tradeMode == controllerNpcTrader.BUY then
        g_game.buyItem(self.selectedItem.ptr, self.amount, self.ignoreCapacity, self.buyWithBackpack)
    else
        g_game.sellItem(self.selectedItem.ptr, self.amount, self.ignoreEquipped)
    end
end

function controllerNpcTrader:clearSearch()
    local input = self:findWidget(".tradeSearchInput")
    if input then
        input:setText("")
        self:filterTradeList("")
    end
end

function controllerNpcTrader:filterTradeList(searchText)
    if not self.allTradeItems then
        return
    end

    self.searchText = searchText
    local lowerSearch = searchText:lower()
    local filteredItems = {}

    for _, item in ipairs(self.allTradeItems) do
        local includeItem = true
        if searchText ~= "" and not item.name:lower():find(lowerSearch, 1, true) then
            includeItem = false
        end

        if includeItem then
            table.insert(filteredItems, item)
        end
    end

    if self.tradeMode == controllerNpcTrader.SELL then
        table.sort(filteredItems, function(a, b)
            local qtyA = self:getSellQuantity(a.ptr)
            local qtyB = self:getSellQuantity(b.ptr)
            if qtyA ~= qtyB then
                return qtyA > qtyB
            end
            if self.sortBy == 'price' then
                return a.price > b.price
            elseif self.sortBy == 'weight' then
                return a.weight > b.weight
            else
                return a.name:lower() < b.name:lower()
            end
        end)
    else
        self:sortTradeItems(filteredItems)
    end

    self.currentList = filteredItems
    self.tradeItems = {}
    self.loadedItems = 0
    self:loadNextBatch()

    if #self.currentList > 0 then
        local found = false
        if self.selectedItem then
            for _, item in ipairs(self.currentList) do
                if item == self.selectedItem then found = true; break end
            end
        end
        if not found then
            self:selectTradeItem(self.tradeItems[1])
        end
    else
        self.selectedItem = nil
        self:updateAmount(0)
    end
end

function controllerNpcTrader:sellAll(delayed, exceptions)
    if type(delayed) == "table" then
        exceptions = delayed
        delayed = false
    end
    exceptions = exceptions or {}
    
    if self.sellAllWithDelayEvent then
        removeEvent(self.sellAllWithDelayEvent)
        self.sellAllWithDelayEvent = nil
    end

    local queue = {}
    if self.tradeMode ~= controllerNpcTrader.SELL then
        return
    end

    for _, entry in ipairs(self.sellItems or {}) do
        local id = entry.ptr:getId()
        if not table.find(exceptions, id) then
            local sellQuantity = self:getSellQuantity(entry.ptr)
            while sellQuantity > 0 do
                local maxPossible = g_game.getFeature(GameDoubleShopSellAmount) and 10000 or 100
                local maxAmount = math.min(sellQuantity, maxPossible)

                if delayed then
                    g_game.sellItem(entry.ptr, maxAmount, self.ignoreEquipped)
                    self.sellAllWithDelayEvent = scheduleEvent(function() self:sellAll(true, exceptions) end, 1100)
                    return
                end
                
                table.insert(queue, { entry.ptr, maxAmount, self.ignoreEquipped })
                sellQuantity = sellQuantity - maxAmount
            end
        end
    end
    
    for _, entry in ipairs(queue) do
        g_game.sellItem(entry[1], entry[2], entry[3])
    end
end
