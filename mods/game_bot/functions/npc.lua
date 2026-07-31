local context = G.botContext

context.NPC = {}

context.NPC.talk = function(text)
  if g_game.getClientVersion() >= 810 then
    g_game.talkChannel(11, 0, text)
  else
    return context.say(text)
  end
end
context.NPC.say = context.NPC.talk

context.NPC.isTrading = function()
  return modules.game_npctrade.isTrading()
end
context.NPC.hasTrade = context.NPC.isTrading
context.NPC.hasTradeWindow = context.NPC.isTrading
context.NPC.isTradeOpen = context.NPC.isTrading

context.NPC.getSellItems = function()
  if not context.NPC.isTrading() then return {} end
  local items = {}
  for i, item in ipairs(modules.game_npctrade.getSellItems()) do
    table.insert(items, {
      item = item.ptr,
      id = item.ptr:getId(),
      count = item.ptr:getCount(),
      name = item.name,
      subType = item.ptr:getSubType(),
      weight = item.weight / 100,
      price = item.price
    })
  end
  return items
end

context.NPC.getBuyItems = function()
  if not context.NPC.isTrading() then return {} end
  local items = {}
  for i, item in ipairs(modules.game_npctrade.getBuyItems()) do
    table.insert(items, {
      item = item.ptr,
      id = item.ptr:getId(),
      count = item.ptr:getCount(),
      name = item.name,
      subType = item.ptr:getSubType(),
      weight = item.weight / 100,
      price = item.price
    })
  end
  return items
end

context.NPC.getSellQuantity = function(item)
  if not context.NPC.isTrading() then return 0 end
  if type(item) == 'number' then
     item = Item.create(item)
  end
  return modules.game_npctrade.getSellQuantity(item)
end

context.NPC.canTradeItem = function(item)
  if not context.NPC.isTrading() then return false end
  if type(item) == 'number' then
     item = Item.create(item)
  end
  return modules.game_npctrade.canTradeItem(item)
end

context.NPC.sell = function(item, count, ignoreEquipped)
  if type(item) == 'number' then
    for i, entry in ipairs(context.NPC.getSellItems()) do
       if entry.id == item then
         item = entry.item
         break
       end
    end
    if type(item) == 'number' then
     item = Item.create(item)
    end
  end
  if count == 0 then
    count = 1
  end
  if count == nil or count == -1 then
    count = context.NPC.getSellQuantity(item)
  end
  if ignoreEquipped == nil then
    ignoreEquipped = true
  end
  g_game.sellItem(item, count, ignoreEquipped)
end

context.NPC.buy = function(item, count, ignoreCapacity, withBackpack)
  if type(item) == 'number' then
    for i, entry in ipairs(context.NPC.getBuyItems()) do
       if entry.id == item then
         item = entry.item
         break
       end
    end
    if type(item) == 'number' then
     item = Item.create(item)
    end
  end
  if count == nil or count <= 0 then
    count = 1
  end
  if ignoreCapacity == nil then
    ignoreCapacity = false
  end
  if withBackpack == nil then
    withBackpack = false
  end
  g_game.buyItem(item, count, ignoreCapacity, withBackpack)
end

context.NPC.sellAll = function()
  if not context.NPC.isTrading() then return false end
  modules.game_npctrade.sellAll()
end

context.NPC.closeTrade = function()
  return modules.game_npctrade.closeNpcTrade()
end
context.NPC.close = context.NPC.closeTrade
context.NPC.finish = context.NPC.closeTrade
context.NPC.endTrade = context.NPC.closeTrade
context.NPC.finishTrade = context.NPC.closeTrade
