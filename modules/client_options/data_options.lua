return {
    vsync                             = {
        value = true,
        action = function(value, options, controller, panels, extraWidgets)
            g_window.setVerticalSync(value)
        end
    },
    showFps                           = {
        value = false,
        action = function(value, options, controller, panels, extraWidgets)
            modules.client_topmenu.setFpsVisible(value)
        end
    },
    showPing                          = {
        value = false,
        action = function(value, options, controller, panels, extraWidgets)
            modules.client_topmenu.setPingVisible(value)
        end
    },
    fullscreen                        = {
        value = false,
        action = function(value, options, controller, panels, extraWidgets)
            g_window.setFullscreen(value)
        end
    },
    classicControl                    = {
        value = g_platform.isMobile() and true or false,
        action = function(value, options, controller, panels, extraWidgets)
            -- Update the mouseControlMode based on this option
            -- 0 = Regular Controls, 1 = Classic Controls, 2 = Left Smart-Click
            local mouseControlMode = 0
            if value == true then
                mouseControlMode = 1 -- Classic Controls
            elseif options.smartLeftClick.value == true then
                mouseControlMode = 2 -- Left Smart-Click
            else
                mouseControlMode = 0 -- Regular Controls
            end
            
            -- Update the value in options table first
            options.mouseControlMode.value = mouseControlMode
            
            -- Then update settings
            g_settings.set('mouseControlMode', mouseControlMode)
            
            -- Update loot control visibility (only visible for Classic Controls)
            local lootControlModeCombobox = panels.generalPanel:recursiveGetChildById('lootControlMode')
            if lootControlModeCombobox then
                lootControlModeCombobox:setVisible(mouseControlMode == 1)
            end
            
            -- Update the combobox UI
            local mouseControlModeCombobox = panels.generalPanel:recursiveGetChildById('mouseControlMode')
            if mouseControlModeCombobox then
                mouseControlModeCombobox:setCurrentOption(mouseControlMode, true)
            end
        end
    },
    smartLeftClick                    = {
        value = false,
        action = function(value, options, controller, panels, extraWidgets)
            -- Update the mouseControlMode based on this option
            -- 0 = Regular Controls, 1 = Classic Controls, 2 = Left Smart-Click
            local mouseControlMode = 0
            if options.classicControl.value == true then
                mouseControlMode = 1 -- Classic Controls
            elseif value == true then
                mouseControlMode = 2 -- Left Smart-Click
            else
                mouseControlMode = 0 -- Regular Controls
            end
            
            -- Update the value in options table first
            options.mouseControlMode.value = mouseControlMode
            
            -- Then update settings
            g_settings.set('mouseControlMode', mouseControlMode)
            
            -- Update loot control visibility (only visible for Classic Controls)
            local lootControlModeCombobox = panels.generalPanel:recursiveGetChildById('lootControlMode')
            if lootControlModeCombobox then
                lootControlModeCombobox:setVisible(mouseControlMode == 1)
            end
            
            -- Update the combobox UI
            local mouseControlModeCombobox = panels.generalPanel:recursiveGetChildById('mouseControlMode')
            if mouseControlModeCombobox then
                mouseControlModeCombobox:setCurrentOption(mouseControlMode, true)
            end
        end
    },
    mouseControlMode                  = {
        value = 0, -- Default to "Regular Controls"
        action = function(value, options, controller, panels, extraWidgets)
            -- Update the underlying options values first
            -- 0 = Regular Controls, 1 = Classic Controls, 2 = Left Smart-Click
            if value == 0 then
                options.classicControl.value = false
                options.smartLeftClick.value = false
                g_settings.set('classicControl', false)
                g_settings.set('smartLeftClick', false)
            elseif value == 1 then
                options.classicControl.value = true
                options.smartLeftClick.value = false
                g_settings.set('classicControl', true)
                g_settings.set('smartLeftClick', false)
            elseif value == 2 then
                options.classicControl.value = false
                options.smartLeftClick.value = true
                g_settings.set('classicControl', false)
                g_settings.set('smartLeftClick', true)
            end
            
            -- Schedule UI updates to ensure they happen after value updates
            scheduleEvent(function()
                -- Update the mouseControlMode combobox
                local mouseControlModeCombobox = panels.generalPanel:recursiveGetChildById('mouseControlMode')
                if mouseControlModeCombobox then
                    -- Force the combobox to select the right option
                    for i = 0, 2 do
                        if i == value then
                            mouseControlModeCombobox:setCurrentOptionByData(i)
                            break
                        end
                    end
                end
                
                -- Update loot control mode visibility (only visible for Classic Controls)
                local lootControlModeCombobox = panels.generalPanel:recursiveGetChildById('lootControlMode')
                if lootControlModeCombobox then
                    lootControlModeCombobox:setVisible(value == 1)
                end
            end, 50)
        end
    },
    lootControlMode                   = {
        value = 0, -- Default to "Loot: Right"
        action = function(value, options, controller, panels, extraWidgets)
            -- We need a small delay to ensure the UI updates correctly
            scheduleEvent(function()
                -- Update the lootControlMode combobox - get it fresh each time
                local lootControlModeCombobox = panels.generalPanel:recursiveGetChildById('lootControlMode')
                if lootControlModeCombobox then
                    -- Force the combobox to select the right option
                    for i = 0, 2 do
                        if i == value then
                            lootControlModeCombobox:setCurrentOptionByData(i)
                            break
                        end
                    end
                end
            end, 50)
        end
    },
    returnDisablesChat                = false,
    smartWalk                         = false,
    autoChaseOverride                 = true,
    talkOnRightClick                  = false,
    moveStack                         = false,
    showStatusMessagesInConsole       = true,
    showEventMessagesInConsole        = true,
    showInfoMessagesInConsole         = true,
    showTimestampsInConsole           = true,
    showLevelsInConsole               = true,
    showPrivateMessagesInConsole      = true,
    showOthersStatusMessagesInConsole = false,
    showPrivateMessagesOnScreen       = true,
    showLootMessagesOnScreen          = true,
    showHighlightedUnderline          = {
        value = false,
        action = function(value, options, controller, panels, extraWidgets)
            local settings = g_settings.getNode('game_console') or {}
            settings.showHighlightedUnderline = value
            g_settings.setNode('game_console', settings)
            if modules and modules.game_console and modules.game_console.setShowHighlightedUnderline then
                modules.game_console.setShowHighlightedUnderline(value)
            end
        end
    },
    showOutfitsOnList                 = {
        value = true,
        action = function(value, options, controller, panels, extraWidgets)
            CharacterList.updateCharactersAppearances(value)
        end
    },
    openMaximized                     = false,
    backgroundFrameRate               = {
        value = 501,
        action = function(value, options, controller, panels, extraWidgets)
            local text, v = value, value
            if value <= 0 or value >= 501 then
                text = 'max'
                v = 0
            end

            panels.graphicsPanel:recursiveGetChildById('backgroundFrameRate'):setText(tr('Game framerate limit: %s', text))
            g_app.setMaxFps(v)
        end
    },
    enableAudio                       = {
        value = true,
        action = function(value, options, controller, panels, extraWidgets)
            if g_sounds then
                g_sounds.setAudioEnabled(value)
            end

            if value then
                extraWidgets.audioButton:setIcon('/images/topbuttons/button_mute_up')
            else
                extraWidgets.audioButton:setIcon('/images/topbuttons/button_mute_pressed')
            end
        end
    },
    enableMusicSound                  = {
        value = true,
        action = function(value, options, controller, panels, extraWidgets)
            if g_sounds then
                g_sounds.getChannel(SoundChannels.Music):setEnabled(value)
            end
        end
    },
    musicSoundVolume                  = {
        value = 100,
        action = function(value, options, controller, panels, extraWidgets)
            if g_sounds then
                g_sounds.getChannel(SoundChannels.Music):setGain(value / 100)
            end
            panels.soundPanel:recursiveGetChildById('musicSoundVolume'):setText(tr('Music volume: %d', value))
        end
    },
    enableLights                      = {
        value = true,
        action = function(value, options, controller, panels, extraWidgets)
            panels.gameMapPanel:setDrawLights(value and options.ambientLight.value < 100)
            panels.graphicsEffectsPanel:recursiveGetChildById('ambientLight'):setEnabled(value)
        end
    },
    limitVisibleDimension             = {
        value = false,
        action = function(value, options, controller, panels, extraWidgets)
            panels.gameMapPanel:setLimitVisibleDimension(value)
        end
    },
    floatingEffect                    = {
        value = false,
        action = function(value, options, controller, panels, extraWidgets)
            g_map.setFloatingEffect(value)
        end
    },
    ambientLight                      = {
        value = 0,
        action = function(value, options, controller, panels, extraWidgets)
            panels.graphicsEffectsPanel:recursiveGetChildById('ambientLight'):setText(string.format(
                'Ambient light: %s%%', value))
            panels.gameMapPanel:setMinimumAmbientLight(value / 100)
            panels.gameMapPanel:setDrawLights(options.enableLights.value)
        end
    },
    displayNames                      = {
        value = true,
        action = function(value, options, controller, panels, extraWidgets)
            panels.gameMapPanel:setDrawNames(value)

            if g_gameConfig.isDrawingInformationByWidget() then
                modules.game_creatureinformation.toggleInformation()
            end
        end
    },
    displayHealth                     = {
        value = true,
        action = function(value, options, controller, panels, extraWidgets)
            panels.gameMapPanel:setDrawHealthBars(value)

            if g_gameConfig.isDrawingInformationByWidget() then
                modules.game_creatureinformation.toggleInformation()
            end
        end
    },
    displayMana                       = {
        value = true,
        action = function(value, options, controller, panels, extraWidgets)
            panels.gameMapPanel:setDrawManaBar(value)

            if g_gameConfig.isDrawingInformationByWidget() then
                modules.game_creatureinformation.toggleInformation()
            end
        end
    },
    displayHarmony                     = {
        value = true,
        action = function(value, options, controller, panels, extraWidgets)
            panels.gameMapPanel:setDrawHarmony(value)
        end
    },
    displayText                       = {
        value = true,
        action = function(value, options, controller, panels, extraWidgets)
            g_app.setDrawTexts(value)
        end
    },
    walkTurnDelay                     = {
        value = 100,
        action = function(value, options, controller, panels, extraWidgets)
            panels.generalPanel:recursiveGetChildById('walkTurnDelay'):setText(string.format(
                'Walk delay after turn: %sms',
                value))
        end
    },
    walkTeleportDelay                 = {
        value = 50,
        action = function(value, options, controller, panels, extraWidgets)
            panels.generalPanel:recursiveGetChildById('walkTeleportDelay'):setText(string.format(
                'Walk delay after teleport: %sms',
                value))
        end
    },
    walkStairsDelay                   = {
        value = 50,
        action = function(value, options, controller, panels, extraWidgets)
            panels.generalPanel:recursiveGetChildById('walkStairsDelay'):setText(string.format(
                'Walk delay after floor change: %sms',
                value))
        end
    },
    hotkeyDelay                       = {
        value = 70,
        action = function(value, options, controller, panels, extraWidgets)
            panels.generalPanel:recursiveGetChildById('hotkeyDelay'):setText(string.format('Hotkey delay: %sms', value))
        end
    },
    crosshair                         = {
        value = 'default',
        action = function(value, options, controller, panels, extraWidgets)
            local crossPath = '/images/game/crosshair/'
            local newValue = value
            if newValue == 'disabled' then
                newValue = nil
            end

            panels.gameMapPanel:setCrosshairTexture(newValue and crossPath .. newValue or nil)
            panels.interface:recursiveGetChildById('crosshair'):setCurrentOptionByData(newValue, true)
        end
    },
    enableHighlightMouseTarget        = {
        value = true,
        action = function(value, options, controller, panels, extraWidgets)
            panels.gameMapPanel:setDrawHighlightTarget(value)
        end
    },
    showDragIcon        = {
        value = true,
    },
    antialiasingMode                  = {
        value = 1,
        action = function(value, options, controller, panels, extraWidgets)
            panels.gameMapPanel:setAntiAliasingMode(value)
            panels.graphicsPanel:recursiveGetChildById('antialiasingMode'):setCurrentOptionByData(value, true)
        end
    },
    shadowFloorIntensity              = {
        value = 30,
        action = function(value, options, controller, panels, extraWidgets)
            panels.graphicsEffectsPanel:recursiveGetChildById('shadowFloorIntensity'):setText(string.format(
                'Shadow floor Intensity: %s%%', value))
            panels.gameMapPanel:setShadowFloorIntensity(1 - (value / 100))
        end
    },
    optimizeFps                       = {
        value = true,
        action = function(value, options, controller, panels, extraWidgets)
            g_app.optimize(value)
        end
    },
    forceEffectOptimization           = {
        value = false,
        action = function(value, options, controller, panels, extraWidgets)
            g_app.forceEffectOptimization(value)
        end
    },
    drawEffectOnTop                   = {
        value = false,
        action = function(value, options, controller, panels, extraWidgets)
            g_app.setDrawEffectOnTop(value)
        end
    },
    floorViewMode                     = {
        value = 1,
        action = function(value, options, controller, panels, extraWidgets)
            panels.gameMapPanel:setFloorViewMode(value)
            panels.graphicsEffectsPanel:recursiveGetChildById('floorViewMode'):setCurrentOptionByData(value, true)

            local fadeMode = value == 1
            panels.graphicsEffectsPanel:recursiveGetChildById('floorFading'):setEnabled(fadeMode)
        end
    },
    floorFading                       = {
        value = 500,
        action = function(value, options, controller, panels, extraWidgets)
            panels.graphicsEffectsPanel:recursiveGetChildById('floorFading'):setText(string.format('Floor Fading: %s ms',
                value))
            panels.gameMapPanel:setFloorFading(tonumber(value))
        end
    },
    asyncTxtLoading                   = {
        value = false,
        action = function(value, options, controller, panels, extraWidgets)
            if g_game.isUsingProtobuf() then
                value = true
            elseif g_app.isEncrypted() then
                local asyncWidget = panels.graphicsPanel:recursiveGetChildById('asyncTxtLoading')
                asyncWidget:setEnabled(false)
                asyncWidget:setChecked(false)
                return
            end

            g_app.setLoadingAsyncTexture(value)
        end
    },
    hudScale                          = {
        event = nil,
        value = g_platform.isMobile() and 2 or 0,
        action = function(value, options, controller, panels, extraWidgets)
            value = value / 2

            if options.hudScale.event ~= nil then
                removeEvent(options.hudScale.event)
            end

            options.hudScale.event = scheduleEvent(function()
                g_app.setHUDScale(math.max(value + 0.5, 1))
                options.hudScale.event = nil
            end, 250)

            local hudWidget = panels.interfaceHUD:recursiveGetChildById('hudScale')
            hudWidget:setText(string.format('HUD Scale: %sx', math.max(value + 0.5, 1)))
        end
    },
    creatureInformationScale          = {
        value = g_platform.isMobile() and 2 or 0,
        action = function(value, options, controller, panels, extraWidgets)
            if value == 0 then
                value = g_window.getDisplayDensity() - 0.5
            else
                value = value / 2
            end
            g_app.setCreatureInformationScale(math.max(value + 0.5, 1))
            panels.interfaceHUD:recursiveGetChildById('creatureInformationScale'):setText(string.format(
                'Creature Information Scale: %sx', math.max(value + 0.5, 1)))
        end
    },
    staticTextScale                   = {
        value = g_platform.isMobile() and 2 or 0,
        action = function(value, options, controller, panels, extraWidgets)
            if value == 0 then
                value = g_window.getDisplayDensity() - 0.5
            else
                value = value / 2
            end
            g_app.setStaticTextScale(math.max(value + 0.5, 1))
            panels.interfaceHUD:recursiveGetChildById('staticTextScale'):setText(string.format('Message Scale: %sx',
                math.max(value + 0.5, 1)))
        end
    },
    animatedTextScale                 = {
        value = g_platform.isMobile() and 2 or 0,
        action = function(value, options, controller, panels, extraWidgets)
            if value == 0 then
                value = g_window.getDisplayDensity() - 0.5
            else
                value = value / 2
            end
            g_app.setAnimatedTextScale(math.max(value + 0.5, 1))
            panels.interfaceHUD:recursiveGetChildById('animatedTextScale'):setText(
                tr('Animated Message Scale: %sx', math.max(value + 0.5, 1)))
        end
    },
    showLeftExtraPanel                = {
        value = false,
        action = function(value, options, controller, panels, extraWidgets)
            modules.game_interface.getLeftExtraPanel():setOn(value)
            -- Update action bars when left extra panel visibility changes
            if modules.game_actionbar and modules.game_actionbar.updateVisibleWidgetsExternal then
                addEvent(function()
                    modules.game_actionbar.updateVisibleWidgetsExternal()
                end)
            end
        end
    },
    showLeftPanel                     = {
        value = true,
        action = function(value, options, controller, panels, extraWidgets)
            modules.game_interface.getLeftPanel():setOn(value)
            -- Update action bars when left panel visibility changes
            if modules.game_actionbar and modules.game_actionbar.updateVisibleWidgetsExternal then
                addEvent(function()
                    modules.game_actionbar.updateVisibleWidgetsExternal()
                end)
            end
        end
    },
    showRightExtraPanel               = {
        value = false,
        action = function(value, options, controller, panels, extraWidgets)
            modules.game_interface.getRightExtraPanel():setOn(value)
            -- Update action bars when right extra panel visibility changes
            if modules.game_actionbar and modules.game_actionbar.updateVisibleWidgetsExternal then
                addEvent(function()
                    modules.game_actionbar.updateVisibleWidgetsExternal()
                end)
            end
        end
    },
    showSpellGroupCooldowns           = {
        value = true,
        action = function(value, options, controller, panels, extraWidgets)
            modules.game_cooldown.setSpellGroupCooldownsVisible(value)
        end
    },
    dontStretchShrink                 = {
        value = false,
        action = function(value, options, controller, panels, extraWidgets)
            addEvent(function()
                modules.game_interface.updateStretchShrink()
            end)
        end
    },
    setEffectAlphaScroll              = {
        value = 100,
        action = function(value, options, controller, panels, extraWidgets)
            g_client.setEffectAlpha(value / 100)
            panels.graphicsEffectsPanel:recursiveGetChildById('setEffectAlphaScroll'):setText(tr('Opacity Effect: %s%%',
                value))
        end
    },
    setMissileAlphaScroll             = {
        value = 100,
        action = function(value, options, controller, panels, extraWidgets)
            g_client.setMissileAlpha(value / 100)
            panels.graphicsEffectsPanel:recursiveGetChildById('setMissileAlphaScroll'):setText(tr(
                'Opacity Missile: %s%%', value))
        end
    },
    distFromCenScrollbar              = {
        value = 0,
        action = function(value, options, controller, panels, extraWidgets)
            local bar = modules.game_healthcircle.optionPanel:recursiveGetChildById('distFromCenScrollbar')
            bar:setText(tr('Distance: %s', bar:recursiveGetChildById('valueBar'):getValue()))
            modules.game_healthcircle.setDistanceFromCenter(bar:recursiveGetChildById('valueBar'):getValue())
        end
    },
    opacityScrollbar                  = {
        value = 0,
        action = function(value, options, controller, panels, extraWidgets)
            local bar = modules.game_healthcircle.optionPanel:recursiveGetChildById('opacityScrollbar')
            bar:setText(tr('Opacity: %s', bar:recursiveGetChildById('valueBar'):getValue() / 100))
            modules.game_healthcircle.setCircleOpacity(bar:recursiveGetChildById('valueBar'):getValue() / 100)
        end
    },
    profile                           = {
        value = 1,
    },
    rightJoystick                     = {
        value = false,
        action = function(value, options, controller, panels, extraWidgets)
            if not g_platform.isMobile() then return end
            if value == true then
                modules.game_shortcuts.getPanel():breakAnchors()
                modules.game_shortcuts.getPanel():addAnchor(AnchorBottom, "parent", AnchorBottom)
                modules.game_shortcuts.getPanel():addAnchor(AnchorLeft, "parent", AnchorLeft)

                modules.game_joystick.getPanel():breakAnchors()
                modules.game_joystick.getPanel():addAnchor(AnchorBottom, "parent", AnchorBottom)
                modules.game_joystick.getPanel():addAnchor(AnchorRight, "parent", AnchorRight)
            else
                modules.game_joystick.getPanel():breakAnchors()
                modules.game_joystick.getPanel():addAnchor(AnchorBottom, "parent", AnchorBottom)
                modules.game_joystick.getPanel():addAnchor(AnchorLeft, "parent", AnchorLeft)

                modules.game_shortcuts.getPanel():breakAnchors()
                modules.game_shortcuts.getPanel():addAnchor(AnchorBottom, "parent", AnchorBottom)
                modules.game_shortcuts.getPanel():addAnchor(AnchorRight, "parent", AnchorRight)
            end
        end
    },
    showExpiryInInvetory              = {
        value = true,
        event = nil,
        action = function(value, options, controller, panels, extraWidgets)
            if options.showExpiryInContainers.event ~= nil then
                removeEvent(options.showExpiryInInvetory.event)
            end
            options.showExpiryInInvetory.event = scheduleEvent(function()
                modules.game_inventory.reloadInventory()
                options.showExpiryInInvetory.event = nil
            end, 100)
        end
    },
    showExpiryInContainers            = {
        value = true,
        event = nil,
        action = function(value, options, controller, panels, extraWidgets)
            if options.showExpiryInContainers.event ~= nil then
                removeEvent(options.showExpiryInContainers.event)
            end
            options.showExpiryInContainers.event = scheduleEvent(function()
                modules.game_containers.reloadContainers()
                options.showExpiryInContainers.event = nil
            end, 100)
        end
    },
    showExpiryOnUnusedItems           = true,
    framesRarity                      = {
        value = 'frames',
        event = nil,
        action = function(value, options, controller, panels, extraWidgets)
            local newValue = value
            if newValue == 'None' then
                newValue = nil
            end
            panels.interface:recursiveGetChildById('frames'):setCurrentOptionByData(newValue, true)
            if options.framesRarity.event ~= nil then
                removeEvent(options.framesRarity.event)
            end
            options.framesRarity.event = scheduleEvent(function()
                modules.game_containers.reloadContainers()
                options.framesRarity.event = nil
            end, 100)
        end
    },
    autoSwitchPreset                  = false,
    listKeybindsPanel                 = {
        action = function(value, options, controller, panels, extraWidgets)
            listKeybindsComboBox(value)
        end
    },
    graphicalCooldown = {
        value = true,
        action = function(value)
            modules.game_actionbar.toggleCooldownOption()
        end,
    },
    cooldownSecond = {
        value = true,
        action = function(value)
            modules.game_actionbar.toggleCooldownOption()
        end,
    },
    actionBarShowBottom1 = {
        value = true,
        action = function(value)
            local allBox = modules.client_options.getOption("allActionBar13") or false
            modules.game_actionbar.configureActionBar('actionBarShowBottom1', allBox and value)
        end,
    },
    actionBarShowBottom2 = {
        value = false,
        action = function(value)
            local allBox = modules.client_options.getOption("allActionBar13") or false
            modules.game_actionbar.configureActionBar('actionBarShowBottom2', allBox and value)
        end,
    },
    actionBarShowBottom3 = {
        value = false,
        action = function(value)
            local allBox = modules.client_options.getOption("allActionBar13") or false
            modules.game_actionbar.configureActionBar('actionBarShowBottom3', allBox and value)
        end,
    },
    actionBarShowLeft1 = {
        value = false,
        action = function(value)
            local allBox = modules.client_options.getOption("allActionBar46") or false
            modules.game_actionbar.configureActionBar('actionBarShowLeft1', allBox and value)
        end,
    },
    actionBarShowLeft2 = {
        value = false,
        action = function(value)
            local allBox = modules.client_options.getOption("allActionBar46") or false
            modules.game_actionbar.configureActionBar('actionBarShowLeft2', allBox and value)
        end,
    },
    actionBarShowLeft3 = {
        value = false,
        action = function(value)
            local allBox = modules.client_options.getOption("allActionBar46") or false
            modules.game_actionbar.configureActionBar('actionBarShowLeft3', allBox and value)
        end,
    },
    actionBarShowRight1 = {
        value = false,
        action = function(value)
            local allBox = modules.client_options.getOption("allActionBar79") or false
            modules.game_actionbar.configureActionBar('actionBarShowRight1', allBox and value)
            return true
        end,
    },
    actionBarShowRight2 = {
        value = false,
        action = function(value)
            local allBox = modules.client_options.getOption("allActionBar79") or false
            modules.game_actionbar.configureActionBar('actionBarShowRight2', allBox and value)
        end,
    },
    actionBarShowRight3 = {
        value = false,
        action = function(value)
            local allBox = modules.client_options.getOption("allActionBar79") or false
            modules.game_actionbar.configureActionBar('actionBarShowRight3', allBox and value)
        end,
    },
    allActionBar46 = {
        value = false,
        action = function(value)
            local huds = {"actionBarShowLeft1", "actionBarShowLeft2", "actionBarShowLeft3"}
            for _, actionBar in pairs(huds) do
                local hud =  panels.actionbars:recursiveGetChildById(actionBar)
                if value then
                    hud:enable()
                else
                    hud:disable()
                end
                modules.game_actionbar.configureActionBar(actionBar, (value and hud:isChecked()))
            end
        end,
    },
    allActionBar13 = {
        value = true,
        action = function(value)
            local huds = {"actionBarShowBottom1", "actionBarShowBottom2", "actionBarShowBottom3"}
            for _, actionBar in pairs(huds) do
                local hud =  panels.actionbars:recursiveGetChildById(actionBar)
                if value then
                    hud:enable()
                else
                    hud:disable()
                end
                modules.game_actionbar.configureActionBar(actionBar, (value and hud:isChecked()))
            end
        end,
    },
    allActionBar79 = {
        value = false,
        action = function(value)
            local huds = {"actionBarShowRight1", "actionBarShowRight2", "actionBarShowRight3"}
            for _, actionBar in pairs(huds) do
                local hud = panels.actionbars:recursiveGetChildById(actionBar)
                if value then
                    hud:enable()
                else
                    hud:disable()
                end
                modules.game_actionbar.configureActionBar(actionBar, (value and hud:isChecked()))
            end
        end,
    },
    actionTooltip = {
        value = true,
        action = function(value)
            modules.game_actionbar.updateVisibleOptions('tooltip', value)
        end,
    },
    showSpellParameters = {
        value = true,
        action = function(value)
            modules.game_actionbar.updateVisibleOptions('parameter', value)
        end,
    },
    showHKObjectsBars = {
        value = true,
        action = function(value)
            modules.game_actionbar.updateVisibleOptions('amount', value)
        end,
    },
    showAssignedHKButton = {
        value = true,
        action = function(value)
            modules.game_actionbar.updateVisibleOptions('hotkey', value)
        end,
    },
    actionBarBottomLocked = false,
    actionBarLeftLocked = false,
    actionBarRightLocked = false ,
        setOwnSpellEffectAlphaScroll                       = {
        value = 100,
        action = function(value, options, controller, panels, extraWidgets)
            panels.graphicsEffectsPanel:recursiveGetChildById('setOwnSpellEffectAlphaScroll'):setText(string.format('Own Spells Effect: %s %%',
                value))
            g_client.setOwnSpellEffectAlpha(value / 100)
        end
    },
    setOtherPlayerSpellEffectAlphaScroll                       = {
        value = 100,
        action = function(value, options, controller, panels, extraWidgets)
            panels.graphicsEffectsPanel:recursiveGetChildById('setOtherPlayerSpellEffectAlphaScroll'):setText(string.format('Other Player Spells Effect: %s %%',
                value))
           g_client.setOtherPlayerSpellEffectAlpha(value / 100)
        end
    },
        setCreatureSpellEffectAlphaScroll                       = {
        value = 100,
        action = function(value, options, controller, panels, extraWidgets)
            panels.graphicsEffectsPanel:recursiveGetChildById('setCreatureSpellEffectAlphaScroll'):setText(string.format('Creature Spells Effect: %s %%',
                value))
            g_client.setCreatureSpellEffectAlpha(value / 100)
        end
    },
        setBossAreaCreatureEffectAlphaScroll                       = {
        value = 100,
        action = function(value, options, controller, panels, extraWidgets)
            panels.graphicsEffectsPanel:recursiveGetChildById('setBossAreaCreatureEffectAlphaScroll'):setText(string.format('Boss Area Creature Effect: %s %%',
                value))
           g_client.setBossAreaCreatureEffectAlpha(value / 100)
        end
    },   
    showInfoBanner                     = true,
}
