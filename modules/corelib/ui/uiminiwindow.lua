-- @docclass
UIMiniWindow = extends(UIWindow, 'UIMiniWindow')

function UIMiniWindow.create()
    local miniwindow = UIMiniWindow.internalCreate()
    miniwindow.UIMiniWindowContainer = true
    return miniwindow
end

function UIMiniWindow:open(dontSave)
    self:setVisible(true)
    if not dontSave then
        self:setSettings({
            closed = false
        })
    end
    signalcall(self.onOpen, self)
end

function UIMiniWindow:close(dontSave)
    if not self:isExplicitlyVisible() then
        return
    end
    self:setVisible(false)

    if not dontSave then
        self:setSettings({
            closed = true
        })
    end

    signalcall(self.onClose, self)
end

function UIMiniWindow:minimize(dontSave)
    self:setOn(true)
    self:getChildById('contentsPanel'):hide()
    self:getChildById('miniwindowScrollBar'):hide()
    self:getChildById('bottomResizeBorder'):hide()
    self:getChildById('minimizeButton'):setOn(true)
    self.maximizedHeight = self:getHeight()
    self:setHeight(self.minimizedHeight)

    -- Hide miniborder when minimizing
    local miniborder = self:recursiveGetChildById('miniborder')
    if miniborder then
        miniborder:setVisible(false)
    end

    if not dontSave then
        self:setSettings({
            minimized = true
        })
    end

    signalcall(self.onMinimize, self)
end

function UIMiniWindow:maximize(dontSave)
    self:setOn(false)
    self:getChildById('contentsPanel'):show()
    self:getChildById('miniwindowScrollBar'):show()
    self:getChildById('bottomResizeBorder'):show()
    self:getChildById('minimizeButton'):setOn(false)
    self:setHeight(self:getSettings('height') or self.maximizedHeight)

    -- Show miniborder when maximizing
    local miniborder = self:recursiveGetChildById('miniborder')
    if miniborder then
        miniborder:setVisible(true)
    end

    if not dontSave then
        self:setSettings({
            minimized = false
        })
    end

    local parent = self:getParent()
    if parent and parent:getClassName() == 'UIMiniWindowContainer' then
        parent:fitAll(self)
    end

    signalcall(self.onMaximize, self)
end

function UIMiniWindow:setup()
    self:getChildById('closeButton').onClick = function()
        self:close()
    end

    self:getChildById('minimizeButton').onClick = function()
        if self:isOn() then
            self:maximize()
        else
            self:minimize()
        end
    end

    local lockButton = self:getChildById('lockButton')
    if lockButton then
        lockButton.onClick = function()
            if self:isDraggable() then
                self:lock()
            else
                self:unlock()
            end
        end
    end

    self:getChildById('miniwindowTopBar').onDoubleClick = function()
        if self:isOn() then
            self:maximize()
        else
            self:minimize()
        end
    end
end

function UIMiniWindow:setupOnStart()
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end

    local oldParent = self:getParent()
    local newParentSet = false
    local settings = g_settings.getNode('CharMiniWindows')

    if not settings then
        settings = {
            [char] = {}
        }
    elseif not settings[char] then
        -- if there are no settings for this character, we'll copy the settings from
        -- another one, so we'll have something better than all the windows randomly positioned
        for k, v in pairs(settings) do
            settings[char] = v
            g_settings.setNode('CharMiniWindows', settings)
            break
        end
    end

    local selfSettings = settings[char][self:getId()]
    if selfSettings then
        if selfSettings.parentId then
            local parent = rootWidget:recursiveGetChildById(selfSettings.parentId)
            if parent and parent:isVisible() then
                if parent:getClassName() == 'UIMiniWindowContainer' and selfSettings.index and parent:isOn() then
                    self.miniIndex = selfSettings.index
                    parent:scheduleInsert(self, selfSettings.index)
                    newParentSet = true
                elseif selfSettings.position then
                    self:setParent(parent, true)
                    self:setPosition(topoint(selfSettings.position))
                    newParentSet = true
                end
            end
        end

        if selfSettings.minimized then
            self:minimize(true)
        elseif selfSettings.height then
            if self:isResizeable() then
                self:setHeight(selfSettings.height)
            else
                self:eraseSettings({
                    height = true
                })
            end
        end

        if selfSettings.closed then
            self:close(true)
        else
            self:open(true)
        end
    else
        if self:getId() == "battleWindow" then
            self:open(true)
        end
    end

    local newParent = self:getParent()

    if not oldParent and not newParentSet then
        oldParent = modules.game_interface.getRightPanel()
        self:setParent(oldParent)
    end

    self.miniLoaded = true

    if self.save then
        if oldParent and oldParent:getClassName() == 'UIMiniWindowContainer' then
            addEvent(function()
                oldParent:order()
            end)
        end
        if newParent and newParent:getClassName() == 'UIMiniWindowContainer' and newParent ~= oldParent then
            addEvent(function()
                newParent:order()
            end)
        end
    end

    self:fitOnParent()
    if self:getId() == "botWindow" then
        local parent = self:getParent()
        local parentId = parent:getId()

        if parentId == "gameLeftPanel" or
            parentId == "gameLeftExtraPanel" or
            parentId == "gameLeftThirdPanel" or
            parentId == "gameRightExtraPanel" or
            parentId == "gameRightThirdPanel" or
            parentId == "gameRightFourthPanel" then
            if parent:isVisible() then
                parent:setWidth(190)
            end
        end
    end
