
require 'TMNL'
require 'mine_net'
local modem = peripheral.find("modem") or error("No modem attached", 0)
local RECEIVE_CHANNEL = 15
local SENDING_CHANNEL = 43
modem.open(RECEIVE_CHANNEL)

print("please enter y to begin mining: ")
userInput = read()
if (userInput == 'y') then
    print("Happy Mining")
    print("waiting")
    C,RC,Message,D = MineNet.listenOnChannel(RECEIVE_CHANNEL)
    if ( Message == "hello") then
        print("Received")
        print("sending Ready")
        modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "ready")
        print("reccieved, awaiting response")
        cA,rcA,MessageA,dA = MineNet.listenOnChannel(RECEIVE_CHANNEL)
        if (MessageA == 'begin mining') then
            while true do
                -- max 55=x, 32=z/y because we are only looking at a one y coord at a time
                
                print("sending Packet")
                for i=0,3,1 do
                    currentMove = TMNL.Forward()
                    modem.transmit(SENDING_CHANNEL,RECEIVE_CHANNEL,textutils.serialize(currentMove))
                end
                TMNL.TurnLeft()
            end
        else
            print("begin mining not recieved")
        end
    else
        print("hello was not recieved")
    end

    
else
    print("invalid") 
end