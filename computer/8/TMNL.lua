--TMNL.lua
--turtle movement net logger
TMNL = {}


local currentCoordinates = { x = 0, y = 0, z = 0 }

TMNL.Packet = {}
--starting location
TMNL.startingCoords = {x = 0, y = 0, z = 0} 
TMNL.Facing = 0 -- e.g. relative to starting pos
-- 0=forward, 1=right, 2=back, 3=left
-- or we return the movement and return it 
-- reset Packet every day cycle


function TMNL.Forward()
    -- rather then a string movement could be a color object as the - 
    -- end result on the main server is a color database where different
    -- colors, black is empty space and grey is unknown if   
    hasMoved = assert(turtle.forward())
    if (hasMoved == true) then
        if TMNL.Facing == 0 then
            --coordinate { -1, 0, 0 }
            currentCoordinates.x = currentCoordinates.x - 1
        elseif TMNL.Facing == 1 then
            currentCoordinates.z = currentCoordinates.z + 1
        elseif TMNL.Facing == 2 then
            currentCoordinates.x = currentCoordinates.x + 1
        elseif TMNL.Facing == 3 then
            currentCoordinates.z = currentCoordinates.z - 1
        end
        table.insert(TMNL.Packet, {
            x = currentCoordinates.x,
            y = currentCoordinates.y,
            z = currentCoordinates.z,
            timestamp = os.date("!%c")
            })
        print(textutils.serialize(TMNL.Packet))
    end
end

function TMNL.Back()
    hasMoved = assert(turtle.back())
    if (hasMoved == true) then
       if TMNL.Facing == 0 then
            currentCoordinates.x = currentCoordinates.x + 1
        elseif TMNL.Facing == 1 then
            currentCoordinates.z = currentCoordinates.z - 1
        elseif TMNL.Facing == 2 then
            currentCoordinates.x = currentCoordinates.x - 1
        elseif TMNL.Facing == 3 then
            currentCoordinates.z = currentCoordinates.z + 1
        end
        table.insert(TMNL.Packet, {
            x = currentCoordinates.x,
            y = currentCoordinates.y,
            z = currentCoordinates.z,
            timestamp = os.date("!%c")
        })
        print(textutils.serialize(TMNL.Packet))
    end
end

function TMNL.Up()
    --needs layer system in addition
    hasMoved = assert(turtle.up())
    if (hasMoved == true) then
        currentCoordinates.y = currentCoordinates.y + 1 
        table.insert(TMNL.Packet, {
            x = currentCoordinates.x,
            y = currentCoordinates.y,
            z = currentCoordinates.z,
            timestamp = os.date("!%c")
        })  
    end
end

function TMNL.Down()
    --needs layer system in addition
    hasMoved = assert(turtle.down())
    if (hasMoved == true) then
       currentCoordinates.y = currentCoordinates.y - 1 
        table.insert(TMNL.Packet, {
            x = currentCoordinates.x,
            y = currentCoordinates.y,
            z = currentCoordinates.z,
            timestamp = os.date("!%c")
        })  
    end
end

function TMNL.TurnLeft()
    --needs facing system in addition
    hasMoved = assert(turtle.turnLeft())
    if (hasMoved == true) then
        TMNL.Facing = (TMNL.Facing - 1) % 4
        if TMNL.Facing < 0 then
            TMNL.Facing = TMNL.Facing + 4
        end
    end
end

function TMNL.TurnRight()
    --needs facing system in addition
    hasMoved = assert(turtle.turnRight())
    if (hasMoved == true) then
        TMNL.Facing = (TMNL.Facing + 1) % 4
    end
end