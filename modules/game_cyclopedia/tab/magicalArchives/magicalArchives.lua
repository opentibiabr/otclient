local UI = nil
local currentSpell = nil
local allSpells = {}
local filteredSpells = {}

local function getMagicalArchivesViewState()
    local defaults = {
        selectedTab = "combat",
        selectedSpellKey = "",
        searchText = ""
    }

    if Cyclopedia.getTabState then
        return Cyclopedia.getTabState("magicalArchives", defaults)
    end

    return defaults
end

local function saveMagicalArchivesViewState(statePatch)
    if Cyclopedia.saveTabState then
        Cyclopedia.saveTabState("magicalArchives", statePatch)
    end
end

local function getSpellStateKey(spell)
    if not spell then
        return ""
    end

    if spell.spellName and spell.spellName ~= "" then
        return spell.spellName
    end

    if spell.name and spell.name ~= "" then
        return spell.name
    end

    if spell.words and spell.words ~= "" then
        return spell.words
    end

    return ""
end

local function resolveSpellDetailsTab(spell, requestedTab)
    local tabName = requestedTab or "combat"
    local isRune = spell and spell.type == "Conjure"
    if tabName == "rune" and not isRune then
        tabName = "combat"
    end
    if tabName ~= "combat" and tabName ~= "additional" and tabName ~= "rune" then
        tabName = "combat"
    end
    return tabName
end

-- Filters state
local filters = {
    charVocationFilter = true,
    charLevelFilter = false,
    learntSpellsFilter = false,
    druidFilter = true,
    knightFilter = true,
    paladinFilter = true,
    sorcererFilter = true,
    monkFilter = true,
    allVocationsFilter = true,
    attackFilter = true,
    healingFilter = true,
    supportFilter = true,
    allSpellGroupsFilter = true,
    premiumFilter = true,
    freeFilter = true,
    runeSpellsFilter = true,
    instantSpellsFilter = true
}

-- Base vocation mapping (promoted -> base)
local baseVocationMap = {
    [6] = 1,  -- Master Sorcerer -> Sorcerer
    [7] = 2,  -- Elder Druid -> Druid
    [8] = 3,  -- Royal Paladin -> Paladin
    [9] = 4,  -- Elite Knight -> Knight
    [10] = 5  -- Exalted Monk -> Monk
}

-- Aim at target storage (global setting for all directional spells)
local aimAtTargetEnabled = false

-- Get vocation name (uses VocationNames from spells.lua)
local function getVocationName(vocId)
    if VocationNames and VocationNames[vocId] then
        return VocationNames[vocId]
    end
    -- Fallback
    local fallback = {
        [0] = 'None', [1] = 'Sorcerer', [2] = 'Druid', [3] = 'Paladin',
        [4] = 'Knight', [5] = 'Monk', [6] = 'Master Sorcerer', [7] = 'Elder Druid',
        [8] = 'Royal Paladin', [9] = 'Elite Knight', [10] = 'Exalted Monk'
    }
    return fallback[vocId] or 'Unknown'
end

local function getSpellIconIdByName(spellName)
    if not spellName or not Spells then
        return 0
    end

    if Spells.getSpellIconId then
        return Spells.getSpellIconId(spellName)
    end

    if Spells.getSpellByName then
        local spellData = Spells.getSpellByName(spellName)
        if spellData then
            if spellData.clientId and spellData.clientId >= 0 then
                return spellData.clientId
            end
            if spellData.id and spellData.id >= 0 then
                return spellData.id
            end
        end
    end

    return 0
end

-- Local function declarations
local selectTab
local onAimTargetChange
local assignSpellToActionBar

-- Reset filters to default values
local function resetFiltersToDefault()
    filters.charVocationFilter = true
    filters.charLevelFilter = false
    filters.learntSpellsFilter = false
    filters.druidFilter = true
    filters.knightFilter = true
    filters.paladinFilter = true
    filters.sorcererFilter = true
    filters.monkFilter = true
    filters.allVocationsFilter = true
    filters.attackFilter = true
    filters.healingFilter = true
    filters.supportFilter = true
    filters.allSpellGroupsFilter = true
    filters.premiumFilter = true
    filters.freeFilter = true
    filters.runeSpellsFilter = true
    filters.instantSpellsFilter = true
end

-- Track if this is the first time opening
local firstOpen = true

function showMagicalArchives()
    UI = g_ui.loadUI("magicalArchives", contentContainer)
    if not UI then
        return
    end
    
    UI:show()
    
    if controllerCyclopedia and controllerCyclopedia.ui then
        if controllerCyclopedia.ui.CharmsBase then
    controllerCyclopedia.ui.CharmsBase:setVisible(false)
        end
        if controllerCyclopedia.ui.GoldBase then
    controllerCyclopedia.ui.GoldBase:setVisible(false)
        end
        if controllerCyclopedia.ui.BestiaryTrackerButton then
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
        end
        if g_game.getClientVersion() >= 1410 and controllerCyclopedia.ui.CharmsBase1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(false)
        end
    end
    
    -- Only reset filters on first open
    if firstOpen then
        resetFiltersToDefault()
        firstOpen = false
    end
    
    -- Bind click handlers programmatically
    bindUICallbacks()
    
    -- Load spells
    loadSpellsData()
    
    -- Setup filter combo
    setupFiltersUI()
    
    -- Setup search
    setupSearchUI()
    
    -- Load aim at target data
    loadAimAtTargetData()
