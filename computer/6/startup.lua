-- demo.lua
--MasterMineUI
require "ui_lib"  -- This defines a global table called UI because of how ui_lib.lua is written
require "mine_net"

--CONFIG
MAX_X = 100
MAX_Y = 100
MAX_Z = 100

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

local UI_X = 1
local UI_Y = 1

UI.initBlockDB()
UI.init(monitor)

modem.open(MASTER_RECEIVE_CHANNEL)

function getClicks()
  while true do
    UI.drawText(37, 38, tostring(currentLayer) .. "  ", colors.green)
    local e, side, x, y = os.pullEvent("monitor_touch")
    if side == monitorSide then
      UI.handleTouch(x, y)
    end
  end
end

function packetCollector()
  while true do
    UI.drawText(42, 38,"  waiting..    ", colors.white)
    UI.drawText(42, 1,"Y".. tostring(UI_Y) .."-"..tostring(UI_Y).."  X".. tostring(UI_X).."-"..tostring(UI_X+55).."  ", colors.white)
    local e = { os.pullEvent() }
    if (e[1] == "modem_message" and e[3] == MASTER_RECEIVE_CHANNEL) then
      MineNet.logToFile(textutils.serialize(e), 'e')
      MineNet.logToFile(textutils.serialize(e[5]), 'e5')

      pack = textutils.unserialize(e[5])
      if type(pack) == "table" then
        local x, y, z
        if pack.x and pack.y and pack.z and
          pack.x >= 1 and pack.x <= MAX_X and
          pack.y >= 1 and pack.y <= MAX_Y and
          pack.z >= 1 and pack.z <= MAX_Z then

          x = pack.x
          y = pack.y
          z = pack.z

          UI.drawText(42, 37, "Mine_Net Online ", colors.green)
          print(("Coords received: x=%d, y=%d, z=%d"):format(x, y, z))
          modem.transmit(MASTER_SENDING_CHANNEL,MASTER_RECEIVE_CHANNEL, 'worked')
          print("updating DB")
          UI.changeGridColor(x,z,y, colors.black)
          currentLayer = y
          print("getting latest")
          UI.CheckDB(currentLayer, UI_X, UI_Y)
          print("DB loaded")
        
        end
      else
        print("No valid packet data in event[5]")
        UI.drawText(42, 37, "MN packet failed", colors.red)
        UI.drawText(42, 38,"retrying...  ", colors.red)
        UI.drawText(42, 37,"             ", colors.red)
        UI.drawText(42, 38,"             ", colors.red)
      end
    end
  end
end

function drawDemo()

  UI.clear()

  UI.GetSavedDB()

  UI.drawText(2, 1, "ComputerCraft UI Demo " .. os.time("local"), colors.cyan)

  UI.drawButton("btn1", 2, 38, 3, 1, "Connect", colors.white, colors.blue, function()
    print("press")
    modem.transmit(MASTER_SENDING_CHANNEL,MASTER_RECEIVE_CHANNEL,'start slaves')
    print("sent")
    UI.drawText(42, 35, "Loading...", colors.white)
    print("waiting for master")
    channel, replyChannel, message, distance = MineNet.listenOnChannel(MASTER_RECEIVE_CHANNEL)
    if (message == 'starting slaves') then
      print("turtle initilized")
      UI.drawText(42, 36, "Mine_Net Init", colors.yellow)
      modem.transmit(MASTER_SENDING_CHANNEL,MASTER_RECEIVE_CHANNEL,'start slaves')
    end
  end)

  UI.drawButton("btn2", 14, 38, 3, 1, "Save", colors.white, colors.green, function()
    UI.SaveDB()
  end)
  
  UI.drawButton("stop", 26, 38, 3, 1, "reset", colors.white, colors.red, function()
    UI.clear()
    UI.drawText(2, 2, "Program restarting.", colors.red)
    sleep(1)
    UI.SaveDB()
    print("Stopped by user")
    MineNet.restart()
    end)
    
  UI.drawButton("uplayer", 33, 38, 3, 1, "-", colors.white, colors.red, function()
    if currentLayer <= 1 then
      currentLayer = 100
    else
      currentLayer = currentLayer - 1 
    end
    UI.CheckDB(currentLayer, UI_X,UI_Y)
    end)

  UI.drawButton("downlayer", 39, 38, 3, 1, "+", colors.white, colors.red, function()
    if currentLayer >= 100 then
      currentLayer = 1
    else
      currentLayer = currentLayer + 1 
    end
    UI.CheckDB(currentLayer, UI_X,UI_Y)
    end)

  UI.drawButton("upX", 1, 15, 1, 1, "-", colors.white, colors.red, function()
    if UI_X <= 1 then
      UI_X = 100 - 55
    else
      UI_X = UI_X - 1 
    end
    UI.CheckDB(currentLayer, UI_X,UI_Y)
    end)

  UI.drawButton("downX", 57, 15, 1, 1, "+", colors.white, colors.red, function()
    if UI_X >= 100 - 55 then
      UI_X = 1
    else
      UI_X = UI_X + 1 
    end
    UI.CheckDB(currentLayer, UI_X,UI_Y)
    end)
  UI.drawButton("upY", 29, 1, 1, 1, "-", colors.white, colors.red, function()
    if UI_Y <= 1 then
      UI_Y = 100 - 36
    else
      UI_Y = UI_Y - 1 
    end
    UI.CheckDB(currentLayer, UI_X,UI_Y)
    end)

  UI.drawButton("downY", 29, 37, 1, 1, "+", colors.white, colors.red, function()
    if UI_Y >= 100 - 36 then
      UI_Y = 1
    else
      UI_Y = UI_Y + 1 
    end
    UI.CheckDB(currentLayer, UI_X,UI_Y)
    end)


  UI.CheckDB(currentLayer, UI_X,UI_Y)
end

drawDemo()
-- note potential limitation on UI if DB updates are also managed by the same computer
parallel.waitForAny(getClicks,packetCollector)
