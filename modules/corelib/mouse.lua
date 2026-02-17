-- @docclass
function g_mouse.bindAutoPress(widget, callback, delay, button, interval)
    local button = button or MouseLeftButton
    local interval = interval or 30
    connect(widget, {
        onMousePress = function(widget, mousePos, mouseButton)
            if mouseButton ~= button then
                return false
            end
            local startTime = g_clock.millis()
            callback(widget, mousePos, mouseButton, 0)
            periodicalEvent(function()
                callback(widget, g_window.getMousePosition(), mouseButton, g_clock.millis() - startTime)
            end, function()
                return g_mouse.isPressed(mouseButton)
            end, interval, delay)
            return true
        end
    })
end

function g_mouse.bindPressMove(widget, callback)
    connect(widget, {
        onMouseMove = function(widget, mousePos, mouseMoved)
            if widget:isPressed() then
                callback(mousePos, mouseMoved)
                return true
            end
        end
    })
end

function g_mouse.bindMove(widget, callback)
    connect(widget, {
        onMouseMove = function(widget, mousePos, mouseMoved)
            callback(mousePos, mouseMoved)
            return true
        end
    })
end

function g_mouse.bindPress(widget, callback, button)
    connect(widget, {
        onMousePress = function(widget, mousePos, mouseButton)
            if not button or button == mouseButton then
                callback(mousePos, mouseButton)
                return true
            end
            return false
        end
    })
end

function g_mouse.bindOnDrop(widget, callback)
    connect(widget, {
        onDrop = function(widget, mousePos)
            callback(mousePos, mouseButton)
            return true
        end
    })
end

if not g_mouse.grabbedMouse then
  g_mouse.grabbedMouse = {}
end

function g_mouse.updateGrabber(widget, mouse)
  if not g_mouse.grabbedMouse[widget] then
    g_mouse.grabbedMouse[widget] = mouse
  else
    g_mouse.grabbedMouse[widget] = nil
  end
end

function g_mouse.clearGrabber()
  for widget, mouse in pairs(g_mouse.grabbedMouse) do
    if mouse ~= '' then
      g_mouse.popCursor(mouse)
    end
    widget:ungrabMouse()
  end
  g_mouse.grabbedMouse = {}
end