end

function bindUICallbacks()
    -- Combat Stats tab
    local combatStatsTab = UI:recursiveGetChildById('combatStatsTab')
    if combatStatsTab then
        combatStatsTab.onClick = function() selectTab('combat') end
    end
    
    -- Additional tab
    local additionalTab = UI:recursiveGetChildById('additionalTab')
    if additionalTab then
        additionalTab.onClick = function() selectTab('additional') end
    end
    
    -- Rune Spell tab
    local runeSpellTab = UI:recursiveGetChildById('runeSpellTab')
    if runeSpellTab then
        runeSpellTab.onClick = function() selectTab('rune') end
    end
    
    -- Assign spell button
    local assignSpellBtn = UI:recursiveGetChildById('assignSpellBtn')
    if assignSpellBtn then
        assignSpellBtn.onClick = function() assignSpellToActionBar() end
    end
    
    -- Aim at target checkbox
    local aimTargetBox = UI:recursiveGetChildById('aimTargetBox')
    if aimTargetBox then
        aimTargetBox.onCheckChange = function(widget) onAimTargetChange(widget) end
    end
    
end

selectTab = function(tabName)
    if not UI then return end
    local combatStatsTab = UI:recursiveGetChildById('combatStatsTab')
    local additionalTab = UI:recursiveGetChildById('additionalTab')
    local runeSpellTab = UI:recursiveGetChildById('runeSpellTab')
    local combatStatsContent = UI:recursiveGetChildById('combatStatsContent')
    local additionalContent = UI:recursiveGetChildById('additionalContent')
    local runeSpellContent = UI:recursiveGetChildById('runeSpellContent')
    
    -- Reset all tabs and content
    if combatStatsTab then combatStatsTab:setChecked(false) end
    if additionalTab then additionalTab:setChecked(false) end
    if runeSpellTab then runeSpellTab:setChecked(false) end
    if combatStatsContent then combatStatsContent:setVisible(false) end
    if additionalContent then additionalContent:setVisible(false) end
    if runeSpellContent then runeSpellContent:setVisible(false) end
    
    local activeTab = tabName
    if activeTab ~= "combat" and activeTab ~= "additional" and activeTab ~= "rune" then
        activeTab = "combat"
    end

    if activeTab == 'combat' then
        if combatStatsTab then combatStatsTab:setChecked(true) end
        if combatStatsContent then combatStatsContent:setVisible(true) end
    elseif activeTab == 'additional' then
        if additionalTab then additionalTab:setChecked(true) end
        if additionalContent then additionalContent:setVisible(true) end
    elseif activeTab == 'rune' then
        if runeSpellTab then runeSpellTab:setChecked(true) end
        if runeSpellContent then runeSpellContent:setVisible(true) end
    end

    saveMagicalArchivesViewState({ selectedTab = activeTab })
end

onAimTargetChange = function(checkbox)
    -- Global setting - applies to ALL directional spells
    aimAtTargetEnabled = checkbox:isChecked()
    saveAimAtTargetData()
    
    -- Send update to server for all directional spells if API exists
    if g_game.sendUpdateAutoAimGlobal then
        g_game.sendUpdateAutoAimGlobal(aimAtTargetEnabled)
    end
end

assignSpellToActionBar = function()
    if not currentSpell then
        if modules.game_textmessage then
            modules.game_textmessage.displayStatusMessage(tr('Please select a spell first.'))
        end
        return
    end
    
    if modules.game_actionbar and modules.game_actionbar.assignSpell then
        modules.game_actionbar.assignSpell(currentSpell)
    else
        if modules.game_textmessage then
            modules.game_textmessage.displayStatusMessage(tr('Action bar not available.'))
        end
    end
end

function loadSpellsData()
    allSpells = {}
    
    if not Spells then
        return
    end
    
    if not SpellInfo or not SpellInfo.Default then
        return
    end
    
    -- Get spells from SpellInfo
    for name, spell in pairs(SpellInfo.Default) do
        spell.spellName = name
        -- Determine spell group type using SpellGroups mapping
        -- spell.group format: {[groupId] = cooldown}, e.g., {[1] = 2000} for Attack
        if spell.group then
            for groupId, _ in pairs(spell.group) do
                -- SpellGroups: [1]='Attack', [2]='Healing', [3]='Support', etc.
                local groupName = SpellGroups and SpellGroups[groupId]
                if groupName then
                    if groupName == "Attack" then
                        spell.spellGroup = "Attack"
                        break
                    elseif groupName == "Healing" then
                        spell.spellGroup = "Healing"
                        break
                    elseif groupName == "Support" or groupName == "Conjure" then
                        spell.spellGroup = "Support"
                        break
                    end
                end
            end
        end
        -- Fallback: if aggressive, it's attack
        if not spell.spellGroup then
            if spell.aggressive then
                spell.spellGroup = "Attack"
            else
                spell.spellGroup = "Support"
            end
        end
        spell.directional = spell.aggressive or false
        table.insert(allSpells, spell)
    end
    
    -- Sort alphabetically
    table.sort(allSpells, function(a, b)
        local nameA = a.name or a.spellName or ""
        local nameB = b.name or b.spellName or ""
        return nameA < nameB
    end)
    
    -- Apply initial filters
    applyAllFilters()
