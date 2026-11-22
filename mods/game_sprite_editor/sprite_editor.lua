local window
local topMenuButton
local canvas
local workCopyService
local activeVersion
local activeAssetPath
local activeWorkRoot
local selectedAppearanceCategory = 0
local selectedAppearanceId
local selectedSpriteId
local appearanceCatalog
local appearanceProperties
local appearanceOriginal
local appearanceChanges = { bools = {}, values = {}, strings = {}, textValues = {}, multiValues = {}, animation = { groups = {} } }
local animationWidgets = {}
local buildingAppearanceProperties = false
local currentPage = 'editor'
local currentPropertiesTab = 'flags'
local previewFrameGroups = {}
local previewFrameGroupIndex = 1
local previewPatternX = 0
local previewPatternY = 0
local previewPatternZ = 0
local previewLayer = 0
local previewPhase = 0
local previewMounted = false
local previewMoving = false
local previewIdleGroupIndex
local previewMovingGroupIndex
local previewHasMovementToggle = false
local previewAnimationPlayer
local timelineScrubbing = false
local previewZoomChangingFromSlider = false
local gameStartCallback
local gameEndCallback
local pendingSpriteEdit
local preparedSpritePath = ''
local settingSpritePath = false
local spritePickerSourceId
local selectedReplacementSpriteId
local selectedCreateSpriteId
local spritePicker
local persistEditorUiState
local capturePreviewSelection
local currentImportSection = 'replace'
local currentReplaceMode = 'sprite'
local currentNewAppearanceSourceMode = 'sprite'
local currentExportSubpage = 'assets'
local currentExportMode = 'replace'
local pngFilePicker
local savedEditorUiState = {}
local editorUiStateSaveEvent
local restoringEditorUiState = false
local installedAssetBackups = {}
local selectedInstalledBackupName
local installedAssetBackupChanges = {}
local selectedInstalledBackupChange
local assetEditHistoryEntries = {}
local selectedAssetEditHistoryEntry
local canaryAppearanceWarningShown = false
local getUserFacingError

local SPRITE_PICKER_WIDGET_IDS = {
   replace = {
      search = 'spriteSearchEdit',
      count = 'spritePickerCountLabel',
      list = 'spritePickerList',
      content = 'spritePickerContent',
      selection = 'selectedReplacementSpriteLabel',
   },
   create = {
      search = 'newAppearanceSpriteSearchEdit',
      count = 'newAppearanceSpritePickerCountLabel',
      list = 'newAppearanceSpritePickerList',
      content = 'newAppearanceSpritePickerContent',
      selection = 'newAppearanceSelectedSpriteLabel',
   },
}

local EXTERNAL_EDITOR_SETTING = 'offline-assets-editor-external-editor'
local EDITOR_UI_STATE_SETTING = 'offline-assets-editor-ui-state'
local EDITOR_UI_STATE_SAVE_DELAY = 400

local STATUS_COLOR_DEFAULT = '#c6c6c6'
local STATUS_COLOR_SUCCESS = '#8fda9b'
local MAX_SPRITE_ID = 2147483647
local MAX_PREVIEW_ZOOM = 64
local PREVIEW_CONTROLS_BOTTOM_MARGIN = 14
local PREVIEW_ZOOM_CONTROL_GAP = 8
local PREVIEW_CANVAS_BOTTOM_MARGIN = 4
local MAX_PREVIEW_TIMELINE_FRAMES = 20
local PREVIEW_TIMELINE_HEIGHT = 100
local PREVIEW_TIMELINE_ONLY_HEIGHT = 56
local PREVIEW_TIMELINE_CELL_WIDTH = 30
local PREVIEW_TIMELINE_TRACK_HEIGHT = 22
local PREVIEW_FRAME_SELECTION_WIDTH = 164
local PREVIEW_DURATION_GROUP_GAP = 6
local PREVIEW_DIRECTION_BUTTON_WIDTH = 48
local PREVIEW_DIRECTION_BUTTON_HEIGHT = 21
local PREVIEW_DIRECTION_PAD_GAP = 8
local MAX_APPEARANCE_THUMBNAIL_FRAMES = 8

local PREVIEW_DIRECTIONS = {
   { index = 0, id = 'previewNorth', name = 'North' },
   { index = 1, id = 'previewEast', name = 'East' },
   { index = 2, id = 'previewSouth', name = 'South' },
   { index = 3, id = 'previewWest', name = 'West' },
   { index = 4, id = 'previewNorthEast', name = 'North-east' },
   { index = 5, id = 'previewSouthEast', name = 'South-east' },
   { index = 6, id = 'previewSouthWest', name = 'South-west' },
   { index = 7, id = 'previewNorthWest', name = 'North-west' },
}

local categories = {
   { name = 'Objects', singular = 'Object', data = 0 },
   { name = 'Outfits', singular = 'Outfit', data = 1 },
   { name = 'Effects', singular = 'Effect', data = 2 },
   { name = 'Missiles', singular = 'Missile', data = 3 },
}

local selectAppearance
local selectSprite
local renderAppearanceRows
local configurePreviewControls
local updateAnimationEditor
local stopPreviewAnimation
local updatePreviewTimelineSelection
local selectPreviewPhase
local updatePreviewPatternControls
local refreshAppearancePreview
local collectAnimationWidgetChanges
local updateDirectionPadLayout
local updatePreviewZoomControl
local refreshSpritePicker
local renderSpritePickerRows
local applySpritePickerFilter
local refreshAppearanceCatalog
local applyAppearanceFilter
local updateCategoryOptions
local updateExportControls
local setActivePage
local refreshAssetEditHistory
local updateInstalledBackupDetails
local formatClientVersion
local loadAppearanceRecord
local reloadAssets
local importPngAsNewSprite
local selectSpritePickerSprite
local linkSpriteToSelectedFrame
local replaceSelectedFrameWithSprite
local updateSpriteReplacementTarget
local getAppearancePropertiesEditor

local function getSpritePickerWidget(name)
   if not window then
      return nil
   end
   local section = currentImportSection
   if name:sub(1, 8) == 'replace_' then
      section = 'replace'
      name = name:sub(9)
   elseif name:sub(1, 7) == 'create_' then
      section = 'create'
      name = name:sub(8)
   end
   local ids = SPRITE_PICKER_WIDGET_IDS[section]
   return ids and window:recursiveGetChildById(ids[name]) or nil
end

local function getSelectedSpritePickerId()
   if currentImportSection == 'create' then
      return selectedCreateSpriteId
   end
   return selectedReplacementSpriteId
end

local function setSelectedSpritePickerId(spriteId)
   if currentImportSection == 'create' then
      selectedCreateSpriteId = spriteId
   else
      selectedReplacementSpriteId = spriteId
   end
   if persistEditorUiState then
      persistEditorUiState()
   end
end

local function setStatus(message, success)
   if window then
      local label = window:recursiveGetChildById('statusLabel')
      label:setText(tr('Status: %s', message))
      label:setColor(success and STATUS_COLOR_SUCCESS or STATUS_COLOR_DEFAULT)
   end
end

local function setExportStatus(message, success)
   if not window then
      return
   end
   local label = window:recursiveGetChildById('exportStatus')
   label:setText(message)
   label:setColor(success and STATUS_COLOR_SUCCESS or STATUS_COLOR_DEFAULT)
end

local function getWorkCopyService()
   if not workCopyService then
      workCopyService = SpriteEditorWorkCopyService.new()
   end
   return workCopyService
end

local function getWorkCopyHistoryState()
   if not activeVersion then
      return { undo = 0, redo = 0 }
   end
   local ok, encoded = pcall(g_spriteAppearances.getWorkCopyHistoryState, activeVersion)
   if not ok then
      return { undo = 0, redo = 0 }
   end
   local decoded, state = pcall(json.decode, encoded)
   if not decoded or type(state) ~= 'table' then
      return { undo = 0, redo = 0 }
   end
   return state
end

local function updateHistoryControls()
   if not window then
      return
   end
   local active = activeVersion ~= nil and not g_game.isOnline()
   local state = getWorkCopyHistoryState()
   local undo = window:recursiveGetChildById('undoButton')
   local redo = window:recursiveGetChildById('redoButton')
   undo:setVisible(active)
   redo:setVisible(active)
   undo:setEnabled(active and (tonumber(state.undo) or 0) > 0)
   redo:setEnabled(active and (tonumber(state.redo) or 0) > 0)
end

local function getAppearanceHistoryChanges(beforeData, afterData)
   if type(beforeData) ~= 'table' or type(afterData) ~= 'table' then
      return {}
   end
   local changed = {}
   local function compare(before, after, path)
      if #changed >= 24 then
         return
      end
      if type(before) == 'table' and type(after) == 'table' then
         local keys = {}
         for key in pairs(before) do
            if key ~= 'enumOptions' then keys[key] = true end
         end
         for key in pairs(after) do
            if key ~= 'enumOptions' then keys[key] = true end
         end
         for key in pairs(keys) do
            compare(before[key], after[key], path == '' and tostring(key) or path .. '.' .. tostring(key))
         end
         return
      end
      if before ~= after then
         table.insert(changed, path)
      end
   end
   compare(beforeData, afterData, '')
   return changed
end

local function showCanaryAppearanceWarning()
   if canaryAppearanceWarningShown then
      return
   end
   canaryAppearanceWarningShown = true

   local messageBox
   local function acknowledge()
      messageBox:ok()
   end
   local message = tr('An appearance definition changed in this work copy. ' ..
      'Canary loads server appearance definitions from its configured core directory at ' ..
      'items/appearances.dat (data/items/appearances.dat by default). Update that file with the ' ..
      'matching appearance data and restart Canary before testing. ' ..
      'Changes to sprite pixels alone do not require changing that server file.')
   messageBox = displayGeneralBox(tr('Canary appearance data changed'),
      message, {
         { text = tr('OK'), callback = acknowledge },
      }, acknowledge, acknowledge)
end

local function runWorkCopyEdit(label, operation, historyContext)
   historyContext = historyContext or {}
   local category = historyContext.category
   if category == nil then category = selectedAppearanceCategory end
   local beforeId = historyContext.beforeAppearanceId
   if beforeId == nil and historyContext.captureBeforeAppearance ~= false then
      beforeId = historyContext.appearanceId or selectedAppearanceId
   end
   local afterId = historyContext.appearanceId or beforeId
   local spriteId = historyContext.spriteId
   local snapshotSpriteId = historyContext.captureSpritePixels and historyContext.spriteId or nil
   local beforeAppearance
   local beforeAppearanceData
   local beforeSprite
   local appearanceDataChanged = false
   local appearanceName = historyContext.appearanceName or (appearanceOriginal and appearanceOriginal.name) or ''
   if category ~= nil and beforeId then
      local ok, snapshot = pcall(g_things.getAppearanceEditorSnapshot, activeVersion, category, beforeId)
      if ok then beforeAppearance = snapshot end
      local dataOk, encoded = pcall(g_things.getAppearanceEditorData, activeVersion, category, beforeId)
      if dataOk then
         local decoded, data = pcall(json.decode, encoded)
         if decoded and type(data) == 'table' then beforeAppearanceData = data end
      end
   end
   if snapshotSpriteId then
      local ok, snapshot = pcall(g_spriteAppearances.getSpriteImagePngBase64, activeVersion, snapshotSpriteId)
      if ok then
         beforeSprite = snapshot
      else
         return false, tr('The current sprite could not be added to asset history: %s', getUserFacingError(snapshot))
      end
   end

   local started, startError = pcall(g_spriteAppearances.beginWorkCopyEdit, activeVersion)
   if not started then
      return false, getUserFacingError(startError)
   end

   local succeeded, result = pcall(operation)
   local historyError
   if succeeded and result ~= false then
      if historyContext.resultIsAppearanceId and tonumber(result) then
         afterId = tonumber(result)
      elseif historyContext.resolveAppearanceId then
         local ok, resolvedId = pcall(historyContext.resolveAppearanceId, result)
         if ok then afterId = tonumber(resolvedId) or afterId end
      end
      if historyContext.resultIsSpriteId and tonumber(result) then
         spriteId = tonumber(result)
      end
      local afterAppearance
      local afterAppearanceData
      local afterSprite
      local afterPresent = false
      if category ~= nil and afterId then
         local ok, snapshot = pcall(g_things.getAppearanceEditorSnapshot, activeVersion, category, afterId)
         if ok then
            afterAppearance = snapshot
            afterPresent = true
         end
         local dataOk, encoded = pcall(g_things.getAppearanceEditorData, activeVersion, category, afterId)
         if dataOk then
            local decoded, data = pcall(json.decode, encoded)
            if decoded and type(data) == 'table' then afterAppearanceData = data end
         end
      end
      if snapshotSpriteId then
         local ok, snapshot = pcall(g_spriteAppearances.getSpriteImagePngBase64, activeVersion, snapshotSpriteId)
         if ok then afterSprite = snapshot end
      end
      local categoryInfo = categories[(category or -1) + 1]
      local changedFields = getAppearanceHistoryChanges(beforeAppearanceData, afterAppearanceData)
      appearanceDataChanged = #changedFields > 0 or
         (beforeAppearanceData == nil) ~= (afterAppearanceData == nil)
      local entry = {
         action = historyContext.action or 'edit',
         label = label,
         summary = historyContext.summary or label,
         category = category,
         categoryName = categoryInfo and categoryInfo.name or '',
         appearanceId = afterId or beforeId,
         appearanceName = appearanceName,
         beforeAppearancePresent = beforeAppearance ~= nil,
         beforeAppearanceSnapshot = beforeAppearance or '',
         afterAppearancePresent = afterPresent,
         afterAppearanceSnapshot = afterAppearance or '',
         changedFields = changedFields,
         spriteId = spriteId or 0,
         beforeSpritePng = beforeSprite or '',
         afterSpritePng = afterSprite or '',
      }
      local saved, err = pcall(g_spriteAppearances.appendAssetEditHistory, activeVersion, json.encode(entry))
      if not saved then
         historyError = getUserFacingError(err)
         g_logger.error('[game_sprite_editor] Unable to save asset edit history: ' .. tostring(err))
      end
   end

   local recorded, changedOrError = pcall(g_spriteAppearances.commitWorkCopyEdit, activeVersion, label)
   updateHistoryControls()
   if not recorded then
      return false, tr('The edit may have been applied, but its undo history could not be saved: %s',
         getUserFacingError(changedOrError))
   end
   if historyError then
      refreshAssetEditHistory()
      if changedOrError == true and appearanceDataChanged then
         showCanaryAppearanceWarning()
      end
      setStatus(tr('Edit saved, but its portable history entry could not be written: %s', historyError))
      return true, result, changedOrError
   end
   if not succeeded then
      return false, getUserFacingError(result)
   end
   refreshAssetEditHistory()
   if changedOrError == true and appearanceDataChanged then
      showCanaryAppearanceWarning()
   end
   return true, result, changedOrError
end

local function setHistoryEntryPreview(row, entry)
   local thumbnail = row:recursiveGetChildById('historyThumbnail')
   local loaded = false
   local appearanceId = tonumber(entry.appearanceId)
   local category = tonumber(entry.category)
   local thing
   if appearanceId and category then
      local ok, result = pcall(g_things.getThingType, appearanceId, category)
      if ok then
         thing = result
      end
   end

   if thing then
      local ok, animationSprites = pcall(thing.getThumbnailAnimationSprites, thing)
      if ok and type(animationSprites) == 'table' and #animationSprites > 1 then
         loaded = thumbnail:setSpriteAnimationIds(animationSprites)
      end
      if not loaded then
         local ok, sprites = pcall(thing.getSprites, thing)
         if ok and type(sprites) == 'table' then
            for _, spriteId in ipairs(sprites) do
               if spriteId > 0 then
                  loaded = thumbnail:setThumbnailSpriteId(spriteId)
                  if loaded then
                     break
                  end
               end
            end
         end
      end
   end

   local spriteId = tonumber(entry.spriteId)
   if not loaded and spriteId and spriteId > 0 then
      loaded = thumbnail:setThumbnailSpriteId(spriteId)
   end
   thumbnail:setVisible(loaded)
   return loaded
end

local function formatHistoryEntryTimestamp(entry)
   local date, time = tostring(entry.createdAt or ''):match(
      '^(%d%d%d%d%-%d%d%-%d%d)T(%d%d:%d%d):%d%dZ$')
   return date and string.format('%s %sZ', date, time) or tostring(entry.createdAt or '')
end

local function formatHistoryEntryRow(entry)
   local category = entry.categoryName and entry.categoryName ~= '' and tr(entry.categoryName) or tr('Assets')
   local appearanceId = tonumber(entry.appearanceId)
   local subject = appearanceId and tr('%s %d', category, appearanceId) or category
   local spriteId = tonumber(entry.spriteId)
   if spriteId and spriteId > 0 then
      subject = tr('%s | Sprite %d', subject, spriteId)
   end
   return string.format('%s\n%s\n%s', subject, tostring(entry.label or tr('Edit')),
      formatHistoryEntryTimestamp(entry))
end

