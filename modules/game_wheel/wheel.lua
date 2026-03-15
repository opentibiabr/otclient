wheelWindow = nil
wheelOfDestinyWindow = nil
gemAtelierWindow = nil
fragmentWindow = nil
newPresetWindow = nil
renamePresetWindow = nil
exportCodeWindow = nil
deletePresetWindow = nil
checkSavePresetWindow = nil
selectedNewPresetRadio = nil
local summaryVisible = false

wheelPanel = nil
centerReferencePoint = nil

if not SkillwheelStringsLibrary then
  SkillwheelStringsLibrary = {}
end

function init()
  loadConfigJson()

  connect(g_game, {
    onGameEnd = onGameEnd,
    onGameStart = WheelOfDestiny.loadWheelPresets,
    onDestinyWheel = function(...) load() WheelOfDestiny.onDestinyWheel(...) end,
    --onUnlockGem = GemAtelier.onUnlockGem, --disabled because it's in TODO
    onResourceBalance = onResourceBalance,
  })
  
end

function load()
  if wheelWindow then
    return
  end

  wheelWindow = g_ui.displayUI('wheel')
  mainPanel = wheelWindow:getChildById('mainPanel')

  wheelOfDestinyWindow = g_ui.loadUI('styles/wheelMenu', mainPanel)
  wheelOfDestinyWindow:hide()

  gemAtelierWindow = g_ui.loadUI('styles/gemMenu', mainPanel)
  gemAtelierWindow:hide()
  
  local affinitiesBox = gemAtelierWindow:recursiveGetChildById('affinitiesBox')
  local qualitiesBox = gemAtelierWindow:recursiveGetChildById('qualitiesBox')
  
  if affinitiesBox then
    affinitiesBox.onOptionChange = function(widget, text, data)
      if GemAtelier and GemAtelier.onSortAffinity then
        GemAtelier.onSortAffinity(widget, widget.currentIndex)
      end
    end
  end
  
  if qualitiesBox then
    qualitiesBox.onOptionChange = function(widget, text, data)
      if GemAtelier and GemAtelier.onSortQuality then
        GemAtelier.onSortQuality(widget, widget.currentIndex)
      end
    end
  end

  fragmentWindow = g_ui.loadUI('styles/fragmentMenu', mainPanel)
  fragmentWindow:hide()

  newPresetWindow = g_ui.displayUI('styles/newPreset')
  newPresetWindow:hide()

  renamePresetWindow = g_ui.displayUI('styles/renamePreset')
  renamePresetWindow:hide()

  selectedNewPresetRadio = UIRadioGroup.create()
  selectedNewPresetRadio:addWidget(newPresetWindow.contentPanel.useEmpty)
  selectedNewPresetRadio:addWidget(newPresetWindow.contentPanel.copyPreset)
  selectedNewPresetRadio:addWidget(newPresetWindow.contentPanel.import)
  selectedNewPresetRadio:selectWidget(newPresetWindow.contentPanel.import)
  selectedNewPresetRadio.onSelectionChange = WheelOfDestiny.onNewPresetSelectionChange

  local addOneButton = wheelOfDestinyWindow:recursiveGetChildById('addOne')
  local rmvOneButton = wheelOfDestinyWindow:recursiveGetChildById('rmvOne')

  g_mouse.bindAutoPress(addOneButton, function()
    onAddOne()
  end, 500, nil)

  g_mouse.bindAutoPress(rmvOneButton, function()
    onRmvOne()
  end, 500, nil)

  loadMenu('wheelMenu')
  toggleTabBarButtons('informationButton')
  wheelWindow:hide()
end

function terminate()
  disconnect(g_game, {
    onGameEnd = onGameEnd,
    onGameStart = WheelOfDestiny.loadWheelPresets,
    onDestinyWheel = WheelOfDestiny.onDestinyWheel,
    --onUnlockGem = GemAtelier.onUnlockGem, --disabled because it's in TODO
    onResourceBalance = onResourceBalance
  })

  if wheelWindow then
    wheelWindow:destroy()
    wheelWindow = nil
  end

  if newPresetWindow then
    newPresetWindow:destroy()
    newPresetWindow = nil
  end

  if renamePresetWindow then
    renamePresetWindow:destroy()
    renamePresetWindow = nil
  end

  if exportCodeWindow then
    exportCodeWindow:destroy()
    exportCodeWindow = nil
  end

  if deletePresetWindow then
    deletePresetWindow:destroy()
    deletePresetWindow = nil
  end

  if checkSavePresetWindow then
    checkSavePresetWindow:destroy()
    checkSavePresetWindow = nil
  end

  if selectedNewPresetRadio then
    selectedNewPresetRadio:destroy()
    selectedNewPresetRadio = nil
  end

  if wheelButton then
    wheelButton:destroy()
    wheelButton = nil
  end

  wheelOfDestinyWindow = nil
  gemAtelierWindow = nil
  fragmentWindow = nil
  mainPanel = nil
  wheelPanel = nil
  centerReferencePoint = nil
  wheelMenuButton = nil
  gemMenuButton = nil
  fragmentMenuButton = nil
  SkillwheelStringsLibrary = {}
