-- tools tab
setDefaultTab("Tools")

-- allows to test/edit bot lua scripts ingame, you can have multiple scripts like this, just change storage.ingame_lua
UI.Button("Ingame macro editor", function(newText)
  UI.MultilineEditorWindow(storage.ingame_macros or "", {title="Macro editor", description="You can add your custom macros (or any other lua code) here"}, function(text)
    storage.ingame_macros = text
    reload()
  end)
end)
UI.Button("Ingame hotkey editor", function(newText)
  UI.MultilineEditorWindow(storage.ingame_hotkeys or "", {title="Hotkeys editor", description="You can add your custom hotkeys/singlehotkeys here"}, function(text)
    storage.ingame_hotkeys = text
    reload()
  end)
end)

UI.Separator()

for _, scripts in ipairs({storage.ingame_macros, storage.ingame_hotkeys}) do
  if type(scripts) == "string" and scripts:len() > 3 then    
    local status, result = pcall(function()
      if _VERSION == "Lua 5.1" and type(jit) ~= "table" then
        assert(loadstring(scripts))()
      else
        assert(load(scripts, "ingame_editor"))()
      end
    end)
    if not status then
      error("Ingame edior error:\n" .. result)
    end
  end
end

UI.Separator()

UI.Button("Zoom In map [ctrl + =]", function() zoomIn() end)
UI.Button("Zoom Out map [ctrl + -]", function() zoomOut() end)

UI.Separator()

local moneyIds = {3031, 3035} -- gold coin, platinium coin
macro(1000, "Exchange money", function()
  local containers = g_game.getContainers()
  for index, container in pairs(containers) do
    if not container.lootContainer then -- ignore monster containers
      for i, item in ipairs(container:getItems()) do
        if item:getCount() == 100 then
          for m, moneyId in ipairs(moneyIds) do
            if item:getId() == moneyId then
              return g_game.use(item)
            end
          end
        end
      end
    end
  end
end)

macro(1000, "Stack items", function()
  local containers = g_game.getContainers()
  local toStack = {}
  for index, container in pairs(containers) do
    if not container.lootContainer then -- ignore monster containers
      for i, item in ipairs(container:getItems()) do
        if item:isStackable() and item:getCount() < 100 then
          local stackWith = toStack[item:getId()]
          if stackWith then
            g_game.move(item, stackWith[1], math.min(stackWith[2], item:getCount()))
            return
          end
          toStack[item:getId()] = {container:getSlotPosition(i - 1), 100 - item:getCount()}
        end
      end
    end
  end
end)

macro(10000, "Anti Kick",  function()
  local dir = player:getDirection()
  turn((dir + 1) % 4)
  turn(dir)
end)

UI.Separator()
UI.Label("Drop items:")
if type(storage.dropItems) ~= "table" then
  storage.dropItems = {283, 284, 285}
end

local foodContainer = UI.Container(function(widget, items)
  storage.dropItems = items
end, true)
foodContainer:setHeight(35)
foodContainer:setItems(storage.dropItems)

macro(5000, "drop items", function()
  if not storage.dropItems[1] then return end
  if TargetBot and TargetBot.isActive() then return end -- pause when attacking
  for _, container in pairs(g_game.getContainers()) do
    for __, item in ipairs(container:getItems()) do
      for i, dropItem in ipairs(storage.dropItems) do
        if item:getId() == dropItem.id then
          if item:isStackable() then
            return g_game.move(item, player:getPosition(), item:getCount())
          else
            return g_game.move(item, player:getPosition(), dropItem.count) -- count is also subtype
          end
        end
      end
    end
  end
end)

UI.Separator()

UI.Label("Mana training")
if type(storage.manaTrain) ~= "table" then
  storage.manaTrain = {on=false, title="MP%", text="utevo lux", min=80, max=100}
end

local manatrainmacro = macro(1000, function()
  if TargetBot and TargetBot.isActive() then return end -- pause when attacking
  local mana = math.min(100, math.floor(100 * (player:getMana() / player:getMaxMana())))
  if storage.manaTrain.max >= mana and mana >= storage.manaTrain.min then
    say(storage.manaTrain.text)
  end
end)
manatrainmacro.setOn(storage.manaTrain.on)

UI.DualScrollPanel(storage.manaTrain, function(widget, newParams)
  storage.manaTrain = newParams
  manatrainmacro.setOn(storage.manaTrain.on)
end)

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
