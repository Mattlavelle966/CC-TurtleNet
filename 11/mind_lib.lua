Mind = {}

function Mind.vectorCopy(p)
	return { x = p.x, y = p.y, z = p.z }
end

function Mind.init(TMNL, opts)
	opts = opts or {}

	Mind.nodeId = TMNL.NodeId
	Mind.facing = TMNL.Facing

	Mind.STARTING_POS = Mind.vectorCopy(TMNL.currentCoordinates)
	Mind.pos = Mind.vectorCopy(TMNL.currentCoordinates)

	Mind.startFacing = TMNL.Facing
	Mind.homeFacing = (TMNL.Facing + 2) % 4

	Mind.home = {
		x = Mind.STARTING_POS.x,
		y = Mind.STARTING_POS.y,
		z = Mind.STARTING_POS.z,
		facing = Mind.homeFacing,
	}

	Mind.workY = opts.workY or Mind.STARTING_POS.y

	Mind.bounds = opts.bounds
		or {
			minX = nil,
			maxX = nil,
			minY = nil,
			maxY = nil,
			minZ = nil,
			maxZ = nil,
		}

	Mind.fuelMin = opts.fuelMin or nil

	Mind.peers = {}
	Mind.seen = {}
	Mind.mined = {}

	Mind.flags = { returningHome = false, dumping = false, paused = false, abort = false, wantHome = false }
end

function Mind._hasMethod(side, method)
	if not peripheral.isPresent(side) then
		return false
	end
	return pcall(function()
		return peripheral.call(side, method)
	end)
end

function Mind.isInventory(side)
	local ok, data
	if side == "up" then
		ok, data = turtle.inspectUp()
	elseif side == "down" then
		ok, data = turtle.inspectDown()
	else
		ok, data = turtle.inspect()
	end

	if not ok or not data or not data.name then
		return false
	end

	local name = data.name

	-- turtles (BLOCK THESE: never dig them)
	if data.tags and data.tags["computercraft:turtle"] then
		return true
	end

	-- fallback: name variants across CC versions/mods
	if name:find("turtle") and name:find("computercraft") then
		return true
	end

	-- inventories
	if name:find("chest") then
		return true
	end
	if name:find("barrel") then
		return true
	end
	if name:find("shulker_box") then
		return true
	end
	if name:find("hopper") then
		return true
	end
	if name:find("furnace") then
		return true
	end

	return false
end

function Mind._clearFront(maxTries)
	maxTries = maxTries or 6
	for i = 1, maxTries do
		if not turtle.detect() then
			return true
		end

		if Mind.isInventory("front") then
			return false -- turtle/chest/etc: do not dig
		end

		turtle.dig()
		sleep(0) -- yield so falling blocks update + let other thread run
	end
	return not turtle.detect()
end

function Mind.safeForward()
	local sx = TMNL.currentCoordinates.x
	local sz = TMNL.currentCoordinates.z

	if turtle.detect() then
		if not Mind._clearFront(8) then
			print("IM BLOCKED: turtle/inventory detected")
			Mind.flags.abort = true
			Mind.flags.wantHome = true
			return false
		end
	end

	TMNL.Forward()

	if TMNL.currentCoordinates.x == sx and TMNL.currentCoordinates.z == sz then
		-- still didn't move; one more quick clear attempt (sand/gravel timing)
		if turtle.detect() then
			Mind._clearFront(3)
			TMNL.Forward()
		end
	end

	if TMNL.currentCoordinates.x == sx and TMNL.currentCoordinates.z == sz then
		return false
	end

	Mind.pos.x = TMNL.currentCoordinates.x
	Mind.pos.y = TMNL.currentCoordinates.y
	Mind.pos.z = TMNL.currentCoordinates.z
	return true
end

function Mind.safeDown()
	local startY = TMNL.currentCoordinates.y

	if turtle.detectDown() then
		if Mind.isInventory("down") then
			print("IM BLOCKED: inventory/turtle below")
			return false
		end
		turtle.digDown()
	end

	TMNL.Down()

	if TMNL.currentCoordinates.y == startY then
		return false
	end

	Mind.pos.y = TMNL.currentCoordinates.y
	return true
