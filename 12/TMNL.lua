--TMNL.lua
--turtle movement net logger
TMNL = {}
-- max of 55=x and 32=z
--starting coords, make dynamic in future
--CONFIG
TMNL.currentCoordinates = { x = 29, y = 1, z = 18 }
TMNL.SaveObject = { 
    X=TMNL.currentCoordinates.x,
    Z=TMNL.currentCoordinates.z,
    Y=TMNL.currentCoordinates.y,
    Facing=0,
    NetId=0,
    isNew=true
}


TMNL.Packet = {}
TMNL.Queue = {}
TMNL.Facing = 0 -- e.g. relative to starting pos
TMNL.NodeId = 0
-- 0=north, 1=west, 2=south, 3=east
-- or we return the movement and return it 
-- reset Packet every day cycle
function TMNL.TurtleInit()
    for i = 1, 4, 1 do
        turtle.turnLeft()
    end
end
function CheckFirstLoad()
    if TMNL.SaveObject.isNew == true then
        local invalid = true
        while invalid do
            print("Please Enter a Starting X Position: ")
            local userX = tonumber(read())
            print("Please Enter a Starting Y Position: ")
            local userY = tonumber(read())
            print("Please Enter a Starting Z Position: ")
            local userZ = tonumber(read())
            print("Please Enter a Starting Facing Position: ")
            local userFacing = tonumber(read())
            print("Please Enter a Node Id(Must be unique and indexed to other nodes): ")
            local userNodeId = tonumber(read())

            local validityX = userX and math.floor(userX) == userX
            local validityY = userY and math.floor(userY) == userY
            local validityZ = userZ and math.floor(userZ) == userZ
            local FacingValidity = userFacing and math.floor(userFacing) == userFacing
            local NodeValidity = userNodeId and math.floor(userNodeId) == userNodeId

            local group = {validityX, validityZ, validityY, NodeValidity, FacingValidity}
            local valid = false
            for i = 1, #group , 1 do
                if(group[i] == false)then
                    valid = false
                    print("problem:" .. tostring(i))
                    break
                elseif(i+1 == #group and group[i+1] ~= false)then
                    valid = true
                end 
            end

            if (valid) then
                print("Confirmed")
                TMNL.SaveObject.Facing = userFacing
                TMNL.SaveObject.NetId = userNodeId
                TMNL.SaveObject.X = userX
                TMNL.SaveObject.Z = userZ
                TMNL.SaveObject.Y = userY
                invalid = false

            else 
                print()
                print("One of the values was invalid.")
            end
        end
    end
end

function TMNL.SaveToDB()
    TMNL.SaveObject.Facing = TMNL.Facing
    TMNL.SaveObject.isNew = false
    TMNL.SaveObject.NetId = TMNL.NodeId
    TMNL.SaveObject.X = TMNL.currentCoordinates.x
    TMNL.SaveObject.Z = TMNL.currentCoordinates.z
    TMNL.SaveObject.Y = TMNL.currentCoordinates.y
    file = fs.open("TMNLSaveDB.txt", "w")
    file.write(textutils.serialize(TMNL.SaveObject))
    file.close()
end

function TMNL.GetSavedDB()
  local exist = fs.exists("TMNLSaveDB.txt")
  if (exist)then
      file = fs.open("TMNLSaveDB.txt", "r")
      local content = file.readAll()
      pack = textutils.unserialize(content)
      TMNL.SaveObject = pack
      print("Saved DB Imported")
  else
      print("No Saved DB available")
  end
end

function TMNL.Forward()
    -- rather then a string movement could be a color object as the - 
    -- end result on the main server is a color database where different
    -- colors, black is empty space and grey is unknown if
    local returnData = {}
    turtle.refuel(1)   
    hasMoved,str = turtle.forward()
    if (hasMoved == true) then
        if TMNL.Facing == 0 then
            --coordinate { -1, 0, 0 }
            TMNL.currentCoordinates.x = TMNL.currentCoordinates.x - 1
        elseif TMNL.Facing == 1 then
            TMNL.currentCoordinates.z = TMNL.currentCoordinates.z - 1
        elseif TMNL.Facing == 2 then
            TMNL.currentCoordinates.x = TMNL.currentCoordinates.x + 1
        elseif TMNL.Facing == 3 then
            TMNL.currentCoordinates.z = TMNL.currentCoordinates.z + 1
        end

        --return TMNL.Packet for all changes ever
        table.insert(TMNL.Packet, {
            x = TMNL.currentCoordinates.x,
            y = TMNL.currentCoordinates.y,
            z = TMNL.currentCoordinates.z,
            turtleId = os.computerID(),
            timestamp = os.time("local")
            })
        table.insert(TMNL.Queue, {
        x = TMNL.currentCoordinates.x,
        y = TMNL.currentCoordinates.y,
        z = TMNL.currentCoordinates.z,
        turtleId = os.computerID(),
        timestamp = os.time("local")
        })
    else
        print(tostring(hasMoved) .. str)        
    end
    table.insert(returnData,{Result = hasMoved, event=str })
    return returnData
end

function TMNL.Back()
    local returnData = {}
    turtle.refuel(1)
    hasMoved,str = turtle.back()
    if (hasMoved == true) then
       if TMNL.Facing == 0 then
            TMNL.currentCoordinates.x = TMNL.currentCoordinates.x + 1
        elseif TMNL.Facing == 1 then
            TMNL.currentCoordinates.z = TMNL.currentCoordinates.z + 1
        elseif TMNL.Facing == 2 then
            TMNL.currentCoordinates.x = TMNL.currentCoordinates.x - 1
        elseif TMNL.Facing == 3 then
            TMNL.currentCoordinates.z = TMNL.currentCoordinates.z - 1
        end
        table.insert(TMNL.Packet, {
            x = TMNL.currentCoordinates.x,
            y = TMNL.currentCoordinates.y,
            z = TMNL.currentCoordinates.z,
            turtleId = os.computerID(),
            timestamp = os.time("local")
        })
        table.insert(TMNL.Queue, {
        x = TMNL.currentCoordinates.x,
        y = TMNL.currentCoordinates.y,
        z = TMNL.currentCoordinates.z,
        turtleId = os.computerID(),
        timestamp = os.time("local")
        })
        
    else
        print(tostring(hasMoved) .. str)        
    end
    table.insert(returnData,{Result = hasMoved, event=str })
    return returnData
end

function TMNL.Up()
    --needs layer system in addition
    turtle.refuel(1)
    hasMoved = turtle.up()
    if (hasMoved == true) then
        TMNL.currentCoordinates.y = TMNL.currentCoordinates.y + 1 
        table.insert(TMNL.Packet, {
            x = TMNL.currentCoordinates.x,
            y = TMNL.currentCoordinates.y,
            z = TMNL.currentCoordinates.z,
            turtleId = os.computerID(),
            timestamp = os.time("local")
        })
        table.insert(TMNL.Queue, {
        x = TMNL.currentCoordinates.x,
        y = TMNL.currentCoordinates.y,
        z = TMNL.currentCoordinates.z,
        turtleId = os.computerID(),
        timestamp = os.time("local")
        })
    end
end

function TMNL.Down()
    --needs layer system in addition
    turtle.refuel(1)
    hasMoved = turtle.down()
    if (hasMoved == true) then
       TMNL.currentCoordinates.y = TMNL.currentCoordinates.y - 1 
        table.insert(TMNL.Packet, {
            x = TMNL.currentCoordinates.x,
            y = TMNL.currentCoordinates.y,
            z = TMNL.currentCoordinates.z,
            turtleId = os.computerID(),
            timestamp = os.time("local")
        })
        table.insert(TMNL.Queue, {
        x = TMNL.currentCoordinates.x,
        y = TMNL.currentCoordinates.y,
        z = TMNL.currentCoordinates.z,
        turtleId = os.computerID(),
        timestamp = os.time("local")
        })
    end
end

function TMNL.TurnLeft()
    --needs facing system in addition
    hasMoved = turtle.turnLeft()
    if (hasMoved == true) then
        TMNL.Facing = (TMNL.Facing - 1) % 4
        if TMNL.Facing < 0 then
            TMNL.Facing = TMNL.Facing + 4
        end
    end
end

function TMNL.TurnRight()
    --needs facing system in addition
    hasMoved = turtle.turnRight()
    if (hasMoved == true) then
        TMNL.Facing = (TMNL.Facing + 1) % 4
    end
end