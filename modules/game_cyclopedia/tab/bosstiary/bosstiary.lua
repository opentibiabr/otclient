local UI = nil
function showBosstiary()
    UI = g_ui.loadUI("bosstiary", contentContainer)
    UI:show()
    g_game.requestBosstiaryInfo()
    UI.FilterBase.BaneIcon:setTooltip(
        "Bane\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 5\nExpertise: 15\nMastery: 30")
    -- UI.FilterBase.BaneIcon:setTooltipAlign(AlignTopLeft)
    UI.FilterBase.ArchfoeIcon:setTooltip(
        "Archfoe\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 10\nExpertise: 30\nMastery: 60")
    -- UI.FilterBase.ArchfoeIcon:setTooltipAlign(AlignTopLeft)
    UI.FilterBase.NemesisIcon:setTooltip(
        "Nemesis\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 10\nExpertise: 30\nMastery: 60")
    -- UI.FilterBase.NemesisIcon:setTooltipAlign(AlignTopLeft)
    UI.StarBase.Info1:setTooltip("Once you have reached the Prowess level, you can assign the boss\nto a boss slot.")
    -- UI.StarBase.Info1:setTooltipAlign(AlignTopLeft)
    UI.StarBase.Info2:setTooltip(
        "Once you have reached the Expertise Level, you can display the\nboss on a Podium of Vigour.")
    -- UI.StarBase.Info2:setTooltipAlign(AlignTopLeft)
    UI.StarBase.Info3:setTooltip(
        "Once you have reached the Mastery Level, youl will receive an\nadditional 25% loot bonus when the boss is assigned to a boss slot.")
    -- UI.StarBase.Info3:setTooltipAlign(AlignTopLeft)
    controllerCyclopedia.ui.CharmsBase:setVisible(false)
    controllerCyclopedia.ui.GoldBase:setVisible(false)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(false)
    end
end

Cyclopedia.Bosstiary = {}

local CATEGORY = {
    BANE = 0,
    NEMESIS = 2,
    ARCHFOE = 1
}
local CONFIG = {
    [0] = {
        EXPERTISE = 100,
        PROWESS = 25,
        MASTERY = 300
    },
    {
        EXPERTISE = 20,
        PROWESS = 5,
        MASTERY = 60
    },
    {
        EXPERTISE = 3,
        PROWESS = 1,
        MASTERY = 5
    }
}

--[[ function Cyclopedia.SetBosstiaryProgress(object, value, maxValue)
    local rect = {
        height = 12,
        x = 0,
        y = 0,
        width = (maxValue < value and maxValue or value) / maxValue * 141
    }

    if value >= 0 and rect.width < 1 then
        object.fill:setVisible(false)
    else
        object.fill:setVisible(true)
    end

    object.fill:setImageRect(rect)
    object.ProgressValue:setText(value)
    object.fill:setImageSource("/game_cyclopedia/images/bestiary/fill")

end ]]

