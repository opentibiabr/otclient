SpriteEditorSpritePicker = {}

local SpritePicker = {}

local WIDGET_IDS = {
   replace = {
      search = 'spriteSearchEdit',
      count = 'spritePickerCountLabel',
      list = 'spritePickerList',
      content = 'spritePickerContent',
      selection = 'selectedReplacementSpriteLabel',
   },
   create = {
      search = 'newAppearanceSpriteSearchEdit',
      count = 'newAppearanceSpritePickerCountLabel',
      list = 'newAppearanceSpritePickerList',
      content = 'newAppearanceSpritePickerContent',
      selection = 'newAppearanceSelectedSpriteLabel',
   },
}

local function get_size_tier(width, height)
   local size = math.max(width, height)
   local tier = 32
   while tier < size do
      tier = tier * 2
   end
   return tier
end

function SpritePicker:get_widget(name)
   return self.callbacks.get_widget(name)
end

function SpritePicker:get_sprite_id_at(index)
   if self.filtered_ids then
      return self.filtered_ids[index]
   end

   local first = 1
   local last = #self.ranges
   while first <= last do
      local middle = math.floor((first + last) / 2)
      if index <= self.ranges[middle][3] then
         last = middle - 1
      else
         first = middle + 1
      end
   end
   local range = self.ranges[first]
   if not range then
      return nil
   end
   local previous_count = first > 1 and self.ranges[first - 1][3] or 0
   return range[1] + index - previous_count - 1
end

function SpritePicker:apply_filter()
   local list = self:get_widget('list')
   if not list then
      return
   end

   local query = self:get_widget('search'):getText():lower():match('^%s*(.-)%s*$')
   if query ~= self.query then
      self.callbacks.clear_selection()
      self.query = query
   end
   self.filtered_ids = nil
   if query ~= '' then
      self.filtered_ids = {}
      for _, range in ipairs(self.ranges) do
         local first_id = math.max(1, range[1])
         for sprite_id = first_id, range[2] do
            if tostring(sprite_id):find(query, 1, true) then
               table.insert(self.filtered_ids, sprite_id)
            end
         end
      end
      self.count = #self.filtered_ids
   else
      self.count = #self.ranges > 0 and self.ranges[#self.ranges][3] or 0
   end

   list:setVirtualOffset({ x = 0, y = 0 })
   self:render_rows(0)
   list:updateScrollBars()
   if self.callbacks.on_filter_change then
      self.callbacks.on_filter_change()
   end
end

