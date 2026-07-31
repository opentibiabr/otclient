local settings = {}
ChangedProfile = false

function init()
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })

end

function terminate()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
end

-- loads settings on character login
function online()
  ChangedProfile = false

  -- startup arguments has higher priority than settings
  local index = getProfileFromStartupArgument()
  if index then
    setProfileOption(index)
  end

  load()

  if not index then
    setProfileOption(getProfileFromSettings() or 1)
  end

  -- create main settings dir
  if not g_resources.directoryExists("/settings/") then
    g_resources.makeDir("/settings/")
  end

  -- create profiles dirs
  for i=1,10 do
    local path = "/settings/profile_"..i

    if not g_resources.directoryExists(path) then
      g_resources.makeDir(path)
    end
  end
end

function setProfileOption(index)
  local currentProfile = g_settings.getNumber('profile')
  currentProfile = tostring(currentProfile)
  index = tostring(index)

  if currentProfile ~= index then
    ChangedProfile = true
    return modules.client_options.setOption('profile', index)
  end

end

-- load profile number from settings
function getProfileFromSettings()
  -- settings should save per character, return if not online
  if not g_game.isOnline() then return end

  local index = g_game.getCharacterName()
  local savedData = settings[index]

  return savedData
end

-- option to launch client with hardcoded profile
function getProfileFromStartupArgument()
    local startupOptions = string.split(g_app.getStartupOptions(), " ")
    if #startupOptions < 2 then
        return false
    end

    for index, option in ipairs(startupOptions) do
        if option == "--profile" then
            local profileIndex = startupOptions[index + 1]
            if profileIndex == nil then
              return g_logger.info("Startup arguments incomplete: missing profile index.")
            end

            g_logger.info("Startup options: Forced profile: "..profileIndex)
            -- set value in options
            return profileIndex
        end
    end

    return false
end

-- returns string path ie. "/settings/1/actionbar.json"
function getSettingsFilePath(fileNameWithFormat)
  local currentProfile = g_settings.getNumber('profile')

  return "/settings/profile_"..currentProfile.."/"..fileNameWithFormat
end

function offline()
  onProfileChange(true)
end

-- profile change callback (called in options), saves settings & reloads given module configs
function onProfileChange(offline)
  if not offline then
    if not g_game.isOnline() then return end
  -- had to apply some delay
    scheduleEvent(collectiveReload, 100)
  end

  local currentProfile = g_settings.getNumber('profile')
  local index = g_game.getCharacterName()

  if index then
    settings[index] = currentProfile
    save()
  end
end

-- collection of refresh functions from different modules
function collectiveReload()
  modules.game_topbar.refresh(true)
  modules.game_actionbar.refresh(true)
  modules.game_bot.refresh()
end

-- json handlers
function load()
  local file = "/settings/profiles.json"
  if g_resources.fileExists(file) then
    local status, result = pcall(function()
        return json.decode(g_resources.readFileContents(file))
    end)
    if not status then
        return g_logger.warning(
                   "Error while reading profiles file. To fix this problem you can delete storage.json. Details: " ..
                       result)
    end
    settings = result
  end
end

function save()
  local file = "/settings/profiles.json"
  local status, result = pcall(function() return json.encode(settings, 2) end)
  if not status then
      return g_logger.warning(
                 "Error while saving profile settings. Data won't be saved. Details: " ..
                     result)
  end
  if result:len() > 100 * 1024 * 1024 then
      return g_logger.warning(
                 "Something went wrong, file is above 100MB, won't be saved")
  end
  g_resources.writeFileContents(file, result)
end
