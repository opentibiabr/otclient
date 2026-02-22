-- UITreeView class with flags and filtering support
-- Handles hierarchical data display with categories and subcategories
UITreeView = extends(UIWidget, 'UITreeView')

function UITreeView.create()
    local treeview = UITreeView.internalCreate()
    treeview:setFocusable(false)
    treeview:setPhantom(true)
    treeview.categories = {}
    treeview.selectedCategory = nil
    treeview.openedCategory = nil
    treeview.selectedSubCategory = nil
    treeview.categorySpacing = 20
    treeview.subCategoryIndentation = 15
    treeview.useSubCategoryIndentation = false
    treeview.autoSelectFirstSubCategory = false
    treeview.activeFilters = {}
    treeview.currentContent = nil
    treeview.getMargin = 5
    local layout = UIVerticalLayout.create(treeview)
    layout:setFitChildren(true)
    treeview:setLayout(layout)
    treeview.widgetCache = {}
    return treeview
end

-- BASIC CONFIGURATION METHODS

-- Sets whether the first subcategory should be automatically selected (global setting)
function UITreeView:setAutoSelectFirstSubCategory(autoSelect)
    self.autoSelectFirstSubCategory = autoSelect
    return self
end

-- Gets the auto-select first subcategory setting (global setting)
function UITreeView:getAutoSelectFirstSubCategory()
    return self.autoSelectFirstSubCategory
end

-- Sets whether the first subcategory should be automatically selected for a specific category
function UITreeView:setCategoryAutoSelectFirstSubCategory(category, autoSelect)
    if category then
        category.autoSelectFirstSubCategory = autoSelect
    end
    return self
end

-- Gets the auto-select first subcategory setting for a specific category
function UITreeView:getCategoryAutoSelectFirstSubCategory(category)
    if category then
        return category.autoSelectFirstSubCategory
    end
    return nil
end

-- Setup the tree view with parent and content widget
function UITreeView:setup(parent, contentWidget)
    if parent then
        self:setParent(parent)
        self:setSize(parent:getSize())
    end

    if contentWidget then
        self.contentWidget = contentWidget
    end

    return self
end

-- WIDGET CACHE MANAGEMENT

-- Caches a widget by ID for faster future lookups
function UITreeView:cacheWidget(id, widget)
    if id and widget then
        self.widgetCache[id] = widget
    end
    return self
end

-- Clears the widget cache
function UITreeView:clearWidgetCache()
    self.widgetCache = {}
    return self
end

-- Gets a widget from cache or finds it if not cached
function UITreeView:getWidgetById(id)
    if not id then
        return nil
    end

    if self.widgetCache[id] then
        return self.widgetCache[id]
    end

    local widget = nil
    if self.contentWidget then
        widget = self.contentWidget:recursiveGetChildById(id)
    end

    if widget then
        self:cacheWidget(id, widget)
    end
    return widget
end

-- Sets the content widget by ID
function UITreeView:setContentById(contentId)
    if not contentId then
        return self
    end

    local contentWidget = self:getWidgetById(contentId)
    if contentWidget then
        self.contentWidget = contentWidget
    end

    return self
end

-- Sets spacing between categories
function UITreeView:setCategorySpacing(spacing)
    self.categorySpacing = spacing
    self:getLayout():setSpacing(spacing)
    return self
end

-- Gets the category spacing value
function UITreeView:getCategorySpacing()
    return self.categorySpacing
end

function UITreeView:setMargin(margin)
    self.getMargin = margin
    return self
end

-- Gets the category spacing value
function UITreeView:getMargin()
    return self.getMargin
end

-- Sets indentation for subcategories
function UITreeView:setSubCategoryIndentation(indent)
    self.subCategoryIndentation = indent
    self:updateSubCategoryWidths()
    return self
end

-- Gets the subcategory indentation value
function UITreeView:getSubCategoryIndentation()
    return self.subCategoryIndentation
end

-- Enables or disables subcategory indentation
function UITreeView:setUseSubCategoryIndentation(useIndent)
    self.useSubCategoryIndentation = useIndent
    self:updateSubCategoryWidths()
    return self
end

-- Gets whether subcategory indentation is enabled
function UITreeView:getUseSubCategoryIndentation()
    return self.useSubCategoryIndentation
