-- mind_lib.lua
-- Turtle "mind" library: peer gossip, chunk claiming, fuel/inventory/home handling, and a simple mining pattern.

require("TMNL")
require("mine_net")

Mind = {}

-- ==========
-- Config
-- ==========
Mind.cfg = {
	receiveChannel = 15, -- turtles listen here (matches NodeMind.lua)
	sendChannel = 43, -- turtles transmit back on this (matches NodeMind.lua)
	gossipChannel = 16, -- NEW: turtle-to-turtle gossip channel (all turtles open this)
	chunkSize = 16, -- 16x16 chunk claims
	minFuel = 250, -- if below this, go into "fuel/home" mode
	emergencyFuel = 50, -- if below this, stop mining immediately
	home = nil, -- {x,y,z} default set at init from TMNL current
	dumpSide = "down", -- where the dump chest is at home: "down","up","front","back","left","right"
	refuelOnlyAtHome = false, -- if true, will not refuel from inventory while away
	mineRadiusChunks = 8, -- search outward up to N chunks for unclaimed work
	telemetryFlushEvery = 3, -- seconds between SaveToDB calls
}

-- ==========
-- State
-- ==========
Mind.modem = nil
Mind.peers = {} -- [peerId] = { lastSeen=os.clock(), claims = { [chunkKey]=ts }, home={...} }
Mind.claims = {} -- local + learned: [chunkKey] = { owner=id, ts=os.time() }
Mind.myClaims = {} -- just mine: [chunkKey]=true
Mind.currentChunk = nil -- {cx, cy, cz, key}
Mind.pattern = { -- simple serpentine inside chunk
	stepInRow = 0,
	row = 0,
	dir = 1, -- 1 forward, -1 backward (we implement via turns)
	started = false,
}

Mind._lastTelemetrySave = 0

-- ==========
-- Helpers
-- ==========
local function nowTs()
	-- os.time("local") is what TMNL uses for packets; keep consistent
	return os.time("local")
end

local function chunkCoord(v, size)
	-- integer chunk coordinate (1-based coords in your UI DB, but world may be any int)
	-- use math.floor for negative-safe chunking
	if v >= 0 then
		return math.floor(v / size)
	else
		return math.floor((v - (size - 1)) / size)
	end
end

local function chunkKey(cx, cy, cz)
	return tostring(cx) .. ":" .. tostring(cy) .. ":" .. tostring(cz)
end

local function getFuel()
	-- "unlimited" mode returns "unlimited" in CC:Tweaked; normalize to huge
	local f = turtle.getFuelLevel()
	if f == "unlimited" then
		return 999999999
	end
	return f or 0
end

local function safeSerialize(t)
	return textutils.serialize(t)
end

local function safeUnserialize(s)
	if type(s) ~= "string" then
		return nil
	end
	return textutils.unserialize(s)
end

local function faceToTurn(targetFacing)
	-- TMNL.Facing: 0=north,1=west,2=south,3=east (per your comment)
	local cur = TMNL.Facing
	local diff = (targetFacing - cur) % 4
	if diff == 0 then
		return
	end
	if diff == 1 then
		TMNL.TurnRight()
	elseif diff == 2 then
		TMNL.TurnRight()
		TMNL.TurnRight()
	elseif diff == 3 then
		TMNL.TurnLeft()
	end
end

-- Determine which way we need to face to move +X/-X/+Z/-Z relative to TMNL's axis mapping.
-- Your TMNL.Forward():
-- Facing 0 => x = x - 1
-- Facing 2 => x = x + 1
-- Facing 1 => z = z - 1
-- Facing 3 => z = z + 1
local function facingForDelta(dx, dz)
	if dx == -1 and dz == 0 then
		return 0
	end
	if dx == 1 and dz == 0 then
		return 2
	end
	if dx == 0 and dz == -1 then
		return 1
	end
	if dx == 0 and dz == 1 then
		return 3
	end
	return nil
end

-- ==========
-- Networking (turtle-to-turtle gossip)
-- ==========
function Mind._sendGossip(msgTable)
	if not Mind.modem then
		return
	end
	Mind.modem.transmit(Mind.cfg.gossipChannel, Mind.cfg.gossipChannel, safeSerialize(msgTable))
end

