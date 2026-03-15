local characterPanel = nil
local UI = nil

local function close(parent)
    if table.empty(parent.subCategories) then
        return
    end

    for subId, _ in ipairs(parent.subCategories) do
        local subWidget = parent:getChildById(subId)

        if subWidget then
            subWidget:setVisible(false)
        end
    end

    parent:setHeight(parent.closedSize)
    parent.opened = false
    parent.Button.Arrow:setVisible(true)
end

local function reset()
    characterPanel.InfoBase.inventoryPanel:setVisible(true)
    characterPanel.InfoBase.outfitPanel:setVisible(false)

    if characterPanel.InfoBase.CharacterButton.state ~= 1 then
        Cyclopedia.characterButton(characterPanel.InfoBase.CharacterButton)
    end

    Cyclopedia.selectCharacterPage()
    characterPanel.openedCategory = nil
end

local function open(parent)
    local oldOpen = UI.openedCategory

    for subId, _ in ipairs(parent.subCategories) do
        local subWidget = parent:getChildById(subId)

        if subWidget then
            if tonumber(subWidget:getId()) == 1 then
                subWidget.Button.onClick(subWidget)
            end

            subWidget:setVisible(true)
        end
    end

    if oldOpen ~= nil and oldOpen ~= parent then
        close(oldOpen)
    end

    parent:setHeight(parent.openedSize)
    parent.opened = true
    parent.Button.Arrow:setVisible(false)

    UI.openedCategory = parent
end

function showCharacter()
    characterPanel = g_ui.loadUI("character", contentContainer)
    UI = characterPanel
    characterPanel:show()
    UI.selectedOption = "InfoBase"

    if g_game.isOnline() then
        local player = g_game.getLocalPlayer()
        UI.CharacterBase:setText(player:getName())
        UI.CharacterBase.InfoLabel:setText(string.format("Level: %d\n%s", player:getLevel(), player:getVocationNameByClientId()))
        UI.CharacterBase.Outfit:setOutfit(player:getOutfit())

        UI.InfoBase.outfitPanel.Sprite:setOutfit(player:getOutfit())
        UI.InfoBase.InspectLabel:setText(tr("You are inspecting") .. ": " .. player:getName())

        for i = InventorySlotFirst, InventorySlotPurse do
            local item = player:getInventoryItem(i)
            local itemWidget = UI.InfoBase.inventoryPanel["slot" .. i]
            if itemWidget then
                if item then
                    itemWidget:setStyle("InventoryItemCyclopedia")
                    itemWidget:setItem(item)
                    ItemsDatabase.setRarityItem(itemWidget, itemWidget:getItem())
                    ItemsDatabase.setTier(itemWidget, itemWidget:getItem())
                    itemWidget:setIcon("")
                else
                    itemWidget:setStyle(Cyclopedia.InventorySlotStyles[i].name)
                    itemWidget:setIcon(Cyclopedia.InventorySlotStyles[i].icon)
                    itemWidget:setItem(nil)
                end
            end
        end

        if g_game.isOnline() then
            Cyclopedia.createCharacterDescription()
            Cyclopedia.configureCharacterCategories()
        end
    end

    reset()
    controllerCyclopedia.ui.CharmsBase:setVisible(true)
    controllerCyclopedia.ui.GoldBase:setVisible(true)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(true)
    end
end

Cyclopedia.Character = {}
Cyclopedia.Character.Achievements = {}
Cyclopedia.InventorySlotStyles = {
    [InventorySlotHead] = {
        icon = "/images/game/slots/inventory-head",
        name = "HeadSlot"
    },
    [InventorySlotNeck] = {
        icon = "/images/game/slots/inventory-neck",
        name = "NeckSlot"
    },
    [InventorySlotBack] = {
        icon = "/images/game/slots/inventory-back",
        name = "BackSlot"
    },
    [InventorySlotBody] = {
        icon = "/images/game/slots/inventory-torso",
        name = "BodySlot"
    },
    [InventorySlotRight] = {
        icon = "/images/game/slots/inventory-right-hand",
        name = "RightSlot"
    },
    [InventorySlotLeft] = {
        icon = "/images/game/slots/inventory-left-hand",
        name = "LeftSlot"
    },
    [InventorySlotLeg] = {
        icon = "/images/game/slots/inventory-legs",
        name = "LegSlot"
    },
    [InventorySlotFeet] = {
        icon = "/images/game/slots/inventory-feet",
        name = "FeetSlot"
    },
    [InventorySlotFinger] = {
        icon = "/images/game/slots/inventory-finger",
        name = "FingerSlot"
    },
    [InventorySlotAmmo] = {
        icon = "/images/game/slots/inventory-hip",
        name = "AmmoSlot"
    }
}

function Cyclopedia.characterAppearancesFilter(widget)
    local parent = widget:getParent()
    for i = 1, parent:getChildCount() do
        local child = parent:getChildByIndex(i)
        if child:getId() ~= "show" then
            child:setChecked(false)
        end
    end

    widget:setChecked(true)

    for _, data in ipairs(Cyclopedia.Character.Appearances) do
        if data.type == widget:getId() then
            data.visible = true
        else
            data.visible = false
        end
    end

    Cyclopedia.reloadCharacterAppearances()
end

function Cyclopedia.reloadCharacterAppearances()
    UI.CharacterAppearances.ListBase.list:destroyChildren()

    for _, data in ipairs(Cyclopedia.Character.Appearances) do
        if data.visible then
            local widget = g_ui.createWidget("CharacterAppearance", UI.CharacterAppearances.ListBase.list)
            widget.name:setText(data.name)
            widget.creature:setOutfit(data.outfit)
            widget.creature:getCreature():setStaticWalking(1000)
        end
    end
end

function Cyclopedia.loadCharacterAppearances(color, outfits, mounts, familiars)
    local data = {}

    local function insert(value, type)
        local lookData = value.lookType
        if type == "mounts" then
            lookData = value.mountId
        end

        local data_t = {
            visible = false,
            name = value.name,
            type = type,
            outfit = {
                auxType = 0,
                type = lookData,
                head = color.lookHead,
                body = color.lookBody,
                legs = color.lookLegs,
                feet = color.lookFeet,
                addon = outfits.addons and outfits.addons or 0
            }
        }

        table.insert(data, data_t)
    end

    local function process(container, containerType)
        for i = 0, #container do
            local value = container[i]
            if value then
                insert(value, containerType)
            end
        end
    end

    process(outfits, "outfits")
    process(mounts, "mounts")
    process(familiars, "familiars")

    Cyclopedia.Character.Appearances = data
    Cyclopedia.characterAppearancesFilter(UI.CharacterAppearances.listFilter.outfits)
end

function Cyclopedia.characterItemsSearch(text)
    local filter = UI.CharacterItems.filters
    local activeFilters = {}

    for i = 1, filter:getChildCount() do
        local child = filter:getChildByIndex(i)
        if child:isChecked() then
            table.insert(activeFilters, child:getId())
        end
    end

    for _, item in ipairs(Cyclopedia.Character.Items) do
        local data = item.data
        local name = data.name:lower()
        local meetsSearchCriteria = text == "" or string.find(name, text:lower()) ~= nil
        local meetsFilterCriteria = #activeFilters == 0 or table.contains(activeFilters, data.type)
        data.visible = meetsSearchCriteria and meetsFilterCriteria
    end

    Cyclopedia.reloadCharacterItems()
end

function Cyclopedia.characterItemsFilter(widget, force)
    if force then
        widget:setChecked(true)
    end

    local id = widget:getId()

    for _, item in ipairs(Cyclopedia.Character.Items) do
        local data = item.data
        if data.type == id then
            data.visible = widget:isChecked()
        end
    end

    Cyclopedia.reloadCharacterItems()
end

function Cyclopedia.reloadCharacterItems()
    UI.CharacterItems.ListBase.list:destroyChildren()
    UI.CharacterItems.gridBase.grid:destroyChildren()

    local colors = {"#484848", "#414141"}
    local colorIndex = 1

    for _, item in ipairs(Cyclopedia.Character.Items) do
        local itemId, data = item.itemId, item.data

        if data.visible then
            local listItem = g_ui.createWidget("CharacterListItem", UI.CharacterItems.ListBase.list)
            listItem.item:setItemId(itemId)
            listItem.name:setText(data.name)
            ItemsDatabase.setRarityItem(listItem.item, listItem.item:getItem())
            ItemsDatabase.setTier(listItem.item, item.tier)
            listItem.amount:setText(data.amount)
            listItem:setBackgroundColor(colors[colorIndex])
            local gridItem = g_ui.createWidget("CharacterGridItem", UI.CharacterItems.gridBase.grid)
            gridItem.item:setItemId(itemId)
            gridItem.amount:setText(data.amount)
            ItemsDatabase.setRarityItem(gridItem.item, gridItem.item:getItem())
            ItemsDatabase.setTier(gridItem.item, item.tier)
            colorIndex = 3 - colorIndex
        end
    end
