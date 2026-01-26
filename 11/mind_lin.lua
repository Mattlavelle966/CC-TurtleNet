-- mind_lin.lua
-- Linear "mind" module: fuel/refuel, peer telemetry + y-level coordination,
-- bounded serpentine mining, home point (10 blocks behind start), layer completion -> next y.

MindLin = {}

-- Defaults (can be overridden by MindLin.init(opts))
MindLin.PEER_CHANNEL = 14
MindLin.PEER_REPLY_CHANNEL = 14

MindLin.MAX_X = 100
MindLin.MAX_Y = 100
MindLin.MAX_Z = 100

MindLin.MIN_X = 1
MindLin.MIN_Y = 1
MindLin.MIN_Z = 1

MindLin.FUEL_MIN = 200 -- refuel if below this
MindLin.FUEL_HARD_RETURN = 80 -- go home if below this (safety)
MindLin.BROADCAST_EVERY = 2.0 -- seconds between peer broadcasts
MindLin.PEER_TIMEOUT = 10.0 -- seconds until peer considered stale

MindLin.totalTurtles = 5

-- Internal runtime state
MindLin.modem = nil
MindLin.nodeId = 0
MindLin.peers = {} -- [nodeId] = {x,y,z,fuel,lastSeen,layer}

MindLin.start = nil -- {x,y,z,facing}
MindLin.home = nil -- {x,y,z}
MindLin.assignedY = nil

-- serpentine scan state
MindLin.scan = {
	minX = 1,
	maxX = 100,
	minZ = 1,
	maxZ = 100,
	dir = 1, -- 1 = +X, -1 = -X
	phase = "row", -- "row" moving X, then "step" moving Z
	completed = false,
}

MindLin._lastBroadcastClock = 0

local function nowClock()
	-- os.clock is monotonic within session; good for timeouts.
	return os.clock()
end

local function clamp(v, lo, hi)
	if v < lo then
		return lo
	end
	if v > hi then
		return hi
	end
	return v
end

local function deepCopy(t)
	local o = {}
	for k, v in pairs(t) do
		o[k] = v
	end
	return o
end

local function isFuelInfinite()
	local lvl = turtle.getFuelLevel()
	return lvl == "unlimited" or lvl == math.huge
end

local function emptySlots()
	local n = 0
	for i = 1, 16 do
		if turtle.getItemCount(i) == 0 then
			n = n + 1
		end
	end
	return n
end

local function tryRefuelAll()
	if isFuelInfinite() then
		return true
	end
	-- Try every slot; only consume items that are fuel
	for i = 1, 16 do
		if turtle.getItemCount(i) > 0 then
			turtle.select(i)
			-- refuel(0) checks if it is fuel without consuming
			if turtle.refuel(0) then
				turtle.refuel(64)
			end
		end
	end
	turtle.select(1)
	return true
end

local function inspectFrontIsTurtle()
	local ok, data = turtle.inspect()
	if not ok or not data then
		return false
	end
	-- In CC:Tweaked, turtles commonly show up as "computercraft:turtle"
	local name = (data.name or ""):lower()
	if name:find("turtle", 1, true) then
		return true
	end
	return false
end

local function withinBounds(x, y, z)
	return (x >= MindLin.MIN_X and x <= MindLin.MAX_X)
		and (y >= MindLin.MIN_Y and y <= MindLin.MAX_Y)
		and (z >= MindLin.MIN_Z and z <= MindLin.MAX_Z)
end

local function computeHomeFromStart(start, stepsBehind)
	-- TMNL facing: 0=north(-x), 1=west(-z), 2=south(+x), 3=east(+z)
	local hx, hy, hz = start.x, start.y, start.z
	local f = start.facing or 0
	stepsBehind = stepsBehind or 10

	if f == 0 then
		-- behind is +x
		hx = hx + stepsBehind
	elseif f == 1 then
		-- behind is +z
		hz = hz + stepsBehind
	elseif f == 2 then
		-- behind is -x
		hx = hx - stepsBehind
	elseif f == 3 then
		-- behind is -z
		hz = hz - stepsBehind
	end

	hx = clamp(hx, MindLin.MIN_X, MindLin.MAX_X)
	hz = clamp(hz, MindLin.MIN_Z, MindLin.MAX_Z)
	hy = clamp(hy, MindLin.MIN_Y, MindLin.MAX_Y)

	return { x = hx, y = hy, z = hz }
