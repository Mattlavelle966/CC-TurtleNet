function serialize(tbl)
  local result = "{"
  for k, v in pairs(tbl) do
    if type(v) == "table" then
      result = result .. serialize(v)
    elseif type(v) == "string" then
      result = result .. string.format("%q", v)
    else
      result = result .. tostring(v)
    end

    result = result .. ","
  end
  return result .. "}"
end

inputStr = "Nodes Available is 1 of a 20 Nodes: kipsem,trailsm,hello"
print(inputStr)

local start_idx, end_idx = string.find(inputStr, "Nodes:")
local spacer = ","

--print(start_idx)
--print(end_idx)

--print(string.sub(inputStr, start_idx, start_idx))
--print(#inputStr)
local list = {}
local curNode = ""
--end_idx+2 removes the spaces from the first entry 
for i = end_idx+2, #inputStr do
  local cur = string.sub(inputStr, i, i)
  if(cur ~= spacer)then
    curNode = curNode .. cur
  end
  if(cur == spacer or i == #inputStr)then
    table.insert(list, curNode)
    curNode = ""
  end
end
print("NodeIds:" .. serialize(list))
