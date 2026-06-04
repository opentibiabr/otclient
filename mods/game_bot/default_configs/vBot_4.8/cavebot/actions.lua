CaveBot.Actions = {}
vBot.lastLabel = ""
local oldTibia = g_game.getClientVersion() < 960
local nextTile = nil
local noPath = 0

-- antistuck f()
local nextPos = nil -- creature
local nextPosF = nil -- furniture
local function modPos(dir)
    local y = 0
    local x = 0

    if dir == 0 then
        y = -1
    elseif dir == 1 then
        x = 1
    elseif dir == 2 then
        y = 1
    elseif dir == 3 then
        x = -1
    elseif dir == 4 then
        y = -1
        x = 1
    elseif dir == 5 then
        y = 1
        x = 1
    elseif dir == 6 then
        y = 1
        x = -1
    elseif dir == 7 then
        y = -1
        x = -1
    end

    return {x, y}
end

-- stack-covered antystuck, in & out pz
local lastMoved = now - 200
onTextMessage(function(mode, text)
  if text ~= 'There is not enough room.' then return end
  if CaveBot.isOff() then return end

  local tiles = getNearTiles(pos())

  for i, tile in ipairs(tiles) do
    if not tile:hasCreatures() and tile:isWalkable() and #tile:getItems() > 9 then
      local topThing = tile:getTopThing()
      if not isInPz() then
        return useWith(3197, tile:getTopThing()) -- disintegrate
      else
        if now < lastMoved + 200 then return end -- delay to prevent clogging
        local nearTiles = getNearTiles(tile:getPosition())
        for i, tile in ipairs(nearTiles) do
          local tpos = tile:getPosition()
          if pos() ~= tpos then
            if tile:isWalkable() then
              lastMoved = now
              return g_game.move(topThing, tpos) -- move item
            end
          end
        end
      end
    end
  end
end)

local furnitureIgnore = { 2986 }
local function breakFurniture(destPos)
  if isInPz() then return false end
  local candidate = {thing=nil, dist=100}
  for i, tile in ipairs(g_map.getTiles(posz())) do
    local walkable = tile:isWalkable()
    local topThing = tile:getTopThing()
    local isWg = topThing and topThing:getId() == 2130
    if topThing and (isWg or not table.find(furnitureIgnore, topThing:getId()) and topThing:isItem()) then
      local moveable = not topThing:isNotMoveable()
      local tpos = tile:getPosition()
      local path = findPath(player:getPosition(), tpos, 7, { ignoreNonPathable = true, precision = 1 })

      if path then
        if isWg or (not walkable and moveable) then
          local distance = getDistanceBetween(destPos, tpos)

          if distance < candidate.dist then
            candidate = {thing=topThing, dist=distance}
          end
        end
      end
    end
  end

  local thing = candidate.thing
  if thing then
    useWith(3197, thing)
    return true
  end

  return false
end

local function pushPlayer(creature)
  local cpos = creature:getPosition()
  local tiles = getNearTiles(cpos)

  for i, tile in ipairs(tiles) do
    local pos = tile:getPosition()
    local minimapColor = g_map.getMinimapColor(pos)
    local stairs = (minimapColor >= 210 and minimapColor <= 213)

    if not stairs and tile:isWalkable() then
      g_game.move(creature, pos)
    end
  end

end

local function pathfinder()
  if not storage.extras.pathfinding then return end
  if noPath < 10 then return end

  if not CaveBot.gotoNextWaypointInRange() then
    if getConfigFromName and getConfigFromName() then
      local profile = CaveBot.getCurrentProfile()
      local config = getConfigFromName()
      local newProfile = profile == '#Unibase' and config or '#Unibase'

      CaveBot.setCurrentProfile(newProfile)
    end
  end
  noPath = 0
  return true
end

