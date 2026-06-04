---@diagnostic disable: undefined-global
setDefaultTab("Main")

local panelName = "pushmax"
local ui = setupUI([[
Panel
  height: 19

  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr('PUSHMAX')

  Button
    id: push
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Setup

]])
ui:setId(panelName)

if not storage[panelName] then
  storage[panelName] = {
    enabled = true,
    pushDelay = 1060,
    pushMaxRuneId = 3188,
    mwallBlockId = 2128,
    pushMaxKey = "PageUp"
  }
end

local config = storage[panelName]

ui.title:setOn(config.enabled)
ui.title.onClick = function(widget)
config.enabled = not config.enabled
widget:setOn(config.enabled)
end

ui.push.onClick = function(widget)
  pushWindow:show()
  pushWindow:raise()
  pushWindow:focus()
end

rootWidget = g_ui.getRootWidget()
if rootWidget then
  pushWindow = UI.createWindow('PushMaxWindow', rootWidget)
  pushWindow:hide()

  pushWindow.closeButton.onClick = function(widget)
    pushWindow:hide()
  end

  local updateDelayText = function()
    pushWindow.delayText:setText("Push Delay: ".. config.pushDelay)
  end
  updateDelayText()
  pushWindow.delay.onValueChange = function(scroll, value)
    config.pushDelay = value
    updateDelayText()
  end
  pushWindow.delay:setValue(config.pushDelay)

  pushWindow.runeId.onItemChange = function(widget)
    config.pushMaxRuneId = widget:getItemId()
  end
  pushWindow.runeId:setItemId(config.pushMaxRuneId)
  pushWindow.mwallId.onItemChange = function(widget)
    config.mwallBlockId = widget:getItemId()
  end
  pushWindow.mwallId:setItemId(config.mwallBlockId)

  pushWindow.hotkey.onTextChange = function(widget, text)
    config.pushMaxKey = text
  end
  pushWindow.hotkey:setText(config.pushMaxKey)
end

-- variables for config
local fieldTable = {2118, 105, 2122}
local cleanTile = nil

-- scripts

local targetTile
local pushTarget

local resetData = function()
  for i, tile in pairs(g_map.getTiles(posz())) do
    if tile:getText() == "TARGET" or tile:getText() == "DEST" or tile:getText() == "CLEAR" then
      tile:setText('')
    end
  end
  pushTarget = nil
  targetTile = nil
  cleanTile = nil
end

local getCreatureById = function(id)
  for i, spec in ipairs(getSpectators()) do
    if spec:getId() == id then
      return spec
    end
  end
  return false
end

local isNotOk = function(t,tile)
  local tileItems = {}

  for i, item in pairs(tile:getItems()) do
    table.insert(tileItems, item:getId())
  end
  for i, field in ipairs(t) do
    if table.find(tileItems, field) then
      return true
    end
  end
  return false
end

local isOk = function(a,b)
  return getDistanceBetween(a,b) == 1
end

-- to mark
local hold = 0
onKeyDown(function(keys)
  if not config.enabled then return end
  if keys ~= config.pushMaxKey then return end
  hold = now
  local tile = getTileUnderCursor()
  if not tile then return end
  if pushTarget and targetTile then
    resetData()
    return
  end
  local creature = tile:getCreatures()[1]
  if not pushTarget and creature then
    pushTarget = creature
    if pushTarget then
      tile:setText('TARGET')
      pushTarget:setMarked('#00FF00')
    end
  elseif not targetTile and pushTarget then
    if pushTarget and getDistanceBetween(tile:getPosition(),pushTarget:getPosition()) ~= 1 then
      resetData()
      return
    else
      tile:setText('DEST')
      targetTile = tile
    end
  end
end)

-- mark tile to throw anything from it
onKeyPress(function(keys)
  if not config.enabled then return end
  if keys ~= config.pushMaxKey then return end
  local tile = getTileUnderCursor()
  if not tile then return end

  if (hold - now) < -2500 then
    if cleanTile and tile ~= cleanTile then
      resetData()
    elseif not cleanTile then
      cleanTile = tile
      tile:setText("CLEAR")
    end
  end
  hold = 0
end)

onCreaturePositionChange(function(creature, newPos, oldPos)
  if not config.enabled then return end
  if creature == player then
    resetData()
  end
  if not pushTarget or not targetTile then return end
  if creature == pushTarget and newPos == targetTile then
    resetData()
  end
end)

macro(50, function()
  if not config.enabled then return end

  local pushDelay = tonumber(config.pushDelay)
  local rune = tonumber(config.pushMaxRuneId)
  local customMwall = config.mwallBlockId

  if cleanTile then
    local tilePos = cleanTile:getPosition()
    local pPos = player:getPosition()
    if not isOk(tilePos, pPos) then
      resetData()
      return
    end

    if not cleanTile:hasCreatures() then return end
    local tiles = getNearTiles(tilePos)
    local destTile
    local forbidden = {}
    -- unfortunately double loop
    for i, tile in pairs(tiles) do
      local minimapColor = g_map.getMinimapColor(tile:getPosition())
      local stairs = (minimapColor >= 210 and minimapColor <= 213)
      if stairs then
        table.insert(forbidden, tile:getPosition())
      end
    end
    for i, tile in pairs(tiles) do
      local minimapColor = g_map.getMinimapColor(tile:getPosition())
      local stairs = (minimapColor >= 210 and minimapColor <= 213)
      if tile:isWalkable() and not isNotOk(fieldTable, tile) and not tile:hasCreatures() and not stairs then
        local tooClose = false
        if #forbidden ~= 0 then
          for i=1,#forbidden do
            local pos = forbidden[i]
            if isOk(pos, tile:getPosition()) then
              tooClose = true
              break
            end
          end
        end
        if not tooClose then
          destTile = tile
          break
        end
      end
    end

    if not destTile then return end
    local parcel = cleanTile:getCreatures()[1]
    if parcel then
      test()
      g_game.move(parcel,destTile:getPosition())
      delay(2000)
    end
  else
    if not pushTarget or not targetTile then return end
    local tilePos = targetTile:getPosition()
    local targetPos = pushTarget:getPosition()
    if not isOk(tilePos,targetPos) then return end

    local tileOfTarget = g_map.getTile(targetPos)

    if not targetTile:isWalkable() then
      local topThing = targetTile:getTopUseThing():getId()
      if topThing == 2129 or topThing == 2130 or topThing == customMwall then
        if targetTile:getTimer() < pushDelay+500 then
          vBot.isUsing = true
          schedule(pushDelay+700, function()
            vBot.isUsing = false
          end)
        end
        if targetTile:getTimer() > pushDelay then
          return
        end
      else
        return resetData()
      end
    end

    if not tileOfTarget:getTopUseThing():isNotMoveable() and targetTile:getTimer() < pushDelay+500 then
      return useWith(rune, pushTarget)
    end
    if isNotOk(fieldTable, targetTile) then
      if targetTile:canShoot() then
        return useWith(3148, targetTile:getTopUseThing())
      else
        return
      end
    end
      g_game.move(pushTarget,tilePos)
      delay(2000)
  end
end)
