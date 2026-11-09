SpriteEditorAppearanceCatalog = {}

local AppearanceCatalog = {}

local ROW_HEIGHT = 52
local MAX_THUMBNAIL_FRAMES = 8

local function get_thumbnail_animation_sprites(thing)
   local sprites = thing:getThumbnailAnimationSprites()
   if #sprites <= MAX_THUMBNAIL_FRAMES then
      return sprites
   end

   local sampled = {}
   for index = 0, MAX_THUMBNAIL_FRAMES - 1 do
      local source_index = math.floor(index * (#sprites - 1) / (MAX_THUMBNAIL_FRAMES - 1)) + 1
      table.insert(sampled, sprites[source_index])
   end
   return sampled
end

local function get_appearance_tooltip(entry)
   local lines = {}
   if entry.name then
      table.insert(lines, entry.name)
   end

   if entry.linkedSpriteCount == 1 then
      table.insert(lines, tr('Sprite ID: %d', entry.minSpriteId))
   elseif entry.linkedSpriteCount > 1 then
      table.insert(lines, tr('Sprite ID span: %d-%d (%d linked)',
         entry.minSpriteId, entry.maxSpriteId, entry.linkedSpriteCount))
   else
      table.insert(lines, tr('No linked sprites'))
   end
   return table.concat(lines, '\n')
end

function AppearanceCatalog:get_widget(id)
   return self.callbacks.get_widget(id)
end

function AppearanceCatalog:get_category_count(category)
   if self.category_counts[category.data] ~= nil then
      return self.category_counts[category.data]
   end

   local count = 0
   for _, thing in pairs(g_things.getThingTypes(category.data)) do
      if thing and thing:getId() > 0 then
         count = count + 1
      end
   end
   self.category_counts[category.data] = count
   return count
end

function AppearanceCatalog:update_category_options()
   local combo_box = self:get_widget('appearanceCategory')
   if not combo_box then
      return
   end
   local on_option_change = combo_box.onOptionChange
   combo_box.onOptionChange = nil
   combo_box:clearOptions()
   for _, category in ipairs(self.categories) do
      local label = tr(category.name)
      if self.callbacks.get_active_version() then
         label = string.format('%s (%d)', label, self:get_category_count(category))
      end
      combo_box:addOption(label, category.data)
   end
   combo_box.onOptionChange = on_option_change
   combo_box:setCurrentOptionByData(self.callbacks.get_selected_category(), true)
end

function AppearanceCatalog:get_thing_entries(category)
   local entries = {}
   for _, thing in pairs(g_things.getThingTypes(category)) do
      local id = thing:getId()
      if id and id > 0 then
         local sprites = thing:getSprites()
         local name = thing:getName()
         local seen_sprite_ids = {}
         local sprite_id
         local min_sprite_id
         local max_sprite_id
         local linked_sprite_count = 0
         for _, linked_sprite_id in ipairs(sprites or {}) do
            if linked_sprite_id > 0 then
               sprite_id = sprite_id or linked_sprite_id
               if not seen_sprite_ids[linked_sprite_id] then
                  seen_sprite_ids[linked_sprite_id] = true
                  min_sprite_id = not min_sprite_id and linked_sprite_id or math.min(min_sprite_id, linked_sprite_id)
                  max_sprite_id = not max_sprite_id and linked_sprite_id or math.max(max_sprite_id, linked_sprite_id)
                  linked_sprite_count = linked_sprite_count + 1
               end
            end
         end
         table.insert(entries, {
            id = id,
            category = category,
            name = name ~= '' and name or nil,
            spriteId = sprite_id,
            minSpriteId = min_sprite_id,
            maxSpriteId = max_sprite_id,
            linkedSpriteCount = linked_sprite_count,
         })
      end
   end
   table.sort(entries, function(a, b)
      return a.id < b.id
   end)
   return entries
end

function AppearanceCatalog:render_rows(scroll_y)
   if not self.callbacks.get_window() or not self.callbacks.get_active_version() then
      return
   end
   local list = self:get_widget('appearanceList')
   local content = self:get_widget('appearanceListContent')
   content:setHeight(math.max(1, #self.filtered_entries * ROW_HEIGHT))
   local first_index = math.floor(math.max(0, scroll_y or 0) / ROW_HEIGHT) + 1
   local viewport_height = math.max(list:getHeight(), 1)
   local pool_size = math.ceil(math.max(viewport_height, 400) / ROW_HEIGHT) + 2
   local thumbnails_updated = false
   while #self.rows < pool_size do
      table.insert(self.rows, g_ui.createWidget('AppearanceResultRow', content))
   end

   local last_visible_index = math.floor(((scroll_y or 0) + viewport_height) / ROW_HEIGHT) + 1
   for slot, row in ipairs(self.rows) do
      local index = first_index + slot - 1
      local entry = self.filtered_entries[index]
      row:setVisible(entry ~= nil)
      if entry then
         row:setMarginTop((index - 1) * ROW_HEIGHT)
         row:setText('')
         row:recursiveGetChildById('appearanceId'):setText(tostring(entry.id))
         row:setTooltip(get_appearance_tooltip(entry))
         local thumbnail = row:recursiveGetChildById('thumbnail')
         thumbnail:setVisible(entry.spriteId ~= nil)
         if entry.spriteId and index <= last_visible_index and row.thumbnailEntry ~= entry then
            local loaded
            local thing = g_things.getThingType(entry.id, entry.category)
            local animation_sprites = get_thumbnail_animation_sprites(thing)
            if #animation_sprites > 1 then
               loaded = thumbnail:setSpriteAnimationIds(animation_sprites)
            else
               loaded = thumbnail:setThumbnailSpriteId(entry.spriteId)
            end
            if not loaded and #animation_sprites > 1 then
               loaded = thumbnail:setThumbnailSpriteId(entry.spriteId)
            end
            if loaded then
               thumbnails_updated = true
               row.thumbnailEntry = entry
            else
               row.thumbnailEntry = nil
            end
         end
         local selected = entry.id == self.callbacks.get_selected_appearance_id() and
            entry.category == self.callbacks.get_selected_category()
         row:setOn(selected)
         row.onClick = function()
            self.callbacks.select_appearance(entry.category, entry.id)
         end
      end
   end

   if thumbnails_updated and g_spriteAppearances.releaseDecodedSpriteSheets then
      g_spriteAppearances.releaseDecodedSpriteSheets()
   end
end

function AppearanceCatalog:apply_filter()
   local search = self:get_widget('appearanceSearch')
   if not search then
      return
   end
   local query = search:getText():lower():match('^%s*(.-)%s*$')
   local exact_id = query:match('^%d+$') and tonumber(query) or nil
   self.filtered_entries = {}
   for _, entry in ipairs(self.entries) do
      local name_text = entry.name and entry.name:lower() or ''
      if query == '' or (exact_id and entry.id == exact_id) or
            (not exact_id and name_text:find(query, 1, true)) then
         table.insert(self.filtered_entries, entry)
      end
   end
   local list = self:get_widget('appearanceList')
   list:setVirtualOffset({ x = 0, y = 0 })
   self:render_rows(0)
   list:updateScrollBars()
   if self.callbacks.on_filter_change then
      self.callbacks.on_filter_change()
   end
end

function AppearanceCatalog:refresh(category)
   if not self.callbacks.get_window() or not self.callbacks.get_active_version() then
      self.entries = {}
      self.filtered_entries = {}
      if self.callbacks.on_filter_change then
         self.callbacks.on_filter_change()
      end
      return
   end
   self.entries = self:get_thing_entries(category)
   self.category_counts[category] = #self.entries
   self:update_category_options()
   self:apply_filter()
end

function AppearanceCatalog:get_filtered_entry(index)
   return self.filtered_entries[index]
end

function AppearanceCatalog:get_entry_count()
   return #self.entries
end

function AppearanceCatalog:get_filtered_ids(limit)
   if #self.filtered_entries == 0 or #self.filtered_entries > limit then
      return nil, #self.filtered_entries
   end
   local ids = {}
   for _, entry in ipairs(self.filtered_entries) do
      table.insert(ids, entry.id)
   end
   return ids, #self.filtered_entries
end

function AppearanceCatalog:get_bottom_offset()
   return math.max(0, (#self.filtered_entries - 1) * ROW_HEIGHT)
end

function AppearanceCatalog:attach_window()
   self:get_widget('appearanceSearch').onTextChange = function()
      self:apply_filter()
   end
   self:get_widget('appearanceList').onScrollChange = function(_, offset)
      self:render_rows(offset.y)
      if self.callbacks.on_scroll_change then
         self.callbacks.on_scroll_change(offset)
      end
   end
end

function AppearanceCatalog:destroy()
   self.entries = {}
   self.filtered_entries = {}
   self.category_counts = {}
   self.rows = {}
end

function AppearanceCatalog:clear_category_counts()
   self.category_counts = {}
end

function SpriteEditorAppearanceCatalog.new(categories, callbacks)
   return setmetatable({
      categories = categories,
      callbacks = callbacks,
      entries = {},
      filtered_entries = {},
      category_counts = {},
      rows = {},
   }, { __index = AppearanceCatalog })
end
