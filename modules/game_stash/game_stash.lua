stashController = Controller:new()
-- LuaFormatter off

-- /*=============================================
-- =            Constants                    =
-- =============================================*/

local CELL_SIZE        = 36   -- matches grid cell-size in game_stash.otui
local BATCH_SIZE       = 0    -- ~20 cols × 12 rows first full viewport + 1 row overscan) but recalculated in ensureWindow from real panel dimensions
local SCROLL_THRESHOLD = 0    -- 3 rows × 36 px load next batch before hitting bottom but recalculated in ensureWindow from real panel dimensions

-- /*=============================================
-- =            Widget struct                    =
-- =============================================*/

local W = {
    window    = nil,
    poolBin   = nil,   -- hidden 0x0 parent that parks pooled StashItemBox widgets
    panels    = { items = nil },
    combos    = { stash = nil, seller = nil, sort = nil },
    inputs    = { search = nil },
    buttons   = { manage = nil, close = nil },
    scrollbar = nil,
    modal     = { selectAmount = nil },
}
-- /*=============================================
-- =            Static data                      =
-- =============================================*/

local categoryNames = {
    [1]  = "Armors",           [2]  = "Amulets",           [3]  = "Boots",
    [4]  = "Containers",       [5]  = "Decoration",        [6]  = "Food",
    [7]  = "Helmets/Hats",     [8]  = "Legs",              [9]  = "Others",
    [10] = "Potions",          [11] = "Rings",             [12] = "Runes",
    [13] = "Shields",          [14] = "Tools",             [15] = "Valuables",
    [16] = "Ammunition",       [17] = "Axes",              [18] = "Clubs",
    [19] = "Distance Weapons", [20] = "Swords",            [21] = "Wands/Rods",
    [22] = "Premium Scrolls",  [23] = "Tibia Coins",       [24] = "Creature Products",
    [25] = "Quiver",           [26] = "Soul Cores",        [27] = "Fist Weapons",
}

local imbuementSet = {}
for _, id in ipairs({
    5877, 5920, 9633, 9635, 9636, 9638, 9639, 9640, 9641, 9644, 9647, 9650, 9654,
    9657, 9660, 9661, 9663, 9665, 9685, 9686, 9691, 9694, 10196, 10281, 10295, 10298,
    10302, 10304, 10307, 10309, 10311, 10405, 10420, 11444, 11447, 11452, 11464, 11466,
    11484, 11489, 11492, 11658, 11702, 11703, 14012, 14079, 14081, 16131, 17458, 17823,
    18993, 18994, 20199, 20200, 20205, 21194, 21200, 21202, 21975, 22007, 22053, 22189,
    22728, 22730, 23507, 23508, 25694, 25702, 28567, 40529,
}) do imbuementSet[id] = true end

local function nameAscComparator(a, b)
    local aName, bName = a.meta.nameLower, b.meta.nameLower
    if aName == bName then return a.itemId < b.itemId end
    return aName < bName
end

local sortFunctions = {
    ["Name (A-Z)"] = nameAscComparator,
    ["Name (Z-A)"] = function(a, b)
        local aName, bName = a.meta.nameLower, b.meta.nameLower
        if aName == bName then return a.itemId < b.itemId end
        return aName > bName
    end,
    ["Quantity (High to Low)"] = function(a, b)
        if a.amount == b.amount then return nameAscComparator(a, b) end
        return a.amount > b.amount
    end,
    ["Quantity (Low to High)"] = function(a, b)
        if a.amount == b.amount then return nameAscComparator(a, b) end
        return a.amount < b.amount
    end,
}

local sortOrder = {
    "Name (A-Z)",
    "Name (Z-A)",
    "Quantity (High to Low)",
    "Quantity (Low to High)",
}

