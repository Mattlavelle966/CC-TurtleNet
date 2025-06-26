-- demo.lua

require "ui_lib"  -- This defines a global table called UI because of how ui_lib.lua is written

local monitorSide = "right"
local monitor = peripheral.wrap(monitorSide)

local colorCycle = { colors.red, colors.green, colors.blue, colors.yellow, colors.orange }
local colorIndex = 1

UI.initBlockDB()
UI.init(monitor)


function drawDemo()
  UI.clear()
  UI.drawText(2, 1, "ComputerCraft UI Demo", colors.cyan)

  UI.drawButton("btn1", 2, 35, 10, 3, "Click Me", colors.white, colors.blue, function()
    UI.drawText(2, 7, "Button Clicked!", colors.lime, colors.black)
  end)

  UI.drawButton("btn2", 14, 35, 10, 3, "Cycle Grid", colors.white, colors.green, function()
    colorIndex = colorIndex + 1
    if colorIndex > #colorCycle then colorIndex = 1 end
    UI.changeGridColor(28,16, colors.black)
    UI.CheckDB()
  end)
  
  UI.drawButton("stop", 26, 35, 10, 3, "Exit", colors.white, colors.red, function()
    UI.clear()
    UI.drawText(2, 2, "Program stopped.", colors.red)
    sleep(1)
    error("Stopped by user")
    end)


  UI.CheckDB()
end

drawDemo()

while true do
  local e, side, x, y = os.pullEvent("monitor_touch")
  if side == monitorSide then
    UI.handleTouch(x, y)
  end
end
