-- HiveMind.lua
-- SCADA-style monitor UI for MineNet turtles (3x3 monitor, touch-driven)
-- Requirements:
-- - Clearer node cards
-- - Add GOTO screen
-- - Add quick toggles for StartY vs Custom Y (and +/-)
-- - No Node changes required (uses: "id:<n> <cmd>")
--
-- Needs ui_lib.lua in same folder.

require("ui_lib")

-- ========= CONFIG =========
local CMD_RECV_CHANNEL = 90
local CMD_SEND_CHANNEL = 91

local DEFAULT_NODE_COUNT = 8

local POLL_INTERVAL = 1.5
local POLL_BATCH_PER_TICK = 3

-- ========= PERIPHERALS =========
local monitor = peripheral.find("monitor") or error("No monitor attached", 0)
local modem = peripheral.find("modem") or error("No modem attached", 0)
modem.open(CMD_SEND_CHANNEL)

-- ========= UI INIT =========
UI.init(monitor)
local W, H = monitor.getSize()

-- ========= STATE =========
local screen = "home" -- home | detail | settings | goto
local nodeCount = DEFAULT_NODE_COUNT

local nodes = {}
local function now()
	return os.clock()
end

local function ensureNodes(n)
	nodeCount = math.max(1, n or 1)
	for i = 1, nodeCount do
		if not nodes[i] then
			nodes[i] = {
				id = i,
				last = nil,
				lastRxAt = nil,
				lastRaw = nil,
				lastPingAt = nil,
				startY = nil, -- learned from first status/hello
			}
		end
	end
end
ensureNodes(nodeCount)

local appLog = {}
local function log(s)
	s = tostring(s or "")
	table.insert(appLog, s)
	while #appLog > 120 do
		table.remove(appLog, 1)
	end
end

local scroll = 0
local selectedId = 1

local autoPoll = true
local pollTimer = nil
local pollCursor = 1

-- Detail: Startlevel Y controls
local yMode = "start" -- "start" or "custom"
local yCustom = "" -- string entry
local yEntryMode = false

-- GOTO screen entry
local gotoEntry = { x = "", y = "", z = "" }
local gotoField = "x" -- x|y|z
local gotoEntryMode = false

-- ========= HELPERS =========
local function clamp(n, a, b)
	if n < a then
		return a
	elseif n > b then
		return b
	else
		return n
	end
end

local function sendCmd(id, cmd)
	local out = ("id:%d %s"):format(id, cmd)
	modem.transmit(CMD_RECV_CHANNEL, CMD_SEND_CHANNEL, out)
	if nodes[id] then
		nodes[id].lastPingAt = now()
	end
	log(("TX id:%d %s"):format(id, cmd))
end

local function parsePayload(raw)
	if type(raw) ~= "string" then
		return nil
	end
	local ok, t = pcall(textutils.unserialize, raw)
	if not ok or type(t) ~= "table" then
		return nil
	end
	return t
end

local function fmtAge(ts)
	if not ts then
		return "N/A"
	end
	local a = now() - ts
	if a < 0 then
		a = 0
	end
	if a < 60 then
		return string.format("%.0fs", a)
	end
	return string.format("%.0fm", a / 60)
end

local function nodeState(n)
	if not n or not n.last then
		return "unknown"
	end
	return tostring(n.last.state or "unknown")
end

local function nodeFuel(n)
	if not n or not n.last then
		return "?"
	end
	local f = n.last.fuel
	if f == -1 then
		return "inf"
	end
	if f == nil then
		return "?"
	end
	return tostring(f)
end

local function nodePos(n)
	if not n or not n.last or not n.last.pos then
		return nil
	end
	return n.last.pos
end

local function nodePosStr(n)
	local p = nodePos(n)
	if not p then
		return "x? y? z?"
	end
	return ("x%s y%s z%s"):format(tostring(p.x), tostring(p.y), tostring(p.z))
