-- Game News JSON Manager
local file = "compendium.json"
local treeView = nil
local compendiumButton = nil
local uiBuilt = false
local currentContentWidget = nil  -- Track current content widget for cleanup
local contentAnchorConnected = false

local function clearContentWidget(widget)
    if not widget or widget:isDestroyed() then
        return
    end
    if widget.destroyChildren then
        widget:destroyChildren()
        return
    end
    local children = widget:getChildren()
    for _, child in ipairs(children) do
        if not child:isDestroyed() then
            child:destroy()
        end
    end
end

local function ensureAnchorHandler(widget)
    if contentAnchorConnected then
        return
    end
    widget.onAnchorClick = function(_, url)
        g_platform.openUrl(url)
        return true
    end
    compendiumController:registerUIEvents(widget, {onAnchorClick = widget.onAnchorClick})
    contentAnchorConnected = true
end

local function processHtmlContent(text)
    if not text then return "" end
    text = tostring(text)

    -- Decode common HTML entities
    text = text:gsub("&nbsp;", " ")
    text = text:gsub("&amp;", "&")
    text = text:gsub("&lt;", "<")
    text = text:gsub("&gt;", ">")
    text = text:gsub("&quot;", "\"")
    text = text:gsub("&#39;", "'")

    -- Collapse all whitespace (including newlines) outside of tags into a single space
    text = text:gsub("([^<]+)", function(segment)
        return segment:gsub("%s+", " ")
    end)

    -- Self-close img tags (OTClient requires XML-style self-closing)
    text = text:gsub("<[Ii][Mm][Gg](%s+[^>]-)%s*/?>", "<img%1/>")


    return text
end

local function wrapHtmlContent(text)
    if not text or text == "" then
        return ""
    end
    return text
end

-- Accepts either a plain string or an array-of-lines (the format used in compendium.json
-- for readability) and always returns a single HTML string.
local function resolveMessage(msg)
    if type(msg) == "table" then
        return table.concat(msg, "\n")
    end
    return msg or ""
end

-- Controller setup
compendiumController = Controller:new()


-- /*=============================================
-- =            Windows                  =
-- =============================================*/
local function show()
    if not compendiumController.ui then
        return
    end
    compendiumController.ui:show()
    compendiumController.ui:raise()
    compendiumController.ui:focus()
    
    -- Only build UI if it hasn't been built yet
    if not uiBuilt then
        checkUpdates(function(newsData)
            if not newsData then
                return
            end

            -- Display the last update date
            local date = os.date("*t", newsData.maxeditdate)
            compendiumController.ui.date:setText(string.format("%d-%02d-%02d %02d:%02d:%02d", date.year, date.month,
                date.day, date.hour, date.min, date.sec))

            buildNewsUI(newsData)
            uiBuilt = true
        end)
    end
end

local function hide()
    if not compendiumController.ui then
        return
    end
    compendiumController.ui:hide()
end

local function toggle()
    if not compendiumController.ui then
        return
    end
    if compendiumController.ui:isVisible() then
        compendiumButton:setOn(false)
        return hide(true)
    end
    show()
    compendiumButton:setOn(true)
end

-- /*=============================================
-- =            Controller                  =
-- =============================================*/
function compendiumController:onInit()
   compendiumController:loadHtml('game_compendium.html')
    self.ui:hide()
    treeView = UITreeView.create()
    treeView:setId('myTreeView')
    treeView:setup(compendiumController:findWidget("#optionsTabBar"), compendiumController:findWidget("#optionsTabContent"))
    treeView:setAutoSelectFirstSubCategory(true)
    treeView:setCategorySpacing(8)
    treeView:setUseSubCategoryIndentation(true)
    treeView:setMargin(15)

    -- Connect close button
    local closeButton = compendiumController:findWidget("#closeButton")
    if closeButton then
        closeButton.onClick = function()
            toggle()
        end
    end

    compendiumButton = modules.game_mainpanel.addToggleButton('compendium', tr('compendium'),
        '/images/options/compendium', toggle, false, 9999)
end

function compendiumController:onTerminate()
    if treeView then
        treeView:clearCategories()
        treeView:destroy()
        treeView = nil
    end
    if compendiumButton then
        compendiumButton:destroy()
        compendiumButton = nil
    end
    
    -- Clean up current content widget
    clearContentWidget(currentContentWidget)
    currentContentWidget = nil
    contentAnchorConnected = false

    if compendiumController.ui then
        compendiumController:unloadHtml()
    end
    
    uiBuilt = false
end
-- /*=============================================
-- =            Json                  =
-- =============================================*/

function loadLocalNews()
    if not g_resources.fileExists(file) then
        return nil
    end

    local status, result = pcall(json.decode, g_resources.readFileContents(file))
    if not status then
        g_logger.error("Error while reading news file. Details: " .. result)
        return nil
    end

    return result or {}
