--By Mami
local love = require'love'
local lg = require'love.graphics'
local Console = require'Console'
local World = require'lib/World'

local math = math
local ceil = math.ceil
local floor = math.floor


local UNITSPERTILE = World.UNITSPERTILE
local TILESPERMAP = World.TILESPERMAP
local UNITSPERMAP = UNITSPERTILE*TILESPERMAP
local MAXUNITWIDTH = 3*UNITSPERMAP/4
local MAXUNITHEIGHT = 9*UNITSPERMAP/16
-- local PixelsPerTile = PixelsPerUnit*UNITSPERTILE
-- local PixelsPerMap = PixelsPerTile*TILESPERMAP



local Display = {
	screen_pixels_sx = 200,
	screen_pixels_sy = 300,
	screen_sx = 200,
	screen_sy = 300,
	pixels_per_unit = 1,
}

function Display.init()
	local x, y = lg.getDimensions()
	Display.Resize(x, y)
	love.resize = Display.Resize
	lg.setDefaultFilter('nearest', 'nearest', 2)
end

function Display.set_pixels_per_unit(ppu)
	local width, height = lg.getDimensions()
	if Display.pixels_per_unit ~= ppu then
		Display.pixels_per_unit = ppu
	end
	Display.screen_pixels_sx, Display.screen_pixels_sy = width, height
	Display.screen_sx = 2*floor(width/ppu/2)
	Display.screen_sy = 2*floor(height/ppu/2)
end
-- local hasResized = false
function Display.Resize(width, height)
	local ppux = ceil(width/MAXUNITWIDTH)
	local ppuy = ceil(height/MAXUNITHEIGHT)
	local ppu
	if ppux > ppuy then
		ppu = ppux
	else
		ppu = ppuy
	end
	if Display.pixels_per_unit ~= ppu then
		Console.log('lib/Display', 'pixels per unit =', ppu)
		Display.pixels_per_unit = ppu
	end
	Display.screen_pixels_sx, Display.screen_pixels_sy = width, height
	Display.screen_sx = 2*floor(width/ppu/2)
	Display.screen_sy = 2*floor(height/ppu/2)
	-- hasResized = true
end

function Display.window_resize(width, height)
	local ppu = Display.pixels_per_unit
	Display.screen_pixels_sx, Display.screen_pixels_sy = width, height
	Display.screen_sx = 2*floor(width/ppu/2)
	Display.screen_sy = 2*floor(height/ppu/2)
end

function Display.pixels_to_units(x, off)
	return floor(x/Display.pixels_per_unit) + off
end
function Display.pixels_to_units_ceil(x, off)
	return ceil(x/Display.pixels_per_unit) + off - 1
end
function Display.pixels_to_tiles(x, off)
	return World.units_to_tiles(Display.pixels_to_units(x, off))
end
function Display.units_to_pixels(x, off)
	return Display.pixels_per_unit*(x - off)
end


lg.setDefaultFilter('nearest', 'nearest', 2)

return Display
