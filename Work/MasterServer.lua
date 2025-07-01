
require "mine_net"

local RECEIVE_CHANNEL = 43
local SENDING_CHANNEL = 15
local MASTER_RECEIVE_CHANNEL = 73
local MASTER_SENDING_CHANNEL = 32
local totalTurtles = 2
local buffer = {}
--read from file 
local latestTimestamp = 0

local modem = peripheral.find("modem") or error("No modem attached", 0)


-- Send our message
--temporary terminal till a startup file 
print("please enter y to begin: ")
userInput = read()
if (userInput == 'y') then
    modem.open(MASTER_RECEIVE_CHANNEL) -- Open 43 so we can receive replies
    print("waiting for UI Master")
    channel, replyChannel, message, distance = MineNet.listenOnChannel(MASTER_RECEIVE_CHANNEL)
    print("master heard")
    modem.transmit(MASTER_SENDING_CHANNEL,MASTER_RECEIVE_CHANNEL,'starting slaves')
    if (message == 'start slaves') then 
        modem.open(RECEIVE_CHANNEL)
        modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "hello")
        print("transmitting on Channel: " .. SENDING_CHANNEL)
        local tansmit15 = os.startTimer(5)
        -- And wait for a reply
        channel, replyChannel, message, distance = MineNet.listenOnChannel(RECEIVE_CHANNEL)
        if (message == "ready") then
            print("ready")
            modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "begin mining")
            while true do
                print("awaiting Turtles")
                for i=1,totalTurtles,1 do
                    print("requesting turtle" .. i)
                    modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "send latest"..i)
                    local timer = os.startTimer(5)
                    local gotResponse = false
                    repeat
                        local e = { os.pullEvent() }
                        if (e[1] == "modem_message") then
                            message = e[5]
                            packets = textutils.unserialize(message)
                            MineNet.logToFile(packets,"packets")
                            if packets then
                                
                                for j=1,#packets,1 do
                                    table.insert(buffer,packets[j])
                                end

                                gotResponse = true
                            else 
                                print("packet null")
                            end
                        elseif (e[1] == "timer") then
                            print("timer triggered")
                            gotResponse = true
                        end
                    until gotResponse
                end
                --should be 1D array of PACKS objects
                print(textutils.serialize(buffer))

                table.sort(buffer, function(a, b)
                    return a.timestamp > b.timestamp
                end)

                MineNet.logToFile(buffer,"buffer")
                for i=1, #buffer,1 do
                    currentBuffer = buffer[i]
                    if (latestTimestamp <= currentBuffer.timestamp)then
                        latestTimestamp = currentBuffer.timestamp
                        print("Pushing latest to Masterdb")
                        modem.transmit(MASTER_SENDING_CHANNEL,MASTER_RECEIVE_CHANNEL,textutils.serialize(currentBuffer))
                        modem.open(MASTER_RECEIVE_CHANNEL)
                        channel, replyChannel, message, distance = MineNet.listenOnChannel(MASTER_RECEIVE_CHANNEL)
                        if (message == 'worked') then
                            print("Pushed to Masterdb")
                        else
                            print("push to DB failed")
                        end
                    end
                end
                modem.open(RECEIVE_CHANNEL)
                buffer = {}                
            end
        else
            print("ready not recieved")
            MineNet.restart()    
        end
    
    end
else
    print("invalid") 
end
