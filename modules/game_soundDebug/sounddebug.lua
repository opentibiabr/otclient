local soundDebugWindow = nil
local soundDebugButton = nil
local overlayWidget = nil
local updateEvent = nil

local headerLabel = nil
local mixSummaryLabel = nil
local sourceSummaryLabel = nil
local itemSummaryLabel = nil
local eventSummaryLabel = nil
local spatialSummaryLabel = nil
local metersPanel = nil
local sourceList = nil
local itemsPanel = nil
local eventList = nil
local soundField = nil
local soundFieldStage = nil
local soundFieldGrid = nil
local soundFieldFloorLayer = nil
local soundFieldMarkerLayer = nil
local listenerPulse = nil
local listenerCore = nil
local fieldPlayer = nil

local meterWidgets = {}
local meterStates = {}
local sourceRows = {}
local itemCards = {}
local eventRows = {}
local mapMarkers = {}
local fieldFloorTiles = {}
local fieldItemMarkers = {}
local fieldEventBursts = {}

local MAX_SOURCE_ROWS = 18
local MAX_ITEM_CARDS = 3
local MAX_EVENT_ROWS = 12
local MAX_MAP_MARKERS = 12
local MAX_FIELD_ITEM_MARKERS = 8
local MAX_FIELD_EVENT_BURSTS = 12
local EVENT_TTL_MS = 2500
local FIELD_GRID_RADIUS = 5
local FIELD_GRID_SIZE = FIELD_GRID_RADIUS * 2 + 1

local METER_ORDER = {
  { key = 'master', short = 'M', label = 'Master', tooltip = 'Master', color = '#f3d67c', soft = '#f3d67c2a', accent = '#fff4c6' },
  { id = SoundChannels.Music, short = 'MU', label = 'Music', tooltip = 'Music', color = '#7fc3ff', soft = '#7fc3ff24', accent = '#dff2ff' },
  { id = SoundChannels.Ambient, short = 'AM', label = 'Ambient', tooltip = 'Ambient', color = '#79d7b7', soft = '#79d7b724', accent = '#ddfff2' },
  { id = SoundChannels.Effect, short = 'FX', label = 'Effect', tooltip = 'Effect', color = '#ff8e6e', soft = '#ff8e6e24', accent = '#ffe4da' },
  { id = SoundChannels.Spells, short = 'SP', label = 'Spells', tooltip = 'Spells', color = '#e48cff', soft = '#e48cff24', accent = '#f8ddff' },
  { id = SoundChannels.Item, short = 'IT', label = 'Item', tooltip = 'Item', color = '#f5c86a', soft = '#f5c86a24', accent = '#fff1d3' },
  { id = SoundChannels.Event, short = 'EV', label = 'Event', tooltip = 'Event', color = '#7ee7ff', soft = '#7ee7ff24', accent = '#ddfaff' },
  { id = SoundChannels.OwnBattles, short = 'OW', label = 'Own', tooltip = 'OwnBattles', color = '#ff6a8d', soft = '#ff6a8d24', accent = '#ffdbe4' },
  { id = SoundChannels.OthersPlayers, short = 'OT', label = 'Others', tooltip = 'OthersPlayers', color = '#5fb0ff', soft = '#5fb0ff24', accent = '#ddeeff' },
  { id = SoundChannels.Creature, short = 'CR', label = 'Creature', tooltip = 'Creature', color = '#9fe278', soft = '#9fe27824', accent = '#ebffdd' },
  { id = SoundChannels.SoundUI, short = 'UI', label = 'UI', tooltip = 'SoundUI', color = '#f1e189', soft = '#f1e18924', accent = '#fff8d2' },
  { id = SoundChannels.Bot, short = 'BT', label = 'Bot', tooltip = 'Bot', color = '#d1a6ff', soft = '#d1a6ff24', accent = '#f3e4ff' },
  { id = SoundChannels.secundaryChannel, short = 'S2', label = 'Secondary', tooltip = 'secundaryChannel', color = '#ffb26b', soft = '#ffb26b24', accent = '#ffeedb' }
}

local CHANNEL_BY_ID = {}
for _, meter in ipairs(METER_ORDER) do
  if meter.id then
    CHANNEL_BY_ID[meter.id] = meter
  end
end

local KIND_BADGES = {
  ['item-ambient'] = 'AMB',
  ['protocol-main'] = 'OPC',
  ['protocol-secondary'] = 'SEC',
  ['music'] = 'MUS',
  ['ambient'] = 'ENV',
  ['ui'] = 'UI',
  ['channel'] = 'SRC',
  ['direct'] = 'DIR'
}

local EVENT_SKINS = {
  main = { border = '#67dfff', fill = '#67dfff24', core = '#effcff', text = '#04131d' },
  secondary = { border = '#ffb26b', fill = '#ffb26b24', core = '#fff4e7', text = '#1d0c00' },
  item = { border = '#f3d67c', fill = '#f3d67c24', core = '#fff6d8', text = '#1d1500' }
}

local function clamp(value, minValue, maxValue)
  if value < minValue then
    return minValue
  end
  if value > maxValue then
    return maxValue
  end
  return value
end

local function lerp(current, target, alpha)
  return current + (target - current) * alpha
end

local function basename(path)
  if not path or path == '' then
    return '-'
  end
  path = path:gsub('\\', '/')
  return path:match('([^/]+)$') or path
end

