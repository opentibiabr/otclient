local UI = nil
local ensureHouseMinimap = nil
local rememberHouseViewState = nil
local houseViewStateLog = nil
local dumpHouseViewState = nil
local applyFilterChecksFromViewState = nil

function showHouse()
    UI = g_ui.loadUI("house", contentContainer)
    UI:show()
    dumpHouseViewState("showHouse:start")
    UI.LateralBase.LayerScrollbar.decrementButton:setVisible(false)
    UI.LateralBase.LayerScrollbar.incrementButton:setVisible(false)
    UI.LateralBase.LayerScrollbar.sliderButton:setImageSource("")
    --[[
    g_ui.createWidget("MapLayerSelector", UI.LateralBase.LayerScrollbar.sliderButton)
    function UI.LateralBase.LayerScrollbar:onValueChange(value)
        local rect = {
            width = 14,
            height = 67,
            y = 0,
            x = Cyclopedia.ConvertLayer(value) * 14
        }

        UI.LateralBase.LayerIndicator:setImageClip(rect)
    end
    ]]--

    UI.LateralBase.LayerScrollbar:setValue(150)

    controllerCyclopedia.ui.CharmsBase:setVisible(false)
    controllerCyclopedia.ui.GoldBase:setVisible(true)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(false)
    end
    -- Cyclopedia.House.Data = json_data

    UI.TopBase.StatesOption:clearOptions()
    UI.TopBase.CityOption:clearOptions()
    UI.TopBase.SortOption:clearOptions()

    for i = 1, #Cyclopedia.StateList do
        UI.TopBase.StatesOption:addOption(Cyclopedia.StateList[i].Title, i)
    end
    UI.TopBase.StatesOption.onOptionChange = Cyclopedia.houseChangeState

    for i = 0, #Cyclopedia.CityList do
        UI.TopBase.CityOption:addOption(Cyclopedia.CityList[i].Title, i)
    end
    UI.TopBase.CityOption.onOptionChange = Cyclopedia.selectTown

    for i = 1, #Cyclopedia.SortList do
        UI.TopBase.SortOption:addOption(Cyclopedia.SortList[i].Title, i)
    end
    UI.TopBase.SortOption.onOptionChange = Cyclopedia.houseSort

    Cyclopedia.House.Loaded = true

    UI.bidArea:setVisible(false)
    UI.ListBase:setVisible(true)
    ensureHouseMinimap()
    local viewState = Cyclopedia.House.ViewState or {}
    Cyclopedia.House.IsRestoringViewState = true

    local desiredFilterMode = viewState.filterMode == "guildhalls" and "guildhalls" or "houses"
    if desiredFilterMode == "guildhalls" then
        Cyclopedia.houseFilter(UI.TopBase.GuildhallsCheck)
    else
        Cyclopedia.houseFilter(UI.TopBase.HousesCheck)
    end
    applyFilterChecksFromViewState()

    local desiredStateText = viewState.stateText or "All States"
    if not UI.TopBase.StatesOption:isOption(desiredStateText) then
        desiredStateText = "All States"
    end
    UI.TopBase.StatesOption:setOption(desiredStateText, true)
    Cyclopedia.houseChangeState(UI.TopBase.StatesOption)

    local desiredSortText = viewState.sortText or "Sort by name"
    if not UI.TopBase.SortOption:isOption(desiredSortText) then
        desiredSortText = "Sort by name"
    end
    UI.TopBase.SortOption:setOption(desiredSortText, true)
    local sortOption = UI.TopBase.SortOption:getCurrentOption()
    if sortOption then
        Cyclopedia.houseSort(UI.TopBase.SortOption, sortOption.text, sortOption.data)
    end

    local accountHouseCount = Cyclopedia.House.Info and Cyclopedia.House.Info.accountHouseCount or 0
    houseViewStateLog("showHouse accountHouseCount=%d", accountHouseCount)
    local desiredCityText = viewState.cityText
    local desiredCityType = viewState.cityType
    if not desiredCityText then
        if accountHouseCount > 0 then
            desiredCityText = "Own Houses"
            desiredCityType = 0
        else
            desiredCityText = Cyclopedia.CityList[1] and Cyclopedia.CityList[1].Title or "Ab'Dendriel"
            desiredCityType = 1
        end
    elseif desiredCityText == "Own Houses" and accountHouseCount <= 0 then
        desiredCityText = Cyclopedia.CityList[1] and Cyclopedia.CityList[1].Title or "Ab'Dendriel"
        desiredCityType = 1
    end

    if not UI.TopBase.CityOption:isOption(desiredCityText) then
        desiredCityText = Cyclopedia.CityList[1] and Cyclopedia.CityList[1].Title or "Ab'Dendriel"
        desiredCityType = 1
    end

    UI.TopBase.CityOption:setOption(desiredCityText, true)
    Cyclopedia.selectTown(nil, desiredCityText, desiredCityType or 1)
    Cyclopedia.House.IsRestoringViewState = false
    dumpHouseViewState("showHouse:after-restore")
    rememberHouseViewState()
end

Cyclopedia.House = {}
Cyclopedia.StateList = {
    { Title = "All States" },
    { Title = "Auctioned" },
    { Title = "Rented" }
}

Cyclopedia.CityList = {
    [0] = { Title = "Own Houses" },
    { Title = "Ab'Dendriel" },
    { Title = "Ankrahmun" },
    { Title = "Carlin" },
    { Title = "Darashia" },
    { Title = "Edron" },
    { Title = "Farmine" },
    { Title = "Gray Beach" },
    { Title = "Issavi" },
    { Title = "Kazordoon" },
    { Title = "Liberty Bay" },
    { Title = "Moonfall" },
    { Title = "Port Hope" },
    { Title = "Rathleton" },
    { Title = "Silvertides" },
    { Title = "Svargrond" },
    { Title = "Thais" },
    { Title = "Venore" },
    { Title = "Yalahar" }
}

Cyclopedia.SortList = {
    { Title = "Sort by name" },
    { Title = "Sort by size" },
    { Title = "Sort by rent" },
    { Title = "Sort by bid" },
    { Title = "Sort by auction end" }
}

Cyclopedia.House.Data = Cyclopedia.House.Data or {}
Cyclopedia.House.Info = Cyclopedia.House.Info or {}
Cyclopedia.House.ViewState = Cyclopedia.House.ViewState or {
    stateText = "All States",
    stateType = 1,
    cityText = nil,
    cityType = nil,
    sortText = "Sort by name",
    sortType = 1,
    filterMode = "houses",
    selectedHouseId = nil,
    houseZoomById = {}
}
Cyclopedia.House.IsRestoringViewState = Cyclopedia.House.IsRestoringViewState or false
Cyclopedia.House.SuppressSelectionPersist = Cyclopedia.House.SuppressSelectionPersist or false

local HOUSE_LUA_LOG_TAG = "[cyclopedia-houses-lua]"
local HOUSE_LUA_LOG_ENABLED = false
local HOUSE_VIEWSTATE_LOG_TAG = "[cyclopedia-houses-viewstate]"
local HOUSE_VIEWSTATE_LOG_ENABLED = false
local HOUSE_METADATA_WARNED = false
local HOUSE_MINIMAP_MIN_ZOOM = 1
local HOUSE_MINIMAP_MAX_ZOOM = 3
local HOUSE_ZOOM_LOG_TAG = "[cyclopedia-houses-zoom]"
local HOUSE_ZOOM_LOG_ENABLED = false
local HOUSE_MARK_ICON = "/game_cyclopedia/images/icon-map-house"
local HOUSE_MINIMAP_SAMPLE_RADIUS = 4
local HOUSE_MINIMAP_MIN_KNOWN_TILES = 14
local HOUSE_MINIMAP_MIN_KNOWN_RATIO = 0.10
local HOUSE_MINIMAP_NEAR_RADIUS = 1
local HOUSE_MINIMAP_MIN_NEAR_KNOWN_TILES = 3
local houseMinimap = nil
local houseMapCenterButton = nil
local houseMapMarkButton = nil
local houseMapZoomInButton = nil
local houseMapZoomOutButton = nil
local houseMinimapCenterPos = nil
local houseMapUnknownLabel = nil

local function houseZoomLog(message, ...)
    if not HOUSE_ZOOM_LOG_ENABLED then
        return
    end

    local text = message
    if select("#", ...) > 0 then
        text = string.format(message, ...)
    end
    g_logger.info(HOUSE_ZOOM_LOG_TAG .. " " .. text)
end

local function clampZoomValue(value, minZoom, maxZoom)
    local zoom = tonumber(value) or 0
    if zoom < minZoom then
        return minZoom
    end
    if zoom > maxZoom then
        return maxZoom
    end
    return math.floor(zoom)
end

local function getHouseZoomProfile(sqm)
    local minZoom = HOUSE_MINIMAP_MIN_ZOOM
    local maxZoom = HOUSE_MINIMAP_MAX_ZOOM
    local defaultZoom = 1

    defaultZoom = clampZoomValue(defaultZoom, minZoom, maxZoom)
    return {
        minZoom = minZoom,
        maxZoom = maxZoom,
        defaultZoom = defaultZoom
    }
end

local function getSavedHouseZoom(houseId)
    local state = Cyclopedia.House.ViewState or {}
    state.houseZoomById = state.houseZoomById or {}
    if not houseId then
        return nil
    end
    return state.houseZoomById[houseId]
end

local function saveHouseZoom(houseId, zoom)
    if not houseId then
        return
    end
    Cyclopedia.House.ViewState = Cyclopedia.House.ViewState or {}
    Cyclopedia.House.ViewState.houseZoomById = Cyclopedia.House.ViewState.houseZoomById or {}
    Cyclopedia.House.ViewState.houseZoomById[houseId] = zoom
end

local function applyHouseMinimapZoom(data, minimap)
    if not data or not minimap then
        return
    end

    local profile = getHouseZoomProfile(data.sqm)
    local savedZoom = getSavedHouseZoom(data.id)
    local appliedZoom = clampZoomValue(savedZoom ~= nil and savedZoom or profile.defaultZoom, profile.minZoom, profile.maxZoom)

    minimap:setMixZoom(profile.minZoom)
    minimap:setMaxZoom(profile.maxZoom)
    minimap:setZoom(appliedZoom)

    houseZoomLog("houseId=%s sqm=%s range=[%d..%d] default=%d applied=%d saved=%s", tostring(data.id), tostring(data.sqm),
        profile.minZoom, profile.maxZoom, profile.defaultZoom, appliedZoom, tostring(savedZoom))
end

houseViewStateLog = function(message, ...)
    if not HOUSE_VIEWSTATE_LOG_ENABLED then
        return
    end

    local text = message
    if select("#", ...) > 0 then
        text = string.format(message, ...)
    end
    g_logger.info(HOUSE_VIEWSTATE_LOG_TAG .. " " .. text)
end

