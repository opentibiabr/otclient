-- @ Widgets
monkCircleBackground = nil
monkHealthCircle = nil
monkSereneCircle = nil
monkHarmonySlots = {}
isMonkMode = false
monkImageSizeBroad = 0
monkImageSizeThin = 0
monkOpacity = 0.7
monkHarmony = 0
monkSerene = false

-- @ position constants
MONK_SERENE_OFFSET_X = 0
MONK_SERENE_OFFSET_Y = 0
MONK_HARMONY_OFFSET_X = 0
MONK_HARMONY_OFFSET_Y = 0

local function clampMonkOpacity(value)
    if type(value) ~= 'number' then
        return monkOpacity
    end
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

local function clampMonkHarmony(value)
    if type(value) ~= 'number' then
        return 0
    end
    value = math.floor(value)
    if value < 0 then
        return 0
    end
    if value > 5 then
        return 5
    end
    return value
end

local function refreshMonkDynamicOpacity()
    if monkSereneCircle then
        monkSereneCircle:setImageColor('#9933FF')
        monkSereneCircle:setOpacity(monkSerene and monkOpacity or 0)
    end

    for i = 1, 5 do
        local slot = monkHarmonySlots[i]
        if slot then
            if i <= monkHarmony then
                slot:setImageColor('#FFD700')
                slot:setOpacity(monkOpacity)
            else
                slot:setOpacity(0)
            end
        end
    end
end

function initMonkWidgets()
    local mapPanel = modules.game_interface.getMapPanel()
    monkCircleBackground = g_ui.createWidget('MonkCircleBackground', mapPanel)
    monkHealthCircle = g_ui.createWidget('MonkHealthCircle', mapPanel)
    monkSereneCircle = g_ui.createWidget('MonkSereneCircle', mapPanel)
    for i = 1, 5 do
        local slot = g_ui.createWidget('MonkHarmonySlot', mapPanel)
        slot:setImageSource('/data/images/game/healthcircle/left/default-slot-' .. i .. '-monk')
        slot:setVisible(false)
        monkHarmonySlots[i] = slot
    end
    monkCircleBackground:setVisible(false)
    monkHealthCircle:setVisible(false)
    monkSereneCircle:setVisible(false)
    monkHarmony = 0
    monkSerene = false
    monkImageSizeBroad = monkHealthCircle:getHeight()
    monkImageSizeThin = monkHealthCircle:getWidth()
    refreshMonkDynamicOpacity()
end

function terminateMonkWidgets()
    if monkCircleBackground then
        monkCircleBackground:destroy()
        monkCircleBackground = nil
    end
    if monkHealthCircle then
        monkHealthCircle:destroy()
        monkHealthCircle = nil
    end
    if monkSereneCircle then
        monkSereneCircle:destroy()
        monkSereneCircle = nil
    end
    for i = 1, 5 do
        if monkHarmonySlots[i] then
            monkHarmonySlots[i]:destroy()
            monkHarmonySlots[i] = nil
        end
    end
    monkHarmony = 0
    monkSerene = false
    isMonkMode = false
end

function switchToMonkMode(enabled)
    if not g_game.getFeature(GameVocationMonk) then
        return
    end
    isMonkMode = enabled
    healthCircle:setVisible(not enabled and isHealthCircle)
    healthCircleFront:setVisible(not enabled and isHealthCircle)
    monkCircleBackground:setVisible(enabled)
    monkHealthCircle:setVisible(enabled)
    monkSereneCircle:setVisible(enabled)
    for i = 1, 5 do
        monkHarmonySlots[i]:setVisible(enabled)
    end
    if enabled then
        local player = g_game.getLocalPlayer()
        if player then
            monkHarmony = clampMonkHarmony(player:getHarmony())
            monkSerene = player:isSerene()
        else
            monkHarmony = 0
            monkSerene = false
        end
        refreshMonkDynamicOpacity()
        whenMapResizeChange()
        whenMonkHealthChange()
    end
end

function checkMonkVocation()
    local player = g_game.getLocalPlayer()
    if not player then
        return false
    end
    local isMonk = player:isMonk() and g_game.getFeature(GameVocationMonk)
    if isMonk ~= isMonkMode then
        switchToMonkMode(isMonk)
    end
    return isMonk
end

function whenMonkHealthChange()
    if not isMonkMode or not g_game.isOnline() then
        return
    end
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end
    local healthPercent = math.floor(player:getHealth() / player:getMaxHealth() * 100)
    local yhppc = math.floor(monkImageSizeBroad * (1 - (healthPercent / 100)))
    local restYhppc = monkImageSizeBroad - yhppc
    monkHealthCircle:setY(monkCircleBackground:getY() + yhppc)
    monkHealthCircle:setHeight(restYhppc)
    monkHealthCircle:setImageClip({
        x = 0,
        y = yhppc,
        width = monkImageSizeThin,
        height = restYhppc
    })
    if healthPercent > 92 then
        monkHealthCircle:setImageColor('#00BC00')
    elseif healthPercent > 60 then
        monkHealthCircle:setImageColor('#50A150')
    elseif healthPercent > 30 then
        monkHealthCircle:setImageColor('#A1A100')
    elseif healthPercent > 8 then
        monkHealthCircle:setImageColor('#BF0A0A')
    else
        monkHealthCircle:setImageColor('#910F0F')
    end
end

function whenMonkSereneChange(localplayer, serene)
    monkSerene = not not serene
    refreshMonkDynamicOpacity()
end

function whenMonkHarmonyChange(localplayer, harmony)
    monkHarmony = clampMonkHarmony(harmony)
    refreshMonkDynamicOpacity()
end

function positionMonkWidgets()
    if not isMonkMode or not monkCircleBackground then
        return
    end
    local monkX = healthCircle:getX()
    local monkY = healthCircle:getY()
    monkCircleBackground:setX(monkX)
    monkCircleBackground:setY(monkY)
    monkHealthCircle:setX(monkX)
    monkHealthCircle:setY(monkY)
    monkSereneCircle:setX(monkX + MONK_SERENE_OFFSET_X)
    monkSereneCircle:setY(monkY + MONK_SERENE_OFFSET_Y)
    for i = 1, 5 do
        monkHarmonySlots[i]:setX(monkX + MONK_HARMONY_OFFSET_X)
        monkHarmonySlots[i]:setY(monkY + MONK_HARMONY_OFFSET_Y)
    end
    whenMonkHealthChange()
end

-------------------------------------------------
-- client_options
-------------------------------------------------

function setMonkCircleOpacity(value)
    monkOpacity = clampMonkOpacity(value)
    if monkCircleBackground then
        monkCircleBackground:setOpacity(monkOpacity)
    end
    if monkHealthCircle then
        monkHealthCircle:setOpacity(monkOpacity)
    end
    refreshMonkDynamicOpacity()
end

function setMonkWidgetsVisible(visible)
    if monkCircleBackground then
        monkCircleBackground:setVisible(visible)
    end
    if monkHealthCircle then
        monkHealthCircle:setVisible(visible)
    end
    if monkSereneCircle then
        monkSereneCircle:setVisible(visible)
    end
    for i = 1, 5 do
        if monkHarmonySlots[i] then
            monkHarmonySlots[i]:setVisible(visible)
        end
    end
end