local function trimText(text, limit)
  text = text or ''
  if #text <= limit then
    return text
  end
  return text:sub(1, math.max(1, limit - 1)) .. '~'
end

local function roundPercent(value)
  return math.floor(clamp(value or 0, 0, 1) * 100 + 0.5)
end

local function isMapPosition(pos)
  return pos and pos.x and pos.y and pos.z and pos.x < 65535 and pos.y < 65535 and pos.z >= 0
end

local function getChannelSkin(channelId)
  return CHANNEL_BY_ID[channelId] or METER_ORDER[1]
end

local function getEventSkin(event)
  if event and event.secondary then
    return EVENT_SKINS.secondary
  end
  return EVENT_SKINS.main
end

local function computeLevelHeight(bodyHeight, value, minimumHeight)
  value = clamp(value or 0, 0, 1)
  local levelHeight = math.floor(bodyHeight * value + 0.5)
  if value > 0 and minimumHeight then
    levelHeight = math.max(levelHeight, minimumHeight)
  end

  return clamp(levelHeight, 0, bodyHeight)
end

local function setFillLevel(widget, bodyHeight, value, minimumHeight)
  if not widget or bodyHeight <= 0 then
    return
  end

  widget:setMarginBottom(0)
  widget:setHeight(computeLevelHeight(bodyHeight, value, minimumHeight))
end

local function setMarkerLevel(widget, bodyHeight, value)
  if not widget or bodyHeight <= 0 then
    return
  end

  local markerHeight = math.max(1, widget:getHeight())
  local offset = computeLevelHeight(bodyHeight, value) - markerHeight
  widget:setMarginBottom(clamp(offset, 0, math.max(0, bodyHeight - markerHeight)))
end

local function bindHoverTooltip(widget, text)
  if not widget then
    return
  end

  widget.soundDebugTooltip = text
  widget.onHoverChange = function(self, hovered)
    if hovered then
      if self.soundDebugTooltip and self.soundDebugTooltip ~= '' and not g_mouse.isPressed() then
        g_tooltip.display(self.soundDebugTooltip)
      end
    else
      g_tooltip.hide()
    end
  end
end

local function hidePool(pool)
  for _, entry in ipairs(pool) do
    if entry.root then
      entry.root:hide()
    end
  end
end

local function resetSummaries()
  headerLabel:setText('Sound debug is idle.')
  mixSummaryLabel:setText('Waiting for active sources.')
  sourceSummaryLabel:setText('No sources.')
  itemSummaryLabel:setText('No ambient items active.')
  eventSummaryLabel:setText('No positional sound events yet.')
  spatialSummaryLabel:setText('Map and radar markers follow positional audio.')
end

local function resetFieldTheme()
  if soundFieldStage then
    soundFieldStage:setBackgroundColor('#09131d')
    soundFieldStage:setBorderColor('#2b4052')
  end

  if listenerPulse then
    listenerPulse:setWidth(18)
    listenerPulse:setHeight(18)
    listenerPulse:setBackgroundColor('#f3d67c14')
    listenerPulse:setBorderColor('#f3d67c')
    listenerPulse:setOpacity(0.35)
  end

  if listenerCore then
    listenerCore:setBackgroundColor('#f8e6a2')
    listenerCore:setBorderColor('#fff6d8')
    listenerCore:setOpacity(1)
  end

  if fieldPlayer then
    fieldPlayer:hide()
  end
end

local function clearVisuals()
  for _, state in pairs(meterStates) do
    state.value = 0
    state.peak = 0
    state.base = 0
  end
  hidePool(sourceRows)
  hidePool(itemCards)
  hidePool(eventRows)
  hidePool(mapMarkers)
  hidePool(fieldFloorTiles)
  hidePool(fieldItemMarkers)
  hidePool(fieldEventBursts)
  resetSummaries()
  resetFieldTheme()
end

local function createMeter(def)
  local root = g_ui.createWidget('SoundDebugMeter', metersPanel)
  local meter = {
    root = root,
    toolTipWidget = root:getChildById('toolTipWidget'),
    body = root:recursiveGetChildById('meterBody'),
    caption = root:recursiveGetChildById('caption'),
    baseline = root:recursiveGetChildById('baseline'),
    fill = root:recursiveGetChildById('fill'),
    peak = root:recursiveGetChildById('peak'),
    footer = root:recursiveGetChildById('footer'),
    meta = root:recursiveGetChildById('meta')
  }

  meter.caption:setText(def.short)
  meter.root:setTooltip(def.tooltip or def.label)
  meter.body:setTooltip(def.tooltip or def.label)
  meter.caption:setTooltip(def.tooltip or def.label)
  meter.baseline:setTooltip(def.tooltip or def.label)
  meter.fill:setTooltip(def.tooltip or def.label)
  meter.peak:setTooltip(def.tooltip or def.label)
  meter.footer:setTooltip(def.tooltip or def.label)
  meter.meta:setTooltip(def.tooltip or def.label)
  meter.fill:setBackgroundColor(def.color)
  meter.baseline:setBackgroundColor(def.soft)
  meter.peak:setBackgroundColor(def.accent)
  meter.footer:setText('--')
  meter.meta:setText(def.label)
  bindHoverTooltip(meter.toolTipWidget, def.tooltip or def.label)
  bindHoverTooltip(meter.root, def.tooltip or def.label)

  meterWidgets[def.key or def.id] = meter
  meterStates[def.key or def.id] = { value = 0, peak = 0 }