dumpHouseViewState = function(prefix)
    local state = Cyclopedia.House.ViewState or {}
    houseViewStateLog(
        "%s stateText='%s' stateType=%s cityText='%s' cityType=%s sortText='%s' sortType=%s filterMode='%s' selectedHouseId=%s lastTown='%s' restoring=%s",
        prefix or "viewState",
        tostring(state.stateText),
        tostring(state.stateType),
        tostring(state.cityText),
        tostring(state.cityType),
        tostring(state.sortText),
        tostring(state.sortType),
        tostring(state.filterMode),
        tostring(state.selectedHouseId),
        tostring(Cyclopedia.House.lastTown),
        tostring(Cyclopedia.House.IsRestoringViewState)
    )
end

local function selectHouseWithoutPersist(widget)
    Cyclopedia.House.SuppressSelectionPersist = true
    Cyclopedia.selectHouse(widget)
    Cyclopedia.House.SuppressSelectionPersist = false
end

rememberHouseViewState = function()
    if Cyclopedia.House.IsRestoringViewState then
        houseViewStateLog("remember skipped because restoring=true")
        return
    end

    if not Cyclopedia.House.ViewState then
        return
    end

    if UI and UI.TopBase then
        local currentState = UI.TopBase.StatesOption and UI.TopBase.StatesOption:getCurrentOption() or nil
        if currentState then
            Cyclopedia.House.ViewState.stateText = currentState.text
            Cyclopedia.House.ViewState.stateType = currentState.data
        end

        local currentCity = UI.TopBase.CityOption and UI.TopBase.CityOption:getCurrentOption() or nil
        if currentCity then
            Cyclopedia.House.ViewState.cityText = currentCity.text
            Cyclopedia.House.ViewState.cityType = currentCity.data
        end

        local currentSort = UI.TopBase.SortOption and UI.TopBase.SortOption:getCurrentOption() or nil
        if currentSort then
            Cyclopedia.House.ViewState.sortText = currentSort.text
            Cyclopedia.House.ViewState.sortType = currentSort.data
        end

        if UI.TopBase.GuildhallsCheck and UI.TopBase.GuildhallsCheck:isChecked() then
            Cyclopedia.House.ViewState.filterMode = "guildhalls"
        else
            Cyclopedia.House.ViewState.filterMode = "houses"
        end
    end

    dumpHouseViewState("remember")
end

local function houseLog(level, message, ...)
    if not HOUSE_LUA_LOG_ENABLED then
        return
    end

    local text = message
    if select("#", ...) > 0 then
        text = string.format(message, ...)
    end

    if level == "warning" then
        g_logger.warning(HOUSE_LUA_LOG_TAG .. " " .. text)
    elseif level == "error" then
        g_logger.error(HOUSE_LUA_LOG_TAG .. " " .. text)
    else
        g_logger.info(HOUSE_LUA_LOG_TAG .. " " .. text)
    end
end

local function houseDebug(message, ...)
    houseLog("info", message, ...)
end

local function resetButtons()
    if UI.LateralBase:getChildById("bidButton") then
        UI.LateralBase:getChildById("bidButton"):destroy()
    end

    if UI.LateralBase:getChildById("transferButton") then
        UI.LateralBase:getChildById("transferButton"):destroy()
    end

    if UI.LateralBase:getChildById("moveOutButton") then
        UI.LateralBase:getChildById("moveOutButton"):destroy()
    end

    if UI.LateralBase:getChildById("cancelTransfer") then
        UI.LateralBase:getChildById("cancelTransfer"):destroy()
    end

    if UI.LateralBase:getChildById("acceptTransfer") then
        UI.LateralBase:getChildById("acceptTransfer"):destroy()
    end

    if UI.LateralBase:getChildById("rejectTransfer") then
        UI.LateralBase:getChildById("rejectTransfer"):destroy()
    end
end

local function createHouseMinimapControls()
    if not UI or not UI.LateralBase or not UI.LateralBase.MapViewbase then
        return
    end

    if houseMapCenterButton and houseMapCenterButton:isDestroyed() then
        houseMapCenterButton = nil
    end
    if houseMapMarkButton and houseMapMarkButton:isDestroyed() then
        houseMapMarkButton = nil
    end
    if houseMapZoomInButton and houseMapZoomInButton:isDestroyed() then
        houseMapZoomInButton = nil
    end
    if houseMapZoomOutButton and houseMapZoomOutButton:isDestroyed() then
        houseMapZoomOutButton = nil
    end
    if houseMapUnknownLabel and houseMapUnknownLabel:isDestroyed() then
        houseMapUnknownLabel = nil
    end

    if not houseMapCenterButton then
        houseMapCenterButton = g_ui.createWidget("Button", UI.LateralBase)
        houseMapCenterButton:setId("houseMapCenterButton")
        houseMapCenterButton:setText("House")
        houseMapCenterButton:setWidth(52)
        houseMapCenterButton:setHeight(20)
        houseMapCenterButton:addAnchor(AnchorBottom, "parent", AnchorBottom)
        houseMapCenterButton:addAnchor(AnchorRight, "parent", AnchorRight)
        houseMapCenterButton:setMarginBottom(7)
        houseMapCenterButton:setMarginRight(76)
    end

    if not houseMapZoomInButton then
        houseMapZoomInButton = g_ui.createWidget("Button", UI.LateralBase.MapViewbase)
        houseMapZoomInButton:setId("houseMapZoomInButton")
        houseMapZoomInButton:setText("+")
        houseMapZoomInButton:setWidth(18)
        houseMapZoomInButton:setHeight(18)
        houseMapZoomInButton:addAnchor(AnchorBottom, "parent", AnchorBottom)
        houseMapZoomInButton:addAnchor(AnchorRight, "parent", AnchorRight)
        houseMapZoomInButton:setMarginBottom(24)
        houseMapZoomInButton:setMarginRight(4)
    end

    if not houseMapZoomOutButton then
        houseMapZoomOutButton = g_ui.createWidget("Button", UI.LateralBase.MapViewbase)
        houseMapZoomOutButton:setId("houseMapZoomOutButton")
        houseMapZoomOutButton:setText("-")
        houseMapZoomOutButton:setWidth(18)
        houseMapZoomOutButton:setHeight(18)
        houseMapZoomOutButton:addAnchor(AnchorBottom, "parent", AnchorBottom)
        houseMapZoomOutButton:addAnchor(AnchorRight, "parent", AnchorRight)
        houseMapZoomOutButton:setMarginBottom(4)
        houseMapZoomOutButton:setMarginRight(4)
    end

    if not houseMapMarkButton then
        houseMapMarkButton = g_ui.createWidget("Button", UI.LateralBase)
        houseMapMarkButton:setId("houseMapMarkButton")
        houseMapMarkButton:setText("Mark")
        houseMapMarkButton:setWidth(52)
        houseMapMarkButton:setHeight(20)
        houseMapMarkButton:addAnchor(AnchorBottom, "prev", AnchorBottom)
        houseMapMarkButton:addAnchor(AnchorRight, "prev", AnchorLeft)
        houseMapMarkButton:setMarginRight(5)
    end

    if not houseMapUnknownLabel then
        houseMapUnknownLabel = g_ui.createWidget("Label", UI.LateralBase.MapViewbase)
        houseMapUnknownLabel:setId("houseMapUnknownLabel")
        houseMapUnknownLabel:setVisible(false)
        houseMapUnknownLabel:setTextAlign(AlignCenter)
        houseMapUnknownLabel:setFont("verdana-11px-antialised")
        houseMapUnknownLabel:setColor("#C0C0C0")
        houseMapUnknownLabel:setTextWrap(true)
        houseMapUnknownLabel:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
        houseMapUnknownLabel:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
        houseMapUnknownLabel:setWidth(170)
        houseMapUnknownLabel:setHeight(54)
        houseMapUnknownLabel:setPhantom(false)
    end
end

ensureHouseMinimap = function()
    if not UI or not UI.LateralBase or not UI.LateralBase.MapViewbase then
        return nil
    end

    if houseMinimap and houseMinimap:isDestroyed() then
        houseMinimap = nil
    end

    if houseMinimap and not houseMinimap:isDestroyed() then
        return houseMinimap
    end

    houseMinimap = g_ui.createWidget("Minimap", UI.LateralBase.MapViewbase)
    houseMinimap:setId("houseMinimap")
    houseMinimap:addAnchor(AnchorTop, "parent", AnchorTop)
    houseMinimap:addAnchor(AnchorBottom, "parent", AnchorBottom)
    houseMinimap:addAnchor(AnchorLeft, "parent", AnchorLeft)
    houseMinimap:addAnchor(AnchorRight, "parent", AnchorRight)
    houseMinimap:setMarginTop(1)
    houseMinimap:setMarginBottom(1)
    houseMinimap:setMarginLeft(1)
    houseMinimap:setMarginRight(1)
    houseMinimap:disableAutoWalk()
    houseMinimap:hideFloor()
    houseMinimap:hideZoom()
    houseMinimap:setMixZoom(HOUSE_MINIMAP_MIN_ZOOM)
    houseMinimap:setMaxZoom(HOUSE_MINIMAP_MAX_ZOOM)
    houseMinimap:setZoom(0)
    houseMinimap:setVisible(false)

    createHouseMinimapControls()

    if houseMapCenterButton then
        houseMapCenterButton.onClick = function()
            if houseMinimap and houseMinimapCenterPos then
                houseMinimap:setCameraPosition(houseMinimapCenterPos)
                houseMinimap:setCrossPosition(houseMinimapCenterPos)
            end
        end
    end

    if houseMapMarkButton then
        houseMapMarkButton.onClick = function()
            local selected = Cyclopedia.House and Cyclopedia.House.lastSelectedHouse
            local data = selected and selected.data or nil
            if not data or (data.entryx or 0) <= 0 or (data.entryy or 0) <= 0 or (data.entryz or -1) < 0 then
                displayInfoBox("House Mark", "This house has no valid entry position.")
                return
            end

            local minimapUi = nil
            if modules and modules.game_minimap and type(modules.game_minimap.getMiniMapUi) == "function" then
                minimapUi = modules.game_minimap.getMiniMapUi()
            elseif type(getMiniMapUi) == "function" then
                minimapUi = getMiniMapUi()
            end

            if not minimapUi then
                displayInfoBox("House Mark", "Minimap is not available right now.")
                return
            end

            local pos = { x = data.entryx, y = data.entryy, z = data.entryz }
            local description = data.name and data.name ~= "" and data.name or string.format("House %d", data.id or 0)

            local function findFlagByDescription(minimap, targetDescription)
                if not minimap or not minimap.flags or not targetDescription then
                    return nil
                end

                local normalized = targetDescription:lower()
                for _, flag in pairs(minimap.flags) do
                    if type(flag.description) == "string" and flag.description:lower() == normalized then
                        return flag
                    end
                end
                return nil
            end

            local function ensureHouseMark(minimap, markPos, markDescription)
                if not minimap then
                    return false, "minimap unavailable"
                end

                local byPos = minimap:getFlag(markPos)
                if byPos and byPos.icon == HOUSE_MARK_ICON and byPos.description == markDescription then
                    return false, "already exists at this position"
                end

                local byName = findFlagByDescription(minimap, markDescription)
                if byName and byName.pos and (byName.pos.x ~= markPos.x or byName.pos.y ~= markPos.y or byName.pos.z ~= markPos.z) then
                    minimap:removeFlag(byName.pos)
                end

                if byPos then
                    minimap:removeFlag(markPos)
                end

                minimap:addFlag(markPos, HOUSE_MARK_ICON, markDescription, false)
                return true, "created"
            end

            local createdMain = ensureHouseMark(minimapUi, pos, description)

            if Cyclopedia and type(Cyclopedia.getMapMinimap) == "function" then
                local cyclopediaMapMinimap = Cyclopedia.getMapMinimap()
                if cyclopediaMapMinimap then
                    ensureHouseMark(cyclopediaMapMinimap, pos, description)
                    if type(Cyclopedia.applyMapFlagFilters) == "function" then
                        Cyclopedia.applyMapFlagFilters()
                    end
                end
            end

            if createdMain then
                displayInfoBox("House Mark", string.format("Map marker added: %s", description))
            else
                displayInfoBox("House Mark", string.format("Map marker already exists: %s", description))
            end
        end
    end

    if houseMapZoomInButton then
        houseMapZoomInButton.onClick = function()
            if houseMinimap then
                houseMinimap:zoomIn()
                local selected = Cyclopedia.House and Cyclopedia.House.lastSelectedHouse
                local data = selected and selected.data or nil
                if data and houseMinimap.getZoom then
                    local currentZoom = houseMinimap:getZoom()
                    saveHouseZoom(data.id, currentZoom)
                    houseZoomLog("zoomIn houseId=%s currentZoom=%s", tostring(data.id), tostring(currentZoom))
                end
            end
        end
    end

    if houseMapZoomOutButton then
        houseMapZoomOutButton.onClick = function()
            if houseMinimap then
                houseMinimap:zoomOut()
                local selected = Cyclopedia.House and Cyclopedia.House.lastSelectedHouse
                local data = selected and selected.data or nil
                if data and houseMinimap.getZoom then
                    local currentZoom = houseMinimap:getZoom()
                    saveHouseZoom(data.id, currentZoom)
                    houseZoomLog("zoomOut houseId=%s currentZoom=%s", tostring(data.id), tostring(currentZoom))
                end
            end
        end
    end

    return houseMinimap
