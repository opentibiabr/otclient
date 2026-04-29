Cyclopedia.Items = {}

-- Additional variables for new features
local itemsData = {}
local lastSelectedItem = nil
local oldBuyChild = nil
local oldSaleChild = nil

Cyclopedia.CategoryItems = {
    { id = 1, name = "Armors" },
    { id = 2, name = "Amulets" },
    { id = 3, name = "Boots" },
    { id = 4, name = "Containers" },
    { id = 24, name = "Creature Products" },
    { id = 5, name = "Decoration" },
    { id = 6, name = "Food" },
    { id = 30, name = "Gold" },
    { id = 7, name = "Helmets and Hats" },
    { id = 8, name = "Legs" },
    { id = 9, name = "Others" },
    { id = 10, name = "Potions" },
    { id = 25, name = "Quivers" },
    { id = 11, name = "Rings" },
    { id = 12, name = "Runes" },
    { id = 13, name = "Shields" },
    { id = 26, name = "Soul Cores" },
    { id = 14, name = "Tools" },
    { id = 31, name = "Unsorted" },
    { id = 15, name = "Valuables" },
    { id = 16, name = "Weapons: Ammo" },
    { id = 17, name = "Weapons: Axe" },
    { id = 18, name = "Weapons: Clubs" },
    { id = 19, name = "Weapons: Distance" },
    { id = 20, name = "Weapons: Swords" },
    { id = 21, name = "Weapons: Wands" },
    { id = 1000, name = "Weapons: All" }
}

local UI = nil

focusCategoryList = nil

local function getItemsViewState()
    local defaults = {
        selectedCategoryId = nil,
        searchText = "",
        vocationFilter = false,
        levelFilter = false,
        h1Filter = false,
        h2Filter = false,
        classificationFilter = 0,
        selectedItemId = nil
    }

    if Cyclopedia.getTabState then
        return Cyclopedia.getTabState("items", defaults)
    end

    return defaults
end

local function saveItemsViewState(statePatch)
    if Cyclopedia.saveTabState then
        Cyclopedia.saveTabState("items", statePatch)
    end
end

-- JSON Data Management Functions
function Cyclopedia.Items.terminate()
	Cyclopedia.Items.saveJson()
end

function Cyclopedia.Items.loadJson()
	if not LoadedPlayer or not LoadedPlayer:isLoaded() then
		return true
	end

	local file = "/characterdata/" .. LoadedPlayer:getId() .. "/itemprices.json"
	if g_resources.fileExists(file) then
		local status, result = pcall(function()
			return json.decode(g_resources.readFileContents(file))
		end)

		if not status then
			g_logger.error("Error while reading characterdata file. Details: " .. result)
			-- Initialize with empty data on error
			itemsData = {
				["primaryLootValueSources"] = {},
				["customSalePrices"] = {}
			}
			return
		end

		itemsData = result
	else
		itemsData = {
			["customSalePrices"] = {},
			["primaryLootValueSources"] = {}
		}
		Cyclopedia.Items.saveJson()
	end

	if table.empty(itemsData) then
		itemsData = {
			["primaryLootValueSources"] = {},
			["customSalePrices"] = {}
		}
	end

	-- Ensure both required tables exist
	if not itemsData["primaryLootValueSources"] then
		itemsData["primaryLootValueSources"] = {}
	end
	if not itemsData["customSalePrices"] then
		itemsData["customSalePrices"] = {}
	end
	if not itemsData["dropTrackerItems"] then
		itemsData["dropTrackerItems"] = {}
	end

	local useMarketPrice = {}
	for k, v in pairs(itemsData["primaryLootValueSources"]) do
		table.insert(useMarketPrice, k)
	end

	local customPrice = {}
	if g_things.getItemsPrice then
		customPrice = g_things.getItemsPrice()
	end
	
	for k, v in pairs(itemsData["customSalePrices"]) do
		local key = tonumber(k) or k
		customPrice[key] = v
	end

	local player = g_game.getLocalPlayer()
	if not player then
		return true
	end

	if player.setCyclopediaMarketList then
		player:setCyclopediaMarketList(useMarketPrice)
	end
	if player.setCyclopediaCustomPrice then
		player:setCyclopediaCustomPrice(customPrice)
	end
end

function Cyclopedia.Items.saveJson()
	if not LoadedPlayer or not LoadedPlayer:isLoaded() then
		return true
	end

	local file = "/characterdata/" .. LoadedPlayer:getId() .. "/itemprices.json"
	local status, result = pcall(function() return json.encode(itemsData, 2) end)
	if not status then
		g_logger.error("Error while saving profile itemsData. Data won't be saved. Details: " .. result)
		return
	end

	if result:len() > 100 * 1024 * 1024 then
		g_logger.error("Something went wrong, file is above 100MB, won't be saved")
		return
	end
	g_resources.writeFileContents(file, result)
end

function Cyclopedia.ResetItemCategorySelection(list)
    for i, child in pairs(list:getChildren()) do
        child:setChecked(false)
        child:setBackgroundColor(child.BaseColor)
    end
end

-- Get NPC buy value for a ThingType or Item
-- @param itemOrThingType: The Item or ThingType object (both have getNpcSaleData method)
-- @param useBuyPrice: true for buyPrice (what NPCs pay us), false for salePrice (what NPCs charge us)
function Cyclopedia.Items.getNpcValue(itemOrThingType, useBuyPrice)
	local npcValue = 0
	if useBuyPrice == nil then
		useBuyPrice = true  -- Default to buyPrice for backward compatibility
	end
	
	if itemOrThingType and itemOrThingType.getNpcSaleData then
		local success, npcSaleData = pcall(function() return itemOrThingType:getNpcSaleData() end)
		if success and npcSaleData and #npcSaleData > 0 then
			if useBuyPrice then
				-- Get the highest buy price from NPCs (what NPCs will pay us for the item)
				for _, npcData in ipairs(npcSaleData) do
					if npcData.buyPrice and npcData.buyPrice > npcValue then
						npcValue = npcData.buyPrice
					end
				end
			else
				-- Get the highest sale price from NPCs (what NPCs charge us for the item)
				-- Note: Using 'salePrice' (not 'sellPrice') based on actual API data
				for _, npcData in ipairs(npcSaleData) do
					if npcData.salePrice and npcData.salePrice > npcValue then
						npcValue = npcData.salePrice
					end
				end
			end
		end
	end
	
	return npcValue
