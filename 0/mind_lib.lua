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

	Mind.flags = { returningHome = false, dumping = false, paused = false }
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

	-- turtles (THIS is the missing part)
	if name == "computercraft:turtle" then
		return true
	end
	if name == "computercraft:advanced_turtle" then
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

function Mind.safeForward()
	local sx = TMNL.currentCoordinates.x
	local sz = TMNL.currentCoordinates.z

	if turtle.detect() then
		if Mind.isInventory("front") then
			print("IM BLOCKED: inventory/turtle detected, returning home")
			Mind.turnTo((TMNL.Facing + 2) % 4)
			Mind.goTo(Mind.home)
			return false
		end
		turtle.dig()
	end

	TMNL.Forward()

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
		if not Mind.safeUp() then
			return false
		end
	end

	while Mind.pos.y > target.y do
		if not Mind.safeDown() then
			return false
		end
	end

	while Mind.pos.x ~= target.x do
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
function Mind.initCmd(modem, cmdRecvCh, cmdSendCh)
	Mind.cmdInbox = {}

	Mind.cmdModem = modem
	Mind.cmdRecvCh = cmdRecvCh
	Mind.cmdSendCh = cmdSendCh

	Mind.state = "Awaiting" -- Awaiting | Busy | Dead
	Mind.target = nil
	Mind.failCount = 0
	Mind.failLimit = 5

	modem.open(cmdRecvCh)
end

function Mind._cmdTx(obj)
	Mind.cmdModem.transmit(Mind.cmdSendCh, Mind.cmdRecvCh, textutils.serialize(obj))
end

function Mind._stateObj()
	return {
		cmd = "state",
		id = TMNL.NodeId,
		state = Mind.state,
		pos = TMNL.currentCoordinates,
		target = Mind.target,
		failCount = Mind.failCount,
	}
end

function Mind._acceptTarget(t)
	Mind.target = { x = t.x, y = t.y, z = t.z, facing = t.facing }
	Mind.state = "Busy"
	Mind._cmdTx({ cmd = "accepted", id = TMNL.NodeId, target = Mind.target, pos = TMNL.currentCoordinates })
end

function Mind.handleCmdMessage(msg)
	local t = nil
	if type(msg) == "string" then
		t = textutils.unserialize(msg)
	end

	-- allow simple string commands too
	if type(t) ~= "table" then
		if msg == "status" then
			Mind._cmdTx(Mind._stateObj())
			return
		elseif msg == "home" then
			Mind._acceptTarget({ x = Mind.home.x, y = Mind.home.y, z = Mind.home.z, facing = Mind.home.facing })
			return
		elseif msg == "stop" then
			Mind.state = "Awaiting"
			Mind.target = nil
			Mind._cmdTx(Mind._stateObj())
			return
		elseif msg == "reset" then
			Mind.state = "Awaiting"
			Mind.target = nil
			Mind.failCount = 0
			Mind._cmdTx(Mind._stateObj())
			return
		end

		local a, x, y, z = tostring(msg):match("^(goto)%s+(-?%d+)%s+(-?%d+)%s+(-?%d+)$")
		if a == "goto" then
			Mind._acceptTarget({ x = tonumber(x), y = tonumber(y), z = tonumber(z) })
		end
		return
	end

	-- table commands
	if t.cmd == "status" then
		Mind._cmdTx(Mind._stateObj())
		return
	elseif t.cmd == "home" then
		Mind._acceptTarget({ x = Mind.home.x, y = Mind.home.y, z = Mind.home.z, facing = Mind.home.facing })
		return
	elseif t.cmd == "goto" then
		if Mind.state == "Dead" and not t.force then
			Mind._cmdTx({
				cmd = "refused",
				id = TMNL.NodeId,
				reason = "dead",
				state = Mind.state,
				pos = TMNL.currentCoordinates,
			})
			return
		end
		if Mind.state == "Busy" and not t.force then
			Mind._cmdTx({
				cmd = "refused",
				id = TMNL.NodeId,
				reason = "busy",
				state = Mind.state,
				pos = TMNL.currentCoordinates,
			})
			return
		end
		Mind._acceptTarget({ x = tonumber(t.x), y = tonumber(t.y), z = tonumber(t.z), facing = t.facing })
		return
	elseif t.cmd == "stop" then
		Mind.state = "Awaiting"
		Mind.target = nil
		Mind._cmdTx(Mind._stateObj())
		return
	elseif t.cmd == "reset" then
		Mind.state = "Awaiting"
		Mind.target = nil
		Mind.failCount = 0
		Mind._cmdTx(Mind._stateObj())
		return
	end
end

function Mind.stepToTarget()
	if Mind.state ~= "Busy" or not Mind.target then
		return
	end

	local ok = Mind.goTo(Mind.target)
	if ok then
		Mind.state = "Awaiting"
		Mind.target = nil
		Mind.failCount = 0
		Mind._cmdTx({ cmd = "done", id = TMNL.NodeId, pos = TMNL.currentCoordinates })
		return
	end

	Mind.failCount = Mind.failCount + 1
	Mind._cmdTx({ cmd = "blocked", id = TMNL.NodeId, pos = TMNL.currentCoordinates, failCount = Mind.failCount })

	if Mind.failCount >= Mind.failLimit then
		Mind.state = "Dead"
		Mind._cmdTx({ cmd = "dead", id = TMNL.NodeId, pos = TMNL.currentCoordinates, reason = "failLimit" })
	else
		Mind.state = "Awaiting"
	end
end