end

local function updateHousePreview(data)
    if not UI or not data then
        return
    end

    local minimap = ensureHouseMinimap()
    local hasEntry = (data.entryx or 0) > 0 and (data.entryy or 0) > 0 and (data.entryz or -1) >= 0
    local hasMinimapCoverage = false
    if hasEntry then
        local samples = 0
        local known = 0
        for dx = -HOUSE_MINIMAP_SAMPLE_RADIUS, HOUSE_MINIMAP_SAMPLE_RADIUS do
            for dy = -HOUSE_MINIMAP_SAMPLE_RADIUS, HOUSE_MINIMAP_SAMPLE_RADIUS do
                samples = samples + 1
                local color = g_map.getMinimapColor({ x = data.entryx + dx, y = data.entryy + dy, z = data.entryz }) or 0
                if color ~= 0 then
                    known = known + 1
                end
            end
        end
        local knownRatio = samples > 0 and (known / samples) or 0
        local centerColor = g_map.getMinimapColor({ x = data.entryx, y = data.entryy, z = data.entryz }) or 0
        local nearSamples = 0
        local nearKnown = 0
        for dx = -HOUSE_MINIMAP_NEAR_RADIUS, HOUSE_MINIMAP_NEAR_RADIUS do
            for dy = -HOUSE_MINIMAP_NEAR_RADIUS, HOUSE_MINIMAP_NEAR_RADIUS do
                nearSamples = nearSamples + 1
                local nearColor = g_map.getMinimapColor({ x = data.entryx + dx, y = data.entryy + dy, z = data.entryz }) or 0
                if nearColor ~= 0 then
                    nearKnown = nearKnown + 1
                end
            end
        end

        hasMinimapCoverage = centerColor ~= 0 and nearKnown >= HOUSE_MINIMAP_MIN_NEAR_KNOWN_TILES and
            known >= HOUSE_MINIMAP_MIN_KNOWN_TILES and knownRatio >= HOUSE_MINIMAP_MIN_KNOWN_RATIO
        if not hasMinimapCoverage then
            houseLog("warning",
                "houseId=%d has low minimap coverage around entry (center=%d near=%d/%d wide=%d/%d %.2f%%), using image fallback",
                data.id or 0, centerColor, nearKnown, nearSamples, known, samples, knownRatio * 100)
        end
    end

    if minimap and hasEntry and hasMinimapCoverage then
        local centerPos = { x = data.entryx, y = data.entryy, z = data.entryz }
        houseMinimapCenterPos = centerPos
        minimap:setVisible(true)
        applyHouseMinimapZoom(data, minimap)
        minimap:setCameraPosition(centerPos)
        minimap:setCrossPosition(centerPos)
        UI.LateralBase.MapViewbase.noHouse:setVisible(false)
        UI.LateralBase.MapViewbase.reload:setVisible(false)
        UI.LateralBase.MapViewbase.houseImage:setVisible(false)
        if houseMapCenterButton then
            houseMapCenterButton:setVisible(true)
        end
        if houseMapMarkButton then
            houseMapMarkButton:setVisible(true)
        end
        if houseMapZoomInButton then
            houseMapZoomInButton:setVisible(true)
        end
        if houseMapZoomOutButton then
            houseMapZoomOutButton:setVisible(true)
        end
        if houseMapUnknownLabel then
            houseMapUnknownLabel:setVisible(false)
        end
        return
    end

    if minimap then
        minimap:setVisible(false)
    end
    if houseMapCenterButton then
        houseMapCenterButton:setVisible(false)
    end
    if houseMapMarkButton then
        houseMapMarkButton:setVisible(hasEntry)
    end
    if houseMapZoomInButton then
        houseMapZoomInButton:setVisible(false)
    end
    if houseMapZoomOutButton then
        houseMapZoomOutButton:setVisible(false)
    end

    UI.LateralBase.MapViewbase.noHouse:setVisible(false)
    UI.LateralBase.MapViewbase.reload:setVisible(true)
    UI.LateralBase.MapViewbase.houseImage:setVisible(false)
    if houseMapUnknownLabel then
        houseMapUnknownLabel:setVisible(false)
    end
    local imagePath = string.format("/game_cyclopedia/images/houses/%s.png", data.id)
    if g_resources.fileExists(imagePath) then
        UI.LateralBase.MapViewbase.reload:setVisible(false)
        UI.LateralBase.MapViewbase.houseImage:setVisible(true)
        UI.LateralBase.MapViewbase.houseImage:setImageSource(imagePath)
        if hasEntry and not hasMinimapCoverage and houseMapUnknownLabel then
            local townName = Cyclopedia.House.lastTown
            if townName and townName ~= "" then
                houseMapUnknownLabel:setText(string.format("House map unknown.\nExplore more of %s to unlock this preview.",
                    townName))
            else
                houseMapUnknownLabel:setText("House map unknown.\nExplore this city to unlock this preview.")
            end
            houseMapUnknownLabel:setVisible(true)
        end
    elseif hasEntry and not hasMinimapCoverage and houseMapUnknownLabel then
        local townName = Cyclopedia.House.lastTown
        if townName and townName ~= "" then
            houseMapUnknownLabel:setText(string.format("House map unknown.\nExplore more of %s to unlock this preview.",
                townName))
        else
            houseMapUnknownLabel:setText("House map unknown.\nExplore this city to unlock this preview.")
        end
        houseMapUnknownLabel:setVisible(true)
    end
end

local function resetSelectedInfo()
    UI.LateralBase.yourLimitBidGold:setVisible(false)
    UI.LateralBase.yourLimitBid:setVisible(false)
    UI.LateralBase.yourLimitLabel:setVisible(false)
    UI.LateralBase.highestBid:setVisible(false)
    UI.LateralBase.highestBidGold:setVisible(false)
    UI.LateralBase.subAuctionLabel:setVisible(false)
    UI.LateralBase.subAuctionText:setVisible(false)
    UI.LateralBase.transferLabel:setVisible(false)
    UI.LateralBase.transferValue:setVisible(false)
    UI.LateralBase.transferGold:setVisible(false)
end

local function applyHouseSortByType(sortType)
    if not Cyclopedia.House.Data then
        return
    end

    if sortType == 1 then
        table.sort(Cyclopedia.House.Data, function(a, b)
            return a.name < b.name
        end)
    elseif sortType == 2 then
        table.sort(Cyclopedia.House.Data, function(a, b)
            return a.sqm < b.sqm
        end)
    elseif sortType == 4 then
        table.sort(Cyclopedia.House.Data, function(a, b)
            if a.hasBid and not b.hasBid then
                return true
            elseif not a.hasBid and b.hasBid then
                return false
            else
                return false
            end
        end)
    elseif sortType == 5 then
        table.sort(Cyclopedia.House.Data, function(a, b)
            if a.hasBid and not b.hasBid then
                return true
            elseif not a.hasBid and b.hasBid then
                return false
            else
                return false
            end
        end)
    end
end

local function applyHouseVisibilityByViewState()
    if not Cyclopedia.House.Data then
        return
    end

    local viewState = Cyclopedia.House.ViewState or {}
    local onlyGuildHall = viewState.filterMode == "guildhalls"
    local stateType = tonumber(viewState.stateType) or 1

    for _, data in ipairs(Cyclopedia.House.Data) do
        local baseVisible = false
        if onlyGuildHall then
            baseVisible = data.gh and true or false
        else
            baseVisible = not data.gh
        end
        if stateType == 3 then
            data.visible = baseVisible and (data.rented or data.inTransfer)
        elseif stateType == 2 then
            data.visible = baseVisible and not data.rented
        else
            data.visible = baseVisible
        end
    end
end

applyFilterChecksFromViewState = function()
    if not UI or not UI.TopBase or not Cyclopedia.House.ViewState then
        return
    end

    local guildhalls = Cyclopedia.House.ViewState.filterMode == "guildhalls"
    if UI.TopBase.HousesCheck then
        UI.TopBase.HousesCheck:setChecked(not guildhalls)
    end
    if UI.TopBase.GuildhallsCheck then
        UI.TopBase.GuildhallsCheck:setChecked(guildhalls)
    end
end

function Cyclopedia.houseChangeState(widget)
    if Cyclopedia.House.Data then
        local onlyGuildHall = UI.TopBase.GuildhallsCheck:isChecked()
        local type = widget:getCurrentOption().data
        houseViewStateLog("houseChangeState type=%s onlyGuildHall=%s", tostring(type), tostring(onlyGuildHall))
        for _, data in ipairs(Cyclopedia.House.Data) do
            if onlyGuildHall then
                data.visible = data.gh
            elseif type == 3 then
                data.visible = data.rented or data.inTransfer
            elseif type == 2 then
                data.visible = not data.rented
            else
                data.visible = true
            end
        end

        Cyclopedia.reloadHouseList()
        Cyclopedia.House.lastChangeState = widget
        rememberHouseViewState()
    end
