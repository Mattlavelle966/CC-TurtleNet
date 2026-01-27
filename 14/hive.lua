-- hive.lua (clean + auto-run + full layer sweep)
-- Uses global commands with id prefix: "id:<n> goto x y z", "id:<n> home", "id:<n> status"
-- Requires turtle-side filtering (see patch below).

-- ===== CONFIG =====
local TOTAL_TURTLES = 5

local DB_BROADCAST_CHANNEL = 92
local CMD_RECV_CHANNEL = 90
local CMD_SEND_CHANNEL = 91

local MIN_X, MAX_X = 1, 100
local MIN_Z, MAX_Z = 1, 100
local MIN_Y, MAX_Y = 1, 100

local PING_INTERVAL = 2.0
local DISPATCH_INTERVAL = 0.2

-- DB persistence
local DB_SAVE_FILE = "HIVE_BLOCK_DB.txt"
local DB_SAVE_INTERVAL = 2.0
-- ===================

local modem = peripheral.find("modem") or error("No modem found")
modem.open(DB_BROADCAST_CHANNEL)
modem.open(CMD_SEND_CHANNEL)

local function now()
	return os.clock()
end

-- ===== DB persistence =====
local lastDbSaveAt = 0

local function loadDbFromDisk()
	if not fs.exists(DB_SAVE_FILE) then
		return nil
	end
	local f = fs.open(DB_SAVE_FILE, "r")
	if not f then
		return nil
	end
	local s = f.readAll()
	f.close()
	local ok, obj = pcall(textutils.unserialize, s)
	if ok and type(obj) == "table" then
		if type(obj.db) == "table" then
			return obj.db
		end
		return obj
	end
	return nil
end

local function saveDbToDisk(db)
	if not db then
		return
	end
	if (now() - lastDbSaveAt) < DB_SAVE_INTERVAL then
		return
	end
	lastDbSaveAt = now()
	local f = fs.open(DB_SAVE_FILE, "w")
	if not f then
		return
	end
	f.write(textutils.serialize({ db = db, savedAt = os.epoch("utc") }))
	f.close()
end
-- ==========================

-- ===== STATE =====
local DB = loadDbFromDisk()
local lastDbAt = DB and now() or nil

local turtles = {}
for i = 1, TOTAL_TURTLES do
	turtles[i] = {
		id = i,
		state = "Unknown",
		pos = nil,
		lastHeard = 0,

		assignedY = nil,
		stage = "idle", -- idle | to_start | sweeping | done
		z = 1,
		dir = 1, -- 1 means go to MAX_X, -1 means go to MIN_X
	}
end

-- ===== comms (id-prefixed strings) =====
local function txTo(id, cmd)
	modem.transmit(CMD_RECV_CHANNEL, CMD_SEND_CHANNEL, ("id:%d %s"):format(id, cmd))
end

local function sendStatusAll()
	for i = 1, TOTAL_TURTLES do
		txTo(i, "status")
	end
end

local function sendHome(id)
	txTo(id, "home")
end
local function sendGoto(id, x, y, z)
	txTo(id, ("goto %d %d %d"):format(x, y, z))
end

-- ===== DB helpers =====
local function layerRemainingGray(y)
	if not DB or not DB[y] then
		return nil
	end
	local count = 0
	for x = MIN_X, MAX_X do
		for z = MIN_Z, MAX_Z do
			if DB[y] and DB[y][x] and DB[y][x][z] == colors.gray then
				count = count + 1
			end
		end
	end
	return count
end

local function claimNextY()
	local used = {}
	for _, t in ipairs(turtles) do
		if t.assignedY then
			used[t.assignedY] = true
		end
	end
	for y = MIN_Y, MAX_Y do
		if not used[y] then
			local rem = layerRemainingGray(y)
			if rem == nil then
				return y
			end
			if rem > 0 then
				return y
			end
		end
	end
	return nil
end

