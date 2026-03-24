HtmlSample = Controller:new()
HtmlSample.showEqualizerEffect = true
HtmlSample.isMainTab = true
HtmlSample.isExamplesTab = false
HtmlSample.exampleBasePath = '/docs/exampleHTML_flex/'

function HtmlSample:isThingsLoaded()
    return modules.game_things and modules.game_things.isLoaded()
end

function HtmlSample:onInit()
    self.playerName = ''
    self.lookType = ''
    self.players = {}

    self.title = "HTML/CSS"
    self.msg = "Welcome to HTML/CSS"
    self.height = 350
    self.width = 500
    self.isMainTab = true
    self.isExamplesTab = false

    self:loadHtml('htmlsample.html')
    self:equalizerEffect()

    self:setupExamplesComboBox()
end

function HtmlSample:selectTab(tab)
    local isExamples = tab == 'examples'
    
    self.isMainTab = not isExamples
    self.isExamplesTab = isExamples
    self.height = isExamples and 650 or 350
    self.width = isExamples and 900 or 500
    -- Explicitly resize the window to ensure it updates immediately
    
    if isExamples then
        -- Defer render until visibility/layout settle for the examples tab.
        self:scheduleEvent(function()
            if self.isExamplesTab then
                self:renderSelectedExample()
            end
        end, 111)
    end
end

function HtmlSample:setupExamplesComboBox()
    local combo = self:findWidget('#exampleComboBox')
    if not combo then
        return
    end

    combo:clearOptions()

    local files = g_resources.listDirectoryFiles(self.exampleBasePath)
    local htmlFiles = {}

    for _, file in ipairs(files) do
        if g_resources.isFileType(file, 'html') then
            table.insert(htmlFiles, file)
        end
    end

    table.sort(htmlFiles)

    for _, file in ipairs(htmlFiles) do
        combo:addOption(file, { file = file })
    end

    self.selectedExampleFile = htmlFiles[1]

    if self.selectedExampleFile then
        combo:setCurrentOption(self.selectedExampleFile, true)
        if self.isExamplesTab then
            self:renderSelectedExample()
        end
    else
        self:showExampleMessage('No .html files found in ejemplosFlex.')
    end
end

function HtmlSample:onExampleComboBoxChange(event)
    local option = event.target and event.target:getCurrentOption()
    if not option then
        return
    end

    self.selectedExampleFile = option.data and option.data.file or event.text
    self:renderSelectedExample()
end

function HtmlSample:showExampleMessage(message)
    local preview = self:findWidget('#examplePreview')
    if not preview then
        return
    end

    preview:destroyChildren()
    self:createWidgetFromHTML('<div style="padding: 10; color: #cfcfcf">' .. message .. '</div>', preview)
end

function HtmlSample:renderSelectedExample()
    local preview = self:findWidget('#examplePreview')
    if not preview then
        return
    end

    preview:destroyChildren()

    if not self.selectedExampleFile or #self.selectedExampleFile == 0 then
        self:showExampleMessage('Select an example to preview.')
        return
    end

    local filePath = self.exampleBasePath .. self.selectedExampleFile
    if not g_resources.fileExists(filePath) then
        self:showExampleMessage('File not found: ' .. self.selectedExampleFile)
        return
    end

    local html = g_resources.readFileContents(filePath)
    if not html or #html == 0 then
        self:showExampleMessage('File is empty: ' .. self.selectedExampleFile)
        return
    end

    local root = self:createWidgetFromHTML(html, preview)
    local function refreshPreviewLayout()
        if not preview or preview:isDestroyed() then
            return
        end

        if root and not root:isDestroyed() then
            if root.updateLayout then
                root:updateLayout()
            end
            if root.updateParentLayout then
                root:updateParentLayout()
            end
        end

        if preview.updateLayout then
            preview:updateLayout()
        end
        if preview.updateScrollBars then
            preview:updateScrollBars()
        end
    end

    self:scheduleEvent(refreshPreviewLayout, 1)
    self:scheduleEvent(refreshPreviewLayout, 30)
    self:scheduleEvent(refreshPreviewLayout, 80)
end

function HtmlSample:addPlayer(name)
    if not name or #name == 0 then
        return
    end

    table.insert(self.players, {
        name = name,
        lookType = self.lookType
    })

    self.playerName = ''
end

function HtmlSample:removePlayer(index)
    table.remove(self.players, index)
end

function HtmlSample:equalizerEffect()
    local widgets = self:findWidgets('.line')

    for _, widget in pairs(widgets) do
        local minV = math.random(0, 30)
        local maxV = math.random(70, 100)
        if minV > maxV then minV, maxV = maxV, minV end

        local range = maxV - minV
        local speed = math.max(1, math.floor(range / 20)) + math.random(0, 1)

        local value = math.random(minV, maxV)
        local dir   = (math.random(0, 1) == 0) and -1 or 1
        self:cycleEvent(function()
            if widget:isDestroyed() then
                return false
            end

            value = value + dir * speed
            if value >= maxV then
                value = maxV
                dir = -1
            elseif value <= minV then
                value = minV
                dir = 1
            end

            widget:setHeight(10 + value)
            widget:setTop(89 - value)
        end, 30)
    end
end