function Mind._broadcastHello()
	Mind._sendGossip({
		t = "HELLO",
		from = TMNL.NodeId,
		ts = nowTs(),
		home = Mind.cfg.home,
	})
end

function Mind._broadcastClaims()
	-- Send just my claims to keep payload small
	local keys = {}
	for k, _ in pairs(Mind.myClaims) do
		table.insert(keys, k)
	end
	Mind._sendGossip({
		t = "CLAIMS",
		from = TMNL.NodeId,
		ts = nowTs(),
		claims = keys,
		home = Mind.cfg.home,
	})
end

function Mind._requestState()
	Mind._sendGossip({
		t = "STATE_REQ",
		from = TMNL.NodeId,
		ts = nowTs(),
	})
end

function Mind._sendState(toId)
	local keys = {}
	for k, v in pairs(Mind.claims) do
		-- share learned global picture (small-ish)
		table.insert(keys, { key = k, owner = v.owner, ts = v.ts })
	end
	Mind._sendGossip({
		t = "STATE_RESP",
		from = TMNL.NodeId,
		to = toId,
		ts = nowTs(),
		claims = keys,
		home = Mind.cfg.home,
	})
end

function Mind._mergeClaims(fromId, claims)
	local ts = nowTs()
	if type(claims) ~= "table" then
		return
	end
	for _, entry in ipairs(claims) do
		if type(entry) == "table" then
			local k = entry.key
			local owner = entry.owner
			local cts = entry.ts or ts
			if k and owner then
				local cur = Mind.claims[k]
				if (not cur) or (cts >= (cur.ts or 0)) then
					Mind.claims[k] = { owner = owner, ts = cts }
				end
			end
		elseif type(entry) == "string" then
			-- "CLAIMS" message: array of keys, owned by sender
			local k = entry
			local cur = Mind.claims[k]
			if (not cur) or (ts >= (cur.ts or 0)) then
				Mind.claims[k] = { owner = fromId, ts = ts }
			end
		end
	end
end

function Mind.handleGossipMessage(msg)
	if type(msg) ~= "table" or not msg.t or not msg.from then
		return
	end
	if msg.from == TMNL.NodeId then
		return
	end

	-- peer bookkeeping
	Mind.peers[msg.from] = Mind.peers[msg.from] or {}
	Mind.peers[msg.from].lastSeen = os.clock()
	if msg.home then
		Mind.peers[msg.from].home = msg.home
	end

	if msg.t == "HELLO" then
		-- respond with state so newcomer learns claims
		Mind._sendState(msg.from)
	elseif msg.t == "STATE_REQ" then
		Mind._sendState(msg.from)
	elseif msg.t == "STATE_RESP" then
		if msg.to ~= TMNL.NodeId then
			return
		end
		Mind._mergeClaims(msg.from, msg.claims)
	elseif msg.t == "CLAIMS" then
		Mind._mergeClaims(msg.from, msg.claims)
	elseif msg.t == "CMD" then
		-- reserved for future "come help", "swap chunk", etc.
	end
end

-- ==========
-- Fuel / inventory / dumping
-- ==========
function Mind.tryRefuelFromInventory(maxItems)
	if Mind.cfg.refuelOnlyAtHome then
		return false
	end
	local before = getFuel()
	local used = 0
	for slot = 1, 16 do
		turtle.select(slot)
		-- try 1 item at a time so we don't burn everything
		if turtle.refuel(1) then
			used = used + 1
			if maxItems and used >= maxItems then
				break
			end
			if getFuel() > before then
				before = getFuel()
			end
			if getFuel() >= Mind.cfg.minFuel then
				break
			end
		end
	end
	return getFuel() > 0
end

local function dumpAll(side)
	local fn
	if side == "down" then
		fn = turtle.dropDown
	elseif side == "up" then
		fn = turtle.dropUp
	else
		fn = turtle.drop
	end

	-- If side is directional, we must turn to it relative to current facing
	local restoreFacing = TMNL.Facing

	if side == "front" then
	-- no turn
	elseif side == "back" then
		TMNL.TurnRight()
		TMNL.TurnRight()
	elseif side == "left" then
		TMNL.TurnLeft()
	elseif side == "right" then
		TMNL.TurnRight()
	end

	for slot = 1, 16 do
		turtle.select(slot)
		fn()
	end

	-- restore facing
	faceToTurn(restoreFacing)
end