end

local function stateColor(st)
	st = tostring(st or ""):lower()
	if st:find("working") then
		return colors.lime
	end
	if st:find("paused") then
		return colors.orange
	end
	if st:find("return") then
		return colors.blue
	end
	if st:find("dead") then
		return colors.red
	end
	if st:find("await") then
		return colors.lightGray
	end
	return colors.gray
end

local function clearElements()
	UI.elements = {}
end

-- ========= COMMON UI =========
local function drawTopBar(title)
	UI.drawText(2, 1, ("HiveMind | %s"):format(title), colors.white, colors.black)
	local right = ("poll:%s"):format(autoPoll and "ON" or "OFF")
	UI.drawText(W - #right + 1, 1, right, autoPoll and colors.lime or colors.orange, colors.black)
end

local function drawFooter()
	local y = H
	UI.drawButton("exit", 2, y - 1, 10, 2, "EXIT", colors.white, colors.red, function()
		monitor.setBackgroundColor(colors.black)
		monitor.clear()
		error("Exit", 0)
	end)

	UI.drawButton("home", 14, y - 1, 10, 2, "HOME", colors.black, colors.lightGray, function()
		screen = "home"
	end)

	UI.drawButton("settings", 26, y - 1, 12, 2, "SETTINGS", colors.black, colors.lightGray, function()
		screen = "settings"
	end)

	UI.drawButton(
		"togglePoll",
		W - 13,
		y - 1,
		12,
		2,
		autoPoll and "POLL ON" or "POLL OFF",
		colors.black,
		autoPoll and colors.lime or colors.orange,
		function()
			autoPoll = not autoPoll
			log("autoPoll=" .. tostring(autoPoll))
			if autoPoll and not pollTimer then
				pollTimer = os.startTimer(0.2)
			end
		end
	)
end

-- ========= HOME (CLEARER CARDS) =========
local function drawHome()
	UI.clear()
	clearElements()
	drawTopBar("NODES")
	UI.drawText(2, 2, "Tap card for details. Scroll: ▲ ▼", colors.gray, colors.black)

	local listTop = 4
	local listBottom = H - 3
	local cardH = 5
	local visible = math.floor((listBottom - listTop + 1) / cardH)
	if visible < 1 then
		visible = 1
	end

	scroll = clamp(scroll, 0, math.max(0, nodeCount - visible))

	UI.drawButton("scrollUp", W - 6, 2, 5, 1, "▲", colors.black, colors.lightGray, function()
		scroll = clamp(scroll - 1, 0, nodeCount)
	end)
	UI.drawButton("scrollDn", W - 6, 3, 5, 1, "▼", colors.black, colors.lightGray, function()
		scroll = clamp(scroll + 1, 0, nodeCount)
	end)

	for i = 1, visible do
		local idx = scroll + i
		if idx > nodeCount then
			break
		end
		local n = nodes[idx]
		local y = listTop + (i - 1) * cardH

		local st = nodeState(n)
		local fuel = nodeFuel(n)
		local age = fmtAge(n.lastRxAt)
		local bar = stateColor(st)

		-- Card background + colored state bar on the left
		UI.drawBox(2, y, W - 2, cardH, colors.gray, "", monitor)
		UI.drawBox(2, y, 1, cardH, bar, "", monitor)

		-- Title row
		UI.drawText(4, y, ("NODE %d"):format(idx), colors.black, colors.gray)
		UI.drawText(15, y, ("st:%s"):format(st), colors.black, colors.gray)

		-- Meta row
		UI.drawText(4, y + 1, ("fuel:%s  age:%s"):format(fuel, age), colors.black, colors.gray)
		UI.drawText(4, y + 2, nodePosStr(n), colors.black, colors.gray)

		-- Job row (if any)
		local job = (n.last and n.last.job and n.last.job.type) and tostring(n.last.job.type) or "idle"
		UI.drawText(4, y + 3, ("job:%s"):format(job), colors.black, colors.gray)

		-- Whole card click -> detail (exclude right-side button area)
		UI.drawButton("open_" .. idx, 2, y, W - 26, cardH, "", colors.black, colors.gray, function()
			selectedId = idx
			screen = "detail"
		end)

		-- Right-side actions (stacked, clearer)
		local bx = W - 23
		UI.drawButton("stat_" .. idx, bx, y, 7, 1, "STATUS", colors.black, colors.lightGray, function()
			sendCmd(idx, "status")
		end)
		UI.drawButton("go_" .. idx, bx + 8, y, 7, 1, "GOTO", colors.black, colors.lightGray, function()
			selectedId = idx
			screen = "goto"
			gotoEntry = { x = "", y = "", z = "" }
			gotoField = "x"
			gotoEntryMode = false
		end)

		UI.drawButton("pause_" .. idx, bx, y + 2, 7, 1, "PAUSE", colors.white, colors.orange, function()
			sendCmd(idx, "pause")
		end)
		UI.drawButton("res_" .. idx, bx + 8, y + 2, 7, 1, "RESUME", colors.black, colors.lime, function()
			sendCmd(idx, "resume")
		end)

		UI.drawButton("home_" .. idx, bx, y + 3, 15, 1, "HOME", colors.white, colors.blue, function()
			sendCmd(idx, "home")
		end)
	end

	drawFooter()
end

-- ========= DETAIL (StartY toggle + +/- + goto button) =========
local function effectiveStartY()
	local n = nodes[selectedId]
	if not n then
		return nil
	end
	return n.startY
end

local function resolveStartLevelY()
	if yMode == "start" then
		return effectiveStartY()
	end
	return tonumber(yCustom)
end

local function bumpCustomY(delta)
	local v = tonumber(yCustom)
	if not v then
		v = effectiveStartY() or 0
	end
	v = v + delta
	yCustom = tostring(v)
end

local function drawDetail()
	UI.clear()
	clearElements()
	drawTopBar(("NODE %d"):format(selectedId))

	local n = nodes[selectedId] or { id = selectedId }
	local st = nodeState(n)
	local fuel = nodeFuel(n)
	local age = fmtAge(n.lastRxAt)

	UI.drawText(2, 2, ("State: %s   Fuel: %s   Age: %s"):format(st, fuel, age), colors.white, colors.black)
	UI.drawText(2, 3, ("Pos: %s"):format(nodePosStr(n)), colors.white, colors.black)

	-- Telemetry box
	UI.drawBox(2, 5, W - 2, 6, colors.gray, "", monitor)
	UI.drawText(3, 5, "Telemetry", colors.black, colors.gray)
	if n.last and type(n.last) == "table" then
		local p = n.last.pos or {}
		UI.drawText(
			3,
			6,
			("id:%s facing:%s"):format(tostring(n.last.id), tostring(n.last.facing)),
			colors.black,
			colors.gray
		)
		UI.drawText(
			3,
			7,
			("x:%s y:%s z:%s"):format(tostring(p.x), tostring(p.y), tostring(p.z)),
			colors.black,
			colors.gray
		)
		UI.drawText(
			3,
			8,
			("job:%s fail:%s"):format(n.last.job and tostring(n.last.job.type) or "nil", tostring(n.last.failCount)),
			colors.black,
			colors.gray
		)
		UI.drawText(3, 9, ("note:%s"):format(tostring(n.last.note or "")):sub(1, W - 6), colors.black, colors.gray)
	else
		UI.drawText(3, 6, "No status yet. Tap STATUS.", colors.black, colors.gray)
	end

	-- Main controls row
	local cy = 12
	UI.drawButton("stat", 2, cy, 10, 2, "STATUS", colors.black, colors.lightGray, function()
		sendCmd(selectedId, "status")
	end)
	UI.drawButton("pause", 13, cy, 10, 2, "PAUSE", colors.white, colors.orange, function()
		sendCmd(selectedId, "pause")
	end)
	UI.drawButton("resume", 24, cy, 10, 2, "RESUME", colors.black, colors.lime, function()
		sendCmd(selectedId, "resume")
	end)
	UI.drawButton("homeBtn", 35, cy, 10, 2, "HOME", colors.white, colors.blue, function()
		sendCmd(selectedId, "home")
	end)

	UI.drawButton("gotoBtn", W - 12, cy, 11, 2, "GOTO", colors.black, colors.lightGray, function()
		screen = "goto"
		gotoEntry = { x = "", y = "", z = "" }
		gotoField = "x"
		gotoEntryMode = false
	end)

	-- Startlevel Y section
	UI.drawText(2, cy + 3, "Startlevel Y:", colors.white, colors.black)

	-- Mode toggle buttons
	UI.drawButton(
		"modeStart",
		16,
		cy + 2,
		10,
		2,
		"StartY",
		colors.black,
		(yMode == "start") and colors.lime or colors.lightGray,
		function()
			yMode = "start"
			yEntryMode = false
		end
	)

	UI.drawButton(
		"modeCustom",
		27,
		cy + 2,
		10,
		2,
		"Custom",
		colors.black,
		(yMode == "custom") and colors.lime or colors.lightGray,
		function()
			yMode = "custom"
			yEntryMode = true
			if yCustom == "" then
				local sy = effectiveStartY()
				if sy ~= nil then
					yCustom = tostring(sy)
				end
			end
		end
	)

	-- Display box
	UI.drawBox(16, cy + 4, 10, 2, colors.gray, "", monitor)
	local displayY = "tap"
	if yMode == "start" then
		local sy = effectiveStartY()
		displayY = sy and tostring(sy) or "?"
	else
		displayY = (yCustom == "" and " " or yCustom)
	end
	UI.drawText(18, cy + 4, displayY, colors.black, colors.gray)

	-- +/- buttons for custom
	UI.drawButton("yMinus", 27, cy + 4, 4, 2, "-1", colors.black, colors.lightGray, function()
		yMode = "custom"
		yEntryMode = false
		bumpCustomY(-1)
	end)
	UI.drawButton("yPlus", 32, cy + 4, 4, 2, "+1", colors.black, colors.lightGray, function()
		yMode = "custom"
		yEntryMode = false
		bumpCustomY(1)
	end)

	-- Start button
	UI.drawButton("goY", 38, cy + 3, 10, 3, "START", colors.white, colors.green, function()
		local y = resolveStartLevelY()
		if y ~= nil then
			sendCmd(selectedId, "startlevel " .. tostring(y))
			yEntryMode = false
		else
			log("invalid y")
		end
	end)

	UI.drawButton("back", W - 10, 2, 9, 2, "BACK", colors.black, colors.lightGray, function()
		screen = "home"
	end)

	-- Recent box
	UI.drawBox(2, H - 10, W - 2, 7, colors.gray, "", monitor)
	UI.drawText(3, H - 10, "Recent", colors.black, colors.gray)

	local shown = 0
	for i = #appLog, 1, -1 do
		local line = appLog[i]
		if line:find("id:" .. tostring(selectedId)) then
			UI.drawText(3, H - 10 + 1 + shown, line:sub(1, W - 6), colors.black, colors.gray)
			shown = shown + 1
			if shown >= 5 then
				break
			end
		end
	end

	drawFooter()
end

-- ========= GOTO SCREEN =========
local function drawGoto()
	UI.clear()
	clearElements()
	drawTopBar(("GOTO NODE %d"):format(selectedId))

	UI.drawText(2, 2, "Tap a field then type. Press ENTER to finish field.", colors.gray, colors.black)

	UI.drawBox(2, 4, W - 2, 7, colors.gray, "", monitor)
	UI.drawText(3, 4, "Coordinates", colors.black, colors.gray)

	local function fieldLine(label, val, y, active)
		local bg = active and colors.lime or colors.lightGray
		UI.drawBox(3, y, W - 6, 1, colors.gray, "", monitor)
		UI.drawText(3, y, label, colors.black, colors.gray)
		UI.drawBox(10, y, 12, 1, bg, "", monitor)
		UI.drawText(11, y, (val == "" and " " or val), colors.black, bg)
	end

	fieldLine("X:", gotoEntry.x, 6, gotoField == "x")
	fieldLine("Y:", gotoEntry.y, 7, gotoField == "y")
	fieldLine("Z:", gotoEntry.z, 8, gotoField == "z")

	UI.drawButton("fx", 10, 6, 12, 1, "", colors.black, colors.lightGray, function()
		gotoField = "x"
		gotoEntryMode = true
	end)
	UI.drawButton("fy", 10, 7, 12, 1, "", colors.black, colors.lightGray, function()
		gotoField = "y"
		gotoEntryMode = true
	end)
	UI.drawButton("fz", 10, 8, 12, 1, "", colors.black, colors.lightGray, function()
		gotoField = "z"
		gotoEntryMode = true
	end)

	UI.drawButton("status2", 2, 12, 10, 2, "STATUS", colors.black, colors.lightGray, function()
		sendCmd(selectedId, "status")
	end)

	UI.drawButton("sendGoto", 13, 12, 12, 2, "SEND GOTO", colors.white, colors.green, function()
		local x = tonumber(gotoEntry.x)
		local y = tonumber(gotoEntry.y)
		local z = tonumber(gotoEntry.z)
		if x and y and z then
			sendCmd(selectedId, ("goto %d %d %d"):format(x, y, z))
			gotoEntryMode = false
		else
			log("goto invalid")
		end
	end)

	UI.drawButton("backG", W - 10, 2, 9, 2, "BACK", colors.black, colors.lightGray, function()
		screen = "detail"
	end)

	-- quick helpers
	UI.drawText(2, 15, "Quick:", colors.white, colors.black)
	UI.drawButton("homeG", 9, 14, 10, 2, "HOME", colors.white, colors.blue, function()
		sendCmd(selectedId, "home")
	end)
	UI.drawButton("pauseG", 20, 14, 10, 2, "PAUSE", colors.white, colors.orange, function()
		sendCmd(selectedId, "pause")
	end)
	UI.drawButton("resG", 31, 14, 10, 2, "RESUME", colors.black, colors.lime, function()
		sendCmd(selectedId, "resume")
	end)

	drawFooter()
end

-- ========= SETTINGS =========
local function drawSettings()
	UI.clear()
	clearElements()
	drawTopBar("SETTINGS")

	UI.drawText(2, 3, "Node count:", colors.white, colors.black)
	UI.drawBox(14, 2, 8, 3, colors.gray, "", monitor)
	UI.drawText(16, 3, tostring(nodeCount), colors.black, colors.gray)

	UI.drawButton("inc", 23, 2, 5, 3, "+", colors.black, colors.lime, function()
		ensureNodes(nodeCount + 1)
	end)
	UI.drawButton("dec", 29, 2, 5, 3, "-", colors.black, colors.orange, function()
		ensureNodes(nodeCount - 1)
		selectedId = clamp(selectedId, 1, nodeCount)
		scroll = clamp(scroll, 0, nodeCount)
	end)

	UI.drawButton("pollNow", 2, 8, 14, 3, "POLL NOW", colors.black, colors.lightGray, function()
		for i = 1, nodeCount do
			sendCmd(i, "status")
		end
	end)

	UI.drawText(2, 12, "Tip: node cards learn StartY after first status.", colors.gray, colors.black)

	UI.drawButton("back2", W - 10, 2, 9, 2, "BACK", colors.black, colors.lightGray, function()
		screen = "home"
	end)

	drawFooter()
end

local function render()
	if screen == "home" then
		drawHome()
	elseif screen == "detail" then
		drawDetail()
	elseif screen == "goto" then
		drawGoto()
	else
		drawSettings()
	end
end

-- ========= INPUT (KEYBOARD) =========
local function setFieldText(field, txt)
	gotoEntry[field] = txt
end

local function appendToField(field, ch)
	local cur = gotoEntry[field]
	if #cur >= 8 then
		return
	end
	gotoEntry[field] = cur .. ch
end

local function backspaceField(field)
	local cur = gotoEntry[field]
	gotoEntry[field] = cur:sub(1, math.max(0, #cur - 1))
end

local function appendCustomY(ch)
	if #yCustom >= 6 then
		return
	end
	yCustom = yCustom .. ch
end

local function backspaceCustomY()
	yCustom = yCustom:sub(1, math.max(0, #yCustom - 1))
end

local function handleKey(k)
	if screen == "home" then
		if k == keys.up then
			scroll = clamp(scroll - 1, 0, nodeCount)
		end
		if k == keys.down then
			scroll = clamp(scroll + 1, 0, nodeCount)
		end
	elseif screen == "detail" then
		if yMode == "custom" and yEntryMode then
			if k == keys.backspace then
				backspaceCustomY()
			end
			if k == keys.enter then
				yEntryMode = false
			end
			if k == keys.minus and #yCustom == 0 then
				yCustom = "-"
			end
		end
	elseif screen == "goto" then
		if gotoEntryMode then
			if k == keys.backspace then
				backspaceField(gotoField)
			end
			if k == keys.enter then
				gotoEntryMode = false
			end
			if k == keys.minus and #gotoEntry[gotoField] == 0 then
				appendToField(gotoField, "-")
			end
		end
	end
end

local function handleChar(ch)
	if screen == "detail" then
		if yMode == "custom" and yEntryMode then
			if ch:match("%d") then
				appendCustomY(ch)
			end
		end
	elseif screen == "goto" then
		if gotoEntryMode then
			if ch:match("%d") then
				appendToField(gotoField, ch)
			end
		end
	end
end

-- ========= POLLING =========
local function pollTick()
	for _ = 1, POLL_BATCH_PER_TICK do
		sendCmd(pollCursor, "status")
		pollCursor = pollCursor + 1
		if pollCursor > nodeCount then
			pollCursor = 1
		end
	end
end

-- ========= MAIN =========
render()
log("HiveMind started")
pollTimer = os.startTimer(0.25)

while true do
	local e = { os.pullEvent() }

	if e[1] == "monitor_touch" then
		UI.handleTouch(e[3], e[4])
		render()
	elseif e[1] == "modem_message" and e[3] == CMD_SEND_CHANNEL then
		local raw = e[5]
		local t = parsePayload(raw)

		if t and type(t) == "table" then
			local id = tonumber(t.id)
			if id and id >= 1 then
				ensureNodes(math.max(nodeCount, id))
				local n = nodes[id]
				n.lastRaw = raw
				n.lastRxAt = now()
				n.last = t

				-- learn StartY from first known position
				if not n.startY and t.pos and type(t.pos) == "table" and t.pos.y ~= nil then
					n.startY = tonumber(t.pos.y)
				end

				log(("RX id:%d cmd:%s state:%s"):format(id, tostring(t.cmd), tostring(t.state)))
			else
				log("RX (no id): " .. tostring(raw))
			end
		else
			log("RX " .. tostring(raw))
		end
		render()
	elseif e[1] == "timer" and e[2] == pollTimer then
		pollTimer = nil
		if autoPoll then
			pollTick()
		end
		pollTimer = os.startTimer(POLL_INTERVAL)
		render()
	elseif e[1] == "key" then
		handleKey(e[2])
		render()
	elseif e[1] == "char" then
		handleChar(e[2])
		render()
	end
end