local sellers = {
    "No Trader Selected", "Sell to Alaister", "Sell to Alesar", "Sell to Alexander",
    "Sell to Arkulius", "Sell to Asnarus", "Sell to Asphota", "Sell to Augustin",
    "Sell to Avan", "Sell to Brengus", "Sell to Chondur", "Sell to Dal the Huntress",
    "Sell to Domizian", "Sell to Esrik", "Sell to Fadil", "Sell to Fiona",
    "Sell to Flint", "Sell to Gladys", "Sell to Gnominission", "Sell to Grizzly Adams",
    "Sell to Haroun", "Sell to Inigo", "Sell to Irmana", "Sell to Khanna",
    "Sell to Kiru", "Sell to Lailene", "Sell to Luna", "Sell to Malunga",
    "Sell to Mugruu", "Sell to Nah'bob", "Sell to Rafzan", "Sell to Rashid",
    "Sell to Rock in a Hard Place", "Sell to Talila", "Sell to Tamoril",
    "Sell to Tamru", "Sell to Telas", "Sell to Tothdral", "Sell to Valindara",
    "Sell to Yaman", "Sell to Yasir",
}

-- /*=============================================
-- =            State                            =
-- =============================================*/

local stashCache          = {}   -- [itemId] = {itemId, amount, meta}
local itemMetaCache       = {}   -- [itemId] = static item metadata
local filteredList        = {}   -- {stashCache entries}
local payloadSeen         = {}
local categorySet         = {}
local categoryList        = {}
local searchDebounce      = nil
local renderState         = { loadedCount = 0, selectedBox = nil }
local filterState         = { searchText = nil, stashIndex = nil, sellerIndex = nil, sortIndex = nil, filtered = false }
local stashHandle         = nil  -- handle from openModalOtui, used to destroy window on close
local itemBoxPool         = nil  -- ObjectPool<StashItemBox>
local suppressRenderEvents = false
-- LuaFormatter on
-- /*=============================================
-- =            Filter helpers                   =
-- =============================================*/
local function resetFilterState()
    filterState.searchText = nil
    filterState.stashIndex = nil
    filterState.sellerIndex = nil
    filterState.sortIndex = nil
    filterState.filtered = false
end

local function matchesCategory(entry, categoryTarget, imbuementOnly)
    if not categoryTarget and not imbuementOnly then
        return true
    end
    if imbuementOnly then
        return imbuementSet[entry.itemId] == true
    end
    return entry.meta.categoryName == categoryTarget
end

local function matchesSeller(meta, sellerTarget)
    if not sellerTarget then
        return true
    end
    return meta.npcSellSet[sellerTarget] == true
end

-- /*=============================================
-- =            Data layer                      =
-- =============================================*/

local function getItemMeta(itemId)
    local meta = itemMetaCache[itemId]
    if meta then
        return meta
    end
    local thingType = g_things.getThingType(itemId, 0)
    local name = ""
    local categoryName = ""
    local npcSellSet = {}
    if thingType then
        name = thingType:getName() or ""
        if thingType:isMarketable() then
            local mData = thingType:getMarketData()
            if mData then
                categoryName = categoryNames[mData.category] or ""
            end
            local nData = thingType:getNpcSaleData()
            if nData then
                for _, npc in ipairs(nData) do
                    if npc.name then
                        npcSellSet[npc.name:lower()] = true
                    end
                end
            end
        end
    end
    meta = {
        itemId = itemId,
        name = name,
        nameLower = name:lower(),
        categoryName = categoryName,
        npcSellSet = npcSellSet,
        thingType = thingType
    }
    itemMetaCache[itemId] = meta
    return meta
end

local function getStashEntry(itemId)
    local entry = stashCache[itemId]
    if entry then
        return entry
    end
    entry = {
        itemId = itemId,
        amount = 0,
        meta = getItemMeta(itemId)
    }
    stashCache[itemId] = entry
    return entry
end

