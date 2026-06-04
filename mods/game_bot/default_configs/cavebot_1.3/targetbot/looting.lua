TargetBot.Looting = {}
TargetBot.Looting.list = {} -- list of containers to loot

local ui
local items = {}
local containers = {}
local itemsById = {}
local containersById = {}
local dontSave = false

TargetBot.Looting.setup = function()
  ui = UI.createWidget("TargetBotLootingPanel")
  UI.Container(TargetBot.Looting.onItemsUpdate, true, nil, ui.items)
  UI.Container(TargetBot.Looting.onContainersUpdate, true, nil, ui.containers)
  ui.everyItem.onClick = function()
    ui.everyItem:setOn(not ui.everyItem:isOn())
    TargetBot.save()
  end
  ui.maxDangerPanel.value.onTextChange = function()
    local value = tonumber(ui.maxDangerPanel.value:getText())
    if not value then
      ui.maxDangerPanel.value:setText(0)
    end
    if dontSave then return end
    TargetBot.save()
  end
  ui.minCapacityPanel.value.onTextChange = function()
    local value = tonumber(ui.minCapacityPanel.value:getText())
    if not value then
      ui.minCapacityPanel.value:setText(0)
    end
    if dontSave then return end
    TargetBot.save()
  end
end

TargetBot.Looting.onItemsUpdate = function()
  if dontSave then return end
  TargetBot.save()
  TargetBot.Looting.updateItemsAndContainers()
end

TargetBot.Looting.onContainersUpdate = function()
  if dontSave then return end
  TargetBot.save()
  TargetBot.Looting.updateItemsAndContainers()
end

TargetBot.Looting.update = function(data)
  dontSave = true
  TargetBot.Looting.list = {}
  ui.items:setItems(data['items'] or {})
  ui.containers:setItems(data['containers'] or {})
  ui.everyItem:setOn(data['everyItem'])
  ui.maxDangerPanel.value:setText(data['maxDanger'] or 10)
  ui.minCapacityPanel.value:setText(data['minCapacity'] or 100)
  TargetBot.Looting.updateItemsAndContainers()
  dontSave = false
end

TargetBot.Looting.save = function(data)
  data['items'] = ui.items:getItems()
  data['containers'] = ui.containers:getItems()
  data['maxDanger'] = tonumber(ui.maxDangerPanel.value:getText())
  data['minCapacity'] = tonumber(ui.minCapacityPanel.value:getText())
  data['everyItem'] = ui.everyItem:isOn()
end

TargetBot.Looting.updateItemsAndContainers = function()
  items = ui.items:getItems()
  containers = ui.containers:getItems()
  itemsById = {}
  containersById = {}
  for i, item in ipairs(items) do
    itemsById[item.id] = 1
  end
  for i, container in ipairs(containers) do
    containersById[container.id] = 1
  end
end

local waitTill = 0
local waitingForContainer = nil
local status = ""
local lastFoodConsumption = 0

TargetBot.Looting.getStatus = function()
  return status
end

TargetBot.Looting.process = function(targets, dangerLevel)
  if (not items[1] and not ui.everyItem:isOn()) or not containers[1] then
    status = ""
    return false
  end
  if dangerLevel > tonumber(ui.maxDangerPanel.value:getText()) then
    status = "High danger"
    return false
  end
  if player:getFreeCapacity() < tonumber(ui.minCapacityPanel.value:getText()) then
    status = "No cap"
    TargetBot.Looting.list = {}
    return false
  end
  local loot = TargetBot.Looting.list[1]
  if loot == nil then
    status = ""
    return false
  end

  if waitTill > now then
    return true
  end
  local containers = g_game.getContainers()
  local lootContainers = TargetBot.Looting.getLootContainers(containers)

  -- check if there's container for loot and has empty space for it
  if not lootContainers[1] then
    -- there's no space, don't loot
    status = "No space"
    return false
  end

  status = "Looting"

  for index, container in pairs(containers) do
    if container.lootContainer then
      TargetBot.Looting.lootContainer(lootContainers, container)
      return true
    end
  end

  local pos = player:getPosition()
  local dist = math.max(math.abs(pos.x-loot.pos.x), math.abs(pos.y-loot.pos.y))
  if loot.tries > 30 or loot.pos.z ~= pos.z or dist > 20 then
    table.remove(TargetBot.Looting.list, 1)
    return true
  end

  local tile = g_map.getTile(loot.pos)
  local minDist = 2
  local walkPrecision = 2
  if g_game.getClientVersion() <= 760 then
    -- In Tibia 7.6 and earlier, corpses must be looted from adjacent tiles (distance 1)
    -- Later versions allow looting from larger distance. We use 760 as cutoff, but the exact
    -- version when CipSoft changed this is unknown
    minDist = 1
    walkPrecision = 1
  end
  if dist > minDist or not tile then
    loot.tries = loot.tries + 1
    TargetBot.walkTo(loot.pos, 20, { ignoreNonPathable = true, precision = walkPrecision })
    return true
  end

  local container = tile:getTopUseThing()
  if not container or not container:isContainer() then
    table.remove(TargetBot.Looting.list, 1)
    return true
  end

  g_game.open(container)
  waitTill = now + 1000 -- give it 1s to open
  waitingForContainer = container:getId()
  loot.tries = loot.tries + 10

  return true