end

function Cyclopedia.loadCharacterItems(data)
    local inventory = data.inventory
    local store = data.store
    local stash = data.stash
    local depot = data.depot
    local inbox = data.inbox
    Cyclopedia.Character.Items = {}

    local function insert(data, type)
        if not data then
            return
        end

        local thing = g_things.getThingType(data.itemId, ThingCategoryItem)
        local name = thing:getMarketData().name:lower()
        name = name ~= "" and name or "?"

        local data_t = {
            visible = false,
            name = name,
            amount = data.amount,
            type = type
        }

        local itemKey = data.itemId .. "-" .. (data.tier or "no_tier")
        local insertedItem = Cyclopedia.Character.Items[itemKey]
        if insertedItem and insertedItem.amount then
            insertedItem.amount = insertedItem.amount + data.amount
        else
            Cyclopedia.Character.Items[itemKey] = {
                itemId = data.itemId,
                tier = data.tier,
                data = data_t
            }
        end
    end

    local function processContainer(container, containerType)
        for i = 0, #container do
            local data = container[i]
            if data then
                insert(data, containerType)
            end
        end
    end

    processContainer(inventory, "inventory")
    processContainer(store, "store")
    processContainer(stash, "stash")
    processContainer(depot, "depot")
    processContainer(inbox, "inbox")

    local sortedItems = {}

    for _, itemData in pairs(Cyclopedia.Character.Items) do
        table.insert(sortedItems, itemData)
    end

    local function compareByName(a, b)
        local nameA = a.data.name:lower()
        local nameB = b.data.name:lower()

        if nameA ~= "?" and nameB == "?" then
            return true
        elseif nameA == "?" and nameB ~= "?" then
            return false
        else
            return nameA < nameB
        end
    end

    table.sort(sortedItems, compareByName)
    Cyclopedia.Character.Items = sortedItems
    Cyclopedia.characterItemsFilter(UI.CharacterItems.filters.inventory, true)
end

function Cyclopedia.loadCharacterAchievements()
    if not Cyclopedia.Character.Achievements.Loaded then
        UI.CharacterAchievements.sort:addOption("Alphabetically", 1, true)
        UI.CharacterAchievements.sort:addOption("By Grade", 2, true)
        UI.CharacterAchievements.sort:addOption("By Unlock Date", 3, true)
        Cyclopedia.achievementFilter(UI.CharacterAchievements.filters.accomplished)
        Cyclopedia.Character.Achievements.Loaded = true
    end
end

function Cyclopedia.characterItemListFilter(widget)
    local parent = widget:getParent()
    for i = 1, parent:getChildCount() do
        local child = parent:getChildByIndex(i)
        if child then
            child:setChecked(false)
        end
    end

    widget:setChecked(true)

    if widget:getId() == "list" then
        UI.CharacterItems.ListBase:setVisible(true)
        UI.CharacterItems.gridBase:setVisible(false)
    else
        UI.CharacterItems.ListBase:setVisible(false)
        UI.CharacterItems.gridBase:setVisible(true)
    end
end

function Cyclopedia.achievementFilter(widget)
    local parent = widget:getParent()
    for i = 1, parent:getChildCount() do
        local child = parent:getChildByIndex(i)
        if child then
            child:setChecked(false)
        end
    end

    if widget:getId() ~= "accomplished" then
        local last = Cyclopedia.Character.Achievements.lastSort
        last = last or 1
        Cyclopedia.achievementSort(last)
    else
        UI.CharacterAchievements.ListBase.List:destroyChildren()
    end

    widget:setChecked(not widget:isChecked())
end

function Cyclopedia.achievementSort(option)
    local tempTable = {}

    for id, data in pairs(ACHIEVEMENTS) do
        local tempData = {
            id = id,
            name = data.name,
            description = data.description,
            grade = data.grade
        }

        table.insert(tempTable, tempData)
    end

    if option == 1 then
        table.sort(tempTable, function(a, b)
            return a.name < b.name
        end)
    elseif option == 2 then
        table.sort(tempTable, function(a, b)
            return a.grade > b.grade
        end)
    end

    UI.CharacterAchievements.ListBase.List:destroyChildren()

    for _, data in pairs(tempTable) do
        local widget = g_ui.createWidget("Achievement", UI.CharacterAchievements.ListBase.List)
        widget:setId(data.id)
        widget.title:setText(data.name)
        widget.title = data.name
        widget:setText(data.description)
        widget.icon:setWidth(11 * data.grade)
        widget.grade = data.grade
    end

    Cyclopedia.Character.Achievements.lastSort = option
end

function Cyclopedia.loadCharacterRecentKills(data)
    UI.RecentKills.ListBase.List:destroyChildren()

    if not table.empty(data) then
        local color = "#484848"

        for i = 1, #data do
            local entry = data[i]
            local time = entry.timestamp
            local description = entry.description
            local status = entry.status
            local widget = g_ui.createWidget("CharacterKill", UI.RecentKills.ListBase.List)

            widget:setId(i)
            widget.date:setText(os.date("%Y-%m-%d, %H:%M:%S", time))
            widget.description:setText(description)
            widget.status:setText(status)
            widget.color = color
            widget:setBackgroundColor(color)

            color = color == "#484848" and "#414141" or "#484848"

            function widget:onClick()
                local parent = widget:getParent()
                for y = 1, parent:getChildCount() do
                    local child = parent:getChildByIndex(y)
                    child:setChecked(false)
                    child.date:setOn(false)
                    child.description:setOn(false)
                    child.status:setOn(false)
                end

                self:setChecked(not self:isChecked())
            end

            function widget:onCheckChange()
                if self:isChecked() then
                    self:setBackgroundColor("#585858")
                else
                    self:setBackgroundColor(self.color)
                end

                self.date:setOn(not self:isOn())
                self.description:setOn(not self:isOn())
                self.status:setOn(not self:isOn())
            end

            if i == 1 then
                widget:setChecked(true)
            end
        end
    end
end

function Cyclopedia.loadCharacterRecentDeaths(data)

    UI.RecentDeaths.ListBase.List:destroyChildren()

    if not table.empty(data) then
        local color = "#484848"

        for i = 1, #data do
            local entry = data[i]
            local widget = g_ui.createWidget("CharacterDeath", UI.RecentDeaths.ListBase.List)

            widget:setId(i)
            widget.date:setText(os.date("%Y-%m-%d, %H:%M:%S", entry.timestamp))
            widget.cause:setText(entry.cause)
            widget.color = color
            widget:setBackgroundColor(color)
            color = color == "#484848" and "#414141" or "#484848"

            function widget:onClick()
                local parent = widget:getParent()
                for y = 1, parent:getChildCount() do
                    local child = parent:getChildByIndex(y)
                    child:setChecked(false)
                    child.cause:setOn(false)
                    child.date:setOn(false)
                end

                self:setChecked(not self:isChecked())
            end

            function widget:onCheckChange()
                if self:isChecked() then
                    self:setBackgroundColor("#585858")
                else
                    self:setBackgroundColor(self.color)
                end

                self.cause:setOn(not self:isOn())
                self.date:setOn(not self:isOn())
            end

            if i == 1 then
                widget:setChecked(true)
            end
        end
    end
end

