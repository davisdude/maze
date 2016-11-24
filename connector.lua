local connector = {
	maps = {},
}

function connector.newConnector( map, ... )
	local indices = { ... }
	connector.maps[map] = { map = map, indices = indices, connections = {} }

	local c = connector.maps[map]
	for i = 1, #indices do
		-- points is stored in such a way that it is easier to prevent duplicate points.
		-- allConnections is stored so that selecting random walls is easier.
		-- Both contain the same connection information, just in different ways.
		c.connections[i] = { points = {}, allConnections = {}, indices = {}, _previousPathLength = 0, _indicesLength = 0 }
		-- Have an easy way to get the number of connections each index has.
		setmetatable( c.connections[i].indices, { __newindex = function( _, index, value )
			if c.connections[i].indices[index] == nil then
				c.connections[i]._indicesLength = c.connections[i]._indicesLength + 1
			end
			rawset( c.connections[i].indices, index, value )
		end } )

		for ii = 1, #indices do
			if i ~= ii then
				c.connections[i].allConnections[ii] = {}
			end
		end
	end
	return setmetatable( c, { __index = connector } )
end

local function getIndex( map, x, y, moveX, moveY )
	if map[moveY] and map[moveY][moveX] then
		return map[moveY][moveX].id
	end
end

local function preventDuplicatePoints( self, index, x, y, moveIndex, moveX, moveY )
	local points = self.connections[index].points
	-- Use coordinates for index to make it faster to find duplicates
	-- (going through list of <= 3 numbers is faster than going through many)
	local current = points[x .. ',' .. y]
	local pass = false
	if current then
		pass = true
		for i = 1, #current, 3 do
			if current[i] == moveIndex and current[i + 1] == moveX and current[i + 2] == moveY then
				pass = false
				break
			end
		end
		if pass then
			current[#current + 1] = moveIndex
			current[#current + 1] = moveX
			current[#current + 1] = moveY
		end
	else
		-- Stored as flat array
		-- x and y information not needed since it's contained in index
		points[x .. ',' .. y] = { moveIndex, moveX, moveY }
		pass = true
	end

	if pass then
		-- Done this way for feeler:removeWall
		table.insert( self.connections[index].allConnections[moveIndex], { moveX, moveY, x, y } )
		self.connections[index].indices[moveIndex] = true
	end
end

local function checkIndex( self, index, x, y, moveX, moveY )
	local moveIndex = getIndex( self.map, x, y, moveX, moveY )
	if moveIndex and moveIndex ~= '' and moveIndex ~= index then
		preventDuplicatePoints( self, index, x, y, moveIndex, moveX, moveY )
		preventDuplicatePoints( self, moveIndex, moveX, moveY, index, x, y )
	end
end

function connector:update()
	for i = 1, #self.indices do
		local index = self.connections[i]
		-- Prevent doing a cell for the same index twice (backtracking)
		if index._previousPathLength < #self.indices[i].path then
			local x, y = self.indices[i].x, self.indices[i].y
			local differentIndices = {}
			checkIndex( self, i, x, y, x, y - 1 )
			checkIndex( self, i, x, y, x, y + 1 )
			checkIndex( self, i, x, y, x - 1, y )
			checkIndex( self, i, x, y, x + 1, y )
		end
		index._previousPathLength = #self.indices[i].path
	end
end

local function getMinimumConnections( connections )
	local indicesCopy = {}
	local sorted = { connections[1]._indicesLength }
	-- Intentionally skips 1 since it's the starting point
	for i = 2, #connections do
		indicesCopy[i] = connections[i]._indicesLength
		table.insert( sorted, connections[i]._indicesLength )
	end
	table.sort( sorted, function( a, b )
		return a > b
	end )

	-- Use Prim's algorithm to compute the minimum spanning tree
	-- Unlike Prim's, the greatest weight (number of connections) is selected
	local visited = { 1 }
	local paths = {}
	-- If a removal is tried before all mazes are connected, prevent any infinite loops
	while not ( ( #sorted == 0 ) or ( sorted[1] == 0 ) ) do
		local chosenIndex, maxLength, maxIndex = 0, 0, 0
		for I = 1, #visited do
			local i = visited[I]
			for ii in pairs( connections[i].indices ) do
				local length = indicesCopy[ii]
				if length == sorted[1] then
					chosenIndex, maxLength, maxIndex = i, length, ii
					break
				end
			end
		end
		if maxIndex ~= 0 then
			table.insert( visited, maxIndex )
			table.insert( paths, { chosenIndex, maxIndex } )
			table.remove( sorted, 1 )
			indicesCopy[maxIndex] = nil
		else
			table.remove( sorted, 1 )
		end
	end

	return paths
end

local function factorial( n )
	local product = 1
	for i = 2, n do
		product = product * n
	end
	return product
end

local function getRemovalIndices( self )
	local connections = {}

	local minimumRemovals = getMinimumConnections( self.connections )
	local min = #minimumRemovals

	for i = 1, min do
		-- Need at least the minimum to guarantee connectedness
		table.insert( connections, minimumRemovals[i] )
	end

	return connections
end

local donut = { 'b.*r', 'rt', 'l.*t', 'bl' }
local blank = {}

local function checkDonut( values )
	local pass = #values > 0 and true or false
	for i = 1, #values do
		if ( not values[i] ) or ( not values[i]:match( donut[i] ) ) then
			pass = false
			break
		end
	end
	return pass
end

local function makesDonut( map, removeX, removeY, startX, startY )
	local direction = getTravelDirection( startX, startY, removeX, removeY )
	local startValue = addDirectionToCell( map, startX, startY, direction )
	local removeValue = addDirectionToCell( map, removeX, removeY, getOppositeDirection( direction ) )

	local pass = true
	if direction:match( '[tb]' ) then
		-- Values in cells aren't updated until next move; need way to update start/end cells to reflect change
		if startY > removeY then
			startY, removeY = removeY, startY
			startValue, removeValue = removeValue, startValue
		end
		local left = { ( map[startY][startX - 1] or blank ).value, ( map[removeY][removeX - 1]  or blank ).value, removeValue, startValue }
		local right = { startValue, removeValue, ( map[removeY][removeX + 1] or blank ).value, ( map[startY][startX + 1] or blank ).value }

		pass = checkDonut( left ) or checkDonut( right )
	else -- direction:match( '[lr]' )
		if startX > removeX then
			startX, removeX = removeX, startX
			startValue, removeValue = removeValue, startValue
		end

		local canGoUp = map[startY - 1]
		local canGoDown = map[startY + 1]
		local up = canGoUp and { map[startY - 1][startX].value, startValue, removeValue, map[removeY - 1][removeX].value } or blank
		local down = canGoDown and { startValue, map[startY + 1][startX].value, map[removeY + 1][removeX].value, removeValue } or blank

		pass = checkDonut( up ) or checkDonut( down )
	end

	return pass
end

-- Connectivity is a number 0-1 indicating how connected the map should be
-- 0 (default) = minimum
-- ... = lerp between min and max
-- 1 = max
function connector:connect()
	local indices = getRemovalIndices( self )

	for i = 1, #indices do
		local i1, i2 = unpack( indices[i] )
		local allPointsInCommon = self.connections[i1].allConnections[i2]
		local pointIndex = love.math.random( 1, #allPointsInCommon )

		-- To avoid "donuts," walls where any of the cells in a specific direction have that removal cannot be removed
		-- e.g. No cells above/below can have a right wall removal, but to the left/right can.
		local donut = makesDonut( self.map, unpack( allPointsInCommon[pointIndex] ) )

		if not donut then
			self.indices[i1]:removeWalls( unpack( allPointsInCommon[pointIndex] ) )
		else
			table.remove( allPointsInCommon, pointIndex )
		end
	end
end

return setmetatable( connector, { __call = function( _, ... ) return connector.newConnector( ... ) end } )