end

-- FLAG MANAGEMENT METHODS

-- Checks if a widget has a specific flag
function UITreeView:hasFlag(widget, flagName)
    return widget.flags and widget.flags[flagName] ~= nil
end

-- Gets the value of a specific flag from a widget
function UITreeView:getFlag(widget, flagName)
    return widget.flags and widget.flags[flagName]
end

-- Adds a flag to a widget
function UITreeView:addFlag(widget, flagName, value)
    if not widget.flags then
        widget.flags = {}
    end

    widget.flags[flagName] = value or true
    return self
end

-- Removes a flag from a widget
function UITreeView:removeFlag(widget, flagName)
    if widget.flags then
        widget.flags[flagName] = nil
    end
    return self
end

-- Clears all flags from a widget
function UITreeView:clearFlags(widget)
    widget.flags = {}
    return self
end

-- CATEGORY AND SUBCATEGORY MANAGEMENT

-- Sets up the UI elements for a button (used by categories and subcategories)
function UITreeView:setupButton(category, text, icon)
    category:setId(text:gsub(" ", "_"))
    -- Only set image source if icon is provided and not empty
    if icon and icon ~= "" then
        category.Button.Icon:setImageSource(icon)
    else
        category.Button.Icon:setVisible(false)
    end
    category.Button.Title:setText(text)
    category.Button.Arrow:setVisible(false)

    category.Button.Title:addAnchor(AnchorRight, "parent", AnchorRight)
    category.Button.Title:setMarginRight(20)
end

-- Adds a new category to the tree
function UITreeView:addCategory(text, icon, callback, content, flags)
    local category = g_ui.createWidget('TreeCategory', self)
    category:setMarginRight(self.getMargin)
    category:setMarginLeft(self.getMargin)
    self:setupButton(category, text, icon)

    category.subCategories = {}
    category.callback = callback
    category.content = content

    if type(content) == "string" then
        local contentWidget = self:getWidgetById(content)
        if contentWidget then
            self:cacheWidget(content, contentWidget)
        end
    end

    category.flags = flags or {}

    category.autoSelectFirstSubCategory = category.flags.autoSelectFirstSubCategory

    category.subCategoryContainer = g_ui.createWidget('SubCategoryContainer', self)
    function category.Button.onClick()
        self:selectCategory(category)
    end

    table.insert(self.categories, category)
    return category
end

-- Adds a subcategory to an existing category
function UITreeView:addSubCategory(category, text, icon, callback, content, flags)
    if not category.subCategories then
        category.subCategories = {}
    end

    local subCategory = g_ui.createWidget('TreeSubCategory', category.subCategoryContainer)

    self:setupButton(subCategory, text, icon)
    if not self.useSubCategoryIndentation then
        subCategory:setMarginRight(self.getMargin)
        subCategory:setMarginLeft(self.getMargin)
        category.subCategoryContainer:setBorderWidth(0)
    end
    subCategory.callback = callback
    subCategory.content = content

    if type(content) == "string" then
        local contentWidget = self:getWidgetById(content)
        if contentWidget then
            self:cacheWidget(content, contentWidget)
        end
    end

    subCategory.flags = flags or {}

    self:updateSubCategoryWidth(category, subCategory)

    subCategory.Button.Arrow:setVisible(false)

    if #category.subCategories == 0 then
        category.Button.Arrow:setVisible(true)
        category.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-down")
        category.closedSize = category:getHeight()
    end

    table.insert(category.subCategories, subCategory)

    function subCategory.Button.onClick()
        self:selectSubCategory(category, subCategory)
    end

    return subCategory
end

-- Updates the width of a subcategory based on indentation settings
function UITreeView:updateSubCategoryWidth(category, subCategory)
    if self.useSubCategoryIndentation then
        subCategory:getParent():setPaddingLeft(self.subCategoryIndentation)
        subCategory:getParent():setMarginLeft(self.getMargin + self.subCategoryIndentation)
    end
end

-- Updates all subcategory widths based on current settings
function UITreeView:updateSubCategoryWidths()
    for _, category in ipairs(self.categories) do
        if category.subCategories then
            for _, subCategory in ipairs(category.subCategories) do
                self:updateSubCategoryWidth(category, subCategory)
            end
        end
    end
