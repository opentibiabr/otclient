setDefaultTab("Main")
local panelName = "newHealer"
local ui = setupUI([[
Panel
  height: 19

  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr('Friend Healer')

  Button
    id: edit
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Setup

]])
ui:setId(panelName)

-- validate current settings
if not storage[panelName] or not storage[panelName].priorities then
    storage[panelName] = nil
end

-- backfill monks condition for existing configs
if storage[panelName] and storage[panelName].conditions and storage[panelName].conditions.monks == nil then
    storage[panelName].conditions.monks = true
end

if not storage[panelName] then
    storage[panelName] = {
        enabled = false,
        customPlayers = {},
        vocations = {},
        groups = {},
        priorities = {

            {name="Custom Spell",           enabled=false, custom=true},
            {name="Exura Gran Sio",         enabled=true, strong = true},
            {name="Exura Sio",              enabled=true, normal = true},
            {name="Exura Gran Mas Res",     enabled=true, area = true},
            {name="Health Item",            enabled=true, health=true},
            {name="Mana Item",              enabled=true, mana=true}

        },
        settings = {

            {type="HealItem",       text="Mana Item ",                   value=268},
            {type="HealScroll",     text="Item Range: ",                 value=6},
            {type="HealItem",       text="Health Item ",                 value=3160},
            {type="HealScroll",     text="Mas Res Players: ",            value=2},
            {type="HealScroll",     text="Heal Friend at: ",             value=80},
            {type="HealScroll",     text="Use Gran Sio at: ",            value=30},
            {type="HealScroll",     text="Min Player HP%: ",             value=90},
            {type="HealScroll",     text="Min Player MP%: ",             value=30},

        },
        conditions = {
            knights = true,
            paladins = true,
            druids = false,
            sorcerers = false,
            monks = true,
            party = true,
            guild = false,
            --botserver = false,
            friends = false
        }
    }
end

local config = storage[panelName]
local healerWindow = UI.createWindow('FriendHealer')
healerWindow:hide()
healerWindow:setId(panelName)

ui.title:setOn(config.enabled)
ui.title.onClick = function(widget)
    config.enabled = not config.enabled
    widget:setOn(config.enabled)
end

ui.edit.onClick = function()
    healerWindow:show()
    healerWindow:raise()
    healerWindow:focus()
end

local conditions = healerWindow.conditions
local targetSettings = healerWindow.targetSettings
local customList = healerWindow.customList
local priority = healerWindow.priority

-- customList
-- create entries on the list
for name, health in pairs(config.customPlayers) do
    local widget = UI.createWidget("HealerPlayerEntry", customList.playerList.list)
    widget.remove.onClick = function()
        config.customPlayers[name] = nil
        widget:destroy()
    end
    widget:setText("["..health.."%]  "..name)
end

customList.playerList.onDoubleClick = function()
    customList.playerList:hide()
end

local function clearFields()
    customList.addPanel.name:setText("friend name")
    customList.addPanel.health:setText("1")
    customList.playerList:show()
end

local function capitalFistLetter(str)
    return (string.gsub(str, "^%l", string.upper))
  end

customList.addPanel.add.onClick = function()
    local name = ""
    local words = string.split(customList.addPanel.name:getText(), " ")
    local health = tonumber(customList.addPanel.health:getText())
    for i, word in ipairs(words) do
      name = name .. " " .. capitalFistLetter(word)
    end

    if not health then
        clearFields()
        return warn("[Friend Healer] Please enter health percent value!")
    end

    if name:len() == 0 or name:lower() == "friend name" then
        clearFields()
        return warn("[Friend Healer] Please enter friend name to be added!")
    end

    if config.customPlayers[name] or config.customPlayers[name:lower()] then
        clearFields()
        return warn("[Friend Healer] Player already added to custom list.")
    else
        config.customPlayers[name] = health
        local widget = UI.createWidget("HealerPlayerEntry", customList.playerList.list)
        widget.remove.onClick = function()
            config.customPlayers[name] = nil
            widget:destroy()
        end
        widget:setText("["..health.."%]  "..name)
    end

    clearFields()
end

local function validate(widget, category)
    local list = widget:getParent()
    local label = list:getParent().title
    -- 1 - priorities | 2 - vocation
    category = category or 0

    if category == 2 and not storage.extras.checkPlayer then
        label:setColor("#d9321f")
        label:setTooltip("! WARNING ! \nTurn on check players in extras to use this feature!")
        return
    else
        label:setColor("#dfdfdf")
        label:setTooltip("")
    end

    local checked = false
    for i, child in ipairs(list:getChildren()) do
        if category == 1 and child.enabled:isChecked() or child:isChecked() then
            checked = true
        end
    end

    if not checked then
        label:setColor("#d9321f")
        label:setTooltip("! WARNING ! \nNo category selected!")
    else
        label:setColor("#dfdfdf")
        label:setTooltip("")
    end