end

local filterPopup = nil
local filterPopupVisible = false

function setupFiltersUI()
    -- Button to toggle filter popup
    local filterBtn = UI:recursiveGetChildById('filterBtn')
    if filterBtn then
        filterBtn.onClick = function(self)
            toggleFilterPopup(self)
        end
    end
end

function toggleFilterPopup(button)
    -- Toggle popup visibility
    if filterPopupVisible and filterPopup then
        closeFilterPopup()
        return
    end
    
    showFilterPopup(button)
end

function showFilterPopup(button)
    -- Close existing popup if any
    if filterPopup then
        filterPopup:destroy()
        filterPopup = nil
    end
    
    -- Create popup
    filterPopup = g_ui.createWidget('FilterPopup', rootWidget)
    if not filterPopup then
        return
    end
    
    -- Position below button
    local pos = button:getPosition()
    local size = button:getSize()
    filterPopup:setPosition({x = pos.x, y = pos.y + size.height})
    
    -- Setup checkboxes
    setupFilterCheckboxesInPopup(filterPopup)
    
    -- Show popup
    filterPopup:show()
    filterPopup:raise()
    filterPopupVisible = true
    
    -- Close on click outside (but not on popup children)
    connect(rootWidget, {
        onMousePress = onRootMousePress
    })
end

function onRootMousePress(widget, mousePos, button)
    if not filterPopup or not filterPopupVisible then
        return false
    end
    
    -- Safely get popup position and size
    local ok, popupPos = pcall(function() return filterPopup:getPosition() end)
    if not ok then return false end
    local ok2, popupSize = pcall(function() return filterPopup:getSize() end)
    if not ok2 then return false end
    
    if mousePos.x >= popupPos.x and mousePos.x <= popupPos.x + popupSize.width and
       mousePos.y >= popupPos.y and mousePos.y <= popupPos.y + popupSize.height then
        -- Click inside popup, don't close
        return false
    end
    
    -- Check if click is on the filter button (to toggle)
    if UI then
        local filterBtn = UI:recursiveGetChildById('filterBtn')
        if filterBtn then
            local btnPos = filterBtn:getPosition()
            local btnSize = filterBtn:getSize()
            if mousePos.x >= btnPos.x and mousePos.x <= btnPos.x + btnSize.width and
               mousePos.y >= btnPos.y and mousePos.y <= btnPos.y + btnSize.height then
                -- Click on button, let it handle toggle
                return false
            end
        end
    end
    
    -- Click outside, close popup and apply filters
    closeFilterPopup()
    return false
end

function closeFilterPopup()
    filterPopupVisible = false
    
    if filterPopup then
        filterPopup:destroy()
        filterPopup = nil
    end
    
    -- Safely disconnect
    if rootWidget then
        pcall(function()
            disconnect(rootWidget, {
                onMousePress = onRootMousePress
            })
        end)
    end
    
    -- Apply filters when closing (only if UI exists)
    if UI then
        applyAllFilters()
    end
end

local isInitializingPopup = false

function setupFilterCheckboxesInPopup(popup)
    local filterIds = {
        'charVocationFilter', 'charLevelFilter', 'learntSpellsFilter',
        'druidFilter', 'knightFilter', 'paladinFilter', 'sorcererFilter', 'monkFilter', 'allVocationsFilter',
        'attackFilter', 'healingFilter', 'supportFilter', 'allSpellGroupsFilter',
        'premiumFilter', 'freeFilter', 'runeSpellsFilter', 'instantSpellsFilter'
    }
    
    -- Prevent callbacks during initialization
    isInitializingPopup = true
    
    for _, filterId in ipairs(filterIds) do
        local checkbox = popup:recursiveGetChildById(filterId)
        if checkbox then
            checkbox.onCheckChange = function(self)
                if not isInitializingPopup then
                    onFilterCheckboxChangeInPopup(self, popup)
                end
            end
            -- Set the checkbox to match the current filter value
            checkbox:setChecked(filters[filterId] == true)
        end
    end
    
    isInitializingPopup = false
end

