local UI = nil
local TypeCharmRadioGroup = nil
Cyclopedia.Charms = {}
local charmCategory_t = {
    CHARM_ALL = 0,
    CHARM_MAJOR = 1,
    CHARM_MINOR = 2
};

local charm_t = {
    CHARM_UNDEFINED = 0,
    CHARM_OFFENSIVE = 1,
    CHARM_DEFENSIVE = 2,
    CHARM_PASSIVE = 3
};
local charmRune_t = {
    CHARM_WOUND = 0,
    CHARM_ENFLAME = 1,
    CHARM_POISON = 2,
    CHARM_FREEZE = 3,
    CHARM_ZAP = 4,
    CHARM_CURSE = 5,
    CHARM_CRIPPLE = 6,
    CHARM_PARRY = 7,
    CHARM_DODGE = 8,
    CHARM_ADRENALINE = 9,
    CHARM_NUMB = 10,
    CHARM_CLEANSE = 11,
    CHARM_BLESS = 12,
    CHARM_SCAVENGE = 13,
    CHARM_GUT = 14,
    CHARM_LOW = 15,
    CHARM_DIVINE = 16,
    CHARM_VAMP = 17,
    CHARM_VOID = 18,
    CHARM_SAVAGE = 19,
    CHARM_FATAL = 20,
    CHARM_VOIDINVERSION = 21,
    CHARM_CARNAGE = 22,
    CHARM_OVERPOWER = 23,
    CHARM_OVERFLUX = 24
}

