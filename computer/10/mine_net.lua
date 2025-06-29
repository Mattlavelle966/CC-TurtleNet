-- mine_net.lua
MineNet = {}

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