end

function Mind.safeUp()
	local startY = TMNL.currentCoordinates.y

	if turtle.detectUp() then
		if Mind.isInventory("up") then
			print("IM BLOCKED: inventory/turtle above")
			return false
		end
		turtle.digUp()
	end

	TMNL.Up()

	if TMNL.currentCoordinates.y == startY then
		print("IM BLOCKED: cannot move up")
		return false
	end

	Mind.pos.y = TMNL.currentCoordinates.y
	return true
end

function Mind.turnTo(targetFacing)
	while TMNL.Facing ~= targetFacing do
		TMNL.TurnRight()
	end
end
--Mind.goTo(Mind.home)
--Mind.turnTo(Mind.home.facing)
--or

--Mind.goTo({ x=10, y=5, z=20 })
function Mind.goTo(target)
	while Mind.pos.y < target.y do
		if Mind.flags and Mind.flags.abort then
			return false
		end
		sleep(0)
		if not Mind.safeUp() then
			return false
		end
	end

	while Mind.pos.y > target.y do
		if Mind.flags and Mind.flags.abort then
			return false
		end
		sleep(0)
		if not Mind.safeDown() then
			return false
		end
	end

	while Mind.pos.x ~= target.x do
		if Mind.flags and Mind.flags.abort then
			return false
		end
		sleep(0)

		if target.x < Mind.pos.x then
			Mind.turnTo(0)
		else
			Mind.turnTo(2)
		end
		if not Mind.safeForward() then
			return false
		end
	end

	while Mind.pos.z ~= target.z do
		if Mind.flags and Mind.flags.abort then
			return false
		end
		sleep(0)

		if target.z < Mind.pos.z then
			Mind.turnTo(1)
		else
			Mind.turnTo(3)
		end
		if not Mind.safeForward() then
			return false
		end
	end

	if target.facing ~= nil then
		Mind.turnTo(target.facing)
	end

	return true
end

-- HIVE inspectDown
--

--
-- =========================
-- HIVE COMMAND + WORKER JOBS
-- =========================
-- This replaces the old "goto target" mind with:
-- startlevel(y): serpentine sweep inside bounds on that Y
-- pause/resume/home/status
--
-- NOTE: Your NodeMind.lua already does "id:<n>" filtering before enqueueing Mind.cmdInbox,
-- so here we just accept plain strings/tables and execute. :contentReference[oaicite:4]{index=4}

