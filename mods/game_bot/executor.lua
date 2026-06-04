function executeBot(config, storage, tabs, msgCallback, saveConfigCallback, reloadCallback, websockets)
  -- load lua and otui files
  local configFiles = g_resources.listDirectoryFiles("/bot/" .. config, true, false)
  local luaFiles = {}
  local uiFiles = {}
  for i, file in ipairs(configFiles) do
    local ext = file:split(".")
    if ext[#ext]:lower() == "lua" then
      table.insert(luaFiles, file)
    end
    if ext[#ext]:lower() == "ui" or ext[#ext]:lower() == "otui" then
      table.insert(uiFiles, file)
    end
  end

  if #luaFiles == 0 then
    return error("Config (/bot/" .. config .. ") doesn't have lua files")
  end

  -- init bot variables
  local context = {}
  context.configDir = "/bot/".. config
  context.tabs = tabs
  context.mainTab = context.tabs:addTab("Main", g_ui.createWidget('BotPanel')).tabPanel.content
  context.panel = context.mainTab
  context.saveConfig = saveConfigCallback
  context.reload = reloadCallback

  context.storage = storage
  if context.storage._macros == nil then
    context.storage._macros = {} -- active macros
  end

  -- websockets, macros, hotkeys, scheduler, icons, callbacks
  context._websockets = websockets
  context._macros = {}
  context._hotkeys = {}
  context._scheduler = {}
  context._callbacks = {
    onKeyDown = {},
    onKeyUp = {},
    onKeyPress = {},
    onTalk = {},
    onTextMessage = {},
    onLoginAdvice = {},
    onAddThing = {},
    onRemoveThing = {},
    onCreatureAppear = {},
    onCreatureDisappear = {},
    onCreaturePositionChange = {},
    onCreatureHealthPercentChange = {},
    onUse = {},
    onUseWith = {},
    onContainerOpen = {},
    onContainerClose = {},
    onContainerUpdateItem = {},
    onMissle = {},
    onAnimatedText = {},
    onStaticText = {},
    onChannelList = {},
    onOpenChannel = {},
    onCloseChannel = {},
    onChannelEvent = {},
    onTurn = {},
    onWalk = {},
    onImbuementWindow = {},
    onModalDialog = {},
    onAttackingCreatureChange = {},
    onManaChange = {},
    onStatesChange = {},
    onAddItem = {},
    onGameEditText = {},
    onGroupSpellCooldown = {},
    onSpellCooldown = {},
    onRemoveItem = {},
    onInventoryChange = {}
  }

  -- basic functions & classes
  context.print = print
  context.bit32 = bit32
  context.bit = bit
  context.pairs = pairs
  context.ipairs = ipairs
  context.tostring = tostring
  context.math = math
  context.table = table
  context.setmetatable = setmetatable
  context.string = string
  context.tonumber = tonumber
  context.type = type
  context.pcall = pcall
  context.os = {
    time = os.time,
    difftime = os.difftime,
    date = os.date,
    clock = os.clock
  }
  if _VERSION == "Lua 5.1" and type(jit) ~= "table" then
    context.load = function(str)
      local func = assert(loadstring(str))
      setfenv(func, context)
      return func
    end
    context.dofile = function(file) 
      local func = assert(loadstring(g_resources.readFileContents("/bot/" .. config .. "/" .. file)))
      setfenv(func, context)
      func()
    end
  else
    context.load = function(str) return assert(load(str, nil, nil, context)) end
    context.dofile = function(file) assert(load(g_resources.readFileContents("/bot/" .. config .. "/" .. file), file, nil, context))() end
  end
  context.loadstring = context.load
  context.assert = assert
  context.gcinfo = gcinfo
  context.tr = tr
  context.json = json
  context.base64 = base64
  context.regexMatch = regexMatch
  context.getDistanceBetween = function(p1, p2)
    return math.max(math.abs(p1.x - p2.x), math.abs(p1.y - p2.y))
  end
  context.isMobile = g_app.isMobile
  context.getVersion = g_app.getVersion

  -- classes
  context.g_resources = g_resources
  context.g_game = g_game
  context.g_map = g_map
  context.g_ui = g_ui
  context.g_sounds = g_sounds
  context.g_window = g_window
  context.g_mouse = g_mouse
  context.g_keyboard = g_keyboard
  context.g_things = g_things
  context.g_settings = g_settings
  context.g_platform = {
    openUrl = g_platform.openUrl,
    openDir = g_platform.openDir,
  }

  context.Item = Item
  context.Creature = Creature
  context.ThingType = ThingType
  context.Effect = Effect
  context.Missile = Missile
  context.Player = Player
  context.Monster = Monster
  context.StaticText = StaticText
  context.HTTP = HTTP
  context.OutputMessage = OutputMessage
  context.modules = modules
  context.Directions = Directions

  -- log functions
  context.info = function(text) return msgCallback("info", tostring(text)) end
  context.warn = function(text) return msgCallback("warn", tostring(text)) end
  context.error = function(text) return msgCallback("error", tostring(text)) end
  context.warning = context.warn

  -- init context
  context.now = g_clock.millis()
  context.time = g_clock.millis()
  context.player = g_game.getLocalPlayer()

  -- init functions
  G.botContext = context
  dofiles("functions")
  context.Panels = {}
  dofiles("panels")
  G.botContext = nil

  -- run ui scripts
  for i, file in ipairs(uiFiles) do
    g_ui.importStyle(file)
  end

  -- run lua script
  for i, file in ipairs(luaFiles) do
      if _VERSION == "Lua 5.1" and type(jit) ~= "table" then
        local func = assert(loadstring(g_resources.readFileContents(file)))
        setfenv(func, context)
        func()
      else
        assert(load(g_resources.readFileContents(file), file, nil, context))()
      end
    context.panel = context.mainTab -- reset default tab
  end

  return {
    script = function()
      context.now = g_clock.millis()
      context.time = g_clock.millis()

      for i, macro in ipairs(context._macros) do
        if macro.lastExecution + macro.timeout <= context.now and macro.enabled then
          local status, result = pcall(function()
            if macro.callback(macro) then
                macro.lastExecution = context.now
            end
          end)
          if not status then
            context.error("Macro: " .. macro.name .. " execution error: " .. result)
          end
        end
      end

      while #context._scheduler > 0 and context._scheduler[1].execution <= g_clock.millis() do
        local status, result = pcall(function()
          context._scheduler[1].callback()
        end)
        if not status then
          context.error("Schedule execution error: " .. result)
        end
        table.remove(context._scheduler, 1)
      end
    end,
    callbacks = {
      onKeyDown = function(keyCode, keyboardModifiers)
        local keyDesc = determineKeyComboDesc(keyCode, keyboardModifiers)
        for i, macro in ipairs(context._macros) do
          if macro.switch and macro.hotkey == keyDesc then
            macro.switch:onClick()
          end
        end
        local hotkey = context._hotkeys[keyDesc]
        if hotkey then
          if hotkey.single then
            if hotkey.callback() then
              hotkey.lastExecution = context.now
            end
          end
          if hotkey.switch then
            hotkey.switch:setOn(true)
          end
        end
        for i, callback in ipairs(context._callbacks.onKeyDown) do
          callback(keyDesc)
        end
      end,
      onKeyUp = function(keyCode, keyboardModifiers)
        local keyDesc = determineKeyComboDesc(keyCode, keyboardModifiers)
        local hotkey = context._hotkeys[keyDesc]
        if hotkey then
          if hotkey.switch then
            hotkey.switch:setOn(false)
          end
        end
        for i, callback in ipairs(context._callbacks.onKeyUp) do
          callback(keyDesc)
        end
      end,
      onKeyPress = function(keyCode, keyboardModifiers, autoRepeatTicks)
        local keyDesc = determineKeyComboDesc(keyCode, keyboardModifiers)
        local hotkey = context._hotkeys[keyDesc]
        if hotkey and not hotkey.single then
          if hotkey.callback() then
            hotkey.lastExecution = context.now
          end
        end
        for i, callback in ipairs(context._callbacks.onKeyPress) do
          callback(keyDesc, autoRepeatTicks)
        end
      end,
      onTalk = function(name, level, mode, text, channelId, pos)
        for i, callback in ipairs(context._callbacks.onTalk) do
          callback(name, level, mode, text, channelId, pos)
        end
      end,
      onImbuementWindow = function(itemId, slots, activeSlots, imbuements, needItems)
        for i, callback in ipairs(context._callbacks.onImbuementWindow) do
          callback(itemId, slots, activeSlots, imbuements, needItems)
        end
      end,
      onTextMessage = function(mode, text)
        for i, callback in ipairs(context._callbacks.onTextMessage) do
          callback(mode, text)
        end
      end,
      onLoginAdvice = function(message)
        for i, callback in ipairs(context._callbacks.onLoginAdvice) do
          callback(message)
        end
      end,
      onAddThing = function(tile, thing)
        for i, callback in ipairs(context._callbacks.onAddThing) do
          callback(tile, thing)
        end
      end,
      onRemoveThing = function(tile, thing)
        for i, callback in ipairs(context._callbacks.onRemoveThing) do
          callback(tile, thing)
        end
      end,
      onCreatureAppear = function(creature)
        for i, callback in ipairs(context._callbacks.onCreatureAppear) do
          callback(creature)
        end
      end,
      onCreatureDisappear = function(creature)
        for i, callback in ipairs(context._callbacks.onCreatureDisappear) do
          callback(creature)
        end
      end,
      onCreaturePositionChange = function(creature, newPos, oldPos)
        for i, callback in ipairs(context._callbacks.onCreaturePositionChange) do
          callback(creature, newPos, oldPos)
        end
      end,
      onCreatureHealthPercentChange = function(creature, healthPercent)
        for i, callback in ipairs(context._callbacks.onCreatureHealthPercentChange) do
          callback(creature, healthPercent)
        end
      end,
      onUse = function(pos, itemId, stackPos, subType)
        for i, callback in ipairs(context._callbacks.onUse) do
          callback(pos, itemId, stackPos, subType)
        end
      end,
      onUseWith = function(pos, itemId, target, subType)
        for i, callback in ipairs(context._callbacks.onUseWith) do
          callback(pos, itemId, target, subType)
        end
      end,
      onContainerOpen = function(container, previousContainer)
        for i, callback in ipairs(context._callbacks.onContainerOpen) do
          callback(container, previousContainer)
        end
      end,
      onContainerClose = function(container)
        for i, callback in ipairs(context._callbacks.onContainerClose) do
          callback(container)
        end
      end,
      onContainerUpdateItem = function(container, slot, item, oldItem)
        for i, callback in ipairs(context._callbacks.onContainerUpdateItem) do
          callback(container, slot, item, oldItem)
        end
      end,
      onMissle = function(missle)
        for i, callback in ipairs(context._callbacks.onMissle) do
          callback(missle)
        end
      end,
      onAnimatedText = function(thing, text)
        for i, callback in ipairs(context._callbacks.onAnimatedText) do
          callback(thing, text)
        end
      end,
      onStaticText = function(thing, text)
        for i, callback in ipairs(context._callbacks.onStaticText) do
          callback(thing, text)
        end
      end,
      onChannelList = function(channels)
        for i, callback in ipairs(context._callbacks.onChannelList) do
          callback(channels)
        end
      end,
      onOpenChannel = function(channelId, channelName)
        for i, callback in ipairs(context._callbacks.onOpenChannel) do
          callback(channels)
        end
      end,
      onCloseChannel = function(channelId)
        for i, callback in ipairs(context._callbacks.onCloseChannel) do
          callback(channelId)
        end
      end,
      onChannelEvent = function(channelId, name, event)
        for i, callback in ipairs(context._callbacks.onChannelEvent) do
          callback(channelId, name, event)
        end
      end,
      onTurn = function(creature, direction)
        for i, callback in ipairs(context._callbacks.onTurn) do
          callback(creature, direction)
        end
      end,
      onWalk = function(creature, oldPos, newPos)
        for i, callback in ipairs(context._callbacks.onWalk) do
          callback(creature, oldPos, newPos)
        end
      end,
      onModalDialog = function(id, title, message, buttons, enterButton, escapeButton, choices, priority)
        for i, callback in ipairs(context._callbacks.onModalDialog) do
          callback(id, title, message, buttons, enterButton, escapeButton, choices, priority)
        end
      end,
      onGameEditText = function(id, itemId, maxLength, text, writer, time)
        for i, callback in ipairs(context._callbacks.onGameEditText) do
          callback(id, itemId, maxLength, text, writer, time)
        end
      end,
      onAttackingCreatureChange = function(creature, oldCreature)
        for i, callback in ipairs(context._callbacks.onAttackingCreatureChange) do
          callback(creature, oldCreature)
        end
      end,
      onManaChange = function(player, mana, maxMana, oldMana, oldMaxMana)
        for i, callback in ipairs(context._callbacks.onManaChange) do
          callback(player, mana, maxMana, oldMana, oldMaxMana)
        end
      end,
      onAddItem = function(container, slot, item)
        for i, callback in ipairs(context._callbacks.onAddItem) do
          callback(container, slot, item)
        end
      end,
      onRemoveItem = function(container, slot, item)
        for i, callback in ipairs(context._callbacks.onRemoveItem) do
          callback(container, slot, item)
        end
      end,
      onStatesChange = function(player, states, oldStates)
        for i, callback in ipairs(context._callbacks.onStatesChange) do
          callback(player, states, oldStates)
        end
      end,
      onGroupSpellCooldown = function(iconId, duration)
        for i, callback in ipairs(context._callbacks.onGroupSpellCooldown) do
          callback(iconId, duration)
        end
      end,
      onSpellCooldown = function(iconId, duration)
        for i, callback in ipairs(context._callbacks.onSpellCooldown) do
          callback(iconId, duration)
        end
      end,
      onInventoryChange = function(player, slot, item, oldItem)
        for i, callback in ipairs(context._callbacks.onInventoryChange) do
          callback(player, slot, item, oldItem)
        end
      end
    }
  }
end
