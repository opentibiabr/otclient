-- =========================================================================
-- Map Generator Studio - Controller
-- GUI wrapper for otclientrc.lua map generation pipeline.
-- =========================================================================

MapGenUI = Controller:new()

MapGenUI.logEntries = {}

-- Internal storage (not bound to HTML directly)
local _mapPath          = ''
local _mapParts         = {}
local mapPreviewWidget  = nil   -- UIMap widget for live tile preview
local satMinimapWidget  = nil   -- UIMinimap for satellite preview
local _previewIdx       = 0     -- cycles 0-9 for temp PNG filenames
local _prevPreviewFile  = nil   -- last temp PNG to delete on next render
local _ramBaseline      = 0     -- process RAM at time of last map load
local _stolenGameMapPanel = nil -- original gameMapPanel temporarily renamed for offline preview
local _mountedExternalDirs = {}
local _preparedMinPos = nil
local _preparedMaxPos = nil
local _preparedAreasCount = 0

local function formatMemoryDeltaFromMb(deltaMb)
    local sign = deltaMb >= 0 and "+" or "-"
    local absMb = math.abs(deltaMb)
    if absMb >= 1024 then
        local gb = absMb / 1024
        local s = string.format("%s%.3f GB", sign, gb)
        return s:gsub("%.", ",")
    end
    return string.format("%s%.0f MB", sign, absMb)
end

-- =========================================================================
-- Lifecycle
-- =========================================================================

function MapGenUI:onInit()
    self.ramText = 'RAM: --'
    self.warningText = 'Warning: estimates unavailable until coordinates are valid.'
    self.fullGenerateWarnText = 'Warning: prepare client to compute generation estimates.'
    self.areaGenerateWarnText = 'Warning (approx.): AREA PNG -- MB, RAM +-- MB, ETA ~--s'
    self.floorGenerateWarnText = 'Warning (approx.): Single floor PNG -- MB, RAM +-- MB, ETA ~--s'
    self.previewInfoText = 'Map info: prepare client first.'
    self.satViewMode = self.satViewMode or 'surface'
    self.progressBarWidth = 0
    self:loadHtml('mapgen.html')
    self:addLog('Map Generator Studio loaded. Configure and press Prepare Client.', '#88ccff')
    self:onVersionChanged(self.clientVersion or '1098')

    -- Update RAM display every 2 seconds using process working-set
    self:cycleEvent(function()
        local bytes = (g_platform.getMemoryUsage and g_platform.getMemoryUsage()) or 0
        if bytes > 0 then
            local mb = bytes / (1024 * 1024)
            local base = _ramBaseline / (1024 * 1024)
            local delta = mb - base
            local ramStr
            if mb >= 1024 then
                ramStr = string.format('RAM: %.2f GB', mb / 1024)
            else
                ramStr = string.format('RAM: %.0f MB', mb)
            end
            if _ramBaseline > 0 and math.abs(delta) >= 1 then
                ramStr = ramStr .. ' (' .. formatMemoryDeltaFromMb(delta) .. ')'
            end
            self.ramText = ramStr
        else
            -- Fallback: Lua heap only (before recompile)
            local kb = collectgarbage('count')
            self.ramText = string.format('Lua: %.1f MB', kb / 1024)
        end

        self:updateGenerateWarning()
    end, 2000, 'ramMonitor')
end

local function estimatePngMbFromImageCount(imagesCount)
    -- Empirical average from user runs: ~42KB per generated PNG.
    return (imagesCount * 42.0) / 1024.0
end

local function estimateRamDeltaMbFromImageCount(imagesCount, threads)
    return math.max(80, math.floor(imagesCount / 380) + (threads or 8) * 8)
end

function MapGenUI:_resolvePartsIdsSoft()
    local partsIds = {}
    if self.genPartsMode == 'all' then
        for i = 1, #_mapParts do table.insert(partsIds, i) end
        return partsIds
    end

    for s in (self.genCustomParts or ''):gmatch('[^,]+') do
        local n = tonumber(s:match('^%s*(.-)%s*$'))
        if n and _mapParts[n] then
            table.insert(partsIds, n)
        end
    end
    return partsIds
end

