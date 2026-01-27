-- HiveMind.lua
-- SCADA-style monitor UI for MineNet turtles (3x3 monitor on RIGHT, modem on LEFT)
-- Uses ui_lib.lua (buttons + touch handling). :contentReference[oaicite:0]{index=0}
--
-- Design:
-- - Home screen: scrollable list of nodes (cards) with status/fuel/pos and quick buttons.
-- - Detail screen: one node controller with bigger buttons + recent log.
-- - Polling: optional auto-poll status for visible nodes (toggle).
-- - No NodeMind changes required. Uses existing packet format: "id:<n> <cmd>".
--
-- Place this file on the computer attached to the monitor+modem.
-- Ensure ui_lib.lua is in same folder.

require("ui_lib")

-- ========= CONFIG =========
local CMD_RECV_CHANNEL = 90
local CMD_SEND_CHANNEL = 91

-- how many turtles to render (you can change live in UI too)
local DEFAULT_NODE_COUNT = 8

-- polling
local POLL_INTERVAL = 1.5 -- seconds
local POLL_BATCH_PER_TICK = 3 -- how many nodes to poll per interval when auto-poll on

-- monitor + modem placement
-- (monitor is on right side physically; peripheral.find will still work)
local monitor = peripheral.find("monitor") or error("No monitor attached", 0)
local modem = peripheral.find("modem") or error("No modem attached", 0)

modem.open(CMD_SEND_CHANNEL)

-- ========= UI INIT =========
UI.init(monitor) -- sets textScale 0.5 already :contentReference[oaicite:1]{index=1}
local W, H = monitor.getSize()

-- ========= STATE =========
local screen = "home" -- home | detail | settings
local nodeCount = DEFAULT_NODE_COUNT

-- per-node state: last status, last rx time, last raw msg, last ping time
local nodes = {}
for i = 1, nodeCount do
	nodes[i] = {
		id = i,
		last = nil, -- table from mind_lib status
		lastRxAt = nil,
		lastRaw = nil,
		lastPingAt = nil,
	}
end

local function now()
	return os.clock()
end

local appLog = {}
local function log(s)
	s = tostring(s or "")
	table.insert(appLog, s)
	while #appLog > 80 do
		table.remove(appLog, 1)
	end
end

-- scroll list
local scroll = 0

-- detail view
local selectedId = 1

-- polling toggle
local autoPoll = true
local pollTimer = nil
local pollCursor = 1

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

local function ensureNodes(n)
	nodeCount = n
	for i = 1, nodeCount do
		if not nodes[i] then
			nodes[i] = { id = i, last = nil, lastRxAt = nil, lastRaw = nil, lastPingAt = nil }
		end
	end
	-- remove extra references not necessary; keep table sparse-safe
end

local function sendCmd(id, cmd)
	local out = ("id:%d %s"):format(id, cmd)
	modem.transmit(CMD_RECV_CHANNEL, CMD_SEND_CHANNEL, out)
	nodes[id] = nodes[id] or { id = id }
	nodes[id].lastPingAt = now()
	log(("TX id:%d %s"):format(id, cmd))
end

local function parseStatus(raw)
	if type(raw) ~= "string" then
		return nil
	end
	local ok, t = pcall(textutils.unserialize, raw)
	if not ok or type(t) ~= "table" then
		return nil
	end
	if t.cmd ~= "status" and t.cmd ~= "done" and t.cmd ~= "accepted" and t.cmd ~= "rx" and t.cmd ~= "hello" then
		-- still might be something useful, but we focus on status
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

local function nodeStateStr(n)
	if not n or not n.last then
		return "unknown"
	end
	return tostring(n.last.state or "unknown")
end

local function nodeFuelStr(n)
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

local function nodePosStr(n)
	if not n or not n.last or not n.last.pos then
		return "x? y? z?"
	end
	local p = n.last.pos
	return ("x%s y%s z%s"):format(tostring(p.x), tostring(p.y), tostring(p.z))
end

local function clearElements()
	UI.elements = {}
end