function onFilterCheckboxChangeInPopup(checkbox, popup)
    local id = checkbox:getId()
    local isChecked = checkbox:isChecked()
    filters[id] = isChecked
    
    
    -- Handle "All Vocations" checkbox
    local vocationFilters = {"druidFilter", "knightFilter", "paladinFilter", "sorcererFilter", "monkFilter"}
    if id == "allVocationsFilter" then
        for _, voc in ipairs(vocationFilters) do
            filters[voc] = isChecked
            local cb = popup:recursiveGetChildById(voc)
            if cb then cb:setChecked(isChecked, true) end
        end
    elseif table.contains(vocationFilters, id) then
        local allChecked = true
        for _, voc in ipairs(vocationFilters) do
            if not filters[voc] then
                allChecked = false
                break
            end
        end
        filters.allVocationsFilter = allChecked
        local allVocCb = popup:recursiveGetChildById("allVocationsFilter")
        if allVocCb then allVocCb:setChecked(allChecked, true) end
    end
    
    -- Handle "All Spell Groups" checkbox
    local spellGroupFilters = {"attackFilter", "healingFilter", "supportFilter"}
    if id == "allSpellGroupsFilter" then
        for _, grp in ipairs(spellGroupFilters) do
            filters[grp] = isChecked
            local cb = popup:recursiveGetChildById(grp)
            if cb then cb:setChecked(isChecked, true) end
        end
    elseif table.contains(spellGroupFilters, id) then
        local allChecked = true
        for _, grp in ipairs(spellGroupFilters) do
            if not filters[grp] then
                allChecked = false
                break
            end
        end
        filters.allSpellGroupsFilter = allChecked
        local allGrpCb = popup:recursiveGetChildById("allSpellGroupsFilter")
        if allGrpCb then allGrpCb:setChecked(allChecked, true) end
    end
    
    -- Apply filters immediately
    applyAllFilters()
end

-- Vocation mapping: base vocation ID for each filter
-- Canary uses different vocation IDs for client vs server:
-- CLIENT_ID (what player:getVocation() returns):
--   Knight=1, Paladin=2, Sorcerer=3, Druid=4, Monk=5
--   Elite Knight=11, Royal Paladin=12, Master Sorcerer=13, Elder Druid=14, Exalted Monk=15
-- SERVER_ID (used in spell definitions):
--   Sorcerer=1, Druid=2, Paladin=3, Knight=4, Monk=5 (base)
--   Master Sorcerer=6, Elder Druid=7, Royal Paladin=8, Elite Knight=9, Exalted Monk=10

-- Map CLIENT_ID to SERVER base vocation ID
local clientVocationToServerBase = {
    [0] = 0,   -- None
    [1] = 4,   -- Knight -> Knight base
    [2] = 3,   -- Paladin -> Paladin base
    [3] = 1,   -- Sorcerer -> Sorcerer base
    [4] = 2,   -- Druid -> Druid base
    [5] = 5,   -- Monk -> Monk base (if using 5)
    [9] = 5,   -- Monk (alt) -> Monk base
    [11] = 4,  -- Elite Knight -> Knight base
    [12] = 3,  -- Royal Paladin -> Paladin base
    [13] = 1,  -- Master Sorcerer -> Sorcerer base
    [14] = 2,  -- Elder Druid -> Druid base
    [15] = 5,  -- Exalted Monk -> Monk base
    [10] = 5,  -- Exalted Monk (alt) -> Monk base
}

-- Map CLIENT_ID to filter key
local clientVocationToFilter = {
    [1] = "knightFilter",   -- Knight
    [2] = "paladinFilter",  -- Paladin
    [3] = "sorcererFilter", -- Sorcerer
    [4] = "druidFilter",    -- Druid
    [5] = "monkFilter",     -- Monk
    [9] = "monkFilter",     -- Monk (alt)
    [11] = "knightFilter",  -- Elite Knight
    [12] = "paladinFilter", -- Royal Paladin
    [13] = "sorcererFilter",-- Master Sorcerer
    [14] = "druidFilter",   -- Elder Druid
    [15] = "monkFilter",    -- Exalted Monk
    [10] = "monkFilter",    -- Exalted Monk (alt)
}

-- Spell vocations use SERVER IDs: 1=Sorcerer, 2=Druid, 3=Paladin, 4=Knight, 5=Monk
-- And promotions: 6=MS, 7=ED, 8=RP, 9=EK, 10=ExaltedMonk
local vocationToFilter = {
    ["Sorcerer"] = {1, 6},   -- Sorcerer + Master Sorcerer
    ["Druid"] = {2, 7},      -- Druid + Elder Druid
    ["Paladin"] = {3, 8},    -- Paladin + Royal Paladin
    ["Knight"] = {4, 9},     -- Knight + Elite Knight
    ["Monk"] = {5, 10}       -- Monk + Exalted Monk
}

local filterToVocations = {
    sorcererFilter = {1, 6},
    druidFilter = {2, 7},
    paladinFilter = {3, 8},
    knightFilter = {4, 9},
    monkFilter = {5, 10}
}

-- Map SERVER vocation ID to filter key
local serverVocationIdToFilter = {
    [1] = "sorcererFilter", [6] = "sorcererFilter",
    [2] = "druidFilter", [7] = "druidFilter",
    [3] = "paladinFilter", [8] = "paladinFilter",
    [4] = "knightFilter", [9] = "knightFilter",
    [5] = "monkFilter", [10] = "monkFilter"
}