function MapGenUI:updateGenerateWarning()
    if not self.isPrepared or not _preparedMinPos or not _preparedMaxPos or _preparedAreasCount <= 0 then
        self.fullGenerateWarnText = 'Warning: prepare client to compute generation estimates.'
        self.areaGenerateWarnText = 'Warning (approx.): AREA PNG -- MB, RAM +-- MB, ETA ~--s'
        self.floorGenerateWarnText = 'Warning (approx.): Single floor PNG -- MB, RAM +-- MB, ETA ~--s'
        return
    end

    local threads = tonumber(self.threads) or 8
    local partsIds = self:_resolvePartsIdsSoft()
    if #partsIds == 0 then
        self.fullGenerateWarnText = 'Warning: no valid parts selected.'
        self.areaGenerateWarnText = 'Warning: no valid parts selected.'
        self.floorGenerateWarnText = 'Warning: no valid parts selected.'
        return
    end

    local fullMinX = _preparedMinPos.x
    local fullMaxX = _preparedMaxPos.x
    local fullWidth = math.max(1, fullMaxX - fullMinX + 1)

    local selectedWidth = 0
    for _, pid in ipairs(partsIds) do
        local p = _mapParts[pid]
        if p then
            local partMinX = math.max(fullMinX, p.minXrender)
            local partMaxX = math.min(fullMaxX, p.maxXrender)
            if partMinX <= partMaxX then
                selectedWidth = selectedWidth + (partMaxX - partMinX + 1)
            end
        end
    end
    local ratio = math.min(1, selectedWidth / fullWidth)
    -- _preparedAreasCount comes from scanned tiles; convert to estimated PNG count.
    local fullImages = math.max(1, math.floor(_preparedAreasCount * 0.085))
    local selectedImages = math.max(1, math.floor(fullImages * ratio))

    local fullPngMb = estimatePngMbFromImageCount(selectedImages)
    local fullRamMb = estimateRamDeltaMbFromImageCount(selectedImages, threads)
    local fullEtaSec = math.max(2, math.floor(selectedImages / math.max(40, threads * 26)))

    local satChunkMb = 0
    local satChunkRam = 0
    local satChunkEta = 0
    if self.satIntegrated then
        local lod = tonumber(self.satLod) or 32
        local mapW = math.max(1, selectedWidth)
        local mapH = math.max(1, _preparedMaxPos.y - _preparedMinPos.y + 1)
        local chunks = math.max(1, math.ceil(mapW / lod) * math.ceil(mapH / lod))
        -- Combined satellite+minimap chunk footprint approximation.
        satChunkMb = chunks * 0.42
        satChunkRam = math.max(40, math.floor(chunks * 0.55))
        satChunkEta = math.max(2, math.floor(chunks / math.max(10, threads * 2)))
    end

    -- Area estimate
    local ax1 = tonumber(self.areaFromX) or fullMinX
    local ay1 = tonumber(self.areaFromY) or _preparedMinPos.y
    local ax2 = tonumber(self.areaToX) or fullMaxX
    local ay2 = tonumber(self.areaToY) or _preparedMaxPos.y
    local areaW = math.max(1, math.abs(ax2 - ax1) + 1)
    local areaH = math.max(1, math.abs(ay2 - ay1) + 1)
    local floorsCount = 0
    for _ in (self.areaFloors or '7'):gmatch('[^,]+') do floorsCount = floorsCount + 1 end
    floorsCount = math.max(1, floorsCount)
    local areaTiles = areaW * areaH * floorsCount
    local areaImages = math.max(1, math.floor(areaTiles / 64))
    local areaPngMb = estimatePngMbFromImageCount(areaImages)
    local areaEtaSec = math.max(1, math.floor(areaImages / math.max(40, threads * 26)))

    -- Floor estimate (by selected parts)
    local mapH = math.max(1, _preparedMaxPos.y - _preparedMinPos.y + 1)
    local floorTiles = math.max(1, selectedWidth) * mapH
    local floorImages = math.max(1, math.floor(floorTiles / 64))
    local floorPngMb = estimatePngMbFromImageCount(floorImages)
    local floorEtaSec = math.max(1, math.floor(floorImages / math.max(40, threads * 26)))

    if self.satIntegrated then
        self.fullGenerateWarnText = string.format(
            'Warning (approx.): Full PNG %.0f MB + SAT %.0f MB, RAM +%d MB, ETA ~%ds (+sat ~%ds)',
            fullPngMb, satChunkMb, fullRamMb + satChunkRam, fullEtaSec + satChunkEta, satChunkEta
        )
    else
        self.fullGenerateWarnText = string.format(
            'Warning (approx.): Full PNG %.0f MB, RAM +%d MB, ETA ~%ds',
            fullPngMb, fullRamMb, fullEtaSec
        )
    end
    self.areaGenerateWarnText = string.format(
        'Warning (approx.): AREA PNG %.0f MB, RAM +%d MB, ETA ~%ds',
        areaPngMb, estimateRamDeltaMbFromImageCount(areaImages, threads), areaEtaSec
    )
    self.floorGenerateWarnText = string.format(
        'Warning (approx.): Single floor PNG %.0f MB, RAM +%d MB, ETA ~%ds',
        floorPngMb, estimateRamDeltaMbFromImageCount(floorImages, threads), floorEtaSec
    )
end

function MapGenUI:onTerminate()
    -- Disable offline preview draw mode so game rendering is not affected
    if g_map.setOfflinePreview then
        g_map.setOfflinePreview(false)
    end
    if mapPreviewWidget and not mapPreviewWidget:isDestroyed() then
        mapPreviewWidget:setId('mapGenPreviewMap')
        mapPreviewWidget:destroy()
        mapPreviewWidget = nil
    end
    if _stolenGameMapPanel and not _stolenGameMapPanel:isDestroyed() then
        _stolenGameMapPanel:setId('gameMapPanel')
    end
    _stolenGameMapPanel = nil
    if satMinimapWidget and not satMinimapWidget:isDestroyed() then
        satMinimapWidget:destroy()
        satMinimapWidget = nil
    end
end

-- =========================================================================
-- Tab switching
-- =========================================================================

function MapGenUI:switchTab(tab)
    self.activeTab = tab
end

function MapGenUI:tabStyle(tab)
    if self.activeTab == tab then
        return 'background-color: #5b3f16ff; color: #ffe4a3ff'
    end
    return 'background-color: #1b1b2eff; color: #8b8ba1ff'
end

-- =========================================================================
-- File / Directory Dialogs
-- =========================================================================

