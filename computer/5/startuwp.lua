rednet.close("right")
rednet.open("right")
term.clear()
term.setCursorPos(0,0)
print("welcome to a SipsCo Admin Verification system")
while (true)do
    print("please enter password::")
    PASSWORD = read()
    rednet.send(9,PASSWORD)
    print("LOADING")
    ServID, VALIDATION,PROTO = rednet.receive()
    if (VALIDATION == "VALID")then
        redstone.setOutput("left", true)
        redstone.setOutput("top",true)
        print("VALID KEY")
        print("please enter door closing!!!")
        sleep(10)
        redstone.setOutput("left", false)
        redstone.setOutput("top", false)
        term.clear()
        term.setCursorPos(0,0)
        
    else
        print("INVALID")
        print("Sounding alarm")
        redstone.setOutput("back", true)
        sleep(5)
        redstone.setOutput("back", true)
    end
    
end
