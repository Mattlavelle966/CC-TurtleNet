--Turtle Mind or script for each node
require("TMNL")
require("mine_net")
require("mind_lib")
TMNL.GetSavedDB()
local modem = peripheral.find("modem") or error("No modem attached", 0)
local RECEIVE_CHANNEL = 15
local SENDING_CHANNEL = 43
--CONFIG

CheckFirstLoad()
TMNL.NodeId = TMNL.SaveObject.NetId
TMNL.currentCoordinates = { x = TMNL.SaveObject.X, y = TMNL.SaveObject.Y, z = TMNL.SaveObject.Z }
TMNL.Facing = TMNL.SaveObject.Facing

Mind.init(TMNL, {
	bounds = { minX = 1, maxX = 100, minY = 1, maxY = 100, minZ = 1, maxZ = 100 },
	fuelMin = 200,
})

local STARTING_POS = Mind.STARTING_POS

modem.open(RECEIVE_CHANNEL)
TMNL.TurtleInit()

local CMD_RECV_CHANNEL = 90
local CMD_SEND_CHANNEL = 91

Mind.initCmd(modem, CMD_RECV_CHANNEL, CMD_SEND_CHANNEL)

function MovementLoop()
	while true do
		if #Mind.cmdInbox > 0 then
			Mind.handleCmdMessage(table.remove(Mind.cmdInbox, 1))
		end

		Mind.stepToTarget()

		sleep(0.05)
	end
end

function ListenLoop()
	print("thread 2")
	while true do
		local e = { os.pullEvent() }
		if e[1] == "modem_message" and e[3] == RECEIVE_CHANNEL then
			--print("EVENT: " .. textutils.serialize(e))

			pack = e[5]
			TMNL.SaveToDB()
			if pack == "send latest" .. tostring(TMNL.NodeId) then
				--print("EVENT: " .. textutils.serialize(e[5]))
				--print("sending Packet")
				modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, textutils.serialize(TMNL.Queue))
				TMNL.Queue = {}
			elseif pack == "stop" then
				MineNet.restart()
			elseif pack == "Are you running #" .. tostring(TMNL.NodeId) then
				modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "Yes")
				--print("Master Is Starting")
			else
				--print("wrong pack")
			end
		-- 2) command channel (NEW: do not handle here, just forward to MovementLoop)
		elseif e[1] == "modem_message" and e[3] == CMD_RECV_CHANNEL then
			print("tablet is working")
			table.insert(Mind.cmdInbox, e[5])

			-- optional immediate ack (so your test script sees *something*)
			modem.transmit(
				CMD_SEND_CHANNEL,
				CMD_RECV_CHANNEL,
				textutils.serialize({
					cmd = "rx",
					id = TMNL.NodeId,
					state = Mind.state,
					pos = TMNL.currentCoordinates,
				})
			)
		end
	end
end

print("Happy Mining")
print("waiting")
while true do
	C, RC, Message, D = MineNet.listenOnChannel(RECEIVE_CHANNEL)
	if Message == "hello" then
		--print("Received")
		--print("sending Ready")
		sleep(5)
		modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "ready")
		--print("reccieved, awaiting response")
		cA, rcA, MessageA, dA = MineNet.listenOnChannel(RECEIVE_CHANNEL)
		if MessageA == "begin mining" then
			--actions thread below
			parallel.waitForAny(MovementLoop, ListenLoop)
		else
			--print("begin mining not recieved")
		end
	else
		--print("hello was not recieved")
	end
end
