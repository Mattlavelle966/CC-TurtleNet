-- server_ui.lua
require "ui_lib"
require "mine_net"


MineNetUI = {}

local monitorSide = "left"
local monitor = peripheral.wrap(monitorSide)
UI.init(monitor)

-- Constants for layout positions
local nodeStartX = 4
local nodeStartY = 4
local nodeWidth = 5
local nodeHeight = 5
local nodeSpacing = 2

local nodeCount = 5

local ERDStartX = 5
local ERDStartY = 15
local boxW = 12
local boxH = 5
local colorMain = colors.green
local colorSecondary = colors.lightGray
local textColor = colors.black

local m = UI.monitor
local completionNum = .0
-- Helper to draw a filled box
MineNetUI.statusBars = {}

-- Box positions
local clientX, clientY = ERDStartX, ERDStartY
local nodesX, nodesY = clientX + boxW + 4, clientY
local packetColX, packetColY = nodesX + boxW + 4, nodesY
local packetManipX, packetManipY = clientX, clientY + boxH + 4
local streamX, streamY = packetManipX + boxW + 8, packetManipY




function MineNetUI.drawHeader()
  UI.drawText(2, 1, "MineNetTracker", colors.white)
end

function MineNetUI.statusBarSetter(color,locX,locY,Width)
  monitor.setBackgroundColor(color)
  monitor.setCursorPos(locX, locY)
  monitor.write((" "):rep(Width))

end

function MineNetUI.drawNodeSection()
  -- Section Title
  UI.drawText(18, 2, "Node Connection State", colors.white, colors.black)
  -- Draw nodes
  for i = 1, nodeCount do
    local x = nodeStartX + (i - 1) * (nodeWidth + nodeSpacing)
    local y = nodeStartY

    -- Node outer box
    monitor.setBackgroundColor(colors.gray)
    for dy = 0, nodeHeight - 1 do
      monitor.setCursorPos(x, y + dy)
      monitor.write((" "):rep(nodeWidth))
    end
    -- Yellow screen (inner block)
    monitor.setBackgroundColor(colors.yellow)
    for dy = 0, 2 do
      monitor.setCursorPos(x + 1, y + 1 + dy)
      monitor.write((" "):rep(nodeWidth - 2))
    end
    
    -- Node ID label
    UI.drawText(x + 3, y + 4, "#" .. i, colors.white, colors.black)
    -- Status bar (default green for now)

    local statusWidth = nodeWidth - 2
    local statusBarY = y + nodeHeight
    local statusBarX = x+1
    table.insert(MineNetUI.statusBars,{
      X = x+1,
      Y = y + nodeHeight,
      width = statusWidth
      
    })
    MineNetUI.statusBarSetter(colors.red, statusBarX,statusBarY,statusWidth)
  end
end

--box Connections
function MineNetUI.ClientConnector(color)
  UI.drawGrid(clientX + boxW, clientY + math.floor(boxH / 2), 4, 1, 1, 1, function() return color end)
end
function MineNetUI.NodesConnector(color)
  UI.drawGrid(nodesX + boxW, nodesY + math.floor(boxH / 2), 4, 1, 1, 1, function() return color end)
end
function MineNetUI.CollectorConnector(color)
  UI.drawGrid(nodesX - 11, nodesY + boxH + 3, 1, 1, 1, 1, function() return color end)
  UI.drawGrid(nodesX - 11, nodesY + boxH + 2, 41, 1, 1, 1, function() return color end)
  UI.drawGrid(packetColX + boxW + 2, packetColY + boxH, 1, 3, 1, 1, function() return color end)
end
function MineNetUI.ManipConnector(color)
  UI.drawGrid(packetManipX + boxW + 2, packetManipY + math.floor(boxH / 2), 6, 1, 1, 1, function() return color end)
end
  

  -- Draw main boxes
function MineNetUI.ClientBox(color)
  UI.drawBox(clientX, clientY, boxW, boxH, color, "Client",m)
  if(color == colors.green)then
    MineNetUI.ClientConnector(color)
    completionNum = .1    
  elseif color == colorSecondary then  
    MineNetUI.ClientConnector(color)
  end  

