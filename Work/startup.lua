-- server_ui.lua
require "ui_lib"

local monitorSide = "top"
local monitor = peripheral.wrap(monitorSide)
UI.init(monitor)

-- Constants for layout positions
local nodeStartX = 4
local nodeStartY = 4
local nodeWidth = 10
local nodeHeight = 6
local nodeSpacing = 2

local nodeCount = 4

function drawHeader()
  UI.drawText(2, 1, "MineNetTracker", colors.white)
end

function drawNodeSection()
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
      monitor.setCursorPos(x + 2, y + 1 + dy)
      monitor.write((" "):rep(nodeWidth - 4))
    end

    -- Node ID label
    UI.drawText(x + 3, y + 4, "#" .. i, colors.white, colors.black)

    -- Status bar (default green for now)
    monitor.setBackgroundColor(colors.green)
    monitor.setCursorPos(x + 1, y + nodeHeight)
    monitor.write((" "):rep(nodeWidth - 2))
  end
end

function drawFlowSteps(startX, startY)
  local function drawAsciiBox(x, y, label, color)
    local width = #label
    UI.drawText(x, y,     "+" .. string.rep("-", width) .. "+", color, colors.black)
    UI.drawText(x, y + 1, "|" .. label .. "|", color, colors.black)
    UI.drawText(x, y + 2, "+" .. string.rep("-", width) .. "+", color, colors.black)
  end

  local white = colors.white
  local green = colors.lime

  -- Box coordinates relative to startX/startY
  local clientX, clientY = startX, startY
  local nodesX, nodesY = startX + 16, startY
  local packetColX, packetColY = startX + 32, startY
  local packetManipX, packetManipY = startX, startY + 6
  local streamX, streamY = startX + 32, startY + 6

  -- Draw boxes
  drawAsciiBox(clientX, clientY, "Client", green)
  drawAsciiBox(nodesX, nodesY, "Nodes", green)
  drawAsciiBox(packetColX, packetColY, "Packet Collection", white)
  drawAsciiBox(packetManipX, packetManipY, "Packet Manip", white)
  drawAsciiBox(streamX, streamY, "Stream", white)

  -- Horizontal connectors
  UI.drawText(clientX + 8, clientY + 1, "--->", green)
  UI.drawText(nodesX + 7, nodesY + 1, "------>", white)

  -- Vertical from Nodes to Packet Manip
  UI.drawText(nodesX + 4, nodesY + 3, "  |", white)
  UI.drawText(nodesX + 4, nodesY + 4, "  |", white)
  UI.drawText(nodesX + 4, nodesY + 5, "  v", white)

  -- Horizontal from Packet Manip to Stream
  UI.drawText(packetManipX + 14, packetManipY + 1, "------------->", white)

  -- Vertical from Packet Collection to Stream
  UI.drawText(packetColX + 18, packetColY + 3, "  |", white)
  UI.drawText(packetColX + 18, packetColY + 4, "  |", white)
  UI.drawText(packetColX + 18, packetColY + 5, "  v", white)
end



function drawProgressBar()
  local x = 4
  local y = 35
  local width = 45

  -- Background (gray)
  monitor.setBackgroundColor(colors.lightGray)
  monitor.setCursorPos(x, y)
  monitor.write((" "):rep(width))

  -- Default fill (partial green)
  local filled = math.floor(width * 0.6)
  monitor.setBackgroundColor(colors.lime)
  monitor.setCursorPos(x, y)
  monitor.write((" "):rep(filled))
end

function drawResetButton()
  local label = "Reset"
  local w = #label + 2
  local x = 47
  local y = 1

  monitor.setBackgroundColor(colors.red)
  monitor.setCursorPos(x, y)
  monitor.write((" "):rep(w))
  UI.drawText(x + 1, y, label, colors.white, colors.red)
end

-- Draw all UI components
UI.clear()
drawHeader()
drawResetButton()
drawNodeSection()
drawFlowSteps(1,20)
drawProgressBar()