local function applyFilters(searchText)
    local searchFilter = (searchText or W.inputs.search:getText() or ""):lower()
    local stashFilter = W.combos.stash.currentIndex ~= 1 and W.combos.stash:getCurrentOption()
    local sellerFilter = W.combos.seller.currentIndex ~= 1 and W.combos.seller:getCurrentOption()
    local categoryTarget = nil
    local imbuementOnly = false
    if stashFilter then
        local opt = stashFilter.text
        if opt == "Show Imbuement Items" then
            imbuementOnly = true
        else
            categoryTarget = opt:sub(6)
        end
    end
    local sellerTarget = sellerFilter and sellerFilter.text:sub(9):lower() or nil
    table.clear(filteredList)
    for _, entry in pairs(stashCache) do
        local meta = entry.meta
        local passSearch = #searchFilter == 0 or meta.nameLower:find(searchFilter, 1, true)
        if passSearch and matchesCategory(entry, categoryTarget, imbuementOnly) and matchesSeller(meta, sellerTarget) then
            table.insert(filteredList, entry)
        end
    end
    filterState.filtered = true
end

local function sortFilteredList()
    local func = sortFunctions[sortOrder[W.combos.sort.currentIndex]]
    if func then
        table.sort(filteredList, func)
    end
end

-- /*=============================================
-- =            Render layer                    =
-- =============================================*/

local function onStashItemBoxMousePress(itemBox, mousePos, mouseButton)
    if mouseButton ~= MouseLeftButton or not itemBox.itemId then
        return false
    end
    if g_keyboard.isCtrlPressed() then
        return false
    end
    if renderState.selectedBox and renderState.selectedBox ~= itemBox then
        renderState.selectedBox:setChecked(false)
    end
    renderState.selectedBox = itemBox
    itemBox:setChecked(true)
    prepareWithdraw(itemBox.itemId, itemBox.amount)
    return true
end

local function onStashItemMouseRelease(itemWidget, mousePos, mouseButton)
    if mouseButton ~= MouseRightButton and not (mouseButton == MouseLeftButton and g_keyboard.isCtrlPressed()) then
        return false
    end
    local itemBox = itemWidget.itemBox
    if not itemBox or not itemBox.itemId then
        return false
    end
    local itemId = itemBox.itemId
    local amount = itemBox.amount
    local name = itemBox.name
    local thingType = itemBox.thingType
    local moduleQuickLoot = modules.game_quickloot
    local menu = g_ui.createWidget('PopupMenu')
    menu:setGameMenu(true)
    menu:addOption(tr('Retrieve'), function()
        prepareWithdraw(itemId, amount)
    end)
    menu:addSeparator()
    menu:addOption(tr('Cyclopedia'), function()
        local cyc = modules.game_cyclopedia
        if not cyc then
            return
        end
        if cyc.controllerCyclopedia and cyc.controllerCyclopedia.ui and cyc.controllerCyclopedia.ui:isVisible() then
            cyc.SelectWindow('items', false)
        else
            cyc.show('items')
        end
        onSupplyStashClose()
        stashController:scheduleEvent(function()
            if cyc.Cyclopedia and cyc.Cyclopedia.ItemSearch then
                cyc.Cyclopedia.ItemSearch(name, false)
            end
        end, 100, "showDeliveryItemCyclopedia")
    end)
    if thingType and thingType:isMarketable() then
        menu:addSeparator()
        menu:addOption(tr('Show in Market'), function()
            local market = modules.game_market
            if not market or not market.onShowRedirect then
                return
            end
            onSupplyStashClose()
            market.onMarketEnter({}, 0, 0, 0)
            stashController:scheduleEvent(function()
                market.onShowRedirect(thingType)
            end, 100, "showDeliveryItemMarket")
        end)
    end
    if moduleQuickLoot and moduleQuickLoot.QuickLoot then
        menu:addSeparator()
        if not moduleQuickLoot.QuickLoot.lootExists(itemId) then
            menu:addOption(tr('Add to Loot List'), function()
                moduleQuickLoot.QuickLoot.addLootList(itemId)
            end)
        else
            menu:addOption(tr('Remove from Loot List'), function()
                moduleQuickLoot.QuickLoot.removeLootList(itemId)
            end)
        end
    end
    menu:display(mousePos)
end