end

function toggle()
  load()
  if wheelWindow:isVisible() then
    wheelWindow:hide()
    wheelWindow:ungrabMouse()
    wheelWindow:ungrabKeyboard()
  else
    wheelWindow:focus()
    loadMenu('wheelMenu')
    if gemAtelierWindow:isVisible() then
      gemAtelierWindow:hide()
    end
    if fragmentWindow:isVisible() then
      fragmentWindow:hide()
    end

    g_game.openWheel(g_game.getLocalPlayer():getId())
    wheelWindow:recursiveGetChildById('tabContent'):setVisible(false)
    WheelOfDestiny.onRemoveClick()
  end
end

function hide()
  if not wheelWindow then
    return
  end
  wheelWindow:ungrabMouse()
  wheelWindow:ungrabKeyboard()
  wheelWindow:hide()
end

function onGameEnd()
  hide()
  WheelOfDestiny.saveWheelPresets()

  newPresetWindow:hide()
  renamePresetWindow:hide()

  if exportCodeWindow then
    exportCodeWindow:destroy()
    exportCodeWindow = nil
  end

  if deletePresetWindow then
    deletePresetWindow:destroy()
    deletePresetWindow = nil
  end

  if checkSavePresetWindow then
    checkSavePresetWindow:destroy()
    checkSavePresetWindow = nil
  end

  WheelOfDestiny.currentPreset = {}
  wheelWindow:ungrabMouse()
  wheelWindow:ungrabKeyboard()
end

function show()
  g_game.openWheel(g_game.getLocalPlayer():getId())
end

-- check click point
function onWheelClick(position)
  WheelOfDestiny.onWheelClick(position)
end

function loadMenu(menuId)
  wheelWindow:ungrabMouse()
  wheelWindow:ungrabKeyboard()
  
  if wheelOfDestinyWindow:isVisible() then
    wheelOfDestinyWindow:hide()
  end
  if gemAtelierWindow:isVisible() then
    gemAtelierWindow:hide()
  end
  if newPresetWindow:isVisible() then
    newPresetWindow:hide()
  end
  if fragmentWindow:isVisible() then
    fragmentWindow:hide()
  end

  wheelMenuButton = wheelWindow.optionsTabBar:getChildById('wheelMenu')
  gemMenuButton = wheelWindow.optionsTabBar:getChildById('gemMenu')
  fragmentMenuButton = wheelWindow.optionsTabBar:getChildById('fragmentMenu')

  if menuId == 'wheelMenu' then
    gemAtelierWindow:hide()
    fragmentWindow:hide()
    wheelPanel = wheelOfDestinyWindow:getChildById('wheelPanel')

    wheelPanel.onMouseMove = WheelOfDestiny.onMouseMove

    centerReferencePoint = wheelOfDestinyWindow:recursiveGetChildById('centerReferencePoint')
    wheelMenuButton:setChecked(true)
    gemMenuButton:setChecked(false)
    fragmentMenuButton:setChecked(false)
    local informationButton = wheelWindow.mainPanel.wheelMenu.info.presetTabBar:getChildById('informationButton')
    local managePresetsButton = wheelWindow.mainPanel.wheelMenu.info.presetTabBar:getChildById('managePresetsButton')
    local summaryButton = wheelWindow.mainPanel.wheelMenu.dedicationPerks:getChildById('summaryButton')
    local summaryOpenedButton = wheelWindow.mainPanel.wheelMenu.summary:getChildById('summaryButton')
    informationButton.onClick = function() toggleTabBarButtons('informationButton') end
    managePresetsButton.onClick = function() 
      toggleTabBarButtons('managePresetsButton')
      scheduleEvent(function() WheelOfDestiny.configurePresets() end, 50)
    end
    summaryButton.onClick = function() toggleSummary() end
    summaryOpenedButton.onClick = function() toggleSummary() end
    toggleTabBarButtons('informationButton')

    if WheelOfDestiny.lastSelectedGemVessel and WheelOfDestiny.lastSelectedGemVessel:isVisible() then
      local currentDomain = WheelOfDestiny.lastSelectedGemVessel:getId():gsub("selectVessel", "")
      WheelOfDestiny.onGemVesselClick(tonumber(currentDomain))
    end
    Workshop.createFragments()
    wheelOfDestinyWindow:show(true)
  elseif menuId == 'gemMenu' then
    Workshop.createFragments()
    GemAtelier.resetFields()
    GemAtelier.showGems(true)
    gemAtelierWindow:show(true)
    wheelMenuButton:setChecked(false)
    fragmentMenuButton:setChecked(false)
    gemMenuButton:setChecked(true)
  elseif menuId == 'fragmentMenu' then
    Workshop.createFragments()
    Workshop.showFragmentList(true)
    fragmentWindow:show(true)
    wheelMenuButton:setChecked(false)
    gemMenuButton:setChecked(false)
    fragmentMenuButton:setChecked(true)
  end
