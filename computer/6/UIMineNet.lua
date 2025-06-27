-- demo.lua

require "ui_lib"  -- This defines a global table called UI because of how ui_lib.lua is written
require "mine_net"

local MASTER_SENDING_CHANNEL = 73
local MASTER_RECEIVE_CHANNEL = 32
local monitorSide = "right"
local monitor = peripheral.wrap(monitorSide)
local modem = peripheral.find("modem") or error("No modem attached", 0)
local currentLayer = 1
local colorCycle = { colors.red, colors.green, colors.blue, colors.yellow, colors.orange }
local colorIndex = 1

local LatestTimestamp

UI.initBlockDB()
UI.init(monitor)

modem.open(MASTER_RECEIVE_CHANNEL)


function drawDemo()
  UI.clear()
  UI.drawText(2, 1, "ComputerCraft UI Demo " .. os.time("local"), colors.cyan)

  UI.drawButton("btn1", 2, 35, 10, 3, "Start", colors.white, colors.blue, function()
    modem.transmit(MASTER_SENDING_CHANNEL,MASTER_RECEIVE_CHANNEL,'start slaves')
    print("sent")
    UI.drawText(40, 35, "Loading...", colors.white)
    print("waiting for master")
    channel, replyChannel, message, distance = MineNet.listenOnChannel(MASTER_RECEIVE_CHANNEL)
    if (message == 'starting slaves') then
      UI.drawText(40, 36, "Mine_Net Online", colors.green)
      print("online")
    end
  end)

  UI.drawButton("btn2", 14, 35, 10, 3, "Update", colors.white, colors.green, function()
    colorIndex = colorIndex + 1
    if colorIndex > #colorCycle then colorIndex = 1 end
    UI.changeGridColor(28,16,currentLayer, colors.black)
    UI.CheckDB(currentLayer)
  end)
  
  UI.drawButton("stop", 26, 35, 10, 3, "Exit", colors.white, colors.red, function()
    UI.clear()
    UI.drawText(2, 2, "Program stopped.", colors.red)
    sleep(1)
    error("Stopped by user")
    end)


  UI.CheckDB(currentLayer)
end

drawDemo()
-- note potential limitation on UI if DB updates are also managed by the same computer
while true do
  local e, side, x, y = os.pullEvent("monitor_touch")
  if side == monitorSide then
    UI.handleTouch(x, y)
  end
end