end

local houseAuctionMessages = {
    [CyclopediaHouseAuctionTypes.Bid] = {
        [0] = "Your bid was successful. You are currently holding the highest bid.",
        [1] = "Your bid was accepted, but there is already a higher bid.",
        [3] = "Bid failed. Characters from Rookgaard cannot bid on houses.",
        [5] = "Bid failed. Premium account is required.",
        [6] = "Bid failed. Only guild leaders can bid on guildhalls.",
        [7] = "Bid failed. Your account can only hold one house bid at a time.",
        [17] = "Bid failed. Your bank account balance is too low to pay the bid and the first month rent.",
        [21] = "Bid failed. The guild bank balance is too low.",
        [24] = "Bid failed due to an internal server error."
    },
    [CyclopediaHouseAuctionTypes.MoveOut] = {
        [0] = "You have successfully initiated your move out.",
        [2] = "Move out failed. You are not the owner of this house.",
        [7] = "Move out failed. Premium account is required.",
        [16] = "Move out failed. Characters from Rookgaard cannot own houses.",
        [32] = "Move out failed due to an internal server error."
    },
    [CyclopediaHouseAuctionTypes.Transfer] = {
        [0] = "You have successfully initiated the transfer of your house.",
        [2] = "House transfer failed. You are not the owner of this house.",
        [4] = "Setting up a house transfer failed. A character with this name does not exist.",
        [7] = "House transfer failed. Premium account is required.",
        [16] = "House transfer failed. The target character is in Rookgaard.",
        [19] = "House transfer failed. The target character already owns this house.",
        [25] = "House transfer failed. The target account already has an active house bid.",
        [32] = "House transfer failed due to an internal server error."
    },
    [CyclopediaHouseAuctionTypes.CancelMoveOut] = {
        [0] = "You have successfully cancelled your move out.",
        [2] = "Cancel move out failed. You are not the owner of this house.",
        [32] = "Cancel move out failed due to an internal server error."
    },
    [CyclopediaHouseAuctionTypes.CancelTransfer] = {
        [0] = "You have successfully cancelled the transfer. You will keep the house.",
        [2] = "Cancel transfer failed. You are not the owner of this house.",
        [32] = "Cancel transfer failed due to an internal server error."
    },
    [CyclopediaHouseAuctionTypes.AcceptTransfer] = {
        [0] = "You have successfully accepted the transfer.",
        [2] = "Accept transfer failed. You are not the designated new owner.",
        [3] = "Accept transfer failed. Your account already has an active house bid.",
        [7] = "Accept transfer failed. This transfer was already accepted.",
        [8] = "Accept transfer failed. Characters from Rookgaard cannot own houses.",
        [9] = "Accept transfer failed. Premium account is required.",
        [15] = "Accept transfer failed. Your bank account balance is too low.",
        [19] = "Accept transfer failed due to an internal server error."
    },
    [CyclopediaHouseAuctionTypes.RejectTransfer] = {
        [0] = "You rejected the house transfer successfully. The old owner will keep the house.",
        [2] = "Reject transfer failed. You are not the designated new owner.",
        [32] = "Reject transfer failed due to an internal server error."
    }
}

local function isHouseActionSuccess(actionType, messageIndex)
    if actionType == CyclopediaHouseAuctionTypes.Bid then
        return messageIndex == 0 or messageIndex == 1
    end

    return messageIndex == 0
end

local function closeHouseActionPanels(actionType)
    if actionType == CyclopediaHouseAuctionTypes.Bid then
        UI.bidArea:setVisible(false)
    elseif actionType == CyclopediaHouseAuctionTypes.MoveOut or actionType == CyclopediaHouseAuctionTypes.CancelMoveOut then
        UI.moveOutArea:setVisible(false)
    elseif actionType == CyclopediaHouseAuctionTypes.Transfer then
        UI.transferArea:setVisible(false)
    elseif actionType == CyclopediaHouseAuctionTypes.CancelTransfer then
        UI.cancelHouseTransferArea:setVisible(false)
    elseif actionType == CyclopediaHouseAuctionTypes.AcceptTransfer then
        UI.acceptTransferHouse:setVisible(false)
    elseif actionType == CyclopediaHouseAuctionTypes.RejectTransfer then
        UI.rejectTransferHouse:setVisible(false)
    end
end

function Cyclopedia.onParseCyclopediaHouseAuctionMessage(houseId, auctionType, index, bidSuccessOrError)
    houseLog("info", "RX callback=HouseAuctionMessage houseId=%d type=%d index=%d bidExtra=%d", houseId or 0,
        auctionType or 0, index or 0, bidSuccessOrError or 0)
    Cyclopedia.houseMessage(houseId, auctionType, index, bidSuccessOrError)
end

function Cyclopedia.onParseCyclopediaHousesInfo(currentHouseId, accountHouseCount, highlightedEntries, housesList, maxTownHouses,
    maxGuildHouses, unknownHeaderA, unknownHeaderB)
    g_logger.info(string.format("[cyclopedia-houses-lua] accountHouseCount=%d", accountHouseCount or 0))

    local highlightedCount = type(highlightedEntries) == "table" and #highlightedEntries or 0
    local housesCount = type(housesList) == "table" and #housesList or 0
    houseLog("info",
        "RX callback=HousesInfo currentHouseId=%d accountHouseCount=%d highlightedCount=%d housesListCount=%d maxTownHouses=%d maxGuildHouses=%d unknownA=%d unknownB=%d",
        currentHouseId or 0, accountHouseCount or 0, highlightedCount, housesCount, maxTownHouses or 0,
        maxGuildHouses or 0, unknownHeaderA or 0, unknownHeaderB or 0)

    if highlightedCount > 0 then
        for idx, entry in ipairs(highlightedEntries) do
            local entryType = entry[1] or 0
            local houseId = entry[2] or 0
            houseLog("info", "RX callback=HousesInfo highlighted[%d]={type=%d, houseId=%d}", idx, entryType, houseId)
        end
    end

    if housesCount > 0 then
        for idx, houseId in ipairs(housesList) do
            houseLog("info", "RX callback=HousesInfo housesList[%d]=%d", idx, houseId or 0)
        end
    end

    Cyclopedia.House.Info = {
        currentHouseId = currentHouseId or 0,
        accountHouseCount = accountHouseCount or 0,
        highlightedEntries = highlightedEntries or {},
        housesList = housesList or {},
        maxTownHouses = maxTownHouses or 0,
        maxGuildHouses = maxGuildHouses or 0,
        unknownHeaderA = unknownHeaderA or 0,
        unknownHeaderB = unknownHeaderB or 0
    }
end

function Cyclopedia.onParseCyclopediaHouseList(data, other)
    if not UI then
        houseLog("warning", "RX callback=HouseList received while UI is nil")
        return
    end
    houseLog("info", "RX callback=HouseList entries=%d extraEntries=%d", type(data) == "table" and #data or 0,
        type(other) == "table" and #other or 0)
    Cyclopedia.loadHouseList(data, other)
end

function Cyclopedia.houseMessage(houseId, type, message)
    if not UI then
        return
    end

    local confirmWindow
    local function yesCallback()
        if confirmWindow then
            confirmWindow:destroy()
            confirmWindow = nil
            Cyclopedia.Toggle(true, false, 5)
        end
    end

    local typeMessages = houseAuctionMessages[type] or {}
    local resultMessage = typeMessages[message] or string.format("House action result: %d.", message or -1)
    local success = isHouseActionSuccess(type, message)
    local title = success and "Summary" or "House Action Failed"

    houseLog("info", "RX callback=HouseAuctionMessage result houseId=%d type=%d message=%d success=%s", houseId or 0,
        type or 0, message or 0, success and "true" or "false")
    if not typeMessages[message] then
        houseLog("warning", "HouseAuctionMessage without mapped text for type=%s message=%s", tostring(type),
            tostring(message))
    end

    if not confirmWindow then
        confirmWindow = displayGeneralBox(tr(title), tr(resultMessage), {
            {
                text = tr("Ok"),
                callback = yesCallback
            },
            anchor = AnchorHorizontalCenter
        }, yesCallback)
        Cyclopedia.Toggle(true, false)
    end

    if success then
        closeHouseActionPanels(type)
        UI.ListBase:setVisible(true)
        Cyclopedia.houseRefresh()
    end
end

function Cyclopedia.rejectTransfer()
    UI.ListBase:setVisible(false)
    UI.rejectTransferHouse:setVisible(true)

    local house = Cyclopedia.House.lastSelectedHouse.data
    local time = os.date("%Y-%m-%d, %H:%M CET", house.paidUntil)
    local transferTime = os.date("%Y-%m-%d, %H:%M CET", house.transferTime)

    function UI.rejectTransferHouse.cancel.onClick()
        UI.rejectTransferHouse:setVisible(false)
        UI.ListBase:setVisible(true)
    end

    function UI.rejectTransferHouse.transfer:onClick()
        local confirmWindow
        local function yesCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end

            houseLog("info", "TX action=RejectTransfer houseId=%d", house.id or 0)
            g_game.requestRejectHouseTransfer(house.id)

            UI.TopBase.StatesOption:setOption("All States", true)
            UI.TopBase.SortOption:setOption("Sort by name", true)
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm House Action"), tr(
                "Do you really want to reject the transfer for the house '%s' offered by %s?\nYou will not get the house. %s will keep the house and can set up a new transfer anytime.",
                house.name, house.owner, house.owner), {
                {
                    text = tr("Yes"),
                    callback = yesCallback
                },
                {
                    text = tr("No"),
                    callback = noCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback, noCallback)

            Cyclopedia.Toggle(true, false)
        end
    end

    UI.rejectTransferHouse.name:setText(house.name)
    UI.rejectTransferHouse.size:setText(house.sqm .. " sqm")
    UI.rejectTransferHouse.beds:setText(house.beds)
    UI.rejectTransferHouse.rent:setText((house.rent))
    UI.rejectTransferHouse.paid:setText(time)
    UI.rejectTransferHouse.owner:setText(house.transferName)
    UI.rejectTransferHouse.transferDate:setText(transferTime)
    UI.rejectTransferHouse.transferPrice:setText(comma_value(house.transferValue))
end

function Cyclopedia.acceptTransfer()
    UI.ListBase:setVisible(false)
    UI.acceptTransferHouse:setVisible(true)

    local house = Cyclopedia.House.lastSelectedHouse.data
    local time = os.date("%Y-%m-%d, %H:%M CET", house.paidUntil)
    local transferTime = os.date("%Y-%m-%d, %H:%M CET", house.transferTime)

    function UI.acceptTransferHouse.cancel.onClick()
        UI.acceptTransferHouse:setVisible(false)
        UI.ListBase:setVisible(true)
    end

    function UI.acceptTransferHouse.transfer:onClick()
        local confirmWindow

        local function yesCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end

            houseLog("info", "TX action=AcceptTransfer houseId=%d", house.id or 0)
            g_game.requestAcceptHouseTransfer(house.id)
            UI.TopBase.StatesOption:setOption("All States", true)
            UI.TopBase.SortOption:setOption("Sort by name", true)
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm House Action"), tr(
                "Do you want to accept the house transfer offered by %s for the property '%s'?\nThe transfer is scheduled for %s.\nThe transfer price was set to %s.\n\nMake sure to have enough gold in your bank account to pay the costs for this house transfer and the next rent.\nRemember to edit the door rights as only the guest list will be reset after the transfer!",
                house.owner, house.name, transferTime, comma_value(house.transferValue)), {
                {
                    text = tr("Yes"),
                    callback = yesCallback
                },
                {
                    text = tr("No"),
                    callback = noCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback, noCallback)

            Cyclopedia.Toggle(true, false)
        end
    end

    UI.acceptTransferHouse.name:setText(house.name)
    UI.acceptTransferHouse.size:setText(house.sqm .. " sqm")
    UI.acceptTransferHouse.beds:setText(house.beds)
    UI.acceptTransferHouse.rent:setText((house.rent))
    UI.acceptTransferHouse.paid:setText(time)
    UI.acceptTransferHouse.owner:setText(house.transferName)
    UI.acceptTransferHouse.transferDate:setText(transferTime)
    UI.acceptTransferHouse.transferPrice:setText(comma_value(house.transferValue))
end

function Cyclopedia.cancelTransfer()
    UI.ListBase:setVisible(false)
    UI.cancelHouseTransferArea:setVisible(true)

    local house = Cyclopedia.House.lastSelectedHouse.data
    local time = os.date("%Y-%m-%d, %H:%M CET", house.paidUntil)
    local transferTime = os.date("%Y-%m-%d, %H:%M CET", house.transferTime)

    function UI.cancelHouseTransferArea.cancel.onClick()
        UI.cancelHouseTransferArea:setVisible(false)
        UI.ListBase:setVisible(true)
    end

    function UI.cancelHouseTransferArea.transfer:onClick()
        local confirmWindow

        local function yesCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end

            houseLog("info", "TX action=CancelTransfer houseId=%d", house.id or 0)
            g_game.requestCancelHouseTransfer(house.id)

            UI.TopBase.StatesOption:setOption("All States", true)
            UI.TopBase.SortOption:setOption("Sort by name", true)
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm House Action"),
                tr("Do you really want to keep your house '%s'?\nYou will no longer transfer the house to %s on %s.",
                    house.name, house.transferName, transferTime), {
                    {
                        text = tr("Yes"),
                        callback = yesCallback
                    },
                    {
                        text = tr("No"),
                        callback = noCallback
                    },
                    anchor = AnchorHorizontalCenter
                }, yesCallback, noCallback)

            Cyclopedia.Toggle(true, false)
        end
    end

    UI.cancelHouseTransferArea.name:setText(house.name)
    UI.cancelHouseTransferArea.size:setText(house.sqm .. " sqm")
    UI.cancelHouseTransferArea.beds:setText(house.beds)
    UI.cancelHouseTransferArea.rent:setText((house.rent))
    UI.cancelHouseTransferArea.paid:setText(time)
    UI.cancelHouseTransferArea.owner:setText(house.transferName)
    UI.cancelHouseTransferArea.transferDate:setText(transferTime)
    UI.cancelHouseTransferArea.transferPrice:setText(comma_value(house.transferValue))