end

-- Function to calculate market offer averages: (sell offers average + buy offers average) / 2
function Cyclopedia.Items.getMarketOfferAverages(itemId)
	-- TODO: Access market statistics from game_market module to get:
	-- 1. Sell offers average price (from saleOfferStatistic in Market.updateDetails)
	-- 2. Buy offers average price (from purchaseOfferStatistic in Market.updateDetails)
	-- 3. Calculate (sellAverage + buyAverage) / 2
	
	-- The market statistics are processed in modules/game_market/market.lua in the updateDetails function
	-- We need to either:
	-- A) Add a public function in Market module to get averages for a specific itemId
	-- B) Request market details for the itemId and cache the results
	-- C) Access the market statistics data structures directly if they're made global
	
	-- Current market average calculation logic from market.lua (for reference):
	-- if totalPrice > 0 and transactions > 0 then
	--     averagePrice = math.floor(totalPrice / transactions)
	-- end
	
	-- For now, return 0 until market statistics access is implemented
	return 0
end

-- Advanced Item Value Functions
function Cyclopedia.Items.showItemPrice(obj)
	if not obj then
		return 0
	end

	-- Detect object type and get the necessary data
	local item, thingType, itemId
	if obj.getMarketData then
		-- This is a ThingType object
		thingType = obj
		itemId = thingType:getId()
		-- Create Item from ThingType for compatibility
		item = Item.create(itemId)
	else
		-- This is an Item object
		item = obj
		itemId = item:getId()
		thingType = g_things.getThingType(itemId, ThingCategoryItem)
	end

	-- Use getMarketOfferAverages() with safety checks
	local avgMarket = 0
	if itemId then
		avgMarket = Cyclopedia.Items.getMarketOfferAverages(itemId)
	end
	
	if UI.InfoBase.MarketGoldPriceBase and UI.InfoBase.MarketGoldPriceBase.Value then
        -- Calculate market offer averages: (sell offers average + buy offers average) / 2
        local marketOfferAverages = Cyclopedia.Items.getMarketOfferAverages(itemId)        
		UI.InfoBase.MarketGoldPriceBase.Value:setText(comma_value(marketOfferAverages))
	end

	local isMarketPrice = false
	if itemsData["primaryLootValueSources"] and itemsData["primaryLootValueSources"][tostring(itemId)] then
		isMarketPrice = true
	end

	-- Get NPC value (use thingType if available, fallback to item)
	local npcValue = Cyclopedia.Items.getNpcValue(thingType or item, true)
	
	-- If no NPC buy price found, fallback to market average price
	if npcValue == 0 then
		npcValue = avgMarket
	end

	-- Priority 1: Custom value always takes precedence
	local resulting = 0
	if itemsData["customSalePrices"] and itemsData["customSalePrices"][tostring(itemId)] then
		resulting = itemsData["customSalePrices"][tostring(itemId)]
		if UI.InfoBase.OwnValueEdit then
			UI.InfoBase.OwnValueEdit:setText(tostring(resulting))
		end
	else
		-- Priority 2 & 3: Use selected loot value source
		if isMarketPrice then
			resulting = avgMarket  -- Use market price
		else
			resulting = npcValue   -- Use NPC price
		end
		
		-- Clear custom value field since no custom value is set
		if UI.InfoBase.OwnValueEdit then
			UI.InfoBase.OwnValueEdit:clearText(true)
		end
	end

	-- Update ResultGoldBase.Value using the new calculation logic
	Cyclopedia.Items.updateResultGoldValue(itemId, resulting, avgMarket, npcValue)

	-- Update loot value source checkboxes
	if UI.LootValue then
		if isMarketPrice then
			UI.LootValue.NpcBuyCheck:setChecked(false)
			UI.LootValue.MarketCheck:setChecked(true)
		else
			UI.LootValue.NpcBuyCheck:setChecked(true)
			UI.LootValue.MarketCheck:setChecked(false)
		end
	end

	return resulting
end

function Cyclopedia.Items.getCurrentItemValue(item)
	if not item then
		return 0
	end

	-- Use getMarketOfferAverages() with safety checks
	local avgMarket = 0
	local itemId = item:getId()
	if itemId then
		avgMarket = Cyclopedia.Items.getMarketOfferAverages(itemId)
	end

	local isMarketPrice = false
	if itemsData["primaryLootValueSources"] and itemsData["primaryLootValueSources"][tostring(item:getId())] then
		isMarketPrice = true
	end

	-- Get NPC value
	local npcValue = Cyclopedia.Items.getNpcValue(item, true)
	
	-- If no NPC buy price found, fallback to market average price
	if npcValue == 0 then
		npcValue = avgMarket
	end

	-- Priority 1: Custom value always takes precedence
	local resulting = 0
	if itemsData["customSalePrices"] and itemsData["customSalePrices"][tostring(item:getId())] then
		resulting = itemsData["customSalePrices"][tostring(item:getId())]
	else
		-- Priority 2 & 3: Use selected loot value source
		if isMarketPrice then
			resulting = avgMarket  -- Use market price
		else
			resulting = npcValue   -- Use NPC price
		end
	end
	
	return resulting
end