end

TargetBot.Looting.getLootContainers = function(containers)
  local lootContainers = {}
  local openedContainersById = {}
  local toOpen = nil
  for index, container in pairs(containers) do
    openedContainersById[container:getContainerItem():getId()] = 1
    if containersById[container:getContainerItem():getId()] and not container.lootContainer then
      if container:getItemsCount() < container:getCapacity() then
        table.insert(lootContainers, container)
      else -- it's full, open next container if possible
        for slot, item in ipairs(container:getItems()) do
          if item:isContainer() and containersById[item:getId()] then
            toOpen = {item, container}
            break
          end
        end
      end
    end
  end
  if not lootContainers[1] then
    if toOpen then
      g_game.open(toOpen[1], toOpen[2])
      waitTill = now + 500 -- wait 0.5s
      return lootContainers
    end
    -- check containers one more time, maybe there's any loot container
    for index, container in pairs(containers) do
      if not containersById[container:getContainerItem():getId()] and not container.lootContainer then
        for slot, item in ipairs(container:getItems()) do
          if item:isContainer() and containersById[item:getId()] then
            g_game.open(item)
            waitTill = now + 500 -- wait 0.5s
            return lootContainers
          end
        end
      end
    end
    -- can't find any lootContainer, let's check slots, maybe there's one
    for slot = InventorySlotFirst, InventorySlotLast do
      local item = getInventoryItem(slot)
      if item and item:isContainer() and not openedContainersById[item:getId()] then
        -- container which is not opened yet, let's open it
        g_game.open(item)
        waitTill = now + 500 -- wait 0.5s
        return lootContainers
      end
    end
  end
  return lootContainers
end

TargetBot.Looting.lootContainer = function(lootContainers, container)
  -- loot items
  local nextContainer = nil
  for i, item in ipairs(container:getItems()) do
    if item:isContainer() and not itemsById[item:getId()] then
      nextContainer = item
    elseif itemsById[item:getId()] or (ui.everyItem:isOn() and not item:isContainer()) then
      item.lootTries = (item.lootTries or 0) + 1
      if item.lootTries < 5 then -- if can't be looted within 0.5s then skip it
        return TargetBot.Looting.lootItem(lootContainers, item)
      end
    elseif storage.foodItems and storage.foodItems[1] and lastFoodConsumption + 5000 < now then
      for _, food in ipairs(storage.foodItems) do
        if item:getId() == food.id then
          g_game.use(item)
          lastFoodConsumption = now
          return
        end
      end
    end
  end

  -- no more items to loot, open next container
  if nextContainer then
    nextContainer.lootTries = (nextContainer.lootTries or 0) + 1
    if nextContainer.lootTries < 2 then -- max 0.6s to open it
      g_game.open(nextContainer, container)
      waitTill = now + 300 -- give it 0.3s to open
      waitingForContainer = nextContainer:getId()
      return
    end
  end

  -- looting finished, remove container from list
  container.lootContainer = false
  g_game.close(container)
  table.remove(TargetBot.Looting.list, 1)
end

TargetBot.Looting.lootItem = function(lootContainers, item)
  if item:isStackable() then
    local count = item:getCount()
    for _, container in ipairs(lootContainers) do
      for slot, citem in ipairs(container:getItems()) do
        if item:getId() == citem:getId() and citem:getCount() < 100 then
          g_game.move(item, container:getSlotPosition(slot - 1), count)
          waitTill = now + 300 -- give it 0.3s to move item
          return
        end
      end
    end
  end

  local container = lootContainers[1]
  g_game.move(item, container:getSlotPosition(container:getItemsCount()), 1)
  waitTill = now + 300 -- give it 0.3s to move item
end

onContainerOpen(function(container, previousContainer)
  if container:getContainerItem():getId() == waitingForContainer then
    container.lootContainer = true
    waitingForContainer = nil
  end
end)

onCreatureDisappear(function(creature)
  if not TargetBot.isOn() then return end
  if not creature:isMonster() then return end
  local config = TargetBot.Creature.calculateParams(creature, {}) -- return {craeture, config, danger, priority}
  if not config.config or config.config.dontLoot then
    return
  end
  local pos = player:getPosition()
  local mpos = creature:getPosition()
  local name = creature:getName()
  if pos.z ~= mpos.z or math.max(math.abs(pos.x-mpos.x), math.abs(pos.y-mpos.y)) > 6 then return end
  schedule(20, function() -- check in 20ms if there's container (dead body) on that tile
    if not containers[1] then return end
    if TargetBot.Looting.list[20] then return end -- too many items to loot
    local tile = g_map.getTile(mpos)
    if not tile then return end
    local container = tile:getTopUseThing()
    if not container or not container:isContainer() then return end
    if not findPath(player:getPosition(), mpos, 6, {ignoreNonPathable=true, ignoreCreatures=true, ignoreCost=true}) then return end
    table.insert(TargetBot.Looting.list, {pos=mpos, creature=name, container=container:getId(), added=now, tries=0})
    container:setMarked('#000088')
  end)
end)