end

function Cyclopedia.transferHouse()
    if UI.moveOutArea:isVisible() then
        UI.moveOutArea:setVisible(false)
    end

    local house = Cyclopedia.House.lastSelectedHouse.data
    local time = os.date("%Y-%m-%d, %H:%M CET", house.paidUntil)

    local function verify(widget, text, type)
        local timestemp = os.time({
            year = UI.transferArea.year:getCurrentOption().text,
            month = UI.transferArea.month:getCurrentOption().text,
            day = UI.transferArea.day:getCurrentOption().text
        })

        if timestemp < os.time() then
            UI.transferArea.transfer:setEnabled(false)
            UI.transferArea.error:setVisible(true)
        else
            UI.transferArea.transfer:setEnabled(true)
            UI.transferArea.error:setVisible(false)
        end
    end

    local function verifyName(widget, text, oldText)
        if text ~= "" then
            UI.transferArea.errorName:setVisible(false)
            UI.transferArea.transfer:setEnabled(true)
        else
            UI.transferArea.transfer:setEnabled(false)
            UI.transferArea.errorName:setVisible(true)
        end
    end

    UI.ListBase:setVisible(false)
    UI.transferArea:setVisible(true)

    function UI.transferArea.cancel.onClick()
        UI.transferArea:setVisible(false)
        UI.ListBase:setVisible(true)
    end

    function UI.transferArea.transfer:onClick()
        local confirmWindow
        local transfer = UI.transferArea.owner:getText()
        local value = UI.transferArea.price:getText()
        local timestemp = os.time({
            year = UI.transferArea.year:getCurrentOption().text,
            month = UI.transferArea.month:getCurrentOption().text,
            day = UI.transferArea.day:getCurrentOption().text
        })

        local function yesCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end

            houseLog("info", "TX action=Transfer houseId=%d timestamp=%d owner=\"%s\" bidValue=%s", house.id or 0,
                timestemp or 0, transfer or "", tostring(value))
            g_game.requestTransferHouse(house.id, timestemp, transfer, tonumber(value))

            UI.TopBase.StatesOption:setOption("All States", true)
            UI.TopBase.SortOption:setOption("Sort by name", true)
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm House Action"), tr(
                "Do you really want to transfer your house '%s', to %s?\nThe transfer is scheduled for %s.\nYou have set the transfer price to %s.\n\nThe transfer will only take place if %s accepts it!.\n\nPlease take all your personal belongings out of the house before the daily server save on the day you move\nout. Everything that remains in the house becomes the property of the new owner after the transfer. The only\nexception are items which have been purchased in the Store. They will be wrapped back up and sent to your\ninbox.",
                house.name, transfer, os.date("%Y-%m-%d, %H:%M CET", timestemp), comma_value(value), transfer), {
                {
                    text = tr("Yes"),
                    callback = yesCallback
                },
                {
                    text = tr("No"),
                    callback = noCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback, noCallback)

            Cyclopedia.Toggle(true, false)
        end
    end

    UI.transferArea.name:setText(house.name)
    UI.transferArea.size:setText(house.sqm .. " sqm")
    UI.transferArea.beds:setText(house.beds)
    UI.transferArea.rent:setText((house.rent))
    UI.transferArea.paid:setText(time)
    UI.transferArea.year:clearOptions()
    UI.transferArea.year.onOptionChange = verify

    local yearNumber = tonumber(os.date("%Y"))

    UI.transferArea.year:addOption(yearNumber, 1, true)
    UI.transferArea.year:addOption(yearNumber + 1, 2, true)
    UI.transferArea.month:clearOptions()
    UI.transferArea.month.onOptionChange = verify

    for i = 1, 12 do
        UI.transferArea.month:addOption(i, i, true)
    end

    UI.transferArea.day:clearOptions()
    UI.transferArea.day.onOptionChange = verify

    local days = tonumber(os.date("%d", os.time({
        day = 0,
        year = yearNumber,
        month = os.date("%m") + 1
    })))

    for i = 1, days do
        UI.transferArea.day:addOption(i, i, true)
    end

    UI.transferArea.month:setOption(tonumber(os.date("%m")), true)
    UI.transferArea.day:setOption(math.min(days, tonumber(os.date("%d")) + 1), true)
    UI.transferArea.owner.onTextChange = verifyName
    UI.transferArea.owner:setText("")
    verifyName(UI.transferArea.owner, "", "")
    UI.transferArea.price:setText(0)

    function UI.transferArea.price:onTextChange(text, oldText)
        local convertedText = tonumber(text)
        if text ~= "" and type(convertedText) ~= "number" then
            self:setText(oldText)
        end

        if text == "" then
            UI.transferArea.transfer:setEnabled(false)
        elseif convertedText then
            UI.transferArea.transfer:setEnabled(true)
        end
    end
end

function Cyclopedia.moveOutHouse()
    if UI.transferArea:isVisible() then
        UI.transferArea:setVisible(false)
    end

    local house = Cyclopedia.House.lastSelectedHouse.data
    local time = os.date("%Y-%m-%d, %H:%M CET", house.paidUntil)

    local function verify(widget, text, type)
        local timestemp = os.time({
            year = UI.moveOutArea.year:getCurrentOption().text,
            month = UI.moveOutArea.month:getCurrentOption().text,
            day = UI.moveOutArea.day:getCurrentOption().text
        })

        if timestemp < os.time() then
            UI.moveOutArea.move:setEnabled(false)
            UI.moveOutArea.error:setVisible(true)
        else
            UI.moveOutArea.move:setEnabled(true)
            UI.moveOutArea.error:setVisible(false)
        end
    end

    UI.ListBase:setVisible(false)
    UI.moveOutArea:setVisible(true)

    function UI.moveOutArea.cancel.onClick()
        UI.moveOutArea:setVisible(false)
        UI.ListBase:setVisible(true)
    end

    function UI.moveOutArea.move:onClick()
        local confirmWindow
        local timestemp = os.time({
            year = UI.moveOutArea.year:getCurrentOption().text,
            month = UI.moveOutArea.month:getCurrentOption().text,
            day = UI.moveOutArea.day:getCurrentOption().text
        })

        local function yesCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end

            houseLog("info", "TX action=MoveOut houseId=%d timestamp=%d", house.id or 0, timestemp or 0)
            g_game.requestMoveOutHouse(house.id, timestemp)
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm House Action"),
                tr("Do you really want to move out of the house '%s'?\nClick on 'Yes' to move out on %s.", house.name,
                    os.date("%Y-%m-%d, %H:%M CET", timestemp)), {
                    {
                        text = tr("Yes"),
                        callback = yesCallback
                    },
                    {
                        text = tr("No"),
                        callback = noCallback
                    },
                    anchor = AnchorHorizontalCenter
                }, yesCallback, noCallback)

            Cyclopedia.Toggle(true, false)
        end
    end

    UI.moveOutArea.name:setText(house.name)
    UI.moveOutArea.size:setText(house.sqm .. " sqm")
    UI.moveOutArea.beds:setText(house.beds)
    UI.moveOutArea.rent:setText((house.rent))
    UI.moveOutArea.paid:setText(time)
    UI.moveOutArea.year:clearOptions()
    UI.moveOutArea.year.onOptionChange = verify

    local yearNumber = tonumber(os.date("%Y"))
    UI.moveOutArea.year:addOption(yearNumber, 1, true)
    UI.moveOutArea.year:addOption(yearNumber + 1, 2, true)
    UI.moveOutArea.month:clearOptions()
    UI.moveOutArea.month.onOptionChange = verify

    for i = 1, 12 do
        UI.moveOutArea.month:addOption(i, i, true)
    end

    UI.moveOutArea.day:clearOptions()
    UI.moveOutArea.day.onOptionChange = verify

    local days = tonumber(os.date("%d", os.time({
        day = 0,
        year = yearNumber,
        month = os.date("%m") + 1
    })))

    for i = 1, days do
        UI.moveOutArea.day:addOption(i, i, true)
    end

    UI.moveOutArea.month:setOption(tonumber(os.date("%m")), true)
    UI.moveOutArea.day:setOption(math.min(days, tonumber(os.date("%d")) + 1), true)