end

local function faceDirection(desiredFacing)
	desiredFacing = desiredFacing % 4
	local cur = TMNL.Facing % 4
	local delta = (desiredFacing - cur) % 4
	if delta == 0 then
		return
	end
	if delta == 1 then
		TMNL.TurnRight()
	elseif delta == 2 then
		TMNL.TurnRight()
		TMNL.TurnRight()
	elseif delta == 3 then
		TMNL.TurnLeft()
	end
end

local function stepToward(target)
	-- Moves 1 step toward target (x,z first, then y), respecting bounds.
	local cx, cy, cz = TMNL.currentCoordinates.x, TMNL.currentCoordinates.y, TMNL.currentCoordinates.z

	-- X axis (TMNL facing 0=-x,2=+x)
	if cx ~= target.x then
		local want = (target.x < cx) and 0 or 2
		faceDirection(want)
		if inspectFrontIsTurtle() then
			-- avoid collision: try right detour
			TMNL.TurnRight()
			return false
		end
		local nx = cx + ((want == 2) and 1 or -1)
		if withinBounds(nx, cy, cz) then
			local data = TMNL.Forward()
			return (data[1] and data[1].Result) or false
		end
		return false
	end

	-- Z axis (TMNL facing 1=-z,3=+z)
	if cz ~= target.z then
		local want = (target.z < cz) and 1 or 3
		faceDirection(want)
		if inspectFrontIsTurtle() then
			TMNL.TurnRight()
			return false
		end
		local nz = cz + ((want == 3) and 1 or -1)
		if withinBounds(cx, cy, nz) then
			local data = TMNL.Forward()
			return (data[1] and data[1].Result) or false
		end
		return false
	end

	-- Y axis (up/down)
	if cy ~= target.y then
		if target.y > cy then
			if withinBounds(cx, cy + 1, cz) then
				TMNL.Up()
				return true
			end
		else
			if withinBounds(cx, cy - 1, cz) then
				TMNL.Down()
				return true
			end
		end
		return false
	end

	return true
end

local function broadcastState()
	if not MindLin.modem then
		return
	end
	local payload = {
		t = "mn_state",
		node = MindLin.nodeId,
		x = TMNL.currentCoordinates.x,
		y = TMNL.currentCoordinates.y,
		z = TMNL.currentCoordinates.z,
		fuel = turtle.getFuelLevel(),
		layer = MindLin.assignedY or TMNL.currentCoordinates.y,
		ts = os.time("local"),
	}
	MindLin.modem.transmit(MindLin.PEER_CHANNEL, MindLin.PEER_REPLY_CHANNEL, textutils.serialize(payload))
end

local function peerYLevelsInUse()
	local used = {}
	used[MindLin.assignedY or TMNL.currentCoordinates.y] = true
	local tnow = nowClock()
	for id, p in pairs(MindLin.peers) do
		if (tnow - (p.lastSeen or 0)) <= MindLin.PEER_TIMEOUT then
			if p.layer then
				used[p.layer] = true
			end
		end
	end
	return used
end

local function chooseInitialAssignedY()
	-- Deterministic first pick: startY + (nodeId-1)
	local base = MindLin.start.y
	local desired = base + (MindLin.nodeId - 1)
	desired = clamp(desired, MindLin.MIN_Y, MindLin.MAX_Y)

	-- If peers already occupy it, walk upward until free.
	local used = peerYLevelsInUse()
	local y = desired
	while used[y] and y < MindLin.MAX_Y do
		y = y + 1
	end
	if used[y] then
		-- fallback: just clamp
		y = desired
	end
	return y
end

local function nextLayerY()
	-- Move to next layer while keeping unique separation:
	-- jump by totalTurtles to avoid collisions across layers.
	local y = (MindLin.assignedY or TMNL.currentCoordinates.y) + MindLin.totalTurtles
	y = clamp(y, MindLin.MIN_Y, MindLin.MAX_Y)

	-- If peer is already there, keep stepping by totalTurtles
	local used = peerYLevelsInUse()
	while used[y] and (y + MindLin.totalTurtles) <= MindLin.MAX_Y do
		y = y + MindLin.totalTurtles
	end
	return y
end

local function resetScanForLayer()
	MindLin.scan = {
		minX = MindLin.MIN_X,
		maxX = MindLin.MAX_X,
		minZ = MindLin.MIN_Z,
		maxZ = MindLin.MAX_Z,
		dir = 1,
		phase = "row",
		completed = false,
	}
