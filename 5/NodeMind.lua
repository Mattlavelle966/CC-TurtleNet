-- NodeMind.lua
-- Turtle runner: config + telemetry + mind loop threads

require("TMNL")
require("mine_net")
require("mind_lib")

TMNL.GetSavedDB()

local modem = peripheral.find("modem") or error("No modem attached", 0)

local RECEIVE_CHANNEL = 15
local SENDING_CHANNEL = 43

-- CONFIG (your existing first-load prompt)
CheckFirstLoad()
TMNL.NodeId = TMNL.SaveObject.NetId
TMNL.currentCoordinates = { x = TMNL.SaveObject.X, y = TMNL.SaveObject.Y, z = TMNL.SaveObject.Z }
TMNL.Facing = TMNL.SaveObject.Facing

modem.open(RECEIVE_CHANNEL)
TMNL.TurtleInit()

-- Init mind (home defaults to starting coords)
Mind.init(modem, {
	receiveChannel = RECEIVE_CHANNEL,
	sendChannel = SENDING_CHANNEL,
	gossipChannel = 16, -- turtle-to-turtle gossip
	home = { x = TMNL.currentCoordinates.x, y = TMNL.currentCoordinates.y, z = TMNL.currentCoordinates.z },
	dumpSide = "down", -- chest under turtle at home
	minFuel = 250,
	emergencyFuel = 50,
	chunkSize = 16,
})

-- ----------------
-- Thread 1: Brain
-- ----------------
function BrainLoop()
	while true do
		Mind.tick()
		-- small sleep prevents 100% CPU + keeps events responsive
		sleep(0.05)
	end
end

-- ------------------------
-- Thread 2: Telemetry API
-- ------------------------
function ListenLoop()
	while true do
		local e = { os.pullEvent() }

		if e[1] == "modem_message" then
			local channel = e[3]
			local replyChannel = e[4]
			local message = e[5]

			-- 1) Turtle-to-turtle gossip channel is handled by mind lib
			if channel == Mind.cfg.gossipChannel then
				local msg = textutils.unserialize(message)
				Mind.handleGossipMessage(msg)

			-- 2) Master/turtle control channel (your original behavior)
			elseif channel == RECEIVE_CHANNEL then
				local pack = message

				-- keep saving TMNL db like before, but Mind.tick also persists periodically
				TMNL.SaveToDB()

				if pack == "send latest" .. tostring(TMNL.NodeId) then
					modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, textutils.serialize(TMNL.Queue))
					TMNL.Queue = {}
				elseif pack == "stop" then
					MineNet.restart()
				elseif pack == "Are you running #" .. tostring(TMNL.NodeId) then
					modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "Yes")

				-- optional: "come home" without master changes (you can send manually)
				elseif pack == "go home" then
					Mind.goHomeAndService()
				else
					-- ignore
				end
			end
		end
	end
end

-- --------------------------
-- Existing "hello/begin" gate
-- --------------------------
print("Happy Mining")
print("waiting")

while true do
	local C, RC, Message, D = MineNet.listenOnChannel(RECEIVE_CHANNEL)

	if Message == "hello" then
		sleep(1)
		modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "ready")

		local cA, rcA, MessageA, dA = MineNet.listenOnChannel(RECEIVE_CHANNEL)
		if MessageA == "begin mining" then
			parallel.waitForAny(BrainLoop, ListenLoop)
		end
	end
end

