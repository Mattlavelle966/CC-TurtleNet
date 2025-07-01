modem = peripheral.find("modem") or error("No modem attached")
local port = 15
modem.open(port)
local id = os.computerID()
print("transmiting...")
modem.transmit(100, port, id)
print("transmition successful")

local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
local coordinates = textutils.unserializeJSON(message)

print(coordinates.x, coordinates.y, coordinates.z)