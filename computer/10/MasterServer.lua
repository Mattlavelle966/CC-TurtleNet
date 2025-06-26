
require "ui_lib"
require "mine_net"

local RECEIVE_CHANNEL = 43
local SENDING_CHANNEL = 15
local MASTER_RECEIVE_CHANNEL = 73
local MASTER_SENDING_CHANNEL = 32

local modem = peripheral.find("modem") or error("No modem attached", 0)
UI.initBlockDB()
-- Send our message
--temporary terminal till a startup file 
print("please enter y to begin: ")
userInput = read()
if (userInput == 'y') then
    while true
    do
        modem.open(MASTER_RECEIVE_CHANNEL) -- Open 43 so we can receive replies
        local netPackage
        print("waiting for UI Master")
        channel, replyChannel, message, distance = MineNet.listenOnChannel(MASTER_RECEIVE_CHANNEL)
        print("master heard")
        modem.transmit(MASTER_SENDING_CHANNEL,MASTER_RECEIVE_CHANNEL,'starting slaves')

        if (message == 'start slaves') then 
            modem.open(RECEIVE_CHANNEL)
            modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "hello")
            print("transmitting on Channel: " .. RECEIVE_CHANNEL)
            
            -- And wait for a reply
            channel, replyChannel, message, distance = MineNet.listenOnChannel(RECEIVE_CHANNEL)
            
            
            
            if (message == "ready") then
                print("ready")
                modem.transmit(SENDING_CHANNEL, RECEIVE_CHANNEL, "begin mining")
                channel, replyChannel, message, distance = MineNet.listenOnChannel(RECEIVE_CHANNEL)
                netPackage = message
                --parse message here
                
                -- once parsed push
                print("Pushing to Masterdb")
                
            
                 --db push update here 
            
            end
        
        end
    end
else
    print("invalid") 
end
