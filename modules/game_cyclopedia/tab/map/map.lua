local UI = nil
local virtualFloor = 7

function showMap()
    g_minimap.saveOtmm('/minimap.otmm')
    UI = g_ui.loadUI("map", contentContainer)
    UI:show()
    controllerCyclopedia:registerEvents(LocalPlayer, {
        onPositionChange = Cyclopedia.onUpdateCameraPosition
    }):execute()

    Cyclopedia.prevFloor = 7
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

    minimapWidget:load()
    -- minimapWidget:hideFlags()
end

function Cyclopedia.CreateMarkItem(Data)
    local MarkItem = g_ui.createWidget("MarkListItem", UI.InformationBase.InternalBase.DisplayBase.MarkList)
    MarkItem:setIcon("/images/game/minimap/flag" .. Data.flagId)
end

function Cyclopedia.toggleMapFlag(widget, checked)
    -- UI.MapBase.minimap:filterFlag(widget:getId(), checked)
end

function Cyclopedia.showAllFlags(checked)
    local size = UI.InformationBase.InternalBase.DisplayBase.MarkList:getChildCount()
    if checked then
        for i = 0, size do
            local flag = UI.InformationBase.InternalBase.DisplayBase.MarkList[i]
            if flag then
                flag:setChecked(true)
            end
        end
    else
        for i = 0, size do
            local flag = UI.InformationBase.InternalBase.DisplayBase.MarkList[i]
            if flag then
                flag:setChecked(false)
            end
        end
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

    virtualFloor = pos.z
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

local function refreshVirtualFloors()
    UI.InformationBase.InternalBase.NavigationBase.layersMark:setMarginTop(((virtualFloor + 1) * 4) - 3)
    UI.InformationBase.InternalBase.NavigationBase.automapLayers:setImageClip((virtualFloor * 14) .. ' 0 14 67')
end

function Cyclopedia.downLayer()
    if virtualFloor == 15 then
        return
    end

    UI.MapBase.minimap:floorDown(1)
    virtualFloor = virtualFloor + 1
    refreshVirtualFloors()
end

function Cyclopedia.upLayer()
    if virtualFloor == 0 then
        return
    end

    UI.MapBase.minimap:floorUp(1)
    virtualFloor = virtualFloor - 1
    refreshVirtualFloors()
end