end

function Cyclopedia.bidHouse(widget)
    if UI.transferArea:isVisible() then
        UI.transferArea:setVisible(false)
    end

    if UI.moveOutArea:isVisible() then
        UI.moveOutArea:setVisible(false)
    end

    local house = Cyclopedia.House.lastSelectedHouse.data
    local time = os.date("%Y-%m-%d, %H:%M CET", house.bidEnd)

    UI.ListBase:setVisible(false)
    UI.bidArea:setVisible(true)
    UI.bidArea.name:setText(house.name)
    UI.bidArea.size:setText(house.sqm .. " sqm")
    UI.bidArea.beds:setText(house.beds)
    UI.bidArea.rent:setText((house.rent))

    local labels = {{
        id = "hightestBidder",
        name = "Highest Bidder: ",
        value = house.bidName
    }, {
        id = "endTime",
        name = "End Time: ",
        value = time
    }, {
        id = "highestBid",
        name = "Highest Bid: ",
        value = house.hightestBid
    }}

    for _, value in ipairs(labels) do
        local child = UI.bidArea:getChildById(value.id)
        if child then
            child:destroy()
            UI.bidArea:getChildById(value.id .. "_value"):destroy()

            if UI.bidArea:getChildById("highestBid_gold") then
                UI.bidArea:getChildById("highestBid_gold"):destroy()
            end
        end
    end

    if UI.bidArea:getChildById("yourLimit") then
        UI.bidArea:getChildById("yourLimit"):destroy()
        UI.bidArea:getChildById("yourLimit_value"):destroy()
        UI.bidArea:getChildById("yourLimit_gold"):destroy()
    end

    if house.hasBid then
        for index, data in ipairs(labels) do
            local label = g_ui.createWidget("Label", UI.bidArea)
            label:setId(data.id)
            label:setText(data.name)
            label:setColor("#909090")
            label:setWidth(90)
            label:setHeight(15)
            label:setTextAlign(AlignRight)
            label:setMarginTop(2)

            if index == 1 then
                label:addAnchor(AnchorTop, "prev", AnchorBottom)
                label:addAnchor(AnchorLeft, "parent", AnchorLeft)
            else
                label:addAnchor(AnchorTop, labels[index - 1].id, AnchorBottom)
                label:addAnchor(AnchorLeft, "parent", AnchorLeft)
            end

            label:setMarginLeft(4)

            local value = g_ui.createWidget("Label", UI.bidArea)
            value:setId(data.id .. "_value")
            value:setText(data.value)
            value:setColor("#C0C0C0")
            value:addAnchor(AnchorTop, "prev", AnchorTop)
            value:addAnchor(AnchorLeft, "prev", AnchorRight)
            value:setMarginLeft(5)

            if data.id == "highestBid" then
                value:setWidth(90)
                value:setHeight(15)
                value:setMarginLeft(7)
                value:setTextAlign(AlignRight)

                local gold = g_ui.createWidget("UIWidget", UI.bidArea)
                gold:setId("highestBid_gold")
                gold:setImageSource("/game_cyclopedia/images/icon_gold")
                gold:addAnchor(AnchorTop, "prev", AnchorTop)
                gold:addAnchor(AnchorLeft, "prev", AnchorRight)
                gold:setMarginTop(2)
                gold:setMarginLeft(9)
            end
        end

        if house.bidHolderLimit then
            local label = g_ui.createWidget("Label", UI.bidArea)
            label:setId("yourLimit")
            label:setText("Your Limit: ")
            label:setColor("#909090")
            label:setWidth(90)
            label:setHeight(15)
            label:setTextAlign(AlignRight)
            label:setMarginTop(2)
            label:addAnchor(AnchorTop, "highestBid", AnchorBottom)
            label:addAnchor(AnchorLeft, "parent", AnchorLeft)

            local value = g_ui.createWidget("Label", UI.bidArea)
            value:setWidth(90)
            value:setHeight(15)
            value:setId("yourLimit_value")
            value:setText(comma_value(house.bidHolderLimit))
            value:setColor("#C0C0C0")
            value:addAnchor(AnchorTop, "prev", AnchorTop)
            value:addAnchor(AnchorLeft, "prev", AnchorRight)
            value:setMarginLeft(13)
            value:setTextAlign(AlignRight)

            local gold = g_ui.createWidget("UIWidget", UI.bidArea)
            gold:setId("yourLimit_gold")
            gold:setImageSource("/game_cyclopedia/images/icon_gold")
            gold:addAnchor(AnchorTop, "prev", AnchorTop)
            gold:addAnchor(AnchorLeft, "prev", AnchorRight)
            gold:setMarginTop(2)
            gold:setMarginLeft(7)
        end
    else
        if UI.bidArea:getChildById("soFar") then
            UI.bidArea:getChildById("soFar"):destroy()
        end

        local label = g_ui.createWidget("Label", UI.bidArea)
        label:setId("soFar")
        label:setText("There is not bid so far.")
        label:setColor("#C0C0C0")
        label:addAnchor(AnchorTop, "prev", AnchorBottom)
        label:addAnchor(AnchorLeft, "parent", AnchorLeft)
        label:setMarginTop(2)
    end

    if UI.bidArea:getChildById("bidArea") then
        UI.bidArea:getChildById("bidArea"):destroy()
    end

    local bidArea = g_ui.createWidget("HouseBidArea", UI.bidArea)
    bidArea:setId("bidArea")
    bidArea:addAnchor(AnchorTop, "prev", AnchorBottom)
    bidArea:addAnchor(AnchorLeft, "parent", AnchorLeft)
    bidArea:addAnchor(AnchorRight, "parent", AnchorRight)
    bidArea:setMarginTop(5)

    if house.bidHolderLimit then
        bidArea.textEdit:setText(house.bidHolderLimit)
    else
        bidArea.textEdit:setText(0)
    end

    function bidArea.textEdit:onTextChange(text, oldText)
        local convertedText = tonumber(text)
        if text ~= "" and type(convertedText) ~= "number" then
            self:setText(oldText)
        end

        if text == "" then
            UI.bidArea.bid:setEnabled(false)
        elseif convertedText then
            UI.bidArea.bid:setEnabled(true)
        end
    end

    if house.hasBid then
        bidArea.information:setText(string.format(
            "When the auction ends at %s the\nwinning bid plus the rent for the first month ( %s) will\nbe debited to your bank account.",
            time, (house.rent)))
    else
        bidArea.information:setText("When the auction ends, the winning bid plus the rent for\nthe first month( " ..
                                        (house.rent) .. ") will de debited yo your bank account.")
    end

    function UI.bidArea.cancel.onClick()
        UI.bidArea:setVisible(false)
        UI.ListBase:setVisible(true)
    end

    function UI.bidArea.bid:onClick()
        local value = tonumber(bidArea.textEdit:getText())
        if not value or value <= 0 then
            return
        end

        local confirmWindow
        local function yesCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end

            houseLog("info", "TX action=Bid houseId=%d bidValue=%s", house.id or 0, tostring(value))
            g_game.requestBidHouse(house.id, value)
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm House Action"), tr(
                "Do you really want to bid on the house '%s'?\nYour have set your bid limit to %s.\nWhen the auction ends, the winning bid plus the rent of %sfor the first month will be debited from your\nbank account.",
                house.name, comma_value(value), (house.rent)), {
                {
                    text = tr("Yes"),
                    callback = yesCallback
                },
                {
                    text = tr("No"),
                    callback = noCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback, noCallback)

            Cyclopedia.Toggle(true, false)
        end
    end
end

function Cyclopedia.houseRefresh()
    if not UI then
        return
    end

    if Cyclopedia.House.lastTown ~= nil then
        houseLog("info", "TX action=Show town=\"%s\" (refresh)", Cyclopedia.House.lastTown or "")
        g_game.requestShowHouses(Cyclopedia.House.lastTown)
    end

    if Cyclopedia.House.lastChangeState then
        if Cyclopedia.House.refreshEvent then
            return
        end

        Cyclopedia.House.refreshEvent = scheduleEvent(function()
            Cyclopedia.houseChangeState(Cyclopedia.House.lastChangeState)
            Cyclopedia.House.refreshEvent = nil
        end, 100)
    end
end

function Cyclopedia.houseSort(widget, text, type)
    if Cyclopedia.House.Data then
        houseViewStateLog("houseSort type=%s text='%s'", tostring(type), tostring(text))
        applyHouseSortByType(type)

        Cyclopedia.reloadHouseList()
        rememberHouseViewState()
    end
end

function Cyclopedia.houseFilter(widget)
    local id = widget:getId()
    local brother
    houseViewStateLog("houseFilter id='%s'", tostring(id))

    if id == "HousesCheck" then
        brother = UI.TopBase.GuildhallsCheck
        if Cyclopedia.House.ViewState then
            Cyclopedia.House.ViewState.filterMode = "houses"
        end
    else
        brother = UI.TopBase.HousesCheck
        if Cyclopedia.House.ViewState then
            Cyclopedia.House.ViewState.filterMode = "guildhalls"
        end
    end

    brother:setChecked(false)
    widget:setChecked(true)

    if not table.empty(Cyclopedia.House.Data) then
        local onlyGuildHall = UI.TopBase.GuildhallsCheck:isChecked()
        for _, data in ipairs(Cyclopedia.House.Data) do
            if onlyGuildHall then
                data.visible = data.gh
            else
                data.visible = not data.gh
            end
        end

        Cyclopedia.reloadHouseList()
    end

    rememberHouseViewState()
end

function Cyclopedia.reloadHouseList()
    if not table.empty(Cyclopedia.House.Data) then
        UI.LateralBase.MapViewbase.noHouse:setVisible(false)
        UI.LateralBase.MapViewbase.houseImage:setVisible(false)
        UI.LateralBase.MapViewbase.reload:setVisible(true)
        UI.LateralBase.AuctionLabel:setVisible(true)
        UI.LateralBase.AuctionText:setVisible(true)
        UI.ListBase.AuctionList:destroyChildren()
        local visibleEntries = 0
        local renderedGuildhalls = 0
        local renderedHouses = 0
        local viewState = Cyclopedia.House.ViewState or {}
        local enforceGuildhalls = viewState.filterMode == "guildhalls"

        for _, data in ipairs(Cyclopedia.House.Data) do
            local passesViewMode = false
            if enforceGuildhalls then
                passesViewMode = data.gh and true or false
            else
                passesViewMode = not data.gh
            end
            if data.visible and passesViewMode then
                visibleEntries = visibleEntries + 1
                if data.gh then
                    renderedGuildhalls = renderedGuildhalls + 1
                else
                    renderedHouses = renderedHouses + 1
                end
                local widget = g_ui.createWidget("House", UI.ListBase.AuctionList)
                widget.data = data
                widget:setId(data.id)
                widget:setText(data.name)
                widget:setColor("#C0C0C0")
                widget:setHeight(56)
                widget.size:setColoredText("{Size:     , #909090}" .. data.sqm .. " sqm")
                widget.beds:setColoredText("{Max. Beds: ,#909090} " .. data.beds)
                widget.rent:setColoredText(data.rent)

                if data.description ~= "" then
                    local icon = g_ui.createWidget("HouseIcon", widget.icons)
                    -- icon:setImageSource("/game_cyclopedia/images/house-description")
                    icon:setTooltip(data.description)
                end

                if data.state == CyclopediaHouseStates.Available then
                    if data.hasBid then
                        local function format(timestamp)
                            local difference = timestamp - os.time()
                            local hour = math.floor(difference / 3600)
                            local minutes = math.floor(difference % 3600 / 60)
                            return string.format("%02dh %02dmin", hour, minutes)
                        end

                        widget.status:setColoredText("{Status:  , #909090}{auctioned, #00F000} (Bid: " ..
                                                         data.hightestBid .. " Ends in: " .. format(data.bidEnd) .. ")")
                    else
                        widget.status:setColoredText("{Status:  , #909090}{auctioned, #00F000} (no bid yet)")
                    end
                elseif data.state == CyclopediaHouseStates.Rented then
                    widget.status:setColoredText("{Status:  , #909090}rented by " .. data.owner)
                elseif data.state == CyclopediaHouseStates.Transfer then
                    widget.status:setColoredText("{Status:  , #909090}transfer to " .. data.transferName)
                elseif data.state == CyclopediaHouseStates.MoveOut then
                    widget.status:setColoredText("{Status:  , #909090}move out scheduled")
                end

                widget.onClick = Cyclopedia.selectHouse

                if data.isYourOwner then
                    local icon = g_ui.createWidget("HouseIcon", widget.icons)
                    -- icon:setImageSource("/game_cyclopedia/images/house-owner-icon")
                end

                if widget.data.isTransferOwner then
                    local icon = g_ui.createWidget("HouseIcon", widget.icons)
                    icon:setImageSource("/game_cyclopedia/images/pending-transfer-house")
                end

                if data.isYourOwner and data.inTransfer then
                    local icon = g_ui.createWidget("HouseIcon", widget.icons)
                    icon:setImageSource("/game_cyclopedia/images/transfer-house")
                end

                if data.shop then
                    local icon = g_ui.createWidget("HouseIcon", widget.icons)
                    -- icon:setImageSource("/game_cyclopedia/images/house-shop")
                    icon:setTooltip("This house is a shop.")
                end
            end
        end

        UI.ListBase.AuctionList:updateLayout()
        houseViewStateLog("reloadHouseList rendered entries=%d guildhalls=%d houses=%d filterMode='%s'", visibleEntries,
            renderedGuildhalls, renderedHouses, tostring(viewState.filterMode))
        houseLog("info", "reloadHouseList visibleEntries=%d renderedChildren=%d", visibleEntries,
            UI.ListBase.AuctionList:getChildCount())

        local selectedHouseId = Cyclopedia.House.ViewState and Cyclopedia.House.ViewState.selectedHouseId or nil
        local last = nil
        if selectedHouseId then
            last = UI.ListBase.AuctionList:getChildById(selectedHouseId)
        end

        if not last and Cyclopedia.House.lastSelectedHouse then
            last = UI.ListBase.AuctionList:getChildById(Cyclopedia.House.lastSelectedHouse:getId())
        end

        if last then
            last = last or UI.ListBase.AuctionList:getChildByIndex(1)
            selectHouseWithoutPersist(last)
        elseif Cyclopedia.House.lastSelectedHouse then
            local fallbackLast = UI.ListBase.AuctionList:getChildById(Cyclopedia.House.lastSelectedHouse:getId())
            fallbackLast = fallbackLast or UI.ListBase.AuctionList:getChildByIndex(1)
            selectHouseWithoutPersist(fallbackLast)
        else
            selectHouseWithoutPersist(UI.ListBase.AuctionList:getChildByIndex(1))
        end
    else
        if houseMinimap then
            houseMinimap:setVisible(false)
        end
        if houseMapCenterButton then
            houseMapCenterButton:setVisible(false)
        end
        if houseMapMarkButton then
            houseMapMarkButton:setVisible(false)
        end
        if houseMapZoomInButton then
            houseMapZoomInButton:setVisible(false)
        end
        if houseMapZoomOutButton then
            houseMapZoomOutButton:setVisible(false)
        end
        UI.LateralBase.MapViewbase.noHouse:setVisible(true)
        UI.LateralBase.MapViewbase.reload:setVisible(false)
        UI.LateralBase.MapViewbase.houseImage:setVisible(false)
        if houseMapUnknownLabel then
            houseMapUnknownLabel:setVisible(false)
        end
        UI.LateralBase.AuctionLabel:setVisible(false)
        UI.LateralBase.AuctionText:setVisible(false)
        UI.LateralBase.icons:destroyChildren()
        UI.LateralBase.yourLimitBidGold:setVisible(false)
        UI.LateralBase.yourLimitBid:setVisible(false)
        UI.LateralBase.yourLimitLabel:setVisible(false)
        UI.LateralBase.highestBid:setVisible(false)
        UI.LateralBase.highestBidGold:setVisible(false)
        UI.LateralBase.subAuctionLabel:setVisible(false)
        UI.LateralBase.subAuctionText:setVisible(false)
        UI.LateralBase.transferLabel:setVisible(false)
        UI.LateralBase.transferValue:setVisible(false)
        UI.LateralBase.transferGold:setVisible(false)
        resetButtons()
    end
end

local function getHouseMetadata(houseId)
    local fallback = {
        id = houseId,
        name = string.format("House %d", houseId),
        description = "",
        rent = "0",
        beds = "0",
        sqm = "0",
        entryx = 0,
        entryy = 0,
        entryz = 7,
        gh = false,
        shop = false
    }

    if type(HOUSE) ~= "table" then
        if not HOUSE_METADATA_WARNED then
            houseLog("warning", "HOUSE metadata table is unavailable; fallback metadata will be used")
            HOUSE_METADATA_WARNED = true
        end
        return fallback
    end

    local house = HOUSE[houseId]
    if not house then
        houseLog("warning", "No metadata for houseId=%d in HOUSE table; using fallback", houseId or 0)
        return fallback
    end

    return {
        id = houseId,
        name = house.name or fallback.name,
        description = house.description or "",
        rent = house.rent or "-",
        beds = house.beds or "-",
        sqm = house.sqm or "-",
        entryx = house.entryx or 0,
        entryy = house.entryy or 0,
        entryz = house.entryz or 7,
        gh = (house.GH or 0) > 0,
        shop = (house.shop or 0) > 0
    }
end

function Cyclopedia.loadHouseList(data, other)
    if not UI then
        houseLog("warning", "loadHouseList aborted because UI is nil")
        return
    end

    local houses = {}
    data = data or {}
    other = other or {}
    houseLog("info", "loadHouseList start entries=%d extraEntries=%d", #data, #other)
    local localPlayer = g_game.getLocalPlayer()
    local playerName = localPlayer and localPlayer:getName() and localPlayer:getName():lower() or nil

    if #data ~= #other then
        houseLog("warning", "loadHouseList payload size mismatch data=%d extra=%d", #data, #other)
    end

    if table.empty(data) then
        houseLog("info", "loadHouseList received empty data")
        Cyclopedia.House.Data = {}
        UI.ListBase.AuctionList:destroyChildren()
        Cyclopedia.reloadHouseList()
        return
    end

    for index, value in ipairs(data) do
        if type(value) ~= "table" then
            houseLog("error", "loadHouseList invalid payload entry index=%d type=%s", index, type(value))
        else
            local houseId, state, bidHolderLimit, bidEnd, highestBid, selfCanBid, paidUntil, transferTime, transferValue,
            hasTransferOwner, canAcceptTransfer, canRejectTransfer, canCancelTransfer, canCancelMoveOut = unpack(value)
            if not houseId then
                houseLog("error", "loadHouseList missing houseId at index=%d", index)
            else
                local details = other[index] or {}
                local owner, bidName, transferPlayer = unpack(details)

                local metadata = getHouseMetadata(houseId)
                local isOwner = owner and playerName and owner:lower() == playerName or false
                local isGuildHall = metadata.gh

                local data_t = {
                    id = houseId,
                    name = metadata.name,
                    description = metadata.description,
                    rent = metadata.rent,
                    beds = metadata.beds,
                    sqm = metadata.sqm,
                    entryx = metadata.entryx or 0,
                    entryy = metadata.entryy or 0,
                    entryz = metadata.entryz or 7,
                    gh = isGuildHall,
                    shop = metadata.shop,
                    visible = not isGuildHall,
                    state = state,
                    owner = owner and owner ~= "" and owner or "?",
                    isYourBid = (bidHolderLimit or 0) > 0,
                    hasBid = (bidEnd or 0) > 0,
                    bidEnd = (bidEnd or 0) > 0 and bidEnd or nil,
                    hightestBid = (highestBid or 0) > 0 and highestBid or nil,
                    bidName = bidName and bidName ~= "" and bidName or nil,
                    bidHolderLimit = (bidHolderLimit or 0) > 0 and bidHolderLimit or nil,
                    canBid = selfCanBid or 0,
                    rented = state == CyclopediaHouseStates.Rented,
                    paidUntil = (paidUntil or 0) > 0 and paidUntil or nil,
                    isYourOwner = isOwner,
                    inTransfer = state == CyclopediaHouseStates.Transfer,
                    movingOut = state == CyclopediaHouseStates.MoveOut,
                    transferName = transferPlayer and transferPlayer ~= "" and transferPlayer or "?",
                    transferTime = transferTime or 0,
                    transferValue = transferValue or 0,
                    isTransferOwner = (hasTransferOwner or 0) > 0,
                    canAcceptTransfer = canAcceptTransfer or 0,
                    canRejectTransfer = canRejectTransfer or 0,
                    canCancelTransfer = canCancelTransfer or 0,
                    canCancelMoveOut = canCancelMoveOut or 0
                }

                table.insert(houses, data_t)
                houseLog("info",
                    "loadHouseList parsed index=%d houseId=%d state=%d owner=\"%s\" bidName=\"%s\" transferName=\"%s\" bidEnd=%s transferTime=%s canBid=%d",
                    index, data_t.id or 0, data_t.state or 0, data_t.owner or "?", data_t.bidName or "",
                    data_t.transferName or "?", tostring(data_t.bidEnd), tostring(data_t.transferTime), data_t.canBid or 0)
            end
        end
    end

    table.sort(houses, function(a, b)
        return a.name < b.name
    end)

    Cyclopedia.House.Data = houses
    applyHouseSortByType((Cyclopedia.House.ViewState and Cyclopedia.House.ViewState.sortType) or 1)
    applyHouseVisibilityByViewState()
    applyFilterChecksFromViewState()
    houseViewStateLog("loadHouseList applied viewState to dataset entries=%d", #houses)
    dumpHouseViewState("loadHouseList:post-apply")
    houseLog("info", "loadHouseList finished mappedEntries=%d", #houses)
    Cyclopedia.reloadHouseList()
end

function Cyclopedia.selectTown(widget, text, type)
    local name = type ~= 0 and text or ""
    Cyclopedia.House.lastTown = name
    if Cyclopedia.House.ViewState then
        Cyclopedia.House.ViewState.cityText = text
        Cyclopedia.House.ViewState.cityType = type
    end
    houseViewStateLog("selectTown text='%s' type=%s requestTown='%s'", tostring(text), tostring(type), tostring(name))
    if name == "" then
        houseLog("info", "TX action=Show town=\"\" (own houses)")
    else
        houseLog("info", "TX action=Show town=\"%s\"", name)
    end
    g_game.requestShowHouses(name)
    rememberHouseViewState()
end

function Cyclopedia.selectHouse(widget)
    if not widget then
        return
    end

    local parent = widget:getParent()
    for i = 1, parent:getChildCount() do
        local child = parent:getChildByIndex(i)
        child:setChecked(false)
    end

    UI.LateralBase.icons:destroyChildren()

    if widget.data.isYourOwner then
        local icon = g_ui.createWidget("HouseIcon", UI.LateralBase.icons)
        -- icon:setImageSource("/game_cyclopedia/images/house-owner-icon")
    end

    if widget.data.isYourOwner and widget.data.inTransfer then
        local icon = g_ui.createWidget("HouseIcon", UI.LateralBase.icons)
        icon:setImageSource("/game_cyclopedia/images/transfer-house")
    end

    if widget.data.isTransferOwner then
        local icon = g_ui.createWidget("HouseIcon", UI.LateralBase.icons)
        icon:setImageSource("/game_cyclopedia/images/pending-transfer-house")
    end

    if widget.data.shop then
        local icon = g_ui.createWidget("HouseIcon", UI.LateralBase.icons)
        -- icon:setImageSource("/game_cyclopedia/images/house-shop")
        icon:setTooltip("This house is a shop.")
    end

    if widget.data.description ~= "" then
        local icon = g_ui.createWidget("HouseIcon", UI.LateralBase.icons)
        -- icon:setImageSource("/game_cyclopedia/images/house-description")
        icon:setTooltip(widget.data.description)
    end

    resetButtons()
    resetSelectedInfo()

    if widget.data.hasBid then
        UI.LateralBase.AuctionLabel:setText("Auction")

        local formattedDate = os.date("%b %d, %H:%M", widget.data.bidEnd)
        local date = string.format("%s %s", formattedDate, "CET")

        UI.LateralBase.AuctionText:setColoredText("{Hightest Bidder: , #909090}" .. widget.data.bidName ..
                                                      "\n{      End Time: , #909090}" .. date ..
                                                      "\n{   Highest Bid: , #909090}")
        UI.LateralBase.highestBid:setVisible(true)
        UI.LateralBase.highestBidGold:setVisible(true)
        UI.LateralBase.highestBid:setText(comma_value(widget.data.hightestBid))

        if widget.data.isYourBid then
            UI.LateralBase.yourLimitLabel:setVisible(true)
            UI.LateralBase.yourLimitBid:setVisible(true)
            UI.LateralBase.yourLimitBid:setText(comma_value(widget.data.bidHolderLimit))
            UI.LateralBase.yourLimitBidGold:setVisible(true)
        end
    elseif widget.data.rented or widget.data.inTransfer or widget.data.movingOut then
        local formattedDate = os.date("%b %d, %H:%M", widget.data.paidUntil)
        local date = string.format("%s %s", formattedDate, "CET")

        UI.LateralBase.AuctionLabel:setText("Rental Details")
        UI.LateralBase.AuctionText:setColoredText("{            Tenant: , #909090}" .. widget.data.owner ..
                                                      "\n{         Paid Until: , #909090}" .. date)

        if widget.data.inTransfer then
            formattedDate = os.date("%b %d, %H:%M", widget.data.transferTime)
            date = string.format("%s %s", formattedDate, "CET")

            UI.LateralBase.subAuctionLabel:setVisible(true)
            UI.LateralBase.subAuctionText:setVisible(true)
            UI.LateralBase.subAuctionText:setColoredText("{      New Owner:  , #909090}" .. widget.data.transferName ..
                                                             "\n{                Date:  , #909090}" .. date)
            UI.LateralBase.transferLabel:setVisible(true)
            UI.LateralBase.transferValue:setVisible(true)
            UI.LateralBase.transferGold:setVisible(true)
            UI.LateralBase.transferValue:setText(comma_value(widget.data.transferValue))
        elseif widget.data.movingOut then
            formattedDate = os.date("%b %d, %H:%M", widget.data.transferTime)
            date = string.format("%s %s", formattedDate, "CET")
            UI.LateralBase.subAuctionLabel:setVisible(true)
            UI.LateralBase.subAuctionText:setVisible(true)
            UI.LateralBase.subAuctionText:setColoredText("{Move Out Date:  , #909090}" .. date)
        end
    else
        UI.LateralBase.AuctionLabel:setText("Auction")
        UI.LateralBase.AuctionText:setText("There is no bid so far.\nBe the first to bid on this house.")
    end

    if widget.data.rented then
        if widget.data.isYourOwner then
            local button = g_ui.createWidget("Button", UI.LateralBase)
            button:setId("transferButton")
            button:setText("Transfer")
            button:setColor("#C0C0C0")
            -- button:setFont("verdana-bold-8px-antialiased")
            button:setWidth(64)
            button:setHeight(20)
            button:addAnchor(AnchorBottom, "parent", AnchorBottom)
            button:addAnchor(AnchorRight, "parent", AnchorRight)
            button:setMarginRight(7)
            button:setMarginBottom(7)
            button.onClick = Cyclopedia.transferHouse
            button = g_ui.createWidget("Button", UI.LateralBase)
            button:setId("moveOutButton")
            button:setText("Move Out")
            button:setColor("#C0C0C0")
            -- button:setFont("verdana-bold-8px-antialiased")
            button:setWidth(64)
            button:setHeight(20)
            button:addAnchor(AnchorTop, "prev", AnchorTop)
            button:addAnchor(AnchorRight, "prev", AnchorLeft)
            button:setMarginRight(5)
            button.onClick = Cyclopedia.moveOutHouse
        end
    elseif widget.data.inTransfer and not widget.data.isTransferOwner then
        local button = g_ui.createWidget("Button", UI.LateralBase)
        button:setId("cancelTransfer")
        button:setText("Cancel Transfer")
        button:setColor("#C0C0C0")
        -- button:setFont("verdana-bold-8px-antialiased")
        button:setWidth(86)
        button:setHeight(20)
        button:addAnchor(AnchorBottom, "parent", AnchorBottom)
        button:addAnchor(AnchorRight, "parent", AnchorRight)
        button:setMarginRight(7)
        button:setMarginBottom(7)
        button.onClick = Cyclopedia.cancelTransfer
    elseif widget.data.isTransferOwner then
        local button = g_ui.createWidget("Button", UI.LateralBase)
        button:setId("rejectTransfer")
        button:setText("Reject Transfer")
        button:setColor("#C0C0C0")
        -- button:setFont("verdana-bold-8px-antialiased")
        button:setWidth(86)
        button:setHeight(20)
        button:addAnchor(AnchorBottom, "parent", AnchorBottom)
        button:addAnchor(AnchorRight, "parent", AnchorRight)
        button:setMarginRight(7)
        button:setMarginBottom(7)
        button:setTextOffset(topoint(0 .. " " .. 0))
        button.onClick = Cyclopedia.rejectTransfer

        local transferButton = g_ui.createWidget("Button", UI.LateralBase)
        transferButton:setId("acceptTransfer")
        transferButton:setText("Accept Transfer")
        transferButton:setColor("#C0C0C0")
        -- transferButton:setFont("verdana-bold-8px-antialiased")
        transferButton:setWidth(86)
        transferButton:setHeight(20)
        transferButton:addAnchor(AnchorTop, "prev", AnchorTop)
        transferButton:addAnchor(AnchorRight, "prev", AnchorLeft)
        transferButton:setMarginRight(5)
        transferButton:setTextOffset(topoint(0 .. " " .. 0))
        transferButton.onClick = Cyclopedia.acceptTransfer

        if widget.data.canAcceptTransfer ~= 0 then
            transferButton:setEnabled(false)
        else
            transferButton:setEnabled(true)
        end
    elseif widget.data.movingOut then
        local button = g_ui.createWidget("Button", UI.LateralBase)
        button:setId("moveOutButton")
        button:setText("Move Out Pending")
        button:setColor("#C0C0C0")
        button:setWidth(86)
        button:setHeight(20)
        button:addAnchor(AnchorBottom, "parent", AnchorBottom)
        button:addAnchor(AnchorRight, "parent", AnchorRight)
        button:setMarginRight(7)
        button:setMarginBottom(7)
        button:setEnabled(false)
    else
        local button = g_ui.createWidget("Button", UI.LateralBase)
        button:setId("bidButton")
        button:setText("Bid")
        button:setColor("#C0C0C0")
        -- button:setFont("verdana-bold-8px-antialiased")
        button:setWidth(64)
        button:setHeight(20)
        button:addAnchor(AnchorBottom, "parent", AnchorBottom)
        button:addAnchor(AnchorRight, "parent", AnchorRight)
        button:setMarginRight(7)
        button:setMarginBottom(7)
        button.onClick = Cyclopedia.bidHouse

        if widget.data.canBid == 0 then
            button:setEnabled(true)
            button:setTooltip("")
        elseif widget.data.canBid == 11 then
            button:setTooltip(
                "A character of your account already holds the highest bid for \nanother house. You may only bid for one house at the same time.")
            button:setTooltipAlign(AlignTopLeft)
            button:setEnabled(false)
        else
            button:setEnabled(false)
            button:setTooltip("")
        end
    end

    widget:setChecked(true)
    updateHousePreview(widget.data)

    Cyclopedia.House.lastSelectedHouse = widget
    houseViewStateLog("selectHouse id=%s name='%s' suppressPersist=%s", tostring(widget.data and widget.data.id),
        tostring(widget.data and widget.data.name), tostring(Cyclopedia.House.SuppressSelectionPersist))
    if not Cyclopedia.House.SuppressSelectionPersist then
        if Cyclopedia.House.ViewState then
            Cyclopedia.House.ViewState.selectedHouseId = widget.data and widget.data.id or nil
        end
        rememberHouseViewState()
    end
end
