local UI = nil

local STAGES = {
    CREATURES = 2,
    SEARCH = 4,
    CATEGORY = 1,
    CREATURE = 3
}

local storedRaceIDs = {}
Cyclopedia.storedTrackerData = Cyclopedia.storedTrackerData or {}
Cyclopedia.storedBosstiaryTrackerData = Cyclopedia.storedBosstiaryTrackerData or {}
local animusMasteryPoints = 0

local function copyTrackerEntry(entry)
    return {unpack(entry)}
end

local function setBestiaryTrackCheck(widget, checked)
    local originalCallback = widget.onCheckChange
    widget.onCheckChange = nil
    widget:setChecked(checked)
    widget.onCheckChange = originalCallback
    widget.bestiaryTrackerState = checked
end

local function addStoredRaceId(raceId)
    if not table.find(storedRaceIDs, raceId) then
        table.insert(storedRaceIDs, raceId)
    end
end

local function removeStoredRaceId(raceId)
    for index, storedRaceId in ipairs(storedRaceIDs) do
        if storedRaceId == raceId then
            table.remove(storedRaceIDs, index)
            return
        end
    end
end

function Cyclopedia.setBestiaryTrackerStatus(raceId, checked, trackerEntry, sendToServer)
    raceId = tonumber(raceId)
    if not raceId then
        return
    end

    Cyclopedia.storedTrackerData = Cyclopedia.storedTrackerData or {}

    local trackerData = {}
    for _, entry in ipairs(Cyclopedia.storedTrackerData) do
        if entry[1] ~= raceId then
            table.insert(trackerData, copyTrackerEntry(entry))
        end
    end

    if checked then
        addStoredRaceId(raceId)
        if trackerEntry then
            table.insert(trackerData, copyTrackerEntry(trackerEntry))
        end
    else
        removeStoredRaceId(raceId)
    end

    Cyclopedia.storedTrackerData = trackerData

    if trackerMiniWindow and Cyclopedia.onParseCyclopediaTracker then
        Cyclopedia.onParseCyclopediaTracker(0, trackerData)
    elseif trackerMiniWindow and trackerMiniWindow.contentsPanel and #trackerData == 0 then
        trackerMiniWindow.contentsPanel:destroyChildren()
    end

    if UI and UI.ListBase and UI.ListBase.CreatureInfo and UI.ListBase.CreatureInfo.LeftBase then
        local trackCheck = UI.ListBase.CreatureInfo.LeftBase.TrackCheck
        if trackCheck and tonumber(trackCheck.raceId) == raceId then
            setBestiaryTrackCheck(trackCheck, checked)
        end
    end

    if sendToServer ~= false then
        g_game.sendStatusTrackerBestiary(raceId, checked)
    end
end

function Cyclopedia.onBestiaryTrackCheckChange(widget)
    local raceId = tonumber(widget.raceId)
    if not raceId then
        return
    end

    local checked = widget:isChecked()
    if widget.bestiaryTrackerState == checked then
        return
    end

    widget.bestiaryTrackerState = checked
    Cyclopedia.setBestiaryTrackerStatus(raceId, checked, widget.trackerData, true)
end

function Cyclopedia.loadBestiaryOverview(name, creatures, animusMasteryPoints)
    if (name == "Result" or name == "") and #creatures > 0 then
        if #creatures == 1 then
            g_game.requestBestiarySearch(creatures[1].id)
            Cyclopedia.ShowBestiaryCreature()
        else
        Cyclopedia.loadBestiarySearchCreatures(creatures)
        end
    else
        Cyclopedia.loadBestiaryCreatures(creatures)
    end

    if animusMasteryPoints and animusMasteryPoints > 0 then
        animusMasteryPoints = animusMasteryPoints
    end
end

function showBestiary()
    UI = g_ui.loadUI("bestiary", contentContainer)
    UI:show()

    UI.ListBase.CategoryList:setVisible(true)
    UI.ListBase.CreatureList:setVisible(false)
    UI.ListBase.CreatureInfo:setVisible(false)

    Cyclopedia.Bestiary.Stage = STAGES.CATEGORY
    controllerCyclopedia.ui.CharmsBase:setVisible(true)
    controllerCyclopedia.ui.GoldBase:setVisible(true)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(true)
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:hide()
    end
    
    Cyclopedia.initializeTrackerData()
    Cyclopedia.ensureStoredRaceIDsPopulated()

    -- Bind Enter key to search when SearchEdit is focused
    g_keyboard.bindKeyDown('Enter', function()
        if UI and UI:isVisible() and UI.SearchEdit:getText() ~= "" then
            Cyclopedia.BestiarySearch()
        end
    end, UI.SearchEdit)

    
    g_game.requestBestiary()
end

Cyclopedia.Bestiary = {}
Cyclopedia.Bestiary.Stage = STAGES.CATEGORY

function Cyclopedia.SetBestiaryProgress(fit, firstBar, secondBar, thirdBar, killCount, firstGoal, secondGoal, thirdGoal)
    local function calculateWidth(value, max)
        return math.min(math.floor((value / max) * fit), fit)
    end

    local function setBarVisibility(bar, isVisible, width, isCompleted)
        isVisible = isVisible and width > 0
        bar:setVisible(isVisible)
        if isVisible then
            -- Use fill image only when bestiary is completed, otherwise use orange progress bar
            if isCompleted then
                bar:setImageRect({
                    height = 12,
                    x = 0,
                    y = 0,
                    width = width
                })
                bar:setImageSource("/game_cyclopedia/images/bestiary/fill")
            else
                -- For orange progress bar, set the widget width and use image as background
                bar:setWidth(width)
                bar:setImageSource("/game_cyclopedia/images/bestiary/progressbar-orange-small")
                -- Clear any image rect to use the full image as background
                bar:setImageRect({})
            end
        end
    end

    -- Check if bestiary is completed (reached final goal)
    local isCompleted = killCount >= thirdGoal

    local firstWidth = calculateWidth(math.min(killCount, firstGoal), firstGoal)
    setBarVisibility(firstBar, killCount > 0, firstWidth, isCompleted)

    local secondWidth = 0
    if killCount > firstGoal then
        secondWidth = calculateWidth(math.min(killCount - firstGoal, secondGoal - firstGoal), secondGoal - firstGoal)
    end
    setBarVisibility(secondBar, killCount > firstGoal, secondWidth, isCompleted)

    local thirdWidth = 0
    if killCount > secondGoal then
        thirdWidth = calculateWidth(math.min(killCount - secondGoal, thirdGoal - secondGoal), thirdGoal - secondGoal)
    end
    setBarVisibility(thirdBar, killCount > secondGoal, thirdWidth, isCompleted)