-- Check if a spell's vocations include any of the given vocation IDs
local function spellMatchesVocation(spellVocations, targetVocIds)
    if not spellVocations or #spellVocations == 0 then
        return true -- No restriction
    end
    for _, spellVoc in ipairs(spellVocations) do
        if spellVoc == 0 then
            return true -- All vocations
        end
        for _, targetVoc in ipairs(targetVocIds) do
            if spellVoc == targetVoc then
                return true
            end
        end
    end
    return false
end

-- Check if spell matches player's vocation (CLIENT_ID input, SERVER_ID spell vocations)
local function spellMatchesPlayerVocation(spellVocations, playerClientVocation)
    if not spellVocations or #spellVocations == 0 then
        return true -- No restriction
    end
    
    -- Convert player's CLIENT_ID to SERVER base vocation
    local playerServerBase = clientVocationToServerBase[playerClientVocation] or 0
    
    for _, spellVoc in ipairs(spellVocations) do
        if spellVoc == 0 then
            return true -- All vocations
        end
        -- Get spell's base vocation (SERVER IDs)
        local spellBase = baseVocationMap[spellVoc] or spellVoc
        if spellBase == playerServerBase then
            return true
        end
    end
    return false
end

function passesVocationFilter(spellVocations, playerClientVocation)
    -- Spell has no vocation requirements = show always
    if not spellVocations or #spellVocations == 0 then
        return true
    end
    
    -- Check if spell is for all vocations (vocations includes 0)
    for _, v in ipairs(spellVocations) do
        if v == 0 then 
            return true -- Spells for all vocations always pass
        end
    end
    
    -- If "All Vocations" is checked, show spells from all vocations
    if filters.allVocationsFilter then
        return true
    end
    
    -- "Character Vocation" mode: Filter by player's vocation
    if filters.charVocationFilter then
        -- First check: player's vocation filter must be enabled
        local playerFilterKey = clientVocationToFilter[playerClientVocation]
        if playerFilterKey and not filters[playerFilterKey] then
            return false -- Player's vocation filter is not checked
        end
        
        -- Second check: spell must be usable by player's vocation
        local matches = spellMatchesPlayerVocation(spellVocations, playerClientVocation)
        return matches
    end
    
    -- "Manual Vocation" mode: Filter by individually checked vocations
    -- Spell must match at least one checked vocation filter (using SERVER vocation IDs)
    local anyFilterChecked = filters.sorcererFilter or filters.druidFilter or 
                             filters.paladinFilter or filters.knightFilter or filters.monkFilter
    
    if not anyFilterChecked then
        return false -- No vocation filter checked at all
    end
    
    if filters.sorcererFilter and spellMatchesVocation(spellVocations, {1, 6}) then return true end
    if filters.druidFilter and spellMatchesVocation(spellVocations, {2, 7}) then return true end
    if filters.paladinFilter and spellMatchesVocation(spellVocations, {3, 8}) then return true end
    if filters.knightFilter and spellMatchesVocation(spellVocations, {4, 9}) then return true end
    if filters.monkFilter and spellMatchesVocation(spellVocations, {5, 10}) then return true end
    
    return false
end

function passesLevelFilter(spellLevel, playerLevel)
    if not filters.charLevelFilter then
        return true -- Level filter is off, show all
    end
    if not spellLevel then
        return true -- Spell has no level requirement
    end
    return spellLevel <= playerLevel
end

function passesSpellGroupFilter(spellGroup)
    if filters.allSpellGroupsFilter then
        return true -- Show all spell groups
    end
    
    local group = spellGroup or "Support"
    
    if filters.attackFilter and group == "Attack" then return true end
    if filters.healingFilter and group == "Healing" then return true end
    if filters.supportFilter and group == "Support" then return true end
    
    return false
end

function passesLearntSpellsFilter(spell, playerLevel, playerClientVocation, isPremium)
    if not filters.learntSpellsFilter then
        return true -- Learnt filter is off
    end
    
    -- Check level requirement
    if spell.level and spell.level > playerLevel then
        return false
    end
    
    -- Check vocation requirement (using CLIENT_ID)
    if not spellMatchesPlayerVocation(spell.vocations, playerClientVocation) then
        return false
    end
    
    -- Check premium requirement
    if spell.premium and not isPremium then
        return false
    end
    
    return true
end

