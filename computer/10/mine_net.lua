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

function MineNet.TemplistenOnChannel(ChannelInput, attempts, gapDuration)
    -- And wait for a reply
    for i=0,attempts,1 do
        event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        if (message) then
            break
        end
        sleep(gapDuration)
    end
    return channel, replyChannel, message, distance 
end
