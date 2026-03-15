-- this file is loaded after all modules are loaded and initialized
-- you can place any custom user code here

print 'Startup done :]'

-- OTClient Map Generator
-- Based on https://github.com/gesior/otclient_mapgen

local clientVersion = 0
local definitionsPath = ''
local mapPath = ''

local isGenerating = false
local threadsToRun = 3
local areasAdded = 0

local startTime = os.time()
local lastPrintStatus = os.time()

local mapParts = {}
local mapPartsToGenerate = {}
local mapPartsCount = 0
local mapPartsCurrentId = 0
local mapImagesGenerated = 0
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

-- Legacy example:   prepareClient(1076, '/things/1076/items.otb', '/map.otbm', 8, 5)
-- Protobuf example: prepareClient(1412, '/things/1412/assets/', '/things/1412/forgotten.otbm', 8, 5)
function prepareClient(cv, dp, mp, ttr, mpc)
    clientVersion = cv
    definitionsPath = dp
    mapPath = mp
    threadsToRun = ttr or 3
    mapPartsCount = mpc
    g_logger.info("Loading client data... (it will freeze client for a few seconds)")
    g_dispatcher.scheduleEvent(prepareClient_action, 1000)
end

function prepareClient_action()


    g_map.initializeMapGenerator(threadsToRun);
    g_resources.makeDir('house');
    g_resources.makeDir('exported_images');
    g_resources.makeDir('exported_images/map');
    
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
    g_map.setMaxXToLoad(-1) -- do not load tiles, just save map min/max position
    g_map.loadOtbm(mapPath)

    local minPos = g_map.getMinPosition()
    local maxPos = g_map.getMaxPosition()
    if not minPos or not maxPos then
        g_logger.error("Map load failed (invalid bounds). Check OTBM compatibility and paths.")
        return
    end

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

-- Per-part satellite generation state
-- Phase 0 = PNG images, 1 = satellite chunks, 2 = minimap chunks
local partSatellitePhase = 0
local partSatelliteLastCount = -1
local partSatelliteStableTicks = 0

-- Set before calling generateMap() to enable satellite data generation per part.
-- outputDir: directory for .bmp.lzma output
-- lod: 16, 32, or 64
local satelliteOutputDir_perPart = nil
local satelliteLod_perPart = 32

function prepareSatelliteGeneration(outputDir, lod)
    satelliteOutputDir_perPart = outputDir or 'satellite_output'
    satelliteLod_perPart = lod or 32
    g_resources.makeDir(satelliteOutputDir_perPart)
    print('Satellite generation enabled: ' .. satelliteOutputDir_perPart .. '  LOD=' .. satelliteLod_perPart)
end

