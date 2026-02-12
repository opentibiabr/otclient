-- LuaFormatter off
--@ array
local ScreenshotType = {
    NONE = 0,
    ACHIEVEMENT = 1,
    BESTIARY_ENTRY_COMPLETED = 2,
    BESTIARY_ENTRY_UNLOCKED = 3,
    BOSS_DEFEATED = 4,
    DEATH_PVE = 5,
    DEATH_PVP = 6,
    LEVEL_UP = 7,
    PLAYER_KILL_ASSIST = 8,
    PLAYER_KILL = 9,
    PLAYER_ATTACKING = 10,
    TREASURE_FOUND = 11,
    SKILL_UP = 12,
    HIGHEST_DAMAGE_DEALT = 13,
    HIGHEST_HEALING_DONE = 14,
    LOW_HEALTH = 15,
    GIFT_OF_LIFE_TRIGGERED = 16
}
local checkboxes = {}
local TypeScreenshots = {}
local AutoScreenshotEvents = {
    {id = ScreenshotType.LEVEL_UP, label = "Level Up", enableDefault = true},
    {id = ScreenshotType.SKILL_UP, label = "Skill Up", enableDefault = true},
    {id = ScreenshotType.ACHIEVEMENT, label = "Achievement", enableDefault = true},
    {id = ScreenshotType.BESTIARY_ENTRY_UNLOCKED, label = "Bestiary Entry Unlocked", enableDefault = false},
    {id = ScreenshotType.BESTIARY_ENTRY_COMPLETED, label = "Bestiary Entry Completed", enableDefault = false},
    {id = ScreenshotType.TREASURE_FOUND, label = "Treasure Found", enableDefault = false},
    {id = -99, label = "Valuable Loot", enableDefault = false},
    {id = ScreenshotType.BOSS_DEFEATED, label = "Boss Defeated", enableDefault = false},
    {id = ScreenshotType.DEATH_PVE, label = "Death PvE", enableDefault = true},
    {id = ScreenshotType.DEATH_PVP, label = "Death PvP", enableDefault = false},
    {id = ScreenshotType.PLAYER_KILL, label = "Player Kill", enableDefault = false},
    {id = ScreenshotType.PLAYER_KILL_ASSIST, label = "Player Kill Assist", enableDefault = false},
    {id = ScreenshotType.PLAYER_ATTACKING, label = "Player Attacking", enableDefault = false},
    {id = ScreenshotType.HIGHEST_DAMAGE_DEALT, label = "Highest Damage Dealt", enableDefault = false},
    {id = ScreenshotType.HIGHEST_HEALING_DONE, label = "Highest Healing Done", enableDefault = false},
    {id = ScreenshotType.LOW_HEALTH, label = "Low Health", enableDefault = false},
    {id = ScreenshotType.GIFT_OF_LIFE_TRIGGERED, label = "Gift of Life Triggered", enableDefault = true}
}
-- LuaFormatter on

-- @ widget
local optionPanel = nil
-- @
-- @ variables
local autoScreenshotDirName = "auto_screenshots"
local autoScreenshotDir = g_resources.getWriteDir() .. "/" .. autoScreenshotDirName

-- @

function screenshot_onTerminate()
    destroyOptionsModule()

    ScreenshotType = {}
    checkboxes = {}
    TypeScreenshots = {}
    AutoScreenshotEvents = {}
end

function screenshot_onGameStart()
    if g_game.getClientVersion() < 1180 then
        return
    end
    optionPanel = g_ui.loadUI('/modules/game_notifications/templates/screenshot', modules.client_options:getPanel())

    if not optionPanel then
        g_logger.info("Failed to load screenshot options panel")
        return
    end

    for _, screenshotEvent in ipairs(AutoScreenshotEvents) do
        local label = g_ui.createWidget("ScreenshotType", optionPanel.allCheckBox)
        local settingKey = screenshotEvent.label:gsub("%s+", "")
        local settings = g_settings.getBoolean(settingKey) or screenshotEvent.enableDefault
        label.text:setText(screenshotEvent.label)
        label.enabled:setChecked(settings)
        label.enabled:setId(screenshotEvent.id)
        screenshotEvent.currentBoolean = settings
    end

    optionPanel:recursiveGetChildById("enableScreenshots"):setChecked(g_settings.getBoolean("enableScreenshots"))
    optionPanel:recursiveGetChildById("onlyCaptureGameWindow"):setChecked(g_settings.getBoolean("onlyCaptureGameWindow"))

    if not g_resources.directoryExists(autoScreenshotDir) then
        g_resources.makeDir(autoScreenshotDirName)
    end

    notificationsController:registerEvents(LocalPlayer, {
        onTakeScreenshot = onScreenShot
    })
    optionPanel:recursiveGetChildById("keepBlacklog"):disable() -- no compatibility 11/07/24
   
    modules.client_options.addButton("Misc.", "Screenshot", optionPanel)
