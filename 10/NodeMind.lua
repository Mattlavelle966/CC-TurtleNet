-- NodeMind.lua
-- Turtle Mind or script for each node

require("TMNL")
require("mine_net")
require("mind_lin")

TMNL.GetSavedDB()

local modem = peripheral.find("modem") or error("No modem attached", 0)

local RECEIVE_CHANNEL = 15
local SENDING_CHANNEL = 43

-- NEW: peer channel (turtle-to-turtle only; master server doesn't need to change)
local PEER_CHANNEL = 14
local PEER_REPLY_CHANNEL = 14

-- CONFIG / INIT
CheckFirstLoad()
TMNL.NodeId = TMNL.SaveObject.NetId
TMNL.currentCoordinates = { x = TMNL.SaveObject.X, y = TMNL.SaveObject.Y, z = TMNL.SaveObject.Z }
TMNL.Facing = TMNL.SaveObject.Facing

modem.open(RECEIVE_CHANNEL)
modem.open(PEER_CHANNEL)

TMNL.TurtleInit()

-- Init the mind module (bounds match your UI DB expectations: 1..100)
MindLin.init({
	modem = modem,
	nodeId = TMNL.NodeId,
	totalTurtles = 5,
	peerChannel = PEER_CHANNEL,
	peerReplyChannel = PEER_REPLY_CHANNEL,

	minX = 1,
	minY = 1,
	minZ = 1,
	maxX = 100,
	maxY = 100,
	maxZ = 100,

	fuelMin = 200,
	fuelHardReturn = 80,
})

function MovementLoop()
	print("thread 1")
	while true do
		-- REPLACED: old for-loop wandering
		-- NOW: a single tick that:
		-- - refuels if needed
		-- - dumps at home if inventory full / fuel safety low
		-- - broadcasts telemetry to peers
		-- - mines a bounded serpentine pattern on this turtle's assigned Y
		-- - only changes Y after completing the full layer
		MindLin.tick()
		sleep(0) -- yield
	end
end

function ListenLoop()
	print("thread 2")
	while true do
		local e = { os.pullEvent() }

		if e[1] == "modem_message" then
			local channel = e[3]
			local pack = e[5]

			-- MASTER SERVER TRAFFIC (unchanged behavior)
			if channel == RECEIVE_CHANNEL then
				TMNL.SaveToDB()

				if pack == "send latest" .. tostring(TMNL.NodeId) then
					modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, textutils.serialize(TMNL.Queue))
					TMNL.Queue = {}
				elseif pack == "stop" then
					MineNet.restart()
				elseif pack == "Are you running #" .. tostring(TMNL.NodeId) then
					modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "Yes")
				else
					-- ignore unknown master packet
				end

			-- PEER TRAFFIC (turtle-to-turtle)
			elseif channel == PEER_CHANNEL then
				local ok, t = pcall(textutils.unserialize, pack)
				if ok and type(t) == "table" then
					MindLin.onPeerPacket(t)
				end
			end
		end
	end
end

print("Happy Mining")
print("waiting")

while true do
	C, RC, Message, D = MineNet.listenOnChannel(RECEIVE_CHANNEL)

	if Message == "hello" then
		print("Received")
		print("sending Ready")
		sleep(5)

		modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "ready")
		print("reccieved, awaiting response")

		cA, rcA, MessageA, dA = MineNet.listenOnChannel(RECEIVE_CHANNEL)

		if MessageA == "begin mining" then
			parallel.waitForAny(MovementLoop, ListenLoop)
		else
			print("begin mining not recieved")
		end
	else
		print("hello was not recieved")
	end
end