-- Function to update ResultGoldBase.Value based on conditions
-- Priority logic:
-- 1. If OwnValueEdit has content: Use custom value
-- 2. If OwnValueEdit is empty and "NPC Buy Value" selected: Use getNpcValue (buyPrice)
-- 3. If OwnValueEdit is empty and "Market Average Value" selected:
--    a. If MarketGoldPriceBase.Value > 0: Use market value
--    b. If MarketGoldPriceBase.Value = 0: Fallback to getNpcValue (buyPrice)
-- 4. If none of the above applies or all values are 0/nil: Set to 0
function Cyclopedia.Items.updateResultGoldValue(itemId, customValue, avgMarket, npcValue)
	if not UI.InfoBase.ResultGoldBase or not UI.InfoBase.ResultGoldBase.Value then
		return
	end
	
	local finalValue = customValue
	
	-- Check if OwnValueEdit field is empty (no custom value)
	local ownValueText = ""
	if UI.InfoBase.OwnValueEdit then
		ownValueText = UI.InfoBase.OwnValueEdit:getText() or ""
		ownValueText = ownValueText:gsub("%s+", "") -- Remove whitespace
	end
	
	-- If OwnValueEdit is empty AND no custom value is stored
	if #ownValueText == 0 and (not itemsData["customSalePrices"] or not itemsData["customSalePrices"][tostring(itemId)]) then
		-- Check which loot value source is selected using the same logic as showItemPrice
		local isMarketPrice = false
		if itemsData["primaryLootValueSources"] and itemsData["primaryLootValueSources"][tostring(itemId)] then
			isMarketPrice = true
		end
		
		if isMarketPrice then
			-- Use Market Average Value (MarketGoldPriceBase.Value)
			local marketValue = 0
			if UI.InfoBase.MarketGoldPriceBase and UI.InfoBase.MarketGoldPriceBase.Value then
				local marketValueText = UI.InfoBase.MarketGoldPriceBase.Value:getText() or "0"
				marketValueText = marketValueText:gsub(",", "") -- Remove commas
				marketValue = tonumber(marketValueText) or 0
			end
			
			-- Enhancement: If market value is 0 or nil, fallback to NPC value
			if marketValue == 0 then
				finalValue = npcValue
			else
				finalValue = marketValue
			end
		else
			-- Use NPC Buy Value (getNpcValue function output, buyPrice)
			finalValue = npcValue
		end
		
		-- Final fallback: if all values are 0 or nil, set to 0
		if not finalValue or finalValue == 0 then
			finalValue = 0
		end
	end
	
	-- Update the ResultGoldBase.Value display
	UI.InfoBase.ResultGoldBase.Value:setText(comma_value(finalValue))
	
	-- Update rarity visual indicator based on final value
	if finalValue > 0 and UI.InfoBase.ResultGoldBase.Rarity then
		ItemsDatabase.setRarityItem(UI.InfoBase.ResultGoldBase.Rarity, finalValue)
	elseif UI.InfoBase.ResultGoldBase.Rarity then
		UI.InfoBase.ResultGoldBase.Rarity:setImageSource("")
	end
	
	return finalValue
end

-- External accessor function to get ResultGoldBase value directly
function Cyclopedia.Items.getResultGoldValue()
	if not UI.InfoBase.ResultGoldBase or not UI.InfoBase.ResultGoldBase.Value then
		return 0
	end
	
	local valueText = UI.InfoBase.ResultGoldBase.Value:getText() or "0"
	valueText = valueText:gsub(",", "") -- Remove commas
	return tonumber(valueText) or 0
end

function Cyclopedia.Items.onSourceValueChange(checked, npcSource)
	if checked or not lastSelectedItem then
		return
	end

	local player = g_game.getLocalPlayer()
	if not player then
		return
	end

	local item = lastSelectedItem.Sprite:getItem()
	if not item then
		return
	end
	
	local itemId = item:getId()
	local currentItemID = tostring(itemId)
	local currentPrice = 0

	if not itemsData["primaryLootValueSources"] then
		itemsData["primaryLootValueSources"] = {}
	end

	if npcSource then
		local newItemList = {}
		newItemList["primaryLootValueSources"] = {}
		for k, v in pairs(itemsData["primaryLootValueSources"]) do
			if k ~= currentItemID then
				newItemList["primaryLootValueSources"][k] = v
			end
		end

		itemsData["primaryLootValueSources"] = newItemList["primaryLootValueSources"]
		Cyclopedia.Items.showItemPrice(item)
		if player.updateCyclopediaMarketList then
			player:updateCyclopediaMarketList(itemId, true)
		end
	else
		itemsData["primaryLootValueSources"][currentItemID] = "market"
		Cyclopedia.Items.showItemPrice(item)
		if player.updateCyclopediaMarketList then
			player:updateCyclopediaMarketList(itemId, false)
		end
	end

	-- Get the actual value displayed in ResultGoldBase.Value (same logic as updateResultGoldValue)
	if UI.InfoBase.ResultGoldBase and UI.InfoBase.ResultGoldBase.Value then
		local valueText = UI.InfoBase.ResultGoldBase.Value:getText() or "0"
		valueText = valueText:gsub(",", "") -- Remove commas
		currentPrice = tonumber(valueText) or 0
	else
		-- Fallback: calculate using the same logic as updateResultGoldValue
		local isMarketPrice = false
		if itemsData["primaryLootValueSources"] and itemsData["primaryLootValueSources"][currentItemID] then
			isMarketPrice = true
		end
		
		-- Check if there's a custom price
		if itemsData["customSalePrices"] and itemsData["customSalePrices"][currentItemID] then
			currentPrice = itemsData["customSalePrices"][currentItemID]
		else
			-- Get the necessary values
			local avgMarket = 0
			local npcValue = 0
			local marketOfferAverages = 0
			
			-- Get market offer averages (same as MarketGoldPriceBase.Value)
			marketOfferAverages = Cyclopedia.Items.getMarketOfferAverages(itemId)
			avgMarket = marketOfferAverages  -- Use the same value for consistency
			
			-- Get NPC value
			npcValue = Cyclopedia.Items.getNpcValue(item, true)
			
			-- Apply the same logic as updateResultGoldValue
			if isMarketPrice then
				-- Market Average Value is selected
				if marketOfferAverages > 0 then
					currentPrice = marketOfferAverages
				else
					-- Enhancement: If market offer averages is 0, fallback to NPC value
					currentPrice = npcValue
				end
			else
				-- NPC Buy Value is selected (default)
				currentPrice = npcValue
			end
		end
	end

	if player.updateCyclopediaCustomPrice then
		player:updateCyclopediaCustomPrice(itemId, currentPrice)
	end
	
	-- Update analyzer modules if they exist
	if modules.game_analyser then
		if modules.game_analyser.HuntingAnalyser and modules.game_analyser.HuntingAnalyser.updateLootedItemValue then
			modules.game_analyser.HuntingAnalyser:updateLootedItemValue(itemId, currentPrice)
		end
		if modules.game_analyser.LootAnalyser and modules.game_analyser.LootAnalyser.updateBasePriceFromLootedItems then
			modules.game_analyser.LootAnalyser:updateBasePriceFromLootedItems(itemId, currentPrice)
		end
	end
end