-- ========= DRAW: COMMON =========
local function drawTopBar(title)
	UI.drawText(2, 1, ("HiveMind | %s"):format(title), colors.white, colors.black)
	local right = ("poll:%s"):format(autoPoll and "ON" or "OFF")
	UI.drawText(W - #right + 1, 1, right, autoPoll and colors.lime or colors.orange, colors.black)
end

local function drawFooter()
	-- bottom bar buttons
	local y = H
	UI.drawButton("exit", 2, y - 1, 10, 2, "EXIT", colors.white, colors.red, function()
		term.setCursorPos(1, 1)
		term.setBackgroundColor(colors.black)
		term.setTextColor(colors.white)
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

-- ========= DRAW: HOME (SCROLL LIST) =========
-- Each node card: status/fuel/pos + buttons: STAT, Y, PAUSE, RES, HOME
local function drawHome()
	UI.clear()
	clearElements()
	drawTopBar("NODES")
	UI.drawText(2, 2, "Tap a node card for details. Scroll: ▲ ▼", colors.gray, colors.black)

	-- layout
	local listTop = 4
	local listBottom = H - 3
	local cardH = 4
	local visible = math.floor((listBottom - listTop + 1) / cardH)
	if visible < 1 then
		visible = 1
	end

	scroll = clamp(scroll, 0, math.max(0, nodeCount - visible))

	-- scroll buttons
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

		-- card background strip
		UI.drawBox(2, y, W - 2, cardH, colors.gray, "", monitor)

		local title = ("Node %d"):format(idx)
		local st = nodeStateStr(n)
		local fuel = nodeFuelStr(n)
		local age = fmtAge(n.lastRxAt)

		UI.drawText(3, y, title, colors.black, colors.gray)
		UI.drawText(3, y + 1, ("st:%s fuel:%s age:%s"):format(st, fuel, age), colors.black, colors.gray)
		UI.drawText(3, y + 2, nodePosStr(n), colors.black, colors.gray)

		-- tap anywhere on left side of card -> detail
		UI.drawButton("open_" .. idx, 2, y, W - 24, cardH, "", colors.black, colors.gray, function()
			selectedId = idx
			screen = "detail"
		end)

		-- small action buttons on right side
		local bx = W - 21
		UI.drawButton("s_" .. idx, bx, y, 5, 1, "STAT", colors.black, colors.lightGray, function()
			sendCmd(idx, "status")
		end)
		UI.drawButton("y_" .. idx, bx + 6, y, 5, 1, "Y", colors.black, colors.lightGray, function()
			-- go to detail; choose Y there (SCADA style)
			selectedId = idx
			screen = "detail"
		end)

		UI.drawButton("p_" .. idx, bx, y + 1, 5, 1, "PAUS", colors.white, colors.orange, function()
			sendCmd(idx, "pause")
		end)
		UI.drawButton("r_" .. idx, bx + 6, y + 1, 5, 1, "RES", colors.black, colors.lime, function()
			sendCmd(idx, "resume")
		end)

		UI.drawButton("h_" .. idx, bx, y + 2, 11, 1, "HOME", colors.white, colors.blue, function()
			sendCmd(idx, "home")
		end)
	end

	drawFooter()
end

-- ========= DRAW: DETAIL =========
-- Large buttons and a compact status window + recent messages
local yEntry = "" -- typed digits for startlevel
local entryMode = false

local function drawDetail()
	UI.clear()
	clearElements()
	drawTopBar(("NODE %d"):format(selectedId))

	local n = nodes[selectedId] or { id = selectedId }
	local st = nodeStateStr(n)
	local fuel = nodeFuelStr(n)
	local age = fmtAge(n.lastRxAt)

	UI.drawText(2, 2, ("State: %s   Fuel: %s   Age: %s"):format(st, fuel, age), colors.white, colors.black)
	UI.drawText(2, 3, ("Pos: %s"):format(nodePosStr(n)), colors.white, colors.black)

	-- status box
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
		UI.drawText(3, 6, "No status yet. Tap STAT.", colors.black, colors.gray)
	end

	-- controls
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

	-- startlevel entry (SCADA keypad style)
	UI.drawText(2, cy + 3, "Startlevel Y:", colors.white, colors.black)
	UI.drawBox(16, cy + 2, 10, 3, colors.gray, "", monitor)
	UI.drawText(
		18,
		cy + 3,
		entryMode and ("[" .. (yEntry == "" and " " or yEntry) .. "]") or (yEntry == "" and "tap" or yEntry),
		colors.black,
		colors.gray
	)

	UI.drawButton("yEntry", 16, cy + 2, 10, 3, "", colors.black, colors.gray, function()
		entryMode = true
	end)

	UI.drawButton("goY", 28, cy + 2, 10, 3, "START", colors.white, colors.green, function()
		local y = tonumber(yEntry)
		if y then
			sendCmd(selectedId, "startlevel " .. y)
			yEntry = ""
			entryMode = false
		else
			log("invalid y")
		end
	end)

	UI.drawButton("back", W - 10, 2, 9, 2, "BACK", colors.black, colors.lightGray, function()
		screen = "home"
	end)

	-- recent raw RX (last 8 log lines relevant to this node)
	UI.drawBox(2, H - 10, W - 2, 7, colors.gray, "", monitor)
	UI.drawText(3, H - 10, "Recent", colors.black, colors.gray)

	local shown = 0
	for i = #appLog, 1, -1 do
		local line = appLog[i]
		if line:find("id:" .. tostring(selectedId)) or line:find("NODE " .. tostring(selectedId)) then
			UI.drawText(3, H - 10 + 1 + shown, line:sub(1, W - 6), colors.black, colors.gray)
			shown = shown + 1
			if shown >= 5 then
				break
			end
		end
	end

	drawFooter()
end

-- ========= DRAW: SETTINGS =========
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
		ensureNodes(math.max(1, nodeCount - 1))
		if selectedId > nodeCount then
			selectedId = nodeCount
		end
		scroll = clamp(scroll, 0, nodeCount)
	end)

	UI.drawText(2, 6, "Tip: set nodeCount to your turtle fleet size.", colors.gray, colors.black)

	UI.drawButton("pollNow", 2, 8, 14, 3, "POLL NOW", colors.black, colors.lightGray, function()
		for i = 1, nodeCount do
			sendCmd(i, "status")
		end
	end)

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
	else
		drawSettings()
	end
end

-- ========= INPUT: TOUCH + KEYPAD =========
-- We support monitor touches for buttons (UI.handleTouch),
-- and keyboard keys for scrolling and Y-entry digits.

local function handleKey(k)
	if screen == "home" then
		if k == keys.up then
			scroll = clamp(scroll - 1, 0, nodeCount)
		elseif k == keys.down then
			scroll = clamp(scroll + 1, 0, nodeCount)
		end
	elseif screen == "detail" then
		if entryMode then
			if k == keys.backspace then
				yEntry = yEntry:sub(1, math.max(0, #yEntry - 1))
			elseif k == keys.enter then
				entryMode = false
			elseif k == keys.minus then
				if #yEntry == 0 then
					yEntry = "-"
				end
			end
		end
	end
end

local function handleChar(ch)
	if screen == "detail" and entryMode then
		if ch:match("%d") then
			if #yEntry < 5 then
				yEntry = yEntry .. ch
			end
		end
	end
end

-- ========= POLLING =========
local function pollTick()
	-- poll a few nodes per tick, smooth traffic
	for _ = 1, POLL_BATCH_PER_TICK do
		sendCmd(pollCursor, "status")
		pollCursor = pollCursor + 1
		if pollCursor > nodeCount then
			pollCursor = 1
		end
	end
end

-- ========= MAIN LOOP =========
render()
log("HiveMind started")
pollTimer = os.startTimer(0.25)

while true do
	local e = { os.pullEvent() }

	if e[1] == "monitor_touch" then
		local x, y = e[3], e[4]
		UI.handleTouch(x, y)
		render()
	elseif e[1] == "modem_message" and e[3] == CMD_SEND_CHANNEL then
		local raw = e[5]
		local t = parseStatus(raw)

		if t and type(t) == "table" then
			local id = tonumber(t.id)
			if id and id >= 1 then
				ensureNodes(math.max(nodeCount, id))
				local n = nodes[id]
				n.lastRaw = raw
				n.lastRxAt = now()
				n.last = t
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
