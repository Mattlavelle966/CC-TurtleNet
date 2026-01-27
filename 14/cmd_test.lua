-- cmd_test.lua (tablet-friendly + DB broadcast handling + stable UI + ID-targeted commands)
local CMD_RECV_CHANNEL = 90
local CMD_SEND_CHANNEL = 91
local DB_BROADCAST_CHANNEL = 92

local modem = peripheral.find("modem")
if not modem then
	error("No modem found")
end

modem.open(CMD_SEND_CHANNEL)
modem.open(DB_BROADCAST_CHANNEL)

local W, H = term.getSize()

-- --- state ---
local lastDbMsgAt = nil
local lastDbPayload = nil
local lastDbRawLen = 0
local lastDbArrivedAt = nil
local dbIntervalEstimate = nil

local dbPanelEnabled = false
local menuEnabled = true

local logLines = {}
local LOG_MAX = math.max(5, H - 14)

-- NEW: target turtle id
local TARGET_ID = 1

local function now()
	return os.clock()
end

local function log(s)
	s = tostring(s)
	table.insert(logLines, s)
	while #logLines > LOG_MAX do
		table.remove(logLines, 1)
	end
end

local function dbQuickStats(db)
	if type(db) ~= "table" then
		return { ok = false, reason = "db not a table" }
	end

	local layerCount = 0
	local minLayer, maxLayer = nil, nil
	for k, _ in pairs(db) do
		if type(k) == "number" then
			layerCount = layerCount + 1
			if not minLayer or k < minLayer then
				minLayer = k
			end
			if not maxLayer or k > maxLayer then
				maxLayer = k
			end
		end
	end

	local sampleLayer = nil
	if minLayer and db[minLayer] then
		sampleLayer = db[minLayer]
	elseif maxLayer and db[maxLayer] then
		sampleLayer = db[maxLayer]
	end

	local xCount, minX, maxX = 0, nil, nil
	local zCount, minZ, maxZ = 0, nil, nil

	if type(sampleLayer) == "table" then
		for x, _ in pairs(sampleLayer) do
			if type(x) == "number" then
				xCount = xCount + 1
				if not minX or x < minX then
					minX = x
				end
				if not maxX or x > maxX then
					maxX = x
				end
			end
		end

		local sampleCol = nil
		if minX and sampleLayer[minX] then
			sampleCol = sampleLayer[minX]
		elseif maxX and sampleLayer[maxX] then
			sampleCol = sampleLayer[maxX]
		end

		if type(sampleCol) == "table" then
			for z, _ in pairs(sampleCol) do
				if type(z) == "number" then
					zCount = zCount + 1
					if not minZ or z < minZ then
						minZ = z
					end
					if not maxZ or z > maxZ then
						maxZ = z
					end
				end
			end
		end
	end

	return {
		ok = true,
		layers = layerCount,
		minLayer = minLayer,
		maxLayer = maxLayer,
		xs = xCount,
		minX = minX,
		maxX = maxX,
		zs = zCount,
		minZ = minZ,
		maxZ = maxZ,
	}
end