-- it adds an action widget to list
CaveBot.addAction = function(action, value, focus)
  action = action:lower()
  local raction = CaveBot.Actions[action]
  if not raction then
    return warn("Invalid cavebot action: " .. action)
  end
  if type(value) == 'number' then
    value = tostring(value)
  end
  local widget = UI.createWidget("CaveBotAction", CaveBot.actionList)
  widget:setText(action .. ":" .. value:split("\n")[1])
  widget.action = action
  widget.value = value
  if raction.color then
    widget:setColor(raction.color)
  end
  widget.onDoubleClick = function(cwidget) -- edit on double click
    if CaveBot.Editor then
      schedule(20, function() -- schedule to have correct focus
        CaveBot.Editor.edit(cwidget.action, cwidget.value, function(action, value)
          CaveBot.editAction(cwidget, action, value)
          CaveBot.save()
        end)
      end)
    end
  end
  if focus then
    widget:focus()
    CaveBot.actionList:ensureChildVisible(widget)
  end
  return widget
end

-- it updates existing widget, you should call CaveBot.save() later
CaveBot.editAction = function(widget, action, value)
  action = action:lower()
  local raction = CaveBot.Actions[action]
  if not raction then
    return warn("Invalid cavebot action: " .. action)
  end

  if not widget.action or not widget.value then
    return warn("Invalid cavebot action widget, has missing action or value")
  end

  widget:setText(action .. ":" .. value:split("\n")[1])
  widget.action = action
  widget.value = value
  if raction.color then
    widget:setColor(raction.color)
  end
  return widget
end

--[[
registerAction:
action - string, color - string, callback = function(value, retries, prev)
value is a string value of action, retries is number which will grow by 1 if return is "retry"
prev is a true when previuos action was executed succesfully, false otherwise
it must return true if executed correctly, false otherwise
it can also return string "retry", then the function will be called again in 20 ms
]]--
CaveBot.registerAction = function(action, color, callback)
  action = action:lower()
  if CaveBot.Actions[action] then
    return warn("Duplicated acction: " .. action)
  end
  CaveBot.Actions[action] = {
    color=color,
    callback=callback
  }
end

CaveBot.registerAction("label", "yellow", function(value, retries, prev)
  vBot.lastLabel = value
  return true
end)

CaveBot.registerAction("gotolabel", "#FFFF55", function(value, retries, prev)
  return CaveBot.gotoLabel(value)
end)

CaveBot.registerAction("delay", "#AAAAAA", function(value, retries, prev)
  if retries == 0 then
    local data = string.split(value, ",")
    local val = tonumber(data[1]:trim())
    local random
    local final


    if #data == 2 then
      random = tonumber(data[2]:trim())
    end

    if random then
      local diff = (val/100) * random
      local min = val - diff
      local max = val + diff
      final = math.random(min, max)
    end
    final = final or val

    CaveBot.delay(final)
    return "retry"
  end
  return true
end)

CaveBot.registerAction("follow", "#FF8400", function(value, retries, prev)
  local c = getCreatureByName(value)
  if not c then
    print("CaveBot[follow]: can't find creature to follow")
    return false
  end
  local cpos = c:getPosition()
  local pos = pos()
  if getDistanceBetween(cpos, pos) < 2 then
    g_game.cancelFollow()
    return true
  else
    follow(c)
    delay(200)
    return "retry"
  end
end)

CaveBot.registerAction("function", "red", function(value, retries, prev)
  local prefix = "local retries = " .. retries .. "\nlocal prev = " .. tostring(prev) .. "\nlocal delay = CaveBot.delay\nlocal gotoLabel = CaveBot.gotoLabel\n"
  prefix = prefix .. "local macro = function() warn('Macros inside cavebot functions are not allowed') end\n"
  for extension, callbacks in pairs(CaveBot.Extensions) do
    prefix = prefix .. "local " .. extension .. " = CaveBot.Extensions." .. extension .. "\n"
  end
  local status, result = pcall(function()
    if _VERSION == "Lua 5.1" and type(jit) ~= "table" then
      return assert(loadstring(prefix .. value))()
    else
      return assert(load(prefix .. value, "cavebot_function"))()
    end
  end)
  if not status then
    warn("warn in cavebot function:\n" .. result)
    return false
  end
  return result
end)

