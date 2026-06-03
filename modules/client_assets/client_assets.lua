ClientAssets = {}

local DEFAULT_CONFIG = {
  enabled = true,
  repository = 'dudantas/tibia-client',
  rawBaseUrl = 'https://raw.githubusercontent.com/%s/%s/',
  installSounds = true,
  timeout = 30,
  retries = 2,
  preferPackedManifestUrls = true,
  strictManifestSha256 = true,
  allowRawFallbackHashMismatch = false,
  preferArchive = true,
  installArchiveExtras = true,
  archiveExtraPrefixes = { 'bin' },
  archiveExtrasDestination = '',
  installPackagedFiles = true,
  packagedFilesDestination = '',
  packagedFilesRequired = false,
  installInWorkDir = true
}

local activeDownload
local releasesCache = {}
local ARCHIVE_EXTENSIONS = { '.zip', '.rar' }
local DOWNLOAD_WINDOW_WIDTH = 360
local DOWNLOAD_WINDOW_HEIGHT = 140
local DOWNLOAD_TEXT_MARGIN = 34
local DOWNLOAD_BAR_HEIGHT = 22
local BUSY_INDICATOR_IMAGE = '/client_assets/images/hourglass'
local BUSY_INDICATOR_SIZE = 20
local BUSY_INDICATOR_ROTATION_DELAY = 650
local BUSY_INDICATOR_ROTATION_STEP = 180
local HTTP_NOT_FOUND_SHA256 = 'd5558cd419c8d46bdc958064cb97f963d1ea793866414c025906ec15033512ed'

local function logInfo(message)
  g_logger.info('[client_assets] ' .. tostring(message))
end

local function logWarning(message)
  g_logger.warning('[client_assets] ' .. tostring(message))
end

local function logError(message)
  g_logger.error('[client_assets] ' .. tostring(message))
end