function Cyclopedia.Items.onChangeCustomPrice(widget)
	if not lastSelectedItem then
		return
	end

	local player = g_game.getLocalPlayer()
	if not player then
		return
	end

	local currentText = widget:getText()
	local item = lastSelectedItem.Sprite:getItem()
	local itemId = item:getId()
	local itemIdStr = tostring(itemId)
	
	if not itemsData["customSalePrices"] then
		itemsData["customSalePrices"] = {}
	end

	if #currentText == 0 then
		local newItemList = {}
		newItemList["customSalePrices"] = {}

		for k, v in pairs(itemsData["customSalePrices"]) do
			if k ~= itemIdStr then
				newItemList["customSalePrices"][k] = v
			end
		end

		itemsData["customSalePrices"] = newItemList["customSalePrices"]
		Cyclopedia.Items.showItemPrice(item)
		
		-- Get the current item value (NPC or market based on selection)
		local itemDefaultValue = Cyclopedia.Items.getCurrentItemValue(item)
		
		if player.updateCyclopediaCustomPrice then
			player:updateCyclopediaCustomPrice(itemId, itemDefaultValue)
		end
		
		-- Update analyzer modules if they exist
		if modules.game_analyser then
			if modules.game_analyser.HuntingAnalyser then
				modules.game_analyser.HuntingAnalyser:updateLootedItemValue(itemId, itemDefaultValue)
			end
			if modules.game_analyser.LootAnalyser then
				modules.game_analyser.LootAnalyser:updateBasePriceFromLootedItems(itemId, itemDefaultValue)
			end
		end
		return
	end

	currentText = currentText:gsub("[^%d]", "")
	widget:setText(currentText)

	local numericValue = tonumber(currentText)
	if numericValue then
		if numericValue >= 999999999 then
			currentText = "999999999"
			widget:setText(currentText)
		end
	end

	numericValue = tonumber(currentText)
	if not numericValue then
		widget:setText("0")
		numericValue = 0
	end

	itemsData["customSalePrices"][itemIdStr] = numericValue
	
	-- Update result display using our new logic
	-- Get necessary values for the update function
	local avgMarket = Cyclopedia.Items.getMarketOfferAverages(itemId)
	local npcValue = Cyclopedia.Items.getNpcValue(item, true)
	
	Cyclopedia.Items.updateResultGoldValue(itemId, numericValue, avgMarket, npcValue)
	
	if player.updateCyclopediaCustomPrice then
		player:updateCyclopediaCustomPrice(itemId, numericValue)
	end
	
	-- Update analyzer modules if they exist
	if modules.game_analyser then
		if modules.game_analyser.LootAnalyser then
			modules.game_analyser.LootAnalyser:updateBasePriceFromLootedItems(itemId, numericValue)
		end
		if modules.game_analyser.HuntingAnalyser then
			modules.game_analyser.HuntingAnalyser:updateLootedItemValue(itemId, numericValue)
		end
	end
end

function showItems()
    UI = g_ui.loadUI("items", contentContainer)
    UI:show()
    local viewState = getItemsViewState()
    Cyclopedia.Items.VocFilter = viewState.vocationFilter == true
    Cyclopedia.Items.LevelFilter = viewState.levelFilter == true
    Cyclopedia.Items.h1Filter = viewState.h1Filter == true
    Cyclopedia.Items.h2Filter = viewState.h2Filter == true
    Cyclopedia.Items.ClassificationFilter = tonumber(viewState.classificationFilter) or 0
    UI.selectedCategory = nil
    UI.LootValue.NpcBuyCheck.onClick = Cyclopedia.onChangeLootValue
    UI.LootValue.MarketCheck.onClick = Cyclopedia.onChangeLootValue
    UI.EmptyLabel:setVisible(true)
    UI.InfoBase:setVisible(false)
    UI.LootValue:setVisible(false)
    UI.H1Button:disable()
    UI.H2Button:disable()
    UI.ItemFilter:disable()
    
    -- Initialize itemsData
    if table.empty(itemsData) then
        itemsData = {
            ["primaryLootValueSources"] = {},
            ["customSalePrices"] = {}
        }
    end
    
    -- Load JSON data
    Cyclopedia.Items.loadJson()
    
    -- Register inspection handler
    if g_game.sendInspectionObject then
        connect(g_game, { onInspectionObject = Cyclopedia.Items.onInspection })
    end
    
    controllerCyclopedia.ui.CharmsBase:setVisible(false)
    controllerCyclopedia.ui.GoldBase:setVisible(false)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(false)
    end
    local CategoryColor = "#484848"

    for _, data in ipairs(Cyclopedia.CategoryItems) do
        local ItemCat = g_ui.createWidget("ItemCategory", UI.CategoryList)

        ItemCat:setId(data.id)
        ItemCat:setText(data.name)
        ItemCat:setBackgroundColor(CategoryColor)
        ItemCat:setPhantom(false)
        ItemCat.BaseColor = CategoryColor

        function ItemCat:onClick()
            Cyclopedia.ResetItemCategorySelection(UI.CategoryList)
            self:setChecked(true)
            self:setBackgroundColor("#585858")
            Cyclopedia.onCategoryChange(self)
        end

        CategoryColor = CategoryColor == "#484848" and "#414141" or "#484848"
    end

    Cyclopedia.ItemList = {}
    Cyclopedia.AllItemList = {}
    Cyclopedia.loadItemsCategories()

    focusCategoryList = UI.CategoryList

    g_keyboard.bindKeyPress('Down', function()
        focusCategoryList:focusNextChild(KeyboardFocusReason)
    end, focusCategoryList:getParent())

    g_keyboard.bindKeyPress('Up', function()
        focusCategoryList:focusPreviousChild(KeyboardFocusReason)
    end, focusCategoryList:getParent())

    connect(focusCategoryList, {
        onChildFocusChange = function(self, focusedChild)
            if focusedChild == nil then
                return
            end
            focusedChild:onClick()
        end
    })

    local selectedCategoryId = tonumber(viewState.selectedCategoryId)
    if selectedCategoryId then
        for _, child in pairs(UI.CategoryList:getChildren()) do
            if tonumber(child:getId()) == selectedCategoryId then
                child:onClick()
                break
            end
        end

        UI.LevelButton:setChecked(Cyclopedia.Items.LevelFilter)
        UI.VocationButton:setChecked(Cyclopedia.Items.VocFilter)

        if Cyclopedia.Items.h1Filter then
            UI.H1Button:setChecked(true)
        elseif Cyclopedia.Items.h2Filter then
            UI.H2Button:setChecked(true)
        end

        if UI.ItemFilter:isEnabled() then
            local classFilter = Cyclopedia.Items.ClassificationFilter
            if classFilter == -1 then
                UI.ItemFilter:setOption("None", true)
            elseif classFilter >= 1 and classFilter <= 4 then
                UI.ItemFilter:setOption("Class " .. classFilter, true)
            else
                UI.ItemFilter:setOption("All", true)
            end
        end
    end

    UI.SearchEdit:setText(viewState.searchText or "")
    if UI.SearchEdit:getText() ~= "" then
        Cyclopedia.ItemSearch(UI.SearchEdit:getText(), false)
    end

    local selectedItemId = tonumber(viewState.selectedItemId)
    if selectedItemId then
        for _, child in pairs(UI.ItemListBase.List:getChildren()) do
            if tonumber(child:getId()) == selectedItemId and child.onClick then
                child:onClick()
                break
            end
        end
    end
