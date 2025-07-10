--TMNL.lua
--turtle movement net logger
TMNL = {}
-- max of 55=x and 32=z
--starting coords, make dynamic in future
--CONFIG
TMNL.currentCoordinates = { x = 29, y = 1, z = 24 }


TMNL.Packet = {}
TMNL.Queue = {}
TMNL.Facing = 0 -- e.g. relative to starting pos
-- 0=north, 1=west, 2=south, 3=east
-- or we return the movement and return it 
-- reset Packet every day cycle
function TMNL.TurtleInit()
    for i = 1, 4, 1 do
        turtle.turnLeft()
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