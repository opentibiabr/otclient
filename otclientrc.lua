-- this file is loaded after all modules are loaded and initialized
-- you can place any custom user code here

print 'Startup done :]'

-- OTClient Map Generator
-- Based on https://github.com/gesior/otclient_mapgen

clientVersion = 0
definitionsPath = ''
mapPath = ''

isGenerating = false
threadsToRun = 3
areasAdded = 0

startTime = os.time()
lastPrintStatus = os.time()

mapParts = {}
mapPartsToGenerate = {}
mapPartsCount = 0
mapPartsCurrentId = 0
mapImagesGenerated = 0
preparedMinPos = nil
preparedMaxPos = nil
_uiPendingGenerate = nil
MAPGEN_UI_STATUS = {
    active = false,
    phase = 'idle',
    done = 0,
    total = 0,
    part = 0,
    parts = 0,
    message = ''
}
SATELLITE_UI_STATUS = {
    active = false,
    phase = 'idle',
    done = 0,
    total = 0,
    message = ''
}

local function getExportBaseDir()
    local cv = tonumber(g_game.getClientVersion()) or tonumber(clientVersion) or 0
    if cv > 0 then
        return "exported_images_" .. tostring(cv)
    end
    return "exported_images"
end

local function getExportMapDir()
    return getExportBaseDir() .. "/map"
end

local function ensureExportDirs()
    g_resources.makeDir(getExportBaseDir())
    g_resources.makeDir(getExportMapDir())
    g_map.setExportMapDir(getExportMapDir())
end

local function clampMapCoord(v)
    return math.max(0, math.min(65535, v))
end

local function setYLoadRange(minY, maxY)
    if g_map.setMinYToLoad then
        g_map.setMinYToLoad(clampMapCoord(minY))
    end
    if g_map.setMaxYToLoad then
        g_map.setMaxYToLoad(clampMapCoord(maxY))
    end
end

local function setPreparedYLoadRange(margin)
    margin = margin or 0
    if preparedMinPos and preparedMaxPos then
        setYLoadRange(preparedMinPos.y - margin, preparedMaxPos.y + margin)
    else
        setYLoadRange(0, 65535)
    end
end

local function setPreparedFullLoadRange(margin)
    margin = margin or 0
    if preparedMinPos and preparedMaxPos then
        g_map.setMinXToLoad(clampMapCoord(preparedMinPos.x - margin))
        g_map.setMaxXToLoad(clampMapCoord(preparedMaxPos.x + margin))
        setYLoadRange(preparedMinPos.y - margin, preparedMaxPos.y + margin)
    else
        g_map.setMinXToLoad(0)
        g_map.setMaxXToLoad(65535)
        setYLoadRange(0, 65535)
    end
end

-- Legacy example:   prepareClient(1076, '/things/1076/items.otb', '/map.otbm', 8, 5)
-- Protobuf example: prepareClient(1412, '/things/1412/assets/', '/things/1412/forgotten.otbm', 8, 5)
function prepareClient(cv, dp, mp, ttr, mpc)
    clientVersion = cv
    definitionsPath = dp
    mapPath = mp
    threadsToRun = ttr or 3
    mapPartsCount = mpc
    preparedMinPos = nil
    preparedMaxPos = nil
    g_logger.info("Loading client data... (it will freeze client for a few seconds)")
    g_dispatcher.scheduleEvent(prepareClient_action, 1000)
end