end

local function ensureOnAssignedLayer()
	if not MindLin.assignedY then
		MindLin.assignedY = chooseInitialAssignedY()
	end
	if TMNL.currentCoordinates.y ~= MindLin.assignedY then
		-- go to same x/z first to stay bounded, then adjust y
		local tgt = { x = TMNL.currentCoordinates.x, y = MindLin.assignedY, z = TMNL.currentCoordinates.z }
		stepToward(tgt)
		return false
	end
	return true
end

local function scanStep()
	-- Serpentine coverage of entire X/Z rectangle at current layer.
	local cx, cz = TMNL.currentCoordinates.x, TMNL.currentCoordinates.z

	local minX, maxX = MindLin.scan.minX, MindLin.scan.maxX
	local minZ, maxZ = MindLin.scan.minZ, MindLin.scan.maxZ

	if MindLin.scan.completed then
		return false
	end

	-- On first tick of a layer, clamp into bounds
	if not withinBounds(cx, TMNL.currentCoordinates.y, cz) then
		TMNL.currentCoordinates.x = clamp(cx, MindLin.MIN_X, MindLin.MAX_X)
		TMNL.currentCoordinates.z = clamp(cz, MindLin.MIN_Z, MindLin.MAX_Z)
	end

	-- If at end of final row -> completed
	if cz == maxZ then
		-- ensure we're also at the far end of the last row
		if (MindLin.scan.dir == 1 and cx == maxX) or (MindLin.scan.dir == -1 and cx == minX) then
			MindLin.scan.completed = true
			return false
		end
	end

	if MindLin.scan.phase == "row" then
		-- move along X
		local targetX = (MindLin.scan.dir == 1) and maxX or minX
		if cx ~= targetX then
			local wantFacing = (MindLin.scan.dir == 1) and 2 or 0
			faceDirection(wantFacing)

			if inspectFrontIsTurtle() then
				-- avoid mining/ramming other turtle
				TMNL.TurnRight()
				return true
			end

			local nx = cx + MindLin.scan.dir
			if withinBounds(nx, TMNL.currentCoordinates.y, cz) then
				local data = TMNL.Forward()
				local ok = (data[1] and data[1].Result) or false
				if not ok then
					-- obstacle: rotate to keep moving without breaking network loop
					TMNL.TurnRight()
				end
				return true
			else
				-- out of bounds protection
				MindLin.scan.phase = "step"
				return true
			end
		else
			-- row finished; now step Z forward (increase z)
			MindLin.scan.phase = "step"
			return true
		end
	else
		-- phase == "step": move +Z by 1 if possible, flip dir, go back to row
		if cz < maxZ then
			faceDirection(3) -- +Z
			if inspectFrontIsTurtle() then
				TMNL.TurnRight()
				return true
			end
			local nz = cz + 1
			if withinBounds(cx, TMNL.currentCoordinates.y, nz) then
				local data = TMNL.Forward()
				local ok = (data[1] and data[1].Result) or false
				if ok then
					MindLin.scan.dir = MindLin.scan.dir * -1
					MindLin.scan.phase = "row"
					return true
				else
					TMNL.TurnRight()
					return true
				end
			end
		end

		-- cannot step further; check completion
		MindLin.scan.completed = true
		return false
	end
end

local function goHomeAndDump()
	if not MindLin.home then
		return
	end

	-- Go home at same assigned layer first (y), then home x/z
	local tgtLayer = { x = TMNL.currentCoordinates.x, y = MindLin.home.y, z = TMNL.currentCoordinates.z }
	while TMNL.currentCoordinates.y ~= tgtLayer.y do
		stepToward(tgtLayer)
		sleep(0)
	end

	local tgt = { x = MindLin.home.x, y = MindLin.home.y, z = MindLin.home.z }
	local guard = 0
	while (TMNL.currentCoordinates.x ~= tgt.x or TMNL.currentCoordinates.z ~= tgt.z) and guard < 500 do
		stepToward(tgt)
		guard = guard + 1
		sleep(0)
	end

	-- Dump everything downward (best-effort)
	for i = 1, 16 do
		turtle.select(i)
		if turtle.getItemCount(i) > 0 then
			turtle.dropDown()
		end
	end
	turtle.select(1)
end

