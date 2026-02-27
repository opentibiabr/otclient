Cyclopedia = {}

trackerButton = nil
trackerMiniWindow = nil
trackerButtonBosstiary = nil
trackerMiniWindowBosstiary = nil
contentContainer = nil

-- Track current character to detect character changes
local currentCharacter = nil

local buttonSelection = nil
local items = nil
local bestiary = nil
local charms = nil
local map = nil
local houses = nil
local character = nil
local CyclopediaButton = nil
local bosstiary = nil
local bossSlot = nil
local ButtonBossSlot = nil
local ButtonBestiary = nil
local tabStack = {}
local previousType = nil
local windowTypes = {}
local magicalArchives = nil
function toggle(defaultWindow)
    if not controllerCyclopedia.ui then
        return
    end
    if controllerCyclopedia.ui:isVisible() then
        return hide()
    end
    show(defaultWindow)
end

controllerCyclopedia = Controller:new()
controllerCyclopedia:setUI('game_cyclopedia')

function controllerCyclopedia:onInit()
end

function controllerCyclopedia:onGameStart()
    if g_game.getClientVersion() >= 1310 then
        CyclopediaButton = modules.game_mainpanel.addToggleButton('CyclopediaButton', tr('Cyclopedia'),
            '/images/options/cooldowns', function() toggle("items") end, false, 7)
        ButtonBossSlot = modules.game_mainpanel.addToggleButton("bossSlot", tr("Open Boss Slots dialog"),
            "/images/options/ButtonBossSlot", function() toggle("bossSlot") end, false, 20)
        CyclopediaButton:setOn(false)
        ButtonBestiary = modules.game_mainpanel.addToggleButton("bosstiary", tr("Open Bosstiary dialog"),
            "/images/options/ButtonBosstiary", function() toggle("bosstiary") end, false, 17)

        contentContainer = controllerCyclopedia.ui:recursiveGetChildById('contentContainer')
        buttonSelection = controllerCyclopedia.ui:recursiveGetChildById('buttonSelection')
        items = buttonSelection:recursiveGetChildById('items')
        bestiary = buttonSelection:recursiveGetChildById('bestiary')
        charms = buttonSelection:recursiveGetChildById('charms')
        map = buttonSelection:recursiveGetChildById('map')
        houses = buttonSelection:recursiveGetChildById('houses')
        character = buttonSelection:recursiveGetChildById('character')
        bosstiary = buttonSelection:recursiveGetChildById('bosstiary')
        bossSlot = buttonSelection:recursiveGetChildById('bossSlot')
        magicalArchives = buttonSelection:recursiveGetChildById('magicalArchives')

        windowTypes = {
            items = { obj = items, func = showItems },
            bestiary = { obj = bestiary, func = showBestiary },
            charms = { obj = charms, func = showCharms },
            map = { obj = map, func = showMap },
            houses = { obj = houses, func = showHouse },
            character = { obj = character, func = showCharacter },
            bosstiary = { obj = bosstiary, func = showBosstiary },
            bossSlot = { obj = bossSlot, func = showBossSlot },
            magicalArchives = { obj = magicalArchives, func = showMagicalArchives },
        }

        g_ui.importStyle("cyclopedia_widgets")
        g_ui.importStyle("cyclopedia_pages")

        controllerCyclopedia:registerEvents(g_game, {
            -- bestiary
            onParseBestiaryRaces = Cyclopedia.loadBestiaryCategories,
            onParseBestiaryOverview = Cyclopedia.loadBestiaryOverview,
            onUpdateBestiaryMonsterData = Cyclopedia.loadBestiarySelectedCreature,
            -- bosstiary // bestiary
            onParseCyclopediaTracker = Cyclopedia.onParseCyclopediaTracker,
            -- bosstiary
            onParseSendBosstiary = Cyclopedia.LoadBosstiaryCreatures,
            -- boss_slot
            onParseBosstiarySlots = Cyclopedia.loadBossSlots,
            -- character
            onParseCyclopediaCharacterGeneralStats = Cyclopedia.loadCharacterGeneralStats,
            onParseCyclopediaCharacterCombatStats = Cyclopedia.loadCharacterCombatStats,
            onParseCyclopediaCharacterBadges = Cyclopedia.loadCharacterBadges,
            onCyclopediaCharacterRecentDeaths = Cyclopedia.loadCharacterRecentDeaths,
            onCyclopediaCharacterRecentKills = Cyclopedia.loadCharacterRecentKills,
            onUpdateCyclopediaCharacterItemSummary = Cyclopedia.loadCharacterItems,
            onParseCyclopediaCharacterAppearances = Cyclopedia.loadCharacterAppearances,
            onParseCyclopediaStoreSummary = Cyclopedia.onParseCyclopediaStoreSummary,
            -- character 14.10
            onCyclopediaCharacterOffenceStats = Cyclopedia.onCyclopediaCharacterOffenceStats,
            onCyclopediaCharacterDefenceStats = Cyclopedia.onCyclopediaCharacterDefenceStats,
            onCyclopediaCharacterMiscStats = Cyclopedia.onCyclopediaCharacterMiscStats,


            -- charms
            onUpdateBestiaryCharmsData = Cyclopedia.loadCharms,
            -- items
            onParseItemDetail = Cyclopedia.loadItemDetail
        })

        --[[===================================================
    =               Tracker Bestiary                      =
    =================================================== ]] --

        -- Only create if it doesn't exist
        if not trackerButton then
            trackerButton = modules.game_mainpanel.addToggleButton("trackerButton", tr("Bestiary Tracker"),
                "/images/options/bestiaryTracker", Cyclopedia.toggleBestiaryTracker, false, 17)
        end
        
        trackerButton:setOn(false)
        
        -- Only create if it doesn't exist
        if not trackerMiniWindow then
            trackerMiniWindow = g_ui.createWidget('BestiaryTracker', modules.game_interface.getRightPanel())

            -- Set the title with length limit like in containers
            local titleWidget = trackerMiniWindow:getChildById('miniwindowTitle')
            if titleWidget then
                local title = tr('Bestiary Tracker')
                if title:len() > 12 then
                    title = title:sub(1, 12) .. "..."
                end
                titleWidget:setText(title)
            end

            -- Set up contextMenuButton positioning and click handler
            local contextMenuButton = trackerMiniWindow:recursiveGetChildById('contextMenuButton')
            local newWindowButton = trackerMiniWindow:recursiveGetChildById('newWindowButton')
            local minimizeButton = trackerMiniWindow:recursiveGetChildById('minimizeButton')
            
            if contextMenuButton then
                contextMenuButton:setVisible(true)
                
                -- Position contextMenuButton like in ImbuementTracker
                if minimizeButton then
                    contextMenuButton:breakAnchors()
                    contextMenuButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
                    contextMenuButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
                    contextMenuButton:setMarginRight(7)
                    contextMenuButton:setMarginTop(0)
                end
                
                contextMenuButton.onClick = function(widget, mousePos, mouseButton)
                    return Cyclopedia.createTrackerContextMenu("bestiary", mousePos)
                end
            end

            if newWindowButton then
                newWindowButton:setVisible(true)
                newWindowButton.onClick = function(widget, mousePos, mouseButton)
                    toggle("bestiary")
                    return true
                end
            end

            -- Hook into the onOpen event to ensure data is loaded when window is shown
            trackerMiniWindow.onOpen = function()
                trackerButton:setOn(true)
                -- Aggressive data loading when window becomes visible
                scheduleEvent(function()
                    local char = g_game.getCharacterName()
                    if char and #char > 0 then
                        -- Always ensure data is initialized
                        Cyclopedia.initializeTrackerData()
                        
                        -- Force refresh if no data is visible
                        if not Cyclopedia.storedTrackerData or #Cyclopedia.storedTrackerData == 0 then
                            -- Try to load from cache first
                            local cachedData = Cyclopedia.loadTrackerData("bestiary")
                            if cachedData and #cachedData > 0 then
                                Cyclopedia.storedTrackerData = cachedData
                                Cyclopedia.onParseCyclopediaTracker(0, Cyclopedia.storedTrackerData)
                            end
                        end
                        
                        -- Always try to refresh, regardless of cached data
                        Cyclopedia.refreshBestiaryTracker()
                        
                        -- Request fresh data from server
                        g_game.requestBestiary()
                        
                        -- Additional fallback check
                        scheduleEvent(function()
                            if trackerMiniWindow:isVisible() and trackerMiniWindow.contentsPanel:getChildCount() == 0 then
                                -- If still no data after all attempts, force another refresh
                                Cyclopedia.refreshBestiaryTracker()
                            end
                        end, 500)
                    end
                end, 50)
            end

            trackerMiniWindow.onClose = function()
                trackerButton:setOn(false)
            end

            trackerMiniWindow:setup()
            trackerMiniWindow:hide()
        end

        --[[===================================================
    =               Tracker Bosstiary                     =
    =================================================== ]] --

        -- Only create if it doesn't exist
        if not trackerButtonBosstiary then
            trackerButtonBosstiary = modules.game_mainpanel.addToggleButton("bosstiarytrackerButton",
                tr("Bosstiary Tracker"), "/images/options/bosstiaryTracker", Cyclopedia.toggleBosstiaryTracker, false, 17)
        end
        
        trackerButtonBosstiary:setOn(false)
        
        -- Only create if it doesn't exist
        if not trackerMiniWindowBosstiary then
            trackerMiniWindowBosstiary = g_ui.createWidget('BestiaryTracker', modules.game_interface.getRightPanel())
            
            -- Set the title with length limit like in containers
            local titleWidgetBosstiary = trackerMiniWindowBosstiary:getChildById('miniwindowTitle')
            if titleWidgetBosstiary then
                local title = tr('Bosstiary Tracker')
                if title:len() > 12 then
                    title = title:sub(1, 12) .. "..."
                end
                titleWidgetBosstiary:setText(title)
            end

            -- Set the icon for Bosstiary Tracker
            local iconWidgetBosstiary = trackerMiniWindowBosstiary:getChildById('miniwindowIcon')
            if iconWidgetBosstiary then
                iconWidgetBosstiary:setImageSource('/images/icons/icon-bosstracker-widget')
            end

            -- Set up contextMenuButton positioning and click handler for Bosstiary
            local contextMenuButtonBosstiary = trackerMiniWindowBosstiary:recursiveGetChildById('contextMenuButton')
            local newWindowButtonBosstiary = trackerMiniWindowBosstiary:recursiveGetChildById('newWindowButton')
            local minimizeButtonBosstiary = trackerMiniWindowBosstiary:recursiveGetChildById('minimizeButton')
            
            if contextMenuButtonBosstiary then
                contextMenuButtonBosstiary:setVisible(true)
                
                -- Position contextMenuButton like in ImbuementTracker
                if minimizeButtonBosstiary then
                    contextMenuButtonBosstiary:breakAnchors()
                    contextMenuButtonBosstiary:addAnchor(AnchorTop, minimizeButtonBosstiary:getId(), AnchorTop)
                    contextMenuButtonBosstiary:addAnchor(AnchorRight, minimizeButtonBosstiary:getId(), AnchorLeft)
                    contextMenuButtonBosstiary:setMarginRight(7)
                    contextMenuButtonBosstiary:setMarginTop(0)
                end
                
                contextMenuButtonBosstiary.onClick = function(widget, mousePos, mouseButton)
                    return Cyclopedia.createTrackerContextMenu("bosstiary", mousePos)
                end
            end

            if newWindowButtonBosstiary then
                newWindowButtonBosstiary:setVisible(true)
                newWindowButtonBosstiary.onClick = function(widget, mousePos, mouseButton)
                    toggle("bosstiary")
                    return true
                end
            end

            -- Hook into the onOpen event to ensure data is loaded when window is shown
            trackerMiniWindowBosstiary.onOpen = function()
                trackerButtonBosstiary:setOn(true)
                -- Aggressive data loading when window becomes visible
                scheduleEvent(function()
                    local char = g_game.getCharacterName()
                    if char and #char > 0 then
                        -- Always ensure data is initialized
                        Cyclopedia.initializeTrackerData()
                        
                        -- Force refresh if no data is visible
                        if not Cyclopedia.storedBosstiaryTrackerData or #Cyclopedia.storedBosstiaryTrackerData == 0 then
                            -- Try to load from cache first
                            local cachedData = Cyclopedia.loadTrackerData("bosstiary")
                            if cachedData and #cachedData > 0 then
                                Cyclopedia.storedBosstiaryTrackerData = cachedData
                                Cyclopedia.onParseCyclopediaTracker(1, Cyclopedia.storedBosstiaryTrackerData)
                            end
                        end
                        
                        -- Always try to refresh, regardless of cached data
                        Cyclopedia.refreshBosstiaryTracker()
                        
                        -- Request fresh data from server
                        g_game.requestBestiary()
                        
                        -- Additional fallback check
                        scheduleEvent(function()
                            if trackerMiniWindowBosstiary:isVisible() and trackerMiniWindowBosstiary.contentsPanel:getChildCount() == 0 then
                                -- If still no data after all attempts, force another refresh
                                Cyclopedia.refreshBosstiaryTracker()
                            end
                        end, 500)
                    end
                end, 50)
            end

            trackerMiniWindowBosstiary.onClose = function()
                trackerButtonBosstiary:setOn(false)
            end

            trackerMiniWindowBosstiary:setup()
            trackerMiniWindowBosstiary:hide()
        end
        trackerMiniWindow:setupOnStart()
        trackerMiniWindowBosstiary:setupOnStart()
        Cyclopedia.loadTrackerFilters("bestiary")
        Cyclopedia.loadTrackerFilters("bosstiary")
        
        -- Populate any visible trackers with cached data after windows are set up
        Cyclopedia.populateVisibleTrackersWithCachedData()
        
        -- Also set up proper tracker button states based on window visibility
        if trackerMiniWindow:isVisible() then
            trackerButton:setOn(true)
        end
        if trackerMiniWindowBosstiary:isVisible() then
            trackerButtonBosstiary:setOn(true)
        end
        
        Cyclopedia.BossSlots.UnlockBosses = {}
        Keybind.new("Windows", "Show/hide Bosstiary Tracker", "", "")

        Keybind.bind("Windows", "Show/hide Bosstiary Tracker", {{
            type = KEY_DOWN,
            callback = Cyclopedia.toggleBosstiaryTracker
        }})

        Keybind.new("Windows", "Show/hide Bestiary Tracker", "", "")
        Keybind.bind("Windows", "Show/hide Bestiary Tracker", {{
            type = KEY_DOWN,
            callback = Cyclopedia.toggleBestiaryTracker
        }})
        
        -- Initialize cached tracker data for immediate loading with delay to ensure character name is available
        scheduleEvent(function()
            local char = g_game.getCharacterName()
            if char and #char > 0 then
                -- Only clear data if character has changed
                if currentCharacter and currentCharacter ~= char then
                    if Cyclopedia.clearTrackerDataForCharacterChange then
                        Cyclopedia.clearTrackerDataForCharacterChange()
                    end
                end
                
                -- Update current character
                currentCharacter = char
                
                -- Initialize tracker data for current character
                Cyclopedia.initializeTrackerData()
                
                -- Populate any visible trackers with cached data
                Cyclopedia.populateVisibleTrackersWithCachedData()
                
                -- Request fresh bestiary data from server
                g_game.requestBestiary()
                
                -- Additional refresh after delays to ensure everything is loaded
                scheduleEvent(function()
                    Cyclopedia.populateVisibleTrackersWithCachedData()
                    Cyclopedia.refreshAllVisibleTrackers()
                end, 500)
                
                -- Final fallback check
                scheduleEvent(function()
                    Cyclopedia.refreshAllVisibleTrackers()
                end, 2000)
            end
        end, 500)
    end
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase.Icon:setImageSource("/game_cyclopedia/images/monster-icon-bonuspoints")
    end
