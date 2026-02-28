partyList = nil

function init()
  partyListButton = modules.game_mainpanel.addToggleButton('partyListButton', tr('Party List'), '/images/options/bot', toggle, false, 99999)
  partyListButton:setOn(false)
  partyListButton:show()
  
  g_ui.displayUI('partyList')
  partyList = g_ui.createWidget('PartyListWindow', modules.game_interface.getRightPanel())
  partyList:hide()
  partyList:setup()
  partyList:close()
  partyList:setId('PartyWindow')

  PartyClass:configure()
  PartyClass:setup(1, partyList)

  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
    onUpdateMana = onUpdateMana,
  })
end

function terminate()
  if partyList then
    partyList:destroy()
    partyList = nil
  end

  disconnect(g_game, {
      onGameStart = online,
      onGameEnd = offline,
      onUpdateMana = onUpdateMana,
    })
end

function toggle()
  if partyList:isVisible() then
    partyList:close()
  else
    partyList:open()
    partyList:setup()
    if modules.game_interface.addToPanels(partyList) then
      if partyList:getParent() then
        partyList:getParent():moveChildToIndex(partyList, #partyList:getParent():getChildren())
      end
      local filterBattleButton = partyList:getChildById('filterBattleButton')
      local filterPanel = partyList:recursiveGetChildById('filterPanel')
      if filterPanel and not filterPanel:isVisible() then
        filterBattleButton:setOn(false)
      end
    end
  end
end

function hide()
  partyList:close()
end

function show()
  partyList:open()
  partyList:setup()
end

function filterPopUp()
  PartyClass:onFilterPopup()
end

function onMiniWindowClose()
  modules.game_sidebuttons.setButtonVisible("partyWidget", false)
end

function setHidingFilters(state)
  settings = {}
  settings['hidingFilters'] = state
  g_settings.mergeNode('BattleList', settings)
end

function hideFilterPanel(id)
  local filterPanel = partyList:recursiveGetChildById('filterPanel')
  local toggleFilterButton = PartyClass:getToggleFilterButton()
  if not filterPanel then
	 return
  end

  local battleWindow = partyList
  PartyClass.showFilters = false
  filterPanel.originalHeight = 25
  filterPanel:setHeight(0)
  toggleFilterButton:getParent():setMarginTop(0)
  toggleFilterButton:setImageClip(torect("0 0 21 12"))
  setHidingFilters(true)
  filterPanel:setVisible(false)
  battleWindow:setContentMinimumHeight(56)
  toggleFilterButton:setOn(false)
end

function showFilterPanel(id)
  local filterPanel = partyList:recursiveGetChildById('filterPanel')
  local toggleFilterButton = PartyClass:getToggleFilterButton()
  if not filterPanel then
   return
  end

  local battleWindow = partyList
  PartyClass.showFilters = true
  toggleFilterButton:getParent():setMarginTop(5)
  filterPanel:setHeight(25)
  toggleFilterButton:setImageClip(torect("21 0 21 12"))
  setHidingFilters(false)
  filterPanel:setVisible(true)

  toggleFilterButton:setOn(true)
  if battleWindow:getHeight() < 115 then
    battleWindow:setHeight(115)
  end

  battleWindow:setContentMinimumHeight(115)
end

function toggleFilterPanel(self)
  local filterBattleButton = self:getChildById('filterBattleButton')
  local filterPanel = PartyClass:getFilterPanel()
  if not filterPanel then
   return
  end

  if filterPanel:isVisible() then
    filterBattleButton:setOn(false)
    hideFilterPanel(id)
    self:getChildById('separator'):setVisible(false)
  else
    filterBattleButton:setOn(true)
    showFilterPanel(id)
    self:getChildById('separator'):setVisible(true)
  end
end

function onPlayerLoad(config)
  if not config then
    partyList:setup()
    return
  end

  if table.empty(config) then
    config = {
      ["name"] = "Party List",
      ["contentHeight"] = 0,
      ["showFilters"] = false,
      ["contentMaximized"] = true,
      ["battleListFilters"] = {},
      ["battleListSortOrder"] = {
        [1] = "byAgeAscending",
        [2] = "byAgeAscending",     -- ??
      }
    }
  end

  PartyClass:setName(config.name)
  for _, value in pairs(config.battleListFilters) do
    if value == "hidePlayerSummons" then
      value = "hideSummons"
    elseif value == "showPlayerSummons" then
      value = "showSummons"
    end

    PartyClass.panel:setFilter(value)
  end

  for _, value in pairs(config.battleListFilters) do
    local invertedValue = value:gsub("hide", "show")
    local button = partyList:recursiveGetChildById('filterPanel').buttons:getChildById(invertedValue)
    if button then
    PartyClass.panel:setFilter(invertedValue)
      button:setChecked(false)
    end
  end

  PartyClass.panel:setSortType(config.battleListSortOrder[1])
  PartyClass.sortType[1] = config.battleListSortOrder[1]

  if config.contentMaximized then
    partyList:maximize()
  else
    partyList:minimize()
  end
  if not modules.game_interface.addToPanels(partyList) then
    modules.game_sidebuttons.setButtonVisible("partyWidget", false)
    return
  end

  if partyList:isVisible() then
    modules.game_sidebuttons.setButtonVisible("partyWidget", true)
  end

  partyList:getParent():moveChildToIndex(partyList, #partyList:getParent():getChildren())
  scheduleEvent(function() setupPartyPanel(config.showFilters) end, 2000, "setupParty")
  if config.contentHeight < partyList:getMinimumHeight() then
    config.contentHeight = partyList:getMinimumHeight()
  end
  partyList:setHeight(config.contentHeight)
  partyList:setup()
end

function setupPartyPanel(showFilters)
  local filterBattleButton = partyList:getChildById('filterBattleButton')
  local filterPanel = partyList:recursiveGetChildById('filterPanel')
  if not filterPanel then
   return
  end
  if not showFilters then
    if not filterPanel:isVisible() then
      return
    end
    filterBattleButton:setOn(false)
    hideFilterPanel()
  else
    if filterPanel:isVisible() then
      return
    end
    filterBattleButton:setOn(true)
    showFilterPanel()
  end
end

function move(panel, height, minimized)
  partyList:setParent(panel)
  partyList:open()
  partyList:maximize()
  partyList:setHeight(height)

  return partyList
end

function getUpcomingPartyMembers()
  local localPlayer = g_game.getLocalPlayer()
  if not localPlayer then return {} end
  
  local players = {}
  local spectators = g_map.getSpectators(localPlayer:getPosition(), false)
  
  for _, creature in pairs(spectators) do
    if creature:isPlayer() and creature:isPartyMember() then
      local creaturePosition = creature:getPosition()
      if creaturePosition and Position.distance(creaturePosition, localPlayer:getPosition()) <= 9 then
        table.insert(players, creature)
      end
    end
  end
  return players
end

function onUpdateMana(creatureId, manaPercent)
  local creature = g_map.getCreatureById(creatureId)
  if creature and creature:isPlayer() and creature:isPartyMember() then
    creature:setManaPercent(manaPercent)
  end
end
