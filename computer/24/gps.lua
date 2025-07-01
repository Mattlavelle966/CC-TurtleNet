require "vector_lib"

local function square(n) return n * n end

function det3x3(m)
    return m[1][1] * (m[2][2]*m[3][3] - m[2][3]*m[3][2])
         - m[1][2] * (m[2][1]*m[3][3] - m[2][3]*m[3][1])
         + m[1][3] * (m[2][1]*m[3][2] - m[2][2]*m[3][1])
end

local function calculateCoordinates (pointData)
    local x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4
    local da, db, dc, dd --d standing for distance
    for point = 1, 4 do
    local p = pointData[point]
    print(("Point #%d: X=%s Y=%s Z=%s (Distance: %s)"):
    format(point, p.loadingVector.x, p.loadingVector.y, p.loadingVector.z, p.distance))
    end

    -- coordinates
    x1 = pointData[1].loadingVector.x
    y1 = pointData[1].loadingVector.y
    z1 = pointData[1].loadingVector.z
    x2 = pointData[2].loadingVector.x
    y2 = pointData[2].loadingVector.y
    z2 = pointData[2].loadingVector.z
    x3 = pointData[3].loadingVector.x
    y3 = pointData[3].loadingVector.y
    z3 = pointData[3].loadingVector.z
    x4 = pointData[4].loadingVector.x
    y4 = pointData[4].loadingVector.y
    z4 = pointData[4].loadingVector.z

    -- distance
    da = pointData[1].distance
    db = pointData[2].distance
    dc = pointData[3].distance
    dd = pointData[4].distance

    -- breaking down to a linear equation
    
    local A = 2*(x1 - x2)
    local B = 2*(y1 - y2)
    local C = 2*(z1 - z2)
    local D = square(da) - square(db) + square(x2) - square(x1) + square(y2) - square(y1) + square(z2) - square(z1)

    local E = 2*(x1 - x3)
    local F = 2*(y1 - y3)
    local G = 2*(z1 - z3)
    local H = square(da) - square(dc) + square(x3) - square(x1) + square(y3) - square(y1) + square(z3) - square(z1)

    local I = 2*(x1 - x4)
    local J = 2*(y1 - y4)
    local K = 2*(z1 - z4)
    -- =
    local L = square(da) - square(dd) + square(x4) - square(x1) + square(y4) - square(y1) + square(z4) - square(z1)
    -- A*x + B*y + C*z = D
    -- E*x + F*y + G*z = H
    -- I*x + J*y + K*z = L

    local M = 
    {
        {A, B, C},
        {E, F, G},
        {I, J, K}
    }

    local Mx = 
    {
        {D, B, C},
        {H, F, G},
        {L, J, K}
    }
    
    local My = 
    {
        {A, D, C},
        {E, H, G},
        {I, L, K}
    }
    
    local Mz =
    {
        {A, B, D},
        {E, F, H},
        {I, J, L}
    }

    local MDeterminant = det3x3(M)
    local MxDeterminant = det3x3(Mx)
    local MyDeterminant = det3x3(My)
    local MZDeterminant = det3x3(Mz)
    local x, y, z

    x = MxDeterminant / MDeterminant
    y = MyDeterminant / MDeterminant
    z = MZDeterminant / MDeterminant

    -- negative because minecraft coordinates are using
    -- left hand orientation
    local coordinates = Vec3.new(-x, -y, -z)
    -- Ax + By + Cz = D
    -- Ex + Fy + Gz = H
    -- Ix + Jy + Kz = L
    
    -- OR 
    -- (this is a 3x3 determinant)
    -- a1 b1 c1
    -- a2 b2 c2
    -- a3 b3 c3

    -- to get a1
    -- comman denoting a new line

    -- trying to eliminate row 1 column 1 to be left with []

    -- {a1} |b1| |c1|
    -- |a2| [b2] [c2]
    -- |a3| [b3] [c3]

    --determinate of a 2x2 matrix
    -- a1[b2 c2, b3 c3]

    -- |a1| {b1} |c1|
    -- [a2] |b2| [c2]
    -- [a3] |b3| [c3]

    -- a1[b2 c2, b3 c3] - b1[a2 c2, a3 c3]

    -- |a1| |b1| {c1}
    -- [a2] [b2] |c2|
    -- [a3] [b3] |c3|

    -- a1[b2 c2, b3 c3] - b1[a2 c2, a3 c3] + c1[a2 b2, a3 b3]

    -- That's how you evaluate a 3x3 determinant

    return coordinates
end


local modem = peripheral.find("modem") or error("No modem attached")
modem.open(101)

while true do
    local pointData = {}
    local channel, distance

    local relayPoints = 0
    while (relayPoints < 4) do
        print("Waiting for Pylons...")
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        print("data received")

        if channel == 101 then
            local data = textutils.unserializeJSON(message)
            print("Received data from pylon")
            print("Distance:", data.distance)
            print(("Loading Pylon Vector3: X=%s Y=%s Z=%s"):format(data.coords.x, data.coords.y, data.coords.z))
            relayPoints = relayPoints + 1
            local loadingVector = Vec3.new(data.coords.x, data.coords.y, data.coords.z)
            local point = { 
                loadingVector = loadingVector,
                distance = data.distance
            }

            table.insert(pointData, relayPoints, point)
        end
    end

    local coordinates = calculateCoordinates(pointData)

    coordinates = Vec3.new(coordinates.x, coordinates.y, coordinates.z)
    modem.transmit(15, 101, textutils.serializeJSON(coordinates))
end