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
