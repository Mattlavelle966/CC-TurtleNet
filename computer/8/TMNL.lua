--TMNL.lua
--turtle movement net logger

TMNL = {}

-- or we return the movement and return it 

function TMNL.Forward()
    -- rather then a string movement could be a color object as the - 
    -- end result on the main server is a color database where different
    -- colors, black is empty space and grey is unknown if   
    movement = ''
    hasMoved = assert(turtle.forward())
    if (hasMoved == true) then
       movement = '#'  
    end
    return movement
end

function TMNL.Back()
    movement = ''
    hasMoved = assert(turtle.back())
    if (hasMoved == true) then
       movement = '#'  
    end
    return movement
end

function TMNL.Up()
    --needs layer system in addition
    movement = ''
    hasMoved = assert(turtle.up())
    if (hasMoved == true) then
       movement = '#'  
    end
    return movement
end

function TMNL.Down()
    --needs layer system in addition
    movement = ''
    hasMoved = assert(turtle.down())
    if (hasMoved == true) then
       movement = '#'  
    end
    return movement
end

function TMNL.TurnLeft()
    --needs facing system in addition
    movement = ''
    hasMoved = assert(turtle.turnLeft())
    if (hasMoved == true) then
       movement = '#'  
    end
    return movement
end

function TMNL.TurnRight()
    --needs facing system in addition
    movement = ''
    hasMoved = assert(turtle.turnRight())
    if (hasMoved == true) then
       movement = '#'  
    end
    return movement
end

function TMNL.Dig(side)
    --needs layer system in addition
    movement = ''
    hasMoved = assert(turtle.dig(side))
    if (hasMoved == true) then
       movement = '#'  
    end
    return movement
end

function TMNL.DigUp()
    --needs layer system in addition
    movement = ''
    hasMoved = assert(turtle.digUp())
    if (hasMoved == true) then
       movement = '#'  
    end
    return movement
end

function TMNL.DigDown()
    --needs layer system in addition
    movement = ''
    hasMoved = assert(turtle.digDown())
    if (hasMoved == true) then
       movement = '#'  
    end
    return movement
end