function Cyclopedia.loadCharacterCombatStats(data, mitigation, additionalSkillsArray, forgeSkillsArray,
    perfectShotDamageRanges, combatsArray, concoctionsArray)
    UI.CombatStats.attack.icon:setImageSource("/images/game/states/player-state-flags")
    UI.CombatStats.attack.icon:setImageClip((data.weaponElement * 9) .. ' 0 9 9')
    UI.CombatStats.attack.value:setText(data.weaponMaxHitChance)

    if data.weaponElementDamage > 0 then
        UI.CombatStats.converted.none:setVisible(false)
        UI.CombatStats.converted.value:setVisible(true)
        UI.CombatStats.converted.icon:setVisible(true)
        UI.CombatStats.converted.icon:setImageSource("/images/game/states/player-state-flags")
        UI.CombatStats.converted.icon:setImageClip((data.weaponElementType * 9) .. ' 0 9 9')
        UI.CombatStats.converted.value:setText(data.weaponElementDamage .. "%")
    else
        UI.CombatStats.converted.none:setVisible(true)
        UI.CombatStats.converted.value:setVisible(false)
        UI.CombatStats.converted.icon:setVisible(false)
    end

    UI.CombatStats.defence.value:setText(data.defense)
    UI.CombatStats.armor.value:setText(data.armor)
    UI.CombatStats.mitigation.value:setText(string.format("%.2f%%", mitigation))
    UI.CombatStats.blessings.value:setText(string.format("%d/8", data.haveBlessings))

    for i = 0, 6 do
        local id = "reduction_" .. i
        if UI.CombatStats[id] then
            UI.CombatStats[id]:destroy()
        end
    end
    UI.CombatStats.reductionNone:destroyChildren()

    if (next(combatsArray) == nil) then
        UI.CombatStats.reductionNone:setVisible(true)
    else
        UI.CombatStats.reductionNone:setVisible(true)
        for i = 1, #combatsArray do
            local widget = g_ui.createWidget("CharacterElementReduction", UI.CombatStats.reductionNone)
            widget:setId("reduction_" .. i)

            local element = Cyclopedia.clientCombat[combatsArray[i][1]]

            if element then
                widget.icon:setImageSource(element.path)
                widget.icon:setImageSize({
                    width = 9,
                    height = 9
                })
            else
                print(string.format("WARNING: Element not found for combat array index %d with key %s.", i, tostring(combatsArray[i][1])))
            end
            local valor = combatsArray[i][2]
            local porcentaje = valor / 100
            local diferencia = 65535 - valor
            local porcentaje_negativo = diferencia / 100
            local resultado
            if porcentaje <= porcentaje_negativo then
                resultado = string.format("+%.2f%%", porcentaje)
                widget.value:setColor("green")
            else
                resultado = string.format("-%.2f%%", porcentaje_negativo)
                widget.value:setColor("red")
            end
            widget.value:setText(resultado)
            if element  then
                widget.name:setText(element.id)
            end
            widget:setMarginLeft(13)
        end
    end

    -- concoctions
    UI.CombatStats.concoctionPanel:destroyChildren()
    if concoctionsArray or next(concoctionsArray) ~= nil then
        for i = 1, #concoctionsArray do
            local widget = g_ui.createWidget("CharacterGridItem", UI.CombatStats.concoctionPanel)
            local itemId = concoctionsArray[i][1]
            widget:setId("concoction_" .. itemId)
            widget.item:setItemId(itemId)
            widget.item:setVirtual(true)
            local minutes = concoctionsArray[i][2] / 60
            local itemName = widget.item:getItem():getMarketData().name
            widget.item:setTooltip(string.format("%s: %.0f minutes", itemName, minutes))
            widget.amount:setVisible(false)
        end
    end

    local skillsIndexes = {
        [Skill.CriticalChance] = 1,
        [Skill.CriticalDamage] = 2,
        [Skill.LifeLeechAmount] = 3,
        [Skill.ManaLeechAmount] = 4
    }

    -- Critical Chance
    local skillIndex = skillsIndexes[Skill.CriticalChance]
    local skill = additionalSkillsArray[skillIndex][2]
    UI.CombatStats.criticalChance.value:setText(string.format("%.2f%%", skill / 100))
    if skill > 0 then
        UI.CombatStats.criticalChance.value:setColor("#44AD25")
    else
        UI.CombatStats.criticalChance.value:setColor("#C0C0C0")
    end

    -- Critical Damage
    skillIndex = skillsIndexes[Skill.CriticalDamage]
    skill = additionalSkillsArray[skillIndex][2]
    UI.CombatStats.criticalDamage.value:setText(string.format("%.2f%%", skill / 100))
    if skill > 0 then
        UI.CombatStats.criticalDamage.value:setColor("#44AD25")
    else
        UI.CombatStats.criticalDamage.value:setColor("#C0C0C0")
    end

    -- Life Leech Amount
    skillIndex = skillsIndexes[Skill.LifeLeechAmount]
    skill = additionalSkillsArray[skillIndex][2]
    if skill > 0 then
        UI.CombatStats.lifeLeech.value:setColor("#44AD25")
        UI.CombatStats.lifeLeech.value:setText(string.format("%.2f%%", skill / 100))
    else
        UI.CombatStats.lifeLeech.value:setColor("#C0C0C0")
        UI.CombatStats.lifeLeech.value:setText(string.format("%d%%", skill))
    end

    -- Mana Leech Amount
    skillIndex = skillsIndexes[Skill.ManaLeechAmount]
    skill = additionalSkillsArray[skillIndex][2]
    if skill > 0 then
        UI.CombatStats.manaLeech.value:setColor("#44AD25")
        UI.CombatStats.manaLeech.value:setText(string.format("%.2f%%", skill / 100))
    else
        UI.CombatStats.manaLeech.value:setColor("#C0C0C0")
        UI.CombatStats.manaLeech.value:setText(string.format("%d%%", skill))
    end

    for i = 1, #forgeSkillsArray do
        local skillId = forgeSkillsArray[i][1]
        local id = "special_" .. skillId
        if UI.CombatStats[id] then
            UI.CombatStats[id]:destroy()
        end
    end

    local firstSpecial = true

    for i = 1, #forgeSkillsArray do
        local skillId = forgeSkillsArray[i][1]
        local percent = forgeSkillsArray[i][2]

        if percent > 0 then
            local widget = g_ui.createWidget("CharacterSkillBase", UI.CombatStats)
            widget:setId("special_" .. skillId)

            local specialName = {
                [13] = "Onslaught",
                [14] = "Ruse",
                [15] = "Momentum",
                [16] = "Transcendence"
            }

            if firstSpecial then
                widget:addAnchor(AnchorTop, "manaLeech", AnchorBottom)
                widget:addAnchor(AnchorLeft, "criticalHit", AnchorLeft)
                widget:addAnchor(AnchorRight, "parent", AnchorRight)
                widget:setMarginTop(5)
            else
                widget:addAnchor(AnchorTop, "prev", AnchorBottom)
                widget:addAnchor(AnchorLeft, "criticalHit", AnchorLeft)
                widget:addAnchor(AnchorRight, "parent", AnchorRight)
                widget:setMarginTop(0)
            end

            widget:setMarginLeft(0)

            local name = g_ui.createWidget("SkillNameLabel", widget)
            name:setText(specialName[skillId])
            name:setColor("#C0C0C0")

            local value = g_ui.createWidget("SkillValueLabel", widget)
            value:setText(string.format("%.2f%%", percent / 100))
            value:setColor("#C0C0C0")
            value:setMarginRight(2)
            value:setColor("#C0C0C0")
            firstSpecial = firstSpecial and false
        end
    end
end

