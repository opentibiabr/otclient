local context = G.botContext
if type(context.UI) ~= "table" then
  context.UI = {}
end
local UI = context.UI

UI.Button = function(text, callback, parent)
  local widget = UI.createWidget("BotButton", parent)
  widget:setText(text)
  widget.onClick = callback
  return widget
end

UI.Config = function(parent)
  return UI.createWidget("BotConfig", parent)
end

-- call :setItems(table) to set items, call :getItems() to get them
-- unique if true, won't allow duplicates
-- callback (can be nil) gets table with new item list, eg: {{id=2160, count=1}, {id=268, count=100}, {id=269, count=20}}
UI.Container = function(callback, unique, parent, widget)
  if not widget then
    widget = UI.createWidget("BotContainer", parent)
  end

  local oldItems = {}

  local scrollToBottom = function()
    local scrollbar = widget.scroll
    if scrollbar and scrollbar.setValue and scrollbar.getMaximum then
      scrollbar:setValue(scrollbar:getMaximum())
    end
  end

  local updateItems = function()
    local items = widget:getItems()

    -- callback part
    local somethingNew = (#items ~= #oldItems)
    for i, item in ipairs(items) do
      if type(oldItems[i]) ~= "table" then
        somethingNew = true
        break
      end
      if oldItems[i].id ~= item.id or oldItems[i].count ~= item.count then
        somethingNew = true
        break
      end
    end

    if somethingNew then
      oldItems = items
      callback(widget, items)
    end

    widget:setItems(items)
  end

  widget.setItems = function(self, items)
    if type(self) == 'table' then
      items = self
    end
    local itemsToShow = math.max(10, #items + 2)
    if itemsToShow % 5 ~= 0 then
      itemsToShow = itemsToShow + 5 - itemsToShow % 5
    end
    widget.items:destroyChildren()
    for i = 1, itemsToShow do
      local widget = g_ui.createWidget("BotItem", widget.items)
      if type(items[i]) == 'number' then
        items[i] = { id = items[i], count = 1 }
      end
      if type(items[i]) == 'table' then
        widget:setItem(Item.create(items[i].id, items[i].count))
      end
    end
    oldItems = items
    for i, child in ipairs(widget.items:getChildren()) do
      child.onItemChange = updateItems
    end
    scrollToBottom()
  end

  widget.getItems = function()
    local items = {}
    local duplicates = {}
    for i, child in ipairs(widget.items:getChildren()) do
      if child:getItemId() >= 100 then
        if not duplicates[child:getItemId()] or not unique then
          table.insert(items, { id = child:getItemId(), count = child:getItemCountOrSubType() })
          duplicates[child:getItemId()] = true
        end
      end
    end
    return items
  end

  widget:setItems({})

  return widget
end

UI.DualScrollPanel = function(params, callback, parent) -- callback = function(widget, newParams)
  --[[ params:
    on - bool,
    text - string,
    title - string,
    min - number,
    max - number,
  ]]
  params.title = params.title or "title"
  params.text = params.text or ""
  params.min = params.min or 20
  params.max = params.max or 80

  local widget = UI.createWidget('DualScrollPanel', parent)

  widget.title:setOn(params.on)
  widget.title.onClick = function()
    params.on = not params.on
    widget.title:setOn(params.on)
    if callback then
      callback(widget, params)
    end
  end

  widget.text:setText(params.text or "")
  widget.text.onTextChange = function(widget, text)
    params.text = text
    if callback then
      callback(widget, params)
    end
  end

  local update = function(dontSignal)
    widget.title:setText("" .. params.min .. "% <= " .. params.title .. " <= " .. params.max .. "%")
    if callback and not dontSignal then
      callback(widget, params)
    end
  end

  widget.scroll1:setValue(params.min)
  widget.scroll2:setValue(params.max)

  widget.scroll1.onValueChange = function(scroll, value)
    params.min = value
    update()
  end
  widget.scroll2.onValueChange = function(scroll, value)
    params.max = value
    update()
  end
  update(true)
end

UI.DualScrollItemPanel = function(params, callback, parent) -- callback = function(widget, newParams)
  --[[ params:
    on - bool,
    item - number,
    subType - number,
    title - string,
    min - number,
    max - number,
  ]]
  params.title = params.title or "title"
  params.item = params.item or 0
  params.subType = params.subType or 0
  params.min = params.min or 20
  params.max = params.max or 80

  local widget = UI.createWidget('DualScrollItemPanel', parent)

  widget.title:setOn(params.on)
  widget.title.onClick = function()
    params.on = not params.on
    widget.title:setOn(params.on)
    if callback then
      callback(widget, params)
    end
  end

  widget.item:setItem(Item.create(params.item, params.subType))
  widget.item.onItemChange = function()
    params.item = widget.item:getItemId()
    params.subType = widget.item:getItemSubType()
    if callback then
      callback(widget, params)
    end
  end

  local update = function(dontSignal)
    widget.title:setText("" .. params.min .. "% <= " .. params.title .. " <= " .. params.max .. "%")
    if callback and not dontSignal then
      callback(widget, params)
    end
  end

  widget.scroll1:setValue(params.min)
  widget.scroll2:setValue(params.max)

  widget.scroll1.onValueChange = function(scroll, value)
    params.min = value
    update()
  end
  widget.scroll2.onValueChange = function(scroll, value)
    params.max = value
    update()
  end
  update(true)
end

UI.Label = function(text, parent)
  local label = UI.createWidget('BotLabel', parent)
  label:setText(text)
  return label
end

UI.Separator = function(parent)
  local separator = UI.createWidget('BotSeparator', parent)
  return separator
end

UI.TextEdit = function(text, callback, parent)
  local widget = UI.createWidget('BotTextEdit', parent)
  widget.onTextChange = callback
  widget:setText(text)
  return widget
end

UI.TwoItemsAndSlotPanel = function(params, callback, parent)
  --[[ params:
    on - bool,
    title - string,
    item1 - number,
    item2 - number,
    slot - number,
  ]]
  params.title = params.title or "title"
  params.item1 = params.item1 or 0
  params.item2 = params.item2 or 0
  params.slot = params.slot or 1

  local widget = UI.createWidget("TwoItemsAndSlotPanel", parent)

  widget.title:setText(params.title)
  widget.title:setOn(params.on)
  widget.title.onClick = function()
    params.on = not params.on
    widget.title:setOn(params.on)
    if callback then
      callback(widget, params)
    end
  end

  widget.slot:setCurrentIndex(params.slot)
  widget.slot.onOptionChange = function()
    params.slot = widget.slot.currentIndex
    if callback then
      callback(widget, params)
    end
  end

  widget.item1:setItemId(params.item1)
  widget.item1.onItemChange = function()
    params.item1 = widget.item1:getItemId()
    if callback then
      callback(widget, params)
    end
  end

  widget.item2:setItemId(params.item2)
  widget.item2.onItemChange = function()
    params.item2 = widget.item2:getItemId()
    if callback then
      callback(widget, params)
    end
  end

  return widget
end

UI.DualLabel = function(left, right, params, parent)
  --[[ params:
    height - int,
    maxWidth - number
  ]]

  left = left or ""
  right = right or ""
  params = params or {}
  if not type(params) == "table" then
    parent = params
    params = {}
  end
  params.height = params.height or 20
  params.maxWidth = params.maxWidth or 88

  local widget = UI.createWidget('DualLabelPanel', parent)

  widget.left:setText(left)
  widget.right:setText(right)
  widget:setHeight(params.height)
  if widget.left:getWidth() > params.maxWidth then
    widget.left:setWidth(params.maxWidth)
  end
  return widget
end

UI.LabelAndTextEdit = function(params, callback, parent)
  --[[ params:
    left - str,
    right - str,
    height - int,
    maxWidth - int,
  ]]

  params = params or {}
  params.left = params.left or ""
  params.right = params.right or ""
  params.height = params.height or 20
  params.maxWidth = params.maxWidth or 88

  local widget = UI.createWidget('LabelAndTextEditPanel', parent)

  widget.left:setText(params.left)
  widget.right:setText(params.right)
  widget:setHeight(params.height)
  if widget.left:getWidth() > params.maxWidth then
    widget.left:setWidth(params.maxWidth)
  end

  widget.right.onTextChange = function(widget, text)
    params.right = text
    if callback then
      callback(widget, params)
    end
  end

  --[[example:

      storage.testParams = storage.testParams or {left = "hotkey", right = "F5"}
      UI.LabelAndTextEdit(storage.testParams, function(widget, newParams)
          storage.testParams = newParams
      end)

  ]]
  return widget
end


UI.SwitchAndButton = function(params, callbackSwitch, callbackButton, callback, parent)
  --[[ params:
    on - bool,
    left - str,
    right - str,
    height - int,
    maxWidth - int,
  ]]

  params = params or {}
  params.on = params.on or false
  params.left = params.left or ""
  params.right = params.right or ""
  params.height = params.height or 20
  params.maxWidth = params.maxWidth or 88

  local widget = UI.createWidget('SwitchAndButtonPanel', parent)

  widget.left:setOn(params.on)
  widget.left:setText(params.left)
  widget.right:setText(params.right)
  widget:setHeight(params.height)
  if widget.right:getWidth() > params.maxWidth then
    widget.right:setWidth(params.maxWidth)
  end

  widget.left.onClick = function()
    params.on = not params.on
    widget.left:setOn(params.on)
    if callback then
      callback(widget, params)
    end
    if callbackSwitch then
      callbackSwitch()
    else
      warn("callback not set!")
    end
  end

  widget.right.onClick = function()
    if callbackButton then
      callbackButton()
    else
      warn("callback not set!")
    end
  end

  --[[ params:
    if type(storage.test1) ~= "table" then
        storage.test1 = storage.test1 or {on = false, left = "new script", right = "config"}
    end

    UI.SwitchAndButton(storage.test1, test, test, function(widget, newParams)
        storage.test1 = newParams
    end)
  ]]
  return widget
end