end

function Cyclopedia.onCategoryChange(widget)
    if widget:isChecked() then
        local categoryId = tonumber(widget:getId())
        Cyclopedia.selectItemCategory(categoryId)
        UI.selectedCategory = widget
        saveItemsViewState({ selectedCategoryId = categoryId })
    end
end

function Cyclopedia.onChangeLootValue(widget)
    if widget:getId() == "NpcBuyCheck" then
        Cyclopedia.Items.onSourceValueChange(widget:isChecked(), true)
    elseif widget:getId() == "MarketCheck" then
        Cyclopedia.Items.onSourceValueChange(widget:isChecked(), false)
    end
end

function Cyclopedia.vocationFilter(value)
    UI.ItemListBase.List:destroyChildren()
    Cyclopedia.Items.VocFilter = value
    saveItemsViewState({ vocationFilter = value == true })
    Cyclopedia.applyFilters()
end

function Cyclopedia.levelFilter(value)
    UI.ItemListBase.List:destroyChildren()
    Cyclopedia.Items.LevelFilter = value
    saveItemsViewState({ levelFilter = value == true })
    Cyclopedia.applyFilters()
end

local ignoreRecursiveCalls = false
local function setCheckedWithoutRecursion(h1Val, h2Val)
    ignoreRecursiveCalls = true
    UI.H1Button:setChecked(h1Val)
    UI.H2Button:setChecked(h2Val)
    ignoreRecursiveCalls = false
end

function Cyclopedia.handFilter(h1Val, h2Val)
    Cyclopedia.Items.h1Filter = h1Val
    Cyclopedia.Items.h2Filter = h2Val
    saveItemsViewState({
        h1Filter = h1Val == true,
        h2Filter = h2Val == true
    })

    if ignoreRecursiveCalls then
        return
    end

    setCheckedWithoutRecursion(h1Val, h2Val)
    UI.ItemListBase.List:destroyChildren()
    Cyclopedia.applyFilters()
end

function Cyclopedia.classificationFilter(data)
    UI.ItemListBase.List:destroyChildren()
    Cyclopedia.Items.ClassificationFilter = tonumber(data)
    saveItemsViewState({ classificationFilter = Cyclopedia.Items.ClassificationFilter })
    Cyclopedia.applyFilters()
end

local function processItemsById(id)
    local idsToProcess = {}
    local tempTable = {}

    if id == 1000 then
        idsToProcess = {17, 18, 19, 20, 21}
    else
        idsToProcess = {id}
    end

    for _, idToProcess in pairs(idsToProcess) do
        if not table.empty(Cyclopedia.ItemList[idToProcess]) then
            for _, data in pairs(Cyclopedia.ItemList[idToProcess]) do
                table.insert(tempTable, data)
            end
        end
    end

    table.sort(tempTable, function(a, b)
        return string.lower(a:getMarketData().name) < string.lower((b:getMarketData().name))
    end)

    for _, data in pairs(tempTable) do
        local item = Cyclopedia.internalCreateItem(data)
    end
end

function Cyclopedia.applyFilters()
    local isSearching = UI.SearchEdit:getText() ~= ""
    if not isSearching then
        if UI.selectedCategory then
           processItemsById(tonumber(UI.selectedCategory:getId()))
        end
    else
        Cyclopedia.ItemSearch(UI.SearchEdit:getText(), false)
    end
end

