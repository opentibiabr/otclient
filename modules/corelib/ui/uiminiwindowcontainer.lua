-- @docclass
UIMiniWindowContainer = extends(UIWidget, 'UIMiniWindowContainer')

function UIMiniWindowContainer.create()
    local container = UIMiniWindowContainer.internalCreate()
    container.scheduledWidgets = {}
    container:setFocusable(false)
    container:setPhantom(true)
    return container
end

-- TODO: connect to window onResize event
-- TODO: try to resize another widget?
-- TODO: try to find another panel?
function UIMiniWindowContainer:fitAll(noRemoveChild)
    if not self:isVisible() then
        return
    end

    if self.ignoreFillAll then
        return
    end

    if not noRemoveChild then
        local children = self:getChildren()
        for i = #children, 1, -1 do
            if not children[i].isColumnFiller and not children[i].isDropPlaceholder then
                noRemoveChild = children[i]
                break
            end
        end
        if not noRemoveChild then
            return
        end
    end

    local sumHeight = 0
    local children = self:getChildren()
    for i = 1, #children do
        if children[i]:isVisible() and not children[i].isColumnFiller then
            sumHeight = sumHeight + children[i]:getHeight()
        end
    end

    local selfHeight = self:getHeight() - (self:getPaddingTop() + self:getPaddingBottom())
    if sumHeight <= selfHeight then
        return
    end

    local removeChildren = {}

    -- try to resize noRemoveChild
    local maximumHeight = selfHeight - (sumHeight - noRemoveChild:getHeight())
    if noRemoveChild:isResizeable() and noRemoveChild:getMinimumHeight() <= maximumHeight then
        sumHeight = sumHeight - noRemoveChild:getHeight() + maximumHeight
        addEvent(function()
            noRemoveChild:setHeight(maximumHeight)
        end)
    end

    -- try to remove no-save widget
    for i = #children, 1, -1 do
        if sumHeight <= selfHeight then
            break
        end

        local child = children[i]
        if child ~= noRemoveChild and not child.save and not child.isColumnFiller and not child.isDropPlaceholder then
            local childHeight = child:getHeight()
            sumHeight = sumHeight - childHeight
            table.insert(removeChildren, child)
        end
    end

    -- try to remove save widget
    for i = #children, 1, -1 do
        if sumHeight <= selfHeight then
            break
        end

        local child = children[i]
        if child ~= noRemoveChild and child:isVisible() and not child.isColumnFiller and not child.isDropPlaceholder then
            local childHeight = child:getHeight()
            sumHeight = sumHeight - childHeight
            table.insert(removeChildren, child)
        end
    end

    -- close widgets
    for i = 1, #removeChildren do
        removeChildren[i]:close()
    end
end

