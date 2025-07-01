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

local toggleChecker = false
local LatestTimestamp

UI.initBlockDB()
UI.init(monitor)

modem.open(MASTER_RECEIVE_CHANNEL)

function getClicks()
  while true do
    UI.drawText(37, 36, tostring(currentLayer) .. "  ", colors.green)
    local e, side, x, y = os.pullEvent("monitor_touch")
    if side == monitorSide then
      UI.handleTouch(x, y)
    end
  end
end

function packetCollector()
  while true do
    local e = { os.pullEvent() }
    if (e[1] == "modem_message") then
      MineNet.logToFile(textutils.serialize(e), 'e')
      MineNet.logToFile(textutils.serialize(e[5]), 'e5')

      pack = textutils.unserialize(e[5])
      if type(pack) == "table" then
        UI.drawText(42, 37, "Mine_Net Online", colors.green)
        local x = pack.x
        local y = pack.y
        local z = pack.z
        print(("Coords received: x=%d, y=%d, z=%d"):format(x, y, z))
        modem.transmit(MASTER_SENDING_CHANNEL,MASTER_RECEIVE_CHANNEL, 'worked')
        print("updating DB")
        UI.changeGridColor(x,z,y, colors.black)
        currentLayer = y
        print("getting latest")
        UI.CheckDB(currentLayer)
        print("DB loaded")
      else
        print("No valid packet data in event[5]")
        UI.drawText(42, 37, "MN packet failed", colors.red)
        sleep(1)
        UI.drawText(42, 38,"retrying...  ", colors.red)
        MineNet.restart()
      end
    end
  end
end

function drawDemo()

  UI.clear()
  UI.drawText(2, 1, "ComputerCraft UI Demo " .. os.time("local"), colors.cyan)
  UI.drawText(37, 36, tostring(currentLayer), colors.green)

  UI.drawButton("btn1", 2, 35, 10, 3, "Connect", colors.white, colors.blue, function()
    modem.transmit(MASTER_SENDING_CHANNEL,MASTER_RECEIVE_CHANNEL,'start slaves')
    print("sent")
    UI.drawText(42, 35, "Loading...", colors.white)
    print("waiting for master")
    channel, replyChannel, message, distance = MineNet.listenOnChannel(MASTER_RECEIVE_CHANNEL)
    if (message == 'starting slaves') then
      print("turtle initilized")
      UI.drawText(42, 36, "Mine_Net Init", colors.yellow)
      
    end
  end)

  UI.drawButton("btn2", 14, 35, 10, 3, "Update", colors.white, colors.green, function()
    colorIndex = colorIndex + 1
    if colorIndex > #colorCycle then colorIndex = 1 end
    UI.changeGridColor(28,16,currentLayer, colors.black)
    UI.CheckDB(currentLayer)
  end)
  
  UI.drawButton("stop", 26, 35, 10, 3, "reset", colors.white, colors.red, function()
    UI.clear()
    UI.drawText(2, 2, "Program restarting.", colors.red)
    sleep(1)
    print("Stopped by user")
    MineNet.restart()
    end)
    
  UI.drawButton("up", 37, 35, 3, 1, "^", colors.white, colors.red, function()
    if currentLayer <= 1 then
      currentLayer = 100
    else
      currentLayer = currentLayer - 1 
    end
    UI.CheckDB(currentLayer)
    end)

  UI.drawButton("down", 37, 37, 3, 1, "=", colors.white, colors.red, function()
    if currentLayer >= 100 then
      currentLayer = 1
    else
      currentLayer = currentLayer + 1 
    end
    UI.CheckDB(currentLayer)
    end)


  UI.CheckDB(currentLayer)
end

drawDemo()
-- note potential limitation on UI if DB updates are also managed by the same computer
parallel.waitForAny(getClicks,packetCollector)