end

function toggleSummary()
  summaryVisible = not summaryVisible

  local summaryPanel = wheelWindow.mainPanel.wheelMenu:getChildById('summary')
  local dedicationPerksPanel = wheelWindow.mainPanel.wheelMenu:getChildById('dedicationPerks')
  local convictionPerksPanel = wheelWindow.mainPanel.wheelMenu:getChildById('convictionPerks')
  local vesselsPanel = wheelWindow.mainPanel.wheelMenu:getChildById('vessels')
  local revelationPerksPanel = wheelWindow.mainPanel.wheelMenu:getChildById('revelationPerks')

  summaryPanel:setVisible(summaryVisible)
  dedicationPerksPanel:setVisible(not summaryVisible)
  convictionPerksPanel:setVisible(not summaryVisible)
  vesselsPanel:setVisible(not summaryVisible)
  revelationPerksPanel:setVisible(not summaryVisible)
  WheelOfDestiny.configureSummary()
end

function toggleTabBarButtons(selectedButtonId)
  local informationButton = wheelWindow.mainPanel.wheelMenu.info.presetTabBar:getChildById('informationButton')
  local managePresetsButton = wheelWindow.mainPanel.wheelMenu.info.presetTabBar:getChildById('managePresetsButton')
  local tabContent = wheelWindow.mainPanel.wheelMenu.info.tabContent

  if selectedButtonId == 'informationButton' then
    informationButton:setSize(tosize("174 34"))
    informationButton:setImageSource('/game_wheel/images/informationSelection')
    informationButton:setImageClip(torect("0 0 174 34"))
    managePresetsButton:setSize(tosize("34 34"))
    managePresetsButton:setImageSource('/game_wheel/images/small_manage_button')
    managePresetsButton:setImageClip(torect("0 0 34 34"))
    tabContent.manage:setVisible(false)
    tabContent.information:setVisible(true)
  elseif selectedButtonId == 'managePresetsButton' then
    informationButton:setSize(tosize("34 34"))
    informationButton:setImageSource('/game_wheel/images/small_information_button')
    informationButton:setImageClip(torect("0 0 34 34"))
    managePresetsButton:setSize(tosize("174 34"))
    managePresetsButton:setImageSource('/game_wheel/images/manageSelect')
    managePresetsButton:setImageClip(torect("0 0 174 34"))
    tabContent.information:setVisible(false)
    tabContent.manage:setVisible(true)
  end
end

function onResourceBalance()
  if not wheelWindow or not wheelWindow:isVisible() then
    return true
  end
  local player = g_game.getLocalPlayer()
  
  local bankMoney = player:getResourceBalance(ResourceTypes.BANK_BALANCE)
  local characterMoney = player:getResourceBalance(ResourceTypes.GOLD_EQUIPPED)
  local lesserFragment = player:getResourceBalance(ResourceTypes.LESSER_FRAGMENTS)
  local greaterFragment = player:getResourceBalance(ResourceTypes.GREATER_FRAGMENTS)

  local value = bankMoney + characterMoney

  wheelWindow.moneyPanel.gold:setText(formatMoney(value, ','))
  wheelWindow.lesserFragmentPanel.gold:setText(lesserFragment)
  wheelWindow.greaterFragmentPanel.gold:setText(greaterFragment)

end

function loadConfigJson()
	local file = "/json/SkillwheelStringsJsonLibrary.json"
	if g_resources.fileExists(file) then
		local status, result = pcall(function()
			return json.decode(g_resources.readFileContents(file))
		end)

		if not status then
			return g_logger.debug("Error while reading characterdata file. Details: " .. result)
		end

		SkillwheelStringsLibrary = result
	end
end
