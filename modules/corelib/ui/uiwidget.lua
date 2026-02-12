-- @docclass UIWidget
function UIWidget:setMargin(...)
    local params = { ... }
    if #params == 1 then
        self:setMarginTop(params[1])
        self:setMarginRight(params[1])
        self:setMarginBottom(params[1])
        self:setMarginLeft(params[1])
    elseif #params == 2 then
        self:setMarginTop(params[1])
        self:setMarginRight(params[2])
        self:setMarginBottom(params[1])
        self:setMarginLeft(params[2])
    elseif #params == 4 then
        self:setMarginTop(params[1])
        self:setMarginRight(params[2])
        self:setMarginBottom(params[3])
        self:setMarginLeft(params[4])
    end
end

function UIWidget:setTitle(title)
    self:setText(title)
    self:setTextAlign(AlignTopCenter)
    self:setColor("#c0c0c0")
end

function UIWidget:parseColoredText(text, default_color)
    default_color = default_color or "#ffffff"
    local result, last_pos = "", 1
    for start, stop in text:gmatch("()%[color=#?%x+%]()") do
        if start > last_pos then
            result = result .. "{" .. text:sub(last_pos, start - 1) .. ", " .. default_color .. "}"
        end
        local closing_tag_start = text:find("%[/color%]", stop)
        if not closing_tag_start then break end
        local content = text:sub(stop, closing_tag_start - 1)
        local color = text:match("#%x+", start) or default_color
        result = result .. "{" .. content .. ", " .. color .. "}"
        last_pos = closing_tag_start + 8
    end
    if last_pos <= #text then
        result = result .. "{" .. text:sub(last_pos) .. ", " .. default_color .. "}"
    end
    self:setColoredText(result)
end

local FOR_CTX = {
    __keys = '',
    __values = nil
}

local function apply_for_ctx_to_new_tree(controller, html_insert_fn)
    if not controller then return html_insert_fn() end
    controller.__current_for_ctx = {
        keys   = FOR_CTX.__keys,
        values = FOR_CTX.__values
    }
    local w = html_insert_fn()
    controller.__current_for_ctx = nil
    return w
end

local function ExprHandlerError(runtime, error, widget, controller, nodeStr, onError)
    if runtime then
        error = "[Script runtime error]\n" .. error
    end
    if onError then error = error .. '\n' .. onError() end
    error = error .. '\nWidget[#' .. widget:getId() .. ']:\n\n' .. nodeStr
    pwarning(error .. "\n\n------------------------------------")
end

local function check_load(expr, chunkName, mode, env)
    if _VERSION == 'Lua 5.1' and loadstring then
        local fn, err = loadstring(expr, chunkName)
        if fn and env then setfenv(fn, env) end
        return fn, err
    end
    return load(expr, chunkName, mode or 'bt', env)
end

local function getFncByExpr(exp, nodeStr, widget, controller, onError)
    local f, syntaxErr = check_load(exp,
        ("Controller: %s | %s"):format(controller.name, controller.dataUI.name))
    if not f then
        ExprHandlerError(false, syntaxErr, widget, controller, nodeStr, onError)
        return
    end
    return f()
end

local function execFnc(f, args, widget, controller, nodeStr, onError)
    if not f or not args then
        return
    end
    local success, value = xpcall(function()
        return f(unpack(args))
    end, function(e) return "Erro: " .. tostring(e) end)
    if not success then
        ExprHandlerError(true, value, widget, controller, nodeStr, onError)
    end
    return value, success
end

function UIWidget:__onHtmlProcessFinished(inheritedStyles)
    self.inheritedStyles = inheritedStyles
end

