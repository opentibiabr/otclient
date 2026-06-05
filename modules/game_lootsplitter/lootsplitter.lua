lootsplitter = nil
advancedOptions = nil
advancedConfig = {}

function init()
  lootsplitter = g_ui.displayUI('lootsplitter')
  lootsplitter:hide()
  advancedOptions = g_ui.loadUI('advanced', g_ui.getRootWidget())
  advancedOptions:hide()
end

function terminate()
  if lootsplitter then
      lootsplitter:destroy()
      lootsplitter = nil
  end
end

function toggle()
  if lootsplitter:isVisible() then
      lootsplitter:hide()
  else
      lootsplitter:show()
  end
end

function show()
  lootsplitter:show()
end

function hide()
  lootsplitter:hide()
end

local function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

local function formatNumber(num)
  num = round(num, 0)
  local formatted = tostring(num)
  while true do
      formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
      if k == 0 then
          break
      end
  end
  return formatted
end

local function parseNumericValue(numericValue)
  numericValue = string.gsub(numericValue, "[^%d,%-]", "")
  numericValue = string.gsub(numericValue, ",", "")
  local num = tonumber(numericValue)
  if num == nil then
      error("Error processing numeric value: " .. numericValue)
  end
  return num
end

local function extractPlayerData(data, step)
  local players = {}
  local totalBalance = 0
  local numPlayers = 0

  local leaderPattern = "([%a%s'%-]+%s*%(Leader%)?)%s*Loot:%s*([%d%,]+)%s*Supplies:%s*([%d%,]+)%s*Balance:%s*([%d%,%-]+)%s*Damage:%s*[%d%,]+%s*Healing:%s*[%d%,]+"
  local playerPattern = "([%a%s'%-]+)%s*Loot:%s*([%d%,]+)%s*Supplies:%s*([%d%,]+)%s*Balance:%s*([%d%,%-]+)%s*Damage:%s*[%d%,]+%s*Healing:%s*[%d%,]+"

  local playerConfig = nil
  local leaderName, leaderLoot, leaderSupplies, leaderBalance = data:match(leaderPattern)
  if leaderName then
    local cleanLeaderName = leaderName:gsub("%s*%b()", ""):match("^%s*(.-)%s*$")
    local leaderBalanceValue = parseNumericValue(leaderBalance)

    totalBalance = totalBalance + leaderBalanceValue

    local extraCost = 0
    local isRemoved = false
    if step == 2 then
      playerConfig = getAdvancedConfig(cleanLeaderName)
      extraCost = playerConfig and playerConfig.ExtraCost or 0
      isRemoved = (playerConfig and playerConfig.isRemoved ~= nil) and playerConfig.isRemoved or false
      leaderBalanceValue = leaderBalanceValue - extraCost
      totalBalance = totalBalance - extraCost
    end

    if step == 1 or (step == 2 and not isRemoved) then
      numPlayers = numPlayers + 1

      table.insert(players, {
          Name = cleanLeaderName,
          Loot = parseNumericValue(leaderLoot),
          Supplies = parseNumericValue(leaderSupplies),
          Balance = leaderBalanceValue,
          isLeader = true
      })
    end
  end

  local remainingData = data:gsub(leaderPattern, "")
  for name, loot, supplies, balance in remainingData:gmatch(playerPattern) do
    local cleanName = name:gsub("%s*%b()", ""):match("^%s*(.-)%s*$")
    local balanceValue = parseNumericValue(balance)

    totalBalance = totalBalance + balanceValue

    local extraCost = 0
    local isRemoved = false
    if step == 2 then
      playerConfig = getAdvancedConfig(cleanName)
      extraCost = playerConfig and playerConfig.ExtraCost or 0
      isRemoved = (playerConfig and playerConfig.isRemoved ~= nil) and playerConfig.isRemoved or false
      balanceValue = balanceValue - extraCost
      totalBalance = totalBalance - extraCost
    end

    if step == 1 or (step == 2 and not isRemoved) then
      numPlayers = numPlayers + 1

      table.insert(players, {
          Name = cleanName,
          Loot = parseNumericValue(loot),
          Supplies = parseNumericValue(supplies),
          Balance = balanceValue,
          isLeader = false
      })
    end
  end

  return players, totalBalance, numPlayers
end

