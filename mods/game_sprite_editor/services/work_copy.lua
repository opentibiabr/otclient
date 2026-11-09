SpriteEditorWorkCopyService = {}

local WorkCopyService = {}

local function load_asset_data(asset_path)
   g_things.invalidateTextureCache()
   if not g_things.loadAppearances(asset_path) then
      return false
   end
   return g_things.loadStaticData(asset_path)
end

local function restore_assets_after_failed_load(self, version, asset_path, root, mounted_by_this_load)
   local unmount_error
   if mounted_by_this_load then
      local unmounted
      unmounted, unmount_error = self:unmount(root)
      if not unmounted then
         unmount_error = unmount_error or tr('Could not unmount the failed work copy.')
      end
   end

   local restored, loaded_or_error = pcall(function()
      if g_game.getClientVersion() ~= version then
         g_game.setClientVersion(version)
      end
      return load_asset_data(asset_path)
   end)
   if not restored then
      return false, loaded_or_error
   end
   if not loaded_or_error then
      return false, tr('The previous client assets could not be reloaded.')
   end
   if unmount_error then
      return false, unmount_error
   end
   return true
end

function WorkCopyService:exists(version)
   return pcall(g_spriteAppearances.workCopyExists, version)
end

function WorkCopyService:load(version)
   local ok, root = pcall(g_spriteAppearances.createWorkCopy, version)
   if not ok then
      return false, root
   end

   local previous_version = g_game.getClientVersion()
   local previous_asset_path = resolvepath(string.format('/data/things/%d/', previous_version))
   local mounted_by_this_load = false
   if not self.mounted_roots[root] then
      if not g_resources.addSearchPath(root, true) then
         return false, tr('Could not mount the work copy.')
      end
      self.mounted_roots[root] = true
      mounted_by_this_load = true
   end

   local loaded, asset_path_or_error = pcall(function()
      if g_game.getClientVersion() ~= version then
         g_game.setClientVersion(version)
      end
      local asset_path = resolvepath(string.format('/data/things/%d/', version))
      if not load_asset_data(asset_path) then
         return nil
      end
      return asset_path
   end)
   if not loaded or not asset_path_or_error then
      local recovered, recovery_error = restore_assets_after_failed_load(self, previous_version,
         previous_asset_path, root, mounted_by_this_load)
      if not recovered then
         g_logger.error('[game_sprite_editor] Unable to restore installed assets after work copy load failed: ' ..
            tostring(recovery_error))
      end
      if not loaded then
         return false, asset_path_or_error
      end
      return false, tr('Could not load the selected work copy. Check the client log for details.')
   end
   return true, root, asset_path_or_error
end

function WorkCopyService:reload(asset_path)
   if not asset_path then
      return false
   end
   return load_asset_data(asset_path)
end

function WorkCopyService:unmount(root)
   if not root or not self.mounted_roots[root] then
      return true, false
   end
   if not g_resources.removeSearchPath(root) then
      return false, false
   end
   self.mounted_roots[root] = nil
   return true, true
end

function WorkCopyService:restore(root, was_mounted)
   if not was_mounted then
      return true
   end
   if not g_resources.addSearchPath(root, true) then
      return false
   end
   self.mounted_roots[root] = true
   return true
end

function WorkCopyService:release(version, root, work_asset_path)
   if not version then
      return true
   end

   local unmounted, was_mounted = self:unmount(root)
   if not unmounted then
      return false, tr('Could not unmount the sprite editor working copy.')
   end

   local installed_asset_path = resolvepath(string.format('/data/things/%d/', version))
   local reloaded, loaded = pcall(load_asset_data, installed_asset_path)
   if not reloaded or not loaded then
      local remounted = not root or self.mounted_roots[root] or g_resources.addSearchPath(root, true)
      if remounted and root then
         self.mounted_roots[root] = true
      end
      if remounted and work_asset_path then
         pcall(load_asset_data, work_asset_path)
      end
      if not reloaded then
         return false, loaded
      end
      return false, tr('The installed client assets could not be reloaded.')
   end
   return true
end

function WorkCopyService:reset(version, root)
   local unmounted, was_mounted = self:unmount(root)
   if not unmounted then
      return false, tr('Could not unmount the working copy before reloading assets.'), false
   end

   local reset_ok, result = pcall(g_spriteAppearances.resetWorkCopy, version)
   if not reset_ok then
      if not self:restore(root, was_mounted) then
         return false, result, true
      end
      return false, result, false
   end
   return true
end

function WorkCopyService:install(version, root)
   local unmounted, was_mounted = self:unmount(root)
   if not unmounted then
      return {
         error = tr('Could not unmount the working copy before installing assets.'),
         unmount_failed = true,
      }
   end

   local installed, result = pcall(g_spriteAppearances.installWorkCopy, version)
   local remounted = self:restore(root, was_mounted)
   if not remounted then
      if installed then
         return {
            installed = true,
            backup_path = result,
            remount_failed = true,
         }
      end
      return {
         error = result,
         remount_failed = true,
      }
   end
   if not installed then
      return { error = result }
   end
   return { installed = true, backup_path = result }
end

function WorkCopyService:install_as_new_version(source_version, target_version, root)
   local unmounted, was_mounted = self:unmount(root)
   if not unmounted then
      return {
         error = tr('Could not unmount the working copy before installing the new version.'),
         unmount_failed = true,
      }
   end

   local installed, result = pcall(g_spriteAppearances.installWorkCopyAsNewVersion, source_version, target_version)
   local remounted = self:restore(root, was_mounted)
   if not remounted then
      if installed then
         return {
            installed = true,
            destination = result,
            remount_failed = true,
         }
      end
      return {
         error = result,
         remount_failed = true,
      }
   end
   if not installed then
      return { error = result }
   end
   return { installed = true, destination = result }
end

function SpriteEditorWorkCopyService.new()
   return setmetatable({ mounted_roots = {} }, { __index = WorkCopyService })
end