end


function controllerCyclopedia:onGameEnd()
    if trackerMiniWindow then
        trackerMiniWindow.contentsPanel:destroyChildren()
    end
    if trackerMiniWindowBosstiary then
        trackerMiniWindowBosstiary.contentsPanel:destroyChildren()
    end
    hide()
    
    -- Save tracker filters and data for current character
    if Cyclopedia.saveTrackerFilters then
        Cyclopedia.saveTrackerFilters("bestiary")
        Cyclopedia.saveTrackerFilters("bosstiary")
    end
    
    -- Save current tracker data for current character
    if Cyclopedia.saveTrackerData then
        if Cyclopedia.storedTrackerData then
            Cyclopedia.saveTrackerData("bestiary", Cyclopedia.storedTrackerData)
        end
        if Cyclopedia.storedBosstiaryTrackerData then
            Cyclopedia.saveTrackerData("bosstiary", Cyclopedia.storedBosstiaryTrackerData)
        end
    end
    
    -- Don't clear currentCharacter here - keep it for character change detection
    
    Keybind.delete("Windows", "Show/hide Bosstiary Tracker")
    Keybind.delete("Windows", "Show/hide Bestiary Tracker")
end

function controllerCyclopedia:onTerminate()
    if trackerButton then
        trackerButton:destroy()
        trackerButton = nil
    end

    if trackerMiniWindow then
        trackerMiniWindow:destroy()
        trackerMiniWindow = nil
    end

    if trackerButtonBosstiary then
        trackerButtonBosstiary:destroy()
        trackerButtonBosstiary = nil
    end

    if trackerMiniWindowBosstiary then
        trackerMiniWindowBosstiary:destroy()
        trackerMiniWindowBosstiary = nil
    end

    if CyclopediaButton then
        CyclopediaButton:destroy()
        CyclopediaButton = nil
    end
    if ButtonBossSlot then
        ButtonBossSlot:destroy()
        ButtonBossSlot = nil
    end
    if ButtonBestiary then
        ButtonBestiary:destroy()
        ButtonBestiary = nil
    end
    
    -- Clear character tracking on module termination
    currentCharacter = nil
    
    -- Save items data if available
    if Cyclopedia and Cyclopedia.Items and Cyclopedia.Items.terminate then
        Cyclopedia.Items.terminate()
    end
    
    onTerminateCharm()