function UIMiniWindowContainer:updateBottomSeparators()
    -- Guard against reentrancy: moving/resizing the filler below re-triggers
    -- the layout pass, which calls this again through onLayoutUpdate.
    if self.updatingBottomSeparators then
        return
    end
    self.updatingBottomSeparators = true

    -- Keep exactly one filler. Duplicates can rarely slip in (e.g. a filler
    -- restored from a stale saved layout alongside a freshly created one), so
    -- scan all children rather than trusting getChildById's first match and
    -- destroy any extras.
    local filler
    local children = self:getChildren()
    for i = #children, 1, -1 do
        local c = children[i]
        if c.isColumnFiller or c:getId() == 'columnFiller' then
            if filler then
                self:removeChild(c)
                c:destroy()
            else
                filler = c
            end
        end
    end

    if not filler then
        filler = g_ui.createWidget('EmptyColumnFiller')
        filler:setId('columnFiller')
        filler.isColumnFiller = true
        filler.miniLoaded = true
        self:addChild(filler)
    end

    children = self:getChildren()
    local wasLast = (children[#children] == filler)
    if not wasLast then
        self:removeChild(filler)
        self:addChild(filler)
    end

    local sumHeight = 0
    children = self:getChildren()
    for i = 1, #children do
        if children[i]:isVisible() and children[i] ~= filler then
            sumHeight = sumHeight + children[i]:getHeight()
        end
    end

    local selfHeight = self:getHeight() - (self:getPaddingTop() + self:getPaddingBottom())
    local remaining = selfHeight - sumHeight
    if remaining < 2 then
        remaining = 2
    end

    local before = filler:getHeight()
    if before ~= remaining then
        filler:setHeight(remaining)
    end

    self.updatingBottomSeparators = false
end

function UIMiniWindowContainer:onGeometryChange(oldRect, newRect)
    if oldRect and newRect and oldRect.height == newRect.height then
        return
    end
    self:updateBottomSeparators()
end

function UIMiniWindowContainer:onLayoutUpdate()
    self:updateBottomSeparators()
end

function UIMiniWindowContainer:fits(child, minContentHeight, maxContentHeight)
    if self.ignoreFillAll then
        return 0
    end

    local containerPanel = child:getChildById('contentsPanel')
    local indispensableHeight = containerPanel:getMarginTop() + containerPanel:getMarginBottom() +
        containerPanel:getPaddingTop() + containerPanel:getPaddingBottom()

    local totalHeight = 0
    local children = self:getChildren()
    for i = 1, #children do
        if children[i]:isVisible() and not children[i].isColumnFiller and not children[i].isDropPlaceholder then
            totalHeight = totalHeight + children[i]:getHeight()
        end
    end

    local available = self:getHeight() - (self:getPaddingTop() + self:getPaddingBottom()) - totalHeight

    if maxContentHeight > 0 and available >= (maxContentHeight + indispensableHeight) then
        return maxContentHeight + indispensableHeight
    elseif available >= (minContentHeight + indispensableHeight) then
        return available
    else
        return -1
    end
end

-- Rule 3c: the dragged window has no placeholder in this column, so room must
-- be made by evicting (closing) existing windows from south to north.
function UIMiniWindowContainer:dropWithEviction(widget, mousePos)
    local content = self:getHeight() - (self:getPaddingTop() + self:getPaddingBottom())
    local needed = widget:getHeight()

    -- IB height = free space currently in the column (widget is floating, not a child here)
    local children = self:getChildren()
    local used = 0
    for i = 1, #children do
        local c = children[i]
        if c ~= widget and c:isVisible() and not c.isColumnFiller then
            used = used + c:getHeight()
        end
    end
    local available = content - used

    -- draggable regular windows in north -> south order
    local rws = {}
    for i = 1, #children do
        local c = children[i]
        if c ~= widget and c.UIMiniWindowContainer and not c.isColumnFiller and not c.isDropPlaceholder and
            c:isDraggable() then
            rws[#rws + 1] = c
        end
    end

    -- accumulate free space from south to north until the dragged window fits
    local sum = available
    local toClose = {}
    for i = #rws, 1, -1 do
        if sum >= needed then
            break
        end
        sum = sum + rws[i]:getHeight()
        toClose[#toClose + 1] = rws[i]
    end

    local enough = sum >= needed
    if not enough then
        -- rule 3c2: even closing every window is not enough; evict them all and
        -- rescale the dragged window to exactly the remaining IB height.
        toClose = rws
    end

    for i = 1, #toClose do
        toClose[i]:close()
    end

    if not enough then
        local usedAfter = 0
        local nowChildren = self:getChildren()
        for i = 1, #nowChildren do
            local c = nowChildren[i]
            if c ~= widget and c:isVisible() and not c.isColumnFiller then
                usedAfter = usedAfter + c:getHeight()
            end
        end
        widget:setHeight(content - usedAfter)
    end

    -- the freed space sits at the south end (just north of the filler)
    local oldParent = widget:getParent()
    if oldParent then
        oldParent:removeChild(widget)
    end
    local filler = self:getChildById('columnFiller')
    if filler then
        self:insertChild(self:getChildIndex(filler), widget)
    else
        self:addChild(widget)
    end
end

function UIMiniWindowContainer:onDrop(widget, mousePos)
    if (self.onlyPhantomDrop and not (widget.moveOnlyToMain)) or (widget.moveOnlyToMain and not (self.onlyPhantomDrop)) then
        return true
    end

    if widget.UIMiniWindowContainer then
        if widget.dropPlaceholder and widget.dropPlaceholderColumn == self then
            -- rules 3a/3b: a placeholder already marks the landing slot
            local index = self:getChildIndex(widget.dropPlaceholder)
            widget.dropPlaceholder:destroy()
            widget.dropPlaceholder = nil
            widget.dropPlaceholderColumn = nil

            local oldParent = widget:getParent()
            if oldParent then
                oldParent:removeChild(widget)
            end
            self:insertChild(index, widget)
        else
            -- rule 3c: no placeholder here, make room by eviction
            if widget.destroyDropPlaceholder then
                widget:destroyDropPlaceholder()
            end
            self:dropWithEviction(widget, mousePos)
        end

        if widget:getId() == "botWindow" and
            (self:getId() == "gameLeftPanel" or self:getId() == "gameLeftExtraPanel" or
                self:getId() == "gameLeftThirdPanel" or self:getId() == "gameRightExtraPanel" or
                self:getId() == "gameRightThirdPanel" or self:getId() == "gameRightFourthPanel") then
            self:setWidth(190)
        end
        self:fitAll(widget)
        self:updateBottomSeparators()
        return true
    end
end

function UIMiniWindowContainer:swapInsert(widget, index)
    local oldParent = widget:getParent()
    local oldIndex = self:getChildIndex(widget)

    if oldParent == self and oldIndex ~= index then
        local oldWidget = self:getChildByIndex(index)
        if oldWidget then
            self:removeChild(oldWidget)
            self:insertChild(oldIndex, oldWidget)
        end
        self:removeChild(widget)
        self:insertChild(index, widget)
    end
end

function UIMiniWindowContainer:scheduleInsert(widget, index)
    if index - 1 > self:getChildCount() then
        if self.scheduledWidgets[index] then
            pdebug('replacing scheduled widget id ' .. widget:getId())
        end
        self.scheduledWidgets[index] = widget
    else
        local oldParent = widget:getParent()
        if oldParent ~= self then
            if oldParent then
                oldParent:removeChild(widget)
            end
            self:insertChild(index, widget)

            while true do
                local placed = false
                for nIndex, nWidget in pairs(self.scheduledWidgets) do
                    if nIndex - 1 <= self:getChildCount() then
                        self:insertChild(nIndex, nWidget)
                        self.scheduledWidgets[nIndex] = nil
                        placed = true
                        break
                    end
                end
                if not placed then
                    break
                end
            end
        end
    end
end

function UIMiniWindowContainer:order()
    local children = self:getChildren()
    for i = 1, #children do
        if not children[i].miniLoaded and not children[i].isColumnFiller then
            return
        end
    end

    for i = 1, #children do
        if children[i].miniIndex and not children[i].isColumnFiller then
            self:swapInsert(children[i], children[i].miniIndex)
        end
    end

    self:updateBottomSeparators()
end

function UIMiniWindowContainer:saveChildren()
    local children = self:getChildren()
    local ignoreIndex = 0
    for i = 1, #children do
        if children[i].save then
            children[i]:saveParentIndex(self:getId(), i - ignoreIndex)
        else
            ignoreIndex = ignoreIndex + 1
        end
    end
end
