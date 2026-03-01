local clayDemoWindow
local clayDemoButton

function init()
    clayDemoButton = modules.client_topmenu.addTopRightRegularButton(
        'clayDemoButton',
        tr('Clay Demo'),
        nil,
        toggle
    )

    -- Show the demo window automatically on first load
    scheduleEvent(function()
        show()
    end, 500)
end

function terminate()
    if clayDemoWindow then
        clayDemoWindow:destroy()
        clayDemoWindow = nil
    end
    if clayDemoButton then
        clayDemoButton:destroy()
        clayDemoButton = nil
    end
end

function show()
    if clayDemoWindow then
        clayDemoWindow:show()
        clayDemoWindow:raise()
        clayDemoWindow:focus()
        return
    end

    clayDemoWindow = g_ui.displayUI('claydemo')
    local closeButton = clayDemoWindow:recursiveGetChildById('closeButton')
    if closeButton then
        closeButton.onClick = function()
            hide()
        end
    end
end

function hide()
    if clayDemoWindow then
        clayDemoWindow:hide()
    end
end

function toggle()
    if clayDemoWindow and clayDemoWindow:isVisible() then
        hide()
    else
        show()
    end
end
