GemAtelier = {}
GemAtelier.__index = GemAtelier

local lockedOnly = false
local sortQuality = 1
local sortAffinity = 1
local currentPage = 1

local destroyGemWindow = nil
local lastSelectedGem = nil
local lastSelectedVessel = nil
local currentGemList = {}
local totalGemList = {}
local currentSearchText = ""

local cachedBasicMods = {}
local cachedSupremeMods = {}

GemRevealPrice = {
  [0] = 125000,  -- Lesser
  [1] = 1000000,  -- Regular
  [2] = 6000000  -- Greater
}

GemSwitchPrice = {
  [0] = 125000,   -- Lesser
  [1] = 250000,   -- Regular
  [2] = 1000000   -- Greater
}

function GemAtelier.resetFields()
	lockedOnly = false
	sortQuality = 1
	sortAffinity = 1
	destroyGemWindow = nil
	lastSelectedGem = nil
	currentGemList = {}
	currentSearchText = ""
	totalGemList = {}
	currentPage = 1
	gemAtelierWindow:recursiveGetChildById("filterPanel").searchText:clearText()
	gemAtelierWindow:recursiveGetChildById("affinitiesBox"):setCurrentIndex(1, true)
	gemAtelierWindow:recursiveGetChildById("qualitiesBox"):setCurrentIndex(1, true)
	gemAtelierWindow:recursiveGetChildById("lockedOnly"):setChecked(false, true)
	if lastSelectedVessel then
		lastSelectedVessel:setVisible(false)
		lastSelectedVessel = nil
	end

	cachedBasicMods = {}
	cachedSupremeMods = {}
	for _, data in pairs(Workshop.getFragmentList()) do
		if data.supreme then
			cachedSupremeMods[data.modID] = data
		else
			cachedBasicMods[data.modID] = data
		end
	end
end