end

function Cyclopedia.SetBestiaryStars(value)
    UI.ListBase.CreatureInfo.StarFill:setWidth(value * 9)
end

function Cyclopedia.SetBestiaryDiamonds(value)
    UI.ListBase.CreatureInfo.DiamondFill:setWidth(value * 9)
end

function Cyclopedia.CreateCreatureItems(data)
    UI.ListBase.CreatureInfo.ItemsBase.Itemlist:destroyChildren()
    local itemsPerRow = 15
    local itemSlotSpacing = 36
    for index, _ in pairs(data) do
        local widget = g_ui.createWidget("BestiaryItemGroup", UI.ListBase.CreatureInfo.ItemsBase.Itemlist)
        widget:setId(index)
        local rowCount = math.max(1, math.ceil(#data[index] / itemsPerRow))
        local slotCount = rowCount * itemsPerRow
        widget:setHeight(45 + ((rowCount - 1) * itemSlotSpacing))
        widget.Title:breakAnchors()
        widget.Title:addAnchor(AnchorLeft, "parent", AnchorLeft)
        widget.Title:addAnchor(AnchorTop, "parent", AnchorTop)
        widget.Title:setMarginLeft(5)
        widget.Title:setMarginTop(16)

        if index == 0 then
            widget.Title:setText(tr("Common") .. ":")
        elseif index == 1 then
            widget.Title:setText(tr("Uncommon") .. ":")
        elseif index == 2 then
            widget.Title:setText(tr("Semi-Rare") .. ":")
        elseif index == 3 then
            widget.Title:setText(tr("Rare") .. ":")
        else
            widget.Title:setText(tr("Very Rare") .. ":")
        end

        local itemRows = {}
        local itemWidgets = {}
        for rowIndex = 1, rowCount do
            local row = g_ui.createWidget("UIWidget", widget.Items)
            row:setId("row" .. rowIndex)
            row:setHeight(34)
            row:addAnchor(AnchorLeft, "parent", AnchorLeft)
            row:addAnchor(AnchorRight, "parent", AnchorRight)

            if rowIndex == 1 then
                row:addAnchor(AnchorTop, "parent", AnchorTop)
                row:setMarginTop(5)
            else
                row:addAnchor(AnchorTop, "row" .. (rowIndex - 1), AnchorBottom)
                row:setMarginTop(2)
            end

            itemRows[rowIndex] = row
        end

        for i = 1, slotCount do
            local rowIndex = math.ceil(i / itemsPerRow)
            local item = g_ui.createWidget("BestiaryItem", itemRows[rowIndex])
            item:setId(i)
            itemWidgets[i] = item
        end

        for itemIndex, itemData in ipairs(data[index]) do
            local thing = g_things.getThingType(itemData.id, ThingCategoryItem)
            local itemWidget = itemWidgets[itemIndex]
            itemWidget:setItemId(itemData.id)
            itemWidget.id = itemData.id
            itemWidget.classification = thing:getClassification()

            if itemData.id == 0 then
                itemWidget.undefinedItem:setVisible(true)
            end

            if itemData.id > 0 then
                if itemData.stackable then
                    itemWidget.Stackable:setText("1+")
                else
                    itemWidget.Stackable:setText("1")
                end
            end

            ItemsDatabase.setRarityItem(itemWidget, itemWidget:getItem())

            itemWidget.onMouseRelease = onAddLootClick
        end
    end
end

function Cyclopedia.loadBestiarySelectedCreature(data)
    local occurence = {
        [0] = 1,
        2,
        3,
        4
    }

    local raceData = g_things.getRaceData(data.id)
    local formattedName = raceData.name:gsub("(%l)(%w*)", function(first, rest)
        return first:upper() .. rest
    end)

    UI.ListBase.CreatureInfo:setText(formattedName)
    Cyclopedia.SetBestiaryDiamonds(occurence[data.ocorrence])
    Cyclopedia.SetBestiaryStars(data.difficulty)
    UI.ListBase.CreatureInfo.LeftBase.Sprite:setOutfit(raceData.outfit)
    UI.ListBase.CreatureInfo.LeftBase.Sprite:getCreature():setStaticWalking(1000)

    Cyclopedia.SetBestiaryProgress(60, UI.ListBase.CreatureInfo.ProgressBack, UI.ListBase.CreatureInfo.ProgressBack33,
        UI.ListBase.CreatureInfo.ProgressBack55, data.killCounter, data.thirdDifficulty, data.secondUnlock,
        data.lastProgressKillCount)

    UI.ListBase.CreatureInfo.ProgressValue:setText(data.killCounter)

    local fullText = ""
    if data.killCounter >= data.lastProgressKillCount then
        fullText = "(fully unlocked)"
    end

    UI.ListBase.CreatureInfo.ProgressBorder1:setTooltip(string.format(" %d / %d %s", data.killCounter,
        data.thirdDifficulty, fullText))
    UI.ListBase.CreatureInfo.ProgressBorder2:setTooltip(string.format(" %d / %d %s", data.killCounter,
        data.secondUnlock, fullText))
    UI.ListBase.CreatureInfo.ProgressBorder3:setTooltip(string.format(" %d / %d %s", data.killCounter,
        data.lastProgressKillCount, fullText))
    UI.ListBase.CreatureInfo.LeftBase.TrackCheck.raceId = data.id
    UI.ListBase.CreatureInfo.LeftBase.TrackCheck.trackerData = {
        data.id,
        data.killCounter,
        data.thirdDifficulty,
        data.secondUnlock,
        data.lastProgressKillCount,
        1
    }

    -- TODO investigate when it can be track-- idk when
    --[[     if data.currentLevel == 1 then
        UI.ListBase.CreatureInfo.LeftBase.TrackCheck:enable()
    else
        UI.ListBase.CreatureInfo.LeftBase.TrackCheck:disable()
    end ]]

    Cyclopedia.ensureStoredRaceIDsPopulated()

    if table.find(storedRaceIDs, data.id) then
        setBestiaryTrackCheck(UI.ListBase.CreatureInfo.LeftBase.TrackCheck, true)
    else
        setBestiaryTrackCheck(UI.ListBase.CreatureInfo.LeftBase.TrackCheck, false)
    end

    if data.currentLevel > 1 then
        UI.ListBase.CreatureInfo.Value1:setText(data.maxHealth)
        UI.ListBase.CreatureInfo.Value2:setText(data.experience)
        UI.ListBase.CreatureInfo.Value3:setText(data.speed)
        UI.ListBase.CreatureInfo.Value4:setText(data.armor)
        UI.ListBase.CreatureInfo.Value5:setText(data.mitigation .. "%")
        UI.ListBase.CreatureInfo.BonusValue:setText(data.charmValue)
    else
        UI.ListBase.CreatureInfo.Value1:setText("?")
        UI.ListBase.CreatureInfo.Value2:setText("?")
        UI.ListBase.CreatureInfo.Value3:setText("?")
        UI.ListBase.CreatureInfo.Value4:setText("?")
        UI.ListBase.CreatureInfo.Value5:setText("?")
        UI.ListBase.CreatureInfo.BonusValue:setText("?")
    end

    if data.attackMode == 1 then
        local rect = {
            height = 9,
            x = 18,
            y = 0,
            width = 18
        }

        UI.ListBase.CreatureInfo.SubTextLabel:setImageSource("/images/icons/icons-skills")
        UI.ListBase.CreatureInfo.SubTextLabel:setImageClip(rect)
        UI.ListBase.CreatureInfo.SubTextLabel:setSize("18 9")
    else
        local rect = {
            height = 9,
            x = 0,
            y = 0,
            width = 18
        }
        UI.ListBase.CreatureInfo.SubTextLabel:setImageSource("/images/icons/icons-skills")
        UI.ListBase.CreatureInfo.SubTextLabel:setImageClip(rect)
        UI.ListBase.CreatureInfo.SubTextLabel:setSize("18 9")
    end

    local resists = {"PhysicalProgress", "FireProgress", "EarthProgress", "EnergyProgress", "IceProgress",
                     "HolyProgress", "DeathProgress", "HealingProgress"}

    if not table.empty(data.combat) then
        for i = 1, 8 do
            local combat = Cyclopedia.calculateCombatValues(data.combat[i])
            UI.ListBase.CreatureInfo[resists[i]].Fill:setMarginRight(combat.margin)
            UI.ListBase.CreatureInfo[resists[i]].Fill:setBackgroundColor(combat.color)
            UI.ListBase.CreatureInfo[resists[i]]:setTooltip(string.format("Sensitive to %s : %s", string.gsub(
                resists[i], "Progress", ""):lower(), combat.tooltip))
        end
    else
        for i = 1, 8 do
            UI.ListBase.CreatureInfo[resists[i]].Fill:setMarginRight(65)
        end
    end

    local lootData = {}
    for _, value in ipairs(data.loot) do
        local loot = {
            name = value.name,
            id = value.itemId,
            type = value.type,
            difficulty = value.diffculty,
            stackable = value.stackable == 1 and true or false
        }

        if not lootData[value.diffculty] then
            lootData[value.diffculty] = {}
        end

        table.insert(lootData[value.diffculty], loot)
    end

    Cyclopedia.CreateCreatureItems(lootData)
    UI.ListBase.CreatureInfo.LocationField.Textlist.Text:setText(data.location)

    if data.AnimusMasteryPoints and data.AnimusMasteryPoints > 1 then
        UI.ListBase.CreatureInfo.AnimusMastery:setTooltip("The Animus Mastery for this creature is unlocked.\nIt yields "..(data.AnimusMasteryBonus / 10).."% bonus experience points, plus an additional 0.1% for every 10 Animus Masteries unlocked, up to a maximum of 4%.\nYou currently benefit from "..(data.AnimusMasteryBonus / 10).."% bonus experience points due to having unlocked ".. data.AnimusMasteryPoints .." Animus Masteries.")
        UI.ListBase.CreatureInfo.AnimusMastery:setVisible(true)
    else
        UI.ListBase.CreatureInfo.AnimusMastery:removeTooltip()
        UI.ListBase.CreatureInfo.AnimusMastery:setVisible(false)
    end
end

function Cyclopedia.ShowBestiaryCreature()
    Cyclopedia.Bestiary.Stage = STAGES.CREATURE
    Cyclopedia.onStageChange()
end

function Cyclopedia.ShowBestiaryCreatures(Category)
    UI.ListBase.CreatureList:destroyChildren()
    UI.ListBase.CategoryList:setVisible(false)
    UI.ListBase.CreatureInfo:setVisible(false)
    UI.ListBase.CreatureList:setVisible(true)
    g_game.requestBestiaryOverview(Category, false, {})
end

function Cyclopedia.CreateBestiaryCategoryItem(Data)
    UI.BackPageButton:setEnabled(false)

    local widget = g_ui.createWidget("BestiaryCategory", UI.ListBase.CategoryList)
    widget:setText(Data.name)
    widget.ClassIcon:setImageSource("/game_cyclopedia/images/bestiary/creatures/" .. Data.name:lower():gsub(" ", "_"))
    widget.Category = Data.name
    widget:setColor("#C0C0C0")
    widget.TotalValue:setText(string.format("Total: %d", Data.amount))
    widget.KnownValue:setText(string.format("Known: %d", Data.know))

    function widget.ClassBase:onClick()
        UI.BackPageButton:setEnabled(true)
        Cyclopedia.ShowBestiaryCreatures(self:getParent().Category)
        Cyclopedia.Bestiary.Stage = STAGES.CREATURES
        Cyclopedia.onStageChange()
    end
end

function Cyclopedia.loadBestiarySearchCreatures(data)
    UI.ListBase.CategoryList:setVisible(false)
    UI.ListBase.CreatureInfo:setVisible(false)
    UI.ListBase.CreatureList:setVisible(true)
    UI.BackPageButton:setEnabled(true)

    Cyclopedia.Bestiary.Stage = STAGES.SEARCH
    Cyclopedia.onStageChange()
    Cyclopedia.Bestiary.Search = {}
    Cyclopedia.Bestiary.Page = 1

    local maxCategoriesPerPage = 15
    Cyclopedia.Bestiary.TotalSearchPages = math.ceil(#data / maxCategoriesPerPage)

    UI.PageValue:setText(string.format("%d / %d", Cyclopedia.Bestiary.Page, Cyclopedia.Bestiary.TotalSearchPages))

    local page = 1
    Cyclopedia.Bestiary.Search[page] = {}

    for i = 1, #data do
        if (i - 1) % maxCategoriesPerPage == 0 and i > 1 then
            page = page + 1
            Cyclopedia.Bestiary.Search[page] = {}
        end
        local creature = {
            id = data[i].id,
            currentLevel = data[i].currentLevel,
            AnimusMasteryBonus = data[i].creatureAnimusMasteryBonus or 0,
        }

        table.insert(Cyclopedia.Bestiary.Search[page], creature)
    end

    Cyclopedia.Bestiary.Stage = STAGES.SEARCH
    Cyclopedia.loadBestiaryCreature(Cyclopedia.Bestiary.Page, true)
    Cyclopedia.verifyBestiaryButtons()
end

function Cyclopedia.loadBestiaryCreatures(data)
    Cyclopedia.Bestiary.Creatures = {}
    Cyclopedia.Bestiary.Page = 1

    local maxCategoriesPerPage = 15
    Cyclopedia.Bestiary.TotalCreaturesPages = math.ceil(#data / maxCategoriesPerPage)

    UI.PageValue:setText(string.format("%d / %d", Cyclopedia.Bestiary.Page, Cyclopedia.Bestiary.TotalCreaturesPages))

    local page = 1
    Cyclopedia.Bestiary.Creatures[page] = {}

    for i = 1, #data do
        if (i - 1) % maxCategoriesPerPage == 0 and i > 1 then
            page = page + 1
            Cyclopedia.Bestiary.Creatures[page] = {}
        end

        local creature = {
            id = data[i].id,
            currentLevel = data[i].currentLevel,
            AnimusMasteryBonus = data[i].creatureAnimusMasteryBonus,

        }

        table.insert(Cyclopedia.Bestiary.Creatures[page], creature)
    end

    Cyclopedia.loadBestiaryCreature(Cyclopedia.Bestiary.Page, false)
    Cyclopedia.verifyBestiaryButtons()
end

-- note: this one needs refactor
-- expected result:
-- when a string is entered
-- the list should generate client-side
-- the list of search results that match the search string
-- looks identical to category view
function Cyclopedia.BestiarySearch()
    local text = UI.SearchEdit:getText()
    local raceList = g_things.getRacesByName(text)
    local list = {}
    for _, race in pairs(raceList) do
        list[#list + 1] = race.raceId
    end

    g_game.requestBestiaryOverview("Result", true, list)
    UI.SearchEdit:setText("")
end

function Cyclopedia.BestiarySearchText(text)
    if text ~= "" then
        UI.SearchButton:enable(true)
    else
        UI.SearchButton:disable(false)
    end
end

function Cyclopedia.CreateBestiaryCreaturesItem(data)
    local raceData = g_things.getRaceData(data.id)

    local function verify(name)
        if #name > 18 then
            return name:sub(1, 15) .. "..."
        else
            return name
        end
    end

    local widget = g_ui.createWidget("BestiaryCreature", UI.ListBase.CreatureList)
    widget:setId(data.id)

    local formattedName = raceData.name:gsub("(%l)(%w*)", function(first, rest)
        return first:upper() .. rest
    end)

    widget.Name:setText(verify(formattedName))
    widget.Sprite:setOutfit(raceData.outfit)
    widget.Sprite:getCreature():setStaticWalking(1000)

    if data.AnimusMasteryBonus > 0 then
        widget.AnimusMastery:setTooltip("The Animus Mastery for this creature is unlocked.\nIt yields ".. data.AnimusMasteryBonus.. "% bonus experience points, plus an additional 0.1% for every 10 Animus Masteries unlocked, up to a maximum of 4%.\nYou currently benefit from ".. data.AnimusMasteryBonus.. "% bonus experience points due to having unlocked ".. animusMasteryPoints.." Animus Masteries.")
        widget.AnimusMastery:setVisible(true)
    else
        widget.AnimusMastery:removeTooltip()
        widget.AnimusMastery:setVisible(false)
    end

    if data.currentLevel >= 4 then
        widget.Finalized:setVisible(true)
        widget.KillsLabel:setVisible(false)
        widget.Sprite:getCreature():setShader("")
    else
        widget.Finalized:setVisible(false)
        widget.KillsLabel:setVisible(true)
        if data.currentLevel < 1 then
            widget.KillsLabel:setText("?")
            widget.Sprite:getCreature():setShader("Outfit - cyclopedia-black")
            widget.Name:setText("Unknown")
            widget.AnimusMastery:setVisible(false)
        else
            widget.KillsLabel:setText(string.format("%d / 3", data.currentLevel - 1))
            widget.Sprite:getCreature():setShader("")
        end
    end

    function widget.ClassBase:onClick()
        if data.currentLevel < 1 then
            return
        end

        UI.BackPageButton:setEnabled(true)
        g_game.requestBestiarySearch(widget:getId())
        Cyclopedia.ShowBestiaryCreature()
    end
end

function Cyclopedia.loadBestiaryCreature(page, search)
    local state = "Creatures"
    if search then
        state = "Search"
    end

    if not Cyclopedia.Bestiary[state][page] then
        return
    end

    UI.ListBase.CreatureList:destroyChildren()

    for _, data in ipairs(Cyclopedia.Bestiary[state][page]) do
        Cyclopedia.CreateBestiaryCreaturesItem(data)
    end
end

function Cyclopedia.loadBestiaryCategories(data)
    Cyclopedia.Bestiary.Categories = {}
    Cyclopedia.Bestiary.Page = 1

    local maxCategoriesPerPage = 15
    Cyclopedia.Bestiary.TotalCategoriesPages = math.ceil(#data / maxCategoriesPerPage)

    if UI == nil or UI.PageValue == nil then -- I know, don't change it
        return
    end

    UI.PageValue:setText(string.format("%d / %d", Cyclopedia.Bestiary.Page, Cyclopedia.Bestiary.TotalCategoriesPages))

    local page = 1
    Cyclopedia.Bestiary.Categories[page] = {}

    for i = 1, #data do
        if (i - 1) % maxCategoriesPerPage == 0 and i > 1 then
            page = page + 1
            Cyclopedia.Bestiary.Categories[page] = {}
        end

        local category = {
            name = data[i].bestClass,
            amount = data[i].count,
            know = data[i].unlockedCount,
            AnimusMasteryBonus = data[i].AnimusMasteryBonus,
        }

        table.insert(Cyclopedia.Bestiary.Categories[page], category)
    end

    Cyclopedia.loadBestiaryCategory(Cyclopedia.Bestiary.Page)
    Cyclopedia.verifyBestiaryButtons()
end

function Cyclopedia.loadBestiaryCategory(page)
    if not Cyclopedia.Bestiary.Categories[page] then
        return
    end

    UI.ListBase.CategoryList:destroyChildren()

    for _, data in ipairs(Cyclopedia.Bestiary.Categories[page]) do
        Cyclopedia.CreateBestiaryCategoryItem(data)
    end
end

function Cyclopedia.onStageChange()
    Cyclopedia.Bestiary.Page = 1

    if Cyclopedia.Bestiary.Stage == STAGES.CATEGORY then
        UI.BackPageButton:setEnabled(false)
        UI.ListBase.CategoryList:setVisible(true)
        UI.ListBase.CreatureList:setVisible(false)
        UI.ListBase.CreatureInfo:setVisible(false)
    end

    if Cyclopedia.Bestiary.Stage == STAGES.CREATURES then
        UI.BackPageButton:setEnabled(true)
        UI.ListBase.CategoryList:setVisible(false)
        UI.ListBase.CreatureList:setVisible(true)
        UI.ListBase.CreatureInfo:setVisible(false)

        function UI.BackPageButton.onClick()
            Cyclopedia.Bestiary.Stage = STAGES.CATEGORY
            Cyclopedia.onStageChange()
        end
    end

    if Cyclopedia.Bestiary.Stage == STAGES.SEARCH then
        UI.BackPageButton:setEnabled(true)
        UI.ListBase.CategoryList:setVisible(false)
        UI.ListBase.CreatureList:setVisible(true)
        UI.ListBase.CreatureInfo:setVisible(false)

        function UI.BackPageButton.onClick()
            Cyclopedia.Bestiary.Stage = STAGES.CATEGORY
            Cyclopedia.onStageChange()
        end
    end

    if Cyclopedia.Bestiary.Stage == STAGES.CREATURE then
        UI.BackPageButton:setEnabled(true)
        UI.ListBase.CategoryList:setVisible(false)
        UI.ListBase.CreatureList:setVisible(false)
        UI.ListBase.CreatureInfo:setVisible(true)

        function UI.BackPageButton.onClick()
            Cyclopedia.Bestiary.Stage = STAGES.CREATURES
            Cyclopedia.onStageChange()
        end
    end

    Cyclopedia.verifyBestiaryButtons()
end

function Cyclopedia.changeBestiaryPage(prev, next)
    if next then
        Cyclopedia.Bestiary.Page = Cyclopedia.Bestiary.Page + 1
    end

    if prev then
        Cyclopedia.Bestiary.Page = Cyclopedia.Bestiary.Page - 1
    end

    local stage = Cyclopedia.Bestiary.Stage
    if stage == STAGES.CATEGORY then
        Cyclopedia.loadBestiaryCategory(Cyclopedia.Bestiary.Page)
    elseif stage == STAGES.CREATURES then
        Cyclopedia.loadBestiaryCreature(Cyclopedia.Bestiary.Page, false)
    elseif stage == STAGES.SEARCH then
        Cyclopedia.loadBestiaryCreature(Cyclopedia.Bestiary.Page, true)
    end

    Cyclopedia.verifyBestiaryButtons()
end

function Cyclopedia.verifyBestiaryButtons()
    local function updateButtonState(button, condition)
        if condition then
            button:enable()
        else
            button:disable()
        end
    end

    local function updatePageValue(currentPage, totalPages)
        UI.PageValue:setText(string.format("%d / %d", currentPage, totalPages))
    end

    updateButtonState(UI.SearchButton, UI.SearchEdit:getText() ~= "")

    local stage = Cyclopedia.Bestiary.Stage
    local totalSearchPages = Cyclopedia.Bestiary.TotalSearchPages
    local page = Cyclopedia.Bestiary.Page
    if stage == STAGES.SEARCH and totalSearchPages then
        local totalPages = totalSearchPages
        updateButtonState(UI.PrevPageButton, page > 1)
        updateButtonState(UI.NextPageButton, page < totalPages)
        updatePageValue(page, totalPages)
        return
    end

    if stage == STAGES.CREATURE then
        UI.PrevPageButton:disable()
        UI.NextPageButton:disable()
        updatePageValue(1, 1)
        return
    end

    local totalCategoriesPages = Cyclopedia.Bestiary.TotalCategoriesPages
    local totalCreaturesPages = Cyclopedia.Bestiary.TotalCreaturesPages
    if stage == STAGES.CATEGORY and totalCategoriesPages or stage == STAGES.CREATURES and totalCreaturesPages then
        local totalPages = stage == STAGES.CATEGORY and totalCategoriesPages or totalCreaturesPages
        updateButtonState(UI.PrevPageButton, page > 1)
        updateButtonState(UI.NextPageButton, page < totalPages)
        updatePageValue(page, totalPages)
    end
end

--[[
===================================================
=                     Tracker                     =
===================================================
]]

function Cyclopedia.refreshBestiaryTracker()
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end

    Cyclopedia.initializeTrackerData()

    if trackerMiniWindow and trackerMiniWindow.contentsPanel then
        Cyclopedia.onParseCyclopediaTracker(0, Cyclopedia.storedTrackerData)
    end

    g_game.requestBestiary()
end

function Cyclopedia.refreshBosstiaryTracker()
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end

    Cyclopedia.initializeTrackerData()

    if trackerMiniWindowBosstiary and trackerMiniWindowBosstiary.contentsPanel then
        trackerMiniWindowBosstiary.contentsPanel:destroyChildren()
    end

    -- Bosstiary tracker state comes from BosstiaryInfo, not the bestiary request.
    Cyclopedia.BosstiaryTrackerPending = true
    g_game.requestBosstiaryInfo()
end

function Cyclopedia.scheduleBosstiaryTrackerRetry(delay)
    if Cyclopedia.BosstiaryTrackerRetryScheduled then
        return
    end

    Cyclopedia.BosstiaryTrackerRetryScheduled = true
    scheduleEvent(function()
        Cyclopedia.BosstiaryTrackerRetryScheduled = false

        if trackerMiniWindowBosstiary and trackerMiniWindowBosstiary:isVisible() and Cyclopedia.BosstiaryTrackerPending then
            Cyclopedia.refreshBosstiaryTracker()
        end
    end, delay or 1000)
end

function Cyclopedia.toggleBestiaryTracker()
    if not trackerMiniWindow then
        return
    end

    if trackerButton:isOn() then
        trackerMiniWindow:close()
        trackerButton:setOn(false)
    else
        if not trackerMiniWindow:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(trackerMiniWindow,
            trackerMiniWindow:getMinimumHeight())
            if not panel then
                return
            end
            panel:addChild(trackerMiniWindow)
        end

        trackerMiniWindow:open()
    end
end

function Cyclopedia.toggleBosstiaryTracker()
    if not trackerMiniWindowBosstiary then
        return
    end

    if trackerButtonBosstiary:isOn() then
        trackerMiniWindowBosstiary:close()
        trackerButtonBosstiary:setOn(false)
    else
        if not trackerMiniWindowBosstiary:getParent() then
            local panel = modules.game_interface.findContentPanelAvailable(trackerMiniWindowBosstiary,
            trackerMiniWindowBosstiary:getMinimumHeight())
            if not panel then
                return
            end
            panel:addChild(trackerMiniWindowBosstiary)
        end

        trackerMiniWindowBosstiary:open()
    end
end

function Cyclopedia.onTrackerClose(temp)
end

function Cyclopedia.setBarPercent(widget, percent)
    if percent > 92 then
        widget.killsBar:setBackgroundColor("#00BC00")
    elseif percent > 60 then
        widget.killsBar:setBackgroundColor("#50A150")
    elseif percent > 30 then
        widget.killsBar:setBackgroundColor("#A1A100")
    elseif percent > 8 then
        widget.killsBar:setBackgroundColor("#BF0A0A")
    elseif percent > 3 then
        widget.killsBar:setBackgroundColor("#910F0F")
    else
        widget.killsBar:setBackgroundColor("#850C0C")
    end

    widget.killsBar:setPercent(percent)
end

function Cyclopedia.onParseCyclopediaTracker(trackerType, data)
    if not data then
        return
    end

    local isBoss = trackerType == 1
    local window = isBoss and trackerMiniWindowBosstiary or trackerMiniWindow

    if isBoss and Cyclopedia.mergeBosstiaryTrackerOverrides and not Cyclopedia.BosstiaryTrackerLocalRender then
        data = Cyclopedia.mergeBosstiaryTrackerOverrides(data)
    end

    if isBoss then
        Cyclopedia.BosstiaryTrackerPending = false
        Cyclopedia.storedBosstiaryTrackerData = data
    else
        Cyclopedia.storedTrackerData = data
        -- Keep checkbox state available even when the miniwindow is still closed.
        storedRaceIDs = {}
        for _, entry in ipairs(data) do
            addStoredRaceId(entry[1])
        end
    end

    if #data == 0 then
        if window and window.contentsPanel then
            window.contentsPanel:destroyChildren()
        end
        return
    end

    if not window or not window.contentsPanel then
        return
    end

    window.contentsPanel:destroyChildren()

    local trackerTypeStr = isBoss and "bosstiary" or "bestiary"
    data = Cyclopedia.sortTrackerData(data, trackerTypeStr)

    for _, entry in ipairs(data) do
        local raceId, kills, uno, dos, maxKills = unpack(entry)
        
        local raceData = g_things.getRaceData(raceId)
        local name = raceData.name

        local widget = g_ui.createWidget("TrackerButton", window.contentsPanel)
        widget:setId(raceId)
        widget.trackerType = trackerType
        widget.creature:setOutfit(raceData.outfit)
        widget.label:setText(name:len() > 12 and name:sub(1, 9) .. "..." or name)
        widget.kills:setText(kills .. "/" .. maxKills)
        widget.onMouseRelease = onTrackerClick

        Cyclopedia.SetBestiaryProgress(54,widget.killsBar2, widget.ProgressBack33, widget.ProgressBack55, kills, uno, dos, maxKills)
    end
end

local BESTIATYTRACKER_FILTERS = {
    ["sortByName"] = false,
    ["ShortByPercentage"] = false,
    ["sortByKills"] = true,
    ["sortByAscending"] = true,
    ["sortByDescending"] = false
}

local BOSSTIARYTRACKER_FILTERS = {
    ["sortByName"] = false,
    ["ShortByPercentage"] = false,
    ["sortByKills"] = true,
    ["sortByAscending"] = true,
    ["sortByDescending"] = false
}

function Cyclopedia.loadTrackerFilters(trackerType)
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        local defaultFilters = trackerType == "bosstiary" and BOSSTIARYTRACKER_FILTERS or BESTIATYTRACKER_FILTERS
        return defaultFilters
    end
    
    local filterKey = trackerType == "bosstiary" and "bosstiaryTracker" or "bestiaryTracker"
    local charFilterKey = string.format("%s_%s", filterKey, char)
    local defaultFilters = trackerType == "bosstiary" and BOSSTIARYTRACKER_FILTERS or BESTIATYTRACKER_FILTERS
    
    local settings = g_settings.getNode(charFilterKey)
    if not settings or not settings['filters'] then
        -- Save default filters for first time use
        g_settings.mergeNode(charFilterKey, {
            ['filters'] = defaultFilters,
            ['character'] = char
        })
        return defaultFilters
    end
    return settings['filters']
end

function Cyclopedia.saveTrackerFilters(trackerType)
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end
    
    local filterKey = trackerType == "bosstiary" and "bosstiaryTracker" or "bestiaryTracker"
    local charFilterKey = string.format("%s_%s", filterKey, char)
    
    g_settings.mergeNode(charFilterKey, {
        ['filters'] = Cyclopedia.loadTrackerFilters(trackerType),
        ['character'] = char
    })
end

function Cyclopedia.initializeTrackerData()
    Cyclopedia.storedTrackerData = Cyclopedia.storedTrackerData or {}
    Cyclopedia.storedBosstiaryTrackerData = Cyclopedia.storedBosstiaryTrackerData or {}
end

function Cyclopedia.ensureStoredRaceIDsPopulated()
    Cyclopedia.initializeTrackerData()

    storedRaceIDs = {}
    for _, entry in ipairs(Cyclopedia.storedTrackerData) do
        addStoredRaceId(entry[1])
    end
end

function Cyclopedia.clearTrackerDataForCharacterChange()
    Cyclopedia.storedTrackerData = {}
    Cyclopedia.storedBosstiaryTrackerData = {}
    Cyclopedia.BosstiaryTrackerPending = false
    Cyclopedia.BosstiaryTrackerRetryScheduled = false
    storedRaceIDs = {}

    if trackerMiniWindow and trackerMiniWindow.contentsPanel then
        trackerMiniWindow.contentsPanel:destroyChildren()
    end
    if trackerMiniWindowBosstiary and trackerMiniWindowBosstiary.contentsPanel then
        trackerMiniWindowBosstiary.contentsPanel:destroyChildren()
    end
end

function Cyclopedia.getTrackerFilter(trackerType, filter)
    return Cyclopedia.loadTrackerFilters(trackerType)[filter] or false
end

function Cyclopedia.setTrackerFilter(trackerType, filter, value)
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end
    
    local filterKey = trackerType == "bosstiary" and "bosstiaryTracker" or "bestiaryTracker"
    local charFilterKey = string.format("%s_%s", filterKey, char)
    local filters = Cyclopedia.loadTrackerFilters(trackerType)
    
    -- Handle mutual exclusion for sorting methods
    if filter == "sortByName" or filter == "ShortByPercentage" or filter == "sortByKills" then
        filters["sortByName"] = false
        filters["ShortByPercentage"] = false
        filters["sortByKills"] = false
        filters[filter] = true
    -- Handle mutual exclusion for sorting direction
    elseif filter == "sortByAscending" or filter == "sortByDescending" then
        filters["sortByAscending"] = false
        filters["sortByDescending"] = false
        filters[filter] = true
    else
        filters[filter] = value
    end
    
    g_settings.mergeNode(charFilterKey, {
        ['filters'] = filters,
        ['character'] = char
    })
    
    -- Refresh the tracker display
    Cyclopedia.refreshTracker(trackerType)
end

function Cyclopedia.refreshTracker(trackerType)
    if trackerType == "bosstiary" then
        if trackerMiniWindowBosstiary and Cyclopedia.storedBosstiaryTrackerData and not Cyclopedia.BosstiaryTrackerPending then
            Cyclopedia.onParseCyclopediaTracker(1, Cyclopedia.storedBosstiaryTrackerData)
        end
    else
        if trackerMiniWindow and Cyclopedia.storedTrackerData then
            Cyclopedia.onParseCyclopediaTracker(0, Cyclopedia.storedTrackerData)
        end
    end
end

function Cyclopedia.sortTrackerData(data, trackerType)
    local filters = Cyclopedia.loadTrackerFilters(trackerType)
    local isDescending = filters.sortByDescending
    
    -- Create a copy of the data to avoid modifying the original
    local sortedData = {}
    for i, v in ipairs(data) do
        sortedData[i] = v
    end
    
    if filters.sortByName then
        table.sort(sortedData, function(a, b)
            local nameA = g_things.getRaceData(a[1]).name:lower()
            local nameB = g_things.getRaceData(b[1]).name:lower()
            if isDescending then
                return nameA > nameB
            else
                return nameA < nameB
            end
        end)
    elseif filters.ShortByPercentage then
        table.sort(sortedData, function(a, b)
            local raceIdA, killsA, _, _, maxKillsA = unpack(a)
            local raceIdB, killsB, _, _, maxKillsB = unpack(b)
            local percentA = maxKillsA > 0 and (killsA / maxKillsA * 100) or 0
            local percentB = maxKillsB > 0 and (killsB / maxKillsB * 100) or 0
            if isDescending then
                return percentA > percentB
            else
                return percentA < percentB
            end
        end)
    elseif filters.sortByKills then
        table.sort(sortedData, function(a, b)
            local remainingA = a[5] - a[2] -- maxKills - kills
            local remainingB = b[5] - b[2] -- maxKills - kills
            if isDescending then
                return remainingA > remainingB
            else
                return remainingA < remainingB
            end
        end)
    end
    
    return sortedData
end

-- Shared function to create tracker context menu
function Cyclopedia.createTrackerContextMenu(trackerType, mousePos)
    local menu = g_ui.createWidget('bestiaryTrackerMenu')
    menu:setGameMenu(true)
    local shortCreature = UIRadioGroup.create()
    local shortAlphabets = UIRadioGroup.create()

    for i, choice in ipairs(menu:getChildren()) do
        if i >= 1 and i <= 3 then
            shortCreature:addWidget(choice)
        elseif i == 5 or i == 6 then
            shortAlphabets:addWidget(choice)
        end
    end

    -- Set default selections
    local filters = Cyclopedia.loadTrackerFilters(trackerType)
    
    -- Set sorting method (default: sortByKills)
    if filters.sortByName then
        menu:getChildById('sortByName'):setChecked(true)
    elseif filters.ShortByPercentage then
        menu:getChildById('ShortByPercentage'):setChecked(true)
    elseif filters.sortByKills then
        menu:getChildById('sortByKills'):setChecked(true)
    else
        menu:getChildById('sortByKills'):setChecked(true)
    end
    
    -- Set sorting direction (default: ascending)
    if filters.sortByDescending then
        menu:getChildById('sortByDescending'):setChecked(true)
    else
        menu:getChildById('sortByAscending'):setChecked(true)
    end

    -- Add click handlers for menu options
    menu:getChildById('sortByName').onClick = function() Cyclopedia.setTrackerFilter(trackerType, 'sortByName', true); menu:destroy() end
    menu:getChildById('ShortByPercentage').onClick = function() Cyclopedia.setTrackerFilter(trackerType, 'ShortByPercentage', true); menu:destroy() end
    menu:getChildById('sortByKills').onClick = function() Cyclopedia.setTrackerFilter(trackerType, 'sortByKills', true); menu:destroy() end
    menu:getChildById('sortByAscending').onClick = function() Cyclopedia.setTrackerFilter(trackerType, 'sortByAscending', true); menu:destroy() end
    menu:getChildById('sortByDescending').onClick = function() Cyclopedia.setTrackerFilter(trackerType, 'sortByDescending', true); menu:destroy() end

    menu:display(mousePos)
    return true
end

-- Legacy functions for backwards compatibility
function Cyclopedia.loadBestiaryTrackerFilters()
    return Cyclopedia.loadTrackerFilters("bestiary")
end

function Cyclopedia.saveBestiaryTrackerFilters()
    return Cyclopedia.saveTrackerFilters("bestiary")
end

function Cyclopedia.getBestiaryTrackerFilter(filter)
    return Cyclopedia.getTrackerFilter("bestiary", filter)
end

function Cyclopedia.setBestiaryTrackerFilter(filter, value)
    return Cyclopedia.setTrackerFilter("bestiary", filter, value)
end

-- trackerMiniWindow.contentsPanel:moveChildToIndex(battleButton, index)
-- TODO Add sort by name, kills, percentage, ascending, descending
function test(index)
    trackerMiniWindow.contentsPanel:moveChildToIndex(trackerMiniWindow.contentsPanel:getLastChild(), index)
end

function onTrackerClick(widget, mousePosition, mouseButton)
    local taskId = tonumber(widget:getId())
    local menu = g_ui.createWidget("PopupMenu")

    menu:setGameMenu(true)
    menu:addOption("stop Tracking " .. widget.label:getText(), function()
        if widget.trackerType == 1 and Cyclopedia.setBosstiaryTrackerStatus then
            Cyclopedia.setBosstiaryTrackerStatus(taskId, false, true)
        elseif Cyclopedia.setBestiaryTrackerStatus then
            Cyclopedia.setBestiaryTrackerStatus(taskId, false, nil, true)
        else
            g_game.sendStatusTrackerBestiary(taskId, false)
        end
    end)
    menu:display(menuPosition)

    return true
end

function onAddLootClick(widget, mousePosition, mouseButton)
    local itemId = widget:getItemId()
    local quickLoot = modules.game_quickloot.QuickLoot
    local lootFilterValue = quickLoot.data.filter
    local menu = g_ui.createWidget("PopupMenu")

    menu:setGameMenu(true)

    if not quickLoot.lootExists(itemId, lootFilterValue) then
        menu:addOption("Add to Loot List",
        function()
            quickLoot.addLootList(itemId, lootFilterValue)
        end)
    else
        menu:addOption("Remove from Loot List", 
        function() 
            quickLoot.removeLootList(itemId, lootFilterValue)
        end)
    end

    menu:display(menuPosition)

    return true
end