-- ===== Turtle reply handling =====
local function handleReply(msg)
	if type(msg) ~= "string" then
		return
	end
	local ok, t = pcall(textutils.unserialize, msg)
	if not ok or type(t) ~= "table" then
		return
	end

	local id = tonumber(t.id)
	if not id or not turtles[id] then
		return
	end

	local tt = turtles[id]
	tt.lastHeard = now()
	if t.state then
		tt.state = t.state
	end
	if t.pos and type(t.pos) == "table" then
		tt.pos = { x = t.pos.x, y = t.pos.y, z = t.pos.z }
	end
end

-- ===== Sweep state machine =====
local function stepTurtle(t)
	-- only issue next waypoint when turtle is waiting
	if t.state ~= "Awaiting" and t.state ~= "Unknown" then
		return
	end

	if not t.assignedY then
		local y = claimNextY()
		if not y then
			return
		end
		t.assignedY = y
		t.stage = "to_start"
		t.z = MIN_Z
		t.dir = 1
	end

	-- if we can see DB, detect completion and send home
	local rem = layerRemainingGray(t.assignedY)
	if rem ~= nil and rem == 0 then
		sendHome(t.id)
		t.assignedY = nil
		t.stage = "idle"
		return
	end

	if t.stage == "to_start" then
		sendGoto(t.id, MIN_X, t.assignedY, MIN_Z)
		t.stage = "sweeping"
		t.z = MIN_Z
		t.dir = 1
		return
	end

	if t.stage == "sweeping" then
		-- waypoint endpoints: (100,y,z) then (1,y,z+1) then (100,y,z+1) ...
		local targetX = (t.dir == 1) and MAX_X or MIN_X
		local targetZ = t.z
		sendGoto(t.id, targetX, t.assignedY, targetZ)

		-- advance to next row
		if t.dir == 1 then
			t.dir = -1
		else
			t.dir = 1
		end

		if t.z >= MAX_Z then
			-- finished last row -> go home, release layer
			sendHome(t.id)
			t.assignedY = nil
			t.stage = "idle"
		else
			t.z = t.z + 1
		end
		return
	end
end

-- ===== UI =====
local function draw()
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.clear()
	term.setCursorPos(1, 1)

	print("HIVE (auto)")
	print("DB:", DB and "loaded" or "none", lastDbAt and ("age " .. string.format("%.1fs", now() - lastDbAt)) or "")
	print("DB file:", fs.exists(DB_SAVE_FILE) and "yes" or "no")
	print("")

	for _, t in ipairs(turtles) do
		local age = now() - (t.lastHeard or 0)
		local y = t.assignedY and tostring(t.assignedY) or "-"
		local pos = t.pos and (("(%d,%d,%d)"):format(t.pos.x, t.pos.y, t.pos.z)) or "(?)"
		print(
			("#%d  %s  y=%s  stage=%s  z=%d  pos=%s  heard=%.1fs"):format(
				t.id,
				tostring(t.state),
				y,
				t.stage,
				t.z or 0,
				pos,
				age
			)
		)
	end

	print("")
	print("Q=quit")
end

draw()

-- ===== main loop =====
local lastPing = 0
local lastDispatch = 0

while true do
	local e = { os.pullEventRaw() }

	if e[1] == "modem_message" then
		local ch = e[3]
		local payload = e[5]

		if ch == DB_BROADCAST_CHANNEL then
			local ok, p = pcall(textutils.unserialize, payload)
			if ok and type(p) == "table" and p.cmd == "db_broadcast" and type(p.db) == "table" then
				DB = p.db
				lastDbAt = now()
				saveDbToDisk(DB)
				draw()
			end
		elseif ch == CMD_SEND_CHANNEL then
			handleReply(payload)
			draw()
		end
	elseif e[1] == "char" then
		if e[2] == "q" or e[2] == "Q" then
			term.clear()
			return
		end
	end

	if (now() - lastPing) >= PING_INTERVAL then
		lastPing = now()
		sendStatusAll()
	end

	if (now() - lastDispatch) >= DISPATCH_INTERVAL then
		lastDispatch = now()
		for _, t in ipairs(turtles) do
			stepTurtle(t)
		end
	end
end
