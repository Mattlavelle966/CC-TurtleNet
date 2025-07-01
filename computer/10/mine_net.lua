-- mine_net.lua
MineNet = {}

function MineNet.logToFile(data,name)
  file = fs.open(name..".txt", "w")
  file.write(textutils.serialize(data))
  file.close()
end

function MineNet.restart()
    print("rebooting..")
    sleep(2)
    os.reboot()
end

function MineNet.timerListenOnChannel(duration)
    local timer = os.startTimer(duration)
    local gotResponse = false
    repeat
        local e = { os.pullEvent() }
        if (e[1] == "modem_message") then
            channel = e[3]
            replyChannel = e[4]
            message = e[5]
            distance = e[6]
            gotResponse = true

        elseif (e[1] == "timer") then
            print("timer triggered")
            gotResponse = true
        end
    until gotResponse
    return channel, replyChannel, message, distance 
end

function MineNet.listenOnChannel(ChannelInput)
    -- And wait for a reply
    local event, side, channel, replyChannel, message, distance
    repeat
        event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    until channel == ChannelInput
    return channel, replyChannel, message, distance 
end

function MineNet.connectionValidation(modem, targetPort, listeningPort, authToken)
    local masterIsReady = false
    local slaveIsReady = false
    modem.open(listeningPort) -- Open 43 so we can receive replies
    --send to server that I am a slave
    -- isOpen
    masterIsReady = isOpen(targetPort)
    -- wait for reply that it is a master
    local event, side, channel, replyChannel, message, distance
    repeat
        event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    until channel == targetPort and message == authToken

    print("Master succsesfully connected to")
    modem.transmit(targetPort, listeningPort, "ready")
    print("Master knows we are ready")

    return slaveIsReady
end