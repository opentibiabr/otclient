skillsWindow = nil
skillsButton = nil
skillsSettings = nil
local ExpRating = {}
local smallSkillsCache = {}

-- Cache for stats data when UI elements are hidden
local statsCache = {
    flatDamageHealing = 0,
    attackValue = 0,
    attackElement = 0,
    convertedDamage = 0,
    convertedElement = 0,
    lifeLeech = 0,
    manaLeech = 0,
    critChance = 0,
    critDamage = 0,
    onslaught = 0,
    defense = 0,
    armor = 0,
    mitigation = 0,
    dodge = 0,
    damageReflection = 0,
    combatAbsorbValues = {
        [0] = 0, -- physicalResist
        [1] = 0, -- fireResist
        [2] = 0, -- earthResist
        [3] = 0, -- energyResist
        [4] = 0, -- IceResist
        [5] = 0, -- HolyResist
        [6] = 0, -- deathResist
        [7] = 0, -- HealingResist
        [8] = 0, -- drowResist
        [9] = 0, -- lifedrainResist
        [10] = 0 -- manadRainResist
    },
    momentum = 0,
    transcendence = 0,
    amplification = 0
}

local function setupUIButtons()
    local toggleFilterButton = skillsWindow:recursiveGetChildById('toggleFilterButton')
    if toggleFilterButton then
        toggleFilterButton:setVisible(false)
        toggleFilterButton:setOn(false)
    end
    
    local contextMenuButton = skillsWindow:recursiveGetChildById('contextMenuButton')
    local minimizeButton = skillsWindow:recursiveGetChildById('minimizeButton')
    if contextMenuButton and minimizeButton then
        contextMenuButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
        contextMenuButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
        contextMenuButton:setMarginRight(7)
        contextMenuButton.onClick = function(widget, mousePos, mouseButton)
            return showSkillsContextMenu(widget, mousePos, mouseButton)
        end
    end
    
    local newWindowButton = skillsWindow:recursiveGetChildById('newWindowButton')
    if newWindowButton then
        newWindowButton.onClick = function()
            if modules.game_cyclopedia then
                modules.game_cyclopedia.show("character")
            end
        end
    end
end

function init()
    connect(LocalPlayer, {
        onExperienceChange = onExperienceChange,
        onLevelChange = onLevelChange,
        onHealthChange = onHealthChange,
        onManaChange = onManaChange,
        onSoulChange = onSoulChange,
        onFreeCapacityChange = onFreeCapacityChange,
        onTotalCapacityChange = onTotalCapacityChange,
        onStaminaChange = onStaminaChange,
        onOfflineTrainingChange = onOfflineTrainingChange,
        onRegenerationChange = onRegenerationChange,
        onSpeedChange = onSpeedChange,
        onBaseSpeedChange = onBaseSpeedChange,
        onMagicLevelChange = onMagicLevelChange,
        onBaseMagicLevelChange = onBaseMagicLevelChange,
        onSkillChange = onSkillChange,
        onBaseSkillChange = onBaseSkillChange,
        onFlatDamageHealingChange = onFlatDamageHealingChange,
        onAttackInfoChange = onAttackInfoChange,
        onConvertedDamageChange = onConvertedDamageChange,
        onImbuementsChange = onImbuementsChange,
        onDefenseInfoChange = onDefenseInfoChange,
        onCombatAbsorbValuesChange = onCombatAbsorbValuesChange,
        onForgeBonusesChange = onForgeBonusesChange,
        onExperienceRateChange = onExperienceRateChange
    })
    connect(g_game, {
        onGameStart = online,
        onGameEnd = offline
    })

    skillsButton = modules.game_mainpanel.addToggleButton('skillsButton', tr('Skills') .. ' (Alt+S)',
                                                                   '/images/options/button_skills', toggle, false, 1)
    skillsButton:setOn(true)
    skillsWindow = g_ui.loadUI('skills')
    skillsWindow:setContentMinimumHeight(80)

    Keybind.new("Windows", "Show/hide skills windows", "Alt+S", "")
    Keybind.bind("Windows", "Show/hide skills windows", {
      {
        type = KEY_DOWN,
        callback = toggle,
      }
    })

    skillSettings = g_settings.getNode('skills-hide')
    if not skillSettings then
        skillSettings = {}
    end

    setupUIButtons()
    skillsWindow:setup()
    if g_game.isOnline() then
        online()
        skillsWindow:setupOnStart()
    end
end

function terminate()
    disconnect(LocalPlayer, {
        onExperienceChange = onExperienceChange,
        onLevelChange = onLevelChange,
        onHealthChange = onHealthChange,
        onManaChange = onManaChange,
        onSoulChange = onSoulChange,
        onFreeCapacityChange = onFreeCapacityChange,
        onTotalCapacityChange = onTotalCapacityChange,
        onStaminaChange = onStaminaChange,
        onOfflineTrainingChange = onOfflineTrainingChange,
        onRegenerationChange = onRegenerationChange,
        onSpeedChange = onSpeedChange,
        onBaseSpeedChange = onBaseSpeedChange,
        onMagicLevelChange = onMagicLevelChange,
        onBaseMagicLevelChange = onBaseMagicLevelChange,
        onSkillChange = onSkillChange,
        onBaseSkillChange = onBaseSkillChange,
        onFlatDamageHealingChange = onFlatDamageHealingChange,
        onAttackInfoChange = onAttackInfoChange,
        onConvertedDamageChange = onConvertedDamageChange,
        onImbuementsChange = onImbuementsChange,
        onDefenseInfoChange = onDefenseInfoChange,
        onCombatAbsorbValuesChange = onCombatAbsorbValuesChange,
        onForgeBonusesChange = onForgeBonusesChange,
        onExperienceRateChange = onExperienceRateChange
    })
    disconnect(g_game, {
        onGameStart = online,
        onGameEnd = offline
    })

    Keybind.delete("Windows", "Show/hide skills windows")
    skillsWindow:destroy()
    skillsButton:destroy()

    skillsWindow = nil
    skillsButton = nil
end

local SKILL_GROUPS = {
    offence = {
        'damageHealing', 'attackValue', 'convertedDamage', 'convertedElement',
        'lifeLeech', 'manaLeech', 'criticalChance', 'criticalExtraDamage', 'onslaught'
    },
    defence = {
        'physicalResist', 'fireResist', 'earthResist', 'energyResist', 'IceResist', 
        'HolyResist', 'deathResist', 'HealingResist', 'drowResist', 'lifedrainResist', 
        'manadRainResist', 'defenceValue', 'armorValue', 'mitigation', 'dodge', 
        'damageReflection'
    },
    misc = {
        'momentum', 'transcendence', 'amplification'
    },
    individual = {
        'level', 'stamina', 'offlineTraining', 'magiclevel', 'skillId0', 'skillId1', 
        'skillId2', 'skillId3', 'skillId4', 'skillId5', 'skillId6'
    },
    GameAdditionalSkills = {
        'skillId7', 'skillId8', 'skillId9', 'skillId10', 'skillId11', 'skillId12'
    },
    GameForgeSkillStats = {
        'skillId13', 'skillId14', 'skillId15'
    },
    GameForgeSkillStats1332 = {
        'skillId16'
    }
}