local charms = {
    [charmRune_t.CHARM_WOUND] = {
        name = "Wound",
        description = "Triggers on a creature with a chance to deal 5% of its initial HP as physical damage.",
        category = charmCategory_t.CHARM_MAJOR,
        type = charm_t.CHARM_OFFENSIVE,
        percent = 5,
        chance = {5, 10, 11},
        points = {240, 360, 1200}
    },
    [charmRune_t.CHARM_ENFLAME] = {
        name = "Enflame",
        description = "Triggers on a creature with a chance to deal 5% of its initial HP as fire damage.",
        category = charmCategory_t.CHARM_MAJOR,
        type = charm_t.CHARM_OFFENSIVE,
        percent = 5,
        chance = {5, 10, 11},
        points = {400, 600, 2000}
    },
    [charmRune_t.CHARM_POISON] = {
        name = "Poison",
        description = "Triggers on a creature with a chance to deal 5% of its initial HP as earth damage.",
        category = charmCategory_t.CHARM_MAJOR,
        type = charm_t.CHARM_OFFENSIVE,
        percent = 5,
        chance = {5, 10, 11},
        points = {240, 360, 1200}
    },
    [charmRune_t.CHARM_FREEZE] = {
        name = "Freeze",
        description = "Triggers on a creature with a chance to deal 5% of its initial HP as ice damage.",
        category = charmCategory_t.CHARM_MAJOR,
        type = charm_t.CHARM_OFFENSIVE,
        percent = 5,
        chance = {5, 10, 11},
        points = {320, 480, 1600}
    },
    [charmRune_t.CHARM_ZAP] = {
        name = "Zap",
        description = "Triggers on a creature with a chance to deal 5% of its initial HP as energy damage.",
        category = charmCategory_t.CHARM_MAJOR,
        type = charm_t.CHARM_OFFENSIVE,
        percent = 5,
        chance = {5, 10, 11},
        points = {320, 480, 1600}
    },
    [charmRune_t.CHARM_CURSE] = {
        name = "Curse",
        description = "Triggers on a creature with a chance to deal 5% of its initial HP as death damage.",
        category = charmCategory_t.CHARM_MAJOR,
        type = charm_t.CHARM_OFFENSIVE,
        percent = 5,
        chance = {5, 10, 11},
        points = {360, 540, 1800}
    },
    [charmRune_t.CHARM_CRIPPLE] = {
        name = "Cripple",
        description = "Cripples the creature and paralyzes it for 10 seconds.",
        category = charmCategory_t.CHARM_MINOR,
        type = charm_t.CHARM_OFFENSIVE,
        chance = {6, 9, 12},
        messageCancel = "You crippled a monster. (cripple charm)",
        points = {100, 150, 225}
    },
    [charmRune_t.CHARM_PARRY] = {
        name = "Parry",
        description = "Reflects incoming damage back to the aggressor.",
        category = charmCategory_t.CHARM_MAJOR,
        type = charm_t.CHARM_DEFENSIVE,
        chance = {5, 10, 11},
        messageCancel = "You parried an attack. (parry charm)",
        points = {400, 600, 2000}
    },
    [charmRune_t.CHARM_DODGE] = {
        name = "Dodge",
        description = "Dodges an attack with a chance, avoiding all damage.",
        category = charmCategory_t.CHARM_MAJOR,
        type = charm_t.CHARM_DEFENSIVE,
        chance = {5, 10, 11},
        messageCancel = "You dodged an attack. (dodge charm)",
        points = {240, 360, 1200}
    },
    [charmRune_t.CHARM_ADRENALINE] = {
        name = "Adrenaline Burst",
        description = "Boosts movement speed for 10 seconds after being hit.",
        category = charmCategory_t.CHARM_MINOR,
        type = charm_t.CHARM_DEFENSIVE,
        chance = {6, 9, 12},
        messageCancel = "Your movements where bursted. (adrenaline burst charm)",
        points = {100, 150, 225}
    },
    [charmRune_t.CHARM_NUMB] = {
        name = "Numb",
        description = "Numbs the creature and paralyzes it for 10 seconds.",
        category = charmCategory_t.CHARM_MINOR,
        type = charm_t.CHARM_DEFENSIVE,
        chance = {6, 9, 12},
        messageCancel = "You numbed a monster. (numb charm)",
        points = {100, 150, 225}
    },
    [charmRune_t.CHARM_CLEANSE] = {
        name = "Cleanse",
        description = "Removes a negative status effect and grants temporary immunity.",
        category = charmCategory_t.CHARM_MINOR,
        type = charm_t.CHARM_DEFENSIVE,
        chance = {6, 9, 12},
        messageCancel = "You purified an attack. (cleanse charm)",
        points = {100, 150, 225}
    },
    [charmRune_t.CHARM_BLESS] = {
        name = "Bless",
        description = "Reduces skill and XP loss by 10% when killed by the chosen creature.",
        category = charmCategory_t.CHARM_MINOR,
        type = charm_t.CHARM_PASSIVE,
        percent = 10,
        chance = {6, 9, 12},
        points = {100, 150, 225}
    },
    [charmRune_t.CHARM_SCAVENGE] = {
        name = "Scavenge",
        description = "Enhances chances to successfully skin or dust a creature.",
        category = charmCategory_t.CHARM_MINOR,
        type = charm_t.CHARM_PASSIVE,
        chance = {60, 90, 120},
        points = {100, 150, 225}
    },
    [charmRune_t.CHARM_GUT] = {
        name = "Gut",
        description = "Increases creature product yields by 20%.",
        category = charmCategory_t.CHARM_MINOR,
        type = charm_t.CHARM_PASSIVE,
        chance = {6, 9, 12},
        points = {100, 150, 225}
    },
    [charmRune_t.CHARM_LOW] = {
        name = "Low Blow",
        description = "Adds 8% critical hit chance to attacks with critical hit weapons.",
        category = charmCategory_t.CHARM_MAJOR,
        type = charm_t.CHARM_PASSIVE,
        chance = {4, 8, 9},
        points = {800, 1200, 4000}
    },
    [charmRune_t.CHARM_DIVINE] = {
        name = "Divine Wrath",
        description = "Triggers on a creature and deals 5% of its initial HP as holy damage.",
        category = charmCategory_t.CHARM_MAJOR,
        type = charm_t.CHARM_OFFENSIVE,
        percent = 5,
        chance = {5, 10, 11},
        points = {600, 900, 3000}
    },
    [charmRune_t.CHARM_VAMP] = {
        name = "Vampiric Embrace",
        description = "Adds 4% life leech to attacks if using life-leeching equipment.",
        category = charmCategory_t.CHARM_MINOR,
        type = charm_t.CHARM_PASSIVE,
        chance = {1.6, 2.4, 3.2},
        points = {100, 150, 225}
    },
    [charmRune_t.CHARM_VOID] = {
        name = "Void's Call",
        description = "Adds 2% mana leech to attacks if using mana-leeching equipment.",
        category = charmCategory_t.CHARM_MINOR,
        type = charm_t.CHARM_PASSIVE,
        chance = {0.8, 1.2, 1.6},
        points = {100, 150, 225}
    },
    [charmRune_t.CHARM_SAVAGE] = {
        name = "Savage Blow",
        description = "Adds extra critical damage to attacks with critical hit weapons.",
        category = charmCategory_t.CHARM_MAJOR,
        type = charm_t.CHARM_PASSIVE,
        chance = {20, 40, 44},
        points = {800, 1200, 4000}
    },
    [charmRune_t.CHARM_FATAL] = {
        name = "Fatal Hold",
        description = "Prevents creatures from fleeing due to low health for 30 seconds.",
        category = charmCategory_t.CHARM_MINOR,
        type = charm_t.CHARM_PASSIVE,
        chance = {30, 45, 60},
        messageCancel = "Your enemy is not able to flee now for 30 seconds. (fatal hold charm)",
        points = {100, 150, 225}
    },
    [charmRune_t.CHARM_VOIDINVERSION] = {
        name = "Void Inversion",
        description = "Chance to gain mana instead of losing it when taking Mana Drain damage.",
        category = charmCategory_t.CHARM_MINOR,
        type = charm_t.CHARM_PASSIVE,
        chance = {20, 30, 40},
        points = {100, 150, 225}
    },
    [charmRune_t.CHARM_CARNAGE] = {
        name = "Carnage",
        description = "Killing a monster deals physical damage to others nearby.",
        category = charmCategory_t.CHARM_MAJOR,
        type = charm_t.CHARM_OFFENSIVE,
        percent = 15,
        chance = {10, 20, 22},
        points = {600, 900, 3000}
    },
    [charmRune_t.CHARM_OVERPOWER] = {
        name = "Overpower",
        description = "Deals physical damage based on your maximum health.",
        category = charmCategory_t.CHARM_MAJOR,
        type = charm_t.CHARM_OFFENSIVE,
        percent = 5,
        chance = {5, 10, 11},
        points = {600, 900, 3000}
    },
    [charmRune_t.CHARM_OVERFLUX] = {
        name = "Overflux",
        description = "Deals physical damage based on your maximum mana.",
        category = charmCategory_t.CHARM_MAJOR,
        type = charm_t.CHARM_OFFENSIVE,
        percent = 2.5,
        chance = {5, 10, 11},
        points = {600, 900, 3000}
    }
}

