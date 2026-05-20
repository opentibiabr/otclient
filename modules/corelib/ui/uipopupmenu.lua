-- @docclass
UIPopupMenu = extends(UIWidget, 'UIPopupMenu')

local currentMenu

function UIPopupMenu.create()
    local menu = UIPopupMenu.internalCreate()
    local layout = UIVerticalLayout.create(menu)
    layout:setFitChildren(true)
    menu:setLayout(layout)
    menu.isGameMenu = false
    return menu
end

function UIPopupMenu:display(pos)
    -- don't display if not options was added
    if self:getChildCount() == 0 then
        self:destroy()
        return
    end

    if g_ui.isMouseGrabbed() then
        self:destroy()
        return
    end

    if currentMenu then
        currentMenu:destroy()
    end

    if pos == nil then
        pos = g_window.getMousePosition()
    end

    rootWidget:addChild(self)
    self:setPosition(pos)
    self:grabMouse()
    self:focus()
    -- self:grabKeyboard()
    currentMenu = self
end

function UIPopupMenu:onGeometryChange(newRect, oldRect)
    local parent = self:getParent()
    if not parent then
        return
    end
    local ymax = parent:getY() + parent:getHeight()
    local xmax = parent:getX() + parent:getWidth()
    if ymax < newRect.y + newRect.height then
        local newy = ymax - newRect.height
        if newy > 0 and ymax > newy + newRect.height then
            self:setY(newy)
        end
    end
    if xmax < newRect.x + newRect.width then
        local newx = xmax - newRect.width
        if newx > 0 and xmax > newx + newRect.width then
            self:setX(newx)
        end
    end
    self:bindRectToParent()
end

function UIPopupMenu:addOption(optionName, optionCallback, shortcut, disabled)
    local optionWidget = g_ui.createWidget(self:getStyleName() .. 'Button', self)
    optionWidget.onClick = function(widget)
        self:destroy()
        optionCallback(self:getPosition())
    end
    optionWidget:setText(optionName)
    local width = optionWidget:getTextSize().width + optionWidget:getMarginLeft() + optionWidget:getMarginRight() + 15

    if shortcut then
        local shortcutLabel = g_ui.createWidget(self:getStyleName() .. 'ShortcutLabel', optionWidget)
        shortcutLabel:setText(shortcut)
        width = width + shortcutLabel:getTextSize().width + shortcutLabel:getMarginLeft() +
                    shortcutLabel:getMarginRight()
    end
    optionWidget:setEnabled(not disabled)
    self:setWidth(math.max(190, math.max(self:getWidth(), width)))
end

function UIPopupMenu:addSeparator()
    g_ui.createWidget('HorizontalSeparator', self)
end

function UIPopupMenu:addText(text)
    local optionWidget = g_ui.createWidget("PopupScrollMenuShortcutLabel", self)
    optionWidget:setText(text)
    local width = optionWidget:getTextSize().width + optionWidget:getMarginLeft() + optionWidget:getMarginRight() + 15
    self:setWidth(math.max(self:getWidth(), width))
end

function UIPopupMenu:addCheckBox(text, checked, callback)
    local checkBox = g_ui.createWidget(self:getStyleName() .. 'CheckBox', self)
    checkBox:setText(text)
    checkBox:setChecked(checked or false)
    checkBox.onClick = function()
        checkBox:setChecked(not checkBox:isChecked())
        self:destroy()
        callback(checkBox, checkBox:isChecked())
    end
    local width = checkBox:getTextSize().width + checkBox:getMarginLeft() + checkBox:getMarginRight() + 30
    self:setWidth(math.max(self:getWidth(), width))
    return checkBox
end

function UIPopupMenu:setGameMenu(state)
    self.isGameMenu = state
end

function UIPopupMenu:onDestroy()
    if currentMenu == self then
        currentMenu = nil
    end
    self:ungrabMouse()
end

function UIPopupMenu:onMousePress(mousePos, mouseButton)
    -- clicks outside menu area destroys the menu
    if not self:containsPoint(mousePos) then
        self:destroy()
    end
    return true
end

function UIPopupMenu:onKeyPress(keyCode, keyboardModifiers)
    if keyCode == KeyEscape then
        self:destroy()
        return true
    end
    return false
end

-- close all menus when the window is resized
local function onRootGeometryUpdate()
    if currentMenu then
        currentMenu:destroy()
    end
end

local function onGameEnd()
    if currentMenu and currentMenu.isGameMenu then
        currentMenu:destroy()
    end
end

connect(rootWidget, {
    onGeometryChange = onRootGeometryUpdate
})
connect(g_game, {
    onGameEnd = onGameEnd
})
