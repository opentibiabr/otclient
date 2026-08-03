local UI = nil

local ARCHIVE_PROFILE = 'Default'
local ARCHIVE_FILTER_VOCATION_ANY = 0

local archiveState = {
    vocationId = ARCHIVE_FILTER_VOCATION_ANY,
    search = ''
}

MagicalArchive = MagicalArchive or {}

local function archiveContains(list, value)
    if not list then
        return false
    end
    for i = 1, #list do
        if list[i] == value then
            return true
        end
    end
    return false
end

-- promoted counterpart of a base vocation (server ids): 1-4 -> 5-8, Monk 9 -> Exalted Monk 10
local function archivePromotedId(vocationId)
    if vocationId >= 1 and vocationId <= 4 then
        return vocationId + 4
    end
    if vocationId == 9 then
        return 10
    end
    return nil
end

function MagicalArchive.buildSpellNames(spellInfo)
    local names = {}
    for name in pairs(spellInfo) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function MagicalArchive.matchesVocation(info, vocationId)
    if vocationId == ARCHIVE_FILTER_VOCATION_ANY then
        return true
    end
    return archiveContains(info.vocations, vocationId) or
        archiveContains(info.vocations, archivePromotedId(vocationId))
end

function MagicalArchive.matchesSearch(name, info, searchText)
    if not searchText or searchText == '' then
        return true
    end
    local needle = searchText:lower()
    if name:lower():find(needle, 1, true) then
        return true
    end
    return (info.words or ''):lower():find(needle, 1, true) ~= nil
end

-- promoted vocations are hidden when their base vocation is also present ("Sorcerer" implies "Master Sorcerer")
function MagicalArchive.formatVocations(vocations, vocationNames)
    vocationNames = vocationNames or VocationNames
    local baseOf = { [5] = 1, [6] = 2, [7] = 3, [8] = 4, [10] = 9 }
    local result = ''
    for i = 1, #vocations do
        local vocationId = vocations[i]
        local base = baseOf[vocationId]
        if not base or not archiveContains(vocations, base) then
            result = result .. (result:len() == 0 and '' or ', ') .. (vocationNames[vocationId] or '?')
        end
    end
    return result
end

function MagicalArchive.formatGroupAndCooldown(info, spellGroups)
    spellGroups = spellGroups or SpellGroups
    local cooldown = (info.exhaustion / 1000) .. 's'
    local group = ''
    for groupId, groupName in ipairs(spellGroups) do
        if info.group[groupId] then
            group = group .. (group:len() == 0 and '' or ' / ') .. groupName
            cooldown = cooldown .. ' / ' .. (info.group[groupId] / 1000) .. 's'
        end
    end
    return group, cooldown
end

local function archiveSetDetailRow(rowId, value)
    local row = UI.spellAndRune.DetailPanel.DetailRows[rowId]
    row.value:setText(value)
end

local function archiveSelectSpell(widget)
    local name = widget.spellName or widget:getId()
    local info = SpellInfo[ARCHIVE_PROFILE][name]
    if not info then
        return
    end

    local detail = UI.spellAndRune.DetailPanel
    UI.spellAndRune.PlaceholderLabel:setVisible(false)
    detail:setVisible(true)

    local iconId = tonumber(info.clientId)
    if iconId then
        detail.SpellIcon:setImageSource(SpelllistSettings[ARCHIVE_PROFILE].iconFile)
        detail.SpellIcon:setImageClip(Spells.getImageClip(iconId, ARCHIVE_PROFILE))
    end

    detail.NameLabel:setText(name)
    detail.FormulaLabel:setText('\'' .. info.words .. '\'')

    local group, cooldown = MagicalArchive.formatGroupAndCooldown(info)
    archiveSetDetailRow('RowVocation', MagicalArchive.formatVocations(info.vocations))
    archiveSetDetailRow('RowGroup', group)
    archiveSetDetailRow('RowType', info.type)
    archiveSetDetailRow('RowCooldown', cooldown)
    archiveSetDetailRow('RowLevel', tostring(info.level))
    archiveSetDetailRow('RowMana', info.mana .. ' / ' .. info.soul)
    archiveSetDetailRow('RowPremium', info.premium and 'yes' or 'no')
end

local function archiveRebuildList()
    local list = UI.InformationBase.selectSpell.SpellListBase.questList
    list:destroyChildren()
    for _, name in ipairs(MagicalArchive.buildSpellNames(SpellInfo[ARCHIVE_PROFILE])) do
        local info = SpellInfo[ARCHIVE_PROFILE][name]
        if MagicalArchive.matchesVocation(info, archiveState.vocationId) and
            MagicalArchive.matchesSearch(name, info, archiveState.search) then
            local row = g_ui.createWidget('ArchiveSpellLabel', list)
            row:setId(name)
            row.spellName = name
            row:setText(name)
            row.onClick = archiveSelectSpell
        end
    end
end

function showMagicalArchives()
    UI = g_ui.loadUI("magicalArchives", contentContainer)
    UI:show()
    controllerCyclopedia.ui.CharmsBase:setVisible(false)
    controllerCyclopedia.ui.GoldBase:setVisible(false)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(false)
    end

    archiveState.vocationId = ARCHIVE_FILTER_VOCATION_ANY
    archiveState.search = ''

    local vocationFilter = UI.InformationBase.selectSpell.VocationFilter
    vocationFilter:addOption(tr('All Vocations'), ARCHIVE_FILTER_VOCATION_ANY)
    vocationFilter:addOption(tr('Sorcerer'), VocationsServer.Sorcerer)
    vocationFilter:addOption(tr('Druid'), VocationsServer.Druid)
    vocationFilter:addOption(tr('Paladin'), VocationsServer.Paladin)
    vocationFilter:addOption(tr('Knight'), VocationsServer.Knight)
    vocationFilter:addOption(tr('Monk'), VocationsServer.Monk)
    vocationFilter.onOptionChange = function(widget, text, data)
        archiveState.vocationId = data
        archiveRebuildList()
    end

    local searchEdit = UI.InformationBase.selectSpell.SearchBase.SearchEdit
    searchEdit.onTextChange = function(widget, text)
        archiveState.search = text
        archiveRebuildList()
    end

    local list = UI.InformationBase.selectSpell.SpellListBase.questList
    connect(list, {
        onChildFocusChange = function(self, focusedChild)
            if focusedChild then
                archiveSelectSpell(focusedChild)
            end
        end
    })

    local detailRows = UI.spellAndRune.DetailPanel.DetailRows
    local captions = {
        RowVocation = tr('Vocation') .. ':',
        RowGroup = tr('Group') .. ':',
        RowType = tr('Type') .. ':',
        RowCooldown = tr('Cooldown') .. ':',
        RowLevel = tr('Level') .. ':',
        RowMana = tr('Mana / Soul') .. ':',
        RowPremium = tr('Premium') .. ':'
    }
    for rowId, caption in pairs(captions) do
        detailRows[rowId].caption:setText(caption)
    end

    archiveRebuildList()
end
