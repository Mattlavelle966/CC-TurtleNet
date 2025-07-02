
require 'TMNL'
require 'mine_net'
local modem = peripheral.find("modem") or error("No modem attached", 0)
local RECEIVE_CHANNEL = 15
local SENDING_CHANNEL = 43
--CONFIG
local MASTER_TURTLE_NUMBER = 2
modem.open(RECEIVE_CHANNEL)
TMNL.TurtleInit()


function MovementLoop()
    print("thread 1")
    while true do
        -- max 55=x, 32=z/y because we are only looking at a one y coord at a time
       
        for i = 1, 16, 1 do
            data = TMNL.Forward()
            MineNet.logToFile(data,"data")
            if (data.Result == false) then
                TMNL.TurnRight()
            end
        end 
        
        TMNL.TurnLeft()
    end
end
function ListenLoop()
    print("thread 2")
    while true do
        local e = { os.pullEvent() }
        if (e[1] == "modem_message" and e[3] == RECEIVE_CHANNEL) then
            print("EVENT: " .. textutils.serialize(e))

            pack = e[5]
            if (pack == "send latest" .. tostring(MASTER_TURTLE_NUMBER)) then    
                print("EVENT: " .. textutils.serialize(e[5]))
                print("sending Packet")
                modem.transmit(SENDING_CHANNEL,RECEIVE_CHANNEL,textutils.serialize(TMNL.Packet))
                elseif (pack == "stop") then
                MineNet.restart()
            else
                print("wrong pack")
             end
        end
    end
end

print("Happy Mining")
print("waiting")
while true do
    C,RC,Message,D = MineNet.listenOnChannel(RECEIVE_CHANNEL)
    if ( Message == "hello") then
        print("Received")
        print("sending Ready")
        sleep(5)
        modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "ready")
        print("reccieved, awaiting response")
        cA,rcA,MessageA,dA = MineNet.listenOnChannel(RECEIVE_CHANNEL)
        if (MessageA == 'begin mining') then
            --actions thread below
            parallel.waitForAny(MovementLoop,ListenLoop)
        else
            print("begin mining not recieved")
        end
    else
        print("hello was not recieved")
    end
end

    