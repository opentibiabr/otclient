EnterGame = {}

function safeDecrypt(text)
    if not text or text == '' then
        return ''
    end
    local success, result = pcall(g_crypt.decrypt, text)
    return success and result or ''
end

-- private variables
local loadBox
local enterGame
local motdWindow
local enterGameButton
local clientBox
local protocolLogin
local motdEnabled = true
local tokenWindow
local authErrorBox
local hasAttemptedAuthenticator = false

-- private functions
local function onError(protocol, message, errorCode)
    if loadBox then
        loadBox:destroy()
        loadBox = nil
    end

    if errorCode == 6 then
        if hasAttemptedAuthenticator then
            if authErrorBox then
              authErrorBox:destroy()
            end
            authErrorBox = displayErrorBox(tr('Authentication Failed'), tr('The token you entered is incorrect.'))
            connect(authErrorBox, {
              onOk = function()
                authErrorBox = nil
                EnterGame.showAuthenticatorInput()
              end
            })
        else
            EnterGame.showAuthenticatorInput()
        end

        return
    end

    if not errorCode then
        EnterGame.clearAccountFields()
    end

    local errorBox = displayErrorBox(tr('Login Error'), message)
    connect(errorBox, {
        onOk = EnterGame.show
    })
end

local function onMotd(protocol, motd)
    G.motdNumber = tonumber(motd:sub(0, motd:find('\n')))
    G.motdMessage = motd:sub(motd:find('\n') + 1, #motd)
end

local function onSessionKey(protocol, sessionKey)
    G.sessionKey = sessionKey
end

local function onCharacterList(protocol, characters, account, otui)
    local httpLogin = enterGame:getChildById('httpLoginBox'):isChecked()

    -- Try add server to the server list
    ServerList.add(G.host, G.port, g_game.getClientVersion(), httpLogin)

    -- Save 'Stay logged in' setting
    g_settings.set('staylogged', enterGame:getChildById('stayLoggedBox'):isChecked())
    g_settings.set('httpLogin', httpLogin)

    if enterGame:getChildById('rememberEmailBox'):isChecked() then
        local account = g_crypt.encrypt(G.account)
        local password = g_crypt.encrypt(G.password)

        g_settings.set('account', account)
        g_settings.set('password', password)

        ServerList.setServerAccount(G.host, G.account)
        ServerList.setServerPassword(G.host, G.password)
        ServerList.setServerAutologin(G.host, enterGame:getChildById('autoLoginBox'):isChecked())

        g_settings.set('autologin', enterGame:getChildById('autoLoginBox'):isChecked())
        ServerList.save()
    else
        -- reset server list account/password
        ServerList.setServerAccount(G.host, '')
        ServerList.setServerPassword(G.host, '')

        EnterGame.clearAccountFields()
    end

    if loadBox then
        loadBox:destroy()
        loadBox = nil
    end

    for _, characterInfo in pairs(characters) do
        if characterInfo.previewState and characterInfo.previewState ~= PreviewState.Default then
            characterInfo.worldName = characterInfo.worldName .. ', Preview'
        end
    end

    CharacterList.create(characters, account, otui)
    CharacterList.show()

    if motdEnabled then
        local lastMotdNumber = g_settings.getNumber('motd')
        if G.motdNumber and G.motdNumber ~= lastMotdNumber then
            g_settings.set('motd', G.motdNumber)
            motdWindow = displayInfoBox(tr('Message of the day'), G.motdMessage)
            connect(motdWindow, {
                onOk = function()
                    CharacterList.show()
                    motdWindow = nil
                end
            })
            CharacterList.hide()
        end
    end
end

local function onUpdateNeeded(protocol, signature)
    if loadBox then
        loadBox:destroy()
        loadBox = nil
    end

    if EnterGame.updateFunc then
        local continueFunc = EnterGame.show
        local cancelFunc = EnterGame.show
        EnterGame.updateFunc(signature, continueFunc, cancelFunc)
    else
        local errorBox = displayErrorBox(tr('Update needed'), tr('Your client needs updating, try redownloading it.'))
        connect(errorBox, {
            onOk = EnterGame.show
        })
    end
end

local function updateLabelText()
    if enterGame:getChildById('clientComboBox') and tonumber(enterGame:getChildById('clientComboBox'):getText()) > 1080 then
        enterGame:setText("Journey Onwards")
        enterGame:getChildById('emailLabel'):setText("Email:")
        enterGame:getChildById('rememberEmailBox'):setText("Remember Email:")
    else
        enterGame:setText("Enter Game")
        enterGame:getChildById('emailLabel'):setText("Acc Name:")
        enterGame:getChildById('rememberEmailBox'):setText("Remember password:")
    end
end

local function loadServerListModule()
    local module = g_modules.getModule('client_serverlist')

    if module and not module:isLoaded() then
        module:load()
    end
end

-- public functions
function EnterGame.init()
    enterGame = g_ui.displayUI('entergame')
    Keybind.new("Misc.", "Change Character", "Ctrl+G", "")
    Keybind.bind("Misc.", "Change Character", {
      {
        type = KEY_DOWN,
        callback = EnterGame.openWindow,
      }
    })

    local host = g_settings.get('host')
    local port = g_settings.get('port')
    local stayLogged = g_settings.getBoolean('staylogged')
    local autologin = g_settings.getBoolean('autologin')
    local httpLogin = g_settings.getBoolean('httpLogin')
    local clientVersion = g_settings.getInteger('client-version')

    if not clientVersion or clientVersion == 0 then
        clientVersion = 860
    end

    if not port or port == 0 then
        port = 7171
    end

    local servers = g_settings.getNode("ServerList") or {}
    local serverData = servers[host] or {}
    if serverData and serverData.account then
        EnterGame.setAccountName(serverData.account)
        EnterGame.setPassword(serverData.password)
        enterGame:getChildById('rememberEmailBox'):setChecked(true)
    else
        EnterGame.setAccountName('')
        EnterGame.setPassword('')
        enterGame:getChildById('rememberEmailBox'):setChecked(false)
    end
    
    enterGame:getChildById('autoLoginBox'):setChecked(serverData.autologin == true)
    enterGame:getChildById('serverHostTextEdit'):setText(host)
    enterGame:getChildById('serverPortTextEdit'):setText(port)
    enterGame:getChildById('stayLoggedBox'):setChecked(stayLogged)
    enterGame:getChildById('httpLoginBox'):setChecked(httpLogin)

    local installedClients = {}
    local amountInstalledClients = 0
    for _, dirItem in ipairs(g_resources.listDirectoryFiles('/data/things/')) do
        if tonumber(dirItem) then
            installedClients[dirItem] = true
            amountInstalledClients = amountInstalledClients + 1
        end
    end

    clientBox = enterGame:getChildById('clientComboBox')

    for _, proto in pairs(g_game.getSupportedClients()) do
        local protoStr = tostring(proto)
        if installedClients[protoStr] or amountInstalledClients == 0 then
            installedClients[protoStr] = nil
            clientBox:addOption(proto)
        end
    end

    for protoStr, status in pairs(installedClients) do
        if status then
            print(string.format('Warning: %s recognized as an installed client, but not supported.', protoStr))
        end
    end

    clientBox:setCurrentOption(clientVersion)

    connect(clientBox, {
        onOptionChange = EnterGame.onClientVersionChange
    })

    connect(enterGame:getChildById('rememberEmailBox'), {
        onCheckChange = function(self, checked)
            local host = enterGame:getChildById('serverHostTextEdit'):getText()
            local account = enterGame:getChildById('accountNameTextEdit'):getText()
            local password = enterGame:getChildById('accountPasswordTextEdit'):getText()

            if checked and #account > 0 then
                ServerList.setServerAccount(host, account)
                ServerList.setServerPassword(host, password)
                ServerList.setServerAutologin(host, enterGame:getChildById('autoLoginBox'):isChecked() or false)
                g_settings.set('host', host)
            else
                ServerList.setServerAccount(host, '')
                ServerList.setServerPassword(host, '')
                ServerList.setServerAutologin(host, false)
            end

            ServerList.save()
            g_configs.saveSettings()
        end
    })

    if Servers_init and next(Servers_init) ~= nil then
        local server = Servers_init[host]
        enterGame.disableToken = not (server and server.useAuthenticator)
        if table.size(Servers_init) == 1 then
            local hostInit, valuesInit = next(Servers_init)
            EnterGame.setUniqueServer(hostInit, valuesInit.port, valuesInit.protocol)
            EnterGame.setHttpLogin(valuesInit.httpLogin)
        elseif not host or host == "" then
            local hostInit, valuesInit = next(Servers_init)
            EnterGame.setDefaultServer(hostInit, valuesInit.port, valuesInit.protocol)
            EnterGame.setHttpLogin(valuesInit.httpLogin)
        end
    else
        EnterGame.toggleStayLoggedBox(clientVersion, true)
    end

    updateLabelText()

    enterGame:hide()

    connect(g_game, {
        onGameStart = EnterGame.hidePanels
    })

    connect(g_game, {
        onGameEnd = EnterGame.showPanels
    })

    if g_app.isRunning() and not g_game.isOnline() then
        enterGame:show()
    end
end

function EnterGame.hidePanels()
    if g_modules.getModule("client_bottommenu"):isLoaded()  then
        modules.client_bottommenu.hide()
    end
    modules.client_topmenu.hide()
end

function EnterGame.showPanels()
    if g_modules.getModule("client_bottommenu"):isLoaded()  then
        modules.client_bottommenu.show()
    end
    modules.client_topmenu.show()
end

function EnterGame.showServerList()
    loadServerListModule()

    if ServerList then
        ServerList.show()
    end
end

function EnterGame.firstShow()
    EnterGame.show()

    local host = g_settings.get('host')
    local servers = g_settings.getNode('ServerList') or {}
    local serverData = servers[host] or {}
    local account = safeDecrypt(serverData.account)
    local password = safeDecrypt(serverData.password)
    local autologin = serverData.autologin == true
    if #host > 0 and #password > 0 and #account > 0 and autologin then
        addEvent(function()
            if not g_settings.getBoolean('autologin') then
                return
            end
            EnterGame.doLogin()
        end)
    end

    if Services and Services.status then
        if g_modules.getModule("client_bottommenu"):isLoaded()  then
            EnterGame.postCacheInfo()
            EnterGame.postEventScheduler()
            -- EnterGame.postShowOff() -- myacc/znote no send login.php
            EnterGame.postShowCreatureBoost()
        end
    end
end

function EnterGame.terminate()
    Keybind.delete("Misc.", "Change Character")

    disconnect(clientBox, {
        onOptionChange = EnterGame.onClientVersionChange
    })
    disconnect(g_game, {
        onGameStart = EnterGame.hidePanels
    })
    disconnect(g_game, {
        onGameEnd = EnterGame.showPanels
    })

    if enterGame then
        enterGame:destroy()
        enterGame = nil
    end

    if clientBox then
        clientBox = nil
    end

    if motdWindow then
        motdWindow:destroy()
        motdWindow = nil
    end

    if loadBox then
        loadBox:destroy()
        loadBox = nil
    end

    if protocolLogin then
        protocolLogin:cancelLogin()
        protocolLogin = nil
    end

    EnterGame = nil
end

local function reportRequestWarning(requestType, msg, errorCode)
    g_logger.warning(("[Webscraping - %s] %s"):format(requestType, msg), errorCode)
end

function EnterGame.postCacheInfo()
    local requestType = 'cacheinfo'

    local onRecvInfo = function(message, err)

        if err then
            -- onError(nil, 'Bad Request. Game_entergame postCacheInfo1 ', 400)
            reportRequestWarning(requestType, "Bad Request. Game_entergame postCacheInfo1")
            return
        end

        local jsonString = message:match("{.*}")
        if not jsonString then
            reportRequestWarning(requestType, "Invalid JSON response format")
            return
        end

        local success, response = pcall(function() return json.decode(jsonString) end)
        if not success or not response then
            reportRequestWarning(requestType, "Failed to parse JSON response")
            return
        end

        if response.errorMessage then
            reportRequestWarning(requestType, response.errorMessage, response.errorCode)
            return
        end

        modules.client_topmenu.setPlayersOnline(response.playersonline)
        modules.client_topmenu.setDiscordStreams(response.discord_online)
        modules.client_topmenu.setYoutubeStreams(response.gamingyoutubestreams)
        modules.client_topmenu.setYoutubeViewers(response.gamingyoutubeviewer)
        modules.client_topmenu.setLinkYoutube(response.youtube_link)
        modules.client_topmenu.setLinkDiscord(response.discord_link)

    end

    HTTP.post(Services.status, json.encode({
        type = requestType
    }), onRecvInfo, false)
end

function EnterGame.postEventScheduler()
    local requestType = 'eventschedule'
    local onRecvInfo = function(message, err)
        if err then
            reportRequestWarning(requestType, "Bad Request.Game_entergame postEventScheduler1")
            return
        end

        local jsonString = message:match("{.*}")
        if not jsonString then
            reportRequestWarning(requestType, "Invalid JSON response format")
            return
        end

        local success, response = pcall(function() return json.decode(jsonString) end)
        if not success or not response then
            reportRequestWarning(requestType, "Failed to parse JSON response")
            return
        end

        if response.errorMessage then
            reportRequestWarning(requestType, response.errorMessage, response.errorCode)
            return
        end
        modules.client_bottommenu.setEventsSchedulerTimestamp(response.lastupdatetimestamp)
        modules.client_bottommenu.setEventsSchedulerCalender(response.eventlist)
    end

    HTTP.post(Services.status, json.encode({
        type = requestType
    }), onRecvInfo, false)
end

function EnterGame.postShowOff()
    local requestType = 'showoff'
    local onRecvInfo = function(message, err)
        if err then
            reportRequestWarning(requestType, "Bad Request.Game_entergame postShowOff")
            return
        end

        local jsonString = message:match("{.*}")
        if not jsonString then
            reportRequestWarning(requestType, "Invalid JSON response format")
            return
        end

        local success, response = pcall(function() return json.decode(jsonString) end)
        if not success or not response then
            reportRequestWarning(requestType, "Failed to parse JSON response")
            return
        end

        if response.errorMessage then
            reportRequestWarning(requestType, response.errorMessage, response.errorCode)
            return
        end

        modules.client_bottommenu.setShowOffData(response)
    end

    HTTP.post(Services.status, json.encode({
        type = requestType
    }), onRecvInfo, false)
end

function EnterGame.postShowCreatureBoost()
    local requestType = 'boostedcreature'
    local onRecvInfo = function(message, err)
        if err then
            -- onError(nil, 'Bad Request. 1 Game_entergame postShowCreatureBoost', 400)
            reportRequestWarning(requestType, "Bad Request.Game_entergame postShowCreatureBoost1")
            return
        end

        local jsonString = message:match("{.*}")
        if not jsonString then
            reportRequestWarning(requestType, "Invalid JSON response format")
            return
        end

        local success, response = pcall(function() return json.decode(jsonString) end)
        if not success or not response then
            reportRequestWarning(requestType, "Failed to parse JSON response")
            return
        end

        if response.errorMessage then
            reportRequestWarning(requestType, response.errorMessage, response.errorCode)
            return
        end

        modules.client_bottommenu.setBoostedCreatureAndBoss(response)
    end

    HTTP.post(Services.status, json.encode({
        type = requestType
    }), onRecvInfo, false)
end

function EnterGame.show()
    if g_game.isOnline() or CharacterList.isVisible() then -- fix login quickly error (http post)
        return
    end

    if loadBox then
        return
    end

    enterGame:show()
    enterGame:raise()
    enterGame:focus()
    hasAttemptedAuthenticator = false
end

function EnterGame.hide()
    enterGame:hide()
end

function EnterGame.openWindow()
    if g_game.isOnline() then
        CharacterList.show()
    elseif not g_game.isLogging() and not CharacterList.isVisible() then
        EnterGame.show()
    end
end

function EnterGame.setAccountName(account)
    local decrypted = safeDecrypt(account or '')
    enterGame:getChildById('accountNameTextEdit'):setText(decrypted)
    enterGame:getChildById('accountNameTextEdit'):setCursorPos(-1)
    enterGame:getChildById('rememberEmailBox'):setChecked(#decrypted > 0)
end

function EnterGame.setPassword(password)
    enterGame:getChildById('accountPasswordTextEdit'):setText(safeDecrypt(password or ''))
end

function EnterGame.setHttpLogin(httpLogin)
    if type(httpLogin) == "boolean" then
        enterGame:getChildById('httpLoginBox'):setChecked(httpLogin)
    else
        enterGame:getChildById('httpLoginBox'):setChecked(#httpLogin > 0)
    end
end

function EnterGame.clearAccountFields()
    enterGame:getChildById('accountNameTextEdit'):clearText()
    enterGame:getChildById('accountPasswordTextEdit'):clearText()
    enterGame:getChildById('accountNameTextEdit'):focus()
    g_settings.remove('account')
    g_settings.remove('password')
end

function EnterGame.toggleStayLoggedBox(clientVersion, init)
    local enabled = (clientVersion >= 1074)
    if enabled == enterGame.stayLoggedBoxEnabled then
        return
    end

    enterGame:getChildById('stayLoggedBox'):setOn(enabled)

    local newHeight = enterGame:getHeight()
    local newY = enterGame:getY()
    if enabled then
        newY = newY - enterGame.stayLoggedBoxHeight
        newHeight = newHeight + enterGame.stayLoggedBoxHeight
    else
        newY = newY + enterGame.stayLoggedBoxHeight
        newHeight = newHeight - enterGame.stayLoggedBoxHeight
    end

    if not init then
        enterGame:breakAnchors()
        enterGame:setY(newY)
        enterGame:bindRectToParent()
    end

    enterGame:setHeight(newHeight)
    enterGame.stayLoggedBoxEnabled = enabled
end

function EnterGame.onClientVersionChange(comboBox, text, data)
    local clientVersion = tonumber(text)
    EnterGame.toggleStayLoggedBox(clientVersion)
    updateLabelText()
end

function EnterGame.tryHttpLogin(clientVersion, httpLogin)
    g_game.setClientVersion(clientVersion)
    g_game.setProtocolVersion(g_game.getClientProtocolVersion(clientVersion))
    g_game.chooseRsa(G.host)
    if not modules.game_things.isLoaded() then
        if loadBox then
            loadBox:destroy()
            loadBox = nil
        end

        local errorBox = displayErrorBox(tr("Login Error"), string.format("Things are not loaded, please put assets in things/%d/<assets>.", clientVersion))
        connect(errorBox, {
            onOk = EnterGame.show
        })
        return
    end

    -- Show connecting message immediately
    loadBox = displayCancelBox(tr('Connecting'), tr('Your character list is being loaded. Please wait.'))
    connect(loadBox, {
        onCancel = function(msgbox)
            loadBox = nil
            G.requestId = 0
            EnterGame.show()
        end
    })

    local host, path = G.host, "/"
    if G.host:find("https?://") then
        local url = G.host:gsub("https?://", "")
        host, path = url:match("([^/]+)(/.*)")
        if not host then
            host = url
            path = "/"
        elseif not path or path == "" then
            path = "/"
        end
    end

    if not G.port then
        if G.host:find("https") then
            G.port = 443
        else
            G.port = 80
        end
    end

    math.randomseed(os.time())
    G.requestId = math.random(1)

    local http = LoginHttp.create()
    http:httpLogin(host, path, G.port, G.account, G.password, G.requestId, httpLogin, G.authenticatorToken)
end

function printTable(t)
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(string.format("%q: {", k))
            printTable(v)
            print("}")
        else
            print(string.format("%q:", k) .. tostring(v) .. ",")
        end
    end
end

function EnterGame.loginSuccess(requestId, jsonSession, jsonWorlds, jsonCharacters)
    if G.requestId ~= requestId then
        return
    end

    -- Update the existing loadBox message or create new one if it doesn't exist
    if loadBox then
        loadBox:destroy()
    end
    loadBox = displayCancelBox(tr('Connecting'), tr('Your character list is being loaded. Please wait.'))

    connect(loadBox, {
        onCancel = function(msgbox)
            loadBox = nil
            G.requestId = 0
            EnterGame.show()
        end
    })

    if tokenWindow then
        tokenWindow:destroy()
        tokenWindow = nil
    end

    local worlds = {}
    for _, world in ipairs(json.decode(jsonWorlds)) do
        worlds[world.id] = {
            name = world.name,
            ip = world.externaladdressprotected,
            port = world.externalportprotected,
            previewState = world.previewstate == 1
        }
    end

    local characters = {}
    for index, character in ipairs(json.decode(jsonCharacters)) do
        local world = worlds[character.worldid]
        characters[index] = {
            name = character.name,
            level = character.level,
            main = character.ismaincharacter,
            dailyreward = character.dailyrewardstate,
            hidden = character.ishidden,
            vocation = character.vocation,
            outfitid = character.outfitid,
            headcolor = character.headcolor,
            torsocolor = character.torsocolor,
            legscolor = character.legscolor,
            detailcolor = character.detailcolor,
            addonsflags = character.addonsflags,
            worldName = world.name,
            worldIp = world.ip,
            worldPort = world.port,
            previewState = world.previewstate
        }
    end

    local session = json.decode(jsonSession)

    local premiumUntil = tonumber(session.premiumuntil)

    local account = {
        status = '',
        premDays = math.floor((premiumUntil - os.time()) / 86400),
        subStatus = premiumUntil > os.time() and SubscriptionStatus.Premium or SubscriptionStatus.Free
    }

    -- set session key
    G.sessionKey = session.sessionkey

    onCharacterList(nil, characters, account)
end

function EnterGame.loginFailed(requestId, msg, result)
    if G.requestId ~= requestId then
        return
    end
    onError(nil, msg, result)
end

function EnterGame.doLogin()
    G.account = enterGame:getChildById('accountNameTextEdit'):getText()
    G.password = enterGame:getChildById('accountPasswordTextEdit'):getText()
    G.stayLogged = enterGame:getChildById('stayLoggedBox'):isChecked()
    G.host = enterGame:getChildById('serverHostTextEdit'):getText()
    G.port = tonumber(enterGame:getChildById('serverPortTextEdit'):getText())
    local clientVersion = tonumber(clientBox:getText())
    G.clientVersion = clientVersion
    local httpLogin = enterGame:getChildById('httpLoginBox'):isChecked()
    EnterGame.hide()

    if g_game.isOnline() then
        local errorBox = displayErrorBox(tr('Login Error'), tr('Cannot login while already in game.'))
        connect(errorBox, {
            onOk = EnterGame.show
        })
        return
    end

    g_settings.set('host', G.host)
    g_settings.set('port', G.port)
    g_settings.set('client-version', clientVersion)

    if clientVersion >= 1281 and G.port ~= 7171 then
        EnterGame.tryHttpLogin(clientVersion, httpLogin)
    else
        protocolLogin = ProtocolLogin.create()
        protocolLogin.onLoginError = onError
        protocolLogin.onMotd = onMotd
        protocolLogin.onSessionKey = onSessionKey
        protocolLogin.onCharacterList = onCharacterList
        protocolLogin.onUpdateNeeded = onUpdateNeeded

        loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to login server...'))

        connect(loadBox, {
            onCancel = function(msgbox)
                loadBox = nil
                protocolLogin:cancelLogin()
                EnterGame.show()
            end
        })

        g_game.setClientVersion(clientVersion)
        g_game.setProtocolVersion(g_game.getClientProtocolVersion(clientVersion))
        g_game.chooseRsa(G.host)

        if modules.game_things.isLoaded() then
            protocolLogin:login(G.host, G.port, G.account, G.password, G.authenticatorToken, G.stayLogged)
        else
            if loadBox then
                loadBox:destroy()
                loadBox = nil
            end

            local errorBox = displayErrorBox(tr("Login Error"), string.format("Things are not loaded, please put spr and dat in things/%d/<here>.", clientVersion))
            connect(errorBox, {
               onOk = EnterGame.show
            })
            return
        end
    end
end

function EnterGame.displayMotd()
    if not motdWindow then
        motdWindow = displayInfoBox(tr('Message of the day'), G.motdMessage)
        motdWindow.onOk = function()
            motdWindow = nil
        end
    end
end

function EnterGame.setDefaultServer(host, port, protocol)
    local hostTextEdit = enterGame:getChildById('serverHostTextEdit')
    local portTextEdit = enterGame:getChildById('serverPortTextEdit')
    local clientLabel = enterGame:getChildById('clientLabel')
    local accountTextEdit = enterGame:getChildById('accountNameTextEdit')
    local passwordTextEdit = enterGame:getChildById('accountPasswordTextEdit')

    if hostTextEdit:getText() ~= host then
        hostTextEdit:setText(host)
        portTextEdit:setText(port)
        clientBox:setCurrentOption(protocol)
        accountTextEdit:setText('')
        passwordTextEdit:setText('')
    end
end

function EnterGame.setUniqueServer(host, port, protocol, windowWidth, windowHeight)
    local hostTextEdit = enterGame:getChildById('serverHostTextEdit')
    hostTextEdit:setText(host)
    hostTextEdit:setVisible(false)
    hostTextEdit:setHeight(0)

    local portTextEdit = enterGame:getChildById('serverPortTextEdit')
    portTextEdit:setText(port)
    portTextEdit:setVisible(false)
    portTextEdit:setHeight(0)

    local stayLoggedBox = enterGame:getChildById('stayLoggedBox')
    stayLoggedBox:setChecked(false)
    stayLoggedBox:setOn(false)

    local clientVersion = tonumber(protocol)
    clientBox:setCurrentOption(clientVersion)
    clientBox:setVisible(false)
    clientBox:setHeight(0)

    local serverLabel = enterGame:getChildById('serverLabel')
    serverLabel:setVisible(false)
    serverLabel:setHeight(0)

    local portLabel = enterGame:getChildById('portLabel')
    portLabel:setVisible(false)
    portLabel:setHeight(0)

    local clientLabel = enterGame:getChildById('clientLabel')
    clientLabel:setVisible(false)
    clientLabel:setHeight(0)

    local httpLoginBox = enterGame:getChildById('httpLoginBox')
    httpLoginBox:setVisible(false)
    httpLoginBox:setHeight(0)

    local serverListButton = enterGame:getChildById('serverListButton')
    serverListButton:setVisible(false)
    serverListButton:setHeight(0)
    serverListButton:setWidth(0)

    local rememberEmailBox = enterGame:getChildById('rememberEmailBox')
    rememberEmailBox:setMarginTop(5)

    if not windowWidth then
        windowWidth = 380
    end
    enterGame:setWidth(windowWidth)
    if not windowHeight then
        windowHeight = 210
    end

    enterGame:setHeight(windowHeight)
    enterGame.disableToken = true
    local server = Servers_init[host]
    enterGame.disableToken = not (server and server.useAuthenticator)

    -- preload the assets
    -- this is for the client_bottommenu module
    -- it needs images of outfits
    -- so it can display the boosted creature
    g_game.setClientVersion(clientVersion)
    g_game.setProtocolVersion(g_game.getClientProtocolVersion(clientVersion))
end

function EnterGame.setServerInfo(message)
    local label = enterGame:getChildById('serverInfoLabel')
    label:setText(message)
end

function EnterGame.disableMotd()
    motdEnabled = false
end

function EnterGame.showAuthenticatorInput()
    if tokenWindow then
        tokenWindow:destroy()
        tokenWindow = nil
    end
    
    -- Create a custom message box with embedded text edit
    tokenWindow = g_ui.createWidget('MessageBoxWindow', rootWidget)
    tokenWindow.title = tokenWindow:getChildById('title')
    tokenWindow.title:setText(tr('Two-Factor Authentication'))
    
    tokenWindow.content = tokenWindow:getChildById('content')
    tokenWindow.content:setText(tr('Please enter a new, valid token:'))
    tokenWindow.content:setColor('#c0c0c0')
    tokenWindow.content:resizeToText()
    -- Align content to the left instead of center
    tokenWindow.content:breakAnchors()
    tokenWindow.content:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    tokenWindow.content:addAnchor(AnchorTop, 'parent', AnchorTop)
    tokenWindow.content:setMarginLeft(15)
    tokenWindow.content:setMarginTop(32)
    
    -- Add text edit field for token input
    local tokenEdit = g_ui.createWidget('TextEdit', tokenWindow)
    tokenEdit:setId('tokenEdit')
    tokenEdit:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    tokenEdit:addAnchor(AnchorTop, 'content', AnchorBottom)
    tokenEdit:setMarginTop(10)
    tokenEdit:setMaxLength(8)
    tokenEdit:setWidth(320)
    tokenEdit:setHeight(16)
    tokenEdit:setMarginLeft(15)
    tokenEdit:setMarginRight(15)
    tokenEdit:focus()
    
    -- Add horizontal separator
    local separator = g_ui.createWidget('HorizontalSeparator', tokenWindow)
    separator:setId('customSeparator')
    separator:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    separator:addAnchor(AnchorRight, 'parent', AnchorRight)
    separator:addAnchor(AnchorTop, 'tokenEdit', AnchorBottom)
    separator:setMarginTop(10)
    separator:setMarginLeft(15)
    separator:setMarginRight(15)
    
    -- Reposition the holder to be below our custom separator
    tokenWindow.holder = tokenWindow:getChildById('holder')
    tokenWindow.holder:breakAnchors()
    tokenWindow.holder:addAnchor(AnchorRight, 'customSeparator', AnchorRight)
    tokenWindow.holder:addAnchor(AnchorLeft, 'customSeparator', AnchorLeft)
    tokenWindow.holder:addAnchor(AnchorTop, 'customSeparator', AnchorBottom)
    tokenWindow.holder:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    tokenWindow.holder:setMarginTop(12)
    
    local okCallback = function()
        local token = tokenEdit:getText()
        if not token or token:len() == 0 then
            if authErrorBox then
              authErrorBox:destroy()
            end
            authErrorBox = displayErrorBox(tr('Error'), tr('Token is required.'))
            connect(authErrorBox, {
              onOk = function()
                authErrorBox = nil
                if tokenWindow then
                    tokenWindow:raise()
                    tokenWindow:focus()
                    tokenEdit:focus()
                end
              end
            })
            return
        end
        
        hasAttemptedAuthenticator = true
        
        G.account = enterGame:getChildById('accountNameTextEdit'):getText()
        G.password = enterGame:getChildById('accountPasswordTextEdit'):getText()
        G.host = enterGame:getChildById('serverHostTextEdit'):getText()
        G.port = tonumber(enterGame:getChildById('serverPortTextEdit'):getText())
        G.authenticatorToken = token
        local clientVersion = tonumber(clientBox:getText())
        local httpLogin = enterGame:getChildById('httpLoginBox'):isChecked()
        
        if tokenWindow then
            tokenWindow:destroy()
            tokenWindow = nil
        end
        
        EnterGame.tryHttpLogin(clientVersion, httpLogin)
    end
    
    local cancelCallback = function()
        hasAttemptedAuthenticator = false
        G.authenticatorToken = nil
        if tokenWindow then
            tokenWindow:destroy()
            tokenWindow = nil
        end
        EnterGame.show()
    end
        
    -- Add Cancel button (to the left of OK button)
    local cancelButton = tokenWindow:addButton(tr('Cancel'), cancelCallback)
    cancelButton:breakAnchors()
    cancelButton:addAnchor(AnchorTop, 'parent', AnchorTop)
    cancelButton:addAnchor(AnchorRight, 'parent', AnchorRight)
    cancelButton:setWidth(45)

    -- Add OK button (right side, added first)
    local okButton = tokenWindow:addButton(tr('Ok'), okCallback)
    okButton:breakAnchors()
    okButton:addAnchor(AnchorTop, 'prev', AnchorTop)
    okButton:addAnchor(AnchorRight, 'prev', AnchorLeft)
    okButton:setMarginRight(10)
    okButton:setWidth(40)
    
    -- Calculate window size based on content
    local windowWidth = 350
    local windowHeight = 28 + tokenWindow.content:getHeight() + 10 + tokenEdit:getHeight() + 10 + 2 + 12 + okButton:getHeight() + 12
    
    tokenWindow:setWidth(windowWidth)
    tokenWindow:setHeight(windowHeight)
    
    -- Connect Enter and Escape keys
    connect(tokenWindow, {
        onEnter = okCallback,
        onEscape = cancelCallback
    })
    
    -- Connect text edit Enter key
    connect(tokenEdit, {
        onEnter = okCallback
    })
end

function EnterGame.doLoginWithToken()
    local servers = Servers_init or {}
    local serverData = servers[G.host]
    if not (serverData and serverData.useAuthenticator) then
        print('Authenticator token is disabled for this server.')
        return
    end
    
    EnterGame.showAuthenticatorInput()
end

function EnterGame.destroyToken()
    if tokenWindow then
      if tokenWindow.destroy then
        tokenWindow:destroy()
      end
      tokenWindow = nil
      hasAttemptedAuthenticator = false
      G.authenticatorToken = nil
    end
end

function ensableBtnCreateNewAccount()
    enterGame.btnCreateNewAccount:enable()
end
