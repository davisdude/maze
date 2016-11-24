local feeler = {}

-- id and map allow feelers to interact
function feeler.new( x, y, id, map )
	local self = setmetatable( {
		x = x,
		y = y,
		id = id,
		map = map,
		path = {},
	}, { __index = feeler } )
	map[y][x].id = id
	return self
end

local function getSurroundingCells( map, x, y, self )
	local upPossible = map[y - 1]
	local downPossible = map[y + 1]
	local leftPossible = map[y][x - 1]
	local rightPossible = map[y][x + 1]

	local surrounding = {}
	if upPossible then table.insert( surrounding, { x, y - 1 } ) end
	if downPossible then table.insert( surrounding, { x, y + 1 } ) end
	if leftPossible then table.insert( surrounding, { x - 1, y } ) end
	if rightPossible then table.insert( surrounding, { x + 1, y } ) end

	return surrounding
end

-- cells: { { x, y }, ... }
local function getUnoccupiedCells( map, cells )
	local unoccupied = {}
	for i = 1, #cells do
		local cell = cells[i]
		if map[cell[2]][cell[1]].value == '' then table.insert( unoccupied, cells[i] ) end
	end
	return unoccupied
end

-- Assumes only NESW directions; no diagonals
-- r = right, l = left, t = top, b = bottom
function getTravelDirection( fromX, fromY, toX, toY )
	if fromX > toX then return 'l'
	elseif fromX < toX then return 'r'
	elseif fromY > toY then return 't'
	elseif fromY < toY then return 'b' end
end

function getOppositeDirection( direction )
	if direction == 'r' then return 'l'
	elseif direction == 'l' then return 'r'
	elseif direction == 't' then return 'b'
	elseif direction == 'b' then return 't' end
end

function addDirectionToCell( map, x, y, direction )
	local cell = map[y][x]
	local pos = 0
	for i = 1, #cell.value do
		local val = cell.value:sub( i, i ) 

		-- Prevent errors caused by tiles being removed mid-update
		if val == direction then
			direction = ''
			break
		elseif val < direction then
			pos = i
		end
	end
	return cell.value:sub( 0, pos ) .. direction .. cell.value:sub( pos + 1 )
end

local function removeWall( map, x, y, direction )
	map[y][x].value = addDirectionToCell( map, x, y, direction )
end

function feeler:removeWalls( futureX, futureY, x, y )
	x = x or self.x
	y = y or self.y
	local direction = getTravelDirection( x, y, futureX, futureY )
	local opposite = getOppositeDirection( direction )
	-- print( direction, opposite )
	removeWall( self.map, x, y, direction )
	removeWall( self.map, futureX, futureY, opposite )
	-- print()
end

local function travelTo( self, future )
	local futureX, futureY = unpack( future )
	self:removeWalls( futureX, futureY )
	table.insert( self.path, { self.x, self.y } )
	self.map[futureY][futureX].id = self.id
	self.x, self.y = futureX, futureY
end

local function backtrack( self )
	local len = #self.path
	if len > 0 then
		local last = self.path[len]
		self.x, self.y = last[1], last[2]
		self.path[len] = nil
		return true
	else
		return false
	end
end

function feeler:step()
	local surrounding = getSurroundingCells( self.map, self.x, self.y, self )
	local unoccupied = getUnoccupiedCells( self.map, surrounding )
	if #unoccupied > 0 then
		local random = love.math.random( 1, #unoccupied )
		local future = unoccupied[random]
		-- print( self.x, self.y, '|', unpack( future ) )
		travelTo( self, future )
		return true
	else
		return backtrack( self )
	end
end

return setmetatable( feeler, { __call = function( _, ... ) return feeler.new( ... ) end } )