function generateManager()
    if partSatellitePhase == 0 then
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
            if satelliteOutputDir_perPart then
                partSatellitePhase = 1
                partSatelliteLastCount = -1
                partSatelliteStableTicks = 0
                g_map.setGeneratedAreasCount(0)
                MAPGEN_UI_STATUS.phase = 'satellite'
                MAPGEN_UI_STATUS.done = 0
                MAPGEN_UI_STATUS.total = 0
                MAPGEN_UI_STATUS.message = 'Generating satellite chunks'
                g_map.generateSatelliteChunks(satelliteOutputDir_perPart, satelliteLod_perPart)
                MAPGEN_UI_STATUS.total = g_map.getAreasCount()
                print('  [Part ' .. mapPartsCurrentId .. '] Generating satellite chunks...')
                g_dispatcher.scheduleEvent(generateManager, 1000)
                return
            end
            advanceToNextPart()
            return
        end

        g_dispatcher.scheduleEvent(generateManager, 100)
        return
    end

    local done = g_map.getGeneratedAreasCount()
    local total = g_map.getAreasCount()
    local phaseLabel = (partSatellitePhase == 1) and 'satellite' or 'minimap'
    MAPGEN_UI_STATUS.active = true
    MAPGEN_UI_STATUS.phase = phaseLabel
    MAPGEN_UI_STATUS.done = done
    MAPGEN_UI_STATUS.total = total
    MAPGEN_UI_STATUS.part = mapPartsCurrentId
    MAPGEN_UI_STATUS.parts = #mapPartsToGenerate
    MAPGEN_UI_STATUS.message = (partSatellitePhase == 1) and 'Generating satellite chunks' or 'Generating minimap chunks'

    if lastPrintStatus ~= os.time() then
        print('  [Part ' .. mapPartsCurrentId .. '] ' .. phaseLabel .. ' chunks: ' .. format_int(done) .. ' of ' .. format_int(total))
        lastPrintStatus = os.time()
    end

    if done == partSatelliteLastCount and done > 0 then
        partSatelliteStableTicks = partSatelliteStableTicks + 1
    else
        partSatelliteStableTicks = 0
        partSatelliteLastCount = done
    end

    if (total > 0 and done >= total) or partSatelliteStableTicks >= 4 then
        if partSatellitePhase == 1 then
            partSatellitePhase = 2
            partSatelliteLastCount = -1
            partSatelliteStableTicks = 0
            g_map.setGeneratedAreasCount(0)
            MAPGEN_UI_STATUS.phase = 'minimap'
            MAPGEN_UI_STATUS.done = 0
            MAPGEN_UI_STATUS.total = 0
            MAPGEN_UI_STATUS.message = 'Generating minimap chunks'
            g_map.generateMinimapChunks(satelliteOutputDir_perPart, satelliteLod_perPart)
            MAPGEN_UI_STATUS.total = g_map.getAreasCount()
            print('  [Part ' .. mapPartsCurrentId .. '] Generating minimap chunks...')
            g_dispatcher.scheduleEvent(generateManager, 1000)
        else
            partSatellitePhase = 0
            partSatelliteLastCount = -1
            partSatelliteStableTicks = 0
            advanceToNextPart()
        end
        return
    end

    g_dispatcher.scheduleEvent(generateManager, 1000)
end

function advanceToNextPart()
    if mapPartsCurrentId ~= #mapPartsToGenerate then
        mapPartsCurrentId = mapPartsCurrentId + 1
        startMapPartGenerator()
        g_dispatcher.scheduleEvent(generateManager, 100)
    else
        -- All parts done
        if satelliteOutputDir_perPart then
            g_map.saveMapDat(satelliteOutputDir_perPart)
            print('map.dat saved to ' .. satelliteOutputDir_perPart .. '/map.dat')
        end
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
end

function startMapPartGenerator()
    local currentMapPart = mapPartsToGenerate[mapPartsCurrentId]

    g_logger.info("Set min X to load: " .. currentMapPart.minXload)
    g_logger.info("Set max X to load: " .. currentMapPart.maxXload)
    g_logger.info("Set min X to render: " .. currentMapPart.minXrender)
    g_logger.info("Set max X to render: " .. currentMapPart.maxXrender)
    g_map.setMinXToLoad(currentMapPart.minXload)
    g_map.setMaxXToLoad(currentMapPart.maxXload)
    g_map.setMinXToRender(currentMapPart.minXrender)
    g_map.setMaxXToRender(currentMapPart.maxXrender)

    g_logger.info("Loading server map part...")
    g_map.loadOtbm(mapPath)

    areasAdded = 0
    partSatellitePhase = 0
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

local function loadMapForXRange(minX, maxX)
    local minXRender = math.max(0, math.floor((minX - 8) / 8) * 8)
    local maxXRender = math.floor((maxX + 8) / 8) * 8
    local minXLoad = math.max(0, math.floor((minXRender - 16) / 8) * 8)
    local maxXLoad = math.floor((maxXRender + 16) / 8) * 8

    g_map.setMinXToLoad(minXLoad)
    g_map.setMaxXToLoad(maxXLoad)
    g_map.setMinXToRender(minXRender)
    g_map.setMaxXToRender(maxXRender)

    g_logger.info("Loading map for X range [" .. minXLoad .. ", " .. maxXLoad .. "]...")
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
                loadMapForXRange(partMinX, partMaxX)
                for _, floor in ipairs(floors) do
                    local fileName = string.format("exported_images/map/%s_z%d_part_%d.png", outputPrefix, floor, partId)
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

    local minPos = g_map.getMinPosition()
    local maxPos = g_map.getMaxPosition()
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
            g_map.setMinXToRender(part.minXrender)
            g_map.setMaxXToRender(part.maxXrender)
            g_map.loadOtbm(mapPath)

            local partMinX = math.max(minPos.x, part.minXrender)
            local partMaxX = math.min(maxPos.x, part.maxXrender)
            if partMinX <= partMaxX then
                local fileName = string.format("exported_images/map/%s_part_%d.png", outputPrefix, partId)
                g_map.saveImage(fileName, partMinX, minPos.y, partMaxX, maxPos.y, floor, false)
                print("Floor map part saved: " .. fileName)
            end
        end
    end