function Mind.initCmd(modem, cmdRecvCh, cmdSendCh)
	Mind.cmdInbox = {}

	Mind.cmdModem = modem
	Mind.cmdRecvCh = cmdRecvCh
	Mind.cmdSendCh = cmdSendCh

	-- states: Awaiting | Working | Paused | Returning | Dead
	Mind.state = "Awaiting"

	-- job object:
	-- {
	--   type="level",
	--   y=<number>,
	--   minX,maxX,minZ,maxZ,
	--   x=<cursorX>, z=<cursorZ>,
	--   dirX=1|-1,        -- current row direction
	--   started=<bool>
	-- }
	Mind.job = nil

	-- legacy fields (kept so other code doesn't break)
	Mind.target = nil
	Mind.failCount = 0
	Mind.failLimit = 8

	-- fuel safety
	-- fuelMin means: "must always maintain enough fuel to return home + buffer"
	Mind.fuelBuffer = Mind.fuelBuffer or 50

	modem.open(cmdRecvCh)

	-- announce presence once
	Mind._cmdTx({ cmd = "hello", id = TMNL.NodeId, pos = TMNL.currentCoordinates, state = Mind.state })
end

function Mind._cmdTx(obj)
	Mind.cmdModem.transmit(Mind.cmdSendCh, Mind.cmdRecvCh, textutils.serialize(obj))
end

function Mind._stateObj(extra)
	local lvl = turtle.getFuelLevel()
	local fuel = lvl
	if lvl == "unlimited" then
		fuel = -1
	end

	local o = {
		cmd = "status",
		id = TMNL.NodeId,
		state = Mind.state,
		pos = TMNL.currentCoordinates,
		facing = TMNL.Facing,
		fuel = fuel,
		failCount = Mind.failCount,
		job = Mind.job,
	}
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			o[k] = v
		end
	end
	return o
end

-- -------------------------
-- FUEL / INVENTORY HELPERS
-- -------------------------

function Mind._fuelIsUnlimited()
	return turtle.getFuelLevel() == "unlimited"
end

function Mind._calcDistManhattan(a, b)
	return math.abs(a.x - b.x) + math.abs(a.y - b.y) + math.abs(a.z - b.z)
end

function Mind._tryRefuelAll()
	-- tries to refuel from whatever is in inventory
	for slot = 1, 16 do
		turtle.select(slot)
		if turtle.refuel(0) then
			-- refuel as much as possible from this slot
			turtle.refuel(64)
		end
	end
	turtle.select(1)
end

function Mind._ensureFuelForReturn()
	if Mind.fuelMin == nil or Mind._fuelIsUnlimited() then
		return true
	end

	-- estimate fuel needed to get home + buffer
	local need = Mind._calcDistManhattan(TMNL.currentCoordinates, Mind.home) + (Mind.fuelBuffer or 50)
	local lvl = turtle.getFuelLevel()

	if lvl >= math.max(Mind.fuelMin, need) then
		return true
	end

	-- attempt refuel from inventory
	Mind._tryRefuelAll()
	lvl = turtle.getFuelLevel()
	if lvl >= math.max(Mind.fuelMin, need) then
		return true
	end

	-- still low: go home and pause (operator can supply fuel)
	Mind._cmdTx(Mind._stateObj({ note = "low_fuel_returning_home" }))
	Mind.flags.abort = true
	Mind.flags.wantHome = true
	Mind.state = "Paused"

	Mind._cmdTx(Mind._stateObj({ note = "paused_low_fuel" }))
	return false
end

function Mind._inventoryFull()
	for i = 1, 16 do
		if turtle.getItemCount(i) == 0 then
			return false
		end
	end
	return true
end

function Mind._dumpToHomeChest()
	-- very simple: at home, try dropDown then drop
	-- (you can refine later, but this keeps it local + safe)
	if
		TMNL.currentCoordinates.x ~= Mind.home.x
		or TMNL.currentCoordinates.y ~= Mind.home.y
		or TMNL.currentCoordinates.z ~= Mind.home.z
	then
		return false
	end

	for i = 1, 16 do
		turtle.select(i)
		turtle.dropDown()
		turtle.drop()
	end
	turtle.select(1)
	return true
end

function Mind._ensureNotOutsideBounds()
	if not Mind.bounds then
		return true
	end

	local b = Mind.bounds
	local p = TMNL.currentCoordinates

	if b.minX and p.x < b.minX then
		return false
	end
	if b.maxX and p.x > b.maxX then
		return false
	end
	if b.minY and p.y < b.minY then
		return false
	end
	if b.maxY and p.y > b.maxY then
		return false
	end
	if b.minZ and p.z < b.minZ then
		return false
	end
	if b.maxZ and p.z > b.maxZ then
		return false
	end

	return true
end

-- -------------------------
-- LEVEL JOB (SERPENTINE)
-- -------------------------

function Mind._startLevelJob(y)
	local b = Mind.bounds or {}
	if not (b.minX and b.maxX and b.minZ and b.maxZ) then
		Mind._cmdTx(Mind._stateObj({ note = "refused_missing_bounds" }))
		return false
	end

	Mind.job = {
		type = "level",
		y = tonumber(y),
		minX = b.minX,
		maxX = b.maxX,
		minZ = b.minZ,
		maxZ = b.maxZ,
		x = b.minX,
		z = b.minZ,
		dirX = 1,
		started = false,
	}
	Mind.state = "Working"
	Mind.failCount = 0
	Mind._cmdTx(Mind._stateObj({ note = "accepted_startlevel", y = tonumber(y) }))
	return true
end

function Mind._levelRowTargetX()
	if not Mind.job then
		return nil
	end
	if Mind.job.dirX == 1 then
		return Mind.job.maxX
	end
	return Mind.job.minX
end

function Mind._advanceToNextRow()
	-- move z +1, flip dir, keep x where it is
	local j = Mind.job
	if j.z >= j.maxZ then
		return false -- done
	end
	j.z = j.z + 1
	j.dirX = -j.dirX
	return true
end

function Mind._tickLevelJob()
	local j = Mind.job
	if not j or j.type ~= "level" then
		return
	end

	-- pause gate
	if Mind.state == "Paused" then
		return
	end

	-- bounds safety gate (should NEVER happen if goTo is correct, but keep hard-stop)
	if not Mind._ensureNotOutsideBounds() then
		Mind.state = "Dead"
		Mind._cmdTx(Mind._stateObj({ note = "dead_out_of_bounds" }))
		return
	end

	-- fuel gate (may set Paused)
	if not Mind._ensureFuelForReturn() then
		return
	end

	-- inventory gate (optional, but prevents getting stuck forever)
	if Mind._inventoryFull() then
		Mind._cmdTx(Mind._stateObj({ note = "inventory_full_returning_home" }))
		Mind.state = "Returning"
		Mind.goTo(Mind.home)
		Mind.turnTo(Mind.home.facing)
		Mind._dumpToHomeChest()
		Mind.state = "Working"
		Mind._cmdTx(Mind._stateObj({ note = "resumed_after_dump" }))
	end

	-- first time: go to the job start corner at the requested Y
	if not j.started then
		local ok = Mind.goTo({ x = j.minX, y = j.y, z = j.minZ })
		if not ok then
			Mind.failCount = Mind.failCount + 1
			Mind._cmdTx(Mind._stateObj({ note = "blocked_going_to_start", failCount = Mind.failCount }))
			if Mind.failCount >= Mind.failLimit then
				Mind.state = "Dead"
				Mind._cmdTx(Mind._stateObj({ note = "dead_failLimit" }))
			else
				Mind.state = "Paused"
			end
			return
		end
		j.started = true
		j.x = TMNL.currentCoordinates.x
		j.z = TMNL.currentCoordinates.z
		Mind._cmdTx(Mind._stateObj({ note = "at_start_begin_sweep" }))
	end

	-- row target: sweep X to either minX or maxX (serpentine)
	local targetX = Mind._levelRowTargetX()

	-- if not at correct Z (should be), correct it
	if TMNL.currentCoordinates.z ~= j.z then
		local okZ = Mind.goTo({ x = TMNL.currentCoordinates.x, y = j.y, z = j.z })
		if not okZ then
			Mind.failCount = Mind.failCount + 1
			Mind._cmdTx(Mind._stateObj({ note = "blocked_correcting_z", failCount = Mind.failCount }))
			if Mind.failCount >= Mind.failLimit then
				Mind.state = "Dead"
				Mind._cmdTx(Mind._stateObj({ note = "dead_failLimit" }))
			else
				Mind.state = "Paused"
			end
			return
		end
	end

	-- move one "segment": go to end of row (cheaper to do in one goTo than per-block)
	if TMNL.currentCoordinates.x ~= targetX then
		local ok = Mind.goTo({ x = targetX, y = j.y, z = j.z })
		if ok then
			j.x = TMNL.currentCoordinates.x
			j.z = TMNL.currentCoordinates.z
			Mind.failCount = 0
			Mind._cmdTx(Mind._stateObj({ note = "row_complete", rowZ = j.z }))
		else
			Mind.failCount = Mind.failCount + 1
			Mind._cmdTx(Mind._stateObj({ note = "blocked_on_row", failCount = Mind.failCount }))
			if Mind.failCount >= Mind.failLimit then
				Mind.state = "Dead"
				Mind._cmdTx(Mind._stateObj({ note = "dead_failLimit" }))
			else
				Mind.state = "Paused"
			end
			return
		end
	end

	-- at end of row: advance to next row (z+1) or finish
	if not Mind._advanceToNextRow() then
		-- finished entire layer
		Mind._cmdTx(Mind._stateObj({ cmd = "done", note = "level_complete", y = j.y }))
		Mind.state = "Awaiting"
		Mind.job = nil
		return
	end

	-- go to next row start position (same x as end, z+1)
	local okRow = Mind.goTo({ x = TMNL.currentCoordinates.x, y = j.y, z = j.z })
	if not okRow then
		Mind.failCount = Mind.failCount + 1
		Mind._cmdTx(Mind._stateObj({ note = "blocked_advancing_row", failCount = Mind.failCount }))
		if Mind.failCount >= Mind.failLimit then
			Mind.state = "Dead"
			Mind._cmdTx(Mind._stateObj({ note = "dead_failLimit" }))
		else
			Mind.state = "Paused"
		end
		return
	end
end

-- -------------------------
-- LEGACY: acceptTarget (kept)
-- -------------------------
function Mind._acceptTarget(t)
	-- legacy goto support: still useful for "home" / manual positioning
	Mind.target = { x = t.x, y = t.y, z = t.z, facing = t.facing }
	Mind.state = "Working"
	Mind.job = { type = "goto", target = Mind.target }
	Mind._cmdTx({ cmd = "accepted", id = TMNL.NodeId, target = Mind.target, pos = TMNL.currentCoordinates })
end

function Mind._tickGotoJob()
	if not Mind.job or Mind.job.type ~= "goto" then
		return
	end
	if Mind.state == "Paused" then
		return
	end

	if not Mind._ensureFuelForReturn() then
		return
	end

	local ok = Mind.goTo(Mind.job.target)
	if ok then
		if Mind.job.target.facing ~= nil then
			Mind.turnTo(Mind.job.target.facing)
		end
		Mind.state = "Awaiting"
		Mind.job = nil
		Mind.target = nil
		Mind.failCount = 0
		Mind._cmdTx({ cmd = "done", id = TMNL.NodeId, pos = TMNL.currentCoordinates })
		return
	end

	Mind.failCount = Mind.failCount + 1
	Mind._cmdTx(Mind._stateObj({ note = "blocked_goto", failCount = Mind.failCount }))

	if Mind.failCount >= Mind.failLimit then
		Mind.state = "Dead"
		Mind._cmdTx(Mind._stateObj({ note = "dead_failLimit" }))
	else
		Mind.state = "Paused"
	end
end

-- -------------------------
-- COMMAND PARSER / API
-- -------------------------
function Mind.handleCmdMessage(msg)
	local t = nil
	local cmd = nil

	-- Normalize incoming message into cmd + optional table t
	if type(msg) == "string" then
		local ut = textutils.unserialize(msg)
		if type(ut) == "table" then
			t = ut
			cmd = t.cmd
		else
			cmd = msg:match("^%s*(.-)%s*$") -- trimmed raw command text
		end
	elseif type(msg) == "table" then
		t = msg
		cmd = t.cmd
	end

	if type(cmd) ~= "string" then
		return
	end

	-- ===== UI COMMANDS (DO NOT CHANGE UI) =====

	if cmd == "status" then
		Mind._cmdTx(Mind._stateObj({ note = "status" }))
		return
	end

	if cmd == "pause" then
		Mind.state = "Paused"
		Mind.flags.paused = true
		Mind._cmdTx(Mind._stateObj({ note = "paused" }))
		return
	end

	if cmd == "resume" then
		Mind.flags.paused = false
		if Mind.state == "Paused" then
			Mind.state = "Awaiting"
		end
		Mind._cmdTx(Mind._stateObj({ note = "resumed" }))
		return
	end

	-- IMPORTANT: do NOT call goTo() inside command handler anymore
	if cmd == "home" then
		Mind.flags.abort = true
		Mind.flags.wantHome = true
		Mind._cmdTx(Mind._stateObj({ note = "returning_home" }))
		return
	end

	if cmd == "stop" then
		Mind.flags.abort = true
		Mind.flags.wantHome = false
		Mind._cmdTx(Mind._stateObj({ note = "stopping" }))
		return
	end

	-- keep your existing goto/startlevel parsing below (examples):
	-- goto x y z
	local gx, gy, gz = cmd:match("^goto%s+(-?%d+)%s+(-?%d+)%s+(-?%d+)%s*$")
	if gx then
		Mind.job = { type = "goto", target = { x = tonumber(gx), y = tonumber(gy), z = tonumber(gz) } }
		Mind.state = "Working"
		Mind._cmdTx(Mind._stateObj({ note = "goto_set", x = tonumber(gx), y = tonumber(gy), z = tonumber(gz) }))
		return
	end

	-- startlevel y
	local ly = cmd:match("^startlevel%s+(-?%d+)%s*$")
	if ly then
		Mind.job = { type = "level", y = tonumber(ly) }
		Mind.state = "Working"
		Mind._cmdTx(Mind._stateObj({ note = "level_set", y = tonumber(ly) }))
		return
	end

	-- if you have other commands (reset, etc.) keep them here...
end

-- -------------------------
-- MAIN TICK (MovementLoop calls this name)
-- -------------------------
function Mind.stepToTarget()
	-- ===============================
	-- HARD STATES
	-- ===============================
	if Mind.state == "Dead" then
		return
	end

	if Mind.flags and Mind.flags.paused then
		return
	end

	-- ===============================
	-- ASYNC INTERRUPT FROM UI
	-- ===============================
	if Mind.flags and Mind.flags.abort then
		Mind.flags.abort = false

		-- UI said "home"
		if Mind.flags.wantHome then
			Mind.flags.wantHome = false

			Mind.job = nil
			Mind.target = nil
			Mind.failCount = 0
			Mind.state = "Returning"

			local ok = Mind.goTo(Mind.home)
			if ok then
				if Mind.home.facing ~= nil then
					Mind.turnTo(Mind.home.facing)
				end
				Mind.state = "Awaiting"
				Mind._cmdTx(Mind._stateObj({ note = "at_home" }))
			else
				Mind.state = "Paused"
				Mind._cmdTx(Mind._stateObj({ note = "blocked_returning_home" }))
			end
			return
		end

		-- UI said "stop"
		Mind.job = nil
		Mind.target = nil
		Mind.failCount = 0
		Mind.state = "Awaiting"
		Mind._cmdTx(Mind._stateObj({ note = "stopped" }))
		return
	end

	-- ===============================
	-- NO JOB
	-- ===============================
	if not Mind.job then
		Mind.state = "Awaiting"
		return
	end

	-- ===============================
	-- JOB: GOTO
	-- ===============================
	if Mind.job.type == "goto" then
		Mind.state = "Working"

		local ok = Mind.goTo(Mind.job.target)
		if ok then
			Mind.job = nil
			Mind.state = "Awaiting"
			Mind._cmdTx(Mind._stateObj({ note = "goto_complete" }))
		else
			Mind.failCount = (Mind.failCount or 0) + 1
			if Mind.failCount >= (Mind.failLimit or 5) then
				Mind.state = "Paused"
				Mind._cmdTx(Mind._stateObj({ note = "goto_failed" }))
			end
		end
		return
	end

	-- ===============================
	-- JOB: LEVEL MINING
	-- ===============================
	if Mind.job.type == "level" then
		Mind.state = "Working"

		local done = Mind._tickLevelJob()
		if done then
			Mind.job = nil
			Mind.state = "Awaiting"
			Mind._cmdTx(Mind._stateObj({ note = "level_complete", y = Mind.job.y }))
		end
		return
	end
end
