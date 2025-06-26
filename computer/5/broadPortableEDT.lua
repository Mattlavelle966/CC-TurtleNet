rednet.close("back")
rednet.open("back")


--these two beloq will equal return to vals from
--the asignVals func using by ref
local GlobalInputOne = ""
local GlobalInputTwo = ""
continue = true
print("Potential Connections")
print("PC:5, PC:8")
print("please type exit to end the program:")
function asignVals(valueSTR)
    GlobalInputOne = ""
    GlobalInputTwo = ""
    firstVal = ""
    secondVal = ""
    emptySpace = false
    for i = 1, #valueSTR do
        local currentChar = valueSTR:sub(i,i)
        if(currentChar == " ")then
            secondVal = secondVal .. valueSTR:sub(i+1,i+1)
            --secondVal = secondVal .. valueSTR:sub(i+2,i+2)
            emptySpace = true
        elseif(emptySpace == false)then
            firstVal = firstVal .. currentChar     
        end
    end
    GlobalInputOne = firstVal
    GlobalInputTwo = secondVal    
 
end
--asignVals("forward 1")
--print(GlobalInputTwo)
--asignVals("back 3")
--print(GlobalInputTwo)
--ABOVE FUNC MAY NEED TO BE IN THE RECIVING SIDE
print("please enter id: ")
currentId = read()

while (continue == true) do
 print("please enter a message/command: ")
 outGoingMessage = read()
 if(outGoingMessage ~= "help" and outGoingMessage ~= "change id") then
    rednet.send(tonumber(currentId), outGoingMessage)
    ID, Message, Protocal = rednet.receive()
    term.setTextColor(colors.green) 
    print("PCID:"..ID.." :MSG: "..Message)
    term.setTextColor(colors.white)
 end
     if (outGoingMessage == "change id")then
         print("please enter a Id: ")
         newId = read()
         rednet.send(tonumber(newId),"do you exist")
         term.setTextColor(colors.green)
         checkId,msg, proto = rednet.receive()
         print(checkId..":ID: "..msg)
         term.setTextColor(colors.white)
         currentId = newId
     end
 
 if(outGoingMessage == "up") then
    id, commandStatus, proto = rednet.receive()
    print(commandStatus) 
 end
 if(outGoingMessage == "down")then
     id, commandStatus, proto = rednet.receive()
     print(commandStaus)
 end
 if(outGoingMessage == "left")then
     id, commandStatus,proto = rednet.receive()
     print(commandStatus)
 end
 if(outGoingMessage == "right")then
     id,commandStatus, protot = rednet.receive()
     print(commandStatus)
 end
 if(outGoingMessage == "forward")then
     id,commandStatus, protot = rednet.receive()
     print(commandStatus)
 end
 if(outGoingMessage == "roomba")then
     id, commandStatus, protot = rednet.receive()
     print(commandStatus)
 end

 if(outGoingMessage == "stop roomba")then
     print("Attempting Execution")
    -- while (true) do
         print("Attempt")
         sleep(.1)
         rednet.send(tonumber(currentId),outGoingMessage)
         a,recept,pr = rednet.receive(.5)
        -- if(a)then
             
            -- break
        -- end
        -- print("no reply")
    -- end
     term.setTextColor(colors.green)
     print(succses)
     term.setTextColor(colors.white)
     
 end
   
 if(outGoingMessage == "exit")then
   continue = false
   
 end
 if(outGoingMessage == "help")then
     term.setBackgroundColor(colors.red)
     print("please type a command below")
     print("EG.(Movement_type Number_of_moves)")
     print("EG.(right 2)")
     print("seperate commands with blank space")
     print("Commands:")
     print("right")
     print("left")
     print("up")
     print("down")
     print("backward")
     print("forward")
     print("Alternate Commands")
     print("change id:changes connection id")
     print("Programs")
     print("Roomba")
     term.setBackgroundColor(colors.black)
 end
end
monitor.setTextScale(1)
print("program over")

