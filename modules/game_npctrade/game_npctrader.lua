controllerNpcTrader = Controller:new()
controllerNpcTrader.widthConsole = controllerNpcTrader.DEFAULT_CONSOLE_WIDTH
controllerNpcTrader.creatureName = ""
controllerNpcTrader.outfit = nil
controllerNpcTrader.buttons = {}
controllerNpcTrader.isTradeOpen = false
controllerNpcTrader.legacyMode = false
controllerNpcTrader.npcTalkConnected = false

function controllerNpcTrader:isLegacyMode()
    return self.legacyMode
end

function controllerNpcTrader:onInit()

end

function controllerNpcTrader:onGameStart()
    self.legacyMode = not g_game.getFeature(GameNpcWindowRedesign)
    if self:isLegacyMode() then
        self:legacy_init()
    end

    self:registerEvents(g_game, {
        onNpcChatWindow = function(data)
            onNpcChatWindow(data)
        end,
        onOpenNpcTrade = function(...)
            if self:isLegacyMode() then
                onOpenNpcTrade(...)
            else
                self:onOpenNpcTrade(...)
            end
        end,
        onPlayerGoods = function(money, items)
            if self:isLegacyMode() then
                onPlayerGoods(money, items)
            else
                self:onPlayerGoods(money, items)
            end
        end,
        onNpcChatWindowClose = function()
            if self:isLegacyMode() then
                self:legacy_hide()
            else
                self:onCloseNpcTrade()
            end
        end,
        onCloseNpcTrade = function()
            if self:isLegacyMode() then
                self:legacy_hide()
            else
                self:onCloseNpcTrade()
            end
        end
    })
end

function controllerNpcTrader:connectNpcTalkEvent()
    if self:isLegacyMode() or self.npcTalkConnected then
        return
    end

    connect(g_game, {
        onTalk = onNpcTalk
    })
    self.npcTalkConnected = true
end

function controllerNpcTrader:disconnectNpcTalkEvent()
    if not self.npcTalkConnected then
        return
    end

    disconnect(g_game, {
        onTalk = onNpcTalk
    })
    self.npcTalkConnected = false
end

function controllerNpcTrader:onTerminate()
    if self:isLegacyMode() then
        self:legacy_terminate()
    else
        self:onCloseNpcTrade()
    end
end

function controllerNpcTrader:onGameEnd()
    if self:isLegacyMode() then
        self:legacy_hide()
    else
        self:onCloseNpcTrade()
    end
end

function controllerNpcTrader:onCloseNpcTrade()
    if self:isLegacyMode() then
        self:legacy_hide()
    else
        self:disconnectNpcTalkEvent()
        if controllerNpcTrader.ui and controllerNpcTrader.ui:isVisible() then
            controllerNpcTrader:unloadHtml()
        end
        controllerNpcTrader.isTradeOpen = false
        if controllerNpcTrader.sellAllWithDelayEvent then
            removeEvent(controllerNpcTrader.sellAllWithDelayEvent)
            controllerNpcTrader.sellAllWithDelayEvent = nil
        end
        -- Clean up state
        controllerNpcTrader.buyItems = {}
        controllerNpcTrader.sellItems = {}
        controllerNpcTrader.playerItems = {}
        controllerNpcTrader.playerMoney = nil
        controllerNpcTrader.selectedItem = nil
        controllerNpcTrader.tradeItems = {}
        controllerNpcTrader.currentList = {}
        controllerNpcTrader.allTradeItems = {}
    end
end

function sellAll(...) -- Vbot Call
    if controllerNpcTrader:isLegacyMode() then
        sellAllLegacy(...)
    else
        controllerNpcTrader:sellAll(...)
    end
end

function isTrading(...) -- Vbot Call
    if controllerNpcTrader:isLegacyMode() then
        return isTradingLegacy(...)
    end

    return controllerNpcTrader.isTradeOpen == true
end

function getSellItems(...) -- Vbot Call
    if controllerNpcTrader:isLegacyMode() then
        return getSellItemsLegacy(...)
    end

    return controllerNpcTrader.sellItems or {}
end

function getBuyItems(...) -- Vbot Call
    if controllerNpcTrader:isLegacyMode() then
        return getBuyItemsLegacy(...)
    end

    return controllerNpcTrader.buyItems or {}
end

function getSellQuantity(item) -- Vbot Call
    if controllerNpcTrader:isLegacyMode() then
        return getSellQuantityLegacy(item)
    end

    if type(item) == 'number' then
        item = Item.create(item)
    end

    return controllerNpcTrader:getSellQuantity(item)
end

function canTradeItem(item) -- Vbot Call
    if controllerNpcTrader:isLegacyMode() then
        return canTradeItemLegacy(item)
    end

    if type(item) == 'number' then
        item = Item.create(item)
    end

    local tradeEntry = item
    if item and not item.ptr then
        for _, entry in ipairs(controllerNpcTrader.sellItems or {}) do
            if entry.ptr:getId() == item:getId() and entry.ptr:getSubType() == item:getSubType() then
                tradeEntry = entry
                break
            end
        end

        if tradeEntry == item then
            for _, entry in ipairs(controllerNpcTrader.buyItems or {}) do
                if entry.ptr:getId() == item:getId() and entry.ptr:getSubType() == item:getSubType() then
                    tradeEntry = entry
                    break
                end
            end
        end
    end

    if not tradeEntry or not tradeEntry.ptr then
        return false
    end

    return controllerNpcTrader:canTradeItem(tradeEntry)
end

function closeNpcTrade(...) -- Vbot Call
    if controllerNpcTrader:isLegacyMode() then
        return closeNpcTradeLegacy(...)
    end

    return g_game.closeNpcTrade()
end
