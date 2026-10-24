SpriteEditorAnimationPlayer = {}

local AnimationPlayer = {}

function AnimationPlayer:is_playing()
   return self.playing
end

function AnimationPlayer:stop()
   if self.event then
      removeEvent(self.event)
      self.event = nil
   end
   self.playing = false
   self.direction = 1
   self.cycles = 0
   self.appearance_id = nil
   self.group_index = nil

   local button = self.callbacks.get_play_button()
   if button then
      button:setText(tr('Play'))
      button:setTooltip(tr('Play the animation preview from the selected frame.'))
      button:setOn(false)
   end
end

function AnimationPlayer:schedule()
   local callbacks = self.callbacks
   local group = callbacks.get_group()
   if not self.playing or not callbacks.is_window_visible() then
      self:stop()
      return
   end
   if not group or group.index ~= self.group_index or callbacks.get_appearance_id() ~= self.appearance_id then
      self:stop()
      return
   end

   local phase_count = math.max(1, group.phaseCount or 1)
   local changes = callbacks.get_group_changes(group.index)
   local loop_type = changes.loopType ~= nil and changes.loopType or group.animation.loopType
   local loop_count = changes.loopCount ~= nil and changes.loopCount or group.animation.loopCount
   self.event = scheduleEvent(function()
      self.event = nil
      if not self.playing then
         return
      end

      local phase = callbacks.get_phase()
      local next_phase = phase + self.direction
      if loop_type == -1 then
         if next_phase < 0 or next_phase >= phase_count then
            self.direction = -self.direction
            next_phase = phase + self.direction
         end
      elseif next_phase >= phase_count then
         self.cycles = self.cycles + 1
         if loop_type == 1 and loop_count > 0 and self.cycles >= loop_count then
            self:stop()
            return
         end
         next_phase = 0
      end

      if not callbacks.select_phase(next_phase) then
         self:stop()
         return
      end
      self:schedule()
   end, callbacks.get_phase_duration(group, callbacks.get_phase()))
end

function AnimationPlayer:toggle()
   if self.playing then
      self:stop()
      return
   end

   local group = self.callbacks.get_group()
   if not group or not group.animation or not group.animation.enabled or (group.phaseCount or 1) < 2 then
      return
   end
   if not self.callbacks.collect_changes() then
      return
   end

   self.playing = true
   self.direction = 1
   self.cycles = 0
   self.appearance_id = self.callbacks.get_appearance_id()
   self.group_index = group.index
   local button = self.callbacks.get_play_button()
   if button then
      button:setText(tr('Pause'))
      button:setTooltip(tr('Pause the animation preview.'))
      button:setOn(true)
   end
   self:schedule()
end

function SpriteEditorAnimationPlayer.new(callbacks)
   return setmetatable({ callbacks = callbacks, playing = false, direction = 1, cycles = 0 }, {
      __index = AnimationPlayer,
   })
end
