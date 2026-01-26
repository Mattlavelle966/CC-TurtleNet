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
	-- “Anything with an inventory” = anything that supports list()/size()
	-- This will catch chests + turtles + any inventory peripheral.
	if not peripheral.isPresent(side) then
		return false
	end
	if Mind._hasMethod(side, "list") then
		return true
	end
	if Mind._hasMethod(side, "size") then
		return true
	end
	return false
end

function Mind.safeDigForward()
	if not turtle.detect() then
		return true
	end

	if Mind.isInventory("front") then
		print("IM BLOCKED: inventory/turtle in front, refusing to dig")
		return false
	end

	local ok, err = turtle.dig()
	if not ok then
		print("IM BLOCKED: cannot dig block in front" .. (err and (": " .. tostring(err)) or ""))
		return false
	end
	return true
end

function Mind.safeForward()
	local r = TMNL.Forward()
	if r[1].Result then
		Mind.pos.x = TMNL.currentCoordinates.x
		Mind.pos.y = TMNL.currentCoordinates.y
		Mind.pos.z = TMNL.currentCoordinates.z
		return true
	end

	if not Mind.safeDigForward() then
		return false
	end

	r = TMNL.Forward()
	if not r[1].Result then
		print("IM BLOCKED: still cannot move forward")
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
		print("IM BLOCKED: cannot move down")
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
