if not PartyClass then
  PartyClass = {}
  PartyClass.__index = PartyClass
end


PartyClass.ageNumber = 1
PartyClass.window = nil
PartyClass.ages = {}
PartyClass.secondary = false
PartyClass.showFilters = true
PartyClass.panel = nil
PartyClass.filterPanel = nil
PartyClass.toggleFilterButton = nil
PartyClass.name = ""
PartyClass.sortType = {
  [1] = "byAgeAscending",
  [2] = "byAgeAscending",   -- ??
}
PartyClass.sortData = {}
PartyClass.spectators = {}
PartyClass.players = {}

function PartyClass:configure()
  PartyClass.ageNumber = 1
  PartyClass.window = nil
  PartyClass.ages = {}
  PartyClass.secondary = false
  PartyClass.showFilters = true
  PartyClass.panel = nil
  PartyClass.filterPanel = nil
  PartyClass.toggleFilterButton = nil
  PartyClass.name = ""
  PartyClass.players = {}
  PartyClass.sortType = {
    [1] = "byAgeAscending",
    [2] = "byAgeAscending",     -- ??
  }
end

function PartyClass:setup(windowId, window)
  if not window then
    PartyClass.window = g_ui.createWidget('partyList', modules.game_interface.getRightPanel())
    PartyClass.window:setId("PartyWindow_" .. windowId)
    PartyClass.window:close()
  else
    PartyClass.window = window
  end

  PartyClass.window.instance = windowId - 1
  PartyClass.window.bid = windowId
  local scrollbar = PartyClass.window:getChildById('miniwindowScrollBar')
  scrollbar:mergeStyle({ ['$!on'] = {} })

  local partyPanel = PartyClass.window:recursiveGetChildById('partyPanel')
  partyPanel:setId("partyPanel_" .. windowId)
  partyPanel.createButton = function()
    local battleButton = g_ui.createWidget('BattleButton', partyPanel)
    battleButton:toggleManaBar(true)
    battleButton:setHeight(26)
    battleButton:hide()
    battleButton.onMouseRelease = modules.game_battle.onBattleButtonMouseRelease
  end

  PartyClass.panel = partyPanel
  -- PartyClass.panel:setIsParty(true)

  local _filterPanel = PartyClass.window:recursiveGetChildById('filterPanel')
  local _toggleFilterButton = PartyClass.window:recursiveGetChildById('toggleFilterButton')
  PartyClass.toggleFilterButton = _toggleFilterButton

  local sortTypeBox = _filterPanel.sortPanel.sortTypeBox
  local sortOrderBox = _filterPanel.sortPanel.sortOrderBox
  sortTypeBox:setVisible(false)
  sortOrderBox:setVisible(false)


  PartyClass.filterPanel = _filterPanel
  PartyClass.window:setContentMinimumHeight(56)

  sortTypeBox:addOption('Name', 'name')
  sortTypeBox:addOption('Distance', 'distance')
  sortTypeBox:addOption('Total age', 'age')
  sortTypeBox:addOption('Screen age', 'screenage')
  sortTypeBox:addOption('Health', 'health')

  sortOrderBox:addOption('Asc.', 'asc')
  sortOrderBox:addOption('Desc.', 'desc')

  PartyClass.window.onMouseRelease = function(widget, mousePos, mouseButton)
    if mouseButton == MouseRightButton and not g_mouse.isPressed(MouseLeftButton) then
      local child = widget:recursiveGetChildByPos(mousePos)

      -- Se clicar na creature não abre esse menu
      if child and child:getClassName() == "UIRealCreatureButton" then
        return
      end

      PartyClass:onFilterPopup()
    end
  end

  -- setup
  PartyClass.window:setup()
end

function PartyClass:getWindow()
  return PartyClass.window
end

function PartyClass:getButtons()
  return PartyClass.buttons
end

function PartyClass:getToggleFilterButton()
  return PartyClass.toggleFilterButton
end

function PartyClass:getFilterPanel()
  return PartyClass.filterPanel
end