local isModernUI = false
function showCharms()
    isModernUI = g_game.getClientVersion() >= 1410
    local UIUX = isModernUI and "charms1410" or "charms"
    UI = g_ui.loadUI(UIUX, contentContainer)
    UI:show()
    g_game.requestBestiary()
    controllerCyclopedia.ui.CharmsBase:setVisible(true)
    controllerCyclopedia.ui.GoldBase:setVisible(true)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if isModernUI then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(true)
        TypeCharmRadioGroup = UIRadioGroup.create()
        TypeCharmRadioGroup:addWidget(UI.mainPanelCharmsType.typeCharmPanel.MajorCharms)
        TypeCharmRadioGroup:addWidget(UI.mainPanelCharmsType.typeCharmPanel.MinorCharms)
        TypeCharmRadioGroup:selectWidget(TypeCharmRadioGroup:getFirstWidget())
        connect(TypeCharmRadioGroup, {
            onSelectionChange = onTypeCharmRadioGroup
        })
    end
end

function onTerminateCharm()
    if TypeCharmRadioGroup then
        disconnect(TypeCharmRadioGroup, {
            onSelectionChange = onTypeCharmRadioGroup
        })
        TypeCharmRadioGroup:destroy()
        TypeCharmRadioGroup = nil
    end
end

function Cyclopedia.CreateCharmItem(data)
    local CharmList = isModernUI and UI.mainPanelCharmsType.panelCharmList.CharmList or UI.CharmList
    local widget = g_ui.createWidget("CharmItem", CharmList)
    local value = widget.PriceBase.Value

    widget:setId(data.id)
    widget.charmBase.image:setImageSource("/game_cyclopedia/images/charms/monster-bonus-effects")

    if data.id ~= nil then
        widget.charmBase.image:setImageClip((data.id * 32) .. ' 0 32 32')
    else
        g_logger.error(string.format("Cyclopedia.CreateCharmItem - charm %s is nil", data.id))
        return
    end

    local charmData = charms[data.id]
    widget:setText(isModernUI and charmData.name or data.name)
    widget.data = data

    if data.asignedStatus then
        if data.raceId then
            local raceData = g_things.getRaceData(data.raceId)
            widget.InfoBase.Sprite:setOutfit(raceData.outfit)
            widget.InfoBase.Sprite:getCreature():setStaticWalking(1000)
        else
            g_logger.error("Cyclopedia.CreateCharmItem - no race id provided")
        end
    end

    local isUnlocked = data.tier > 0 or data.unlocked
    if not isModernUI then
        widget.PriceBase.Charm:setVisible(not isUnlocked)
        widget.PriceBase.Gold:setVisible(isUnlocked)
    end
    widget.charmBase.lockedMask:setVisible(not isUnlocked)
    widget.icon = isUnlocked and 1 or 0

    if isUnlocked then
        widget.PriceBase.Value:setText(data.asignedStatus and comma_value(data.removeRuneCost) or 0)
    else
        widget.PriceBase.Value:setText(comma_value(data.unlockPrice))
    end

    local player = g_game.getLocalPlayer()
    if widget.icon == 1 and player:getTotalMoney() then
        local canAfford = data.removeRuneCost <= player:getTotalMoney()
        value:setColor(canAfford and "#C0C0C0" or "#D33C3C")
    elseif widget.icon == 0 then
        local canAfford = data.unlockPrice <= UI.CharmsPoints
        value:setColor(canAfford and "#C0C0C0" or "#D33C3C")
    end

    widget.category = charmData.category

    if isModernUI and data.tier > 0 then
        widget.charmBase.border:setImageSource("/game_cyclopedia/images/charms/border/backdrop_charmgrade" .. data.tier)
    end
end

