MarketOwnOffers = {
    mySellOffers = {},
    myBuyOffers = {},
    onTopListValueChange = nil,
    onBottomListValueChange = nil,
    topListMin = 0,
    topListMax = 0,
    bottomListMin = 0,
    bottomListMax = 0,
    topListFitItems = 0,
    bottomListFitItems = 0,
    topListPool = {},
    bottomListPool = {},
    topListData = {},
    bottomListData = {},

    labelSize = 16,
    ownSellPool = 14,
    ownBuyPool = 14,

    selectedSellCounter = {
        counter = 0,
        action = 0
    },
    selectedBuyCounter = {
        counter = 0,
        action = 0
    }
}

MarketOwnOffers.__index = MarketOwnOffers

function MarketOwnOffers.onParseMyOffers(buyOffers, sellOffers)
    local window = marketWindow.MarketHistory.currentOffers

    lastSelectedMySell = nil
    lastSelectedMyBuy = nil
    window.buyCancelOffer:setVisible(true)
    window.sellCancelOffer:setVisible(true)
    window.buyCancelOffer:setEnabled(false)
    window.sellCancelOffer:setEnabled(false)

    local buyScrollbar = marketWindow.MarketHistory:recursiveGetChildById('buyOffersListScroll')
    local sellScrollbar = marketWindow.MarketHistory:recursiveGetChildById('sellOffersListScroll')
    buyScrollbar.onValueChange = nil
    sellScrollbar.onValueChange = nil

    local updatedBuy = false
    local updatedSell = false

    if #buyOffers == 1 then
        local updateOffer = buyOffers[1]
        for i, data in pairs(MarketOwnOffers.myBuyOffers) do
            if data.counter == updateOffer.counter and data.timestamp == updateOffer.timestamp then
                table.remove(MarketOwnOffers.myBuyOffers, i)
                updatedBuy = true
                break
            end
        end
    end

    if #sellOffers == 1 then
        local updateOffer = sellOffers[1]
        for i, data in pairs(MarketOwnOffers.mySellOffers) do
            if data.counter == updateOffer.counter and data.timestamp == updateOffer.timestamp then
                table.remove(MarketOwnOffers.mySellOffers, i)
                updatedSell = true
                break
            end
        end
    end

    if not updatedBuy and #buyOffers > 0 then
        MarketOwnOffers.myBuyOffers = buyOffers
    end

    if not updatedSell and #sellOffers > 0 then
        MarketOwnOffers.mySellOffers = sellOffers
    end

    window.sellOffersList:destroyChildren()
    for i = 1, MarketOwnOffers.ownSellPool do
        local data = MarketOwnOffers.mySellOffers[i]
        if data then
            local widget = g_ui.createWidget('MarketCurrentWidget', window.sellOffersList)
            local color = i % 2 == 0 and '#484848' or '#414141'
            widget:setId(color)
            widget.actionId = i
            widget:setBackgroundColor(color)
            widget.amount:setText(data.amount)
            widget.name:setText(g_things.getThingType(data.itemId, ThingCategoryItem):getMarketData().name)
            widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", data.timestamp))
            widget.counter = data.counter

            local itemTier = data.itemTier or 0
            if itemTier > 0 then
                widget.name:setText(widget.name:getText() .. " (Tier " .. itemTier .. ")")
            end

            local totalPrice = data.price * data.amount
            local unitPrice = data.price
            widget.piecePrice:setText(convertLongGold(unitPrice))
            widget.totalPrice:setText(convertLongGold(totalPrice))
            if totalPrice > 99999999 then
                widget.totalPrice:setTooltip(comma_value(totalPrice))
            end

            if unitPrice > 99999999 then
                widget.piecePrice:setTooltip(comma_value(unitPrice))
            end
        end
    end

    MarketOwnOffers.topListMin = #MarketOwnOffers.mySellOffers > 0 and 1 or 0
    MarketOwnOffers.topListMax = #MarketOwnOffers.mySellOffers + 1
    MarketOwnOffers.topListFitItems = math.floor(window.sellOffersList:getHeight() / MarketOwnOffers.labelSize)

    sellScrollbar:setValue(0)
    sellScrollbar:setMinimum(MarketOwnOffers.topListMin)
    sellScrollbar:setMaximum(math.max(0, MarketOwnOffers.topListMax - MarketOwnOffers.ownSellPool))
    sellScrollbar.onValueChange = function(self, value, delta)
        MarketOwnOffers.onTopListValueChange(self, value, delta)
    end

    window.buyOffersList:destroyChildren()
    for i = 1, MarketOwnOffers.ownBuyPool do
        local data = MarketOwnOffers.myBuyOffers[i]
        if data then
            local widget = g_ui.createWidget('MarketCurrentWidget', window.buyOffersList)
            local color = i % 2 == 0 and '#484848' or '#414141'
            widget:setId(color)
            widget.actionId = i
            widget:setBackgroundColor(color)
            widget.amount:setText(data.amount)
            widget.name:setText(g_things.getThingType(data.itemId, ThingCategoryItem):getMarketData().name)
            widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", data.timestamp))

            local itemTier = data.itemTier or 0
            if itemTier > 0 then
                widget.name:setText(widget.name:getText() .. " (Tier " .. itemTier .. ")")
            end

            local totalPrice = data.price * data.amount
            local unitPrice = data.price
            widget.piecePrice:setText(convertLongGold(unitPrice))
            widget.totalPrice:setText(convertLongGold(totalPrice))

            if totalPrice > 99999999 then
                widget.totalPrice:setTooltip(comma_value(totalPrice))
            end

            if unitPrice > 99999999 then
                widget.piecePrice:setTooltip(comma_value(unitPrice))
            end
        end
    end

    MarketOwnOffers.bottomListMin = #MarketOwnOffers.myBuyOffers > 0 and 1 or 0
    MarketOwnOffers.bottomListMax = #MarketOwnOffers.myBuyOffers + 1
    MarketOwnOffers.bottomListFitItems = math.floor(window.buyOffersList:getHeight() / MarketOwnOffers.labelSize)

    buyScrollbar:setValue(0)
    buyScrollbar:setMinimum(MarketOwnOffers.bottomListMin)
    buyScrollbar:setMaximum(math.max(0, MarketOwnOffers.bottomListMax - MarketOwnOffers.ownBuyPool))
    buyScrollbar.onValueChange = function(self, value, delta)
        MarketOwnOffers.onBottomListValueChange(self, value, delta)
    end

    window.sellOffersList.onChildFocusChange = function(self, selected)
        MarketOwnOffers.onSelectMyOffersChild(self, selected, true)
    end
    window.buyOffersList.onChildFocusChange = function(self, selected)
        MarketOwnOffers.onSelectMyOffersChild(self, selected, false)
    end

    local firstChild = window.sellOffersList:getChildren()[1]
    if firstChild then
        window.sellCancelOffer:setEnabled(true)
        window.sellOffersList:onChildFocusChange(firstChild, nil, KeyboardFocusReason)
    end

    firstChild = window.buyOffersList:getChildren()[1]
    if firstChild then
        window.buyCancelOffer:setEnabled(true)
        window.buyOffersList:onChildFocusChange(firstChild, nil, KeyboardFocusReason)
    end

    window.sellOffersLabel:setText("Sell Offers (" .. #MarketOwnOffers.mySellOffers .. "):")
    window.buyOffersLabel:setText("Buy Offers (" .. #MarketOwnOffers.myBuyOffers .. "):")
end

function MarketOwnOffers.onSelectMyOffersChild(self, selected, selling)
    if not selected then
        return
    end

    local lastSelected = selling and lastSelectedMySell or lastSelectedMyBuy
    if lastSelected then
        if not lastSelected.piecePrice then
            lastSelected = nil
        else
            lastSelected:setBackgroundColor(lastSelected:getId())
            lastSelected.piecePrice:setColor("#c0c0c0")
            lastSelected.totalPrice:setColor("#c0c0c0")
            lastSelected.name:setColor("#c0c0c0")
            lastSelected.amount:setColor("#c0c0c0")
            lastSelected.endAt:setColor("#c0c0c0")
        end
    end

    if selling then
        lastSelectedMySell = selected
        MarketOwnOffers.selectedSellCounter.counter = selected.counter
        MarketOwnOffers.selectedSellCounter.action = selected.actionId
    else
        lastSelectedMyBuy = selected
        MarketOwnOffers.selectedBuyCounter.counter = selected.counter
        MarketOwnOffers.selectedBuyCounter.action = selected.actionId
    end

    selectedCounter = selected.counter

    selected:setBackgroundColor('#585858')
    selected.piecePrice:setColor("#f4f4f4")
    selected.totalPrice:setColor("#f4f4f4")
    selected.name:setColor("#f4f4f4")
    selected.amount:setColor("#f4f4f4")
    selected.endAt:setColor("#f4f4f4")
end

function MarketOwnOffers.cancelMarketOffer(selling)
    local window = marketWindow.MarketHistory.currentOffers
    local widget = selling and window.sellOffersList:getFocusedChild() or window.buyOffersList:getFocusedChild()
    if not widget then
        if selling then
            window.sellOffersList:focusChild(window.sellOffersList:getFirstChild())
        else
            window.buyOffersList:focusChild(window.buyOffersList:getFirstChild())
        end
        widget = selling and window.sellOffersList:getFocusedChild() or window.buyOffersList:getFocusedChild()
    end

    local targetList = selling and MarketOwnOffers.mySellOffers or MarketOwnOffers.myBuyOffers
    local targetAction = selling and MarketOwnOffers.selectedSellCounter.action or
                             MarketOwnOffers.selectedBuyCounter.action
    local targetOffer = targetList[targetAction]
    if not targetOffer then
        return true
    end

    sendMarketCancelOffer(targetOffer.timestamp, targetOffer.counter)
end

function MarketOwnOffers.onTopListValueChange(scroll, value, delta)
    local window = marketWindow.MarketHistory.currentOffers
    local startLabel = math.max(MarketOwnOffers.topListMin, value)
    local endLabel = startLabel + MarketOwnOffers.topListFitItems - 1

    if endLabel > MarketOwnOffers.topListMax then
        endLabel = MarketOwnOffers.topListMax
        startLabel = endLabel - MarketOwnOffers.topListFitItems + 1
    end

    for i, widget in ipairs(window.sellOffersList:getChildren()) do
        local index = value > 0 and (startLabel + i - 1) or (startLabel + i)
        local data = MarketOwnOffers.mySellOffers[index]
        if not data then
            break
        end

        local color = i % 2 == 0 and '#484848' or '#414141'
        widget:setId(color)
        widget.actionId = index
        widget:setBackgroundColor(color)
        widget.amount:setText(data.amount)
        widget.name:setText(g_things.getThingType(data.itemId, ThingCategoryItem):getMarketData().name)
        widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", data.timestamp))
        widget.counter = data.counter
        widget.piecePrice:setColor("#c0c0c0")
        widget.totalPrice:setColor("#c0c0c0")
        widget.name:setColor("#c0c0c0")
        widget.amount:setColor("#c0c0c0")
        widget.endAt:setColor("#c0c0c0")

        local itemTier = data.itemTier or 0
        if itemTier > 0 then
            widget.name:setText(widget.name:getText() .. " (Tier " .. itemTier .. ")")
        end

        local totalPrice = data.price * data.amount
        local unitPrice = data.price
        widget.piecePrice:setText(convertLongGold(unitPrice))
        widget.totalPrice:setText(convertLongGold(totalPrice))
        if totalPrice > 99999999 then
            widget.totalPrice:setTooltip(comma_value(totalPrice))
        end

        if unitPrice > 99999999 then
            widget.piecePrice:setTooltip(comma_value(unitPrice))
        end

        if MarketOwnOffers.selectedSellCounter.counter == data.counter then
            widget:setBackgroundColor('#585858')
            widget.piecePrice:setColor("#f4f4f4")
            widget.totalPrice:setColor("#f4f4f4")
            widget.name:setColor("#f4f4f4")
            widget.amount:setColor("#f4f4f4")
            widget.endAt:setColor("#f4f4f4")
            window.sellOffersList:focusChild(widget)
        end
    end
end

local function createWidgetMarket(widget, count, value, startLabel, i)
    local window = marketWindow.MarketHistory.currentOffers
    local index = value > 0 and (startLabel + i - 1) or (startLabel + i)
    local data = MarketOwnOffers.myBuyOffers[index]
    if not data then
        return false
    end
    local color = count % 2 == 0 and '#484848' or '#414141'

    widget:setId(color)
    widget.actionId = index
    widget:setBackgroundColor(color)
    widget.amount:setText(data.amount)
    widget.name:setText(g_things.getThingType(data.itemId, ThingCategoryItem):getMarketData().name)
    widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", data.timestamp))
    widget.counter = data.counter
    widget.piecePrice:setColor("#c0c0c0")
    widget.totalPrice:setColor("#c0c0c0")
    widget.name:setColor("#c0c0c0")
    widget.amount:setColor("#c0c0c0")
    widget.endAt:setColor("#c0c0c0")

    local itemTier = data.itemTier or 0
    if itemTier > 0 then
        widget.name:setText(widget.name:getText() .. " (Tier " .. itemTier .. ")")
    end

    local totalPrice = data.price * data.amount
    local unitPrice = data.price
    widget.piecePrice:setText(convertLongGold(unitPrice))
    widget.totalPrice:setText(convertLongGold(totalPrice))
    if totalPrice > 99999999 then
        widget.totalPrice:setTooltip(comma_value(totalPrice))
    end

    if unitPrice > 99999999 then
        widget.piecePrice:setTooltip(comma_value(unitPrice))
    end

    if MarketOwnOffers.selectedBuyCounter.counter == data.counter then
        widget:setBackgroundColor('#585858')
        widget.piecePrice:setColor("#f4f4f4")
        widget.totalPrice:setColor("#f4f4f4")
        widget.name:setColor("#f4f4f4")
        widget.amount:setColor("#f4f4f4")
        widget.endAt:setColor("#f4f4f4")
        window.buyOffersList:focusChild(widget)
    end

    return true
end

function MarketOwnOffers.onBottomListValueChange(scroll, value, delta)
    local window = marketWindow.MarketHistory.currentOffers
    local startLabel = math.max(MarketOwnOffers.bottomListMin, value)
    local endLabel = startLabel + MarketOwnOffers.bottomListFitItems - 1

    if endLabel > MarketOwnOffers.bottomListMax then
        endLabel = MarketOwnOffers.bottomListMax
        startLabel = endLabel - MarketOwnOffers.bottomListFitItems + 1
    end

    local count = 0
    for i, widget in ipairs(window.buyOffersList:getChildren()) do
        if createWidgetMarket(widget, count, value, startLabel, i) then
            count = count + 1
        end
    end
end
