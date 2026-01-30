CompendiumController = Controller:new()
CompendiumController.currentTab = 'player-guide'
CompendiumController.callbacks = {}

function CompendiumController:onInit()
    -- CompendiumController:registerEvents(g_game, {
    --     onBlessingsChange = onBlessingsChange
    -- })
end

function CompendiumController:onTerminate()
    -- CompendiumController:findWidget("#blessingsWindow"):destroy()
end

function CompendiumController:onGameStart()
    if g_game.getFeature(GameCompendium) then -- 1100
        if not CompendiumBtn then
            CompendiumBtn = modules.game_mainpanel.addToggleButton('CompendiumBtn', tr('Open Compendium'),
                '/images/options/compendium.png', function()
                    self:toggle()
                end)
        end
        self.currentTab = 'player-guide'
    else
        -- Store unload callback
        self.callbacks.unloadModule = function()
            g_modules.getModule("game_compendium"):unload()
        end
        scheduleEvent(self.callbacks.unloadModule, 100)
    end
end

function CompendiumController:onGameEnd()
    self:hide()
end

function CompendiumController:close()
    self:hide()
end

function CompendiumController:show()
    self:loadHtml('compendium.html')
    self.ui:show()
    self.ui:raise()
    self.ui:focus()
end

function CompendiumController:hide()
    if self.ui then
        self:unloadHtml()
    end
end

function CompendiumController:toggle()
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
