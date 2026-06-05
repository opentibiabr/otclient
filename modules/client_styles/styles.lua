local resourceLoaders = {
    ["otui"] = g_ui.importStyle,
    ["otfont"] = g_fonts.importFont,
    ["ttf"] = g_fonts.importFont,
    ["otf"] = g_fonts.importFont,
    ["otps"] = g_particles.importParticle,
}

function init()
    local device = g_platform.getDevice()
    importResources("styles", "otui", device)
    importResources("fonts/otfont", "otfont", device)
    importResources("fonts//ttf", "ttf", device)
    importResources("fonts/ttf", "otf", device)
    importResources("particles", "otps", device)

    g_mouse.loadCursors('/cursors/cursors')
    g_gameConfig.loadFonts()
end

function terminate()
end

function importResources(dir, type, device)
    local path = '/' .. dir .. '/'
    local files = g_resources.listDirectoryFiles(path, true, false, true)
    for _, file in pairs(files) do
        if g_resources.isFileType(file, type) then
            resourceLoaders[type](file)
        end
    end

    -- try load device specific resources
    if device then
        local devicePath = g_platform.getDeviceShortName(device.type)
        if devicePath ~= "" then
            table.insertall(files, importResources(dir .. '/' .. devicePath, type))
        end
        local osPath = g_platform.getOsShortName(device.os)
        if osPath ~= "" then
            table.insertall(files, importResources(dir .. '/' .. osPath, type))
        end
        return
    end
    return files
end

function reloadParticles()
    g_particles.terminate()
    local device = g_platform.getDevice()
    importResources("particles", "otps", device)
end