end

function saveNews(newsData)
    local status, result = pcall(json.encode, newsData, 2)
    if not status then
        g_logger.error("Error while saving news data. Details: " .. result)
        return false
    end
    if result:len() > 100 * 1024 * 1024 then -- 100MB
        g_logger.error("Something went wrong, file is above 100MB, won't be saved")
        return false
    end

    g_resources.writeFileContents(file, result)
    return true
end


-- /*=============================================
-- =            HTTP                  =
-- =============================================*/

function makeHttpRequest(callback)
    if Services and not Services.status then
        return callback(nil, "")
    end
    HTTP.post(Services.status, json.encode({
        type = "news"
    }), function(message, err)
        if err then
            g_logger.warning("[Webscraping - news] Request failed: " .. tostring(err))
            return callback(nil, err)
        end

        local json_part = message:match("{.*}")
        if not json_part then
            g_logger.warning("[Webscraping - news] JSON not found in the response")
            return callback(nil, "Invalid response format")
        end

        local status, response = pcall(json.decode, json_part)
        if not status or type(response) ~= "table" then
            g_logger.warning("[Webscraping - news] JSON decode error: " .. (status and "Invalid format" or response))
            return callback(nil, status and "Invalid response format" or response)
        end

        return callback(response)
    end, false)
end

function checkUpdates(callback)
    local localNews = loadLocalNews()
    local localTimestamp = localNews and localNews.maxeditdate or 0

    makeHttpRequest(function(remoteNews, err)
        if err or not remoteNews or not remoteNews.maxeditdate then
            -- g_logger.warning("[News] Failed to fetch remote news, using local data")
            return callback(localNews)
        end

        -- Check if remote news is newer
        if remoteNews.maxeditdate > localTimestamp then
            -- Download complete news data and save locally
            makeHttpRequest(function(fullNews, fullErr)
                if fullErr or not fullNews then
                    return callback(localNews)
                end

                if saveNews(fullNews) then
                    -- g_logger.info("[News] Updated local news data")
                    return callback(fullNews)
                else
                    return callback(localNews)
                end
            end)
        else
            -- g_logger.info("[News] Local news data is up to date")
            return callback(localNews)
        end
    end)
end

-- /*=============================================
-- =            build treeView                  =
-- =============================================*/


function buildNewsUI(newsData)
    if not newsData or not newsData.gamenews then
        return
    end
    if not treeView then
        g_logger.error("[Compendium] treeView is not initialized")
        return
    end
    treeView:clearCategories()
    
    local categories = {}
    local uniqueCategories = {}
    local contentWidget = compendiumController:findWidget("#optionsTabContent")

    -- Sort MAJOR UPDATES entries by publishdate descending (newest first),
    -- keeping all other entries in their original positions.
    local gamenews = newsData.gamenews
    local majorUpdates = {}
    local majorPositions = {}
    for i, entry in ipairs(gamenews) do
        if entry.category == "MAJOR UPDATES" then
            table.insert(majorUpdates, entry)
            table.insert(majorPositions, i)
        end
    end
    table.sort(majorUpdates, function(a, b)
        return (a.publishdate or 0) > (b.publishdate or 0)
    end)
    local sortedNews = {}
    for i, v in ipairs(gamenews) do sortedNews[i] = v end
    for i, pos in ipairs(majorPositions) do
        sortedNews[pos] = majorUpdates[i]
    end
    
    for _, entry in ipairs(sortedNews) do
        if entry.category then
            uniqueCategories[entry.category] = true
        end
    end
    
    local function setContent(entryId, headline, message)
        clearContentWidget(contentWidget)

        local processedMessage = wrapHtmlContent(processHtmlContent(message))
        contentWidget:html(processedMessage)

        -- Add anchor click handler once
        ensureAnchorHandler(contentWidget)
        
        compendiumController:findWidget("#minipanel"):setTitle(headline)
        currentContentWidget = contentWidget
    end

    for _, entry in ipairs(sortedNews) do
        local catFlags = {
            category = entry.category,
            type = entry.type,
            id = entry.id
        }
        local entryType = entry.type:lower()
        if entryType == "group header" then
            categories[entry.id] = treeView:addCategory(entry.headline, nil, function()
                setContent(entry.id, entry.headline, resolveMessage(entry.message))
            end, nil, catFlags)
        elseif entryType == "regular" or entryType == "returner" then
            local parentCategory = categories[entry.groupheaderid]
            if parentCategory then
                if not catFlags.category and parentCategory.flags and parentCategory.flags.category then
                    catFlags.category = parentCategory.flags.category
                end
                treeView:addSubCategory(parentCategory, entry.headline, nil, function()
                    setContent(entry.id, entry.headline, resolveMessage(entry.message))
                end, nil, catFlags)
            else
                categories[entry.id] = treeView:addCategory(entry.headline, nil, function()
                    setContent(entry.id, entry.headline, resolveMessage(entry.message))
                end, nil, catFlags)
            end
        end
    end

    addOtcContent()
    createCategoryButtons(uniqueCategories)