local function startsWith(value, prefix)
  return type(value) == 'string' and value:sub(1, #prefix) == prefix
end

local function endsWith(value, suffix)
  return type(value) == 'string' and suffix ~= '' and value:sub(-#suffix) == suffix
end

local function isArchivePath(path)
  path = tostring(path or ''):lower()
  for _, extension in ipairs(ARCHIVE_EXTENSIONS) do
    if endsWith(path, extension) then
      return true
    end
  end
  return false
end

local function isLzmaPath(path)
  return endsWith(tostring(path or ''):lower(), '.lzma')
end

local function parentPath(path)
  path = tostring(path or ''):gsub('\\', '/')
  return path:match('^(.*)/[^/]+$') or ''
end

local function stripArchiveExtension(path)
  for _, extension in ipairs(ARCHIVE_EXTENSIONS) do
    if endsWith(path:lower(), extension) then
      return path:sub(1, #path - #extension)
    end
  end
  return path
end

local function toList(value)
  if type(value) == 'table' then
    return value
  end
  if type(value) == 'string' then
    return { value }
  end
  return {}
end

local function matchesAnyPrefix(path, prefixes)
  path = tostring(path or '')
  local prefixList = toList(prefixes)
  if #prefixList == 0 then
    return true
  end
  for _, prefix in ipairs(prefixList) do
    if startsWith(path, prefix) then
      return true
    end
  end
  return false
end

local function joinUrl(baseUrl, path)
  if not baseUrl or baseUrl == '' then
    return path
  end
  if startsWith(path, 'http://') or startsWith(path, 'https://') then
    return path
  end
  if not endsWith(baseUrl, '/') then
    baseUrl = baseUrl .. '/'
  end
  while startsWith(path, '/') do
    path = path:sub(2)
  end
  return baseUrl .. path
end

local function cloneConfig()
  local config = {}
  for key, value in pairs(DEFAULT_CONFIG) do
    config[key] = value
  end

  local custom = Services and Services.clientAssets
  if custom == false then
    config.enabled = false
    return config
  end

  if type(custom) == 'string' then
    config.manifestUrl = custom
  elseif type(custom) == 'table' then
    for key, value in pairs(custom) do
      config[key] = value
    end
  end

  if not config.releasesUrl and config.repository then
    config.releasesUrl = string.format('https://api.github.com/repos/%s/releases?per_page=100', config.repository)
  end

  return config
end

local function withHttpTimeout(config, fn)
  local oldTimeout = HTTP.timeout
  HTTP.timeout = config.timeout or oldTimeout
  local ok, result = pcall(fn)
  HTTP.timeout = oldTimeout
  if not ok then
    error(result)
  end
  return result
end

local function httpGet(config, url, callback)
  return withHttpTimeout(config, function()
    return HTTP.get(url, callback)
  end)
end

local function httpGetJSON(config, url, callback)
  return withHttpTimeout(config, function()
    return HTTP.getJSON(url, callback)
  end)
end

local function httpDownload(config, url, path, callback, progressCallback)
  return withHttpTimeout(config, function()
    return HTTP.download(url, path, callback, progressCallback)
  end)
end

local function versionLabel(version)
  version = tonumber(version) or 0
  return string.format('%d.%02d', math.floor(version / 100), version % 100)
end

local function shortenText(value, maxLength)
  value = tostring(value or '')
  maxLength = maxLength or 56
  if #value <= maxLength then
    return value
  end
  if maxLength <= 8 then
    return value:sub(1, maxLength)
  end
  local head = math.floor((maxLength - 3) / 2)
  local tail = maxLength - 3 - head
  return value:sub(1, head) .. '...' .. value:sub(#value - tail + 1)
end

local function userFacingError(message)
  if not message then
    return nil
  end

  message = tostring(message)
  if message:find('SHA%-256') or #message > 180 then
    return 'Unable to download client assets.\nSee the console for full details.\n' .. shortenText(message, 120)
  end

  return message
end

local function createDownloadWindow()
  local initialText = tr('Preparing download...') .. '\n0%'
  local window = displayCancelBox(tr('Downloading Assets'), initialText)
  local width = DOWNLOAD_WINDOW_WIDTH
  if rootWidget then
    width = math.min(width, math.max(280, rootWidget:getWidth() - 40))
  end

  window:setWidth(width)
  window:setHeight(DOWNLOAD_WINDOW_HEIGHT)

  window.content:setTextWrap(true)
  window.content:setWidth(width - DOWNLOAD_TEXT_MARGIN)
  window.content:setText(initialText)
  window.content:resizeToText()

  local progressBar = g_ui.createWidget('UIWidget', window)
  progressBar:setId('assetDownloadProgressBar')
  progressBar:setHeight(DOWNLOAD_BAR_HEIGHT)
  progressBar:setBackgroundColor('#1a1a1a')
  progressBar:setBorderWidth(1)
  progressBar:setBorderColor('#000000')
  progressBar:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  progressBar:addAnchor(AnchorRight, 'parent', AnchorRight)
  progressBar:addAnchor(AnchorTop, 'content', AnchorBottom)
  progressBar:setMarginLeft(15)
  progressBar:setMarginRight(15)
  progressBar:setMarginTop(8)
  window.progressBar = progressBar

  local progressFill = g_ui.createWidget('UIWidget', progressBar)
  progressFill:setId('assetDownloadProgressFill')
  progressFill:setBackgroundColor('#4444ff')
  progressFill:setHeight(DOWNLOAD_BAR_HEIGHT - 2)
  progressFill:setWidth(0)
  progressFill:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  progressFill:addAnchor(AnchorTop, 'parent', AnchorTop)
  progressFill:addAnchor(AnchorBottom, 'parent', AnchorBottom)
  progressFill:setMarginLeft(1)
  progressFill:setMarginTop(1)
  progressFill:setMarginBottom(1)
  window.progressFill = progressFill

  local busyIndicator = g_ui.createWidget('UIWidget', window)
  busyIndicator:setId('assetDownloadBusyIndicator')
  busyIndicator:setSize(string.format('%d %d', BUSY_INDICATOR_SIZE, BUSY_INDICATOR_SIZE))
  busyIndicator:setImageSource(BUSY_INDICATOR_IMAGE)
  busyIndicator:setImageSmooth(true)
  busyIndicator:setPhantom(true)
  busyIndicator:setVisible(false)
  busyIndicator:addAnchor(AnchorHorizontalCenter, 'assetDownloadProgressBar', AnchorHorizontalCenter)
  busyIndicator:addAnchor(AnchorVerticalCenter, 'assetDownloadProgressBar', AnchorVerticalCenter)
  busyIndicator:raise()
  window.busyIndicator = busyIndicator

  local separator = window:getChildById('messageBoxSeparator')
  if separator then
    separator:setVisible(false)
  end

  window.holder = window:getChildById('holder')
  if window.holder then
    window.holder:breakAnchors()
    window.holder:addAnchor(AnchorRight, 'assetDownloadProgressBar', AnchorRight)
    window.holder:addAnchor(AnchorLeft, 'assetDownloadProgressBar', AnchorLeft)
    window.holder:addAnchor(AnchorTop, 'assetDownloadProgressBar', AnchorBottom)
    window.holder:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    window.holder:setMarginTop(14)
  end

  return window
end

local function clampPercent(percent)
  percent = math.floor(tonumber(percent) or 0)
  return math.max(0, math.min(100, percent))
end

local function updateDownloadBar(window, percent)
  if not window or not window.progressFill or not window.progressBar then
    return
  end

  percent = clampPercent(percent)
  local width = math.max(0, (window.progressBar:getWidth() or 0) - 2)
  window.progressFill:setWidth(math.floor(width * percent / 100))
end

local function completeMarkerPath(version)
  return string.format('data/things/%d/.client-assets-complete', version)
end

local function joinPhysicalPath(base, path)
  base = tostring(base or ''):gsub('\\', '/'):gsub('/+$', '')
  path = tostring(path or ''):gsub('\\', '/'):gsub('^/+', '')
  if base == '' then
    return path
  end
  return base .. '/' .. path
end

local function physicalInstallPath(path)
  return joinPhysicalPath(g_resources.getWorkDir(), path)
end

local function shouldInstallInWorkDir(config)
  return config and config.installInWorkDir ~= false
end

local function hasCatalogEntryFile(basePath, entry)
  if type(entry) ~= 'table' or type(entry.file) ~= 'string' then
    return false
  end
  return g_resources.fileExists(basePath .. entry.file)
end

local function installFileExists(path)
  if g_resources.fileExistsInWorkDir and g_resources.fileExistsInWorkDir(path) then
    return true
  end
  return g_resources.fileExists('/' .. path)
end

local function readInstallFile(path)
  if g_resources.readFileContentsFromWorkDir and
     (not g_resources.fileExistsInWorkDir or g_resources.fileExistsInWorkDir(path)) then
    local ok, contents = pcall(function() return g_resources.readFileContentsFromWorkDir(path) end)
    if ok and type(contents) == 'string' then
      return contents
    end
  end
  return g_resources.readFileContents('/' .. path)
end

local function hasInstallCatalogEntryFile(basePath, entry)
  if type(entry) ~= 'table' or type(entry.file) ~= 'string' then
    return false
  end
  return installFileExists(basePath .. entry.file)
end

local function hasModernClientFilesAtPath(basePath, installPath)
  local fileExists = installPath and installFileExists or g_resources.fileExists
  local readFile = installPath and readInstallFile or g_resources.readFileContents

  if not fileExists(basePath .. 'catalog-content.json') or
     not fileExists(basePath .. 'assets.json.sha256') then
    return false
  end

  local ok, data = pcall(readFile, basePath .. 'catalog-content.json')
  if not ok or type(data) ~= 'string' then
    return false
  end

  local decodeOk, catalog = pcall(json.decode, data)
  if not decodeOk or type(catalog) ~= 'table' then
    return false
  end

  local hasAppearances = false
  local hasStaticData = false
  for _, entry in ipairs(catalog) do
    local entryType = entry.type
    if entryType == 'appearances' or entryType == 'staticdata' or entryType == 'proficiencies' then
      if installPath and not hasInstallCatalogEntryFile(basePath, entry) then
        return false
      elseif not installPath and not hasCatalogEntryFile(basePath, entry) then
        return false
      end
      if entryType == 'appearances' then
        hasAppearances = true
      elseif entryType == 'staticdata' then
        hasStaticData = true
      end
    end
  end

  return hasAppearances and hasStaticData
end

local function hasModernClientFiles(version)
  return hasModernClientFilesAtPath(string.format('data/things/%d/', version), true)
end

local hasInstalledModernClientFiles = hasModernClientFiles

local function markClientVersionInstalled(config, version)
  local markerPath = completeMarkerPath(version)
  local contents = string.format('client=%d\n', version)
  if shouldInstallInWorkDir(config) and g_resources.writeFileContentsToWorkDir then
    return g_resources.writeFileContentsToWorkDir(markerPath, contents)
  end

  g_resources.makeDir(string.format('/data/things/%d', version))
  return g_resources.writeFileContents('/' .. markerPath, contents)
end

local function normalizeVersionKey(version)
  return tostring(tonumber(version) or version)
end

local function readVersionEntry(manifest, version)
  local key = normalizeVersionKey(version)
  if type(manifest) ~= 'table' then
    return nil
  end
  if type(manifest.versions) == 'table' then
    return manifest.versions[key] or manifest.versions[tonumber(version)]
  end
  return manifest[key] or manifest[tonumber(version)]
end

local function normalizeDescriptor(config, version, descriptor)
  if type(descriptor) ~= 'table' then
    return nil
  end

  descriptor.version = tonumber(version)
  descriptor.installSounds = descriptor.installSounds
  if descriptor.installSounds == nil then
    descriptor.installSounds = config.installSounds
  end

  descriptor.baseUrl = descriptor.baseUrl or descriptor.rawBaseUrl
  if not descriptor.baseUrl and descriptor.tag and config.repository then
    descriptor.baseUrl = string.format(config.rawBaseUrl, config.repository, descriptor.tag)
  end

  descriptor.manifestUrl = descriptor.manifestUrl or descriptor.manifest or descriptor.assetsManifest
  descriptor.manifestSha256 = descriptor.manifestSha256 or descriptor.assetsManifestSha256
  descriptor.manifestSha256Url = descriptor.manifestSha256Url or descriptor.assetsManifestSha256Url

  if type(descriptor.archive) == 'table' then
    descriptor.archiveUrl = descriptor.archive.url or descriptor.archiveUrl
    descriptor.archiveSha256 = descriptor.archive.sha256 or descriptor.archiveSha256
    descriptor.archiveThingsPrefix = descriptor.archive.thingsPrefix or descriptor.archiveThingsPrefix
    descriptor.archiveSoundsPrefix = descriptor.archive.soundsPrefix or descriptor.archiveSoundsPrefix
  end

  descriptor.archiveUrl = descriptor.archiveUrl or descriptor.zipUrl or descriptor.packageUrl
  descriptor.archiveThingsPrefix = descriptor.archiveThingsPrefix or 'assets'
  descriptor.archiveSoundsPrefix = descriptor.archiveSoundsPrefix or 'sounds'
  descriptor.installArchiveExtras = descriptor.installArchiveExtras
  if descriptor.installArchiveExtras == nil then
    descriptor.installArchiveExtras = config.installArchiveExtras
  end
  descriptor.archiveExtraPrefixes = descriptor.archiveExtraPrefixes or config.archiveExtraPrefixes
  descriptor.archiveExtrasDestination = descriptor.archiveExtrasDestination or config.archiveExtrasDestination
  descriptor.treeUrl = descriptor.treeUrl or descriptor.packagedFilesUrl
  if not descriptor.treeUrl and descriptor.tag and config.repository then
    descriptor.treeUrl = string.format('https://api.github.com/repos/%s/git/trees/%s?recursive=1', config.repository, descriptor.tag)
  end
  descriptor.installPackagedFiles = descriptor.installPackagedFiles
  if descriptor.installPackagedFiles == nil then
    descriptor.installPackagedFiles = config.installPackagedFiles
  end
  descriptor.packagedFilePrefixes = descriptor.packagedFilePrefixes or config.packagedFilePrefixes
  descriptor.packagedFilesDestination = descriptor.packagedFilesDestination or config.packagedFilesDestination
  descriptor.packagedFilesRequired = descriptor.packagedFilesRequired
  if descriptor.packagedFilesRequired == nil then
    descriptor.packagedFilesRequired = config.packagedFilesRequired
  end

  return descriptor
end

local function findReleaseArchive(release)
  if type(release.assets) ~= 'table' then
    return nil
  end

  local fallback
  for _, asset in ipairs(release.assets) do
    local name = tostring(asset.name or ''):lower()
    local url = asset.browser_download_url
    if url and isArchivePath(name) then
      fallback = fallback or url
      if not name:find('mac', 1, true) and not name:find('.app.zip', 1, true) then
        return url
      end
    end
  end

  return fallback
end

local function codeloadZipUrl(repository, tag)
  if not repository or not tag then
    return nil
  end
  return string.format('https://codeload.github.com/%s/zip/refs/tags/%s', repository, tag)
end

local function descriptorFromRelease(config, version, release)
  local tag = release.tag_name
  if not tag or tag == '' then
    return nil
  end

  local baseUrl = string.format(config.rawBaseUrl, config.repository, tag)
  return normalizeDescriptor(config, version, {
    tag = tag,
    baseUrl = baseUrl,
    manifestUrl = baseUrl .. 'assets.json',
    manifestSha256Url = baseUrl .. 'assets.json.sha256',
    treeUrl = string.format('https://api.github.com/repos/%s/git/trees/%s?recursive=1', config.repository, tag),
    archiveUrl = findReleaseArchive(release) or codeloadZipUrl(config.repository, tag)
  })
end

local function findReleaseForVersion(releases, version)
  local label = versionLabel(version):lower()
  for _, release in ipairs(releases) do
    local tag = tostring(release.tag_name or ''):lower()
    local name = tostring(release.name or ''):lower()
    if tag:find(label, 1, true) or name:find(label, 1, true) then
      return release
    end
  end
  return nil
end

local function overallProgress(index, total, fileProgress)
  total = math.max(tonumber(total) or 1, 1)
  index = math.max(tonumber(index) or 1, 1)
  fileProgress = math.max(0, math.min(100, tonumber(fileProgress) or 0))
  return clampPercent(((index - 1) + (fileProgress / 100)) * 100 / total)
end

local function stopDownloadBusy()
  if activeDownload and activeDownload.busyEvent then
    removeEvent(activeDownload.busyEvent)
    activeDownload.busyEvent = nil
  end
  if activeDownload and activeDownload.busySpinEvent then
    removeEvent(activeDownload.busySpinEvent)
    activeDownload.busySpinEvent = nil
  end
  if activeDownload and activeDownload.window and activeDownload.window.busyIndicator then
    activeDownload.window.busyIndicator:setRotation(0)
    activeDownload.window.busyIndicator:setVisible(false)
  end
end

local function renderDownloadStatus(status, percent, detail)
  if not activeDownload or not activeDownload.window or not activeDownload.window.content then
    return
  end

  local width = DOWNLOAD_WINDOW_WIDTH
  if rootWidget then
    width = math.min(width, math.max(260, rootWidget:getWidth() - 40))
  end

  activeDownload.window:setWidth(width)
  activeDownload.window.content:setTextWrap(true)
  activeDownload.window.content:setWidth(width - DOWNLOAD_TEXT_MARGIN)
  if percent then
    percent = clampPercent(percent)
    activeDownload.window.content:setText(string.format('%s\n%d%%', status, percent))
  elseif detail and detail ~= '' then
    activeDownload.window.content:setText(status .. '\n' .. detail)
  else
    activeDownload.window.content:setText(status)
  end
  activeDownload.window.content:resizeToText()
  activeDownload.window:setHeight(DOWNLOAD_WINDOW_HEIGHT)
  if percent and activeDownload.window.busyIndicator then
    activeDownload.window.busyIndicator:setRotation(0)
    activeDownload.window.busyIndicator:setVisible(false)
  end
  if activeDownload.window.progressBar then
    if percent then
      updateDownloadBar(activeDownload.window, percent)
    else
      updateDownloadBar(activeDownload.window, 0)
    end
  end
end

local function setDownloadProgress(status, percent, detail)
  stopDownloadBusy()
  renderDownloadStatus(status, percent, detail)
end

local function scheduleDownloadStep(callback)
  scheduleEvent(function()
    if not activeDownload or activeDownload.canceled then
      return
    end
    callback()
  end, 50)
end

local function startBusyIndicatorSpin()
  if not activeDownload or activeDownload.busySpinEvent then
    return
  end

  local function spin()
    if not activeDownload or not activeDownload.window or not activeDownload.window.busyIndicator then
      return
    end

    activeDownload.busyRotation = ((activeDownload.busyRotation or 0) + BUSY_INDICATOR_ROTATION_STEP) % 360
    activeDownload.window.busyIndicator:setRotation(activeDownload.busyRotation)
    activeDownload.busySpinEvent = scheduleEvent(spin, BUSY_INDICATOR_ROTATION_DELAY)
  end

  spin()
end

local function setDownloadBusy(status, detail)
  if not activeDownload then
    return
  end

  activeDownload.busyStatus = status
  activeDownload.busyDetail = detail
  startBusyIndicatorSpin()
  if activeDownload.busyEvent then
    return
  end

  local frames = { '', '.', '..', '...' }

  local function tick()
    if not activeDownload or not activeDownload.window then
      return
    end

    activeDownload.busyFrame = ((activeDownload.busyFrame or 0) % #frames) + 1
    renderDownloadStatus((activeDownload.busyStatus or status) .. frames[activeDownload.busyFrame], nil, activeDownload.busyDetail)
    updateDownloadBar(activeDownload.window, 0)
    if activeDownload.window.busyIndicator then
      activeDownload.window.busyIndicator:setVisible(true)
      activeDownload.window.busyIndicator:raise()
    end
    activeDownload.busyEvent = scheduleEvent(tick, 350)
  end

  tick()
end

local function logArchiveHeartbeat(message)
  if not activeDownload then
    return
  end

  local now = g_clock.millis()
  if activeDownload.lastArchiveHeartbeat and now - activeDownload.lastArchiveHeartbeat < 5000 then
    return
  end

  activeDownload.lastArchiveHeartbeat = now
  logInfo(message)
end

local function finishDownload(ok, message)
  local callback = activeDownload and activeDownload.callback
  if ok then
    logInfo(message or 'Asset download finished.')
  elseif message then
    logError(message)
  end
  stopDownloadBusy()
  if activeDownload and activeDownload.window then
    activeDownload.window:destroy()
  end
  activeDownload = nil
  if callback then
    callback(ok, ok and message or userFacingError(message))
  end
end

local function cancelDownload()
  if activeDownload then
    activeDownload.canceled = true
    if activeDownload.operationId then
      HTTP.cancel(activeDownload.operationId)
    end
    activeDownload.window = nil
  end
  finishDownload(false, tr('Download canceled.'))
end

local function verifyDownloadedSha256(downloadPath, expectedSha256)
  if not expectedSha256 or expectedSha256 == '' then
    return true
  end

  local ok, contents = pcall(function()
    return g_resources.readFileContents('/downloads/' .. downloadPath)
  end)
  if not ok then
    return false, contents
  end

  local actualSha256 = g_crypt.sha256(contents)
  if actualSha256 ~= expectedSha256 then
    return false, string.format('Invalid SHA-256 for %s. Expected %s, got %s.', downloadPath, expectedSha256, actualSha256)
  end

  return true
end

local function verifyInstalledSha256(destinationPath, expectedSha256, deleteOnMismatch)
  if not expectedSha256 or expectedSha256 == '' then
    return true
  end

  local actualSha256
  if g_resources.fileSha256InWorkDir then
    actualSha256 = g_resources.fileSha256InWorkDir(destinationPath)
  else
    actualSha256 = g_resources.fileSha256('/' .. destinationPath)
  end
  if actualSha256 ~= expectedSha256 then
    if deleteOnMismatch ~= false then
      g_resources.deleteFile('/' .. destinationPath)
    end
    return false, string.format('Invalid installed SHA-256 for %s. Expected %s, got %s.', destinationPath, expectedSha256, actualSha256)
  end

  return true
end

local function writeDownloadedFile(config, downloadPath, destinationPath, decompressLzma)
  if shouldInstallInWorkDir(config) and g_resources.writeDownloadedFileToWorkDir then
    return g_resources.writeDownloadedFileToWorkDir(downloadPath, destinationPath, decompressLzma == true)
  end
  return g_resources.writeDownloadedFile(downloadPath, destinationPath, decompressLzma == true)
end

local function extractDownloadedArchive(config, downloadPath, destinationPath, entryPrefix, stripPrefix)
  if shouldInstallInWorkDir(config) and g_resources.extractDownloadedArchiveToWorkDir then
    return g_resources.extractDownloadedArchiveToWorkDir(downloadPath, destinationPath, entryPrefix or '', stripPrefix == true)
  end
  return g_resources.extractDownloadedArchive(downloadPath, destinationPath, entryPrefix or '', stripPrefix == true)
end

local function installDownloadedFile(config, downloadPath, destinationPath, decompressLzma, expectedFileSha256, allowHashMismatch)
  if not writeDownloadedFile(config, downloadPath, destinationPath, decompressLzma) then
    return false, 'Unable to write downloaded asset: ' .. destinationPath
  end

  local ok, hashError = verifyInstalledSha256(destinationPath, expectedFileSha256, not allowHashMismatch)
  if not ok and allowHashMismatch and not hashError:find(HTTP_NOT_FOUND_SHA256, 1, true) then
    logWarning(hashError .. ' Continuing with raw fallback because allowRawFallbackHashMismatch is enabled.')
    return true
  end

  return ok, hashError
end

local function installDownloadedArchive(config, downloadPath, destinationPath, entryPrefix, stripPrefix, expectedPath, expectedSha256)
  if not extractDownloadedArchive(config, downloadPath, destinationPath, entryPrefix, stripPrefix) then
    return false, 'Unable to extract downloaded archive: ' .. destinationPath
  end

  if expectedPath then
    return verifyInstalledSha256(expectedPath, expectedSha256)
  end

  return true
end

local function shouldInstallManifestEntry(entry, version, config)
  local localfile = entry.localfile or entry.file or entry.path
  if type(localfile) ~= 'string' then
    return nil
  end

  if startsWith(localfile, 'assets/') then
    local relativePath = localfile:sub(#'assets/' + 1)
    local archive = isArchivePath(localfile) or isArchivePath(entry.url)
    local basePath = string.format('data/things/%d', version)
    return {
      sourcePath = localfile,
      relativePath = relativePath,
      destinationPath = archive and (basePath .. '/' .. parentPath(relativePath)) or (basePath .. '/' .. relativePath),
      extractedFilePath = archive and not isArchivePath(localfile) and (basePath .. '/' .. localfile:sub(#'assets/' + 1)) or nil,
      archive = archive,
      sound = false
    }
  end

  if config.installSounds ~= false and startsWith(localfile, 'sounds/') then
    local relativePath = localfile:sub(#'sounds/' + 1)
    local archive = isArchivePath(localfile) or isArchivePath(entry.url)
    local basePath = string.format('data/sounds/%d', version)
    return {
      sourcePath = localfile,
      relativePath = relativePath,
      destinationPath = archive and (basePath .. '/' .. parentPath(relativePath)) or (basePath .. '/' .. relativePath),
      extractedFilePath = archive and not isArchivePath(localfile) and (basePath .. '/' .. localfile:sub(#'sounds/' + 1)) or nil,
      archive = archive,
      sound = true
    }
  end

  local archive = isArchivePath(localfile) or isArchivePath(entry.url)
  if config.installPackagedFiles ~= false and archive and matchesAnyPrefix(localfile, config.packagedFilePrefixes) then
    local destination = string.format(config.packagedFilesDestination or '', version)
    local finalPath = isArchivePath(localfile) and stripArchiveExtension(localfile) or localfile
    return {
      sourcePath = localfile,
      relativePath = localfile,
      destinationPath = joinUrl(destination, parentPath(localfile)),
      extractedFilePath = not isArchivePath(localfile) and joinUrl(destination, finalPath) or nil,
      archive = true,
      packaged = true
    }
  end

  return nil
end

local function buildManifestDownload(entry, descriptor, selectedEntry, usePackedUrl)
  local sourcePath = selectedEntry.sourcePath
  local downloadUrl = joinUrl(descriptor.baseUrl, sourcePath)
  local decompressLzma = false
  local extractArchive = selectedEntry.archive == true
  local expectedDownloadSha256
  local expectedFileSha256

  if usePackedUrl and entry.url then
    sourcePath = entry.url
    downloadUrl = joinUrl(descriptor.baseUrl, sourcePath)
    expectedDownloadSha256 = entry.packedhash
    extractArchive = isArchivePath(sourcePath)
    if extractArchive then
      expectedFileSha256 = selectedEntry.extractedFilePath and entry.unpackedhash or nil
    elseif endsWith(sourcePath, '.lzma') and entry.unpack ~= false then
      decompressLzma = true
      expectedFileSha256 = entry.unpackedhash
    else
      expectedFileSha256 = entry.packedhash
    end
  else
    extractArchive = isArchivePath(sourcePath)
    if extractArchive then
      expectedDownloadSha256 = entry.packedhash or entry.unpackedhash
      expectedFileSha256 = selectedEntry.extractedFilePath and entry.unpackedhash or nil
    elseif entry.unpack == false then
      expectedDownloadSha256 = entry.packedhash
      expectedFileSha256 = entry.packedhash
    else
      expectedDownloadSha256 = entry.unpackedhash or entry.packedhash
      expectedFileSha256 = entry.unpackedhash or entry.packedhash
    end
  end

  return {
    url = downloadUrl,
    sourcePath = sourcePath,
    decompressLzma = decompressLzma,
    extractArchive = extractArchive,
    archiveEntryPrefix = entry.archiveEntryPrefix or entry.archivePrefix or '',
    stripArchivePrefix = entry.stripArchivePrefix,
    expectedDownloadSha256 = expectedDownloadSha256,
    expectedFileSha256 = expectedFileSha256,
    destinationPath = selectedEntry.destinationPath,
    extractedFilePath = selectedEntry.extractedFilePath
  }
end

local function installManifestEntries(config, descriptor, files, index, installed, total, callback)
  if activeDownload and activeDownload.canceled then
    return callback(false, tr('Download canceled.'))
  end

  local entry = files[index]
  if not entry then
    return callback(true, string.format('Installed %d assets.', installed))
  end

  local selectedEntry = shouldInstallManifestEntry(entry, descriptor.version, descriptor)
  if not selectedEntry then
    return installManifestEntries(config, descriptor, files, index + 1, installed, total, callback)
  end

  local preferPacked = descriptor.preferPackedManifestUrls or config.preferPackedManifestUrls
  local directDownload = buildManifestDownload(entry, descriptor, selectedEntry, preferPacked)
  local fallbackDownload
  if config.allowRawFallbackHashMismatch ~= false and not directDownload.extractArchive and not isLzmaPath(directDownload.sourcePath) then
    directDownload.allowHashMismatch = true
  end
  if entry.url then
    fallbackDownload = buildManifestDownload(entry, descriptor, selectedEntry, not preferPacked)
    if fallbackDownload.sourcePath == directDownload.sourcePath then
      fallbackDownload = nil
    elseif config.allowRawFallbackHashMismatch ~= false and not isArchivePath(fallbackDownload.sourcePath) and not isLzmaPath(fallbackDownload.sourcePath) then
      fallbackDownload.allowHashMismatch = true
    end
  end
  if directDownload.expectedFileSha256 and g_resources.fileSha256('/' .. directDownload.destinationPath) == directDownload.expectedFileSha256 then
    return installManifestEntries(config, descriptor, files, index + 1, installed, total, callback)
  end

  local function downloadEntry(downloadInfo, nextFallback, retriesLeft)
    local fileName = string.format('asset-downloads/%d/%04d-%s', descriptor.version, index, g_resources.getFileName(downloadInfo.sourcePath))
    setDownloadProgress(string.format('Downloading assets for client %s', versionLabel(descriptor.version)), overallProgress(index, total, 0))

    activeDownload.operationId = httpDownload(config, downloadInfo.url, fileName, function(path, checksum, err)
      if not activeDownload then
        return
      end

      activeDownload.operationId = nil

      if activeDownload.canceled then
        return callback(false, tr('Download canceled.'))
      end

      if err then
        if retriesLeft > 0 then
          return downloadEntry(downloadInfo, nextFallback, retriesLeft - 1)
        end
        if nextFallback then
          logWarning(string.format('Download failed for %s: %s. Trying %s.', downloadInfo.sourcePath, err, nextFallback.sourcePath))
          return downloadEntry(nextFallback, nil, config.retries or 0)
        end
        return callback(false, err)
      end

      local ok, hashError = verifyDownloadedSha256(path, downloadInfo.expectedDownloadSha256)
      if not ok then
        if nextFallback then
          logWarning(hashError .. ' Trying ' .. nextFallback.sourcePath .. '.')
          return downloadEntry(nextFallback, nil, config.retries or 0)
        end
        if downloadInfo.allowHashMismatch and not hashError:find(HTTP_NOT_FOUND_SHA256, 1, true) then
          logWarning(hashError .. ' Continuing with raw fallback because allowRawFallbackHashMismatch is enabled.')
          ok = true
        else
          return callback(false, hashError)
        end
      end

      if not ok then
        return callback(false, hashError)
      end

      if downloadInfo.extractArchive then
        ok, hashError = installDownloadedArchive(
          config,
          path,
          downloadInfo.destinationPath,
          downloadInfo.archiveEntryPrefix,
          downloadInfo.stripArchivePrefix,
          downloadInfo.extractedFilePath,
          downloadInfo.expectedFileSha256
        )
      else
        ok, hashError = installDownloadedFile(config, path, downloadInfo.destinationPath, downloadInfo.decompressLzma, downloadInfo.expectedFileSha256, downloadInfo.allowHashMismatch)
      end
      if not ok then
        if nextFallback then
          logWarning(hashError .. ' Trying ' .. nextFallback.sourcePath .. '.')
          return downloadEntry(nextFallback, nil, config.retries or 0)
        end
        return callback(false, hashError)
      end

      return installManifestEntries(config, descriptor, files, index + 1, installed + 1, total, callback)
    end, function(progress, speed)
      setDownloadProgress(string.format('Downloading assets for client %s', versionLabel(descriptor.version)), overallProgress(index, total, progress))
    end)
  end

  downloadEntry(directDownload, fallbackDownload, config.retries or 0)
end

local function fetchManifestSha256(config, descriptor, callback)
  if descriptor.manifestSha256 or not descriptor.manifestSha256Url then
    return callback(descriptor.manifestSha256)
  end

  activeDownload.operationId = httpGet(config, descriptor.manifestSha256Url, function(data, err)
    if not activeDownload then
      return
    end
    activeDownload.operationId = nil
    if err then
      return callback(nil)
    end
    data = tostring(data or ''):match('^%s*(.-)%s*$')
    callback(data ~= '' and data or nil)
  end)
end

local function installFromManifest(config, descriptor, callback)
  if not descriptor.manifestUrl then
    return callback(false, 'No asset manifest URL configured.')
  end

  setDownloadProgress(string.format('Fetching assets manifest for client %s', versionLabel(descriptor.version)), 0)
  activeDownload.operationId = httpGet(config, descriptor.manifestUrl, function(data, err)
    if not activeDownload then
      return
    end
    activeDownload.operationId = nil
    if err then
      return callback(false, err)
    end

    fetchManifestSha256(config, descriptor, function(expectedSha256)
      if expectedSha256 then
        local actualSha256 = g_crypt.sha256(data)
        if actualSha256 ~= expectedSha256 then
          local hashError = string.format('Invalid assets manifest SHA-256 for %s. Expected %s, got %s.', descriptor.manifestUrl, expectedSha256, actualSha256)
          if descriptor.strictManifestSha256 or config.strictManifestSha256 then
            return callback(false, hashError)
          end
          logWarning(hashError .. ' Continuing because strictManifestSha256 is disabled.')
        end
      end

      local ok, manifest = pcall(function()
        return json.decode(data)
      end)
      if not ok or type(manifest) ~= 'table' or type(manifest.files) ~= 'table' then
        return callback(false, 'Invalid assets manifest.')
      end

      installManifestEntries(config, descriptor, manifest.files, 1, 0, #manifest.files, callback)
    end)
  end)
end

local function installFromArchive(config, descriptor, callback)
  if not descriptor.archiveUrl then
    return callback(false, 'No asset archive URL configured.')
  end

  local archiveName = string.format('asset-downloads/%d/%s', descriptor.version, g_resources.getFileName(descriptor.archiveUrl))
  logInfo(string.format('Downloading asset archive for client %s from %s.', versionLabel(descriptor.version), descriptor.archiveUrl))
  setDownloadBusy('Downloading files', string.format('Client %s archive', versionLabel(descriptor.version)))

  activeDownload.operationId = httpDownload(config, descriptor.archiveUrl, archiveName, function(path, checksum, err)
    if not activeDownload then
      return
    end

    activeDownload.operationId = nil

    if err then
      return callback(false, err)
    end

    logInfo(string.format('Asset archive download completed for client %s. Verifying archive.', versionLabel(descriptor.version)))
    setDownloadBusy('Verifying downloaded archive', string.format('Client %s', versionLabel(descriptor.version)))
    local ok, hashError = verifyDownloadedSha256(path, descriptor.archiveSha256)
    if not ok then
      return callback(false, hashError)
    end

    local label = versionLabel(descriptor.version)
    local thingsDestination = string.format('data/things/%d', descriptor.version)
    local soundsDestination = string.format('data/sounds/%d', descriptor.version)

    local function finishArchiveInstall()
      setDownloadProgress('Finishing asset install', 100)
      logInfo(string.format('Finished archive install for client %s.', label))
      callback(true)
    end

    local function extractArchiveExtras()
      if descriptor.installArchiveExtras == false or not descriptor.archiveExtraPrefixes then
        return finishArchiveInstall()
      end

      local prefixes = descriptor.archiveExtraPrefixes
      if type(prefixes) == 'string' then
        prefixes = { prefixes }
      end

      local destination = descriptor.archiveExtrasDestination or ''
      destination = string.format(destination, descriptor.version)

      local function extractNextExtra(extraIndex)
        local prefix = prefixes[extraIndex]
        if not prefix then
          return finishArchiveInstall()
        end

        logInfo(string.format('Extracting archive extras for client %s: %s. This can take a while.', label, prefix))
        setDownloadBusy('Extracting files', string.format('Client %s extras: %s', label, prefix))
        scheduleDownloadStep(function()
          extractDownloadedArchive(config, path, destination, prefix, false)
          logInfo(string.format('Finished archive extras for client %s: %s.', label, prefix))
          logInfo(string.format('Archive extras install path: %s.', physicalInstallPath(destination)))
          extractNextExtra(extraIndex + 1)
        end)
      end

      extractNextExtra(1)
    end

    local function extractSoundAssets()
      if descriptor.installSounds == false then
        return extractArchiveExtras()
      end

      logInfo(string.format('Extracting sound assets for client %s. This can take a while.', label))
      setDownloadBusy('Extracting files', string.format('Client %s sounds', label))
      scheduleDownloadStep(function()
        if extractDownloadedArchive(config, path, soundsDestination, descriptor.archiveSoundsPrefix or 'sounds', true) then
          logInfo(string.format('Finished extracting sound assets for client %s.', label))
          logInfo(string.format('Sound assets install path: %s.', physicalInstallPath(soundsDestination)))
        else
          logWarning(string.format('No sound assets were extracted for client %s.', label))
        end
        extractArchiveExtras()
      end)
    end

    local function extractAssetHashIdentifier()
      logInfo(string.format('Extracting asset hash identifier for client %s.', label))
      extractDownloadedArchive(config, path, thingsDestination, 'assets.json.sha256', false)
      extractSoundAssets()
    end

    logInfo(string.format('Extracting things assets for client %s. This can take a while.', label))
    setDownloadBusy('Extracting files', string.format('Client %s assets', label))
    scheduleDownloadStep(function()
      if not extractDownloadedArchive(config, path, thingsDestination, descriptor.archiveThingsPrefix or 'assets', true) then
        return callback(false, 'Unable to extract assets from archive.')
      end

      logInfo(string.format('Finished extracting things assets for client %s.', label))
      logInfo(string.format('Things install path: %s.', physicalInstallPath(thingsDestination)))
      extractAssetHashIdentifier()
    end)
  end, function(progress, speed)
    setDownloadBusy('Downloading files', string.format('Client %s archive', versionLabel(descriptor.version)))
    logArchiveHeartbeat('Archive download still in progress. GitHub did not provide a reliable total size, so the UI is in indeterminate mode.')
  end)
end

local function collectPackagedFiles(descriptor, tree)
  local packagedFiles = {}
  if type(tree) ~= 'table' or type(tree.tree) ~= 'table' then
    return packagedFiles
  end

  for _, item in ipairs(tree.tree) do
    local path = item.path
    if item.type == 'blob' and isArchivePath(path) and matchesAnyPrefix(path, descriptor.packagedFilePrefixes) then
      packagedFiles[#packagedFiles + 1] = path
    end
  end

  table.sort(packagedFiles)
  return packagedFiles
end

local function installPackagedFileList(config, descriptor, files, index, callback)
  local path = files[index]
  if not path then
    return callback(true)
  end

  if activeDownload and activeDownload.canceled then
    return callback(false, tr('Download canceled.'))
  end

  local url = joinUrl(descriptor.baseUrl, path)
  local downloadName = string.format('asset-downloads/%d/packaged-%04d-%s', descriptor.version, index, g_resources.getFileName(path))
  logInfo(string.format('Downloading packaged file %d/%d for client %s: %s.', index, #files, versionLabel(descriptor.version), path))
  setDownloadBusy('Downloading files', string.format('Client %s packaged files', versionLabel(descriptor.version)))

  activeDownload.operationId = httpDownload(config, url, downloadName, function(downloadPath, checksum, err)
    if not activeDownload then
      return
    end

    activeDownload.operationId = nil

    if err then
      return callback(false, err)
    end

    local destination = string.format(descriptor.packagedFilesDestination or '', descriptor.version)
    local destinationPath = joinUrl(destination, parentPath(path))
    logInfo(string.format('Extracting packaged file %d/%d for client %s: %s.', index, #files, versionLabel(descriptor.version), path))
    setDownloadBusy('Extracting files', string.format('Client %s packaged files', versionLabel(descriptor.version)))

    scheduleDownloadStep(function()
      local ok, extractError = installDownloadedArchive(config, downloadPath, destinationPath, '', false)
      if not ok then
        return callback(false, extractError)
      end

      logInfo(string.format('Finished packaged file %d/%d for client %s: %s.', index, #files, versionLabel(descriptor.version), path))
      logInfo(string.format('Packaged file install path: %s.', physicalInstallPath(destinationPath)))
      installPackagedFileList(config, descriptor, files, index + 1, callback)
    end)
  end, function(progress, speed)
    setDownloadBusy('Downloading files', string.format('Client %s packaged files', versionLabel(descriptor.version)))
    logArchiveHeartbeat(string.format('Packaged file download still in progress (%d/%d): %s.', index, #files, path))
  end)
end

local function installPackagedFiles(config, descriptor, callback)
  if descriptor.installPackagedFiles == false or not descriptor.treeUrl or not descriptor.baseUrl then
    return callback(true)
  end

  activeDownload.operationId = httpGetJSON(config, descriptor.treeUrl, function(data, err)
    if not activeDownload then
      return
    end

    activeDownload.operationId = nil

    if err then
      if descriptor.packagedFilesRequired then
        return callback(false, err)
      end
      return callback(true)
    end

    local packagedFiles = collectPackagedFiles(descriptor, data)
    if #packagedFiles == 0 then
      return callback(true)
    end

    installPackagedFileList(config, descriptor, packagedFiles, 1, callback)
  end)
end

local function installDescriptor(config, descriptor, callback)
  local function finishWithPackagedFiles(ok, message)
    if not ok then
      return callback(false, message)
    end

    installPackagedFiles(config, descriptor, function(packagedOk, packagedMessage)
      callback(packagedOk, packagedMessage or message)
    end)
  end

  local function manifestFallback()
    installFromManifest(config, descriptor, function(ok, message)
      if ok or not descriptor.archiveUrl then
        return finishWithPackagedFiles(ok, message)
      end
      installFromArchive(config, descriptor, finishWithPackagedFiles)
    end)
  end

  if descriptor.preferArchive or config.preferArchive then
    return installFromArchive(config, descriptor, function(ok, message)
      if ok or not descriptor.manifestUrl then
        return finishWithPackagedFiles(ok, message)
      end
      manifestFallback()
    end)
  end

  manifestFallback()
end

local function resolveFromCustomManifest(config, version, callback)
  if not config.manifestUrl then
    return callback(nil)
  end

  activeDownload.operationId = httpGetJSON(config, config.manifestUrl, function(data, err)
    if not activeDownload then
      return
    end
    activeDownload.operationId = nil
    if err then
      return callback(nil, err)
    end

    local descriptor = normalizeDescriptor(config, version, readVersionEntry(data, version))
    callback(descriptor)
  end)
end

local function resolveFromGitHubReleases(config, version, callback)
  if not config.releasesUrl then
    return callback(nil)
  end

  local cacheKey = tostring(config.releasesUrl or config.repository or '')
  if releasesCache[cacheKey] then
    local release = findReleaseForVersion(releasesCache[cacheKey], version)
    return callback(release and descriptorFromRelease(config, version, release) or nil)
  end

  activeDownload.operationId = httpGetJSON(config, config.releasesUrl, function(data, err)
    if not activeDownload then
      return
    end
    activeDownload.operationId = nil
    if err then
      return callback(nil, err)
    end

    releasesCache[cacheKey] = data
    local release = findReleaseForVersion(releasesCache[cacheKey], version)
    callback(release and descriptorFromRelease(config, version, release) or nil)
  end)
end

local function resolveDescriptor(config, version, callback)
  resolveFromCustomManifest(config, version, function(descriptor)
    if descriptor then
      return callback(descriptor)
    end
    resolveFromGitHubReleases(config, version, callback)
  end)
end

function isEnabled()
  return cloneConfig().enabled ~= false
end

function isClientVersionInstalled(version)
  version = tonumber(version)
  if not version then
    return false
  end

  if version >= 1281 then
    return hasInstalledModernClientFiles(version)
  end

  return g_resources.fileExists(string.format('/data/things/%d/Tibia.dat', version)) and
         g_resources.fileExists(string.format('/data/things/%d/Tibia.spr', version))
end

function getInstalledClientVersions()
  local installed = {}
  local paths = { '/data/things/' }
  for _, path in ipairs(paths) do
    for _, dirItem in ipairs(g_resources.listDirectoryFiles(path)) do
      if tonumber(dirItem) then
        installed[tostring(dirItem)] = true
      end
    end
  end
  return installed
end

function ensureClientVersion(version, callback)
  version = tonumber(version)
  if not version then
    return callback(false, 'Invalid client version.')
  end

  local config = cloneConfig()
  if config.enabled == false or isClientVersionInstalled(version) then
    return callback(true)
  end

  if activeDownload then
    return callback(false, 'Another asset download is already running.')
  end

  local promptBox
  local message = string.format('Assets for client %s are not installed.\nDownload them now?', versionLabel(version))
  local function startDownload()
    if promptBox then
      local box = promptBox
      promptBox = nil
      box:ok()
    end

    if activeDownload then
      return
    end

    activeDownload = {
      version = version,
      callback = callback,
      canceled = false
    }

    logInfo(string.format('Starting asset download for client %s.', versionLabel(version)))
    activeDownload.window = createDownloadWindow()
    connect(activeDownload.window, {
      onCancel = cancelDownload
    })

    resolveDescriptor(config, version, function(descriptor, err)
      if not descriptor then
        return finishDownload(false, err or string.format('No assets source found for client %s.', versionLabel(version)))
      end

      installDescriptor(config, descriptor, function(ok, installError)
        if not ok then
          return finishDownload(false, installError or 'Unable to install client assets.')
        end

        if not hasModernClientFiles(version) then
          return finishDownload(false, 'Assets were downloaded but the client files are still incomplete. Missing catalog-content.json, assets.json.sha256, or required catalog files.')
        end

        local markerPath = completeMarkerPath(version)
        if not installFileExists(markerPath) then
          markClientVersionInstalled(config, version)
          if not installFileExists(markerPath) then
            logWarning('Assets were downloaded but the install marker could not be written.')
          end
        end

        logInfo(string.format('Client %s installed at: %s.', versionLabel(version), physicalInstallPath(string.format('data/things/%d', version))))
        if config.installSounds ~= false then
          logInfo(string.format('Client %s sounds installed at: %s.', versionLabel(version), physicalInstallPath(string.format('data/sounds/%d', version))))
        end
        if config.installArchiveExtras ~= false then
          logInfo(string.format('Client %s extra files installed at: %s.', versionLabel(version), physicalInstallPath('bin')))
        end

        finishDownload(true)
      end)
    end)
  end

  local function cancelPrompt()
    if promptBox then
      local box = promptBox
      promptBox = nil
      box:cancel()
    end
    callback(false, tr('Assets are required for this client version.'))
  end

  promptBox = displayGeneralBox(tr('Missing Assets'), message, {
    { text = tr('Download'), callback = startDownload },
    { text = tr('Cancel'), callback = cancelPrompt }
  }, startDownload, cancelPrompt)
end