function Cyclopedia.loadCharacterGeneralStats(data, skills)
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    local function format(value)
        local totalMinutes = value / 60
        local hours = math.floor(totalMinutes / 60)
        local minutes = math.floor(totalMinutes % 60)

        if hours < 10 then
            hours = "0" .. hours
        end

        if minutes < 10 then
            minutes = "0" .. minutes
        end

        return hours .. ":" .. minutes
    end

    Cyclopedia.setCharacterSkillValue("level", comma_value(data.level))

    local text = tr("You have %s percent to go ", 100 - data.levelPercent)
    Cyclopedia.setCharacterSkillPercent("level", data.levelPercent, text)
    Cyclopedia.setCharacterSkillValue("experience", comma_value(player:getExperience()))

    local expGainRate = data.baseExpGain + data.XpBoostPercent
    local hasStoreExpBonus = data.XpBoostPercent > 0
    local hasStaminaBonus = data.staminaMinutes / 60 >= 3

    expGainRate = hasStaminaBonus and expGainRate * 1.5 or expGainRate

    local staminaBonusTime = string.format("%02d:%02d", math.floor(math.min(data.staminaMinutes, 180) / 60),
        math.min(data.staminaMinutes, 180) % 60)
    local storeExpBonusTime = format(data.XpBoostBonusRemainingTime)
    local expGainRateTooltip = string.format(
        "Your current XP gain rate amounts to %d%%.\nYour XP gain rate is calculated as follows:\n- Base XP gain rate: %d%%",
        expGainRate, data.baseExpGain)

    expGainRateTooltip = hasStoreExpBonus and expGainRateTooltip ..
                             string.format("\n- XP boost: %d%% (%s h remaining).", data.XpBoostPercent,
            storeExpBonusTime) or expGainRateTooltip
    expGainRateTooltip = hasStaminaBonus and expGainRateTooltip ..
                             string.format("\n- Stamina bonus: x1.5 (%s h remaining).", staminaBonusTime) or
                             expGainRateTooltip

    UI.CharacterStats.expGainRate:setTooltip(expGainRateTooltip)
    -- UI.CharacterStats.expGainRate:setTooltipAlign(AlignTopLeft)
    Cyclopedia.setCharacterSkillValue("expGainRate", comma_value(expGainRate) .. "%")
    Cyclopedia.setCharacterSkillValue("health", comma_value(data.maxHealth))
    Cyclopedia.setCharacterSkillValue("mana", comma_value(data.mana))
    Cyclopedia.setCharacterSkillValue("soul", data.soul)
    Cyclopedia.setCharacterSkillValue("capacity", comma_value(math.floor(player:getFreeCapacity())))

    if data.speed > 0 then
        UI.CharacterStats.speed.value:setColor("#44AD25")
    else
        UI.CharacterStats.speed.value:setColor("#C0C0C0")
    end

    Cyclopedia.setCharacterSkillValue("speed", comma_value(math.floor(data.speed)))
    Cyclopedia.setCharacterSkillValue("food", format(data.regenerationCondition))

    local function formatTime(time)
        local hours = math.floor(time / 60)
        local minutes = time % 60
        if minutes < 10 then
            minutes = "0" .. minutes
        end
        return hours, minutes
    end

    local staminaPercent = math.floor(100 * data.staminaMinutes / 2520)
    local staminaHours, staminaMinutes = formatTime(data.staminaMinutes)

    Cyclopedia.setCharacterSkillValue("stamina", staminaHours .. ":" .. staminaMinutes)

    if data.staminaMinutes > 2400 and g_game.getClientVersion() >= 1038 and player:isPremium() then
        local text = tr("You have %s hours and %s minutes left", staminaHours, staminaMinutes) .. "\n" ..
                         tr("Now you will gain 50%% more experience")

        Cyclopedia.setCharacterSkillPercent("stamina", staminaPercent, text, "green")
    elseif data.staminaMinutes > 2400 and g_game.getClientVersion() >= 1038 and not player:isPremium() then
        local text = tr("You have %s hours and %s minutes left", staminaHours, staminaMinutes) .. "\n" ..
                         tr(
                "You will not gain 50%% more experience because you aren't premium player, now you receive only 1x experience points")

        Cyclopedia.setCharacterSkillPercent("stamina", staminaPercent, text, "#89F013")
    elseif data.staminaMinutes <= 840 and data.staminaMinutes > 0 then
        local text = tr("You have %s hours and %s minutes left", staminaHours, staminaMinutes) .. "\n" ..
                         tr("You gain only 50%% experience and you don't may gain loot from monsters")

        Cyclopedia.setCharacterSkillPercent("stamina", staminaPercent, text, "red")
    elseif data.staminaMinutes == 0 then
        local text = tr("You have %s hours and %s minutes left", staminaHours, staminaMinutes) .. "\n" ..
                         tr("You don't may receive experience and loot from monsters")

        Cyclopedia.setCharacterSkillPercent("stamina", staminaPercent, text, "black")
    end

    local trainerHours, trainerMinutes = formatTime(data.offlineTrainingTime)
    local trainerPercent = 100 * data.offlineTrainingTime / 720

    Cyclopedia.setCharacterSkillValue("trainer", trainerHours .. ":" .. trainerMinutes)
    Cyclopedia.setCharacterSkillPercent("trainer", trainerPercent, tr("You have %s percent", trainerPercent))
    Cyclopedia.setCharacterSkillValue("magiclevel", data.magicLevel)
    Cyclopedia.setCharacterSkillPercent("magiclevel", data.magicLevelPercent / 100,
        tr("You have %s percent to go", 100 - data.magicLevelPercent / 100))
    Cyclopedia.setCharacterSkillBase("magiclevel", data.magicLevel, data.baseMagicLevel)

    for i = Skill.Fist + 1, Skill.Fishing + 1 do
        local skillLevel, baseSkill, skillPercent = unpack(skills[i])
        Cyclopedia.onSkillChange(player, i - 1, skillLevel, skillPercent)
        Cyclopedia.onBaseCharacterSkillChange(player, i - 1, baseSkill)
    end
end

function Cyclopedia.setCharacterSkillValue(id, value, color)
    local skill = UI.CharacterStats:recursiveGetChildById(id)
    local widget = skill:getChildById("value")
    widget:setText(value)
    widget:setColor(color)
end

function Cyclopedia.setCharacterSkillPercent(id, percent, tooltip, color)
    local skill = UI.CharacterStats:recursiveGetChildById(id)
    local widget = skill:getChildById("percent")
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

function Cyclopedia.setCharacterSkillBase(id, value, baseValue)
    if baseValue <= 0 or value < 0 then
        return
    end

    local skill = UI.CharacterStats:recursiveGetChildById(id)
    local widget = skill:getChildById("value")

    if baseValue < value then
        widget:setColor("#44AD25")
        skill:setTooltip(baseValue .. " +" .. value - baseValue)
    elseif value < baseValue then
        widget:setColor("#b22222")
        skill:setTooltip(baseValue .. " " .. value - baseValue)
    else
        widget:setColor("#bbbbbb")
        skill:removeTooltip()
    end
end

function Cyclopedia.onBaseCharacterSkillChange(localPlayer, id, baseLevel)
    Cyclopedia.setCharacterSkillBase("skillId" .. id, localPlayer:getSkillLevel(id), baseLevel)
end

function Cyclopedia.onSkillChange(localPlayer, id, level, percent)
    Cyclopedia.setCharacterSkillValue("skillId" .. id, level)
    Cyclopedia.setCharacterSkillPercent("skillId" .. id, percent, tr("You have %s percent to go", 100 - percent))
    Cyclopedia.onBaseCharacterSkillChange(localPlayer, id, localPlayer:getSkillBaseLevel(id))
end

function Cyclopedia.selectCharacterPage()
    local selectedOption = UI.selectedOption
    UI[selectedOption]:setVisible(false)
    UI.InfoBase:setVisible(true)
    Cyclopedia.closeCharacterButtons()

    local oldOpen = UI.openedCategory
    if oldOpen ~= nil then
        close(oldOpen)
    end

    UI.selectedOption = "InfoBase"
end

function Cyclopedia.closeCharacterButtons()
    local size = UI.OptionsBase:getChildCount()
    for i = 1, size do
        local widget = UI.OptionsBase:getChildByIndex(i)
        if widget then
            if widget.subCategories ~= nil then
                for subId, _ in ipairs(widget.subCategories) do
                    local subWidget = widget:getChildById(subId)

                    if subWidget then
                        subWidget.Button:setChecked(false)
                        subWidget.Button.Arrow:setVisible(false)
                        subWidget.Button.Icon:setChecked(false)
                    end
                end
            else
                widget.Button:setChecked(false)
                widget.Button.Arrow:setVisible(false)
                widget.Button.Icon:setChecked(false)
            end
        end
    end
end

