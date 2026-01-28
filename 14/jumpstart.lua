-- tablet_jumpstart.lua
local RX = 15 -- turtle receives
local TX = 43 -- turtle replies

local modem = peripheral.find("modem") or error("No modem", 0)
modem.open(TX)

print("Sending hello...")
modem.transmit(RX, TX, "hello")

print("Waiting for ready...")
while true do
	local e = { os.pullEvent("modem_message") }
	if e[3] == TX then
		print("Got:", e[5])
		if e[5] == "ready" then
			print("Sending begin mining")
			modem.transmit(RX, TX, "begin mining")
			print("DONE")
			break
		end
	end
end
