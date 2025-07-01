require "vector_lib"


local modem = peripheral.find("modem") or error("No modem attached", 0)
modem.open(100)

local savePath = "pylon_coords.json"
local coords

if fs.exists(savePath) then
    local file = fs.open(savePath, "r")
    coords = textutils.unserializeJSON(file.readAll())
    file.close()
else
local x, y, z

print("Enter pylon computers coordinates")
print("to assist you can use F3 to view.")
print("the targeted blocks coordinates while looking")
print("at the computer acting as a pylon.")
print("IF AT ANY POINT YOU WISH TO CHANGE THE")
print("COORDS YOU MUST DELETE THE 'pylon_coords.json'")
print("X:")
x = tonumber(io.read())
print("Y: ")
y = tonumber(io.read())
print("Z: ")
z = tonumber(io.read())

coords = Vec3.new(x, y, z)

local file = fs.open(savePath, "w")
file.write(textutils.serializeJSON(coords))
file.close()
end

--waiting for reply
local event, side, channel, replyChannel, message, distance

while (true) do
repeat
    print("Waiting for request...")
    -- local event, s, ch, rep, msg, dist = os.pullEvent()
    event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    -- print("Got:", ch, event, msg)
    print("Got:", channel)
until channel == 100
print("replyChannel:", replyChannel)
print("Message:", message)
print("Distance:", distance)
local packet = {
    distance = distance,
    coords = coords,
    replyChannel = replyChannel
}

local serializedPacket = textutils.serializeJSON(packet)

modem.transmit(101, 100, serializedPacket)
end