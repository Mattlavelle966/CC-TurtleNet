while true do
    local modem = peripheral.find("modem") or error("No modem attached", 0)
    print("transmiting")
    sleep(30)
    modem.transmit(43, 15, "ready")


end
