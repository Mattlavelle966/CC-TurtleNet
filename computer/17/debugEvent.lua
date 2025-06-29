function debugEvents()
  while true do
    local e = { os.pullEvent() }
    print("EVENT: " .. textutils.serialize(e))
  end
end

debugEvents()