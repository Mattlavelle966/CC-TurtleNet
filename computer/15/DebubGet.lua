
local modem = peripheral.find("modem") or error("No modem attached", 0)
modem.open(15) -- Open 43 so we can receive replies
print("open on 15")
local event, side, channel, replyChannel, message, distance
repeat
event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
until channel == 15

if (message == "hello") then
    modem.transmit(43, 15, "ready")
    local event1, side1, channel1, replyChannel1, message1, distance1
    repeat
    event1, side1, channel1, replyChannel1, message1, distance1 = os.pullEvent("modem_message")
    until channel == 15
    print(distance1)

    

end