local function setSkillGroupVisibility(groupName, visible)
    local skills = SKILL_GROUPS[groupName]
    if not skills then return end
    
    for _, skillId in pairs(skills) do
        local skill = skillsWindow:recursiveGetChildById(skillId)
        if skill then
            if visible then
                local valueWidget = skill:getChildById('value')
                local text = valueWidget and valueWidget:getText() or ""
                if g_game.getClientVersion() >= 1410 then
                    skill:setVisible(text ~= "" and text ~= "0" and text ~= "0%" and 
                        text ~= "+ 0%" and text ~= "0.0%" and text ~= "+ 0.0%")
                else
                    skill:setVisible(true)
                end
            else
                skill:setVisible(false)
            end
        end
    end
end

local function areStatsVisible(groupName)
    if g_game.getClientVersion() < 1412 and groupName ~= 'individual' then
        return false
    end
    
    local skills = SKILL_GROUPS[groupName]
    if not skills then 
        return false
    end
    
    for _, skillId in pairs(skills) do
        local skill = skillsWindow:recursiveGetChildById(skillId)
        if skill and skill:isVisible() then
            return true
        end
    end
    return false
end

local function refreshGroupData(groupName)
    -- When stats are made visible, apply cached data to the UI elements
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end
    
    scheduleEvent(function()
        if groupName == 'offence' then
            -- Apply cached offence data
            onFlatDamageHealingChange(player, statsCache.flatDamageHealing)
            onAttackInfoChange(player, statsCache.attackValue, statsCache.attackElement)
            onConvertedDamageChange(player, statsCache.convertedDamage, statsCache.convertedElement)
            onImbuementsChange(player, statsCache.lifeLeech, statsCache.manaLeech, statsCache.critChance, statsCache.critDamage, statsCache.onslaught)
        elseif groupName == 'defence' then
            -- Apply cached defence data
            onDefenseInfoChange(player, statsCache.defense, statsCache.armor, statsCache.mitigation, statsCache.dodge, statsCache.damageReflection)
            onCombatAbsorbValuesChange(player, statsCache.combatAbsorbValues)
        elseif groupName == 'misc' then
            -- Apply cached misc data
            onForgeBonusesChange(player, statsCache.momentum, statsCache.transcendence, statsCache.amplification)
        end
    end, 50)
end

local function toggleGroupVisibility(groupName)
    if g_game.getClientVersion() < 1412 and groupName ~= 'individual' then
        return
    end
    
    local shouldShow = not areStatsVisible(groupName)
    setSkillGroupVisibility(groupName, shouldShow)
    
    -- If we're showing stats, refresh the data
    if shouldShow then
        refreshGroupData(groupName)
    end
    
    local char = g_game.getCharacterName()
    if not skillSettings[char] then
        skillSettings[char] = {}
    end
    skillSettings[char][groupName .. 'Stats_visible'] = shouldShow
    g_settings.setNode('skills-hide', skillSettings)
end

local function hideOldClientStats()
    local features = {
        newAppearance = g_game.getFeature(GameEnterGameShowAppearance),
        charSkills = g_game.getFeature(GameCharacterSkillStats),
        additionalSkills = g_game.getFeature(GameAdditionalSkills),
        forgeSkills = g_game.getFeature(GameForgeSkillStats)
    }
    if features.newAppearance then
        skillsWindow:recursiveGetChildById('regenerationTime'):getChildByIndex(1):setText('Food')
        skillsWindow:recursiveGetChildById('experience'):getChildByIndex(1):setText('XP')
    end
    local version = g_game.getClientVersion()
    setSkillGroupVisibility('offence', features.charSkills)
    setSkillGroupVisibility('defence', features.charSkills)
    setSkillGroupVisibility('misc', features.charSkills)
    setSkillGroupVisibility('GameAdditionalSkills', features.additionalSkills)
    setSkillGroupVisibility('GameForgeSkillStats1332', features.forgeSkills and version >= 1332)
    setSkillGroupVisibility('GameForgeSkillStats', features.forgeSkills)
    -- For very old clients (before 1098) the skills list fits without a slider.
    -- Keep the scrollbar track visible but hide the draggable slider so it's not interactive.
    if version < 1098 then
        local scroll = skillsWindow:recursiveGetChildById('miniwindowScrollBar')
        if scroll then
            local slider = scroll:getChildById('sliderButton')
            if slider then
                slider:setVisible(false)
            end
        end
         -- Also hide the offence info separator for old clients
        local sep = skillsWindow:recursiveGetChildById('separadorOnOffenceInfoChange')
        if sep then
            sep:setVisible(false)
        end
    end
end

local function hideMenuOptionsForOldClients(menu)
    if not g_game.getFeature(GameOfflineTrainingTime) then
        local offlineTrainingOption = menu:getChildById('showOfflineTraining')
        if offlineTrainingOption then
            offlineTrainingOption:setVisible(false)
        end
    end
    
    if g_game.getClientVersion() < 1412 then
        local statsOptions = {'showOffenceStats', 'showDefenceStats', 'showMiscStats'}
        for _, optionId in pairs(statsOptions) do
            local option = menu:getChildById(optionId)
            if option then
                option:setVisible(false)
            end
        end
    end
end

function showSkillsContextMenu(widget, mousePos, mouseButton)
    local menu = g_ui.createWidget('SkillsListSubMenu')
    menu:setGameMenu(true)

    hideMenuOptionsForOldClients(menu)

    for _, choice in ipairs(menu:getChildren()) do
        local choiceId = choice:getId()
        if choiceId and choiceId ~= 'HorizontalSeparator' then
            if choiceId == 'resetExperienceCounter' then
                choice.onClick = function()
                    onSkillsMenuAction(choiceId)
                    menu:destroy()
                end
            else
                local currentState = getSkillVisibilityState(choiceId)
                choice:setChecked(currentState)
                choice.onCheckChange = function()
                    onSkillsMenuAction(choiceId)
                    menu:destroy()
                end
            end
        end
    end
    
    local buttonPos = widget:getPosition()
    local buttonSize = widget:getSize()
    local menuWidth = menu:getWidth()
    
    local buttonCenterX = buttonPos.x + buttonSize.width / 2
    local buttonCenterY = buttonPos.y + buttonSize.height / 2
    
    local menuX = buttonCenterX - menuWidth
    local menuY = buttonCenterY
    
    menu:display({x = menuX, y = menuY})
    return true
end

