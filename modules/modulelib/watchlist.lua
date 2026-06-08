local WATCH_LIST = {}
local WATCH_CYCLE_CHECK_MS = 50
local WATCH_EVENT = nil

local WidgetWatch = {}

function WidgetWatch.update()
    table.remove_if(WATCH_LIST, function(i, obj)
        if not obj or not obj.widget then
            return true
        end

        local isDestroyed = obj.widget:isDestroyed()
        if isDestroyed then
            obj.widget = nil
        elseif obj.methodName == 'conditionif' or obj.methodName == 'visible' or obj.widget:isVisible() then
            obj.fnc(obj)
        end

        return isDestroyed
    end)

    if #WATCH_LIST == 0 then
        removeEvent(WATCH_EVENT)
        WATCH_EVENT = nil
    end
end

function WidgetWatch.register(obj)
    assert(type(obj) == "table" and obj.widget, "WidgetWatch.register: obj.widget é obrigatório")
    local w = obj.widget

    if not w then
        pwarning("WidgetWatch.register: obj.widget is nil")
        return
    end

    if w:isDestroyed() then
        pwarning(string.format(
            "WidgetWatch.register: widget '%s' is already destroyed.",
            w:getId()
        ))
        return
    end

    table.insert(WATCH_LIST, obj)

    if WATCH_EVENT ~= nil or #WATCH_LIST == 0 then
        return
    end

    WATCH_EVENT = cycleEvent(WidgetWatch.update, WATCH_CYCLE_CHECK_MS)
end

_G.WidgetWatch = WidgetWatch

-- table.watchList
-- Watches an array-like table (1..N) for structural changes.
-- Emits only inserts and removes (no move callbacks).
-- Keys come from ops.keyOf(item, index) or default to the item reference itself.
-- initial inserts via ops.initialScan = true or w:scan(true).
function table.watchList(realList, ops)
    local self       = {}
    local keyOf      = (ops and ops.keyOf) or function(x) return x end
    local beginBatch = ops and ops.beginBatch
    local endBatch   = ops and ops.endBatch
    local onInsert   = ops and ops.onInsert
    local onRemove   = ops and ops.onRemove
    local onUpdate   = ops and ops.onUpdate

    self.list        = realList
    self.keyOf       = keyOf
    self.prev        = {}
    self.prevK       = {}

    for i = 1, #realList do
        self.prev[i]  = realList[i]
        self.prevK[i] = self.keyOf(realList[i], i)
    end

    local function buildIndexMap(keys)
        local m = {}
        for i = 1, #keys do m[keys[i]] = i end
        return m
    end

    function self:scan(initial)
        if initial then
            if beginBatch then beginBatch() end
            if onInsert then
                for i = 1, #self.list do onInsert(i, self.list[i]) end
            end
            if endBatch then endBatch() end
            return
        end

        local curr = self.list
        local wantK = {}
        for i = 1, #curr do wantK[i] = self.keyOf(curr[i], i) end

        if beginBatch then beginBatch() end

        local prevK   = self.prevK
        local prev    = self.prev
        local needsUpdate = #curr ~= #prev
        if onUpdate and not needsUpdate then
            for i = 1, #curr do
                if curr[i] ~= prev[i] then
                    needsUpdate = true
                    break
                end
            end
        end

        local wantSet = {}
        for i = 1, #wantK do wantSet[wantK[i]] = true end

        if onRemove then
            for i = #prevK, 1, -1 do
                local k = prevK[i]
                if not wantSet[k] then onRemove(i, prev[i]) end
            end
        end

        local curK = {}
        for i = 1, #prevK do
            local k = prevK[i]
            if wantSet[k] then curK[#curK + 1] = k end
        end

        local idxByKey = buildIndexMap(curK)

        local i = 1
        while i <= #wantK do
            local want = wantK[i]
            if curK[i] == want then
                i = i + 1
            else
                local j = idxByKey[want]
                if j then
                    local movedKey = table.remove(curK, j)
                    table.insert(curK, i, movedKey)
                    if j > i then
                        for p = i + 1, j do idxByKey[curK[p]] = p end
                    else
                        for p = j, i do idxByKey[curK[p]] = p end
                    end
                    idxByKey[movedKey] = i
                    i = i + 1
                else
                    if onInsert then onInsert(i, curr[i]) end
                    table.insert(curK, i, want)
                    for p = i, #curK do idxByKey[curK[p]] = p end
                    i = i + 1
                end
            end
        end

        if onUpdate and needsUpdate then
            for i = 1, #curr do onUpdate(i, curr[i]) end
        end

        if endBatch then endBatch() end

        self.prev = {}
        for k = 1, #curr do self.prev[k] = curr[k] end
        self.prevK = wantK
    end

    if ops and ops.initialScan then
        self:scan(true)
    end

    return self
end
