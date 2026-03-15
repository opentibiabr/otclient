local UI = nil
local virtualFloor = 7
local viewRadioGroup = nil
local loadedAssetsDir = nil
local loadedFloorSet = {} -- floors already indexed for loadedAssetsDir

-- Forward declaration — defined later in the file.
local refreshVirtualFloors

-- Surface View is only available for floors 0-7 (surface and above).
-- Underground floors (8-15) always use Map View.
local SEA_FLOOR = 7

local function ensureViewFloorsLoaded()
    local assetsDir = string.format("/data/things/%d", g_game.getClientVersion())

    -- Reset when switching game versions
    if assetsDir ~= loadedAssetsDir then
        g_satelliteMap.clear()
        loadedFloorSet = {}
        loadedAssetsDir = assetsDir
    end

    -- For surface floors: composite view needs [virtualFloor, SEA_FLOOR].
    -- For underground: only the current floor is needed (static minimap, map view only).
    local floorMax = (virtualFloor <= SEA_FLOOR) and SEA_FLOOR or virtualFloor

    local minNeeded, maxNeeded
    for f = virtualFloor, floorMax do
        if not loadedFloorSet[f] then
            if not minNeeded then
                minNeeded = f
            end
            maxNeeded = f
        end
    end

    if minNeeded then
        g_satelliteMap.loadFloors(assetsDir, minNeeded, maxNeeded)
        for f = minNeeded, maxNeeded do
            loadedFloorSet[f] = true
        end
    end
end

local function isSurfaceFloor(floor)
    return floor <= SEA_FLOOR
end

local function updateViewMode()
    if not UI or not viewRadioGroup then
        return
    end

    local minimapWidget = UI.MapBase.minimap
    local viewBase = UI.InformationBase.InternalBase.DisplayBase.ViewBase1
    local surfaceCheck = viewBase.SurfaceCheck
    local separatorScroll = viewBase.SeparatorScroll
    local separatorLabel = viewBase.SeparatorLabel

    local canUseSurface = isSurfaceFloor(virtualFloor) and g_satelliteMap.hasChunksForView(virtualFloor)

    -- Underground: force Map View and lock the Surface option.
    -- selectWidget must come BEFORE setEnabled: UIRadioGroup calls setChecked(false)
    -- on the deselected widget, which does not work correctly on a disabled widget.
    if not canUseSurface then
        viewRadioGroup:selectWidget(viewBase.MapCheck)
    end
    surfaceCheck:setEnabled(canUseSurface)

    -- Level separator scroll is only meaningful in Surface View on floors above z7 (z < 7).
    -- At z7 itself the composite has no lower floor to blend with, so the scroll is unused.
    local inSurfaceMode = canUseSurface and surfaceCheck:isChecked() and virtualFloor < SEA_FLOOR
    separatorScroll:setEnabled(inSurfaceMode)
    separatorLabel:setEnabled(inSurfaceMode)
end

function showMap()
    g_minimap.saveOtmm('/minimap.otmm')
    UI = g_ui.loadUI("map", contentContainer)
    UI:show()
    controllerCyclopedia:registerEvents(LocalPlayer, {
        onPositionChange = Cyclopedia.onUpdateCameraPosition
    }):execute()

    Cyclopedia.loadMap()

    controllerCyclopedia.ui.CharmsBase:setVisible(false)
    controllerCyclopedia.ui.GoldBase:setVisible(true)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(false)
    end
end

