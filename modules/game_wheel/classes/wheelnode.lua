WheelNode = {}
WheelNode._index = WheelNode

function WheelNode:new()
    local instance = {
        connecteds = {},
        connections = {}
    }
    setmetatable(instance, WheelNode)
    return instance
end

WheelNodes = {}

for i = 1, 36 do
    WheelNodes[i] = WheelNode:new()
end

-- Green Connections
-- 1 - 50
WheelNodes[15].connections = {14, 9}
-- 2 - 75
WheelNodes[9].connections = {14, 10, 3, 8}
WheelNodes[14].connections = {9, 20, 13, 8}
-- 3 - 100
WheelNodes[13].connections = {8, 14, 19, 7}
WheelNodes[8].connections = {14, 9, 13, 3, 7, 2}
WheelNodes[3].connections = {8, 9, 4, 2}
-- 4 - 150
WheelNodes[2].connections = {3, 8, 7, 1}
WheelNodes[7].connections = {8, 13, 2, 1}
-- 5 - 200
WheelNodes[1].connections = {}
-- Green Connected
-- 1 - 50
WheelNodes[15].connecteds = {}
-- 2 - 75
WheelNodes[9].connecteds = {14, 15, 10, 3, 8}
WheelNodes[14].connecteds = {9, 15, 20, 13, 8}
-- 3 - 100
WheelNodes[13].connecteds = {8, 14, 19, 7}
WheelNodes[8].connecteds = {14, 9, 13, 3, 7, 2}
WheelNodes[3].connecteds = {8, 9, 4, 2}
-- 4 - 150
WheelNodes[2].connecteds = {3, 8, 7, 1}
WheelNodes[7].connecteds = {8, 13, 2, 1}
-- 5 - 200
WheelNodes[1].connecteds = {2, 7}


-- Red Connections
-- 1 - 50
WheelNodes[16].connections = {17, 10}
-- 2 - 75
WheelNodes[17].connections = {10, 23, 18, 11}
WheelNodes[10].connections = {9, 17, 4, 11}
-- 3 - 100
WheelNodes[4].connections = {3, 10, 11, 5}
WheelNodes[11].connections = {10, 17, 4, 18, 5, 12}
WheelNodes[18].connections = {17, 11, 24, 12}
-- 4 - 150
WheelNodes[12].connections = {11, 18, 5, 6}
WheelNodes[5].connections = {4, 11, 12, 6}
-- 5 - 200
WheelNodes[6].connections = {}
-- Red Connected
-- 1 - 50
WheelNodes[16].connecteds = {}
-- 2 - 75
WheelNodes[17].connecteds = {10, 16, 23, 18, 11}
WheelNodes[10].connecteds = {9, 16, 17, 4, 11}
-- 3 - 100
WheelNodes[4].connecteds = {3, 10, 11, 5}
WheelNodes[11].connecteds = {10, 17, 4, 18, 5, 12}
WheelNodes[18].connecteds = {17, 11, 24, 12}
-- 4 - 150
WheelNodes[12].connecteds = {11, 18, 5, 6}
WheelNodes[5].connecteds = {4, 11, 12, 6}
-- 5 - 200
WheelNodes[6].connecteds = {12, 5}


-- Purple Connections
-- 1 - 50
WheelNodes[22].connections = {23, 28}
-- 2 - 75
WheelNodes[23].connections = {28, 17, 24, 29}
WheelNodes[28].connections = {23, 27, 29, 34}
-- 3 - 100
WheelNodes[24].connections = {23, 18, 29, 30}
WheelNodes[29].connections = {23, 28, 24, 34, 30, 35}
WheelNodes[34].connections = {28, 33, 29, 35}
-- 4 - 150
WheelNodes[30].connections = {24, 29,35, 36}
WheelNodes[35].connections = {29, 34, 30, 36}
-- 5 - 200
WheelNodes[36].connections = {}
-- Purple Connected
-- 1 - 50
WheelNodes[22].connecteds = {}
-- 2 - 75
WheelNodes[23].connecteds = {22, 28, 17, 24, 29}
WheelNodes[28].connecteds = {22, 23, 27, 29, 34}
-- 3 - 100
WheelNodes[24].connecteds = {23, 18, 29, 30}
WheelNodes[29].connecteds = {23, 28, 24, 34, 30, 35}
WheelNodes[34].connecteds = {28, 33, 29, 35}
-- 4 - 150
WheelNodes[30].connecteds = {24, 29,35, 36}
WheelNodes[35].connecteds = {29, 34, 30, 36}
-- 5 - 200
WheelNodes[36].connecteds = {30, 35}

-- Blue Connections
-- 1 - 50
WheelNodes[21].connections = {20, 27}
-- 2 - 75
WheelNodes[20].connections = {14, 27, 19, 26}
WheelNodes[27].connections = {28, 20, 26, 33}
-- 3 - 100
WheelNodes[19].connections = {13, 20, 26, 25}
WheelNodes[26].connections = {27, 20, 19, 25, 32, 33}
WheelNodes[33].connections = {27, 34, 26, 32}
-- 4 - 150
WheelNodes[25].connections = {19, 26, 32, 31}
WheelNodes[32].connections = {26, 25, 33, 31}
-- 5 - 200
WheelNodes[31].connections = {}
-- Blue Connected
-- 1 - 50
WheelNodes[21].connecteds = {}
-- 2 - 75
WheelNodes[20].connecteds = {21, 14, 27, 19, 26}
WheelNodes[27].connecteds = {21, 28, 20, 26, 33}
-- 3 - 100
WheelNodes[19].connecteds = {13, 20, 26, 25}
WheelNodes[26].connecteds = {27, 20, 19, 25, 32, 33}
WheelNodes[33].connecteds = {27, 34, 26, 32}
-- 4 - 150
WheelNodes[25].connecteds = {19, 26, 32, 31}
WheelNodes[32].connecteds = {26, 25, 33, 31}
-- 5 - 200
WheelNodes[31].connecteds = {25, 32}

function canReachRootNodeFromNode(node, ignoreNode)
    local nodesToVisit = {node}
    local visitedNodes = {}
    local roots = {
        [15] = true,
        [16] = true,
        [21] = true,
        [22] = true
    }

    while #nodesToVisit > 0 do
        local currentNodeId = nodesToVisit[1]
        table.remove(nodesToVisit, 1)
        local currentNode = WheelNodes[currentNodeId]

        if roots[currentNodeId] then
            return true
        end

        for _, connectedNode in ipairs(currentNode.connecteds) do
            if not visitedNodes[connectedNode] and WheelOfDestiny.isLitFull(connectedNode) and connectedNode ~= ignoreNode then
                table.insert(nodesToVisit, connectedNode)
            end
        end

        visitedNodes[currentNodeId] = true
    end

    return false
end
