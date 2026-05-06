InspectController = Controller:new()

-- /*=============================================
-- =            Helpers            =
-- =============================================*/

local function asText(v)
    return v ~= nil and tostring(v) or ""
end

local function normalizeDescription(d)
    if type(d) ~= "table" then
        return {
            detail = "",
            description = asText(d)
        }
    end
    return {
        detail = asText(d.detail or d[1] or d.key),
        description = asText(d.description or d[2] or d.value)
    }
end

local function normalizeDescriptions(list)
    if type(list) ~= "table" then
        return {}
    end
    local out = {}
    for _, d in ipairs(list) do
        out[#out + 1] = normalizeDescription(d)
    end
    return out
end

local function normalizeItem(item)
    return type(item) == "number" and Item and Item.create and Item.create(item) or item
end

-- LuaFormatter off
-- slot > 0 → slotIndex = slot - 1  (1-based server → 0-based widget)
-- slot == 0 → slotIndex = 0
local function normalizeInventoryItems(items)
    if type(items) ~= "table" then
        return {}, {}
    end
    local list, bySlot = {}, {}
    for _, data in ipairs(items) do
        if type(data) == "table" then
            local slot = tonumber(data.slot)
            local idx = slot and (slot > 0 and slot - 1 or slot) or nil
            local entry = {
                item = normalizeItem(data.item or data.itemId),
                name = asText(data.name or data.itemName),
                slot = slot,
                slotIndex = idx,
                descriptions = normalizeDescriptions(data.descriptions),
                imbuements = type(data.imbuements) == "table" and data.imbuements or {}
            }
            list[#list + 1] = entry
            if idx ~= nil then
                bySlot[idx] = entry
            end
        end
    end
    return list, bySlot
end

-- /*=============================================
-- =            State Builder             =
-- =============================================*/
-- INSPECT_CYCLOPEDIA            → character view (player + equipment slots + outfit)
-- INSPECT_NORMALOBJECT / NPCTRADE → item view (single item, no slots)
local function buildState(data)
    if data.inspectionType == InspectObjectTypes.INSPECT_CYCLOPEDIA then
        local playerName = asText(data.playerName or data.name)
        local playerDesc = normalizeDescriptions(data.playerDescriptions)
        local items, bySlot = normalizeInventoryItems(data.inventoryItems)
        local title = playerName ~= "" and tr("Inspect Character") .. " " .. playerName or tr("Inspect Character")
        return {
            isCyclopedia = true,
            windowTitle = title,
            playerName = playerName,
            playerDesc = playerDesc,
            inventoryItems = items,
            bySlot = bySlot,
            selectedSlot = nil,
            viewState = InspectConst.CYCLOPEDIA_VIEW_INVENTORY,
            outfit = type(data.outfit) == "table" and data.outfit or nil,
            activeItem = nil,
            activeName = playerName,
            activeDesc = playerDesc,
            activeImbu = {},
            creatureId = data.creatureId
        }
    end
    return {
        isCyclopedia = false,
        windowTitle = tr("Inspect Object"),
        playerName = "",
        playerDesc = {},
        inventoryItems = {},
        bySlot = {},
        selectedSlot = nil,
        viewState = InspectConst.CYCLOPEDIA_VIEW_INVENTORY,
        outfit = nil,
        activeItem = normalizeItem(data.item or data.itemId),
        activeName = asText(data.itemName or data.name),
        activeDesc = normalizeDescriptions(data.descriptions),
        activeImbu = type(data.imbuements) == "table" and data.imbuements or {}
    }
end
-- LuaFormatter on

-- /*=============================================
-- =            Lifecycle            =
-- =============================================*/

function InspectController:onGameStart()
    if g_game.getClientVersion() < 1281 then
        self:scheduleEvent(function()
            g_modules.getModule("game_inspect"):unload()
        end, 100, "unloadInspect")
        return
    end
    self:registerEvents(g_game, {
        onParseItemDetail = function(...)
            if not (modules.game_cyclopedia and modules.game_cyclopedia.isVisible()) then
                self:onInspection(...)
            end
        end,
        onParseCharacterInspection = function(...)
            self:onInspection(...)
        end,
        onInspectionState = function(creatureId, state)
            g_logger.info(string.format("[InspectController] onInspectionState: creatureId=%s, state=%s TODO: forward state to UI when behavior is defined" ,
                tostring(creatureId), tostring(state)))
        end
    })
end

function InspectController:onGameEnd()
    self.state = nil
    self.layout = nil
    self.pendingCreatureId = nil
    self:hide()
end

function InspectController:onTerminate()
    self.state = nil
    self.layout = nil
    self.pendingCreatureId = nil
    self:hide()
end

-- /*=============================================
-- =            Incoming Packet            =
-- =============================================*/

function InspectController:onInspection(data)
    if type(data) ~= "table" or not InspectObjectTypes then
        return
    end

    local t = data.inspectionType
    if t ~= InspectObjectTypes.INSPECT_CYCLOPEDIA and t ~= InspectObjectTypes.INSPECT_NORMALOBJECT and t ~=
        InspectObjectTypes.INSPECT_NPCTRADE then
        return
    end

    if not data.creatureId and self.pendingCreatureId then
        data.creatureId = self.pendingCreatureId
    end
    self.pendingCreatureId = nil

    self.state = buildState(data)
    self.layout = self.state.isCyclopedia and InspectConst.LAYOUTS.CYCLOPEDIA or InspectConst.LAYOUTS.NPCTRADE
    self:show()
end

-- /*=============================================
-- =            Capability Checks            =
-- =============================================*/

function InspectController:isCyclopediaInspection()
    return self.state ~= nil and self.state.isCyclopedia == true
end

function InspectController:isItemCyclopediaable()
    local item = self.state and self.state.activeItem
    return item ~= nil and modules.game_cyclopedia ~= nil and item:getCyclopediaType() > 0
end

function InspectController:isItemProficiencyable()
    local item = self.state and self.state.activeItem
    return item ~= nil and modules.game_proficiency ~= nil and item:getProficiencyId() > 0
end

-- /*=============================================
-- =            UI Management            =
-- =============================================*/

function InspectController:show()
    if not self.state then
        return
    end
    if not self.ui then
        self:loadHtml(InspectConst.HTML_PATH)
    end
    self:render()
    self.ui:show()
    self.ui:raise()
    self.ui:focus()
end

function InspectController:hide()
    if self.ui then
        self:unloadHtml()
    end
end

function InspectController:toggle()
    if self.ui and self.ui:isVisible() then
        self:hide()
    else
        self:show()
    end
end

-- /*=============================================
-- =            Render Engine            =
-- =============================================*/

function InspectController:_scheduleResize()
    self:scheduleEvent(function()
        self:resizeDetailRows()
    end, 50, "resizeDetailRows")
end

function InspectController:_renderActive()
    self:renderHeader()
    self:renderDescriptions()
    self:_scheduleResize()
end

function InspectController:render()
    if not self.ui or not self.state then
        return
    end
    self.ui:setTitle(self.state.windowTitle)
    if self.state.isCyclopedia then
        self:renderInventorySlots()
        self:renderOutfit()
        self:renderPanelMode()
    else
        local panel = self:findWidget("#cyclopediaPanel")
        if panel then
            panel:setVisible(false)
        end
    end
    self:_renderActive()
end

function InspectController:renderHeader()
    local s = self.state
    if not s then
        return
    end
    local label = self:findWidget("#inspectName")
    if label then
        label:setText(s.activeName ~= "" and tr("You are inspecting: ") .. s.activeName or tr("You are inspecting:"))
    end
    local itemWidget = self:findWidget("#inspectItem")
    if itemWidget then
        if s.activeItem then
            itemWidget:setItem(s.activeItem)
            ItemsDatabase.setTier(itemWidget, itemWidget:getItem(), false)
        else
            itemWidget:clearItem()
        end
    end
    for i = 1, 3 do
        local slot = self:findWidget("#imbuiSlot" .. i)
        if slot then
            local val = s.activeImbu[4 - i]
            local active = val and tonumber(val) and tonumber(val) > 0
            slot:setVisible(val ~= nil)
            slot:setImageSource(active and InspectConst.SLOT_ACTIVE_SOURCE_PREFIX .. val or
                                    InspectConst.SLOT_INACTIVE_SOURCE)
            slot:setImageClip(InspectConst.SLOT_EMPTY_CLIP)
        end
    end
end

function InspectController:renderInventorySlots()
    local s = self.state
    if not s then
        return
    end
    local isOutfit = s.viewState == InspectConst.CYCLOPEDIA_VIEW_OUTFIT
    local inv = self:findWidget("#inventoryPanel")
    local out = self:findWidget("#outfitPanel")
    if inv then
        inv:setVisible(not isOutfit)
    end
    if out then
        out:setVisible(isOutfit)
    end
    local selBorder = InspectConst.CYCLOPEDIA_SELECTED_SLOT_BORDER
    local normBorder = InspectConst.CYCLOPEDIA_SLOT_BORDER
    for slotIndex, widgetId in pairs(InspectConst.CYCLOPEDIA_SLOT_WIDGETS) do
        local w = self:findWidget("#" .. widgetId)
        if w then
            local entry = s.bySlot[slotIndex]
            local selected = s.selectedSlot == slotIndex
            w:setBorderWidth(1)
            w:setBorderColor(selected and selBorder or normBorder)
            if entry and entry.item then
                w:setItem(entry.item)
                ItemsDatabase.setTier(w, w:getItem(), false)
                w:setTooltip(entry.name)
                w:setIcon("")
            else
                w:clearItem()
                w:setTooltip("")
                local icon = InspectConst.CYCLOPEDIA_SLOT_ICONS[slotIndex]
                if icon then
                    w:setIcon(icon)
                end
            end
        end
    end
end

function InspectController:renderOutfit()
    local s = self.state
    if not s then
        return
    end
    local creature = self:findWidget("#outfitCreature")
    if creature and s.outfit then
        creature:setOutfit(s.outfit)
        creature:setCenter(true)
    end
end

function InspectController:renderPanelMode()
    local s = self.state
    if not s then
        return
    end
    local btn = self:findWidget("#previewOutfit")
    if btn then
        local isOutfit = s.viewState == InspectConst.CYCLOPEDIA_VIEW_OUTFIT
        btn:setIcon(isOutfit and InspectConst.CYCLOPEDIA_EQUIPMENT_ICON or InspectConst.CYCLOPEDIA_PLAYER_ICON)
    end
end

local function updateRowHeight(widget, oldRect, newRect)
    if oldRect.height == newRect.height then
        return
    end
    local parent = widget:getParent()
    if not parent then
        return
    end
    local k = parent:querySelector(".detailKey")
    local v = parent:querySelector(".detailValue")
    parent:setHeight(math.max(19, k and k:getHeight() or 0, v and v:getHeight() or 0) + 2)
end

function InspectController:renderDescriptions()
    local list = self:findWidget("#itemInfo")
    local s = self.state
    if not list or not s then
        return
    end
    list:destroyChildren()
    for _, d in ipairs(s.activeDesc) do
        local row = self:createWidgetFromHTML([[
            <div class="detailRow">
                <label class="detailKey"></label>
                <label class="detailValue"></label>
            </div>
        ]], list)
        if row then
            local key = row:querySelector(".detailKey")
            local val = row:querySelector(".detailValue")
            if key then
                key:setText(d.detail ~= "" and d.detail .. ":" or "")
                key.onGeometryChange = updateRowHeight
            end
            if val then
                val:setText(d.description)
                val.onGeometryChange = updateRowHeight
            end
        end
    end
end

local function widgetTextHeight(w)
    if not w then
        return 0
    end
    local h = w:getHeight()
    local ts = w.getTextSize and w:getTextSize() or nil
    if ts and ts.height then
        local tsh = ts.height + w:getPaddingTop() + w:getPaddingBottom()
        if tsh > h then
            h = tsh
        end
    end
    return h
end

function InspectController:resizeDetailRows()
    local rows = self:findWidgets(".detailRow")
    if not rows then
        return
    end
    for _, row in ipairs(rows) do
        if not row:isDestroyed() then
            local key = row:querySelector(".detailKey")
            local val = row:querySelector(".detailValue")
            local rw = row:getWidth()
            if key and val and rw > 0 then
                local expectedWidth = rw - key:getWidth() - 5
                if expectedWidth > 0 and val:getWidth() ~= expectedWidth then
                    val:setWidth(expectedWidth)
                end
            end
            local kh = widgetTextHeight(key)
            local vh = widgetTextHeight(val)
            local h = math.max(19, kh, vh)
            if key and kh > 0 and key:getHeight() ~= kh then
                key:setHeight(kh)
            end
            if val and vh > 0 and val:getHeight() ~= vh then
                val:setHeight(vh)
            end
            if row:getHeight() ~= h + 2 then
                row:setHeight(h + 2)
            end
        end
    end
end
-- LuaFormatter off

-- /*=============================================
-- =            Cyclopedia Interactions            =
-- =============================================*/
function InspectController:onCyclopediaSlotClick(slotIndex)
    local s = self.state
    if not s or not s.isCyclopedia then
        return
    end
    local entry = s.bySlot[slotIndex]
    if not entry then
        return
    end
    s.selectedSlot = slotIndex
    s.viewState = InspectConst.CYCLOPEDIA_VIEW_INVENTORY
    s.activeItem = entry.item
    s.activeName = entry.name
    s.activeDesc = entry.descriptions
    s.activeImbu = entry.imbuements
    self:renderInventorySlots()
    self:_renderActive()
end

function InspectController:toggleCyclopediaPreview()
    local s = self.state
    if not s or not s.isCyclopedia then
        return
    end
    s.viewState = s.viewState == InspectConst.CYCLOPEDIA_VIEW_INVENTORY and InspectConst.CYCLOPEDIA_VIEW_OUTFIT or
                      InspectConst.CYCLOPEDIA_VIEW_INVENTORY
    s.selectedSlot = nil
    s.activeItem = nil
    s.activeName = s.playerName
    s.activeDesc = s.playerDesc
    s.activeImbu = {}
    self:renderInventorySlots()
    self:renderOutfit()
    self:renderPanelMode()
    self:_renderActive()
end
-- LuaFormatter on

-- /*=============================================
-- =            External Integrations            =
-- =============================================*/
function InspectController:toggleCyclopedia()
    if not self:isItemCyclopediaable() then
        return
    end
    local item = self.state and self.state.activeItem
    local cyclopedia = modules.game_cyclopedia and modules.game_cyclopedia.Cyclopedia
    if item and cyclopedia and cyclopedia.openItem then
        cyclopedia.openItem(item:getId())
    end
end

function InspectController:toggleProficiency()
    if not self:isItemProficiencyable() then
        return
    end
    local item = self.state and self.state.activeItem
    local proficiency = modules.game_proficiency
    if item and proficiency and proficiency.requestOpenWindow then
        proficiency.requestOpenWindow(item)
    end
end

function InspectController:copyInformation()
    local s = self.state
    if not s then
        return
    end
    local lines = {s.activeName ~= "" and tr("You are inspecting: ") .. s.activeName or tr("You are inspecting:")}
    for _, d in ipairs(s.activeDesc) do
        if d.detail ~= "" then
            lines[#lines + 1] = d.detail .. ": " .. d.description
        elseif d.description ~= "" then
            lines[#lines + 1] = d.description
        end
    end
    g_window.setClipboardText(table.concat(lines, "\n"))
end

function InspectController:showWheel()
    local s = self.state
    if not s then
        return
    end
    g_game.openWheelOfDestiny(s.creatureId)
end
