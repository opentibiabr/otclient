if not Imbuement then
  Imbuement = {
    window = nil,
    selectItemOrScroll = nil,
    scrollImbue = nil,
    selectImbue = nil,
    clearImbue = nil,

    messageWindow = nil,

    bankGold = 0,
    inventoryGold = 0,
  }
  Imbuement.__index = Imbuement
end

-- Funcao auxiliar para calcular a posicao de um sprite em um spritesheet
function getFramePosition(frameIndex, frameWidth, frameHeight, columns)
  local row = math.floor(frameIndex / columns)
  local col = frameIndex % columns
  local x = col * frameWidth
  local y = row * frameHeight
  return string.format("%d %d", x, y)
end

-- Funcao auxiliar para obter o saldo total do player (banco + inventario)
function getPlayerBalance()
  local player = g_game.getLocalPlayer()
  if not player then return 0 end
  
  local bankGold = player:getResourceBalance(1) or 0  -- BANK_BALANCE
  local inventoryGold = player:getResourceBalance(0) or 0  -- GOLD_EQUIPPED
  return bankGold + inventoryGold
end

-- Funcao auxiliar para formatar numeros com virgulas (separador de milhares)
function comma_value(amount)
  if not amount then return "0" end
  local formatted = tostring(amount)
  -- Usar virgula como separador de milhares (formato: 5,561,475)
  while true do  
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if k == 0 then break end
  end
  return formatted
end

-- Adicionar capitalize a string se nao existir
if not string.capitalize then
  function string.capitalize(str)
    if not str or str == "" then return str end
    return str:sub(1, 1):upper() .. str:sub(2)
  end
end

-- Funcao auxiliar para obter o nome de um item por ID
function getItemNameById(itemId)
  local itemType = g_things.getThingType(itemId, ThingCategoryItem)
  if itemType and itemType.getName and type(itemType.getName) == "function" then
    return itemType:getName() or "Unknown Item"
  end
  return "Unknown Item"
end

Imbuement.MessageDialog = {
	ImbuementSuccess = 0,
	ImbuementError = 1,
	ImbuementRollFailed = 2,
	ImbuingStationNotFound = 3,
	ClearingCharmSuccess = 10,
	ClearingCharmError = 11,
	PreyMessage = 20,
	PreyError = 21,
}

local self = Imbuement
function Imbuement.init()
  self.window = g_ui.displayUI('t_imbui')
  self:hide()

  ImbuementSelection:startUp()

  self.selectItemOrScroll = self.window:recursiveGetChildById('selectItemOrScroll')
  self.scrollImbue = self.window:recursiveGetChildById('scrollImbue')
  self.selectImbue = self.window:recursiveGetChildById('selectImbue')
  self.clearImbue = self.window:recursiveGetChildById('clearImbue')

  connect(g_game, {
    onGameStart = self.offline,
    onGameEnd = self.offline,
    onOpenImbuementWindow = self.onOpenImbuementWindow,
    onImbuementItem = self.onImbuementItem,
    onImbuementScroll = self.onImbuementScroll,
    onCloseImbuementWindow = self.offline,
    onMessageDialog = self.onMessageDialog,
  })
end

function Imbuement.terminate()
  disconnect(g_game, {
    onGameStart = self.offline,
    onGameEnd = self.offline,
    onOpenImbuementWindow = self.onOpenImbuementWindow,
    onImbuementItem = self.onImbuementItem,
    onImbuementScroll = self.onImbuementScroll,
    onResourceBalance = self.onResourceBalance,
    onCloseImbuementWindow = self.offline,
    onMessageDialog = self.onMessageDialog,
  })


  if self.messageWindow then
    self.messageWindow:destroy()
    self.messageWindow = nil
  end

  ImbuementItem:shutdown()
  ImbuementSelection:shutdown()
  ImbuementScroll:shutdown()
  if self.selectItemOrScroll then
    self.selectItemOrScroll:destroy()
    self.selectItemOrScroll = nil
  end

  if self.scrollImbue then
    self.scrollImbue:destroy()
    self.scrollImbue = nil
  end

  if self.selectImbue then
    self.selectImbue:destroy()
    self.selectImbue = nil
  end

  if self.clearImbue then
    self.clearImbue:destroy()
    self.clearImbue = nil
  end

  if self.window then
    self.window:destroy()
    self.window = nil
  end
