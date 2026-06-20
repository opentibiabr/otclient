controller = Controller:new()

if not g_gameConfig.isDrawingInformationByWidget() then
    return
end

g_logger.warning("Creature Information By Widget is enabled. (performance may be depreciated)");

local devMode = false
local debug = false

local COVERED_COLOR = '#606060'
local NPC_COLOR = '#66CCFF'

local function onCreate(creature)
    local widget = g_ui.loadUI('creatureinformation')

    if debug then
        widget:setBorderColor('red')
        widget:setBorderWidth(2)
        widget.icons:setBorderColor('yellow')
        widget.icons:setBorderWidth(2)
    end

    widget.manaBar:setVisible(creature:isLocalPlayer())

    creature:setWidgetInformation(widget)
end

local function onHealthPercentChange(creature, healthPercent, oldHealthPercent)
    local gameMapPanel = modules.game_interface.getMapPanel()
    local widget = creature:getWidgetInformation()
    local color = nil

    if healthPercent > 92 then
        color = '#00BC00';
    elseif healthPercent > 60 then
        color = '#50A150';
    elseif healthPercent > 30 then
        color = '#A1A100';
    elseif healthPercent > 8 then
        color = '#BF0A0A';
    elseif healthPercent > 3 then
        color = '#910F0F';
    else
        color = '#850C0F'
    end

    widget.name:setColor(color)
    widget.lifeBar:setPercent(healthPercent)
    widget.lifeBar:setBackgroundColor(color)
    widget.lifeBar:setVisible(gameMapPanel:isDrawingHealthBars()
        and not (creature:isLocalPlayer() and not gameMapPanel:isDrawingSelfHealthBar()))
end

local function onManaChange(player, mana, maxMana, oldMana, oldMaxMana)
    local gameMapPanel = modules.game_interface.getMapPanel()
    local widget = player:getWidgetInformation()

    if player:getMaxMana() > 1 then
        widget.manaBar:setPercent((mana / maxMana) * 100)
    else
        widget.manaBar:setPercent(1)
    end

    widget.manaBar:setVisible(gameMapPanel:isDrawingManaBar())
end

local function onChangeName(creature, name, oldName)
    local gameMapPanel = modules.game_interface.getMapPanel()
    local infoWidget = creature:getWidgetInformation()

    if g_game.getFeature(GameBlueNpcNameColor) and creature:isNpc() and creature:isFullHealth() then
        infoWidget.name:setColor(NPC_COLOR)
    end

    infoWidget.name:setText(name)
    infoWidget.name:setVisible(gameMapPanel:isDrawingNames())
end

local function onCovered(creature, isCovered, oldIsCovered)
    local infoWidget = creature:getWidgetInformation()
    if isCovered then
        infoWidget.name:setColor(COVERED_COLOR)
        infoWidget.lifeBar:setBackgroundColor(COVERED_COLOR)
    else
        onHealthPercentChange(creature, creature:getHealthPercent())
    end
end

local function onOutfitChange(creature, outfit, oldOutfit)
    local infoWidget = creature:getWidgetInformation()
    if not infoWidget then
        return
    end

    if g_gameConfig.isAdjustCreatureInformationBasedCropSize() then
        infoWidget:setMarginTop(-creature:getExactSize())
    end
end

local function blinkIcon(icon, ticks)
    if icon:isDestroyed() then
        return
    end

    icon:setVisible(not icon:isVisible())

    scheduleEvent(function()
        blinkIcon(icon, ticks)
    end, ticks)
end

local function setIcon(creature, id, getIconPath, typeIcon)
    local setParentAnchor = function(w)
        w:addAnchor(AnchorTop, 'parent', AnchorTop)
        w:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    end

    local infoWidget = creature:getWidgetInformation()
    local oldIcon = infoWidget.icons[typeIcon]

    if oldIcon then
        local index = oldIcon:getChildIndex()
        oldIcon:destroy()

        if index == 1 and infoWidget.icons:hasChildren() then
            setParentAnchor(infoWidget.icons:getChildByIndex(index))
        end
    end

    local hasChildren = infoWidget.icons:hasChildren()
    local path, blink = getIconPath(id)

    if path == nil then
        if not hasChildren then
            infoWidget.icons:setVisible(false)
        end
        return
    end

    local icon = g_ui.createWidget('IconInformation', infoWidget.icons)
    icon:setId(typeIcon)
    icon:setImageSource(path)

    if not hasChildren then
        setParentAnchor(icon)
        infoWidget.icons:setVisible(true)
    end

    if blink then
        blinkIcon(icon, g_gameConfig.getShieldBlinkTicks())
    end
end

local creatureEvents = {
    onCreate = onCreate,
    onOutfitChange = onOutfitChange,
    onCovered = onCovered,
    onHealthPercentChange = onHealthPercentChange,
    onChangeName = onChangeName,
    onTypeChange = function(creature, id) setIcon(creature, id, getTypeImagePath, 'type') end,
    onIconChange = function(creature, id) setIcon(creature, id, getIconImagePath, 'icon') end,
    onSkullChange = function(creature, id) setIcon(creature, id, getSkullImagePath, 'skull') end,
    onShieldChange = function(creature, id) setIcon(creature, id, getShieldImagePathAndBlink, 'shield') end,
    onEmblemChange = function(creature, id) setIcon(creature, id, getEmblemImagePath, 'emblem') end,
};

function toggleInformation()
    local localPlayer = g_game.getLocalPlayer()
    if not localPlayer then return end

    local gameMapPanel = modules.game_interface.getMapPanel()

    localPlayer:getWidgetInformation().manaBar:setVisible(gameMapPanel:isDrawingManaBar())

    local spectators = modules.game_interface.getMapPanel():getSpectators()
    for _, creature in ipairs(spectators) do
        creature:getWidgetInformation().name:setVisible(gameMapPanel:isDrawingNames())
        creature:getWidgetInformation().lifeBar:setVisible(gameMapPanel:isDrawingHealthBars())
    end
end

function controller:onInit()
    controller:registerEvents(Creature, creatureEvents)
    controller:registerEvents(LocalPlayer, { onManaChange = onManaChange })
end

if devMode then
    function controller:onGameStart()
        local spectators = modules.game_interface.getMapPanel():getSpectators()
        for _, creature in ipairs(spectators) do
            onCreate(creature)

            if creature:isLocalPlayer() then
                onManaChange(creature, creature:getMana(), creature:getMaxMana(), creature:getMana(),
                    creature:getMaxMana())
            end

            onOutfitChange(creature, creature:getOutfit())
            onCovered(creature, creature:isCovered())
            onHealthPercentChange(creature, creature:getHealthPercent(), creature:getHealthPercent())
            onChangeName(creature, creature:getName())

            creatureEvents.onTypeChange(creature, creature:getType())
            creatureEvents.onIconChange(creature, creature:getIcon())
            creatureEvents.onSkullChange(creature, creature:getSkull())
            creatureEvents.onShieldChange(creature, creature:getShield())
            creatureEvents.onEmblemChange(creature, creature:getEmblem())
        end
    end
end
