local CMD_RECV_CHANNEL = 90
local CMD_SEND_CHANNEL = 91

local modem = peripheral.find("modem")
if not modem then
	error("No modem found")
end

modem.open(CMD_SEND_CHANNEL)

print("Sending status request...")
modem.transmit(CMD_RECV_CHANNEL, CMD_SEND_CHANNEL, "status")

local function waitReply(timeout)
	local t = os.startTimer(timeout or 2)
	while true do
		local e = { os.pullEvent() }
		if e[1] == "modem_message" then
			print("REPLY:", e[5])
			return
		elseif e[1] == "timer" and e[2] == t then
			print("No reply")
			return
		end
	end
end

waitReply(10)

print("Sending goto...")
modem.transmit(
	CMD_RECV_CHANNEL,
	CMD_SEND_CHANNEL,
	textutils.serialize({
		cmd = "goto",
		y = 95,
		x = 61,
		z = 60,
	})
)

waitReply(2)

print("Sending home...")
modem.transmit(CMD_RECV_CHANNEL, CMD_SEND_CHANNEL, "home")

waitReply(2)

print("Done.")