end
-- /*=============================================
-- =            build Top Button                  =
-- =============================================*/
function createCategoryButtons(uniqueCategories)
    local children = compendiumController.ui.typeCharmPanel:getChildren()
    for _, child in ipairs(children) do
        child:destroy()
    end
    for category, _ in pairs(uniqueCategories) do
        -- Skip empty or invalid categories
        if not category or category == "" then
            goto continue
        end
        
        local button = g_ui.createWidget("ButtonTibia14", compendiumController.ui.typeCharmPanel)
        button:setText(category:gsub("(%a)(%w*)", function(a, b)
            return a:upper() .. b:lower()
        end))
        button:setId(category)
        local imagePath = "images/icon-news-"
        if category == "player guide" then
            imagePath = imagePath .. "game-content"
        else
            imagePath = imagePath .. string.gsub(category, " ", "-")
        end
        
        -- Check if the image file exists before setting it
        local fullPath = "/modules/game_compendium/" .. imagePath
        if g_resources.fileExists(fullPath .. ".png") then
            button.icon:setImageSource(imagePath)
        else
            -- Use a fallback icon if the specific icon doesn't exist
            button.icon:setImageSource("images/icon-news-useful-info")
        end
        
        if string.len(category) > 11 then
            button:setTextOffset("12 0")
        end
        
        ::continue::
    end
    -- Add OTC button
    local otcButton = g_ui.createWidget("ButtonTibia14", compendiumController.ui.typeCharmPanel)
    otcButton:setText("OTC")
    otcButton:setId("OTC")
    otcButton.icon:setImageSource("images/otcicon")
    otcButton.icon:setImageSize("32 32")
    otcButton.icon:setMarginBottom(8)
    
    local TypeCharmRadioGroup = UIRadioGroup.create()
    for _, child in ipairs(compendiumController.ui.typeCharmPanel:getChildren()) do
        TypeCharmRadioGroup:addWidget(child)
    end
    local defaultWidget = compendiumController.ui.typeCharmPanel:getChildById("player guide") or TypeCharmRadioGroup:getFirstWidget()
    if defaultWidget then
        TypeCharmRadioGroup:selectWidget(defaultWidget)
    end

    connect(TypeCharmRadioGroup, {
        onSelectionChange = function(_, selectedWidget)
            local charmCategory = selectedWidget:getId()
            treeView:filterByFlag("category", charmCategory, true)
        end
    })

    if defaultWidget then
        treeView:filterByFlag("category", defaultWidget:getId(), true)
    end
end

function addOtcContent()
    local contentWidget = compendiumController:findWidget("#optionsTabContent")
    
    local function loadOtcRedemption()
        clearContentWidget(contentWidget)
        compendiumController:findWidget("#minipanel"):setTitle("OTC Redemption")
        
        HTTP.get("https://raw.githubusercontent.com/kokekanon/OTredemption-Picture-NODELETE/refs/heads/main/Wiki/readme.html", function(data, err)
            if err then
                warn("[Compendium]: Unable to load OTC Redemption content:\n" .. err)
                contentWidget:html("<p>Failed to load content. Please check your internet connection.</p>")
                return
            end
            contentWidget:html(wrapHtmlContent(data))
            ensureAnchorHandler(contentWidget)
        end)
        
        currentContentWidget = contentWidget
    end
    
    local function loadAttachEffect()
        clearContentWidget(contentWidget)
        compendiumController:findWidget("#minipanel"):setTitle("Attach Effect")
        
        HTTP.get("https://raw.githubusercontent.com/wiki/mehah/otclient/Tutorial-Attached-Effects.md", function(data, err)
            if err then
                warn("[Compendium]: Unable to load Attach Effect content:\n" .. err)
                contentWidget:html("<p>Failed to load content. Please check your internet connection.</p>")
                return
            end
            contentWidget:html(wrapHtmlContent(data))
            ensureAnchorHandler(contentWidget)
        end)
        
        currentContentWidget = contentWidget
    end
    
    local buttons = {{
        text = "OTC Redemption",
        icon = "/images/icons/icon_controls",
        callback = function()
            loadOtcRedemption()
        end,
        flag = {
            category = "OTC",
            type = "regular",
            id = 999,
            autoSelectFirstSubCategory = false
        },
        subCategories = {{
            text = "Attach Effect",
            icon = "/images/icons/icon_controls",
            callback = function()
                loadAttachEffect()
            end,
            flag = {
                category = "OTC",
                type = "regular",
                id = 998
            }
        }}
    }}
    treeView:createFromArray(buttons, false)
end