function onSkillsMenuAction(actionId)
    if actionId == 'resetExperienceCounter' then
        resetExperienceCounter()
    elseif actionId == 'showOffenceStats' then
        toggleGroupVisibility('offence')
    elseif actionId == 'showDefenceStats' then
        toggleGroupVisibility('defence')
    elseif actionId == 'showMiscStats' then
        toggleGroupVisibility('misc')
    elseif actionId == 'showAllSkillBars' then
        toggleAllSkillBars()
    else
        local skillMap = {
            showLevel = 'level',
            showStamina = 'stamina',
            showOfflineTraining = 'offlineTraining',
            showMagic = 'magiclevel',
            showFist = 'skillId0',
            showClub = 'skillId1',
            showSword = 'skillId2',
            showAxe = 'skillId3',
            showDistance = 'skillId4',
            showShielding = 'skillId5',
            showFishing = 'skillId6'
        }
        local skillId = skillMap[actionId]
        if skillId then
            toggleSkillProgressBar(skillId)
        end
    end
end

function getSkillVisibilityState(actionId)
    local skillMap = {
        showLevel = 'level',
        showStamina = 'stamina',
        showOfflineTraining = 'offlineTraining',
        showMagic = 'magiclevel',
        showFist = 'skillId0',
        showClub = 'skillId1',
        showSword = 'skillId2',
        showAxe = 'skillId3',
        showDistance = 'skillId4',
        showShielding = 'skillId5',
        showFishing = 'skillId6'
    }
    
    local groupMap = {
        showOffenceStats = 'offence',
        showDefenceStats = 'defence',
        showMiscStats = 'misc'
    }
    
    local skillId = skillMap[actionId]
    if skillId then
        return isSkillPercentBarVisible(skillId)
    end
    
    local groupName = groupMap[actionId]
    if groupName then
        return areStatsVisible(groupName)
    end
    
    if actionId == 'showAllSkillBars' then
        return areAllSkillBarsVisible()
    end
    
    return false
end

function isSkillVisible(skillId)
    local skill = skillsWindow:recursiveGetChildById(skillId)
    return skill and skill:isVisible()
end

function isSkillPercentBarVisible(skillId)
    local skill = skillsWindow:recursiveGetChildById(skillId)
    if skill then
        local percentBar = skill:getChildById('percent')
        return percentBar and percentBar:isVisible()
    end
    return false
end

function toggleSkillProgressBar(skillId)
    local skill = skillsWindow:recursiveGetChildById(skillId)
    if skill then
        local percentBar = skill:getChildById('percent')
        local skillIcon = skill:getChildById('icon')
        
        if percentBar then
            local isVisible = percentBar:isVisible()
            percentBar:setVisible(not isVisible)
            
            -- Also toggle skill icon if it exists
            if skillIcon then
                skillIcon:setVisible(not isVisible)
            end
            
            -- Adjust skill button height
            if not isVisible then
                skill:setHeight(21) -- Show progress bar
            else
                skill:setHeight(15) -- Hide progress bar
            end
            
            -- Save the setting
            local char = g_game.getCharacterName()
            if not skillSettings[char] then
                skillSettings[char] = {}
            end
            skillSettings[char][skillId] = isVisible and 1 or 0  -- 1 = hidden, 0 = visible
            g_settings.setNode('skills-hide', skillSettings)
        end
    end
end

function toggleSkillVisibility(skillId)
    local skill = skillsWindow:recursiveGetChildById(skillId)
    if skill then
        local percentBar = skill:getChildById('percent')
        local skillIcon = skill:getChildById('icon')
        
        if percentBar then
            local isVisible = percentBar:isVisible()
            percentBar:setVisible(not isVisible)
            
            -- Also toggle skill icon if it exists
            if skillIcon then
                skillIcon:setVisible(not isVisible)
            end
            
            -- Adjust skill button height
            if not isVisible then
                skill:setHeight(21) -- Show progress bar
            else
                skill:setHeight(15) -- Hide progress bar
            end
            
            -- Save the setting
            local char = g_game.getCharacterName()
            if not skillSettings[char] then
                skillSettings[char] = {}
            end
            skillSettings[char][skillId] = isVisible and 1 or 0  -- 1 = hidden, 0 = visible
            g_settings.setNode('skills-hide', skillSettings)
        end
    end
end

function resetExperienceCounter()
    local player = g_game.getLocalPlayer()
    if player then
        modules.game_textmessage.displayGameMessage('Experience counter has been reset.')
    end
end

function areOffenceStatsVisible()
    return areStatsVisible('offence')
end

function toggleOffenceStatsVisibility()
    toggleGroupVisibility('offence')
end

function areDefenceStatsVisible()
    return areStatsVisible('defence')
end

function toggleDefenceStatsVisibility()
    toggleGroupVisibility('defence')
end

function areMiscStatsVisible()
    return areStatsVisible('misc')
end

function toggleMiscStatsVisibility()
    toggleGroupVisibility('misc')
end

function areAllSkillBarsVisible()
    for _, skillId in pairs(SKILL_GROUPS.individual) do
        local skill = skillsWindow:recursiveGetChildById(skillId)
        if skill then
            local percentBar = skill:getChildById('percent')
            if percentBar and not percentBar:isVisible() then
                return false
            end
        end
    end
    return true
end

function toggleAllSkillBars()
    local shouldShow = not areAllSkillBarsVisible()
    
    for _, skillId in pairs(SKILL_GROUPS.individual) do
        local skill = skillsWindow:recursiveGetChildById(skillId)
        if skill then
            local percentBar = skill:getChildById('percent')
            local skillIcon = skill:getChildById('icon')
            
            if percentBar then
                percentBar:setVisible(shouldShow)
                
                if skillIcon then
                    skillIcon:setVisible(shouldShow)
                end
                
                skill:setHeight(shouldShow and 21 or 15)
                
                local char = g_game.getCharacterName()
                if not skillSettings[char] then
                    skillSettings[char] = {}
                end
                skillSettings[char][skillId] = shouldShow and 0 or 1
            end
        end
    end
    
    g_settings.setNode('skills-hide', skillSettings)
end

function expForLevel(level)
    return math.floor((50 * level * level * level) / 3 - 100 * level * level + (850 * level) / 3 - 200)
end

function expToAdvance(currentLevel, currentExp)
    return expForLevel(currentLevel + 1) - currentExp
end

function resetSkillColor(id)
    local skill = skillsWindow:recursiveGetChildById(id)
    local widget = skill:getChildById('value')
    widget:setColor('#bbbbbb')
end

function toggleSkill(id, state)
    local skill = skillsWindow:recursiveGetChildById(id)
    skill:setVisible(state)
end

function setSkillBase(id, value, baseValue)
    if baseValue <= 0 or value < 0 then
        return
    end
    local skill = skillsWindow:recursiveGetChildById(id)
    local widget = skill:getChildById('value')

    if value > baseValue then
        widget:setColor('#008b00') -- green
        skill:setTooltip(baseValue .. ' +' .. (value - baseValue))
    elseif value < baseValue then
        widget:setColor('#b22222') -- red
        skill:setTooltip(baseValue .. ' ' .. (value - baseValue))
    else
        widget:setColor('#bbbbbb') -- default
        skill:removeTooltip()
    end
end

