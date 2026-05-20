return function(context)
  local imbuementApi = {
    window = nil,
    selectItemOrScroll = nil,
    scrollImbue = nil,
    selectImbue = nil,
    clearImbue = nil,

    messageWindow = nil,

    bankGold = 0,
    inventoryGold = 0,
  }

  imbuementApi.__index = imbuementApi

  imbuementApi.MessageDialog = {
    ImbuementSuccess = 0,
    ImbuementError = 1,
    ImbuementRollFailed = 2,
    ImbuingStationNotFound = 3,
    ClearingCharmSuccess = 10,
    ClearingCharmError = 11,
    PreyMessage = 20,
    PreyError = 21,
  }

  local self = imbuementApi

  function imbuementApi.ensureWindow()
    if self.window then
      return
    end

    self.window = g_ui.displayUI('t_imbui')
    self.selectItemOrScroll = self.window:recursiveGetChildById('selectItemOrScroll')
    self.scrollImbue = self.window:recursiveGetChildById('scrollImbue')
    self.selectImbue = self.window:recursiveGetChildById('selectImbue')
    self.clearImbue = self.window:recursiveGetChildById('clearImbue')
    self:hide()
  end

  function imbuementApi.destroyWindow()
    self.selectItemOrScroll = nil
    self.scrollImbue = nil
    self.selectImbue = nil
    self.clearImbue = nil

    if self.window then
      self.window:destroy()
      self.window = nil
    end
  end

  function imbuementApi.init()
  end

  function imbuementApi.terminate()
    if self.messageWindow then
      self.messageWindow:destroy()
      self.messageWindow = nil
    end

    if context.item then
      context.item:shutdown()
    end
    if context.selection then
      context.selection:shutdown()
    end
    if context.scroll then
      context.scroll:shutdown()
    end
    self.destroyWindow()
  end

  function imbuementApi.online()
    self:hide()
    if self.messageWindow then
      self.messageWindow:destroy()
      self.messageWindow = nil
    end
  end

  function imbuementApi.offline()
    self:hide()
    if context.item then
      context.item:shutdown()
    end
    if context.scroll then
      context.scroll:shutdown()
    end
    if context.selection then
      context.selection:shutdown()
    end
    if self.messageWindow then
      self.messageWindow:destroy()
      self.messageWindow = nil
    end
    self.destroyWindow()
  end

  function imbuementApi.show()
    self.ensureWindow()
    self.window:show(true)
    self.window:raise()
    self.window:focus()
    if self.messageWindow then
      self.messageWindow:destroy()
      self.messageWindow = nil
    end
  end

  function imbuementApi.hide()
    if self.window then
      self.window:hide()
    end
  end

  function imbuementApi.close()
    if g_game.isOnline() then
      g_game.closeImbuingWindow()
    end
    if self.window then
      self.window:hide()
    end
  end

  function imbuementApi:toggleMenu(menu)
    for key, value in pairs(self) do
      if type(value) == 'userdata' and key ~= 'window' then
        if key == menu then
          value:show()
          if menu == 'selectItemOrScroll' then
            self.window:setHeight(388)
          elseif menu == 'scrollImbue' then
            self.window:setHeight(655)
          elseif menu == 'selectImbue' then
            self.window:setHeight(528)
          elseif menu == 'clearImbue' then
            self.window:setHeight(502)
          end
        else
          value:hide()
        end
      end
    end
  end

  function imbuementApi.onOpenImbuementWindow()
    self.ensureWindow()
    self:show()

    local player = g_game.getLocalPlayer()
    if player then
      local bankGold = player:getResourceBalance(ResourceTypes.BANK_BALANCE) or 0
      local inventoryGold = player:getResourceBalance(ResourceTypes.GOLD_EQUIPPED) or 0
      local totalGold = bankGold + inventoryGold
      self.window.contentPanel.gold.gold:setText(context.commaValue(totalGold))
    end

    self:toggleMenu("selectItemOrScroll")
  end

  function imbuementApi.onImbuementItem(itemId, tier, slots, activeSlots, availableImbuements, needItems)
    self.ensureWindow()
    local needItemsTable = {}

    for _, item in ipairs(needItems) do
      if item and item.getId then
        local itemId = item:getId()
        local count = item:getCount() or 0
        needItemsTable[itemId] = count
      end
    end

    self:show()
    self:toggleMenu("selectImbue")
    context.item.setup(itemId, tier, slots, activeSlots, availableImbuements, needItemsTable)
  end

  function imbuementApi.onImbuementScroll(availableImbuements, needItems)
    self.ensureWindow()
    local needItemsTable = {}

    for _, item in ipairs(needItems) do
      if item and item.getId then
        local itemId = item:getId()
        local count = item:getCount() or 0
        needItemsTable[itemId] = count
      end
    end

    self:toggleMenu("scrollImbue")
    context.scroll.setup(availableImbuements, needItemsTable)
  end

  function imbuementApi.onSelectItem()
    self:hide()
    context.selection:selectItem()
  end

  function imbuementApi.onSelectScroll()
    g_game.selectImbuementScroll()
  end

  function imbuementApi.onMessageDialog(type, content)
    if type > imbuementApi.MessageDialog.ImbuingStationNotFound or not self.window or not self.window:isVisible() then
      return
    end

    self:hide()
    if self.messageWindow then
      self.messageWindow:destroy()
      self.messageWindow = nil
    end

    local function confirm()
      self.messageWindow:destroy()
      self.messageWindow = nil

      imbuementApi.show()
    end

    self.messageWindow = displayGeneralBox(tr('Message Dialog'), content or "",
      { { text=tr('Ok'), callback=confirm },
      }, confirm, confirm)
  end

  return imbuementApi
end