end

-- CATEGORY AND SUBCATEGORY INTERACTION

-- Toggles the visibility of subcategories for a given category
function UITreeView:toggleSubCategories(category, isOpen)
    if not category then
        return
    end
    if category.autoSelectFirstSubCategory and isOpen then
        category.opened = isOpen
    end
    category.subCategoryContainer:setVisible(isOpen)

    if not isOpen then
        category.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-down")
    end
end

-- Closes a category (hides its subcategories)
function UITreeView:closeCategory(category)
    if not category or table.empty(category.subCategories) then
        return
    end

    self:toggleSubCategories(category, false)
end

-- Opens a category (shows its subcategories)
function UITreeView:openCategory(category)
    if not category or table.empty(category.subCategories) then
        return
    end

    local oldOpen = self.openedCategory

    if oldOpen and oldOpen ~= category then
        if oldOpen.Button then
            oldOpen.Button:setChecked(false)
            oldOpen.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-down")
        end
        self:closeCategory(oldOpen)
    end

    self:toggleSubCategories(category, true)
    self.openedCategory = category
end

-- Resolves a content reference to a widget
function UITreeView:resolveContent(content)
    if not content then
        return nil
    end

    if type(content) ~= "string" then
        return content
    end

    return self:getWidgetById(content)
end

-- Selects a category and displays its content
function UITreeView:selectCategory(category)
    local oldOpen = self.openedCategory
    if oldOpen and oldOpen ~= category then
        if oldOpen.Button then
            oldOpen.Button:setChecked(false)
            oldOpen.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-down")
        end
        self:closeCategory(oldOpen)
    end
    self:closeAllSubCategoryButtons()

    local oldSelected = self.selectedCategory
    if oldSelected and oldSelected ~= category then
        oldSelected.Button:setChecked(false)
    end

    category.Button:setChecked(true)
    self.selectedCategory = category

    if self.currentContent then
        self.currentContent:hide()
        self.currentContent:setVisible(false)
    end

    if category.callback then
        category.callback()
    end

    if category.subCategories and #category.subCategories > 0 then
        if category.opened then
            self:closeCategory(category)
        else
            self:openCategory(category)

            local shouldAutoSelect = category.autoSelectFirstSubCategory
            if shouldAutoSelect == nil then
                shouldAutoSelect = self.autoSelectFirstSubCategory
            end

            if shouldAutoSelect and #category.subCategories > 0 then
                if not category.content then
                    self:selectSubCategory(category, category.subCategories[1])
                    return
                end
            end
        end
    end

    if self.contentWidget and category.content then
        self.currentContent = self:resolveContent(category.content)

        if self.currentContent then
            self.currentContent:show()
            self.currentContent:setVisible(true)
            self.currentContent:raise()
        end
    end
end

-- Selects a subcategory and displays its content
function UITreeView:selectSubCategory(category, subCategory)
    -- Safety checks - silently return if widgets are invalid (e.g., after clearCategories)
    if not category or not category.Button or category:isDestroyed() then
        return
    end
    if not subCategory or not subCategory.Button or subCategory:isDestroyed() then
        return
    end
    
    self:closeAllSubCategoryButtons()

    local oldSelected = self.selectedSubCategory
    if oldSelected and oldSelected ~= subCategory then
        if oldSelected.Button and not oldSelected:isDestroyed() then
            oldSelected.Button:setChecked(false)
            oldSelected.Button.Arrow:setVisible(false)
        end
    end

    if not category.opened then
        self:openCategory(category)
    end

    category.Button:setChecked(false)
    category.Button.Arrow:setVisible(true)

    subCategory.Button:setChecked(true)
    subCategory.Button.Arrow:setVisible(true)
    subCategory.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-right")

    if self.useSubCategoryIndentation then
        subCategory.Button.Arrow:setVisible(false)
        if subCategory.Arrow then
            subCategory.Arrow:setVisible(true)
        end
    end

    self.selectedSubCategory = subCategory

    if self.currentContent then
        self.currentContent:hide()
        self.currentContent:setVisible(false)
    end

    if subCategory.callback then
        subCategory.callback()
    end

    if self.contentWidget and subCategory.content then
        self.currentContent = self:resolveContent(subCategory.content)

        if self.currentContent then
            self.currentContent:show()
            self.currentContent:setVisible(true)
            self.currentContent:raise()
        end
    end