function setSkillValue(id, value)
    local skill = skillsWindow:recursiveGetChildById(id)
    if not skill then
        return
    end
    local widget = skill:getChildById('value')
    local GameAdditionalSkills = isSkillInGroups(id, {'GameAdditionalSkills'})
    if GameAdditionalSkills then
        local usePercentage = g_game.getFeature(GameEnterGameShowAppearance)
        if usePercentage then
            local needsDecimals = (id == 'skillId10' or id == 'skillId12')
            local displayValue = needsDecimals and (value / 100) or value
            local text = needsDecimals
                and string.format("%.2f%%", displayValue)
                or (displayValue .. "%")
        
            widget:setText(text)
            local color = (displayValue > 0 and 'green')
                or (displayValue == 0 and '#C0C0C0')
                or 'red'
            widget:setColor(color)
        else
            widget:setText(((id == 'skillId8') and "+" or "") .. value .. "%")
        end
    else
        widget:setText(value)
        widget:setColor('#C0C0C0')
    end
end

function isSkillInGroups(skillId, groupNames)
    if smallSkillsCache[skillId] ~= nil then
        return smallSkillsCache[skillId]
    end
    for _, groupName in ipairs(groupNames) do
        local skills = SKILL_GROUPS[groupName]
        if skills then
            for _, id in ipairs(skills) do
                if id == skillId then
                    smallSkillsCache[skillId] = true
                    return true
                end
            end
        end
    end
    smallSkillsCache[skillId] = false
    return false
end

function setSkillColor(id, value)
    local skill = skillsWindow:recursiveGetChildById(id)
    if skill then
        local widget = skill:getChildById('value')
        widget:setColor(value)
    end
end

function setSkillTooltip(id, value)
    local skill = skillsWindow:recursiveGetChildById(id)
    if skill then
        if value then
            skill:setTooltip(value)
        else
            skill:removeTooltip()
        end
    end
end

function setSkillPercent(id, percent, tooltip, color)
    local skill = skillsWindow:recursiveGetChildById(id)
    if skill then
        local widget = skill:getChildById('percent')
        if widget then
            widget:setPercent(math.floor(percent))

            if tooltip then
                widget:setTooltip(tooltip)
            end

            if color then
                widget:setBackgroundColor(color)
            end
        end
    end
end

function checkAlert(id, value, maxValue, threshold, greaterThan)
    if greaterThan == nil then
        greaterThan = false
    end
    local alert = false

    -- maxValue can be set to false to check value and threshold
    -- used for regeneration checking
    if type(maxValue) == 'boolean' then
        if maxValue then
            return
        end

        if greaterThan then
            if value > threshold then
                alert = true
            end
        else
            if value < threshold then
                alert = true
            end
        end
    elseif type(maxValue) == 'number' then
        if maxValue < 0 then
            return
        end

        local percent = math.floor((value / maxValue) * 100)
        if greaterThan then
            if percent > threshold then
                alert = true
            end
        else
            if percent < threshold then
                alert = true
            end
        end
    end

    if alert then
        setSkillColor(id, '#b22222') -- red
    else
        resetSkillColor(id)
    end
end

function update()
    local offlineTraining = skillsWindow:recursiveGetChildById('offlineTraining')
    if not g_game.getFeature(GameOfflineTrainingTime) then
        offlineTraining:setVisible(false)
    else
        offlineTraining:show()
    end

    local regenerationTime = skillsWindow:recursiveGetChildById('regenerationTime')
    if not g_game.getFeature(GamePlayerRegenerationTime) then
        regenerationTime:setVisible(false)
    else
        regenerationTime:show()
    end
    local xpBoostButton = skillsWindow:recursiveGetChildById('xpBoostButton')
    local xpGainRate = skillsWindow:recursiveGetChildById('xpGainRate')
    if g_game.getFeature(GameExperienceBonus) then
        xpBoostButton:show()
        xpGainRate:show()
    else
        xpBoostButton:setVisible(false)
        xpGainRate:setVisible(false)
    end
end

function online()
    skillsWindow:setupOnStart()
    refresh()

    local newWindowButton = skillsWindow:recursiveGetChildById('newWindowButton')
    if g_game.getClientVersion() < 1310 and newWindowButton then
        newWindowButton:setVisible(false)
        local sepForge = skillsWindow:recursiveGetChildById('separadorOnForgeBonusesChange')
        if sepForge and sepForge:isVisible() then
            sepForge:setVisible(false)
        end
        local sepDefense = skillsWindow:recursiveGetChildById('separadorOnDefenseInfoChange')
        if sepDefense and sepDefense:isVisible() then
            sepDefense:setVisible(false)
        end

        local lockButton = skillsWindow:recursiveGetChildById('lockButton')
        local contextMenuButton = skillsWindow:recursiveGetChildById('contextMenuButton')
        
        if lockButton and contextMenuButton then
            lockButton:breakAnchors()
            lockButton:addAnchor(AnchorTop, contextMenuButton:getId(), AnchorTop)
            lockButton:addAnchor(AnchorRight, contextMenuButton:getId(), AnchorLeft)
            lockButton:setMarginRight(2)
            lockButton:setMarginTop(0)
        end
    end
    
    scheduleEvent(function() 
        loadSkillsVisibilitySettings() 
    end, 100)
    hideOldClientStats()
    updateHeight()
end

function refresh()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    if expSpeedEvent then
        expSpeedEvent:cancel()
        expSpeedEvent = nil
    end
    expSpeedEvent = cycleEvent(checkExpSpeed, 30 * 1000)

    onExperienceChange(player, player:getExperience())
    onLevelChange(player, player:getLevel(), player:getLevelPercent())
    onHealthChange(player, player:getHealth(), player:getMaxHealth())
    onManaChange(player, player:getMana(), player:getMaxMana())
    onSoulChange(player, player:getSoul())
    onFreeCapacityChange(player, player:getFreeCapacity())
    onStaminaChange(player, player:getStamina())
    onMagicLevelChange(player, player:getMagicLevel(), player:getMagicLevelPercent())
    onOfflineTrainingChange(player, player:getOfflineTrainingTime())
    onRegenerationChange(player, player:getRegenerationTime())
    onSpeedChange(player, player:getSpeed())

    for i = Skill.Fist, Skill.Transcendence do
        onSkillChange(player, i, player:getSkillLevel(i), player:getSkillLevelPercent(i))
    end
    update()
    updateHeight()
    if g_game.getClientVersion() >= 1410 then
        onFlatDamageHealingChange(player, statsCache.flatDamageHealing)
        onAttackInfoChange(player, statsCache.attackValue, statsCache.attackElement)
        onConvertedDamageChange(player, statsCache.convertedDamage, statsCache.convertedElement)
        onImbuementsChange(player, statsCache.lifeLeech, statsCache.manaLeech, statsCache.critChance, statsCache.critDamage, statsCache.onslaught)
        onDefenseInfoChange(player, statsCache.defense, statsCache.armor, statsCache.mitigation, statsCache.dodge, statsCache.damageReflection)
        onCombatAbsorbValuesChange(player, statsCache.combatAbsorbValues)
        onForgeBonusesChange(player, statsCache.momentum, statsCache.transcendence, statsCache.amplification)
    end
