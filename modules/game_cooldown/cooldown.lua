local ProgressCallback = {
    update = 1,
    finish = 2
}

cooldownWindow = nil

contentsPanel = nil
cooldownPanel = nil
lastPlayer = nil

cooldown = {}
groupCooldown = {}
tierUpgradeFeatureEnabled = false

function init()
    connect(g_game, {
        onGameEnd = offline,
        onGameStart = online,
        onSpellGroupCooldown = onSpellGroupCooldown,
        onSpellCooldown = onSpellCooldown
    })

    if modules.client_options.getOption('showSpellGroupCooldowns') then
        modules.client_options.setOption('showSpellGroupCooldowns', true)
    else
        modules.client_options.setOption('showSpellGroupCooldowns', false)
    end

    cooldownWindow = g_ui.loadUI('cooldown', modules.game_interface.getBottomPanel())
    contentsPanel = cooldownWindow:getChildById('contentsPanel2')
    cooldownPanel = contentsPanel:getChildById('cooldownPanel')

    -- preload cooldown images
    for k, v in pairs(SpelllistSettings) do
        g_textures.preload(v.iconFile)
        g_textures.preload(v.iconsForGameCooldown)
    end

    if g_game.isOnline() then
        online()
    end
end

function terminate()
    disconnect(g_game, {
        onGameEnd = offline,
        onGameStart = online,
        onSpellGroupCooldown = onSpellGroupCooldown,
        onSpellCooldown = onSpellCooldown
    })

    cooldownWindow:destroy()
end

function loadIcon(iconId)
    local spell, profile, spellName = Spells.getSpellByIcon(iconId)
    if not spellName then
        print('[WARNING] loadIcon: empty spellName for server spell id: ' .. iconId)
        return nil, nil
    end
    if not profile then
        print('[WARNING] loadIcon: empty profile for server spell id: ' .. iconId)
        return nil, nil
    end

    local container = cooldownPanel:getChildById(iconId)
    if not container then
        container = g_ui.createWidget('SpellIconContainer')
        container:setId(iconId)
    end

    local spellSettings = SpelllistSettings[profile]
    if spellSettings then
        local spellIcon = container:getChildById('icon')
        if not spellIcon then
            spellIcon = g_ui.createWidget('SpellIcon', container)
            spellIcon:setId('icon')
            spellIcon:addAnchor(AnchorTop, 'parent', AnchorTop)
            spellIcon:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            spellIcon:setMarginTop(1)
            spellIcon:setMarginLeft(1)
        end
        spellIcon:setImageSource(spellSettings.iconsForGameCooldown)
        spellIcon:setImageClip(Spells.getImageClipCooldown(spell.clientId, profile))
        container.spellName = spellName

        if not container:getChildById('cooldownBarBg') then
            local barBg = g_ui.createWidget('UIWidget', container)
            barBg:setId('cooldownBarBg')
            barBg:setSize('20 2')
            barBg:setBackgroundColor('#000000')
            barBg:addAnchor(AnchorTop, 'icon', AnchorBottom)
            barBg:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            barBg:setMarginTop(1)
            barBg:setMarginLeft(1)
        end

        if not container:getChildById('cooldownBarFg') then
            local barFg = g_ui.createWidget('UIWidget', container)
            barFg:setId('cooldownBarFg')
            barFg:setSize('0 2')
            barFg:setBackgroundColor('#FFFFFF')
            barFg:addAnchor(AnchorTop, 'icon', AnchorBottom)
            barFg:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            barFg:setMarginTop(1)
            barFg:setMarginLeft(1)
        end

        local progressRect = container:getChildById('progressRect')
        local isNewProgressRect = false
        if not progressRect then
            progressRect = g_ui.createWidget('SpellProgressRect', container)
            progressRect:setId('progressRect')
            progressRect:fill('parent')
            isNewProgressRect = true
        end
        progressRect.icon = container
        progressRect:setTooltip(spellName .. " (" .. (spell.exhaustion / 1000) .. " sec. cooldown)")
        if isNewProgressRect then
            progressRect:setPercent(0)
        end
    else
        print('[WARNING] loadIcon: empty spell icon for server spell id: ' .. iconId)
        container = nil
    end
    return container, spellName
end

function online()
    tierUpgradeFeatureEnabled = g_game.getFeature(GameForgeSkillStats) or g_game.getFeature(GameCharacterSkillStats)

    local console = modules.game_console.consolePanel
    if console then
        console:addAnchor(AnchorTop, cooldownWindow:getId(), AnchorBottom)
    end
    if not g_game.getFeature(GameSpellList) then
        modules.client_options.setOption('showSpellGroupCooldowns', false)
        return
    end

    local oldProtocol = g_game.getClientVersion() > 1100
    local monkFeature = g_game.getFeature(GameVocationMonk)
    local groupsToToggle = {'Crippling', 'Focus', 'UltimateStrikes', 'GreatBeams', 'BurstsOfNature', 'Virtue'}
    for _, groupName in ipairs(groupsToToggle) do
        local container = contentsPanel:getChildById('container' .. groupName)
        if container then
            local visible = oldProtocol
            if groupName == 'Virtue' then
                visible = monkFeature
            end
            container:setVisible(visible)
            container:setWidth(visible and 22 or 0)
        end
    end

    if not lastPlayer or lastPlayer ~= g_game.getCharacterName() then
        refresh()
        lastPlayer = g_game.getCharacterName()
    end