end

local function createSourceRow()
  local root = g_ui.createWidget('SoundDebugSourceRow', sourceList)
  table.insert(sourceRows, {
    root = root,
    badge = root:recursiveGetChildById('badge'),
    badgeText = root:recursiveGetChildById('badgeText'),
    title = root:recursiveGetChildById('title'),
    meta = root:recursiveGetChildById('meta'),
    levelTrack = root:recursiveGetChildById('levelTrack'),
    levelFill = root:recursiveGetChildById('levelFill')
  })
end

local function createItemCard()
  local root = g_ui.createWidget('SoundDebugItemCard', itemsPanel)
  local itemWidget = root:recursiveGetChildById('item')
  itemWidget:setVirtual(true)
  itemWidget:setShowCount(false)
  table.insert(itemCards, {
    root = root,
    item = itemWidget,
    title = root:recursiveGetChildById('title'),
    meta = root:recursiveGetChildById('meta'),
    effect = root:recursiveGetChildById('effect')
  })
end

local function createEventRow()
  local root = g_ui.createWidget('SoundDebugEventRow', eventList)
  table.insert(eventRows, {
    root = root,
    badge = root:recursiveGetChildById('badge'),
    badgeText = root:recursiveGetChildById('badgeText'),
    title = root:recursiveGetChildById('title'),
    meta = root:recursiveGetChildById('meta')
  })
end

local function createMarker()
  local root = g_ui.createWidget('SoundDebugMarker', overlayWidget)
  table.insert(mapMarkers, {
    root = root,
    ring = root:recursiveGetChildById('ring'),
    core = root:recursiveGetChildById('core'),
    tag = root:recursiveGetChildById('tag')
  })
end

local function createFieldFloorTile()
  local root = g_ui.createWidget('SoundDebugFieldTile', soundFieldFloorLayer)
  table.insert(fieldFloorTiles, {
    root = root
  })
end

local function createFieldItemMarker()
  local root = g_ui.createWidget('SoundDebugFieldItemMarker', soundFieldMarkerLayer)
  local itemWidget = root:recursiveGetChildById('item')
  itemWidget:setVirtual(true)
  itemWidget:setShowCount(false)
  table.insert(fieldItemMarkers, {
    root = root,
    item = itemWidget,
    count = root:recursiveGetChildById('count'),
    meta = root:recursiveGetChildById('meta')
  })
end

local function createFieldEventBurst()
  local root = g_ui.createWidget('SoundDebugFieldEventBurst', soundFieldMarkerLayer)
  local itemWidget = root:recursiveGetChildById('item')
  itemWidget:setVirtual(true)
  itemWidget:setShowCount(false)
  local creatureWidget = root:recursiveGetChildById('creature')
  if creatureWidget then
    creatureWidget:setCenter(true)
  end
  table.insert(fieldEventBursts, {
    root = root,
    item = itemWidget,
    creature = creatureWidget,
    core = root:recursiveGetChildById('core'),
    tag = root:recursiveGetChildById('tag')
  })
end

local widgetsInitialized = false

local function isDebugVisible()
  return soundDebugWindow and soundDebugWindow:isVisible()
end

local function syncOverlayVisibility()
  if not overlayWidget then
    return
  end

  local visible = isDebugVisible() and g_game.isOnline()
  overlayWidget:setVisible(visible)
  if visible then
    overlayWidget:raise()
  else
    hidePool(mapMarkers)
  end
end

local function setupWidgets()
  if widgetsInitialized then
    return
  end
  widgetsInitialized = true

  soundDebugWindow = g_ui.displayUI('sounddebug')
  soundDebugWindow:hide()

  headerLabel = soundDebugWindow:recursiveGetChildById('headerLabel')
  mixSummaryLabel = soundDebugWindow:recursiveGetChildById('mixSummaryLabel')
  sourceSummaryLabel = soundDebugWindow:recursiveGetChildById('sourceSummaryLabel')
  itemSummaryLabel = soundDebugWindow:recursiveGetChildById('itemSummaryLabel')
  eventSummaryLabel = soundDebugWindow:recursiveGetChildById('eventSummaryLabel')
  spatialSummaryLabel = soundDebugWindow:recursiveGetChildById('spatialSummaryLabel')
  metersPanel = soundDebugWindow:recursiveGetChildById('metersPanel')
  sourceList = soundDebugWindow:recursiveGetChildById('sourceList')
  itemsPanel = soundDebugWindow:recursiveGetChildById('itemsPanel')
  eventList = soundDebugWindow:recursiveGetChildById('eventList')
  soundField = soundDebugWindow:recursiveGetChildById('soundField')
  soundFieldStage = soundDebugWindow:recursiveGetChildById('soundFieldStage')
  soundFieldGrid = soundDebugWindow:recursiveGetChildById('soundFieldGrid')
  soundFieldFloorLayer = soundDebugWindow:recursiveGetChildById('soundFieldFloorLayer')
  soundFieldMarkerLayer = soundDebugWindow:recursiveGetChildById('soundFieldMarkerLayer')
  listenerPulse = soundDebugWindow:recursiveGetChildById('listenerPulse')
  listenerCore = soundDebugWindow:recursiveGetChildById('listenerCore')
  fieldPlayer = soundDebugWindow:recursiveGetChildById('fieldPlayer')

  overlayWidget = g_ui.createWidget('SoundDebugOverlay', modules.game_interface.getMapPanel())
  overlayWidget:hide()

  for _, def in ipairs(METER_ORDER) do
    createMeter(def)
  end

  for _ = 1, MAX_SOURCE_ROWS do
    createSourceRow()
  end
  for _ = 1, MAX_ITEM_CARDS do
    createItemCard()
  end
  for _ = 1, MAX_EVENT_ROWS do
    createEventRow()
  end
  for _ = 1, MAX_MAP_MARKERS do
    createMarker()
  end
  for _ = 1, FIELD_GRID_SIZE * FIELD_GRID_SIZE do
    createFieldFloorTile()
  end
  for _ = 1, MAX_FIELD_EVENT_BURSTS do
    createFieldEventBurst()
  end
  for _ = 1, MAX_FIELD_ITEM_MARKERS do
    createFieldItemMarker()
  end

  if listenerPulse then
    listenerPulse:raise()
  end
  if listenerCore then
    listenerCore:raise()
  end
  if fieldPlayer then
    fieldPlayer:setCenter(true)
    fieldPlayer:raise()
  end

  clearVisuals()