-- ==========
-- Navigation (simple Manhattan return; relies on TMNL coords)
-- ==========
function Mind.goTo(target)
	-- Simple axis-walk: adjust X first then Z; assumes clear-ish tunnels. (We can later add obstacle logic)
	local tx, ty, tz = target.x, target.y, target.z

	-- Y handling (optional)
	while TMNL.currentCoordinates.y < ty do
		TMNL.Up()
	end
	while TMNL.currentCoordinates.y > ty do
		TMNL.Down()
	end

	-- X (remember: facing 2 increases x, facing 0 decreases x)
	while TMNL.currentCoordinates.x < tx do
		faceToTurn(2)
		local moved = TMNL.Forward()
		if moved[1] and moved[1].Result == false then
			turtle.dig()
			moved = TMNL.Forward()
			if moved[1] and moved[1].Result == false then
				break
			end
		end
	end
	while TMNL.currentCoordinates.x > tx do
		faceToTurn(0)
		local moved = TMNL.Forward()
		if moved[1] and moved[1].Result == false then
			turtle.dig()
			moved = TMNL.Forward()
			if moved[1] and moved[1].Result == false then
				break
			end
		end
	end

	-- Z (facing 3 increases z, facing 1 decreases z)
	while TMNL.currentCoordinates.z < tz do
		faceToTurn(3)
		local moved = TMNL.Forward()
		if moved[1] and moved[1].Result == false then
			turtle.dig()
			moved = TMNL.Forward()
			if moved[1] and moved[1].Result == false then
				break
			end
		end
	end
	while TMNL.currentCoordinates.z > tz do
		faceToTurn(1)
		local moved = TMNL.Forward()
		if moved[1] and moved[1].Result == false then
			turtle.dig()
			moved = TMNL.Forward()
			if moved[1] and moved[1].Result == false then
				break
			end
		end
	end
end

function Mind.goHomeAndService()
	if not Mind.cfg.home then
		return
	end
	Mind.goTo(Mind.cfg.home)

	-- dump inventory
	dumpAll(Mind.cfg.dumpSide)

	-- refuel harder at home (burn more items if needed)
	local before = getFuel()
	for slot = 1, 16 do
		turtle.select(slot)
		turtle.refuel()
		if getFuel() >= Mind.cfg.minFuel then
			break
		end
	end

	return getFuel() > before
end

-- ==========
-- Chunk claiming / selection
-- ==========
function Mind._myChunkForCurrentPos()
	local cx = chunkCoord(TMNL.currentCoordinates.x, Mind.cfg.chunkSize)
	local cz = chunkCoord(TMNL.currentCoordinates.z, Mind.cfg.chunkSize)
	local cy = TMNL.currentCoordinates.y
	local key = chunkKey(cx, cy, cz)
	return { cx = cx, cy = cy, cz = cz, key = key }
end

function Mind._isChunkClaimed(key)
	local c = Mind.claims[key]
	return c ~= nil and c.owner ~= nil
end

function Mind._claimChunk(chunk)
	local ts = nowTs()
	Mind.currentChunk = chunk
	Mind.claims[chunk.key] = { owner = TMNL.NodeId, ts = ts }
	Mind.myClaims[chunk.key] = true
	Mind._broadcastClaims()
end

function Mind.pickNextChunk()
	-- Search outward in a square spiral around home chunk (or current pos if no home)
	local base = Mind.cfg.home or TMNL.currentCoordinates
	local baseCx = chunkCoord(base.x, Mind.cfg.chunkSize)
	local baseCz = chunkCoord(base.z, Mind.cfg.chunkSize)
	local cy = base.y

	local maxR = Mind.cfg.mineRadiusChunks
	for r = 0, maxR do
		for dx = -r, r do
			for dz = -r, r do
				local cx = baseCx + dx
				local cz = baseCz + dz
				local key = chunkKey(cx, cy, cz)
				if not Mind._isChunkClaimed(key) then
					return { cx = cx, cy = cy, cz = cz, key = key }
				end
			end
		end
	end
	return nil
end

function Mind.goToChunkOrigin(chunk)
	-- origin corner of chunk (top-left-ish): cx*size, cz*size
	local size = Mind.cfg.chunkSize
	local ox = chunk.cx * size
	local oz = chunk.cz * size
	Mind.goTo({ x = ox, y = chunk.cy, z = oz })
