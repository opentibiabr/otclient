WheelOfDestiny = {}
WheelOfDestiny.__index = WheelOfDestiny
WheelOfDestiny.pointInvested = {}
WheelOfDestiny.clickIndex = {}

WheelOfDestiny.equipedGems = {}
WheelOfDestiny.atelierGems = {}
WheelOfDestiny.basicModsUpgrade =  {}
WheelOfDestiny.supremeModsUpgrade =  {}
WheelOfDestiny.vocationId = 0
WheelOfDestiny.changeState = 0
WheelOfDestiny.lastSelectedGemVessel = nil
WheelOfDestiny.extraGemPoints = 0
WheelOfDestiny.fromAchievementType = 0

WheelOfDestiny.passivePoints = {}
WheelOfDestiny.extraPassivePoints = {}

WheelOfDestiny.basicModCount = {}
WheelOfDestiny.supremeModCount = {}

WheelOfDestiny.vesselEnabled = {}

WheelOfDestiny.equipedGemBonuses = {}

WheelOfDestiny.externalPreset = {}
WheelOfDestiny.internalPreset = {}
WheelOfDestiny.currentPreset = {}

WheelOfDestiny.mouseIndex = 0

WheelOfDestiny.revealedGems = {}

local openWheel = nil
local lastSelectedGemVessel = nil

local defaultExportString = {
  [0] = "",
  [1] = "K0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
  [2] = "P0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
  [3] = "S0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
  [4] = "D0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
  [5] = "M0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
}

local function normalizeEquipedGems(equipedGems)
  if type(equipedGems) ~= "table" then
    return {-1, -1, -1, -1}
  end

  local normalized = {}
  local hasStruct = false
  for _, value in pairs(equipedGems) do
    if type(value) == "table" and value.gemID ~= nil then
      hasStruct = true
      break
    end
  end

  if hasStruct then
    local domains = {GemDomains.GREEN, GemDomains.RED, GemDomains.ACQUA, GemDomains.PURPLE}
    for _, domain in ipairs(domains) do
      local entry = equipedGems[domain]
      local gemId = type(entry) == "table" and tonumber(entry.gemID) or tonumber(entry)
      table.insert(normalized, gemId or -1)
    end
  else
    for _, value in ipairs(equipedGems) do
      local gemId = tonumber(value)
      table.insert(normalized, gemId or -1)
    end
    if #normalized == 0 then
      for _, value in pairs(equipedGems) do
        local gemId = tonumber(value)
        table.insert(normalized, gemId or -1)
      end
    end
  end

  while #normalized < 4 do
    table.insert(normalized, -1)
  end

  return normalized
end

function WheelOfDestiny.getSliceIndex(position)
  local x = centerReferencePoint:getX()
  local y = centerReferencePoint:getY()

  
  local wheelClick = WheelSettings.topLeft
  if position.x <= x then
    
    if position.y > y then
      wheelClick = WheelSettings.bottomLeft
    else
      wheelClick = WheelSettings.topLeft
    end
    
  else
    
    if position.y > y then
      wheelClick = WheelSettings.bottomRight
    else
      wheelClick = WheelSettings.topRight
    end
  end

  local bigLargeCircle = Circle.new(x, y, BIG_LARGE_CIRCLE)
  local largeCircle = Circle.new(x, y, LARGE_CIRCLE)
  local bigMediumCircle = Circle.new(x, y, BIG_MEDIUM_CIRCLE)
  local mediumCircle = Circle.new(x, y, MEDIUM_CIRCLE)
  local smallCircle = Circle.new(x, y, SMALL_CIRCLE)

  for _, index in pairs(wheelClick) do
    if WheelButtons[index] then
      local radius = WheelButtons[index].radius
      local circle = Circle.new(x, y, radius)
      if radius == BIG_LARGE_CIRCLE and (largeCircle:inArea(position) or bigMediumCircle:inArea(position) or mediumCircle:inArea(position) or smallCircle:inArea(position)) then
        goto continue
      elseif radius == BIG_LARGE_CIRCLE then
        circle = bigLargeCircle
      elseif radius == LARGE_CIRCLE and (bigMediumCircle:inArea(position) or mediumCircle:inArea(position) or smallCircle:inArea(position)) then
        goto continue
      elseif radius == LARGE_CIRCLE then
        circle = largeCircle
      elseif radius == BIG_MEDIUM_CIRCLE and (mediumCircle:inArea(position) or smallCircle:inArea(position)) then
        goto continue
      elseif radius == BIG_MEDIUM_CIRCLE then
        circle = bigMediumCircle
      elseif radius == MEDIUM_CIRCLE and smallCircle:inArea(position) then
        goto continue
      elseif radius == MEDIUM_CIRCLE then
        circle = mediumCircle
      elseif radius == SMALL_CIRCLE then
        circle = smallCircle
      end

      if circle:inArea(position) then
        if circle:isPointInSlice(position, WheelButtons[index].slice, WheelButtons[index].totalSlice) then
          return index
        end
      end

      ::continue::
    end
  end

  return 0
end

function WheelOfDestiny.canAddPoints(index, ignoreMaxPoint)
  if WheelOfDestiny.vocationId == 0 then
    return false
  end

  if ignoreMaxPoint == nil then
    ignoreMaxPoint = false
  end

  local bonus = WheelBonus[index - 1]
  if not ignoreMaxPoint then
    if WheelOfDestiny.pointInvested[index] >= bonus.maxPoints then
      return false
    end
  end

  if not WheelOfDestiny.points then
    WheelOfDestiny.points = 0
  end

  local totalPoints = WheelOfDestiny.points + (WheelOfDestiny.extraGemPoints + WheelOfDestiny.scrollPoints)

  if not ignoreMaxPoint then
    if totalPoints - WheelOfDestiny.usedPoints <= 0 then
      return false
    end
  end

  if bonus.maxPoints == 50 then
    return true
  end

  local iconInfo = WheelNodes[index]
  if #iconInfo.connecteds == 0 then
    return true
  end

  for _, id in pairs(iconInfo.connecteds) do
    local bonus = WheelBonus[id - 1]
    local pointInvested = WheelOfDestiny.pointInvested[id]
    if pointInvested >= bonus.maxPoints then
      return true
    end
  end

  return false
end

function WheelOfDestiny.canRemovePoints(index)
  if not WheelOfDestiny.isLit(index) then
    return false
  end

  if WheelOfDestiny.changeState ~= 1 then
    return false
  end

  if WheelButtons[index].radius == BIG_LARGE_CIRCLE then
    return true
  end

  local iconInfo = WheelNodes[index]
  if not iconInfo.connections or #iconInfo.connections == 0 then
    return true
  end

  local c = WheelNodes[index].connections
  for _, id in pairs(c) do
    if WheelOfDestiny.isLit(id) and not canReachRootNodeFromNode(id, index) then
        return false
    end
  end

  return true
end

function WheelOfDestiny.isLit(index)
  return WheelOfDestiny.pointInvested[index] > 0
end

function WheelOfDestiny.isLitFull(index)
  return WheelOfDestiny.pointInvested[index] ==  WheelBonus[index - 1].maxPoints
end

function WheelOfDestiny.insertUnlockedThe(index)
  local iconInfo = WheelNodes[index]
  if #iconInfo.connections == 0 then
    return false
  end

  local bonus = WheelBonus[index - 1]
  local pointInvested = WheelOfDestiny.pointInvested[index]
  if pointInvested < bonus.maxPoints then
    return false
  end

  for _, id in pairs(iconInfo.connections) do
    local widgetFull = wheelPanel:recursiveGetChildById('fullColorWheel_'..id)
    widgetFull:setVisible(true)
    widgetFull:setOpacity(0.2)
  end
end

