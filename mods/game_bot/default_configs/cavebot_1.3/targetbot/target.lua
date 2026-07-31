local targetbotMacro = nil
local config = nil
local lastAction = 0
local cavebotAllowance = 0
local lureEnabled = true
local dangerValue = 0

-- ui
local configWidget = UI.Config()
local ui = UI.createWidget("TargetBotPanel")

ui.list = ui.listPanel.list -- shortcut
TargetBot.targetList = ui.list
TargetBot.Looting.setup()

ui.status.left:setText("Status:")
ui.status.right:setText("Off")
ui.target.left:setText("Target:")
ui.target.right:setText("-")
ui.config.left:setText("Config:")
ui.config.right:setText("-")
ui.danger.left:setText("Danger:")
ui.danger.right:setText("0")

ui.editor.debug.onClick = function()
  local on = ui.editor.debug:isOn()
  ui.editor.debug:setOn(not on)
  if on then
    for _, spec in ipairs(getSpectators()) do
      spec:clearText()
    end
  end
end

-- main loop, controlled by config
targetbotMacro = macro(100, function()
  local pos = player:getPosition()
  local creatures = g_map.getSpectatorsInRange(pos, false, 6, 6) -- 12x12 area
  if #creatures > 10 then -- if there are too many monsters around, limit area
    creatures = g_map.getSpectatorsInRange(pos, false, 3, 3) -- 6x6 area
  end
  local highestPriority = 0
  local dangerLevel = 0
  local targets = 0
  local highestPriorityParams = nil
  for i, creature in ipairs(creatures) do
    local path = findPath(player:getPosition(), creature:getPosition(), 7, {ignoreLastCreature=true, ignoreNonPathable=true, ignoreCost=true})
    if creature:isMonster() and path then
      local params = TargetBot.Creature.calculateParams(creature, path) -- return {craeture, config, danger, priority}
      dangerLevel = dangerLevel + params.danger
      if params.priority > 0 then
        targets = targets + 1
        if params.priority > highestPriority then
          highestPriority = params.priority
          highestPriorityParams = params
        end
        if ui.editor.debug:isOn() then
          creature:setText(params.config.name .. "\n" .. params.priority)
        end
      end
    end
  end

  -- reset walking
  TargetBot.walkTo(nil)

  -- looting
  local looting = TargetBot.Looting.process(targets, dangerLevel)
  local lootingStatus = TargetBot.Looting.getStatus()

  dangerValue = dangerLevel
  ui.danger.right:setText(dangerLevel)
  if highestPriorityParams and not isInPz() then
    ui.target.right:setText(highestPriorityParams.creature:getName())
    ui.config.right:setText(highestPriorityParams.config.name)
    TargetBot.Creature.attack(highestPriorityParams, targets, looting)
    if lootingStatus:len() > 0 then
      TargetBot.setStatus("Attack & " .. lootingStatus)
    elseif cavebotAllowance > now then
      TargetBot.setStatus("Luring using CaveBot")
    else
      TargetBot.setStatus("Attacking")
      if not lureEnabled then
        TargetBot.setStatus("Attacking (luring off)")
      end
    end
    TargetBot.walk()
    lastAction = now
    return
  end

  ui.target.right:setText("-")
  ui.config.right:setText("-")
  if looting then
    TargetBot.walk()
    lastAction = now
  end
  if lootingStatus:len() > 0 then
    TargetBot.setStatus(lootingStatus)
  else
    TargetBot.setStatus("Waiting")
  end
end)

-- config, its callback is called immediately, data can be nil
config = Config.setup("targetbot_configs", configWidget, "json", function(name, enabled, data)
  if not data then
    ui.status.right:setText("Off")
    return targetbotMacro.setOff()
  end
  TargetBot.Creature.resetConfigs()
  for _, value in ipairs(data["targeting"] or {}) do
    TargetBot.Creature.addConfig(value)
  end
  TargetBot.Looting.update(data["looting"] or {})

  -- add configs
  if enabled then
    ui.status.right:setText("On")
  else
    ui.status.right:setText("Off")
  end

  targetbotMacro.setOn(enabled)
  targetbotMacro.delay = nil
  lureEnabled = true
end)