function MindLin.init(opts)
	opts = opts or {}
	MindLin.modem = opts.modem
	MindLin.nodeId = opts.nodeId or TMNL.NodeId or 0
	MindLin.totalTurtles = opts.totalTurtles or MindLin.totalTurtles

	MindLin.PEER_CHANNEL = opts.peerChannel or MindLin.PEER_CHANNEL
	MindLin.PEER_REPLY_CHANNEL = opts.peerReplyChannel or MindLin.PEER_REPLY_CHANNEL

	MindLin.MIN_X = opts.minX or MindLin.MIN_X
	MindLin.MIN_Y = opts.minY or MindLin.MIN_Y
	MindLin.MIN_Z = opts.minZ or MindLin.MIN_Z
	MindLin.MAX_X = opts.maxX or MindLin.MAX_X
	MindLin.MAX_Y = opts.maxY or MindLin.MAX_Y
	MindLin.MAX_Z = opts.maxZ or MindLin.MAX_Z

	MindLin.FUEL_MIN = opts.fuelMin or MindLin.FUEL_MIN
	MindLin.FUEL_HARD_RETURN = opts.fuelHardReturn or MindLin.FUEL_HARD_RETURN

	-- snapshot starting point for home calc (10 behind start)
	MindLin.start = {
		x = TMNL.SaveObject.X,
		y = TMNL.SaveObject.Y,
		z = TMNL.SaveObject.Z,
		facing = TMNL.SaveObject.Facing or 0,
	}
	MindLin.home = computeHomeFromStart(MindLin.start, 10)

	resetScanForLayer()
	MindLin._lastBroadcastClock = 0
end

function MindLin.onPeerPacket(packetTable)
	if type(packetTable) ~= "table" then
		return
	end
	if packetTable.t ~= "mn_state" then
		return
	end
	if not packetTable.node then
		return
	end
	local nid = tonumber(packetTable.node)
	if not nid or nid == MindLin.nodeId then
		return
	end

	MindLin.peers[nid] = {
		x = packetTable.x,
		y = packetTable.y,
		z = packetTable.z,
		fuel = packetTable.fuel,
		layer = packetTable.layer,
		lastSeen = nowClock(),
	}
end

function MindLin.tick()
	-- 1) Fuel check + refuel
	if not isFuelInfinite() then
		local fuel = turtle.getFuelLevel()
		if fuel ~= nil and type(fuel) == "number" then
			if fuel < MindLin.FUEL_MIN then
				tryRefuelAll()
			end
			-- safety: if still too low, go home and try again
			fuel = turtle.getFuelLevel()
			if type(fuel) == "number" and fuel < MindLin.FUEL_HARD_RETURN then
				goHomeAndDump()
				tryRefuelAll()
			end
		end
	end

	-- 2) Inventory full => go home and dump
	if emptySlots() == 0 then
		goHomeAndDump()
	end

	-- 3) Stay on assigned Y (unique per turtle)
	if not ensureOnAssignedLayer() then
		-- also broadcast while moving to layer
		local t = nowClock()
		if (t - MindLin._lastBroadcastClock) >= MindLin.BROADCAST_EVERY then
			broadcastState()
			MindLin._lastBroadcastClock = t
		end
		return
	end

	-- 4) Broadcast state periodically
	local t = nowClock()
	if (t - MindLin._lastBroadcastClock) >= MindLin.BROADCAST_EVERY then
		broadcastState()
		MindLin._lastBroadcastClock = t
	end

	-- 5) Main mining step: bounded serpentine
	local moved = scanStep()

	-- 6) Completed layer => ONLY THEN change Y
	if MindLin.scan.completed then
		-- Go home to dump before changing layers (keeps things tidy)
		goHomeAndDump()

		local nextY = nextLayerY()
		MindLin.assignedY = nextY
		resetScanForLayer()
	end

	-- 7) Final hard bounds safety (never leave DB)
	local cx, cy, cz = TMNL.currentCoordinates.x, TMNL.currentCoordinates.y, TMNL.currentCoordinates.z
	if not withinBounds(cx, cy, cz) then
		TMNL.currentCoordinates.x = clamp(cx, MindLin.MIN_X, MindLin.MAX_X)
		TMNL.currentCoordinates.y = clamp(cy, MindLin.MIN_Y, MindLin.MAX_Y)
		TMNL.currentCoordinates.z = clamp(cz, MindLin.MIN_Z, MindLin.MAX_Z)
	end

	return moved
end

return MindLin