end

function hide()
    if not controllerCyclopedia.ui then
        return
    end
    resetCyclopediaTabs()
    controllerCyclopedia.ui:hide()
end

function resetCyclopediaTabs()
    tabStack = {}
    controllerCyclopedia.ui.BackButton:setEnabled(false)
    if previousType then
        local previousWindow = windowTypes[previousType]
        previousWindow.obj:enable()
        previousWindow.obj:setOn(false)
        previousType = nil;
    end
end

function show(defaultWindow)
    if not controllerCyclopedia.ui or not CyclopediaButton then
        return
    end

    controllerCyclopedia.ui:show()
    controllerCyclopedia.ui:raise()
    controllerCyclopedia.ui:focus()
    SelectWindow(defaultWindow, false)
    controllerCyclopedia.ui.GoldBase.Value:setText(Cyclopedia.formatGold(g_game.getLocalPlayer():getResourceBalance()))
end

function toggleBack()
    local previousTab = table.remove(tabStack, #tabStack)
    if #tabStack < 1 then
        controllerCyclopedia.ui.BackButton:setEnabled(false)
    end
    SelectWindow(previousTab, true)
end

function SelectWindow(type, isBackButtonPress)
    if previousType then
        local previousWindow = windowTypes[previousType]
        previousWindow.obj:enable()
        previousWindow.obj:setOn(false)
        if not isBackButtonPress then
            table.insert(tabStack, previousType)
            controllerCyclopedia.ui.BackButton:setEnabled(true)
        end
    end
    contentContainer:destroyChildren()

    local window = windowTypes[type]
    if window then
        window.obj:setOn(true)
        window.obj:disable()
        previousType = type
        if window.func then
            window.func(contentContainer)
        end
    end
end
