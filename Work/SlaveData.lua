local modem = periphral.find("modem") or error("No modem attached", 0)
MineNet.connectionValidation(modem, 43, 15, "hello")