end

function loadSkillsVisibilitySettings()
    local char = g_game.getCharacterName()
    if not char or not skillSettings[char] then
        return
    end
    
    local settings = skillSettings[char]
    
    for _, skillId in pairs(SKILL_GROUPS.individual) do
        if settings[skillId] ~= nil then
            local skill = skillsWindow:recursiveGetChildById(skillId)
            if skill then
                local percentBar = skill:getChildById('percent')
                local skillIcon = skill:getChildById('icon')
                
                if percentBar then
                    local shouldShow = settings[skillId] ~= 1
                    percentBar:setVisible(shouldShow)
                    
                    if skillIcon then
                        skillIcon:setVisible(shouldShow)
                    end
                    
                    skill:setHeight(shouldShow and 21 or 15)
                end
            end
        end
    end
    
    if g_game.getClientVersion() >= 1412 then
        local groupSettings = {
            {name = 'offence', key = 'offenceStats_visible'},
            {name = 'defence', key = 'defenceStats_visible'},
            {name = 'misc', key = 'miscStats_visible'}
        }
        
        for _, group in pairs(groupSettings) do
            if settings[group.key] == nil then
                settings[group.key] = true
                g_settings.setNode('skills-hide', skillSettings)
            end
            
            if settings[group.key] ~= nil then
                setSkillGroupVisibility(group.name, settings[group.key])
            end
        end
    end
end

function updateHeight()
    local maximumHeight = 8 -- margin top and bottom
    local minimumHeight = 80 -- ensure minimum height is maintained

    if g_game.isOnline() then
        local char = g_game.getCharacterName()

        if not skillSettings[char] then
            skillSettings[char] = {}
        end

        local skillsButtons = skillsWindow:recursiveGetChildById('experience'):getParent():getChildren()

        for _, skillButton in pairs(skillsButtons) do
            local percentBar = skillButton:getChildById('percent')

            if skillButton:isVisible() then
                if percentBar then
                    showPercentBar(skillButton, skillSettings[char][skillButton:getId()] ~= 1)
                end
                maximumHeight = maximumHeight + skillButton:getHeight() + skillButton:getMarginBottom()
            end
        end
    else
        maximumHeight = 390
    end

    local contentsPanel = skillsWindow:getChildById('contentsPanel')
    skillsWindow:setContentMinimumHeight(math.max(minimumHeight, 44))
    skillsWindow:setContentMaximumHeight(maximumHeight)
end

local function resetTable(t)
    for k, v in pairs(t) do
        if type(v) == "table" then
            resetTable(v)
        else
            t[k] = 0
        end
    end
end

function offline()
    skillsWindow:setParent(nil, true)
    if expSpeedEvent then
        expSpeedEvent:cancel()
        expSpeedEvent = nil
    end
    
    local allGroups = {'offence', 'defence', 'misc', 'GameAdditionalSkills', 'GameForgeSkillStats', 'GameForgeSkillStats1332'}
    for _, groupName in pairs(allGroups) do
        local skills = SKILL_GROUPS[groupName]
        if skills then
            for _, skillId in pairs(skills) do
                local skill = skillsWindow:recursiveGetChildById(skillId)
                if skill then
                    if not string.find(skillId, "separador") then
                        local valueWidget = skill:getChildById('value')
                        if valueWidget then
                            valueWidget:setText("0")
                        end
                        skill:setVisible(false)
                    end
                end
            end
        end
    end
    resetTable(statsCache)
    g_settings.setNode('skills-hide', skillSettings)
end

function toggle()
    if skillsButton:isOn() then
        skillsWindow:close()
        skillsButton:setOn(false)
    else
        if not skillsWindow:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(skillsWindow, skillsWindow:getMinimumHeight())
            if not panel then
                return
            end
            panel:addChild(skillsWindow)
        end
        skillsWindow:open()
        skillsButton:setOn(true)
        updateHeight()
    end
end

function checkExpSpeed()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    local currentExp = player:getExperience()
    local currentTime = g_clock.seconds()
    
    if player.lastExps == nil then
        player.lastExps = {}
    end
    
    table.insert(player.lastExps, {currentExp, currentTime})
    if #player.lastExps > 30 then
        table.remove(player.lastExps, 1)
    end
    
    if #player.lastExps >= 2 then
        local oldestEntry = player.lastExps[1]
        local expGained = currentExp - oldestEntry[1]
        local timeElapsed = currentTime - oldestEntry[2]
        
        player.expSpeed = timeElapsed > 0 and (expGained / timeElapsed) or 0
        
        onLevelChange(player, player:getLevel(), player:getLevelPercent())
        onExperienceChange(player, player:getExperience())
    end
end

function onMiniWindowOpen()
    skillsButton:setOn(true)
end

function onMiniWindowClose()
    skillsButton:setOn(false)
end

function onSkillButtonClick(button)
    local percentBar = button:getChildById('percent')
    local skillIcon = button:getChildById('icon')
    if percentBar and skillIcon then
        showPercentBar(button, not percentBar:isVisible())
        skillIcon:setVisible(skillIcon:isVisible())

        local char = g_game.getCharacterName()
        if percentBar:isVisible() then
            skillsWindow:modifyMaximumHeight(6)
            skillSettings[char][button:getId()] = 0
        else
            skillsWindow:modifyMaximumHeight(-6)
            skillSettings[char][button:getId()] = 1
        end
    end
end

function showPercentBar(button, show)
    local percentBar = button:getChildById('percent')
    local skillIcon = button:getChildById('icon')
    if percentBar and skillIcon then
        percentBar:setVisible(show)
        skillIcon:setVisible(show)
        if show then
            button:setHeight(21)
        else
            button:setHeight(21 - 6)
        end
    end
end

local function getExperienceTooltip(localPlayer)
    local currentLevel = localPlayer:getLevel()
    local currentExp = localPlayer:getExperience()
    local nextLevelExp = expForLevel(currentLevel + 1)
    local expNeeded = nextLevelExp - currentExp
    
    if expNeeded <= 0 then
        return nil
    end
    
    if localPlayer.expSpeed and localPlayer.expSpeed > 0 then
        local expPerHour = math.floor(localPlayer.expSpeed * 3600)
        local hoursLeft = expNeeded / expPerHour
        local minutesLeft = math.floor((hoursLeft - math.floor(hoursLeft)) * 60)
        hoursLeft = math.floor(hoursLeft)
        return tr('%s of experience per hour', comma_value(expPerHour)) .. '\n' ..
               tr('Next level in %d hours and %d minutes', hoursLeft, minutesLeft)
    end
    
    local states = localPlayer:getStates()
    local isInBattle = Player.isStateActive(states, PlayerStates.Swords) or Player.isStateActive(states, PlayerStates.RedSwords)
    
    if not isInBattle then
        return tr('%s XP for next level', comma_value(expNeeded))
    end
    
    return nil
end

function onExperienceChange(localPlayer, value)
    setSkillValue('experience', comma_value(value))
    setSkillTooltip('experience', getExperienceTooltip(localPlayer))
