-- tools tab
setDefaultTab("Tools")

if type(storage.moneyItems) ~= "table" then
  storage.moneyItems = {3031, 3035}
end
macro(1000, "Exchange money", function()
  if not storage.moneyItems[1] then return end
  
  -- Check for Magic Gold Converter in open containers
  local converter = nil
  for _, container in pairs(g_game.getContainers()) do
    if not container.lootContainer then
      for _, item in ipairs(container:getItems()) do
        local id = item:getId()
        if id == 26378 or id == 31181 or id == 32071 or id == 25719 then
          converter = item
          break
        end
      end
      if converter then break end
    end
  end

  local containers = g_game.getContainers()
  for index, container in pairs(containers) do
    if not container.lootContainer then
      for i, item in ipairs(container:getItems()) do
        if item:getCount() == 100 then
          for m, moneyId in ipairs(storage.moneyItems) do
            local targetId = type(moneyId) == "table" and moneyId.id or moneyId
            if item:getId() == targetId then
              if converter then
                if converter:getId() == 31181 then
                  return g_game.use(converter)
                else
                  return g_game.useWith(converter, item)
                end
              else
                return g_game.use(item)
              end
            end
          end
        end
      end
    end
  end
end)

local moneyContainer = UI.Container(function(widget, items)
  storage.moneyItems = items
end, true)
moneyContainer:setHeight(65)
moneyContainer:setItems(storage.moneyItems)

UI.Separator()

macro(60000, "Send message on trade", function()
  local trade = getChannelId("advertising")
  if not trade then
    trade = getChannelId("trade")
  end
  if trade and storage.autoTradeMessage:len() > 0 then
    sayChannel(trade, storage.autoTradeMessage)
  end
end)
UI.TextEdit(storage.autoTradeMessage or "I'm using OTClient Redemption!", function(widget, text)
  storage.autoTradeMessage = text
end)

UI.Separator()