function prepareClient_action()


    g_map.initializeMapGenerator(threadsToRun);
    g_resources.makeDir('house');
    ensureExportDirs()
    
    g_logger.info("Loading client Tibia.dat and Tibia.spr...")
    g_game.setProtocolVersion(clientVersion)
    g_game.setClientVersion(clientVersion)
    g_logger.info("Loading item definitions...")
    if clientVersion >= 1281 and not g_game.getFeature(GameLoadSprInsteadProtobuf) then
        -- Protobuf/assets clients use client ids directly (no OTB mapping / no serverId conversion).
        local protobufPath = definitionsPath
        if not protobufPath:match('/$') then
            protobufPath = protobufPath .. '/'
        end

        if not g_resources.fileExists(protobufPath .. 'catalog-content.json')
            and g_resources.fileExists(protobufPath .. 'assets/catalog-content.json') then
            protobufPath = protobufPath .. 'assets/'
        end

        g_logger.info("Loading protobuf assets from: " .. protobufPath)
        g_things.loadAppearances(protobufPath)

        -- Optional compatibility mapping: some protobuf-era OTBM files still
        -- encode item ids using OTB/server ids. If items.otb exists, load it
        -- only for id mapping while keeping sprite source as protobuf assets.
        local basePath = definitionsPath
        if not basePath:match('/$') then
            basePath = basePath .. '/'
        end
        local otbMapPath = basePath .. 'items.otb'
        if g_resources.fileExists(otbMapPath) then
            g_logger.info("Loading optional OTB id mapping from: " .. otbMapPath)
            g_things.loadOtb(otbMapPath)
        end
    else
        g_things.loadOtb(definitionsPath)
    end
    g_logger.info("Loading server map information...")
    if g_map.setMapGenOptimizedLoad then
        g_map.setMapGenOptimizedLoad(true)
    end
    g_map.setMinXToLoad(0)
    g_map.setMaxXToLoad(-1) -- do not load tiles, just save map min/max position
    setYLoadRange(0, 65535)
    g_map.loadOtbm(mapPath)

    local minPos = g_map.getMinPosition()
    local maxPos = g_map.getMaxPosition()
    if not minPos or not maxPos then
        preparedMinPos = nil
        preparedMaxPos = nil
        g_logger.error("Map load failed (invalid bounds). Check OTBM compatibility and paths.")
        return
    end

    preparedMinPos = { x = minPos.x, y = minPos.y, z = minPos.z }
    preparedMaxPos = { x = maxPos.x, y = maxPos.y, z = maxPos.z }

    g_logger.info("Loaded map positions. Minimum [X: " .. minPos.x .. ", Y: " .. minPos.y .. ", Z: " .. minPos.z .. "] Maximum [X: " .. maxPos.x .. ", Y: " .. maxPos.y .. ", Z: " .. maxPos.z .. "]")
    g_logger.info("Loaded client data.")

    local totalTilesCount = 0
    local mapTilesPerX = g_map.getMapTilesPerX()
    for x, c in pairs(mapTilesPerX) do
        totalTilesCount = totalTilesCount + c
    end
    
    mapParts = {}
    local targetTilesCount = totalTilesCount / mapPartsCount
    local currentTilesCount = 0
    local currentPart = {["minXrender"] = 0}
    for i = 0, 70000 do
        if mapTilesPerX[i] then
            currentTilesCount = currentTilesCount + mapTilesPerX[i]
            currentPart.maxXrender = i
            if #mapParts < mapPartsCount and currentTilesCount > targetTilesCount then
                table.insert(mapParts, currentPart)
                currentPart = {["minXrender"] = i}
                currentTilesCount = 0
            end
        end
    end
    currentPart.maxXrender = 70000
    table.insert(mapParts, currentPart)
    
    g_logger.info('----- MAP PARTS LIST -----')
    for i, currentPart in pairs(mapParts) do
        -- render +/- 8 tiles to avoid problem with calculations precision
        currentPart.minXrender = math.max(0, math.floor((currentPart.minXrender - 8) / 8) * 8)
        currentPart.maxXrender = math.floor((currentPart.maxXrender + 8) / 8) * 8
        
        -- load +/- 16 tiles to be sure that all items on floors below will load
        currentPart.minXload = math.max(0, math.floor((currentPart.minXrender - 16) / 8) * 8)
        currentPart.maxXload = math.floor((currentPart.maxXrender + 16) / 8) * 8
        
        print("PART " .. i .. " FROM X: " .. currentPart.minXrender .. ", TO X: " .. currentPart.maxXrender)
    end
    g_logger.info('----- MAP PARTS LIST -----')
    
    g_logger.info('')
    g_logger.info("----- STEP 2 -----")
    g_logger.info("Now just type (lower levels shadow 30%):");
    g_logger.info("ALL PARTS OF MAP:")
    g_logger.info("generateMap('all', 30)");
    g_logger.info("ONLY PARTS 2 AND 3 OF MAP:")
    g_logger.info("generateMap({2, 3}, 30)");
    g_logger.info("SPECIFIC AREA + FLOORS:")
    g_logger.info("generateMapArea('all', 30, 32364, 32231, 32374, 32243, {7,8,9}, 'area_test')");
    g_logger.info("generateMapArea({2,3}, 30, 32364, 32231, 32374, 32243, {7,8,9}, 'area_test')");
    g_logger.info("ONE FLOOR BY PARTS:")
    g_logger.info("generateMapFloor('all', 30, 7, 'f7') or generateMapFloor({2,3}, 30, 7, 'f7')");
    g_logger.info("OPTIONAL FULL ONE FLOOR:")
    g_logger.info("generateMapFloorFull(7, 30, 'full_floor_7.png')");
    g_logger.info("")
    MAPGEN_UI_STATUS.active = false
    MAPGEN_UI_STATUS.phase = 'idle'
    MAPGEN_UI_STATUS.done = 0
    MAPGEN_UI_STATUS.total = 0
    MAPGEN_UI_STATUS.part = 0
    MAPGEN_UI_STATUS.parts = 0
    MAPGEN_UI_STATUS.message = 'Client prepared'

    if _uiPendingGenerate then
        local pending = _uiPendingGenerate
        _uiPendingGenerate = nil
        g_dispatcher.scheduleEvent(function()
            generateMap(pending.partsIds, pending.shadowPercent)
        end, 100)
    end