function Cyclopedia.configureCharacterCategories()
    UI.OptionsBase:destroyChildren()

    local buttons = {
        {
            text = "General Stats",
            icon = "/game_cyclopedia/images/character_icons/icon_generalstats",
            subCategories = function()
                local categories = {
                    {
                        text = "Character Stats",
                        icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-overview",
                        open = "CharacterStats"
                    }
                }
                
                if g_game.getClientVersion() < 1410 then
                    table.insert(categories, {
                        text = "Combat Stats",
                        icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-combatstats",
                        open = "CombatStats"
                    })
                else
                    table.insert(categories, {
                        text = "Offence Stats",
                        icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-combatstats",
                        open = "OffenceStats"
                    })
                    table.insert(categories, {
                        text = "Deffence Stats",
                        icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-defence",
                        open = "DeffenceStats"
                    })
                    table.insert(categories, {
                        text = "Misc. Stats",
                        icon = "/game_cyclopedia/images/character_icons/icon-character-generalstats-misc",
                        open = "MiscStats"
                    })
                end
                
                return categories
            end
        },
        {
            text = "Battle Results",
            icon = "/game_cyclopedia/images/character_icons/icon_battleresults",
            subCategories = {
                {
                    text = "Recent Deaths",
                    icon = "/game_cyclopedia/images/character_icons/icon-character-battleresults-recentdeaths",
                    open = "RecentDeaths"
                },
                {
                    text = "Recent PvP Kills",
                    icon = "/game_cyclopedia/images/character_icons/icon-character-battleresults-recentpvpkills",
                    open = "RecentKills"
                }
            }
        },
        {
            text = "Achievements",
            icon = "/game_cyclopedia/images/character_icons/icon_achievement",
            open = "CharacterAchievements"
        },
        {
            text = "Item Summary",
            icon = "/game_cyclopedia/images/character_icons/icon_items",
            open = "CharacterItems"
        },
        {
            text = "Appearances",
            icon = "/game_cyclopedia/images/character_icons/icon_outfitsmounts",
            open = "CharacterAppearances"
        },
        {
            text = "Store Summary",
            icon = "/game_cyclopedia/images/character_icons/icon-character-store",
            open = "StoreSummary"
        },
        {
            text = "Character Titles",
            icon = "/game_cyclopedia/images/character_icons/icon-character-titles",
            open = "CharacterTitles"
        }
    }

    for id, button in ipairs(buttons) do
        local widget = g_ui.createWidget("CharacterCategoryItem", UI.OptionsBase)
        widget:setId(id)
        widget.Button.Icon:setIcon(button.icon)
        widget.Button.Title:setText(button.text)

        if button.open ~= nil then
            widget.open = button.open
        end

        if button.subCategories ~= nil then
            local subCats = button.subCategories
            if type(subCats) == "function" then
                subCats = subCats()
            end
            
            widget.subCategories = subCats
            widget.subCategoriesSize = #subCats
            widget.Button.Arrow:setVisible(true)

            for subId, subButton in ipairs(subCats) do
                local subWidget = g_ui.createWidget("CharacterCategoryItem", widget)
                subWidget:setId(subId)
                subWidget.Button.Icon:setIcon(subButton.icon)
                subWidget.Button.Title:setText(subButton.text)
                subWidget:setVisible(false)
                subWidget.open = subButton.open

                function subWidget.Button:onClick(test)
                    local selectedOption = UI.selectedOption
                    Cyclopedia.closeCharacterButtons()
                    subWidget.Button:setChecked(true)
                    subWidget.Button.Arrow:setVisible(true)
                    subWidget.Button.Arrow:setImageSource("/game_cyclopedia/images/icon-arrow7x7-right")
                    subWidget.Button.Icon:setChecked(true)
                    UI[selectedOption]:setVisible(false)
                    UI[subWidget.open]:setVisible(true)

                    if subWidget.open == "CharacterStats" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.GeneralStats)
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.Badges)
                    elseif subWidget.open == "CombatStats" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.CombatStats)
                    elseif subWidget.open == "OffenceStats" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.Offencestats)
                    elseif subWidget.open == "DeffenceStats" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.Defencestats)
                    elseif subWidget.open == "MiscStats" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.Miscstats)
                    elseif subWidget.open == "RecentDeaths" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.RecentDeaths, 23, 1)
                    elseif subWidget.open == "RecentKills" then
                        g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.RecentPVPKills, 23, 1)
                    end

                    UI.selectedOption = subWidget.open
                end

                if subId == 1 then
                    subWidget:addAnchor(AnchorTop, "parent", AnchorTop)
                    subWidget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
                    subWidget:setMarginTop(20)
                else
                    subWidget:addAnchor(AnchorTop, "prev", AnchorBottom)
                    subWidget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
                    subWidget:setMarginTop(-1)
                end
            end
        end

        if id == 1 then
            widget:addAnchor(AnchorTop, "parent", AnchorTop)
            widget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
            widget:setMarginTop(5)
        else
            widget:addAnchor(AnchorTop, "prev", AnchorBottom)
            widget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
            widget:setMarginTop(5)
        end

        function widget.Button.onClick(this)
            if widget.open == "CharacterAchievements" then
                Cyclopedia.loadCharacterAchievements()
            elseif widget.open == "CharacterItems" then
                g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.ItemSummary)
                Cyclopedia.characterItemListFilter(UI.CharacterItems.listFilter.list)
            elseif widget.open == "CharacterAppearances" then
                g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.OutfitsAndMounts)
            elseif widget.open == "StoreSummary" then
                g_game.requestCharacterInfo(0, CyclopediaCharacterInfoTypes.StoreSummary)
            end

            local parent = this:getParent()
            if parent.subCategoriesSize ~= nil then
                if parent.closedSize == nil then
                    parent.closedSize = parent:getHeight() / (parent.subCategoriesSize + 1) + 15
                end

                if parent.openedSize == nil then
                    parent.openedSize = parent:getHeight() * (parent.subCategoriesSize + 1) - 6
                end

                open(parent)
            else
                local oldOpen = UI.openedCategory
                local selectedOption = UI.selectedOption

                Cyclopedia.closeCharacterButtons()
                this.Arrow:setImageSource("/game_cyclopedia/images/icon-arrow7x7-right")
                this.Arrow:setVisible(true)

                if oldOpen ~= nil and oldOpen ~= parent then
                    close(oldOpen)
                end

                this:setChecked(true)
                this.Icon:setChecked(true)
                UI[selectedOption]:setVisible(false)
                UI[parent.open]:setVisible(true)
                UI.selectedOption = parent.open
            end
        end
    end
end

function Cyclopedia.createCharacterDescription()
    UI.InfoBase.DetailsBase.List:destroyChildren()

    local player = g_game.getLocalPlayer()
    local descriptions = {
        { Level = player:getLevel() },
        { Vocation = player:getVocationNameByClientId() },
        { loyaltyTitle = "?" },
        { Prey = "?" },
        { Outfit = "?" },
        { }
    }

    for _, description in ipairs(descriptions) do
        local widget = g_ui.createWidget("UIWidget", UI.InfoBase.DetailsBase.List)
        for key, value in pairs(description) do
            widget:setText(key .. ": " .. value)
            widget:setColor("#C0C0C0")
        end
        widget:setTextWrap(true)
    end
end

function Cyclopedia.characterButton(widget)
    if widget.state == 1 then
        widget.state = 2
        widget:setIcon("/game_cyclopedia/images/icon-equipmentdetails")
        UI.InfoBase.inventoryPanel:setVisible(false)
        UI.InfoBase.outfitPanel:setVisible(true)
    else
        widget.state = 1
        widget:setIcon("/game_cyclopedia/images/icon-playerdetails")
        UI.InfoBase.inventoryPanel:setVisible(true)
        UI.InfoBase.outfitPanel:setVisible(false)
    end
end

function Cyclopedia.loadCharacterBadges(showAccountInformation, playerOnline, playerPremium, loyaltyTitle, badgesVector)
    UI.CharacterStats.ListBadge:destroyChildren()

    local playerOnlineStatus = "Offline"
    local playerOnlineStatusColor = "#ff0000"
    if playerOnline == 1 then
        playerOnlineStatus = "Online"
        playerOnlineStatusColor = "#00ff00"
    end

    local accountStatus = "Free"
    local accountStatusColor = "#ff0000"
    if playerPremium == 1 then
        accountStatus = "Premium"
        accountStatusColor = "#00ff00"
    end

    if not loyaltyTitle or loyaltyTitle == "" then
        loyaltyTitle = "None"
    end

    Cyclopedia.setCharacterSkillValue("accountStatus", accountStatus, accountStatusColor)
    Cyclopedia.setCharacterSkillValue("accountOnline", playerOnlineStatus, playerOnlineStatusColor)
    Cyclopedia.setCharacterSkillValue("loyaltyTitle", loyaltyTitle)

    for _, badge in ipairs(badgesVector) do
        local cell = g_ui.createWidget("CharacterBadge", UI.CharacterStats.ListBadge)
        if cell then
            cell:setImageClip(getImageClip(badge[1]))
            cell:setTooltip(badge[2])
        end
    end
end

function getImageClip(elementIndex)
    local elementSize = 64
    local elementsPerRow = 21
    local y = 0
    local x = (elementIndex - 1) * elementSize
    local imageClip = string.format("%d %d %d %d", x, y, elementSize, elementSize)
    return imageClip