end
-- targetSettings
targetSettings.vocations.box.knights:setChecked(config.conditions.knights)
targetSettings.vocations.box.knights.onClick = function(widget)
    config.conditions.knights = not config.conditions.knights
    widget:setChecked(config.conditions.knights)
    validate(widget, 2)
end

targetSettings.vocations.box.paladins:setChecked(config.conditions.paladins)
targetSettings.vocations.box.paladins.onClick = function(widget)
    config.conditions.paladins = not config.conditions.paladins
    widget:setChecked(config.conditions.paladins)
    validate(widget, 2)
end

targetSettings.vocations.box.druids:setChecked(config.conditions.druids)
targetSettings.vocations.box.druids.onClick = function(widget)
    config.conditions.druids = not config.conditions.druids
    widget:setChecked(config.conditions.druids)
    validate(widget, 2)
end

targetSettings.vocations.box.sorcerers:setChecked(config.conditions.sorcerers)
targetSettings.vocations.box.sorcerers.onClick = function(widget)
    config.conditions.sorcerers = not config.conditions.sorcerers
    widget:setChecked(config.conditions.sorcerers)
    validate(widget, 2)
end

targetSettings.vocations.box.monks:setChecked(config.conditions.monks)
targetSettings.vocations.box.monks.onClick = function(widget)
    config.conditions.monks = not config.conditions.monks
    widget:setChecked(config.conditions.monks)
    validate(widget, 2)
end

targetSettings.groups.box.friends:setChecked(config.conditions.friends)
targetSettings.groups.box.friends.onClick = function(widget)
    config.conditions.friends = not config.conditions.friends
    widget:setChecked(config.conditions.friends)
    validate(widget)
end

targetSettings.groups.box.party:setChecked(config.conditions.party)
targetSettings.groups.box.party.onClick = function(widget)
    config.conditions.party = not config.conditions.party
    widget:setChecked(config.conditions.party)
    validate(widget)
end

targetSettings.groups.box.guild:setChecked(config.conditions.guild)
targetSettings.groups.box.guild.onClick = function(widget)
    config.conditions.guild = not config.conditions.guild
    widget:setChecked(config.conditions.guild)
    validate(widget)
end
targetSettings.groups.box.botserver:hide()
--targetSettings.groups.box.botserver:setChecked(config.conditions.botserver)
--targetSettings.groups.box.botserver.onClick = function(widget)
--    config.conditions.botserver = not config.conditions.botserver
--    widget:setChecked(config.conditions.botserver)
--    validate(widget)
--end

validate(targetSettings.vocations.box.knights)
validate(targetSettings.groups.box.friends)
validate(targetSettings.vocations.box.sorcerers, 2)

-- conditions
for i, setting in ipairs(config.settings) do
    local widget = UI.createWidget(setting.type, conditions.box)
    local text = setting.text
    local val = setting.value
    widget.text:setText(text)

    if setting.type == "HealScroll" then
        widget.text:setText(widget.text:getText()..val)
        if not (text:find("Range") or text:find("Mas Res")) then
            widget.text:setText(widget.text:getText().."%")
        end
        widget.scroll:setValue(val)
        widget.scroll.onValueChange = function(scroll, value)
            setting.value = value
            widget.text:setText(text..value)
            if not (text:find("Range") or text:find("Mas Res")) then
                widget.text:setText(widget.text:getText().."%")
            end
        end
        if text:find("Range") or text:find("Mas Res") then
            widget.scroll:setMaximum(10)
        end
    else
        widget.item:setItemId(val)
        widget.item:setShowCount(false)
        widget.item.onItemChange = function(widget)
            setting.value = widget:getItemId()
        end
    end
end

-- priority and toggles
local function setCrementalButtons()
    for i, child in ipairs(priority.list:getChildren()) do
        if i == 1 then
            child.increment:disable()
        elseif i == 6 then
            child.decrement:disable()
        else
            child.increment:enable()
            child.decrement:enable()
        end
    end
end

for i, action in ipairs(config.priorities) do
    local widget = UI.createWidget("PriorityEntry", priority.list)

    widget:setText(action.name)
    widget.increment.onClick = function()
        local index = priority.list:getChildIndex(widget)
        local table = config.priorities

        priority.list:moveChildToIndex(widget, index-1)
        table[index], table[index-1] = table[index-1], table[index]
        setCrementalButtons()
    end
    widget.decrement.onClick = function()
        local index = priority.list:getChildIndex(widget)
        local table = config.priorities

        priority.list:moveChildToIndex(widget, index+1)
        table[index], table[index+1] = table[index+1], table[index]
        setCrementalButtons()
    end
    widget.enabled:setChecked(action.enabled)
    widget:setColor(action.enabled and "#98BF64" or "#dfdfdf")
    widget.enabled.onClick = function()
        action.enabled = not action.enabled
        widget:setColor(action.enabled and "#98BF64" or "#dfdfdf")
        widget.enabled:setChecked(action.enabled)
        validate(widget, 1)
    end
    if action.custom then
        widget.onDoubleClick = function()
            local window = modules.client_textedit.show(widget, {title = "Custom Spell", description = "Enter below formula for a custom healing spell"})
            schedule(50, function()
              window:raise()
              window:focus()
            end)
        end
        widget.onTextChange = function(widget,text)
            action.name = text
        end
        widget:setTooltip("Double click to set spell formula.")
    end

    if i == #config.priorities then
        validate(widget, 1)
        setCrementalButtons()
    end