end

function onLevelChange(localPlayer, value, percent)
    setSkillValue('level', comma_value(value))
    local text = tr('You have %s percent to go', 100 - percent)

    setSkillPercent('level', percent, text)
end

function onHealthChange(localPlayer, health, maxHealth)
    setSkillValue('health', comma_value(health))
    checkAlert('health', health, maxHealth, 30)
end

function onManaChange(localPlayer, mana, maxMana)
    setSkillValue('mana', comma_value(mana))
    checkAlert('mana', mana, maxMana, 30)
end

function onSoulChange(localPlayer, soul)
    setSkillValue('soul', soul)
end

function onFreeCapacityChange(localPlayer, freeCapacity)
    setSkillValue('capacity', comma_value(freeCapacity))
    checkAlert('capacity', freeCapacity, localPlayer:getTotalCapacity(), 20)
end

function onTotalCapacityChange(localPlayer, totalCapacity)
    checkAlert('capacity', localPlayer:getFreeCapacity(), totalCapacity, 20)
end

local function formatTime(minutes)
    local hours = math.floor(minutes / 60)
    local mins = minutes % 60
    if mins < 10 then
        mins = '0' .. mins
    end
    return hours .. ':' .. mins
end

local function getStaminaTooltip(hours, minutes, stamina)
    local timeText = tr('You have %s hours and %s minutes left', hours, minutes)
    
    if stamina > 2400 and g_game.getClientVersion() >= 1038 then
        local player = g_game.getLocalPlayer()
        if player:isPremium() then
            return timeText .. '\n' .. tr('Now you will gain 50%% more experience')
        else
            return timeText .. '\n' .. tr('You will not gain 50%% more experience because you aren\'t premium player, now you receive only 1x experience points')
        end
    elseif stamina >= 2400 and g_game.getClientVersion() < 1038 then
        return timeText .. '\n' .. tr('If you are premium player, you will gain 50%% more experience')
    elseif stamina < 2400 and stamina > 840 then
        return timeText
    elseif stamina <= 840 and stamina > 0 then
        return timeText .. '\n' .. tr('You gain only 50%% experience and you don\'t may gain loot from monsters')
    elseif stamina == 0 then
        return timeText .. '\n' .. tr('You don\'t may receive experience and loot from monsters')
    end
    return timeText
end

function onStaminaChange(localPlayer, stamina)
    local hours = math.floor(stamina / 60)
    local minutes = stamina % 60
    local percent = math.floor(100 * stamina / (42 * 60))
    
    setSkillValue('stamina', formatTime(stamina))
    
    local tooltip = getStaminaTooltip(hours, minutes, stamina)
    local color = 'orange'
    
    if stamina > 2400 then
        color = g_game.getClientVersion() >= 1038 and localPlayer:isPremium() and 'green' or '#89F013'
    elseif stamina <= 840 and stamina > 0 then
        color = 'red'
    elseif stamina == 0 then
        color = 'black'
    end
    
    setSkillPercent('stamina', percent, tooltip, color)
end

function onOfflineTrainingChange(localPlayer, offlineTrainingTime)
    if not g_game.getFeature(GameOfflineTrainingTime) then
        return
    end
    local percent = 100 * offlineTrainingTime / (12 * 60)
    setSkillValue('offlineTraining', formatTime(offlineTrainingTime))
    setSkillPercent('offlineTraining', percent, tr('You have %s percent', percent))
end

function onRegenerationChange(localPlayer, regenerationTime)
    if not g_game.getFeature(GamePlayerRegenerationTime) or regenerationTime < 0 then
        return
    end
    local hours = math.floor(regenerationTime / 3600)
    local minutes = math.floor(regenerationTime / 60)
    local seconds = regenerationTime % 60
    if seconds < 10 then
        seconds = '0' .. seconds
    end
    if minutes < 10 then
        minutes = '0' .. minutes
    end
    if hours < 10 then
        hours = '0' .. hours
    end
    local fmt = ""
    local alert = 300
    if g_game.getFeature(GameEnterGameShowAppearance) then
        fmt = string.format("%02d:%02d:%02d", hours, minutes, seconds)
        alert = 0
    else
        fmt = string.format("%02d:%02d", minutes, seconds)
    end
    setSkillValue('regenerationTime', fmt)
    checkAlert('regenerationTime', regenerationTime, false, alert)
    if g_game.getFeature(GameEnterGameShowAppearance) then
        modules.game_interface.StatsBar.onHungryChange(regenerationTime, alert)
    end
end

function onSpeedChange(localPlayer, speed)
    setSkillValue('speed', comma_value(speed))

    onBaseSpeedChange(localPlayer, localPlayer:getBaseSpeed())
end

function onBaseSpeedChange(localPlayer, baseSpeed)
    setSkillBase('speed', localPlayer:getSpeed(), baseSpeed)
end

function onMagicLevelChange(localPlayer, magiclevel, percent)
    setSkillValue('magiclevel', magiclevel)
    setSkillPercent('magiclevel', percent, tr('You have %s percent to go', 100 - percent))

    onBaseMagicLevelChange(localPlayer, localPlayer:getBaseMagicLevel())
end

function onBaseMagicLevelChange(localPlayer, baseMagicLevel)
    setSkillBase('magiclevel', localPlayer:getMagicLevel(), baseMagicLevel)
end

function onSkillChange(localPlayer, id, level, percent)
    setSkillValue('skillId' .. id, level)
    setSkillPercent('skillId' .. id, percent, tr('You have %s percent to go', 100 - percent))

    onBaseSkillChange(localPlayer, id, localPlayer:getSkillBaseLevel(id))

    if id > Skill.ManaLeechAmount then
	    toggleSkill('skillId' .. id, level > 0)
    end
end

function onBaseSkillChange(localPlayer, id, baseLevel)
    setSkillBase('skillId' .. id, localPlayer:getSkillLevel(id), baseLevel)
end