-- Convert an absolute OS path returned by the dialog to a virtual path
-- that OTClient resources can use. Strips the write/work dir prefix.
local function toVirtualPath(absPath)
    if not absPath or absPath == '' then return nil end

    absPath = absPath:gsub('\\', '/')

    local writeDir = g_resources.getWriteDir():gsub('\\', '/')
    local workDir  = g_resources.getWorkDir():gsub('\\', '/')

    -- Strip trailing slashes for comparison
    writeDir = writeDir:gsub('/$', '')
    workDir  = workDir:gsub('/$', '')

    if writeDir ~= '' and absPath:sub(1, #writeDir) == writeDir then
        return '/' .. absPath:sub(#writeDir + 2)
    end
    if workDir ~= '' and absPath:sub(1, #workDir) == workDir then
        return '/' .. absPath:sub(#workDir + 2)
    end

    -- Cannot map to virtual path — return as-is and warn
    return absPath
end

local function resolveLoadPath(path, logFn)
    if not path or path == '' then
        return path
    end

    local normalized = path:gsub('\\', '/')
    if #normalized > 3 then
        normalized = normalized:gsub('/+$', '')
    end
    if normalized:sub(1, 1) == '/' then
        return normalized
    end

    if normalized:match('^%a:/') then
        local dir, file = normalized:match('^(.*)/([^/]+)$')
        if not dir or not file then
            return normalized
        end

        if not _mountedExternalDirs[dir] then
            local ok, err = pcall(function() return g_resources.addSearchPath(dir, true) end)
            if ok then
                _mountedExternalDirs[dir] = true
                if logFn then
                    logFn('Mounted external directory: ' .. dir, '#aaaacc')
                end
            else
                if logFn then
                    logFn('WARNING: failed to mount external directory: ' .. dir .. ' (' .. tostring(err) .. ')', '#ddaa44')
                end
            end
        end

        return '/' .. file
    end

    return normalized
end

function MapGenUI:browseFile(extensions, targetProp)
    if not g_platform.openFileDialog then
        self.statusText = 'Browse unavailable: recompile needed. Enter path manually.'
        self:addLog('openFileDialog not bound yet. Recompile the client.', '#ddaa44')
        return
    end
    local ok, result = pcall(g_platform.openFileDialog, extensions)
    if not ok or not result or result == '' then return end

    local vpath = toVirtualPath(result)
    self[targetProp] = vpath
    self:addLog('Selected: ' .. vpath, '#aaccff')
    self.statusText = 'Selected: ' .. vpath
end

function MapGenUI:browseDir(targetProp)
    if not g_platform.openDirectoryDialog then
        self.statusText = 'Browse unavailable: recompile needed. Enter path manually.'
        self:addLog('openDirectoryDialog not bound yet. Recompile the client.', '#ddaa44')
        return
    end
    local ok, result = pcall(g_platform.openDirectoryDialog)
    if not ok or not result or result == '' then return end

    local vpath = toVirtualPath(result):gsub('/$', '')
    self[targetProp] = vpath
    self:addLog('Selected: ' .. vpath, '#aaccff')
end

-- Auto-switch protobuf mode when a version >= 1281 is chosen from the combobox
function MapGenUI:onVersionChanged(v)
    local cv = tonumber(v) or 0
    if cv >= 1281 then
        self.isProtobuf = true
        self.assetsPath = '/data/things/' .. v
        self.mapPath    = '/data/things/' .. v .. '/otservbr.otbm'
    else
        self.isProtobuf = false
        self.definitionsPath = '/data/things/' .. v .. '/items.otb'
        self.datPath         = '/things/' .. v .. '/Tibia.dat'
        self.sprPath         = '/things/' .. v .. '/Tibia.spr'
        self.mapPath         = '/data/things/' .. v .. '/forgotten.otbm'
    end

    -- Keep feature checkboxes aligned with common defaults by version.
    self.featSpritesU32 = (cv >= 960)
    self.featEnhancedAnimations = (cv >= 1050)
    self.featIdleAnimations = (cv >= 1057)
    self.featSpritesAlphaChannel = (cv >= 1281)

    local satDir = 'satellite_output_' .. tostring(v)
    self.satOutputDir = satDir
    self.satPreviewDir = satDir
end

function MapGenUI:onVersionComboChange()
    g_dispatcher.scheduleEvent(function()
        self:onVersionChanged(self.clientVersion)
    end, 1)
end

-- Returns the export command as a single string (avoids multi-line template rendering)
function MapGenUI:exportCmdText()
    return string.format('g_map.saveImage("%s", %s, %s, %s, %s, %s, %s)',
        self.imgFilename or 'map_export.png',
        self.imgMinX, self.imgMinY,
        self.imgMaxX, self.imgMaxY,
        self.imgFloor,
        self.imgDrawLower and 'true' or 'false')
end

function MapGenUI:exportMinimapCmdText()
    return string.format('g_minimap.saveImage("%s", %s, %s, %s, %s, %s)',
        self.minimapFilename or 'minimap_export.png',
        self.imgMinX, self.imgMinY,
        self.imgMaxX, self.imgMaxY,
        self.imgFloor)
end

-- =========================================================================
-- Logging
-- =========================================================================

function MapGenUI:addLog(text, color)
    color = color or '#88aa88ff'
    table.insert(self.logEntries, {
        text  = os.date('[%H:%M:%S] ') .. text,
        color = color
    })
    if #self.logEntries > 600 then
        table.remove(self.logEntries, 1)
    end
end

function MapGenUI:clearLog()
    self.logEntries = {}
    self:addLog('Log cleared.', '#555577')
end

-- =========================================================================
-- Presets
-- =========================================================================

function MapGenUI:applyPreset(name)
    if name == 'legacy860' then
        self.clientVersion   = '860'
        self.isProtobuf      = false
        self.definitionsPath = '/data/things/860/items.otb'
        self.datPath         = '/things/860/Tibia.dat'
        self.sprPath         = '/things/860/Tibia.spr'
        self.mapPath         = '/data/things/860/forgotten.otbm'
    elseif name == 'legacy1098' then
        self.clientVersion   = '1098'
        self.isProtobuf      = false
        self.definitionsPath = '/data/things/1098/items.otb'
        self.datPath         = '/things/1098/Tibia.dat'
        self.sprPath         = '/things/1098/Tibia.spr'
        self.mapPath         = '/data/things/1098/forgotten.otbm'
    elseif name == 'proto1310' then
        self.clientVersion   = '1310'
        self.isProtobuf      = true
        self.assetsPath      = '/data/things/1310'
        self.mapPath         = '/data/things/1310/otservbr.otbm'
    elseif name == 'proto1412' then
        self.clientVersion   = '1412'
        self.isProtobuf      = true
        self.assetsPath      = '/data/things/1412'
        self.mapPath         = '/data/things/1412/otservbr.otbm'
    elseif name == 'proto1511' then
        self.clientVersion   = '1511'
        self.isProtobuf      = true
        self.assetsPath      = '/data/things/1511'
        self.mapPath         = '/data/things/1511/otservbr.otbm'
    end
    self:onVersionChanged(self.clientVersion)
    self:addLog('Preset applied: ' .. name .. '. Adjust paths if needed, then Prepare.', '#88ccff')
    self.statusText = 'Preset "' .. name .. '" loaded.'
end

-- =========================================================================
-- Prepare Client
-- =========================================================================

function MapGenUI:doPrepare()
    local cv = tonumber(self.clientVersion)
    if not cv or cv < 700 then
        self:addLog('ERROR: Invalid client version "' .. tostring(self.clientVersion) .. '"', '#ff6666')
        self.statusText = 'Error: invalid client version.'
        return
    end

    self:addLog('Preparing client v' .. cv .. ' ...', '#88ccff')
    self.statusText = 'Preparing client... (may freeze briefly)'

    -- Small delay so UI can redraw before the potential freeze
    g_dispatcher.scheduleEvent(function()
        self:_doPrepareAction(cv)
    end, 150)
end

function MapGenUI:_doPrepareAction(cv)
    local dpRaw  = self.isProtobuf and self.assetsPath or self.definitionsPath
    local datRaw = self.datPath or ''
    local sprRaw = self.sprPath or ''
    local mpRaw  = self.mapPath
    local thr = tonumber(self.threads) or 8
    local pts = tonumber(self.parts)   or 5

    local ok, err = pcall(function()
        -- Threads & directories
        g_map.initializeMapGenerator(thr)
        g_resources.makeDir('house')
        g_resources.makeDir('exported_images')
        g_resources.makeDir('exported_images/map')

        -- Protocol / client version
        g_game.setProtocolVersion(cv)
        g_game.setClientVersion(cv)
        if self.featSpritesU32 then g_game.enableFeature(GameSpritesU32) else g_game.disableFeature(GameSpritesU32) end
        if self.featSpritesAlphaChannel then g_game.enableFeature(GameSpritesAlphaChannel) else g_game.disableFeature(GameSpritesAlphaChannel) end
        if self.featEnhancedAnimations then g_game.enableFeature(GameEnhancedAnimations) else g_game.disableFeature(GameEnhancedAnimations) end
        if self.featIdleAnimations then g_game.enableFeature(GameIdleAnimations) else g_game.disableFeature(GameIdleAnimations) end

        -- Load thing definitions
        if cv >= 1281 and not g_game.getFeature(GameLoadSprInsteadProtobuf) then
            local dp = resolveLoadPath(dpRaw, function(msg, color) self:addLog(msg, color) end)
            local protobufPath = dp
            if not protobufPath:match('/$') then protobufPath = protobufPath .. '/' end

            -- Auto-detect catalog in sub-folder
            if not g_resources.fileExists(protobufPath .. 'catalog-content.json')
                and g_resources.fileExists(protobufPath .. 'assets/catalog-content.json') then
                protobufPath = protobufPath .. 'assets/'
            end

            self:addLog('Loading protobuf assets: ' .. protobufPath, '#aaaacc')
            g_things.loadAppearances(protobufPath)

            -- Optional OTB id mapping
            local base = dp:gsub('/$', '') .. '/'
            local otbPath = base .. 'items.otb'
            if g_resources.fileExists(otbPath) then
                self:addLog('Loading OTB id mapping: ' .. otbPath, '#aaaacc')
                g_things.loadOtb(otbPath)
            end
        else
            local dat = resolveLoadPath(datRaw, function(msg, color) self:addLog(msg, color) end)
            local spr = resolveLoadPath(sprRaw, function(msg, color) self:addLog(msg, color) end)
            local dp = resolveLoadPath(dpRaw, function(msg, color) self:addLog(msg, color) end)
            if dat ~= '' then
                self:addLog('Loading DAT: ' .. dat, '#aaaacc')
                g_things.loadDat(dat)
            end
            if spr ~= '' then
                self:addLog('Loading SPR: ' .. spr, '#aaaacc')
                g_sprites.loadSpr(spr)
            end
            self:addLog('Loading OTB definitions: ' .. dp, '#aaaacc')
            g_things.loadOtb(dp)
        end

        -- Capture RAM baseline before loading map data
        _ramBaseline = (g_platform.getMemoryUsage and g_platform.getMemoryUsage()) or 0

        -- Scan map for bounds (do NOT load tiles yet)
        local mp = resolveLoadPath(mpRaw, function(msg, color) self:addLog(msg, color) end)
        self:addLog('Scanning map bounds: ' .. mpRaw, '#aaaacc')
        g_map.setMaxXToLoad(-1)
        g_map.loadOtbm(mp)

        local minPos = g_map.getMinPosition()
        local maxPos = g_map.getMaxPosition()
        if not minPos or not maxPos then
            error('Map load failed: could not determine bounds. Check path and compatibility.')
        end

        -- Update bound display
        self.mapBoundsText = string.format('[%d,%d,%d] - [%d,%d,%d]',
            minPos.x, minPos.y, minPos.z, maxPos.x, maxPos.y, maxPos.z)
        _preparedMinPos = minPos
        _preparedMaxPos = maxPos

        -- Default preview / export coords to map centre
        local cx = math.floor((minPos.x + maxPos.x) / 2)
        local cy = math.floor((minPos.y + maxPos.y) / 2)
        self.prevMinX = tostring(cx - 50);  self.prevMinY = tostring(cy - 50)
        self.prevMaxX = tostring(cx + 50);  self.prevMaxY = tostring(cy + 50)
        self.prevFloor = tostring(minPos.z)
        self.imgMinX = tostring(cx - 100); self.imgMinY = tostring(cy - 100)
        self.imgMaxX = tostring(cx + 100); self.imgMaxY = tostring(cy + 100)
        self.imgFloor = tostring(minPos.z)

        -- Build map parts
        local totalTiles = 0
        local tilesPerX  = g_map.getMapTilesPerX()
        for _, c in pairs(tilesPerX) do totalTiles = totalTiles + c end

        _mapParts = {}
        local target  = totalTiles / pts
        local current = 0
        local part    = { minXrender = 0 }
        for i = 0, 70000 do
            if tilesPerX[i] then
                current = current + tilesPerX[i]
                part.maxXrender = i
                if #_mapParts < pts and current > target then
                    table.insert(_mapParts, part)
                    part    = { minXrender = i }
                    current = 0
                end
            end
        end
        part.maxXrender = 70000
        table.insert(_mapParts, part)

        local infoLines = {}
        for i, p in ipairs(_mapParts) do
            p.minXrender = math.max(0, math.floor((p.minXrender - 8) / 8) * 8)
            p.maxXrender = math.floor((p.maxXrender + 8) / 8) * 8
            p.minXload   = math.max(0, math.floor((p.minXrender - 16) / 8) * 8)
            p.maxXload   = math.floor((p.maxXrender + 16) / 8) * 8
            table.insert(infoLines, 'Part ' .. i .. ': X ' .. p.minXrender .. '-' .. p.maxXrender)
        end
        self.mapPartsInfo = table.concat(infoLines, '  |  ')
        _preparedAreasCount = math.max(g_map.getAreasCount() or 0, totalTiles or 0)

        _mapPath = mp
    end)

    if ok then
        self.isPrepared  = true
        self.statusText  = 'Client ready. Bounds: ' .. self.mapBoundsText
        self:addLog('Client prepared successfully. Parts: ' .. #_mapParts, '#44dd88')
        local modeStr = self.isProtobuf and 'protobuf/assets' or 'legacy dat/spr/otb'
        self.previewInfoText = string.format(
            'Map info: %s | bounds %s | parts %d | areas %s | threads %s',
            modeStr, self.mapBoundsText, #_mapParts, self:_fmtInt(_preparedAreasCount), tostring(self.threads or 8)
        )
        self:updateGenerateWarning()
    else
        self.isPrepared  = false
        self.statusText  = 'Preparation failed. See log.'
        self:addLog('ERROR: ' .. tostring(err), '#ff6666')
        self.previewInfoText = 'Map info: unavailable (prepare failed).'
    end
end

-- =========================================================================
-- Map Preview (UIMap)
-- =========================================================================

-- Preview uses UIMap with g_map.setOfflinePreview(true) to bypass the
-- g_game.isOnline() guard in client.cpp. The widget is given id "gameMapPanel"
-- so Client::draw() can find it during the draw pipeline.
function MapGenUI:doPreview()
    if not self.isPrepared then
        self:addLog('Cannot preview: client not prepared.', '#ff6666')
        return
    end

    local minX  = tonumber(self.prevMinX) or 32000
    local minY  = tonumber(self.prevMinY) or 32000
    local maxX  = tonumber(self.prevMaxX) or 32100
    local maxY  = tonumber(self.prevMaxY) or 32100
    local floor = tonumber(self.prevFloor) or 7
    self:addLog(string.format('Loading preview tiles [%d,%d]-[%d,%d] z=%d', minX, minY, maxX, maxY, floor), '#88ccff')
    self.statusText = 'Loading map tiles for preview...'

    g_map.setMinXToLoad(math.max(0, minX - 16))
    g_map.setMaxXToLoad(maxX + 16)
    g_map.setMinXToRender(minX)
    g_map.setMaxXToRender(maxX)

    g_dispatcher.scheduleEvent(function()
        local ok, err = pcall(function() g_map.loadOtbm(_mapPath) end)
        if not ok then
            self:addLog('ERROR loading tiles: ' .. tostring(err), '#ff6666')
            self.statusText = 'Error loading tiles for preview.'
            return
        end

        local host = self:findWidget('#mapPreviewHost')
        if not host then
            self:addLog('ERROR: mapPreviewHost widget not found.', '#ff6666')
            return
        end

        -- Client::draw() resolves UIMap by id="gameMapPanel". If another widget
        -- already owns this id, offline preview will render to the wrong map.
        local currentPanel = g_ui.getRootWidget():recursiveGetChildById('gameMapPanel')
        if currentPanel and (not mapPreviewWidget or currentPanel ~= mapPreviewWidget) then
            _stolenGameMapPanel = currentPanel
            _stolenGameMapPanel:setId('gameMapPanel_live')
        end

        -- Create UIMap once; id="gameMapPanel" so Client::draw() can locate it
        if not mapPreviewWidget or mapPreviewWidget:isDestroyed() then
            mapPreviewWidget = g_ui.createWidget('UIMap', host)
            mapPreviewWidget:fill('parent')
            mapPreviewWidget:setId('gameMapPanel')
            mapPreviewWidget:setDrawNames(false)
            mapPreviewWidget:setDrawHealthBars(false)
            mapPreviewWidget:setMinimumAmbientLight(1.0)
            mapPreviewWidget:setDrawLights(false)
            mapPreviewWidget:setDrawManaBar(false)
            mapPreviewWidget:setAntiAliasingMode(0)
            mapPreviewWidget.previewDragging = false
            mapPreviewWidget.onMousePress = function(widget, mousePos, button)
                if button == MouseLeftButton or button == MouseRightButton or button == MouseMiddleButton then
                    widget.previewDragging = true
                    return true
                end
                return false
            end
            mapPreviewWidget.onMouseMove = function(widget, mousePos, mouseMoved)
                if widget.previewDragging then
                    local speed = 3
                    widget:movePixels(-mouseMoved.x * speed, -mouseMoved.y * speed)
                    return true
                end
                return false
            end
            mapPreviewWidget.onMouseRelease = function(widget, mousePos, button)
                widget.previewDragging = false
                return true
            end
            mapPreviewWidget.onMouseWheel = function(widget, mousePos, direction)
                local before = widget:getPosition(mousePos)
                if direction == MouseWheelUp then
                    widget:zoomIn()
                elseif direction == MouseWheelDown then
                    widget:zoomOut()
                else
                    return false
                end

                local after = widget:getPosition(mousePos)
                local cam = widget:getCameraPosition()
                if before and after and cam then
                    cam.x = cam.x + (before.x - after.x)
                    cam.y = cam.y + (before.y - after.y)
                    widget:setCameraPosition(cam)
                end
                return true
            end
        else
            mapPreviewWidget:setId('gameMapPanel')
        end

        -- Enable offline rendering in the draw pipeline
        g_map.setOfflinePreview(true)

        local cx = math.floor((minX + maxX) / 2)
        local cy = math.floor((minY + maxY) / 2)
        local widthTiles = math.max(1, maxX - minX + 1)
        local heightTiles = math.max(1, maxY - minY + 1)
        local dim = math.max(15, math.min(255, math.max(widthTiles, heightTiles)))

        mapPreviewWidget:setCameraPosition({ x = cx, y = cy, z = floor })
        mapPreviewWidget:lockVisibleFloor(floor)
        mapPreviewWidget:setLimitVisibleDimension(false)
        mapPreviewWidget:setMaxZoomOut(1024)
        mapPreviewWidget:setVisibleDimension({ width = dim, height = dim })

        self:addLog(string.format('Preview ready. Center [%d,%d,%d] (offline mode)', cx, cy, floor), '#44dd88')
        self.statusText = string.format('Preview active. Center [%d,%d,%d]', cx, cy, floor)
    end, 250)
end

function MapGenUI:zoomPreviewIn()
    if mapPreviewWidget and not mapPreviewWidget:isDestroyed() then
        mapPreviewWidget:zoomIn()
    end
end

function MapGenUI:zoomPreviewOut()
    if mapPreviewWidget and not mapPreviewWidget:isDestroyed() then
        mapPreviewWidget:zoomOut()
    end
end

function MapGenUI:centerPreview()
    if mapPreviewWidget and not mapPreviewWidget:isDestroyed() then
        local cx = math.floor(((tonumber(self.prevMinX) or 0) + (tonumber(self.prevMaxX) or 0)) / 2)
        local cy = math.floor(((tonumber(self.prevMinY) or 0) + (tonumber(self.prevMaxY) or 0)) / 2)
        local cz = tonumber(self.prevFloor) or 7
        mapPreviewWidget:setCameraPosition({ x = cx, y = cy, z = cz })
    end
end

-- =========================================================================
-- Export PNG
-- =========================================================================

function MapGenUI:doExportPng()
    if not self.isPrepared then
        self:addLog('Cannot export: client not prepared.', '#ff6666')
        return
    end

    local minX  = tonumber(self.imgMinX)  or 32000
    local minY  = tonumber(self.imgMinY)  or 32000
    local maxX  = tonumber(self.imgMaxX)  or 32200
    local maxY  = tonumber(self.imgMaxY)  or 32200
    local floor = tonumber(self.imgFloor) or 7
    local lower = self.imgDrawLower
    local fname = self.imgFilename or 'map_export.png'

    self:addLog(string.format('Exporting PNG "%s" area [%d,%d]-[%d,%d] z=%d lower=%s',
        fname, minX, minY, maxX, maxY, floor, tostring(lower)), '#88ccff')
    self.statusText = 'Exporting PNG...'

    g_map.setMinXToLoad(math.max(0, minX - 16))
    g_map.setMaxXToLoad(maxX + 16)
    g_map.setMinXToRender(minX)
    g_map.setMaxXToRender(maxX)

    g_dispatcher.scheduleEvent(function()
        local ok, err = pcall(function()
            g_map.loadOtbm(_mapPath)
            g_map.saveImage(fname, minX, minY, maxX, maxY, floor, lower)
        end)

        if ok then
            self:addLog('PNG exported: ' .. fname, '#44dd88')
            self.statusText = 'PNG exported: ' .. fname
        else
            self:addLog('ERROR: ' .. tostring(err), '#ff6666')
            self.statusText = 'PNG export failed. See log.'
        end
    end, 250)
end

function MapGenUI:copyExportCmd()
    local cmd = string.format(
        "g_map.saveImage('%s', %s, %s, %s, %s, %s, %s)",
        self.imgFilename or 'map_export.png',
        self.imgMinX, self.imgMinY,
        self.imgMaxX, self.imgMaxY,
        self.imgFloor,
        self.imgDrawLower and 'true' or 'false'
    )
    self:addLog('CMD: ' .. cmd, '#dddd88')
    self.statusText = 'Command copied to log.'
end

function MapGenUI:doExportMinimap()
    if not self.isPrepared then
        self:addLog('Cannot export minimap: client not prepared.', '#ff6666')
        return
    end

    local minX  = tonumber(self.imgMinX)  or 0
    local minY  = tonumber(self.imgMinY)  or 0
    local maxX  = tonumber(self.imgMaxX)  or 500
    local maxY  = tonumber(self.imgMaxY)  or 500
    local floor = tonumber(self.imgFloor) or 7
    local fname = self.minimapFilename or 'minimap_export.png'

    self:addLog(string.format('Exporting minimap "%s" area [%d,%d]-[%d,%d] z=%d',
        fname, minX, minY, maxX, maxY, floor), '#88ccff')
    self.statusText = 'Exporting minimap...'

    g_map.setMinXToLoad(math.max(0, minX - 16))
    g_map.setMaxXToLoad(maxX + 16)
    g_map.setMinXToRender(minX)
    g_map.setMaxXToRender(maxX)

    g_dispatcher.scheduleEvent(function()
        local ok, err = pcall(function()
            g_map.loadOtbm(_mapPath)
            g_minimap.saveImage(fname, minX, minY, maxX, maxY, floor)
        end)

        if ok then
            self:addLog('Minimap exported: ' .. fname, '#44dd88')
            self.statusText = 'Minimap exported: ' .. fname
        else
            self:addLog('ERROR: ' .. tostring(err), '#ff6666')
            self.statusText = 'Minimap export failed. See log.'
        end
    end, 250)
end

-- =========================================================================
-- Full Map Generation (delegates to otclientrc.lua globals)
-- =========================================================================

function MapGenUI:doGenerate()
    if not self.isPrepared then
        self:addLog('Cannot generate: client not prepared.', '#ff6666')
        return
    end
    if self.isGenerating then
        self:addLog('Already generating.', '#ddaa44')
        return
    end

    local shadow   = tonumber(self.shadowPercent) or 30
    local partsIds = self:_resolvePartsIds()
    if not partsIds then return end

    self:addLog('Starting generation. Parts: {' .. table.concat(partsIds, ',') .. '} shadow=' .. shadow .. '%', '#88ccff')

    if self.satIntegrated then
        local sdir = self.satOutputDir or 'satellite_output'
        local slod = tonumber(self.satLod) or 32
        prepareSatelliteGeneration(sdir, slod)
        self:addLog('Satellite per-part enabled: ' .. sdir .. ' LOD=' .. slod, '#88ccff')
    end

    self.isGenerating    = true
    self.progressPercent = 0
    self.progressBarWidth = 0
    self.progressLabel   = 'Preparing generation...'
    self.statusText      = 'Preparing full generation...'
    self.waitingGenerateStart = true

    local cv = tonumber(self.clientVersion) or 1098
    local dp = self.isProtobuf and self.assetsPath or self.definitionsPath
    local mp = self.mapPath
    local thr = tonumber(self.threads) or 8
    local pts = tonumber(self.parts) or 5

    if startGenerateFromUI then
        startGenerateFromUI(cv, dp, mp, thr, pts, partsIds, shadow)
    else
        generateMap(partsIds, shadow)
        self.waitingGenerateStart = false
    end
    self.progressLabel = 'Preparing data...'
    self.statusText = 'Preparing and waiting for generation...'
    self:_startProgressMonitor()
end

function MapGenUI:doStopGenerate()
    self.isGenerating = false
    self.statusText   = 'Stopped by user.'
    self:addLog('Generation stopped by user.', '#ddaa44')
end

function MapGenUI:_startProgressMonitor()
    self:cycleEvent(function()
        local status = MAPGEN_UI_STATUS
        if not status then
            return
        end

        if self.waitingGenerateStart and status.active then
            self.waitingGenerateStart = false
        end

        if self.waitingGenerateStart then
            self.progressPercent = 0
            self.progressBarWidth = 0
            self.progressLabel = 'Preparing data...'
            self.statusText = 'Preparing full generation...'
            return
        end

        if not status.active and (status.phase == 'done' or not isGenerating) then
            self.isGenerating    = false
            self.progressPercent = 100
            self.progressBarWidth = 690
            self.progressLabel   = status.message ~= '' and status.message or 'Complete!'
            self.statusText      = 'Generation complete.'
            self:addLog('Map generation finished!', '#44dd88')
            return false
        end

        local total = tonumber(status.total) or 0
        local done  = tonumber(status.done) or 0
        local part = tonumber(status.part) or 0
        local parts = tonumber(status.parts) or 0
        local phase = status.phase or 'png'

        if total and total > 0 then
            self.progressPercent = math.floor(done / total * 100)
            self.progressBarWidth = math.min(690, math.floor(self.progressPercent * 6.9))
            self.progressLabel   = string.format('%d%%, %s of %s PNG images - PART %d OF %d',
                self.progressPercent, self:_fmtInt(done), self:_fmtInt(total), part, parts)
        else
            self.progressPercent = 0
            self.progressBarWidth = 0
            if phase == 'satellite' or phase == 'minimap' then
                self.progressLabel = string.format('%s chunks: %s - PART %d OF %d',
                    phase, self:_fmtInt(done), part, parts)
            else
                self.progressLabel = status.message ~= '' and status.message or 'Working...'
            end
        end
    end, 1000, 'genMonitor')
end

-- =========================================================================
-- generateMapArea — specific coordinate range + floors
-- =========================================================================

function MapGenUI:doGenerateMapArea()
    if not self.isPrepared then
        self:addLog('Cannot generate: client not prepared.', '#ff6666')
        return
    end
    if self.isGenerating then
        self:addLog('Already generating.', '#ddaa44')
        return
    end

    local fromX  = tonumber(self.areaFromX) or 0
    local fromY  = tonumber(self.areaFromY) or 0
    local toX    = tonumber(self.areaToX)   or 0
    local toY    = tonumber(self.areaToY)   or 0
    local shadow = tonumber(self.shadowPercent) or 30
    local name   = (self.areaName and self.areaName ~= '') and self.areaName or 'area_map'

    -- Parse floors: "7,8,9" → {7,8,9}
    local floors = {}
    for s in (self.areaFloors or '7'):gmatch('[^,]+') do
        local n = tonumber(s:match('^%s*(.-)%s*$'))
        if n then table.insert(floors, n) end
    end
    if #floors == 0 then
        self:addLog('ERROR: no valid floors specified (e.g. "7,8,9")', '#ff6666')
        return
    end

    local partsIds = self:_resolvePartsIds()
    if not partsIds then return end

    self:addLog(string.format('generateMapArea("%s", shadow=%d, [%d,%d]-[%d,%d], floors={%s})',
        name, shadow, fromX, fromY, toX, toY, table.concat(floors, ',')), '#88ccff')
    self.isGenerating    = true
    self.progressPercent = 0
    self.progressBarWidth = 0
    self.progressLabel   = 'Starting area generation...'
    self.statusText      = 'Generating map area...'

    generateMapArea(partsIds, shadow, fromX, fromY, toX, toY, floors, name)

    self:cycleEvent(function()
        if not isGenerating then
            self.isGenerating    = false
            self.progressPercent = 100
            self.progressLabel   = 'Area generation complete!'
            self.statusText      = 'generateMapArea finished.'
            self:addLog('generateMapArea finished!', '#44dd88')
            return false
        end
    end, 1000, 'areaMonitor')
end

-- =========================================================================
-- generateMapFloor — whole map, one floor at a time
-- =========================================================================

function MapGenUI:doGenerateMapFloor()
    if not self.isPrepared then
        self:addLog('Cannot generate: client not prepared.', '#ff6666')
        return
    end
    if self.isGenerating then
        self:addLog('Already generating.', '#ddaa44')
        return
    end

    local floor  = tonumber(self.floorNum)     or 7
    local shadow = tonumber(self.shadowPercent) or 30
    local name   = (self.floorName and self.floorName ~= '') and self.floorName or ('f' .. tostring(floor))

    local partsIds = self:_resolvePartsIds()
    if not partsIds then return end

    self:addLog(string.format('generateMapFloor("%s", shadow=%d, floor=%d)', name, shadow, floor), '#88ccff')
    self.isGenerating    = true
    self.progressPercent = 0
    self.progressLabel   = 'Starting floor generation...'
    self.statusText      = 'Generating floor ' .. floor .. '...'

    generateMapFloor(partsIds, shadow, floor, name)

    self.isGenerating    = false
    self.progressPercent = 100
    self.progressLabel   = 'Floor complete!'
    self.statusText      = 'generateMapFloor finished.'
    self:addLog('generateMapFloor finished!', '#44dd88')
end

-- shared helper: returns resolved parts id table or nil+logs error
function MapGenUI:_resolvePartsIds()
    local partsIds = {}
    if self.genPartsMode == 'all' then
        for i = 1, #_mapParts do table.insert(partsIds, i) end
    else
        for s in self.genCustomParts:gmatch('[^,]+') do
            local n = tonumber(s:match('^%s*(.-)%s*$'))
            if n then table.insert(partsIds, n) end
        end
    end
    if #partsIds == 0 then
        self:addLog('ERROR: no parts selected.', '#ff6666')
        return nil
    end
    return partsIds
end

-- =========================================================================
-- Satellite Generation (standalone)
-- =========================================================================

function MapGenUI:doGenerateSatellite()
    if not self.isPrepared then
        self:addLog('Cannot generate: client not prepared.', '#ff6666')
        return
    end
    if self.isGenerating then
        self:addLog('Already generating.', '#ddaa44')
        return
    end

    local odir   = self.satOutputDir or 'satellite_output'
    local lod    = tonumber(self.satLod)    or 32
    local shadow = tonumber(self.satShadow) or 30

    self:addLog(string.format('Starting satellite gen: %s  LOD=%d  shadow=%d%%', odir, lod, shadow), '#88ccff')
    self.isGenerating    = true
    self.progressPercent = 0
    self.progressLabel   = 'Initialising...'
    self.statusText      = 'Generating satellite data...'

    generateSatelliteData(odir, lod, shadow)

    self:cycleEvent(function()
        local s = SATELLITE_UI_STATUS
        if not s then
            return
        end

        if not s.active and (s.phase == 'done' or not satelliteGenerating) then
            self.isGenerating    = false
            self.progressPercent = 100
            self.progressBarWidth = 690
            self.progressLabel   = 'Satellite complete!'
            self.statusText      = 'Satellite generation complete.'
            self:addLog('Satellite generation finished!', '#44dd88')
            return false
        end

        local done = tonumber(s.done) or 0
        local total = tonumber(s.total) or 0
        local phase = s.phase or '?'
        if total > 0 then
            self.progressPercent = math.floor(done / total * 100)
            self.progressBarWidth = math.min(690, math.floor(self.progressPercent * 6.9))
            self.progressLabel = string.format('%d%%, %s of %s chunks [%s]', self.progressPercent, self:_fmtInt(done), self:_fmtInt(total), phase)
        else
            self.progressPercent = 0
            self.progressBarWidth = 0
            self.progressLabel = self:_fmtInt(done) .. ' chunks  [' .. phase .. ']'
        end
    end, 2000, 'satMonitor')
end

function MapGenUI:doEnableSatellitePerPart()
    local odir = self.satOutputDir or 'satellite_output'
    local lod  = tonumber(self.satLod) or 32
    prepareSatelliteGeneration(odir, lod)
    self:addLog('Satellite per-part armed: ' .. odir .. ' LOD=' .. lod .. '. Go to Full Generate tab.', '#44dd88')
    self.statusText = 'Satellite per-part armed. Run Full Generate to proceed.'
end

-- =========================================================================
-- Satellite Minimap Preview
-- =========================================================================

function MapGenUI:doLoadSatPreview()
    local dir = self.satPreviewDir or ''
    if dir == '' then
        self:addLog('Satellite preview: no directory set.', '#ddaa44')
        self.statusText = 'Enter a satellite directory to preview.'
        return
    end

    if not g_satelliteMap then
        self:addLog('g_satelliteMap not available (recompile needed).', '#ff6666')
        return
    end

    local ok, err = pcall(function() g_satelliteMap.loadDirectory(dir) end)
    if not ok then
        self:addLog('ERROR loading satellite dir: ' .. tostring(err), '#ff6666')
        self.statusText = 'Failed to load satellite dir.'
        return
    end

    local host = self:findWidget('#satMinimapHost')
    if not host then
        self:addLog('ERROR: satMinimapHost not found.', '#ff6666')
        return
    end

    if not satMinimapWidget or satMinimapWidget:isDestroyed() then
        satMinimapWidget = g_ui.createWidget('UIMinimap', host)
        satMinimapWidget:fill('parent')
        satMinimapWidget.previewDragging = false
        satMinimapWidget.onMousePress = function(widget, mousePos, button)
            if button == MouseLeftButton or button == MouseRightButton or button == MouseMiddleButton then
                widget.previewDragging = true
                return true
            end
            return false
        end
        satMinimapWidget.onMouseMove = function(widget, mousePos, mouseMoved)
            if widget.previewDragging then
                widget:move(mouseMoved.x, mouseMoved.y)
                return true
            end
            return false
        end
        satMinimapWidget.onMouseRelease = function(widget, mousePos, button)
            widget.previewDragging = false
            return true
        end
        satMinimapWidget.onMouseWheel = function(widget, mousePos, direction)
            local before = widget:getTilePosition(mousePos)
            if direction == MouseWheelUp then
                widget:zoomIn()
            elseif direction == MouseWheelDown then
                widget:zoomOut()
            else
                return false
            end

            local after = widget:getTilePosition(mousePos)
            local cam = widget:getCameraPosition()
            if before and after and cam then
                cam.x = cam.x + (before.x - after.x)
                cam.y = cam.y + (before.y - after.y)
                widget:setCameraPosition(cam)
            end
            return true
        end
    end

    self:satApplyViewMode()

    local floor = tonumber(self.satPreviewFloor) or 7
    satMinimapWidget:setCameraPosition({ x = 32000, y = 32000, z = floor })

    self:addLog('Satellite preview loaded from: ' .. dir, '#44dd88')
    self.statusText = 'Satellite preview active. Floor ' .. floor
end

function MapGenUI:satSetViewMode(mode)
    if mode ~= 'surface' and mode ~= 'map' then
        return
    end
    self.satViewMode = mode
    self:satApplyViewMode()
end

function MapGenUI:satApplyViewMode()
    if not satMinimapWidget or satMinimapWidget:isDestroyed() then
        return
    end

    if self.satViewMode == 'surface' then
        satMinimapWidget:setUseStaticMinimap(false)
        satMinimapWidget:setSatelliteMode(true)
        self.statusText = 'Satellite preview mode: Surface'
    else
        satMinimapWidget:setSatelliteMode(false)
        satMinimapWidget:setUseStaticMinimap(true)
        self.statusText = 'Satellite preview mode: Map'
    end
end

function MapGenUI:satPreviewLoadOutputDir()
    self.satPreviewDir = self.satOutputDir or 'satellite_output'
    self:doLoadSatPreview()
end

function MapGenUI:satFloorUp()
    if satMinimapWidget and not satMinimapWidget:isDestroyed() then
        satMinimapWidget:floorUp()
        local f = tonumber(self.satPreviewFloor) or 7
        self.satPreviewFloor = tostring(math.max(0, f - 1))
    end
end

function MapGenUI:satFloorDown()
    if satMinimapWidget and not satMinimapWidget:isDestroyed() then
        satMinimapWidget:floorDown()
        local f = tonumber(self.satPreviewFloor) or 7
        self.satPreviewFloor = tostring(math.min(15, f + 1))
    end
end

function MapGenUI:satZoomIn()
    if satMinimapWidget and not satMinimapWidget:isDestroyed() then
        satMinimapWidget:zoomIn()
    end
end

function MapGenUI:satZoomOut()
    if satMinimapWidget and not satMinimapWidget:isDestroyed() then
        satMinimapWidget:zoomOut()
    end
end

function MapGenUI:satGoToPosition()
    if not satMinimapWidget or satMinimapWidget:isDestroyed() then
        self:addLog('Load a satellite preview first.', '#ddaa44')
        return
    end
    local x = tonumber(self.satPosX) or 32000
    local y = tonumber(self.satPosY) or 32000
    local z = tonumber(self.satPreviewFloor) or 7
    satMinimapWidget:setCameraPosition({ x = x, y = y, z = z })
    self.statusText = string.format('Satellite view moved to [%d,%d,%d]', x, y, z)
end

-- =========================================================================
-- Helpers
-- =========================================================================

function MapGenUI:_fmtInt(n)
    if not n then return '0' end
    local s = tostring(math.floor(n))
    return s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
end
