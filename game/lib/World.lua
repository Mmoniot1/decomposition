--By Mami
local Type = require'lualib/Type'
local Console = require'Console'
local ld = require'love.data'

local floor = math.floor
local exp = math.exp
local ceil = math.ceil
local abs = math.abs
local pairs = pairs

local TILESPERMAP = 32
local UNITSPERTILE = 32
local UNITSPERMAP = TILESPERMAP*UNITSPERTILE


local function coordToNum(x, y)
	return 128*y + x
	-- if x >= 0 and y >= 0 then
	-- 	local a = x + y
	-- 	return a*(a + 1)/2 + y
	-- else
	-- 	return -1
	-- end
end

local World = {
	UNITSPERTILE = UNITSPERTILE,
	TILESPERMAP = TILESPERMAP,
	UNITSPERMAP = UNITSPERMAP,
}

function World.get_tile(map, x, y)
	assert(x >= 0)
	assert(y >= 0)
	assert(x < TILESPERMAP)
	assert(y < TILESPERMAP)
	return map[x + TILESPERMAP*y]
end
function World.set_tile(map, x, y, v)
	assert(x >= 0)
	assert(y >= 0)
	assert(x < TILESPERMAP)
	assert(y < TILESPERMAP)
	map[x + TILESPERMAP*y] = v
end



function World.get_map(world, map_x, map_y)
	return world[coordToNum(map_x, map_y)]
end
function World.set_map(world, map_x, map_y, map)
	assert(map_x%1 == 0)
	assert(map_y%1 == 0)
	map.x = map_x
	map.y = map_y
	world[coordToNum(map_x, map_y)] = map
end
World.map_to_key = coordToNum

function World.units_to_tiles(x)
	return floor(x/UNITSPERTILE)
end
function World.units_to_tiles_ceil(x)
	--will error if x == 0
	assert(x ~= 0)
	return ceil(x/UNITSPERTILE) - 1
end
function World.align_to_tile(x)
	return UNITSPERTILE*floor(x/UNITSPERTILE)
end
function World.align_to_tile_ceil(x)
	return UNITSPERTILE*(ceil(x/UNITSPERTILE) - 1)
end
function World.tiles_to_units(tileX)
	return UNITSPERTILE*tileX
end


-- function World.IsBoxColliding(x0, y0, sx0, sy0, )
--
-- end

local TILE_WALL = 0
local TILE_EMPTY = 1
local TILE_PLATFORM = 2
local TILE_LADDER = 3
local TILE_HATCH = 4
local TILE_NULL = TILE_WALL
World.TILE_NULL = TILE_NULL
World.TILE_EMPTY = TILE_EMPTY
World.TILE_LADDER = TILE_LADDER
World.TILE_PLATFORM = TILE_PLATFORM
World.TILE_HATCH = TILE_HATCH
World.TILE_WALL = TILE_WALL


function World:check_hor_tiles(x, sx, tileY, func, noMap)
	--Must return false if maps are nil
	assert(sx >= 0)
	-- assert(x >= 0)
	-- assert(y >= 0)
	local MapX = floor(x/UNITSPERMAP)
	x = x%UNITSPERMAP
	local MapY = floor(tileY/TILESPERMAP)
	tileY = tileY%TILESPERMAP
	local map = World.get_map(self, MapX, MapY)
	if not map then
		return not noMap
	end

	local tileX = World.units_to_tiles(x)
	local tileX1 = World.units_to_tiles_ceil(x + sx)
	local iX = tileX
	while iX <= tileX1 do
		if tileX >= TILESPERMAP then
			tileX = 0
			MapX = MapX + 1
			map = World.get_map(self, MapX, MapY)
			if not map then
				return not noMap
			end
		end
		-- Console.print(x, tileX, tileY, tileX1)
		if not func(map, tileX, tileY) then
			return false
		end
		iX = iX + 1
		tileX = tileX + 1
	end
	return true
end
function World:check_ver_tiles(y, sY, tileX, func, noMap)
	--Must return false if maps are nil
	assert(sY >= 0)
	-- assert(x >= 0)
	-- assert(y >= 0)
	local MapY = floor(y/UNITSPERMAP)
	y = y%UNITSPERMAP
	local MapX = floor(tileX/TILESPERMAP)
	tileX = tileX%TILESPERMAP
	local map = World.get_map(self, MapX, MapY)
	if not map then
		return not noMap
	end

	local tileY = World.units_to_tiles(y)
	local iY = tileY
	local tileY1 = World.units_to_tiles_ceil(y + sY)

	-- Console.print(x, y, tileX, tileY, tileX1, tileY1)
	while iY <= tileY1 do
		if tileY >= TILESPERMAP then
			tileY = 0
			MapY = MapY + 1
			map = World.get_map(self, MapX, MapY)
			if not map then
				return not noMap
			end
		end
		-- Console.print(tileX, tileY, iY, tileY1)
		if not func(map, tileX, tileY) then
			return false
		end
		iY = iY + 1
		tileY = tileY + 1
	end
	return true
end
function World:check_tiles(x, y, sx, sY, func, noMap)
	--Must return false if maps are nil
	assert(sx >= 0)
	assert(sY >= 0)
	-- assert(x >= 0)
	-- assert(y >= 0)
	local MapY = floor(y/UNITSPERMAP)
	y = y%UNITSPERMAP
	local MapX = floor(x/TILESPERMAP)
	x = x%TILESPERMAP
	local map = World.get_map(self, MapX, MapY)
	if not map then
		return not noMap
	end

	local bX = World.units_to_tiles(x)
	local tileX1 = World.units_to_tiles_ceil(x + sx)
	local tileY = World.units_to_tiles(y)
	local iY = tileY
	local tileY1 = World.units_to_tiles_ceil(y + sY)

	-- Console.print(x, y, tileX, tileY, tileX1, tileY1)
	while iY <= tileY1 do
		if tileY > TILESPERMAP then
			tileY = 0
			MapY = MapY + 1
			map = World.get_map(self, MapX, MapY)
			if not map then
				return not noMap
			end
		end
		local tileX = bX
		local iX = tileX
		while iX <= tileX1 do
			if tileX > TILESPERMAP then
				tileX = 0
				MapX = MapX + 1
				map = World.get_map(self, MapX, MapY)
				if not map then
					return not noMap
				end
			end
			local flag = func(map, tileX, tileY)
			if flag then
				return flag
			end
			iX = iX + 1
			tileX = tileX + 1
		end
		iY = iY + 1
		tileY = tileY + 1
	end
	return false
end
function World:get_tile_from_units(tileX, tileY)
	assert(tileX >= 0)
	assert(tileY >= 0)
	-- error(mapX..', '..mapY..'; '..tileX..', '..tileY)
	local mapX = floor(tileX/TILESPERMAP)
	tileX = tileX%TILESPERMAP
	local mapY = floor(tileY/TILESPERMAP)
	tileY = tileY%TILESPERMAP
	local map = World.get_map(self, mapX, mapY)
	return World.get_tile(map, tileX, tileY)
end



function World.new()
	return {}
end
function World.map_new()
	local map = {}
	for i = 0, TILESPERMAP*TILESPERMAP do
		map[i] = TILE_NULL
	end
	return map
end



return World