function WheelOfDestiny.removeUnlockedThe(index)
  local iconInfo = WheelNodes[index]
  if #iconInfo.connections == 0 then
    return false
  end

  for _, unlocked_point in pairs(iconInfo.connections) do
    local skipUnlock = {}
    for _alternative, alternative_unlocker in ipairs(WheelNodes[unlocked_point].connecteds) do
      if alternative_unlocker ~= index and WheelOfDestiny.isLit(alternative_unlocker) then
        skipUnlock[#skipUnlock + 1] = unlocked_point
      end
    end

    if not table.isIn(skipUnlock, unlocked_point) then
      local widgetFull = wheelPanel:recursiveGetChildById('fullColorWheel_'..unlocked_point)
      widgetFull:setVisible(false)
      widgetFull:setOpacity(0.2)
    end
  end

end

function WheelOfDestiny.onWheelClick(position)
  local index = WheelOfDestiny.getSliceIndex(position)
  if index == 0 then
    return
  end

  WheelOfDestiny.resetPassiveFocus()

  local pointInvested = WheelOfDestiny.pointInvested[index]
  if not pointInvested then
    return
  end

  if WheelOfDestiny.lastSelectedGemVessel then
    WheelOfDestiny.lastSelectedGemVessel:setVisible(false)
  end

  if wheelOfDestinyWindow.selection.gemContent:isVisible() then
    wheelOfDestinyWindow.selection.gemContent:setVisible(false)
    wheelOfDestinyWindow.selection.tabContent:setVisible(true)
  end

  if not wheelWindow:recursiveGetChildById('tabContent'):isVisible() then
    wheelWindow:recursiveGetChildById('tabContent'):setVisible(true)
  end

  WheelOfDestiny.clickIndex = index
  wheelPanel.borderSelectedWheel:setVisible(true)
  wheelPanel.borderSelectedWheel:setImageSource(WheelButtons[index].borderImageBase)

  local bonus = WheelBonus[index - 1]
  wheelOfDestinyWindow.selection.tabContent.information1:setTooltip(ConvictionTooltip)

  wheelOfDestinyWindow.selection.tabContent.dedicationPb:setValue(pointInvested, 0, bonus.maxPoints)
  wheelOfDestinyWindow.selection.tabContent.dedicationPb:setText(pointInvested.." / ".. bonus.maxPoints)

  wheelOfDestinyWindow.selection.tabContent.dedicationTitle:setText("Dedication Perk")
  wheelOfDestinyWindow.selection.tabContent.convictionTitle:setText("Conviction Perk")
  wheelOfDestinyWindow.selection.tabContent.convictionTitle:setTextAlign(AlignCenter)

  WheelOfDestiny.configureDedication(index)
  WheelOfDestiny.configureConviction(index)
  WheelOfDestiny.checkManagerPointsButtons(index)
end

function WheelOfDestiny.onRemoveClick()
  if WheelOfDestiny.lastSelectedGemVessel then
    WheelOfDestiny.lastSelectedGemVessel:setVisible(false)
  end

  if wheelOfDestinyWindow.selection.gemContent:isVisible() then
    wheelOfDestinyWindow.selection.gemContent:setVisible(false)
    wheelOfDestinyWindow.selection.tabContent:setVisible(true)
  end

  WheelOfDestiny.clickIndex = 0
  wheelPanel.borderSelectedWheel:setVisible(false)
  wheelOfDestinyWindow:recursiveGetChildById('addMax'):setVisible(false)
  wheelOfDestinyWindow:recursiveGetChildById('addOne'):setVisible(false)
  wheelOfDestinyWindow:recursiveGetChildById('rmvMax'):setVisible(false)
  wheelOfDestinyWindow:recursiveGetChildById('rmvOne'):setVisible(false)

end

function WheelOfDestiny.checkManagerPointsButtons(index)
  wheelOfDestinyWindow:recursiveGetChildById('addMax'):setVisible(true)
  wheelOfDestinyWindow:recursiveGetChildById('addOne'):setVisible(true)
  wheelOfDestinyWindow:recursiveGetChildById('rmvMax'):setVisible(true)
  wheelOfDestinyWindow:recursiveGetChildById('rmvOne'):setVisible(true)

  if WheelOfDestiny.canAddPoints(index) then
    wheelOfDestinyWindow:recursiveGetChildById('addMax'):setEnabled(true)
    wheelOfDestinyWindow:recursiveGetChildById('addOne'):setEnabled(true)
  else
    wheelOfDestinyWindow:recursiveGetChildById('addMax'):setEnabled(false)
    wheelOfDestinyWindow:recursiveGetChildById('addOne'):setEnabled(false)
  end


  if WheelOfDestiny.canRemovePoints(index) then
    wheelOfDestinyWindow:recursiveGetChildById('rmvMax'):setEnabled(true)
    wheelOfDestinyWindow:recursiveGetChildById('rmvOne'):setEnabled(true)
  else
    wheelOfDestinyWindow:recursiveGetChildById('rmvMax'):setEnabled(false)
    wheelOfDestinyWindow:recursiveGetChildById('rmvOne'):setEnabled(false)
  end
end

function WheelOfDestiny.onMouseRelease(self, mousePosition, mouseButton)
  if mouseButton ~= MouseRightButton then
    return
  end

  local index = WheelOfDestiny.getSliceIndex(mousePosition)
  if index == 0 then
    return
  end

  local countByModifier = 0
  if g_keyboard.getModifiers() == KeyboardAltModifier then
    countByModifier = 1
  elseif g_keyboard.getModifiers() == KeyboardShiftModifier then
    countByModifier = 50
  elseif g_keyboard.getModifiers() == KeyboardCtrlModifier then
    countByModifier = 100
  end

  local bonus = WheelBonus[index - 1]
  local pointInvested = WheelOfDestiny.pointInvested[index]
  local pointInvested = WheelOfDestiny.pointInvested[index]

  if pointInvested > bonus.maxPoints then
    if not WheelOfDestiny.canRemovePoints(index) then
      return
    end

    onRmvMax(index)
    WheelOfDestiny.checkManagerPointsButtons(index)
    WheelOfDestiny.onWheelClick(mousePosition)
  else
    if not WheelOfDestiny.canAddPoints(index) then
      if WheelOfDestiny.canRemovePoints(index) then
        onRmvMax(index)
        WheelOfDestiny.checkManagerPointsButtons(index)
        WheelOfDestiny.onWheelClick(mousePosition)
      end
      return
    end

    if countByModifier ~= 0 then
      onAddCustom(index, countByModifier)
    else
      onAddMax(index)
    end
    WheelOfDestiny.checkManagerPointsButtons(index)
  end

  WheelOfDestiny.onWheelClick(mousePosition)
  return true
end

function WheelOfDestiny.onMouseMove(widget, position, offset)
  local index = WheelOfDestiny.getSliceIndex(position)
  if index == 0 then
    wheelPanel.focusSelectedWheel:setVisible(false)
    return
  end

  if WheelOfDestiny.mouseIndex == index then
    return
  end

  WheelOfDestiny.mouseIndex = index

  local bonus = WheelBonus[index - 1]
  local pointInvested = WheelOfDestiny.pointInvested[index]
  if not pointInvested then
    wheelPanel.focusSelectedWheel:setVisible(false)
    return
  end

  local bar = wheelOfDestinyWindow.info.tabContent.information.tabContent.dedicationPB2

  bar:setValue(pointInvested, 0, bonus.maxPoints)
  bar:setText(pointInvested.." / ".. bonus.maxPoints)

  bar:setImageSource("/game_cyclopedia/images/ui/mosnter-bar")
  bar:setPercent((pointInvested * 100 / bonus.maxPoints))

  wheelOfDestinyWindow.info.tabContent.information.tabContent.dedication2:setText(getDedicationBonus(index))
  if WheelOfDestiny.pointInvested[index] > 0 then
    wheelOfDestinyWindow.info.tabContent.information.tabContent.dedication2:setColor("#c0c0c0")
  else
    wheelOfDestinyWindow.info.tabContent.information.tabContent.dedication2:setColor("#707070")
  end

  local conviction = getConvictionBonus(index, true)
  if type(conviction) == "string" then
    wheelOfDestinyWindow.info.tabContent.information.tabContent.conviction2:setText(conviction)
    if WheelOfDestiny.pointInvested[index] >= bonus.maxPoints then
      wheelOfDestinyWindow.info.tabContent.information.tabContent.conviction2:setColor("#c0c0c0")
    else
      wheelOfDestinyWindow.info.tabContent.information.tabContent.conviction2:setColor("#707070")
    end
  elseif type(conviction) == "table" then
    wheelOfDestinyWindow.info.tabContent.information.tabContent.conviction2:setColoredText(conviction)
  end

  wheelPanel.focusSelectedWheel:setVisible(true)
  wheelPanel.focusSelectedWheel:setOpacity(0.3)
  wheelPanel.focusSelectedWheel:setImageSource(WheelButtons[index].focusImageBase)
end

function WheelOfDestiny.insertPoint(index, points)
  local bonus = WheelBonus[index - 1]
  if points > 0 then
    wheelPanel:recursiveGetChildById('fullColorWheel_'..index):setVisible(true)
    wheelPanel:recursiveGetChildById('fullColorWheel_'..index):setOpacity(0.2)
    wheelPanel:recursiveGetChildById('colorWheel_'..index):setVisible(true)
    local button = WheelButtons[index]
    if points >= bonus.maxPoints then
      local maxcolor = 20
      if button.radius == BIG_LARGE_CIRCLE then
        maxcolor = 20
      elseif button.radius == LARGE_CIRCLE then
        maxcolor = 15
      elseif button.radius == BIG_MEDIUM_CIRCLE then
        maxcolor = 10
      elseif button.radius == MEDIUM_CIRCLE then
        maxcolor = 8
      elseif button.radius == SMALL_CIRCLE then
        maxcolor = 5
      end
      wheelPanel:recursiveGetChildById('colorWheel_'..index):setImageSource(button.colorImageBase .. maxcolor)
      wheelPanel:recursiveGetChildById('colorWheel_'..index):setOpacity(0.6)
      WheelOfDestiny.insertUnlockedThe(index)

      local widget = wheelPanel:recursiveGetChildById("icon"..index)
      local modIcon = widget:recursiveGetChildById("modIcon"..index)
      local iconInfo = WheelIcons[WheelOfDestiny.vocationId][index]

      if bonus and table.contains(VesselIndex[bonus.domain - 1], index - 1) then
        local gem = GemAtelier.getEquipedGem(bonus.domain - 1)
        if gem then
          local enabled = WheelOfDestiny.vesselEnabled[bonus.domain - 1]
          if #enabled == 0 and gem.lesserBonus > -1 then
            widget:setImageSource("/images/game/wheel/icons-skillwheel-basicmods")
            widget:setImageClip(30 * gem.lesserBonus .. " 0 30 30")
            modIcon:setVisible(true)
            WheelOfDestiny.equipedGemBonuses[index] = {bonusID = gem.lesserBonus, supreme = false, gemID = gem.gemID}
            table.insert(WheelOfDestiny.vesselEnabled[bonus.domain - 1], index)
          elseif #enabled == 1 and gem.regularBonus > -1 then
            widget:setImageSource("/images/game/wheel/icons-skillwheel-basicmods")
            widget:setImageClip(30 * gem.regularBonus .. " 0 30 30")
            modIcon:setVisible(true)
            WheelOfDestiny.equipedGemBonuses[index] = {bonusID = gem.regularBonus, supreme = false, gemID = gem.gemID}
            table.insert(WheelOfDestiny.vesselEnabled[bonus.domain - 1], index)
          elseif #enabled == 2 and gem.supremeBonus > -1 then
            widget:setImageSource("/images/game/wheel/icons-skillwheel-suprememods")
            widget:setImageClip(35 * gem.supremeBonus .. " 0 35 35")
            widget:setSize(tosize("35 35"))
            modIcon:setVisible(true)
            WheelOfDestiny.equipedGemBonuses[index] = {bonusID = gem.supremeBonus, supreme = false, gemID = gem.gemID}
            table.insert(WheelOfDestiny.vesselEnabled[bonus.domain - 1], index)
          end
        else
          widget:setImageSource("/images/game/wheel/icons-skillwheel-mediumperks")
          widget:setImageClip(iconInfo.iconRect)
          modIcon:setVisible(false)
        end
      else
        widget:setImageClip(iconInfo.iconRect)
      end
    else
      local maxcolor = math.floor(points / 10) + 1
      if maxcolor > 0 then
        wheelPanel:recursiveGetChildById('colorWheel_'..index):setImageSource(button.colorImageBase .. maxcolor)
        wheelPanel:recursiveGetChildById('colorWheel_'..index):setOpacity(0.6)
      end
    end
  elseif index ~= 15 and index ~= 16 and index ~= 21 and index ~= 22 then
    wheelPanel:recursiveGetChildById('fullColorWheel_'..index):setVisible(false)
    wheelPanel:recursiveGetChildById('colorWheel_'..index):setVisible(false)
  end

  WheelOfDestiny.checkFilledVessels(index)
end

function WheelOfDestiny.checkFilledVessels(originalIndex)
	local bonus = WheelBonus[originalIndex - 1]
	local order = WheelDomainOrder[bonus.domain - 1]
	local function findIndex(value)
		for i, v in ipairs(order) do
			if v == value then
				return i
			end
		end
		return nil
	end

	local function customSort(a, b)
	local indexA = findIndex(a)
	local indexB = findIndex(b)
		return indexA < indexB
	end

	table.sort(WheelOfDestiny.vesselEnabled[bonus.domain - 1], customSort)

	local lastModInserted = 0
	for _, id in pairs(WheelOfDestiny.vesselEnabled[bonus.domain - 1]) do
		local widget = wheelPanel:recursiveGetChildById("icon"..id)
		local modIcon = widget:recursiveGetChildById("modIcon"..id)
		local iconInfo = WheelIcons[WheelOfDestiny.vocationId][id]

		bonus = WheelBonus[id - 1]
		local gem = GemAtelier.getEquipedGem(bonus.domain - 1)
		if not gem then
			goto continue
		end

		widget:setImageSource("/images/game/wheel/icons-skillwheel-mediumperks")
		widget:setImageClip(iconInfo.iconRect)
		widget:setSize(tosize("30 30"))

		if lastModInserted == 0 and gem.lesserBonus > -1 then
			widget:setImageSource("/images/game/wheel/icons-skillwheel-basicmods")
			widget:setImageClip(30 * gem.lesserBonus .. " 0 30 30")
			modIcon:setVisible(true)
			WheelOfDestiny.equipedGemBonuses[id] = {bonusID = gem.lesserBonus, supreme = false, gemID = gem.gemID}
			lastModInserted = 1
		elseif lastModInserted == 1 and gem.regularBonus > -1 then
			widget:setImageSource("/images/game/wheel/icons-skillwheel-basicmods")
			widget:setImageClip(30 * gem.regularBonus .. " 0 30 30")
			modIcon:setVisible(true)
			WheelOfDestiny.equipedGemBonuses[id] = {bonusID = gem.regularBonus, supreme = false, gemID = gem.gemID}
			lastModInserted = 2
		elseif lastModInserted == 2 and gem.supremeBonus > -1 then
			widget:setImageSource("/images/game/wheel/icons-skillwheel-suprememods")
			widget:setImageClip(35 * gem.supremeBonus .. " 0 35 35")
			widget:setSize(tosize("35 35"))
			modIcon:setVisible(true)
			WheelOfDestiny.equipedGemBonuses[id] = {bonusID = gem.supremeBonus, supreme = true, gemID = gem.gemID}
			lastModInserted = 3
		end
		:: continue ::
	end
end

function WheelOfDestiny.removePoint(index, points)
  local bonus = WheelBonus[index - 1]
  if points > 0 then
    wheelPanel:recursiveGetChildById('fullColorWheel_'..index):setVisible(true)
    wheelPanel:recursiveGetChildById('fullColorWheel_'..index):setOpacity(0.2)
    wheelPanel:recursiveGetChildById('colorWheel_'..index):setVisible(true)
    local button = WheelButtons[index]
    if points >= bonus.maxPoints then
      local maxcolor = 20
      if button.radius == BIG_LARGE_CIRCLE then
        maxcolor = 20
      elseif button.radius == LARGE_CIRCLE then
        maxcolor = 15
      elseif button.radius == BIG_MEDIUM_CIRCLE then
        maxcolor = 10
      elseif button.radius == MEDIUM_CIRCLE then
        maxcolor = 8
      elseif button.radius == SMALL_CIRCLE then
        maxcolor = 5
      end

      wheelPanel:recursiveGetChildById('colorWheel_'..index):setImageSource(button.colorImageBase .. maxcolor)
      wheelPanel:recursiveGetChildById('colorWheel_'..index):setOpacity(0.6)
      WheelOfDestiny.insertUnlockedThe(index)
    else
      if table.contains(VesselIndex[bonus.domain - 1], index - 1) then
        local widget = wheelPanel:recursiveGetChildById("icon"..index)
        local modIcon = widget:recursiveGetChildById("modIcon"..index)
        local iconInfo = WheelIcons[WheelOfDestiny.vocationId][index]
        widget:setImageSource("/images/game/wheel/icons-skillwheel-mediumperks")
        widget:setImageClip(iconInfo.iconRect)
        widget:setSize(tosize("30 30"))
        modIcon:setVisible(false)
        WheelOfDestiny.equipedGemBonuses[index] = {bonusID = -1, supreme = false, gemID = 0}
        local removeIndex = 0
        for k, id in pairs(WheelOfDestiny.vesselEnabled[bonus.domain - 1]) do
          if id == index then
            removeIndex = k;
          end
        end
        table.remove(WheelOfDestiny.vesselEnabled[bonus.domain - 1], removeIndex)
		WheelOfDestiny.checkFilledVessels(index)
      end

      local maxcolor = math.floor(points / 10) + 1
      if maxcolor > 0 then
        wheelPanel:recursiveGetChildById('colorWheel_'..index):setImageSource(button.colorImageBase .. maxcolor)
        wheelPanel:recursiveGetChildById('colorWheel_'..index):setOpacity(0.6)
      end
    end
  else
    if table.contains(VesselIndex[bonus.domain - 1], index - 1) then
      local widget = wheelPanel:recursiveGetChildById("icon"..index)
      local modIcon = widget:recursiveGetChildById("modIcon"..index)
      local iconInfo = WheelIcons[WheelOfDestiny.vocationId][index]
      widget:setImageSource("/images/game/wheel/icons-skillwheel-mediumperks")
      widget:setImageClip(iconInfo.iconRect)
      widget:setSize(tosize("30 30"))
      modIcon:setVisible(false)
      WheelOfDestiny.equipedGemBonuses[index] = {bonusID = -1, supreme = false, gemID = 0}
      local removeIndex = 0
      for k, id in pairs(WheelOfDestiny.vesselEnabled[bonus.domain - 1]) do
         if id == index then
          removeIndex = k;
         end
      end
      table.remove(WheelOfDestiny.vesselEnabled[bonus.domain - 1], removeIndex)
	  WheelOfDestiny.checkFilledVessels(index)
    end

    wheelPanel:recursiveGetChildById('fullColorWheel_'..index):setVisible(true)
    wheelPanel:recursiveGetChildById('colorWheel_'..index):setVisible(false)
  end
end

function WheelOfDestiny.onDestinyWheel(playerId, canView, changeState, vocationId, points, scrollPoints, pointInvested, usedPromotionScrolls, equipedGems, atelierGems, basicUpgraded, supremeUpgraded, earnedFromAchievements)
  if not table.isIn({1, 2, 3, 4, 5}, vocationId) then
    local cancelFunc = function()
      if openWheel then
        openWheel:destroy()
        openWheel = nil
      end
    end

    if not openWheel then
      openWheel = displayGeneralBox(tr('Info'), tr("To be able to use the Wheel of Destiny, a character must be at leat level 51, be promoted and have active\nPremium Time."),
      { { text=tr('Ok'), callback=cancelFunc }}, cancelFunc)
      wheelWindow:hide()
    end
    return
  end

  if table.empty(WheelOfDestiny.internalPreset) then
    WheelOfDestiny.loadWheelPresets()
  end

  if not wheelWindow:isVisible() then
    wheelWindow:show()
    WheelOfDestiny.resetPassiveFocus()
  end

  resetWheel(true)

  local player = g_game.getLocalPlayer()
  local bankMoney = player:getResourceBalance(ResourceTypes.BANK_BALANCE)
  local characterMoney = player:getResourceBalance(ResourceTypes.GOLD_EQUIPPED)
  local lesserFragment = player:getResourceBalance(ResourceTypes.LESSER_FRAGMENTS)
  local greaterFragment = player:getResourceBalance(ResourceTypes.GREATER_FRAGMENTS)

  local value = bankMoney + characterMoney
  wheelWindow.moneyPanel.gold:setText(formatMoney(value, ','))
  wheelWindow.lesserFragmentPanel.gold:setText(lesserFragment)
  wheelWindow.greaterFragmentPanel.gold:setText(greaterFragment)

  WheelOfDestiny.create(playerId, canView, changeState, vocationId, points, scrollPoints, pointInvested, usedPromotionScrolls, equipedGems, atelierGems, basicUpgraded, supremeUpgraded, earnedFromAchievements)

  if GemAtelier and gemAtelierWindow and gemAtelierWindow:isVisible() then
    if GemAtelier.setupVesselPanel then
      GemAtelier.setupVesselPanel()
    end
  end

  wheelPanel.onMouseRelease = WheelOfDestiny.onMouseRelease

  local presetEnabled = (changeState == 1)
  local managePresetsButton = wheelWindow.mainPanel.wheelMenu.info.presetTabBar:getChildById('managePresetsButton')
  if not presetEnabled then
    toggleTabBarButtons('informationButton')
  end

  managePresetsButton:setEnabled(presetEnabled)

  if vocationId == 1 then
    wheelPanel.vocationWheel:setImageSource('/images/game/wheel/wheel-vocations/backdrop_skillwheel_knight')
    wheelPanel:recursiveGetChildById("perkIconTopLeft"):setImageClip("0 0 34 34")
    wheelPanel:recursiveGetChildById("perkIconTopRight"):setImageClip("34 0 34 34")
    wheelPanel:recursiveGetChildById("perkIconBottomLeft"):setImageClip("68 0 34 34")
    wheelPanel:recursiveGetChildById("perkIconBottomRight"):setImageClip("102 0 34 34")
  elseif vocationId == 2 then
    wheelPanel.vocationWheel:setImageSource('/images/game/wheel/wheel-vocations/backdrop_skillwheel_paladin')
    wheelPanel:recursiveGetChildById("perkIconTopLeft"):setImageClip("0 0 34 34")
    wheelPanel:recursiveGetChildById("perkIconTopRight"):setImageClip("136 0 34 34")
    wheelPanel:recursiveGetChildById("perkIconBottomLeft"):setImageClip("170 0 34 34")
    wheelPanel:recursiveGetChildById("perkIconBottomRight"):setImageClip("204 0 34 34")
  elseif vocationId == 3 then
    wheelPanel.vocationWheel:setImageSource('/images/game/wheel/wheel-vocations/backdrop_skillwheel_sorcerer')
    wheelPanel:recursiveGetChildById("perkIconTopLeft"):setImageClip("0 0 34 34")
    wheelPanel:recursiveGetChildById("perkIconTopRight"):setImageClip("238 0 34 34")
    wheelPanel:recursiveGetChildById("perkIconBottomLeft"):setImageClip("272 0 34 34")
    wheelPanel:recursiveGetChildById("perkIconBottomRight"):setImageClip("306 0 34 34")
  elseif vocationId == 4 then
    wheelPanel.vocationWheel:setImageSource('/images/game/wheel/wheel-vocations/backdrop_skillwheel_druid')
    wheelPanel:recursiveGetChildById("perkIconTopLeft"):setImageClip("0 0 34 34")
    wheelPanel:recursiveGetChildById("perkIconTopRight"):setImageClip("374 0 34 34")
    wheelPanel:recursiveGetChildById("perkIconBottomLeft"):setImageClip("340 0 34 34")
    wheelPanel:recursiveGetChildById("perkIconBottomRight"):setImageClip("408 0 34 34")
  elseif vocationId == 5 then
    wheelPanel.vocationWheel:setImageSource('/images/game/wheel/wheel-vocations/backdrop_skillwheel_monk')
    wheelPanel:recursiveGetChildById("perkIconTopLeft"):setImageClip("0 0 34 34")
    wheelPanel:recursiveGetChildById("perkIconTopRight"):setImageClip("442 0 34 34")
    wheelPanel:recursiveGetChildById("perkIconBottomLeft"):setImageClip("476 0 34 34")
    wheelPanel:recursiveGetChildById("perkIconBottomRight"):setImageClip("510 0 34 34")
  end
	
  if WheelOfDestiny.changeState == 1 then
    wheelWindow.reset:setEnabled(true)
    wheelWindow.apply:setEnabled(true)
    wheelWindow.ok:setEnabled(true)
  elseif WheelOfDestiny.changeState == 2 then
    wheelWindow.reset:setEnabled(false)
    wheelWindow.apply:setEnabled(true)
    wheelWindow.ok:setEnabled(true)
  else
    wheelWindow.reset:setEnabled(false)
    wheelWindow.apply:setEnabled(false)
    wheelWindow.ok:setEnabled(false)
  end

	WheelOfDestiny.onCreate(vocationId)
	WheelOfDestiny.checkApplyButton()

	WheelOfDestiny.determinateCurrentPreset()
	WheelOfDestiny.updateCurrentPreset()
  WheelOfDestiny.configureVessels()
end

function WheelOfDestiny.onCreate(vocationId)
	for id, iconInfo in pairs(WheelIcons[vocationId]) do
    local widget = wheelPanel:recursiveGetChildById("icon"..id)
    local modIcon = widget:recursiveGetChildById("modIcon"..id)
		
    if widget then
      local pointInvested = WheelOfDestiny.pointInvested[id]
      local bonus = WheelBonus[id - 1]
      if bonus and table.contains(VesselIndex[bonus.domain - 1], id - 1) then
        local gem = GemAtelier.getEquipedGem(bonus.domain - 1)
        if gem and pointInvested >= bonus.maxPoints then
          if bonus.modType == 0 and gem.lesserBonus > -1 then
            widget:setImageSource("/images/game/wheel/icons-skillwheel-basicmods")
            widget:setImageClip(30 * gem.lesserBonus .. " 0 30 30")
            modIcon:setVisible(true)
          elseif bonus.modType == 1 and gem.regularBonus > -1 then
            widget:setImageSource("/images/game/wheel/icons-skillwheel-basicmods")
            widget:setImageClip(30 * gem.regularBonus .. " 0 30 30")
            modIcon:setVisible(true)
          elseif bonus.modType == 2 and gem.supremeBonus > -1 then
            widget:setImageSource("/images/game/wheel/icons-skillwheel-suprememods")
            widget:setImageClip(35 * gem.supremeBonus .. " 0 35 35")
            widget:setSize(tosize("35 35"))
            modIcon:setVisible(true)
          else
            widget:setImageSource("/images/game/wheel/icons-skillwheel-mediumperks")
            widget:setImageClip(iconInfo.iconRect)
            widget:setSize(tosize("30 30"))
            modIcon:setVisible(false)
          end
        else
          widget:setImageSource("/images/game/wheel/icons-skillwheel-mediumperks")
          widget:setImageClip(iconInfo.iconRect)
          widget:setSize(tosize("30 30"))
          if modIcon then
            modIcon:setVisible(false)
          end
        end
      else
        widget:setImageClip(iconInfo.iconRect)
      end
    end
		
    local widget = wheelPanel:recursiveGetChildById("smallicon"..id)
    if widget then
      widget:setImageClip(iconInfo.miniIconRect)
    end
  end
	
  for i = 1, 4 do
    WheelOfDestiny.vesselEnabled[i - 1] = {}
    for _, index in pairs(WheelDomainOrder[i - 1]) do
      local bonus = WheelBonus[index - 1]
      local pointInvested = WheelOfDestiny.pointInvested[index]
      if pointInvested >= bonus.maxPoints and bonus.conviction == "vessel" then
        table.insert(WheelOfDestiny.vesselEnabled[bonus.domain - 1], index)
        WheelOfDestiny.checkFilledVessels(index + 1)
      end
    end
  end

  local totalPoints = WheelOfDestiny.points + (WheelOfDestiny.extraGemPoints + WheelOfDestiny.scrollPoints)
  wheelOfDestinyWindow.selection.points:setText(totalPoints - WheelOfDestiny.usedPoints .. " / ".. totalPoints)
	
  wheelPanel:recursiveGetChildById('fullColorWheel_15'):setVisible(true)
  wheelPanel:recursiveGetChildById('fullColorWheel_16'):setVisible(true)
  wheelPanel:recursiveGetChildById('fullColorWheel_21'):setVisible(true)
  wheelPanel:recursiveGetChildById('fullColorWheel_22'):setVisible(true)

  WheelOfDestiny.configureDedicationPerk()
  WheelOfDestiny.configureConvictionPerk()
  WheelOfDestiny.configureVessels()
  WheelOfDestiny.configureSummary()
  WheelOfDestiny.configurePassives()
  WheelOfDestiny.configureEquippedGems()
	
  if gemAtelierWindow:isVisible() then
	  GemAtelier.showGems()
  end
	
  if fragmentWindow:isVisible() then
    -- Preserve current search text and filter when refreshing after enhance
    local searchWidget = fragmentWindow:recursiveGetChildById('searchText')
    local currentSearch = searchWidget and searchWidget:getText() or ""
    Workshop.showFragmentList(false, false, true, currentSearch)
  end
end

function onAddMax(index)
  local index = index and index or WheelOfDestiny.clickIndex
  if index == 0 then
    return
  end

  local bonus = WheelBonus[index - 1]
  local pointInvested = WheelOfDestiny.pointInvested[index]
  if pointInvested >= bonus.maxPoints then
    return
  end

  local totalPoints = WheelOfDestiny.points + (WheelOfDestiny.extraGemPoints + WheelOfDestiny.scrollPoints)
  local pointToInvest = math.max(totalPoints - WheelOfDestiny.usedPoints, 0)

  if pointToInvest == 1 then
    return onAddOne(index)
  end

  local maxPoints = math.max(bonus.maxPoints, 0)
  if not WheelOfDestiny.canAddPoints(index, true) then
    return
  end

  WheelOfDestiny.pointInvested[index] = math.min((pointInvested + pointToInvest), maxPoints)

  wheelOfDestinyWindow.selection.tabContent.dedicationPb:setValue(WheelOfDestiny.pointInvested[index], 0, bonus.maxPoints)
  wheelOfDestinyWindow.selection.tabContent.dedicationPb:setText(WheelOfDestiny.pointInvested[index].." / ".. bonus.maxPoints)

  WheelOfDestiny.configureDedication(index)
  WheelOfDestiny.configureConviction(index)

  WheelOfDestiny.insertPoint(index, WheelOfDestiny.pointInvested[index])
  WheelOfDestiny.insertUnlockedThe(index)

  WheelOfDestiny.passivePoints = table.reserve(4, 0)

  local usedPoints = 0
  for id, _points in pairs(WheelOfDestiny.pointInvested) do
    usedPoints = usedPoints + _points
    local bonus = WheelBonus[id - 1]
    WheelOfDestiny.passivePoints[bonus.domain] = WheelOfDestiny.passivePoints[bonus.domain] + _points
  end

  WheelOfDestiny.usedPoints = usedPoints
  wheelOfDestinyWindow.selection.points:setText(totalPoints - WheelOfDestiny.usedPoints .. " / ".. totalPoints)

  WheelOfDestiny.checkManagerPointsButtons(index)
  WheelOfDestiny.configureDedicationPerk()
  WheelOfDestiny.configureConvictionPerk()
  WheelOfDestiny.configureVessels()
  WheelOfDestiny.configureSummary()
  WheelOfDestiny.configurePassives()

  if WheelOfDestiny.changeState == 0 or WheelOfDestiny.changeState == 2 then
    onWheelOfDestinyApply(false, false)
  end

	WheelOfDestiny.checkApplyButton()
end

function onAddOne(index)
  local index = index and index or WheelOfDestiny.clickIndex
  if index == 0 then
    return
  end

  local bonus = WheelBonus[index - 1]
  local pointInvested = WheelOfDestiny.pointInvested[index]
  if pointInvested >= bonus.maxPoints then
    return
  end

  if not WheelOfDestiny.canAddPoints(index, true) then
    return
  end

  WheelOfDestiny.pointInvested[index] = pointInvested + 1

  wheelOfDestinyWindow.selection.tabContent.dedicationPb:setValue(WheelOfDestiny.pointInvested[index], 0, bonus.maxPoints)
  wheelOfDestinyWindow.selection.tabContent.dedicationPb:setText(WheelOfDestiny.pointInvested[index].." / ".. bonus.maxPoints)

  WheelOfDestiny.configureDedication(index)
  WheelOfDestiny.configureConviction(index)

  WheelOfDestiny.insertPoint(index, WheelOfDestiny.pointInvested[index])
  WheelOfDestiny.insertUnlockedThe(index)

  WheelOfDestiny.passivePoints = table.reserve(4, 0)

  local usedPoints = 0
  for id, _points in pairs(WheelOfDestiny.pointInvested) do
    usedPoints = usedPoints + _points
    local bonus = WheelBonus[id - 1]
    WheelOfDestiny.passivePoints[bonus.domain] = WheelOfDestiny.passivePoints[bonus.domain] + _points
  end

  WheelOfDestiny.usedPoints = usedPoints

  local totalPoints = WheelOfDestiny.points + (WheelOfDestiny.extraGemPoints + WheelOfDestiny.scrollPoints)
  wheelOfDestinyWindow.selection.points:setText(totalPoints - WheelOfDestiny.usedPoints .. " / ".. totalPoints)

  WheelOfDestiny.checkManagerPointsButtons(index)
  WheelOfDestiny.configureDedicationPerk()
  WheelOfDestiny.configureConvictionPerk()
  WheelOfDestiny.configureVessels()
  WheelOfDestiny.configureSummary()
  WheelOfDestiny.configurePassives()

  if WheelOfDestiny.changeState == 0 or WheelOfDestiny.changeState == 2 then
    onWheelOfDestinyApply(false, false)
  end

	WheelOfDestiny.checkApplyButton()
end

function onAddCustom(index, count)
  local index = index and index or WheelOfDestiny.clickIndex
  if index == 0 then
    return
  end

  local bonus = WheelBonus[index - 1]
  local pointInvested = WheelOfDestiny.pointInvested[index]
  if pointInvested >= bonus.maxPoints then
    return
  end

  if not WheelOfDestiny.canAddPoints(index, true) then
    return
  end

  local customCount = math.min(bonus.maxPoints, pointInvested + count)

  WheelOfDestiny.pointInvested[index] = customCount

  wheelOfDestinyWindow.selection.tabContent.dedicationPb:setValue(WheelOfDestiny.pointInvested[index], 0, bonus.maxPoints)
  wheelOfDestinyWindow.selection.tabContent.dedicationPb:setText(WheelOfDestiny.pointInvested[index].." / ".. bonus.maxPoints)

  WheelOfDestiny.configureDedication(index)
  WheelOfDestiny.configureConviction(index)

  WheelOfDestiny.insertPoint(index, WheelOfDestiny.pointInvested[index])
  WheelOfDestiny.insertUnlockedThe(index)

  WheelOfDestiny.passivePoints = table.reserve(4, 0)

  local usedPoints = 0
  for id, _points in pairs(WheelOfDestiny.pointInvested) do
    usedPoints = usedPoints + _points
    local bonus = WheelBonus[id - 1]
    WheelOfDestiny.passivePoints[bonus.domain] = WheelOfDestiny.passivePoints[bonus.domain] + _points
  end

  WheelOfDestiny.usedPoints = usedPoints

  local totalPoints = WheelOfDestiny.points + (WheelOfDestiny.extraGemPoints + WheelOfDestiny.scrollPoints)
  wheelOfDestinyWindow.selection.points:setText(totalPoints - WheelOfDestiny.usedPoints .. " / ".. totalPoints)

  WheelOfDestiny.checkManagerPointsButtons(index)
  WheelOfDestiny.configureDedicationPerk()
  WheelOfDestiny.configureConvictionPerk()
  WheelOfDestiny.configureVessels()
  WheelOfDestiny.configureSummary()
  WheelOfDestiny.configurePassives()

  if WheelOfDestiny.changeState == 0 or WheelOfDestiny.changeState == 2 then
    onWheelOfDestinyApply(false, false)
  end

	WheelOfDestiny.checkApplyButton()
end

function onRmvMax(index)
  local index = index and index or WheelOfDestiny.clickIndex
  if index == 0 then
    return
  end

  if WheelOfDestiny.changeState ~= 1 then
    return false
  end

  local pointInvested = WheelOfDestiny.pointInvested[index]
  if pointInvested == 0 then
    return
  end

  if not WheelOfDestiny.canRemovePoints(index) then
    return
  end

  local bonus = WheelBonus[index - 1]
  WheelOfDestiny.pointInvested[index] = 0

  wheelOfDestinyWindow.selection.tabContent.dedicationPb:setValue(WheelOfDestiny.pointInvested[index], 0, bonus.maxPoints)
  wheelOfDestinyWindow.selection.tabContent.dedicationPb:setText(WheelOfDestiny.pointInvested[index].." / ".. bonus.maxPoints)

  WheelOfDestiny.configureDedication(index)
  WheelOfDestiny.configureConviction(index)

  WheelOfDestiny.removePoint(index, WheelOfDestiny.pointInvested[index])
  WheelOfDestiny.removeUnlockedThe(index)

  WheelOfDestiny.passivePoints = table.reserve(4, 0)

  local usedPoints = 0
  for id, _points in pairs(WheelOfDestiny.pointInvested) do
    usedPoints = usedPoints + _points
    local bonus = WheelBonus[id - 1]
    WheelOfDestiny.passivePoints[bonus.domain] = WheelOfDestiny.passivePoints[bonus.domain] + _points
  end

  WheelOfDestiny.usedPoints = usedPoints

  local totalPoints = WheelOfDestiny.points + (WheelOfDestiny.extraGemPoints + WheelOfDestiny.scrollPoints)
  wheelOfDestinyWindow.selection.points:setText(totalPoints - WheelOfDestiny.usedPoints .. " / ".. totalPoints)

  WheelOfDestiny.checkManagerPointsButtons(index)
  WheelOfDestiny.configureDedicationPerk()
  WheelOfDestiny.configureConvictionPerk()
  WheelOfDestiny.configureVessels()
  WheelOfDestiny.configureSummary()
  WheelOfDestiny.configurePassives()

	WheelOfDestiny.checkApplyButton()
end

function onRmvOne(index)
  local index = index and index or WheelOfDestiny.clickIndex
  if index == 0 then
    return
  end

  if not WheelOfDestiny.canRemovePoints(index) then
    return
  end

  if WheelOfDestiny.changeState ~= 1 then
    return false
  end

  local pointInvested = WheelOfDestiny.pointInvested[index]
  if pointInvested == 0 then
    return
  end

  local bonus = WheelBonus[index - 1]
  WheelOfDestiny.pointInvested[index] = pointInvested - 1

  wheelOfDestinyWindow.selection.tabContent.dedicationPb:setValue(WheelOfDestiny.pointInvested[index], 0, bonus.maxPoints)
  wheelOfDestinyWindow.selection.tabContent.dedicationPb:setText(WheelOfDestiny.pointInvested[index].." / ".. bonus.maxPoints)

  WheelOfDestiny.configureDedication(index)
  WheelOfDestiny.configureConviction(index)

  WheelOfDestiny.removePoint(index, WheelOfDestiny.pointInvested[index])
  WheelOfDestiny.removeUnlockedThe(index)

  WheelOfDestiny.passivePoints = table.reserve(4, 0)

  local usedPoints = 0
  for id, _points in pairs(WheelOfDestiny.pointInvested) do
    usedPoints = usedPoints + _points
    local bonus = WheelBonus[id - 1]
    WheelOfDestiny.passivePoints[bonus.domain] = WheelOfDestiny.passivePoints[bonus.domain] + _points
  end

  WheelOfDestiny.usedPoints = usedPoints

  local totalPoints = WheelOfDestiny.points + (WheelOfDestiny.extraGemPoints + WheelOfDestiny.scrollPoints)
  wheelOfDestinyWindow.selection.points:setText(totalPoints - WheelOfDestiny.usedPoints .. " / ".. totalPoints)

  WheelOfDestiny.checkManagerPointsButtons(index)
  WheelOfDestiny.configureDedicationPerk()
  WheelOfDestiny.configureConvictionPerk()
  WheelOfDestiny.configureVessels()
  WheelOfDestiny.configureSummary()
  WheelOfDestiny.configurePassives()

	WheelOfDestiny.checkApplyButton()
end

function resetWheel(ignoreprotocol)
  WheelOfDestiny.passivePoints = table.reserve(4, 0)

  for index, connection in ipairs(WheelNodes) do
    if WheelOfDestiny.vocationId ~= 0 then
      local widget = wheelPanel:recursiveGetChildById("icon"..index)
      local modIcon = widget:recursiveGetChildById("modIcon"..index)
      local iconInfo = WheelIcons[WheelOfDestiny.vocationId][index]
      widget:setImageSource("/images/game/wheel/icons-skillwheel-mediumperks")
      widget:setImageClip(iconInfo.iconRect)
      widget:setSize(tosize("30 30"))
      if modIcon then
        modIcon:setVisible(false)
      end
    end

    if WheelButtons[index].radius == SMALL_CIRCLE then
      wheelPanel:recursiveGetChildById('fullColorWheel_'..index):setVisible(true)
      wheelPanel:recursiveGetChildById('colorWheel_'..index):setVisible(false)
      goto continue
    end

    wheelPanel:recursiveGetChildById('fullColorWheel_'..index):setVisible(false)
    wheelPanel:recursiveGetChildById('colorWheel_'..index):setVisible(false)

    ::continue::

    WheelOfDestiny.pointInvested[index] = 0
  end

  for i = 0, 3 do
    WheelOfDestiny.vesselEnabled[i] = {}
  end

  WheelOfDestiny.equipedGemBonuses = {}
  WheelOfDestiny.equipedGems = {-1, -1, -1, -1}

  WheelOfDestiny.configureDedicationPerk()
  WheelOfDestiny.configureConvictionPerk()
  WheelOfDestiny.configureVessels()
  WheelOfDestiny.configureSummary()
  onWheelOfDestinyApply(false, ignoreprotocol)
end

function WheelOfDestiny.configureDedication(index)
  wheelOfDestinyWindow.selection.tabContent.dedication:setWidth("185")
  wheelOfDestinyWindow.selection.tabContent.dedication:setHeight("29")
  wheelOfDestinyWindow.selection.tabContent.dedication:setText(getDedicationBonus(index))
  wheelOfDestinyWindow.selection.tabContent.information:setTooltip(getDedicationTooltip(index))
  if WheelOfDestiny.pointInvested[index] > 0 then
    wheelOfDestinyWindow.selection.tabContent.dedication:setColor("#c0c0c0")
  else
    wheelOfDestinyWindow.selection.tabContent.dedication:setColor("#707070")
  end
end

function WheelOfDestiny.configureConviction(index)
  local bonus = WheelBonus[index - 1]
  local conviction = getConvictionBonus(index)

  local tooltip = getConvictionBonusTooltip(index)
  if type(conviction) == "string" then
    wheelOfDestinyWindow.selection.tabContent.conviction:setTooltip(tooltip)
    wheelOfDestinyWindow.selection.tabContent.conviction:setText(conviction)

    if WheelOfDestiny.pointInvested[index] >= bonus.maxPoints then
      wheelOfDestinyWindow.selection.tabContent.conviction:setColor("#c0c0c0")
    else
      wheelOfDestinyWindow.selection.tabContent.conviction:setColor("#707070")
    end
  elseif type(conviction) == "table" then
    wheelOfDestinyWindow.selection.tabContent.conviction:setTooltip(tooltip)
    wheelOfDestinyWindow.selection.tabContent.conviction:setColoredText(conviction)
  end

end

function WheelOfDestiny.configureDedicationPerk()
  local health = 0
  local mana = 0
  local cap = 0
  local mitigation = 0

  local vocation = WheelOfDestiny.vocationId

  for id, bonus in pairs(WheelBonus) do
    local index = id + 1
    if not WheelOfDestiny.isLit(index) then
      goto label
    end
    local points = WheelOfDestiny.pointInvested[index]
    local attribute = WheelConsts[bonus.dedication]

    if bonus.dedication ==  "capacity" then
      cap = cap + (points * attribute[vocation])
    elseif bonus.dedication ==  "mana" then
      mana = mana + (points * attribute[vocation])
    elseif bonus.dedication ==  "health" then
      health = health +  (points * attribute[vocation])
    elseif bonus.dedication ==  "mitigation" then
      mitigation = mitigation +  (points * attribute)
    elseif bonus.dedication ==  "lifemana" then
      health = health +  (points * attribute["life"][vocation])
      mana = mana +  (points * attribute["mana"][vocation])
    end

    ::label::
  end

  wheelOfDestinyWindow.dedicationPerks.tabContent.hitPoints.value:setText((health > 0 and "+" or "") .. health)
  wheelOfDestinyWindow.dedicationPerks.tabContent.manaPoints.value:setText((mana > 0 and "+" or "") .. mana)
  wheelOfDestinyWindow.dedicationPerks.tabContent.capPoints.value:setText((cap > 0 and "+" or "") .. cap)
  wheelOfDestinyWindow.dedicationPerks.tabContent.mitigationPoints.value:setText(string.format("%.2f%%", mitigation))
end

function WheelOfDestiny.configureConvictionPerk()
  wheelOfDestinyWindow.convictionPerks.tabContent:destroyChildren()
  wheelOfDestinyWindow.convictionPerks.tabContentScroll:setVisible(false)

  local convictions = getConvictionPerks()

  if #convictions > 8 then
    wheelOfDestinyWindow.convictionPerks.tabContentScroll:setVisible(true)
  end

  for _, i in pairs(convictions) do
    local widget = g_ui.createWidget("PerksPanel", wheelOfDestinyWindow.convictionPerks.tabContent)
    widget.perk:setText(i.perk)
    if i.stringPoint then
      widget.value:setText(i.stringPoint)
    else
      widget.value:setVisible(false)
    end
    if i.tooltip then
      widget.info:setTooltip(i.tooltip)
    else
      widget.info:setVisible(false)
    end
  end
end

function WheelOfDestiny.configureVessels()
  local container = wheelOfDestinyWindow.vessels.tabContent
  local scrollBar = wheelOfDestinyWindow.vessels.tabContentScroll

  container:destroyChildren()
  scrollBar:setVisible(false)

  local bonus = getVesselBonus()
  for i, data in ipairs(bonus) do
    local widget = g_ui.createWidget("PerksPanel", container)
    widget:setHeight(20)

    if not data.text or data.text == "" then
      data.text = "(Unknown)"
    end

    widget.perk:setText(data.text)

    if data.value == -1 then
      widget.value:setVisible(false)
    else
      local value = tostring(data.value)
      if not value:match("[+-I]") then
        if data.value and tonumber(data.value) < 15 then
          widget.value:setText("+" .. value .. "%")
        else
          widget.value:setText("+" .. value)
        end
      elseif data.text:find("RM") then
        widget.value:setText("+" .. value)
      else
        if data.bonusType == "augment" or data.bonusType == "mitigation" then
          widget.value:setText("+" .. value .. "%")
        else
          widget.value:setText(data.value)
        end
      end
    end

    if data.tooltip then
      widget.info:setVisible(true)
      widget.info:setTooltip(data.tooltip)
    end
  end

  if scrollBar:getMaximum() > 0 then
    scrollBar:setVisible(true)
  end
end


function WheelOfDestiny.configureSummary()
  if not wheelOfDestinyWindow.summary.tabContent:isVisible() then
    return
  end

  wheelOfDestinyWindow.summary.tabContent:destroyChildren()

  local health = 0
  local mana = 0
  local cap = 0
  local mitigation = 0

  local vocation = WheelOfDestiny.vocationId

  for id, bonus in pairs(WheelBonus) do
    local index = id + 1
    if not WheelOfDestiny.isLit(index) then
      goto label
    end
    local points = WheelOfDestiny.pointInvested[index]
    local attribute = WheelConsts[bonus.dedication]

    if bonus.dedication ==  "capacity" then
      cap = cap + (points * attribute[vocation])
    elseif bonus.dedication ==  "mana" then
      mana = mana + (points * attribute[vocation])
    elseif bonus.dedication ==  "health" then
      health = health +  (points * attribute[vocation])
    elseif bonus.dedication ==  "mitigation" then
      mitigation = mitigation +  (points * attribute)
    elseif bonus.dedication ==  "lifemana" then
      health = health +  (points * attribute["life"][vocation])
      mana = mana +  (points * attribute["mana"][vocation])
    end

    ::label::
  end

  -- normal gem bonusses
  for i, k in pairs(WheelOfDestiny.equipedGemBonuses) do
		if k.bonusID == -1 then
			goto continue
		end

		local bonus = k.supreme and SupremeGemDescription[k.bonusID] or RegularGemDescription[k.bonusID]
    if not k.supreme then
      if bonus.type1 == "life" or bonus.type2 == "life" then
        local type1 = getValueByVocation(bonus.type1, bonus.step)
        local type2 = getValueByVocation(bonus.type2, bonus.step)
        health = health + (type1 + type2)
      end

      if bonus.type1 == "capacity" or bonus.type2 == "capacity" then
        local type1 = getValueByVocation(bonus.type1, bonus.step)
        local type2 = getValueByVocation(bonus.type2, bonus.step)
        cap = cap + (type1 + type2)
      end

      if bonus.type1 == "mana" or bonus.type2 == "mana" then
        local type1 = getValueByVocation(bonus.type1, bonus.step)
        local type2 = getValueByVocation(bonus.type2, bonus.step)
        mana = mana + (type1 + type2)
      end

      if bonus.type1 == "mitigation" or bonus.type2 == "mitigation" then
        local type1 = getValueByVocation(bonus.type1, bonus.step)
        local type2 = getValueByVocation(bonus.type2, bonus.step)
        mitigation = mitigation + (type1 + type2)
      end
    end
    :: continue ::
  end

  -- damage and healing
  local damage = 0

  -- wheel damage
  for _, points in ipairs(WheelOfDestiny.passivePoints) do
    if points >= 1000 then
      damage = damage + 20
    elseif points >= 500 then
      damage = damage + 9
    elseif points >= 250 then
      damage = damage + 4
    end
  end

  damage = damage + GemAtelier:getDamageAndHealing()

  if damage > 0 then
    local widget = g_ui.createWidget("PerksPanel", wheelOfDestinyWindow.summary.tabContent)
    widget.perk:setText("Damage and Healing")
    widget.value:setText("+" .. damage)
    widget.info:setVisible(false)
    g_ui.createWidget("HorizontalSeparator", wheelOfDestinyWindow.summary.tabContent)
  end
  -- separator

  local f_table = {
    [1] = "Hit Points",
    [2] = "Mana",
    [3] = "Capacity",
    [4] = "Mitigation Mult.",
    [5] = "Life Leech",
    [6] = "Mana Leech",
  }

  local convictions = getConvictionPerks()
  for _, t in ipairs(f_table) do
    local widget = g_ui.createWidget("PerksPanel", wheelOfDestinyWindow.summary.tabContent)
    widget.perk:setText(t)
    widget.info:setVisible(false)
    if t == "Hit Points" then
      widget.value:setText((health > 0 and "+" or "") .. health)
    elseif t == "Mana" then
      widget.value:setText((mana > 0 and "+" or "") .. mana)
    elseif t == "Capacity" then
      widget.value:setText((cap > 0 and "+" or "") .. cap)
    elseif t == "Mitigation Mult." then
      widget.value:setText(string.format("%.2f%%", mitigation))
      widget.info:setTooltip('Increase your mitigation multiplicatively.')
      widget.info:setVisible(true)
    elseif t == "Life Leech" then
      local lifeleech = convictions[4]
      if not lifeleech or lifeleech.points == 0 then
        widget:destroy()
        goto label
      end

      widget.value:setText(lifeleech.stringPoint)
      widget.info:setVisible(false)
    elseif t == "Mana Leech" then
      local manaleech = convictions[5]
      if not manaleech or manaleech.points == 0 then
        widget:destroy()
        goto label
      end

      widget.value:setText(manaleech.stringPoint)
      widget.info:setVisible(false)
    else
      widget:destroy()
    end
    ::label::
  end

  -- separator
  g_ui.createWidget("HorizontalSeparator", wheelOfDestinyWindow.summary.tabContent)

  -- special and skill
  local f_table = {
    [1] = "special_1",
    [2] = "special_2",
    [3] = "skill",
  }

  local hasCreated = false
  for _, t in pairs(f_table) do
    local widget = g_ui.createWidget("PerksPanel", wheelOfDestinyWindow.summary.tabContent)
    if t == "special_1" then
      local c = convictions[1]
      if not c then
        widget:destroy()
        goto label
      end

      widget.perk:setText(c.perk)
      widget.value:setVisible(false)
      widget.info:setVisible(true)
      widget.info:setTooltip(c.tooltip)
      hasCreated = true
    elseif t == "special_2" then
      local c = convictions[2]
      if not c then
        widget:destroy()
        goto label
      end

      widget.perk:setText(c.perk)
      widget.value:setVisible(false)
      widget.info:setVisible(true)
      widget.info:setTooltip(c.tooltip)
      hasCreated = true
    elseif t == "skill" then
      local c = convictions[3]
      if not c then
        widget:destroy()
        goto label
      end

      widget.perk:setText(c.perk)
      widget.value:setText(c.stringPoint)
      widget.info:setVisible(true)
      widget.info:setTooltip(c.tooltip)
      hasCreated = true
    end
    ::label::
  end

  if hasCreated then
    g_ui.createWidget("HorizontalSeparator", wheelOfDestinyWindow.summary.tabContent)
  end

  local f_table = {
    [6] = "spell_1",
    [7] = "spell_2",
    [8] = "spell_3",
    [9] = "spell_4",
    [10] = "spell_5",
  }

  --- Convictions
  local hasCreated = false
  for _, t in pairs(f_table) do
    local widget = g_ui.createWidget("PerksPanel", wheelOfDestinyWindow.summary.tabContent)
    local c = convictions[_]
    if not c then
      widget:destroy()
      goto label
    end

    widget.perk:setText(c.perk)
    widget.value:setText(c.stringPoint)
    widget.info:setTooltip(c.tooltip)
    widget.info:setVisible(true)
    hasCreated = true
    ::label::
  end

  local bonus = getVesselBonus()
  for _, data in pairs(bonus) do
    if data.bonusType ~= "augment" then
      goto continue
    end

    local widget = g_ui.createWidget("PerksPanel", wheelOfDestinyWindow.summary.tabContent)
    widget.perk:setText(data.text)
    if data.value == -1 then
      widget.value:setVisible(false)
    end

    if data.tooltip then
      widget.info:setVisible(true)
      widget.info:setTooltip(data.tooltip)
    end

    local value = tostring(data.value)
    if not value:match("[+-I]") then
      if tonumber(data.value) < 15 then
        widget.value:setText("+" .. value .. "%")
      else
        widget.value:setText("+" .. value)
      end
    else
      widget.value:setText(data.value)
    end

    hasCreated = true
    :: continue ::
  end

  if hasCreated then
    g_ui.createWidget("HorizontalSeparator", wheelOfDestinyWindow.summary.tabContent)
  end


  local avatarName = "Avatar Of Nature"
  local spell1, tooltip1 = "Blessing of the Gr...", "Blessing of the Grave"
  local spell2, tooltip2 = "Blessing of the Gr...", "Blessing of the Grave"
  local vocation = WheelOfDestiny.vocationId
  if vocation == KNIGHT then
    avatarName = "Avatar of Steel"
    spell1 = "Executioner's T..."
    tooltip1 = "Executioner's Throw"
    spell2 = "Combat Mastery"
    tooltip2 = "Combat Mastery"
  elseif vocation == PALADIN then
    avatarName = "Avatar of Light"
    spell1 = "Divine Grenade"
    tooltip1 = "Divine Grenade"
    spell2 = "Divine Empowerment"
    tooltip2 = "Divine Empowerment"
  elseif vocation == SORCERER then
    avatarName = "Avatar of Storm"
    spell1 = "Beam Mastery"
    tooltip1 = "Beam Mastery"
    spell2 = "Drain Body"
    tooltip2 = "Drain Body"
  elseif vocation == DRUID then
    avatarName = "Avatar of Nature"
    spell1 = "Blessing of the Gr..."
    tooltip1 = "Blessing of the Grave"
    spell2 = "Twin Bursts"
    tooltip2 = "Twin Bursts"
  elseif vocation == MONK then
    avatarName = "Avatar of Balance"
    spell1 = "Spiritual Outburst"
    tooltip1 = "Spiritual Outburst"
    spell2 = "Ascetic"
    tooltip2 = "Ascetic"
  end

  local m1, m2 = getPassiveInfo(4)
  local passive = WheelOfDestiny.passivePoints[4]

  local widget = g_ui.createWidget("PerksPanel", wheelOfDestinyWindow.summary.tabContent)
  widget.perk:setText(avatarName)
  if passive >= 1000 then
    widget.value:setText("Stage 3")
  elseif passive >= 500 then
    widget.value:setText("Stage 2")
  elseif passive >= 250 then
    widget.value:setText("Stage 1")
  else
    widget.value:setText("Locked")
  end
  widget.info:setTooltip(m2)

  local m1, m2 = getPassiveInfo(2)
  local passive = WheelOfDestiny.passivePoints[2]

  local widget = g_ui.createWidget("PerksPanel", wheelOfDestinyWindow.summary.tabContent)
  widget.perk:setText(spell1)
  widget.perk:setTooltip(tooltip1)
  if passive >= 1000 then
    widget.value:setText("Stage 3")
  elseif passive >= 500 then
    widget.value:setText("Stage 2")
  elseif passive >= 250 then
    widget.value:setText("Stage 1")
  else
    widget.value:setText("Locked")
  end
  widget.info:setTooltip(m2)
  ------------------
  local m1, m2 = getPassiveInfo(1)
  local passive = WheelOfDestiny.passivePoints[1]

  local widget = g_ui.createWidget("PerksPanel", wheelOfDestinyWindow.summary.tabContent)
  widget.perk:setText("Gift of Life")
  if passive >= 1000 then
    widget.value:setText("Stage 3")
  elseif passive >= 500 then
    widget.value:setText("Stage 2")
  elseif passive >= 250 then
    widget.value:setText("Stage 1")
  else
    widget.value:setText("Locked")
  end
  widget.info:setTooltip(m2)
  ------------------
  local m1, m2 = getPassiveInfo(3)
  local passive = WheelOfDestiny.passivePoints[3]

  local widget = g_ui.createWidget("PerksPanel", wheelOfDestinyWindow.summary.tabContent)
  widget.perk:setText(spell2)
  widget.perk:setTooltip(tooltip2)
  if passive >= 1000 then
    widget.value:setText("Stage 3")
  elseif passive >= 500 then
    widget.value:setText("Stage 2")
  elseif passive >= 250 then
    widget.value:setText("Stage 1")
  else
    widget.value:setText("Locked")
  end
  widget.info:setTooltip(m2)

  local bonus = getVesselBonus()
  for _, data in pairs(bonus) do
    if data.bonusType ~= "revelation" then
      goto continue
    end

    local widget = g_ui.createWidget("PerksPanel", wheelOfDestinyWindow.summary.tabContent)
    widget.perk:setText(data.text)
    if data.value == -1 then
      widget.value:setVisible(false)
    end

    if data.tooltip then
      widget.info:setVisible(true)
      widget.info:setTooltip(data.tooltip)
    end

    local value = tostring(data.value)
    if not value:match("[+-I]") then
      if tonumber(data.value) < 15 then
        widget.value:setText("+" .. value .. "%")
      else
        widget.value:setText("+" .. value)
      end
    else
      widget.value:setText(data.value)
    end
    :: continue ::
  end

  ----------------------------
  g_ui.createWidget("HorizontalSeparator", wheelOfDestinyWindow.summary.tabContent)

  -- defenses
  local hasDefense = false
  local bonus = getVesselBonus()
  for _, data in pairs(bonus) do
    if data.bonusType ~= "defense" then
      goto continue
    end

    local widget = g_ui.createWidget("PerksPanel", wheelOfDestinyWindow.summary.tabContent)
    widget.perk:setText(data.text)
    if data.value == -1 then
      widget.value:setVisible(false)
    end

    if data.tooltip then
      widget.info:setVisible(true)
      widget.info:setTooltip(data.tooltip)
    end

    local value = tostring(data.value)
    if not value:match("[+-I]") then
      if tonumber(data.value) < 15 then
        widget.value:setText("+" .. value .. "%")
      else
        widget.value:setText("+" .. value)
      end
    else
      widget.value:setText(data.value)
    end

    hasDefense = true
    :: continue ::
  end

  if hasDefense then
    g_ui.createWidget("HorizontalSeparator", wheelOfDestinyWindow.summary.tabContent)
  end
  -----------------------------------------------------------------------------------

  local f_table = {
    [11] = "vessel.1",
    [12] = "vessel.2",
    [13] = "vessel.3",
    [14] = "vessel.4",
  }

  local hasCreated = false
  for _, t in pairs(f_table) do
    local widget = g_ui.createWidget("PerksPanel", wheelOfDestinyWindow.summary.tabContent)
    local c = convictions[_]
    if not c then
      widget:destroy()
      goto label
    end
    widget.perk:setText(c.perk)
    widget.value:setText(c.stringPoint)
    widget.info:setTooltip(c.tooltip)
    widget.info:setVisible(true)
    hasCreated = true
    ::label::
  end

  if hasCreated then
    g_ui.createWidget("HorizontalSeparator", wheelOfDestinyWindow.summary.tabContent)
  end

end

function WheelOfDestiny.create(playerId, canView, changeState, vocationId, points, scrollPoints, pointInvested, usedPromotionScrolls, equipedGems, atelierGems, basicUpgraded, supremeUpgraded, earnedFromAchievements)
  WheelOfDestiny.playerId = playerId
  WheelOfDestiny.canView = canView
  WheelOfDestiny.changeState = changeState
  WheelOfDestiny.vocationId = vocationId
  WheelOfDestiny.points = points
  WheelOfDestiny.levelPoints = points
  WheelOfDestiny.scrollPoints = scrollPoints
  WheelOfDestiny.usedPromotionScrolls = usedPromotionScrolls
  WheelOfDestiny.equipedGems = normalizeEquipedGems(equipedGems)
  WheelOfDestiny.atelierGems = atelierGems
  
  WheelOfDestiny.basicModsUpgrade = basicUpgraded
  WheelOfDestiny.supremeModsUpgrade = supremeUpgraded
  WheelOfDestiny.extraGemPoints = 0
  WheelOfDestiny.fromAchievementType = earnedFromAchievements

  WheelOfDestiny.passivePoints = table.reserve(4, 0)

  if WheelOfDestiny.vocationId == 0 then
    local player = g_game.getLocalPlayer()
    if player then
      WheelOfDestiny.vocationId = translateWheelVocation[player:getVocation()]
    end
  end

  -- order
  local orderned = {
    15, 9, 14, 3, 8, 13, 2, 7, 1, 16, 10, 17, 4, 11, 18, 5, 12, 6, 22, 23, 28, 24, 29, 34, 30, 35, 36, 21, 20, 27, 19, 26, 33, 25, 32, 31
  }

  -- Extra points by gem upgraded
  for _, tier in pairs(WheelOfDestiny.basicModsUpgrade) do
    if tier == 3 then
      WheelOfDestiny.extraGemPoints = WheelOfDestiny.extraGemPoints + 1
    end
  end

  for _, tier in pairs(WheelOfDestiny.supremeModsUpgrade) do
    if tier == 3 then
      WheelOfDestiny.extraGemPoints = WheelOfDestiny.extraGemPoints + 1
    end
  end

  WheelOfDestiny.setupPointsTooltip()

	local a = 0
	for k, v in pairs(pointInvested) do
		a = a + v
	end

  WheelOfDestiny.usedPoints = 0
  for _, id in pairs(orderned) do
    _points = pointInvested[id]
    local bonus = WheelBonus[id - 1]
    WheelOfDestiny.pointInvested[id] = 0
    for i = 1, _points do
      WheelOfDestiny.usedPoints = WheelOfDestiny.usedPoints + 1
      WheelOfDestiny.passivePoints[bonus.domain] = WheelOfDestiny.passivePoints[bonus.domain] + 1
      WheelOfDestiny.pointInvested[id] = WheelOfDestiny.pointInvested[id] + 1
    end
  end

	local b = 0
	for k, v in pairs(WheelOfDestiny.pointInvested) do
		b = b + v
	end

  -- check integrity
  for id, _points in pairs(WheelOfDestiny.pointInvested) do
    if not WheelOfDestiny.canAddPoints(id, true) and _points > 0 then
      local bonus = WheelBonus[id - 1]
      WheelOfDestiny.usedPoints = WheelOfDestiny.usedPoints - _points
      WheelOfDestiny.passivePoints[bonus.domain] = WheelOfDestiny.passivePoints[bonus.domain] - _points
      _points = 0
    end
  end


  for id, _points in pairs(WheelOfDestiny.pointInvested) do
    WheelOfDestiny.insertPoint(id, _points)
  end

  for id, _points in pairs(WheelOfDestiny.pointInvested) do
    local bonus = WheelBonus[id - 1]
    if bonus.maxPoints <= _points then
      WheelOfDestiny.insertUnlockedThe(id)
    end
  end

  local function incrementBonusCount(bonus, bonusType)
    -- Ignores invalid or null values (0 and -1 mean "no bonus")
    if type(bonus) ~= "number" or bonus <= 0 then

      return
    end
  
    local key = tostring(bonus)
    bonusType[key] = (bonusType[key] or 0) + 1
  end

  WheelOfDestiny.basicModCount = {}
  WheelOfDestiny.supremeModCount = {}
  for _, info in pairs(WheelOfDestiny.atelierGems) do
    local function dumpCounts(title, t)

    end
    dumpCounts("basicModCount", WheelOfDestiny.basicModCount)
    dumpCounts("supremeModCount", WheelOfDestiny.supremeModCount)

    incrementBonusCount(info.lesserBonus, WheelOfDestiny.basicModCount)
    incrementBonusCount(info.regularBonus, WheelOfDestiny.basicModCount)
    incrementBonusCount(info.supremeBonus, WheelOfDestiny.supremeModCount)
  end

  local totalPoints = WheelOfDestiny.points + (WheelOfDestiny.extraGemPoints + WheelOfDestiny.scrollPoints)
  wheelOfDestinyWindow.selection.points:setText("[7]" ..  totalPoints - WheelOfDestiny.usedPoints .. " / ".. totalPoints)

  wheelPanel:recursiveGetChildById("perkIconTopLeft").onClick = function() WheelOfDestiny.onWheelPassiveClick(1) end
  wheelPanel:recursiveGetChildById("perkIconTopRight").onClick = function() WheelOfDestiny.onWheelPassiveClick(2) end
  wheelPanel:recursiveGetChildById("perkIconBottomLeft").onClick = function() WheelOfDestiny.onWheelPassiveClick(3) end
  wheelPanel:recursiveGetChildById("perkIconBottomRight").onClick = function() WheelOfDestiny.onWheelPassiveClick(4) end

	WheelOfDestiny.onCreate(vocationId)
end

function WheelOfDestiny.resetPassiveFocus()
  for i = 1, 4 do
    local widget = wheelPanel:recursiveGetChildById("selectPassive"..i)
    if widget then
      widget:setVisible(false)
    end
  end
end

local function getGemStruct(preset)
	local struct = {
		[GemDomains.GREEN] = {gemID = -1},
		[GemDomains.RED] = {gemID = -1},
		[GemDomains.ACQUA] = {gemID = -1},
		[GemDomains.PURPLE] = {gemID = -1},
	}

  local source = preset ~= nil and preset.equipedGems or WheelOfDestiny.equipedGems
	for _, id in pairs(source) do
		local domain = GemAtelier.getGemDomainById(id)
		if domain ~= -1 then
			struct[domain].hasGem = true
			struct[domain].gemID = id
		end
	end

	return struct
end

local function getLocalGemStruct()
  local struct = {-1, -1, -1, -1}

  for _, id in pairs(WheelOfDestiny.equipedGems) do
    local domain = GemAtelier.getGemDomainById(id)
    if domain == -1 then
      goto continue
    end

    struct[domain + 1] = id
    ::continue::
  end

  return struct
end

function onWheelOfDestinyApply(close, ignoreprotocol)
  local struct = getGemStruct()


  if not ignoreprotocol then
    local g = struct[GemDomains.GREEN].gemID or 0
    local r = struct[GemDomains.RED].gemID or 0
    local a = struct[GemDomains.ACQUA].gemID or 0
    local p = struct[GemDomains.PURPLE].gemID or 0
  
    if WheelOfDestiny.currentPreset then
      WheelOfDestiny.currentPreset.equipedGems = normalizeEquipedGems(struct)
    end
  
    g_logger.debug(string.format(
      "[WheelApply] Sending gems -> GREEN:%d  RED:%d  ACQUA:%d  PURPLE:%d",
      g, r, a, p))
  
    g_game.sendApplyWheelPoints(WheelOfDestiny.pointInvested, g, r, a, p)
  end

  -- Update and save current preset (only if local player is available)
  local player = g_game.getLocalPlayer()
  if player then
    WheelOfDestiny.updateCurrentPreset()
    WheelOfDestiny.saveWheelPresets()
  end

  if close then
    scheduleEvent(function()
      wheelWindow:hide()
      wheelWindow:ungrabMouse()
      wheelWindow:ungrabKeyboard()
    end, 100)
  end
end


function WheelOfDestiny.configurePassives()
  WheelOfDestiny.extraPassivePoints = table.reserve(4, 0)

  for i = 0, 3 do
    local data = GemAtelier.getEquipedGem(i)
    local filledCount = GemAtelier.getFilledVesselCount(i)
    if data and data.supremeBonus > 0 and filledCount == 3 then
      local vocationId = translateVocation(WheelOfDestiny.vocationId)
      local supremeList = data.supremeBonus > 5 and VocationSupremeMods[vocationId] or FlatSupremeMods
      if supremeList then
        local bonus = supremeList[data.supremeBonus]
        if bonus and bonus.domain then
          local gemValue = getBonusValueUpgrade(data.supremeBonus, data.gemID, true, true)
          local currentValue = WheelOfDestiny.extraPassivePoints[bonus.domain + 1] or 0
          WheelOfDestiny.extraPassivePoints[bonus.domain + 1] = gemValue + currentValue
        end
      end
    end
  end

  local passivel = "TL"
  for domain, points in ipairs(WheelOfDestiny.passivePoints) do
    if domain == 1 then
      passivel = "TL"
    elseif domain == 2 then
      passivel = "TR"
    elseif domain == 3 then
      passivel = "BL"
    elseif domain == 4 then
      passivel = "BR"
    end

    local extraPoints = WheelOfDestiny.extraPassivePoints[domain] or 0
    points = points + extraPoints

    local widget = wheelPanel:recursiveGetChildById("wheelPassive"..domain)
    local widgetPercent = wheelPanel:recursiveGetChildById("revelationPerk"..passivel)
    if points < 250 then
      widget:setImageSource("/images/game/wheel/backdrop_skillwheel_largebonus_front0_"..passivel)
      widgetPercent:setPercent(math.floor(((points - 0) / (250 - 0)) * 100))
    elseif points < 500 then
      widget:setImageSource("/images/game/wheel/backdrop_skillwheel_largebonus_front1_"..passivel)
      widgetPercent:setPercent(math.floor(((points - 250) / (500 - 250)) * 100))
    elseif points < 1000 then
      widget:setImageSource("/images/game/wheel/backdrop_skillwheel_largebonus_front2_"..passivel)
      widgetPercent:setPercent(math.floor(((points - 500) / (1000 - 500)) * 100))
    else
      widget:setImageSource("/images/game/wheel/backdrop_skillwheel_largebonus_front3_"..passivel)
      widgetPercent:setPercent(100)
    end
  end

  WheelOfDestiny.configureRevelationPerks()
end

function WheelOfDestiny.onWheelPassiveClick(domain)
  if not wheelWindow:recursiveGetChildById('tabContent'):isVisible() then
    wheelWindow:recursiveGetChildById('tabContent'):setVisible(true)
  end

  WheelOfDestiny.resetPassiveFocus()
  wheelPanel:recursiveGetChildById("selectPassive"..domain):setVisible(true)

  if WheelOfDestiny.lastSelectedGemVessel then
    WheelOfDestiny.lastSelectedGemVessel:setVisible(false)
  end

  if wheelOfDestinyWindow.selection.gemContent:isVisible() then
    wheelOfDestinyWindow.selection.gemContent:setVisible(false)
    wheelOfDestinyWindow.selection.tabContent:setVisible(true)
  end

  wheelOfDestinyWindow.selection.tabContent.dedicationTitle:setText("Revelation Perk")
  wheelOfDestinyWindow.selection.tabContent.convictionTitle:setText("More details: ")
  wheelOfDestinyWindow.selection.tabContent.convictionTitle:setTextAlign(AlignLeft)
  wheelOfDestinyWindow.selection.tabContent.information:setTooltip("To unlock a Revelation Perk, you need to distribute promotion \npoints in the corresponding domain.\nTo unlock stage 1 of a Revelation Perk, you need 250 promotion \npoints. Stage 2 requires 500 promotion points. As soon as you have \ndistributed 1000 promotion points, stage 3 is unlocked.\nRevelation Mastery, which can be found on some gems, provides \nadditional points to unlock Revelation Perks.\n\nUnlocked Revelation Perks grant a bonus to all damage and \nhealing:\n* Stage 1 grants a bonus of +4 damage and healing\n* Stage 2 increases this bonus to +9\n* Stage 3 increases this bonus to +20")

  local passive = WheelOfDestiny.passivePoints[domain]
  local maximum = 250
  
  local extraPoints = WheelOfDestiny.extraPassivePoints[domain] or 0
  passive = passive + extraPoints

  if passive >= 1000 then
    maximum = 1000
  elseif passive >= 500 then
    maximum = 1000
  elseif passive >= 250 then
    maximum = 500
  end

  if passive < 0 then
    passive = 0
  end

  wheelOfDestinyWindow.selection.tabContent.dedicationPb:setValue(passive, 0, maximum)
  wheelOfDestinyWindow.selection.tabContent.dedicationPb:setText(passive.." / ".. maximum)
  wheelPanel.borderSelectedWheel:setVisible(false)

  wheelOfDestinyWindow:recursiveGetChildById('addMax'):setVisible(false)
  wheelOfDestinyWindow:recursiveGetChildById('addOne'):setVisible(false)
  wheelOfDestinyWindow:recursiveGetChildById('rmvMax'):setVisible(false)
  wheelOfDestinyWindow:recursiveGetChildById('rmvOne'):setVisible(false)

  local m1, m2 = getPassiveInfo(domain)

  local panelHeight = WheelDedicationHeight[WheelOfDestiny.vocationId] or {}
  local height = panelHeight[domain] or 0

  wheelOfDestinyWindow.selection.tabContent.dedication:setHeight(height)
  wheelOfDestinyWindow.selection.tabContent.dedication:setText(m1)
  wheelOfDestinyWindow.selection.tabContent.information1:setTooltip(m2)

  if passive == 1000 then
    wheelOfDestinyWindow.selection.tabContent.dedication:setColor("#c0c0c0")
  else
    wheelOfDestinyWindow.selection.tabContent.dedication:setColor("#707070")
  end

  wheelOfDestinyWindow.selection.tabContent.conviction:setText("Locked")
  wheelOfDestinyWindow.selection.tabContent.conviction:setColor("#c0c0c0")

  if passive >= 1000 then
    wheelOfDestinyWindow.selection.tabContent.conviction:setText("Stage 3")
  elseif passive >= 500 then
    wheelOfDestinyWindow.selection.tabContent.conviction:setText("Stage 2")
  elseif passive >= 250 then
    wheelOfDestinyWindow.selection.tabContent.conviction:setText("Stage 1")
  end
end

function WheelOfDestiny.configureRevelationPerks()
  -- damage and healing
  local damage = 0
  for domain, points in ipairs(WheelOfDestiny.passivePoints) do
    local extraPoints = WheelOfDestiny.extraPassivePoints[domain] or 0
    points = points + extraPoints

    if points >= 1000 then
      damage = damage + 20
    elseif points >= 500 then
      damage = damage + 9
    elseif points >= 250 then
      damage = damage + 4
    end
  end

  if damage > 0 then
    wheelOfDestinyWindow.revelationPerks.tabContent.damage.value:setText("+"..damage)
  end

  local m1, m2 = getPassiveInfo(1)
  local passive = WheelOfDestiny.passivePoints[1]
  local extraPoints = WheelOfDestiny.extraPassivePoints[1] or 0
  passive = passive + extraPoints

  wheelOfDestinyWindow.revelationPerks.tabContent.spell2.value:setText("Locked")
  if passive >= 1000 then
    wheelOfDestinyWindow.revelationPerks.tabContent.spell2.value:setText("Stage 3")
  elseif passive >= 500 then
    wheelOfDestinyWindow.revelationPerks.tabContent.spell2.value:setText("Stage 2")
  elseif passive >= 250 then
    wheelOfDestinyWindow.revelationPerks.tabContent.spell2.value:setText("Stage 1")
  end

  wheelOfDestinyWindow.revelationPerks.tabContent.infoSpell2:setTooltip(m1)


  local avatarName = "Avatar Of Nature"
  local spell1, tooltip1 = "Blessing of the Gr...", "Blessing of the Grave"
  local spell2, tooltip2 = "Blessing of the Gr...", "Blessing of the Grave"
  local vocation = WheelOfDestiny.vocationId
  if vocation == KNIGHT then
    avatarName = "Avatar of Steel"
    spell1 = "Executioner's Throw"
    tooltip1 = "Executioner's Throw"
    spell2 = "Combat Mastery"
    tooltip2 = "Combat Mastery"
  elseif vocation == PALADIN then
    avatarName = "Avatar of Light"
    spell1 = "Divine Grenade"
    tooltip1 = "Divine Grenade"
    spell2 = "Divine Empowerment"
    tooltip2 = "Divine Empowerment"
  elseif vocation == SORCERER then
    avatarName = "Avatar of Storm"
    spell1 = "Beam Mastery"
    tooltip1 = "Beam Mastery"
    spell2 = "Drain Body"
    tooltip2 = "Drain Body"
  elseif vocation == DRUID then
    avatarName = "Avatar of Nature"
    spell1 = "Blessing of the Gr..."
    tooltip1 = "Blessing of the Grave"
    spell2 = "Twin Bursts"
    tooltip2 = "Twin Bursts"
  elseif vocation == MONK then
    avatarName = "Avatar of Balance"
    spell1 = "Spiritual Outburst"
    tooltip1 = "Spiritual Outburst"
    spell2 = "Ascetic"
    tooltip2 = "Ascetic"
  end

  local m1, m2 = getPassiveInfo(4)
  local passive = WheelOfDestiny.passivePoints[4]
  local extraPoints = WheelOfDestiny.extraPassivePoints[4] or 0
  passive = passive + extraPoints

  wheelOfDestinyWindow.revelationPerks.tabContent.avatar.perk1:setText(avatarName)
  wheelOfDestinyWindow.revelationPerks.tabContent.avatar.value:setText("Locked")
  if passive >= 1000 then
    wheelOfDestinyWindow.revelationPerks.tabContent.avatar.value:setText("Stage 3")
  elseif passive >= 500 then
    wheelOfDestinyWindow.revelationPerks.tabContent.avatar.value:setText("Stage 2")
  elseif passive >= 250 then
    wheelOfDestinyWindow.revelationPerks.tabContent.avatar.value:setText("Stage 1")
  end

  wheelOfDestinyWindow.revelationPerks.tabContent.infoAvatar:setTooltip(m1)

  local m1, m2 = getPassiveInfo(2)
  local passive = WheelOfDestiny.passivePoints[2]
  local extraPoints = WheelOfDestiny.extraPassivePoints[2] or 0
  passive = passive + extraPoints

  wheelOfDestinyWindow.revelationPerks.tabContent.spell1.perk2:setText(spell1)
  wheelOfDestinyWindow.revelationPerks.tabContent.spell1.perk2:setTooltip(tooltip1)
  wheelOfDestinyWindow.revelationPerks.tabContent.spell1.value:setText("Locked")
  if passive >= 1000 then
    wheelOfDestinyWindow.revelationPerks.tabContent.spell1.value:setText("Stage 3")
  elseif passive >= 500 then
    wheelOfDestinyWindow.revelationPerks.tabContent.spell1.value:setText("Stage 2")
  elseif passive >= 250 then
    wheelOfDestinyWindow.revelationPerks.tabContent.spell1.value:setText("Stage 1")
  end

  wheelOfDestinyWindow.revelationPerks.tabContent.infoSpell1:setTooltip(m1)

  local m1, m2 = getPassiveInfo(3)
  local passive = WheelOfDestiny.passivePoints[3]
  local extraPoints = WheelOfDestiny.extraPassivePoints[3] or 0
  passive = passive + extraPoints

  wheelOfDestinyWindow.revelationPerks.tabContent.spell3.perk4:setText(spell2)
  wheelOfDestinyWindow.revelationPerks.tabContent.spell3.perk4:setTooltip(tooltip2)
  wheelOfDestinyWindow.revelationPerks.tabContent.spell3.value:setText("Locked")
  if passive >= 1000 then
    wheelOfDestinyWindow.revelationPerks.tabContent.spell3.value:setText("Stage 3")
  elseif passive >= 500 then
    wheelOfDestinyWindow.revelationPerks.tabContent.spell3.value:setText("Stage 2")
  elseif passive >= 250 then
    wheelOfDestinyWindow.revelationPerks.tabContent.spell3.value:setText("Stage 1")
  end

  wheelOfDestinyWindow.revelationPerks.tabContent.infoSpell3:setTooltip(m1)
end

local function checkValidName(text)
  for _, data in pairs(WheelOfDestiny.internalPreset) do
    if data.presetName == text then
      return false
    end
  end
  return #text > 1
end

function WheelOfDestiny.showNewPreset(createPreset)
  wheelWindow:hide()
  newPresetWindow:show()

  if not createPreset then
    selectedNewPresetRadio:selectWidget(newPresetWindow.contentPanel.import)
  else
    selectedNewPresetRadio:selectWidget(newPresetWindow.contentPanel.useEmpty)
  end

  newPresetWindow.contentPanel.presetName:clearText()
  newPresetWindow.contentPanel.presetCode:clearText()
  newPresetWindow.contentPanel.copyPreset:setText(string.format("Copy preset '%s'", WheelOfDestiny.currentPreset.presetName))
end

function WheelOfDestiny.onImportConfig(base64Data)
  if not base64Data or base64Data == "" then
    return {}
  end

  base64Data = base64Data:gsub("-", "+"):gsub("_", "/")
  local remainder = #base64Data % 4
  if remainder > 0 then
    base64Data = base64Data .. string.rep("=", 4 - remainder)
  end

  -- Avoid invalid base64 code
  if not base64.isValidBase64(base64Data) then
    g_logger.debug(string.format("[WheelOfDestiny.onImportConfig]: Invalid base64 string: %s", base64Data))
    return {}
  end

  local decodedData = base64.decode(base64Data)
  local points = string.unpack_custom("I2", decodedData)

  local pointInvested = {}
  local equipedGems = {}

  local index = 3
	local usedPoints = 0

  local totalPoints = WheelOfDestiny.points

  local importMap = {
    -- TL (Green) - (Top -> Bot)
    15, 14, 9, 13, 8, 3, 7, 2, 1,
    -- TR (Red) - (Right -> Top)
    16, 17, 10, 18, 11, 4, 12, 5, 6,
    -- BR (Purple) - (Right -> Bot)
    22, 23, 28, 24, 29, 34, 30, 35, 36,
    -- BL (Blue) - (Left -> Bot)
    21, 20, 27, 19, 26, 33, 32, 25, 31
  }

  local unsortedPoints = {}
  while index <= #decodedData do
    local value = string.unpack_custom("I1", decodedData:sub(index, index))

    if totalPoints then
      if usedPoints + value > totalPoints then
        value = totalPoints - usedPoints
        if value < 0 then
          value = 0
        end
      end
    end

    table.insert(unsortedPoints, value)
    usedPoints = usedPoints + value 
    index = index + 1

    if index >= 39 then
      break
    end
  end

  for i = 1, 36 do
    pointInvested[i] = 0
  end

  for i, value in ipairs(unsortedPoints) do
    if importMap[i] then
      pointInvested[importMap[i]] = value
    end
  end

  while index <= #decodedData do
    local value = string.unpack_custom("I1", decodedData:sub(index, index))
    -- Convert 255 to -1 (255 means no gem in import format, -1 is used internally)
    -- Note: Gem ID 0 is valid and should not be converted!
    if value == 255 then
      value = -1
    end
    table.insert(equipedGems, value)
    index = index + 1
  end

  while #equipedGems < 4 do
    table.insert(equipedGems, -1)
  end

  if usedPoints > points then
    return {}
  end

  return { maxPoints = points, usedPoints = usedPoints, pointInvested = pointInvested, equipedGems = equipedGems }
end

function WheelOfDestiny.onImportPreset()
  -- Open the New Preset dialog with Import option pre-selected
  WheelOfDestiny.showNewPreset(false)
  -- Focus keyboard on the import code text field
  newPresetWindow.contentPanel.presetCode:focus()
end

function WheelOfDestiny.onExportPreset()
  if exportCodeWindow then
    exportCodeWindow:destroy()
    exportCodeWindow = nil
  end

  wheelWindow:hide()

  local codeButton = function()
    if exportCodeWindow then
      exportCodeWindow:destroy()
      exportCodeWindow = nil
    end

    wheelWindow:show()
    
    -- Generate and copy the export code to clipboard
    local exportCode = WheelOfDestiny.getExportCode(WheelOfDestiny.currentPreset)
    if exportCode and exportCode ~= "" then
      g_window.setClipboardText(exportCode)
      g_logger.debug(string.format("[WheelOfDestiny] Export code copied to clipboard: %s", exportCode))
    else
      g_logger.debug("[WheelOfDestiny] Failed to generate export code")
    end
    
    return true
  end

  local urlButton = function()
    -- TODO: Implement URL export functionality
    g_logger.debug("[WheelOfDestiny] URL export - TODO: Not yet implemented")
    return true
  end

  local cancelButton = function()
    if exportCodeWindow then
      exportCodeWindow:destroy()
      exportCodeWindow = nil
    end

    wheelWindow:show()
    return false
  end

  exportCodeWindow = displayGeneralBox('Copy to Clipboard', tr("Copy export code or URL of the planner to clipboard."),
    {
      { text=tr('Code'), callback=codeButton },
      { text=tr('URL'), callback=urlButton },
      { text=tr('Cancel'), callback=cancelButton }
    })
end

function WheelOfDestiny.onExportConfig()
  local totalPoints = WheelOfDestiny.points + (WheelOfDestiny.extraGemPoints + WheelOfDestiny.scrollPoints)
  local pointInvested = WheelOfDestiny.pointInvested or {}
  local equipedGems = WheelOfDestiny.equipedGems or {}
  local dataParts = {}

  local packedHeader = string.pack_custom("I2", totalPoints)
  if not packedHeader or packedHeader == "" then
      return ""
  end

  table.insert(dataParts, packedHeader)
  for _, value in ipairs(pointInvested) do
      local packedValue = string.pack_custom("I1", value)
      if packedValue and packedValue ~= "" then
          table.insert(dataParts, packedValue)
      end
  end

	-- Pack gems in fixed order: GREEN, RED, ACQUA, PURPLE
	-- Note: Gem ID 0 is valid! Use 255 as marker for no gem (-1)
	local gems = getGemStruct()
	local gemOrder = {GemDomains.GREEN, GemDomains.RED, GemDomains.ACQUA, GemDomains.PURPLE}
	for _, domain in ipairs(gemOrder) do
		local gemData = gems[domain]
		local gemID = gemData and gemData.gemID or -1
		-- Use 255 as "no gem" marker since gem ID 0 is valid
		local packedValue = string.pack_custom("I1", gemID < 0 and 255 or gemID)
		if packedValue and packedValue ~= "" then
			table.insert(dataParts, packedValue)
		end
	end

  local data = table.concat(dataParts)
  if not data or data == "" then
      return ""
  end

  local base64Data = base64.encode(data)
  local formatedString = string.format("%s%s", getVocationSt(WheelOfDestiny.vocationId), base64Data)
  g_window.setClipboardText(formatedString)
end

function WheelOfDestiny.getExportCode(preset)
  if not preset or table.empty(preset) then
    return ""
  end

  local points = preset.availablePoints
  local pointInvested = preset.pointInvested or {}
  local equipedGems = preset.equipedGems or {}
  local dataParts = {}

  local packedHeader = string.pack_custom("I2", points)
  if not packedHeader or packedHeader == "" then
      return ""
  end

  table.insert(dataParts, packedHeader)
  
  -- Export map: converts internal position to export position
  -- This is the INVERSE of importMap used in onImportConfig
  local exportMap = {
    -- TL (Green) - (Top -> Bot)
    15, 14, 9, 13, 8, 3, 7, 2, 1,
    -- TR (Red) - (Right -> Top)
    16, 17, 10, 18, 11, 4, 12, 5, 6,
    -- BR (Purple) - (Right -> Bot)
    22, 23, 28, 24, 29, 34, 30, 35, 36,
    -- BL (Blue) - (Left -> Bot)
    21, 20, 27, 19, 26, 33, 32, 25, 31
  }
  
  -- Convert internal pointInvested array to export order
  local exportPoints = {}
  for i = 1, 36 do
    exportPoints[i] = 0
  end
  
  for exportIndex, internalIndex in ipairs(exportMap) do
    exportPoints[exportIndex] = pointInvested[internalIndex] or 0
  end
  
  -- Pack the points in export order
  for _, value in ipairs(exportPoints) do
      local packedValue = string.pack_custom("I1", value)
      if packedValue and packedValue ~= "" then
          table.insert(dataParts, packedValue)
      end
  end

  -- Pack gems in fixed order: GREEN, RED, ACQUA, PURPLE
  -- Note: Gem ID 0 is valid! Use 255 as marker for no gem (-1)
  local gems = getGemStruct(preset)
  local gemOrder = {GemDomains.GREEN, GemDomains.RED, GemDomains.ACQUA, GemDomains.PURPLE}
  for _, domain in ipairs(gemOrder) do
    local gemData = gems[domain]
    local gemID = gemData and gemData.gemID or -1
    -- Use 255 as "no gem" marker since gem ID 0 is valid
    local packedValue = string.pack_custom("I1", gemID < 0 and 255 or gemID)
    if packedValue and packedValue ~= "" then
      table.insert(dataParts, packedValue)
    end
  end

  local data = table.concat(dataParts)
  if not data or data == "" then
      return ""
  end

  local base64Data = base64.encode(data)
  local player = g_game.getLocalPlayer()
  if not player then
    return ""
  end
  local currentVocation = translateWheelVocation(player:getVocation())
  return string.format("%s%s", getVocationSt(currentVocation), base64Data)
end

function WheelOfDestiny.onCancelConfig()
  wheelWindow:show(true)

  newPresetWindow:hide()
end

function WheelOfDestiny.validadeImportCode(code)
	if not code or code == "" or #code < 3 then
		return "Export code does not match a valid Wheel of Destiny."
	end

	local vocationString = code:sub(1, 2)
	local base64Data = code:sub(3)

	if vocationString ~= getVocationSt(WheelOfDestiny.vocationId) then
		return "Export code does not match the character's vocation."
	end

	-- Verify base64Data is not empty
	if not base64Data or base64Data == "" then
		return "Export code does not match a valid Wheel of Destiny."
	end

	local importResult = WheelOfDestiny.onImportConfig(base64Data)
	if not importResult or table.empty(importResult) then
		return "Export code does not match a valid Wheel of Destiny."
	end
	return ""
end

function WheelOfDestiny.onEditCode(text)
  selectedNewPresetRadio:selectWidget(newPresetWindow.contentPanel.import)

	local validate = WheelOfDestiny.validadeImportCode(text)
	if not string.empty(validate) then
      newPresetWindow.contentPanel.importTooltip:setVisible(true)
      newPresetWindow.contentPanel.importTooltip:setTooltip(validate)
      newPresetWindow.contentPanel.ok:setEnabled(false)
      return
  end

  newPresetWindow.contentPanel.importTooltip:setVisible(false)
  
  -- Only enable OK button if both preset name is valid AND code is valid
  local presetName = newPresetWindow.contentPanel.presetName:getText()
  local nameValid = checkValidName(presetName)
  newPresetWindow.contentPanel.ok:setEnabled(nameValid)
end

function WheelOfDestiny.onEditName(text)
  newPresetWindow.contentPanel.presetNameTooltip:setVisible(not checkValidName(text))

	local checkName = checkValidName(text)
	local checkCode = string.empty(WheelOfDestiny.validadeImportCode(newPresetWindow.contentPanel.presetCode:getText()))
  local selectedOption = selectedNewPresetRadio:getSelectedWidget()
  
  -- Check if we have a valid code and name
  if selectedOption == newPresetWindow.contentPanel.import then
    newPresetWindow.contentPanel.ok:setEnabled(checkName and checkCode)
    return
  end

  newPresetWindow.contentPanel.ok:setEnabled(checkName)
	return
end

function WheelOfDestiny.onNewPresetSelectionChange()
  local selectedOption = selectedNewPresetRadio:getSelectedWidget()
  if not selectedOption then
    return true
  end

  local presetName = newPresetWindow.contentPanel.presetName:getText()
  local checkName = checkValidName(presetName)

  if selectedOption == newPresetWindow.contentPanel.import then
    local presetCode = newPresetWindow.contentPanel.presetCode:getText()
    local checkCode = string.empty(WheelOfDestiny.validadeImportCode(presetCode))
    newPresetWindow.contentPanel.ok:setEnabled(checkName and checkCode)
    return
  end

  newPresetWindow.contentPanel.ok:setEnabled(checkName)
end

function WheelOfDestiny.onConfirmCreatePreset()
  local selectedOption = selectedNewPresetRadio:getSelectedWidget()
  if not selectedOption then return true end

  local presetName = newPresetWindow.contentPanel.presetName:getText()
  if not checkValidName(presetName) then return end

  local dataCopy = nil

  if selectedOption == newPresetWindow.contentPanel.import then
    local presetCode = newPresetWindow.contentPanel.presetCode:getText()
    local vocationString = presetCode:sub(1, 2)
    if vocationString ~= getVocationSt(WheelOfDestiny.vocationId) then return end

    local base64Data = presetCode:sub(3)
    local loadedResult = WheelOfDestiny.onImportConfig(base64Data)
    if table.empty(loadedResult) then return end

    dataCopy = {
      presetName = presetName,
      availablePoints = loadedResult.maxPoints,
      usedPoints = loadedResult.usedPoints,
      pointInvested = loadedResult.pointInvested,
      equipedGems = loadedResult.equipedGems
    }

  elseif selectedOption == newPresetWindow.contentPanel.copyPreset then
    dataCopy = table.copy(WheelOfDestiny.currentPreset)
    dataCopy.presetName = presetName

  elseif selectedOption == newPresetWindow.contentPanel.useEmpty then
    local totalPoints = WheelOfDestiny.points + (WheelOfDestiny.extraGemPoints + WheelOfDestiny.scrollPoints)
    dataCopy = {
      presetName = presetName,
      availablePoints = totalPoints,
      usedPoints = 0,
      pointInvested = table.reserve(36, 0),
      equipedGems = {-1, -1, -1, -1}
    }

  else
    return
  end

  wheelWindow:show(true)
  newPresetWindow:hide()
  
  -- When importing a preset, preserve the character's current gem equipment
  -- Only the skill point distribution should be imported
  -- Store current gems before they're cleared by resetWheel
  local currentEquipedGems = table.copy(WheelOfDestiny.equipedGems)
  local currentAtelierGems = WheelOfDestiny.atelierGems
  local currentBasicMods = WheelOfDestiny.basicModsUpgrade
  local currentSupremeMods = WheelOfDestiny.supremeModsUpgrade
  
  -- Replace imported gems with character's actual gems
  if selectedOption == newPresetWindow.contentPanel.import then
    dataCopy.equipedGems = currentEquipedGems
  end
  
  -- Create the preset (this sets it as current)
  WheelOfDestiny.createPreset(presetName, dataCopy)
  
  -- Save to JSON file
  WheelOfDestiny.saveWheelPresets()
  
  -- Now apply the preset data exactly like switching presets does
  -- This ensures proper UI reload
  local oldPoints = table.copy(dataCopy.pointInvested)
  local oldGems = table.copy(dataCopy.equipedGems)

  resetWheel(true)

  WheelOfDestiny.currentPreset.pointInvested = oldPoints
  WheelOfDestiny.currentPreset.equipedGems = oldGems
  
  -- Calculate base points from current character
  local basePoints = WheelOfDestiny.levelPoints or WheelOfDestiny.points or 0
  local pointsInvested = dataCopy.availablePoints - (WheelOfDestiny.extraGemPoints + WheelOfDestiny.scrollPoints)
  
  -- Use basePoints to let create() calculate properly  -- Always use character's actual gem data, never from imported preset
  WheelOfDestiny.create(WheelOfDestiny.playerId, WheelOfDestiny.canView, WheelOfDestiny.changeState, WheelOfDestiny.vocationId, basePoints, WheelOfDestiny.scrollPoints, dataCopy.pointInvested, WheelOfDestiny.usedPromotionScrolls, dataCopy.equipedGems, currentAtelierGems, currentBasicMods, currentSupremeMods)
  
  -- Update gem atelier vessel panel after create() has set the new gems
  if GemAtelier and gemAtelierWindow and gemAtelierWindow:isVisible() then
    if GemAtelier.setupVesselPanel then
      GemAtelier.setupVesselPanel()
    end
  end
  
  -- Update preset label
  local presetLabel = wheelWindow:recursiveGetChildById("presetLabel")
  if presetLabel then
    presetLabel:setText(string.format("Current Preset: %s", presetName))
  end
  
  local presetHotCopy = wheelWindow:recursiveGetChildById("hotCopy")
  if presetHotCopy then
    presetHotCopy.onClick = function() 
      WheelOfDestiny.onExportConfig()
    end
  end
  
  local managePanel = wheelWindow:recursiveGetChildById("manage")
  if managePanel then
    managePanel.applyPresetChanges:setEnabled(false)
    managePanel.renamePreset:setEnabled(true)
  end
  
  -- Switch to manage presets tab to show the new preset in the list
  toggleTabBarButtons('managePresetsButton')
  
  -- Rebuild preset list and focus the new preset
  scheduleEvent(function()
    WheelOfDestiny.configurePresets()
    
    local presetPanel = wheelWindow:recursiveGetChildById("presetList")
    if presetPanel then
      for _, widget in ipairs(presetPanel:getChildren()) do
        if widget.presetData and widget.presetData.presetName == presetName then
          presetPanel:focusChild(widget)
          break
        end
      end
    end
  end, 100)

end

function WheelOfDestiny.createPreset(presetName, dataCopy)
  WheelOfDestiny.currentPreset = dataCopy
  table.insert(WheelOfDestiny.internalPreset, dataCopy)
end

function WheelOfDestiny.changePresetName(newName)
  for _, data in pairs(WheelOfDestiny.internalPreset) do
    if data.presetName == WheelOfDestiny.currentPreset.presetName then
      data.presetName = newName
    end
  end
end

function WheelOfDestiny.onRenamePreset()
  wheelWindow:hide()
  renamePresetWindow:show()
  renamePresetWindow.contentPanel.presetName:setText(WheelOfDestiny.currentPreset.presetName)
  renamePresetWindow:grabMouse()
  renamePresetWindow:grabKeyboard()
end

function WheelOfDestiny.onPresetNameChange(text)
  local checkName = checkValidName(text)
  local selectedOption = selectedNewPresetRadio:getSelectedWidget()

  renamePresetWindow.contentPanel.presetNameTooltip:setVisible(not checkName)
  renamePresetWindow.contentPanel.ok:setEnabled(checkName)
end

function WheelOfDestiny.onConfirmRenamePreset(cancel)
  if cancel then
    renamePresetWindow:hide()
    wheelWindow:show(true)

    return
  end

  local newName = renamePresetWindow.contentPanel.presetName:getText()
  if not checkValidName(newName) then return end

  WheelOfDestiny.changePresetName(newName)
  WheelOfDestiny.currentPreset.presetName = newName
  renamePresetWindow:hide()
  wheelWindow:show(true)
  WheelOfDestiny.configurePresets()
  WheelOfDestiny.saveWheelPresets()
  wheelWindow:grabMouse()
  wheelWindow:grabKeyboard()
end

function WheelOfDestiny.onDeletePreset()
  if deletePresetWindow then
    deletePresetWindow:destroy()
  end

  wheelWindow:hide()

  local noOption = function()
    deletePresetWindow:destroy()
    deletePresetWindow = nil
    wheelWindow:show(true)

  end

  local yesOption = function()
    WheelOfDestiny.deletePreset()
    wheelWindow:show(true)
    deletePresetWindow:destroy()
    deletePresetWindow = nil
    WheelOfDestiny.configurePresets()
    WheelOfDestiny.saveWheelPresets()
  end

  local message = string.format("Do you really  want to delete the preset '%s'?", WheelOfDestiny.currentPreset.presetName)
  deletePresetWindow = displayGeneralBox("Delete Preset", message, {
    { text="Yes", callback=yesOption },
    { text="No", callback=noOption }
  })
end

function WheelOfDestiny.deletePreset()
  local currentPreset = WheelOfDestiny.currentPreset
  for i, data in pairs(WheelOfDestiny.internalPreset) do
    if data.presetName == currentPreset.presetName then
      table.remove(WheelOfDestiny.internalPreset, i)
      break
    end
  end

  WheelOfDestiny.currentPreset = WheelOfDestiny.internalPreset[1]
end

local configuringPresets = false

function WheelOfDestiny.configurePresets()
	if configuringPresets then
		return
	end
	
	configuringPresets = true
	local status, err = pcall(function()
		local presetPanel = wheelWindow:recursiveGetChildById("presetList")
		if not presetPanel then
			configuringPresets = false
			return
		end
		
		if not presetPanel:isVisible() then
			configuringPresets = false
			return
		end

		-- Load presets if not already loaded
		if table.empty(WheelOfDestiny.internalPreset) then
			WheelOfDestiny.loadWheelPresets()
		end

		presetPanel:destroyChildren()
		
		presetPanel.onChildFocusChange = function(self, selection, oldSelection) 
			WheelOfDestiny.onPreparePresetClick(self, selection, oldSelection) 
		end

		if table.empty(WheelOfDestiny.internalPreset) then
			configuringPresets = false
			return
		end

		table.sort(WheelOfDestiny.internalPreset, function(a, b)
			if not a or not a.presetName then return false end
			if not b or not b.presetName then return true end
			return a.presetName:lower() < b.presetName:lower()
		end)
		
		for i, data in pairs(WheelOfDestiny.internalPreset) do
			local widgetStatus, widgetErr = pcall(function()
				local widget = g_ui.createWidget('PresetLabel', presetPanel)
				if not widget then
					return
				end
				
				local nameLabel = widget:getChildById('name')
				local pointsLabel = widget:getChildById('points')
				
				if nameLabel then
					nameLabel:setText(data.presetName or "Unknown")
				end
				
				if pointsLabel then
					local pointsText = tostring((data.availablePoints or 0) - (data.usedPoints or 0))
					pointsLabel:setText(pointsText)
				end
				
				widget:setBackgroundColor(i % 2 == 0 and "#484848" or "#414141")
				widget.presetData = data

				if WheelOfDestiny.currentPreset and WheelOfDestiny.currentPreset.presetName == data.presetName then
					presetPanel:focusChild(widget)
				end
			end)
			
			if not widgetStatus then
			end
		end

		local deletePreset = wheelWindow:recursiveGetChildById("deletePreset")
		if deletePreset then
			deletePreset:setEnabled(#WheelOfDestiny.internalPreset > 1)
		end
	end)
	
	configuringPresets = false
	
	if not status then
	end
end

function WheelOfDestiny.onPreparePresetClick(list, selection, oldSelection)
  if not selection or not selection.presetData then
    return
  end
  
  if not oldSelection or not oldSelection.presetData then
    WheelOfDestiny.onPresetClick(list, selection, oldSelection)
    return
  end

  local pointsArray = oldSelection.presetData.pointInvested or {}
	local isEqual = table.compare(pointsArray, WheelOfDestiny.pointInvested)

  if isEqual then
    WheelOfDestiny.onPresetClick(list, selection, oldSelection)
    return
  end

  -- Inform that has currently unsaved changes
  if checkSavePresetWindow then
    checkSavePresetWindow:destroy()
  end

  wheelWindow:hide()

  local yesOption = function()
    if checkSavePresetWindow then
      checkSavePresetWindow:destroy()
      checkSavePresetWindow = nil
    end

    wheelWindow:show(true)

    onWheelOfDestinyApply(false, false)
    WheelOfDestiny.updateCurrentPreset()
    return true
  end

  local noOption = function()
    if checkSavePresetWindow then
      checkSavePresetWindow:destroy()
      checkSavePresetWindow = nil
    end

    wheelWindow:show(true)
    wheelWindow:grabMouse()
    wheelWindow:grabKeyboard()

    WheelOfDestiny.onPresetClick(list, selection, oldSelection)
    return false
  end

  local message = string.format("You have not saved the changes you made to preset '%s'.\nDo you want to save your current changes and active the preset?", WheelOfDestiny.currentPreset.presetName)
  checkSavePresetWindow = displayGeneralBox("Save?", message, {
    { text="Yes", callback=yesOption },
    { text="No", callback=noOption }
  })
end

function WheelOfDestiny.onPresetClick(list, selection, oldSelection)
	if not selection then
		return
	end
	
	if not selection.presetData then
		return
	end
	
	-- Cache presetData locally because configurePresets() will destroy this widget
	local presetData = selection.presetData
	
	if oldSelection then
		local widgetIndex = list:getChildIndex(oldSelection)
		oldSelection:setBackgroundColor(widgetIndex % 2 == 0 and "#484848" or "#414141")
		oldSelection.name:setColor("#c0c0c0")
		oldSelection.points:setColor("#c0c0c0")
	end

  local player = g_game.getLocalPlayer()
  if player and not player:hasState(PlayerStates.Pz) then
    local managePresetsButton = wheelWindow.mainPanel.wheelMenu.info.presetTabBar:getChildById('managePresetsButton')
    toggleTabBarButtons('informationButton')
    managePresetsButton:setEnabled(false)
    return
  end

	selection.name:setColor("#f4f4f4")
	selection.points:setColor("#f4f4f4")

  WheelOfDestiny.currentPreset = presetData

  local presetLabel = wheelWindow:recursiveGetChildById("presetLabel")
  presetLabel:setText(string.format("Current Preset: %s", presetData.presetName))

  local presetHotCopy = wheelWindow:recursiveGetChildById("hotCopy")
  presetHotCopy.onClick = function() 
    WheelOfDestiny.onExportConfig()
  end

  local managePanel = wheelWindow:recursiveGetChildById("manage")
  managePanel.applyPresetChanges:setEnabled(false)
  managePanel.renamePreset:setEnabled(true)

  local deletePreset = wheelWindow:recursiveGetChildById("deletePreset")
  deletePreset:setEnabled(#WheelOfDestiny.internalPreset > 1)

  local oldPoints = table.copy(WheelOfDestiny.currentPreset.pointInvested)
  local oldGems = table.copy(WheelOfDestiny.currentPreset.equipedGems)

  resetWheel(true)

  WheelOfDestiny.currentPreset.pointInvested = oldPoints
  WheelOfDestiny.currentPreset.equipedGems = oldGems
  local pointsInvested = presetData.availablePoints - (WheelOfDestiny.extraGemPoints + WheelOfDestiny.scrollPoints)

  WheelOfDestiny.create(WheelOfDestiny.playerId, WheelOfDestiny.canView, WheelOfDestiny.changeState, WheelOfDestiny.vocationId, pointsInvested, WheelOfDestiny.scrollPoints, presetData.pointInvested, WheelOfDestiny.usedPromotionScrolls, presetData.equipedGems, WheelOfDestiny.atelierGems, WheelOfDestiny.basicModsUpgrade, WheelOfDestiny.supremeModsUpgrade)
  
  -- Update gem atelier vessel panel after create() has set the new gems
  if GemAtelier and gemAtelierWindow and gemAtelierWindow:isVisible() then
    if GemAtelier.setupVesselPanel then
      GemAtelier.setupVesselPanel()
    end
  end 
end

function WheelOfDestiny.determinateCurrentPreset()
	local localGems = getLocalGemStruct()

	for i, data in pairs(WheelOfDestiny.internalPreset) do
		local pointsArray = data.pointInvested
		local gemsArray = data.equipedGems

		if table.compare(pointsArray, WheelOfDestiny.pointInvested) and table.compare(gemsArray, localGems) then
			WheelOfDestiny.currentPreset = data
			local presetLabel = wheelWindow:recursiveGetChildById("presetLabel")
			presetLabel:setText(string.format("Current Preset: %s", data.presetName))

			local presetHotCopy = wheelWindow:recursiveGetChildById("hotCopy")
			presetHotCopy.onClick = function() 
				WheelOfDestiny.onExportConfig()
			end

			return
		end
	end

	-- If no matching preset found, initialize to first preset
	if not WheelOfDestiny.currentPreset or table.empty(WheelOfDestiny.currentPreset) then
		if not table.empty(WheelOfDestiny.internalPreset) then
			WheelOfDestiny.currentPreset = WheelOfDestiny.internalPreset[1]
			local presetLabel = wheelWindow:recursiveGetChildById("presetLabel")
			if presetLabel then
				presetLabel:setText(string.format("Current Preset: %s", WheelOfDestiny.currentPreset.presetName))
			end
		end
	end
end

function WheelOfDestiny.updateCurrentPreset()
	if not WheelOfDestiny.currentPreset then
		return
	end

	local player = g_game.getLocalPlayer()
	if not player then
		return
	end

	WheelOfDestiny.currentPreset.pointInvested = WheelOfDestiny.pointInvested or {}
	WheelOfDestiny.currentPreset.equipedGems = getLocalGemStruct()
	WheelOfDestiny.currentPreset.usedPoints = WheelOfDestiny.usedPoints or 0

  local points = WheelOfDestiny.points or 0
  local extraGemPoints = WheelOfDestiny.extraGemPoints or 0
  local scrollPoints = WheelOfDestiny.scrollPoints or 0
  local totalPoints = points + (extraGemPoints + scrollPoints)
	WheelOfDestiny.currentPreset.availablePoints = totalPoints

  WheelOfDestiny.currentPreset.extraGemPoints = extraGemPoints
  WheelOfDestiny.currentPreset.presetName = WheelOfDestiny.currentPreset.presetName or "Default-Preset"

	for i, data in pairs(WheelOfDestiny.internalPreset) do
		if data.presetName == WheelOfDestiny.currentPreset.presetName then
			WheelOfDestiny.internalPreset[i] = WheelOfDestiny.currentPreset
			break
		end
	end

	-- Update displayed data
	WheelOfDestiny.configurePresets()
end

function WheelOfDestiny.checkApplyButton()
	local pointsArray = WheelOfDestiny.currentPreset.pointInvested or {}
	local hasChanges = table.compare(pointsArray, WheelOfDestiny.pointInvested)

	-- Preset buttons
	local managePanel = wheelWindow:recursiveGetChildById("manage")
	managePanel.applyPresetChanges:setEnabled(not hasChanges)
	managePanel.renamePreset:setEnabled(hasChanges)

	-- Footer buttons
	local closeButton = wheelWindow:recursiveGetChildById("close")
	local applyButton = wheelWindow:recursiveGetChildById("apply")
	local okButton = wheelWindow:recursiveGetChildById("ok")
	closeButton:setText(hasChanges and "Close" or "Cancel")
	okButton:setEnabled(not hasChanges)
end

function WheelOfDestiny.loadWheelPresets()
	WheelOfDestiny.externalPreset = {}
	WheelOfDestiny.internalPreset = {}

	local player = g_game.getLocalPlayer()
	if not player then
		return false
	end

	local playerVocation = translateWheelVocation(player:getVocation())
	local defaultData = { presets = {{ exportString = defaultExportString[playerVocation], name = "Default-Preset" }}} -- default data

	local file = "/characterdata/" .. player:getId() .. "/wheelOfDestiny.json"
	
	if g_resources.fileExists(file) then
		local status, result = pcall(function()
			return json.decode(g_resources.readFileContents(file))
		end)

		if not status then
			WheelOfDestiny.externalPreset = defaultData
			WheelOfDestiny.generateInternalPreset()
			return false
		end

    if result["presets"] == nil or #result["presets"] == 0 then
      WheelOfDestiny.externalPreset = defaultData
    else
		  WheelOfDestiny.externalPreset = result
    end
	else
		WheelOfDestiny.externalPreset = defaultData
	end

	-- Validate preset structure
	WheelOfDestiny.generateInternalPreset()
	return true
end

function WheelOfDestiny.generateInternalPreset()
  local player = g_game.getLocalPlayer()
  if not player then
    return
  end
  
  local playerVocation = translateWheelVocation(player:getVocation())

  
	for k, v in pairs(WheelOfDestiny.externalPreset.presets) do
		local codeString = v["exportString"]
		local vocationString = codeString:sub(1, 2)
		local base64Data = codeString:sub(3)
		local data = WheelOfDestiny.onImportConfig(base64Data)

		-- Invalid data
		if table.empty(data) or vocationString ~= getVocationSt(playerVocation) then
			table.remove(WheelOfDestiny.externalPreset.presets, k)
      goto continue
		end

		g_logger.debug(string.format("[WheelPresets] Adding preset '%s' with %d points", v.name, data.maxPoints))
		table.insert(WheelOfDestiny.internalPreset, { presetName = v.name, availablePoints = data.maxPoints, usedPoints = data.usedPoints, pointInvested = data.pointInvested, equipedGems = data.equipedGems })
	
    :: continue ::
  end
end

function WheelOfDestiny.saveWheelPresets()
  local player = g_game.getLocalPlayer()
  if not player then
    return false
  end

  if table.empty(WheelOfDestiny.internalPreset) then
    return false
  end

  local savedData = {}
  savedData.presets = {}

  for _, preset in pairs(WheelOfDestiny.internalPreset) do
    local exportStr = WheelOfDestiny.getExportCode(preset)
    if not string.empty(exportStr) and #exportStr < 10 then
      exportStr = defaultExportString[translateWheelVocation(player:getVocation())]
    end

    if not string.empty(exportStr) then
      table.insert(savedData.presets, { exportString = exportStr, name = preset.presetName })
    end
  end

  local directory = "/characterdata/" .. player:getId()
  local file = directory .. "/wheelOfDestiny.json"
  
  
  -- Ensure directory exists
  if not g_resources.directoryExists(directory) then
    local success = g_resources.makeDir(directory)
  else
  end

  local status, result = pcall(function() return json.encode(savedData, 2) end)
  if not status then
    return false
  end

  if result:len() > 100 * 1024 * 1024 then
    return false
  end

  g_resources.writeFileContents(file, result)
  return true
end

function WheelOfDestiny.configureEquippedGems()
  for i = 0, 3 do
    local data = GemAtelier.getEquipedGem(i)
    local background = wheelPanel:recursiveGetChildById("socketBackground" .. i)
    local socket = wheelPanel:recursiveGetChildById("gemSocket" .. i)
    local gemIcon = socket:recursiveGetChildById("gemIcon" .. i)
    local filledCount = GemAtelier.getFilledVesselCount(i)

    local backGroundImage = (filledCount == 0 and "backdrop_skillwheel_largebonus_socketdisabled_" .. i or "backdrop_skillwheel_largebonus_socketenabled_" .. i)
    background:setImageSource("/images/game/wheel/" .. backGroundImage)

    local showSocket = filledCount > 0
    socket:setVisible(showSocket)
    if showSocket then
      local startPos = 442
      if data and filledCount == (data.gemType + 1) then
        startPos = 34
      end

      local domainOffset = startPos + (102 * i)
      local modOffset = 34 * math.max(0, filledCount - 1)
      socket:setImageClip(domainOffset + modOffset .. " 0 34 34")
    end

    socket:setVisible(true)
    gemIcon:setVisible(data ~= nil)

    if data then
      local typeOffset = data.gemType * 32
      local domainOffet = data.gemDomain * 96
      local vocationOffset = (WheelOfDestiny.vocationId - 1) * 384
      local gemOffset = vocationOffset + domainOffet + typeOffset
      gemIcon:setImageClip(gemOffset .. " 0 32 32")
      socket:setImageSource("/images/game/wheel/icons-skillwheel-sockets")
      socket:setVisible(true)
      if not showSocket then
        socket:setImageClip("0 0 34 34")
      end
    else
      socket:setImageSource("/images/game/wheel/backdrop_skillwheel_socket_inactive.png")
      socket:setImageClip("0 0 34 34")
    end
  end
end

function WheelOfDestiny.onGemVesselClick(domain)
  if WheelOfDestiny.lastSelectedGemVessel then
    WheelOfDestiny.lastSelectedGemVessel:setVisible(false)
  end

  WheelOfDestiny.resetPassiveFocus()
  wheelPanel.borderSelectedWheel:setVisible(false)

  local widget = wheelPanel:recursiveGetChildById("selectVessel" .. domain)
  WheelOfDestiny.lastSelectedGemVessel = widget
  WheelOfDestiny.lastSelectedGemVessel:setVisible(true)

  wheelOfDestinyWindow.selection.tabContent:setVisible(false)
  wheelOfDestinyWindow.selection.gemContent:setVisible(true)

  local filledCount = GemAtelier.getFilledVesselCount(domain)
  local data = GemAtelier.getEquipedGem(domain)
  if not data then
    wheelOfDestinyWindow.selection.gemContent.gemName:setText("Vessel contains no gem")
  end

  local romanLetter = {"I", "II", "III"}
  local vesselStatus = "Sealed"
  if filledCount == 1 then
    vesselStatus = "Dormant"
  elseif filledCount == 2 then
    vesselStatus = "Awakened"
  elseif filledCount == 3 then
    vesselStatus = "Radiant"
  end

  wheelOfDestinyWindow.selection.gemContent.sealedInfo:setText(tr("%s Vessel (VR %s)", vesselStatus, (filledCount == 0 and "0" or romanLetter[filledCount])))
  wheelOfDestinyWindow.selection.gemContent.VRBonus:setText("")

  wheelOfDestinyWindow.selection.gemContent.modification0:setText("")
  wheelOfDestinyWindow.selection.gemContent.modification1:setText("")
  wheelOfDestinyWindow.selection.gemContent.modification2:setText("")

  if data then
    local formatedName = GemVocations[WheelOfDestiny.vocationId][data.gemType].name:gsub(" %(x 0%)", "")
    local gemSlot1, gemSlot2, gemSlot3 = 0
    local decription = "(Unkown)"

    if data.gemType == 0 then
      local text = {}
      decription, gemSlot1 = Workshop.getGemInformationByBonus(data.lesserBonus, false, data.gemID, 0)
      setStringColor(text, decription, (filledCount >= 1 and "#c0c0c0" or "#707070"))
      wheelOfDestinyWindow.selection.gemContent.modification0:setColoredText(text)
    elseif data.gemType == 1 then
      local text = {}
      decription, gemSlot1 = Workshop.getGemInformationByBonus(data.lesserBonus, false, data.gemID, 0)
      setStringColor(text, decription, (filledCount >= 1 and "#c0c0c0" or "#707070"))
      wheelOfDestinyWindow.selection.gemContent.modification0:setColoredText(text)

      text = {}
      decription, gemSlot2 = Workshop.getGemInformationByBonus(data.regularBonus, false, data.gemID, 1)
      setStringColor(text, decription, (filledCount >= 2 and "#c0c0c0" or "#707070"))
      wheelOfDestinyWindow.selection.gemContent.modification1:setColoredText(text)
    elseif data.gemType == 2 then
      local text = {}
      decription, gemSlot1 = Workshop.getGemInformationByBonus(data.lesserBonus, false, data.gemID, 0)
      setStringColor(text, decription, (filledCount >= 1 and "#c0c0c0" or "#707070"))
      wheelOfDestinyWindow.selection.gemContent.modification0:setColoredText(text)

      text = {}
      decription, gemSlot2 = Workshop.getGemInformationByBonus(data.regularBonus, false, data.gemID, 1)
      setStringColor(text, decription, (filledCount >= 2 and "#c0c0c0" or "#707070"))
      wheelOfDestinyWindow.selection.gemContent.modification1:setColoredText(text)

      text = {}
      decription, gemSlot3 = Workshop.getGemInformationByBonus(data.supremeBonus, true, data.gemID, 2)
      setStringColor(text, decription, (filledCount == 3 and "#c0c0c0" or "#707070"))
      wheelOfDestinyWindow.selection.gemContent.modification2:setColoredText(text)
    end

    local text = {}
    setStringColor(text, tr("+%s Damage and Healing", (data.gemType == 2 and 2 or 1)), (filledCount == 3 and "#c0c0c0" or "#707070"))
    wheelOfDestinyWindow.selection.gemContent.VRBonus:setColoredText(text)


    local replaceStr = {[0] = "�", [1] = "�", [2] = "�", [3] = "�"}
    local coloredStr = {}
    setStringColor(coloredStr, formatedName .. " ", "#c0c0c0")
    if data then
      setStringColor(coloredStr, replaceStr[gemSlot1], "white")
      if data.gemType >= 1 then
        setStringColor(coloredStr, replaceStr[gemSlot2], "white")
      end

      if data.gemType >= 2 then
        setStringColor(coloredStr, replaceStr[gemSlot3], "white")
      end
    end

    wheelOfDestinyWindow.selection.gemContent.gemName:setColoredText(coloredStr)
  end
end

function WheelOfDestiny.onChangeGemButton(domain)
  if wheelOfDestinyWindow:isVisible() then
    wheelOfDestinyWindow:hide()
  end

  local wheelMenuButton = wheelWindow.optionsTabBar:getChildById('wheelMenu')
  local gemMenuButton = wheelWindow.optionsTabBar:getChildById('gemMenu')

  wheelMenuButton:setChecked(false)
  gemMenuButton:setChecked(true)

  gemAtelierWindow:show(true)
  wheelMenuButton:setChecked(false)
  gemMenuButton:setChecked(true)
  
  local currentDomain = WheelOfDestiny.lastSelectedGemVessel and WheelOfDestiny.lastSelectedGemVessel:getId():gsub("selectVessel", "") or 0
  local data = GemAtelier.getEquipedGem(tonumber(currentDomain))
  if data then
    GemAtelier.redirectToGem(data)
  else
    GemAtelier.resetFields()
    GemAtelier.showGems(true)
	end
end

function WheelOfDestiny.setupPointsTooltip()
  local tooltip = tr(WheelPointTooltip, WheelOfDestiny.levelPoints, WheelOfDestiny.extraGemPoints, WheelOfDestiny.scrollPoints)
  if WheelOfDestiny.scrollPoints > 0 then
    tooltip = tooltip .. "\nYou have received bonus promotion points by using the following items: "
    for k, v in pairs(WheelOfDestiny.usedPromotionScrolls) do
      local item = Item.create(k)
      local marketData = item:getMarketData()
      if marketData then
        tooltip = tooltip .. "\n" .. string.format("%s (%s points)", marketData.name, v)
      end
    end
  end

  if WheelOfDestiny.fromAchievementType and WheelOfDestiny.fromAchievementType > 0 then
    tooltip = tooltip .. "\nYou were rewarded 10 bonus promotion points for earning the achievement \"Path of Insight\"."
  end

  wheelOfDestinyWindow.selection.pointsDesc:setTooltip(tooltip)
  wheelOfDestinyWindow.selection.points:setTooltip(tooltip)
end
