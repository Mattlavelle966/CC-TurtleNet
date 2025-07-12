
require "mine_net"
require "mine_net_ui"
--MasterMineServer
local RECEIVE_CHANNEL = 43
local SENDING_CHANNEL = 15
local MASTER_RECEIVE_CHANNEL = 73
local MASTER_SENDING_CHANNEL = 32
local totalTurtles = 5
local buffer = {}
--read from file 
local latestTimestamp = 0
MineNetUI.initUI()
local modem = peripheral.find("modem") or error("No modem attached", 0)


-- Send our message
--temporary terminal till a startup file 
modem.open(MASTER_RECEIVE_CHANNEL) -- Open 43 so we can receive replies
print("waiting for UI Master")
MineNetUI.ClientBox(colors.yellow)
channel, replyChannel, message, distance = MineNet.listenOnChannel(MASTER_RECEIVE_CHANNEL)
print("master heard")
--ui
MineNetUI.ClientBox(colors.green)
MineNetUI.drawProgressBar()

modem.transmit(MASTER_SENDING_CHANNEL,MASTER_RECEIVE_CHANNEL,'starting slaves')
if (message == 'start slaves') then 
    modem.open(RECEIVE_CHANNEL)
    modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "hello")
    print("transmitting on Channel: " .. SENDING_CHANNEL)
    --ui
    MineNetUI.NodesBox(colors.yellow)
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
                    if (e[1] == "modem_message" and e[3] == RECEIVE_CHANNEL) then
                        message = e[5]
                        packets = textutils.unserialize(message)
                        MineNet.logToFile(packets,"packets")
                        MineNetUI.statusBarSetter(colors.green, MineNetUI.statusBars[i].X, MineNetUI.statusBars[i].Y, MineNetUI.statusBars[i].width)

                        if packets then
                            
                            for j=1,#packets,1 do
                                table.insert(buffer,packets[j])
                            end

                            gotResponse = true
                        else 
                            print("packet null")
                        end
                    elseif (e[1] == "timer" and e[2] == timer) then
                        print("timer triggered")
                        gotResponse = true
                    else
                        print("all failed")
                    end
                until gotResponse
            end
            MineNetUI.NodesBox(colors.green)
            MineNetUI.drawProgressBar()
            --should be 1D array of PACKS objects
            print(textutils.serialize(buffer))

            table.sort(buffer, function(a, b)
                return a.timestamp > b.timestamp
            end)
            MineNetUI.PackerCollBox(colors.green)
            MineNetUI.drawProgressBar()

            MineNet.logToFile(buffer,"buffer")
            
            MineNetUI.ManipBox(colors.green)
            MineNetUI.drawProgressBar()
            for i=1, #buffer,1 do
                currentBuffer = buffer[i]
                if (latestTimestamp <= currentBuffer.timestamp)then
                    latestTimestamp = currentBuffer.timestamp
                    print("Pushing latest to Masterdb")
                    modem.open(MASTER_RECEIVE_CHANNEL)
                    modem.transmit(MASTER_SENDING_CHANNEL,MASTER_RECEIVE_CHANNEL,textutils.serialize(currentBuffer))
                    channel, replyChannel, message, distance = MineNet.listenOnChannel(MASTER_RECEIVE_CHANNEL)
                    
                    if (message == 'worked') then
                        print("Pushed to Masterdb")
                        MineNetUI.StreamBox(colors.green)
                        MineNetUI.drawProgressBar()

                    else
                        print("message was invalid")
                        break
                    end
                end
            end
            modem.open(RECEIVE_CHANNEL)
            buffer = {}                
        end
        MineNet.loopUiInit()
    else
        print("ready not recieved")
    end
end
