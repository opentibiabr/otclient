Updater = {}

Updater.maxRetries = 5

local updaterWindow
local loadModulesFunction
local scheduledEvent
local httpOperationId = 0

local function onLog(level, message, time)
  if level == LogError then
    Updater.error(message)
    g_logger.setOnLog(nil)
  end
end

local function loadModules()
  if loadModulesFunction then
    local tmpLoadFunc = loadModulesFunction
    loadModulesFunction = nil
    tmpLoadFunc()
  end
end

local function downloadFiles(url, files, index, retries, doneCallback)
  if not updaterWindow then return end
  local entry = files[index]
  if not entry then -- finished
    return doneCallback()
  end
  local file = entry[1]
  local file_checksum = entry[2]

  if retries > 0 then
    updaterWindow.downloadStatus:setText(tr("Downloading (%i retry):\n%s", retries, file))
  else
    updaterWindow.downloadStatus:setText(tr("Downloading:\n%s", file))
  end
  updaterWindow.downloadProgress:setPercent(0)
  updaterWindow.mainProgress:setPercent(math.floor(100 * index / #files))

  httpOperationId = HTTP.download(url .. file, file,
    function(file, checksum, err)
      if not err and checksum ~= file_checksum then
        err = "Invalid checksum of: " .. file .. ".\nShould be " .. file_checksum .. ", is: " .. checksum
      end
      if err then
        if retries >= Updater.maxRetries then
          Updater.error("Can't download file: " .. file .. ".\nError: " .. err)
        else
          scheduledEvent = scheduleEvent(function()
            downloadFiles(url, files, index, retries + 1, doneCallback)
          end, 250)
        end
        return
      end
      downloadFiles(url, files, index + 1, 0, doneCallback)
    end,
    function(progress, speed)
      updaterWindow.downloadProgress:setPercent(progress)
      updaterWindow.downloadProgress:setText(speed .. " kbps")
    end)
end

local function updateFiles(data, keepCurrentFiles)
  if not updaterWindow then return end

  if type(data) ~= "table" then
    return Updater.error("Invalid data from updater api (not table)")
  end

  if type(data.error) == 'string' and data.error:len() > 0 then
    return Updater.error(data.error)
  end

  if not data.files or type(data.url) ~= 'string' or data.url:len() < 4 then
    return Updater.error("Invalid data from updater api: " .. json.encode(data, 2))
  end

  if data.keepFiles then
    keepCurrentFiles = true
  end

  local newFiles = false
  local finalFiles = {}
  local localFiles = g_resources.filesChecksums()

  local toUpdate = {}
  local toUpdateFiles = {}
  -- keep all files or files from data/things
  for file, checksum in pairs(localFiles) do
    if keepCurrentFiles or string.find(file, "data/things") then
      table.insert(finalFiles, file)
    end
  end

  -- update files
  for file, checksum in pairs(data.files) do
    table.insert(finalFiles, file)
    if not localFiles[file] or localFiles[file] ~= checksum then
      table.insert(toUpdate, { file, checksum })
      table.insert(toUpdateFiles, file)
      newFiles = true
    end
  end

  -- update binary
  local binary = nil
  if type(data.binary) == "table" 
    and type(data.binary.file) == "string" and data.binary.file:len() > 1 
    and type(data.binary.checksum) == "string" and data.binary.checksum:len() > 0 then
    local selfChecksum = g_resources.selfChecksum()
    if selfChecksum:len() > 0 and selfChecksum ~= data.binary.checksum then
      binary = data.binary.file
      table.insert(toUpdate, { binary, data.binary.checksum })
    end
  end

  if #toUpdate == 0 then -- nothing to update
    updaterWindow.mainProgress:setPercent(100)
    scheduledEvent = scheduleEvent(Updater.abort, 20)
    return
  end

  -- update of some files require full client restart
  local forceRestart = false
  local reloadModules = false
  local forceRestartPattern = { "init.lua", "corelib", "updater", "otmod" }
  for _, file in ipairs(toUpdate) do
    for __, pattern in ipairs(forceRestartPattern) do
      if string.find(file[1], pattern) then
        forceRestart = true
      end
      if not string.find(file[1], "data/things") then
        reloadModules = true
      end
    end
  end

  updaterWindow.status:setText(tr("Updating %i files", #toUpdate))
  updaterWindow.mainProgress:setPercent(0)
  updaterWindow.downloadProgress:setPercent(0)
  updaterWindow.downloadProgress:show()
  updaterWindow.downloadStatus:show()
  if updaterWindow.changeUrlButton then
    updaterWindow.changeUrlButton:hide()
  end

  downloadFiles(data["url"], toUpdate, 1, 0, function()
    updaterWindow.status:setText(tr("Updating client (may take few seconds)"))
    updaterWindow.mainProgress:setPercent(100)
    updaterWindow.downloadProgress:hide()
    updaterWindow.downloadStatus:hide()
    scheduledEvent = scheduleEvent(function()
      local restart = binary or (not loadModulesFunction and reloadModules) or forceRestart
      if newFiles then
        g_resources.updateFiles(toUpdateFiles, not restart)
      end

      if binary then
        g_resources.updateExecutable(binary)
      end

      if restart then
        g_app.restart()
      else
        if reloadModules then
          g_textures.clearCache()
          g_modules.reloadModules()
        end
        Updater.abort()
      end
    end, 100)
  end)
end

-- public functions
function Updater.init(loadModulesFunc)
  g_logger.setOnLog(onLog)
  loadModulesFunction = loadModulesFunc
  Updater.check()
end

function Updater.terminate()
  loadModulesFunction = nil
  Updater.abort(true)
end

function Updater.abort(terminate)
  HTTP.cancel(httpOperationId)
  removeEvent(scheduledEvent)
  if updaterWindow then
    updaterWindow:destroy()
    updaterWindow = nil
  end
  loadModules()
  if not terminate then
    signalcall(g_app.onUpdateFinished, g_app)
  end
end

function Updater.check(args)
  if updaterWindow then return end

  updaterWindow = g_ui.displayUI('updater')
  updaterWindow:show()
  updaterWindow:focus()
  updaterWindow:raise()

  local updateData = nil
  local allowCustomServers = ALLOW_CUSTOM_SERVERS or false
  local function progressUpdater(value)
    removeEvent(scheduledEvent)
    if value == 100 then
      return Updater.error(tr("Timeout"))
    end
    if updateData and (value > 60 or (not g_platform.isMobile() or not allowCustomServers or not loadModulesFunction)) then -- gives 3s to set custom updater for mobile version
      return updateFiles(updateData)
    end
    scheduledEvent = scheduleEvent(function() progressUpdater(value + 1) end, 100)
    updaterWindow.mainProgress:setPercent(value)
  end
  progressUpdater(0)

  httpOperationId = HTTP.postJSON(Services.updater, {
    version = g_app.getBuildRevision(),
    build = g_app.getVersion(),
    os = g_app.getOs(),
    platform = g_window.getPlatformType(),
    args = args or {}
  }, function(data, err)
    if err then
      return Updater.error(err)
    end
    updateData = data
  end)
end

function Updater.error(message)
  removeEvent(scheduledEvent)
  if not updaterWindow then return end
  displayErrorBox(tr("Updater Error"), message).onOk = function()
    Updater.abort()
  end
end

-- TODO: [MOBILE-TEST] Mobile testing required for changeUrl functionality
-- Feature flag to enable/disable changeUrl (set to false until mobile testing is complete)
Updater.enableChangeUrl = false

-- Test Checklist for changeUrl on mobile:
-- [ ] 1. Verify dialog opens correctly on mobile screen sizes
-- [ ] 2. Test TextEdit input works with mobile keyboard
-- [ ] 3. Confirm OK button saves URL with trailing slash and restarts updater
-- [ ] 4. Confirm Restart button restarts updater without changing URL
-- [ ] 5. Verify dialog closes properly when buttons are clicked
-- [ ] 6. Test with valid and invalid URLs (less than 5 characters)
-- [ ] 7. Verify update process cancellation works correctly

function Updater.changeUrl()
    if not updaterWindow then
        return
    end

    -- Guard: only allow if feature flag is enabled
    if not Updater.enableChangeUrl then
        g_logger.warning("Updater.changeUrl is disabled. Set Updater.enableChangeUrl = true to enable.")
        return
    end

    local dialog = g_ui.createWidget('MainWindow', rootWidget)
    dialog:setId('changeUrlDialog')
    dialog:setText(tr('Change Updater URL'))
    dialog:setSize({
        width = 400,
        height = 120
    })

    local layout = g_ui.createWidget('VerticalBox', dialog)
    layout:setId('layout')
    layout:addAnchor(AnchorTop, 'parent', AnchorTop)
    layout:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    layout:addAnchor(AnchorRight, 'parent', AnchorRight)
    layout:setMarginTop(30)
    layout:setMarginLeft(10)
    layout:setMarginRight(10)

    local textEdit = g_ui.createWidget('TextEdit', layout)
    textEdit:setId('urlInput')
    textEdit:setText(Services.updater or '')
    textEdit:setHeight(20)

    local buttonBox = g_ui.createWidget('HorizontalBox', layout)
    buttonBox:setMarginTop(10)
    buttonBox:setHeight(25)

    local okButton = g_ui.createWidget('Button', buttonBox)
    okButton:setText(tr('OK'))
    okButton:setWidth(80)
    okButton:setMarginRight(5)
    okButton.onClick = function()
        local newUrl = textEdit:getText()
        if newUrl and newUrl:len() > 4 then
            -- Cancel current update process before restarting with new URL
            removeEvent(scheduledEvent)
            HTTP.cancel(httpOperationId)
            -- Normalize URL to ensure trailing slash
            if not newUrl:match("/$") then
                newUrl = newUrl .. "/"
            end
            Services.updater = newUrl
            dialog:destroy()
            -- Restart updater with new URL
            if updaterWindow then
                updaterWindow:destroy()
                updaterWindow = nil
            end
            Updater.check()
        end
    end

    local restartButton = g_ui.createWidget('Button', buttonBox)
    restartButton:setText(tr('Restart'))
    restartButton:setWidth(80)
    restartButton.onClick = function()
        -- Cancel current update process before restarting
        removeEvent(scheduledEvent)
        HTTP.cancel(httpOperationId)
        dialog:destroy()
        if updaterWindow then
            updaterWindow:destroy()
            updaterWindow = nil
        end
        -- Restart update process from beginning
        Updater.check()
    end

    dialog:show()
    dialog:focus()
    dialog:raise()
    textEdit:focus()
end