function applyAllFilters()
    if not UI then
        return
    end
    
        filteredSpells = {}
    local player = g_game.getLocalPlayer()
    local playerLevel = player and player:getLevel() or 999
    local playerVocation = player and player:getVocation() or 0
    local isPremiumPlayer = player and player:isPremium() or false
    
        for _, spell in ipairs(allSpells) do
        local passes = true
        
        -- Learnt Spells filter (must meet level, vocation, premium)
        if passes and not passesLearntSpellsFilter(spell, playerLevel, playerVocation, isPremiumPlayer) then
            passes = false
        end
        
        -- Vocation filter
        if passes and not passesVocationFilter(spell.vocations, playerVocation) then
            passes = false
        end
        
        -- Level filter
        if passes and not passesLevelFilter(spell.level, playerLevel) then
            passes = false
        end
        
        -- Spell group filter (Attack, Healing, Support)
        if passes and not passesSpellGroupFilter(spell.spellGroup) then
            passes = false
        end
        
        -- Premium/Free filter
        if passes then
            local isPremium = spell.premium == true
            if isPremium and not filters.premiumFilter then
                passes = false
            elseif not isPremium and not filters.freeFilter then
                passes = false
            end
        end
        
        -- Rune/Instant filter
        if passes then
            local isRune = spell.type == "Conjure"
            if isRune and not filters.runeSpellsFilter then
                passes = false
            elseif not isRune and not filters.instantSpellsFilter then
                passes = false
            end
        end
        
        if passes then
            table.insert(filteredSpells, spell)
        end
    end
    
    updateSpellListUI()
end

function setupSearchUI()
    local searchEdit = UI:recursiveGetChildById('searchEdit')
    if not searchEdit then return end

    local viewState = getMagicalArchivesViewState()
    if searchEdit:getText() ~= (viewState.searchText or "") then
        searchEdit:setText(viewState.searchText or "")
    end
    
    searchEdit.onTextChange = function(self, text)
        saveMagicalArchivesViewState({ searchText = text or "" })
        if text and text ~= '' then
            searchSpells(text)
        else
            -- When search is cleared, re-apply all filters
            applyAllFilters()
        end
    end

    if viewState.searchText and viewState.searchText ~= "" then
        searchSpells(viewState.searchText)
    end
end

function searchSpells(searchText)
    if not searchText or searchText == '' then
        applyAllFilters()
        return
    end
    
    searchText = searchText:lower()
    filteredSpells = {}
    
    for _, spell in ipairs(allSpells) do
        local spellName = spell.name or ""
        local spellWords = spell.words or ""
        if spellName:lower():find(searchText) or spellWords:lower():find(searchText) then
            table.insert(filteredSpells, spell)
        end
    end
    
    updateSpellListUI()
end

function updateSpellListUI()
    if not UI then 
        return 
    end
    local spellList = UI:recursiveGetChildById('spellList')
    if not spellList then 
        return 
    end
    
    spellList:destroyChildren()
    
    local player = g_game.getLocalPlayer()
    local playerLevel = player and player:getLevel() or 1
    local viewState = getMagicalArchivesViewState()
    local selectedSpellKey = viewState.selectedSpellKey or ""
    local firstWidget = nil
    local selectedWidget = nil
    
    for i, spell in ipairs(filteredSpells) do
        local widget = g_ui.createWidget('SpellListItem', spellList)
        if widget then
            -- Set spell icon (using small 20x20 icons for list)
            local spellIcon = widget:getChildById('spellIcon')
            if spellIcon and spell.name then
                local iconId = getSpellIconIdByName(spell.name)
                local profile = "Default"
                if SpelllistSettings and SpelllistSettings['Default'] then
                    local source = SpelllistSettings['Default'].iconsForGameCooldown
                    spellIcon:setImageSource(source)
                    local clip = Spells.getImageClipCooldown(iconId, profile)
                    spellIcon:setImageClip(clip)
                end
            end
            
            -- Set spell name
            local nameLabel = widget:getChildById('spellName')
            if nameLabel then
                local displayName = spell.name or "Unknown"
                if #displayName > 18 then
                    displayName = displayName:sub(1, 15) .. "..."
                    nameLabel:setTooltip(spell.name)
                end
                nameLabel:setText(displayName)
            end
            
            -- Check if spell is locked
            local grayOverlay = widget:getChildById('grayOverlay')
            if grayOverlay then
                local isLocked = spell.level and spell.level > playerLevel
                grayOverlay:setVisible(isLocked)
            end
            
            widget.spell = spell
            widget:setFocusable(true)
            if not firstWidget then
                firstWidget = widget
            end
            if selectedSpellKey ~= "" and getSpellStateKey(spell) == selectedSpellKey then
                selectedWidget = widget
            end
            
            widget.onFocusChange = function(self, focused)
                if focused then
                    selectSpellDetails(self.spell)
                end
            end
        end
    end
    
    if #filteredSpells == 0 then
        currentSpell = nil
        local emptyLabel = g_ui.createWidget('Label', spellList)
        emptyLabel:setText(tr('No spells found'))
        emptyLabel:setColor('#909090')
        emptyLabel:setTextAlign(AlignCenter)
    elseif selectedWidget then
        selectedWidget:focus()
        selectSpellDetails(selectedWidget.spell)
    elseif firstWidget then
        firstWidget:focus()
        selectSpellDetails(firstWidget.spell)
    end
end

-- Vocation icon clips (Knight, Paladin, Sorcerer, Druid, Monk in order)
local vocationIconClips = {
    Knight = "0 0 9 9",
    Paladin = "9 0 9 9",
    Sorcerer = "18 0 9 9",
    Druid = "27 0 9 9",
    Monk = "36 0 9 9"
}

