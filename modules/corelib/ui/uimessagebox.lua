if not UIMiniWindow then
    dofile 'uiminiwindow'
end

-- @docclass
UIMessageBox = extends(UIMiniWindow, 'UIMessageBox')

-- messagebox cannot be created from otui files
function UIMessageBox.create(title, okCallback, cancelCallback)
    local calendar = UIMessageBox.internalCreate()
    return calendar
end

function UIMessageBox.display(title, message, buttons, onEnterCallback, onEscapeCallback)
    local rootWidth = rootWidget and rootWidget:getWidth() or 956
    local rootHeight = rootWidget and rootWidget:getHeight() or 656
    local staticSizes = {
        width = {
            max = math.min(916, math.max(260, rootWidth - 40)),
            min = 246
        },
        height = {
            min = 56,
            max = math.min(616, math.max(120, rootHeight - 40))
        }
    }
    local horizontalPadding = 32
    local maxContentWidth = staticSizes.width.max - horizontalPadding
    local currentSizes = {
        width = 0,
        height = 0
    }

    local messageBox = g_ui.createWidget('MessageBoxWindow', rootWidget)
    messageBox.title = messageBox:getChildById('title')
    messageBox.title:setText(title)

    messageBox.content = messageBox:getChildById('content')
    messageBox.content:setTextWrap(true)
    messageBox.content:setWidth(maxContentWidth)
    messageBox.content:setText(message)
    messageBox.content:resizeToText()
    currentSizes.width = currentSizes.width + math.min(maxContentWidth, math.max(messageBox.content:getWidth(), messageBox.content:getTextSize().width)) + horizontalPadding
    currentSizes.height = currentSizes.height + messageBox.content:getHeight() + 20

    messageBox.holder = messageBox:getChildById('holder')

    currentSizes.height = currentSizes.height + 22
    for i = 1, #buttons do
        local button = messageBox:addButton(buttons[i].text, buttons[i].callback)
        button:addAnchor(AnchorTop, 'parent', AnchorTop)
        if i == 1 then
            button:addAnchor(AnchorRight, 'parent', AnchorRight)
            currentSizes.height = currentSizes.height + button:getHeight() + 22
        else
            button:addAnchor(AnchorRight, 'prev', AnchorLeft)
            button:setMarginRight(10)
        end
    end

    local finalWidth = math.min(staticSizes.width.max, math.max(staticSizes.width.min, currentSizes.width))
    messageBox:setWidth(finalWidth)
    messageBox.content:setWidth(finalWidth - horizontalPadding)
    messageBox.content:resizeToText()

    currentSizes.height = messageBox.content:getHeight() + 20 + 22
    if #buttons > 0 then
        currentSizes.height = currentSizes.height + 42
    end
    messageBox:setHeight(math.min(staticSizes.height.max, math.max(staticSizes.height.min, currentSizes.height)))

    if onEnterCallback then
        connect(messageBox, {
            onEnter = onEnterCallback
        })
    end
    if onEscapeCallback then
        connect(messageBox, {
            onEscape = onEscapeCallback
        })
    end

    return messageBox
end

function alert(msg)
    displayInfoBox("Alert", msg)
end

function displayInfoBox(title, message)
    local messageBox
    local defaultCallback = function()
        messageBox:ok()
    end
    messageBox = UIMessageBox.display(title, message, { {
        text = 'Ok',
        callback = defaultCallback
    } }, defaultCallback, defaultCallback)
    return messageBox
end

function displayErrorBox(title, message)
    local messageBox
    local defaultCallback = function()
        messageBox:ok()
    end
    messageBox = UIMessageBox.display(title, message, { {
        text = 'Ok',
        callback = defaultCallback
    } }, defaultCallback, defaultCallback)
    return messageBox
end

function displayCancelBox(title, message)
    local messageBox
    local defaultCallback = function()
        messageBox:cancel()
    end
    messageBox = UIMessageBox.display(title, message, { {
        text = 'Cancel',
        callback = defaultCallback
    } }, defaultCallback, defaultCallback)
    return messageBox
end

function displayGeneralBox(title, message, buttons, onEnterCallback, onEscapeCallback)
    return UIMessageBox.display(title, message, buttons, onEnterCallback, onEscapeCallback)
end

function displayGeneralSHOPBox(title, message, description, buttons, onEnterCallback, onEscapeCallback)
    return UIMessageBox.displaySHOP(title, message, description, buttons, onEnterCallback, onEscapeCallback)
end

function UIMessageBox:addButton(text, callback)
    local holder = self:getChildById('holder')
    local button = g_ui.createWidget('QtButton', holder)
    button:setWidth(math.max(48, 10 + (string.len(text) * 8)))
    button:setHeight(20)
    button:setText(text)
    connect(button, {
        onClick = callback
    })
    return button
end

function UIMessageBox:ok()
    signalcall(self.onOk, self)
    self.onOk = nil
    self:destroy()
end

function UIMessageBox:cancel()
    signalcall(self.onCancel, self)
    self.onCancel = nil
    self:destroy()
end

function UIMessageBox.displaySHOP(title, message, description, buttons, onEnterCallback, onEscapeCallback)
    local staticSizes = {
        width = {
            max = 390,
            min = 390
        },
        height = {
            min = 200,
            max = 200
        }
    }
    local currentSizes = {
        width = 0,
        height = 0
    }

    local messageBox = g_ui.createWidget('MessageBoxShopWindow', rootWidget)
    messageBox.title = messageBox:getChildById('title')
    messageBox.title:setText(title)
    messageBox.title:setTextAutoResize(true)

    messageBox.content = messageBox:getChildById('content')
    messageBox.content:setText(message)
    messageBox.content:setTextAutoResize(true)
    messageBox.content:setTextWrap(true)
    messageBox.content:setTextAlign(AlignCenter)

    messageBox.additionalLabel:setText(description)
    messageBox.additionalLabel:setTextWrap(true)
    messageBox.additionalLabel:setTextAlign(AlignCenter)

    local contentWidth = messageBox.content:getTextSize().width + messageBox.content:getPaddingLeft() +
    messageBox.content:getPaddingRight()
    local contentHeight = messageBox.content:getHeight() + messageBox.content:getPaddingTop() +
    messageBox.content:getPaddingBottom()

    currentSizes.width = contentWidth + 32
    currentSizes.height = contentHeight + 20

    messageBox.holder = messageBox:getChildById('holder')

    currentSizes.height = currentSizes.height + 22
    for i = 1, #buttons do
        local button = messageBox:addButton(buttons[i].text, buttons[i].callback)
        button:addAnchor(AnchorTop, 'parent', AnchorTop)
        if i == 1 then
            button:addAnchor(AnchorRight, 'parent', AnchorRight)
            currentSizes.height = currentSizes.height + button:getHeight() + 22
            button:setImageSource('/images/options/blue_large')
            button:setImageClip("0 0 108 20")
        else
            button:addAnchor(AnchorRight, 'prev', AnchorLeft)

            button:setMarginRight(10)
        end
    end

    messageBox:setWidth(currentSizes.width)
    messageBox:setHeight(math.min(staticSizes.height.max, math.max(staticSizes.height.min, currentSizes.height)))

    if onEnterCallback then
        connect(messageBox, {
            onEnter = onEnterCallback
        })
    end
    if onEscapeCallback then
        connect(messageBox, {
            onEscape = onEscapeCallback
        })
    end

    return messageBox
end
