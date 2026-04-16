-- LuaFormatter off
local ExivaData = {
  allowAllExiva        = false,
  allowGuildMember     = false,
  allowPartyMember     = false,
  allowVipList         = false,
  allowCharacterWhiteList = false,
  allowGuildWhiteList  = false,
  characterWhiteList   = {},
  removeCharacter      = {},
  guildWhiteList       = {},
  removeGuild          = {}
}
-- LuaFormatter on

local W = {}
local radioAllowType = nil

local function syncUI()
    if not consoleController.ui or not radioAllowType or not W.allowOnly then
        return
    end
    radioAllowType:selectWidget(ExivaData.allowAllExiva and W.allowAll or W.allowOnly)
    W.guild:setChecked(ExivaData.allowGuildMember)
    W.party:setChecked(ExivaData.allowPartyMember)
    W.vip:setChecked(ExivaData.allowVipList)
    W.charBox:setChecked(ExivaData.allowCharacterWhiteList)
    W.guildBox:setChecked(ExivaData.allowGuildWhiteList)
    W.charText:setText(table.concat(ExivaData.characterWhiteList, "\n"))
    W.guildText:setText(table.concat(ExivaData.guildWhiteList, "\n"))
end

local function onAllowTypeChange(_, selectedWidget)
    local enabled = selectedWidget == W.allowOnly
    local groupWidgets = {W.guild, W.party, W.vip, W.charBox, W.charText, W.guildBox, W.guildText, W.charLabel,
                          W.guildLabel, W.note}
    for _, w in ipairs(groupWidgets) do
        w:setEnabled(enabled)
    end
end

local function parseWhiteList(text, oldList)
    local newList, count = {}, 0
    local overflow = false
    for line in text:gmatch("[^\r\n]+") do
        if count >= 200 then
            overflow = true
            break
        end
        newList[#newList + 1] = line
        count = count + 1
    end
    if overflow then
        return nil, nil, true
    end
    local lookup = {}
    for _, v in ipairs(newList) do
        lookup[v] = true
    end
    local removed = {}
    for _, v in ipairs(oldList) do
        if not lookup[v] then
            removed[#removed + 1] = v
        end
    end
    return newList, removed, false
end

local function collectData()
    local newChars, removedChars, errChars = parseWhiteList(W.charText:getText(), ExivaData.characterWhiteList)
    if errChars then
        return false, "Character whitelist exceeds the maximum allowed 200 lines."
    end

    local newGuilds, removedGuilds, errGuilds = parseWhiteList(W.guildText:getText(), ExivaData.guildWhiteList)
    if errGuilds then
        return false, "Guild whitelist exceeds the maximum allowed 200 lines."
    end

    ExivaData.characterWhiteList = newChars
    ExivaData.removeCharacter = removedChars
    ExivaData.guildWhiteList = newGuilds
    ExivaData.removeGuild = removedGuilds
    ExivaData.allowGuildMember = W.guild:isChecked()
    ExivaData.allowPartyMember = W.party:isChecked()
    ExivaData.allowVipList = W.vip:isChecked()
    ExivaData.allowCharacterWhiteList = W.charBox:isChecked()
    ExivaData.allowGuildWhiteList = W.guildBox:isChecked()
    local sel = radioAllowType:getSelectedWidget()
    ExivaData.allowAllExiva = sel == W.allowAll
    return true
end

local function sendExiva()
    g_game.sendExivaOptions(ExivaData.allowAllExiva, ExivaData.allowGuildMember, ExivaData.allowPartyMember,
        ExivaData.allowVipList, ExivaData.allowCharacterWhiteList, ExivaData.allowGuildWhiteList,
        ExivaData.characterWhiteList, ExivaData.removeCharacter, ExivaData.guildWhiteList, ExivaData.removeGuild)
end

function consoleController:openWindow()
    if self.ui then
        self.ui:raise()
        self.ui:focus()
        return
    end
    self:loadHtml("exiva_option.html")
    -- LuaFormatter off
    W = {
        allowAll          = self:findWidget('#allowAllCheckBox'),
        allowOnly         = self:findWidget('#allowOnlyCheckBox'),
        guild             = self:findWidget('#membersOfGuildCheckBox'),
        party             = self:findWidget('#membersOfPartyCheckBox'),
        vip               = self:findWidget('#allVipCheckBox'),
        charBox           = self:findWidget('#charWhiteListCheckBox'),
        charText          = self:findWidget('#charWhiteListTextEdit'),
        charLabel         = self:findWidget('#charWhiteListLabel'),
        guildBox          = self:findWidget('#guildWhiteListCheckBox'),
        guildText         = self:findWidget('#guildWhiteListTextEdit'),
        guildLabel        = self:findWidget('#guildWhiteListLabel'),
        note              = self:findWidget('#noteLabel'),
    }
-- LuaFormatter on
    local group = UIRadioGroup.create()
    group:addWidget(W.allowAll)
    group:addWidget(W.allowOnly)
    group.onSelectionChange = onAllowTypeChange
    radioAllowType = group
    syncUI()
    self.ui:raise()
    self.ui:focus()
end

function consoleController:closeWindowExiva()
    if self.ui then
        self:unloadHtml()
    end
    W = {}
    radioAllowType = nil
end

function consoleController:toggle()
    if self.ui then
        self:closeWindowExiva()
    else
        self:openWindow()
    end
end

function consoleController:onApply()
    local success, err = collectData()
    if not success then
        displayErrorBox(tr("Error"), tr(err))
        return
    end
    sendExiva()
end

function consoleController:onOkay()
    local success, err = collectData()
    if not success then
        displayErrorBox(tr("Error"), tr(err))
        return
    end
    sendExiva()
    self:closeWindowExiva()
end

function onReceiveExivaOptions(allowAllExiva, allowGuildMember, allowPartyMember, allowVipList, allowCharacterWhiteList,
    allowGuildWhiteList, characterWhiteList, removeCharacter, guildWhiteList, removeGuild)
    ExivaData.allowAllExiva = allowAllExiva
    ExivaData.allowGuildMember = allowGuildMember
    ExivaData.allowPartyMember = allowPartyMember
    ExivaData.allowVipList = allowVipList
    ExivaData.allowCharacterWhiteList = allowCharacterWhiteList
    ExivaData.allowGuildWhiteList = allowGuildWhiteList
    ExivaData.characterWhiteList = characterWhiteList
    ExivaData.removeCharacter = removeCharacter
    ExivaData.guildWhiteList = guildWhiteList
    ExivaData.removeGuild = removeGuild
    if consoleController.ui then
        syncUI()
    end
end

function onRequestExivaOptions()
    consoleController:openWindow()
end