end

local function onVisibilityChange(visible)
  if visible then
    setupWidgets()
    soundDebugWindow:show()
    soundDebugWindow:raise()
    soundDebugWindow:focus()
    soundDebugButton:setOn(true)
  else
    if soundDebugWindow then
      soundDebugWindow:hide()
    end
    soundDebugButton:setOn(false)
    hidePool(mapMarkers)
    hidePool(fieldFloorTiles)
    hidePool(fieldItemMarkers)
    hidePool(fieldEventBursts)
  end

  syncOverlayVisibility()
end

function init()
  g_ui.importStyle('sounddebug.otui')

  soundDebugButton = modules.client_topmenu.addTopRightToggleButton('soundDebugButton', tr('Sound Debug'),
    '/images/topbuttons/audio', toggle)
  soundDebugButton:setOn(false)

  Keybind.new('Debug', 'Toggle Sound Debug', 'Ctrl+Alt+S', '')
  Keybind.bind('Debug', 'Toggle Sound Debug', {
    {
      type = KEY_DOWN,
      callback = toggle,
    }
  })

  connect(g_game, {
    onGameEnd = clearVisuals,
    onGameStart = syncOverlayVisibility
  })

  updateEvent = scheduleEvent(update, 80)
end

function terminate()
  disconnect(g_game, {
    onGameEnd = clearVisuals,
    onGameStart = syncOverlayVisibility
  })

  Keybind.delete('Debug', 'Toggle Sound Debug')

  removeEvent(updateEvent)

  if widgetsInitialized then
    clearVisuals()
  end

  if overlayWidget then
    overlayWidget:destroy()
    overlayWidget = nil
  end

  if soundDebugWindow then
    soundDebugWindow:destroy()
    soundDebugWindow = nil
  end

  if soundDebugButton then
    soundDebugButton:destroy()
    soundDebugButton = nil
  end

  widgetsInitialized = false
end

function toggle()
  onVisibilityChange(not isDebugVisible())
end

function onMiniWindowClose()
  onVisibilityChange(false)
end

local function buildChannelMap(snapshot)
  local channelMap = {}
  for _, channel in ipairs(snapshot.channels or {}) do
    channelMap[channel.id] = channel
  end
  return channelMap
end

local function updateMeter(meter, state, target, base, enabled, footer, meta, skin)
  if not meter or not state then
    return
  end

  local bodyHeight = meter.body:getHeight()
  if bodyHeight <= 0 then
    return
  end

  state.value = lerp(state.value, clamp(target, 0, 1), 0.35)
  state.peak = math.max(target, state.peak - 0.05)
  state.base = lerp(state.base or 0, clamp(base, 0, 1), 0.2)

  setFillLevel(meter.baseline, bodyHeight, state.base)
  setFillLevel(meter.fill, bodyHeight, state.value, 1)
  setMarkerLevel(meter.peak, bodyHeight, state.peak)

  meter.fill:setBackgroundColor(skin.color)
  meter.baseline:setBackgroundColor(skin.soft)
  meter.peak:setBackgroundColor(skin.accent)
  meter.fill:setOpacity(enabled and 1 or 0.18)
  meter.baseline:setOpacity(enabled and 0.55 or 0.15)
  meter.peak:setOpacity(enabled and 1 or 0.2)
  meter.footer:setText(footer)
  meter.meta:setText(meta)
  meter.root:setBackgroundColor(enabled and '#111821' or '#0a0f15')
end