-- Map server vocation IDs to base vocation names for icon display
local serverVocIdToName = {
    [1] = "Sorcerer", [6] = "Sorcerer",
    [2] = "Druid", [7] = "Druid",
    [3] = "Paladin", [8] = "Paladin",
    [4] = "Knight", [9] = "Knight",
    [5] = "Monk", [10] = "Monk"
}

function createVocationIcons(panel, vocations)
    if not panel then return end
    panel:destroyChildren()
    
    if not vocations or #vocations == 0 then return end
    
    -- Check if spell is for all vocations
    local isAllVocations = false
    for _, v in ipairs(vocations) do
        if v == 0 then
            isAllVocations = true
            break
        end
    end
    
    -- If all vocations, show all icons
    if isAllVocations then
        for _, vocName in ipairs({"Knight", "Paladin", "Sorcerer", "Druid", "Monk"}) do
            local icon = g_ui.createWidget('VocationIcon', panel)
            if icon then
                icon:setImageClip(vocationIconClips[vocName])
                icon:setTooltip(vocName)
            end
        end
    else
        -- Show specific vocation icons
        local addedVocations = {}
        for _, vocId in ipairs(vocations) do
            local baseName = serverVocIdToName[vocId]
            if baseName and not addedVocations[baseName] then
                local icon = g_ui.createWidget('VocationIcon', panel)
                if icon then
                    icon:setImageClip(vocationIconClips[baseName])
                    icon:setTooltip(baseName)
                end
                addedVocations[baseName] = true
            end
        end
    end
end

function selectSpellDetails(spell)
    currentSpell = spell
    saveMagicalArchivesViewState({ selectedSpellKey = getSpellStateKey(spell) })
    
    local emptyState = UI:recursiveGetChildById('emptyState')
    local spellDetails = UI:recursiveGetChildById('spellDetails')
    
    if emptyState then
        emptyState:setVisible(false)
    end
    
    if not spellDetails then return end
        spellDetails:setVisible(true)
    
    -- Update header - spell icon in details panel (32x32)
    local spellIcon = spellDetails:recursiveGetChildById('spellIcon')
    local spellName = spellDetails:recursiveGetChildById('spellName')
    local spellWords = spellDetails:recursiveGetChildById('spellWords')
    local spellLevel = spellDetails:recursiveGetChildById('spellLevel')
    
    if spellIcon and spell.name then
        local iconId = getSpellIconIdByName(spell.name)
        local profile = "Default"
        local source = SpelllistSettings['Default'].iconFile
        spellIcon:setImageSource(source)
        spellIcon:setImageClip(Spells.getImageClip(iconId, profile))
    end
    
    if spellName then
        spellName:setText(spell.name or "Unknown")
    end
    
    if spellWords then
        spellWords:setText(spell.words or "")
    end
    
    if spellLevel then
        -- Show Magic Level for runes, Level for regular spells
        if spell.type == "Conjure" and spell.maglevel and spell.maglevel > 0 then
            spellLevel:setText('Magic Level ' .. spell.maglevel)
        else
            spellLevel:setText('Level ' .. (spell.level or 0))
        end
    end
    
    -- Create vocation icons in header
    local vocationPanel = spellDetails:recursiveGetChildById('vocationPanel')
    createVocationIcons(vocationPanel, spell.vocations)
    
    -- Show/hide Rune Spell tab based on spell type
    local runeSpellTab = UI:recursiveGetChildById('runeSpellTab')
    local isRune = spell.type == "Conjure"
    if runeSpellTab then
        runeSpellTab:setVisible(isRune)
    end
    
    -- Update Combat Stats
    updateCombatStatsUI(spell)
    
    -- Update Additional
    updateAdditionalInfoUI(spell)
    
    -- Update Rune Spell info if applicable
    if isRune then
        updateRuneSpellUI(spell)
    end
    
    -- Show/hide Aim at Target checkbox ONLY for directional spells (waves, beams)
    local aimTargetBox = UI:recursiveGetChildById('aimTargetBox')
    if aimTargetBox then
        local showAimTarget = isDirectionalSpell(spell)
        aimTargetBox:setVisible(showAimTarget == true)
        if showAimTarget then
            -- Use global setting
            aimTargetBox:setChecked(aimAtTargetEnabled, true)
        end
    end
    
    local viewState = getMagicalArchivesViewState()
    local selectedTab = resolveSpellDetailsTab(spell, viewState.selectedTab)
    selectTab(selectedTab)
end

function updateCombatStatsUI(spell)
    local manaValue = UI:recursiveGetChildById('manaValue')
    if manaValue then
        local mana = spell.mana or 0
        local soul = spell.soul or 0
        manaValue:setText(mana .. ' / ' .. soul)
    end
    
    local groupValue = UI:recursiveGetChildById('groupValue')
    if groupValue then
        groupValue:setText(spell.spellGroup or spell.type or 'Support')
    end
    
    local powerValue = UI:recursiveGetChildById('powerValue')
    if powerValue then
        if spell.basePower and spell.basePower > 0 then
            powerValue:setText(tostring(spell.basePower))
        else
        powerValue:setText('-')
        end
    end
    
    local scalesValue = UI:recursiveGetChildById('scalesValue')
    if scalesValue then
        if spell.scalesWith then
            scalesValue:setText(spell.scalesWith)
        elseif spell.aggressive then
            scalesValue:setText('Magic Level')
        else
        scalesValue:setText('-')
    end