local function createPooledItemBox()
    local itemBox = g_ui.createWidget('StashItemBox', W.poolBin)
    local itemWidget = itemBox:getChildById('item')
    itemBox.itemWidget = itemWidget
    itemWidget.itemBox = itemBox
    itemBox.onMousePress = onStashItemBoxMousePress
    itemWidget.onMouseRelease = onStashItemMouseRelease
    return itemBox
end

local function resetItems()
    if not W.panels.items then
        return
    end
    local panel = W.panels.items
    while panel:getChildCount() > 0 do
        itemBoxPool:release(panel:getChildByIndex(1))
    end
    renderState.selectedBox = nil
end

local function createItemBox(entry)
    local itemBox = itemBoxPool:get()
    itemBox:setParent(W.panels.items)
    local meta = entry.meta
    local itemWidget = itemBox.itemWidget or itemBox:getChildById('item')
    itemBox.itemId = entry.itemId
    itemBox.amount = entry.amount
    itemBox.name = meta.name
    itemBox.thingType = meta.thingType
    itemWidget:setItemId(entry.itemId)
    itemWidget:setDisplayCount(entry.amount)
    ItemsDatabase.setRarityItem(itemWidget, entry.itemId)
    itemBox:setTooltip(#meta.name > 0 and string.format("Name: %s \nCount: %d", meta.name, entry.amount) or "Loading...")
end

local function refreshRenderedItems()
    resetItems()
    renderState.loadedCount = 0
    renderState.selectedBox = nil
    loadNextBatch()
end

function renderItems(reason)
    if suppressRenderEvents then
        return
    end
    if not g_game.isOnline() then
        return
    end
    if not W.window then
        return
    end
    local searchText = W.inputs.search:getText() or ""
    local stashIndex = W.combos.stash.currentIndex
    local sellerIndex = W.combos.seller.currentIndex
    local sortIndex = W.combos.sort.currentIndex
    local filterChanged = reason == "data" or not filterState.filtered or searchText ~= filterState.searchText or
                              stashIndex ~= filterState.stashIndex or sellerIndex ~= filterState.sellerIndex
    local sortChanged = filterChanged or sortIndex ~= filterState.sortIndex
    if filterChanged then
        applyFilters(searchText)
    end
    if sortChanged then
        sortFilteredList()
    end
    filterState.searchText = searchText
    filterState.stashIndex = stashIndex
    filterState.sellerIndex = sellerIndex
    filterState.sortIndex = sortIndex
    refreshRenderedItems()
    if W.window:isHidden() then
        W.window:show()
        W.window:lock()
    end
end

-- /*=============================================
-- =            Scroll load                     =
-- =============================================*/

function loadNextBatch()
    local total = #filteredList
    local current = renderState.loadedCount
    if current >= total then
        return
    end
    local limit = math.min(total, current + BATCH_SIZE)
    for i = current + 1, limit do
        createItemBox(filteredList[i])
    end
    renderState.loadedCount = limit
end

local function onItemsPanelScroll(widget, offset)
    if renderState.loadedCount >= #filteredList then
        return
    end
    local maxScroll = W.scrollbar:getMaximum()
    if offset.y >= maxScroll - SCROLL_THRESHOLD then
        loadNextBatch()
    end
end

-- /*=============================================
-- =            Search debounce            =
-- =============================================*/

function onSearchChange()
    if searchDebounce then
        searchDebounce:cancel()
        searchDebounce = nil
    end
    searchDebounce = scheduleEvent(renderItems, 150, "searchDebounce")
end

-- /*=============================================
-- =            Modal: withdraw amount            =
-- =============================================*/
local function resetSelectAmount()
    if W.modal.selectAmount then
        W.modal.selectAmount:destroy()
        W.modal.selectAmount = nil
    end
end

function prepareWithdraw(itemId, itemAmount)
    resetSelectAmount()
    W.modal.selectAmount = g_ui.createWidget('StashSelectAmount', rootWidget)
    W.modal.selectAmount:lock()
    local itembox = W.modal.selectAmount:getChildById('item')
    local scrollbar = W.modal.selectAmount:getChildById('countScrollBar')
    itembox:setItemId(itemId)
    itembox:setDisplayCount(itemAmount)
    scrollbar:setMaximum(itemAmount)
    scrollbar:setMinimum(1)
    scrollbar:setValue(itemAmount)
    scrollbar.onValueChange = function(_, value)
        itembox:setDisplayCount(value)
    end
    g_keyboard.bindKeyPress('Up', function()
        scrollbar:setValue(scrollbar:getValue() + 10)
    end, W.modal.selectAmount)
    g_keyboard.bindKeyPress('Down', function()
        scrollbar:setValue(scrollbar:getValue() - 10)
    end, W.modal.selectAmount)
    g_keyboard.bindKeyPress('Right', function()
        scrollbar:onIncrement()
    end, W.modal.selectAmount)
    g_keyboard.bindKeyPress('Left', function()
        scrollbar:onDecrement()
    end, W.modal.selectAmount)
    g_keyboard.bindKeyPress('PageUp', function()
        scrollbar:setValue(scrollbar:getMaximum())
    end, W.modal.selectAmount)
    g_keyboard.bindKeyPress('PageDown', function()
        scrollbar:setValue(scrollbar:getMinimum())
    end, W.modal.selectAmount)
    local function withdraw()
        g_game.stashWithdraw(itemId, scrollbar:getValue(), 1)
        W.modal.selectAmount:unlock()
        resetSelectAmount()
    end
    local function cancel()
        W.modal.selectAmount:unlock()
        resetSelectAmount()
    end
    W.modal.selectAmount.onEnter = withdraw
    W.modal.selectAmount.onEscape = cancel
    W.modal.selectAmount:getChildById('buttonOk').onClick = withdraw
    W.modal.selectAmount:getChildById('buttonCancel').onClick = cancel
end

-- /*=============================================
-- =            Viewport geometry            =
-- =============================================*/
local function recomputeViewport()
    local cols = math.max(1, math.floor(W.panels.items:getWidth() / CELL_SIZE))
    local rows = math.max(1, math.floor(W.panels.items:getHeight() / CELL_SIZE))
    BATCH_SIZE = cols * (rows + 1) -- full viewport + 1 row overscan
    SCROLL_THRESHOLD = CELL_SIZE * 3 -- trigger 3 rows before bottom
end

-- /*=============================================
-- =            Window setup / teardown          =
-- =============================================*/

local function destroyWindow()
    if not stashHandle then
        return
    end
    itemBoxPool = nil
    stashController:closeModalOtui(stashHandle)
    stashHandle = nil
    W.window = nil
    W.poolBin = nil
    W.panels.items = nil
    W.inputs.search = nil
    W.combos.stash = nil
    W.combos.seller = nil
    W.combos.sort = nil
    W.scrollbar = nil
    W.buttons.manage = nil
    W.buttons.close = nil
end

local function ensureWindow()
    if W.window then
        return true
    end
    stashHandle = stashController:openModalOtui('StashWindow')
    if not stashHandle or not stashHandle.ui then
        return false
    end
    W.window = stashHandle.ui
    W.panels.items = W.window:recursiveGetChildById('itemsPanel')
    W.inputs.search = W.window:recursiveGetChildById('searchEdit')
    W.combos.stash = W.window:recursiveGetChildById('stashCombo')
    W.combos.seller = W.window:recursiveGetChildById('sellerCombo')
    W.combos.sort = W.window:recursiveGetChildById('sortCombo')
    W.scrollbar = W.window:recursiveGetChildById('itemsPanelListScrollBar')
    W.buttons.manage = W.window:recursiveGetChildById('manageButton')
    W.buttons.close = W.window:recursiveGetChildById('closeButton')
    W.window:hide()
    W.poolBin = g_ui.createWidget('UIWidget', W.window)
    W.poolBin:hide()
    W.poolBin:setWidth(0)
    W.poolBin:setHeight(0)
    itemBoxPool = ObjectPool.new(createPooledItemBox, function(itemBox)
        itemBox:setChecked(false)
        itemBox:setTooltip('')
        itemBox.itemId = nil
        itemBox.amount = nil
        itemBox.name = nil
        itemBox.thingType = nil
        itemBox:setParent(W.poolBin)
    end)
    W.panels.items.onScrollChange = onItemsPanelScroll
    local oldSuppress = suppressRenderEvents
    suppressRenderEvents = true
    W.combos.stash:addOption("Show All")
    W.combos.stash:setCurrentOption("Show All", true)
    for _, name in ipairs(sellers) do
        W.combos.seller:addOption(name)
    end
    W.combos.seller:setCurrentOption("No Trader Selected", true)
    for _, name in ipairs(sortOrder) do
        W.combos.sort:addOption(name)
    end
    W.combos.sort:setCurrentOption(sortOrder[1], true)
    suppressRenderEvents = oldSuppress
    recomputeViewport()
    return true
end

-- /*=============================================
-- =            Server event handlers            =
-- =============================================*/

local function onSupplyStashEnter(payload)
    if not ensureWindow() then
        return
    end
    if not W.window then
        return
    end
    table.clear(payloadSeen)
    table.clear(categorySet)
    table.clear(categoryList)
    for i = 1, #payload do
        local itemId = payload[i][1]
        local amount = payload[i][2]
        local entry = getStashEntry(itemId)
        payloadSeen[itemId] = true
        entry.amount = amount
        if entry.meta.categoryName ~= "" then
            categorySet[entry.meta.categoryName] = true
        end
    end
    for itemId in pairs(stashCache) do
        if not payloadSeen[itemId] then
            stashCache[itemId] = nil
        end
    end
    local oldSuppress = suppressRenderEvents
    suppressRenderEvents = true
    W.combos.stash:clearOptions()
    W.combos.stash:addOption("Show All")
    for catName in pairs(categorySet) do
        table.insert(categoryList, catName)
    end
    table.sort(categoryList)
    table.insert(categoryList, "Imbuement Items")
    for _, catName in ipairs(categoryList) do
        W.combos.stash:addOption("Show " .. catName)
    end
    W.combos.stash:setCurrentOption("Show All", true)
    suppressRenderEvents = oldSuppress
    renderItems("data")
end

-- /*=============================================
-- =            onClick Button                   =
-- =============================================*/

function onSupplyStashClose()
    if not W.window then
        return
    end
    table.clear(stashCache)
    table.clear(itemMetaCache)
    table.clear(filteredList)
    table.clear(payloadSeen)
    table.clear(categorySet)
    table.clear(categoryList)
    renderState.loadedCount = 0
    renderState.selectedBox = nil
    resetFilterState()
    resetSelectAmount()
    if searchDebounce then
        searchDebounce:cancel()
        searchDebounce = nil
    end
    modules.game_interface.getRootPanel():focus()
    destroyWindow()
end

function openManageContainers()
    onSupplyStashClose()
    modules.game_quickloot.QuickLoot.toggle()
end

-- /*=============================================
-- =            Controller                       =
-- =============================================*/

function stashController:onInit()

end

function stashController:onGameStart()
    local version = g_game.getClientVersion()
    if version < 1180 then
        return
    end
    g_ui.importStyle('game_stash')
    stashController:registerEvents(g_game, {
        onSupplyStashEnter = onSupplyStashEnter
    })
end

function stashController:onGameEnd()
    onSupplyStashClose()
end

function stashController:onTerminate()
    resetSelectAmount()
    itemBoxPool = nil
    stashHandle = nil
    W.window = nil
    table.clear(stashCache)
    table.clear(itemMetaCache)
    table.clear(filteredList)
    table.clear(payloadSeen)
    table.clear(categorySet)
    table.clear(categoryList)
    resetFilterState()
    if searchDebounce then
        searchDebounce:cancel()
        searchDebounce = nil
    end
end