function UIWidget:__applyOrBindHtmlAttribute(attr, value, isInheritable, controllerName, NODE_STR)
    local controller = G_CONTROLLER_CALLED[controllerName]

    if attr == 'image-source' then
        if value:starts('http://') or value:starts('https://') then
            HTTP.downloadImage(value, function(path, err)
                if err then
                    g_logger.warning('HTTP error: ' .. err .. ' - ' .. value)
                    return
                end

                if self:isDestroyed() then
                    return
                end

                self:setImageSource(path)
            end)
            return
        elseif not value:starts('/') and not value:starts('\\') then
            value = '/modules/' .. controller.name .. '/' .. value
        end
    end

    local setterName = ''
    for _, _name in pairs(attr:trim():split('-')) do
        setterName = setterName .. _name:gsub("^%l", string.upper)
    end

    local watchObj = nil

    local isBinding = setterName:starts('*')
    if isBinding then
        setterName = setterName:sub(2):gsub("^%l", string.upper)
        local success = true
        local fnc = getFncByExpr('return function(self, target ' .. FOR_CTX.__keys .. ') return ' .. value .. ' end',
            NODE_STR, self, controller, function()
                return ('Attribute Error[%s]: %s'):format(attr, value)
            end)

        if self:isVisible() then
            local valueExpr = FOR_CTX.__values or {}
            value, success = execFnc(fnc, { controller, self, unpack(valueExpr) }, self,
                roller, NODE_STR,
                function()
                    return ('Attribute Error[%s]: %s'):format(attr, value)
                end)
        else
            value = nil
        end

        if not success then return end

        watchObj = {
            widget = self,
            res = value,
            method = nil,
            methodName = setterName:lower(),
            attr = attr:sub(2),
            htmlId = self:getHtmlId(),
            valueExpr = FOR_CTX.__values or {},
            fnc = function(self)
                local value = fnc(controller, self.widget, unpack(self.valueExpr))
                if value ~= self.res then
                    self.method(self.widget, value)
                    self.res = value
                end
            end
        }
    elseif value == '' or value == 'true' or value == setterName then
        value = true
    elseif value == 'false' then
        value = false
    else
        value = tonumber(value) or toboolean(value) or value
    end

    local setMethod = self['set' .. setterName]
    if setMethod then
        local method = setMethod
        if isInheritable then
            method = function(self, value)
                setMethod(self, value)
                local children = self:querySelectorAll(':node-all')
                for i = 1, #children do
                    local child = children[i]
                    if child.inheritedStyles then
                        local inheritedFromId = child.inheritedStyles[self.attr]
                        if not inheritedFromId or inheritedFromId == self.htmlId then
                            setMethod(child, value)
                        end
                    end
                end
            end

            g_dispatcher.deferEvent(function()
                method(self, value)
            end)
        elseif value ~= nil then
            method(self, value)
        end

        if watchObj then
            watchObj.method = method
            WidgetWatch.register(watchObj)
        end
    else
        local _name = string.sub(setterName, 1, 1):lower() .. string.sub(setterName, 2, -1)
        self[_name] = value
    end
end

local EVENTS_TRANSLATED = {
    onstyleapply     = 'onStyleApply',
    ondestroy        = 'onDestroy',
    onidchange       = 'onIdChange',
    onwidthchange    = 'onWidthChange',
    onheightchange   = 'onHeightChange',
    onresize         = 'onResize',
    onenabled        = 'onEnabled',
    onpropertychange = 'onPropertyChange',
    ongeometrychange = 'onGeometryChange',
    onlayoutupdate   = 'onLayoutUpdate',
    onfocus          = 'onFocusChange',
    onchildfocus     = 'onChildFocusChange',
    onhover          = 'onHoverChange',
    onvisibility     = 'onVisibilityChange',
    ondragenter      = 'onDragEnter',
    ondragleave      = 'onDragLeave',
    ondragmove       = 'onDragMove',
    ondrop           = 'onDrop',
    onkeytext        = 'onKeyText',
    onkeydown        = 'onKeyDown',
    onkeypress       = 'onKeyPress',
    onkeyup          = 'onKeyUp',
    onmousepress     = 'onMousePress',
    onmouserelease   = 'onMouseRelease',
    onmousemove      = 'onMouseMove',
    onmousewheel     = 'onMouseWheel',
    onclick          = 'onClick',
    ondoubleclick    = 'onDoubleClick',
    oncreate         = 'onCreate',
    onsetup          = 'onSetup',
    ontextareaupdate = 'onTextAreaUpdate',
    onfontchange     = 'onFontChange',
    ontextchange     = 'onTextChange',
    onescape         = 'onEscape',
}