end

    local cooldownValue = UI:recursiveGetChildById('cooldownValue')
    if cooldownValue then
        local cd = spell.exhaustion or 0
        cooldownValue:setText((cd / 1000) .. 's')
    end
    
    local groupCooldownValue = UI:recursiveGetChildById('groupCooldownValue')
    if groupCooldownValue then
        local groupCd = 0
        if spell.group then
            for _, cd in pairs(spell.group) do
                if type(cd) == "number" then
                groupCd = cd
                break
                end
            end
        end
        groupCooldownValue:setText((groupCd / 1000) .. 's')
    end
    
    local typeValue = UI:recursiveGetChildById('typeValue')
    if typeValue then
        if spell.damageType then
            typeValue:setText(spell.damageType)
        elseif spell.aggressive then
            typeValue:setText('Physical')
        else
            typeValue:setText('-')
        end
    end
    
    local rangeValue = UI:recursiveGetChildById('rangeValue')
    if rangeValue then
        if spell.range and spell.range > 0 then
            rangeValue:setText(tostring(spell.range))
        else
            rangeValue:setText('-')
        end
    end
end

function updateAdditionalInfoUI(spell)
    local sourceValue = UI:recursiveGetChildById('sourceValue')
    if sourceValue then
        sourceValue:setText(spell.source or 'NPC')
    end
    
    local learnValue = UI:recursiveGetChildById('learnValue')
    if learnValue then
        if spell.cities and #spell.cities > 0 then
            learnValue:setText(table.concat(spell.cities, ', '))
        else
            learnValue:setText('Various cities')
        end
    end
end

function updateRuneSpellUI(spell)
    -- Mana / SP
    local runeManaValue = UI:recursiveGetChildById('runeManaValue')
    if runeManaValue then
        local mana = spell.mana or 0
        local soul = spell.soul or 0
        runeManaValue:setText(mana .. ' / ' .. soul)
    end
    
    -- Spell group
    local runeGroupValue = UI:recursiveGetChildById('runeGroupValue')
    if runeGroupValue then
        runeGroupValue:setText(spell.spellGroup or 'Support')
    end
    
    -- Restriction (level requirement)
    local runeRestrictionValue = UI:recursiveGetChildById('runeRestrictionValue')
    if runeRestrictionValue then
        if spell.level and spell.level > 0 then
            runeRestrictionValue:setText('Level ' .. spell.level)
        else
            runeRestrictionValue:setText('-')
        end
    end
    
    -- Amount (for conjure spells)
    local runeAmountValue = UI:recursiveGetChildById('runeAmountValue')
    if runeAmountValue then
        local amount = spell.amount or spell.charges or 1
        runeAmountValue:setText(tostring(amount))
    end
    
    -- Cooldown
    local runeCooldownValue = UI:recursiveGetChildById('runeCooldownValue')
    if runeCooldownValue then
        local cooldown = spell.cooldown or 2000
        local seconds = math.floor(cooldown / 1000)
        runeCooldownValue:setText(seconds .. 's')
    end
    
    -- Group Cooldown
    local runeGroupCooldownValue = UI:recursiveGetChildById('runeGroupCooldownValue')
    if runeGroupCooldownValue then
        local groupCooldown = spell.groupCooldown or spell.cooldown or 2000
        local seconds = math.floor(groupCooldown / 1000)
        runeGroupCooldownValue:setText(seconds .. 's')
    end
    
    -- Vocations icons
    local runeVocationsPanel = UI:recursiveGetChildById('runeVocationsPanel')
    createVocationIcons(runeVocationsPanel, spell.vocations)
end

function loadAimAtTargetData()
    -- Global setting - applies to all directional spells
    local data = g_settings.getNode('aimAtTargetGlobal')
    aimAtTargetEnabled = data and data.enabled or false
end

function saveAimAtTargetData()
    -- Global setting - applies to all directional spells
    g_settings.setNode('aimAtTargetGlobal', { enabled = aimAtTargetEnabled })
end

-- Check if a spell is directional (needs direction to cast - waves, beams, etc.)
function isDirectionalSpell(spell)
    if not spell then return false end
    
    -- Check spell words for directional patterns
    local words = spell.words or ''
    words = words:lower()
    
    -- Wave spells (exevo ... hur)
    if words:find('hur') and words:find('exevo') then
        return true
    end
    
    -- Beam spells (exevo ... lux)
    if words:find('lux') and words:find('exevo') then
        return true
    end
    
    -- Front sweep, whirlwind throw, etc.
    if words:find('exori min') or words:find('exori hur') then
        return true
    end
    
    -- Directional strike spells
    if spell.directional then
        return true
    end
    
    return false
end

-- Get global aim at target setting
function isAimAtTargetEnabled()
    return aimAtTargetEnabled
end
