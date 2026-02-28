notificationsController = Controller:new()
function notificationsController:onInit()
    self.bannerQueue = {}
    self.bannerState = "idle"
    self:registerEvents(g_game, {
        onClientEvent = function(...)
            self:onClientEvent(...)
        end,
    })
end
function notificationsController:onTerminate()
    screenshot_onTerminate()
    infoBanner_onTerminate()
end

function notificationsController:onGameStart()
    screenshot_onGameStart()
end

function notificationsController:onGameEnd()
    screenshot_onGameEnd()
end