end

function Cyclopedia.onParseCyclopediaStoreSummary(xpBoostTime, dailyRewardXpBoostTime, blessings, preySlotsUnlocked,
    preyWildcards, instantRewards, hasCharmExpansion, hirelingsObtained, hirelingSkills, houseItems)

    UI.StoreSummary.ListBase.List.XPBoosts.RemainingStoreXPBoostTimeValue:setText(string.format("%02d:%02d",
        math.floor(xpBoostTime / 3600), math.floor((xpBoostTime % 3600) / 60)))
    UI.StoreSummary.ListBase.List.XPBoosts.RemainingDailyRewardXPBoostTimeValue:setText(string.format("%02d:%02d",
        math.floor(dailyRewardXpBoostTime / 3600), math.floor((dailyRewardXpBoostTime % 3600) / 60)))

    local panel = UI.StoreSummary.ListBase.List.Blessings.PurchasedHouseItems
    for _, blessing in ipairs(blessings) do
        local row = g_ui.createWidget('BlessCreate', panel)
        row.text1:setText(blessing[1])
        row.text2:setText("x" .. blessing[2])

    end

    UI.StoreSummary.ListBase.List.preyPanel.PermanentPreySlotsValue:setText(preySlotsUnlocked)
    UI.StoreSummary.ListBase.List.preyPanel.PreyWildcardsValue:setText(preyWildcards)
    UI.StoreSummary.ListBase.List.dailyReward.InstantRewardAccessValue:setText(instantRewards)

    if hasCharmExpansion then
        UI.StoreSummary.ListBase.List.CharmPanel.CharmExpansionValue:setText("Yes")
    else
        UI.StoreSummary.ListBase.List.CharmPanel.CharmExpansionValue:setText("No")
    end

    UI.StoreSummary.ListBase.List.hirelings.PurchasedHirelingsValue:setText(hirelingsObtained)

    local rowHeight = 130
    local maxVisibleRows = 1.6
    local itemCount = #houseItems
    UI.StoreSummary.ListBase.List.houseItems:setHeight(math.min(itemCount, maxVisibleRows) * rowHeight)
    UI.StoreSummary.ListBase.List.houseItems.PurchasedHouseItems:destroyChildren() 
    for _, item in ipairs(houseItems) do
        local row = g_ui.createWidget('RowStore2', UI.StoreSummary.ListBase.List.houseItems.PurchasedHouseItems)
        local nameLabel = row:getChildById('lblName')
        nameLabel:setText(item[2])
        nameLabel:setTextAlign(AlignCenter)
        nameLabel:setMarginRight(10)
        row:getChildById('lblPrice'):setText(item[3])
        local itemWidget = g_ui.createWidget('Item', row:getChildById('image'))
        itemWidget:setId(item[1])
        itemWidget:setItemId(item[1])
        itemWidget:fill('parent')
    end
end
local function getWeaponSkillName2(skillType)
        local skillNames = {
            [1]  = "Magic Level",
	        [6]  = "Shielding",
	        [7]  = "Distance Fighting",
	        [8]  = "Sword Fighting",
	        [9]  = "Club Fighting",
	        [10] = "Axe Fighting",
	        [11] = "Fist Fighting",
	        [13] = "Fishing"
        }
        
    return skillNames[skillType] or "Fighting Skill"
end

local  function getWeaponSkillName(skillType)
        local skillNames = {
            [0] = "Fist Fighting",
            [1] = "Club Fighting",
            [2] = "Sword Fighting",
            [3] = "Axe Fighting",
            [4] = "Distance Fighting",
            [5] = "Shielding",
            [6] = "Fishing",
            [7] = "Magic Level",
            [8] = "Critical Hits",
            [9] = "Life Leech",
            [10] = "Mana Leech"
        }
        
        return skillNames[skillType] or "Fighting Skill"
end

