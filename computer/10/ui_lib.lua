-- ui_lib.lua
UI = {
    elements = {},
    width = 0,
    height = 0
}
BLOCK_DB = {}

function UI.init(monitor)
  UI.monitor = monitor
  UI.width, UI.height = monitor.getSize()
  monitor.setTextScale(0.5)
  UI.clear()
end

function UI.clear()
  local m = UI.monitor
  m.setBackgroundColor(colors.black)
  m.clear()
end

function UI.drawText(x, y, text, textColor, bgColor)
  local m = UI.monitor
  m.setTextColor(textColor or colors.white)
  m.setBackgroundColor(bgColor or colors.black)
  m.setCursorPos(x, y)
  m.write(text)
end

function UI.drawButton(id, x, y, w, h, label, textColor, bgColor, onClick)
  local m = UI.monitor
  local btn = {
    id = id, type = "button", x = x, y = y, w = w, h = h,
    label = label, textColor = textColor or colors.white,
    bgColor = bgColor or colors.gray, onClick = onClick
  }
  table.insert(UI.elements, btn)

  m.setBackgroundColor(btn.bgColor)
  for i = 0, h - 1 do
    m.setCursorPos(x, y + i)
    m.write((" "):rep(w))
  end

  m.setCursorPos(x + math.floor((w - #label) / 2), y + math.floor(h / 2))
  m.setTextColor(btn.textColor)
  m.write(label)
end

function UI.drawGrid(x, y, cols, rows, cellW, cellH, gridFunc)
  local m = UI.monitor
  for row = 1, rows do
    for col = 1, cols do
      local cellX = x + (col - 1) * cellW
      local cellY = y + (row - 1) * cellH
      local color = gridFunc(col, row)
      m.setBackgroundColor(color)
      for h = 0, cellH - 1 do
        m.setCursorPos(cellX, cellY + h)
        m.write((" "):rep(cellW))
      end
    end
  end
end

--NEW
function UI.initBlockDB() 
    for col = 1, 55 do
        BLOCK_DB[col] = {}
        for row = 1, 32 do
            BLOCK_DB[col][row] = {}  -- or a default value like false or "empty"
            for layers = 1, 100 do
              BLOCK_DB[col][row][layers] = colors.gray
            end
        end
    end
end
--NEW
--Note changeGridColor changes the database not the screen
function UI.changeGridColor(col, row, layer, color)
    if BLOCK_DB[col] and BLOCK_DB[col][row] and BLOCK_DB[col][row][layer] then
        BLOCK_DB[col][row][layer] = color
    end
end
--NEW
function UI.CheckDB(layer)
  selectedLayer = {}
  UI.drawGrid(2, 2, 55, 32, 1, 1, function(col, row)
    if BLOCK_DB[col] and BLOCK_DB[col][row] and BLOCK_DB[col][row][layer] then
      selectedLayer = BLOCK_DB[col][row][layer] 
    else 
      selectedLayer = colors.red -- only if empty for some reason
    end
    return selectedLayer
  end)
end

function UI.handleTouch(x, y)
  for _, el in ipairs(UI.elements) do
    if el.type == "button" then
      if x >= el.x and x <= el.x + el.w - 1 and y >= el.y and y <= el.y + el.h - 1 then
        if el.onClick then el.onClick() end
        break
      end
    end
  end
end
