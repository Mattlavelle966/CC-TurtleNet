local modem = peripheral.find("modem") or error("No modem attached", 0)
modem.open(15) -- Open 43 so we can receive replies

-- Send our message

-- And wait for a reply
while true
do
local event, side, channel, replyChannel, message, distance
repeat
    event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
until channel == 15

modem.transmit(43, 15, "Hello, world!")

print("Received a reply: " .. tostring(message))
end