end

function Imbuement.online()
 self:hide()
 if self.messageWindow then
   self.messageWindow:destroy()
   self.messageWindow = nil
 end
end

function Imbuement.offline()
  self:hide()
  ImbuementItem:shutdown()
  ImbuementScroll:shutdown()
  if self.messageWindow then
    self.messageWindow:destroy()
    self.messageWindow = nil
  end
end

function Imbuement.show()
  self.window:show(true)
  self.window:raise()
  self.window:focus()
  if self.messageWindow then
    self.messageWindow:destroy()
    self.messageWindow = nil
  end
end

function Imbuement.hide()
  self.window:hide()
end

function Imbuement.close()
  if g_game.isOnline() then
    g_game.closeImbuingWindow()
  end
  self.window:hide()
end

function Imbuement:toggleMenu(menu)
  for key, value in pairs(self) do
    if type(value) == 'userdata' and key ~= 'window' then
      if key == menu then
        value:show()
        -- Ajustar tamanho da janela baseado no menu
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

function Imbuement.onOpenImbuementWindow()
  self:show()
  -- Atualizar recursos do player
  local player = g_game.getLocalPlayer()
  if player then
    local bankGold = player:getResourceBalance(ResourceTypes.BANK_BALANCE) or 0
    local inventoryGold = player:getResourceBalance(ResourceTypes.GOLD_EQUIPPED) or 0
    local totalGold = bankGold + inventoryGold
    self.window.contentPanel.gold.gold:setText(comma_value(totalGold))
  end
  self:toggleMenu("selectItemOrScroll")
end

-- Funcao para contar itens no inventario do jogador
function getPlayerItemCount(itemId)
  local player = g_game.getLocalPlayer()
  if not player then return 0 end
  
  local totalCount = 0
  
  -- Contar nos slots do inventario
  for slot = InventorySlotFirst, InventorySlotLast do
    local item = player:getInventoryItem(slot)
    if item then
      if item:getId() == itemId then
        totalCount = totalCount + item:getCount()
      end
    end
  end
  
  return totalCount
end

function Imbuement.onImbuementItem(itemId, tier, slots, activeSlots, availableImbuements, needItems)
  local needItemsTable = {}
  
  for i, item in ipairs(needItems) do
    if item and item.getId then
      local itemId = item:getId()
      local count = item:getCount() or 0
      needItemsTable[itemId] = count
    end
  end
  
  self:show()
  self:toggleMenu("selectImbue")
  ImbuementItem.setup(itemId, tier, slots, activeSlots, availableImbuements, needItemsTable)
end

function Imbuement.onImbuementScroll(availableImbuements, needItems)
  -- Converter needItems de array de Items para tabela {itemId -> count}
  -- USAR O COUNT QUE VEM DO SERVIDOR (ja esta no Item)
  local needItemsTable = {}
  
  for i, item in ipairs(needItems) do
    if item and item.getId then
      local itemId = item:getId()
      local count = item:getCount() or 0  -- Usar o count que o servidor enviou
      needItemsTable[itemId] = count
    end
  end
  
  self:toggleMenu("scrollImbue")
  ImbuementScroll.setup(availableImbuements, needItemsTable)
end

function Imbuement.onSelectItem()
  self:hide()
  ImbuementSelection:selectItem()
end

function Imbuement.onSelectScroll()
  g_game.selectImbuementScroll()
end

function Imbuement.onMessageDialog(type, content)
  if type > Imbuement.MessageDialog.ImbuingStationNotFound or not self.window:isVisible() then
    return
  end

  self:hide()
  local message = content or ""
  if self.messageWindow then
    self.messageWindow:destroy()
    self.messageWindow = nil
  end

  local function confirm()
      self.messageWindow:destroy()
      self.messageWindow = nil

      Imbuement.show()
  end

  self.messageWindow = displayGeneralBox(tr('Message Dialog'), content,
    { { text=tr('Ok'), callback=confirm },
    }, confirm, confirm)


  -- g_client.setInputLockWidget(self.messageWindow) -- deprecated
end