HtmlSample = Controller:new()
HtmlSample.showEqualizerEffect = true
HtmlSample.isMainTab = true
HtmlSample.isExamplesTab = false
HtmlSample.isResponsiveTab = false
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
    self.isResponsiveTab = false
    self.responsiveWidth = 480
    self.responsiveDirection = -1

    self:loadHtml('htmlsample.html')
    self:equalizerEffect()

    self:setupExamplesComboBox()
    self:setupResponsiveDemo()
end

function HtmlSample:selectTab(tab)
    local isExamples = tab == 'examples'
    local isResponsive = tab == 'responsive'

    self.isMainTab = not isExamples and not isResponsive
    self.isExamplesTab = isExamples
    self.isResponsiveTab = isResponsive
    self.height = (isExamples or isResponsive) and 650 or 350
    self.width = (isExamples or isResponsive) and 900 or 500

    if self.ui and not self.ui:isDestroyed() then
        self.ui:setHeight(self.height)
        self.ui:setWidth(self.width)
    end

    if isExamples then
        -- Defer render until visibility/layout settle for the examples tab.
        self:scheduleEvent(function()
            if self.isExamplesTab then
                self:renderSelectedExample()
            end
        end, 111)
    elseif isResponsive then
        self:scheduleEvent(function()
            self:updateResponsiveViewport()
            self:startResponsiveDemo()
        end, 1)
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
        self:showExampleMessage('No .html files found in ' .. self.exampleBasePath)
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

function HtmlSample:setupResponsiveDemo()
    local viewport = self:findWidget('#responsiveViewport')
    if not viewport then
        return
    end

    viewport:destroyChildren()

    local palette = {
          "red",
    "blue",
    "green",
    "darkorange",
    "purple",
    "darkred",
    "teal",
    "navy",
    "maroon",
    "darkgreen",
    "brown",
    "darkslategray",
    "crimson",
    "darkviolet",
    "firebrick",
    "midnightblue",
    "sienna",
    "darkolivegreen",
    "indigo",
    "darkslateblue",
    }

    for i = 1, 30 do
        local width = math.random(10, 78)
        local color = palette[math.random(1, #palette)]
        self:createWidgetFromHTML(string.format(
            '<div class="responsiveBox" style="width: %dpx; background-color: %s;"></div>',
            width,
            color
        ), viewport)
    end

    self:updateResponsiveViewport()
end

function HtmlSample:updateResponsiveViewport()
    local viewport = self:findWidget('#responsiveViewport')
    if not viewport or viewport:isDestroyed() then
        return
    end

    viewport:setWidth(self.responsiveWidth)

    local widthLabel = self:findWidget('#responsiveWidthLabel')
    if widthLabel and not widthLabel:isDestroyed() then
        widthLabel:setText(string.format('Width: %dpx', self.responsiveWidth))
    end
end

function HtmlSample:startResponsiveDemo()
    self:cycleEvent(function()
        if not self.ui or self.ui:isDestroyed() then
            return false
        end
        local viewport = self:findWidget('#responsiveViewport')
        if not viewport or viewport:isDestroyed() then
            return false
        end

        if not self.isResponsiveTab then
            return false
        end

        self.responsiveWidth = self.responsiveWidth + self.responsiveDirection * 24
        if self.responsiveWidth <= 220 then
            self.responsiveWidth = 220
            self.responsiveDirection = 1
        elseif self.responsiveWidth >= 760 then
            self.responsiveWidth = 760
            self.responsiveDirection = -1
        end

        self:updateResponsiveViewport()
    end, 90, 'responsive-demo')
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
