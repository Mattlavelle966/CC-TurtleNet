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