CaveBot.registerAction("goto", "green", function(value, retries, prev)
  local pos = regexMatch(value, "\\s*([0-9]+)\\s*,\\s*([0-9]+)\\s*,\\s*([0-9]+),?\\s*([0-9]?)")
  if not pos[1] then
    warn("Invalid cavebot goto action value. It should be position (x,y,z), is: " .. value)
    return false
  end

  -- reset pathfinder
  nextPosF = nil
  nextPos = nil

  if CaveBot.Config.get("mapClick") then
    if retries >= 5 then
      noPath = noPath + 1
      pathfinder()
      return false -- tried 5 times, can't get there
    end
  else
    if retries >= 100 then
      noPath = noPath + 1
      pathfinder()
      return false -- tried 100 times, can't get there
    end
  end

  local precision = tonumber(pos[1][5])
  pos = {x=tonumber(pos[1][2]), y=tonumber(pos[1][3]), z=tonumber(pos[1][4])}
  local playerPos = player:getPosition()
  if pos.z ~= playerPos.z then
    noPath = noPath + 1
    pathfinder()
    return false -- different floor
  end

  local maxDist = storage.extras.gotoMaxDistance or 40

  if math.abs(pos.x-playerPos.x) + math.abs(pos.y-playerPos.y) > maxDist then
    noPath = noPath + 1
    pathfinder()
    return false -- too far way
  end

  local minimapColor = g_map.getMinimapColor(pos)
  local stairs = (minimapColor >= 210 and minimapColor <= 213)

  if stairs then
    if math.abs(pos.x-playerPos.x) == 0 and math.abs(pos.y-playerPos.y) <= 0 then
      noPath = 0
      return true -- already at position
    end
  elseif math.abs(pos.x-playerPos.x) == 0 and math.abs(pos.y-playerPos.y) <= (precision or 1) then
      noPath = 0
      return true -- already at position
  end
  -- check if there's a path to that place, ignore creatures and fields
  local path = findPath(playerPos, pos, maxDist, { ignoreNonPathable = true, precision = 1, ignoreCreatures = true, allowUnseen = true, allowOnlyVisibleTiles = false  })
  if not path then
    if breakFurniture(pos, storage.extras.machete) then
      CaveBot.delay(1000)
      retries = 0
      return "retry"
    end
    noPath = noPath + 1
    pathfinder()
    return false -- there's no way
  end

  -- check if there's a path to destination but consider Creatures (attack only if trapped)
  local path2 = findPath(playerPos, pos, maxDist, { ignoreNonPathable = true, precision = 1 })
  if not path2 then
    local foundMonster = false
    for i, dir in ipairs(path) do
      local dirs = modPos(dir)
      nextPos = nextPos or playerPos
      nextPos.x = nextPos.x + dirs[1]
      nextPos.y = nextPos.y + dirs[2]

      local tile = g_map.getTile(nextPos)
      if tile then
          if tile:hasCreatures() then
              local creature = tile:getCreatures()[1]
              local hppc = creature:getHealthPercent()
              if creature:isMonster() and (hppc and hppc > 0) and (oldTibia or creature:getType() < 3) then
                  -- real blocking creature can not meet those conditions - ie. it could be player, so just in case check if the next creature is reachable
                  local path = findPath(playerPos, creature:getPosition(), 7, { ignoreNonPathable = true, precision = 1 })
                  if path then
                      foundMonster = true
                      if g_game.getAttackingCreature() ~= creature then
                        if distanceFromPlayer(creature:getPosition()) > 3 then
                          CaveBot.walkTo(creature:getPosition(), 7, { ignoreNonPathable = true, precision = 1 })
                        else
                          attack(creature)
                        end
                      end
                      g_game.setChaseMode(1)
                      CaveBot.delay(100)
                      retries = 0 -- reset retries, we are trying to unclog the cavebot
                      break
                  end
              end
          end
      end
    end

    if not foundMonster then
      foundMonster = false
      return false -- no other way
    end
  end

  -- try to find path, don't ignore creatures, don't ignore fields
  if not CaveBot.Config.get("ignoreFields") and CaveBot.walkTo(pos, 40) then
    return "retry"
  end

  -- try to find path, don't ignore creatures, ignore fields
  if CaveBot.walkTo(pos, maxDist, { ignoreNonPathable = true, allowUnseen = true, allowOnlyVisibleTiles = false }) then
    return "retry"
  end

  if retries >= 3 then
    -- try to lower precision, find something close to final position
    local precison = retries - 1
    if stairs then
      precison = 0
    end
    if CaveBot.walkTo(pos, 50, { ignoreNonPathable = true, precision = precison, allowUnseen = true, allowOnlyVisibleTiles = false }) then
      return "retry"
    end
  end

  if not CaveBot.Config.get("mapClick") and retries >= 5 then
    noPath = noPath + 1
    pathfinder()
    return false
  end

  if CaveBot.Config.get("skipBlocked") then
    noPath = noPath + 1
    pathfinder()
    return false
  end

  -- everything else failed, try to walk ignoring creatures, maybe will work
  CaveBot.walkTo(pos, maxDist, { ignoreNonPathable = true, precision = 1, ignoreCreatures = true, allowUnseen = true, allowOnlyVisibleTiles = false })
  return "retry"
end)