end

function UITreeView:closeAllSubCategoryButtons()
    for _, category in ipairs(self.categories) do
        if category.subCategories then
            for _, subCategory in ipairs(category.subCategories) do
                if subCategory.Button then
                    subCategory.Button:setChecked(false)
                    if subCategory.Button.Arrow then
                        subCategory.Button.Arrow:setVisible(false)
                        if subCategory.Arrow then
                            subCategory.Arrow:setVisible(false)
                        end
                    end
                end
            end
        end
    end
end

-- SELECTION METHODS

function UITreeView:selectCategoryById(id)
    for _, category in ipairs(self.categories) do
        if category:getId() == id then
            self:selectCategory(category)
            return true
        end
    end
    return false
end

function UITreeView:selectSubCategoryById(categoryId, subCategoryId)
    for _, category in ipairs(self.categories) do
        if category:getId() == categoryId and category.subCategories then
            for _, subCategory in ipairs(category.subCategories) do
                if subCategory:getId() == subCategoryId then
                    self:openCategory(category)
                    self:selectSubCategory(category, subCategory)
                    return true
                end
            end
        end
    end
    return false
end

function UITreeView:getSelectedCategory()
    return self.selectedCategory
end

function UITreeView:getSelectedSubCategory()
    return self.selectedSubCategory
end

function UITreeView:findAndSelectSubCategoryByName(categoryName, subCategoryName)
    for _, category in ipairs(self.categories) do
        if category.Button.Title:getText() == categoryName then
            for _, subCategory in ipairs(category.subCategories) do
                if subCategory.Button.Title:getText() == subCategoryName then
                    self:selectSubCategory(category, subCategory)
                    return true
                end
            end
        end
    end
    return false
end

-- LAYOUT MANAGEMENT

-- Updates the layout to reflect current visibility and sizing
function UITreeView:updateLayout()
    self:getLayout():update()
end

-- Collapses all categories (hides all subcategories)
function UITreeView:collapseAll()
    for _, category in ipairs(self.categories) do
        self:closeCategory(category)
    end
end

-- Expands all categories (shows all subcategories)
function UITreeView:expandAll()
    for _, category in ipairs(self.categories) do
        self:openCategory(category)
    end
end

-- Clears all categories and resets the tree view
function UITreeView:clearCategories()
    for _, category in ipairs(self.categories) do
        category:destroy()
    end
    self.categories = {}
    self.selectedCategory = nil
    self.openedCategory = nil
    self.selectedSubCategory = nil
    if self.currentContent then
        self.currentContent:hide()
        self.currentContent = nil
    end
    return self
end

-- Gets all categories in the tree view
function UITreeView:getAllCategories()
    return self.categories
end

-- CONTENT MANAGEMENT

-- Finds a content widget by ID or returns the widget directly
function UITreeView:findContentWidget(contentIdOrWidget)
    if not contentIdOrWidget then
        return nil
    end

    if type(contentIdOrWidget) ~= "string" then
        return contentIdOrWidget
    end

    return self:getWidgetById(contentIdOrWidget)
end

-- Displays content by ID or widget reference
function UITreeView:displayContent(contentIdOrWidget)
    if self.currentContent then
        self.currentContent:hide()
        self.currentContent:setVisible(false)
    end

    local newContent = self:findContentWidget(contentIdOrWidget)
    if newContent then
        self.currentContent = newContent
        self.currentContent:show()
        self.currentContent:setVisible(true)
        self.currentContent:raise()
        return true
    end

    return false
end

-- FILTERING METHODS

-- Filters items by flag name and value
function UITreeView:filterByFlag(flagName, flagValue, selectFirstVisible)
    self.activeFilters.flag = {
        name = flagName,
        value = flagValue
    }

    self:applyFilters()

    if selectFirstVisible then
        for _, category in ipairs(self.categories) do
            if category:isVisible() then
                self:selectCategory(category)
                break
            end
        end
    end

    return self
end

