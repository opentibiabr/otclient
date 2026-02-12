Circle = {}
Circle.__index = Circle

function Circle.new(centerX, centerY, radius)
    local self = setmetatable({}, Circle)
    self._centerX = centerX
    self._centerY = centerY
    self._radius = radius
    return self
end

function Circle:inArea(point)
    local dx = point.x - self._centerX
    local dy = point.y - self._centerY
    return (dx * dx + dy * dy) <= (self._radius * self._radius)
end

function Circle:divideIntoSlices(n)
    local slices = {}
    local angleStep = 2 * math.pi / n

    for i = 0, n - 1 do
        local angle = i * angleStep
        local x = self._centerX + self._radius * math.cos(angle)
        local y = self._centerY + self._radius * math.sin(angle)
        table.insert(slices, {x = x, y = y})
    end

    return slices
end

function Circle:isPointInSlice(point, sliceIndex, totalSlices)
    local angleStep = 2 * math.pi / totalSlices
    local startAngle = sliceIndex * angleStep
    local endAngle = startAngle + angleStep

    local dx = point.x - self._centerX
    local dy = point.y - self._centerY
    local angle = math.atan2(dy, dx)
    if angle < 0 then
        angle = angle + 2 * math.pi -- Normalizes to 0 to 2π
    end

    local distanceSquared = dx * dx + dy * dy
    return angle >= startAngle and angle <= endAngle and distanceSquared <= (self._radius * self._radius)
end