end

-- Set before calling generateMap() to enable satellite data generation after all parts.
-- outputDir: directory for .bmp.lzma output
-- lod: 16, 32, or 64
_satelliteFromFullGenerate = false
satelliteOutputDir_perPart = nil
satelliteLod_perPart = 32

function prepareSatelliteGeneration(outputDir, lod)
    satelliteOutputDir_perPart = outputDir or '/satellite_output'
    satelliteLod_perPart = lod or 32
    g_resources.makeDir(satelliteOutputDir_perPart)
    print('Satellite generation enabled: ' .. satelliteOutputDir_perPart .. '  LOD=' .. satelliteLod_perPart)
end

function generateManager()
    local done = g_map.getGeneratedAreasCount()
    local total = g_map.getAreasCount()
    MAPGEN_UI_STATUS.active = true
    MAPGEN_UI_STATUS.phase = 'png'
    MAPGEN_UI_STATUS.done = done
    MAPGEN_UI_STATUS.total = total
    MAPGEN_UI_STATUS.part = mapPartsCurrentId
    MAPGEN_UI_STATUS.parts = #mapPartsToGenerate
    MAPGEN_UI_STATUS.message = 'Generating PNG images'

    if (done / 1000) + 1 > areasAdded then
        g_map.addAreasToGenerator(areasAdded * 1000, areasAdded * 1000 + 999)
        areasAdded = areasAdded + 1
    end

    if lastPrintStatus ~= os.time() and total > 0 then
        print(math.floor(done / total * 100) .. '%, ' .. format_int(done) .. ' of ' .. format_int(total) .. ' PNG images - PART ' .. mapPartsCurrentId .. ' OF ' .. #mapPartsToGenerate)
        lastPrintStatus = os.time()
    end

    if total > 0 and done >= total then
        mapImagesGenerated = mapImagesGenerated + done
        advanceToNextPart()
        return
    end

    g_dispatcher.scheduleEvent(generateManager, 100)
end

function advanceToNextPart()
    if mapPartsCurrentId ~= #mapPartsToGenerate then
        mapPartsCurrentId = mapPartsCurrentId + 1
        startMapPartGenerator()
        g_dispatcher.scheduleEvent(generateManager, 100)
    else
        -- All PNG parts done
        if satelliteOutputDir_perPart then
            -- Satellite/minimap requires ALL tiles loaded at once.
            -- Reload the full map before generating.
            print('Reloading full map for satellite generation...')
            MAPGEN_UI_STATUS.phase = 'satellite'
            MAPGEN_UI_STATUS.message = 'Reloading map for satellite...'
            g_dispatcher.scheduleEvent(function()
                setPreparedFullLoadRange(16)
                g_map.setMinXToRender(0)
                g_map.setMaxXToRender(70000)
                g_map.loadOtbm(mapPath)
                -- Use standalone satellite generator (handles satellite → minimap → map.dat)
                _satelliteFromFullGenerate = true
                generateSatelliteData(satelliteOutputDir_perPart, satelliteLod_perPart, g_map.getShadowPercent(), mapPath)
            end, 100)
        else
            finishFullGeneration()
        end
    end
end

function finishFullGeneration()
    isGenerating = false
    MAPGEN_UI_STATUS.active = false
    MAPGEN_UI_STATUS.phase = 'done'
    MAPGEN_UI_STATUS.done = mapImagesGenerated
    MAPGEN_UI_STATUS.total = mapImagesGenerated
    MAPGEN_UI_STATUS.part = #mapPartsToGenerate
    MAPGEN_UI_STATUS.parts = #mapPartsToGenerate
    MAPGEN_UI_STATUS.message = 'Generation complete'
    print('Map generation finished.')
    print(mapImagesGenerated .. ' PNG images generated in ' .. (os.time() - startTime) .. ' seconds.')
end

function startMapPartGenerator()
    local currentMapPart = mapPartsToGenerate[mapPartsCurrentId]

    g_logger.info("Set min X to load: " .. currentMapPart.minXload)
    g_logger.info("Set max X to load: " .. currentMapPart.maxXload)
    g_logger.info("Set min X to render: " .. currentMapPart.minXrender)
    g_logger.info("Set max X to render: " .. currentMapPart.maxXrender)
    g_map.setMinXToLoad(currentMapPart.minXload)
    g_map.setMaxXToLoad(currentMapPart.maxXload)
    setPreparedYLoadRange(16)
    g_map.setMinXToRender(currentMapPart.minXrender)
    g_map.setMaxXToRender(currentMapPart.maxXrender)

    g_logger.info("Loading server map part...")
    g_map.loadOtbm(mapPath)

    areasAdded = 0
    g_map.setGeneratedAreasCount(0)
    MAPGEN_UI_STATUS.active = true
    MAPGEN_UI_STATUS.phase = 'png'
    MAPGEN_UI_STATUS.done = 0
    MAPGEN_UI_STATUS.total = g_map.getAreasCount()
    MAPGEN_UI_STATUS.part = mapPartsCurrentId
    MAPGEN_UI_STATUS.parts = #mapPartsToGenerate
    MAPGEN_UI_STATUS.message = 'Generating PNG part ' .. mapPartsCurrentId

    print('Starting generator (PART ' .. mapPartsCurrentId .. ' OF ' .. #mapPartsToGenerate .. '). ' .. format_int(g_map.getAreasCount()) .. ' images to generate. ' .. threadsToRun .. ' threads will generate it now. Please wait.')
end

function generateMap(mapPartsToGenerateIds, shadowPercent)
    if isGenerating then
        print('Generating script is already running. Cannot start another generation')
        return
    end
    
    isGenerating = true
    MAPGEN_UI_STATUS.active = true
    MAPGEN_UI_STATUS.phase = 'preparing'
    MAPGEN_UI_STATUS.done = 0
    MAPGEN_UI_STATUS.total = 0
    MAPGEN_UI_STATUS.part = 0
    MAPGEN_UI_STATUS.parts = 0
    MAPGEN_UI_STATUS.message = 'Preparing generation'

    if type(mapPartsToGenerateIds) == "string" then
        mapPartsToGenerateIds = {}
        for i = 1, mapPartsCount do
            table.insert(mapPartsToGenerateIds, i)
        end
    end
    
--generateMap({1}, nil)
    g_map.setShadowPercent(shadowPercent)
    mapImagesGenerated = 0
    
    -- split map into parts
    mapPartsCurrentId = 1
    mapPartsToGenerate = {}
    
    for _, i in pairs(mapPartsToGenerateIds) do
        table.insert(mapPartsToGenerate, mapParts[i])
    end
    
    startTime = os.time()
    
    startMapPartGenerator()
    
    g_dispatcher.scheduleEvent(generateManager, 1000)
end

-- UI-safe wrapper: prepares otclientrc internals and starts generation after prepare is done.
function startGenerateFromUI(cv, dp, mp, ttr, mpc, partsIds, shadowPercent)
    _uiPendingGenerate = {
        partsIds = partsIds,
        shadowPercent = shadowPercent
    }
    prepareClient(cv, dp, mp, ttr, mpc)
end

local function normalizeAreaBounds(fromX, fromY, toX, toY)
    local minX = math.min(fromX, toX)
    local maxX = math.max(fromX, toX)
    local minY = math.min(fromY, toY)
    local maxY = math.max(fromY, toY)
    return minX, minY, maxX, maxY
end

local function loadMapForXRange(minX, maxX, minY, maxY)
    local minXRender = math.max(0, math.floor((minX - 8) / 8) * 8)
    local maxXRender = math.floor((maxX + 8) / 8) * 8
    local minXLoad = math.max(0, math.floor((minXRender - 16) / 8) * 8)
    local maxXLoad = math.floor((maxXRender + 16) / 8) * 8

    g_map.setMinXToLoad(minXLoad)
    g_map.setMaxXToLoad(maxXLoad)
    if minY ~= nil and maxY ~= nil then
        local minYNorm = math.min(minY, maxY)
        local maxYNorm = math.max(minY, maxY)
        setYLoadRange(minYNorm - 16, maxYNorm + 16)
    else
        setPreparedYLoadRange(16)
    end
    g_map.setMinXToRender(minXRender)
    g_map.setMaxXToRender(maxXRender)

    local minYLoad = g_map.getMinYToLoad and g_map.getMinYToLoad() or 0
    local maxYLoad = g_map.getMaxYToLoad and g_map.getMaxYToLoad() or 65535
    g_logger.info("Loading map for X/Y range [" .. minXLoad .. ", " .. maxXLoad .. "] / [" .. minYLoad .. ", " .. maxYLoad .. "]...")
    g_map.loadOtbm(mapPath)
end

local function normalizePartsArg(partsArg)
    if type(partsArg) == "table" then
        return partsArg
    end

    -- Keep same style as generateMap('all', 30): any non-table means all parts.
    local parts = {}
    for i = 1, mapPartsCount do
        table.insert(parts, i)
    end
    return parts
end

-- Generate area PNGs per floor and per map part (same part logic as generateMap()).
-- Example:
-- Preferred style (same as generateMap parts+shadow):
-- generateMapArea('all', 30, 32364, 32231, 32374, 32243, {7,8,9}, "area_test")
-- generateMapArea({2,3}, 30, 32364, 32231, 32374, 32243, {7,8,9}, "area_test")
-- Legacy style (still supported):
-- generateMapArea(32364, 32231, 32374, 32243, {7,8,9}, 30, {2,3}, "area_test")
function generateMapArea(a1, a2, a3, a4, a5, a6, a7, a8)
    if isGenerating then
        print('Generating script is already running. Cannot start another generation')
        return
    end

    local mapPartsToGenerateIds
    local shadowPercent
    local fromX
    local fromY
    local toX
    local toY
    local floors
    local outputPrefix

    if type(a1) == "string" or type(a1) == "table" then
        -- New style: (parts, shadow, fromX, fromY, toX, toY, floors, prefix)
        mapPartsToGenerateIds = normalizePartsArg(a1)
        shadowPercent = a2
        fromX = a3
        fromY = a4
        toX = a5
        toY = a6
        floors = a7
        outputPrefix = a8
    else
        -- Legacy style: (fromX, fromY, toX, toY, floors, shadow, parts, prefix)
        fromX = a1
        fromY = a2
        toX = a3
        toY = a4
        floors = a5
        shadowPercent = a6
        mapPartsToGenerateIds = normalizePartsArg(a7)
        outputPrefix = a8
    end

    if type(floors) ~= "table" or #floors == 0 then
        print('generateMapArea: floors must be a non-empty table, example {7,8,9}')
        return
    end

    local minX, minY, maxX, maxY = normalizeAreaBounds(fromX, fromY, toX, toY)

    outputPrefix = outputPrefix or "area_map"

    g_map.setShadowPercent(shadowPercent)

    for _, partId in ipairs(mapPartsToGenerateIds) do
        local part = mapParts[partId]
        if part then
            local partMinX = math.max(minX, part.minXrender)
            local partMaxX = math.min(maxX, part.maxXrender)
            if partMinX <= partMaxX then
                loadMapForXRange(partMinX, partMaxX, minY, maxY)
                for _, floor in ipairs(floors) do
                    local fileName = string.format("%s/%s_z%d_part_%d.png", getExportMapDir(), outputPrefix, floor, partId)
                    g_map.saveImage(fileName, partMinX, minY, partMaxX, maxY, floor, false)
                    print("Area map part saved: " .. fileName)
                end
            end
        end
    end
end

-- Generate one floor split by map parts (like generateMap parts flow).
-- Examples:
-- Preferred style (same as generateMap parts+shadow):
-- generateMapFloor('all', 30, 7, "f7")
-- generateMapFloor({2,3}, 30, 7, "f7")
-- Legacy style (still supported):
-- generateMapFloor(7, 30, {2,3}, "f7")
function generateMapFloor(a1, a2, a3, a4)
    local mapPartsToGenerateIds
    local shadowPercent
    local floor
    local outputPrefix

    if type(a1) == "string" or type(a1) == "table" then
        -- New style: (parts, shadow, floor, prefix)
        mapPartsToGenerateIds = normalizePartsArg(a1)
        shadowPercent = a2
        floor = a3
        outputPrefix = a4
    else
        -- Legacy style: (floor, shadow, parts, prefix)
        floor = a1
        shadowPercent = a2
        mapPartsToGenerateIds = normalizePartsArg(a3)
        outputPrefix = a4
    end

    local minPos = preparedMinPos or g_map.getMinPosition()
    local maxPos = preparedMaxPos or g_map.getMaxPosition()
    if not minPos or not maxPos then
        print("generateMapFloor: invalid map bounds. Run prepareClient() first.")
        return
    end

    outputPrefix = outputPrefix or string.format("floor_%d", floor)
    g_map.setShadowPercent(shadowPercent)

    for _, partId in ipairs(mapPartsToGenerateIds) do
        local part = mapParts[partId]
        if part then
            g_logger.info("Loading map part " .. partId .. " for floor " .. floor .. "...")
            g_map.setMinXToLoad(part.minXload)
            g_map.setMaxXToLoad(part.maxXload)
            setPreparedYLoadRange(16)
            g_map.setMinXToRender(part.minXrender)
            g_map.setMaxXToRender(part.maxXrender)
            g_map.loadOtbm(mapPath)

            local partMinX = math.max(minPos.x, part.minXrender)
            local partMaxX = math.min(maxPos.x, part.maxXrender)
            if partMinX <= partMaxX then
                local fileName = string.format("%s/%s_part_%d.png", getExportMapDir(), outputPrefix, partId)
                g_map.saveImage(fileName, partMinX, minPos.y, partMaxX, maxPos.y, floor, false)
                print("Floor map part saved: " .. fileName)
            end
        end
    end
end

-- Optional: generate a single full PNG for one floor.
function generateMapFloorFull(floor, shadowPercent, outputFileName)
    local minPos = preparedMinPos or g_map.getMinPosition()
    local maxPos = preparedMaxPos or g_map.getMaxPosition()
    if not minPos or not maxPos then
        print("generateMapFloorFull: invalid map bounds. Run prepareClient() first.")
        return
    end

    outputFileName = outputFileName or string.format("full_floor_%d.png", floor)
    if not outputFileName:find("/") then
        outputFileName = getExportMapDir() .. "/" .. outputFileName
    end

    g_map.setShadowPercent(shadowPercent)
    g_map.setMinXToLoad(clampMapCoord(minPos.x - 16))
    g_map.setMaxXToLoad(clampMapCoord(maxPos.x + 16))
    setYLoadRange(minPos.y - 16, maxPos.y + 16)
    g_map.setMinXToRender(minPos.x)
    g_map.setMaxXToRender(maxPos.x)
    g_map.loadOtbm(mapPath)
    g_map.saveImage(outputFileName, minPos.x, minPos.y, maxPos.x, maxPos.y, floor, false)
    print("Full floor map saved: " .. outputFileName)
end

function format_int(number)
    local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
    int = int:reverse():gsub("(%d%d%d)", "%1,")
    return minus .. int:reverse():gsub("^,", "") .. fraction
end

-- Debug helper: print tile stack/order and item ids at a position.
function printTileItems(x, y, z)
    local pos = { x = x, y = y, z = z }
    local tile = g_map.getTile(pos)
    if not tile then
        print(string.format("printTileItems: tile %d,%d,%d not found", x, y, z))
        return
    end

    local things = tile:getThings()
    print(string.format("printTileItems: tile %d,%d,%d -> %d things", x, y, z, #things))

    for i, thing in ipairs(things) do
        local kind = "thing"
        if thing:isGround() then
            kind = "ground"
        elseif thing:isGroundBorder() then
            kind = "groundBorder"
        elseif thing:isOnBottom() then
            kind = "onBottom"
        elseif thing:isOnTop() then
            kind = "onTop"
        elseif thing:isCreature() then
            kind = "creature"
        elseif thing:isItem() then
            kind = "item"
        end

        local id = thing:getId()
        local stackPriority = thing:getStackPriority()
        local extra = ""

        if thing:isItem() then
            local okSid, sid = pcall(function() return thing:getServerId() end)
            if okSid then
                extra = extra .. " sid=" .. tostring(sid)
            end

            local okName, name = pcall(function() return thing:getName() end)
            if okName and name and name ~= "" then
                extra = extra .. " name='" .. tostring(name) .. "'"
            end
        end

        print(string.format("  [%02d] %s id=%d stackPriority=%d%s", i, kind, id, stackPriority, extra))
    end
end

-- ---------------------------------------------------------------------------
-- Satellite / Minimap chunk generation (.bmp.lzma + map.dat)
-- ---------------------------------------------------------------------------

local satelliteGenerating = false
local satelliteOutputDir = ''
local satellitePhase = '' -- 'satellite', 'minimap', or 'done'
local satelliteLodQueue = {}     -- list of satellite LODs to generate (e.g. {16, 32})
local satelliteLodQueueIdx = 1   -- current index into satelliteLodQueue
local satelliteMinimapLod = 32   -- LOD used for minimap generation
local satelliteStartTime = 0
local satelliteLastCount = -1
local satelliteStableTicks = 0
-- 'all' | 'satellite' | 'minimap'  (set per-call, read in progress manager)
local satelliteGenerateMode = 'all'

function generateSatelliteData(outputDir, lod, shadowPercent, mapPathOverride, mode)
    if satelliteGenerating then
        print('Satellite generation is already running.')
        return
    end

    outputDir = outputDir or '/satellite_output'
    shadowPercent = shadowPercent or 30
    satelliteGenerateMode = mode or 'all'

    -- Native CIP format always has satellite at LOD 16 + LOD 32, minimap at LOD 32
    satelliteLodQueue    = {16, 32}
    satelliteLodQueueIdx = 1
    satelliteMinimapLod  = 32

    satelliteGenerating = true
    satelliteOutputDir = outputDir
    satelliteStartTime = os.time()
    satelliteLastCount = -1
    satelliteStableTicks = 0

    SATELLITE_UI_STATUS.active = true
    SATELLITE_UI_STATUS.done = 0
    SATELLITE_UI_STATUS.total = 0

    g_resources.makeDir(outputDir)
    g_map.setShadowPercent(shadowPercent)

    -- Reload full map so all tiles are available for rendering.
    -- Without this, only the last loaded part's tiles exist in memory.
    local effectiveMapPath = mapPathOverride or mapPath
    if effectiveMapPath and effectiveMapPath ~= '' then
        print('Reloading full map for satellite generation...')
        setPreparedFullLoadRange(16)
        g_map.setMinXToRender(0)
        g_map.setMaxXToRender(70000)
        g_map.loadOtbm(effectiveMapPath)
    end

    if satelliteGenerateMode == 'minimap' then
        -- Skip satellite phase, go straight to minimap
        satellitePhase = 'minimap'
        SATELLITE_UI_STATUS.phase = 'minimap'
        SATELLITE_UI_STATUS.message = 'Generating minimap chunks'
        g_map.setGeneratedAreasCount(0)
        g_map.generateMinimapChunks(outputDir, satelliteMinimapLod)
        SATELLITE_UI_STATUS.total = g_map.getAreasCount()
        print('Starting minimap chunk generation (LOD=' .. satelliteMinimapLod .. ')...')
    else
        -- Phase 1: satellite at first LOD (16)
        local firstLod = satelliteLodQueue[1]
        satellitePhase = 'satellite'
        SATELLITE_UI_STATUS.phase = 'satellite'
        SATELLITE_UI_STATUS.message = 'Generating satellite chunks'
        g_map.setGeneratedAreasCount(0)
        g_map.generateSatelliteChunks(outputDir, firstLod)
        SATELLITE_UI_STATUS.total = g_map.getAreasCount()
        print('Starting satellite chunk generation (LOD=' .. firstLod .. ')...')
    end

    g_dispatcher.scheduleEvent(satelliteProgressManager, 1000)
end

function satelliteProgressManager()
    local count = g_map.getGeneratedAreasCount()
    local total = g_map.getAreasCount()
    SATELLITE_UI_STATUS.active = true
    SATELLITE_UI_STATUS.phase = satellitePhase
    SATELLITE_UI_STATUS.done = count
    SATELLITE_UI_STATUS.total = total
    SATELLITE_UI_STATUS.message = 'Generating ' .. tostring(satellitePhase) .. ' chunks'
    -- Mirror progress to MAPGEN_UI_STATUS for full generate UI
    if _satelliteFromFullGenerate then
        MAPGEN_UI_STATUS.active = true
        MAPGEN_UI_STATUS.phase = satellitePhase
        MAPGEN_UI_STATUS.done = count
        MAPGEN_UI_STATUS.total = total
        MAPGEN_UI_STATUS.message = 'Generating ' .. tostring(satellitePhase) .. ' chunks'
    end
    print('[' .. satellitePhase .. '] ' .. format_int(count) .. ' chunks generated...')

    if count == satelliteLastCount and count > 0 then
        satelliteStableTicks = satelliteStableTicks + 1
    else
        satelliteStableTicks = 0
        satelliteLastCount = count
    end

    if (total > 0 and count >= total) or satelliteStableTicks >= 4 then
        print('[' .. satellitePhase .. '] Complete: ' .. format_int(count) .. ' chunks.')
        if satellitePhase == 'satellite' then
            -- Advance to next satellite LOD, or to minimap if all LODs done
            satelliteLodQueueIdx = satelliteLodQueueIdx + 1
            satelliteLastCount = -1
            satelliteStableTicks = 0
            if satelliteLodQueueIdx <= #satelliteLodQueue then
                local nextLod = satelliteLodQueue[satelliteLodQueueIdx]
                SATELLITE_UI_STATUS.done = 0
                SATELLITE_UI_STATUS.message = 'Generating satellite chunks (LOD=' .. nextLod .. ')'
                g_map.setGeneratedAreasCount(0)
                g_map.generateSatelliteChunks(satelliteOutputDir, nextLod)
                SATELLITE_UI_STATUS.total = g_map.getAreasCount()
                print('Starting satellite chunk generation (LOD=' .. nextLod .. ')...')
                g_dispatcher.scheduleEvent(satelliteProgressManager, 1000)
            elseif satelliteGenerateMode == 'satellite' then
                -- satellite-only mode: skip minimap, go straight to done
                satellitePhase = 'done'
                g_map.saveMapDat(satelliteOutputDir)
                print('map.dat saved to ' .. satelliteOutputDir .. '/map.dat')
                print('Satellite-only generation finished in ' .. (os.time() - satelliteStartTime) .. ' seconds.')
                satelliteGenerating = false
                if g_map.clearGenerateFloorRange then g_map.clearGenerateFloorRange() end
                SATELLITE_UI_STATUS.active = false
                SATELLITE_UI_STATUS.phase = 'done'
                SATELLITE_UI_STATUS.done = count
                SATELLITE_UI_STATUS.total = total
                SATELLITE_UI_STATUS.message = 'Satellite generation complete'
                satelliteLastCount = -1
                satelliteStableTicks = 0
                if _satelliteFromFullGenerate then
                    _satelliteFromFullGenerate = false
                    finishFullGeneration()
                end
            else
                satellitePhase = 'minimap'
                SATELLITE_UI_STATUS.phase = 'minimap'
                SATELLITE_UI_STATUS.done = 0
                SATELLITE_UI_STATUS.message = 'Generating minimap chunks'
                g_map.setGeneratedAreasCount(0)
                g_map.generateMinimapChunks(satelliteOutputDir, satelliteMinimapLod)
                SATELLITE_UI_STATUS.total = g_map.getAreasCount()
                print('Starting minimap chunk generation (LOD=' .. satelliteMinimapLod .. ')...')
                g_dispatcher.scheduleEvent(satelliteProgressManager, 1000)
            end
        else
            satellitePhase = 'done'
            g_map.saveMapDat(satelliteOutputDir)
            print('map.dat saved to ' .. satelliteOutputDir .. '/map.dat')
            print('Satellite data generation finished in ' .. (os.time() - satelliteStartTime) .. ' seconds.')
            satelliteGenerating = false
            if g_map.clearGenerateFloorRange then g_map.clearGenerateFloorRange() end
            SATELLITE_UI_STATUS.active = false
            SATELLITE_UI_STATUS.phase = 'done'
            SATELLITE_UI_STATUS.done = count
            SATELLITE_UI_STATUS.total = total
            SATELLITE_UI_STATUS.message = 'Satellite generation complete'
            satelliteLastCount = -1
            satelliteStableTicks = 0
            -- If triggered from full generate, finalize the overall generation
            if _satelliteFromFullGenerate then
                _satelliteFromFullGenerate = false
                finishFullGeneration()
            end
        end
    else
        g_dispatcher.scheduleEvent(satelliteProgressManager, 1000)
    end
end
-- Example usage instructions
g_logger.info('OTClient Map Generator version: 6.1')
g_logger.info("To generate map images, execute:")
g_logger.info("1. prepareClient(1098, '/things/1098/items.otb', '/things/1098/forgotten.otbm', 8, 5)")
g_logger.info("   - client version, definitions path, MAP path, threads, parts")
g_logger.info("   - protobuf example: prepareClient(1412, '/things/1412/assets/', '/things/1412/forgotten.otbm', 8, 5)")
g_logger.info("2. generateMap('all', 30)")
g_logger.info("   - 'all' or {1,2,3} for parts, shadow percent")
g_logger.info("   - area by floors+parts: generateMapArea('all', 30, fromX, fromY, toX, toY, {7,8,9}, 'area_name')")
g_logger.info("   - one floor by parts: generateMapFloor('all', 30, 7, 'f7') or generateMapFloor({2,3}, 30, 7, 'f7')")
g_logger.info("   - optional full one floor: generateMapFloorFull(7, 30, 'full_floor_7.png')")
g_logger.info("3. generateSatelliteData('/satellite_output', 32, 30)")
g_logger.info("   - output dir, LOD (16/32/64), shadow percent")
