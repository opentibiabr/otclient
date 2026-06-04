local debugInfoWindow = nil
local debugInfoButton = nil
local luaStats = nil
local luaCallback = nil
local mainStats = nil
local dispatcherStats = nil
local render = nil
local atlas = nil
local adaptiveRender = nil
local slowMain = nil
local slowRender = nil
local widgetsInfo = nil
local widgetsInfoToggle = nil
local packets = nil
local slowPackets = nil

local updateEvent = nil
local monitorEvent = nil
local iter = 0
local fps = {}
local ping = {}
local widgetsInfoEnabled = false

function init()
	debugInfoButton = modules.client_topmenu.addTopRightToggleButton("debugInfoButton", tr("Debug Info"),
		"/images/topbuttons/debug", toggle)
	debugInfoButton:setOn(false)

	debugInfoWindow = g_ui.displayUI("debug_info")
	debugInfoWindow:hide()

	Keybind.new("Debug", "Toggle Stats", "Ctrl+Alt+D", "")
	Keybind.bind("Debug", "Toggle Stats", {
		{
			type = KEY_DOWN,
			callback = toggle,
		}
	})

	luaStats = debugInfoWindow:recursiveGetChildById("luaStats")
	luaCallback = debugInfoWindow:recursiveGetChildById("luaCallback")
	mainStats = debugInfoWindow:recursiveGetChildById("mainStats")
	dispatcherStats = debugInfoWindow:recursiveGetChildById("dispatcherStats")
	render = debugInfoWindow:recursiveGetChildById("render")
	atlas = debugInfoWindow:recursiveGetChildById("atlas")
	packets = debugInfoWindow:recursiveGetChildById("packets")
	adaptiveRender = debugInfoWindow:recursiveGetChildById("adaptiveRender")
	slowMain = debugInfoWindow:recursiveGetChildById("slowMain")
	slowRender = debugInfoWindow:recursiveGetChildById("slowRender")
	slowPackets = debugInfoWindow:recursiveGetChildById("slowPackets")
	widgetsInfo = debugInfoWindow:recursiveGetChildById("widgetsInfo")
	widgetsInfoToggle = debugInfoWindow:recursiveGetChildById("widgetsInfoToggle")
	if widgetsInfoToggle then
		widgetsInfoToggle:setChecked(false)
		widgetsInfoToggle.onCheckChange = function(_, checked)
			widgetsInfoEnabled = checked
			if checked then
				widgetsInfo:setVisible(true)
				widgetsInfo:setText(g_stats.getWidgetsInfo(10, true))
			else
				widgetsInfo:setText("")
				widgetsInfo:setHeight(0)
				widgetsInfo:setVisible(false)
			end
		end
	end
	widgetsInfo:setText("")
	widgetsInfo:setHeight(0)
	widgetsInfo:setVisible(false)

	if adaptiveRender then
		adaptiveRender:setText("Adaptive renderer not available")
	end
	if atlas then
		atlas:setText("Atlas: " .. g_atlas.getStats())
	end

	g_stats.resetSleepTime()
	lastSleepTimeReset = g_clock.micros()

	updateEvent = scheduleEvent(update, 2000)
	monitorEvent = scheduleEvent(monitor, 1000)
end

function terminate()
	debugInfoWindow:destroy()
	debugInfoButton:destroy()

	Keybind.delete("Debug", "Toggle Stats")

	removeEvent(updateEvent)
	removeEvent(monitorEvent)
end

function onClose()
	debugInfoButton:setOn(false)
end

function onMiniWindowClose()
	onClose()
end

function toggle()
	if debugInfoButton:isOn() then
		debugInfoWindow:hide()
		debugInfoButton:setOn(false)
	else
		debugInfoWindow:show()
		debugInfoWindow:raise()
		debugInfoWindow:focus()
		debugInfoButton:setOn(true)
	end
end

function monitor()
	if #fps > 1000 then
		fps = {}
	end
	if #ping > 1000 then
		ping = {}
	end
	table.insert(fps, g_app.getFps())
	table.insert(ping, g_game.getPing())
	monitorEvent = scheduleEvent(monitor, 1000)
end

function update()
	updateEvent = scheduleEvent(update, 20)

	if not debugInfoWindow:isVisible() then
		return
	end

	iter = (iter + 1) % 8 -- some functions are slow (~5ms), it will avoid lags
	if iter == 0 then
		debugInfoWindow.debugPanel.sleepTime:setText("GFPS: " .. g_app.getGraphicsFps() .. " PFPS: " .. g_app.getProcessingFps() .. " Packets: " .. g_game.getRecivedPacketsCount() .. " , " .. (g_game.getRecivedPacketsSize() / 1024) .. " KB")
		debugInfoWindow.debugPanel.luaRamUsage:setText("Ram usage by lua: " .. gcinfo() .. " kb")
	elseif iter == 1 then
		atlas:setText("Atlas: " .. g_atlas.getStats())
		render:setText(g_stats.get(2, 10, true))
		mainStats:setText(g_stats.get(1, 5, true))
		dispatcherStats:setText(g_stats.get(3, 5, true))
	elseif iter == 2 then
		luaStats:setText(g_stats.get(4, 5, true))
		luaCallback:setText(g_stats.get(5, 5, true))
	elseif iter == 3 then
		slowMain:setText(g_stats.getSlow(3, 10, 10, true) .. "\n\n\n" .. g_stats.getSlow(1, 20, 20, true))
	elseif iter == 4 then
		slowRender:setText(g_stats.getSlow(2, 10, 10, true))
	elseif iter == 5 then
		if widgetsInfoEnabled then
			widgetsInfo:setText(g_stats.getWidgetsInfo(10, true))
		end
	elseif iter == 6 then
		packets:setText(g_stats.get(6, 10, true))
		slowPackets:setText(g_stats.getSlow(6, 10, 10, true))
	elseif iter == 7 then
		if g_proxy then
			local text = ""
			local proxiesDebug = g_proxy.getProxiesDebugInfo()
			for proxy_name, proxy_debug in pairs(proxiesDebug) do
				text = text .. proxy_name .. " - " .. proxy_debug .. "\n"
			end
			debugInfoWindow.debugPanel.proxies:setText(text)
		end
	end
end
