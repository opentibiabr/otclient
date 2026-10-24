SpriteEditorAppearanceProperties = {}

local AppearanceProperties = {}

local EQUIPMENT_SLOT_OPTIONS = {
   { label = 'Not equippable', data = 0 },
   { label = 'Head', data = 1 },
   { label = 'Necklace', data = 2 },
   { label = 'Backpack', data = 3 },
   { label = 'Armor', data = 4 },
   { label = 'Right hand', data = 5 },
   { label = 'Left hand', data = 6 },
   { label = 'Legs', data = 7 },
   { label = 'Feet', data = 8 },
   { label = 'Ring', data = 9 },
   { label = 'Ammo', data = 10 },
}
local ENUM_NOT_SET = -2147483648

local function sorted_keys(values)
   local keys = {}
   for key in pairs(values) do
      table.insert(keys, key)
   end
   table.sort(keys)
   return keys
end

local function property_label(key)
   local label = key:gsub('cyclopediaitem', 'cyclopedia item'):gsub('%.', ' / '):gsub('_', ' ')
   label = label:gsub('(%a)([%w]*)', function(first, rest)
      return first:upper() .. rest:lower()
   end)
   return label:gsub('Id', 'ID')
end

local function set_property_label(widget, key)
   local label = property_label(key)
   widget:setText(label)
   widget:setTooltip(label)
end

local function sorted_values(values)
   local result = {}
   for _, value in ipairs(values or {}) do
      table.insert(result, tonumber(value))
   end
   table.sort(result)
   return result
end

local function same_values(left, right)
   left = sorted_values(left)
   right = sorted_values(right)
   if #left ~= #right then
      return false
   end
   for index, value in ipairs(left) do
      if value ~= right[index] then
         return false
      end
   end
   return true
end

function AppearanceProperties:get_widget(id)
   return self.callbacks.get_widget(id)
end

function AppearanceProperties:is_building()
   return self.callbacks.is_building()
end

function AppearanceProperties:update()
   self.callbacks.update()
end

function AppearanceProperties:build_equipment_slot_editor(values_list, data)
   local slot = data.values['clothes.slot'] or 0
   local row = g_ui.createWidget('AppearanceValueSelectRow', values_list)
   row:setWidth(285)
   row:recursiveGetChildById('propertyLabel'):setText(tr('Equipment slot'))
   local combo_box = row:recursiveGetChildById('propertySelection')
   for _, option in ipairs(EQUIPMENT_SLOT_OPTIONS) do
      combo_box:addOption(tr(option.label), option.data)
   end
   combo_box:setCurrentOptionByData(slot, true)
   combo_box.onOptionChange = function(_, _, value)
      if self:is_building() then
         return
      end
      if value == slot then
         self.callbacks.get_changes().values['clothes.slot'] = nil
      else
         self.callbacks.get_changes().values['clothes.slot'] = value
      end
      self:update()
   end
end