end

function UIMiniWindow:onVisibilityChange(visible)
    self:fitOnParent()
end

local function isRegularWindow(w)
    return w.UIMiniWindowContainer and not w.isColumnFiller and not w.isDropPlaceholder
end

-- Free vertical space in a column (the IB height), excluding the filler.
local function columnFreeHeight(column)
    local content = column:getHeight() - (column:getPaddingTop() + column:getPaddingBottom())
    local used = 0
    local children = column:getChildren()
    for i = 1, #children do
        local c = children[i]
        if c:isVisible() and not c.isColumnFiller then
            used = used + c:getHeight()
        end
    end
    return content - used
end

-- Child index where a placeholder should be inserted in `column` so that it
-- sits north of the first movable window whose midpoint is south of refY.
-- Immovable (non-draggable) windows act as fixed top anchors.
local function slotIndexForY(column, refY)
    local children = column:getChildren()
    for i = 1, #children do
        local c = children[i]
        if isRegularWindow(c) and c:isDraggable() then
            local mid = c:getY() + c:getHeight() / 2
            if refY < mid then
                return column:getChildIndex(c)
            end
        end
    end
    local filler = column:getChildById('columnFiller')
    if filler then
        return column:getChildIndex(filler)
    end
    return column:getChildCount() + 1
end

function UIMiniWindow:destroyDropPlaceholder()
    if self.dropPlaceholder then
        local column = self.dropPlaceholderColumn
        self.dropPlaceholder:destroy()
        self.dropPlaceholder = nil
        self.dropPlaceholderColumn = nil
        if column then
            column:updateBottomSeparators()
        end
    end
end

function UIMiniWindow:createDropPlaceholder(column, index)
    self:destroyDropPlaceholder()
    local dp = g_ui.createWidget('MiniWindowDropPlaceholder')
    dp.isDropPlaceholder = true
    dp:setHeight(self:getHeight())
    column:insertChild(index, dp)
    self.dropPlaceholder = dp
    self.dropPlaceholderColumn = column
    column:updateBottomSeparators()
    self:raise()
end

function UIMiniWindow:getHoveredColumn(mousePos)
    local widgets = rootWidget:recursiveGetChildrenByMarginPos(mousePos)
    for i = 1, #widgets do
        -- Walk up to the enclosing column. Bounded by a hard depth cap so a
        -- malformed/cyclic parent chain can never spin forever.
        local w = widgets[i]
        for _ = 1, 32 do
            if not w or w == rootWidget then
                break
            end
            if w:getClassName() == 'UIMiniWindowContainer' then
                return w
            end
            w = w:getParent()
        end
    end
    return nil
end

function UIMiniWindow:onDragEnter(mousePos)
    local parent = self:getParent()
    if not parent then
        return false
    end

    if parent:getClassName() == 'UIMiniWindowContainer' then
        self.oldParentDrag = parent
        self.oldParentDragIndex = parent:getChildIndex(self)
        local containerParent = parent:getParent()
        local originIndex = self.oldParentDragIndex

        parent:removeChild(self)
        containerParent:addChild(self)
        parent:saveChildren()

        self:createDropPlaceholder(parent, originIndex)
    end

    local oldPos = self:getPosition()
    self.movingReference = {
        x = mousePos.x - oldPos.x,
        y = mousePos.y - oldPos.y
    }
    self:setPosition(oldPos)
    self.free = true
    return true
end

-- Rule 1: reposition the placeholder within its own column. Uses the exact same
-- mouse-Y-vs-window-midpoint rule as cross-column placement (slotIndexForY), so
-- the snap height is a pure function of the cursor position with no direction
-- dependence. The placeholder is lifted out before computing the target slot so
-- midpoints are read at their natural (undisplaced) positions, then reinserted.
function UIMiniWindow:reorderPlaceholderSameColumn(column, mousePos)
    local dp = self.dropPlaceholder
    if not dp then
        return
    end

    local curIndex = column:getChildIndex(dp)
    column:removeChild(dp)
    local index = slotIndexForY(column, mousePos.y)
    column:insertChild(index, dp)

    if column:getChildIndex(dp) ~= curIndex then
        column:updateBottomSeparators()
    end
