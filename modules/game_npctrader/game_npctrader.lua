controllerNpcTrader = Controller:new()
controllerNpcTrader.widthConsole = controllerNpcTrader.DEFAULT_CONSOLE_WIDTH
controllerNpcTrader.creatureName = ""
controllerNpcTrader.outfit = nil
controllerNpcTrader.buttons = {}
controllerNpcTrader.isTradeOpen = false

function controllerNpcTrader:onInit()

end

function controllerNpcTrader:onGameStart()
    if not g_game.getFeature(GameNpcWindowRedesign) then
        self:legacy_init()
    end

    self:registerEvents(g_game, {
        onNpcChatWindow = onNpcChatWindow,
        onOpenNpcTrade = function(...)
            if not g_game.getFeature(GameNpcWindowRedesign) then
                self:onOpenNpcTradeLegacy(...)
            else
                onOpenNpcTrade(...)
            end
        end,
        onPlayerGoods = function(...)
            if not g_game.getFeature(GameNpcWindowRedesign) then
                self:onPlayerGoodsLegacy(...)
            else
                -- onPlayerGoods(...)
            end
        end,
        onCloseNpcTrade = function()
            self:onCloseNpcTrade()
        end,
        onTalk = onNpcTalk
    })
end

function controllerNpcTrader:onTerminate()
    self:onCloseNpcTrade()
    if  not g_game.getFeature(GameNpcWindowRedesign) then
        self:legacy_terminate()
    end
end

function controllerNpcTrader:onGameEnd()
    self:onCloseNpcTrade()
    if not g_game.getFeature(GameNpcWindowRedesign) then
        self:legacy_hide()
    end
end

function controllerNpcTrader:onCloseNpcTrade()
    controllerNpcTrader.isTradeOpen = false
    -- Clean up state
    controllerNpcTrader.buyItems = {}
    controllerNpcTrader.sellItems = {}
    controllerNpcTrader.playerItems = {}
    controllerNpcTrader.selectedItem = nil
    controllerNpcTrader.tradeItems = {}
    controllerNpcTrader.currentList = {}
    controllerNpcTrader.allTradeItems = {}

    if not g_game.getFeature(GameNpcWindowRedesign) then
        self:legacy_hide()
    end

    if controllerNpcTrader.ui and controllerNpcTrader.ui:isVisible() then
        controllerNpcTrader:unloadHtml()
    end
end

