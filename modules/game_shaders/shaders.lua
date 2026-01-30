local HOTKEY = 'Ctrl+Y'
local MAP_SHADERS = { {
    name = 'Map - Default',
    frag = nil
}, {
    name = 'Map - Fog',
    frag = 'shaders/fragment/fog.frag',
    tex1 = 'images/clouds'
}, {
    name = 'Map - Rain',
    frag = 'shaders/fragment/rain.frag'
}, {
    name = 'Map - Snow',
    frag = 'shaders/fragment/snow.frag',
    tex1 = 'images/snow'
}, {
    name = 'Map - Gray Scale',
    frag = 'shaders/fragment/grayscale.frag'
}, {
    name = 'Map - Bloom',
    frag = 'shaders/fragment/bloom.frag'
}, {
    name = 'Map - Sepia',
    frag = 'shaders/fragment/sepia.frag'
}, {
    name = 'Map - Pulse',
    frag = 'shaders/fragment/pulse.frag',
    drawViewportEdge = true
}, {
    name = 'Map - Old Tv',
    frag = 'shaders/fragment/oldtv.frag'
}, {
    name = 'Map - Party',
    frag = 'shaders/fragment/party.frag'
}, {
    name = 'Map - Radial Blur',
    frag = 'shaders/fragment/radialblur.frag',
    drawViewportEdge = true
}, {
    name = 'Map - Zomg',
    frag = 'shaders/fragment/zomg.frag',
    drawViewportEdge = true
}, {
    name = 'Map - Heat',
    frag = 'shaders/fragment/heat.frag',
    drawViewportEdge = true
}, {
    name = 'Map - Noise',
    frag = 'shaders/fragment/noise.frag'
} }

local OUTFIT_SHADERS = { {
    name = 'Outfit - Default',
    frag = nil
}, {
    name = 'Outfit - Rainbow',
    frag = 'shaders/fragment/party.frag'
}, {
    name = 'Outfit - Ghost',
    frag = 'shaders/fragment/radialblur.frag',
    drawColor = false
}, {
    name = 'Outfit - Jelly',
    frag = 'shaders/fragment/heat.frag'
}, {
    name = 'Outfit - Fragmented',
    frag = 'shaders/fragment/noise.frag'
}, {
    name = 'Outfit - cyclopedia-black',
    frag = 'shaders/fragment/cyclopedia.frag'
}, {
    name = 'Outfit - Outline',
    useFramebuffer = true,
    frag = 'shaders/fragment/outline.frag'
}, {
    name = 'Outfit - ForgeDonor',
    useFramebuffer = true,
    frag = 'shaders/fragment/forge_donor.frag'
}, {
    name = 'Outfit - ForgeSuccess',
    useFramebuffer = true,
    frag = 'shaders/fragment/forge_success.frag'
}, {
    name = 'Outfit - ForgeFailed',
    useFramebuffer = true,
    frag = 'shaders/fragment/forge_failed.frag'
}, }

local MOUNT_SHADERS = { {
    name = 'Mount - Default',
    frag = nil
}, {
    name = 'Mount - Rainbow',
    frag = 'shaders/fragment/party.frag'
} }

-- Text shaders for improved readability and visual effects
-- All shaders use multi-sample circular sampling for smooth outlines
local TEXT_SHADERS = { {
    name = 'Text - Default',
    frag = nil -- No shader, standard text rendering
}, {
    name = 'Text - Gold Outline',
    frag = 'shaders/fragment/text_golden_shadow_bold_fragment.frag' -- Smooth gold (#ee8413) outline
}, {
    name = 'Text - Black Outline',
    frag = 'shaders/fragment/text_black_outline.frag' -- Classic black outline, max readability
}, {
    name = 'Text - Glow',
    frag = 'shaders/fragment/text_glow.frag' -- Soft glow effect (higher GPU cost)
} }

local function attachShaders()
    local map = modules.game_interface.getMapPanel()
    map:setShader('Default')

    local player = g_game.getLocalPlayer()
    player:setShader('Default')
    player:setMountShader('Default')
end

local registerShader = function(opts, method)
    local fragmentShaderPath = resolvepath(opts.frag)

    if fragmentShaderPath ~= nil then
        --  local shader = g_shaders.createShader()
        g_shaders.createFragmentShader(opts.name, opts.frag, opts.useFramebuffer or false)

        if opts.tex1 then
            g_shaders.addMultiTexture(opts.name, opts.tex1)
        end
        if opts.tex2 then
            g_shaders.addMultiTexture(opts.name, opts.tex2)
        end

        -- Setup proper uniforms
        g_shaders[method](opts.name)
    end
end

ShaderController = Controller:new()

function ShaderController:onInit()
    for _, opts in pairs(MAP_SHADERS) do
        registerShader(opts, 'setupMapShader')
    end

    for _, opts in pairs(OUTFIT_SHADERS) do
        registerShader(opts, 'setupOutfitShader')
    end

    for _, opts in pairs(MOUNT_SHADERS) do
        registerShader(opts, 'setupMountShader')
    end

    for _, opts in pairs(TEXT_SHADERS) do
        registerShader(opts, 'setupTextShader')
    end

    Keybind.new('Windows', 'show/hide Shader Windows', HOTKEY, '')
    Keybind.bind('Windows', 'show/hide Shader Windows', {
        {
            type = KEY_DOWN,
            callback = function()
                if ShaderController.ui then
                    ShaderController:unloadHtml()
                else
                    ShaderController:open()
                end
            end,
        }
    })
end

function ShaderController:onTerminate()
    g_shaders.clear()
    Keybind.delete('Windows', 'show/hide Shader Windows')
end

function ShaderController:onGameStart()
    attachShaders()
end

function ShaderController:onMapComboBoxChange(event)
    local map = modules.game_interface.getMapPanel()
    map:setShader(event.text)

    local data = event.target:getCurrentOption().data
    map:setDrawViewportEdge(data.drawViewportEdge == true)
end

function ShaderController:onOutfitComboBoxChange(event)
    local player = g_game.getLocalPlayer()
    if player then
        player:setShader(event.text)
        local data = event.target:getCurrentOption().data
        player:setDrawOutfitColor(data.drawColor ~= false)
    end
end

function ShaderController:onMountComboBoxChange(event)
    local player = g_game.getLocalPlayer()
    if player then
        player:setMountShader(event.text)
    end
end

function ShaderController:open()
    self:loadHtml('shaders.html', modules.game_interface.getMapPanel())

    for _, opts in pairs(MAP_SHADERS) do
        self.ui.mapComboBox:addOption(opts.name, opts)
    end

    for _, opts in pairs(OUTFIT_SHADERS) do
        self.ui.outfitComboBox:addOption(opts.name, opts)
    end

    for _, opts in pairs(MOUNT_SHADERS) do
        self.ui.mountComboBox:addOption(opts.name, opts)
    end
    for _, opts in pairs(TEXT_SHADERS) do
        self.ui.textComboBox:addOption(opts.name, opts)
    end
end

function ShaderController:onTextComboBoxChange(event)
    -- Apply text shader to local player's name
    -- This affects how the player's name is rendered above their character
    local player = g_game.getLocalPlayer()
    if player then
        -- If using widget-based name rendering
        local infoWidget = player:getWidgetInformation()
        if infoWidget then
            infoWidget:setShader(event.text)
        end
        -- Apply to engine-level name rendering (requires C++ support)
        if player.setNameShader then
            player:setNameShader(event.text)
        end
    end
end