local function getElementName(id)
        local elementNames = {
          [0] = "Physical",
          [1] = "Fire",
          [2] = "Earth",
          [3] = "Energy",
          [4] = "Ice",
          [5] = "Holy",
          [6] = "Death",
          [7] = "Healing",
          [8] = "Drowning",
          [9] = "Life Drain",
          [10] = "Mana Drain",
          [11] = "Agony"
        }
        return elementNames[id] or "Unknown"
    end
    function Cyclopedia.onCyclopediaCharacterOffenceStats(data)
        -- TODO UI/UX , verticalScroll, add new stats
        local container = UI.OffenceStats.content.statsContainer
        local leftPanel = container.leftPanel
        local rightPanel = container.rightPanel
        
        rightPanel:destroyChildren()
        leftPanel:destroyChildren()

        -- pdump(data)

        -- Initial Stats List
        local stats = {
            -- Left Panel Items
            {name = "Flat Damage and healing", value = data.flatDamage or 0, icon = false, percent = false},
            {name = "From Character Level",  value = data.flatDamageBase or 0, align = "center", percent = false, icon = false},
            {name = "From Wheel of destiny",  value = data.flatDamageWheel or 0, align = "center", percent = false, icon = false},

            {name = "Attack Value", value = data.weaponAttack, icon = true, weaponElement = data.weaponElementType},
            {name = "From Flat Bonus", value = data.weaponFlatModifier or 0, align = "center", icon = false},
            {name = "From Magic Level", value = data.weaponDamage or 0, align = "center", icon = false},
            {name = "From Equipment", value = data.weaponSkillLevel or 0, align = "center", icon = false},
            {name = "From Combat Tactics", value = data.weaponSkillModifier or 0, align = "center", icon = false},
    
            {name = "Converted Damage", value = data.weaponElementDamage, icon = true, weaponElement = data.weaponElementType, percent = true},

            {name = "Life Leech", value = data.lifeLeechTotal or data.lifeLeech or 0, icon = false, percent = true},
            {name = "From Equipment", value = data.lifeLeechBase or data.lifeLeechEquipament or 0, align = "center", percent = true, icon = false},
            {name = "From Imbuements", value = data.lifeLeechImbuement or 0, align = "center", percent = true, icon = false},
            {name = "From Wheel of Destiny", value = data.lifeLeechWheel or 0, align = "center", percent = true, icon = false},
            {name = "From Event Bonus", value = data.lifeLeechEventBonus or 0, align = "center", percent = true, icon = false},

            {name = "Life Gain on hit", value = data.lifeGainHit or 0, icon = false, percent = false},
            {name = "Life Gain on kill", value = data.lifeGainKill or 0, icon = false, percent = false},

            {name = "Mana Leech", value = data.manaLeechTotal or data.manaLeech or 0, icon = false, percent = true},
            {name = "From Base", value = data.manaLeechBase or data.manaLeechEquipament or 0, align = "center", percent = true, icon = false},
            {name = "From Equipment", value = data.manaLeechImbuement or 0, align = "center", percent = true, icon = false},
            {name = "From Wheel", value = data.manaLeechWheel or 0, align = "center", percent = true, icon = false},
            {name = "From Event", value = data.manaLeechEventBonus or 0, align = "center", percent = true, icon = false},
    
            {name = "Mana Gain on hit", value = data.manaGainHit or 0, icon = false, percent = false},
            {name = "Mana Gain on kill", value = data.manaGainKill or 0, icon = false, percent = false},

            {name = "Onslaught", value = data.onslaught or 0, icon = false, percent = true},
            {name = "From Equipment", value = data.onslaughtBase or 0, align = "center", percent = true, icon = false},
            {name = "From Amplification", value = data.onslaughtBonus or 0, align = "center", percent = true, icon = false},
            {name = "From Event Bonus", value = data.onslaughtEventBonus or 0, align = "center", percent = true, icon = false},

            {name = "Damage against Specific Targets", value = "", icon = false, percent = false},
            {name = "against Placeholder", value = data.critDamageFlat or 0, align = "center", percent = true, icon = false},
            {name = "against Powerful Foes", value = data.critChanceImbuement or 0, align = "center", percent = true, icon = false},
        }

        -- Dynamic Left/Mixed Panel Lists
        if data.extraDamageSkills and #data.extraDamageSkills > 0 then
            table.insert(stats, {name = "Auto-Attack Extra Damage", value = "", icon = false, percent = false})
            for _, skill in ipairs(data.extraDamageSkills) do
                table.insert(stats, {name = "from " .. getWeaponSkillName2(skill.skillId), value = skill.valueA or 0, align = "center", percent = false, icon = false})
            end
        end

        if data.extraDamageSpells and #data.extraDamageSpells > 0 then
            table.insert(stats, {name = "Extra Spell Damage", value = "", icon = false, percent = false})
            for _, skill in ipairs(data.extraDamageSpells) do
                table.insert(stats, {name = "from " .. getWeaponSkillName2(skill.skillId), value = skill.valueA or 0, align = "center", percent = false, icon = false})
            end
        end

        if data.extraHealingSpells and #data.extraHealingSpells > 0 then
            table.insert(stats, {name = "Extra Spell Healing", value = "", icon = false, percent = false})
            for _, skill in ipairs(data.extraHealingSpells) do
                table.insert(stats, {name = "from " .. getWeaponSkillName2(skill.skillId), value = skill.valueA or 0, align = "center", percent = false, icon = false})
            end
        end

        -- Right Panel Items (Critical Hit Section)
        table.insert(stats, {name = "Critical Hit", parent = "right", value = "", icon = false})
        table.insert(stats, {name = "  Chance", parent = "right", value = data.critChanceTotal or data.critChance or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from flat Bonus", parent = "right", align = "center", value = data.critChanceEquipament or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Equipment", parent = "right", align = "center", value = data.critChanceFlat or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Imbuement", parent = "right", align = "center", value = data.critChanceImbuement or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Wheel of destiny", parent = "right", align = "center", value = data.critChanceWheel or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Concoction", parent = "right", align = "center", value = data.critChanceConcoction or 0, percent = true, icon = false})
        
        -- Critical Chance by Type
        table.insert(stats, {name = "Critical Chance by Type", parent = "right", value = "", percent = false, icon = false})
        if data.damageElements and #data.damageElements > 0 then
             for _, el in ipairs(data.damageElements) do
                 table.insert(stats, {
                     name = "     from " .. getElementName(el.element),
                     parent = "right",
                     value = el.value,
                     align = "center",
                     percent = true,
                     icon = false
                 })
             end
        end
        table.insert(stats, {name = "     from Offensive Runes", parent = "right", value = data.offensiveRuneDamage or 0, align = "center", percent = true, icon = false})
        table.insert(stats, {name = "     from Auto Attack", parent = "right", value = data.autoAttackDamage or 0, align = "center", percent = true, icon = false})

        -- Critical Damage
        table.insert(stats, {name = "  Extra damage", parent = "right", value = data.critDamageTotal or 0, icon = false, percent = true})
        table.insert(stats, {name = "     from flat Bonus", parent = "right", align = "center", value = data.critDamageEquipament or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Equipment", parent = "right", align = "center", value = data.critDamageFlat or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Imbuement", parent = "right", align = "center", value = data.critDamageImbuement or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Wheel of destiny", parent = "right", align = "center", value = data.critDamageWheel or 0, percent = true, icon = false})
        table.insert(stats, {name = "     from Concoction", parent = "right", align = "center", value = data.critDamageConcoction or 0, percent = true, icon = false})
        
        -- Critical Damage by Type
        table.insert(stats, {name = "Critical Damage by Type", parent = "right", value = "", percent = false, icon = false})
        if data.critDamageElements and #data.critDamageElements > 0 then
             for _, el in ipairs(data.critDamageElements) do
                 table.insert(stats, {
                     name = "     from " .. getElementName(el.element),
                     parent = "right",
                     value = el.value,
                     align = "center",
                     percent = true,
                     icon = false
                 })
             end
        end
        table.insert(stats, {name = "     from Offensive Runes", parent = "right", value = data.critDamageOffensiveRunes or 0, align = "center", percent = true, icon = false})
        table.insert(stats, {name = "     from Auto Attack", parent = "right", value = data.critDamageAutoAttack or 0, align = "center", percent = true, icon = false})

        -- Cleave & Distance
        table.insert(stats, {name = "Cleave", parent = "right", value = data.cleavePercent or 0, icon = false, percent = true})
        table.insert(stats, {name = "Distance Fighting Accuracy", parent = "right", value = data.critChanceEquipament or 0, icon = false, percent = true})

        -- Perfect Shot
        if data.perfectShotDamage then
            for i = 1, #data.perfectShotDamage do
                if data.perfectShotDamage[i] and data.perfectShotDamage[i] > 0 then
                    if i == 1 then
                         table.insert(stats, {name = "Perfect Shot Damage Bonus", parent = "right", value = "", icon = false})
                    end
                    table.insert(stats, {
                        name = "     from Range " .. i, 
                        parent = "right", 
                        value = "+" .. data.perfectShotDamage[i], 
                        align = "center", 
                        icon = false
                    })
                end
            end
        end

        -- Target Specific & Armor Pen
        table.insert(stats, {name = "Damage Against Targets \nAbove 95% hit points", parent = "right", value = data.damageHighHp or 0, icon = false, percent = true})
        table.insert(stats, {name = "Damage Against Targets \nBelow 30% hit points", parent = "right", value = data.damageLowHp or 0, icon = false, percent = true})
        table.insert(stats, {name = "Armor Penetration", parent = "right", value = data.armorPenetration or 0, icon = false, percent = true})

        -- Elemental Pierce
        table.insert(stats, {name = "Elemental Pierce", parent = "right", value = "", icon = false, percent = true})
        if data.elementalPierce and #data.elementalPierce > 0 then
             for _, el in ipairs(data.elementalPierce) do
                 table.insert(stats, {
                     name = "     from " .. getElementName(el.element),
                     parent = "right",
                     value = el.value,
                     align = "center",
                     percent = true,
                     icon = false
                 })
             end
        end

        -- Render Helper Function
        local function renderStat(stat)
            local parent = stat.parent == "right" and rightPanel or leftPanel
    
            if stat.align == "center" then
                local widget = g_ui.createWidget("Label", parent)
                local valueText = stat.value
                -- Check if value is a string (pre-formatted) or number
                if type(valueText) == "number" and stat.percent then
                    local percentValue = math.floor(valueText * 10000) / 100
                    local sign = percentValue > 0 and "+ " or ""
                    valueText = sign .. percentValue .. "%"
                elseif type(valueText) == "number" then
                     valueText = tostring(valueText)
                end
                widget:setText("   " .. valueText .. " " .. stat.name)
                widget:setTextOffset("29 0")
                widget:setHeight(16)
                return widget
            else
                local widget = g_ui.createWidget("CharacterSkillBase", parent)
                local nameLabel = g_ui.createWidget("SkillNameLabel", widget)
                nameLabel:setText(stat.name .. ":")
                
                if string.find(stat.name, "\n") then
                    nameLabel:setTextWrap(true)
                    nameLabel:setTextAutoResize(true)
                    widget:setHeight(math.max(widget:getHeight(), nameLabel:getHeight() + 4))
                end

                local valueLabel = g_ui.createWidget("SkillValueLabel", widget)
                if stat.percent and type(stat.value) == "number" then
                    local percentValue = math.floor(stat.value * 10000) / 100
                    local sign = percentValue > 0 and "+ " or ""
                    valueLabel:setText(sign .. percentValue .. "%")
                else
                    valueLabel:setText(tostring(stat.value))
                end
                if stat.icon then
                    valueLabel:setMarginRight(12)
                    local icon = g_ui.createWidget("SkillCharacterIcon", widget)
                    icon:setMarginTop(2)
                    icon:addAnchor(AnchorRight, "parent", AnchorRight)
                    local element = clientCombat[stat.weaponElement]
                    if element then
                        icon:setImageSource(element.path)
                        icon:setImageSize({
                            width = 9,
                            height = 9
                        })
                    end
                end
    
                return widget
            end
        end
    
        for _, stat in ipairs(stats) do
            if stat.align ~= "center" and stat.value == 0 and stat.value ~= "" then
                -- Skip 0
            else
                renderStat(stat)
            end
        end 

        -- temp fix
        controllerCyclopedia:scheduleEvent(function()
            local height = math.max(leftPanel:getHeight() + leftPanel:getMarginTop(), rightPanel:getHeight() + rightPanel:getMarginTop())
            container:setHeight(height + 10)
        end, 50)
    end
    function Cyclopedia.onCyclopediaCharacterDefenceStats(data)
        UI.DeffenceStats.rightPanel:destroyChildren()
        UI.DeffenceStats.leftPanel:destroyChildren()
    
        local stats = {
            {name = "Defence Value", value = data.defense or 0, icon = false, percent = false},
            {name = "From Equipment", value = data.defenseEquipment or 0, align = "center", icon = false},
            {name = "From Wheel", value = data.defenseWheel or 0, align = "center", icon = false},
            {name = getWeaponSkillName(data.defenseSkillType), value = data.shieldingSkill or 0, align = "center", icon = false},
            
            {name = "Armor Value", value = data.armor or 0, icon = false, percent = false},
            
            {name = "Mitigation", value = data.mitigation or 0, icon = false, percent = true},
            {name = "From Shielding", value = data.mitigationShield or 0, align = "center", percent = true, icon = false},
            {name = "From Combat Tactics", value = data.mitigationCombatTactics or 0, align = "center", percent = true, icon = false},
            {name = "From Base", value = data.mitigationBase or 0, align = "center", percent = true, icon = false},
            {name = "From Equipment", value = data.mitigationEquipment or 0, align = "center", percent = true, icon = false},
            {name = "From Wheel", value = data.mitigationWheel or 0, align = "center", percent = true, icon = false},
            
            {name = "Dodge", value = data.dodgeTotal or 0, icon = false, percent = true},
            {name = "From Base", value = data.dodgeBase or 0, align = "center", percent = true, icon = false},
            {name = "From Amplification", value = data.dodgeBonus or 0, align = "center", percent = true, icon = false},
            {name = "From Wheel", value = data.dodgeWheel or 0, align = "center", percent = true, icon = false},
            
            {name = "Magic Shield Capacity", value = data.magicShieldCapacity or 0, icon = false, percent = false},
            {name = "Flat", value = data.magicShieldCapacityFlat or 0, align = "center", icon = false},
            {name = "Percent", value = data.magicShieldCapacityPercent or 0, align = "center", percent = true, icon = false},
            
            {name = "Reflect Physical", value = data.reflectPhysical or 0, icon = false, percent = false},
            
            {name = "Resistances", parent = "right", value = "", icon = false}
        }
        
        local resistanceMap = {}
        if data.resistances then
            for _, resistance in ipairs(data.resistances) do
                resistanceMap[resistance.element] = resistance.value
            end
        end
        
        for elementId, elementInfo in pairs(Cyclopedia.clientCombat) do
            local value = resistanceMap[elementId] or 0
            local percentValue = value *100
            local color = "#FFFFFF"
            
            if percentValue > 0 then
                color = "#44AD25"
            elseif percentValue < 0 then
                color = "#FF9900"
            end
            
            local sign = percentValue >= 0 and "+" or ""
            table.insert(stats, {
                name = "     " .. elementInfo.id,
                parent = "right", 
                value = sign .. string.format("%.2f", tonumber(percentValue)) .. "%", 
                percent = false,
                element = elementId,
                icon = true,
                color = color
            })
        end
    
        local function renderStat(stat)
            local parent = stat.parent == "right" and UI.DeffenceStats.rightPanel or UI.DeffenceStats.leftPanel
    
            if stat.align == "center" then
                local widget = g_ui.createWidget("Label", parent)
                local valueText = stat.value
                if stat.percent then
                    local percentValue = math.floor(stat.value * 10000) / 100
                    local sign = percentValue > 0 and "+ " or ""
                    valueText = sign .. percentValue .. "%"
                end
                widget:setText("   " .. valueText .. " " .. stat.name)
                widget:setMarginLeft(80)
                return widget
            else
                local widget = g_ui.createWidget("CharacterSkillBase", parent)
                local nameLabel = g_ui.createWidget("SkillNameLabel", widget)
                nameLabel:setText(stat.name .. ":")
                local valueLabel = g_ui.createWidget("SkillValueLabel", widget)
                if stat.percent then
                    local percentValue = math.floor(stat.value * 10000) / 100
                    local sign = percentValue > 0 and "+ " or ""
                    valueLabel:setText(sign .. percentValue .. "%")
                else
                    valueLabel:setText(tostring(stat.value))
                end
                
                if stat.color then
                    valueLabel:setColor(stat.color)
                end
                
                if stat.icon then
                    valueLabel:setMarginRight(12)
                    local icon = g_ui.createWidget("SkillCharacterIcon", widget)
                    icon:setMarginTop(2)
                    icon:addAnchor(AnchorRight, "parent", AnchorRight)
                    local element = Cyclopedia.clientCombat[stat.element]
                    if element then
                        icon:setImageSource(element.path)
                        icon:setImageSize({
                            width = 9,
                            height = 9
                        })
                    end
                end
    
                return widget
            end
        end
    
        for _, stat in ipairs(stats) do
            if stat.align ~= "center" and stat.value == 0 and stat.value ~= "" then
                -- Skip
            else
                renderStat(stat)
            end
        end
    end

    function Cyclopedia.onCyclopediaCharacterMiscStats(data)
        UI.MiscStats.leftPanel:destroyChildren()
        UI.MiscStats.rightPanel:destroyChildren()
    
        local stats = {
            {name = "Momentum", value = data.momentumTotal or 0, icon = false, percent = true},
            {name = "From Equipment", value = data.momentumBase or 0, align = "center", percent = true, icon = false},
            {name = "From Amplification", value = data.momentumBonus or 0, align = "center", percent = true, icon = false},
            {name = "From Wheel", value = data.momentumWheel or 0, align = "center", percent = true, icon = false},
            
            {name = "Transcendence", value = data.dodgeTotal or 0, icon = false, percent = true},
            {name = "From Base", value = data.dodgeBase or 0, align = "center", percent = true, icon = false},
            {name = "From Amplification", value = data.dodgeBonus or 0, align = "center", percent = true, icon = false},
            {name = "From Event Bonus", value = data.dodgeWheel or 0, align = "center", percent = true, icon = false},
            
            {name = "Damage Reflection", value = data.damageReflectionTotal or 0, icon = false, percent = true},
            {name = "From Base", value = data.damageReflectionBase or 0, align = "center", percent = true, icon = false},
            {name = "From Bonus", value = data.damageReflectionBonus or 0, align = "center", percent = true, icon = false},
            
            {name = "Blessings", value = (data.haveBlesses or 0) .. "/" .. (data.totalBlesses or 0), icon = false, percent = false},

        }
        
        if data.concoctions and #data.concoctions > 0 then
            for _, concoction in ipairs(data.concoctions) do
                table.insert(stats, {
                    name = "     " .. concoction.name,
                    parent = "right", 
                    value = concoction.value, 
                    percent = true,
                    icon = false
                })
            end
        end
    
        local function renderStat(stat)
            local parent = stat.parent == "right" and UI.MiscStats.rightPanel or UI.MiscStats.leftPanel
    
            if stat.align == "center" then
                local widget = g_ui.createWidget("Label", parent)
                local valueText = stat.value
                if stat.percent then
                    local percentValue = math.floor(stat.value * 10000) / 100
                    local sign = percentValue > 0 and "+ " or ""
                    valueText = sign .. percentValue .. "%"
                end
                widget:setText("   " .. valueText .. " " .. stat.name)
                widget:setMarginLeft(60)
                return widget
            else
                local widget = g_ui.createWidget("CharacterSkillBase", parent)
                local nameLabel = g_ui.createWidget("SkillNameLabel", widget)
                nameLabel:setText(stat.name .. ":")
                local valueLabel = g_ui.createWidget("SkillValueLabel", widget)
                if stat.percent then
                    local percentValue = math.floor(stat.value * 10000) / 100
                    local sign = percentValue > 0 and "+ " or ""
                    
                    
                    valueLabel:setText(sign .. percentValue .. "%")
                else
                    valueLabel:setText(tostring(stat.value))
                end
                
                if stat.icon then
                    valueLabel:setMarginRight(12)
                    local icon = g_ui.createWidget("SkillCharacterIcon", widget)
                    icon:setMarginTop(2)
                    icon:addAnchor(AnchorRight, "parent", AnchorRight)
                    if stat.element then
                        local element = Cyclopedia.clientCombat[stat.element]
                        if element then
                            icon:setImageSource(element.path)
                            icon:setImageSize({
                                width = 9,
                                height = 9
                            })
                        end
                    end
                end
    
                return widget
            end
        end
    
        for _, stat in ipairs(stats) do
            if stat.align ~= "center" and stat.value == 0 and stat.value ~= "" then
                -- Skip
            else
                renderStat(stat)
            end
        end
    end