end
function MineNetUI.NodesBox(color)
  UI.drawBox(nodesX, nodesY, boxW, boxH, color, "Nodes",m)
  if(color == colors.green)then
    MineNetUI.NodesConnector(color)
    completionNum = .2    
  elseif color == colorSecondary then  
    MineNetUI.NodesConnector(color)
  end
end
function MineNetUI.PackerCollBox(color)
  UI.drawBox(packetColX, packetColY, boxW + 4, boxH, color, "Packet Coll.",m)
  if(color == colors.green)then
    MineNetUI.CollectorConnector(color)
    completionNum = .4 
  elseif color == colorSecondary then   
    MineNetUI.CollectorConnector(color)
  end
end
function MineNetUI.ManipBox(color)
  UI.drawBox(packetManipX, packetManipY, boxW + 2, boxH, color, "Packet Manip",m)
  if(color == colorMain)then
    MineNetUI.ManipConnector(color)
    completionNum = .8
  elseif color == colorSecondary then
    MineNetUI.ManipConnector(color)
  end
end
function MineNetUI.StreamBox(color)
  UI.drawBox(streamX, streamY, boxW, boxH, color, "Stream",m)
  if(color == colors.green)then
    completionNum = 1   
  end
end



function MineNetUI.drawProgressBar()
  local x = 4
  local y = 35
  local width = 50

  -- Background (gray)
  monitor.setBackgroundColor(colors.lightGray)
  monitor.setCursorPos(x, y)
  monitor.write((" "):rep(width))

  -- Default fill (partial green)
  if (completionNum > 0)then
    local filled = math.floor(width * completionNum)
    monitor.setBackgroundColor(colors.lime)
    monitor.setCursorPos(x, y)
    monitor.write((" "):rep(filled))
  end
end

function MineNetUI.drawResetButton()
  local label = "Reset"
  local x = 47
  local y = 1

  UI.drawButton("1", x, y, 3, 1, label, colors.white, colors.red, function()
    MineNet.restart()
  end)
end
function MineNetUI.ResetNodeStatusBars()
  for i,val in ipairs(MineNetUI.statusBars) do
    MineNetUI.statusBarSetter(colors.red, val.X, val.Y, val.width)
  end
end
-- Draw all UI components

function MineNetUI.initUI()
  UI.clear()
  MineNetUI.drawHeader()
  MineNetUI.drawResetButton()
  MineNetUI.drawNodeSection()
  MineNetUI.ClientBox(colorSecondary)
  MineNetUI.NodesBox(colorSecondary)
  MineNetUI.PackerCollBox(colorSecondary)
  MineNetUI.ManipBox(colorSecondary)
  MineNetUI.StreamBox(colorSecondary)
  MineNetUI.drawProgressBar()
end
function MineNet.loopUiInit()
  MineNetUI.drawNodeSection()
  MineNetUI.NodesBox(colorSecondary)
  MineNetUI.PackerCollBox(colorSecondary)
  MineNetUI.ManipBox(colorSecondary)
  MineNetUI.StreamBox(colorSecondary)
  MineNetUI.ClientConnector(colorSecondary)
  MineNetUI.NodesConnector(colorSecondary)
  MineNetUI.CollectorConnector(colorSecondary)
  MineNetUI.ManipConnector(colorSecondary)
  completionNum = .0
  MineNetUI.drawProgressBar()
  MineNetUI.ResetNodeStatusBars()
end


--MineNetUI.initUI()

--MineNetUI.ClientBox(colorMain)
--MineNetUI.drawProgressBar()

--MineNetUI.NodesBox(colors.yellow)
--for i, value in ipairs(statusBars) do
  --MineNetUI.statusBarSetter(colorMain, value.X,value.Y,value.width)
--end
--MineNetUI.NodesBox(colorMain)
--MineNetUI.drawProgressBar()

--MineNetUI.PackerCollBox(colorMain)
--MineNetUI.drawProgressBar()
--MineNetUI.ManipBox(colorMain)
--MineNetUI.drawProgressBar()
--MineNetUI.StreamBox(colorMain)
--MineNetUI.drawProgressBar()