local function drawDbLight()
	local cx, cy = term.getCursorPos()

	local age = lastDbMsgAt and (now() - lastDbMsgAt) or 9999
	local label, bg = "DB: NONE", colors.red
	if age < 2.5 then
		label, bg = "DB: OK", colors.green
	elseif age < 8 then
		label, bg = "DB: SLOW", colors.yellow
	end

	local pill = (" %s "):format(label)
	local x = math.max(1, W - #pill + 1)

	term.setCursorPos(x, 1)
	term.setBackgroundColor(bg)
	term.setTextColor(colors.black)
	term.write(pill)

	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.setCursorPos(cx, cy)
end

local function drawHeader()
	term.setCursorPos(1, 1)
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.clearLine()

	term.write(("cmd_test | target id:%d | "):format(TARGET_ID))
	drawDbLight()
end

local function drawMenu()
	term.setCursorPos(1, 3)
	term.setTextColor(colors.white)
	term.setBackgroundColor(colors.black)

	print("Select command:")
	print("T) set target turtle id")
	print("1) status")
	print("2) goto")
	print("3) home")
	print("4) stop")
	print("5) reset")
	print("6) show last DB broadcast summary")
	print("7) toggle DB panel (" .. (dbPanelEnabled and "ON" or "OFF") .. ")")
	print("8) clear log")
	print("9) redraw menu")
	print("0) quit")
	print("")
end

local function drawDbPanel()
	if not dbPanelEnabled then
		return
	end

	local panelW = math.min(24, math.max(12, math.floor(W * 0.35)))
	local panelH = 7
	local panelX = W - panelW + 1
	local panelY = 2

	if panelW < 12 or panelX < 1 then
		return
	end

	local function fillLine(y, bg)
		term.setCursorPos(panelX, y)
		term.setBackgroundColor(bg)
		term.setTextColor(colors.black)
		term.write((" "):rep(panelW))
	end

	local function writeAt(line, text)
		local y = panelY + line
		term.setCursorPos(panelX + 1, y)
		term.setBackgroundColor(colors.gray)
		term.setTextColor(colors.black)
		local s = tostring(text or "")
		if #s > panelW - 2 then
			s = s:sub(1, panelW - 2)
		end
		term.write(s .. (" "):rep((panelW - 2) - #s))
	end

	for i = 0, panelH - 1 do
		fillLine(panelY + i, colors.gray)
	end

	writeAt(0, "DB PANEL")
	local age = lastDbMsgAt and (now() - lastDbMsgAt) or nil
	writeAt(1, "Age: " .. (age and string.format("%.2fs", age) or "N/A"))
	writeAt(2, "Bytes: " .. tostring(lastDbRawLen))
	writeAt(3, "Int~: " .. (dbIntervalEstimate and string.format("%.2fs", dbIntervalEstimate) or "N/A"))

	if lastDbPayload and type(lastDbPayload) == "table" then
		writeAt(4, "cmd: " .. tostring(lastDbPayload.cmd))
		local st = dbQuickStats(lastDbPayload.db)
		if st.ok then
			writeAt(5, ("L:%s X:%s Z:%s"):format(st.layers or "?", st.xs or "?", st.zs or "?"))
			writeAt(6, ("Y:%s-%s"):format(tostring(st.minLayer), tostring(st.maxLayer)))
		else
			writeAt(5, "db: bad")
			writeAt(6, "")
		end
	else
		writeAt(4, "No payload yet")
		writeAt(5, "")
		writeAt(6, "")
	end

	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
end

local function drawLog()
	print("--- LOG ---")
	for i = 1, #logLines do
		print(logLines[i])
	end
	print("-----------")
end

local function render(input)
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.clear()

	drawHeader()
	if menuEnabled then
		drawMenu()
	end
	drawDbPanel()
	drawLog()

	term.setCursorPos(1, H)
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.clearLine()
	term.write("> " .. (input or ""))
end

-- NEW: id-prefixed send helper
local function sendCmd(msg)
	msg = tostring(msg)
	local out = ("id:%d %s"):format(TARGET_ID, msg)
	modem.transmit(CMD_RECV_CHANNEL, CMD_SEND_CHANNEL, out)
end

-- input state machine
local mode = "menu" -- menu | set_id | goto_x | goto_y | goto_z
local tmpX, tmpY = nil, nil
local input = ""

local function promptLine(label)
	log(label)
end

render(input)
promptLine("ready")

local refreshTimer = os.startTimer(0.25)

while true do
	local e = { os.pullEvent() }

	if e[1] == "modem_message" and e[3] == DB_BROADCAST_CHANNEL then
		local raw = e[5]
		lastDbRawLen = type(raw) == "string" and #raw or 0

		local ok, payload = pcall(function()
			if type(raw) == "string" then
				return textutils.unserialize(raw)
			end
			return nil
		end)

		if ok and type(payload) == "table" and payload.cmd == "db_broadcast" then
			lastDbPayload = payload
			local tnow = now()
			if lastDbArrivedAt then
				local dt = tnow - lastDbArrivedAt
				dbIntervalEstimate = dbIntervalEstimate and (dbIntervalEstimate * 0.7 + dt * 0.3) or dt
			end
			lastDbArrivedAt = tnow
			lastDbMsgAt = tnow
			log(("DB rx: ts=%s bytes=%d"):format(tostring(payload.ts), lastDbRawLen))
		else
			log("DB rx: unserialize failed or invalid payload")
		end

		render(input)
	elseif e[1] == "modem_message" and e[3] == CMD_SEND_CHANNEL then
		log("REPLY: " .. tostring(e[5]))
		render(input)
	elseif e[1] == "timer" and e[2] == refreshTimer then
		refreshTimer = os.startTimer(0.25)
		render(input)
	elseif e[1] == "char" then
		input = input .. e[2]
		render(input)
	elseif e[1] == "key" then
		local key = e[2]

		if key == keys.backspace then
			input = input:sub(1, math.max(0, #input - 1))
			render(input)
		elseif key == keys.enter then
			local entered = input
			input = ""
			render(input)

			if mode == "set_id" then
				local n = tonumber(entered)
				if n and n >= 1 then
					TARGET_ID = math.floor(n)
					log("target id set to " .. TARGET_ID)
				else
					log("invalid id")
				end
				mode = "menu"
				render(input)
			elseif mode == "goto_x" then
				tmpX = tonumber(entered)
				mode = "goto_y"
				promptLine("y:")
				render(input)
			elseif mode == "goto_y" then
				tmpY = tonumber(entered)
				mode = "goto_z"
				promptLine("z:")
				render(input)
			elseif mode == "goto_z" then
				local z = tonumber(entered)
				if tmpX and tmpY and z then
					sendCmd(("goto %d %d %d"):format(tmpX, tmpY, z))
					log(("sent id:%d goto %d %d %d"):format(TARGET_ID, tmpX, tmpY, z))
				else
					log("invalid coords")
				end
				tmpX, tmpY = nil, nil
				mode = "menu"
				render(input)
			else
				local choice = (entered or ""):match("^%s*(.-)%s*$")

				if choice == "T" or choice == "t" then
					mode = "set_id"
					promptLine("target id:")
				elseif choice == "1" then
					sendCmd("status")
					log("sent status")
				elseif choice == "2" then
					mode = "goto_x"
					promptLine("x:")
				elseif choice == "3" then
					sendCmd("home")
					log("sent home")
				elseif choice == "4" then
					sendCmd("stop")
					log("sent stop")
				elseif choice == "5" then
					sendCmd("reset")
					log("sent reset")
				elseif choice == "6" then
					if lastDbPayload then
						local st = dbQuickStats(lastDbPayload.db)
						log("DB payload summary:")
						log("  ts=" .. tostring(lastDbPayload.ts))
						log("  bytes=" .. tostring(lastDbRawLen))
						if lastDbMsgAt then
							log(("  age=%.2fs"):format(now() - lastDbMsgAt))
						end
						if dbIntervalEstimate then
							log(("  interval~=%.2fs"):format(dbIntervalEstimate))
						end
						if st.ok then
							log(
								("  layers=%s (Y %s-%s)"):format(
									tostring(st.layers),
									tostring(st.minLayer),
									tostring(st.maxLayer)
								)
							)
							log(("  X=%s (X %s-%s)"):format(tostring(st.xs), tostring(st.minX), tostring(st.maxX)))
							log(("  Z=%s (Z %s-%s)"):format(tostring(st.zs), tostring(st.minZ), tostring(st.maxZ)))
						else
							log("  db stats failed: " .. tostring(st.reason))
						end
					else
						log("DB: (none received yet)")
					end
				elseif choice == "7" then
					dbPanelEnabled = not dbPanelEnabled
					log("DB panel: " .. (dbPanelEnabled and "ON" or "OFF"))
				elseif choice == "8" then
					logLines = {}
					log("log cleared")
				elseif choice == "9" then
					log("redraw")
				elseif choice == "0" then
					term.setBackgroundColor(colors.black)
					term.setTextColor(colors.white)
					term.clear()
					print("bye")
					return
				else
					log("invalid option")
				end

				render(input)
			end
		end
	end
end