function Cyclopedia.loadCharms(charmsData)
    if not UI then
        return
    end
    if isModernUI and not UI.mainPanelCharmsType then
        return
    end
    local CharmList = isModernUI and UI.mainPanelCharmsType.panelCharmList.CharmList or UI.CharmList
    local player = g_game.getLocalPlayer()
    if not CharmList then
        return
    end
    if isModernUI then
        local formatResourceBalance = function(resourceType, maxResourceType)
            return string.format("%d/%d", player:getResourceBalance(resourceType),
                player:getResourceBalance(maxResourceType))
        end

        controllerCyclopedia.ui.CharmsBase.Value:setText(formatResourceBalance(ResourceTypes.CHARM,
            ResourceTypes.MAX_CHARM))
        controllerCyclopedia.ui.CharmsBase1410.Value:setText(
            formatResourceBalance(ResourceTypes.MINOR_CHARM, ResourceTypes.MAX_MINOR_CHARM))
        local canAfford = charmsData.resetAllCharmsCost <= player:getTotalMoney()
        UI.anotherPanel.CharmsBase1410.Value:setText(Cyclopedia.formatGold(charmsData.resetAllCharmsCost))
        UI.anotherPanel.CharmsBase1410.Value:setColor(canAfford and "#BDBDBD" or "#D33C3C")
        UI.anotherPanel.resetAllButton:setEnabled(canAfford)
    else
        controllerCyclopedia.ui.CharmsBase.Value:setText(Cyclopedia.formatGold(charmsData.points))
    end

    UI.CharmsPoints = charmsData.points
    UI.resetAllCharmsCost = charmsData.resetAllCharmsCost

    Cyclopedia.Charms.Monsters = {}
    local raceIdNamePairs = {}

    for _, raceId in ipairs(charmsData.finishedMonsters) do
        local raceData = g_things.getRaceData(raceId)
        local raceName = raceData.name ~= "" and raceData.name or string.format("unnamed_%d", raceId)
        table.insert(raceIdNamePairs, {
            raceId = raceId,
            name = raceName
        })
    end

    table.sort(raceIdNamePairs, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    for _, pair in ipairs(raceIdNamePairs) do
        table.insert(Cyclopedia.Charms.Monsters, pair.raceId)
    end

    CharmList:destroyChildren()

    local formattedData = {}
    for _, charmData in pairs(charmsData.charms) do
        local internalId = charmData.id
        if internalId and charms[internalId] then
            local charm = charms[internalId]
            charmData.name = charmData.name ~= "" and charmData.name or charm.name
            charmData.description = charmData.description ~= "" and charmData.description or charm.description
            charmData.internalId = internalId
            charmData.typePriority = charm.type
            charmData.category = charm.category
            table.insert(formattedData, charmData)
        end
    end

    if isModernUI then
        table.sort(formattedData, function(a, b)
            local tierA, tierB = a.tier or 0, b.tier or 0
            if tierA ~= tierB then
                return tierA > tierB
            end
            return a.name:lower() < b.name:lower()
        end)
    else
        table.sort(formattedData, function(a, b)
            if a.unlocked ~= b.unlocked then
                return a.unlocked and not b.unlocked
            end
            return a.name:lower() < b.name:lower()
        end)
    end

    for _, value in ipairs(formattedData) do
        if value and value.name and value.description and value.internalId and value.typePriority then
            local success, error = pcall(Cyclopedia.CreateCharmItem, value)
            if not success then
                g_logger.error(string.format("Error creating charm item: %s for charm ID: %s (%s)", error,
                    tostring(value.internalId), tostring(value.name)))
            end
        else
            g_logger.error(string.format("Incomplete charm data: ID: %s",
                value and tostring(value.internalId or "unknown") or "nil"))
        end
    end

    if isModernUI then
        local selectedWidget = TypeCharmRadioGroup:getSelectedWidget()
        if selectedWidget then
            local charmCategory = selectedWidget:getId() == "MajorCharms" and charmCategory_t.CHARM_MAJOR or
                                      charmCategory_t.CHARM_MINOR

            for _, widget in ipairs(CharmList:getChildren()) do
                widget:setVisible(widget.category == charmCategory)
            end

            CharmList:getLayout():update()
        end
    end

    local firstCharm = Cyclopedia.Charms.redirect and CharmList:getChildById(Cyclopedia.Charms.redirect) or
                           CharmList:getChildByIndex(1)

    if firstCharm then
        Cyclopedia.selectCharm(firstCharm, firstCharm:isChecked())
        Cyclopedia.Charms.redirect = nil
    end
end

local function getUIBase()
    if isModernUI then
        return {
            CreatureList = UI.InformationBase.PanelCreatureList.CreaturesBase.CreatureList,
            InfoBase = UI.InformationBase.panelSelectCreature.InfoBase,
            TextBase = UI.InformationBase.TextBase,
            ItemBase = UI.InformationBase.ItemBase,
            PriceBase = UI.InformationBase.verticalPanelUnLockClearChram.PriceBaseGold,
            UnlockButton = UI.InformationBase.verticalPanelUnLockClearChram.UnlockButton,
            SearchEdit = UI.InformationBase.PanelCreatureList.SearchPanel.SearchEdit,
            SearchLabel = UI.InformationBase.SearchLabel,
            CreaturesBase = UI.InformationBase.PanelCreatureList.CreaturesBase,
            CreaturesLabel = UI.InformationBase.panelSelectCreature.CreaturesLabel
        }
    else
        return {
            CreatureList = UI.InformationBase.CreaturesBase.CreatureList,
            InfoBase = UI.InformationBase.InfoBase,
            TextBase = UI.InformationBase.TextBase,
            ItemBase = UI.InformationBase.ItemBase,
            PriceBase = UI.InformationBase.PriceBase,
            UnlockButton = UI.InformationBase.UnlockButton,
            SearchEdit = UI.InformationBase.SearchEdit,
            SearchLabel = UI.InformationBase.SearchLabel,
            CreaturesBase = UI.InformationBase.CreaturesBase,
            CreaturesLabel = UI.InformationBase.CreaturesLabel
        }
    end
end

local function formatCreatureName(text)
    local capitalizedText = text:gsub("(%l)(%w*)", function(first, rest)
        return first:upper() .. rest
    end)
    return #capitalizedText > 19 and capitalizedText:sub(1, 16) .. "..." or capitalizedText
end

local function updateUIColors(widget, UI_BASE)
    local player = g_game.getLocalPlayer()
    local priceValue = UI_BASE.PriceBase.Value
    if isModernUI then
        local charmEntry = charms[widget.data.id]
        if charmEntry and charmEntry.points and charmEntry.points[widget.data.tier + 1] then
            local selectedWidget = TypeCharmRadioGroup:getSelectedWidget()
            if selectedWidget then
                local charmCategory = selectedWidget:getId() == "MajorCharms" and ResourceTypes.CHARM or
                                          ResourceTypes.MINOR_CHARM
                local pointsValue = charmEntry.points[widget.data.tier + 1]
                local canAfford = pointsValue <= player:getResourceBalance(charmCategory)
                UI.InformationBase.verticalPanelUnLockClearChram.PriceBaseCharm.Value:setColor(
                    canAfford and "#C0C0C0" or "#D33C3C")
                UI.InformationBase.verticalPanelUnLockClearChram.UnlockButton:setEnabled(canAfford)
            end
        else
            UI.InformationBase.verticalPanelUnLockClearChram.PriceBaseCharm.Value:setColor("#C0C0C0")
            UI.InformationBase.verticalPanelUnLockClearChram.UnlockButton:setEnabled(false)
        end
        priceValue:setText(comma_value(widget.data.removeRuneCost))
        local canAfford = widget.data.removeRuneCost <= player:getTotalMoney()
        priceValue:setColor(canAfford and "#C0C0C0" or "#D33C3C")
        UI.InformationBase.verticalPanelUnLockClearChram.ClearButton:setEnabled(canAfford and widget.data.asignedStatus)
    else
        if widget.icon == 1 and player:getTotalMoney() then
            local canAfford = widget.data.removeRuneCost <= player:getTotalMoney()
            priceValue:setColor(canAfford and "#C0C0C0" or "#D33C3C")
            UI_BASE.UnlockButton:setEnabled(canAfford)

            local priceText = (widget.data.unlocked and not widget.data.asignedStatus) and 0 or
                                  comma_value(widget.data.removeRuneCost)
            priceValue:setText(priceText)
        elseif widget.icon == 0 then
            local canAfford = widget.data.unlockPrice <= UI.CharmsPoints
            priceValue:setColor(canAfford and "#C0C0C0" or "#D33C3C")
            UI_BASE.UnlockButton:setEnabled(canAfford)
            priceValue:setText(widget.data.unlockPrice)
        end
    end
end

local function setupCreatureList(widget, UI_BASE)
    if (widget.data.unlocked and not widget.data.asignedStatus) or isModernUI then
        UI_BASE.UnlockButton:setText("Select")

        local color = "#484848"
        for index, raceId in ipairs(Cyclopedia.Charms.Monsters) do
            local creatureWidget = g_ui.createWidget("CharmCreatureName", UI_BASE.CreatureList)
            creatureWidget:setId(index)
            creatureWidget:setText(formatCreatureName(g_things.getRaceData(raceId).name))
            creatureWidget.raceId = raceId
            creatureWidget:setBackgroundColor(color)
            creatureWidget.color = color
            color = color == "#484848" and "#414141" or "#484848"
        end

        UI_BASE.UnlockButton:setEnabled(false)
        UI_BASE.SearchEdit:setEnabled(true)
        if UI_BASE.SearchLabel then
            UI_BASE.SearchLabel:setEnabled(true)
        end
        UI_BASE.CreaturesLabel:setEnabled(true)
    end
end

local function setupModernVersionUpgrade(widget, UI_BASE)
    if not isModernUI then
        return
    end

    local charmId = widget.data.id
    local tier = widget.data.tier or 0
    local charmEntry = charms[charmId]

    if charmEntry and charmEntry.points and charmEntry.points[tier + 1] then
        local pointsValue = charmEntry.points[tier + 1]
        local chanceValue = charmEntry.chance and charmEntry.chance[tier + 1] or 0

        UI.InformationBase.verticalPanelUnLockClearChram.PriceBaseCharm.Value:setText(comma_value(pointsValue))
        local tierButtons = {
            [3] = "Fully Unlocked",
            [2] = string.format("Upgrade to %d%%", charmEntry.chance[3] or 0),
            [1] = string.format("Upgrade to %d%%", charmEntry.chance[2] or 0),
            [0] = "Unlock"
        }
        UI_BASE.UnlockButton:setText(tierButtons[tier])
        if tier >= 0 and tier < 3 then
            UI_BASE.UnlockButton:setEnabled(true)
        end
        UI_BASE.UnlockButton:getParent().data = widget.data
    else
        UI_BASE.UnlockButton:setText("Fully Unlocked")
        UI.InformationBase.verticalPanelUnLockClearChram.PriceBaseCharm.Value:setText(comma_value(0))
    end
end

function Cyclopedia.selectCharm(widget, isChecked)
    local UI_BASE = getUIBase()
    UI_BASE.CreatureList:destroyChildren()

    local parent = widget:getParent()
    UI.InformationBase.data = widget.data
    for i = 1, parent:getChildCount() do
        local internalWidget = parent:getChildByIndex(i)
        if internalWidget:isChecked() and widget:getId() ~= internalWidget:getId() then
            internalWidget:setChecked(false)
        end
    end

    if not isChecked then
        widget:setChecked(true)
    end

    UI_BASE.TextBase:setText(widget.data.description)
    UI_BASE.ItemBase.image:setImageSource(widget.charmBase.image:getImageSource())
    UI_BASE.ItemBase.image:setImageClip(widget.charmBase.image:getImageClip())

    if isModernUI then
        UI.InformationBase:setText(widget:getText())
        if widget.data.tier > 0 then
            UI_BASE.ItemBase.border:setImageSource("/game_cyclopedia/images/charms/border/backdrop_charmgrade" ..
                                                       widget.data.tier)
            UI_BASE.ItemBase.lockedMask:setVisible(false)
        else
            UI_BASE.ItemBase.lockedMask:setVisible(true)
            UI_BASE.ItemBase.border:setImageSource("")
        end
    end

    if widget.data.asignedStatus then
        local sprite = UI_BASE.InfoBase.sprite
        sprite:setVisible(true)
        sprite:setOutfit(g_things.getRaceData(widget.data.raceId).outfit)
        sprite:getCreature():setStaticWalking(1000)
        sprite:setOpacity(1)
    else
        UI_BASE.InfoBase.sprite:setVisible(false)
    end

    if not isModernUI then
        UI_BASE.PriceBase.Gold:setVisible(widget.icon == 1)
        UI_BASE.PriceBase.Charm:setVisible(widget.icon == 0)
    end

    updateUIColors(widget, UI_BASE)

    setupCreatureList(widget, UI_BASE)

    if widget.data.asignedStatus then
        UI_BASE.UnlockButton:setText("Remove")
        local creatureWidget = g_ui.createWidget("CharmCreatureName", UI_BASE.CreatureList)
        creatureWidget:setText(formatCreatureName(g_things.getRaceData(widget.data.raceId).name))
        creatureWidget:setEnabled(false)
        creatureWidget:setColor("#707070")

        if not isModernUI then
            UI_BASE.SearchEdit:setEnabled(false)
            if UI_BASE.SearchLabel then
                UI_BASE.SearchLabel:setEnabled(false)
            end
            UI_BASE.CreaturesLabel:setEnabled(false)
        end
    end

    if not widget.data.unlocked then
        UI_BASE.UnlockButton:setText("Unlock")
        if not isModernUI then
            UI_BASE.SearchEdit:setEnabled(false)
            if UI_BASE.SearchLabel then
                UI_BASE.SearchLabel:setEnabled(false)
            end
            UI_BASE.CreaturesLabel:setEnabled(false)
        end
    end

    setupModernVersionUpgrade(widget, UI_BASE)
end

function Cyclopedia.selectCreatureCharm(widget, isChecked)
    local UI_BASE = {}

    if isModernUI then
        UI_BASE.InfoBase = UI.InformationBase.panelSelectCreature.InfoBase
        UI_BASE.UnlockButton = UI.InformationBase.verticalPanelUnLockClearChram.UnlockButton
    else
        UI_BASE.InfoBase = UI.InformationBase.InfoBase
        UI_BASE.UnlockButton = UI.InformationBase.UnlockButton
    end
    local parent = widget:getParent()

    for i = 1, parent:getChildCount() do
        local internalWidget = parent:getChildByIndex(i)

        if internalWidget:isChecked() and widget:getId() ~= internalWidget:getId() then
            internalWidget:setChecked(false)
            internalWidget:setBackgroundColor(internalWidget.color)
        end
    end

    if not isChecked then
        widget:setChecked(true)
    end

    UI_BASE.InfoBase.sprite:setVisible(true)
    UI_BASE.InfoBase.sprite:setOutfit(g_things.getRaceData(widget.raceId).outfit)
    UI_BASE.InfoBase.sprite:getCreature():setStaticWalking(1000)
    UI_BASE.InfoBase.sprite:setOpacity(0.5)
    UI_BASE.UnlockButton:setEnabled(true)

    Cyclopedia.Charms.SelectedCreature = widget.raceId
end

function Cyclopedia.searchCharmMonster(text)
    local UI_BASE = {}

    if isModernUI then
        UI_BASE.CreaturesBase = UI.InformationBase.PanelCreatureList.CreaturesBase
    else
        UI_BASE.CreaturesBase = UI.InformationBase.CreaturesBase
    end

    UI_BASE.CreaturesBase.CreatureList:destroyChildren()

    local function format(string)
        local capitalizedText = string:gsub("(%l)(%w*)", function(first, rest)
            return first:upper() .. rest
        end)

        if #capitalizedText > 19 then
            return capitalizedText:sub(1, 16) .. "..."
        else
            return capitalizedText
        end
    end

    local function getColor(currentColor)
        return currentColor == "#484848" and "#414141" or "#484848"
    end

    local searchedMonsters = {}

    if text ~= "" then
        for _, raceId in ipairs(Cyclopedia.Charms.Monsters) do
            local name = g_things.getRaceData(raceId).name
            if string.find(name:lower(), text:lower()) then
                table.insert(searchedMonsters, raceId)
            end
        end
    else
        searchedMonsters = Cyclopedia.Charms.Monsters
    end

    local color = "#484848"

    for _, raceId in ipairs(searchedMonsters) do
        local internalWidget = g_ui.createWidget("CharmCreatureName", UI_BASE.CreaturesBase.CreatureList)
        internalWidget:setId(raceId)
        internalWidget:setText(format(g_things.getRaceData(raceId).name))
        internalWidget.raceId = raceId
        internalWidget:setBackgroundColor(color)
        internalWidget.color = color
        color = getColor(color)
    end
end

function Cyclopedia.actionCharmButton(widget)
    local confirmWindow
    local type = widget:getText()
    local data = widget:getParent().data

    if type == "Unlock" then
        local function yesCallback()
            if isModernUI then
                g_game.BuyCharmRune(0, data.id, 0)
            else
                g_game.BuyCharmRune(data.id)
            end
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                -- Cyclopedia.Toggle(true, false, 3)
            end

            Cyclopedia.Charms.redirect = data.id
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm Unlocking of Charm"), tr(
                "Do you want to unlock the Charm %s? This will cost you %d Charm Points?", data.name, data.unlockPrice),
                {
                    {
                        text = tr("Yes"),
                        callback = yesCallback
                    },
                    {
                        text = tr("No"),
                        callback = noCallback
                    },
                    anchor = AnchorHorizontalCenter
                }, yesCallback, noCallback)
        end
    end
    if type == "Select" or type == "Select Creature" then
        local function yesCallback()
            if isModernUI then
                g_game.BuyCharmRune(1, data.id, Cyclopedia.Charms.SelectedCreature)
            else
                g_game.BuyCharmRune(data.id, 1, Cyclopedia.Charms.SelectedCreature)
            end
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
            end
            Cyclopedia.Charms.redirect = data.id
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm Selected Charm"),
                tr("Do you want to use the Charm %s for this creature?", data.name), {
                    {
                        text = tr("Yes"),
                        callback = yesCallback
                    },
                    {
                        text = tr("No"),
                        callback = noCallback
                    },
                    anchor = AnchorHorizontalCenter
                }, yesCallback, noCallback)
        end
    end

    if type == "Remove" then
        local function yesCallback()
            g_game.BuyCharmRune(data.id, 2)
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
            end

            Cyclopedia.Charms.redirect = data.id
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm Charm Removal"),
                tr("Do you want to remove the Charm %s from this creature? This will cost you %s gold pieces.",
                    data.name, comma_value(data.removeRuneCost)), {
                    {
                        text = tr("Yes"),
                        callback = yesCallback
                    },
                    {
                        text = tr("No"),
                        callback = noCallback
                    },
                    anchor = AnchorHorizontalCenter
                }, yesCallback, noCallback)
        end
    end
    if isModernUI and type:match("^Upgrade") then
        local function yesCallback()
            g_game.BuyCharmRune(0, data.id, 0)
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
            end
            Cyclopedia.Charms.redirect = data.id
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm Unlocking of Charm"), tr(
                "Do you want to upgrade the Charm %s? This will cost you %d Charm Points?", data.name, data.unlockPrice),
                {
                    {
                        text = tr("Yes"),
                        callback = yesCallback
                    },
                    {
                        text = tr("No"),
                        callback = noCallback
                    },
                    anchor = AnchorHorizontalCenter
                }, yesCallback, noCallback)
        end
    end
