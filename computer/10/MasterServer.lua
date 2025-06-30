
require "mine_net"

local RECEIVE_CHANNEL = 43
local SENDING_CHANNEL = 15
local MASTER_RECEIVE_CHANNEL = 73
local MASTER_SENDING_CHANNEL = 32
local totalTurtles = 2
local buffer = {}

local modem = peripheral.find("modem") or error("No modem attached", 0)

function logToFile(data,name)
  file = fs.open(name..".txt", "w")
  file.write(textutils.serialize(data))
  file.close()
end

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
        -- And wait for a reply
        channel, replyChannel, message, distance = MineNet.listenOnChannel(RECEIVE_CHANNEL)
        
        if (message == "ready") then
            print("ready")
            modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "begin mining")
            while true do
                
                --below should be the array of listens depending on how many turtles there are
                print("awaiting Turtles")
                --
                for i=1,totalTurtles,1 do
                    print("requesting turtle" .. i)
                    sleep(.5)
                    modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "send latest"..i)
                    local e = { os.pullEvent() }
                    if (e[1] == "modem_message") then
                        --print("EVENT: " .. textutils.serialize(e))
                        logToFile(e,"e")
                        sleep(1)
                        message = e[5]
                        packets = textutils.unserialize(message)
                        for j=1,#packets,1 do
                            sleep(1)
                            logToFile(packets[j],"packetsJ")
                            --print(textutils.serialize(packets[j]))                            
                            table.insert(buffer,packets[j])
                           
                        end
                    end
                end
                --should be 1D array of PACKS objects
                print(textutils.serialize(buffer))
                table.sort(buffer, function(a, b)
                    return a.timestamp > b.timestamp
                end)
                logToFile(buffer,"buffer")
                for i=0, #buffer,1 do
                    logToFile(textutils.serialize(buffer[i]),"bufferI") 
                    print("Pushing to Masterdb")
                    modem.transmit(MASTER_SENDING_CHANNEL,MASTER_RECEIVE_CHANNEL,textutils.serialize(buffer[i]))
                    modem.open(MASTER_RECEIVE_CHANNEL)
                    channel, replyChannel, message, distance = MineNet.listenOnChannel(MASTER_RECEIVE_CHANNEL)
                    if (message == 'worked') then
                        print("Pushed to Masterdb")
                    else
                        print("push to DB failed")
                    end
                end

                modem.open(RECEIVE_CHANNEL)
                buffer = {}                
            end
        else
            print("ready not recieved")    
        end
    
    end
else
    print("invalid") 
end