CaveBot.registerAction("use", "#FFB272", function(value, retries, prev)
  local pos = regexMatch(value, "\\s*([0-9]+)\\s*,\\s*([0-9]+)\\s*,\\s*([0-9]+)")
  if not pos[1] then
    local itemid = tonumber(value)
    if not itemid then
      warn("Invalid cavebot use action value. It should be (x,y,z) or item id, is: " .. value)
      return false
    end
    use(itemid)
    return true
  end

  pos = {x=tonumber(pos[1][2]), y=tonumber(pos[1][3]), z=tonumber(pos[1][4])}
  local playerPos = player:getPosition()
  if pos.z ~= playerPos.z then
    return false -- different floor
  end

  if math.max(math.abs(pos.x-playerPos.x), math.abs(pos.y-playerPos.y)) > 7 then
    return false -- too far way
  end

  local tile = g_map.getTile(pos)
  if not tile then
    return false
  end

  local topThing = tile:getTopUseThing()
  if not topThing then
    return false
  end

  use(topThing)
  CaveBot.delay(CaveBot.Config.get("useDelay") + CaveBot.Config.get("ping"))
  return true
end)

CaveBot.registerAction("usewith", "#EEB292", function(value, retries, prev)
  local pos = regexMatch(value, "\\s*([0-9]+)\\s*,\\s*([0-9]+)\\s*,\\s*([0-9]+)\\s*,\\s*([0-9]+)")
  if not pos[1] then
    if not itemid then
      warn("Invalid cavebot usewith action value. It should be (itemid,x,y,z) or item id, is: " .. value)
      return false
    end
    use(itemid)
    return true
  end

  local itemid = tonumber(pos[1][2])
  pos = {x=tonumber(pos[1][3]), y=tonumber(pos[1][4]), z=tonumber(pos[1][5])}
  local playerPos = player:getPosition()
  if pos.z ~= playerPos.z then
    return false -- different floor
  end

  if math.max(math.abs(pos.x-playerPos.x), math.abs(pos.y-playerPos.y)) > 7 then
    return false -- too far way
  end

  local tile = g_map.getTile(pos)
  if not tile then
    return false
  end

  local topThing = tile:getTopUseThing()
  if not topThing then
    return false
  end

  usewith(itemid, topThing)
  CaveBot.delay(CaveBot.Config.get("useDelay") + CaveBot.Config.get("ping"))
  return true
end)

CaveBot.registerAction("say", "#FF55FF", function(value, retries, prev)
  say(value)
  return true
end)

CaveBot.registerAction("npcsay", "#FF55FF", function(value, retries, prev)
  NPC.say(value)
  return true
end)