function Cyclopedia.CreateBosstiaryCreature(data)
    if not data.visible then
        return
    end

    local widget = g_ui.createWidget("BosstiaryItem", UI.ListBase.BossList)
    widget:setId(data.raceId)
    local raceData = g_things.getRaceData(data.raceId)
    local icons = {
        [CATEGORY.BANE] = "/game_cyclopedia/images/boss/icon_bane",
        [CATEGORY.ARCHFOE] = "/game_cyclopedia/images/boss/icon_archfoe",
        [CATEGORY.NEMESIS] = "/game_cyclopedia/images/boss/icon_nemesis"
    }

    local function format(string)
        if #string > 19 then
            return string:sub(1, 16) .. "..."
        else
            return string
        end
    end

    local fullText = ""

    if data.kills >= CONFIG[data.category].MASTERY then
        fullText = "(fully unlocked)"
    end

    widget.ProgressBorder1:setTooltip(string.format(" %d / %d %s", data.kills, CONFIG[data.category].PROWESS, fullText))
    widget.ProgressBorder2:setTooltip(
        string.format(" %d / %d %s", data.kills, CONFIG[data.category].EXPERTISE, fullText))
    widget.ProgressBorder3:setTooltip(string.format(" %d / %d %s", data.kills, CONFIG[data.category].MASTERY, fullText))

    if data.kills >= CONFIG[data.category].PROWESS then
        widget.bronzeStar:setImageSource("/game_cyclopedia/images/boss/icon_star_bronze")
    else
        widget.silverStar:setImageSource("/game_cyclopedia/images/boss/icon_star_dark")
    end

    if data.kills >= CONFIG[data.category].EXPERTISE then
        widget.silverStar:setImageSource("/game_cyclopedia/images/boss/icon_star_silver")
    else
        widget.silverStar:setImageSource("/game_cyclopedia/images/boss/icon_star_dark")
    end

    if data.kills >= CONFIG[data.category].MASTERY then
        widget.goldStar:setImageSource("/game_cyclopedia/images/boss/icon_star_gold")
    else
        widget.goldStar:setImageSource("/game_cyclopedia/images/boss/icon_star_dark")
    end

    widget.TypeIcon:setImageSource(icons[data.category])

    if data.category == CATEGORY.BANE then
        widget.TypeIcon:setTooltip(
            "Bane\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 5\nExpertise: 15\nMastery: 30")
        -- widget.TypeIcon:setTooltipAlign(AlignTopLeft)
    elseif data.category == CATEGORY.ARCHFOE then
        widget.TypeIcon:setTooltip(
            "Archfoe\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 10\nExpertise: 30\nMastery: 60")
        -- widget.TypeIcon:setTooltipAlign(AlignTopLeft)
    elseif data.category == CATEGORY.NEMESIS then
        widget.TypeIcon:setTooltip(
            "Nemesis\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 10\nExpertise: 30\nMastery: 60")
        -- widget.TypeIcon:setTooltipAlign(AlignTopLeft)
    end
    widget.ProgressValue:setText(data.kills)

    Cyclopedia.SetBestiaryProgress(46,widget.ProgressBack, widget.ProgressBack33, widget.ProgressBack55,  data.kills, CONFIG[data.category].PROWESS, CONFIG[data.category].EXPERTISE, CONFIG[data.category].MASTERY)

    widget.Sprite:setOutfit(raceData.outfit)
    widget.Sprite:getCreature():setStaticWalking(1000)
    if data.unlocked then
        widget.Sprite:getCreature():setShader("")
        widget:setText(format(data.name))
        if g_game.getClientVersion() >= 1320 then
            widget.TrackCheck:enable()
            if data.isTrackerActived == 1 then
                widget.TrackCheck:setChecked(true)
            else
                widget.TrackCheck:setChecked(false)
            end
        else
            widget.TrackCheck:hide()
        end
    else
        widget.Sprite:getCreature():setShader("Outfit - cyclopedia-black")
        widget.TrackCheck:disable()

    end
end

