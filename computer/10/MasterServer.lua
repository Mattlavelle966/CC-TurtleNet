

require "mine_net"


local modem = peripheral.find("modem") or error("No modem attached", 0)
modem.open(43) -- Open 43 so we can receive replies
print("open on 43")
-- Send our message

while true
do
    local netPackage
    modem.transmit(15, 43, "hello")
    print("transmitting to 15")

    -- And wait for a reply
    channel, replyChannel, message, distance = MineNet.listenOnChannel(43)



    if (message == "ready") then
        print("ready")
        modem.transmit(15, 43, "begin mining")
        channel, replyChannel, message, distance = MineNet.listenOnChannel(43)
        netPackage = message
        print("Pushing to db")
        modem.transmit(75,33, "hello DB") 
        

    end
        
end
