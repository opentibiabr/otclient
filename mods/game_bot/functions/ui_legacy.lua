local context = G.botContext

-- DO NOT USE THIS CODE.
-- IT'S ONLY HERE FOR BACKWARD COMPATIBILITY, MAY BE REMOVED IN THE FUTURE

context.createWidget = function(name, parent)
  if parent == nil then
    parent = context.panel
  end
  g_ui.createWidget(name, parent)
end

context.setupUI = function(otml, parent)
  if parent == nil then
    parent = context.panel
  end
  local widget = g_ui.loadUIFromString(otml, parent)
  widget.botWidget = true
  return widget
end

context.importStyle = function(otml)
  if type(otml) ~= "string" then
    return error("Invalid parameter for importStyle, should be string")
  end
  if otml:find(".otui") and not otml:find("\n") then
    return g_ui.importStyle(context.configDir .. "/" .. otml)
  end
  return g_ui.importStyleFromString(otml)
end

context.addTab = function(name)
  local tab = context.tabs:getTab(name)
  if tab then -- return existing tab
    return tab.tabPanel.content
  end

  local smallTabs = #(context.tabs.tabs) >= 5
  local newTab = context.tabs:addTab(name, g_ui.createWidget('BotPanel')).tabPanel.content
  context.tabs:setOn(true)
  if smallTabs then
    for k,tab in pairs(context.tabs.tabs) do
      tab:setFont('small-9px')
    end
  end

  return newTab
end
context.getTab = context.addTab

context.setDefaultTab = function(name)
  local tab = context.addTab(name)
  context.panel = tab
end

context.addSwitch = function(id, text, onClickCallback, parent)
  if not parent then
    parent = context.panel
  end
  local switch = g_ui.createWidget('BotSwitch', parent)
  switch:setId(id)
  switch:setText(text)
  switch.onClick = onClickCallback
  return switch
end

context.addButton = function(id, text, onClickCallback, parent)
  if not parent then
    parent = context.panel
  end
  local button = g_ui.createWidget('BotButton', parent)
  button:setId(id)
  button:setText(text)
  button.onClick = onClickCallback
  return button
end

context.addLabel = function(id, text, parent)
  if not parent then
    parent = context.panel
  end
  local label = g_ui.createWidget('BotLabel', parent)
  label:setId(id)
  label:setText(text)
  return label
end

context.addTextEdit = function(id, text, onTextChangeCallback, parent)
  if not parent then
    parent = context.panel
  end
  local widget = g_ui.createWidget('BotTextEdit', parent)
  widget:setId(id)
  widget.onTextChange = onTextChangeCallback
  widget:setText(text)
  return widget
end

context.addSeparator = function(id, parent)
  if not parent then
    parent = context.panel
  end
  local separator = g_ui.createWidget('BotSeparator', parent)
  separator:setId(id)
  return separator
end

context._addMacroSwitch = function(name, keys, parent)
  if not parent then
    parent = context.panel
  end
  local text = name
  if keys:len() > 0 then
    text = name .. " [" .. keys .. "]"
  end
  local switch = context.addSwitch("macro_" .. #context._macros, text, function(widget)
    context.storage._macros[name] = not context.storage._macros[name]
    widget:setOn(context.storage._macros[name])
  end, parent)
  switch:setOn(context.storage._macros[name])
  return switch
end

context._addHotkeySwitch = function(name, keys, parent)
  if not parent then
    parent = context.panel
  end
  local text = name
  if keys:len() > 0 then
    text = name .. " [" .. keys .. "]"
  end
  local switch = context.addSwitch("hotkey_" .. #context._hotkeys, text, nil, parent)
  switch:setOn(false)
  return switch
end
