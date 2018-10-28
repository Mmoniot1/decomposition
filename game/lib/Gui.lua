--By mami
local Display = require'lib/Display'
local lg = require'love.graphics'
local Console = require'Console'

local unpack = unpack
--NOTE: graphics are measured in units


local all_font = love.graphics.newFont(12)


local Gui = {
	RED     = {1, 0, 0},
	YELLOW  = {1, 1, 0},
	GREEN   = {0, 1, 0},
	TEAL    = {0, 1, 1},
	BLUE    = {.2, .2, 1},
	MAGENTA = {1, 0, 1},
	PURPLE  = {.5, 0, 1},
	ORANGE  = {1, .5, 0},
	BROWN   = {1, .5, .5},
	WHITE   = {1, 1, 1},
	GRAY    = {.6, .6, .6},
	DARK_GRAY = {.2, .2, .2},
	BLACK   = {0, 0, 0},
}

function Gui.move(frame, x, y)
	frame.x = frame.x + x
	frame.y = frame.y + y
end


function Gui.set_parent(frame0, frame1)
	frame0.x = frame0.x + frame1.x
	frame0.y = frame0.y + frame1.y
end
function Gui.scale_from_center(frame, scale_x, scale_y)
	local sx = scale_x*frame.sx
	local sy = scale_y*frame.sy
	frame.x = frame.x - (sx - frame.sx)/2
	frame.y = frame.y - (sy - frame.sy)/2
	frame.sx = sx
	frame.sy = sy
end


function Gui.remove_parent(frame0, frame1)
	frame0.x = frame0.x - frame1.x
	frame0.y = frame0.y - frame1.y
end


function Gui.draw_box(frame, mode)
	lg.rectangle(mode and 'line' or 'fill', frame.x, frame.y, frame.sx, frame.sy)
end
function Gui.draw_quad(frame, image, quad, image_sx, image_sy)
	lg.draw(image, quad, frame.x, frame.y, 0, frame.sx/image_sx, frame.sy/image_sy)
end

function Gui.get_abs_frame(frame, sx, sy)
	local new_frame = {
		x = frame.x*sx,
		y = frame.y*sy,
		sx = frame.sx*sx,
		sy = frame.sy*sy,
	}
	return new_frame
end



function Gui.set_color(color, alpha)
	local r, g, b = unpack(color)
	lg.setColor(r, g, b, alpha)
end

function Gui.set_font(font)
	lg.setFont(font)
end

function Gui.screen_origin()
	lg.origin()
	lg.scale(Display.pixels_per_unit, Display.pixels_per_unit)
end
function Gui.screen_abs_origin()
	lg.origin()
end

function Gui.screen_center()
	lg.translate(Display.screen_sx/2, Display.screen_sy/2)
end

function Gui.screen_trans(x, y)
	lg.translate(x, y)
end



return Gui