-- Filters items by text
function UITreeView:filterByText(searchText)
    self.activeFilters.text = searchText:lower()
    self:applyFilters()
    return self
end

-- Applies all active filters
function UITreeView:applyFilters()
    local activeFlag = self.activeFilters.flag
    local activeText = self.activeFilters.text

    for _, category in ipairs(self.categories) do
        local showCategory = true

        if activeFlag then
            local val = activeFlag.value
            if val == nil then
                showCategory = self:hasFlag(category, activeFlag.name)
            else
                showCategory = (self:getFlag(category, activeFlag.name) == val)
            end
        end

        if showCategory and activeText then
            showCategory = category.Button.Title:getText():lower():find(activeText) ~= nil
        end

        local showSubCategories = false
        if category.subCategories then
            for _, subCategory in ipairs(category.subCategories) do
                local showSubCategory = true

                if activeFlag then
                    local val = activeFlag.value
                    if val == nil then
                        showSubCategory = self:hasFlag(subCategory, activeFlag.name)
                    else
                        showSubCategory = (self:getFlag(subCategory, activeFlag.name) == val)
                    end
                end

                if showSubCategory and activeText then
                    showSubCategory = subCategory.Button.Title:getText():lower():find(activeText) ~= nil
                end

                subCategory:setVisible(showSubCategory)
                if showSubCategory then
                    showSubCategories = true
                end
            end
        end

        category:setVisible(showCategory or showSubCategories)
    end

    self:updateLayout()
    return self
end

-- Clears all active filters
function UITreeView:clearFilters()
    self.activeFilters = {}

    for _, category in ipairs(self.categories) do
        category:setVisible(true)

        if category.subCategories then
            for _, subCategory in ipairs(category.subCategories) do
                subCategory:setVisible(true)
            end
        end

        if category.subCategoryContainer then
            category.subCategoryContainer:setVisible(false)
            category.opened = false
            if category.Button.Arrow then
                category.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-down")
            end
        end
    end

    self:updateLayout()
    return self
end

-- Filters by multiple criteria
function UITreeView:filter(options)
    self.activeFilters = {}

    if options.flag then
        self.activeFilters.flag = {
            name = options.flag.name,
            value = options.flag.value
        }
    end

    if options.text then
        self.activeFilters.text = options.text:lower()
    end

    self:applyFilters()
    return self
end

-- BULK CREATION METHODS

-- Creates categories and subcategories from an array of data
function UITreeView:createFromArray(buttonsArray, clearExisting)
    if clearExisting ~= false then
        self:clearCategories()
    end

    self.initialSelections = nil

    for _, categoryData in ipairs(buttonsArray) do
        local category = self:addCategory(categoryData.text, categoryData.icon, categoryData.callback,
            categoryData.content, categoryData.flags or categoryData.flag)

        if categoryData.flags and categoryData.flags.autoSelectFirstSubCategory ~= nil then
            category.autoSelectFirstSubCategory = categoryData.flags.autoSelectFirstSubCategory
        elseif categoryData.flag and categoryData.flag.autoSelectFirstSubCategory ~= nil then
            category.autoSelectFirstSubCategory = categoryData.flag.autoSelectFirstSubCategory
        end

        if categoryData.subCategories then
            for _, subCategoryData in ipairs(categoryData.subCategories) do
                local subCategory = self:addSubCategory(category, subCategoryData.text, subCategoryData.icon,
                    subCategoryData.callback, subCategoryData.content, subCategoryData.flags or subCategoryData.flag)

                if subCategoryData.open then
                    if not self.initialSelections then
                        self.initialSelections = {}
                    end
                    table.insert(self.initialSelections, {
                        category = category,
                        subCategory = subCategory,
                        content = subCategoryData.open
                    })
                end
            end
        end

        if categoryData.open then
            if not self.initialSelections then
                self.initialSelections = {}
            end
            table.insert(self.initialSelections, {
                category = category,
                content = categoryData.open
            })
        end
    end

    self:processInitialSelections()

    self:updateLayout()

    return self
end