end

function onTypeCharmRadioGroup(radioGroup, selectedWidget)
    local charmCategory = selectedWidget:getId() == "MajorCharms" and charmCategory_t.CHARM_MAJOR or
                              charmCategory_t.CHARM_MINOR
    local CharmList = UI.mainPanelCharmsType.panelCharmList.CharmList
    if charmCategory == charmCategory_t.CHARM_MAJOR then
        UI.InformationBase.verticalPanelUnLockClearChram.PriceBaseCharm.Charm:setImageSource(
            "/game_cyclopedia/images/monster-icon-bonuspoints")
    else
        UI.InformationBase.verticalPanelUnLockClearChram.PriceBaseCharm.Charm:setImageSource(
            "/game_cyclopedia/images/minor-charm-echoes")
    end
    for _, widget in ipairs(CharmList:getChildren()) do
        if widget.category == charmCategory then
            widget:setVisible(true)
        else
            widget:setVisible(false)
        end
    end

    CharmList:getLayout():update()
end

function Cyclopedia.actionSelectCharmButton(widget)
    local confirmWindow
    local type = widget:getText()
    local data = UI.InformationBase.data
    if type == "Select" or type == "Select Creature" then
        local function yesCallback()
            if isModernUI then
                g_game.BuyCharmRune(1, data.id, Cyclopedia.Charms.SelectedCreature)
            else
                g_game.BuyCharmRune(data.id, 1, Cyclopedia.Charms.SelectedCreature)
            end
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
            end
            Cyclopedia.Charms.redirect = data.id
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm Selected Charm"),
                tr("Do you want to use the Charm %s for this creature?", data.name), {
                    {
                        text = tr("Yes"),
                        callback = yesCallback
                    },
                    {
                        text = tr("No"),
                        callback = noCallback
                    },
                    anchor = AnchorHorizontalCenter
                }, yesCallback, noCallback)
        end
    end
