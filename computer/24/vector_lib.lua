Vec3 = {}
Vec3.__index = Vec3

function Vec3.new(x, y, z)
    return setmetatable({ x = x, y = y, z = z}, Vec3)
end

-- used to get angle between vectors
function Vec3.dot(other)
    return self.x * other.x + self.y * other.y + self..z * other.z
end