-- Processes initial selections for categories/subcategories
function UITreeView:processInitialSelections()
    if not self.initialSelections then
        return
    end

    for _, selection in ipairs(self.initialSelections) do
        if selection.subCategory then
            self:openCategory(selection.category)
            self:selectSubCategory(selection.category, selection.subCategory)

            if selection.content then
                self:displayContent(selection.content)
            end
        else
            self:selectCategory(selection.category)

            if selection.content then
                self:displayContent(selection.content)
            end
        end
    end

    self.initialSelections = nil
end

-- HELPER FUNCTIONS FOR EXTERNAL MODULE USAGE

-- Finds a category by name
function UITreeView:findCategoryByName(categoryName)
    for _, category in ipairs(self.categories) do
        if category.Button.Title:getText() == categoryName then
            return category
        end
    end
    return nil
end

-- Finds a subcategory by name within a category
function UITreeView:findSubCategoryByName(category, subCategoryName)
    if not category or not category.subCategories then
        return nil
    end

    for _, subCategory in ipairs(category.subCategories) do
        if subCategory.Button.Title:getText() == subCategoryName then
            return subCategory
        end
    end
    return nil
end

-- Adds a button (category or subcategory) with position control
function UITreeView:addCategoryOrSubCategory(categoryName, subCategoryName, content, callback, icon, position)
    local category = self:findCategoryByName(categoryName)
    if not category then
        category = self:addCategory(categoryName, icon or nil, nil, nil)

        if position and not subCategoryName then
            self:repositionCategory(category, position)
        end
    end

    if not subCategoryName then
        if callback then
            category.callback = callback
        end
        if content then
            category.content = content
            if type(content) == "string" then
                local contentWidget = self:getWidgetById(content)
                if contentWidget then
                    self:cacheWidget(content, contentWidget)
                end
            end
        end

        return category
    end

    -- Handle subcategory
    local subCategory = self:findSubCategoryByName(category, subCategoryName)
    if not subCategory then
        -- Create new subcategory if it doesn't exist
        subCategory = self:addSubCategory(category, subCategoryName, icon or nil, callback, content)

        if position then
            self:repositionSubCategory(category, subCategory, position)
        end
    else
        if callback then
            subCategory.callback = callback
        end
        if content then
            subCategory.content = content
            if type(content) == "string" then
                local contentWidget = self:getWidgetById(content)
                if contentWidget then
                    self:cacheWidget(content, contentWidget)
                end
            end
        end
    end

    return subCategory
end

function UITreeView:enableOrDisableAllButtons(enable)
    for _, category in ipairs(self.categories) do
        category.Button:setEnabled(enable)
        if category.subCategories then
            for _, subCategory in ipairs(category.subCategories) do
                subCategory.Button:setEnabled(enable)
            end
        end
    end
end

-- Removes a category or subcategory
function UITreeView:removeCategoryOrSubCategory(categoryName, subCategoryName, contentToDestroy)
    local category = self:findCategoryByName(categoryName)
    if not category then
        return false
    end

    if not subCategoryName then
        if self.selectedCategory == category then
            self.selectedCategory = nil
        end
        if self.openedCategory == category then
            self.openedCategory = nil
        end

        if category.subCategories then
            for _, subCategory in ipairs(category.subCategories) do
                if subCategory.content and type(subCategory.content) ~= "string" and contentToDestroy then
                    subCategory.content:destroy()
                end

                if self.selectedSubCategory == subCategory then
                    self.selectedSubCategory = nil
                end
            end
        end

        if category.content and type(category.content) ~= "string" and contentToDestroy then
            category.content:destroy()
        end

        for i, cat in ipairs(self.categories) do
            if cat == category then
                table.remove(self.categories, i)
                break
            end
        end

        category:destroy()
        self:updateLayout()
        return true
    end

    local subCategory = self:findSubCategoryByName(category, subCategoryName)
    if not subCategory then
        return false
    end

    if self.selectedSubCategory == subCategory then
        self.selectedSubCategory = nil
    end

    if subCategory.content and type(subCategory.content) ~= "string" and contentToDestroy then
        subCategory.content:destroy()
    end
    for i, sub in ipairs(category.subCategories) do
        if sub == subCategory then
            table.remove(category.subCategories, i)
            break
        end
    end
    subCategory:destroy()
    if #category.subCategories == 0 and category.Button.Arrow then
        category.Button.Arrow:setVisible(false)
    end

    self:updateLayout()
    return true
end

