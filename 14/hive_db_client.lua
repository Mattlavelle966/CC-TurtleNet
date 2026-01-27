-- hive_db_client.lua (simple: receive db_broadcast + count colors)
local DB_BROADCAST_CHANNEL = 92

-- counting a huge DB is expensive; throttle it
local COUNT_EVERY_SECONDS = 1.0

local modem = peripheral.find("modem")
if not modem then
	error("No modem found")
end
modem.open(DB_BROADCAST_CHANNEL)

local HIVE = {
	db = nil,
	lastTs = nil,
	lastRxAt = nil,
	rxCount = 0,
	badCount = 0,

	lastCountAt = nil,
	counts = { gray = 0, black = 0, yellow = 0, other = 0, total = 0 },
}

local function now()
	return os.clock()
end

local function tryUnserialize(s)
	if type(s) ~= "string" then
		return false, "not a string"
	end
	local ok, obj = pcall(function()
		return textutils.unserialize(s)
	end)
	if not ok then
		return false, "unserialize error"
	end
	if type(obj) ~= "table" then
		return false, "not a table"
	end
	return true, obj
end

local function countColors(db)
	local c = { gray = 0, black = 0, yellow = 0, other = 0, total = 0 }
	if type(db) ~= "table" then
		return c
	end

	-- db[layer][x][z] = colors.<...>
	for _, layer in pairs(db) do
		if type(layer) == "table" then
			for _, col in pairs(layer) do
				if type(col) == "table" then
					for _, v in pairs(col) do
						c.total = c.total + 1
						if v == colors.gray then
							c.gray = c.gray + 1
						elseif v == colors.black then
							c.black = c.black + 1
						elseif v == colors.yellow then
							c.yellow = c.yellow + 1
						else
							c.other = c.other + 1
						end
					end
				end
			end
		end
	end

	return c
end

local function draw()
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.clear()
	term.setCursorPos(1, 1)

	print("hive_db_client (simple)")
	print("listening on " .. DB_BROADCAST_CHANNEL)
	print(("rx=%d  bad=%d"):format(HIVE.rxCount, HIVE.badCount))

	if HIVE.lastRxAt then
		print(("age=%.2fs  ts=%s"):format(now() - HIVE.lastRxAt, tostring(HIVE.lastTs)))
	else
		print("age=N/A  ts=nil")
	end

	print("")
	print("COUNTS:")
	print(("  gray   (unmined): %d"):format(HIVE.counts.gray))
	print(("  black  (mined)  : %d"):format(HIVE.counts.black))
	print(("  yellow (turtles): %d"):format(HIVE.counts.yellow))
	print(("  other          : %d"):format(HIVE.counts.other))
	print(("  total cells    : %d"):format(HIVE.counts.total))

	print("")
	print("Press Q to quit.")
end

draw()

local redrawTimer = os.startTimer(0.25)

while true do
	local e = { os.pullEvent() }

	if e[1] == "modem_message" and e[3] == DB_BROADCAST_CHANNEL then
		local raw = e[5]
		local ok, payloadOrErr = tryUnserialize(raw)

		if ok then
			local payload = payloadOrErr
			if payload.cmd == "db_broadcast" and type(payload.db) == "table" then
				HIVE.db = payload.db
				HIVE.lastTs = payload.ts
				HIVE.lastRxAt = now()
				HIVE.rxCount = HIVE.rxCount + 1
			else
				HIVE.badCount = HIVE.badCount + 1
			end
		else
			HIVE.badCount = HIVE.badCount + 1
		end

		-- throttle counting
		if HIVE.db and ((not HIVE.lastCountAt) or (now() - HIVE.lastCountAt >= COUNT_EVERY_SECONDS)) then
			HIVE.counts = countColors(HIVE.db)
			HIVE.lastCountAt = now()
		end

		draw()
	elseif e[1] == "timer" and e[2] == redrawTimer then
		redrawTimer = os.startTimer(0.25)
		draw()
	elseif e[1] == "char" then
		if e[2] == "q" or e[2] == "Q" then
			term.setBackgroundColor(colors.black)
			term.setTextColor(colors.white)
			term.clear()
			print("bye")
			return
		end
	end
end
