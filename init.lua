-- this is the first file executed when the application starts
-- we have to load the first modules form here

-- updater
Services = {
    --updater = "http://localhost/api/updater.php", --./updater
    --status = "http://localhost/login.php", --./client_entergame | ./client_topmenu
    --websites = "http://localhost/?subtopic=accountmanagement", --./client_entergame "Forgot password and/or email"
    --createAccount = "http://localhost/clientcreateaccount.php", --./client_entergame -- createAccount.lua
    --getCoinsUrl = "http://localhost/?subtopic=shop&step=terms", --./game_market
}

-- Toggle NPC trade implementation: set to `true` to use the legacy module
NPCTRADE_USE_LEGACY = false

--[[
Servers_init = {
    ["http://127.0.0.1/login.php"] = {
        ["port"] = 80,
        ["protocol"] = 1320,
        ["httpLogin"] = true
    },
    ["ip.net"] = {
        ["port"] = 7171,
        ["protocol"] = 860,
        ["httpLogin"] = false
    },
}
]]

g_app.setName("OTClient - Redemption");
g_app.setCompactName("otclient");
g_app.setOrganizationName("otcr");

g_app.hasUpdater = function()
    return (Services.updater and Services.updater ~= "" and g_modules.getModule("updater"))
end

-- setup logger
g_logger.setLogFile(g_resources.getWorkDir() .. g_app.getCompactName() .. '.log')
g_logger.info(os.date('== application started at %b %d %Y %X'))
g_logger.info("== operating system: " .. g_platform.getOSName())

-- print first terminal message
g_logger.info(g_app.getName() .. ' ' .. g_app.getVersion() .. ' rev ' .. g_app.getBuildRevision() .. ' (' ..
    g_app.getBuildCommit() .. ') built on ' .. g_app.getBuildDate() .. ' for arch ' ..
    g_app.getBuildArch())

-- setup lua debugger
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
    g_logger.debug("Started LUA debugger.")
else
    g_logger.debug("LUA debugger not started (not launched with VSCode local-lua).")
end

-- add data directory to the search path
if not g_resources.addSearchPath(g_resources.getWorkDir() .. 'data', true) then
    g_logger.fatal('Unable to add data directory to the search path.')
end

-- add modules directory to the search path
if not g_resources.addSearchPath(g_resources.getWorkDir() .. 'modules', true) then
    g_logger.fatal('Unable to add modules directory to the search path.')
end

g_html.addGlobalStyle('/data/styles/html.css')
g_html.addGlobalStyle('/data/styles/custom.css')

-- try to add mods path too
g_resources.addSearchPath(g_resources.getWorkDir() .. 'mods', true)

-- setup directory for saving configurations
g_resources.setupUserWriteDir(('%s/'):format(g_app.getCompactName()))

-- search all packages
g_resources.searchAndAddPackages('/', '.otpkg', true)

-- load settings
g_configs.loadSettings('/config.otml')

-- Ensure correct NPC trade module is enabled based on the toggle above.
local function setOtmodState(folder, enable)
    local filePath = g_resources.getWorkDir() .. 'modules/' .. folder .. '/npctrade.otmod'
    local f = io.open(filePath, 'r')
    if not f then
        g_logger.warning('npctrade otmod not found: ' .. filePath)
        return
    end
    local content = f:read('*a')
    f:close()

    if enable then
        content = content:gsub('enabled:%s*false', 'enabled: true')
        content = content:gsub('autoload:%s*false', 'autoload: true')
    else
        content = content:gsub('enabled:%s*true', 'enabled: false')
        content = content:gsub('autoload:%s*true', 'autoload: false')
    end

    local fo = io.open(filePath, 'w')
    if not fo then
        g_logger.warning('Unable to open npctrade otmod for writing: ' .. filePath)
        return
    end
    fo:write(content)
    fo:close()
    --g_logger.info(('Set %s -> enabled=%s autoload=%s'):format(folder, tostring(enable), tostring(enable)))
end

if NPCTRADE_USE_LEGACY then
    setOtmodState('game_npctrade_legacy', true)
    setOtmodState('game_npctrade', false)
else
    setOtmodState('game_npctrade', true)
    setOtmodState('game_npctrade_legacy', false)
end

g_modules.discoverModules()

-- libraries modules 0-99
g_modules.autoLoadModules(99)
g_modules.ensureModuleLoaded('corelib')
g_modules.ensureModuleLoaded('gamelib')
g_modules.ensureModuleLoaded('modulelib')
g_modules.ensureModuleLoaded("startup")

g_modules.autoLoadModules(999)
g_modules.ensureModuleLoaded('game_shaders') -- pre load

local function loadModules()
    -- client modules 100-499
    g_modules.autoLoadModules(499)
    g_modules.ensureModuleLoaded('client')

    -- game modules 500-999
    g_modules.autoLoadModules(999)
    g_modules.ensureModuleLoaded('game_interface')

    -- mods 1000-9999
    g_modules.autoLoadModules(9999)
    g_modules.ensureModuleLoaded('client_mods')

    local script = '/' .. g_app.getCompactName() .. 'rc.lua'

    if g_resources.fileExists(script) then
        dofile(script)
    end

    -- uncomment the line below so that modules are reloaded when modified. (Note: Use only mod dev)
    -- g_modules.enableAutoReload()
end

-- run updater, must use data.zip
if g_app.hasUpdater() then
    g_modules.ensureModuleLoaded("updater")
    return Updater.init(loadModules)
end

loadModules()