-- setup ui
ui.editor.buttons.add.onClick = function()
  TargetBot.Creature.edit(nil, function(newConfig)
    TargetBot.Creature.addConfig(newConfig, true)
    TargetBot.save()
  end)
end

ui.editor.buttons.edit.onClick = function()
  local entry = ui.list:getFocusedChild()
  if not entry then return end
  TargetBot.Creature.edit(entry.value, function(newConfig)
    entry:setText(newConfig.name)
    entry.value = newConfig
    TargetBot.Creature.resetConfigsCache()
    TargetBot.save()
  end)
end

ui.editor.buttons.remove.onClick = function()
  local entry = ui.list:getFocusedChild()
  if not entry then return end
  entry:destroy()
  TargetBot.Creature.resetConfigsCache()
  TargetBot.save()
end

-- public function, you can use them in your scripts
TargetBot.isActive = function() -- return true if attacking or looting takes place
  return lastAction + 300 > now
end

TargetBot.isCaveBotActionAllowed = function()
  return cavebotAllowance > now
end

TargetBot.setStatus = function(text)
  return ui.status.right:setText(text)
end

TargetBot.isOn = function()
  return config.isOn()
end

TargetBot.isOff = function()
  return config.isOff()
end

TargetBot.setOn = function(val)
  if val == false then
    return TargetBot.setOff(true)
  end
  config.setOn()
end

TargetBot.setOff = function(val)
  if val == false then
    return TargetBot.setOn(true)
  end
  config.setOff()
end

TargetBot.delay = function(value)
  targetbotMacro.delay = now + value
end

TargetBot.save = function()
  local data = {targeting={}, looting={}}
  for _, entry in ipairs(ui.list:getChildren()) do
    table.insert(data.targeting, entry.value)
  end
  TargetBot.Looting.save(data.looting)
  config.save(data)
end

TargetBot.allowCaveBot = function(time)
  cavebotAllowance = now + time
end

TargetBot.disableLuring = function()
  lureEnabled = false
end

TargetBot.enableLuring = function()
  lureEnabled = true
end

TargetBot.Danger = function()
  if not TargetBot.isOn() then
    return 0
  end
  return dangerValue
end

-- attacks
local lastSpell = 0
local lastAttackSpell = 0

TargetBot.saySpell = function(text, delay)
  if type(text) ~= 'string' or text:len() < 1 then return end
  if not delay then delay = 500 end
  if g_game.getProtocolVersion() < 1090 then
    lastAttackSpell = now -- pause attack spells, healing spells are more important
  end
  if lastSpell + delay < now then
    say(text)
    lastSpell = now
    return true
  end
  return false
end

TargetBot.sayAttackSpell = function(text, delay)
  if type(text) ~= 'string' or text:len() < 1 then return end
  if not delay then delay = 2000 end
  if lastAttackSpell + delay < now then
    say(text)
    lastAttackSpell = now
    return true
  end
  return false
end

local lastItemUse = 0
local lastRuneAttack = 0

TargetBot.useItem = function(item, subType, target, delay)
  if not delay then delay = 200 end
  if lastItemUse + delay < now then
    local thing = g_things.getThingType(item)
    if not thing or not thing:isFluidContainer() then
      subType = g_game.getClientVersion() >= 860 and 0 or 1
    end
    if g_game.getClientVersion() < 780 then
      local tmpItem = g_game.findPlayerItem(item, subType)
      if not tmpItem then return end
      g_game.useWith(tmpItem, target, subType) -- using item from bp
    else
      g_game.useInventoryItemWith(item, target, subType) -- hotkey
    end
    lastItemUse = now
  end
end

TargetBot.useAttackItem = function(item, subType, target, delay)
  if not delay then delay = 2000 end
  if lastRuneAttack + delay < now then
    local thing = g_things.getThingType(item)
    if not thing or not thing:isFluidContainer() then
      subType = g_game.getClientVersion() >= 860 and 0 or 1
    end
    if g_game.getClientVersion() < 780 then
      local tmpItem = g_game.findPlayerItem(item, subType)
      if not tmpItem then return end
      g_game.useWith(tmpItem, target, subType) -- using item from bp
    else
      g_game.useInventoryItemWith(item, target, subType) -- hotkey
    end
    lastRuneAttack = now
  end
end

TargetBot.canLure = function()
  return lureEnabled
end