function processLootMessage(message)
  local sessionData = message:match("Session data:%s*(.-)%s*$")
  if not sessionData then
      return
  end

   local players, totalBalance, numPlayers = extractPlayerData(sessionData, 1)
   local playersListWidget = advancedOptions.contentPanel:getChildById('playersList')
   playersListWidget:destroyChildren()
   for _, player in ipairs(players) do
     addPlayerToList(player)
   end

  local players, totalBalance, numPlayers = extractPlayerData(sessionData, 2)
  if numPlayers == 0 then
      return
  end

  local averageProfit = totalBalance / numPlayers
  local transfers = {}
  local debtors = {}
  local creditors = {}

  for _, player in ipairs(players) do
      local profitDifference = player.Balance - averageProfit
      if profitDifference > 0 then
          table.insert(creditors, {Name = player.Name, Amount = profitDifference})
      elseif profitDifference < 0 then
          table.insert(debtors, {Name = player.Name, Amount = -profitDifference})
      end
  end

  local transferLog = ""
  for _, debtor in ipairs(debtors) do
      for _, creditor in ipairs(creditors) do
          local transferAmount = math.floor(math.min(debtor.Amount, creditor.Amount))
          if transferAmount > 0 then
              transferLog = transferLog .. string.format(
                  "- %s should transfer %s to %s\n",
                  creditor.Name, transferAmount, debtor.Name
              )

              debtor.Amount = debtor.Amount - transferAmount
              creditor.Amount = creditor.Amount - transferAmount

              if debtor.Amount <= 0 then break end
          end
      end
  end

  local resultLogContent = lootsplitter.contentPanel:getChildById('resultLogContent')
  local resultText = string.format(
      "- Loot Splitter -\n"
  )

  resultText = resultText .. "\n- Bank transfers:\n"
  resultText = resultText .. (transferLog ~= "" and transferLog or "No transfers needed.\n")

  resultText = resultText .. string.format(
      "\n- Total profit: %s $ (%s $ each)",
      formatNumber(totalBalance), formatNumber(averageProfit)
  )

  resultLogContent:setText(resultText)
  lootsplitter.fullResultText = resultText
end

function copyResultText()
  if lootsplitter.fullResultText then
      g_window.setClipboardText(lootsplitter.fullResultText)
  end
end

function onGenerateButtonClick()
  local message = lootsplitter.contentPanel:getChildById('huntLogContent'):getText()
  processLootMessage(message)
end

function showAdvancedOptions()
  lootsplitter:hide()
  advancedOptions:show()
end

function getAdvancedConfig(playerName)
  for _, playerData in pairs(advancedConfig) do
    if playerData.Name == playerName then
      return playerData
    end
  end
  return nil
end

function updateAdvancedConfigs(playerData)
  local playerExists = false
  for _, playerConfig in pairs(advancedConfig) do
    if playerConfig.Name == playerData.Name then
      playerConfig.Supplies = playerData.Supplies
      playerConfig.Balance = playerData.Balance
      playerConfig.Loot = playerData.Loot
      playerConfig.ExtraCost = playerData.ExtraCost
      playerConfig.isRemoved = playerData.isRemoved
      playerExists = true
    end
  end
  if not playerExists then
    table.insert(advancedConfig, playerData)
  end
end

function addPlayerToList(playerData)
  local playerWidget = g_ui.createWidget('PlayerOptionInfo', advancedOptions.contentPanel:getChildById('playersList'))

  local playerNameLabel = playerWidget:getChildById('playerNameLabel')
  playerNameLabel:setText(playerData.Name)

  local playerConfig = getAdvancedConfig(playerData.Name)

  local extraCostText = playerWidget:getChildById('extraCostText')
  if extraCostText then
    if playerConfig and playerConfig.ExtraCost then
      extraCostText:setText(playerConfig.ExtraCost)
    end

    extraCostText.onTextChange = function(widget)
      playerData.ExtraCost = tonumber(widget:getText()) or 0
      updateAdvancedConfigs(playerData)
    end
  end

  local removePlayerCheck = playerWidget:getChildById('removePlayer')
  if removePlayerCheck then
    if playerConfig then
      removePlayerCheck:setChecked(playerConfig.isRemoved)
      if removePlayerCheck:isChecked() then
        for _, child in ipairs(playerWidget:getChildren()) do
          if child ~= removePlayerCheck then
            child:setEnabled(false)
          end
        end
      end
    end
    removePlayerCheck.onCheckChange = function(widget)
      if widget:isChecked() then
        for _, child in ipairs(playerWidget:getChildren()) do
          if child ~= removePlayerCheck then
            child:setEnabled(false)
          end
        end
        playerData.isRemoved = true
      else
        for _, child in ipairs(playerWidget:getChildren()) do
          if child ~= removePlayerCheck then
            child:setEnabled(true)
          end
        end
        playerData.isRemoved = false
      end
      updateAdvancedConfigs(playerData)
    end
  end
end

function applyChanges()
  advancedOptions:hide() 
  lootsplitter:show()
  onGenerateButtonClick()
end