end

-- Rule 2: entering a different column. Only create a placeholder if the column
-- has room for the dragged window (IB height >= dragged height).
function UIMiniWindow:placePlaceholderInColumn(column, mousePos)
    if (column.onlyPhantomDrop and not self.moveOnlyToMain) or (self.moveOnlyToMain and not column.onlyPhantomDrop) then
        self:destroyDropPlaceholder()
        return
    end

    if columnFreeHeight(column) < self:getHeight() then
        self:destroyDropPlaceholder()
        return
    end

    local index = slotIndexForY(column, mousePos.y)
    self:createDropPlaceholder(column, index)
end

function UIMiniWindow:onDragMove(mousePos, mouseMoved)
    local column = self:getHoveredColumn(mousePos)
    if column then
        if column == self.dropPlaceholderColumn then
            self:reorderPlaceholderSameColumn(column, mousePos)
        else
            self:placePlaceholderInColumn(column, mousePos)
        end
    end

    return UIWindow.onDragMove(self, mousePos, mouseMoved)
end

function UIMiniWindow:onDragLeave(droppedWidget, mousePos)
    -- moveOnlyToMain widgets (minimap, inventory, ...) must return to their main panel.
    local forceReturn = false
    if self.moveOnlyToMain or (droppedWidget and droppedWidget.onlyPhantomDrop) then
        if (not droppedWidget) or (self.moveOnlyToMain and not droppedWidget.onlyPhantomDrop) or
            (not self.moveOnlyToMain and droppedWidget.onlyPhantomDrop) then
            forceReturn = true
        end
    end

    if forceReturn then
        self:destroyDropPlaceholder()
        local p = self:getParent()
        if p then
            p:removeChild(self)
        end
        self.oldParentDrag:insertChild(self.oldParentDragIndex, self)
        self.oldParentDrag:updateBottomSeparators()
    elseif not droppedWidget then
        -- Drop wasn't accepted by any column: land at the placeholder if it
        -- exists, otherwise fall back to the origin column (rule 3 guarantee).
        local column = self.dropPlaceholderColumn
        if column then
            local index = column:getChildIndex(self.dropPlaceholder)
            self.dropPlaceholder:destroy()
            self.dropPlaceholder = nil
            self.dropPlaceholderColumn = nil
            local p = self:getParent()
            if p then
                p:removeChild(self)
            end
            column:insertChild(index, self)
            column:fitAll(self)
            column:updateBottomSeparators()
        elseif self.oldParentDrag then
            self:destroyDropPlaceholder()
            local p = self:getParent()
            if p then
                p:removeChild(self)
            end
            self.oldParentDrag:dropWithEviction(self, { x = 0, y = 1e9 })
            self.oldParentDrag:fitAll(self)
            self.oldParentDrag:updateBottomSeparators()
        end
    else
        self:destroyDropPlaceholder()
    end

    self:saveParent(self:getParent())
    return true
end

function UIMiniWindow:onMousePress()
    local parent = self:getParent()
    if not parent then
        return false
    end
    if parent:getClassName() ~= 'UIMiniWindowContainer' then
        self:raise()
        return true
    end
end

function UIMiniWindow:onFocusChange(focused)
    if not focused then
        return
    end
    local parent = self:getParent()
    if parent and parent:getClassName() ~= 'UIMiniWindowContainer' then
        self:raise()
    end
end

function UIMiniWindow:onHeightChange(height)
    if not self:isOn() then
        self:setSettings({
            height = height
        })
    end
    self:fitOnParent()
end

function UIMiniWindow:getSettings(name)
    if not self.save then
        return nil
    end
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return nil
    end

    local settings = g_settings.getNode('CharMiniWindows')
    if settings then
        local selfSettings = settings[char][self:getId()]
        if selfSettings then
            return selfSettings[name]
        end
    end

    return nil
end

function UIMiniWindow:setSettings(data)
    if not self.save then
        return
    end
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end

    local settings = g_settings.getNode('CharMiniWindows')
    if not settings then
        settings = {}
    end
    if not settings[char] then
        settings[char] = {}
    end

    local id = self:getId()
    if not settings[char][id] then
        settings[char][id] = {}
    end

    for key, value in pairs(data) do
        settings[char][id][key] = value
    end

    g_settings.setNode('CharMiniWindows', settings)
end