end

-- Optional: generate a single full PNG for one floor.
function generateMapFloorFull(floor, shadowPercent, outputFileName)
    local minPos = g_map.getMinPosition()
    local maxPos = g_map.getMaxPosition()
    if not minPos or not maxPos then
        print("generateMapFloorFull: invalid map bounds. Run prepareClient() first.")
        return
    end

    outputFileName = outputFileName or string.format("full_floor_%d.png", floor)
    if not outputFileName:find("/") then
        outputFileName = "exported_images/map/" .. outputFileName
    end

    g_map.setShadowPercent(shadowPercent)
    g_map.setMinXToLoad(-1)
    g_map.setMinXToRender(0)
    g_map.setMaxXToRender(70000)
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
local satelliteLod = 32
local satellitePhase = '' -- 'satellite', 'minimap', or 'done'
local satelliteStartTime = 0
local satelliteLastCount = -1
local satelliteStableTicks = 0

function generateSatelliteData(outputDir, lod, shadowPercent)
    if satelliteGenerating then
        print('Satellite generation is already running.')
        return
    end

    outputDir = outputDir or 'satellite_output'
    lod = lod or 32
    shadowPercent = shadowPercent or 30

    satelliteGenerating = true
    SATELLITE_UI_STATUS.active = true
    SATELLITE_UI_STATUS.phase = 'satellite'
    SATELLITE_UI_STATUS.done = 0
    SATELLITE_UI_STATUS.total = 0
    SATELLITE_UI_STATUS.message = 'Generating satellite chunks'
    satelliteOutputDir = outputDir
    satelliteLod = lod
    satelliteStartTime = os.time()

    g_resources.makeDir(outputDir)
    g_map.setShadowPercent(shadowPercent)

    -- Phase 1: Generate satellite chunks
    satellitePhase = 'satellite'
    satelliteLastCount = -1
    satelliteStableTicks = 0
    g_map.setGeneratedAreasCount(0)
    g_map.generateSatelliteChunks(outputDir, lod)
    SATELLITE_UI_STATUS.total = g_map.getAreasCount()

    print('Starting satellite chunk generation (LOD=' .. lod .. ')...')

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
            satellitePhase = 'minimap'
            satelliteLastCount = -1
            satelliteStableTicks = 0
            SATELLITE_UI_STATUS.phase = 'minimap'
            SATELLITE_UI_STATUS.done = 0
            SATELLITE_UI_STATUS.message = 'Generating minimap chunks'
            g_map.setGeneratedAreasCount(0)
            g_map.generateMinimapChunks(satelliteOutputDir, satelliteLod)
            SATELLITE_UI_STATUS.total = g_map.getAreasCount()
            print('Starting minimap chunk generation (LOD=' .. satelliteLod .. ')...')
            g_dispatcher.scheduleEvent(satelliteProgressManager, 1000)
        else
            satellitePhase = 'done'
            g_map.saveMapDat(satelliteOutputDir)
            print('map.dat saved to ' .. satelliteOutputDir .. '/map.dat')
            print('Satellite data generation finished in ' .. (os.time() - satelliteStartTime) .. ' seconds.')
            satelliteGenerating = false
            SATELLITE_UI_STATUS.active = false
            SATELLITE_UI_STATUS.phase = 'done'
            SATELLITE_UI_STATUS.done = count
            SATELLITE_UI_STATUS.total = total
            SATELLITE_UI_STATUS.message = 'Satellite generation complete'
            satelliteLastCount = -1
            satelliteStableTicks = 0
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
g_logger.info("3. generateSatelliteData('satellite_output', 32, 30)")
g_logger.info("   - output dir, LOD (16/32/64), shadow percent")