function Cyclopedia.LoadBosstiaryCreatures(data)
    if not UI then
        return
    end
    local maxCategoriesPerPage = 8

    Cyclopedia.Bosstiary.Creatures = {}
    Cyclopedia.Bosstiary.NotVisibleCreatures = {}
    Cyclopedia.Bosstiary.Page = 1
    Cyclopedia.Bosstiary.TotalPages = math.ceil(#data / maxCategoriesPerPage)

    UI.PageValue:setText(string.format("%d / %d", Cyclopedia.Bosstiary.Page, Cyclopedia.Bosstiary.TotalPages))

    local page = 1

    Cyclopedia.Bosstiary.Creatures[page] = {}

    local validCreatures = {}

    for i, dataEntry in ipairs(data) do
        local raceData = g_things.getRaceData(dataEntry.raceId)
        local creature = {
            visible = true,
            raceId = dataEntry.raceId,
            name = raceData and raceData.name or "?",
            kills = dataEntry.kills,
            category = dataEntry.category,
            isTrackerActived = dataEntry.isTrackerActived,
            unlocked = dataEntry.kills > 0 and true or false
        }

        table.insert(validCreatures, creature)
    end

    table.sort(validCreatures, function(a, b)
        if a.name == "?" and b.name ~= "?" then
            return false
        elseif a.name ~= "?" and b.name == "?" then
            return true
        elseif a.unlocked and not b.unlocked then
            return true
        elseif not a.unlocked and b.unlocked then
            return false
        else
            return a.name < b.name
        end
    end)

    for i = 1, #validCreatures do
        local creature = validCreatures[i]

        if creature.visible then
            table.insert(Cyclopedia.Bosstiary.Creatures[page], creature)
        else
            table.insert(Cyclopedia.Bosstiary.NotVisibleCreatures[page], creature)
        end

        if i % maxCategoriesPerPage == 0 and i < #validCreatures then
            page = page + 1
            Cyclopedia.Bosstiary.Creatures[page] = {}
        end
    end

    Cyclopedia.LoadBosstiaryCreature(Cyclopedia.Bosstiary.Page)
    Cyclopedia.verifyBosstiaryButtons()
end

function Cyclopedia.LoadBosstiaryCreature(page)
    if not Cyclopedia.Bosstiary.Creatures[page] then
        return
    end

    UI.ListBase.BossList:destroyChildren()

    for _, data in ipairs(Cyclopedia.Bosstiary.Creatures[page]) do
        Cyclopedia.CreateBosstiaryCreature(data)
    end
end

function Cyclopedia.verifyBosstiaryButtons()
    local page = Cyclopedia.Bosstiary.Page
    local totalPages = Cyclopedia.Bosstiary.TotalPages

    local function updateButtonState(button, condition)
        if condition then
            button:enable()
        else
            button:disable()
        end
    end

    local function updatePageValue(currentPage, maxPages)
        UI.PageValue:setText(string.format("%d / %d", currentPage, maxPages))
    end

    updateButtonState(UI.PrevPageButton, page > 1)
    updateButtonState(UI.NextPageButton, page < totalPages)
    updatePageValue(page, totalPages)
end

function Cyclopedia.changeBosstiaryPage(prev, next)
    if next then
        Cyclopedia.Bosstiary.Page = Cyclopedia.Bosstiary.Page + 1
    end

    if prev then
        Cyclopedia.Bosstiary.Page = Cyclopedia.Bosstiary.Page - 1
    end

    Cyclopedia.LoadBosstiaryCreature(Cyclopedia.Bosstiary.Page)
    Cyclopedia.verifyBosstiaryButtons()
end

function Cyclopedia.BosstiarySearchText(text, clear)
    local allCreatures = {}

    if clear then
        UI.SearchEdit:setText("")
    end

    for _, creatures in ipairs(Cyclopedia.Bosstiary.Creatures) do
        for _, creature in ipairs(creatures) do
            table.insert(allCreatures, creature)
        end
    end

    for _, creature in ipairs(Cyclopedia.Bosstiary.NotVisibleCreatures) do
        table.insert(allCreatures, creature)
    end

    if text ~= "" then
        for _, creature in ipairs(allCreatures) do
            if not creature.unlocked then
                creature.visible = false
            elseif string.find(creature.name:lower(), text:lower()) == nil then
                creature.visible = false
            else
                creature.visible = true
            end
        end
    else
        for _, creature in ipairs(allCreatures) do
            creature.visible = true
        end
    end

    Cyclopedia.ReadjustPages()
end

function Cyclopedia.changeBosstiaryFilter(widget, isCheck)
    widget:setChecked(not isCheck)

    local id = widget:getId()
    local allCreatures = {}

    for _, creatures in ipairs(Cyclopedia.Bosstiary.Creatures) do
        for _, creature in ipairs(creatures) do
            table.insert(allCreatures, creature)
        end
    end

    for _, creature in ipairs(Cyclopedia.Bosstiary.NotVisibleCreatures) do
        table.insert(allCreatures, creature)
    end

    for _, creature in ipairs(allCreatures) do
        if id == "BaneCheck" then
            if creature.category == CATEGORY.BANE then
                creature.visible = widget:isChecked()
            end
        elseif id == "ArchfoeCheck" then
            if creature.category == CATEGORY.ARCHFOE then
                creature.visible = widget:isChecked()
            end
        elseif id == "NemesisCheck" then
            if creature.category == CATEGORY.NEMESIS then
                creature.visible = widget:isChecked()
            end
        elseif id == "NoKillsCheck" then
            if creature.kills < 1 then
                creature.visible = widget:isChecked()
            end
        elseif id == "FewKillsCheck" then
            if creature.kills ~= 0 and creature.kills < CONFIG[creature.category].PROWESS then
                creature.visible = widget:isChecked()
            end
        elseif id == "ProwessCheck" then
            if creature.kills ~= 0 and creature.kills >= CONFIG[creature.category].PROWESS and creature.kills <=
                CONFIG[creature.category].EXPERTISE then
                creature.visible = widget:isChecked()
            end
        elseif id == "ExpertiseCheck" then
            if creature.kills ~= 0 and creature.kills >= CONFIG[creature.category].EXPERTISE and creature.kills <=
                CONFIG[creature.category].MASTERY then
                creature.visible = widget:isChecked()
            end
        elseif id == "MasteryCheck" and creature.kills ~= 0 and creature.kills >= CONFIG[creature.category].MASTERY then
            creature.visible = widget:isChecked()
        end
    end

    Cyclopedia.ReadjustPages()
end

function Cyclopedia.ReadjustPages()
    local maxCategoriesPerPage = 8
    local allCreatures = {}

    for _, creatures in ipairs(Cyclopedia.Bosstiary.Creatures) do
        for _, creature in ipairs(creatures) do
            table.insert(allCreatures, creature)
        end
    end

    for _, creature in ipairs(Cyclopedia.Bosstiary.NotVisibleCreatures) do
        table.insert(allCreatures, creature)
    end

    table.sort(allCreatures, function(a, b)
        if a.name == "?" and b.name ~= "?" then
            return false
        elseif a.name ~= "?" and b.name == "?" then
            return true
        elseif a.unlocked and not b.unlocked then
            return true
        elseif not a.unlocked and b.unlocked then
            return false
        else
            return a.name < b.name
        end
    end)

    Cyclopedia.Bosstiary.Creatures = {}
    Cyclopedia.Bosstiary.NotVisibleCreatures = {}

    local page = 1

    Cyclopedia.Bosstiary.Creatures[page] = {}

    for i, creature in ipairs(allCreatures) do
        if creature.visible then
            table.insert(Cyclopedia.Bosstiary.Creatures[page], creature)

            if #Cyclopedia.Bosstiary.Creatures[page] == maxCategoriesPerPage then
                page = page + 1
                Cyclopedia.Bosstiary.Creatures[page] = {}
            end
        else
            table.insert(Cyclopedia.Bosstiary.NotVisibleCreatures, creature)
        end
    end

    local totalVisible = 0

    for _, pageCreatures in ipairs(Cyclopedia.Bosstiary.Creatures) do
        totalVisible = totalVisible + #pageCreatures
    end

    Cyclopedia.Bosstiary.TotalPages = math.ceil(totalVisible / maxCategoriesPerPage)

    if Cyclopedia.Bosstiary.Page > Cyclopedia.Bosstiary.TotalPages then
        Cyclopedia.Bosstiary.Page = 1
    end

    UI.PageValue:setText(string.format("%d / %d", Cyclopedia.Bosstiary.Page, Cyclopedia.Bosstiary.TotalPages))
    Cyclopedia.LoadBosstiaryCreature(Cyclopedia.Bosstiary.Page)
    Cyclopedia.verifyBosstiaryButtons()
end