function AppearanceProperties:build_fields(data)
   local flags_list = self:get_widget('appearanceFlagsList')
   local values_list = self:get_widget('appearanceValuesList')
   flags_list:destroyChildren()
   values_list:destroyChildren()
   self.value_widgets = {}
   self.string_widgets = {}
   self.text_value_widgets = {}
   self.multi_value_widgets = {}
   self.enum_widgets = {}
   data.values = data.values or {}
   data.textValues = data.textValues or {}
   data.enumOptions = data.enumOptions or {}
   data.multiValues = data.multiValues or {}
   data.unsetValues = data.unsetValues or {}
   if self.callbacks.get_category() == 0 then
      data.values['clothes.slot'] = data.values['clothes.slot'] or 0
   end

   local name_edit = self:get_widget('appearanceName')
   local description_edit = self:get_widget('appearanceDescription')
   name_edit:setEnabled(true)
   description_edit:setEnabled(true)
   name_edit:setText(data.name or '')
   description_edit:setText(data.description or '')
   self.string_widgets.name = name_edit
   self.string_widgets.description = description_edit
   for _, key in ipairs({ 'name', 'description' }) do
      self.string_widgets[key].onTextChange = function(widget)
         if self:is_building() then
            return
         end
         local value = widget:getText()
         if value == (data[key] or '') then
            self.callbacks.get_changes().strings[key] = nil
         else
            self.callbacks.get_changes().strings[key] = value
         end
         self:update()
      end
   end

   for _, key in ipairs(sorted_keys(data.bools)) do
      local checkbox = g_ui.createWidget('AppearanceFlagCheckBox', flags_list)
      checkbox:setWidth(285)
      checkbox:setText(property_label(key))
      checkbox:setChecked(data.bools[key])
      checkbox.onCheckChange = function(widget)
         if self:is_building() then
            return
         end
         local checked = widget:isChecked()
         if checked == data.bools[key] then
            self.callbacks.get_changes().bools[key] = nil
         else
            self.callbacks.get_changes().bools[key] = checked
         end
         self:update()
      end
   end

   if self.callbacks.get_category() == 0 then
      self:build_equipment_slot_editor(values_list, data)
   end

   local scalar_value_keys = {}
   for key in pairs(data.values) do
      scalar_value_keys[key] = true
   end
   for key in pairs(data.enumOptions) do
      if data.multiValues[key] == nil then
         scalar_value_keys[key] = true
      end
   end
   for _, key in ipairs(sorted_keys(scalar_value_keys)) do
      if key ~= 'clothes.slot' or self.callbacks.get_category() ~= 0 then
         local options = data.enumOptions[key]
         if options then
            local row = g_ui.createWidget('AppearanceValueSelectRow', values_list)
            row:setWidth(285)
            set_property_label(row:recursiveGetChildById('propertyLabel'), key)
            local combo_box = row:recursiveGetChildById('propertySelection')
            combo_box:addOption(tr('Not set'), ENUM_NOT_SET)
            for _, option in ipairs(options) do
               combo_box:addOption(tr(option.label), option.value)
            end
            local original_value = data.values[key] == nil and ENUM_NOT_SET or data.values[key]
            combo_box:setCurrentOptionByData(original_value, true)
            self.enum_widgets[key] = combo_box
            combo_box.onOptionChange = function(_, _, value)
               if self:is_building() then
                  return
               end
               if value == original_value then
                  self.callbacks.get_changes().values[key] = nil
               else
                  self.callbacks.get_changes().values[key] = value
               end
               self:update()
            end
         else
            local row = g_ui.createWidget('AppearanceValueRow', values_list)
            row:setWidth(285)
            set_property_label(row:recursiveGetChildById('propertyLabel'), key)
            local edit = row:recursiveGetChildById('propertyValue')
            edit:setText(data.unsetValues[key] and '' or tostring(data.values[key] or 0))
            self.value_widgets[key] = edit
            edit.onTextChange = function(widget)
               if self:is_building() then
                  return
               end
               local text = widget:getText():trim()
               local value = tonumber(text)
               if text == '' and not data.unsetValues[key] then
                  self.callbacks.get_changes().values[key] = ENUM_NOT_SET
               elseif text == '' then
                  self.callbacks.get_changes().values[key] = nil
               elseif value and value >= 0 and value % 1 == 0 and
                     (value ~= data.values[key] or data.unsetValues[key]) then
                  self.callbacks.get_changes().values[key] = value
               else
                  self.callbacks.get_changes().values[key] = nil
               end
               self:update()
            end
         end
      end
   end

   for _, key in ipairs(sorted_keys(data.textValues)) do
      local row = g_ui.createWidget('AppearanceTextValueRow', values_list)
      row:setWidth(285)
      set_property_label(row:recursiveGetChildById('propertyLabel'), key)
      local edit = row:recursiveGetChildById('propertyValue')
      edit:setText(data.textValues[key])
      self.text_value_widgets[key] = edit
      edit.onTextChange = function(widget)
         if self:is_building() then
            return
         end
         local value = widget:getText()
         if value == data.textValues[key] then
            self.callbacks.get_changes().textValues[key] = nil
         else
            self.callbacks.get_changes().textValues[key] = value
         end
         self:update()
      end
   end

   for _, key in ipairs(sorted_keys(data.multiValues)) do
      local options = data.enumOptions[key] or {}
      if #options > 0 then
         local group = g_ui.createWidget('AppearanceMultiValueGroup', values_list)
         group:setWidth(285)
         group:setHeight(23 + #options * 19)
         set_property_label(group:recursiveGetChildById('propertyLabel'), key)
         local option_list = group:recursiveGetChildById('propertyOptions')
         local selected_values = {}
         for _, value in ipairs(data.multiValues[key]) do
            selected_values[tonumber(value)] = true
         end
         local checkboxes = {}
         for _, option in ipairs(options) do
            local checkbox = g_ui.createWidget('AppearanceMultiValueCheckBox', option_list)
            checkbox:setWidth(275)
            checkbox:setText(tr(option.label))
            checkbox:setChecked(selected_values[tonumber(option.value)] == true)
            checkboxes[tonumber(option.value)] = checkbox
            checkbox.onCheckChange = function()
               if self:is_building() then
                  return
               end
               local current_values = {}
               for value, option_checkbox in pairs(checkboxes) do
                  if option_checkbox:isChecked() then
                     table.insert(current_values, value)
                  end
               end
               table.sort(current_values)
               if same_values(current_values, data.multiValues[key]) then
                  self.callbacks.get_changes().multiValues[key] = nil
               else
                  self.callbacks.get_changes().multiValues[key] = current_values
               end
               self:update()
            end
         end
         self.multi_value_widgets[key] = { checkboxes = checkboxes, original = data.multiValues[key] }
      end
   end
end

function AppearanceProperties:clear_fields()
   self:get_widget('appearanceName'):setText('')
   self:get_widget('appearanceDescription'):setText('')
   self:get_widget('appearanceFlagsList'):destroyChildren()
   self:get_widget('appearanceValuesList'):destroyChildren()
   self.value_widgets = {}
   self.string_widgets = {}
   self.text_value_widgets = {}
   self.multi_value_widgets = {}
   self.enum_widgets = {}
end

function AppearanceProperties:set_enabled(enabled)
   self:get_widget('appearanceName'):setEnabled(enabled)
   self:get_widget('appearanceDescription'):setEnabled(enabled)
end

function AppearanceProperties:has_widget_changes()
   local original = self.callbacks.get_original()
   if not original then
      return false
   end

   for key, edit in pairs(self.string_widgets) do
      if edit:getText() ~= (original[key] or '') then
         return true
      end
   end
   for key, edit in pairs(self.value_widgets) do
      local text = edit:getText():trim()
      local value = tonumber(text)
      if text == '' then
         if not original.unsetValues[key] then
            return true
         end
      elseif value == nil or value ~= original.values[key] or original.unsetValues[key] then
         return true
      end
   end
   for key, combo_box in pairs(self.enum_widgets) do
      local option = combo_box:getCurrentOption()
      local original_value = original.values[key] == nil and ENUM_NOT_SET or original.values[key]
      if not option or option.data ~= original_value then
         return true
      end
   end
   for key, edit in pairs(self.text_value_widgets) do
      if edit:getText() ~= (original.textValues[key] or '') then
         return true
      end
   end
   for key, group in pairs(self.multi_value_widgets) do
      local selected_values = {}
      for value, checkbox in pairs(group.checkboxes) do
         if checkbox:isChecked() then
            table.insert(selected_values, value)
         end
      end
      if not same_values(selected_values, group.original) then
         return true
      end
   end
   return false
end

function AppearanceProperties:collect_changes()
   local original = self.callbacks.get_original()
   if not original then
      return false
   end
   local changes = self.callbacks.get_changes()
   for key, edit in pairs(self.value_widgets) do
      local text = edit:getText():trim()
      if text == '' then
         if original.unsetValues[key] then
            changes.values[key] = nil
         else
            changes.values[key] = ENUM_NOT_SET
         end
      else
         local value = tonumber(text)
         if not value or value < 0 or value % 1 ~= 0 then
            self.callbacks.set_status(tr('Appearance values must be non-negative integers.'))
            return false
         end
         if value == original.values[key] and not original.unsetValues[key] then
            changes.values[key] = nil
         else
            changes.values[key] = value
         end
      end
   end
   for key, combo_box in pairs(self.enum_widgets) do
      local option = combo_box:getCurrentOption()
      local value = option and option.data or nil
      local original_value = original.values[key] == nil and ENUM_NOT_SET or original.values[key]
      if value == original_value then
         changes.values[key] = nil
      else
         changes.values[key] = value
      end
   end
   for key, edit in pairs(self.text_value_widgets) do
      local value = edit:getText()
      if #value > 128 then
         self.callbacks.set_status(tr('Appearance text values must not exceed 128 characters.'))
         return false
      end
      if value == (original.textValues[key] or '') then
         changes.textValues[key] = nil
      else
         changes.textValues[key] = value
      end
   end
   for key, group in pairs(self.multi_value_widgets) do
      local values = {}
      for value, checkbox in pairs(group.checkboxes) do
         if checkbox:isChecked() then
            table.insert(values, value)
         end
      end
      table.sort(values)
      if same_values(values, group.original) then
         changes.multiValues[key] = nil
      else
         changes.multiValues[key] = values
      end
   end
   for key, edit in pairs(self.string_widgets) do
      local value = edit:getText()
      if value == (original[key] or '') then
         changes.strings[key] = nil
      else
         changes.strings[key] = value
      end
   end
   return true
end

function AppearanceProperties:destroy()
   self.value_widgets = {}
   self.string_widgets = {}
   self.text_value_widgets = {}
   self.multi_value_widgets = {}
   self.enum_widgets = {}
end

function SpriteEditorAppearanceProperties.new(callbacks)
   return setmetatable({
      callbacks = callbacks,
      value_widgets = {},
      string_widgets = {},
      text_value_widgets = {},
      multi_value_widgets = {},
      enum_widgets = {},
   }, { __index = AppearanceProperties })
end