local function updateExperienceRate(localPlayer)
    local baseRate = ExpRating[ExperienceRate.BASE] or 100
    local expRateTotal = baseRate

    for type, value in pairs(ExpRating) do
        if type ~= ExperienceRate.BASE and type ~= ExperienceRate.STAMINA_MULTIPLIER then
            expRateTotal = expRateTotal + (value or 0)
        end
    end

    local staminaMultiplier = ExpRating[ExperienceRate.STAMINA_MULTIPLIER] or 100
    expRateTotal = expRateTotal * staminaMultiplier / 100

    local xpgainrate = skillsWindow:recursiveGetChildById("xpGainRate")
    if not xpgainrate then
        return
    end

    local widget = xpgainrate:getChildById("value")
    if not widget then
        return
    end

    widget:setText(math.floor(expRateTotal) .. "%")

    local tooltip = string.format("Your current XP gain rate amounts to %d%%.", math.floor(expRateTotal))
    tooltip = tooltip .. string.format("\nYour XP gain rate is calculated as follows:\n- Base XP gain rate %d%%", baseRate)

    if (ExpRating[ExperienceRate.VOUCHER] or 0) > 0 then
        tooltip = tooltip .. string.format("\n- Voucher: %d%%", ExpRating[ExperienceRate.VOUCHER])
    end

    if (ExpRating[ExperienceRate.XP_BOOST] or 0) > 0 then
        tooltip = tooltip .. string.format("\n- XP Boost: %d%% (%s h remaining)", ExpRating[ExperienceRate.XP_BOOST],
            formatTimeBySeconds(localPlayer:getStoreExpBoostTime()))
    end

    if (ExpRating[ExperienceRate.LOW_LEVEL] or 0) > 0 then
        tooltip = tooltip .. string.format("\n- Low Level Bonus: %d%%", ExpRating[ExperienceRate.LOW_LEVEL])
    end

    tooltip = tooltip .. string.format("\n- Stamina multiplier: x%.1f (%s h remaining)", staminaMultiplier / 100,
        formatTimeByMinutes(localPlayer:getStamina() - 2340))

    xpgainrate:setTooltip(tooltip)

    local colors = {
        [0] = "#ff4a4a",
        ["greater"] = "#00cc00",
        ["less"] = "#ff9429",
        ["equal"] = "#ffffff"
    }
    
    local colorKey = expRateTotal == 0 and 0 or 
                     (expRateTotal > 100 and "greater" or 
                      (expRateTotal < 100 and "less" or "equal"))
    
    widget:setColor(colors[colorKey])
end

function onExperienceRateChange(localPlayer, type, value)
    ExpRating[type] = value
    updateExperienceRate(localPlayer)
end

local function setSkillValueWithTooltips(id, value, tooltip, showPercentage, color)
    local skill = skillsWindow:recursiveGetChildById(id)
    if not skill then
        return
    end
    
    if g_game.getClientVersion() < 1412 then
        local oldClientStats = {
            'skillId7', 'skillId8', 'skillId9', 'skillId10', 'skillId11', 'skillId12', 
            'skillId13', 'skillId14', 'skillId15', 'skillId16',
            'damageHealing', 'attackValue', 'convertedDamage', 'convertedElement',
            'criticalHit', 'lifeLeech', 'manaLeech', 'criticalChance', 'criticalExtraDamage', 'onslaught',
            'physicalResist', 'fireResist', 'earthResist', 'energyResist', 'IceResist', 
            'HolyResist', 'deathResist', 'HealingResist', 'drowResist', 'lifedrainResist', 
            'manadRainResist', 'defenceValue', 'armorValue', 'mitigation', 'dodge', 
            'damageReflection', 'momentum', 'transcendence', 'amplification'
        }
        
        for _, statId in pairs(oldClientStats) do
            if id == statId then
                skill:setVisible(false)
                return
            end
        end
    end
    
    if g_game.getClientVersion() >= 1412 then
        local char = g_game.getCharacterName()
        if char and skillSettings and skillSettings[char] then
            local settings = skillSettings[char]
            
            for groupName, groupStats in pairs({offence = SKILL_GROUPS.offence, defence = SKILL_GROUPS.defence, misc = SKILL_GROUPS.misc}) do
                for _, statId in pairs(groupStats) do
                    if id == statId and settings[groupName .. 'Stats_visible'] == false then
                        skill:setVisible(false)
                        return
                    end
                end
            end
        end
    end
    
    if value ~= nil then
        local shouldHide = false
        if value == 0 or (type(value) == "number" and math.abs(value) < 0.0001) then
            shouldHide = true
        elseif showPercentage then
            local percentValue = math.floor(value * 10000) / 100
            shouldHide = (percentValue == 0 or math.abs(percentValue) < 0.01)
        end
        if shouldHide then
            skill:setVisible(false)
            return
        end
        
        skill:show()
        local widget = skill:getChildById('value')
        if not widget then
            return
        end
        if color then
            widget:setColor(color)
        end
        if showPercentage then
            local percentValue = math.floor(value * 10000) / 100
            local sign = percentValue > 0 and "+ " or ""
            widget:setText(sign .. percentValue .. "%")
            if percentValue < 0 then
                widget:setColor("#FF9854")
            end
        else
            widget:setText(tostring(value))
        end
        if tooltip then
            skill:setTooltip(tooltip)
        end
    elseif string.find(id, "separador") then
        -- Separators should be shown when the group is visible, regardless of value
        skill:show()
    else
        skill:setVisible(false)
    end
end

function onFlatDamageHealingChange(localPlayer, flatBonus)
    -- Cache the data regardless of visibility
    statsCache.flatDamageHealing = flatBonus or 0
    
    local char = g_game.getCharacterName()
    if char and skillSettings and skillSettings[char] and skillSettings[char]['offenceStats_visible'] ~= false then
        skillsWindow:recursiveGetChildById("separadorOnOffenceInfoChange"):setVisible(true)
    end
    local tooltips = "This flat bonus is the main source of your character's power, added \nto most of the damage and healing values you cause."
    setSkillValueWithTooltips('damageHealing', flatBonus, tooltips, false)
end

function onAttackInfoChange(localPlayer, attackValue, attackElement)
    -- Cache the data regardless of visibility
    statsCache.attackValue = attackValue or 0
    statsCache.attackElement = attackElement or 0
    
    local char = g_game.getCharacterName()
    if char and skillSettings and skillSettings[char] and skillSettings[char]['offenceStats_visible'] ~= false then
        skillsWindow:recursiveGetChildById("separadorOnOffenceInfoChange"):setVisible(true)
    end
    local tooltips = "This is your character's basic attack power whenever you enter a \nfight with a weapon or your fists. It does not apply to any spells \nyou cast. The attack value is calculated from the weapon's attack\n value, the corresponding weapon skill, combat tactics, the bonus \nreceived from the Revelation Perks and the player's level. The \nvalue represents the average damage you would inflict on a\ncreature which had no kind of defence or protection."
    setSkillValueWithTooltips('attackValue', attackValue, tooltips, false)
    local skill = skillsWindow:recursiveGetChildById("attackValue")
    if skill then
        local element = clientCombat[attackElement]
        if element then
            skill:getChildById('icon'):setImageSource(element.path)
            skill:getChildById('icon'):setImageSize({width = 9, height = 9})
        end
    end
end

function onConvertedDamageChange(localPlayer, convertedDamage, convertedElement)
    -- Cache the data regardless of visibility
    statsCache.convertedDamage = convertedDamage or 0
    statsCache.convertedElement = convertedElement or 0
    
    setSkillValueWithTooltips('convertedDamage', convertedDamage, false, true)
    setSkillValueWithTooltips('convertedElement', convertedElement, false, true)
end

