-- @docvars @{
-- root widget
rootWidget = g_ui.getRootWidget()
modules = package.loaded

-- G is used as a global table to save variables in memory between reloads
G = G or {}

-- @}

-- @docfuncs @{

local function getEventName(callback)
	local ok, info = pcall(debug.getinfo, callback, "S")
	if ok and info then
		local src = info.short_src or "lua"
		local line = info.linedefined or 0
		return src .. ":" .. line
	end
	return "lua"
end

function scheduleEvent(callback, delay)
	local name = getEventName(callback)
	local event
	if g_dispatcher.scheduleEventEx then
		event = g_dispatcher.scheduleEventEx(name, callback, delay)
	else
		event = g_dispatcher.scheduleEvent(callback, delay)
	end
	-- must hold a reference to the callback, otherwise it would be collected
	event._callback = callback
	return event
end

function addEvent(callback, front)
	local name = getEventName(callback)
	local event
	if g_dispatcher.addEventEx then
		event = g_dispatcher.addEventEx(name, callback)
	else
		event = g_dispatcher.addEvent(callback, front)
	end
	-- must hold a reference to the callback, otherwise it would be collected
	event._callback = callback
	return event
end

function cycleEvent(callback, interval)
	local name = getEventName(callback)
	local event
	if g_dispatcher.cycleEventEx then
		event = g_dispatcher.cycleEventEx(name, callback, interval)
	else
		event = g_dispatcher.cycleEvent(callback, interval)
	end
	-- must hold a reference to the callback, otherwise it would be collected
	event._callback = callback
	return event
end

function periodicalEvent(eventFunc, conditionFunc, delay, autoRepeatDelay)
	delay = delay or 30
	autoRepeatDelay = autoRepeatDelay or delay

	local func
	func = function()
		if conditionFunc and not conditionFunc() then
			func = nil
			return
		end
		eventFunc()
		scheduleEvent(func, delay)
	end

	scheduleEvent(function()
		func()
	end, autoRepeatDelay)
end

function removeEvent(event)
	if event then
		event:cancel()
		event._callback = nil
	end
end

-- @}
