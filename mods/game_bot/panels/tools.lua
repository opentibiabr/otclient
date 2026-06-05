local context = G.botContext
local Panels = context.Panels

Panels.TradeMessage = function(parent)
  context.macro(60000, "Send message on trade", nil, function()
    local trade = context.getChannelId("advertising")
    if not trade then
      trade = context.getChannelId("trade")
    end
    if context.storage.autoTradeMessage:len() > 0 and trade then
      context.sayChannel(trade, context.storage.autoTradeMessage)
    end
  end, parent)
  context.addTextEdit("autoTradeMessage", context.storage.autoTradeMessage or "I'm using OTClient Redemption - https://github.com/mehah/otclient", function(widget, text)
    context.storage.autoTradeMessage = text
  end, parent)
end

Panels.AutoStackItems = function(parent)
  context.macro(500, "Auto stacking items", nil, function()
    local containers = context.getContainers()
    for i, container in pairs(containers) do
      local toStack = {}
      for j, item in ipairs(container:getItems()) do
        if item:isStackable() and item:getCount() ~= 100 then
          local otherItem = toStack[item:getId()]
          if otherItem then
            g_game.move(item, otherItem, item:getCount())
            return
          end
          toStack[item:getId()] = container:getSlotPosition(j - 1)
        end
      end
    end
  end, parent)
end