function GemAtelier.redirectToGem(gemData)
	if not WheelOfDestiny or not gemAtelierWindow then
		return true
	end

	GemAtelier.resetFields()
	GemAtelier.setupVesselPanel()
	local gemList = gemAtelierWindow:recursiveGetChildById("gemContent")
	if not gemList then
		return true
	end

	if gemData then
		local affinityWidget = gemAtelierWindow:recursiveGetChildById("affinitiesBox")
		local qualityWidget = gemAtelierWindow:recursiveGetChildById("qualitiesBox")
		affinityWidget:setCurrentIndex(gemData.gemDomain + 2, true)
		qualityWidget:setCurrentIndex(1, true)
		sortQuality = 1
		sortAffinity = gemData.gemDomain + 2

		local highLight = gemAtelierWindow:recursiveGetChildById("selectVessel" .. gemData.gemDomain)
		highLight:setVisible(true)

		if lastSelectedVessel then
			lastSelectedVessel:setVisible(false)
		end

		lastSelectedVessel = highLight
	end

	gemList:destroyChildren()
	
	totalGemList = {}
	currentGemList = {}

	local index = 1
	local foundIndex = 1

	for i, data in pairs(WheelOfDestiny.atelierGems) do
		if (sortQuality > 1 and data.gemType ~= sortQuality - 2) or (sortAffinity > 1 and data.gemDomain ~= sortAffinity - 2) then
		 	goto continue
	 	end

		if gemData.gemID == data.gemID then
			currentPage = math.ceil(index / 15)
			foundIndex = math.max(1, index - 15)
		end

		index = index + 1
		table.insert(totalGemList, data)
		:: continue ::
	end

	local gemCount = 0
	local beginList = (currentPage - 1) * 15 + 1
	local focusedGem = nil

	for i, data in pairs(totalGemList) do
		if gemCount == 15 then
			break
		end

		if i < beginList then
			goto continue
		end

		local widget = g_ui.createWidget('GemPanel', gemList)
		local success = GemAtelier.setupGemWidget(widget, data)
		
		if success then
			currentGemList[#currentGemList + 1] = data
			if widget then
				widget.gemIndex = #currentGemList
			end
			gemCount = gemCount + 1

			if data.gemID == gemData.gemID then
				focusedGem = widget
			end
		else
			widget:destroy()
		end

		:: continue ::
	end

	GemAtelier.showGemRevelation()
	GemAtelier.configurePages()

	gemList.onChildFocusChange = function(self, selected) GemAtelier.onSelectGem(selected, true) end
	
	if not focusedGem then
		focusedGem = gemList:getFirstChild()
	end
	
	gemList:focusChild(focusedGem, ActiveFocusReason, true)
	GemAtelier.onSelectGem(focusedGem, true)
end

function GemAtelier.showGems(selectFirst, lastIndex)
	if not WheelOfDestiny or not gemAtelierWindow then
		return true
	end

	GemAtelier.setupVesselPanel()
	local gemList = gemAtelierWindow:recursiveGetChildById("gemContent")
	if not gemList then
		return true
	end

	totalGemList = {}
	currentGemList = {}
	
	
	for i, data in pairs(WheelOfDestiny.atelierGems) do
		if not data.gemID or data.gemID < 0 then
			g_logger.debug(string.format("[GemAtelier] Skipping gem with invalid ID: %s", tostring(data.gemID)))
			goto continue
		end
		
		local isLocked = data.locked == 1 or data.locked == true
		if lockedOnly and not isLocked then
			goto continue
		elseif sortQuality > 1 and data.gemType ~= sortQuality - 2 then
			goto continue
		elseif sortAffinity > 1 and data.gemDomain ~= sortAffinity - 2 then
			goto continue
		elseif #currentSearchText > 0 and not GemAtelier.matchGemText(data) then
			goto continue
		end

		table.insert(totalGemList, data)
		:: continue ::
	end

	gemList:destroyChildren()
	gemList.onChildFocusChange = function(self, selected) GemAtelier.onSelectGem(selected, true) end

	local gemCount = 0
	local beginList = (currentPage - 1) * 15 + 1

	for i, data in pairs(totalGemList) do
		if gemCount == 15 then
			break
		end

		if i < beginList then
			goto continue
		end

		local widget = g_ui.createWidget('GemPanel', gemList)
		local success = GemAtelier.setupGemWidget(widget, data)
		
		if success then
			currentGemList[#currentGemList + 1] = data
			if widget then
				widget.gemIndex = #currentGemList
			end
			gemCount = gemCount + 1
		else
			widget:destroy()
		end

		:: continue ::
	end

	GemAtelier.showGemRevelation()
	GemAtelier.configurePages()

	local panel = gemAtelierWindow:recursiveGetChildById("clickedPanel")
	local children = gemList:getChildren()

	if #children == 0 then
		panel.clickedContent:setVisible(false)
		panel.cleanContent:setVisible(true)
	else
		gemList:focusChild(nil)
		panel.cleanContent:setVisible(false)
		if selectFirst then
			gemList:focusChild(gemList:getFirstChild())
		elseif lastIndex then
			gemList:focusChild(children[lastIndex])
		elseif lastSelectedGem and lastSelectedGem:isVisible() and lastSelectedGem.gemID then
			local targetIndex = 0
			for i, widget in ipairs(children) do
				if widget.gemID == lastSelectedGem.gemID then
					targetIndex = i
					break
				end
			end
		
			if targetIndex > 0 then
				gemList:focusChild(children[targetIndex])
			else
				g_logger.debug(string.format("[GemAtelier] gemID %d not found among displayed children.", lastSelectedGem.gemID or -1))
				if #children > 0 then
					gemList:focusChild(children[1])
				end
			end
		else
			if #children > 0 then
				gemList:focusChild(children[1])
			end
		end
	end
end

function GemAtelier.matchGemText(data)
	local descriptions = {RegularGemDescription[data.lesserBonus].text, cachedBasicMods[data.lesserBonus].tooltip}

	if data.gemType > 0 then
		table.insert(descriptions, RegularGemDescription[data.regularBonus].text)
		table.insert(descriptions, cachedBasicMods[data.regularBonus].tooltip)
	end
	if data.gemType > 1 then
		table.insert(descriptions, SupremeGemDescription[data.supremeBonus].text)
		table.insert(descriptions, cachedSupremeMods[data.supremeBonus].tooltip)
	end

	for _, text in pairs(descriptions) do
		if matchText(currentSearchText, text) then
			return true
		end
	end
	return false
end

function GemAtelier.setupGemWidget(widget, data)
	if not widget then
	  g_logger.debug("[GemAtelier] widget nil — could not configure gem")
	  return false
	end
  
	if data and data.gemID and data.gemID >= 0 then
		widget.gemID = data.gemID
		g_logger.debug(string.format("[GemAtelier] setupGemWidget: set gemID=%d for widget", data.gemID))
	else
		widget.gemID = -1
		g_logger.debug(string.format("[GemAtelier] gem without valid gemID — gemID=%s (type=%s)", tostring(data and data.gemID), type(data and data.gemID)))
		return false
	end
  
	if not data then
	  g_logger.debug("[GemAtelier] setupGemWidget called with data=nil")
	  return false
	end
	if not data.gemType or not data.gemDomain then
	  g_logger.debug(string.format("[GemAtelier] incomplete gem data: id=%s type=%s domain=%s",
		tostring(data.gemID), tostring(data.gemType), tostring(data.gemDomain)))
	  return false
	end
  
	local typeOffset = data.gemType * 32
	local domainOffset = data.gemDomain * 96
	local vocationOffset = (WheelOfDestiny.vocationId - 1) * 384
	local gemOffset = vocationOffset + domainOffset + typeOffset
  
	local tmpData = GemVocations[WheelOfDestiny.vocationId][data.gemType]
	if not tmpData then
	  g_logger.debug(string.format("[GemAtelier] gem id %d not found in GemVocations[%d][%d]",
		data.gemID or -1, WheelOfDestiny.vocationId or -1, data.gemType or -1))
	  return false
	end
  
	local lockedState = data.locked == 1
	widget.locker:setChecked(lockedState)
	widget.locker.onClick = GemAtelier.onLockGem
	widget.locker.gemID = data.gemID

	g_logger.debug(string.format(
	"[GemAtelier] Locker configured for gemID=%d | locked=%d | checked=%s | visible=%s",
	data.gemID or -1,
	data.locked or -1,
	tostring(widget.locker:isChecked()),
	tostring(widget.locker:isVisible())
	))
	widget.gemRevelationItem:setImageClip(gemOffset .. " 0 32 32")
	widget.gemRevelationItem:setTooltip(tmpData.name:gsub(" %(x 0%)", ""))
  
	if GemAtelier.isGemEquipped(data.gemID) then
	  widget.gemDomainImage:setVisible(true)
	  widget.gemDomainImage:setImageClip(data.gemDomain * 26 .. " 0 26 26")
	end
  
	local gemTypeWidget = widget:recursiveGetChildById("modType" .. data.gemType)
	if not gemTypeWidget then
	  g_logger.debug(string.format("[GemAtelier] gemTypeWidget modType%d not found for gemID=%d", data.gemType, data.gemID))
	  return false
	end
  
	gemTypeWidget:setVisible(true)
  
	GemAtelier.setupGemSlot(gemTypeWidget.fragmentType0.gemMod0, data.lesserBonus, WheelOfDestiny.basicModsUpgrade, false, data, 0)
	GemAtelier.setGemUpgradeImage(gemTypeWidget.fragmentType0, data.lesserBonus, WheelOfDestiny.basicModsUpgrade, nil)
  
	if data.gemType > 0 then
	  GemAtelier.setupGemSlot(gemTypeWidget.fragmentType1.gemMod1, data.regularBonus, WheelOfDestiny.basicModsUpgrade, false, data, 1)
	  GemAtelier.setGemUpgradeImage(gemTypeWidget.fragmentType1, data.regularBonus, WheelOfDestiny.basicModsUpgrade, WheelOfDestiny.basicModsUpgrade[data.lesserBonus] or 0, true)
	end
  
	if data.gemType > 1 then
	  GemAtelier.setupGemSlot(gemTypeWidget.fragmentType2.gemMod2, data.supremeBonus, WheelOfDestiny.supremeModsUpgrade, true, data, 2)
	  local effectiveBonus = math.min(WheelOfDestiny.basicModsUpgrade[data.lesserBonus] or 0, WheelOfDestiny.basicModsUpgrade[data.regularBonus] or 0)
	  GemAtelier.setGemUpgradeImage(gemTypeWidget.fragmentType2, data.supremeBonus, WheelOfDestiny.supremeModsUpgrade, effectiveBonus)
	end
  
g_logger.debug(string.format("[GemAtelier] GemWidget configured: id=%d type=%d domain=%d locked=%d",
	  data.gemID or -1, data.gemType or -1, data.gemDomain or -1, data.locked or -1))
	
	return true
  end
  

function GemAtelier.setupGemSlot(gemSlot, bonus, upgradeData, isSupreme, gemData, gemPosition)
	gemSlot:setImageClip(bonus * (isSupreme and 35 or 30) .. " 0 " .. (isSupreme and 35 or 30) .. " " .. (isSupreme and 35 or 30))
	GemAtelier.createGemInformation(gemSlot, bonus, isSupreme, true, gemData, gemPosition)
end

function GemAtelier.setGemUpgradeImage(gemFragment, bonus, upgradeData, prevBonus, debug)
	local upgradeLevel = upgradeData[bonus] or 0
	if prevBonus then
		if upgradeLevel > prevBonus then
			gemFragment.potential:setVisible(true)
			gemFragment.potential:setImageClip(upgradeLevel * 50 .. " 0 50 50")
			gemFragment:setImageClip(prevBonus * 50 .. " 0 50 50")
		else
			gemFragment:setImageClip(upgradeLevel * 50 .. " 0 50 50")
		end
	else
		gemFragment:setImageClip(upgradeLevel * 50 .. " 0 50 50")
	end
end

function GemAtelier.showGemRevelation()
	local data = GemVocations[WheelOfDestiny.vocationId]
	if not data then
		return true
	end

	local player = g_game:getLocalPlayer()
	local revelation = gemAtelierWindow.gemRevelation
	local totalBalance = player:getResourceBalance(ResourceTypes.BANK_BALANCE) + player:getResourceBalance(ResourceTypes.GOLD_EQUIPPED)
	local resources = {
		[0] = player:getResourceBalance(ResourceTypes.LESSER_GEMS),
		[1] = player:getResourceBalance(ResourceTypes.REGULAR_GEMS),
		[2] = player:getResourceBalance(ResourceTypes.GREATER_GEMS)
	}

	for i = 0, 2 do
		local itemWidget = revelation:recursiveGetChildById("gemRevelationItem" .. i)
		local gemInfo = revelation:recursiveGetChildById("gemInfo" .. i)
		local revealCost = revelation:recursiveGetChildById("gemRevealCost" .. i)
		local button = revelation:recursiveGetChildById("revealButton" .. i)

		itemWidget:setItemId(data[i].id)
		gemInfo:setText(data[i].name:gsub("%d", resources[i]))
		gemInfo:setMarginTop(60)
		if not gemInfo:isTextWrap() then
			gemInfo:setMarginTop(67)
		end

		revealCost.gold:setText(comma_value(GemRevealPrice[i] / 1000) .. "k")

		local toolTip = ""
		button:setOn(true)
		button:setTooltip("")
		if totalBalance < GemRevealPrice[i] then
			toolTip = tr(GemStaticTooltips[0], comma_value(GemRevealPrice[i]))
		end

		if resources[i] < 1 then
			toolTip = tr("%s" .. GemStaticTooltips[1], (#toolTip > 0 and toolTip .. "\n" or ""), comma_value(GemRevealPrice[i]))
		end

		if WheelOfDestiny.changeState ~= 1 then
			toolTip = tr("%s%s", (#toolTip > 0 and toolTip .. "\n" or ""), GemStaticTooltips[2])
		end

		if #WheelOfDestiny.atelierGems >= 225 then
			toolTip = tr("%s%s", (#toolTip > 0 and toolTip .. "\n" or ""), GemStaticTooltips[3])
		end

		if #toolTip > 0 then
			button:setTooltip(toolTip)
			button:setOn(false)
		end
	end
end

function GemAtelier.configurePages()
	if not gemAtelierWindow then
		return true
	end

	local panel = gemAtelierWindow:recursiveGetChildById("filterPanel")
	local totalCount = #totalGemList
	local maxPage = math.max(1, math.ceil(totalCount / 15))
	panel.pagesPanel.pagesLabel:setText(tr('Page %s / %s (%s Gems)', currentPage, maxPage, totalCount))

	if currentPage == 1 and maxPage == 1  then
		panel.pagesPanel.leftArrow:setOn(false)
		panel.pagesPanel.rightArrow:setOn(false)
	end

	if currentPage == 1 and maxPage > 1 then
		panel.pagesPanel.leftArrow:setOn(false)
		panel.pagesPanel.rightArrow:setOn(true)
	end

	if currentPage > 1 and currentPage < maxPage then
		panel.pagesPanel.leftArrow:setOn(true)
		panel.pagesPanel.rightArrow:setOn(true)
	end

	if currentPage > 1 and currentPage == maxPage then
		panel.pagesPanel.leftArrow:setOn(true)
		panel.pagesPanel.rightArrow:setOn(false)
	end
end

function GemAtelier.managePage(button, foward)
	if not button:isOn() then
		return true
	end

	local totalCount = #WheelOfDestiny.atelierGems
	local maxPage = math.max(1, math.ceil(totalCount / 15))

	if foward then
		currentPage = math.min(currentPage + 1, math.ceil(maxPage))
	else
		currentPage = math.max(1, currentPage - 1)
	end
	GemAtelier.showGems(true)
end

function shortenAfterCooldown(text)
    local cooldownIndex = text:find("Cooldown")
    if cooldownIndex then
        local afterCooldownIndex = cooldownIndex + #"Cooldown" - 1
        if text:sub(afterCooldownIndex + 1):match("%S") then
            return text:sub(1, afterCooldownIndex) .. "…"
        else
            return text
        end
    else
        return text
    end
end

function GemAtelier.getEffectiveLevel(gemData, currentBonusID, supreme, gemSlot)
	local basicUpgrade = WheelOfDestiny.basicModsUpgrade
	local supremeUpgrade = WheelOfDestiny.supremeModsUpgrade
	local upgradeTier = supreme and (supremeUpgrade[currentBonusID] or 0) or (basicUpgrade[currentBonusID] or 0)

	if gemSlot == 0 then
		return upgradeTier
	elseif gemSlot == 1 then
		local lesserUpgradeTier = basicUpgrade[gemData.lesserBonus] or 0
		return math.min(upgradeTier, lesserUpgradeTier)
	elseif gemSlot == 2 then
		local lesserUpgradeTier = basicUpgrade[gemData.lesserBonus] or 0
		local regularUpgradeTier = basicUpgrade[gemData.regularBonus] or 0
		local effectiveTier = math.min(lesserUpgradeTier, regularUpgradeTier)
		return math.min(upgradeTier, effectiveTier)
	end
end

function GemAtelier.createGemInformation(widget, gemTypeID, supremeMod, tooltip, gemData, gemSlot)
	local search = nil
	if supremeMod then
		search = cachedSupremeMods[gemTypeID]
	else
		search = cachedBasicMods[gemTypeID]
	end

	if not search then
		return true
	end

	local function shortenAfterCooldown(text)
		local cooldownIndex = text:find("Cooldown")
		if cooldownIndex then
			local afterCooldownIndex = cooldownIndex + #"Cooldown" - 1
			if text:sub(afterCooldownIndex + 1):match("%S") then
				return text:sub(1, afterCooldownIndex) .. "...", true
			else
				return text, false
			end
		else
			return text, false
		end
	end

	local shorted = false
	local currentTier = GemAtelier.getEffectiveLevel(gemData, gemTypeID, supremeMod, gemSlot)
	local text = Workshop.getBonusDescription(search, currentTier)
	if tooltip then
		widget:setTooltip(text)
	else
		local originalText = text
		text, shorted = shortenAfterCooldown(text)
		widget:setTooltip(shorted and originalText or "")
		widget:setText(text)
	end
end

function GemAtelier.onSelectGem(selected, clicked)
	if not selected or not selected.gemID then
		return true
	end
	
	g_logger.debug(string.format("[GemAtelier] onSelectGem: gemID=%d currentGemList size=%d", selected.gemID, #currentGemList))

	if #currentGemList == 0 then
		return true
	end

	local gemData = GemAtelier.getGemDataById(selected.gemID)
	if not gemData then
		g_logger.debug(string.format(
			"[GemAtelier] gemData is nil for gemID=%s (currentGemList size=%d)",
			tostring(selected.gemID), #currentGemList
		))
		return true
	end

	if lastSelectedGem then
		lastSelectedGem:setBorderWidth(0)
		lastSelectedGem:setBorderColor('alpha')
	end
	lastSelectedGem = selected
	lastSelectedGem:setBorderWidth(2)
	lastSelectedGem:setBorderColor('white')

	local panel = gemAtelierWindow:recursiveGetChildById("clickedPanel")
	if panel.cleanContent:isVisible() then
		panel.cleanContent:setVisible(false)
	end
	panel.clickedContent:setVisible(true)

	panel.clickedContent.placeVessel.onClick  = function() GemAtelier.manageVessel(false) end
	panel.clickedContent.removeVessel.onClick = function() GemAtelier.manageVessel(true)  end
	panel.clickedContent.switch.onClick       = GemAtelier.onSwitchDomain
	panel.clickedContent.destroy.onClick      = GemAtelier.onDestroyGem

	local typeOffset    = gemData.gemType * 64
	local domainOffset  = gemData.gemDomain * 192
	local vocationOffset = (WheelOfDestiny.vocationId - 1) * 64
	local gemOffset     = domainOffset + typeOffset

	local gemText = GemVocations[WheelOfDestiny.vocationId][gemData.gemType].name
	panel.clickedContent.gemDetails.gemName:setText(string.gsub(gemText, " %(x 0%)", ""))
	panel.clickedContent.gemDetails.gemDetailItem:setImageClip(gemOffset .. " " .. vocationOffset .. " 64 64")
	panel.clickedContent.gemDetails.domain:setImageClip(gemData.gemDomain * 26 .. " 0 26 26")

	local widgetMods = panel.clickedContent.gemMods
	for i = 0, 2 do
		widgetMods:recursiveGetChildById("fragmentType" .. i):setVisible(false)
		widgetMods:recursiveGetChildById("gemModItem" .. i):setVisible(false)
		widgetMods:recursiveGetChildById("modLabel" .. i):setVisible(false)
	end
	widgetMods.fragmentType0.gemModItem0:setImageClip(gemData.lesserBonus * 30 .. " 0 30 30")
	GemAtelier.setupModAvailable(widgetMods, 0, 1, gemData)
	GemAtelier.createGemInformation(widgetMods.modLabel0, gemData.lesserBonus, false, false, gemData, 0)
	if gemData.gemType > 0 then
		widgetMods.fragmentType1.gemModItem1:setImageClip(gemData.regularBonus * 30 .. " 0 30 30")
		GemAtelier.setupModAvailable(widgetMods, 1, 2, gemData)
		GemAtelier.createGemInformation(widgetMods.modLabel1, gemData.regularBonus, false, false, gemData, 1)
	end
	if gemData.gemType > 1 then
		widgetMods.fragmentType2.gemModItem2:setImageClip(gemData.supremeBonus * 35 .. " 0 35 35")
		GemAtelier.setupModAvailable(widgetMods, 2, 3, gemData)
		GemAtelier.createGemInformation(widgetMods.modLabel2, gemData.supremeBonus, true, false, gemData, 2)
	end

	local player = g_game:getLocalPlayer()
	local totalBalance = player:getResourceBalance(ResourceTypes.BANK_BALANCE)
	+ player:getResourceBalance(ResourceTypes.GOLD_EQUIPPED)

	local price = GemSwitchPrice[gemData.gemType] or 0
	local enough = totalBalance >= price
	local goldWidget = panel.clickedContent.switchCost.gold

	goldWidget:setText((price / 1000) .. "k")
	goldWidget:setColor(enough and "#c0c0c0" or "#d33c3c")
	panel.clickedContent.switchCost:setTooltip(comma_value(price))

	local alreadyEquipped = false
	local isTheSameGem = false
	for _, id in pairs(WheelOfDestiny.equipedGems or {}) do
		if type(id) == "number" and id > 0 then
			local dom = GemAtelier.getGemDomainById(id)
			if dom == gemData.gemDomain then
				alreadyEquipped = true
				if id == gemData.gemID then
					isTheSameGem = true
				end
				break
			end
		end
	end

	-- decide button visibility
	-- If selected gem is the same as equipped, show "Remove from Vessel"
	-- If it's a different gem but same color, show "Place in Vessel" (will replace)
	-- If no gem is equipped, show "Place in Vessel"
	if alreadyEquipped and isTheSameGem then
		panel.clickedContent.placeVessel:setVisible(false)
		panel.clickedContent.removeVessel:setVisible(true)
	else
		panel.clickedContent.placeVessel:setVisible(true)
		panel.clickedContent.removeVessel:setVisible(false)
	end


	local switchTip, destroyTip = "", ""
	local canInteract = (WheelOfDestiny.changeState == 1) and (gemData.locked == 0)
	panel.clickedContent.switch:setOn(canInteract)
	panel.clickedContent.destroy:setOn(canInteract)
	g_logger.debug(string.format(
		"[GemAtelier] Buttons updated -> changeState=%d locked=%d canInteract=%s",
		WheelOfDestiny.changeState or -1, gemData.locked or -1, tostring(canInteract)
	))

	local gemCount = GemAtelier.getGemCountByDomain(gemData.gemDomain)
	if gemCount < 2 then
		switchTip  = tr("%s%sYou cannot switch the last gem of the domain.", switchTip,  (#switchTip  > 0 and "\n" or ""))
		destroyTip = tr("%s%sYou cannot destroy the last gem of the domain.", destroyTip,(#destroyTip > 0 and "\n" or ""))
	end
	if totalBalance < price then
		switchTip = tr("%s%sYou need at least %s gold to change the domain of this gem.", switchTip, (#switchTip > 0 and "\n" or ""), comma_value(price))
	end
	if gemData.locked == 1 then
		switchTip  = tr("%s%sBefore you can change the domain of this gem, you must unlock it.", switchTip,  (#switchTip  > 0 and "\n" or ""))
		destroyTip = tr("%s%sBefore you can destroy the gem, you must unlock it.", destroyTip,(#destroyTip > 0 and "\n" or ""))
	end
	if GemAtelier.isGemEquipped(gemData.gemID) then
		switchTip  = tr("%s%sYou must remove the gem from its vessel before you can switch its domain.", switchTip,  (#switchTip  > 0 and "\n" or ""))
		destroyTip = tr("%s%sThe gem must be removed from its vessel before it can be destroyed.", destroyTip,(#destroyTip > 0 and "\n" or ""))
	end

	panel.clickedContent.switch:setTooltip(switchTip)
	panel.clickedContent.destroy:setTooltip(destroyTip)
	if #switchTip  > 0 then panel.clickedContent.switch:setOn(false)  end
	if #destroyTip > 0 then panel.clickedContent.destroy:setOn(false) end
	if totalBalance >= price then
		panel.clickedContent.switch:setTooltip(tr("%s%sSwitch the gem\'s domain one step clockwise by paying the free of %s gold.", switchTip, (#switchTip > 0 and "\n" or ""), comma_value(price)))
	end
end


function GemAtelier.isVesselAvailable(domain, count)
	local vesselFilled = 0
	local domainIndex = VesselIndex[domain]
	if not domainIndex then
		return false
	end

	for _, index in pairs(domainIndex) do
		local bonus = WheelBonus[index]
		local currentPoints = WheelOfDestiny.pointInvested[index + 1]
		if currentPoints >= bonus.maxPoints then
			vesselFilled = vesselFilled + 1
		end
	end
	return vesselFilled >= count
end

function GemAtelier.getFilledVesselCount(domain)
	local vesselFilled = 0
	local domainIndex = VesselIndex[domain]
	for _, index in pairs(domainIndex) do
		local bonus = WheelBonus[index]
		local currentPoints = WheelOfDestiny.pointInvested[index + 1]
		if bonus and currentPoints and currentPoints >= bonus.maxPoints then
			vesselFilled = vesselFilled + 1
		end
	end
	return vesselFilled
end

function GemAtelier.setupModAvailable(widget, gemType, vesselCount, gemData)
	if not widget then
		return true
	end

	local gemDomain = gemData.gemDomain
	local fragmentType = widget:recursiveGetChildById("fragmentType" .. gemType)
	local modItem = widget:recursiveGetChildById("gemModItem" .. gemType)
	local modLabel = widget:recursiveGetChildById("modLabel" .. gemType)
	local potentialLevel = fragmentType:recursiveGetChildById("potential")

	fragmentType:setVisible(true)
	modItem:setVisible(true)
	modLabel:setVisible(true)

	if GemAtelier.isVesselAvailable(gemDomain, vesselCount) then
		fragmentType:setShader("")
		modItem:setShader("")
		modLabel:setColor("#c0c0c0")
	else
		fragmentType:setShader("image_black_white")
		modItem:setShader("image_black_white")
		modLabel:setColor("#707070")
	end

	potentialLevel:setVisible(false)
	local gemBonusID = (gemType == 0 and gemData.lesserBonus or gemType == 1 and gemData.regularBonus or gemType == 2 and gemData.supremeBonus)
	local upgradeTier = WheelOfDestiny.basicModsUpgrade[gemBonusID] or 0
	if vesselCount == 3 then
		upgradeTier= WheelOfDestiny.supremeModsUpgrade[gemBonusID] or 0
	end

	if gemType == 0 then
		fragmentType:setImageClip(upgradeTier * 50 .. " 0 50 50")
		fragmentType.currentTier = upgradeTier
	elseif gemType == 1 then
		local lesserUpgradeTier = WheelOfDestiny.basicModsUpgrade[gemData.lesserBonus] or 0
		if upgradeTier > lesserUpgradeTier then
			fragmentType:setImageClip(lesserUpgradeTier * 50 .. " 0 50 50")
			potentialLevel:setVisible(true)
			potentialLevel:setImageClip(upgradeTier * 50 .. " 0 50 50")
			fragmentType.currentTier = lesserUpgradeTier
		else
			fragmentType:setImageClip(upgradeTier * 50 .. " 0 50 50")
			fragmentType.currentTier = upgradeTier
		end
	elseif gemType == 2 then
		local lesserUpgradeTier = WheelOfDestiny.basicModsUpgrade[gemData.lesserBonus] or 0
		local regularUpgradeTier = WheelOfDestiny.basicModsUpgrade[gemData.regularBonus] or 0
		local effectiveTier = math.min(lesserUpgradeTier, regularUpgradeTier)

		if upgradeTier > effectiveTier then
			fragmentType:setImageClip(effectiveTier * 50 .. " 0 50 50")
			potentialLevel:setVisible(true)
			potentialLevel:setImageClip(upgradeTier * 50 .. " 0 50 50")
			fragmentType.currentTier = effectiveTier
		else
			fragmentType:setImageClip(upgradeTier * 50 .. " 0 50 50")
			fragmentType.currentTier = upgradeTier
		end
	end

	fragmentType.modID = gemBonusID
	fragmentType.isSupreme = vesselCount == 3
end

function GemAtelier.manageVessel(remove)
	if not lastSelectedGem then
		return true
	end

	local gemData
	for _, data in ipairs(currentGemList) do
		if data.gemID == lastSelectedGem.gemID then
			gemData = data
			break
		end
	end
	if not gemData then
		g_logger.debug(string.format("[GemAtelier] gemData not found for gemID=%s", tostring(lastSelectedGem.gemID)))
		return true
	end

	local equipedList = {-1, -1, -1, -1}
	
	for _, id in pairs(WheelOfDestiny.equipedGems or {}) do
		if type(id) == "number" and id >= 0 then
			local domain = GemAtelier.getGemDomainById(id)
			if domain ~= -1 and domain ~= gemData.gemDomain then
				equipedList[domain + 1] = id
			end
		end
	end
	
	if not remove then
		equipedList[gemData.gemDomain + 1] = gemData.gemID
	else
		equipedList[gemData.gemDomain + 1] = -1
	end
	
	WheelOfDestiny.equipedGems = equipedList

	if WheelOfDestiny.currentPreset then
		WheelOfDestiny.currentPreset.equipedGems = equipedList
	end

	g_logger.debug(string.format(
		"[GemAtelier] manageVessel -> %s gemID=%d domain=%d | equipedGems={%s}",
		remove and "remove" or "equip",
		gemData.gemID, gemData.gemDomain,
		table.concat(WheelOfDestiny.equipedGems, ", ")
	))

	if lastSelectedGem then
		g_logger.debug("[GemAtelier] Updating side panel after equip/remove.")
		GemAtelier.setupVesselPanel()
		GemAtelier.onSelectGem(lastSelectedGem, true)
	else
		g_logger.debug("[GemAtelier] No gem selected after manageVessel, could not update panel.")
	end

	GemAtelier.showGems(false, lastSelectedGem.gemIndex or 1)
end


function GemAtelier.isGemEquipped(gemID)
	if not gemID or gemID < 0 then
		return false
	end
	for _, id in pairs(WheelOfDestiny.equipedGems or {}) do
		if type(id) == "number" and id == gemID then
			return true
		end
	end
	return false
end

function GemAtelier.getGemDomainById(id)
	if type(id) ~= "number" or id < 0 then
		return -1
	end
	for _, data in pairs(WheelOfDestiny.atelierGems) do
	  if data.gemID == id then
		return data.gemDomain
	  end
	end
	return -1
  end

function GemAtelier.getGemCountByDomain(domain)
	local count = 0
	for _, data in pairs(WheelOfDestiny.atelierGems) do
		if data.gemDomain == domain then
			count = count + 1
		end
	end
	return count
end

function GemAtelier.getGemDataById(id)
	if type(id) ~= "number" or id < 0 then
		g_logger.debug(string.format("[GemAtelier] getGemDataById called with invalid id: %s (type=%s)", tostring(id), type(id)))
		return nil
	end
	for _, data in pairs(WheelOfDestiny.atelierGems) do
		if data.gemID == id then
			return data
		end
	end
	g_logger.debug(string.format("[GemAtelier] getGemDataById: gemID=%d not found in atelierGems (total gems=%d)", id, #WheelOfDestiny.atelierGems))
	return nil
end

function GemAtelier.getEquipedGem(domain)
  for _, data in pairs(WheelOfDestiny.atelierGems) do
		if data.gemDomain == domain and GemAtelier.isGemEquipped(data.gemID) then
			return data
		end
	end
	return nil
end

function sendgemAction(actionType, param, pos)
	param = param or 0
	pos = pos or 0

	g_logger.debug(string.format("[GemAtelier] Sending action -> type=%d param=%d pos=%d", actionType, param, pos))
	g_game.gemAction(actionType, param, pos)

	if actionType == 3 then
		scheduleEvent(function()
			local gem = GemAtelier.getGemDataById(param)
			if not gem then
				g_logger.debug(string.format("[GemAtelier] Failed to toggle lock: gem id=%d not found.", param))
				return
			end

			gem.locked = gem.locked == 1 and 0 or 1
			g_logger.debug(string.format("[GemAtelier] Toggled local lock of gem id=%d -> %s", 
				param, gem.locked == 1 and "locked" or "unlocked"))

			if lastSelectedGem and lastSelectedGem.locker then
				lastSelectedGem.locker:setChecked(gem.locked == 1)
			end

			local lastIndex = lastSelectedGem and lastSelectedGem.gemIndex or 1
			GemAtelier.showGems(false, lastIndex)
		end, 300)
	end
end



function GemAtelier.onRevealGem(button, gemType)
	if not button:isOn() then
		return true
	end
	sendgemAction(1, gemType)
end

function GemAtelier.onSwitchDomain(button)
	if not button:isOn() or not lastSelectedGem then
	  return true
	end
  
	local gemData = GemAtelier.getGemDataById(lastSelectedGem.gemID)
	if gemData then
	  g_logger.debug(string.format("[GemAtelier] Requesting domain switch for gem id=%d", gemData.gemID))
	  sendgemAction(2, gemData.gemID)
	else
	  g_logger.debug(string.format("[GemAtelier] onSwitchDomain: gemData not found for gemID=%s", tostring(lastSelectedGem.gemID)))
	end
end

function GemAtelier.onDestroyGem(button)
	if not button or not button:isOn() or not lastSelectedGem or destroyGemWindow ~= nil then
	  return true
	end
  
	local gemData = GemAtelier.getGemDataById(lastSelectedGem.gemID)
	if not gemData then
	  g_logger.debug("[GemAtelier] Failed to destroy: gemData not found.")
	  return true
	end
  
	wheelWindow:hide()
	wheelWindow:ungrabMouse()
	wheelWindow:ungrabKeyboard()
  
	local yesFunction = function()
	  sendgemAction(0, gemData.gemID)
	  g_logger.debug(string.format("[GemAtelier] Requesting gem destruction id=%d", gemData.gemID))
	  wheelWindow:show(true)
	  destroyGemWindow:destroy()
	  destroyGemWindow = nil
	  wheelWindow:grabMouse()
	  wheelWindow:grabKeyboard()
	end
  
	local noFunction = function()
	  wheelWindow:show(true)
	  destroyGemWindow:destroy()
	  destroyGemWindow = nil
	  wheelWindow:grabMouse()
	  wheelWindow:grabKeyboard()
	end
  
	destroyGemWindow = displayGeneralBox(
	  tr('Destroy Gem'),
	  tr("Are you sure you want to destroy this gem?"),
	  { { text = tr('Yes'), callback = yesFunction }, { text = tr('No'), callback = noFunction } },
	  yesFunction, noFunction
	)
  end
  

function GemAtelier.onLockGem(button)
	local gemID = (button and button.gemID) or (lastSelectedGem and lastSelectedGem.gemID)
	if not gemID then
	  g_logger.debug("[GemAtelier] onLockGem called without gemID.")
	  return true
	end
	g_logger.debug(string.format("[GemAtelier] Toggle lock gemID=%d", gemID))
	sendgemAction(3, gemID)
end
  
function GemAtelier.showLockedOnly(button)
	if not gemAtelierWindow then
		return true
	end

	lockedOnly = button:isChecked()
	currentPage = 1
	GemAtelier.showGems()
	GemAtelier.configurePages()
	local gemList = gemAtelierWindow:recursiveGetChildById("gemContent")
	if not gemList then
		return true
	end

	if #gemList:getChildren() > 0 then
		GemAtelier.onSelectGem(gemList:getChildren()[1])
	end
end

function GemAtelier.onSortQuality(widget, selectedIndex)
	if not gemAtelierWindow then
		return true
	end

	if type(selectedIndex) ~= "number" then
		if type(widget) == "number" then
			selectedIndex = widget
		elseif widget and widget.currentIndex then
			selectedIndex = widget.currentIndex
		else
			selectedIndex = 1
		end
	end


	sortQuality = selectedIndex
	currentPage = 1
	GemAtelier.showGems()
	GemAtelier.configurePages()
	local gemList = gemAtelierWindow:recursiveGetChildById("gemContent")
	if not gemList then
		return true
	end

	if #gemList:getChildren() > 0 then
		GemAtelier.onSelectGem(gemList:getChildren()[1])
	end
end

function GemAtelier.onSortAffinity(widget, selectedIndex)
	if not gemAtelierWindow then
		return true
	end

	if type(selectedIndex) ~= "number" then
		if type(widget) == "number" then
			selectedIndex = widget
		elseif widget and widget.currentIndex then
			selectedIndex = widget.currentIndex
		else
			selectedIndex = 1
		end
	end


	sortAffinity = selectedIndex
	currentPage = 1
	GemAtelier.showGems()
	GemAtelier.configurePages()
	local gemList = gemAtelierWindow:recursiveGetChildById("gemContent")
	if not gemList then
		return true
	end

	if #gemList:getChildren() > 0 then
		GemAtelier.onSelectGem(gemList:getChildren()[1])
	end
end

function GemAtelier.onSearchChange(self)
	local text = self:getText()
	if #text == 0 then
		currentSearchText = ""
		GemAtelier.showGems(true)
		return true
	end
	currentSearchText = text
	GemAtelier.showGems(true)
end

function GemAtelier.setupVesselPanel()
    if not gemAtelierWindow then
        return true
    end

    local selectWidget = gemAtelierWindow:recursiveGetChildById("vesselsContent")
    if not selectWidget then
        g_logger.debug("[GemAtelier] vesselsContent not found in window.")
        return
    end

    for i = 0, 3 do
        local background = selectWidget:recursiveGetChildById("vesselBg" .. i)
        local gemContainer = selectWidget:recursiveGetChildById("vessel" .. i)
        local gemItem = selectWidget:recursiveGetChildById("gemItem" .. i)

        if not background or not gemContainer or not gemItem then
            g_logger.debug(string.format(
                "[GemAtelier] Estrutura do slot %d incompleta (bg=%s, container=%s, gem=%s)",
                i, tostring(background ~= nil), tostring(gemContainer ~= nil), tostring(gemItem ~= nil)
            ))
        else
            background:setImageSource("/images/game/wheel/backdrop_skillwheel_socket_inactive")
            gemContainer:setVisible(false)
            gemItem:setImageClip("0 0 32 32")

            gemItem.gemID = -1
            gemItem:setVisible(false)

            local filledCount = GemAtelier.getFilledVesselCount(i)
            if filledCount ~= 0 then
                local startPos = 442
                local containerOffset = startPos + (102 * i)
                local modOffset = 34 * math.max(0, filledCount - 1)
                gemContainer:setImageClip(containerOffset + modOffset .. " 0 34 34")
                gemContainer:setVisible(true)
                background:setImageSource("/images/game/wheel/backdrop_skillwheel_socket_active")
            end
        end
    end

    for _, id in pairs(WheelOfDestiny.equipedGems) do
        if type(id) ~= "number" or id < 0 then
            goto skipGem
        end
        
        local data = GemAtelier.getGemDataById(id)
        if data then
            local background = selectWidget:recursiveGetChildById("vesselBg" .. data.gemDomain)
            local gemContainer = selectWidget:recursiveGetChildById("vessel" .. data.gemDomain)
            local gemItem = selectWidget:recursiveGetChildById("gemItem" .. data.gemDomain)

            if background and gemContainer and gemItem then
                if GemAtelier.isVesselAvailable(data.gemDomain, 1) then
                    background:setImageSource("/images/game/wheel/backdrop_skillwheel_socket_active")
                    gemContainer:setVisible(true)
                end

                local typeOffset = data.gemType * 32
                local domainOffset = data.gemDomain * 96
                local vocationOffset = (WheelOfDestiny.vocationId - 1) * 384
                local gemOffset = vocationOffset + domainOffset + typeOffset

                gemItem:setImageClip(gemOffset .. " 0 32 32")
                gemItem.gemID = data.gemID
                gemItem:setVisible(true)

                local startPos = 442
                local filledCount = GemAtelier.getFilledVesselCount(data.gemDomain)
                if filledCount == (data.gemType + 1) then
                    startPos = 34
                end

                local containerOffset = startPos + (102 * data.gemDomain)
                local modOffset = 34 * math.max(0, filledCount - 1)
                gemContainer:setImageClip(containerOffset + modOffset .. " 0 34 34")
            else
                g_logger.debug(string.format(
                    "[GemAtelier] Slot %d incomplete when applying gem %d.",
                    data.gemDomain or -1, data.gemID or -1
                ))
            end
        end
        ::skipGem::
    end

    g_logger.debug("[GemAtelier] setupVesselPanel completed with 4 vessels.")
end


function GemAtelier.onClickVessel(widget, domain)
	g_logger.debug(string.format("[DebugClick] Click on vessel domain=%d gemID=%s", domain, tostring(widget.gemID)))
  
	if lastSelectedVessel then
	  lastSelectedVessel:setVisible(false)
	end
  
	local currentHighlight = gemAtelierWindow:recursiveGetChildById("selectVessel" .. domain)
	if currentHighlight then
	  currentHighlight:setVisible(true)
	  lastSelectedVessel = currentHighlight
	end
  
	local gemItem = gemAtelierWindow:recursiveGetChildById("gemItem" .. domain)
	local gemID = gemItem and gemItem.gemID
  
	local gemData = nil
	if gemID ~= nil then
	  gemData = GemAtelier.getGemDataById(gemID)
	end
  
	if gemData and gemData.gemDomain == domain then
	  g_logger.debug(string.format("[DebugClick] Gem found id=%d domain=%d (valid for vessel)", gemData.gemID, gemData.gemDomain))
	  GemAtelier.redirectToGem(gemData)
	  return
	end
  
	local fallbackGem = nil
	for _, data in pairs(WheelOfDestiny.atelierGems or {}) do
	  if data.gemDomain == domain then
		if not fallbackGem or data.gemID < fallbackGem.gemID then
		  fallbackGem = data
		end
	  end
	end
  
	if fallbackGem then
	  g_logger.debug(string.format("[DebugClick] No vessel equipped -> focusing smallest gem of domain %d (gemID=%d)", domain, fallbackGem.gemID))
	  GemAtelier.redirectToGem(fallbackGem)
	else
	  g_logger.debug(string.format("[DebugClick] No gem found in domain %d -> just filtering", domain))
	  GemAtelier.currentDomain = domain
	  if GemAtelier.showGems then
		GemAtelier.showGems(false, domain)
	  end
	end
end
  
function GemAtelier.onUnlockGem(gemID)
end

function GemAtelier.onModRedirect(self)
	local modID = self.modID
	local isSupreme = self.isSupreme
	local itemsPerPage = 30
	local pageIndex = nil
	local focusIndex = 0

	for i, k in pairs(Workshop.getFragmentList()) do
		if (isSupreme and k.supreme and k.modID == modID) or (not isSupreme and not k.supreme and k.modID == modID) then
			pageIndex = math.ceil(i / itemsPerPage)
			focusIndex = ((i - 1) % itemsPerPage) + 1
			break
		end
	end

	if not pageIndex then
		return true
	end

	Workshop.setCurrentPage(pageIndex)
	Workshop.showFragmentList(true, false, false, "", focusIndex)
	gemAtelierWindow:hide()
	fragmentWindow:show(true)
    gemMenuButton:setChecked(false)
    fragmentMenuButton:setChecked(true)
end

function GemAtelier.onHoverGem(self, hovered)
	local hoverWidget = self:recursiveGetChildById("hover")
	if not hoverWidget then
		return true
	end
	hoverWidget:setVisible(hovered)
	hoverWidget:setImageClip(self.currentTier and (200 + self.currentTier * 50 .. " 0 50 50") or "0 0 50 50")
	if hovered then
		g_mouse.pushCursor('pointer')
	else
		g_mouse.popCursor('pointer')
	end
end

function GemAtelier.getDamageAndHealing(self)
  local damage = 0
	for i = 0, 3 do
		local data = self.getEquipedGem(i)
		if data then
			local filledCount = self.getFilledVesselCount(i)
			if filledCount >= (data.gemType + 1) then
				damage = damage + (data.gemType == 2 and 2 or 1)
			end
		end
	end
  return damage
end