end

local lastItemUse = now
local lastStrongHeal = 0
local lastMasRes = 0
local lastSio = 0
local function friendHealerAction(spec, targetsInRange)
    local name = spec:getName()
    local health = spec:getHealthPercent()
    local mana = spec:getManaPercent()
    local dist = distanceFromPlayer(spec:getPosition())
    targetsInRange = targetsInRange or 0

    local masResAmount = config.settings[4].value
    local itemRange = config.settings[2].value
    local healItem = config.settings[3].value
    local manaItem = config.settings[1].value
    local normalHeal = config.customPlayers[name] or config.settings[5].value
    local strongHeal = config.customPlayers[name] and normalHeal/2 or config.settings[6].value

    for i, action in ipairs(config.priorities) do
        if action.enabled then
            if action.area and masResAmount <= targetsInRange and now > lastMasRes then
                lastMasRes = now + 2000
                return say("exura gran mas res")
            end
            if action.mana and findItem(manaItem) and mana <= normalHeal and dist <= itemRange and now - lastItemUse > 1000 then
                lastItemUse = now
                return useWith(manaItem, spec)
            end
            if action.health and findItem(healItem) and health <= normalHeal and dist <= itemRange and now - lastItemUse > 1000 then
                lastItemUse = now
                return useWith(healItem, spec)
            end
            if action.strong and health <= strongHeal and now > lastStrongHeal then
                lastStrongHeal = now + 60000
                return say('exura gran sio "'..name)
            end
            if (action.normal or action.custom) and health <= normalHeal and now > lastSio then
                lastSio = lastSio + 1000
                return say('exura sio "'..name)
            end
        end
    end
end

local function isCandidate(spec)
    if spec:isLocalPlayer() or not spec:isPlayer() then
        return nil
    end
    if not spec:canShoot() then
        return false
    end

    local curHp = spec:getHealthPercent()
    if curHp == 100 or (config.customPlayers[name] and curHp > config.customPlayers[name]) then
        return false
    end

    local specText = spec:getText()
    local name = spec:getName()
    -- check players is enabled and spectator already verified
    if storage.extras.checkPlayer and specText:len() > 0 then
        if specText:find("EK") and not config.conditions.knights or
           specText:find("RP") and not config.conditions.paladins or
           specText:find("ED") and not config.conditions.druids or
           specText:find("MS") and not config.conditions.sorcerers or
           specText:find("EM") and not config.conditions.monks then
           if not config.customPlayers[name] then
               return nil
           end
        end
    end

    if not table.find(storage.playerList.friendList, name, true) then
        return nil
    end
    
    local okParty = config.conditions.party and spec:isPartyMember()
    local okFriend = config.conditions.friends and isFriend(spec)
    local okGuild = config.conditions.guild and spec:getEmblem() == 1
   -- local okBotServer = config.conditions.botserver and vBot.BotServerMembers[spec:getName()]

   -- if not (okParty or okFriend or okGuild or okBotServer) then
    if not (okParty or okFriend or okGuild) then
        return nil
    end

    local health = config.customPlayers[name] and curHp/2 or curHp
    local dist = distanceFromPlayer(spec:getPosition())

    return health, dist
end

macro(100, function()
    if not config.enabled then return end
 --   if modules.game_cooldown.isGroupCooldownIconActive(2) then return end

    local minHp = config.settings[7].value
    local minMp = config.settings[8].value

    local healTarget = {creature=nil, hp=100}
    local inMasResRange = 0

    -- check basic
    if hppercent() <= minHp or manapercent() <= minMp then return end

    -- get all spectators
    local spectators = getSpectators(posz())

    -- main check

    for i, spec in ipairs(spectators) do
        local health, dist = isCandidate(spec)
        --mas san
        if dist then
            inMasResRange = dist <= 3 and inMasResRange+1 or inMasResRange

            -- best target
            if health <= healTarget.hp then
                healTarget = {creature = spec, hp = health}
            end
        end
    end

    -- action
    if healTarget.creature then
        return friendHealerAction(healTarget.creature, inMasResRange)
    end
end)