end

-- ==========
-- Mining pattern (serpentine 16x16)
-- ==========
function Mind._resetPattern()
	Mind.pattern = { stepInRow = 0, row = 0, dir = 1, started = false }
end

local function digForwardIfBlocked()
	if turtle.detect() then
		turtle.dig()
	end
end

function Mind.mineStep()
	if not Mind.currentChunk then
		return
	end

	if not Mind.pattern.started then
		-- start: face "east-ish" in your coord system.
		-- We'll do a serpentine using forward moves; turning at row ends.
		Mind._resetPattern()
		Mind.pattern.started = true
	end

	local size = Mind.cfg.chunkSize
	local row = Mind.pattern.row
	local step = Mind.pattern.stepInRow

	-- Finished chunk?
	if row >= size then
		return "CHUNK_DONE"
	end

	-- Each row: move (size-1) forward steps, then shift row (turn, forward, turn).
	if step < (size - 1) then
		digForwardIfBlocked()
		local moved = TMNL.Forward()
		if moved[1] and moved[1].Result == false then
			-- if still blocked, try dig again and turn to avoid deadlock
			turtle.dig()
			moved = TMNL.Forward()
			if moved[1] and moved[1].Result == false then
				TMNL.TurnRight()
			end
		else
			Mind.pattern.stepInRow = Mind.pattern.stepInRow + 1
		end
		return "MINING"
	else
		-- end of row, shift to next row if possible
		if row == (size - 1) then
			Mind.pattern.row = Mind.pattern.row + 1
			return "CHUNK_DONE"
		end

		-- serpentine turn based on row parity
		if (row % 2) == 0 then
			TMNL.TurnRight()
			digForwardIfBlocked()
			TMNL.Forward()
			TMNL.TurnRight()
		else
			TMNL.TurnLeft()
			digForwardIfBlocked()
			TMNL.Forward()
			TMNL.TurnLeft()
		end

		Mind.pattern.row = Mind.pattern.row + 1
		Mind.pattern.stepInRow = 0
		return "MINING"
	end
end

-- ==========
-- Main decision loop helpers
-- ==========
function Mind.tick()
	-- Periodically persist TMNL Save DB (your current NodeMind does this on every modem msg; keep it lighter)
	if (os.clock() - Mind._lastTelemetrySave) >= Mind.cfg.telemetryFlushEvery then
		TMNL.SaveToDB()
		Mind._lastTelemetrySave = os.clock()
	end

	-- Emergency fuel behavior
	local fuel = getFuel()
	if fuel <= Mind.cfg.emergencyFuel then
		-- try quick refuel from inventory; if not, go home immediately
		Mind.tryRefuelFromInventory(2)
		Mind.goHomeAndService()
		return
	end

	if fuel < Mind.cfg.minFuel then
		-- if not enough fuel, attempt light refuel, then home service
		Mind.tryRefuelFromInventory(4)
		if getFuel() < Mind.cfg.minFuel then
			Mind.goHomeAndService()
		end
		return
	end

	-- Ensure we have a chunk
	if not Mind.currentChunk then
		local next = Mind.pickNextChunk()
		if next then
			Mind._claimChunk(next)
			Mind.goToChunkOrigin(next)
			Mind._resetPattern()
		else
			-- nothing available; ask peers again and idle a bit
			Mind._requestState()
			sleep(1)
		end
		return
	end

	-- Mine
	local status = Mind.mineStep()
	if status == "CHUNK_DONE" then
		-- drop claim? Keep it claimed so nobody repeats.
		Mind.currentChunk = nil
		Mind._resetPattern()
		Mind._broadcastClaims()
	end
end

-- ==========
-- Init
-- ==========
function Mind.init(modem, overrides)
	Mind.modem = modem
	if overrides then
		for k, v in pairs(overrides) do
			Mind.cfg[k] = v
		end
	end

	if not Mind.cfg.home then
		Mind.cfg.home = { x = TMNL.currentCoordinates.x, y = TMNL.currentCoordinates.y, z = TMNL.currentCoordinates.z }
	end

	-- open channels
	Mind.modem.open(Mind.cfg.receiveChannel)
	Mind.modem.open(Mind.cfg.gossipChannel)

	-- announce and learn
	Mind._broadcastHello()
	Mind._requestState()
	Mind._broadcastClaims()
end
