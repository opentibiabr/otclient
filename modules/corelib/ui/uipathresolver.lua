-- Resolves module-relative UI paths in Lua before they reach the C++ layer.
--
-- Root cause being worked around: ResourceManager::resolvePath() resolves a
-- relative path against g_lua.getCurrentSourcePath(), but when the call happens
-- inside a callback (UI button, protocol packet, scheduled event) that context
-- can be unavailable — and the isPreDrawing() branch skips it entirely — so
-- 'file' resolves to '/file.otui' (the root) and the load fails. This breaks
-- every g_ui.loadUI/displayUI/importStyle('barename') call made from a
-- callback (imbuing, outfit, console channels, VIP add/edit, shop, stash,
-- character list, ...), while the same call works from a module's init().
--
-- The fix: wrap the three entry points and, when the argument is a relative
-- path, resolve it against the *calling file's* directory (debug.getinfo),
-- but only if the target file actually exists there. In every other case the
-- argument is forwarded untouched, so behavior is identical to before.

local function resolveCallerPath(path)
    if type(path) ~= 'string' or path == '' or path:sub(1, 1) == '/' then
        return path
    end

    -- level 3: 1 = resolveCallerPath, 2 = wrapper, 3 = caller
    local info = debug.getinfo(3, 'S')
    local src = info and info.source
    if not src or src:sub(1, 1) ~= '@' then
        return path
    end

    src = src:sub(2)
    if src:sub(1, 1) ~= '/' then
        return path
    end

    local dir = src:match('^(.*)/[^/]*$')
    if not dir or dir == '' then
        return path
    end

    local candidate = dir .. '/' .. path
    -- mirror g_resources.guessFilePath(candidate, 'otui')
    local candidateFile = candidate
    if candidate:sub(-5) ~= '.otui' then
        candidateFile = candidate .. '.otui'
    end

    if g_resources.fileExists(candidateFile) then
        return candidate
    end
    return path
end

if not g_ui.__pathResolverInstalled then
    g_ui.__pathResolverInstalled = true

    local origLoadUI = g_ui.loadUI
    local origDisplayUI = g_ui.displayUI
    local origImportStyle = g_ui.importStyle

    g_ui.loadUI = function(path, ...)
        return origLoadUI(resolveCallerPath(path), ...)
    end

    g_ui.displayUI = function(path, ...)
        return origDisplayUI(resolveCallerPath(path), ...)
    end

    g_ui.importStyle = function(path, ...)
        return origImportStyle(resolveCallerPath(path), ...)
    end
end
