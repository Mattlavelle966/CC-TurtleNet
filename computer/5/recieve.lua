--BackUpFile
require "roomba"

local GlobalInputOne = ""
local GloabalInputTwo = ""

function asignVals(valueSTR)
    GlobalInputOne = ""
    GlobalInputOne = ""
    firstVal = ""
    secondVal = ""
    emptySpace = false
    for i = 1, #valueSTR do
        local currentChar = valueSTR:sub(i,i)
        if(currentChar == " ")then
            secondVal = secondVal .. valueSTR:sub(i+1,i+1)
            secondVal = secondVal .. valueSTR:sub(i+2,i+2)
            emptySpace = true
        elseif(emptySpace == false)then
            firstVal = firstVal .. currentChar
        end
            
    end
    GlobalInputOne = firstVal
    GlobalInputTwo = secondVal

end
--asignVals("forward 1")
--print(GlobalInputOne)
--print(GlobalInputTwo)
--asignVals("down 2")
--print(GlobalInputOne)
--print(GlobalInputTwo)
--TestCode 
rednet.close()
rednet.open("left")
turtle.refuel(1)

while (true) do
  print("listening")
  a,message,b = rednet.receive()
  print(message.." extra:")
  print(b)
  print("PCID: "..a)
  asignVals(message)
  rednet.broadcast("i am receving you")
  
  --input conditions below
  if(GlobalInputOne == "up") then
      print("below")
      print(GlobalInputTwo)
      rednet.broadcast("moving up")
      for i = 1, tonumber(GlobalInputTwo) do  
          turtle.refuel(1)
          turtle.up()
      end 
      --MUST ADD FOR LOOP TO OTHER IF 
      --STATEMENTS
  end
  if(GlobalInputOne == "down")then
      rednet.broadcast("moving down")
      for i = 1, tonumber(GlobalInputTwo) do
          turtle.refuel(1)
          turtle.down()
      end
      
  end
  if(GlobalInputOne == "right")then
      rednet.broadcast("moving right")
      turtle.turnRight()
      for i = 1, tonumber(GlobalInputTwo) do
          turtle.refuel(1)
          turtle.forward()
      
      end
  end
  if(GlobalInputOne == "left")then
      rednet.broadcast("moving left")
      turtle.turnLeft()
      for i = 1, tonumber(GlobalInputTwo) do
          turtle.refuel(1)
          turtle.forward()
      end
  end
  if(GlobalInputOne == "forward")then
      rednet.broadcast("moving forward")
      for i = 1, tonumber(GlobalInputTwo) do
      
          turtle.refuel(1)
          turtle.forward()
      end
  end
  if(GlobalInputOne == "backward")then
      turtle.turnLeft()
      turtle.turnLeft()
      rednet.broadcast("moving backward")
      
      for i = 1, tonumber(GlobalInputTwo) do
          turtle.refuel(1)
          turtle.forward()
      end
  end
  if(GlobalInputOne == "roomba")then
      rednet.broadcast("Starting the Roomba Prog")
      roomba()
  end

end