local function updateMeters(snapshot)
  local channelMap = buildChannelMap(snapshot)
  local loudestChannel = nil
  local loudestActivity = 0
  for _, channel in ipairs(snapshot.channels or {}) do
    if (channel.activity or 0) > loudestActivity then
      loudestActivity = channel.activity or 0
      loudestChannel = channel
    end
  end

  local sourceHeadline = snapshot.sources and snapshot.sources[1] or nil
  local headlineName = sourceHeadline and basename(sourceHeadline.name) or 'silence'
  headerLabel:setText(string.format('master %d%% | live %d%% | %d active | hot %s | lead %s',
    snapshot.masterVolume or 0,
    roundPercent(snapshot.masterActivity),
    snapshot.totalSources or 0,
    loudestChannel and loudestChannel.name or 'silent',
    trimText(headlineName, 20)))

  mixSummaryLabel:setText(string.format('%s | %d recent positional bursts | %d ambient anchors',
    snapshot.audioEnabled and 'Audio engine online' or 'Audio engine muted',
    #(snapshot.events or {}),
    #(snapshot.items or {})))

  for _, def in ipairs(METER_ORDER) do
    local meter = meterWidgets[def.key or def.id]
    local state = meterStates[def.key or def.id]
    if def.key == 'master' then
      local enabled = snapshot.audioEnabled
      updateMeter(meter, state, snapshot.masterActivity or 0, (snapshot.masterVolume or 0) / 100, enabled,
        string.format('%d%%', snapshot.masterVolume or 0),
        string.format('%d src', snapshot.totalSources or 0), def)
    else
      local channel = channelMap[def.id] or { gain = 1, enabled = true, activity = 0, activeSources = 0 }
      local enabled = channel.enabled ~= false and snapshot.audioEnabled
      local footer = enabled and string.format('%d%%', roundPercent(channel.gain)) or 'OFF'
      local meta = channel.activeSources and channel.activeSources > 0 and string.format('%d src', channel.activeSources) or '--'
      updateMeter(meter, state, channel.activity or 0, channel.gain or 0, enabled, footer, meta, def)
    end
  end
end

local function updateSources(snapshot)
  local sources = snapshot.sources or {}
  local hidden = math.max(0, #sources - MAX_SOURCE_ROWS)
  if #sources == 0 then
    sourceSummaryLabel:setText('No active sources in the mixer.')
  else
    sourceSummaryLabel:setText(string.format('%d visible of %d active%s', math.min(#sources, MAX_SOURCE_ROWS), #sources,
      hidden > 0 and string.format(' (+%d hidden)', hidden) or ''))
  end

  for index, row in ipairs(sourceRows) do
    local source = sources[index]
    if not source then
      row.root:hide()
    else
      local skin = getChannelSkin(source.channelId)
      local badge = KIND_BADGES[source.kind] or 'SRC'
      local levelHeight = row.levelTrack:getHeight()
      row.root:show()
      row.root:setBackgroundColor(index % 2 == 0 and '#0f1620' or '#0b121a')
      row.badge:setBackgroundColor(skin.color)
      row.badgeText:setText(badge)
      row.title:setText(trimText(basename(source.name), 28))
      row.meta:setText(string.format('%s  g:%d%%  pan:%+.2f%s%s',
        source.channelName or 'Direct',
        roundPercent(source.gain),
        (source.position and source.position.x or 0),
        source.looping and '  loop' or '',
        source.streaming and '  stream' or ''))
      row.levelFill:setBackgroundColor(skin.color)
      setFillLevel(row.levelFill, levelHeight, source.gain or 0, 1)
    end
  end
end

local function updateItems(snapshot)
  local items = snapshot.items or {}
  if #items == 0 then
    itemSummaryLabel:setText('No ambient items active.')
  else
    local lead = items[1]
    itemSummaryLabel:setText(string.format('%d live anchors | nearest %s @ %.1f',
      #items,
      trimText(basename(lead.fileName), 12),
      lead.distance or 0))
  end

  for index, card in ipairs(itemCards) do
    local item = items[index]
    if not item then
      card.root:hide()
    else
      card.root:show()
      card.root:setBackgroundColor(index % 2 == 0 and '#111821' or '#0f1720')
      card.root:setBorderColor('#d4ba6c')
      if item.itemId and item.itemId > 0 then
        card.item:setItemVisible(true)
        card.item:setItemId(item.itemId)
      else
        card.item:clearItem()
        card.item:setItemVisible(false)
      end
      card.title:setText(trimText(basename((item.fileName and item.fileName ~= '' and item.fileName) or ('effect_' .. tostring(item.effectId))), 11))
      card.meta:setText(string.format('x%d  d%.1f', item.itemCount or 0, item.distance or 0))
      card.effect:setText(string.format('fx %d', item.effectId or 0))
    end
  end
end

local function updateEvents(snapshot)
  local events = snapshot.events or {}
  if #events == 0 then
    eventSummaryLabel:setText('No positional sound events yet.')
  else
    local newest = events[1]
    eventSummaryLabel:setText(string.format('%d recent bursts | latest %s age %.1fs',
      #events,
      trimText(basename(newest.fileName), 14),
      (newest.ageMs or 0) / 1000))
  end

  for index, row in ipairs(eventRows) do
    local event = events[index]
    if not event then
      row.root:hide()
    else
      local skin = getEventSkin(event)
      local fade = 1 - clamp((event.ageMs or EVENT_TTL_MS) / EVENT_TTL_MS, 0, 1)
      row.root:show()
      row.root:setOpacity(0.4 + fade * 0.6)
      row.badge:setBackgroundColor(skin.border)
      row.badgeText:setText(event.secondary and 'SEC' or 'OPC')
      row.badgeText:setColor(skin.text)
      row.title:setText(trimText(basename((event.fileName and event.fileName ~= '' and event.fileName) or ('effect_' .. tostring(event.soundEffectId))), 24))
      row.meta:setText(string.format('fx:%d  d:%.1f  g:%d%%  age:%.1fs',
        event.soundEffectId or 0,
        event.distance or 0,
        roundPercent(event.gain),
        (event.ageMs or 0) / 1000))
    end
  end
end

local function updateMapMarkers(snapshot)
  if not overlayWidget or not overlayWidget:isVisible() then
    hidePool(mapMarkers)
    return
  end

  local mapPanel = modules.game_interface.getMapPanel()
  local markerIndex = 1
  for _, event in ipairs(snapshot.events or {}) do
    if markerIndex > MAX_MAP_MARKERS then
      break
    end

    if isMapPosition(event.position) and mapPanel:isInRange(event.position) then
      local rect = mapPanel:getTileRect(event.position)
      if rect and rect.width and rect.width > 0 and rect.height and rect.height > 0 then
        local fade = 1 - clamp((event.ageMs or EVENT_TTL_MS) / EVENT_TTL_MS, 0, 1)
        local skin = getEventSkin(event)
        local size = math.max(18, math.floor(rect.width + 8 + (1 - fade) * 18 + (event.gain or 0) * 10))
        local marker = mapMarkers[markerIndex]
        marker.root:show()
        marker.root:setWidth(size)
        marker.root:setHeight(size)
        marker.root:setX(rect.x + math.floor(rect.width / 2) - math.floor(size / 2))
        marker.root:setY(rect.y + math.floor(rect.height / 2) - math.floor(size / 2))
        marker.root:setOpacity(0.25 + fade * 0.75)
        marker.ring:setBorderColor(skin.border)
        marker.ring:setBackgroundColor(skin.fill)
        marker.core:setBackgroundColor(skin.core)
        marker.tag:setColor(skin.text)
        marker.tag:setText(event.secondary and 'S' or 'O')
        markerIndex = markerIndex + 1
      end
    end
  end

  for index = markerIndex, #mapMarkers do
    mapMarkers[index].root:hide()
  end
end

local function setFieldWidgetCenteredOnTile(widget, tileX, tileY, tileSize, width, height, verticalBias)
  verticalBias = verticalBias or 0
  local x = math.floor(tileX * tileSize + (tileSize - width) / 2)
  local y = math.floor(tileY * tileSize + (tileSize - height) / 2 + verticalBias)
  widget:setWidth(width)
  widget:setHeight(height)
  widget:setMarginLeft(x)
  widget:setMarginTop(y)
end

local function getTilePreviewThing(position)
  if not isMapPosition(position) then
    return nil
  end

  local tile = g_map.getTile(position)
  if not tile then
    return nil
  end

  local topThing = tile:getTopUseThing()
  if topThing and topThing:isItem() then
    return topThing
  end

  local things = tile:getThings() or {}
  for index = #things, 1, -1 do
    local thing = things[index]
    if thing and thing:isItem() and not thing:isGround() then
      return thing
    end
  end

  return nil
end

local function syncFieldFloor(tileSize)
  if not soundFieldGrid or not soundFieldFloorLayer or not soundFieldMarkerLayer then
    return
  end

  local gridPixelSize = tileSize * FIELD_GRID_SIZE
  soundFieldGrid:setWidth(gridPixelSize)
  soundFieldGrid:setHeight(gridPixelSize)
  soundFieldFloorLayer:setWidth(gridPixelSize)
  soundFieldFloorLayer:setHeight(gridPixelSize)
  soundFieldMarkerLayer:setWidth(gridPixelSize)
  soundFieldMarkerLayer:setHeight(gridPixelSize)

  local index = 1
  for row = 0, FIELD_GRID_SIZE - 1 do
    for column = 0, FIELD_GRID_SIZE - 1 do
      local tile = fieldFloorTiles[index]
      if tile then
        tile.root:show()
        tile.root:setWidth(tileSize)
        tile.root:setHeight(tileSize)
        tile.root:setMarginLeft(column * tileSize)
        tile.root:setMarginTop(row * tileSize)
        local onAxis = row == FIELD_GRID_RADIUS or column == FIELD_GRID_RADIUS
        tile.root:setOpacity(onAxis and 1 or ((row + column) % 2 == 0 and 0.88 or 0.76))
      end
      index = index + 1
    end
  end
end

local function updateFieldTheme(snapshot, sameFloorEvents, sameFloorItems, tileSize)
  local eventActive = sameFloorEvents > 0
  local itemActive = sameFloorItems > 0
  local intensity = clamp((snapshot.masterActivity or 0) * 0.55 + sameFloorEvents * 0.11 + sameFloorItems * 0.08, 0, 1)
  local pulseBase = math.max(20, tileSize + 8)
  local pulseSize = pulseBase + math.floor(intensity * math.max(8, tileSize * 0.7) + 0.5)
  local coreSize = math.max(8, math.floor(tileSize * 0.45))
  local borderColor = eventActive and '#67dfff' or itemActive and '#f3d67c' or '#2b4052'
  local fillColor = eventActive and '#0b1a25' or itemActive and '#17140c' or '#09131d'

  if soundFieldStage then
    soundFieldStage:setBorderColor(borderColor)
    soundFieldStage:setBackgroundColor(fillColor)
  end

  if listenerPulse then
    listenerPulse:setWidth(pulseSize)
    listenerPulse:setHeight(pulseSize)
    listenerPulse:setBorderColor(borderColor)
    listenerPulse:setBackgroundColor(eventActive and '#67dfff18' or itemActive and '#f3d67c18' or '#f3d67c12')
    listenerPulse:setOpacity(0.22 + intensity * 0.48)
  end

  if listenerCore then
    listenerCore:setWidth(coreSize)
    listenerCore:setHeight(coreSize)
    listenerCore:setBackgroundColor(eventActive and '#effcff' or itemActive and '#fff1c4' or '#f8e6a2')
    listenerCore:setBorderColor(eventActive and '#9be9ff' or itemActive and '#ffe6a5' or '#fff6d8')
    listenerCore:setOpacity(0.75 + intensity * 0.25)
  end
end

local function updateFieldPlayer(localPlayer, tileSize)
  if not fieldPlayer or not localPlayer then
    return
  end

  local playerPos = localPlayer:getPosition()
  fieldPlayer:setOutfit(localPlayer:getOutfit())
  fieldPlayer:setDirection(localPlayer:getDirection())
  fieldPlayer:setCreatureSize(clamp(tileSize * 2, 40, 72))
  fieldPlayer:setCenter(true)
  fieldPlayer:setTooltip(string.format('local player\n(%d, %d, %d)', playerPos and playerPos.x or 0, playerPos and playerPos.y or 0, playerPos and playerPos.z or 0))
  fieldPlayer:show()
end

local function updateFieldItems(snapshot, playerPos, tileSize)
  local markerIndex = 1
  local sameFloorItems = 0

  for _, item in ipairs(snapshot.items or {}) do
    if isMapPosition(item.position) and item.position.z == playerPos.z then
      sameFloorItems = sameFloorItems + 1

      if markerIndex <= MAX_FIELD_ITEM_MARKERS then
        local marker = fieldItemMarkers[markerIndex]
        local deltaX = item.position.x - playerPos.x
        local deltaY = item.position.y - playerPos.y
        local gridX = FIELD_GRID_RADIUS + clamp(deltaX, -FIELD_GRID_RADIUS, FIELD_GRID_RADIUS)
        local gridY = FIELD_GRID_RADIUS + clamp(deltaY, -FIELD_GRID_RADIUS, FIELD_GRID_RADIUS)
        local clampedToEdge = math.abs(deltaX) > FIELD_GRID_RADIUS or math.abs(deltaY) > FIELD_GRID_RADIUS
        local itemSize = math.max(tileSize + 6, 28)
        local cardWidth = itemSize + 8
        local cardHeight = itemSize + 18
        local fileLabel = (item.fileName and item.fileName ~= '' and basename(item.fileName)) or ('effect_' .. tostring(item.effectId or 0))
        local tooltip = string.format('%s\nitem %d | x%d | d%.1f | (%d, %d, %d)%s',
          fileLabel,
          item.itemId or 0,
          item.itemCount or 0,
          item.distance or 0,
          item.position.x or 0,
          item.position.y or 0,
          item.position.z or 0,
          clampedToEdge and '\npreview clamped to edge' or '')

        marker.root:show()
        marker.root:setBorderColor(clampedToEdge and '#f5d992' or '#d4ba6c')
        marker.root:setBackgroundColor(clampedToEdge and '#171108ee' or '#111821ee')
        marker.root:setOpacity(0.96)
        setFieldWidgetCenteredOnTile(marker.root, gridX, gridY, tileSize, cardWidth, cardHeight, -math.floor(tileSize * 0.2))

        marker.item:setWidth(itemSize)
        marker.item:setHeight(itemSize)
        if item.itemId and item.itemId > 0 then
          marker.item:setItemVisible(true)
          marker.item:setItemId(item.itemId)
          marker.item:setItemCount(item.itemCount or 0)
        else
          marker.item:clearItem()
          marker.item:setItemVisible(false)
        end

        marker.count:setText(item.itemCount and item.itemCount > 0 and ('x' .. item.itemCount) or ('fx ' .. tostring(item.effectId or 0)))
        marker.meta:setText(string.format('d%.1f', item.distance or 0))
        marker.root:setTooltip(tooltip)
        marker.item:setTooltip(tooltip)
        marker.count:setTooltip(tooltip)
        marker.meta:setTooltip(tooltip)
        markerIndex = markerIndex + 1
      end
    end
  end

  for index = markerIndex, #fieldItemMarkers do
    fieldItemMarkers[index].root:hide()
  end

  return sameFloorItems
end

local function updateFieldEvents(snapshot, playerPos, tileSize)
  local burstIndex = 1
  local sameFloorEvents = 0

  for _, event in ipairs(snapshot.events or {}) do
    if isMapPosition(event.position) and event.position.z == playerPos.z then
      sameFloorEvents = sameFloorEvents + 1

      if burstIndex <= MAX_FIELD_EVENT_BURSTS then
        local burst = fieldEventBursts[burstIndex]
        local deltaX = event.position.x - playerPos.x
        local deltaY = event.position.y - playerPos.y
        local gridX = FIELD_GRID_RADIUS + clamp(deltaX, -FIELD_GRID_RADIUS, FIELD_GRID_RADIUS)
        local gridY = FIELD_GRID_RADIUS + clamp(deltaY, -FIELD_GRID_RADIUS, FIELD_GRID_RADIUS)
        local clampedToEdge = math.abs(deltaX) > FIELD_GRID_RADIUS or math.abs(deltaY) > FIELD_GRID_RADIUS
        local skin = getEventSkin(event)
        local fade = 1 - clamp((event.ageMs or EVENT_TTL_MS) / EVENT_TTL_MS, 0, 1)
        local burstSize = math.max(16, math.min(tileSize + 14, tileSize - 2 + math.floor((event.gain or 0) * 10 + (1 - fade) * 6)))
        local fileLabel = (event.fileName and event.fileName ~= '' and basename(event.fileName)) or ('effect_' .. tostring(event.soundEffectId or 0))

        -- look for a creature first, then fall back to an item at that tile
        local tileCreature = nil
        local tileThing = nil
        if isMapPosition(event.position) then
          local tile = g_map.getTile(event.position)
          if tile then
            tileCreature = tile:getTopCreature()
            tileThing = getTilePreviewThing(event.position)
          end
        end

        local thingLabel = tileCreature and tileCreature:getName() or
          (tileThing and ('item ' .. tileThing:getId()) or 'empty')
        local tooltip = string.format('%s\nfx %d | d%.1f | g:%d%% | (%d, %d, %d)\n%s%s',
          fileLabel,
          event.soundEffectId or 0,
          event.distance or 0,
          roundPercent(event.gain),
          event.position.x or 0,
          event.position.y or 0,
          event.position.z or 0,
          thingLabel,
          clampedToEdge and '\npreview clamped to edge' or '')

        burst.root:show()
        burst.root:setBorderColor(skin.border)
        burst.root:setBackgroundColor(skin.fill)
        burst.root:setOpacity(0.28 + fade * 0.72)
        burst.tag:setColor(skin.text)
        burst.tag:setText(event.secondary and 'S' or 'O')

        -- show creature sprite if one is at the tile, else show item, else show core dot
        if tileCreature and burst.creature then
          burst.creature:setOutfit(tileCreature:getOutfit())
          burst.creature:setCreatureSize(math.max(tileSize + 4, 28))
          burst.creature:setVisible(true)
          burst.item:setVisible(false)
          burst.core:setVisible(false)
        elseif tileThing then
          burst.item:setItemVisible(true)
          burst.item:setItemId(tileThing:getId())
          burst.item:setItemCount(tileThing.getCount and tileThing:getCount() or 0)
          burst.item:setWidth(math.max(tileSize - 4, 18))
          burst.item:setHeight(math.max(tileSize - 4, 18))
          burst.item:setVisible(true)
          if burst.creature then burst.creature:setVisible(false) end
          burst.core:setVisible(false)
        else
          burst.item:clearItem()
          burst.item:setVisible(false)
          if burst.creature then burst.creature:setVisible(false) end
          burst.core:setVisible(true)
          burst.core:setBackgroundColor(skin.core)
        end

        setFieldWidgetCenteredOnTile(burst.root, gridX, gridY, tileSize, burstSize, burstSize)
        burst.root:setTooltip(tooltip)
        burst.item:setTooltip(tooltip)
        burst.core:setTooltip(tooltip)
        burst.tag:setTooltip(tooltip)
        burst.root:raise()
        burstIndex = burstIndex + 1
      end
    end
  end

  for index = burstIndex, #fieldEventBursts do
    fieldEventBursts[index].root:hide()
  end

  return sameFloorEvents
end

local function updateSpatialField(snapshot)
  local localPlayer = g_game.getLocalPlayer()
  if not localPlayer or not localPlayer:getPosition() then
    hidePool(fieldFloorTiles)
    hidePool(fieldItemMarkers)
    hidePool(fieldEventBursts)
    resetFieldTheme()
    spatialSummaryLabel:setText('Preview is waiting for a tracked listener.')
    return
  end

  local playerPos = localPlayer:getPosition()
  if not isMapPosition(playerPos) then
    hidePool(fieldFloorTiles)
    hidePool(fieldItemMarkers)
    hidePool(fieldEventBursts)
    resetFieldTheme()
    spatialSummaryLabel:setText('Preview is waiting for a tracked listener.')
    return
  end

  local fieldRoot = soundFieldStage or soundField
  local fieldWidth = fieldRoot:getWidth()
  local fieldHeight = fieldRoot:getHeight()
  if fieldWidth <= 0 or fieldHeight <= 0 then
    return
  end

  local tileSize = clamp(math.floor(math.min((fieldWidth - 24) / FIELD_GRID_SIZE, (fieldHeight - 24) / FIELD_GRID_SIZE)), 18, 32)

  syncFieldFloor(tileSize)
  updateFieldPlayer(localPlayer, tileSize)

  local sameFloorItems = updateFieldItems(snapshot, playerPos, tileSize)
  local sameFloorEvents = updateFieldEvents(snapshot, playerPos, tileSize)

  updateFieldTheme(snapshot, sameFloorEvents, sameFloorItems, tileSize)
  if fieldPlayer then
    fieldPlayer:raise()
  end
  spatialSummaryLabel:setText(string.format('preview +/- %d sqm | z:%d | floor items %d/%d | opcode bursts %d/%d | overlay %s',
    FIELD_GRID_RADIUS,
    playerPos.z,
    sameFloorItems,
    #(snapshot.items or {}),
    sameFloorEvents,
    #(snapshot.events or {}),
    overlayWidget and overlayWidget:isVisible() and 'online' or 'hidden'))
end

function update()
  updateEvent = scheduleEvent(update, isDebugVisible() and 80 or 250)

  if not isDebugVisible() then
    return
  end

  syncOverlayVisibility()

  local snapshot = g_sounds.getDebugSnapshot()
  if not snapshot then
    clearVisuals()
    return
  end

  updateMeters(snapshot)
  updateSources(snapshot)
  updateItems(snapshot)
  updateEvents(snapshot)
  updateMapMarkers(snapshot)
  updateSpatialField(snapshot)
end