end

function offline()
    tierUpgradeFeatureEnabled = false

    local console = modules.game_console.consolePanel
    if console then
        console:removeAnchor(AnchorTop)
        console:fill('parent')
    end
    if g_game.getFeature(GameSpellList) then
        --cooldownWindow:setParent(nil, true)
    end
end

function refresh()
    if cooldownPanel then
        cooldownPanel:destroyChildren()
    end
end

function removeCooldown(progressRect)
    removeEvent(progressRect.event)
    if progressRect.icon then
        progressRect.icon:destroy()
        progressRect.icon = nil
    end
    progressRect = nil
end

function turnOffCooldown(progressRect)
    removeEvent(progressRect.event)
    progressRect.event = nil
    progressRect.callback = nil
    if progressRect.icon then
        progressRect.icon:setOn(false)
        progressRect.icon = nil
    end

    local container = progressRect:getParent()
    if container then
        local barFg = container:getChildById('cooldownBarFg')
        if barFg then
            barFg:setWidth(0)
        end
    end

    progressRect = nil
end

function initCooldown(progressRect, updateCallback, finishCallback)
    progressRect:setPercent(0)

    local container = progressRect:getParent()
    if container then
        local barFg = container:getChildById('cooldownBarFg')
        if barFg then
            barFg:setWidth(20)
        end
    end

    progressRect.callback = {}
    progressRect.callback[ProgressCallback.update] = updateCallback
    progressRect.callback[ProgressCallback.finish] = finishCallback

    updateCallback()
end

function hasTierUpgradeFeature()
    return tierUpgradeFeatureEnabled
end

function updateCooldown(progressRect, duration)
    if not progressRect or progressRect:isDestroyed() then
        return
    end

    local callbacks = progressRect.callback
    if not callbacks then
        return
    end
    progressRect:setPercent(progressRect:getPercent() + 10000 / duration)

    local container = progressRect:getParent()
    if container then
        local barFg = container:getChildById('cooldownBarFg')
        if barFg then
            local remainingPercent = math.max(0, 100 - progressRect:getPercent())
            barFg:setWidth(math.floor(remainingPercent / 100 * 20 + 0.5))
        end
    end

    if progressRect:getPercent() < 100 then
        removeEvent(progressRect.event)
        local updateCallback = callbacks[ProgressCallback.update]
        if not updateCallback then
            return
        end
        progressRect.event = scheduleEvent(function()
            if progressRect and not progressRect:isDestroyed() and progressRect.callback then
                updateCallback()
            end
        end, 100)
    else
        local finishCallback = callbacks[ProgressCallback.finish]
        if finishCallback then
            finishCallback()
        end
    end
end

function isGroupCooldownIconActive(groupId)
    if hasTierUpgradeFeature() then
        local current = groupCooldown[groupId]
        return type(current) == 'number' and g_clock.millis() < current
    else
        return groupCooldown[groupId] == true
    end
end

function isCooldownIconActive(iconId)
    if hasTierUpgradeFeature() then
        local current = cooldown[iconId]
        return type(current) == 'number' and g_clock.millis() < current
    else
        return cooldown[iconId] == true
    end
end

function onSpellCooldown(iconId, duration)
    if not cooldownWindow:isVisible() then
        return
    end
    local container, spellName = loadIcon(iconId)
    if not container then
        print('[WARNING] Can not load cooldown icon on spell with id: ' .. iconId)
        return
    end
    container:setParent(cooldownPanel)

    local progressRect = container:getChildById('progressRect')
    if not progressRect then
        progressRect = g_ui.createWidget('SpellProgressRect', container)
        progressRect:setId('progressRect')
        progressRect:fill('parent')
    end
    progressRect.icon = container
    progressRect:setPercent(0)

    local updateFunc = function()
        updateCooldown(progressRect, duration)
    end
    local finishFunc = function()
        removeCooldown(progressRect)
        cooldown[iconId] = nil
    end
    initCooldown(progressRect, updateFunc, finishFunc)
    if hasTierUpgradeFeature() then
        cooldown[iconId] = g_clock.millis() + duration
    else
        cooldown[iconId] = true
    end
end

function onSpellGroupCooldown(groupId, duration)
    if not cooldownWindow:isVisible() then
        return
    end
    if not SpellGroups[groupId] then
        return
    end

    local container = contentsPanel:getChildById('container' .. SpellGroups[groupId])
    if not container then
        return
    end

    local icon = container:getChildById('icon')
    local progressRect = container:getChildById('progressRect')
    if icon then
        icon:setOn(true)
        removeEvent(icon.event)
    end

    if progressRect then
        progressRect.icon = icon
        removeEvent(progressRect.event)
        local updateFunc = function()
            updateCooldown(progressRect, duration)
        end
        local finishFunc = function()
            turnOffCooldown(progressRect)
            groupCooldown[groupId] = nil
        end
        initCooldown(progressRect, updateFunc, finishFunc)
        if hasTierUpgradeFeature() then
            groupCooldown[groupId] = g_clock.millis() + duration
        else
            groupCooldown[groupId] = true
        end
    end
end

function setSpellGroupCooldownsVisible(visible)
    if visible then
        cooldownWindow:setHeight(26)
        cooldownWindow:show()
    else
        cooldownWindow:hide()
        cooldownWindow:setHeight(10)
    end
end