local parseEvents = function(widget, eventName, callStr, controller, NODE_STR)
    local fnc = getFncByExpr('return function(self, event, target ' .. FOR_CTX.__keys .. ') ' .. callStr .. ' end',
        NODE_STR, widget, controller, function()
            return ('Event Error[%s]: %s'):format(eventName, callStr)
        end)

    local event = { target = widget }
    local forCtx = FOR_CTX.__values or {}
    local function execEventCall()
        execFnc(fnc, { controller, event, widget, unpack(forCtx) }, widget, controller, NODE_STR, function()
            return ('Event Error[%s]: %s'):format(eventName, callStr)
        end)
    end

    if eventName == 'onchange' then
        if widget.__class == 'UIComboBox' then
            controller:registerUIEvents(widget, {
                onOptionChange = function(widget, text, data)
                    event.name = 'onOptionChange'
                    event.text = text
                    event.data = data
                    execEventCall()
                end
            })
        elseif widget.__class == 'UIRadioGroup' then
            controller:registerUIEvents(widget, {
                onSelectionChange = function(widget, selectedWidget, previousSelectedWidget)
                    event.name = 'onSelectionChange'
                    event.selectedWidget = selectedWidget
                    event.previousSelectedWidget = previousSelectedWidget
                    execEventCall()
                end
            })
        elseif widget.__class == 'UICheckBox' then
            controller:registerUIEvents(widget, {
                onCheckChange = function(widget, checked)
                    event.name = 'onCheckChange'
                    event.checked = checked
                    execEventCall()
                end
            })
        elseif widget.__class == 'UIScrollBar' then
            controller:registerUIEvents(widget, {
                onValueChange = function(widget, value, delta)
                    event.name = 'onValueChange'
                    event.value = value
                    event.delta = delta
                    execEventCall()
                end
            })
        elseif widget.setValue then
            controller:registerUIEvents(widget, {
                onValueChange = function(widget, value)
                    event.name = 'onValueChange'
                    event.value = value
                    execEventCall()
                end
            })
        else
            controller:registerUIEvents(widget, {
                onTextChange = function(widget, value)
                    event.name = 'onTextChange'
                    event.value = value
                    execEventCall()
                end
            })
        end

        return
    end

    local trEventName = EVENTS_TRANSLATED[eventName]
    if not trEventName then
        pwarning('[' .. controller.dataUI.name .. ']:' .. widget:getId() .. ' Event ' .. eventName .. ' does not exist.')
        return
    end

    local data = {}
    data[trEventName] = function(widget, value)
        event.name = trEventName
        event.value = value
        execEventCall()
    end

    controller:registerUIEvents(widget, data)
end

function UIWidget:onClick(mousePos)
    if self and type(self.onClick) == "table" then
        for _, func in pairs(self.onClick) do
            if type(func) == "function" and func ~= UIWidget.onClick then
                func(self, mousePos)
            end
        end
    end

    local focusedWidgets = modules.game_interface.focusReason
    if not focusedWidgets or table.empty(focusedWidgets) then
        return true
    end

    local clickedWidget = g_ui.getRootWidget():recursiveGetChildByPos(mousePos, false)
    if not clickedWidget then
        return true
    end

    local ignorableWidgets = { "searchText" }
    if table.contains(ignorableWidgets, clickedWidget:getId()) then
        return true
    end

    return true
end

function UIWidget:onCreateByHTML(tagName, attrs, controllerName, NODE_STR)
    local controller = G_CONTROLLER_CALLED[controllerName]

    local cur = controller and controller.__current_for_ctx
    if cur and not self.__for_values then
        self.__for_keys   = cur.keys
        self.__for_values = cur.values
    end

    for attr, v in pairs(attrs) do
        if attr:starts('on') then
            parseEvents(self, attr:lower(), v, controller, NODE_STR)
        elseif attr == "for" then
            if tagName == 'label' then
                local widgetRef = self:getParent():getChildById(v)
                if widgetRef then
                    controller:registerUIEvents(self, {
                        onClick = function(widget, value)
                            widgetRef:onClick(g_window.getMousePosition())
                        end
                    })
                end
            end
        end
    end

    local getFncSet = function(attrName)
        local exp = attrs[attrName]
        return getFncByExpr('return function(self, value, target ' .. FOR_CTX.__keys .. ') ' .. exp .. '=value end',
            NODE_STR, self, controller, function()
                return ('Attribute error[%s]: %s'):format(attrName, exp)
            end)
    end

    local attrName = '*checked'
    if attrs[attrName] then
        local set = getFncSet(attrName)
        if set then
            controller:registerUIEvents(self, {
                onCheckChange = function(widget, value)
                    local forCtx = widget.__for_values or {}
                    execFnc(set, { controller, value, widget, unpack(forCtx) }, self,
                        controller, NODE_STR, function()
                            return ('Attribute error[%s]: %s'):format(attrName, attrs[attrName])
                        end)
                end
            })
        end
    end

    attrName = '*value'
    if attrs['*value'] then
        local set = getFncSet(attrName)
        if set then
            if self.getCurrentOption then
                controller:registerUIEvents(self, {
                    onOptionChange = function(widget, text, data)
                        local forCtx = widget.__for_values or {}
                        execFnc(set, { controller, data, widget, unpack(forCtx) },
                            self, controller, NODE_STR, function()
                                return ('Attribute error[%s]: %s'):format(attrName, attrs[attrName])
                            end)
                    end
                })
            else
                controller:registerUIEvents(self, {
                    onTextChange = function(widget, value)
                        local forCtx = widget.__for_values or {}
                        execFnc(set, { controller, value, widget, unpack(forCtx) },
                            self, controller, NODE_STR, function()
                                return ('Attribute error[%s]: %s'):format(attrName, attrs[attrName])
                            end)
                    end
                })
            end
        end
    end