function onImbuementsChange(localPlayer, lifeLeech, manaLeech, critChance, critDamage, onslaught)
    -- Cache the data regardless of visibility
    statsCache.lifeLeech = lifeLeech or 0
    statsCache.manaLeech = manaLeech or 0
    statsCache.critChance = critChance or 0
    statsCache.critDamage = critDamage or 0
    statsCache.onslaught = onslaught or 0
    
    local char = g_game.getCharacterName()
    if char and skillSettings and skillSettings[char] and skillSettings[char]['offenceStats_visible'] ~= false then
        skillsWindow:recursiveGetChildById("separadorOnOffenceInfoChange"):setVisible(true)
    end
    
    local tooltips = {
        lifeLeech = "You have a +11.4% chance to trigger Onslaught, granting you 60% increased damage for all attacks.",
        manaLeech = "You have a +1% chance to cause +1% extra damage.",
        critChance = "Critical Hits deal more damage than normal attacks. They have a chance to be \ntriggered during combat, inflicting additional damage beyond the standard amount.",
        critDamage = "You get +1% of the damage dealt as mana",
        onslaught = "You get +1% of the damage dealt as hit points"
    }
    
    setSkillValueWithTooltips('lifeLeech', lifeLeech, tooltips.lifeLeech, true)
    setSkillValueWithTooltips('manaLeech', manaLeech, tooltips.manaLeech, true)
    setSkillValueWithTooltips('criticalChance', critChance, tooltips.critChance, true)
    setSkillValueWithTooltips('criticalExtraDamage', critDamage, tooltips.critDamage, true)
    setSkillValueWithTooltips('onslaught', onslaught, tooltips.onslaught, true)
    local criticalHitWidget = skillsWindow:recursiveGetChildById("criticalHit")
    if criticalHitWidget then
        local critChanceWidget = skillsWindow:recursiveGetChildById("criticalChance")
        local critDamageWidget = skillsWindow:recursiveGetChildById("criticalExtraDamage")
        local shouldShowCriticalHit = false
        if (critChanceWidget and critChanceWidget:isVisible()) or (critDamageWidget and critDamageWidget:isVisible()) then
            shouldShowCriticalHit = true
        end
        criticalHitWidget:setVisible(shouldShowCriticalHit)
    end
end

local combatIdToWidgetId = {
    [0] = "physicalResist",
    [1] = "fireResist",
    [2] = "earthResist",
    [3] = "energyResist",
    [4] = "IceResist",
    [5] = "HolyResist",
    [6] = "deathResist",
    [7] = "HealingResist",
    [8] = "drowResist",
    [9] = "lifedrainResist",
    [10] = "manadRainResist"
}

function onCombatAbsorbValuesChange(localPlayer, absorbValues)
    -- Cache the data regardless of visibility
    statsCache.combatAbsorbValues = absorbValues or {}
    
    for id, widgetId in pairs(combatIdToWidgetId) do
        local skill = skillsWindow:recursiveGetChildById(widgetId)
        if skill then
                local value = absorbValues[id]
                if value ~= nil then
                    setSkillValueWithTooltips(widgetId, value, false, true, "#44AD25")
                else
                    skill:setVisible(false)
                end
        end
    end
end

function onDefenseInfoChange(localPlayer, defense, armor, mitigation, dodge, damageReflection)
    -- Cache the data regardless of visibility
    statsCache.defense = defense or 0
    statsCache.armor = armor or 0
    statsCache.mitigation = mitigation or 0
    statsCache.dodge = dodge or 0
    statsCache.damageReflection = damageReflection or 0
    
    -- Show separator if defense stats are visible
    local char = g_game.getCharacterName()
    if char and skillSettings and skillSettings[char] and skillSettings[char]['defenceStats_visible'] ~= false then
        local separator = skillsWindow:recursiveGetChildById("separadorOnDefenseInfoChange")
        if separator then
            separator:setVisible(true)
        end
    end
    
    local tooltips = {
        defense = "When attacked, you have a +9.6% chance to trigger Dodge, which \nwill fully mitigate the damage.",
        armor = "Mitigation reduces most of the damage you take and varies based\non your shielding skill, equipped weapon, chosen combat tactics \nand any mitigation multipliers acquired in your Wheel of Destiny.",
        mitigation = "This shows how well your armor protects you from all physical\nattacks.",
        dodge = "This is your protection against all physical attacks in close combat \nas well as all distance physical attacks. The higher the defence value, the less damage you will take from melee physical hits. The defence\n value is calculated from your shield and/or weapon\n defence and the corresponding skill. Careful! \nYour defence value protects you only from hits of two creatures in a single round."
    }
    
    setSkillValueWithTooltips('defenceValue', defense, tooltips.defense, false)
    setSkillValueWithTooltips('armorValue', armor, tooltips.armor, false)
    setSkillValueWithTooltips('mitigation', mitigation, tooltips.mitigation, true)
    setSkillValueWithTooltips('dodge', dodge, tooltips.dodge, true)
    setSkillValueWithTooltips('damageReflection', damageReflection, false, true)
end

function onForgeBonusesChange(localPlayer, momentum, transcendence, amplification)
    -- Cache the data regardless of visibility
    statsCache.momentum = momentum or 0
    statsCache.transcendence = transcendence or 0
    statsCache.amplification = amplification or 0
    
    local char = g_game.getCharacterName()
    if char and skillSettings and skillSettings[char] and skillSettings[char]['miscStats_visible'] ~= false then
        skillsWindow:recursiveGetChildById("separadorOnForgeBonusesChange"):setVisible(true)
    end
    
    local tooltips = {
        momentum = "During combat, you have a +" .. math.floor(momentum * 10000) / 100 .. "% chance to trigger Momentum\n, which reduces all spell cooldowns by 2 seconds.",
        transcendence = "During combat, you have a +" .. math.floor(transcendence * 10000) / 100 .. "% chance to trigger\nTranscendence, which transforms your character into a vocation-\nspecific avatar for 7 seconds. While in this form, you will benefit\nfrom a 15% damage reduction and guaranteed critical hits that \ndeal an additional 15% damage.",
        amplification = "Effects of tiered items are amplified by +" .. math.floor(amplification * 10000) / 100 .. "%."
    }

    setSkillValueWithTooltips('momentum', momentum, tooltips.momentum, true)
    setSkillValueWithTooltips('transcendence', transcendence, tooltips.transcendence, true)
    setSkillValueWithTooltips('amplification', amplification, tooltips.amplification, true)
end

-- Function to get experience rate values for other modules
function getExpRating(type)
    if type then
        return ExpRating[type] or 0
    else
        return ExpRating
    end
end

-- Function to calculate the total experience rate multiplier (excluding base rate)
function getTotalExpRateMultiplier()
    local baseRate = ExpRating[ExperienceRate.BASE] or 100
    local expRateTotal = baseRate

    for type, value in pairs(ExpRating) do
        if type ~= ExperienceRate.BASE and type ~= ExperienceRate.STAMINA_MULTIPLIER then
            expRateTotal = expRateTotal + (value or 0)
        end
    end

    local staminaMultiplier = ExpRating[ExperienceRate.STAMINA_MULTIPLIER] or 100
    expRateTotal = expRateTotal * staminaMultiplier / 100

    return expRateTotal / 100  -- Return as a decimal multiplier
end

-- Function to get just the base experience rate
function getBaseExpRate()
    return ExpRating[ExperienceRate.BASE] or 100
end
