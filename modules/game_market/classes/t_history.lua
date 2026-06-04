MarketHistory = {}
MarketHistory.__index = MarketHistory

local onTopListValueChange = nil
local onBottomListValueChange = nil

local topListMin = 0
local topListMax = 0

local bottomListMin = 0
local bottomListMax = 0

local topListFitItems = 0
local bottomListFitItems = 0

local labelSize = 16
local historyOfferPool = 14

local topListPool = {}
local bottomListPool = {}

local topListData = {}
local bottomListData = {}

function MarketHistory.onTopListValueChange(scroll, value, delta)
    local startLabel = math.max(topListMin, value)
    local endLabel = startLabel + topListFitItems - 1

    if endLabel > topListMax then
        endLabel = topListMax
        startLabel = endLabel - topListFitItems + 1
    end

    for i, widget in ipairs(topListPool) do
        local index = value > 0 and (startLabel + i - 1) or (startLabel + i)
        local data = topListData[index]
        if not data then
            widget:setVisible(false)
        else
            local color = i % 2 == 0 and '#484848' or '#414141'
            widget:setId(color)
            widget.actionId = i
            widget:setBackgroundColor(color)
            widget:setColor('#c0c0c0')
            widget.amount:setText(data.amount)
            widget.name:setText(g_things.getThingType(data.itemId, ThingCategoryItem):getMarketData().name)
            widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", data.timestamp))
            widget.status:setText(MarketSellStatus[data.state])
            widget.piecePrice:setColor("#c0c0c0")
            widget.totalPrice:setColor("#c0c0c0")
            widget.name:setColor("#c0c0c0")
            widget.amount:setColor("#c0c0c0")
            widget.endAt:setColor("#c0c0c0")
            widget.status:setColor("#c0c0c0")

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

    local window = marketWindow.MarketHistory:recursiveGetChildById('sellOffersList')
    window:focusChild(nil)
    lastSelectedHistorySell = nil
end

function MarketHistory.onBottomListValueChange(scroll, value, delta)
    local startLabel = math.max(bottomListMin, value)
    local endLabel = startLabel + bottomListFitItems - 1
    if endLabel > bottomListMax then
        endLabel = bottomListMax
        startLabel = endLabel - bottomListFitItems + 1
    end

    for i, widget in ipairs(bottomListPool) do
        local index = value > 0 and (startLabel + i - 1) or (startLabel + i)
        local data = bottomListData[index]
        if not data then
            break
        end

        local color = ((index % 2 == 0) and '#414141' or '#484848')
        widget:setId(color)
        widget.actionId = index
        widget:setBackgroundColor(color)
        widget:setColor('#c0c0c0')
        widget.amount:setText(data.amount)
        widget.name:setText(g_things.getThingType(data.itemId, ThingCategoryItem):getMarketData().name)
        widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", data.timestamp))
        widget.status:setText(MarketBuyStatus[data.state])
        widget.piecePrice:setColor("#c0c0c0")
        widget.totalPrice:setColor("#c0c0c0")
        widget.name:setColor("#c0c0c0")
        widget.amount:setColor("#c0c0c0")
        widget.endAt:setColor("#c0c0c0")
        widget.status:setColor("#c0c0c0")

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

    local window = marketWindow.MarketHistory:recursiveGetChildById('buyOffersList')
    window:focusChild(nil)
    lastSelectedHistoryBuy = nil
end