end

function UIWidget:__scriptHtml(moduleName, script, NODE_STR)
    local controller = G_CONTROLLER_CALLED[moduleName]
    local fnc = getFncByExpr('return function(self) ' .. script .. ' end',
        NODE_STR, self, controller)
    execFnc(fnc, { controller }, self, controller, NODE_STR)
end

function ngfor_exec(content, env, fn)
    if not content or content == "" then return end
    content = content:gsub("(%s)let(%s)", "%1local%2")

    local variable, iterable, aliases, ifCond, trackBy = nil, nil, {}, nil, nil
    for part in content:gmatch("[^;]+") do
        part = part:match("^%s*(.-)%s*$")
        local v, it = part:match("^local%s+([%a_][%w_]*)%s+in%s+(.+)$")
        if v and it then
            variable, iterable = v, it:match("^%s*(.-)%s*$")
        else
            local an, as = part:match("^local%s+([%a_][%w_]*)%s*=%s*(.+)$")
            if an and as then
                aliases[#aliases + 1] = { name = an, source = as:match("^%s*(.-)%s*$") }
            else
                local tb = part:match("^trackBy%s*:%s*(.+)$")
                if tb then
                    trackBy = tb:match("^%s*(.-)%s*$")
                else
                    local ic = part:match("^if%s*:%s*(.+)$")
                    if ic then ifCond = ic:match("^%s*(.-)%s*$") end
                end
            end
        end
    end
    if not variable or not iterable then return end

    local order = { variable, "index" }
    for i = 1, #aliases do order[#order + 1] = aliases[i].name end
    local keys_str = ',' .. table.concat(order, ",")

    local is51 = (_VERSION == "Lua 5.1")
    local evalIterable, evalIf, evalKey

    if is51 then
        local li, erri = check_load("return " .. iterable, "for_iterable")
        if not li then error(erri) end
        evalIterable = function(e)
            setfenv(li, e); return li()
        end

        if ifCond then
            local lf, errf = check_load("return " .. ifCond, "for_if")
            if not lf then error(errf) end
            evalIf = function(e)
                setfenv(lf, e); return lf()
            end
        end

        if trackBy then
            local lk, errk = check_load("return " .. trackBy, "for_key")
            if not lk then error(errk) end
            evalKey = function(e)
                setfenv(lk, e); return lk()
            end
        end
    else
        local ci, erri = check_load("return function(_ENV) return " .. iterable .. " end", "for_iterable", "t")
        if not ci then error(erri) end
        ci = ci(); evalIterable = function(e) return ci(e) end

        if ifCond then
            local cf, errf = check_load("return function(_ENV) return " .. ifCond .. " end", "for_if", "t")
            if not cf then error(errf) end
            cf = cf(); evalIf = function(e) return cf(e) end
        end

        if trackBy then
            local ck, errk = check_load("return function(_ENV) return " .. trackBy .. " end", "for_key", "t")
            if not ck then error(errk) end
            ck = ck(); evalKey = function(e) return ck(e) end
        end
    end

    local list = evalIterable(env)
    if type(list) ~= "table" then return end

    local count = #list
    for i, val in ipairs(list) do
        local locals = {
            [variable] = val,
            index      = i - 1,
            first      = (i == 1),
            last       = (i == count),
            even       = (i % 2 == 0),
            odd        = (i % 2 == 1)
        }
        for a = 1, #aliases do
            locals[aliases[a].name] = locals[aliases[a].source]
        end
        local menv = setmetatable(locals, { __index = env })

        local pass = true
        if evalIf then
            local ok, cond = pcall(evalIf, menv)
            pass = ok and cond
        end

        if pass then
            local values = {}
            for idx = 1, #order do
                values[idx] = locals[order[idx]]
            end

            local old_keys, old_values = FOR_CTX.__keys, FOR_CTX.__values
            FOR_CTX.__keys             = keys_str
            FOR_CTX.__values           = values
            FOR_CTX.__key              = evalKey and (pcall(evalKey, menv) and evalKey(menv) or nil) or nil

            fn({
                __keys   = keys_str,
                __values = values,
                __key    = FOR_CTX.__key
            })

            FOR_CTX.__keys, FOR_CTX.__values = old_keys, old_values
        end
    end

    return list, keys_str
end

function UIWidget:__childFor(moduleName, expr, html, index, onFinished)
    local controller = G_CONTROLLER_CALLED[moduleName]

    local finishedFnc
    if onFinished and onFinished ~= "" then
        finishedFnc = getFncByExpr('return function(self) ' .. onFinished .. ' end',
            html, self, controller)
    end

    local hasChanges = false
    local scan = function(self)
        hasChanges = false
        local baseEnv = { self = controller }
        setmetatable(baseEnv, { __index = _G })

        local widget = self.widget

        local function merge_parent_for_env(base, w)
            if not w.__for_keys or not w.__for_values then return base end
            local names = {}
            for name in string.gmatch(w.__for_keys, "[^,%s]+") do
                if name ~= "" then
                    names[#names + 1] = name
                end
            end
            local e = {}
            local maxn = math.min(#names, #w.__for_values)
            for i = 1, maxn do
                e[names[i]] = w.__for_values[i]
            end
            setmetatable(e, { __index = base })
            return e
        end

        local env          = merge_parent_for_env(baseEnv, widget)

        local isFirst      = (self.watchList == nil)
        local childindex   = index

        local outer_keys   = widget.__for_keys or ''
        local outer_values = widget.__for_values

        local list, keys   = ngfor_exec(expr, env, function(c)
            if not isFirst then return end
            childindex = childindex + 1

            local combined_keys = (outer_keys or '') .. (c.__keys or '')
            local combined_vals = {}

            do
                local pos = 0
                if outer_values and type(outer_values) == 'table' then
                    for i = 1, #outer_values do
                        pos = pos + 1
                        combined_vals[pos] = outer_values[i]
                    end
                end
                local inner_vals = c.__values or {}
                for i = 1, #inner_vals do
                    pos = pos + 1
                    combined_vals[pos] = inner_vals[i]
                end
            end

            FOR_CTX.__keys   = combined_keys
            FOR_CTX.__values = combined_vals

            do
                local __w        = apply_for_ctx_to_new_tree(controller, function()
                    return widget:insert(childindex, html)
                end)
                __w.__for_values = FOR_CTX.__values
                __w.__for_keys   = FOR_CTX.__keys
            end

            FOR_CTX.__keys   = ''
            FOR_CTX.__values = nil
        end)

        if isFirst then
            hasChanges = true
            local watch = table.watchList(list, {
                onInsert = function(i, it)
                    hasChanges = true
                    local outer_keys    = widget.__for_keys or ''
                    local outer_values  = widget.__for_values
                    local combined_keys = (outer_keys or '') .. keys
                    local combined_vals = {}
                    do
                        local pos = 0
                        if outer_values and type(outer_values) == 'table' then
                            for j = 1, #outer_values do
                                pos = pos + 1
                                combined_vals[pos] = outer_values[j]
                            end
                        end
                        pos = pos + 1; combined_vals[pos] = it
                        pos = pos + 1; combined_vals[pos] = i
                    end

                    FOR_CTX.__keys   = combined_keys
                    FOR_CTX.__values = combined_vals

                    do
                        local __w        = apply_for_ctx_to_new_tree(controller, function()
                            return widget:insert(index + i, html)
                        end)
                        __w.__for_values = FOR_CTX.__values
                        __w.__for_keys   = FOR_CTX.__keys
                    end
                    FOR_CTX.__keys   = ''
                    FOR_CTX.__values = nil
                end,
                onRemove = function(i)
                    hasChanges = true
                    local child = widget:getChildByIndex(index + i)
                    if not child then
                        pwarning('onRemove: child(' .. index + i .. ') not found.')
                        return
                    end
                    local nextChild = child:getNextWidget()
                    widget:removeChild(child)
                    child:destroy()
                    controller:checkWidgetsDestroyed()
                    local childIndex = index + i
                    while nextChild do
                        if not nextChild.__for_values then break end
                        nextChild.__for_values[2] = childIndex
                        childIndex = childIndex + 1
                        nextChild = nextChild:getNextWidget()
                    end
                end
            })
            self.watchList = watch
        else
            self.watchList.list = list
        end

        self.watchList:scan()
        if finishedFnc and hasChanges then
            execFnc(finishedFnc, { controller }, self.widget, controller, html)
        end
    end

    WidgetWatch.register({
        widget = self,
        fnc = scan
    })
end
