local modem = peripheral.find("modem") or error("No modem attached", 0)
modem.open(43) -- Open 43 so we can receive replies
print("open on 43")
-- Send our message

while true
do
modem.transmit(15, 43, "Hello Mathew :)")
print("transmitting to 15")

-- And wait for a reply
local event, side, channel, replyChannel, message, distance
repeat
event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
until channel == 43

print("Received a reply: " .. tostring(message))
end