function MarketHistory.onParseMarketHistory(buyOffers, sellOffers)
    local window = marketWindow.MarketHistory.offerHistory
    window.sellOffersList:destroyChildren()
    window.buyOffersList:destroyChildren()
    lastSelectedHistorySell = nil
    lastSelectedHistoryBuy = nil

    topListFitItems = math.floor(window.sellOffersList:getHeight() / labelSize)
    topListMin = 0
    topListPool = {}
    topListData = sellOffers
    topListMax = #sellOffers

    for i = 1, historyOfferPool do
        local widget = g_ui.createWidget('MarketHistoryWidget', window.sellOffersList)
        local data = sellOffers[i]
        if not data then
            widget:setVisible(false)
        else
            local color = i % 2 == 0 and '#414141' or '#484848'
            widget:setId(color)
            widget.actionId = i
            widget:setBackgroundColor(color)
            widget.amount:setText(data.amount)
            widget.name:setText(g_things.getThingType(data.itemId, ThingCategoryItem):getMarketData().name)
            widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", data.timestamp))
            widget.status:setText(MarketSellStatus[data.state])

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

        table.insert(topListPool, widget)
    end

    local sellScrollbar = marketWindow.MarketHistory:recursiveGetChildById('sellOffersListScroll')
    sellScrollbar:setMinimum(topListMin)
    sellScrollbar:setMaximum(math.max(0, topListMax - historyOfferPool))
    sellScrollbar.onValueChange = function(self, value, delta)
        MarketHistory.onTopListValueChange(self, value, delta)
    end

    bottomListFitItems = math.floor(window.buyOffersList:getHeight() / labelSize)
    bottomListMin = 0
    bottomListPool = {}
    bottomListData = buyOffers
    bottomListMax = #buyOffers

    for i = 1, historyOfferPool do
        local widget = g_ui.createWidget('MarketHistoryWidget', window.buyOffersList)
        local data = buyOffers[i]
        if not data then
            widget:setVisible(false)
        else
            local color = i % 2 == 0 and '#484848' or '#414141'
            widget:setId(color)
            widget.actionId = i
            widget:setBackgroundColor(color)
            widget.amount:setText(data.amount)
            widget.name:setText(g_things.getThingType(data.itemId, ThingCategoryItem):getMarketData().name)
            widget.endAt:setText(os.date("%Y-%m-%d, %H:%M:%S", data.timestamp))
            widget.status:setText(MarketBuyStatus[data.state])

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

        table.insert(bottomListPool, widget)
    end

    local buyScrollbar = marketWindow.MarketHistory:recursiveGetChildById('buyOffersListScroll')
    buyScrollbar:setMinimum(bottomListMin)
    buyScrollbar:setMaximum(math.max(0, bottomListMax - historyOfferPool))
    buyScrollbar.onValueChange = function(self, value, delta)
        MarketHistory.onBottomListValueChange(self, value, delta)
    end

    window.sellOffersList.onChildFocusChange = function(self, selected)
        MarketHistory.onSelectHistoryChild(self, selected, true)
    end
    window.buyOffersList.onChildFocusChange = function(self, selected)
        MarketHistory.onSelectHistoryChild(self, selected, false)
    end

    local firstChild = window.sellOffersList:getChildren()[1]
    if firstChild then
        window.sellOffersList:onChildFocusChange(firstChild, nil, KeyboardFocusReason)
    end

    firstChild = window.buyOffersList:getChildren()[1]
    if firstChild then
        window.buyOffersList:onChildFocusChange(firstChild, nil, KeyboardFocusReason)
    end

    window.sellOffersLabel:setText("Sell Offers (" .. #sellOffers .. "):")
    window.buyOffersLabel:setText("Buy Offers (" .. #buyOffers .. "):")
end

function MarketHistory.onSelectHistoryChild(widget, selected, selling)
    if not selected then
        return
    end

    local lastSelected = selling and lastSelectedHistorySell or lastSelectedHistoryBuy
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
            lastSelected.status:setColor("#c0c0c0")
        end
    end

    if selling then
        lastSelectedHistorySell = selected
    else
        lastSelectedHistoryBuy = selected
    end

    selected:setBackgroundColor('#585858')
    selected.piecePrice:setColor("#f4f4f4")
    selected.totalPrice:setColor("#f4f4f4")
    selected.name:setColor("#f4f4f4")
    selected.amount:setColor("#f4f4f4")
    selected.endAt:setColor("#f4f4f4")
    selected.status:setColor("#f4f4f4")
end