function SpritePicker:refresh()
   if not self.callbacks.get_window() or not self.callbacks.get_active_version() then
      self.ranges = {}
      self.filtered_ids = nil
      self.count = 0
      return
   end

   local ok, encoded = pcall(g_spriteAppearances.getSpriteRanges)
   local decoded, ranges = false, nil
   if ok then
      decoded, ranges = pcall(json.decode, encoded)
   end
   if not decoded or type(ranges) ~= 'table' then
      self.ranges = {}
      self.filtered_ids = nil
      self.count = 0
      self.callbacks.set_status(tr('The sprite list could not be loaded.'))
      return
   end

   local valid_ranges = {}
   for _, range in ipairs(ranges) do
      local first_id = tonumber(range[1])
      local last_id = tonumber(range[2])
      if first_id and last_id and first_id % 1 == 0 and last_id % 1 == 0 and last_id >= first_id then
         table.insert(valid_ranges, { math.max(1, first_id), last_id })
      end
   end
   table.sort(valid_ranges, function(a, b)
      return a[1] < b[1]
   end)

   self.ranges = {}
   for _, range in ipairs(valid_ranges) do
      local previous = self.ranges[#self.ranges]
      if previous and range[1] <= previous[2] + 1 then
         previous[2] = math.max(previous[2], range[2])
      else
         table.insert(self.ranges, { range[1], range[2] })
      end
   end

   local cumulative_count = 0
   for _, range in ipairs(self.ranges) do
      cumulative_count = cumulative_count + math.max(0, range[2] - range[1] + 1)
      range[3] = cumulative_count
   end
   for _, cells in pairs(self.cells) do
      for _, cell in ipairs(cells) do
         cell.spriteId = nil
         cell.thumbnailSpriteId = nil
      end
   end
   self:apply_filter()
end

function SpritePicker:select(sprite_id)
   if not self.callbacks.get_window() or not sprite_id then
      return
   end
   self.callbacks.select_sprite(sprite_id)
end

function SpritePicker:render_rows(scroll_y)
   local list = self:get_widget('list')
   if not list then
      return
   end

   local content = self:get_widget('content')
   local cell_width = 70
   local cell_height = 60
   local column_gap = 3
   local column_count = math.max(1, math.floor((list:getWidth() + column_gap) / (cell_width + column_gap)))
   local cells = self.cells[self.callbacks.get_section()]
   local total_rows = math.ceil(self.count / column_count)
   content:setHeight(math.max(1, total_rows * cell_height))

   local first_row = math.floor(math.max(0, scroll_y or 0) / cell_height)
   local viewport_height = math.max(list:getHeight(), cell_height)
   local pool_size = (math.ceil(viewport_height / cell_height) + 2) * column_count
   while #cells < pool_size do
      table.insert(cells, g_ui.createWidget('SpritePickerCell', content))
   end

   local updated_thumbnails = false
   local section = self.callbacks.get_section()
   for slot, cell in ipairs(cells) do
      local index = first_row * column_count + slot
      local sprite_id = index <= self.count and self:get_sprite_id_at(index) or nil
      cell:setVisible(sprite_id ~= nil)
      if sprite_id then
         cell.isSpritePickerCell = true
         cell:setDraggable(section == 'replace' and self.callbacks.get_active_version() ~= nil and
            not g_game.isOnline() and self.callbacks.get_selected_frame_sprite_id() ~= nil)
         cell:setMarginTop(math.floor((index - 1) / column_count) * cell_height)
         cell:setMarginLeft(((index - 1) % column_count) * (cell_width + column_gap))
         cell:recursiveGetChildById('spritePickerId'):setText(tostring(sprite_id))
         cell:setOn(sprite_id == self.callbacks.get_selected_id())
         cell.spriteId = sprite_id
         if cell.thumbnailSpriteId ~= sprite_id then
            local thumbnail = cell:recursiveGetChildById('thumbnail')
            local size_badge = cell:recursiveGetChildById('spriteSizeBadge')
            if thumbnail:setThumbnailSpriteId(sprite_id) then
               cell.thumbnailSpriteId = sprite_id
               updated_thumbnails = true
               local width = thumbnail:getSpriteWidth()
               local height = thumbnail:getSpriteHeight()
               local largest_dimension = math.max(width, height)
               thumbnail:setThumbnailSizeBadge(largest_dimension)
               size_badge:setText(tostring(get_size_tier(width, height)))
               size_badge:setColor(largest_dimension <= 32 and '#ffffff' or '#171717')
               cell:setTooltip(tr('Sprite dimensions: %d x %d', width, height))
               size_badge:setVisible(true)
            else
               cell.thumbnailSpriteId = nil
               cell:setTooltip('')
               size_badge:setVisible(false)
            end
         end
         cell.onClick = function()
            self:select(sprite_id)
         end
         cell.onDragEnter = function(widget)
            if not widget.spriteId or not self.callbacks.get_active_version() or g_game.isOnline() or
                  not self.callbacks.get_selected_frame_sprite_id() then
               return false
            end
            self:select(widget.spriteId)
            return true
         end
         cell.onDragMove = function(_, mouse_position)
            local canvas = self.callbacks.get_canvas()
            local over_canvas = canvas and canvas:isVisible() and canvas:containsPoint(mouse_position)
            if canvas then
               canvas:setBorderWidth(over_canvas and 2 or 0)
               canvas:setBorderColor(over_canvas and '#8f69d3' or 'alpha')
            end
            return true
         end
         cell.onDragLeave = function()
            local canvas = self.callbacks.get_canvas()
            if canvas then
               canvas:setBorderWidth(0)
               canvas:setBorderColor('alpha')
            end
            return true
         end
      else
         cell.spriteId = nil
         cell.thumbnailSpriteId = nil
         cell.isSpritePickerCell = false
         cell:setDraggable(false)
         cell:setTooltip('')
         cell:recursiveGetChildById('spriteSizeBadge'):setVisible(false)
      end
   end

   self:get_widget('count'):setText(self.count == 1 and tr('%d sprite', self.count) or
      tr('%d sprites', self.count))
   local selection_label = self:get_widget('selection')
   local selected_sprite = self.callbacks.get_selected_id()
   if section == 'create' then
      selection_label:setText(selected_sprite and tr('Selected sprite ID %d.', selected_sprite) or
         tr('Choose a sprite from the list.'))
   else
      selection_label:setText(selected_sprite and tr('Drag sprite %d onto the preview.', selected_sprite) or
         tr('Select or drag a sprite onto the preview.'))
   end

   if updated_thumbnails and g_spriteAppearances.releaseDecodedSpriteSheets then
      g_spriteAppearances.releaseDecodedSpriteSheets()
   end
end

function SpritePicker:attach_window()
   local function schedule_filter()
      if self.search_event then
         removeEvent(self.search_event)
      end
      self.search_event = scheduleEvent(function()
         self.search_event = nil
         self:apply_filter()
      end, 120)
   end

   for _, name in ipairs({ 'replace_search', 'create_search' }) do
      local widget = self.callbacks.get_widget(name)
      if widget then
         widget.onTextChange = schedule_filter
      end
   end
   for _, name in ipairs({ 'replace_list', 'create_list' }) do
      local widget = self.callbacks.get_widget(name)
      if widget then
         widget.onScrollChange = function(_, offset)
            self:render_rows(offset.y)
            if self.callbacks.on_scroll_change then
               self.callbacks.on_scroll_change(offset)
            end
         end
      end
   end
end

function SpritePicker:destroy()
   if self.search_event then
      removeEvent(self.search_event)
      self.search_event = nil
   end
   self.ranges = {}
   self.filtered_ids = nil
   self.count = 0
   self.cells = { replace = {}, create = {} }
   self.query = ''
end

function SpriteEditorSpritePicker.new(callbacks)
   return setmetatable({
      callbacks = callbacks,
      cells = { replace = {}, create = {} },
      count = 0,
      filtered_ids = nil,
      query = '',
      ranges = {},
      search_event = nil,
   }, { __index = SpritePicker })
end