function Cyclopedia.loadMap()
    local clientVersion = g_game.getClientVersion()
    local minimapWidget = UI.MapBase.minimap

    -- Prime virtualFloor from current player position before any floor-dependent logic
    local player = g_game.getLocalPlayer()
    if player then
        local pos = player:getPosition()
        if pos then
            virtualFloor = pos.z
        end
    end

    g_minimap.clean()

    local loaded = false
    local minimapFile = "/minimap.otmm"
    local dataMinimapFile = "/data" .. minimapFile
    local versionedMinimapFile = "/minimap" .. clientVersion .. ".otmm"

    if g_resources.fileExists(dataMinimapFile) then
        loaded = g_minimap.loadOtmm(dataMinimapFile)
    end

    if not loaded and g_resources.fileExists(versionedMinimapFile) then
        loaded = g_minimap.loadOtmm(versionedMinimapFile)
    end

    if not loaded and g_resources.fileExists(minimapFile) then
        loaded = g_minimap.loadOtmm(minimapFile)
    end

    if not loaded then
        print("Minimap couldn't be loaded, file missing?")
    end

    -- Preserve the zoom declared in the OTUI style — load() overwrites it with the
    -- HUD minimap's saved settings zoom, which we don't want for Cyclopedia.
    local initialZoom = minimapWidget:getZoom()
    minimapWidget:load()
    minimapWidget:setZoom(initialZoom)
    minimapWidget:setUseStaticMinimap(true)

    -- Load satellite chunks for the floors needed by the current view only.
    -- Additional floors are indexed on demand when the user navigates deeper.
    ensureViewFloorsLoaded()
    local chunkCount = g_satelliteMap.hasChunksForView(virtualFloor) and 1 or 0

    -- Views panel is always visible; satellite chunks determine whether Surface View is enabled.
    local viewBase = UI.InformationBase.InternalBase.DisplayBase.ViewBase1
    local surfaceCheck = viewBase.SurfaceCheck
    local mapCheck = viewBase.MapCheck

    -- Clean up previous radio group if the map tab was reopened
    if viewRadioGroup then
        viewRadioGroup:destroy()
        viewRadioGroup = nil
    end

    viewRadioGroup = UIRadioGroup.create()
    viewRadioGroup:addWidget(surfaceCheck)
    viewRadioGroup:addWidget(mapCheck)

    viewRadioGroup.onSelectionChange = function(self, selected)
        local inSurface = selected == surfaceCheck and isSurfaceFloor(virtualFloor) and
                              g_satelliteMap.hasChunksForView(virtualFloor)
        minimapWidget:setSatelliteMode(inSurface)

        -- Sync separator scroll enabled state (only for floors above z7)
        local separatorScroll = viewBase.SeparatorScroll
        local separatorLabel = viewBase.SeparatorLabel
        local canUseSeparator = inSurface and virtualFloor < SEA_FLOOR
        separatorScroll:setEnabled(canUseSeparator)
        separatorLabel:setEnabled(canUseSeparator)
    end

    -- Default: Surface View when satellite data exists and on a surface floor, else Map View
    viewRadioGroup:selectWidget((chunkCount > 0 and isSurfaceFloor(virtualFloor)) and surfaceCheck or mapCheck)

    -- Hook separator scroll: adjusts floor compositing opacity (1.0 = all visible, 0.0 = target only)
    local separatorScroll = viewBase.SeparatorScroll
    separatorScroll.onValueChange = function(self, value)
        minimapWidget:setFloorSeparatorOpacity(value / 100.0)
    end
    -- Reset opacity on (re-)open
    minimapWidget:setFloorSeparatorOpacity(separatorScroll:getValue() / 100.0)

    updateViewMode()

    -- Sync flags from main minimap's live table (avoids stale g_settings on first open).
    local mainMinimap = modules.game_minimap and modules.game_minimap.getMiniMapUi and
                            modules.game_minimap.getMiniMapUi()
    if mainMinimap then
        for _, flag in pairs(mainMinimap.flags) do
            if not minimapWidget:getFlag(flag.pos) then
                minimapWidget:addFlag(flag.pos, flag.icon, flag.description)
            end
        end
    end

    -- Apply initial filter state: hide flags whose filter checkbox is unchecked.
    local markList = UI.InformationBase.InternalBase.DisplayBase.MarkList
    for _, flag in pairs(minimapWidget.flags) do
        local btn = markList:getChildById(tostring(flag.icon))
        flag:setVisible(btn ~= nil and btn:isChecked())
    end

    refreshVirtualFloors()
end

function Cyclopedia.toggleMapFlag(widget, checked)
    local flagType = tonumber(widget:getId())
    if not flagType then
        return
    end
    local minimapWidget = UI.MapBase.minimap
    for _, flag in pairs(minimapWidget.flags) do
        if flag.icon == flagType then
            flag:setVisible(checked)
        end
    end
end

function Cyclopedia.showAllFlags(checked)
    local list = UI.InformationBase.InternalBase.DisplayBase.MarkList
    for i = 0, list:getChildCount() - 1 do
        local btn = list:getChildByIndex(i)
        if btn then
            btn:setChecked(checked)
        end
    end
    local minimapWidget = UI.MapBase.minimap
    for _, flag in pairs(minimapWidget.flags) do
        flag:setVisible(checked)
    end
end