-- Extra functions
function PartyClass:onFilterPopup()
  local menu = g_ui.createWidget('PopupMenu')
  menu:setGameMenu(true)
  menu:addOption(tr('Edit Name'), function() self:displayEditName() end)
  menu:addSeparator()
  menu:addCheckBoxOption(tr('Sort Ascending by Display Time'),
    function()
      PartyClass.panel:setSortType('byAgeAscending')
      self.sortType[1] = 'byAgeAscending'
    end, "", self.sortType[1] == 'byAgeAscending')
  menu:addCheckBoxOption(tr('Sort Descending by Display Time'),
    function()
      PartyClass.panel:setSortType('byAgeDescending')
      self.sortType[1] = 'byAgeDescending'
    end, "", self.sortType[1] == 'byAgeDescending')
  menu:addCheckBoxOption(tr('Sort Ascending by Distance'),
    function()
      PartyClass.panel:setSortType('byDistanceAscending')
      self.sortType[1] = 'byDistanceAscending'
    end, "", self.sortType[1] == 'byDistanceAscending')
  menu:addCheckBoxOption(tr('Sort Descending by Distance'),
    function()
      PartyClass.panel:setSortType('byDistanceDescending')
      self.sortType[1] = 'byDistanceDescending'
    end, "", self.sortType[1] == 'byDistanceDescending')
  menu:addCheckBoxOption(tr('Sort Ascending by Hit Points'),
    function()
      PartyClass.panel:setSortType('byHitpointsAscending')
      self.sortType[1] = 'byHitpointsAscending'
    end, "", self.sortType[1] == 'byHitpointsAscending')
  menu:addCheckBoxOption(tr('Sort Descending by Hit Points'),
    function()
      PartyClass.panel:setSortType('byHitpointsDescending')
      self.sortType[1] = 'byHitpointsDescending'
    end, "", self.sortType[1] == 'byHitpointsDescending')
  menu:addCheckBoxOption(tr('Sort Ascending by Name'),
    function()
      PartyClass.panel:setSortType('byNameAscending')
      self.sortType[1] = 'byNameAscending'
    end, "", self.sortType[1] == 'byNameAscending')
  menu:addCheckBoxOption(tr('Sort Descending by Name'),
    function()
      PartyClass.panel:setSortType('byNameDescending')
      self.sortType[1] = 'byNameDescending'
    end, "", self.sortType[1] == 'byNameDescending')
  menu:display(g_window.getMousePosition())
end

function PartyClass:setName(newName)
  self.name = newName
  if newName ~= '' then
    self.window:setText(newName)
  else
    self.window:setText(tr('Party List'))
  end
end

function PartyClass:displayEditName()
  if editNameBattleWindow then
    editNameBattleWindow:destroy()
    editNameBattleWindow = nil
  end


  editNameBattleWindow = g_ui.displayUI("newName")


  local function cancel()
    editNameBattleWindow:hide()
    editNameBattleWindow:destroy()
    editNameBattleWindow = nil
  end
  local function okCallback()
    local text = editNameBattleWindow.contentPanel.newName:getText()
    self:setName(text)
    editNameBattleWindow:hide()
    editNameBattleWindow:destroy()
    editNameBattleWindow = nil
  end

  editNameBattleWindow.onEscape = cancel
  editNameBattleWindow.onEnter = okCallback
  editNameBattleWindow.contentPanel.newName:focus()
  editNameBattleWindow.contentPanel.newName:setText(self.name)

  editNameBattleWindow.contentPanel.cancel.onClick = cancel
  editNameBattleWindow.contentPanel.ok.onClick = okCallback
end

function PartyClass:registerInSideBars()
  local configs = {
    battleListFilters = {},
    battleListSortOrder = self.sortType,
    contentHeight = (self.window.minimizeButton:isOn() and 140 or self.window:getHeight()),
    contentMaximized = not self.window.minimizeButton:isOn(),
    isPartyView = true,
    isPrimary = false,
    name = self.name,
    showFilters = self.showFilters,
  }

  local hidePlayers = not self.filterPanel.buttons.showPlayers:isChecked()
  local hideKnights = not self.filterPanel.buttons.showKnights:isChecked()
  local hidePaladins = not self.filterPanel.buttons.showPaladins:isChecked()
  local hideDruids = not self.filterPanel.buttons.showDruids:isChecked()
  local hideSorceres = not self.filterPanel.buttons.showSorcerers:isChecked()
  local hideMonks = not self.filterPanel.buttons.showMonks:isChecked()
  local hideSummons = not self.filterPanel.buttons.showSummons:isChecked()
  if hideKnights then
    table.insert(configs.battleListFilters, "hideKnights")
  end
  if hidePaladins then
    table.insert(configs.battleListFilters, "hidePaladins")
  end
  if hideDruids then
    table.insert(configs.battleListFilters, "hideDruids")
  end
  if hideSorceres then
    table.insert(configs.battleListFilters, "hideSorcerers")
  end
  if hideMonks then
    table.insert(configs.battleListFilters, "hideMonks")
  end
  if hidePlayers then
    table.insert(configs.battleListFilters, "hidePlayers")
  end
  if hideSummons then
    table.insert(configs.battleListFilters, "hideSummons")
  end

  modules.game_sidebars.registerPartyWindow(configs)
end

function PartyClass.setFilter(self, filter, value)
  if PartyClass.panel then PartyClass.panel:setFilter(filter, value) end
end

