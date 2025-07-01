
require 'TMNL'
require 'mine_net'
local modem = peripheral.find("modem") or error("No modem attached", 0)
local RECEIVE_CHANNEL = 15
local SENDING_CHANNEL = 43
modem.open(RECEIVE_CHANNEL)
function restart()
    print("rebooting..")
    sleep(2)
    os.reboot()
end

function MovementLoop()
    print("thread 1")
    while true do
        -- max 55=x, 32=z/y because we are only looking at a one y coord at a time
       
         sleep(1)
        TMNL.Forward()
        sleep(1)
        TMNL.Forward()
        sleep(1)
        TMNL.Forward()
        sleep(1)
        TMNL.Forward()
        sleep(1)
        TMNL.Forward()
        sleep(1)
        TMNL.Forward()
        sleep(1)
        TMNL.Forward()
        sleep(1)
        TMNL.Forward()
        
        TMNL.TurnLeft()
    end
end
function ListenLoop()
    print("thread 2")
    while true do
        local e = { os.pullEvent() }
        if (e[1] == "modem_message") then
            print("EVENT: " .. textutils.serialize(e))

            pack = e[5]
            if (pack == "send latest1") then
                print("EVENT: " .. textutils.serialize(e[5]))
                --if (#TMNL.Queue > 0) then
                print("sending Packet")
                modem.transmit(SENDING_CHANNEL,RECEIVE_CHANNEL,textutils.serialize(TMNL.Packet))
                --    TMNL.Queue = {}
                --else
                --    print("empty queue")
                --end
            else
                 print("wrong pack")       
            end
        end
    end
end

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
        --actions thread below
        parallel.waitForAny(MovementLoop,ListenLoop)
    else
        print("begin mining not recieved")
        restart()
    end
else
    print("hello was not recieved")
    restart()
end

    