function Cyclopedia.moveMap(widget)
    local distance = 5
    local direction = widget:getId()
    if direction == "n" then
        UI.MapBase.minimap:move(0, distance)
    elseif direction == "ne" then
        UI.MapBase.minimap:move(-distance, distance)
    elseif direction == "e" then
        UI.MapBase.minimap:move(-distance, 0)
    elseif direction == "se" then
        UI.MapBase.minimap:move(-distance, -distance)
    elseif direction == "s" then
        UI.MapBase.minimap:move(0, -distance)
    elseif direction == "sw" then
        UI.MapBase.minimap:move(distance, -distance)
    elseif direction == "w" then
        UI.MapBase.minimap:move(distance, 0)
    elseif direction == "nw" then
        UI.MapBase.minimap:move(distance, distance)
    end
end

function Cyclopedia.floorScrollBar(oldValue, value)
    if value < oldValue then
        UI.MapBase.minimap:floorUp()
    elseif oldValue < value then
        UI.MapBase.minimap:floorDown()
    end

    if value < 0 then
        value = 0
    elseif value > 15 then
        value = 15
    end
end

function ConvertLayer(Value)
    if Value == 150 then
        return 7
    elseif Value == 300 then
        return 15
    elseif Value >= 1 and Value <= 300 then
        return math.floor((Value - 1) / 20)
    else
        return 0
    end
end

refreshVirtualFloors = function()
    local mark = UI.InformationBase.InternalBase.NavigationBase.layersMark
    mark:setMarginTop(((virtualFloor + 1) * 4) - 3)
    UI.InformationBase.InternalBase.NavigationBase.automapLayers:setImageClip((virtualFloor * 14) .. ' 0 14 67')

    -- Update player marker (cross) visibility on the minimap
    local cross = UI.MapBase.minimap.cross
    if cross then
        if virtualFloor > SEA_FLOOR then
            cross:setVisible(false)
        elseif virtualFloor < SEA_FLOOR then
            cross:setVisible(true)
            cross:setIconColor("#ffffff80")
        else
            cross:setVisible(true)
            cross:setIconColor("#ffffffff")
        end
    end
end

function Cyclopedia.onUpdateCameraPosition()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    local pos = player:getPosition()
    if not pos then
        return
    end

    local minimapWidget = UI.MapBase.minimap
    if not minimapWidget:isDragging() then
        if not fullmapView then
            minimapWidget:setCameraPosition(player:getPosition())
        end

        minimapWidget:setCrossPosition(player:getPosition(), true)
    end

    local prevFloor = virtualFloor
    virtualFloor = pos.z

    -- When the player changes floor, sync the visual floor indicator and
    -- satellite/map view toggle (e.g. walking underground disables Surface View).
    if virtualFloor ~= prevFloor then
        ensureViewFloorsLoaded()
        refreshVirtualFloors()
        updateViewMode()
    end
end

function Cyclopedia.onClickRoseButton(dir)
    if dir == 'north' then
        UI.MapBase.minimap:move(0, 1)
    elseif dir == 'north-east' then
        UI.MapBase.minimap:move(-1, 1)
    elseif dir == 'east' then
        UI.MapBase.minimap:move(-1, 0)
    elseif dir == 'south-east' then
        UI.MapBase.minimap:move(-1, -1)
    elseif dir == 'south' then
        UI.MapBase.minimap:move(0, -1)
    elseif dir == 'south-west' then
        UI.MapBase.minimap:move(1, -1)
    elseif dir == 'west' then
        UI.MapBase.minimap:move(1, 0)
    elseif dir == 'north-west' then
        UI.MapBase.minimap:move(1, 1)
    end
end

function Cyclopedia.setZooom(zoom)
    if zoom then
        UI.MapBase.minimap:zoomIn()
    else
        UI.MapBase.minimap:zoomOut()
    end
end

function Cyclopedia.downLayer()
    if virtualFloor == 15 then
        return
    end

    UI.MapBase.minimap:floorDown(1)
    virtualFloor = virtualFloor + 1
    ensureViewFloorsLoaded()
    refreshVirtualFloors()
    updateViewMode()
end

function Cyclopedia.upLayer()
    if virtualFloor == 0 then
        return
    end

    UI.MapBase.minimap:floorUp(1)
    virtualFloor = virtualFloor - 1
    ensureViewFloorsLoaded()
    refreshVirtualFloors()
    updateViewMode()
end