function Cyclopedia.internalCreateItem(data)
    local player = g_game.getLocalPlayer()
    local vocation = player:getVocation()
    local level = player:getLevel()
    local classification = data:getClassification()
    local marketData = data:getMarketData()
    local vocFilter = Cyclopedia.Items.VocFilter
    local levelFilter = Cyclopedia.Items.LevelFilter
    local h1Filter = Cyclopedia.Items.h1Filter
    local h2Filter = Cyclopedia.Items.h2Filter
    local classificationFilter = Cyclopedia.Items.ClassificationFilter

    if vocFilter and tonumber(marketData.restrictVocation) > 0 then
        local demotedVoc = vocation > 10 and (vocation - 10) or vocation
        local vocBitMask = Bit.bit(tonumber(demotedVoc))
        if not Bit.hasBit(marketData.restrictVocation, vocBitMask) then
            return
        end
    end

    if levelFilter and level < marketData.requiredLevel then
        return
    end

    if h1Filter and data:getClothSlot() ~= 6 then
        return
    end

    if h2Filter and data:getClothSlot() ~= 0 then
        return
    end

    if classificationFilter == -1 and classification ~= 0 then
        return
    elseif classificationFilter == 1 and classification ~= 1 then
        return
    elseif classificationFilter == 2 and classification ~= 2 then
        return
    elseif classificationFilter == 3 and classification ~= 3 then
        return
    elseif classificationFilter == 4 and classification ~= 4 then
        return
    end

    local item = g_ui.createWidget("ItemsListBaseItem", UI.ItemListBase.List)

    item:setId(data:getId())
    item.Sprite:setItemId(data:getId())
    item.Name:setText(marketData.name)
    local price = data:getMeanPrice()

    item.Value = price
    item.Vocation = marketData.restrictVocation
    ItemsDatabase.setRarityItem(item.Sprite, item.Sprite:getItem())
    
    -- Add visual feedback for tracked items
    if Cyclopedia.Items.isInDropTracker(data:getId()) then
        item.Name:setColor("#FF9854")  -- Orange color for tracked items
    else
        item.Name:setColor("#c0c0c0")  -- Default color
    end

    function item.onClick(widget)
        UI.InfoBase.SellBase.List:destroyChildren()
        UI.InfoBase.BuyBase.List:destroyChildren()

        local oldSelected = UI.selectItem
        local lootValue = UI.LootValue
        local itemId = tonumber(widget:getId())
        local internalData = g_things.getThingType(itemId, ThingCategoryItem)

        if oldSelected then
            oldSelected:setBackgroundColor("#00000000")
        end

        g_game.inspectionObject(3, itemId)

        if not lootValue:isVisible() then
            lootValue:setVisible(true)
        end

        UI.EmptyLabel:setVisible(false)
        UI.InfoBase:setVisible(true)
        UI.InfoBase.ResultGoldBase.Value:setText(Cyclopedia.formatGold(item.Value))
        UI.SelectedItem.Sprite:setItemId(data:getId())

        -- Store reference to selected item
        lastSelectedItem = widget

        -- Update item price display
        if data then
            Cyclopedia.Items.showItemPrice(data)
        end

        if price > 0 then
            ItemsDatabase.setRarityItem(UI.SelectedItem.Rarity, price)
            ItemsDatabase.setRarityItem(UI.InfoBase.ResultGoldBase.Rarity, price)
        else
            UI.InfoBase.ResultGoldBase.Rarity:setImageSource("")
            UI.SelectedItem.Rarity:setImageSource("")
        end
        widget:setBackgroundColor("#585858")
        saveItemsViewState({ selectedItemId = itemId })
       
        if modules.game_quickloot.QuickLoot.data.filter == 2 then
            UI.InfoBase.quickLootCheck:setText("Loot when Quick Looting")
        else
            UI.InfoBase.quickLootCheck:setText('Skip when Quick Looting')
        end
        UI.InfoBase.quickLootCheck.onCheckChange = function(self, checked)
            if checked then
                modules.game_quickloot.QuickLoot.addLootList(data:getId(), modules.game_quickloot.QuickLoot.data.filter)
            else
                modules.game_quickloot.QuickLoot.removeLootList(data:getId(), modules.game_quickloot.QuickLoot.data.filter)
            end
        end
        UI.InfoBase.quickLootCheck:setChecked(modules.game_quickloot.QuickLoot.lootExists(data:getId(), modules.game_quickloot.QuickLoot.data.filter))

        -- Setup drop tracker if available
        if UI.InfoBase.TrackCheck then
            -- Temporarily disable the callback to prevent unwanted triggers
            local originalCallback = UI.InfoBase.TrackCheck.onCheckChange
            UI.InfoBase.TrackCheck.onCheckChange = nil
            
            UI.InfoBase.TrackCheck.itemId = data:getId()  -- Store item ID for callback
            local inTracker = Cyclopedia.Items.isInDropTracker(data:getId())
            UI.InfoBase.TrackCheck:setChecked(inTracker)
            
            -- Restore the callback
            UI.InfoBase.TrackCheck.onCheckChange = originalCallback
        end

        -- Setup quick sell whitelist if available
        if UI.InfoBase.quickSellCheck then
            local inWhitelist = Cyclopedia.Items.isInQuickSellWhitelist(data:getId())
            UI.InfoBase.quickSellCheck:setChecked(inWhitelist)
            UI.InfoBase.quickSellCheck.itemId = data:getId()  -- Store item ID for callback
        end

        -- Setup custom price edit handler
        if UI.InfoBase.OwnValueEdit then
            UI.InfoBase.OwnValueEdit.onTextChange = function(self)
                Cyclopedia.Items.onChangeCustomPrice(self)
            end
        end

        local buy, sell = Cyclopedia.formatSaleData(internalData:getNpcSaleData())
        local sellColor = "#484848"

        for index, value in ipairs(sell) do
            local t_widget = g_ui.createWidget("UIWidget", UI.InfoBase.SellBase.List)

            t_widget:setId(index)
            t_widget:setText(value)
            t_widget:setTextAlign(AlignLeft)
            t_widget:setBackgroundColor(sellColor)

            t_widget.BaseColor = sellColor

            function t_widget:onClick()
                Cyclopedia.ResetItemCategorySelection(UI.InfoBase.SellBase.List)
                self:setChecked(true)
                self:setBackgroundColor("#585858")
            end

            sellColor = sellColor == "#484848" and "#414141" or "#484848"
        end

        local buyColor = "#484848"

        for index, value in ipairs(buy) do
            local t_widget = g_ui.createWidget("UIWidget", UI.InfoBase.BuyBase.List)

            t_widget:setId(index)
            t_widget:setText(value)
            t_widget:setTextAlign(AlignLeft)
            t_widget:setBackgroundColor(buyColor)

            t_widget.BaseColor = buyColor

            function t_widget:onClick()
                Cyclopedia.ResetItemCategorySelection(UI.InfoBase.BuyBase.List)
                self:setChecked(true)
                self:setBackgroundColor("#585858")
            end

            buyColor = buyColor == "#484848" and "#414141" or "#484848"
        end 

        UI.selectItem = widget
    end

    return item
end