local function updateAssetEditHistoryDetails()
   if not window then
      return
   end
   local entry = selectedAssetEditHistoryEntry
   local title = window:recursiveGetChildById('historyDetailTitle')
   local details = window:recursiveGetChildById('historyDetailLabel')
   local restore = window:recursiveGetChildById('restoreHistoryButton')
   if not entry then
      title:setText(tr('Select an edit'))
      details:setText(#assetEditHistoryEntries == 0 and tr('No recorded edits for this package yet.') or
         tr('Choose an entry to see its details and restore the previous state.'))
      restore:setEnabled(false)
      return
   end

   local category = entry.categoryName and entry.categoryName ~= '' and tr(entry.categoryName) or tr('Appearance')
   local appearanceId = tonumber(entry.appearanceId)
   local spriteId = tonumber(entry.spriteId)
   title:setText(appearanceId and tr('%s %d', category, appearanceId) or tr('Asset edit'))
   local parts = { tostring(entry.summary or entry.label or tr('Asset edit')) }
   if entry.appearanceName and entry.appearanceName ~= '' then
      table.insert(parts, tr('Name: %s', entry.appearanceName))
   end
   if spriteId and spriteId > 0 then
      table.insert(parts, tr('Sprite ID: %d', spriteId))
   end
   if type(entry.changedFields) == 'table' and #entry.changedFields > 0 then
      local fieldLabels = {}
      local count = math.min(#entry.changedFields, 4)
      for index = 1, count do
         local field = tostring(entry.changedFields[index])
         local group, sprite = field:match('^frameGroups%.(%d+)%.sprites%.(%d+)$')
         if group then
            field = tr('Frame group %s, sprite slot %s', group, sprite)
         else
            field = field:gsub('^bools%.', ''):gsub('^values%.', '')
               :gsub('^textValues%.', ''):gsub('^multiValues%.', '')
            field = field:gsub('^strings%.name$', tr('Name')):gsub('^strings%.description$', tr('Description'))
         end
         table.insert(fieldLabels, field)
      end
      if #entry.changedFields > count then
         table.insert(fieldLabels, #entry.changedFields >= 24 and tr('Other changed fields') or
            tr('+%d more', #entry.changedFields - count))
      end
      table.insert(parts, tr('Changed: %s', table.concat(fieldLabels, ', ')))
   end
   if entry.createdAt then
      table.insert(parts, tostring(entry.createdAt))
   end
   details:setText(table.concat(parts, '\n'))
   restore:setEnabled(activeVersion ~= nil and not g_game.isOnline() and appearanceId ~= nil and
      entry.beforeAppearancePresent ~= nil and
      (entry.beforeAppearancePresent == true or entry.afterAppearancePresent == true or
         spriteId and spriteId > 0 and entry.beforeSpritePng ~= ''))
end

refreshAssetEditHistory = function()
   assetEditHistoryEntries = {}
   selectedAssetEditHistoryEntry = nil
   if not window or not activeVersion then
      return
   end
   local ok, encoded = pcall(g_spriteAppearances.getAssetEditHistory, activeVersion)
   if not ok then
      g_logger.warning('[game_sprite_editor] Unable to load portable asset history: ' .. tostring(encoded))
      return
   end
   local decoded, history = pcall(json.decode, encoded)
   if decoded and type(history) == 'table' and type(history.entries) == 'table' then
      assetEditHistoryEntries = history.entries
   end

   local list = window:recursiveGetChildById('assetEditHistoryList')
   list:destroyChildren()
   selectedAssetEditHistoryEntry = assetEditHistoryEntries[#assetEditHistoryEntries]
   for index = #assetEditHistoryEntries, 1, -1 do
      local entry = assetEditHistoryEntries[index]
      local row = g_ui.createWidget('AssetEditHistoryEntry', list)
      row.historyEntryId = entry.id
      row:recursiveGetChildById('historyText'):setText(formatHistoryEntryRow(entry))
      row:setTooltip(entry.appearanceName and entry.appearanceName ~= '' and
         tr('%s\nName: %s', formatHistoryEntryRow(entry), entry.appearanceName) or
         formatHistoryEntryRow(entry))
      setHistoryEntryPreview(row, entry)
      local rowEntry = entry
      row.onClick = function()
         selectedAssetEditHistoryEntry = rowEntry
         for _, candidate in ipairs(list:getChildren()) do
            candidate:setOn(candidate == row)
         end
         updateAssetEditHistoryDetails()
      end
      row:setOn(selectedAssetEditHistoryEntry and selectedAssetEditHistoryEntry.id == entry.id)
   end
   if g_spriteAppearances.releaseDecodedSpriteSheets then
      g_spriteAppearances.releaseDecodedSpriteSheets()
   end
   window:recursiveGetChildById('historySourceLabel'):setText(
      tr('Working copy %s | %d saved edits', formatClientVersion(activeVersion), #assetEditHistoryEntries))
   updateAssetEditHistoryDetails()
end

local function refreshInstalledAssetBackups()
   installedAssetBackups = {}
   if not activeVersion then
      return
   end
   local ok, encoded = pcall(g_spriteAppearances.getInstalledAssetBackups, activeVersion)
   if not ok then
      g_logger.warning('[game_sprite_editor] Unable to list installed asset backups: ' .. tostring(encoded))
      return
   end
   local decoded, backups = pcall(json.decode, encoded)
   if decoded and type(backups) == 'table' then
      for _, name in ipairs(backups) do
         if type(name) == 'string' then
            local label = name
            local timestamp = name:match('^%d+%-(%d+)')
            local milliseconds = tonumber(timestamp)
            if milliseconds and milliseconds >= 1000000000000 then
               local seconds = math.floor(milliseconds / 1000)
               local date = os.date('%Y-%m-%d %H:%M:%S', seconds)
               local timezone = os.date('%z', seconds)
               if date then
                  label = string.format('%s.%03d %s', date, milliseconds % 1000,
                     timezone and timezone ~= '%z' and timezone or tr('local time'))
               end
            end
            table.insert(installedAssetBackups, { label = label, data = name, timestamp = milliseconds })
         end
      end
   end
   table.sort(installedAssetBackups, function(left, right)
      if left.timestamp and right.timestamp and left.timestamp ~= right.timestamp then
         return left.timestamp > right.timestamp
      end
      if left.timestamp ~= nil and right.timestamp == nil then
         return true
      end
      if right.timestamp ~= nil and left.timestamp == nil then
         return false
      end
      return left.data > right.data
   end)
   if selectedInstalledBackupName then
      local selectedFound = false
      for _, backup in ipairs(installedAssetBackups) do
         if backup.data == selectedInstalledBackupName then
            selectedFound = true
            break
         end
      end
      if not selectedFound then
         selectedInstalledBackupName = nil
      end
   end
end

local function getInstalledAssetBackup(name)
   for _, backup in ipairs(installedAssetBackups) do
      if backup.data == name then
         return backup
      end
   end
end

local function getAppearanceCatalogComponent()
   if appearanceCatalog then
      return appearanceCatalog
   end

   appearanceCatalog = SpriteEditorAppearanceCatalog.new(categories, {
      get_widget = function(id)
         return window and window:recursiveGetChildById(id) or nil
      end,
      get_window = function() return window end,
      get_active_version = function() return activeVersion end,
      get_selected_category = function() return selectedAppearanceCategory end,
      get_selected_appearance_id = function() return selectedAppearanceId end,
      select_appearance = function(category, id)
         selectAppearance(category, id)
      end,
      on_filter_change = function()
         if updateExportControls then
            updateExportControls()
         end
         if persistEditorUiState then
            persistEditorUiState()
         end
      end,
      on_scroll_change = function()
         if persistEditorUiState then
            persistEditorUiState()
         end
      end,
   })
   return appearanceCatalog
end

renderAppearanceRows = function(scrollY)
   getAppearanceCatalogComponent():render_rows(scrollY)
end

refreshAppearanceCatalog = function(category)
   getAppearanceCatalogComponent():refresh(category)
end

applyAppearanceFilter = function()
   getAppearanceCatalogComponent():apply_filter()
end

updateCategoryOptions = function()
   getAppearanceCatalogComponent():update_category_options()
end

local function getFilteredAppearanceEntry(index)
   return getAppearanceCatalogComponent():get_filtered_entry(index)
end

local function getAppearanceEntryCount()
   return getAppearanceCatalogComponent():get_entry_count()
end

local function getSpritePickerComponent()
   if spritePicker then
      return spritePicker
   end

   spritePicker = SpriteEditorSpritePicker.new({
      get_widget = getSpritePickerWidget,
      get_window = function() return window end,
      get_active_version = function() return activeVersion end,
      get_section = function() return currentImportSection end,
      get_selected_id = getSelectedSpritePickerId,
      get_selected_frame_sprite_id = function() return selectedSpriteId end,
      get_canvas = function() return canvas end,
      clear_selection = function() setSelectedSpritePickerId(nil) end,
      select_sprite = function(spriteId)
         setSelectedSpritePickerId(spriteId)
         updateSpriteReplacementTarget()
      end,
      set_status = function(message) setStatus(message) end,
      on_filter_change = function()
         if persistEditorUiState then
            persistEditorUiState()
         end
      end,
      on_scroll_change = function()
         if persistEditorUiState then
            persistEditorUiState()
         end
      end,
   })
   return spritePicker
end

refreshSpritePicker = function()
   getSpritePickerComponent():refresh()
end

renderSpritePickerRows = function(scrollY)
   getSpritePickerComponent():render_rows(scrollY)
end

applySpritePickerFilter = function()
   getSpritePickerComponent():apply_filter()
end

selectSpritePickerSprite = function(spriteId)
   getSpritePickerComponent():select(spriteId)
end

local function setAppearanceStatus(message, success)
   if window then
      local label = window:recursiveGetChildById('appearanceStatus')
      label:setText(message)
      label:setColor(success and STATUS_COLOR_SUCCESS or STATUS_COLOR_DEFAULT)
   end
end

getUserFacingError = function(error)
   local message = tostring(error)
   local stackTraceStart = message:find('\nstack traceback:', 1, true)
   if stackTraceStart then
      message = message:sub(1, stackTraceStart - 1)
   end
   message = message:gsub('^C%+%+ call failed: ', '')
   return message
end

local function getSupportedAssetVersions()
   local versions = {}
   for _, version in ipairs(g_game.getSupportedClients()) do
      if version >= 1500 and version < 1600 then
         table.insert(versions, version)
      end
   end
   return versions
end

local function isSupportedAssetVersion(version)
   if not version or version < 1500 or version >= 1600 or version % 1 ~= 0 then
      return false
   end
   for _, supportedVersion in ipairs(getSupportedAssetVersions()) do
      if supportedVersion == version then
         return true
      end
   end
   return false
end

local function getVersions()
   local versions = {}
   for _, entry in ipairs(g_resources.listDirectoryFiles('/data/things/')) do
      local version = tonumber(entry)
      if isSupportedAssetVersion(version) and modules.client_assets.isClientVersionInstalled(version) then
         table.insert(versions, version)
      end
   end
   table.sort(versions, function(a, b) return a > b end)
   return versions
end

local function getSelectableAssetVersions()
   local versions = getSupportedAssetVersions()
   table.sort(versions, function(a, b) return a > b end)
   return versions
end

local function getSavedPreviewSelection(selection)
   if type(selection) ~= 'table' then
      return nil
   end
   local groupIndex = tonumber(selection.groupIndex)
   if not groupIndex or groupIndex < 1 then
      return nil
   end
   return {
      groupType = tonumber(selection.groupType) or 0,
      groupId = tonumber(selection.groupId),
      groupIndex = math.floor(groupIndex),
      patternX = math.max(0, math.floor(tonumber(selection.patternX) or 0)),
      patternY = math.max(0, math.floor(tonumber(selection.patternY) or 0)),
      patternZ = math.max(0, math.floor(tonumber(selection.patternZ) or 0)),
      layer = math.max(0, math.floor(tonumber(selection.layer) or 0)),
      phase = math.max(0, math.floor(tonumber(selection.phase) or 0)),
      mounted = selection.mounted == true,
   }
end

local function restoreEditorUiStateFromSettings()
   local state = g_settings.getNode(EDITOR_UI_STATE_SETTING)
   if type(state) ~= 'table' then
      return
   end

   local page = state.page
   if page ~= 'editor' and page ~= 'import' and page ~= 'export' and page ~= 'history' then
      page = 'editor'
   end
   local propertiesTab = state.propertiesTab == 'values' and 'values' or 'flags'
   local importSection = state.importSection
   if importSection ~= 'replace' and importSection ~= 'create' and importSection ~= 'batch' and
         importSection ~= 'sheet' and importSection ~= 'bundle' then
      importSection = 'replace'
   end
   local replaceMode = state.replaceMode == 'png' and 'png' or 'sprite'
   local newAppearanceSourceMode = state.newAppearanceSourceMode == 'png' and 'png' or 'sprite'
   local exportSubpage = state.exportSubpage == 'backups' and 'backups' or 'assets'
   local exportMode = state.exportMode
   if exportMode ~= 'new' and exportMode ~= 'folder' and exportMode ~= 'appearance' then
      exportMode = 'replace'
   end
   local category = math.floor(tonumber(state.category) or 0)
   if category < 0 or category >= #categories then
      category = 0
   end

   savedEditorUiState = {
      version = isSupportedAssetVersion(tonumber(state.version)) and tonumber(state.version) or nil,
      page = page,
      propertiesTab = propertiesTab,
      importSection = importSection,
      replaceMode = replaceMode,
      newAppearanceSourceMode = newAppearanceSourceMode,
      exportSubpage = exportSubpage,
      exportMode = exportMode,
      category = category,
      appearanceId = math.max(0, math.floor(tonumber(state.appearanceId) or 0)),
      appearanceSearch = type(state.appearanceSearch) == 'string' and state.appearanceSearch or '',
      appearanceListOffset = math.max(0, math.floor(tonumber(state.appearanceListOffset) or 0)),
      replaceSpriteSearch = type(state.replaceSpriteSearch) == 'string' and state.replaceSpriteSearch or '',
      createSpriteSearch = type(state.createSpriteSearch) == 'string' and state.createSpriteSearch or '',
      replaceSpriteListOffset = math.max(0, math.floor(tonumber(state.replaceSpriteListOffset) or 0)),
      createSpriteListOffset = math.max(0, math.floor(tonumber(state.createSpriteListOffset) or 0)),
      replacementSpriteId = math.max(0, math.floor(tonumber(state.replacementSpriteId) or 0)),
      createSpriteId = math.max(0, math.floor(tonumber(state.createSpriteId) or 0)),
      previewSelection = getSavedPreviewSelection(state.previewSelection),
   }

   currentPage = savedEditorUiState.page
   currentPropertiesTab = savedEditorUiState.propertiesTab
   currentImportSection = savedEditorUiState.importSection
   currentReplaceMode = savedEditorUiState.replaceMode
   currentNewAppearanceSourceMode = savedEditorUiState.newAppearanceSourceMode
   currentExportSubpage = savedEditorUiState.exportSubpage
   currentExportMode = savedEditorUiState.exportMode
   selectedAppearanceCategory = savedEditorUiState.category
   selectedReplacementSpriteId = savedEditorUiState.replacementSpriteId > 0 and
      savedEditorUiState.replacementSpriteId or nil
   selectedCreateSpriteId = savedEditorUiState.createSpriteId > 0 and savedEditorUiState.createSpriteId or nil
end

local function requestClientAssets(version, callback)
   local clientAssets = modules.client_assets
   if not isSupportedAssetVersion(version) then
      callback(false, tr('This OTClient build does not support client version %s.', formatClientVersion(version or 0)))
      return
   end
   if not clientAssets or not clientAssets.ensureClientVersion or not clientAssets.isClientVersionInstalled or
         not clientAssets.isEnabled then
      callback(false, tr('Automatic client asset downloads are unavailable.'))
      return
   end
   if not clientAssets.isEnabled() then
      callback(false, tr('Automatic client asset downloads are disabled.'))
      return
   end
   if clientAssets.isClientVersionInstalled(version) then
      callback(true)
      return
   end

   clientAssets.ensureClientVersion(version, function(success, message)
      if success and not clientAssets.isClientVersionInstalled(version) then
         callback(false, tr('Client assets could not be verified after download.'))
         return
      end
      callback(success, message)
   end)
end

formatClientVersion = function(version)
   return string.format('%d.%02d', math.floor(version / 100), version % 100)
end

local function parseClientVersion(value)
   local major, minor = tostring(value):match('^%s*(%d+)%.(%d%d)%s*$')
   if tonumber(major) ~= 15 or not minor then
      return nil
   end
   return tonumber(major) * 100 + tonumber(minor)
end

local function getVersionDirectories()
   local directories = {}
   for _, entry in ipairs(g_resources.listDirectoryFiles('/data/things/')) do
      local version = tonumber(entry)
      if version and version >= 1500 and version % 1 == 0 then
         directories[version] = true
      end
   end
   return directories
end

local function getNextAvailableVersion(sourceVersion)
   local directories = getVersionDirectories()
   local supportedVersions = getSupportedAssetVersions()
   for _, version in ipairs(supportedVersions) do
      if version > sourceVersion and not directories[version] then
         return version
      end
   end
   for index = #supportedVersions, 1, -1 do
      local version = supportedVersions[index]
      if version < sourceVersion and not directories[version] then
         return version
      end
   end
   return nil
end

local function hasAppearanceChanges()
   if next(appearanceChanges.bools) ~= nil or
         next(appearanceChanges.values) ~= nil or
         next(appearanceChanges.strings) ~= nil or
         next(appearanceChanges.textValues) ~= nil or
         next(appearanceChanges.multiValues) ~= nil or
         next(appearanceChanges.animation.groups) ~= nil then
      return true
   end

   if not appearanceOriginal then
      return false
   end

   if appearanceProperties and appearanceProperties:has_widget_changes() then
      return true
   end

   local groupIndex = animationWidgets.groupIndex
   local group = groupIndex ~= nil and appearanceOriginal.frameGroups[groupIndex + 1] or nil
   if group and group.animation and group.animation.enabled then
      for field, edit in pairs(animationWidgets.fields or {}) do
         local value = tonumber(edit:getText())
         if value == nil or value ~= group.animation[field] then
            return true
         end
      end

      for phaseIndex, fields in pairs(animationWidgets.phases or {}) do
         local phase = group.animation.phases[phaseIndex + 1]
         if phase then
            for field, edit in pairs(fields) do
               local value = tonumber(edit:getText())
               if value == nil or value ~= phase[field] then
                  return true
               end
            end
         end
      end
   end

   return false
end

local function clearAppearanceChanges()
   appearanceChanges = { bools = {}, values = {}, strings = {}, textValues = {}, multiValues = {}, animation = { groups = {} } }
end

local function selectedOption(comboBox)
   local option = comboBox and comboBox:getCurrentOption()
   return option and option.data
end

local function updateAppearanceSaveButton()
   if window then
      local hasChanges = hasAppearanceChanges()
      local saveButton = window:recursiveGetChildById('saveAppearanceButton')
      saveButton:setVisible(hasChanges)
      saveButton:setHeight(hasChanges and 26 or 0)
      saveButton:setEnabled(hasChanges)
      if appearanceOriginal then
         setAppearanceStatus(hasChanges and tr('Unsaved edits. Save to the working copy.') or
            tr('Saved in the working copy.'))
      end
   end
end

getAppearancePropertiesEditor = function()
   if appearanceProperties then
      return appearanceProperties
   end

   appearanceProperties = SpriteEditorAppearanceProperties.new({
      get_widget = function(id)
         return window and window:recursiveGetChildById(id) or nil
      end,
      get_category = function() return selectedAppearanceCategory end,
      get_original = function() return appearanceOriginal end,
      get_changes = function() return appearanceChanges end,
      is_building = function() return buildingAppearanceProperties end,
      update = updateAppearanceSaveButton,
      set_status = setAppearanceStatus,
   })
   return appearanceProperties
end

local function setSpritePath(path)
   if not window then
      return
   end
   settingSpritePath = true
   window:recursiveGetChildById('previewSpritePathEdit'):setText(path or '')
   settingSpritePath = false
end

local function destroyPngFilePicker()
   if pngFilePicker then
      pngFilePicker:destroy()
   end
end

function closePngFilePicker()
   destroyPngFilePicker()
end

local function createPngFilePicker()
   pngFilePicker = SpriteEditorPngFilePicker.new({
      on_status = setStatus,
      get_canvas = function() return canvas end,
      can_drag = function(target)
         return target == 'replace' and currentPage == 'import' and currentImportSection == 'replace' and
            currentReplaceMode == 'png' and activeVersion ~= nil and selectedSpriteId ~= nil and
            not g_game.isOnline()
      end,
      on_selected = function(target, path)
         if target == 'export' then
            window:recursiveGetChildById('exportFolderEdit'):setText(path)
            updateExportControls()
            setStatus(tr('Export destination selected: %s', path))
            return
         end
         if target == 'batch' then
            window:recursiveGetChildById('batchPngFolderEdit'):setText(path)
            updateSpriteReplacementTarget()
            setStatus(tr('PNG folder selected: %s', path))
            return
         end
         if target == 'appearanceImport' then
            window:recursiveGetChildById('appearanceBundlePathEdit'):setText(path)
            setStatus(tr('Appearance bundle selected: %s', path:match('([^/]+)$') or path))
            return
         end
         if target == 'appearanceExport' then
            window:recursiveGetChildById('exportFolderEdit'):setText(path)
            updateExportControls()
            setStatus(tr('Appearance bundle destination selected: %s', path))
            return
         end
         if target == 'sheet' then
            window:recursiveGetChildById('spriteSheetPathEdit'):setText(path)
            updateSpriteReplacementTarget()
            setStatus(tr('Sprite sheet selected: %s', path:match('([^/]+)$') or path))
            return
         end
         if target == 'create' then
            window:recursiveGetChildById('newAppearancePngPathEdit'):setText(path)
            setStatus(tr('PNG selected for the new appearance: %s', path:match('([^/]+)$') or path))
            return
         end

         preparedSpritePath = path
         setSpritePath(path)
         updateSpriteReplacementTarget()
         setStatus(tr('PNG selected: %s', path:match('([^/]+)$') or path))
      end,
      on_action = function(target, path)
         if target == 'replace' then
            preparedSpritePath = path
            setSpritePath(path)
            updateSpriteReplacementTarget()
            importPngAndReplace()
            return
         end
         if target == 'create' then
            window:recursiveGetChildById('newAppearancePngPathEdit'):setText(path)
            createAppearance()
         end
      end,
   })
end

function openPngFilePicker(target)
   target = target or 'replace'
   if target ~= 'replace' and target ~= 'create' and target ~= 'export' and target ~= 'batch' and
         target ~= 'sheet' and target ~= 'appearanceImport' and target ~= 'appearanceExport' then
      return
   end
   local isExportTarget = target == 'export' or target == 'appearanceExport'
   if not window or (not isExportTarget and not activeVersion) or g_game.isOnline() or
         (target == 'replace' and not selectedSpriteId) then
      return
   end
   if not g_platform.isDesktop() then
      setStatus(tr('Browsing local files is available in desktop builds.'))
      return
   end
   if not g_platform.getCurrentDir or not g_platform.listDirectoryEntries then
      setStatus(tr('Restart the client to enable PNG file browsing.'))
      return
   end
   if not pngFilePicker then
      createPngFilePicker()
   end

   local pathEditId = target == 'create' and 'newAppearancePngPathEdit' or
      ((target == 'export' or target == 'appearanceExport') and 'exportFolderEdit' or
         (target == 'appearanceImport' and 'appearanceBundlePathEdit' or
            (target == 'batch' and 'batchPngFolderEdit' or
               (target == 'sheet' and 'spriteSheetPathEdit' or 'previewSpritePathEdit'))))
   local existingPath = window:recursiveGetChildById(pathEditId):getText()
   pngFilePicker:open(target, existingPath)
end

function openExportFolderPicker()
   openPngFilePicker(currentExportMode == 'appearance' and 'appearanceExport' or 'export')
end

function openAppearanceBundleExportPicker()
   openPngFilePicker('appearanceExport')
end

local function updatePreviewTitle()
   if not window or not canvas or not selectedSpriteId then
      return
   end

   window:recursiveGetChildById('spriteInfoLabel'):setText(tr('Sprite ID %d | %d x %d',
      selectedSpriteId, canvas:getSpriteWidth(), canvas:getSpriteHeight()))
   updatePreviewZoomControl()
end

local function setPreviewZoom(zoom)
   if not canvas or not selectedSpriteId then
      return
   end

   local targetZoom = math.max(1, math.min(MAX_PREVIEW_ZOOM, math.floor(zoom + 0.5)))
   previewZoomChangingFromSlider = true
   while canvas:getZoom() < targetZoom do
      canvas:zoomIn()
   end
   while canvas:getZoom() > targetZoom do
      canvas:zoomOut()
   end
   previewZoomChangingFromSlider = false
   updatePreviewZoomControl()
end

local function setPreviewMessage(message)
   if not window then
      return
   end
   window:recursiveGetChildById('spriteInfoLabel'):setText(message)
   updatePreviewZoomControl()
end

updateSpriteReplacementTarget = function()
   if not window then
      return
   end
   local hasTarget = selectedSpriteId ~= nil
   local canReplace = hasTarget and activeVersion ~= nil and not g_game.isOnline()
   local canEditAssets = activeVersion ~= nil and not g_game.isOnline()
   local showImport = currentPage == 'import'
   local showReplace = showImport and currentImportSection == 'replace'
   local showCreate = showImport and currentImportSection == 'create'
   local showBatch = showImport and currentImportSection == 'batch'
   local showSheet = showImport and currentImportSection == 'sheet'
   local showBundle = showImport and currentImportSection == 'bundle'
   if spritePickerSourceId ~= selectedSpriteId then
      spritePickerSourceId = selectedSpriteId
      selectedReplacementSpriteId = nil
   end
   local targetPanel = window:recursiveGetChildById('replaceFramePanel')
   targetPanel:setVisible(showReplace)
   window:recursiveGetChildById('newAppearancePanel'):setVisible(showCreate)
   window:recursiveGetChildById('batchPngsPanel'):setVisible(showBatch)
   window:recursiveGetChildById('spriteSheetPanel'):setVisible(showSheet)
   window:recursiveGetChildById('appearanceBundlePanel'):setVisible(showBundle)
   window:recursiveGetChildById('replaceSourceModes'):setVisible(showReplace and hasTarget)
   window:recursiveGetChildById('selectedSpriteTargetLabel'):setText(
      hasTarget and tr('Current frame | Sprite %d', selectedSpriteId) or tr('Select a sprite frame to continue'))
   window:recursiveGetChildById('spriteIdReplacePanel'):setVisible(showReplace and hasTarget and currentReplaceMode == 'sprite')
   window:recursiveGetChildById('pngReplacePanel'):setVisible(showReplace and hasTarget and currentReplaceMode == 'png')
   window:recursiveGetChildById('editCurrentSpritePanel'):setVisible(showReplace and (hasTarget or pendingSpriteEdit ~= nil))
   window:recursiveGetChildById('spriteIdModeButton'):setOn(currentReplaceMode == 'sprite')
   window:recursiveGetChildById('pngModeButton'):setOn(currentReplaceMode == 'png')
   window:recursiveGetChildById('spriteSearchEdit'):setEnabled(canReplace)
   window:recursiveGetChildById('newAppearanceSourceModes'):setVisible(showCreate)
   window:recursiveGetChildById('newAppearanceSpriteModeButton'):setOn(currentNewAppearanceSourceMode == 'sprite')
   window:recursiveGetChildById('newAppearancePngModeButton'):setOn(currentNewAppearanceSourceMode == 'png')
   window:recursiveGetChildById('newAppearanceSpritePanel'):setVisible(
      showCreate and currentNewAppearanceSourceMode == 'sprite')
   window:recursiveGetChildById('newAppearancePngPanel'):setVisible(
      showCreate and currentNewAppearanceSourceMode == 'png')
   window:recursiveGetChildById('replaceFrameTabButton'):setOn(currentImportSection == 'replace')
   window:recursiveGetChildById('newAppearanceTabButton'):setOn(currentImportSection == 'create')
   window:recursiveGetChildById('batchPngsTabButton'):setOn(currentImportSection == 'batch')
   window:recursiveGetChildById('spriteSheetTabButton'):setOn(currentImportSection == 'sheet')
   window:recursiveGetChildById('newAppearanceSpriteSearchEdit'):setEnabled(canEditAssets)
   window:recursiveGetChildById('newAppearanceCategory'):setEnabled(canEditAssets)
   local batchFolderEdit = window:recursiveGetChildById('batchPngFolderEdit')
   batchFolderEdit:setEnabled(canEditAssets)
   window:recursiveGetChildById('batchPngFolderBrowseButton'):setEnabled(canEditAssets and g_platform.isDesktop())
   window:recursiveGetChildById('batchPngImportButton'):setEnabled(
      canEditAssets and batchFolderEdit:getText():trim() ~= '')
   local spriteSheetPathEdit = window:recursiveGetChildById('spriteSheetPathEdit')
   spriteSheetPathEdit:setEnabled(canEditAssets)
   window:recursiveGetChildById('spriteSheetBrowseButton'):setEnabled(canEditAssets and g_platform.isDesktop())
   window:recursiveGetChildById('spriteSheetCellWidth'):setEnabled(canEditAssets)
   window:recursiveGetChildById('spriteSheetCellHeight'):setEnabled(canEditAssets)
   window:recursiveGetChildById('spriteSheetFirstCell'):setEnabled(canEditAssets)
   window:recursiveGetChildById('spriteSheetLastCell'):setEnabled(canEditAssets)
   window:recursiveGetChildById('spriteSheetSkipTransparent'):setEnabled(canEditAssets)
   window:recursiveGetChildById('spriteSheetImportButton'):setEnabled(
      canEditAssets and spriteSheetPathEdit:getText():trim() ~= '')
   local pngPathEdit = window:recursiveGetChildById('previewSpritePathEdit')
   pngPathEdit:setEnabled(canReplace)
   window:recursiveGetChildById('browsePngButton'):setEnabled(canReplace and g_platform.isDesktop())
   window:recursiveGetChildById('importPngReplaceButton'):setEnabled(canReplace and pngPathEdit:getText() ~= '')
   local newAppearancePngPathEdit = window:recursiveGetChildById('newAppearancePngPathEdit')
   newAppearancePngPathEdit:setEnabled(canEditAssets)
   window:recursiveGetChildById('browseNewAppearancePngButton'):setEnabled(canEditAssets and g_platform.isDesktop())
   window:recursiveGetChildById('createAppearanceButton'):setEnabled(canEditAssets and (
      (currentNewAppearanceSourceMode == 'sprite' and selectedCreateSpriteId ~= nil) or
      (currentNewAppearanceSourceMode == 'png' and newAppearancePngPathEdit:getText() ~= '')))
   window:recursiveGetChildById('newAppearanceSourceHintLabel'):setText(
      currentNewAppearanceSourceMode == 'sprite' and tr('Choose the category above, then create the appearance.') or
      tr('The PNG will be added as a new sprite ID when you create the appearance.'))
   window:recursiveGetChildById('spriteEditHelpLabel'):setText(pendingSpriteEdit and
      tr('Temporary PNG: %s', pendingSpriteEdit.path) or
      tr('Edit the current sprite in an external app, then apply it to the work copy.'))
   window:recursiveGetChildById('editAppearanceSpriteButton'):setEnabled(canReplace)
   local applyButton = window:recursiveGetChildById('applyEditedSpriteButton')
   applyButton:setVisible(pendingSpriteEdit ~= nil)
   applyButton:setEnabled(pendingSpriteEdit ~= nil and not g_game.isOnline())
   applyButton:setText(tr('Apply edit'))
   applyButton:setTooltip(pendingSpriteEdit and tr('Apply the edited PNG to sprite %d in the work copy.', pendingSpriteEdit.spriteId) or '')
   window:recursiveGetChildById('configureSpriteEditorButton'):setEnabled(activeVersion ~= nil and not g_game.isOnline())
   window:recursiveGetChildById('newAppearanceSpriteModeButton'):setEnabled(canEditAssets)
   window:recursiveGetChildById('newAppearancePngModeButton'):setEnabled(canEditAssets)
   window:recursiveGetChildById('duplicateAppearanceButton'):setEnabled(
      selectedAppearanceId ~= nil and activeVersion ~= nil and not g_game.isOnline())
   window:recursiveGetChildById('deleteAppearanceButton'):setEnabled(
      selectedAppearanceId ~= nil and activeVersion ~= nil and not g_game.isOnline() and pendingSpriteEdit == nil)
   window:recursiveGetChildById('createAppearanceShortcutButton'):setEnabled(
      activeVersion ~= nil and not g_game.isOnline())
   if hasTarget then updatePreviewTitle() end
   if renderSpritePickerRows and currentImportSection ~= 'batch' then
      local pickerList = getSpritePickerWidget('list')
      renderSpritePickerRows(pickerList and pickerList:getVirtualOffset().y or 0)
   end
end

local function setPreviewControlsVisible(visible, panelHeight)
   local controls = window:recursiveGetChildById('previewControls')
   controls:setVisible(visible)
   controls:setHeight(visible and panelHeight or 0)
   canvas:setMarginBottom(visible and panelHeight + PREVIEW_CONTROLS_BOTTOM_MARGIN or PREVIEW_CANVAS_BOTTOM_MARGIN)
   updatePreviewZoomControl()
end

local function updatePreviewTimelineLayout(phaseCount, hasFrameControls, hasAnimation)
   local showFrameButtons = hasFrameControls and phaseCount <= MAX_PREVIEW_TIMELINE_FRAMES
   local showNumericFrameSelector = hasFrameControls and phaseCount > MAX_PREVIEW_TIMELINE_FRAMES
   local showAnimationFrameRow = showNumericFrameSelector or hasAnimation
   local timelinePanel = window:recursiveGetChildById('previewTimelinePanel')
   local timelineLabel = window:recursiveGetChildById('previewTimelineLabel')
   local timeline = window:recursiveGetChildById('previewTimeline')
   local timelineScroll = window:recursiveGetChildById('previewTimelineScroll')
   local phaseActions = window:recursiveGetChildById('previewPhaseActions')
   local playButton = window:recursiveGetChildById('previewPlayButton')
   local frameRow = window:recursiveGetChildById('previewAnimationFrameRow')
   local frameSelectionGroup = window:recursiveGetChildById('previewFrameSelectionGroup')
   local durationGroup = window:recursiveGetChildById('previewDurationGroup')

   timelinePanel:setVisible(hasFrameControls)
   local panelHeight = showAnimationFrameRow and PREVIEW_TIMELINE_HEIGHT or PREVIEW_TIMELINE_ONLY_HEIGHT
   timelinePanel:setHeight(panelHeight)
   timelineLabel:setVisible(hasFrameControls)
   timeline:setVisible(showFrameButtons)
   timelineScroll:setVisible(showFrameButtons and phaseCount * PREVIEW_TIMELINE_CELL_WIDTH > timeline:getWidth())
   phaseActions:setVisible(hasFrameControls)
   local showPlayButton = hasAnimation and phaseCount > 1
   playButton:setVisible(showPlayButton)
   playButton:setEnabled(showPlayButton)
   phaseActions:setWidth(showPlayButton and 104 or 54)
   frameRow:setVisible(showAnimationFrameRow)
   frameRow:setMarginBottom(showFrameButtons and showAnimationFrameRow and 11 or 0)
   frameSelectionGroup:setVisible(showNumericFrameSelector)
   durationGroup:setVisible(hasAnimation)
   durationGroup:setMarginLeft(showNumericFrameSelector and
      PREVIEW_FRAME_SELECTION_WIDTH + PREVIEW_DURATION_GROUP_GAP or 0)
   return showFrameButtons, showNumericFrameSelector, panelHeight
end

local function setPropertiesTab(tab)
   if not window then
      return
   end
   local flagsAvailable = appearanceOriginal ~= nil and next(appearanceOriginal.bools or {}) ~= nil
   local valuesAvailable = appearanceOriginal ~= nil and next(appearanceOriginal.values or {}) ~= nil
   window:recursiveGetChildById('flagsTabButton'):setVisible(flagsAvailable)
   window:recursiveGetChildById('valuesTabButton'):setVisible(valuesAvailable)
   local tabBar = window:recursiveGetChildById('propertiesTabBar')
   local hasTabs = flagsAvailable or valuesAvailable
   tabBar:setVisible(hasTabs)
   tabBar:setHeight(hasTabs and 24 or 0)
   window:recursiveGetChildById('noPropertyOptionsLabel'):setVisible(
      appearanceOriginal ~= nil and not flagsAvailable and not valuesAvailable)
   window:recursiveGetChildById('noPropertyOptionsLabel'):setText(
      tr('No additional editable properties for this appearance.'))

   if tab == 'values' and valuesAvailable then
      currentPropertiesTab = 'values'
   elseif tab == 'flags' and flagsAvailable then
      currentPropertiesTab = 'flags'
   elseif flagsAvailable then
      currentPropertiesTab = 'flags'
   elseif valuesAvailable then
      currentPropertiesTab = 'values'
   else
      currentPropertiesTab = 'flags'
   end
   local flagsVisible = currentPropertiesTab == 'flags'
   local valuesVisible = currentPropertiesTab == 'values'
   window:recursiveGetChildById('appearanceFlagsList'):setVisible(flagsVisible and flagsAvailable)
   window:recursiveGetChildById('appearanceFlagsScroll'):setVisible(flagsVisible and flagsAvailable)
   window:recursiveGetChildById('appearanceValuesList'):setVisible(valuesVisible and valuesAvailable)
   window:recursiveGetChildById('appearanceValuesScroll'):setVisible(valuesVisible and valuesAvailable)
   window:recursiveGetChildById('flagsTabButton'):setOn(flagsVisible)
   window:recursiveGetChildById('valuesTabButton'):setOn(valuesVisible)
   if persistEditorUiState then
      persistEditorUiState()
   end
end

local function buildAppearanceProperties(data)
   clearAppearanceChanges()
   appearanceOriginal = data
   data.values = data.values or {}
   if selectedAppearanceCategory == 0 then
      data.values['clothes.slot'] = data.values['clothes.slot'] or 0
   end
   buildingAppearanceProperties = true
   getAppearancePropertiesEditor():build_fields(data)
   configurePreviewControls(data.frameGroups or {})
   updateAnimationEditor()
   buildingAppearanceProperties = false
   updateAppearanceSaveButton()
   setPropertiesTab(currentPropertiesTab)
end

local function clearAppearanceProperties()
   buildingAppearanceProperties = true
   window:recursiveGetChildById('appearanceInfoLabel'):setText(tr('Select an appearance from the list.'))
   setAppearanceStatus(tr('Open a work copy and select an appearance to edit.'))
   selectedAppearanceId = nil
   appearanceOriginal = nil
   selectedSpriteId = nil
   getAppearancePropertiesEditor():clear_fields()
   getAppearancePropertiesEditor():set_enabled(false)
   window:recursiveGetChildById('previewTimelineFrames'):destroyChildren()
   setPreviewMessage(tr('Select an appearance to see its sprite.'))
   canvas:setVisible(false)
   setSpritePath(preparedSpritePath)
   updateSpriteReplacementTarget()
   animationWidgets = {}
   configurePreviewControls({})
   updateAnimationEditor()
   clearAppearanceChanges()
   buildingAppearanceProperties = false
   setPropertiesTab(currentPropertiesTab)
   updateAppearanceSaveButton()
end

local function resetAppearanceDraft()
   if appearanceOriginal then
      buildAppearanceProperties(appearanceOriginal)
   else
      clearAppearanceChanges()
   end
end

local function confirmUnsavedChanges(message, continueAction)
   local messageBox
   local function saveAndContinue()
      messageBox:ok()
      saveAppearanceProperties()
      if not hasAppearanceChanges() then
         continueAction()
      end
   end
   local function cancelMessageBox()
      messageBox:cancel()
   end
   messageBox = displayGeneralBox(tr('Unsaved changes'), message, {
      { text = tr('Save and continue'), callback = saveAndContinue },
      { text = tr('Discard edits'), callback = function()
         messageBox:ok()
         resetAppearanceDraft()
         continueAction()
      end },
      { text = tr('Cancel'), callback = cancelMessageBox },
   }, saveAndContinue, cancelMessageBox)
end

selectSprite = function(id)
   if not canvas or not activeVersion then
      return false
   end
   if not canvas:setSpriteId(id) then
      canvas:setVisible(false)
      selectedSpriteId = nil
      updateDirectionPadLayout()
      updatePreviewZoomControl()
      updateSpriteReplacementTarget()
      setStatus(tr('Sprite %d is not available in this 15.x work copy.', id))
      if persistEditorUiState then
         persistEditorUiState()
      end
      return false
   end

   canvas:setVisible(true)
   selectedSpriteId = id
   updatePreviewTitle()
   updateDirectionPadLayout()
   updateSpriteReplacementTarget()
   if persistEditorUiState then
      persistEditorUiState()
   end
   return true
end

local function frameGroupName(group, index)
   local names = {
      [0] = tr('Idle'),
      [1] = tr('Moving'),
      [2] = tr('Initial'),
   }
   return names[group.type] or tr('Group %d', index)
end

local function currentPreviewGroup()
   return previewFrameGroups[previewFrameGroupIndex]
end

stopPreviewAnimation = function()
   if previewAnimationPlayer then
      previewAnimationPlayer:stop()
   end
end

updatePreviewTimelineSelection = function(phaseCount)
   if not window then
      return
   end
   local frameList = window:recursiveGetChildById('previewTimelineFrames')
   for index, frameCell in ipairs(frameList:getChildren()) do
      local selected = index - 1 == previewPhase
      local frameButton = frameCell:getChildById('previewTimelineFrameButton')
      frameButton:setOn(selected)
      frameButton:setColor(selected and '#d9c7ff' or '#dfdfdf')
      local thumb = frameCell:recursiveGetChildById('previewTimelineThumb')
      if thumb then
         thumb:setVisible(selected)
      end
   end

   local phaseStepper = window:recursiveGetChildById('previewPhaseStepper')
   if phaseStepper then
      local onValueChange = phaseStepper.onValueChange
      phaseStepper.onValueChange = nil
      phaseStepper:setValue(previewPhase + 1, true)
      phaseStepper.onValueChange = onValueChange
   end
   if phaseCount then
      local phaseCountLabel = window:recursiveGetChildById('previewPhaseCount')
      phaseCountLabel:setText(tr('of %d', phaseCount))
   end
   local selectedPhase = previewPhase
   local timelineWindow = window
   addEvent(function()
      if not window or window ~= timelineWindow or not window:isVisible() then
         return
      end
      local timeline = window:recursiveGetChildById('previewTimeline')
      local frameCell = window:recursiveGetChildById('previewTimelineFrames'):getChildByIndex(selectedPhase + 1)
      local ensureChildVisible = UIScrollArea and UIScrollArea.ensureChildVisible
      if timeline and frameCell and ensureChildVisible then
         ensureChildVisible(timeline, frameCell)
      end
   end)
end

local function updatePreviewPhaseDurationFields(group)
   if not group or not group.animation or not group.animation.enabled then
      return
   end
   local phase = group.animation.phases[previewPhase + 1]
   if not phase then
      return
   end
   local groupChanges = appearanceChanges.animation.groups[tostring(group.index)] or {}
   local phaseChanges = groupChanges.phases and groupChanges.phases[tostring(previewPhase)] or {}
   local minEdit = window:recursiveGetChildById('animationDurationMin')
   local maxEdit = window:recursiveGetChildById('animationDurationMax')
   local wasBuildingProperties = buildingAppearanceProperties
   buildingAppearanceProperties = true
   minEdit:setText(tostring(phaseChanges.durationMin ~= nil and phaseChanges.durationMin or phase.durationMin))
   maxEdit:setText(tostring(phaseChanges.durationMax ~= nil and phaseChanges.durationMax or phase.durationMax))
   buildingAppearanceProperties = wasBuildingProperties
   animationWidgets.phaseIndex = previewPhase
end

selectPreviewPhase = function(phaseIndex, playbackTick)
   local group = currentPreviewGroup()
   if not group then
      return false
   end
   if not playbackTick then
      stopPreviewAnimation()
   end
   if not collectAnimationWidgetChanges() then
      return false
   end

   previewPhase = math.max(0, math.min(phaseIndex, math.max(0, (group.phaseCount or 1) - 1)))
   updatePreviewTimelineSelection(group.phaseCount)
   updatePreviewPhaseDurationFields(group)
   return refreshAppearancePreview()
end

local function getPreviewPhaseDuration(group, phaseIndex)
   local phase = group.animation.phases[phaseIndex + 1]
   local groupChanges = appearanceChanges.animation.groups[tostring(group.index)] or {}
   local phaseChanges = groupChanges.phases and groupChanges.phases[tostring(phaseIndex)] or {}
   local minimum = phaseChanges.durationMin ~= nil and phaseChanges.durationMin or phase.durationMin
   local maximum = phaseChanges.durationMax ~= nil and phaseChanges.durationMax or phase.durationMax
   if minimum == 0 and maximum == 0 then
      for _, candidate in ipairs(group.animation.phases) do
         if candidate.durationMin > 0 or candidate.durationMax > 0 then
            minimum = candidate.durationMin
            maximum = candidate.durationMax
            break
         end
      end
   end
   return math.max(1, math.floor((minimum + maximum) / 2))
end

local function getPreviewAnimationPlayer()
   if previewAnimationPlayer then
      return previewAnimationPlayer
   end

   previewAnimationPlayer = SpriteEditorAnimationPlayer.new({
      get_group = currentPreviewGroup,
      get_appearance_id = function() return selectedAppearanceId end,
      get_phase = function() return previewPhase end,
      get_phase_duration = getPreviewPhaseDuration,
      get_group_changes = function(groupIndex)
         return appearanceChanges.animation.groups[tostring(groupIndex)] or {}
      end,
      get_play_button = function()
         return window and window:recursiveGetChildById('previewPlayButton') or nil
      end,
      is_window_visible = function()
         return window ~= nil and window:isVisible()
      end,
      collect_changes = function() return collectAnimationWidgetChanges() end,
      select_phase = function(phaseIndex)
         return selectPreviewPhase(phaseIndex, true)
      end,
   })
   return previewAnimationPlayer
end

function togglePreviewAnimation()
   if window then
      getPreviewAnimationPlayer():toggle()
   end
end

local function setAnimationChange(groupIndex, field, value, phaseIndex)
   local group = previewFrameGroups[groupIndex + 1]
   if not group or not group.animation.enabled then
      return
   end

   local groupKey = tostring(groupIndex)
   local groupChanges = appearanceChanges.animation.groups[groupKey]
   if not groupChanges then
      groupChanges = { phases = {} }
      appearanceChanges.animation.groups[groupKey] = groupChanges
   end

   local original
   local changeContainer = groupChanges
   if phaseIndex ~= nil then
      local originalPhase = group.animation.phases[phaseIndex + 1]
      if not originalPhase then
         return
      end
      local phaseKey = tostring(phaseIndex)
      groupChanges.phases = groupChanges.phases or {}
      changeContainer = groupChanges.phases[phaseKey]
      if not changeContainer then
         changeContainer = {}
         groupChanges.phases[phaseKey] = changeContainer
      end
      original = originalPhase[field]
   else
      original = group.animation[field]
   end

   if value == original then
      changeContainer[field] = nil
   else
      changeContainer[field] = value
   end

   if next(changeContainer) == nil and phaseIndex ~= nil then
      groupChanges.phases[tostring(phaseIndex)] = nil
   end
   if groupChanges.phases and next(groupChanges.phases) == nil then
      groupChanges.phases = nil
   end
   if next(groupChanges) == nil then
      appearanceChanges.animation.groups[groupKey] = nil
   end
   updateAppearanceSaveButton()
end

local function updatePreviewAnimationPhaseCount(groupIndex, phaseCount)
   local group = previewFrameGroups[groupIndex + 1]
   local originalGroup = appearanceOriginal and appearanceOriginal.frameGroups[groupIndex + 1]
   if not group or not originalGroup or phaseCount < 1 then
      return false
   end

   local spritesPerPhase = math.max(1, originalGroup.layers or 1) *
      math.max(1, originalGroup.patternWidth or 1) *
      math.max(1, originalGroup.patternHeight or 1) *
      math.max(1, originalGroup.patternDepth or 1)
   local originalPhaseCount = math.max(1, originalGroup.phaseCount or 1)
   local maximumPhaseCount = math.floor(2147483647 / spritesPerPhase)
   if phaseCount > maximumPhaseCount then
      setAppearanceStatus(tr('This frame group cannot contain more animation frames.'))
      return false
   end

   local groupKey = tostring(groupIndex)
   local groupChanges = appearanceChanges.animation.groups[groupKey]
   if not groupChanges then
      groupChanges = { phases = {} }
      appearanceChanges.animation.groups[groupKey] = groupChanges
   end
   local function getAnimationValue(field, fallback)
      if groupChanges[field] ~= nil then
         return groupChanges[field]
      end
      return fallback
   end

   local sprites = {}
   local originalSprites = originalGroup.sprites or {}
   local copiedPhaseCount = math.min(phaseCount, originalPhaseCount)
   for index = 1, math.min(#originalSprites, copiedPhaseCount * spritesPerPhase) do
      sprites[index] = originalSprites[index]
   end
   for phaseIndex = originalPhaseCount, phaseCount - 1 do
      for spriteOffset = 1, spritesPerPhase do
         local spriteIndex = phaseIndex * spritesPerPhase + spriteOffset
         local previousSpriteIndex = (phaseIndex - 1) * spritesPerPhase + spriteOffset
         sprites[spriteIndex] = sprites[previousSpriteIndex] or 0
      end
   end

   local originalAnimation = originalGroup.animation or {}
   local animation = {
      enabled = phaseCount > 1,
      defaultStartPhase = getAnimationValue('defaultStartPhase', originalAnimation.defaultStartPhase or 0),
      randomStartPhase = getAnimationValue('randomStartPhase', originalAnimation.randomStartPhase or false),
      synchronized = getAnimationValue('synchronized', originalAnimation.synchronized or false),
      loopType = getAnimationValue('loopType', originalAnimation.enabled and originalAnimation.loopType or 0),
      loopCount = getAnimationValue('loopCount', originalAnimation.loopCount or 0),
      phases = {},
   }
   if phaseCount > 1 then
      for phaseIndex = 1, phaseCount do
         local originalPhase = originalAnimation.phases and originalAnimation.phases[phaseIndex]
         local phaseChanges = groupChanges.phases and groupChanges.phases[tostring(phaseIndex - 1)] or {}
         animation.phases[phaseIndex] = {
            durationMin = phaseChanges.durationMin ~= nil and phaseChanges.durationMin or
               originalPhase and originalPhase.durationMin or 100,
            durationMax = phaseChanges.durationMax ~= nil and phaseChanges.durationMax or
               originalPhase and originalPhase.durationMax or 100,
         }
      end
      animation.defaultStartPhase = math.min(animation.defaultStartPhase, phaseCount - 1)
   else
      animation.defaultStartPhase = 0
      animation.randomStartPhase = false
      animation.synchronized = false
      animation.loopType = 0
      animation.loopCount = 0
   end

   group.phaseCount = phaseCount
   group.sprites = sprites
   group.animation = animation

   groupChanges.phaseCount = phaseCount ~= originalPhaseCount and phaseCount or nil
   if phaseCount == 1 then
      groupChanges.defaultStartPhase = nil
      groupChanges.randomStartPhase = nil
      groupChanges.synchronized = nil
      groupChanges.loopType = nil
      groupChanges.loopCount = nil
   end
   if phaseCount == 1 then
      groupChanges.phases = nil
   else
      groupChanges.phases = groupChanges.phases or {}
      for phaseKey in pairs(groupChanges.phases) do
         if tonumber(phaseKey) >= phaseCount then
            groupChanges.phases[phaseKey] = nil
         end
      end
      if next(groupChanges.phases) == nil then
         groupChanges.phases = nil
      end
   end
   if next(groupChanges) == nil then
      appearanceChanges.animation.groups[groupKey] = nil
   end

   previewPhase = math.min(previewPhase, phaseCount - 1)
   updateAppearanceSaveButton()
   return true
end

local function changeAnimationPhaseCount(delta)
   stopPreviewAnimation()
   local group = currentPreviewGroup()
   if not group or not collectAnimationWidgetChanges() then
      return false
   end
   local phaseCount = math.max(1, group.phaseCount or 1)
   local newPhaseCount = phaseCount + delta
   if newPhaseCount < 1 then
      return false
   end
   if not updatePreviewAnimationPhaseCount(group.index, newPhaseCount) then
      return false
   end
   updatePreviewPatternControls()
   updateAnimationEditor()
   refreshAppearancePreview()
   setAppearanceStatus(delta > 0 and tr('Frame added. Replace its sprite if needed, then save the appearance.') or
      tr('Last frame removed. Save the appearance to apply the change.'))
   return true
end

local function setComboOptions(comboBox, options, selectedData)
   local onOptionChange = comboBox.onOptionChange
   comboBox.onOptionChange = nil
   comboBox:clearOptions()
   for _, option in ipairs(options) do
      comboBox:addOption(option.label, option.data)
   end
   if options[1] then
      comboBox:setCurrentOptionByData(selectedData or options[1].data, true)
   end
   comboBox.onOptionChange = onOptionChange
end

local function formatBackupHistoryChange(entry)
   local category = entry.categoryName and entry.categoryName ~= '' and tr(entry.categoryName) or tr('Appearance')
   local appearanceId = tonumber(entry.appearanceId)
   local subject = appearanceId and tr('%s %d', category, appearanceId) or category
   local label = tostring(entry.label or tr('Asset edit'))
   local fields = {}
   for index = 1, math.min(type(entry.changedFields) == 'table' and #entry.changedFields or 0, 3) do
      local field = tostring(entry.changedFields[index])
      field = field:gsub('^bools%.', ''):gsub('^values%.', '')
         :gsub('^textValues%.', ''):gsub('^multiValues%.', '')
      field = field:gsub('^strings%.name$', tr('Name')):gsub('^strings%.description$', tr('Description'))
      table.insert(fields, field)
   end
   local spriteId = tonumber(entry.spriteId)
   if spriteId and spriteId > 0 then
      subject = tr('%s | Sprite %d', subject, spriteId)
   end
   local summary = #fields > 0 and tr('Changed: %s', table.concat(fields, ', ')) or label
   return string.format('%s\n%s\n%s\n%s', subject, label, summary,
      tostring(entry.createdAt or ''))
end

updateInstalledBackupDetails = function()
   if not window then
      return
   end

   installedAssetBackupChanges = {}
   selectedInstalledBackupChange = nil
   local backupName = selectedInstalledBackupName
   local backup = backupName and getInstalledAssetBackup(backupName)
   local backupLabel = backup and backup.label or backupName
   local detail = window:recursiveGetChildById('backupDetailLabel')
   local backupList = window:recursiveGetChildById('installedBackupList')
   local list = window:recursiveGetChildById('backupChangesList')
   local restoreChange = window:recursiveGetChildById('restoreBackupChangeButton')
   list:destroyChildren()
   restoreChange:setEnabled(false)

   if not activeVersion or not backupName then
      detail:setText(#installedAssetBackups == 0 and tr('No installed backups are available for this assets version.') or
         tr('Select a backup above to inspect its timestamp and changes.'))
      backupList:setEnabled(#installedAssetBackups > 0)
      window:recursiveGetChildById('restoreBackupButton'):setEnabled(false)
      return
   end

   refreshAssetEditHistory()
   local baselineOk, baselineEncoded = pcall(g_spriteAppearances.getInstalledAssetBackupHistory,
      activeVersion, backupName)
   local baselineIds = {}
   local baselineHistoryAvailable = false
   if baselineOk then
      local decoded, baseline = pcall(json.decode, baselineEncoded)
      if decoded and type(baseline) == 'table' and type(baseline.entries) == 'table' then
         baselineHistoryAvailable = baseline.historyAvailable ~= false
         if baselineHistoryAvailable then
            for _, entry in ipairs(baseline.entries) do
               if entry.id then baselineIds[tostring(entry.id)] = true end
            end
         end
      end
   else
      g_logger.warning('[game_sprite_editor] Unable to inspect installed backup history: ' .. tostring(baselineEncoded))
   end

   local backupUtcTimestamp = backup and backup.timestamp and
      os.date('!%Y-%m-%dT%H:%M:%S', math.floor(backup.timestamp / 1000))
   for _, entry in ipairs(assetEditHistoryEntries) do
      local isAfterBackup = false
      if baselineHistoryAvailable then
         isAfterBackup = entry.id and not baselineIds[tostring(entry.id)] or false
      elseif backupUtcTimestamp then
         local entryUtcTimestamp = tostring(entry.createdAt or ''):match(
            '^(%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d)Z$')
         isAfterBackup = entryUtcTimestamp and entryUtcTimestamp >= backupUtcTimestamp or false
      end
      if isAfterBackup then
         table.insert(installedAssetBackupChanges, entry)
      end
   end
   table.sort(installedAssetBackupChanges, function(left, right)
      return tostring(left.createdAt or '') < tostring(right.createdAt or '')
   end)

   if baselineHistoryAvailable then
      detail:setText(tr('Created: %s\n%d recorded edits after this backup.',
         backupLabel, #installedAssetBackupChanges))
   elseif backupUtcTimestamp then
      detail:setText(tr('Created: %s\nHistory starts later; edits use 1-second timestamps.', backupLabel))
   else
      detail:setText(tr('Created: %s\nNo edit history is available for comparison.', backupLabel))
   end

   for _, entry in ipairs(installedAssetBackupChanges) do
      local row = g_ui.createWidget('BackupChangeEntry', list)
      row:recursiveGetChildById('historyText'):setText(formatHistoryEntryRow(entry))
      row:setTooltip(formatBackupHistoryChange(entry))
      setHistoryEntryPreview(row, entry)
      local rowEntry = entry
      row.onClick = function()
         selectedInstalledBackupChange = rowEntry
         for _, candidate in ipairs(list:getChildren()) do
            candidate:setOn(candidate == row)
         end
         restoreChange:setEnabled(tonumber(rowEntry.appearanceId) ~= nil and
            (rowEntry.beforeAppearancePresent == true or rowEntry.beforeAppearancePresent == false or
               (tonumber(rowEntry.spriteId) and tonumber(rowEntry.spriteId) > 0 and
                  rowEntry.beforeSpritePng and rowEntry.beforeSpritePng ~= '')))
      end
   end
   if g_spriteAppearances.releaseDecodedSpriteSheets then
      g_spriteAppearances.releaseDecodedSpriteSheets()
   end

   if #installedAssetBackupChanges == 0 and (baselineHistoryAvailable or backupUtcTimestamp) then
      detail:setText(tr('Created: %s\nNo later edits are recorded in the portable history.', backupLabel))
   end
   window:recursiveGetChildById('restoreBackupButton'):setEnabled(true)
end

local function updateInstalledAssetBackupOptions()
   if not window then
      return
   end
   local list = window:recursiveGetChildById('installedBackupList')
   list:destroyChildren()
   window:recursiveGetChildById('installedBackupListLabel'):setText(
      tr('Available backups (%d) | Newest first', #installedAssetBackups))

   if #installedAssetBackups == 0 then
      local emptyEntry = g_ui.createWidget('InstalledAssetBackupEmptyEntry', list)
      emptyEntry:setText(tr('No installed backups are available for this assets version.'))
   end

   for _, backup in ipairs(installedAssetBackups) do
      local row = g_ui.createWidget('InstalledAssetBackupEntry', list)
      row.backupName = backup.data
      row:recursiveGetChildById('backupTimestamp'):setText(backup.label)
      row:recursiveGetChildById('backupCaption'):setText(tr('Installed asset package'))
      local backupName = backup.data
      row.onClick = function()
         selectedInstalledBackupName = backupName
         for _, candidate in ipairs(list:getChildren()) do
            candidate:setOn(candidate == row)
         end
         updateInstalledBackupDetails()
         updateExportControls()
      end
      row:setOn(backup.data == selectedInstalledBackupName)
   end

   updateInstalledBackupDetails()
end

local function buildPatternOptions(comboBox, label, count, selectedIndex, optionLabelForIndex)
   local options = {}
   for index = 0, count - 1 do
      local optionLabel = optionLabelForIndex and optionLabelForIndex(index) or
         string.format('%s %d', label, index + 1)
      table.insert(options, { label = optionLabel, data = index })
   end
   setComboOptions(comboBox, options, math.min(selectedIndex or 0, count - 1))
   comboBox:setVisible(count > 1)
end

local function outfitAddonOptionLabel(index)
   if index == 0 then
      return tr('No addon')
   elseif index == 1 then
      return tr('Addon 1')
   elseif index == 2 then
      return tr('Addon 2')
   elseif index == 3 then
      return tr('Both addons')
   end
   return tr('Addon pattern %d', index + 1)
end

local function setCheckBoxState(checkBox, checked)
   local onCheckChange = checkBox.onCheckChange
   checkBox.onCheckChange = nil
   checkBox:setChecked(checked)
   checkBox.onCheckChange = onCheckChange
end

updatePreviewZoomControl = function()
   if not window or not canvas then
      return
   end

   local zoomControl = window:recursiveGetChildById('previewZoomControl')
   local zoomLabel = window:recursiveGetChildById('previewZoomLabel')
   local zoomScroll = window:recursiveGetChildById('previewZoomScroll')
   local previewControls = window:recursiveGetChildById('previewControls')
   zoomControl:setMarginBottom(previewControls:getHeight() + previewControls:getMarginBottom() +
      PREVIEW_ZOOM_CONTROL_GAP)
   local spriteWidth = canvas:getSpriteWidth()
   local spriteHeight = canvas:getSpriteHeight()
   local visible = selectedSpriteId ~= nil and spriteWidth > 0 and spriteHeight > 0
   zoomControl:setVisible(visible)
   if not visible then
      return
   end

   local zoom = canvas:getZoom()
   zoomLabel:setText(tr('%dx', zoom))
   if not previewZoomChangingFromSlider then
      local onValueChange = zoomScroll.onValueChange
      zoomScroll.onValueChange = nil
      zoomScroll:setValue(MAX_PREVIEW_ZOOM + 1 - zoom)
      zoomScroll.onValueChange = onValueChange
   end

end

updateDirectionPadLayout = function()
   if not window or not canvas then
      return
   end

   local directionPad = window:recursiveGetChildById('previewDirectionPad')
   local group = currentPreviewGroup()
   local visible = selectedSpriteId ~= nil and selectedAppearanceCategory == 1 and group and
      group.patternWidth >= 4 or false
   directionPad:setVisible(visible)
   if not visible then
      return
   end

   local spriteWidth = canvas:getSpriteWidth()
   local spriteHeight = canvas:getSpriteHeight()
   if spriteWidth > 0 and spriteHeight > 0 then
      local zoom = canvas:getZoom()
      local padWidth = spriteWidth * zoom + 2 * (PREVIEW_DIRECTION_BUTTON_WIDTH + PREVIEW_DIRECTION_PAD_GAP)
      local padHeight = spriteHeight * zoom + 2 * (PREVIEW_DIRECTION_BUTTON_HEIGHT + PREVIEW_DIRECTION_PAD_GAP)
      local maxWidth = math.max(PREVIEW_DIRECTION_BUTTON_WIDTH, canvas:getWidth() - 16)
      local maxHeight = math.max(PREVIEW_DIRECTION_BUTTON_HEIGHT, canvas:getHeight() - 16)
      local width = math.min(padWidth, maxWidth)
      local height = math.min(padHeight, maxHeight)
      directionPad:setWidth(width)
      directionPad:setHeight(height)

      local canvasRect = canvas:getPaddingRect()
      local spriteCenter = canvas:getSpriteRenderCenter()
      local maxOffsetX = math.max(0, (canvasRect.width - width) / 2)
      local maxOffsetY = math.max(0, (canvasRect.height - height) / 2)
      local offsetX = math.max(-maxOffsetX, math.min(maxOffsetX, spriteCenter.x - canvasRect.width / 2))
      local offsetY = math.max(-maxOffsetY, math.min(maxOffsetY, spriteCenter.y - canvasRect.height / 2))
      directionPad:setMarginLeft(offsetX)
      directionPad:setMarginTop(offsetY)
   end
end

updatePreviewPatternControls = function()
   if not window then
      return
   end
   local group = currentPreviewGroup()
   if not group then
      setPreviewControlsVisible(false)
      updateDirectionPadLayout()
      return
   end

   local isOutfit = selectedAppearanceCategory == 1
   local useDirectionPad = isOutfit and group.patternWidth >= 4
   local groupBox = window:recursiveGetChildById('previewFrameGroup')
   local movingCheck = window:recursiveGetChildById('previewMoving')
   local mountedCheck = window:recursiveGetChildById('previewMounted')
   local directionBox = window:recursiveGetChildById('previewPatternX')
   local addonBox = window:recursiveGetChildById('previewPatternY')
   local layerBox = window:recursiveGetChildById('previewLayer')
   local patternZBox = window:recursiveGetChildById('previewPatternZ')
   local settings = window:recursiveGetChildById('previewTopControls')
   local phaseLabel = window:recursiveGetChildById('previewPhaseLabel')

   settings:setMarginLeft(8)
   local hasAnimation = group.animation and group.animation.enabled and group.animation.phases and
      #group.animation.phases > 0 or false
   local phaseCount = math.max(1, group.phaseCount or 1)
   local hasFrameControls = group ~= nil
   local _, showNumericFrameSelector, framePanelHeight =
      updatePreviewTimelineLayout(phaseCount, hasFrameControls, hasAnimation)

   groupBox:setVisible(#previewFrameGroups > 1 and not previewHasMovementToggle)
   movingCheck:setVisible(previewHasMovementToggle)
   setCheckBoxState(movingCheck, previewMoving)
   mountedCheck:setVisible(isOutfit and group.patternDepth > 1)
   setCheckBoxState(mountedCheck, previewMounted)
   local animationSettingsRow = window:recursiveGetChildById('previewAnimationSettingsRow')
   animationSettingsRow:setVisible(hasAnimation)

   if useDirectionPad then
      directionBox:setVisible(false)
      for _, direction in ipairs(PREVIEW_DIRECTIONS) do
         local button = window:recursiveGetChildById(direction.id)
         local visible = direction.index < group.patternWidth
         button:setVisible(visible)
         if visible then
            local selected = direction.index == previewPatternX
            button:setChecked(selected)
            button:setColor(selected and '#d9c7ff' or '#dfdfdf')
         end
      end
   else
      buildPatternOptions(directionBox, isOutfit and tr('Direction') or tr('Pattern X'), group.patternWidth, previewPatternX)
   end

   buildPatternOptions(addonBox, isOutfit and tr('Addon') or tr('Pattern Y'), group.patternHeight,
      previewPatternY, isOutfit and outfitAddonOptionLabel or nil)
   buildPatternOptions(layerBox, tr('Layer'), group.layers, previewLayer)
   if isOutfit then
      patternZBox:setVisible(false)
   else
      buildPatternOptions(patternZBox, tr('Pattern Z'), group.patternDepth, previewPatternZ)
   end

   local metaRow = window:recursiveGetChildById('previewMetaRow')
   local patternRow = window:recursiveGetChildById('previewPatternRow')
   local hasMetaControls = (#previewFrameGroups > 1 and not previewHasMovementToggle) or
      previewHasMovementToggle or (isOutfit and group.patternDepth > 1)
   local hasPatternControls = (not useDirectionPad and group.patternWidth > 1) or group.patternHeight > 1 or
      group.layers > 1 or (not isOutfit and group.patternDepth > 1)
   local hasTopSettings = hasMetaControls or hasPatternControls or hasAnimation
   metaRow:setVisible(hasMetaControls)
   patternRow:setVisible(hasPatternControls)
   local settingsRowCount = (hasMetaControls and 1 or 0) + (hasPatternControls and 1 or 0) +
      (hasAnimation and 1 or 0)
   local settingsHeight = settingsRowCount > 0 and
      (hasMetaControls and 22 or 0) + (hasPatternControls and 22 or 0) + (hasAnimation and 28 or 0) +
      (settingsRowCount - 1) * 4 or 1
   settings:setHeight(settingsHeight)

   local groupOptions = {}
   for index, frameGroup in ipairs(previewFrameGroups) do
      table.insert(groupOptions, { label = frameGroupName(frameGroup, index), data = index })
   end
   setComboOptions(groupBox, groupOptions, previewFrameGroupIndex)

   phaseLabel:setVisible(showNumericFrameSelector)
   previewPhase = math.min(previewPhase, phaseCount - 1)
   local phaseStepper = window:recursiveGetChildById('previewPhaseStepper')
   phaseStepper:setVisible(showNumericFrameSelector)
   local onValueChange = phaseStepper.onValueChange
   phaseStepper.onValueChange = nil
   phaseStepper:setMinimum(1)
   phaseStepper:setMaximum(phaseCount)
   phaseStepper:setStep(1)
   phaseStepper:setMouseScroll(true)
   phaseStepper:setValue(previewPhase + 1, true)
   phaseStepper.onValueChange = onValueChange
   local phaseCountLabel = window:recursiveGetChildById('previewPhaseCount')
   phaseCountLabel:setVisible(showNumericFrameSelector)
   phaseCountLabel:setText(tr('of %d', phaseCount))
   local panelHeight = 8 + settingsHeight + (hasFrameControls and 6 or 0) + framePanelHeight + 8
   setPreviewControlsVisible(hasTopSettings or hasFrameControls, panelHeight)
   updateDirectionPadLayout()
   updateSpriteReplacementTarget()
end

refreshAppearancePreview = function()
   local group = currentPreviewGroup()
   if not group then
      return false
   end

   local directionBox = window:recursiveGetChildById('previewPatternX')
   local addonBox = window:recursiveGetChildById('previewPatternY')
   local layerBox = window:recursiveGetChildById('previewLayer')
   local patternZBox = window:recursiveGetChildById('previewPatternZ')
   local phaseStepper = window:recursiveGetChildById('previewPhaseStepper')
   local useDirectionPad = selectedAppearanceCategory == 1 and group.patternWidth >= 4
   if not useDirectionPad then
      previewPatternX = selectedOption(directionBox) or 0
   end
   previewPatternY = selectedOption(addonBox) or 0
   previewLayer = selectedOption(layerBox) or 0
   previewPhase = (phaseStepper:getValue() or 1) - 1
   if selectedAppearanceCategory == 1 and group.patternDepth > 1 then
      previewMounted = window:recursiveGetChildById('previewMounted'):isChecked()
      previewPatternZ = previewMounted and group.patternDepth - 1 or 0
   else
      previewPatternZ = selectedOption(patternZBox) or 0
   end

   local spriteIndex = (((previewPhase * group.patternDepth + previewPatternZ) * group.patternHeight +
      previewPatternY) * group.patternWidth + previewPatternX) * group.layers + previewLayer + 1
   local spriteId = group.sprites[spriteIndex]
   if spriteId and spriteId > 0 then
      local selected = selectSprite(spriteId)
      if selected then
         updateSpriteReplacementTarget()
      end
      return selected
   end

   selectedSpriteId = nil
   canvas:setVisible(false)
   updateDirectionPadLayout()
   setPreviewMessage(tr('No sprite is linked to this frame selection.'))
   updateSpriteReplacementTarget()
   setStatus(tr('No sprite is linked to this frame selection.'))
   return false
end

capturePreviewSelection = function()
   local group = currentPreviewGroup()
   if not group then
      return nil
   end
   return {
      groupType = group.type,
      groupId = group.id,
      groupIndex = previewFrameGroupIndex,
      patternX = previewPatternX,
      patternY = previewPatternY,
      patternZ = previewPatternZ,
      layer = previewLayer,
      phase = previewPhase,
      mounted = previewMounted,
   }
end

local function restorePreviewSelection(selection)
   if not selection then
      return
   end

   local matchingIndex
   for index, group in ipairs(previewFrameGroups) do
      if group.type == selection.groupType and group.id == selection.groupId then
         matchingIndex = index
         break
      end
   end
   previewFrameGroupIndex = matchingIndex or math.min(selection.groupIndex, #previewFrameGroups)
   local group = currentPreviewGroup()
   if not group then
      return
   end

   previewMoving = previewHasMovementToggle and group.type == 1
   previewPatternX = math.min(selection.patternX, math.max(0, group.patternWidth - 1))
   previewPatternY = math.min(selection.patternY, math.max(0, group.patternHeight - 1))
   previewPatternZ = math.min(selection.patternZ, math.max(0, group.patternDepth - 1))
   previewLayer = math.min(selection.layer, math.max(0, group.layers - 1))
   previewPhase = math.min(selection.phase, math.max(0, (group.phaseCount or 1) - 1))
   previewMounted = selectedAppearanceCategory == 1 and group.patternDepth > 1 and selection.mounted

   updatePreviewPatternControls()
   updateAnimationEditor()
   refreshAppearancePreview()
end

persistEditorUiState = function(saveImmediately)
   if restoringEditorUiState then
      return
   end

   local version = activeVersion
   if not version and window then
      version = selectedOption(window:recursiveGetChildById('versionComboBox'))
   end
   version = tonumber(version) or savedEditorUiState.version

   local appearanceSearch = savedEditorUiState.appearanceSearch or ''
   local appearanceListOffset = savedEditorUiState.appearanceListOffset or 0
   local replaceSpriteSearch = savedEditorUiState.replaceSpriteSearch or ''
   local createSpriteSearch = savedEditorUiState.createSpriteSearch or ''
   local replaceSpriteListOffset = savedEditorUiState.replaceSpriteListOffset or 0
   local createSpriteListOffset = savedEditorUiState.createSpriteListOffset or 0
   if window then
      local search = window:recursiveGetChildById('appearanceSearch')
      local list = window:recursiveGetChildById('appearanceList')
      local replaceSearch = window:recursiveGetChildById('spriteSearchEdit')
      local createSearch = window:recursiveGetChildById('newAppearanceSpriteSearchEdit')
      local replaceList = window:recursiveGetChildById('spritePickerList')
      local createList = window:recursiveGetChildById('newAppearanceSpritePickerList')
      appearanceSearch = search and search:getText() or appearanceSearch
      appearanceListOffset = activeVersion and list and list:getVirtualOffset().y or appearanceListOffset
      replaceSpriteSearch = replaceSearch and replaceSearch:getText() or replaceSpriteSearch
      createSpriteSearch = createSearch and createSearch:getText() or createSpriteSearch
      replaceSpriteListOffset = activeVersion and replaceList and
         replaceList:getVirtualOffset().y or replaceSpriteListOffset
      createSpriteListOffset = activeVersion and createList and
         createList:getVirtualOffset().y or createSpriteListOffset
   end

   savedEditorUiState = {
      version = version,
      page = currentPage,
      propertiesTab = currentPropertiesTab,
      importSection = currentImportSection,
      replaceMode = currentReplaceMode,
      newAppearanceSourceMode = currentNewAppearanceSourceMode,
      exportSubpage = currentExportSubpage,
      exportMode = currentExportMode,
      category = selectedAppearanceCategory,
      appearanceId = selectedAppearanceId or (not activeVersion and savedEditorUiState.appearanceId) or 0,
      appearanceSearch = appearanceSearch,
      appearanceListOffset = math.max(0, math.floor(appearanceListOffset or 0)),
      replaceSpriteSearch = replaceSpriteSearch,
      createSpriteSearch = createSpriteSearch,
      replaceSpriteListOffset = math.max(0, math.floor(replaceSpriteListOffset or 0)),
      createSpriteListOffset = math.max(0, math.floor(createSpriteListOffset or 0)),
      replacementSpriteId = selectedReplacementSpriteId or 0,
      createSpriteId = selectedCreateSpriteId or 0,
      previewSelection = (capturePreviewSelection and capturePreviewSelection()) or
         (not activeVersion and savedEditorUiState.previewSelection) or nil,
   }
   g_settings.setNode(EDITOR_UI_STATE_SETTING, savedEditorUiState)

   if editorUiStateSaveEvent then
      removeEvent(editorUiStateSaveEvent)
      editorUiStateSaveEvent = nil
   end
   if saveImmediately then
      if not g_settings.save() then
         g_logger.warning('[game_sprite_editor] Unable to save editor UI state.')
      end
      return
   end

   editorUiStateSaveEvent = scheduleEvent(function()
      editorUiStateSaveEvent = nil
      if not g_settings.save() then
         g_logger.warning('[game_sprite_editor] Unable to save editor UI state.')
      end
   end, EDITOR_UI_STATE_SAVE_DELAY)
end

local function refreshAfterHistoryChange(label, action)
   local category = selectedAppearanceCategory
   local appearanceId = selectedAppearanceId
   local selection = capturePreviewSelection()
   local page = currentPage
   if not reloadAssets() then
      setStatus(tr('%s was applied, but the working copy could not be reloaded.', action))
      return false
   end

   refreshAppearanceCatalog(category)
   local thing = appearanceId and g_things.getThingType(appearanceId, category)
   if thing and thing:getId() == appearanceId then
      loadAppearanceRecord(category, appearanceId, true, true)
      restorePreviewSelection(selection)
   else
      selectedAppearanceId = nil
      local firstEntry = getFilteredAppearanceEntry(1)
      if firstEntry then
         loadAppearanceRecord(category, firstEntry.id, true, true)
      else
         clearAppearanceProperties()
      end
   end
   setActivePage(page)
   updateHistoryControls()
   setStatus(tr('%s: %s.', action, label))
   return true
end

function undoWorkCopyEdit(forceDiscard)
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before undoing?'), function()
         undoWorkCopyEdit(true)
      end)
      return
   end
   if pendingSpriteEdit then
      setStatus(tr('Apply or discard the pending sprite edit before undoing.'))
      return
   end
   if not activeVersion or g_game.isOnline() then
      return
   end

   local ok, label = pcall(g_spriteAppearances.undoWorkCopyEdit, activeVersion)
   if not ok then
      setStatus(getUserFacingError(label))
      return
   end
   if label == '' then
      updateHistoryControls()
      return
   end
   refreshAfterHistoryChange(label, tr('Undid'))
end

function redoWorkCopyEdit(forceDiscard)
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before redoing?'), function()
         redoWorkCopyEdit(true)
      end)
      return
   end
   if pendingSpriteEdit then
      setStatus(tr('Apply or discard the pending sprite edit before redoing.'))
      return
   end
   if not activeVersion or g_game.isOnline() then
      return
   end

   local ok, label = pcall(g_spriteAppearances.redoWorkCopyEdit, activeVersion)
   if not ok then
      setStatus(getUserFacingError(label))
      return
   end
   if label == '' then
      updateHistoryControls()
      return
   end
   refreshAfterHistoryChange(label, tr('Redid'))
end

configurePreviewControls = function(frameGroups)
   stopPreviewAnimation()
   previewFrameGroups = frameGroups or {}
   previewFrameGroupIndex = math.min(math.max(1, previewFrameGroupIndex), math.max(1, #previewFrameGroups))
   previewIdleGroupIndex = nil
   previewMovingGroupIndex = nil
   for index, group in ipairs(previewFrameGroups) do
      if group.type == 0 and not previewIdleGroupIndex then
         previewIdleGroupIndex = index
      elseif group.type == 1 and not previewMovingGroupIndex then
         previewMovingGroupIndex = index
      end
   end
   previewHasMovementToggle = selectedAppearanceCategory == 1 and #previewFrameGroups == 2 and
      previewIdleGroupIndex ~= nil and previewMovingGroupIndex ~= nil
   previewMoving = false
   if previewHasMovementToggle then
      previewFrameGroupIndex = previewIdleGroupIndex
   end
   previewPatternX = 0
   previewPatternY = 0
   previewPatternZ = 0
   previewLayer = 0
   previewPhase = 0
   previewMounted = false
   previewMoving = false
   if not window then
      return
   end

   setPreviewControlsVisible(false)
   if #previewFrameGroups == 0 then
      return
   end

   local frameGroupBox = window:recursiveGetChildById('previewFrameGroup')
   frameGroupBox.onOptionChange = function(_, _, frameGroupIndex)
      if frameGroupIndex then
         stopPreviewAnimation()
         if not collectAnimationWidgetChanges() then
            frameGroupBox:setCurrentOptionByData(previewFrameGroupIndex, true)
            return
         end
         previewFrameGroupIndex = frameGroupIndex
         previewPatternX = 0
         previewPatternY = 0
         previewPatternZ = 0
         previewLayer = 0
         previewPhase = 0
         previewMounted = false
         updatePreviewPatternControls()
         updateAnimationEditor()
         refreshAppearancePreview()
      end
   end

   for _, controlId in ipairs({ 'previewPatternX', 'previewPatternY', 'previewLayer', 'previewPatternZ' }) do
      window:recursiveGetChildById(controlId).onOptionChange = function()
         refreshAppearancePreview()
      end
   end
   window:recursiveGetChildById('previewPhaseStepper').onValueChange = function(_, value)
      if not collectAnimationWidgetChanges() then
         local phaseStepper = window:recursiveGetChildById('previewPhaseStepper')
         local onValueChange = phaseStepper.onValueChange
         phaseStepper.onValueChange = nil
         phaseStepper:setValue(previewPhase + 1, true)
         phaseStepper.onValueChange = onValueChange
         return
      end
      previewPhase = (value or 1) - 1
      selectPreviewPhase(previewPhase, false)
   end
   window:recursiveGetChildById('previewMoving').onCheckChange = function(widget)
      if not previewHasMovementToggle then
         return
      end
      stopPreviewAnimation()
      if not collectAnimationWidgetChanges() then
         setCheckBoxState(widget, not widget:isChecked())
         return
      end
      previewMoving = widget:isChecked()
      previewFrameGroupIndex = previewMoving and previewMovingGroupIndex or previewIdleGroupIndex
      previewPhase = 0
      updatePreviewPatternControls()
      updateAnimationEditor()
      refreshAppearancePreview()
   end

   window:recursiveGetChildById('previewMounted').onCheckChange = function()
      refreshAppearancePreview()
   end

   updatePreviewPatternControls()
   updateAnimationEditor()
   refreshAppearancePreview()
end

updateAnimationEditor = function()
   if not window then
      return
   end
   local wasBuildingProperties = buildingAppearanceProperties
   buildingAppearanceProperties = true
   local frameList = window:recursiveGetChildById('previewTimelineFrames')
   frameList:destroyChildren()
   animationWidgets = {}
   local group = currentPreviewGroup()
   local enabled = group and group.animation and group.animation.enabled == true or false
   local phaseCount = group and math.max(1, group.phaseCount or 1) or 1
   local isAnimated = enabled and group.animation.phases and #group.animation.phases > 0 or false
   local settingsRow = window:recursiveGetChildById('previewAnimationSettingsRow')
   local phaseStepper = window:recursiveGetChildById('previewPhaseStepper')
   local addFrameButton = window:recursiveGetChildById('addAnimationFrameButton')
   local removeFrameButton = window:recursiveGetChildById('removeAnimationFrameButton')
   local playButton = window:recursiveGetChildById('previewPlayButton')
   local phaseCountLabel = window:recursiveGetChildById('previewPhaseCount')
   local minLabel = window:recursiveGetChildById('animationDurationMinLabel')
   local minEdit = window:recursiveGetChildById('animationDurationMin')
   local maxLabel = window:recursiveGetChildById('animationDurationMaxLabel')
   local maxEdit = window:recursiveGetChildById('animationDurationMax')
   local frameSelectionGroup = window:recursiveGetChildById('previewFrameSelectionGroup')
   local durationGroup = window:recursiveGetChildById('previewDurationGroup')
   local hasFrameControls = group ~= nil
   local showFrameButtons, showNumericFrameSelector =
      updatePreviewTimelineLayout(phaseCount, hasFrameControls, isAnimated)

   frameSelectionGroup:setVisible(showNumericFrameSelector)
   durationGroup:setVisible(isAnimated)
   phaseStepper:setMinimum(1)
   phaseStepper:setMaximum(phaseCount)
   phaseStepper:setStep(1)
   phaseStepper:setMouseScroll(true)
   phaseStepper:setVisible(showNumericFrameSelector)
   phaseCountLabel:setVisible(showNumericFrameSelector)
   phaseCountLabel:setText(tr('of %d', phaseCount))
   minLabel:setVisible(isAnimated)
   minEdit:setVisible(isAnimated)
   maxLabel:setVisible(isAnimated)
   maxEdit:setVisible(isAnimated)
   settingsRow:setVisible(isAnimated)
   local showPlayButton = isAnimated and phaseCount > 1
   playButton:setVisible(showPlayButton)
   playButton:setEnabled(showPlayButton)
   window:recursiveGetChildById('previewPhaseActions'):setWidth(showPlayButton and 104 or 54)
   local previewIsPlaying = previewAnimationPlayer and previewAnimationPlayer:is_playing() or false
   playButton:setText(previewIsPlaying and tr('Pause') or tr('Play'))
   playButton:setTooltip(previewIsPlaying and tr('Pause the animation preview.') or
      tr('Play the animation preview from the selected frame.'))
   playButton:setOn(previewIsPlaying)
   local canEditFrames = group ~= nil and activeVersion ~= nil and not g_game.isOnline()
   addFrameButton:setEnabled(canEditFrames and phaseCount < math.floor(2147483647 /
      (math.max(1, group.layers or 1) * math.max(1, group.patternWidth or 1) *
      math.max(1, group.patternHeight or 1) * math.max(1, group.patternDepth or 1))))
   removeFrameButton:setEnabled(canEditFrames and phaseCount > 1)
   addFrameButton.onClick = function()
      changeAnimationPhaseCount(1)
   end
   removeFrameButton.onClick = function()
      if not canEditFrames or phaseCount <= 1 or not collectAnimationWidgetChanges() then
         return
      end
      local messageBox
      messageBox = displayGeneralBox(tr('Remove animation frame'),
         tr('Remove the last frame (%d) and its sprite links? This change will be applied when you save the appearance.', phaseCount), {
            { text = tr('Remove frame'), callback = function()
               messageBox:ok()
               changeAnimationPhaseCount(-1)
            end },
            { text = tr('Cancel'), callback = function() messageBox:cancel() end },
         })
   end

   local onValueChange = phaseStepper.onValueChange
   phaseStepper.onValueChange = nil
   phaseStepper:setValue(previewPhase + 1, true)
   phaseStepper.onValueChange = onValueChange

   if isAnimated then
      local groupIndex = group.index
      local groupKey = tostring(groupIndex)
      local changes = appearanceChanges.animation.groups[groupKey] or {}
      local animation = group.animation
      local defaultPhase = window:recursiveGetChildById('animationDefaultPhase')
      local randomStart = window:recursiveGetChildById('animationRandomStart')
      local synchronized = window:recursiveGetChildById('animationSynchronized')
      local loopTypeBox = window:recursiveGetChildById('animationLoopType')
      local loopCountLabel = window:recursiveGetChildById('animationLoopCountLabel')
      local loopCount = window:recursiveGetChildById('animationLoopCount')
      local loopCountControls = window:recursiveGetChildById('animationLoopCountControls')
      local randomStartValue = changes.randomStartPhase
      if randomStartValue == nil then
         randomStartValue = animation.randomStartPhase
      end
      local synchronizedValue = changes.synchronized
      if synchronizedValue == nil then
         synchronizedValue = animation.synchronized
      end
      local defaultPhaseValue = changes.defaultStartPhase
      if defaultPhaseValue == nil then
         defaultPhaseValue = animation.defaultStartPhase
      end
      defaultPhase:setText(tostring(defaultPhaseValue))
      randomStart:setChecked(randomStartValue)
      synchronized:setChecked(synchronizedValue)
      loopCount:setText(tostring(changes.loopCount ~= nil and changes.loopCount or animation.loopCount))
      setComboOptions(loopTypeBox, {
         { label = tr('Ping pong'), data = -1 },
         { label = tr('Infinite'), data = 0 },
         { label = tr('Counted'), data = 1 },
      }, changes.loopType ~= nil and changes.loopType or animation.loopType)
      local loopType = changes.loopType ~= nil and changes.loopType or animation.loopType
      loopCountLabel:setVisible(loopType == 1)
      loopCount:setVisible(loopType == 1)
      loopCountControls:setVisible(loopType == 1)
      loopCountControls:setWidth(loopType == 1 and 100 or 0)

      animationWidgets.groupIndex = groupIndex
      animationWidgets.fields = { defaultStartPhase = defaultPhase, loopCount = loopCount }

      defaultPhase.onTextChange = function(widget)
         if not buildingAppearanceProperties then
            local value = tonumber(widget:getText())
            if value and value >= 0 and value % 1 == 0 and value < phaseCount then
               setAnimationChange(groupIndex, 'defaultStartPhase', value)
            end
         end
      end
      randomStart.onCheckChange = function(widget)
         if not buildingAppearanceProperties then
            setAnimationChange(groupIndex, 'randomStartPhase', widget:isChecked())
         end
      end
      synchronized.onCheckChange = function(widget)
         if not buildingAppearanceProperties then
            setAnimationChange(groupIndex, 'synchronized', widget:isChecked())
         end
      end
      loopTypeBox.onOptionChange = function(_, _, value)
         if not buildingAppearanceProperties and value ~= nil then
            setAnimationChange(groupIndex, 'loopType', value)
            loopCountLabel:setVisible(value == 1)
            loopCount:setVisible(value == 1)
            loopCountControls:setVisible(value == 1)
            loopCountControls:setWidth(value == 1 and 100 or 0)
         end
      end
      loopCount.onTextChange = function(widget)
         if not buildingAppearanceProperties then
            local value = tonumber(widget:getText())
            if value and value >= 0 and value % 1 == 0 then
               setAnimationChange(groupIndex, 'loopCount', value)
            end
         end
      end

      local phase = animation.phases[previewPhase + 1]
      if phase then
         local phaseChanges = changes.phases and changes.phases[tostring(previewPhase)] or {}
         minEdit:setText(tostring(phaseChanges.durationMin ~= nil and phaseChanges.durationMin or phase.durationMin))
         maxEdit:setText(tostring(phaseChanges.durationMax ~= nil and phaseChanges.durationMax or phase.durationMax))
         animationWidgets.phaseIndex = previewPhase
         animationWidgets.phaseFields = { durationMin = minEdit, durationMax = maxEdit }
         local function updatePhaseDurationChanges()
            if buildingAppearanceProperties then
               return
            end
            local durationMin = tonumber(minEdit:getText())
            local durationMax = tonumber(maxEdit:getText())
            if not durationMin or not durationMax or durationMin < 0 or durationMax < 0 or
                  durationMin % 1 ~= 0 or durationMax % 1 ~= 0 or durationMin > durationMax then
               return
            end
            setAnimationChange(groupIndex, 'durationMin', durationMin, previewPhase)
            setAnimationChange(groupIndex, 'durationMax', durationMax, previewPhase)
         end
         minEdit.onTextChange = updatePhaseDurationChanges
         maxEdit.onTextChange = updatePhaseDurationChanges
      end
   else
      local loopTypeBox = window:recursiveGetChildById('animationLoopType')
      loopTypeBox.onOptionChange = nil
      loopTypeBox:clearOptions()
      local loopCountControls = window:recursiveGetChildById('animationLoopCountControls')
      loopCountControls:setVisible(false)
      loopCountControls:setWidth(0)
      window:recursiveGetChildById('animationLoopCountLabel'):setVisible(false)
      window:recursiveGetChildById('animationDefaultPhase'):setText('0')
      window:recursiveGetChildById('animationRandomStart'):setChecked(false)
      window:recursiveGetChildById('animationSynchronized'):setChecked(false)
      window:recursiveGetChildById('animationLoopCount'):setText('0')
      minEdit:setText('')
      maxEdit:setText('')
   end

   if showFrameButtons then
      for phaseIndex = 0, phaseCount - 1 do
         local currentPhaseIndex = phaseIndex
         local frameCell = g_ui.createWidget('AppearanceTimelineCell', frameList)
         local frameButton = frameCell:getChildById('previewTimelineFrameButton')
         local frameTrack = frameCell:getChildById('previewTimelineTrack')
         frameTrack:setHeight(PREVIEW_TIMELINE_TRACK_HEIGHT)
         frameTrack:setVisible(phaseCount > 1)
         frameButton:setText(tostring(currentPhaseIndex + 1))
         frameButton:setTooltip(tr('Frame %d', currentPhaseIndex + 1))
         frameButton.onMousePress = function(_, _, mouseButton)
            if mouseButton ~= MouseLeftButton then
               return false
            end
            timelineScrubbing = false
            selectPreviewPhase(currentPhaseIndex, false)
            return true
         end
         frameTrack:setTooltip(tr('Drag to scrub through frames.'))
         frameTrack.onMousePress = function(_, _, mouseButton)
            if mouseButton ~= MouseLeftButton then
               return false
            end
            stopPreviewAnimation()
            timelineScrubbing = true
            selectPreviewPhase(currentPhaseIndex, true)
            return true
         end
         frameTrack.onMouseMove = function(_, mousePos)
            if not timelineScrubbing then
               return false
            end
            for index, candidate in ipairs(frameList:getChildren()) do
               local rect = candidate:getRect()
               if mousePos.x >= rect.x and mousePos.x < rect.x + rect.width then
                  if index - 1 ~= previewPhase then
                     selectPreviewPhase(index - 1, true)
                  end
                  return true
               end
            end
            return true
         end
         frameTrack.onMouseRelease = function(_, _, mouseButton)
            if mouseButton == MouseLeftButton then
               timelineScrubbing = false
               return true
            end
            return false
         end
         if currentPhaseIndex == previewPhase then
            local phaseToReveal = currentPhaseIndex
            addEvent(function()
               if not window or not window:isVisible() then
                  return
               end

               local currentTimeline = window:recursiveGetChildById('previewTimeline')
               local currentFrameList = window:recursiveGetChildById('previewTimelineFrames')
               local currentFrameButton = currentFrameList:getChildByIndex(phaseToReveal + 1)
               local ensureChildVisible = UIScrollArea and UIScrollArea.ensureChildVisible
               if currentTimeline and currentFrameButton and ensureChildVisible then
                  ensureChildVisible(currentTimeline, currentFrameButton)
               end
            end)
         end
      end
   end
   frameList:setWidth(showFrameButtons and math.max(1, phaseCount * PREVIEW_TIMELINE_CELL_WIDTH) or 1)
   updatePreviewTimelineSelection(phaseCount)
   buildingAppearanceProperties = wasBuildingProperties
end

local function refreshSelectedAppearance()
   if not window or not activeVersion or not selectedAppearanceId then
      return
   end
   local thing = g_things.getThingType(selectedAppearanceId, selectedAppearanceCategory)
   if not thing or thing:getId() ~= selectedAppearanceId then
      setStatus(tr('Appearance %d is not available.', selectedAppearanceId))
      return
   end

   local category = categories[selectedAppearanceCategory + 1]
   local categoryName = category and tr(category.singular) or tr('Appearance')
   window:recursiveGetChildById('appearanceInfoLabel'):setText(
      tr('%s properties', categoryName))
   if #previewFrameGroups > 0 then
      refreshAppearancePreview()
   else
      local sprites = thing:getSprites()
      if #sprites > 0 then
         selectSprite(sprites[1])
      else
         selectedSpriteId = nil
         canvas:setVisible(false)
         setPreviewMessage(tr('This appearance has no linked sprites.'))
         updateSpriteReplacementTarget()
      end
   end
end

loadAppearanceRecord = function(category, id, forceDiscard, forceReload)
   if not window or not activeVersion or g_game.isOnline() then
      setStatus(tr('Open a 15.x work copy before editing appearances.'))
      return false
   end
   if selectedAppearanceCategory == category and selectedAppearanceId == id and appearanceOriginal and not forceReload then
      refreshSelectedAppearance()
      return true
   end
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before selecting another appearance?'), function()
         loadAppearanceRecord(category, id, true)
      end)
      return false
   end

   local ok, encoded = pcall(g_things.getAppearanceEditorData, activeVersion, category, id)
   if not ok then
      setStatus(getUserFacingError(encoded))
      return false
   end
   local decoded, data = pcall(json.decode, encoded)
   if not decoded or type(data) ~= 'table' or type(data.bools) ~= 'table' or type(data.values) ~= 'table' then
      setStatus(tr('Appearance properties could not be read.'))
      return false
   end
   local thing = g_things.getThingType(id, category)
   if not thing or thing:getId() ~= id then
      setStatus(tr('Appearance %d is not loaded by the client.', id))
      return false
   end

   selectedAppearanceCategory = category
   selectedAppearanceId = id
   selectedSpriteId = nil
   updateSpriteReplacementTarget()
   window:recursiveGetChildById('appearanceCategory'):setCurrentOptionByData(category, true)
   buildAppearanceProperties(data)
   refreshSelectedAppearance()
   local categoryInfo = categories[category + 1]
   setStatus(tr('%s %d loaded.', categoryInfo and tr(categoryInfo.singular) or tr('Appearance'), id))
   renderAppearanceRows(window:recursiveGetChildById('appearanceList'):getVirtualOffset().y)
   updateExportControls()
   if persistEditorUiState then
      persistEditorUiState()
   end
   return true
end

selectAppearance = function(category, id, forceDiscard)
   stopPreviewAnimation()
   loadAppearanceRecord(category, id, forceDiscard)
end

local function changeAppearanceCategory(category, forceDiscard)
   if not category then
      return
   end
   stopPreviewAnimation()
   if hasAppearanceChanges() and not forceDiscard then
      window:recursiveGetChildById('appearanceCategory'):setCurrentOptionByData(selectedAppearanceCategory, true)
      confirmUnsavedChanges(tr('Save changes before switching categories?'), function()
         changeAppearanceCategory(category, true)
      end)
      return
   end
   selectedAppearanceCategory = category
   selectedAppearanceId = nil
   updateExportControls()
   appearanceOriginal = nil
   clearAppearanceChanges()
   local searchEdit = window:recursiveGetChildById('appearanceSearch')
   if searchEdit:getText() ~= '' then
      searchEdit:setText('')
   end
   refreshAppearanceCatalog(category)
   local firstEntry = getFilteredAppearanceEntry(1)
   if firstEntry then
      loadAppearanceRecord(category, firstEntry.id, true)
   else
      clearAppearanceProperties()
      setStatus(getAppearanceEntryCount() > 0 and tr('No appearances match this search.') or
         tr('No appearances in this category.'))
   end
end

reloadAssets = function()
   if not activeAssetPath then
      return false
   end
   if not getWorkCopyService():reload(activeAssetPath) then
      return false
   end
   if refreshSpritePicker then refreshSpritePicker() end
   return true
end

local function releaseActiveWorkCopy()
   if not activeVersion then
      return true
   end

   local released, err = getWorkCopyService():release(activeVersion, activeWorkRoot, activeAssetPath)
   if not released then
      return false, getUserFacingError(err)
   end

   activeVersion = nil
   activeAssetPath = nil
   activeWorkRoot = nil
   installedAssetBackups = {}
   selectedInstalledBackupName = nil
   assetEditHistoryEntries = {}
   selectedAssetEditHistoryEntry = nil
   return true
end

updateExportControls = function()
   if not window then
      return
   end

   local offline = not g_game.isOnline()
   local showExportForm = currentExportSubpage == 'assets'
   local canExport = activeVersion ~= nil and offline
   local isNewVersion = currentExportMode == 'new'
   local isFolderExport = currentExportMode == 'folder'
   local isAppearanceExport = currentExportMode == 'appearance'
   local isDirectoryExport = isFolderExport or isAppearanceExport
   local canExportAppearance = canExport and selectedAppearanceId ~= nil and selectedAppearanceCategory ~= nil
   local batchAppearanceIds, filteredAppearanceCount = getAppearanceCatalogComponent():get_filtered_ids(8)
   local selectedVersion = selectedOption(window:recursiveGetChildById('versionComboBox'))
   local targetVersion = parseClientVersion(window:recursiveGetChildById('newVersionEdit'):getText())
   local destinationRoot = window:recursiveGetChildById('exportFolderEdit'):getText():trim()
   local isAbsoluteDestination = destinationRoot:sub(1, 1) == '/' or destinationRoot:match('^%a:[/\\]') ~= nil or
      destinationRoot:match('^[/\\][/\\]') ~= nil
   local versionDirectories = getVersionDirectories()
   local newVersionValid = isSupportedAssetVersion(targetVersion) and targetVersion ~= activeVersion and
      not versionDirectories[targetVersion]
   local folderDestinationValid = isAbsoluteDestination and activeVersion ~= nil

   window:recursiveGetChildById('exportAssetsSubpageButton'):setOn(showExportForm)
   window:recursiveGetChildById('exportBackupsSubpageButton'):setOn(not showExportForm)
   window:recursiveGetChildById('exportHeader'):setText(showExportForm and tr('Export assets') or tr('Asset backups'))
   window:recursiveGetChildById('exportModeTabs'):setVisible(showExportForm)
   window:recursiveGetChildById('exportSourceLabel'):setVisible(showExportForm)
   window:recursiveGetChildById('exportTargetRow'):setVisible(showExportForm)
   window:recursiveGetChildById('installTargetLabel'):setVisible(showExportForm)
   window:recursiveGetChildById('exportButton'):setVisible(showExportForm)
   window:recursiveGetChildById('exportHint'):setVisible(showExportForm)
   window:recursiveGetChildById('exportStatus'):setVisible(showExportForm)
   window:recursiveGetChildById('replaceVersionModeButton'):setOn(not isNewVersion and not isFolderExport and not isAppearanceExport)
   window:recursiveGetChildById('newVersionModeButton'):setOn(isNewVersion)
   window:recursiveGetChildById('exportFolderModeButton'):setOn(isFolderExport)
   window:recursiveGetChildById('exportAppearanceModeButton'):setOn(isAppearanceExport)
   window:recursiveGetChildById('replaceVersionModeButton'):setEnabled(canExport)
   window:recursiveGetChildById('newVersionModeButton'):setEnabled(canExport)
   window:recursiveGetChildById('exportFolderModeButton'):setEnabled(canExport)
   window:recursiveGetChildById('exportAppearanceModeButton'):setEnabled(canExportAppearance)
   window:recursiveGetChildById('targetVersionLabel'):setText(isNewVersion and
      tr('New supported version') or tr('Replace current version'))
   window:recursiveGetChildById('targetVersionLabel'):setVisible(not isDirectoryExport)
   window:recursiveGetChildById('newVersionEdit'):setEnabled(canExport and isNewVersion)
   window:recursiveGetChildById('newVersionEdit'):setVisible(isNewVersion)
   window:recursiveGetChildById('exportFolderEdit'):setEnabled(canExport and isDirectoryExport)
   window:recursiveGetChildById('exportFolderEdit'):setVisible(isDirectoryExport)
   window:recursiveGetChildById('exportFolderBrowseButton'):setEnabled(canExport and isDirectoryExport and g_platform.isDesktop())
   window:recursiveGetChildById('exportFolderBrowseButton'):setVisible(isDirectoryExport)
   local sourceCategory = categories[(selectedAppearanceCategory or -1) + 1]
   window:recursiveGetChildById('exportSourceLabel'):setText(isAppearanceExport and selectedAppearanceId and
      tr('Selected: %s %d', sourceCategory and tr(sourceCategory.singular) or tr('Appearance'), selectedAppearanceId) or
      (activeVersion and tr('Source version: %s', formatClientVersion(activeVersion)) or tr('No assets version loaded.')))
   local category = categories[(selectedAppearanceCategory or -1) + 1]
   local categoryName = category and category.name:lower() or 'appearance'
   local installTarget = isFolderExport and
      (folderDestinationValid and string.format('%s/data/things/%d', destinationRoot, activeVersion) or
         tr('Choose an absolute destination folder.')) or
      (isAppearanceExport and (folderDestinationValid and
         string.format('%s/appearance-%s-%d', destinationRoot, categoryName:lower(), selectedAppearanceId or 0) or
         tr('Choose an absolute destination folder.')) or
      (isNewVersion and (newVersionValid and string.format('data/things/%d', targetVersion) or
         tr('Choose an unused 15.x version supported by this client.')) or
         (activeVersion and string.format('data/things/%d', activeVersion) or tr('No install destination.'))))
   window:recursiveGetChildById('installTargetLabel'):setText(installTarget)
   local exportButton = window:recursiveGetChildById('exportButton')
   exportButton:setText(isAppearanceExport and tr('Export appearance bundle') or
      (isFolderExport and tr('Copy assets to folder') or
         (isNewVersion and tr('Install as new version') or
            tr('Replace %s', activeVersion and formatClientVersion(activeVersion) or ''))))
   window:recursiveGetChildById('exportHint'):setText(isFolderExport and
      tr('Creates a data/things/%d package. Existing packages are never overwritten.', activeVersion or 0) or
         (isAppearanceExport and tr('Includes appearance metadata and referenced sprites. Batch export follows the left list filter and handles up to 8 appearances.') or
         (isNewVersion and tr('The source stays unchanged. Choose an unused version to add it to the client.') or
            tr('Existing assets are backed up first. If none exist, the working copy is installed.'))))
   local exportTargetValid = isAppearanceExport and folderDestinationValid or isFolderExport and folderDestinationValid or
      (isNewVersion and newVersionValid) or (not isNewVersion and not isFolderExport)
   if isAppearanceExport then
      exportTargetValid = folderDestinationValid and selectedAppearanceId ~= nil
   end
   exportButton:setEnabled((isAppearanceExport and canExportAppearance or canExport) and exportTargetValid)
   local batchExportButton = window:recursiveGetChildById('exportAppearanceBatchButton')
   batchExportButton:setVisible(showExportForm and isAppearanceExport)
   batchExportButton:setText(filteredAppearanceCount > 8 and tr('Filter to 8 or fewer appearances') or
      tr('Export %d filtered bundle(s)', filteredAppearanceCount))
   batchExportButton:setEnabled(isAppearanceExport and canExport and folderDestinationValid and
      batchAppearanceIds ~= nil)
   local loadAssetsButton = window:recursiveGetChildById('loadAssetsButton')
   local selectedVersionInstalled = selectedVersion and modules.client_assets.isClientVersionInstalled(selectedVersion)
   loadAssetsButton:setText(selectedVersionInstalled and tr('Load assets') or tr('Download and load'))
   loadAssetsButton:setEnabled(offline and selectedVersion ~= nil and
      (selectedVersionInstalled or (modules.client_assets.isEnabled and modules.client_assets.isEnabled())))
   window:recursiveGetChildById('importPageButton'):setEnabled(activeVersion ~= nil and not g_game.isOnline())
   window:recursiveGetChildById('exportPageButton'):setEnabled(activeVersion ~= nil and not g_game.isOnline())
   window:recursiveGetChildById('historyPageButton'):setEnabled(activeVersion ~= nil and not g_game.isOnline())
   window:recursiveGetChildById('reloadButton'):setEnabled(activeVersion ~= nil and not g_game.isOnline())
   window:recursiveGetChildById('newAppearanceTabButton'):setEnabled(activeVersion ~= nil and not g_game.isOnline())
   window:recursiveGetChildById('appearanceBundleTabButton'):setEnabled(activeVersion ~= nil and not g_game.isOnline())
   local restoreBackupPanel = window:recursiveGetChildById('restoreBackupPanel')
   restoreBackupPanel:setVisible(not showExportForm)
   window:recursiveGetChildById('restoreBackupHeader'):setText(
      tr('Restore installed backup (%s)', activeVersion and formatClientVersion(activeVersion) or ''))
   window:recursiveGetChildById('restoreBackupButton'):setEnabled(
      canExport and selectedInstalledBackupName ~= nil and
         getInstalledAssetBackup(selectedInstalledBackupName) ~= nil)
   updateHistoryControls()
end

function setExportSubpage(subpage)
   if subpage ~= 'assets' and subpage ~= 'backups' then
      return
   end
   currentExportSubpage = subpage
   updateExportControls()
   if persistEditorUiState then
      persistEditorUiState()
   end
end

function setExportMode(mode)
   if mode ~= 'replace' and mode ~= 'new' and mode ~= 'folder' and mode ~= 'appearance' then
      return
   end
   currentExportMode = mode
   if window then
      setExportStatus('')
      updateExportControls()
   end
   if persistEditorUiState then
      persistEditorUiState()
   end
end

function exportFilteredAppearanceBundles(confirmed)
   if currentExportMode ~= 'appearance' or not activeVersion or g_game.isOnline() or
         selectedAppearanceCategory == nil then
      return
   end
   local ids = getAppearanceCatalogComponent():get_filtered_ids(8)
   if not ids then
      setStatus(tr('Filter the appearance list to 8 or fewer results before batch export.'))
      return
   end
   local destination = window:recursiveGetChildById('exportFolderEdit'):getText():trim()
   local absolute = destination:sub(1, 1) == '/' or destination:match('^%a:[/\\]') ~= nil or
      destination:match('^[/\\][/\\]') ~= nil
   if not absolute then
      setStatus(tr('Choose an absolute destination folder.'))
      return
   end
   if hasAppearanceChanges() then
      confirmUnsavedChanges(tr('Save changes before exporting appearance bundles?'), function()
         exportFilteredAppearanceBundles(true)
      end)
      return
   end
   if not confirmed then
      local box
      local function cancelExport()
         box:cancel()
      end
      local function confirmExport()
         box:ok()
         exportFilteredAppearanceBundles(true)
      end
      box = displayGeneralBox(tr('Export filtered appearances?'),
         tr('Exports %d appearances from the current filtered list to %s. Existing bundle folders are kept unchanged.',
            #ids, destination), {
            { text = tr('Export bundles'), callback = confirmExport },
            { text = tr('Cancel'), callback = cancelExport },
         }, cancelExport, cancelExport)
      return
   end

   local called, response = pcall(g_things.exportAppearanceBundles, activeVersion,
      selectedAppearanceCategory, json.encode(ids), destination)
   if not called then
      setStatus(getUserFacingError(response))
      return
   end
   local decoded, result = pcall(json.decode, response)
   if not decoded or type(result) ~= 'table' or type(result.items) ~= 'table' or
         type(result.failures) ~= 'table' then
      setStatus(tr('The batch bundle export returned an invalid result. Check the client log.'))
      return
   end
   if tonumber(result.exported) == 0 then
      local failure = result.failures[1]
      setStatus(failure and tr('No bundles were exported. Appearance %d: %s', failure.id, failure.error) or
         tr('No appearance bundles were exported.'))
      return
   end
   if tonumber(result.failed) > 0 then
      local failure = result.failures[1]
      setStatus(tr('Exported %d bundle(s); %d failed. First failure for appearance %d: %s',
         result.exported, result.failed, failure.id, failure.error))
   else
      setStatus(tr('Exported %d appearance bundle(s) to %s.', result.exported, destination))
   end
end

setActivePage = function(page)
   if not window then
      return
   end
   currentPage = page
   window:recursiveGetChildById('propertiesPanel'):setVisible(page == 'editor')
   window:recursiveGetChildById('importPanel'):setVisible(page == 'import')
   window:recursiveGetChildById('exportPanel'):setVisible(page == 'export')
   window:recursiveGetChildById('historyPanel'):setVisible(page == 'history')
   window:recursiveGetChildById('editorPageButton'):setOn(page == 'editor')
   window:recursiveGetChildById('importPageButton'):setOn(page == 'import')
   window:recursiveGetChildById('exportPageButton'):setOn(page == 'export')
   window:recursiveGetChildById('historyPageButton'):setOn(page == 'history')
   updateSpriteReplacementTarget()
   updateExportControls()
   if persistEditorUiState then
      persistEditorUiState()
   end
end

local getSelectedSpriteReference

local function createWindow(restoreEditorState)
   if window then
      window:destroy()
   end
   window = g_ui.displayUI('sprite_editor')
   if not window then
      displayErrorBox(tr('Assets Editor'), tr('Could not create the editor window. Check the client log for UI errors.'))
      return false
   end

   local rightPanel = window:recursiveGetChildById('rightPanel')
   if not rightPanel then
      window:destroy()
      window = nil
      displayErrorBox(tr('Assets Editor'), tr('The editor side panel could not be initialized.'))
      return false
   end
   for _, panelName in ipairs({ 'sprite_editor_properties', 'sprite_editor_import', 'sprite_editor_export',
         'sprite_editor_history' }) do
      local loaded, panel = pcall(g_ui.loadUI, panelName, rightPanel)
      if not loaded or not panel then
         g_logger.error('[game_sprite_editor] Unable to load panel ' .. panelName .. ': ' .. tostring(panel))
         window:destroy()
         window = nil
         displayErrorBox(tr('Assets Editor'), tr('Could not load the editor side panel. Check the client log.'))
         return false
      end
   end

   canvas = window:recursiveGetChildById('canvas')
   if not canvas then
      window:destroy()
      window = nil
      displayErrorBox(tr('Assets Editor'), tr('The editor canvas could not be initialized.'))
      return false
   end
   canvas.onStateChange = function()
      if canvas and window then
         updatePreviewTitle()
         updateDirectionPadLayout()
         updatePreviewZoomControl()
      end
   end
   canvas.onPositionChange = function()
      if canvas and window then
         updateDirectionPadLayout()
         updatePreviewZoomControl()
      end
   end
   local zoomScroll = window:recursiveGetChildById('previewZoomScroll')
   zoomScroll:setMinimum(1)
   zoomScroll:setMaximum(MAX_PREVIEW_ZOOM)
   zoomScroll:setStep(1)
   zoomScroll.onValueChange = function(_, value)
      setPreviewZoom(MAX_PREVIEW_ZOOM + 1 - math.floor(value + 0.5))
   end
   canvas.onDrop = function(_, draggedWidget)
      if not draggedWidget or currentPage ~= 'import' or currentImportSection ~= 'replace' then
         return false
      end

      if draggedWidget.isPngFilePickerCell then
         local path = draggedWidget.filePickerPath
         if not path or currentReplaceMode ~= 'png' or not activeVersion or g_game.isOnline() or
               not selectedSpriteId or not getSelectedSpriteReference() then
            return false
         end

         preparedSpritePath = path
         setSpritePath(path)
         closePngFilePicker()
         canvas:setBorderWidth(0)
         canvas:setBorderColor('alpha')
         importPngAndReplace()
         return true
      end

      if not draggedWidget.isSpritePickerCell or currentReplaceMode ~= 'sprite' then
         return false
      end
      local spriteId = tonumber(draggedWidget.spriteId)
      if not spriteId or not activeVersion or g_game.isOnline() or not selectedSpriteId then
         return false
      end

      selectSpritePickerSprite(spriteId)
      replaceSelectedFrameWithSprite(spriteId)
      return true
   end

   local spritePathEdit = window:recursiveGetChildById('previewSpritePathEdit')
   spritePathEdit.onTextChange = function(widget)
      if not settingSpritePath and
            (not pendingSpriteEdit or widget:getText() ~= pendingSpriteEdit.path) then
         preparedSpritePath = widget:getText()
      end
      window:recursiveGetChildById('importPngReplaceButton'):setEnabled(
         activeVersion ~= nil and not g_game.isOnline() and selectedSpriteId ~= nil and widget:getText() ~= '')
   end
   setSpritePath(preparedSpritePath)

   local categoryBox = window:recursiveGetChildById('appearanceCategory')
   updateCategoryOptions()
   categoryBox:setCurrentOptionByData(selectedAppearanceCategory, true)
   categoryBox.onOptionChange = function(_, _, category)
      changeAppearanceCategory(category)
   end
   local newAppearanceCategoryBox = window:recursiveGetChildById('newAppearanceCategory')
   for _, category in ipairs(categories) do
      newAppearanceCategoryBox:addOption(tr(category.name), category.data)
   end
   newAppearanceCategoryBox:setCurrentOptionByData(selectedAppearanceCategory, true)
   if restoreEditorState then
      window:recursiveGetChildById('appearanceSearch'):setText(savedEditorUiState.appearanceSearch or '')
      window:recursiveGetChildById('spriteSearchEdit'):setText(savedEditorUiState.replaceSpriteSearch or '')
      window:recursiveGetChildById('newAppearanceSpriteSearchEdit'):setText(savedEditorUiState.createSpriteSearch or '')
   end
   getAppearanceCatalogComponent():attach_window()
   getSpritePickerComponent():attach_window()
   window:recursiveGetChildById('newAppearancePngPathEdit').onTextChange = function(widget)
      window:recursiveGetChildById('createAppearanceButton'):setEnabled(
         activeVersion ~= nil and not g_game.isOnline() and currentNewAppearanceSourceMode == 'png' and
         widget:getText() ~= '')
   end
   window:recursiveGetChildById('batchPngFolderEdit').onTextChange = function()
      updateSpriteReplacementTarget()
   end
   local spriteSheetPathEdit = window:recursiveGetChildById('spriteSheetPathEdit')
   spriteSheetPathEdit.onTextChange = function()
      updateSpriteReplacementTarget()
   end
   for _, id in ipairs({ 'spriteSheetCellWidth', 'spriteSheetCellHeight' }) do
      local sizeBox = window:recursiveGetChildById(id)
      for _, size in ipairs({ 32, 64, 96, 128, 192, 384 }) do
         sizeBox:addOption(tostring(size), size)
      end
      sizeBox:setCurrentOptionByData(64, true)
   end
   window:recursiveGetChildById('spriteSheetFirstCell'):setText('1')
   window:recursiveGetChildById('spriteSheetLastCell'):setText('0')

   local versionBox = window:recursiveGetChildById('versionComboBox')
   local versions = getSelectableAssetVersions()
   for _, version in ipairs(versions) do
      versionBox:addOption(formatClientVersion(version), version)
   end
   local selectedVersion = activeVersion or savedEditorUiState.version or versions[1]
   if selectedVersion then
      versionBox:setCurrentOptionByData(selectedVersion, true)
   end
   versionBox.onOptionChange = function()
      updateExportControls()
      if persistEditorUiState then
         persistEditorUiState()
      end
   end
   refreshInstalledAssetBackups()
   updateInstalledAssetBackupOptions()
   local newVersionEdit = window:recursiveGetChildById('newVersionEdit')
   local suggestedVersion = activeVersion and getNextAvailableVersion(activeVersion)
   if suggestedVersion then
      newVersionEdit:setText(formatClientVersion(suggestedVersion))
   end
   newVersionEdit.onTextChange = function()
      updateExportControls()
   end
   local exportFolderEdit = window:recursiveGetChildById('exportFolderEdit')
   exportFolderEdit.onTextChange = function()
      updateExportControls()
   end

   setActivePage(currentPage)
   setPropertiesTab(currentPropertiesTab)
   setImportSection(currentImportSection)
   window:show()
   window:raise()
   window:focus()
   if topMenuButton then topMenuButton:setOn(true) end
   if activeVersion then
      refreshAppearanceCatalog(selectedAppearanceCategory)
      refreshSpritePicker()
      refreshAssetEditHistory()
      if restoreEditorState then
         selectedReplacementSpriteId = savedEditorUiState.replacementSpriteId > 0 and
            savedEditorUiState.replacementSpriteId or nil
         selectedCreateSpriteId = savedEditorUiState.createSpriteId > 0 and
            savedEditorUiState.createSpriteId or nil
         local spriteList = getSpritePickerWidget('list')
         if spriteList then
            local savedOffset = currentImportSection == 'create' and
               savedEditorUiState.createSpriteListOffset or savedEditorUiState.replaceSpriteListOffset
            spriteList:setVirtualOffset({ x = 0, y = savedOffset or 0 })
            spriteList:updateScrollBars()
            renderSpritePickerRows(spriteList:getVirtualOffset().y)
         end
      end
      local restoredAppearanceId = restoreEditorState and tonumber(savedEditorUiState.appearanceId) or nil
      if restoredAppearanceId and restoredAppearanceId < 1 then
         restoredAppearanceId = nil
      end
      local restoredThing = restoredAppearanceId and
         g_things.getThingType(restoredAppearanceId, selectedAppearanceCategory)
      if restoredThing and restoredThing:getId() == restoredAppearanceId then
         loadAppearanceRecord(selectedAppearanceCategory, restoredAppearanceId, true)
      else
         local firstEntry = getFilteredAppearanceEntry(1)
         if firstEntry then
            loadAppearanceRecord(selectedAppearanceCategory, firstEntry.id, true)
         end
      end
      if restoreEditorState then
         local appearanceList = window:recursiveGetChildById('appearanceList')
         appearanceList:setVirtualOffset({ x = 0, y = savedEditorUiState.appearanceListOffset or 0 })
         appearanceList:updateScrollBars()
         renderAppearanceRows(appearanceList:getVirtualOffset().y)
         if restoredThing and restoredThing:getId() == restoredAppearanceId then
            restorePreviewSelection(savedEditorUiState.previewSelection)
         end
      end
   else
      clearAppearanceProperties()
   end
   return true
end

local function destroyWindow()
   stopPreviewAnimation()
   timelineScrubbing = false
   destroyPngFilePicker()
   if spritePicker then
      spritePicker:destroy()
   end
   if appearanceProperties then
      appearanceProperties:destroy()
   end
   animationWidgets = {}
   if window then
      window:destroy()
      window = nil
      canvas = nil
   end
   if appearanceCatalog then
      appearanceCatalog:destroy()
   end
   spritePickerSourceId = nil
   selectedReplacementSpriteId = nil
   selectedCreateSpriteId = nil
   selectedAppearanceId = nil
   selectedSpriteId = nil
   appearanceOriginal = nil
   clearAppearanceChanges()
   if g_spriteAppearances.releaseDecodedSpriteSheets then
      g_spriteAppearances.releaseDecodedSpriteSheets()
   end
end

local function loadAssets(version)
   if g_game.isOnline() then
      displayErrorBox(tr('Assets Editor'), tr('Disconnect before opening the offline assets editor.'))
      return false
   end
   local loaded, workRoot, assetPath = getWorkCopyService():load(version)
   if not loaded then
      displayErrorBox(tr('Assets Editor'), getUserFacingError(workRoot))
      return false
   end

   activeVersion = version
   canaryAppearanceWarningShown = false
   activeAssetPath = assetPath
   activeWorkRoot = workRoot
   refreshInstalledAssetBackups()
   if appearanceCatalog then
      appearanceCatalog:clear_category_counts()
   end
   selectedAppearanceCategory = 0
   return true
end

function init()
   if not g_spriteAppearances.createWorkCopy then
      return
   end
   restoreEditorUiStateFromSettings()
   g_ui.importStyle('sprite_editor_widgets')
   gameStartCallback = function()
      if persistEditorUiState then
         persistEditorUiState(true)
      end
      if topMenuButton then
         topMenuButton:setOn(false)
         topMenuButton:setVisible(false)
      end
      if window then
         stopPreviewAnimation()
         window:hide()
      end
   end
   gameEndCallback = function()
      if topMenuButton then
         topMenuButton:setVisible(true)
         topMenuButton:setOn(false)
      end
   end
   topMenuButton = modules.client_topmenu.addTopRightToggleButton(
      'offlineAssetsEditorButton', tr('Offline Assets Editor'), '/images/topbuttons/assets_editor', toggle, true)
   topMenuButton:setVisible(not g_game.isOnline())
   topMenuButton:setOn(false)
   connect(g_game, { onGameStart = gameStartCallback, onGameEnd = gameEndCallback })
end

function terminate()
   disconnect(g_game, { onGameStart = gameStartCallback, onGameEnd = gameEndCallback })
   if persistEditorUiState then
      persistEditorUiState(true)
   end
   if activeVersion then
      local released, err = releaseActiveWorkCopy()
      if not released then
         g_logger.error('[game_sprite_editor] Unable to restore installed assets during shutdown: ' .. tostring(err))
      end
   end
   destroyWindow()
   if topMenuButton then
      topMenuButton:destroy()
      topMenuButton = nil
   end
   activeVersion = nil
   canaryAppearanceWarningShown = false
   activeAssetPath = nil
   activeWorkRoot = nil
   if editorUiStateSaveEvent then
      removeEvent(editorUiStateSaveEvent)
      editorUiStateSaveEvent = nil
   end
   restoringEditorUiState = false
   gameStartCallback = nil
   gameEndCallback = nil
end

function toggle()
   if g_game.isOnline() then
      if topMenuButton then topMenuButton:setOn(false) end
      displayErrorBox(tr('Assets Editor'), tr('Disconnect before opening the offline assets editor.'))
      return
   end
   if window then
      if window:isVisible() then
         requestClose()
      else
         window:show()
         window:raise()
         window:focus()
         if topMenuButton then topMenuButton:setOn(true) end
      end
   elseif activeVersion then
      createWindow()
   else
      local versions = getVersions()
      local version
      for _, installedVersion in ipairs(versions) do
         if installedVersion == savedEditorUiState.version then
            version = installedVersion
            break
         end
      end
      version = version or versions[1]
      if version then
         openWorkCopyVersion(version, true)
      else
         if not createWindow(true) then
            return
         end
         local versionBox = window:recursiveGetChildById('versionComboBox')
         local selectedVersion = selectedOption(versionBox)
         if not selectedVersion then
            setStatus(tr('No supported 15.x client versions are available in this build.'))
            return
         end

         setStatus(tr('No 15.x assets are installed. Downloading client %s is required to use the editor.',
            formatClientVersion(selectedVersion)))
         requestClientAssets(selectedVersion, function(success, message)
            if not success then
               if window then
                  setStatus(message or tr('No assets were installed. Use Download and load to retry.'))
               end
               return
            end
            if window and window:isVisible() and not g_game.isOnline() then
               openWorkCopyVersion(selectedVersion, true)
            end
         end)
      end
   end
end

function loadSelectedAssets()
   if not window or g_game.isOnline() then
      return
   end
   local version = selectedOption(window:recursiveGetChildById('versionComboBox'))
   if not version then
      displayErrorBox(tr('Assets Editor'), tr('No installed client version 15.x assets were found.'))
      return
   end

   requestClientAssets(version, function(success, message)
      if not window or g_game.isOnline() then
         return
      end
      if not success then
         setStatus(message or tr('Unable to download client assets.'))
         return
      end

      local ok, hasWorkCopy = getWorkCopyService():exists(version)
      if not ok then
         displayErrorBox(tr('Assets Editor'), getUserFacingError(hasWorkCopy))
         return
      end
      if not hasWorkCopy then
         if hasAppearanceChanges() then
            confirmUnsavedChanges(tr('Save changes before loading another assets version?'), function()
               openWorkCopyVersion(version)
            end)
            return
         end
         openWorkCopyVersion(version)
         return
      end

      local messageBox
      local function cancelReset()
         messageBox:cancel()
      end
      local function resetAndLoad()
         messageBox:ok()
         local resetOk, result, remountFailed = getWorkCopyService():reset(version, activeWorkRoot)
         if not resetOk then
            local resetMessage = getUserFacingError(result)
            if remountFailed then
               resetMessage = tr('%s The working copy could not be remounted.', resetMessage)
            end
            displayErrorBox(tr('Assets Editor'), resetMessage)
            return
         end
         openWorkCopyVersion(version)
      end
      messageBox = displayGeneralBox(tr('Reload assets from the installed version?'),
         tr('This replaces the selected working copy with the installed assets and discards its saved edits and any unsaved editor changes.'), {
            { text = tr('Reload assets'), callback = resetAndLoad },
            { text = tr('Cancel'), callback = cancelReset },
         }, cancelReset, cancelReset)
   end)
end

function restoreInstalledBackup(forceDiscard, confirmed)
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before restoring an installed backup?'), function()
         restoreInstalledBackup(true, false)
      end)
      return
   end
   if not activeVersion or g_game.isOnline() then
      setStatus(tr('Open an offline assets version before restoring a backup.'))
      return
   end
   if pendingSpriteEdit then
      setStatus(tr('Apply or discard the pending sprite edit before restoring a backup.'))
      return
   end

   local backupName = selectedInstalledBackupName
   if not backupName then
      setStatus(tr('No installed backup is selected.'))
      return
   end
   if not confirmed then
      local messageBox
      local function cancelRestore()
         messageBox:cancel()
      end
      local function confirmRestore()
         messageBox:ok()
         restoreInstalledBackup(true, true)
      end
      messageBox = displayGeneralBox(tr('Restore installed backup?'),
         tr('Restore %s to data/things/%d? This replaces the current installed package without creating another backup. The working copy will reset to the restored version and discard its saved edits.',
            getInstalledAssetBackup(backupName) and getInstalledAssetBackup(backupName).label or backupName,
            activeVersion), {
            { text = tr('Restore backup'), callback = confirmRestore },
            { text = tr('Cancel'), callback = cancelRestore },
         }, cancelRestore, cancelRestore)
      return
   end

   local version = activeVersion
   local released, releaseError = releaseActiveWorkCopy()
   if not released then
      displayErrorBox(tr('Assets Editor'), releaseError)
      return
   end

   local restored, restoreError = pcall(g_spriteAppearances.restoreInstalledAssetBackup, version, backupName)
   if not restored then
      openWorkCopyVersion(version)
      setStatus(getUserFacingError(restoreError))
      return
   end

   local reset, resetError = pcall(g_spriteAppearances.resetWorkCopy, version)
   if not reset then
      openWorkCopyVersion(version)
      displayErrorBox(tr('Assets Editor'), tr('The installed backup was restored, but the working copy could not be reset. Use Load assets to retry. Details: %s',
         getUserFacingError(resetError)))
      return
   end

   if openWorkCopyVersion(version) then
      setStatus(tr('Installed assets restored from the selected backup. No new backup was created.'), true)
   end
end

function openWorkCopyVersion(version, restoreEditorState)
   if not isSupportedAssetVersion(version) then
      displayErrorBox(tr('Assets Editor'), tr('This OTClient build does not support client version %s.',
         formatClientVersion(version or 0)))
      return false
   end
   if activeVersion then
      local released, err = releaseActiveWorkCopy()
      if not released then
         displayErrorBox(tr('Assets Editor'), err)
         return false
      end
   end
   destroyWindow()
   if not loadAssets(version) then
      restoringEditorUiState = false
      createWindow()
      return false
   end
   if restoreEditorState then
      currentPage = savedEditorUiState.page or 'editor'
      currentPropertiesTab = savedEditorUiState.propertiesTab or 'flags'
      currentImportSection = savedEditorUiState.importSection or 'replace'
      currentReplaceMode = savedEditorUiState.replaceMode or 'sprite'
      currentNewAppearanceSourceMode = savedEditorUiState.newAppearanceSourceMode or 'sprite'
      currentExportSubpage = savedEditorUiState.exportSubpage or 'assets'
      currentExportMode = savedEditorUiState.exportMode or 'replace'
      selectedAppearanceCategory = savedEditorUiState.category or 0
      selectedReplacementSpriteId = savedEditorUiState.replacementSpriteId > 0 and
         savedEditorUiState.replacementSpriteId or nil
      selectedCreateSpriteId = savedEditorUiState.createSpriteId > 0 and savedEditorUiState.createSpriteId or nil
   else
      currentPage = 'editor'
   end
   restoringEditorUiState = restoreEditorState == true
   local created = createWindow(restoreEditorState == true)
   restoringEditorUiState = false
   if not created then
      return false
   end
   window:recursiveGetChildById('versionComboBox'):setCurrentOptionByData(version, true)
   setStatus(tr('Working copy ready for client %s.', formatClientVersion(version)))
   if persistEditorUiState then
      persistEditorUiState(true)
   end
   return true
end

function applyAppearanceSearch()
   applyAppearanceFilter()
end

function showEditorPage()
   setActivePage('editor')
end

function setImportSection(section)
   if section ~= 'replace' and section ~= 'create' and section ~= 'batch' and section ~= 'sheet' and section ~= 'bundle' then
      return
   end
   local search = getSpritePickerWidget('search')
   local query = search and search:getText() or ''
   if section ~= currentImportSection and section == 'create' then
      selectedCreateSpriteId = nil
   end
   currentImportSection = section
   if window then
      if section == 'replace' or section == 'create' then
         local pickerSearch = getSpritePickerWidget('search')
         if pickerSearch then
            pickerSearch:setText(query)
         end
      end
      window:recursiveGetChildById('replaceFramePanel'):setVisible(section == 'replace')
      window:recursiveGetChildById('newAppearancePanel'):setVisible(section == 'create')
      window:recursiveGetChildById('batchPngsPanel'):setVisible(section == 'batch')
      window:recursiveGetChildById('spriteSheetPanel'):setVisible(section == 'sheet')
      window:recursiveGetChildById('appearanceBundlePanel'):setVisible(section == 'bundle')
      window:recursiveGetChildById('replaceFrameTabButton'):setOn(section == 'replace')
      window:recursiveGetChildById('newAppearanceTabButton'):setOn(section == 'create')
      window:recursiveGetChildById('batchPngsTabButton'):setOn(section == 'batch')
      window:recursiveGetChildById('spriteSheetTabButton'):setOn(section == 'sheet')
      window:recursiveGetChildById('appearanceBundleTabButton'):setOn(section == 'bundle')
      if section == 'replace' or section == 'create' then
         applySpritePickerFilter()
      end
   end
   updateSpriteReplacementTarget()
   if persistEditorUiState then
      persistEditorUiState()
   end
end

function importAppearanceBundle(forceDiscard)
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before importing an appearance bundle?'), function()
         importAppearanceBundle(true)
      end)
      return
   end
   if not activeVersion or g_game.isOnline() then
      setStatus(tr('Open an offline 15.x work copy before importing an appearance bundle.'))
      return
   end

   local bundleDirectory = window:recursiveGetChildById('appearanceBundlePathEdit'):getText():trim()
   if bundleDirectory == '' then
      setStatus(tr('Choose an appearance bundle folder.'))
      return
   end

   local imported, response = runWorkCopyEdit(tr('Import appearance bundles'), function()
      return g_things.importAppearanceBundlesFromDirectory(activeVersion, bundleDirectory)
   end, {
      action = 'appearance-import',
      captureBeforeAppearance = false,
      summary = tr('Imported appearance bundle(s)'),
      resolveAppearanceId = function(encoded)
         local ok, result = pcall(json.decode, encoded)
         return ok and result.items and result.items[1] and result.items[1].id
      end,
   })
   if not imported then
      setStatus(getUserFacingError(response))
      return
   end
   local decoded, result = pcall(json.decode, response)
   if not decoded or type(result) ~= 'table' or type(result.items) ~= 'table' or
         type(result.failures) ~= 'table' then
      setStatus(tr('The appearance bundle import returned an invalid result. Check the client log.'))
      return
   end
   local firstItem = result.items[1]
   if not firstItem then
      local failure = result.failures[1]
      setStatus(failure and tr('No bundles were imported. %s: %s', failure.bundle, failure.error) or
         tr('No appearance bundles were imported.'))
      return
   end
   if not reloadAssets() then
      setStatus(tr('%d bundle(s) were imported, but the work copy could not be reloaded.', result.imported))
      return
   end

   refreshAppearanceCatalog(firstItem.category)
   if loadAppearanceRecord(firstItem.category, firstItem.id, true, true) then
      setActivePage('editor')
      if tonumber(result.failed) > 0 then
         local failure = result.failures[1]
         setStatus(tr('Imported %d bundle(s); %d failed. First failure: %s: %s', result.imported,
            result.failed, failure.bundle, failure.error))
      else
         setStatus(tr('Imported %d appearance bundle(s). Selected appearance %d has %d remapped sprites.',
            result.imported, firstItem.id, tonumber(firstItem.sprites) or 0))
      end
   end
end

function setReplaceMode(mode)
   if mode ~= 'sprite' and mode ~= 'png' then
      return
   end
   currentReplaceMode = mode
   updateSpriteReplacementTarget()
   if persistEditorUiState then
      persistEditorUiState()
   end
end

function setNewAppearanceSourceMode(mode)
   if mode ~= 'sprite' and mode ~= 'png' then
      return
   end
   currentNewAppearanceSourceMode = mode
   updateSpriteReplacementTarget()
   if persistEditorUiState then
      persistEditorUiState()
   end
end

function duplicateSelectedAppearance(forceDiscard)
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before duplicating this appearance?'), function()
         duplicateSelectedAppearance(true)
      end)
      return
   end
   if not activeVersion or g_game.isOnline() or not selectedAppearanceId then
      setStatus(tr('Select an appearance in an offline 15.x work copy first.'))
      return
   end

   local sourceId = selectedAppearanceId
   local category = selectedAppearanceCategory
   local ok, duplicateId = runWorkCopyEdit(tr('Duplicate appearance'), function()
      return g_things.duplicateAppearance(activeVersion, category, sourceId)
   end, {
      category = category,
      captureBeforeAppearance = false,
      resultIsAppearanceId = true,
      action = 'duplicate',
      summary = tr('Duplicated from appearance %d', sourceId),
   })
   if not ok then
      setStatus(getUserFacingError(duplicateId))
      return
   end
   if not reloadAssets() then
      setStatus(tr('Appearance %d was duplicated, but the work copy could not be reloaded.', duplicateId))
      return
   end

   local searchEdit = window:recursiveGetChildById('appearanceSearch')
   if searchEdit:getText() ~= '' then
      searchEdit:setText('')
   end
   refreshAppearanceCatalog(category)
   if loadAppearanceRecord(category, duplicateId, true, true) then
      setActivePage('editor')
      local list = window:recursiveGetChildById('appearanceList')
      local targetOffset = getAppearanceCatalogComponent():get_bottom_offset()
      list:setVirtualOffset({ x = 0, y = targetOffset })
      renderAppearanceRows(list:getVirtualOffset().y)
      list:updateScrollBars()
      setStatus(tr('Duplicated %d as %d. Sprite IDs remain shared.', sourceId, duplicateId))
   end
end

function deleteSelectedAppearance(forceDiscard)
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before deleting this appearance?'), function()
         deleteSelectedAppearance(true)
      end)
      return
   end
   if not activeVersion or g_game.isOnline() or not selectedAppearanceId then
      setStatus(tr('Select an appearance in an offline 15.x work copy first.'))
      return
   end
   if pendingSpriteEdit then
      setStatus(tr('Apply or discard the pending sprite edit before deleting an appearance.'))
      return
   end

   local appearanceId = selectedAppearanceId
   local category = selectedAppearanceCategory
   local messageBox
   local function cancelDeletion()
      messageBox:cancel()
   end
   local function confirmDeletion()
      messageBox:ok()
      local ok, deleted = runWorkCopyEdit(tr('Delete appearance'), function()
         return g_things.deleteAppearance(activeVersion, category, appearanceId)
      end, {
         category = category,
         appearanceId = appearanceId,
         action = 'delete',
         summary = tr('Deleted appearance %d', appearanceId),
      })
      if not ok then
         setStatus(getUserFacingError(deleted))
         return
      end
      if not deleted then
         setStatus(tr('Appearance %d could not be deleted.', appearanceId))
         return
      end
      if not reloadAssets() then
         selectedAppearanceId = nil
         appearanceOriginal = nil
         clearAppearanceProperties()
         updateExportControls()
         refreshAppearanceCatalog(category)
         setStatus(tr('Appearance %d was deleted, but the work copy could not be reloaded.', appearanceId))
         return
      end

      local searchEdit = window:recursiveGetChildById('appearanceSearch')
      if searchEdit:getText() ~= '' then
         searchEdit:setText('')
      end
      selectedAppearanceId = nil
      appearanceOriginal = nil
      refreshAppearanceCatalog(category)
      updateExportControls()
      local nextEntry = getFilteredAppearanceEntry(1)
      if nextEntry then
         loadAppearanceRecord(category, nextEntry.id, true, true)
      else
         clearAppearanceProperties()
      end
      setStatus(tr('Appearance %d was removed from the working copy. Its sprites were kept.', appearanceId))
   end
   messageBox = displayGeneralBox(tr('Delete appearance'),
      tr('Remove appearance %d from this working copy? Sprite data will be kept. To restore the appearance, reload assets from the installed version.', appearanceId), {
         { text = tr('Delete'), callback = confirmDeletion },
         { text = tr('Cancel'), callback = cancelDeletion },
      }, cancelDeletion, cancelDeletion)
end

function importPngAndReplace(forceDiscard)
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before importing a PNG for this frame?'), function()
         importPngAndReplace(true)
      end)
      return
   end
   importPngAsNewSprite()
end

function showImportPage()
   setActivePage('import')
   setImportSection(currentImportSection)
   if refreshSpritePicker then refreshSpritePicker() end
end

function openNewAppearance()
   if not activeVersion or g_game.isOnline() then
      setStatus(tr('Load an offline 15.x work copy before creating an appearance.'))
      return
   end

   showImportPage()
   setImportSection('create')
   window:recursiveGetChildById('newAppearanceCategory'):setCurrentOptionByData(selectedAppearanceCategory, true)
end

function selectPreviewDirection(directionIndex)
   local group = currentPreviewGroup()
   if not group or selectedAppearanceCategory ~= 1 or directionIndex < 0 or directionIndex >= group.patternWidth then
      return
   end
   previewPatternX = directionIndex
   updatePreviewPatternControls()
   refreshAppearancePreview()
end

function showExportPage()
   setActivePage('export')
end

function showHistoryPage()
   refreshAssetEditHistory()
   setActivePage('history')
end

function restoreAssetHistoryEntry(forceDiscard, confirmed)
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before restoring asset history?'), function()
         restoreAssetHistoryEntry(true, false)
      end)
      return
   end
   local entry = selectedAssetEditHistoryEntry
   local appearanceId = entry and tonumber(entry.appearanceId)
   local spriteId = entry and tonumber(entry.spriteId)
   if not activeVersion or g_game.isOnline() or not entry or not appearanceId then
      setStatus(tr('Select a recoverable history entry in an offline work copy.'))
      return
   end
   if entry.beforeAppearancePresent ~= true and entry.beforeAppearancePresent ~= false and
         (not spriteId or spriteId < 1 or entry.beforeSpritePng == '') then
      setStatus(tr('This history entry does not contain a recoverable previous state.'))
      return
   end
   if pendingSpriteEdit then
      setStatus(tr('Apply or discard the pending sprite edit before restoring asset history.'))
      return
   end
   if not confirmed then
      local spriteWarning = spriteId and spriteId > 0 and entry.beforeSpritePng ~= '' and
         tr(' The sprite is shared, so all appearances using it will change.') or ''
      local dialog
      dialog = displayGeneralBox(tr('Restore previous asset state?'),
         tr('Restore the state before %s for %s %d? The current state remains available in the history as a new edit.%s',
            tostring(entry.label or tr('this edit')), tr(entry.categoryName or 'Appearance'), appearanceId, spriteWarning), {
            { text = tr('Restore previous state'), callback = function()
               dialog:ok()
               restoreAssetHistoryEntry(true, true)
            end },
            { text = tr('Cancel'), callback = function() dialog:cancel() end },
         })
      return
   end

   local category = tonumber(entry.category)
   if category == nil then
      setStatus(tr('This history entry does not include an appearance category.'))
      return
   end
   local restored, err = runWorkCopyEdit(tr('Restore previous asset state'), function()
      if spriteId and spriteId > 0 and entry.beforeSpritePng ~= '' then
         g_spriteAppearances.restoreSpriteImageFromPngBase64(activeVersion, spriteId, entry.beforeSpritePng)
      end
      if entry.beforeAppearancePresent == true or entry.beforeAppearancePresent == false then
         g_things.restoreAppearanceEditorSnapshot(activeVersion, category, appearanceId,
            entry.beforeAppearancePresent, entry.beforeAppearanceSnapshot or '')
      end
      return true
   end, {
      category = category,
      appearanceId = appearanceId,
      beforeAppearanceId = appearanceId,
      spriteId = spriteId and spriteId > 0 and spriteId or nil,
      captureSpritePixels = spriteId and spriteId > 0 and entry.beforeSpritePng ~= '',
      action = 'restore',
      summary = tr('Restored the state before %s', tostring(entry.label or tr('this edit'))),
   })
   if not restored then
      setStatus(getUserFacingError(err))
      return
   end
   if not reloadAssets() then
      setStatus(tr('The previous state was written, but the work copy could not be reloaded.'))
      return
   end
   refreshAppearanceCatalog(category)
   if entry.beforeAppearancePresent then
      loadAppearanceRecord(category, appearanceId, true, true)
   elseif selectedAppearanceCategory == category and selectedAppearanceId == appearanceId then
      selectedAppearanceId = nil
      clearAppearanceProperties()
   end
   refreshAssetEditHistory()
   setActivePage('history')
   setStatus(tr('Restored the previous state of %s %d. The restore is recorded in asset history.',
      tr(entry.categoryName or 'Appearance'), appearanceId))
end

function restoreInstalledBackupChange()
   local entry = selectedInstalledBackupChange
   if not entry then
      setStatus(tr('Select a recorded change after this backup first.'))
      return
   end

   selectedAssetEditHistoryEntry = entry
   setActivePage('history')
   local list = window:recursiveGetChildById('assetEditHistoryList')
   for _, row in ipairs(list:getChildren()) do
      row:setOn(row.historyEntryId == entry.id)
   end
   updateAssetEditHistoryDetails()
   restoreAssetHistoryEntry()
end

function showPropertiesTab(tab)
   setPropertiesTab(tab)
end

function zoomIn()
   if canvas then canvas:zoomIn() end
end

function zoomOut()
   if canvas then canvas:zoomOut() end
end

getSelectedSpriteReference = function()
   local group = currentPreviewGroup()
   if not group or not selectedAppearanceId or not selectedSpriteId then
      setStatus(tr('Select a linked sprite frame before replacing it.'))
      return nil
   end

   local spriteIndex = (((previewPhase * group.patternDepth + previewPatternZ) * group.patternHeight +
      previewPatternY) * group.patternWidth + previewPatternX) * group.layers + previewLayer + 1
   if group.sprites[spriteIndex] ~= selectedSpriteId then
      setStatus(tr('The selected sprite frame is no longer current. Select it again and retry.'))
      return nil
   end

   return previewFrameGroupIndex - 1, spriteIndex - 1
end

local function refreshAfterSpriteReferenceChange(category, appearanceId, previewSelection, returnToImport)
   if not reloadAssets() then
      setStatus(tr('The sprite link was saved, but the work copy could not be reloaded.'))
      return false
   end
   refreshAppearanceCatalog(category)
   if not loadAppearanceRecord(category, appearanceId, true, true) then
      setStatus(tr('The sprite link was saved, but the appearance preview could not be reloaded.'))
      return false
   end
   restorePreviewSelection(previewSelection)
   setActivePage(returnToImport and 'import' or 'editor')
   return true
end

linkSpriteToSelectedFrame = function(spriteId)
   local category = selectedAppearanceCategory
   local appearanceId = selectedAppearanceId
   local frameGroupIndex, spriteIndex = getSelectedSpriteReference()
   if not frameGroupIndex then
      return false
   end

   local previewSelection = capturePreviewSelection()
   local ok, result = runWorkCopyEdit(tr('Replace frame sprite'), function()
      return g_things.replaceAppearanceSprite(activeVersion, category,
         appearanceId, frameGroupIndex, spriteIndex, spriteId)
   end, {
      category = category,
      appearanceId = appearanceId,
      action = 'sprite-link',
      spriteId = spriteId,
      summary = tr('Linked frame to sprite %d', spriteId),
   })
   if not ok then
      setStatus(getUserFacingError(result))
      return false
   end
   if not refreshAfterSpriteReferenceChange(category, appearanceId, previewSelection, true) then
      return false
   end

   setStatus(tr('Frame linked to sprite %d; other appearances are unchanged.', spriteId))
   return true
end

replaceSelectedFrameWithSprite = function(spriteId, forceDiscard)
   if not activeVersion or g_game.isOnline() then
      setStatus(tr('Open a 15.x work copy before replacing a sprite.'))
      return false
   end
   if currentPage ~= 'import' or currentImportSection ~= 'replace' or currentReplaceMode ~= 'sprite' then
      return false
   end
   if not getSelectedSpriteReference() then
      return false
   end
   if spriteId == selectedSpriteId then
      setStatus(tr('This frame already uses sprite %d.', spriteId))
      return false
   end

   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before replacing this frame sprite?'), function()
         replaceSelectedFrameWithSprite(spriteId, true)
      end)
      return false
   end

   return linkSpriteToSelectedFrame(spriteId)
end

importPngAsNewSprite = function()
   if not activeVersion or g_game.isOnline() then
      setStatus(tr('Open a 15.x work copy before importing a sprite.'))
      return
   end
   local path = window:recursiveGetChildById('previewSpritePathEdit'):getText()
   if path == '' then
      setStatus(tr('Enter the absolute PNG path in the Import PNG section.'))
      window:recursiveGetChildById('previewSpritePathEdit'):focus()
      return
   end
   local category = selectedAppearanceCategory
   local appearanceId = selectedAppearanceId
   local frameGroupIndex, spriteIndex = getSelectedSpriteReference()
   if not frameGroupIndex then
      return
   end
   local previewSelection = capturePreviewSelection()
   local imported, spriteId = runWorkCopyEdit(tr('Import and replace frame sprite'), function()
      local newSpriteId = g_spriteAppearances.importSpriteForAppearance(selectedSpriteId, path, activeVersion)
      assert(reloadAssets(), tr('The imported sprite was saved, but the work copy could not be reloaded.'))
      assert(g_things.replaceAppearanceSprite(activeVersion, category,
         appearanceId, frameGroupIndex, spriteIndex, newSpriteId))
      return newSpriteId
   end, {
      category = category,
      appearanceId = appearanceId,
      resultIsSpriteId = true,
      action = 'sprite-import-and-link',
      summary = tr('Imported a PNG and linked it to the selected frame'),
   })
   if not imported then
      setStatus(getUserFacingError(spriteId))
      return
   end
   if not refreshAfterSpriteReferenceChange(category, appearanceId, previewSelection) then
      return
   end
   setStatus(tr('PNG imported as sprite %d and linked to this frame.', spriteId), true)
end

function replaceSprite(forceDiscard)
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before replacing this frame sprite?'), function()
         replaceSprite(true)
      end)
      return
   end
   if not activeVersion or g_game.isOnline() then
      setStatus(tr('Open a 15.x work copy before replacing a sprite.'))
      return
   end
   if not getSelectedSpriteReference() then
      return
   end

   setActivePage('import')
   setImportSection('replace')
   setReplaceMode(currentReplaceMode)
end

local function saveExternalEditorPath(path)
   local editorPath = path:gsub('^%s+', ''):gsub('%s+$', '')
   if editorPath == '' or not g_platform.fileExists(editorPath) then
      setStatus(tr('Choose an existing editor executable or launcher path.'))
      return false
   end

   g_settings.setValue(EXTERNAL_EDITOR_SETTING, editorPath)
   if not g_settings.save() then
      setStatus(tr('The editor path was set for this session but could not be saved.'))
   else
      setStatus(tr('External editor saved: %s', editorPath))
   end
   return true
end

function configureSpriteEditor(onConfigured)
   if not g_platform.isDesktop() then
      setStatus(tr('External sprite editors are available in desktop builds.'))
      return
   end
   displayInputBox(tr('External sprite editor'),
      tr('Enter the absolute path to an editor executable or launcher. The PNG path will be passed to it.'),
      function(path)
         if saveExternalEditorPath(path) and onConfigured then
            onConfigured(path:gsub('^%s+', ''):gsub('%s+$', ''))
         end
      end, nil, g_settings.getValue(EXTERNAL_EDITOR_SETTING), 1024)
end

local function launchSpriteInEditor(editorPath, pngPath)
   local ok, launched = pcall(g_platform.spawnProcess, editorPath, { pngPath })
   if not ok or not launched then
      setStatus(tr('Could not start the external editor. Check its executable path.'))
      return false
   end
   setStatus(tr('Editing sprite %d in the external editor. Save the PNG there, then return and apply it.',
      pendingSpriteEdit.spriteId))
   return true
end

function editSprite(forceDiscard)
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before opening the sprite editor?'), function()
         editSprite(true)
      end)
      return
   end
   if not activeVersion or g_game.isOnline() or not selectedSpriteId then
      setStatus(tr('Select a sprite in an offline 15.x work copy before editing it.'))
      return
   end
   if not g_platform.isDesktop() then
      setStatus(tr('External sprite editors are available in desktop builds.'))
      return
   end
   if pendingSpriteEdit and (pendingSpriteEdit.spriteId ~= selectedSpriteId or
         pendingSpriteEdit.version ~= activeVersion) then
      setStatus(tr('Apply the pending edit for sprite %d before opening another sprite.', pendingSpriteEdit.spriteId))
      return
   end

   local pngPath
   if pendingSpriteEdit then
      pngPath = pendingSpriteEdit.path
   else
      local writeRoot = g_resources.getWriteDir()
      if not writeRoot or writeRoot == '' then
         setStatus(tr('Could not find the client profile directory for the temporary PNG.'))
         return
      end
      writeRoot = writeRoot:gsub('[\\/]+$', '')
      local fileName = string.format('otclient-sprite-editor-%d-%d-%d-%d.png',
         g_platform.getProcessId(), activeVersion, selectedSpriteId, g_clock.millis())
      pngPath = string.format('%s/%s', writeRoot, fileName)
      local saved, errorMessage = pcall(g_spriteAppearances.saveSpriteToFile, selectedSpriteId, fileName)
      if not saved or not g_platform.fileExists(pngPath) then
         setStatus(saved and tr('Could not create the temporary PNG for this sprite.') or getUserFacingError(errorMessage))
         return
      end
      pendingSpriteEdit = {
         spriteId = selectedSpriteId,
         version = activeVersion,
         path = pngPath,
         width = canvas:getSpriteWidth(),
         height = canvas:getSpriteHeight(),
      }
      updateSpriteReplacementTarget()
   end

   local editorPath = g_settings.getValue(EXTERNAL_EDITOR_SETTING)
   if editorPath == '' then
      configureSpriteEditor(function(path)
         launchSpriteInEditor(path, pngPath)
      end)
      return
   end
   launchSpriteInEditor(editorPath, pngPath)
end

function applyEditedSprite(forceDiscard, confirmed, closeAfterApply)
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before applying the edited sprite?'), function()
         applyEditedSprite(true)
      end)
      return
   end
   if not pendingSpriteEdit then
      setStatus(tr('Open a sprite in the external editor before applying an edit.'))
      return
   end
   if not activeVersion or g_game.isOnline() or activeVersion ~= pendingSpriteEdit.version then
      setStatus(tr('Reopen the matching offline 15.x work copy before applying this sprite edit.'))
      return
   end
   if not confirmed then
      local edit = pendingSpriteEdit
      local dialog
      dialog = displayGeneralBox(tr('Apply edited sprite'),
         tr('Update sprite %d in the work copy? Every appearance sharing this sprite will change; installed assets remain untouched.', edit.spriteId), {
            { text = tr('Apply to work copy'), callback = function()
               dialog:ok()
               applyEditedSprite(true, true)
            end },
            { text = tr('Cancel'), callback = function() dialog:cancel() end },
         })
      return
   end

   local edit = pendingSpriteEdit
   local category = selectedAppearanceCategory
   local appearanceId = selectedAppearanceId
   local previewSelection = capturePreviewSelection()
   local imported, result = runWorkCopyEdit(tr('Edit sprite image'), function()
      return g_spriteAppearances.importSpriteFromFile(edit.spriteId, edit.path, edit.version)
   end, {
      category = category,
      appearanceId = appearanceId,
      spriteId = edit.spriteId,
      captureSpritePixels = true,
      action = 'sprite-image-edit',
      summary = tr('Edited sprite %d pixels', edit.spriteId),
   })
   if not imported then
      local errorMessage = getUserFacingError(result)
      if errorMessage:find('prepared PNG dimensions must match the selected sprite', 1, true) then
         errorMessage = tr('Sprite %d needs a %d x %d PNG. The working copy was not changed.',
            edit.spriteId, edit.width, edit.height)
      end
      setStatus(errorMessage)
      return
   end
   if not reloadAssets() then
      setStatus(tr('Sprite %d was written, but the work copy could not be reloaded. The edited PNG was kept.', edit.spriteId))
      return
   end
   if category ~= nil and appearanceId ~= nil then
      refreshAppearanceCatalog(category)
      if loadAppearanceRecord(category, appearanceId, true, true) then
         restorePreviewSelection(previewSelection)
      end
   end

   pendingSpriteEdit = nil
   pcall(g_platform.removeFile, edit.path)
   updateSpriteReplacementTarget()
   setStatus(tr('Sprite %d was updated in the work copy. All appearances sharing this sprite use the edited image.', edit.spriteId))
   if closeAfterApply then
      requestClose(true, true)
   end
end

function createAppearance(forceDiscard)
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before creating an appearance?'), function()
         createAppearance(true)
      end)
      return
   end
   if not activeVersion or g_game.isOnline() then
      setStatus(tr('Open a 15.x work copy before creating an appearance.'))
      return
   end
   local category = selectedOption(window:recursiveGetChildById('newAppearanceCategory'))
   local sourceMode = currentNewAppearanceSourceMode
   if not category then
      setStatus(tr('Choose an appearance category.'))
      return
   end

   local spriteId
   local importedNewSprite = false
   if sourceMode == 'png' then
      local path = window:recursiveGetChildById('newAppearancePngPathEdit'):getText()
      if path == '' then
         setStatus(tr('Choose a PNG file first.'))
         return
      end
      local imported, result = runWorkCopyEdit(tr('Import sprite PNG'), function()
         return g_spriteAppearances.importSpriteFromFile(0, path, activeVersion)
      end, {
         category = category,
         captureBeforeAppearance = false,
         resultIsSpriteId = true,
         action = 'sprite-import',
         summary = tr('Imported PNG as a new sprite'),
      })
      if not imported then
         setStatus(getUserFacingError(result))
         return
      end
      spriteId = result
      importedNewSprite = true
      if not reloadAssets() then
         displayErrorBox(tr('Assets Editor'), tr('Sprite %d was imported, but the work copy could not be reloaded.', spriteId))
         return
      end
   elseif sourceMode == 'sprite' then
      spriteId = selectedCreateSpriteId
      if not spriteId or spriteId < 1 or spriteId > MAX_SPRITE_ID then
         setStatus(tr('Search for a sprite ID and select its thumbnail first.'))
         return
      end
   else
      setStatus(tr('Choose a PNG file or an existing sprite ID.'))
      return
   end

   local created, appearanceId = runWorkCopyEdit(tr('Create appearance'), function()
      return g_things.createAppearanceFromSprite(activeVersion, category, spriteId)
   end, {
      category = category,
      captureBeforeAppearance = false,
      resultIsAppearanceId = true,
      action = 'create',
      summary = tr('Created appearance from sprite %d', spriteId),
   })
   if not created then
      if importedNewSprite then reloadAssets() end
      setStatus(tr('Sprite %d is ready, but the appearance could not be created: %s', spriteId, getUserFacingError(appearanceId)))
      return
   end
   if not reloadAssets() then
      displayErrorBox(tr('Assets Editor'), tr('Appearance %d was created, but the work copy could not be reloaded.', appearanceId))
      return
   end

   window:recursiveGetChildById('newAppearancePngPathEdit'):setText('')
   selectedCreateSpriteId = nil
   window:recursiveGetChildById('newAppearanceCategory'):setCurrentOptionByData(category, true)
   updateSpriteReplacementTarget()
   refreshAppearanceCatalog(category)
   loadAppearanceRecord(category, appearanceId, true)
   selectSprite(spriteId)
   showEditorPage()
   setStatus(tr('Created appearance %d with sprite %d.', appearanceId, spriteId), true)
end

function importPngFolder(forceDiscard)
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before importing PNGs?'), function()
         importPngFolder(true)
      end)
      return
   end
   if not activeVersion or g_game.isOnline() then
      setStatus(tr('Open a 15.x work copy before importing PNGs.'))
      return
   end

   local folder = window:recursiveGetChildById('batchPngFolderEdit'):getText():trim()
   if folder == '' then
      setStatus(tr('Choose a folder containing prepared PNG sprites.'))
      return
   end

   local imported, response = runWorkCopyEdit(tr('Import PNG folder'), function()
      return g_spriteAppearances.importSpritesFromDirectory(folder, activeVersion)
   end, {
      captureBeforeAppearance = false,
      action = 'sprite-batch-import',
      summary = tr('Imported prepared PNG sprites from a folder'),
   })
   if not imported then
      setStatus(getUserFacingError(response))
      return
   end

   local decoded, result = pcall(json.decode, response)
   if not decoded or type(result) ~= 'table' then
      setStatus(tr('The PNG import returned an invalid result. Check the client log.'))
      return
   end

   local importedCount = tonumber(result.imported) or 0
   if importedCount > 0 then
      if not reloadAssets() then
         setStatus(tr('%d sprites were written, but the work copy could not be reloaded.', importedCount))
         return
      end
   end

   if result.error and result.error ~= '' then
      setStatus(result.error)
      return
   end
   if importedCount == 0 then
      setStatus(tr('No PNG sprites were imported.'))
      return
   end

   local firstId = math.huge
   local lastId = 0
   for _, item in ipairs(result.items or {}) do
      local spriteId = tonumber(item.id)
      if spriteId then
         firstId = math.min(firstId, spriteId)
         lastId = math.max(lastId, spriteId)
      end
   end
   if firstId == math.huge then
      setStatus(tr('%d sprites imported. They are ready in the Sprite ID picker.', importedCount), true)
   else
      setStatus(tr('%d sprites imported (IDs %d-%d). They are ready in the Sprite ID picker.',
         importedCount, firstId, lastId), true)
   end
end

function importSpriteSheet(forceDiscard)
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes before importing this sprite sheet?'), function()
         importSpriteSheet(true)
      end)
      return
   end
   if not activeVersion or g_game.isOnline() then
      setStatus(tr('Open a 15.x work copy before importing a sprite sheet.'))
      return
   end

   local fileName = window:recursiveGetChildById('spriteSheetPathEdit'):getText():trim()
   if fileName == '' then
      setStatus(tr('Choose a PNG sprite sheet.'))
      return
   end
   local spriteWidth = tonumber(selectedOption(window:recursiveGetChildById('spriteSheetCellWidth')))
   local spriteHeight = tonumber(selectedOption(window:recursiveGetChildById('spriteSheetCellHeight')))
   if not spriteWidth or not spriteHeight then
      setStatus(tr('Choose the width and height of each sprite cell.'))
      return
   end
   local firstCell = tonumber(window:recursiveGetChildById('spriteSheetFirstCell'):getText():trim())
   local lastCell = tonumber(window:recursiveGetChildById('spriteSheetLastCell'):getText():trim())
   if not firstCell or firstCell < 1 or firstCell % 1 ~= 0 or not lastCell or lastCell < 0 or
         lastCell % 1 ~= 0 or (lastCell ~= 0 and lastCell < firstCell) then
      setStatus(tr('Enter a valid cell range. The last cell can be 0 to include the rest of the sheet.'))
      return
   end

   local imported, response = runWorkCopyEdit(tr('Import sprite sheet'), function()
      return g_spriteAppearances.importSpritesFromSheet(fileName, activeVersion,
         spriteWidth, spriteHeight, firstCell, lastCell,
         window:recursiveGetChildById('spriteSheetSkipTransparent'):isChecked())
   end, {
      captureBeforeAppearance = false,
      action = 'sprite-sheet-import',
      summary = tr('Imported sprites from a PNG sheet'),
   })
   if not imported then
      setStatus(getUserFacingError(response))
      return
   end

   local decoded, result = pcall(json.decode, response)
   if not decoded or type(result) ~= 'table' then
      setStatus(tr('The sprite sheet import returned an invalid result. Check the client log.'))
      return
   end

   local importedCount = tonumber(result.imported) or 0
   if importedCount > 0 and not reloadAssets() then
      setStatus(tr('%d sprites were written, but the work copy could not be reloaded.', importedCount))
      return
   end
   if result.error and result.error ~= '' then
      setStatus(result.error)
      return
   end
   if importedCount == 0 then
      setStatus(tr('No sprite cells were imported.'))
      return
   end

   local firstId = tonumber(result.items[1].id)
   local lastId = tonumber(result.items[importedCount].id)
   local skippedCount = tonumber(result.skipped) or 0
   if skippedCount > 0 then
      setStatus(tr('Imported %d sprites as IDs %d-%d; skipped %d fully transparent cells.',
         importedCount, firstId, lastId, skippedCount))
   else
      setStatus(tr('Imported %d sprites as IDs %d-%d, in row-major order.', importedCount, firstId, lastId), true)
   end
end

collectAnimationWidgetChanges = function()
   if not animationWidgets.groupIndex then
      return true
   end

   local group = previewFrameGroups[animationWidgets.groupIndex + 1]
   if not group or not group.animation.enabled then
      return true
   end

   for field, edit in pairs(animationWidgets.fields or {}) do
      local value = tonumber(edit:getText())
      if not value or value < 0 or value % 1 ~= 0 or value > 4294967295 then
         setAppearanceStatus(tr('Animation values must be non-negative 32-bit integers.'))
         return false
      end
      if field == 'defaultStartPhase' and value >= group.phaseCount then
         setAppearanceStatus(tr('Default phase must be within the frame group.'))
         return false
      end
      setAnimationChange(animationWidgets.groupIndex, field, value)
   end

   local phaseFields = animationWidgets.phaseFields
   if phaseFields then
      local durationMin = tonumber(phaseFields.durationMin:getText())
      local durationMax = tonumber(phaseFields.durationMax:getText())
      if not durationMin or not durationMax or durationMin < 0 or durationMax < 0 or
            durationMin % 1 ~= 0 or durationMax % 1 ~= 0 or
            durationMin > 4294967295 or durationMax > 4294967295 then
         setAppearanceStatus(tr('Frame durations must be non-negative 32-bit integers.'))
         return false
      end
      if durationMin > durationMax then
         setAppearanceStatus(tr('Minimum frame duration cannot exceed maximum duration.'))
         return false
      end
      setAnimationChange(animationWidgets.groupIndex, 'durationMin', durationMin, animationWidgets.phaseIndex)
      setAnimationChange(animationWidgets.groupIndex, 'durationMax', durationMax, animationWidgets.phaseIndex)
   end
   return true
end

function saveAppearanceProperties()
   if not appearanceOriginal or not activeVersion or g_game.isOnline() then
      return
   end
   if not getAppearancePropertiesEditor():collect_changes() then
      return
   end
   if not collectAnimationWidgetChanges() then
      return
   end
   if not hasAppearanceChanges() then
      setAppearanceStatus(tr('There are no appearance changes to save.'))
      return
   end

   local previewSelection = capturePreviewSelection()
   local updates = {}
   for section, values in pairs(appearanceChanges) do
      local hasSectionChanges = section == 'animation' and next(values.groups) ~= nil or
         section ~= 'animation' and next(values) ~= nil
      if hasSectionChanges then
         updates[section] = values
      end
   end
   local ok, err = runWorkCopyEdit(tr('Save appearance changes'), function()
      return g_things.saveAppearanceEditorData(activeVersion, selectedAppearanceCategory,
         selectedAppearanceId, json.encode(updates))
   end)
   if not ok then
      setAppearanceStatus(getUserFacingError(err))
      return
   end
   if not reloadAssets() then
      displayErrorBox(tr('Assets Editor'), tr('Properties were saved, but the work copy could not be reloaded.'))
      return
   end
   refreshAppearanceCatalog(selectedAppearanceCategory)
   if not loadAppearanceRecord(selectedAppearanceCategory, selectedAppearanceId, true, true) then
      setAppearanceStatus(tr('Changes were saved, but the appearance could not be reloaded.'))
      return
   end
   restorePreviewSelection(previewSelection)
   setAppearanceStatus(tr('Appearance %d saved to the work copy.', selectedAppearanceId), true)
end

function exportWorkCopy(forceContinue, confirmed)
   if hasAppearanceChanges() and not forceContinue then
      local messageBox
      local function saveAndExport()
         messageBox:ok()
         saveAppearanceProperties()
         if not hasAppearanceChanges() then
            exportWorkCopy(true, false)
         end
      end
      local function cancelMessageBox()
         messageBox:cancel()
      end
      local unsavedMessage = currentExportMode == 'appearance' and
         tr('Save or discard the pending appearance changes before exporting this bundle.') or
         tr('Save or discard the pending changes before exporting the work copy.')
      messageBox = displayGeneralBox(tr('Unsaved appearance properties'), unsavedMessage, {
         { text = tr('Save and continue'), callback = saveAndExport },
         { text = tr('Discard edits'), callback = function()
            messageBox:ok()
            resetAppearanceDraft()
            exportWorkCopy(true, false)
         end },
         { text = tr('Cancel'), callback = cancelMessageBox },
      }, saveAndExport, cancelMessageBox)
      return
   end
   if not activeVersion or g_game.isOnline() then
      setExportStatus(tr('Load an offline 15.x work copy before exporting.'))
      return
   end
   local isNewVersion = currentExportMode == 'new'
   local isFolderExport = currentExportMode == 'folder'
   local isAppearanceExport = currentExportMode == 'appearance'
   local targetVersion = activeVersion
   local destinationRoot
   if isNewVersion then
      targetVersion = parseClientVersion(window:recursiveGetChildById('newVersionEdit'):getText())
   elseif isFolderExport or isAppearanceExport then
      destinationRoot = window:recursiveGetChildById('exportFolderEdit'):getText():trim()
      local isAbsoluteDestination = destinationRoot:sub(1, 1) == '/' or destinationRoot:match('^%a:[/\\]') ~= nil or
         destinationRoot:match('^[/\\][/\\]') ~= nil
      if not isAbsoluteDestination then
         setExportStatus(tr('Choose an absolute destination folder.'))
         return
      end
   end
   if isAppearanceExport and not selectedAppearanceId then
      setExportStatus(tr('Select an appearance in the list before exporting its bundle.'))
      return
   end
   if isNewVersion and (not isSupportedAssetVersion(targetVersion) or targetVersion == activeVersion or
         getVersionDirectories()[targetVersion]) then
      setExportStatus(tr('Choose an unused 15.x version supported by this client.'))
      return
   end
   if not confirmed then
      local messageBox
      local function cancelInstall()
         messageBox:cancel()
      end
      local function confirmInstall()
         messageBox:ok()
         exportWorkCopy(true, true)
      end
      local title = isAppearanceExport and tr('Export this appearance bundle?') or
         (isFolderExport and tr('Copy assets to the selected folder?') or
         (isNewVersion and tr('Install client version %s?', formatClientVersion(targetVersion)) or
            tr('Replace client version %s?', formatClientVersion(activeVersion))))
      local message = isAppearanceExport and
         tr('Creates a new bundle in %s with the selected appearance, its flags and animation data, and copies of its referenced sprites. Existing folders are never overwritten.',
            destinationRoot) or
         (isFolderExport and
         tr('Creates %s/data/things/%d. Existing packages are never overwritten.', destinationRoot, activeVersion) or
         (isNewVersion and
            tr('Creates data/things/%d. Existing versions are never overwritten; source %s stays unchanged.',
               targetVersion, formatClientVersion(activeVersion)) or
            tr('Replaces data/things/%d. Existing assets are backed up first; if none exist, the working copy is installed there.', activeVersion)))
      messageBox = displayGeneralBox(title, message, {
            { text = isAppearanceExport and tr('Export bundle') or
               (isFolderExport and tr('Copy assets') or
                  (isNewVersion and tr('Install new version') or tr('Replace version'))), callback = confirmInstall },
            { text = tr('Cancel'), callback = cancelInstall },
         }, cancelInstall, cancelInstall)
      return
   end

   if isFolderExport then
      local copied, result = pcall(g_spriteAppearances.exportWorkCopy, activeVersion, destinationRoot)
      if not copied then
         local errorMessage = getUserFacingError(result)
         setExportStatus(errorMessage)
         setStatus(errorMessage)
         return
      end
      local status = tr('Assets copied to %s. The installed version was not changed.', result)
      setExportStatus(status, true)
      setStatus(tr('Work copy exported to %s.', result), true)
      return
   end

   if isAppearanceExport then
      local ok, result = pcall(g_things.exportAppearanceBundle, activeVersion,
         selectedAppearanceCategory, selectedAppearanceId, destinationRoot)
      if not ok then
         local errorMessage = getUserFacingError(result)
         setExportStatus(errorMessage)
         setStatus(errorMessage)
         return
      end
      local status = tr('Appearance bundle exported to %s.', result)
      setExportStatus(status, true)
      setStatus(status, true)
      return
   end

   local result = isNewVersion and
      getWorkCopyService():install_as_new_version(activeVersion, targetVersion, activeWorkRoot) or
      getWorkCopyService():install(activeVersion, activeWorkRoot)
   if result.installed and not isNewVersion then
      refreshInstalledAssetBackups()
      updateInstalledAssetBackupOptions()
      updateExportControls()
   end
   if isNewVersion and result.installed then
      window:recursiveGetChildById('versionComboBox'):addOption(formatClientVersion(targetVersion), targetVersion)
   end
   if result.remount_failed then
      local details = isNewVersion and result.destination or result.backup_path
      local message = result.installed and
         tr('Assets were installed, but the working copy could not be remounted. Location: %s', details) or
         tr('%s The working copy could not be remounted.', getUserFacingError(result.error))
      setExportStatus(message)
      displayErrorBox(tr('Assets Editor'), message)
      return
   end
   if not result.installed then
      setExportStatus(getUserFacingError(result.error))
      return
   end
   if isNewVersion then
      local status = tr('Version %s installed. Select it in Assets version to load it.', formatClientVersion(targetVersion))
      setExportStatus(status, true)
      setStatus(tr('Client version %s is available in data/things/%d.', formatClientVersion(targetVersion), targetVersion), true)
      return
   end

   local backupPath = result.backup_path
   if not reloadAssets() then
      local message = backupPath and backupPath ~= '' and
         tr('Assets were installed, but the editor could not reload them. Backup: %s', backupPath) or
         tr('Assets were installed, but the editor could not reload them. No previous package existed to back up.')
      setExportStatus(message)
      displayErrorBox(tr('Assets Editor'), message)
      return
   end

   refreshAppearanceCatalog(selectedAppearanceCategory)
   if selectedAppearanceId then
      loadAppearanceRecord(selectedAppearanceCategory, selectedAppearanceId, true, true)
   end
   local status = backupPath and backupPath ~= '' and
      tr('Assets installed and reloaded. Backup: %s', backupPath) or
      tr('Assets installed and reloaded. No previous package existed to back up.')
   setExportStatus(status, true)
   setStatus(tr('Client %s is installed and reloaded.', formatClientVersion(activeVersion)), true)
end

function reloadPackage()
   if not activeVersion or g_game.isOnline() then
      return
   end
   if hasAppearanceChanges() then
      confirmUnsavedChanges(tr('Save changes before reloading the work copy?'), function()
         reloadPackageNow()
      end)
      return
   end
   reloadPackageNow()
end

function reloadPackageNow()
   if not reloadAssets() then
      displayErrorBox(tr('Assets Editor'), tr('Could not reload the selected work copy.'))
      return
   end
   refreshAppearanceCatalog(selectedAppearanceCategory)
   if selectedAppearanceId then
      loadAppearanceRecord(selectedAppearanceCategory, selectedAppearanceId, true, true)
   end
   setStatus(tr('Work copy reloaded from disk.'))
end

function requestClose(forceDiscard, pendingEditConfirmed)
   if not window then
      return
   end
   stopPreviewAnimation()
   if hasAppearanceChanges() and not forceDiscard then
      confirmUnsavedChanges(tr('Save changes to the working copy before closing?'), function()
         requestClose(true, pendingEditConfirmed)
      end)
      return
   end
   if pendingSpriteEdit and not pendingEditConfirmed then
      local edit = pendingSpriteEdit
      local messageBox
      local function keepEditing()
         messageBox:cancel()
      end
      local function applyEditAndClose()
         messageBox:ok()
         applyEditedSprite(true, true, true)
      end
      local function discardEditAndClose()
         messageBox:ok()
         if pendingSpriteEdit then
            pcall(g_platform.removeFile, pendingSpriteEdit.path)
            pendingSpriteEdit = nil
            updateSpriteReplacementTarget()
         end
         requestClose(true, true)
      end
      messageBox = displayGeneralBox(tr('Pending sprite edit'),
         tr('Sprite %d has a temporary PNG open in the external editor. Save it there before applying, or discard the temporary edit before closing.', edit.spriteId), {
            { text = tr('Apply edit and close'), callback = applyEditAndClose },
            { text = tr('Discard edit and close'), callback = discardEditAndClose },
            { text = tr('Keep editing'), callback = keepEditing },
         }, keepEditing, keepEditing)
      return
   end
   if persistEditorUiState then
      persistEditorUiState(true)
   end
   if activeVersion then
      local released, err = releaseActiveWorkCopy()
      if not released then
         displayErrorBox(tr('Assets Editor'), err)
         return
      end
   end
   destroyWindow()
   if topMenuButton then topMenuButton:setOn(false) end
end
