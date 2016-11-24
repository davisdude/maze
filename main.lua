local Feeler = require 'feeler'
local Connector = require 'connector'
require 'autobatch'

local cellWidth, cellHeight = 10, 10
local screenWidth, screenHeight = love.graphics.getDimensions()
local cellsWide, cellsHigh = screenWidth / cellWidth, screenHeight / cellHeight
local map, drawMap, scaleX, scaleY, quadWidth, quadHeight
local DEBUG = true
-- The path coloring debug option uses images to take advantage of autobatch
-- Before: 15-60 FPS; After: 60 (steady)
local indicesImage, colors
local done

local function debug( self, cellWidth, cellHeight )
	love.graphics.draw( indicesImage, colors[self.id], ( self.x - 1 ) * cellWidth, ( self.y - 1 ) * cellHeight, 0, scaleX, scaleY )
	for i = 1, #self.path do
		love.graphics.draw( indicesImage, colors[self.id], ( self.path[i][1] - 1 ) * cellWidth, ( self.path[i][2] - 1 ) * cellHeight, 0, scaleX, scaleY )
	end
end

function love.load()
	done = false
	love.graphics.setFont( love.graphics.newFont( 12 ) )
	love.graphics.setBackgroundColor( 255, 255, 255 )
	love.graphics.setDefaultFilter( 'nearest', 'nearest' )
	local mazeImage = love.graphics.newImage( 'maze.png' )
	local mazeImageWidth, mazeImageHeight = mazeImage:getDimensions()
	indicesImage = love.graphics.newImage( 'indices.png' )
	local indicesImageWidth, indicesImageHeight = indicesImage:getDimensions()

	quadWidth, quadHeight = 5, 5
	scaleX, scaleY = cellWidth / quadWidth, cellHeight / quadHeight
	local quads = {}
	-- l    r    t    b
	-- lb   rb   tb    
	-- lt   rt   lrtb ltb
	-- lr   brt  lrt  lrb
	-- Names are alphabetized
	-- b l r t
	local names = { 'l', 'r', 't', 'b', 'bl', 'br', 'bt', '', 'lt', 'rt', 'blrt', 'blt', 'lr', 'brt', 'lrt', 'blr' }
	local i = 0
	for y = 0, mazeImageHeight - quadHeight, quadHeight do
		for x = 0, mazeImageWidth - quadWidth, quadWidth do
			i = i + 1
			quads[names[i]] = love.graphics.newQuad( x, y, quadWidth, quadHeight, mazeImageWidth, mazeImageHeight )
		end
	end

	colors = {}
	for y = 0, indicesImageHeight - quadHeight, quadHeight do
		for x = 0, indicesImageWidth - quadWidth, quadWidth do
			table.insert( colors, love.graphics.newQuad( x, y, quadWidth, quadHeight, indicesImageWidth, indicesImageHeight ) )
		end
	end

	map = {}
	for y = 1, screenHeight / cellHeight do
		map[y] = {}
		for x = 1, screenWidth / cellWidth do
			map[y][x] = { value = '', id = '' }
		end
	end

	function drawMap( map )
		for y = 1, #map do
			for x = 1, #map[y] do
				love.graphics.draw( mazeImage, quads[map[y][x].value], ( x - 1 ) * cellWidth, ( y - 1 ) * cellHeight, 0, scaleX, scaleY )
			end
		end
	end

	a = Feeler( 1, 1, 1, map )
	b = Feeler( #map[1], 1, 2, map )
	c = Feeler( #map[1], #map, 3, map )
	d = Feeler( 1, #map, 4, map )
	e = Feeler( math.floor( #map[1] / 2 ), math.floor( #map / 2 ), 5, map )

	connector = Connector( map, a, b, c, d, e )
end

function love.update( dt )
	if not done then
		local adone = a:step()
		local bdone = b:step()
		local cdone = c:step()
		local ddone = d:step()
		local edone = e:step()

		if not ( adone or bdone or cdone or ddone or edone ) then
			done = true
			connector:connect()
		else
			connector:update()
		end
	end
end

function love.draw()
	love.graphics.setColor( 255, 255, 255 )
	if DEBUG then
		debug( a, cellWidth, cellHeight )
		debug( b, cellWidth, cellHeight )
		debug( c, cellWidth, cellHeight )
		debug( d, cellWidth, cellHeight )
		debug( e, cellWidth, cellHeight )
	end
	drawMap( map )

	-- if DEBUG then
	-- 	for y = 1, #map do
	-- 		for x = 1, #map[y] do
	-- 			love.graphics.setColor( 100, 100, 100 )
	-- 			love.graphics.rectangle( 'line', ( x - 1 ) * cellWidth, ( y - 1 ) * cellHeight, cellWidth, cellHeight )
	-- 			love.graphics.print( x .. ', ' .. y, ( x - 1 ) * cellWidth, ( y - 1 ) * cellHeight )
	-- 		end
	-- 	end
	-- end
end

function love.keyreleased( key )
	if key == 'escape' then love.event.quit() end
	if key == '`' then DEBUG = not DEBUG end
	if key == 'r' then love.load() end
end

function love.wheelmoved( x, y )
	if y > 0 then -- Wheel up
		cellWidth, cellHeight = cellWidth + 5, cellHeight + 5
		cellWidth = cellWidth < screenWidth / 4 and cellWidth or math.floor( screenWidth / 4 )
		cellHeight = cellHeight < screenHeight / 4 and cellHeight or math.floor( screenHeight / 4 )
	elseif y < 0 then -- Wheel down
		cellWidth, cellHeight = cellWidth - 5, cellHeight - 5
		cellWidth = cellWidth > quadWidth and cellWidth or quadWidth
		cellHeight = cellHeight > quadWidth and cellWidth or quadWidth
	end
	love.load()
end