function Cyclopedia.ItemSearch(text, clearTextEdit)
    UI.ItemListBase.List:destroyChildren()
    if text ~= "" then
        UI.SelectedItem.Sprite:setItemId(0)
        UI.SelectedItem.Rarity:setImageSource("")

        local searchedItems = {}

        local oldSelected = UI.selectedCategory
        if oldSelected then
            oldSelected:setBackgroundColor(oldSelected.BaseColor)
            oldSelected:setChecked(false)
        end

        local searchTermLower = string.lower(text)

        for _, data in pairs(Cyclopedia.AllItemList) do
            local marketData = data:getMarketData()
            local itemNameLower = string.lower(marketData.name)
            local _, endIndex = itemNameLower:find(searchTermLower, 1, true)

            if endIndex and (itemNameLower:sub(endIndex + 1, endIndex + 1) == " " or endIndex == #itemNameLower) then
                table.insert(searchedItems, data)
            end
        end

        for _, data in ipairs(searchedItems) do
            local item = Cyclopedia.internalCreateItem(data)
        end
    else
        UI.SelectedItem.Sprite:setItemId(0)
        UI.SelectedItem.Rarity:setImageSource("")
    end

    if clearTextEdit then
        UI.SearchEdit:setText("")
    end

    saveItemsViewState({ searchText = UI.SearchEdit:getText() or "" })
end

local function isHandWeapon(id)
    if id >= 17 and id <= 21 or id == 1000 then
        return true
    end
end

function Cyclopedia.selectItemCategory(id)
    -- Reset all filters when changing categories
    setCheckedWithoutRecursion(false, false)
    UI.LevelButton:setChecked(false)
    UI.VocationButton:setChecked(false)
    Cyclopedia.Items.VocFilter = false
    Cyclopedia.Items.LevelFilter = false
    Cyclopedia.Items.h1Filter = false
    Cyclopedia.Items.h2Filter = false
    Cyclopedia.Items.ClassificationFilter = 0
    saveItemsViewState({
        selectedCategoryId = id,
        vocationFilter = false,
        levelFilter = false,
        h1Filter = false,
        h2Filter = false,
        classificationFilter = 0
    })

    if UI.SearchEdit:getText() ~= "" then
        Cyclopedia.ItemSearch("", true)
    end

    UI.ItemListBase.List:destroyChildren()

    if Cyclopedia.hasClassificationFilter(id) then
        UI.ItemFilter:clearOptions()
        UI.ItemFilter:addOption("All", 0, true)
        UI.ItemFilter:addOption("None", -1, true)

        for class = 1, 4 do
            UI.ItemFilter:addOption("Class " .. class, class, true)
        end

        UI.ItemFilter:enable()
    else
        UI.ItemFilter:clearOptions()
        Cyclopedia.Items.ClassificationFilter = 0
    end

    processItemsById(id)

    if Cyclopedia.hasHandedFilter(id) then
        UI.H1Button:enable()
        UI.H2Button:enable()
    else
        UI.H1Button:disable()
        UI.H2Button:disable()
    end
end

function Cyclopedia.loadItemsCategories()
    local types = g_things.findThingTypeByAttr(ThingAttrMarket, 0)
    local tempItemList = {}

    for _, data in pairs(types) do
        local marketData = data:getMarketData()
        if not tempItemList[marketData.category] then
            tempItemList[marketData.category] = {}
        end

        if marketData then
            table.insert(Cyclopedia.AllItemList, data)
        end

        table.insert(tempItemList[marketData.category], data)
    end

    for category, itemList in pairs(tempItemList) do
        table.sort(itemList, Cyclopedia.compareItems)
        Cyclopedia.ItemList[category] = itemList
    end
end

function Cyclopedia.FillItemList()
    local types = g_things.findThingTypeByAttr(ThingAttrMarket, 0)

    for i = 1, #types do
        local itemType = types[i]
        local item = Item.create(itemType:getId())
        if item then
            local marketData = itemType:getMarketData()
            if not table.empty(marketData) then
                item:setId(marketData.showAs)

                local marketItem = {
                    displayItem = item,
                    thingType = itemType,
                    marketData = marketData
                }

                if Cyclopedia.ItemList[marketData.category] ~= nil then
                    table.insert(Cyclopedia.ItemList[marketData.category], marketItem)
                end
            end
        end
    end
end

function Cyclopedia.loadItemDetail(itemId, descriptions)
    UI.InfoBase.DetailsBase.List:destroyChildren()

    local internalData = g_things.getThingType(itemId, ThingCategoryItem)
    local classification = internalData:getClassification()

    for _, description in ipairs(descriptions) do
        local widget = g_ui.createWidget("UIWidget", UI.InfoBase.DetailsBase.List)
        local key = description[1]
        local value = description[2]
        widget:setText(key .. ": " .. value)
        widget:setColor("#C0C0C0")
        widget:setTextWrap(true)
    end

    if classification > 0 then
        local widget = g_ui.createWidget("UIWidget", UI.InfoBase.DetailsBase.List)
        widget:setText("Classification: " .. classification)
        widget:setColor("#C0C0C0")
    end
end

-- Inspection handler for item details
function Cyclopedia.Items.onInspection(inspectType, itemName, item, descriptions)
    if inspectType ~= 1 then return end
    if UI and UI.InfoBase and UI.InfoBase.DetailsBase then
        Cyclopedia.loadItemDetail(item:getId(), descriptions)
    end
end

-- Utility function for comma-separated values
function comma_value(amount)
    if not amount then return "0" end
    local formatted = tostring(amount)
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then
            break
        end
    end
    return formatted
end

-- Enhanced formatGold function that uses comma formatting
function Cyclopedia.formatGold(value)
    return comma_value(value or 0)
end

-- Send party loot items function
function Cyclopedia.Items.sendPartyLootItems()
    if not Cyclopedia.ItemList then return end
    
    local totalList = {}
    for i, category in pairs(Cyclopedia.ItemList) do
        local skipCategory = (i == 1000 or i == 30) -- Skip WeaponsAll and Gold categories

        if not skipCategory then
            for _, itemInfo in ipairs(category) do
                if itemInfo then
                    local item = Item.create(itemInfo:getId())
                    if item then
                        local itemValue = Cyclopedia.Items.getCurrentItemValue(item)
                        totalList[tonumber(itemInfo:getId())] = itemValue
                    end
                end
            end
        end
    end

	if g_game.sendPartyLootPrice then
		g_game.sendPartyLootPrice(totalList)
	end
end

function Cyclopedia.Items.addToDropTracker(itemId)
    if modules.game_analyser and modules.game_analyser.managerDropTracker then
        modules.game_analyser.managerDropTracker(itemId, true)
    end
    
    -- Also store in our JSON backup
    if not itemsData["dropTrackerItems"] then
        itemsData["dropTrackerItems"] = {}
    end
    itemsData["dropTrackerItems"][tostring(itemId)] = true
    Cyclopedia.Items.saveJson()
    
    -- Update visual feedback for all items with this ID
    Cyclopedia.Items.updateItemVisualFeedback(itemId, true)
end

function Cyclopedia.Items.removeFromDropTracker(itemId)
    if modules.game_analyser and modules.game_analyser.managerDropTracker then
        modules.game_analyser.managerDropTracker(itemId, false)
    end
    
    -- Also remove from our JSON backup
    if itemsData["dropTrackerItems"] then
        itemsData["dropTrackerItems"][tostring(itemId)] = nil
        Cyclopedia.Items.saveJson()
    end
    
    -- Update visual feedback for all items with this ID
    Cyclopedia.Items.updateItemVisualFeedback(itemId, false)
end

function Cyclopedia.Items.updateItemVisualFeedback(itemId, isTracked)
    -- Update visual feedback for all widgets in the item list with this ID
    if UI and UI.ItemListBase and UI.ItemListBase.List then
        for _, widget in pairs(UI.ItemListBase.List:getChildren()) do
            if widget:getId() == tostring(itemId) and widget.Name then
                if isTracked then
                    widget.Name:setColor("#FF9854")  -- Orange color for tracked items
                else
                    widget.Name:setColor("#c0c0c0")  -- Default color
                end
            end
        end
    end
end

function Cyclopedia.Items.isInDropTracker(itemId)
    -- First try the game_analyser module
    if modules.game_analyser and modules.game_analyser.isInDropTracker then
        local inAnalyser = modules.game_analyser.isInDropTracker(itemId)
        if inAnalyser then
            return true
        end
    end
    
    -- Fallback to our JSON backup
    if itemsData["dropTrackerItems"] and itemsData["dropTrackerItems"][tostring(itemId)] then
        return true
    end
    
    return false
end

-- Helper functions for Drop Tracker integration (avoiding circular dependencies)
function Cyclopedia.Items.removeFromDropTrackerDirectly(itemId)
    -- Remove from our JSON backup without calling back to game_analyser
    if itemsData["dropTrackerItems"] then
        itemsData["dropTrackerItems"][tostring(itemId)] = nil
        Cyclopedia.Items.saveJson()
    end
    
    -- Update visual feedback for all items with this ID
    Cyclopedia.Items.updateItemVisualFeedback(itemId, false)
end

function Cyclopedia.Items.refreshCurrentItem()
    -- Force refresh the currently displayed item's tracking state
    if UI and UI.InfoBase and UI.InfoBase.TrackCheck and UI.InfoBase.TrackCheck.itemId then
        local itemId = UI.InfoBase.TrackCheck.itemId
        
        -- Temporarily disable the callback to prevent unwanted triggers
        local originalCallback = UI.InfoBase.TrackCheck.onCheckChange
        UI.InfoBase.TrackCheck.onCheckChange = nil
        
        local inTracker = Cyclopedia.Items.isInDropTracker(itemId)
        UI.InfoBase.TrackCheck:setChecked(inTracker)
        
        -- Restore the callback
        UI.InfoBase.TrackCheck.onCheckChange = originalCallback
    end
end

function Cyclopedia.Items.removeAllFromDropTrackerDirectly()
    -- Clear all drop tracker items from our JSON backup without calling back to game_analyser
    if itemsData then
        itemsData["dropTrackerItems"] = {}
        Cyclopedia.Items.saveJson()
    end
    
    -- Update visual feedback for all items in the list
    if UI and UI.ItemListBase and UI.ItemListBase.List then
        for _, widget in pairs(UI.ItemListBase.List:getChildren()) do
            if widget.Name then
                widget.Name:setColor("#c0c0c0")  -- Reset to default color
            end
        end
    end
end

-- Safe wrapper functions for module compatibility
function Cyclopedia.Items.addToQuickSellWhitelist(itemId)
	if modules.game_npctrade then
		if modules.game_npctrade.addToWhitelist then
			modules.game_npctrade.addToWhitelist(itemId)
		elseif modules.game_npctrade.addToList then
			modules.game_npctrade.addToList(itemId)
		end
	end
end

function Cyclopedia.Items.removeFromQuickSellWhitelist(itemId)
	if modules.game_npctrade then
		if modules.game_npctrade.removeItemInList then
			modules.game_npctrade.removeItemInList(itemId)
		elseif modules.game_npctrade.removeFromList then
			modules.game_npctrade.removeFromList(itemId)
		elseif modules.game_npctrade.removeItem then
			modules.game_npctrade.removeItem(itemId)
		end
	end
end

function Cyclopedia.Items.isInQuickSellWhitelist(itemId)
    if not modules.game_npctrade then return false end
    
    -- Try different possible function names
    local npctrade = modules.game_npctrade
    if npctrade.inWhiteList then
        return npctrade.inWhiteList(itemId)
    elseif npctrade.isInList then
        return npctrade.isInList(itemId)
    elseif npctrade.contains then
        return npctrade.contains(itemId)
    end
    
    return false
end

function Cyclopedia.Items.onChangeLootValue(self)
    if not self or not self:getParent() then return end
    
    local parent = self:getParent()
    local npcCheck = parent:getChildById('NpcBuyCheck')
    local marketCheck = parent:getChildById('MarketCheck')
    
    if not npcCheck or not marketCheck then return end
    
    -- Ensure only one is checked at a time
    if self:getId() == 'NpcBuyCheck' and self:isChecked() then
        marketCheck:setChecked(false)
    elseif self:getId() == 'MarketCheck' and self:isChecked() then
        npcCheck:setChecked(false)
    end
    
    -- If neither is checked, default to NPC
    if not npcCheck:isChecked() and not marketCheck:isChecked() then
        npcCheck:setChecked(true)
    end
    
    -- Update the primaryLootValueSources data structure
    if lastSelectedItem and lastSelectedItem.data then
        local item = lastSelectedItem.Sprite:getItem()
        if item then
            local itemId = item:getId()
            local currentItemID = tostring(itemId)
            
            if not itemsData["primaryLootValueSources"] then
                itemsData["primaryLootValueSources"] = {}
            end
            
            -- Update the data structure based on which checkbox is checked
            if marketCheck:isChecked() then
                -- Market checkbox is checked - add to market list
                itemsData["primaryLootValueSources"][currentItemID] = "market"
            else
                -- NPC checkbox is checked - remove from market list (default to NPC)
                itemsData["primaryLootValueSources"][currentItemID] = nil
            end
            
            -- Update the player's market list on the server
            local player = g_game.getLocalPlayer()
            if player and player.updateCyclopediaMarketList then
                player:updateCyclopediaMarketList(itemId, not marketCheck:isChecked()) -- true for NPC, false for market
            end
        end
        
        -- Refresh the price display using the last selected item
        Cyclopedia.Items.showItemPrice(lastSelectedItem.data)
    end
end

-- End of Cyclopedia Items module