end

function Cyclopedia.clearCharm()
    local confirmWindow
    local data = UI.InformationBase.data
    if not data then
        return
    end

    local charm = charms[data.id]
    if not charm then
        return
    end

    local function yesCallback()
        g_game.BuyCharmRune(2, data.id, 0)
        if confirmWindow then
            confirmWindow:destroy()
            confirmWindow = nil
        end
    end

    local function noCallback()
        if confirmWindow then
            confirmWindow:destroy()
            confirmWindow = nil
        end
    end

    if not confirmWindow then
        confirmWindow = displayGeneralBox("Confirm Charm Removal",
            string.format("Do you want to remove the Charm %s from this creature? This will cost you %s gold pieces.",
                charm.name, comma_value(data.removeRuneCost)), {
                {
                    text = "Yes",
                    callback = yesCallback
                },
                {
                    text = "No",
                    callback = noCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback, noCallback)
    end
end

function Cyclopedia.resetAllCharms()
    if not UI or not UI.resetAllCharmsCost then
        return
    end

    local title = "Confirm Reset of Charms"
    local text = string.format("Do you want to reset all Charms? This will cost you %s gold?",
        comma_value(UI.resetAllCharmsCost))

    local yesCallback = function()
        g_game.BuyCharmRune(3, -58, 0)
        if UI.displayGeneralBox then
            UI.displayGeneralBox:destroy()
            UI.displayGeneralBox = nil
        end
    end

    local noCallback = function()
        if UI.displayGeneralBox then
            UI.displayGeneralBox:destroy()
            UI.displayGeneralBox = nil
        end
    end

    if UI.displayGeneralBox then
        UI.displayGeneralBox:destroy()
    end

    UI.displayGeneralBox = displayGeneralBox(title, text, {
        {
            text = 'Yes',
            callback = yesCallback
        },
        {
            text = 'No',
            callback = noCallback
        }
    }, yesCallback, noCallback)
end

function Cyclopedia.onSearchTextChange(text, panel)
    local creaturesBase = panel:getChildById('CreaturesBase')
    if not creaturesBase then
        return
    end

    local creatureList = creaturesBase:getChildById('CreatureList')
    if not creatureList then
        return
    end

    local children = creatureList:getChildren()
    text = text:lower()
    for _, child in ipairs(children) do
        local name = child:getText():lower()
        if name:find(text, 1, true) then
            child:show()
        else
            child:hide()
        end
    end
end