function UIMiniWindow:eraseSettings(data)
    if not self.save then
        return
    end
    local char = g_game.getCharacterName()
    if not char or #char == 0 then
        return
    end

    local settings = g_settings.getNode('CharMiniWindows')
    if not settings then
        settings = {}
    end
    if not settings[char] then
        settings[char] = {}
    end

    local id = self:getId()
    if not settings[char][id] then
        settings[char][id] = {}
    end

    for key, value in pairs(data) do
        settings[char][id][key] = nil
    end

    g_settings.setNode('CharMiniWindows', settings)
end

function UIMiniWindow:saveParent(parent)
    local parent = self:getParent()
    if parent then
        if parent:getClassName() == 'UIMiniWindowContainer' then
            parent:saveChildren()
        else
            self:saveParentPosition(parent:getId(), self:getPosition())
        end
    end
end

function UIMiniWindow:saveParentPosition(parentId, position)
    local selfSettings = {}
    selfSettings.parentId = parentId
    selfSettings.position = pointtostring(position)
    self:setSettings(selfSettings)
end

function UIMiniWindow:saveParentIndex(parentId, index)
    local selfSettings = {}
    selfSettings.parentId = parentId
    selfSettings.index = index
    self:setSettings(selfSettings)
    self.miniIndex = index
end

function UIMiniWindow:disableResize()
    self:getChildById('bottomResizeBorder'):disable()
end

function UIMiniWindow:enableResize()
    self:getChildById('bottomResizeBorder'):enable()
end

function UIMiniWindow:fitOnParent()
    local parent = self:getParent()
    if parent and parent:getClassName() == 'UIMiniWindowContainer' then
        if self:isVisible() then
            parent:fitAll(self)
        end
        parent:updateBottomSeparators()
    end
end

function UIMiniWindow:setParent(parent, dontsave)
    UIWidget.setParent(self, parent)
    if not dontsave then
        self:saveParent(parent)
    end
    self:fitOnParent()
end

function UIMiniWindow:setHeight(height)
    UIWidget.setHeight(self, height)
    signalcall(self.onHeightChange, self, height)
end

function UIMiniWindow:setContentHeight(height)
    local contentsPanel = self:getChildById('contentsPanel')
    local minHeight = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() +
        contentsPanel:getPaddingBottom()

    local resizeBorder = self:getChildById('bottomResizeBorder')
    resizeBorder:setParentSize(minHeight + height)
end

function UIMiniWindow:setContentMinimumHeight(height)
    local contentsPanel = self:getChildById('contentsPanel')
    local minHeight = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() +
        contentsPanel:getPaddingBottom()

    local resizeBorder = self:getChildById('bottomResizeBorder')
    resizeBorder:setMinimum(minHeight + height)
end

function UIMiniWindow:setContentMaximumHeight(height)
    local contentsPanel = self:getChildById('contentsPanel')
    local minHeight = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() +
        contentsPanel:getPaddingBottom()

    local resizeBorder = self:getChildById('bottomResizeBorder')
    resizeBorder:setMaximum(minHeight + height)
end

function UIMiniWindow:getMinimumHeight()
    local resizeBorder = self:getChildById('bottomResizeBorder')
    return resizeBorder:getMinimum()
end

function UIMiniWindow:getMaximumHeight()
    local resizeBorder = self:getChildById('bottomResizeBorder')
    return resizeBorder:getMaximum()
end

function UIMiniWindow:modifyMaximumHeight(height)
    local resizeBorder = self:getChildById('bottomResizeBorder')
    local newHeight = resizeBorder:getMaximum() + height
    local curHeight = self:getHeight()
    resizeBorder:setMaximum(newHeight)
    if newHeight < curHeight or newHeight - height == curHeight then
        self:setHeight(newHeight)
    end
end

function UIMiniWindow:isResizeable()
    local resizeBorder = self:getChildById('bottomResizeBorder')
    if not resizeBorder then
        return false
    end
    return resizeBorder:isExplicitlyVisible() and resizeBorder:isEnabled()
end

function UIMiniWindow:lock(dontSave)
    local lockButton = self:getChildById('lockButton')
    if lockButton then
        lockButton:setOn(true)
    end
    self:setDraggable(false)
    self:setBorderWidth(1)
    self:setBorderColor('#d33c3c')
    if not dontSave then
        self:setSettings({
            locked = true
        })
    end

    signalcall(self.onLockChange, self)
end

function UIMiniWindow:unlock(dontSave)
    local lockButton = self:getChildById('lockButton')
    if lockButton then
        lockButton:setOn(false)
    end
    self:setDraggable(true)
    self:setBorderWidth(0)
    if not dontSave then
        self:setSettings({
            locked = false
        })
    end
    signalcall(self.onLockChange, self)
end