end

function screenshot_onGameEnd()
    if g_game.getClientVersion() >= 1180 and optionPanel then
        g_settings.set("onlyCaptureGameWindow", optionPanel:recursiveGetChildById("onlyCaptureGameWindow"):isChecked())
        g_settings.set("enableScreenshots", optionPanel:recursiveGetChildById("enableScreenshots"):isChecked())
        destroyOptionsModule()
    end

    for _, screenshotEvent in ipairs(AutoScreenshotEvents) do
        local labelScreenshotEvent = screenshotEvent.label:gsub("%s+", "")
        g_settings.set(labelScreenshotEvent, screenshotEvent.currentBoolean)
    end
end

function onUICheckBox(widget, checked)
    if not widget then
        return
    end
    local id = tonumber(widget:getId())
    for _, screenshotEvent in ipairs(AutoScreenshotEvents) do
        if screenshotEvent.id == id then
            screenshotEvent.currentBoolean = checked
            break
        end
    end
end

-- LuaFormatter off
function resetValues()
    for _, screenshotEvent in ipairs(AutoScreenshotEvents) do
        local labelScreenshotEvent = screenshotEvent.label:gsub("%s+", "")
        g_settings.set(labelScreenshotEvent, screenshotEvent.currentBoolean)
    end
    if not optionPanel then
        return
    end
    for _, selectedCheckBox in pairs(optionPanel.allCheckBox:getChildren()) do
        for _, selectedCheckBoxChildren in pairs(selectedCheckBox:getChildren()) do
            if selectedCheckBoxChildren:getStyle().__class == 'UICheckBox' then
                local id = tonumber(selectedCheckBoxChildren:getId())
                if id then
                    for _, screenshotEvent in ipairs(AutoScreenshotEvents) do
                        if screenshotEvent.id == id then                
                            selectedCheckBoxChildren:setChecked(screenshotEvent.enableDefault)
                            break
                        end
                    end
                end
            end
        end
    end
end
-- LuaFormatter on

function destroyOptionsModule()
    modules.client_options.removeButton("Misc.","Screenshot")
    if optionPanel and not optionPanel:isDestroyed() then
        optionPanel:destroy()
        optionPanel = nil
    end
end

function onScreenShot(type)
    if not optionPanel or not optionPanel.Opciones3.enableScreenshots:isChecked() then
        return
    end
    local name = g_game.getLocalPlayer():getName() or "player"
    local level = g_game.getLocalPlayer():getLevel() or 1
    for _, screenshotEvent in ipairs(AutoScreenshotEvents) do
        if screenshotEvent.id == type and screenshotEvent.currentBoolean then
            local screenshotName = name .. level .. "_" .. screenshotEvent.label:gsub("%s+", "") .. "_" ..
                                       os.date("%Y%m%d%H%M%S") .. ".png"
            takeScreenshot("/" .. autoScreenshotDirName .. "/" .. screenshotName)
            return
        end
    end
end

function takeScreenshot(name)
    if not g_game.isOnline() then
        return
    end
    if not name:lower():match("%.png$") then
        name = name .. ".png"
    end
    notificationsController:scheduleEvent(function()
        if optionPanel and optionPanel:recursiveGetChildById("onlyCaptureGameWindow"):isChecked() then
            g_app.doMapScreenshot(name)
        else
            g_app.doScreenshot(name)
        end
    end, 50, 'screenshotScheduleEvent')
    local directory = g_resources.getWriteDir():gsub("[/\\]+", "\\") .. autoScreenshotDirName
    local message = string.format("Screenshot has been saved to '%s'.",directory)
    local console = modules.game_console
    console.addText(message, console.SpeakTypesSettings, tr("Server Log"))
    modules.game_textmessage.displayStatusMessage(message)
end

function OpenFolder()
    local directory = g_resources.getWriteDir():gsub("[/\\]+", "\\") .. autoScreenshotDirName
    g_platform.openDir(directory)
end
