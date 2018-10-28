--By Mami
local Console = require'Console'
local love = require'love'
local lk = require'love.keyboard'
local lm = require'love.mouse'


local key_down = lk.isScancodeDown

local Con = {
	LEFT = 1,
	RIGHT = 2,
	UP = 3,
	DOWN = 4,
	SHIFT = 5,
	M1 = 6,
	M2 = 7,
	M3 = 8,
	CONTROL = 9,
	Q = 10,
	E = 11,
	Z = 12,
	X = 13,
	C = 14,
	V = 15,
	DELETE = 16,
	ONE = 17,
	TWO = 18,
	THREE = 19,
	FOUR = 20,
	FIVE = 21,
}

local Mouse_wheel = 0
function Con.get_input()
	local input = {
		[Con.UP] = key_down('w'),
		[Con.DOWN] = key_down('s'),
		[Con.LEFT] = key_down('a'),
		[Con.RIGHT] = key_down('d'),
		[Con.SHIFT] = key_down('lshift'),
		[Con.CONTROL] = key_down('lctrl'),
		[Con.Q] = key_down('q'),
		[Con.E] = key_down('e'),
		[Con.Z] = key_down('z'),
		[Con.X] = key_down('x'),
		[Con.C] = key_down('c'),
		[Con.V] = key_down('v'),
		[Con.DELETE] = key_down('backspace') or key_down('delete'),
		[Con.ONE] = key_down('1'),
		[Con.TWO] = key_down('2'),
		[Con.THREE] = key_down('3'),
		[Con.FOUR] = key_down('4'),
		[Con.FIVE] = key_down('5'),
		[Con.M1] = lm.isDown(1),
		[Con.M2] = lm.isDown(2),
		[Con.M3] = lm.isDown(3),
		x = lm.getX(),
		y = lm.getY(),
		wheel = Mouse_wheel
	}
	Mouse_wheel = 0
	return input
end

function Con.new_controller()
	local con = {
	}
	for i = 1, Con.FIVE do
		con[i] = -1
	end
	return con
end

function Con.process(s_input, inputs, time)
	for con = 1, Con.FIVE do
		if s_input[con] > 0 then
			if not inputs[con] then
				s_input[con] = -time
				-- Console.record(TO_NAME[con], -time)
			end
		elseif inputs[con] then
			s_input[con] = time
			-- Console.record(TO_NAME[con], time)
		end
	end
end

function Con.is_down(input, con)
	return input[con] > 0
end
function Con.just_down(input, con, time)
	return input[con] == time
end
function Con.around_down(input, con, time, range)
	return input[con] > 0 and input[con] + range >= time
end
function Con.is_up(input, con)
	return input[con] < 0
end
function Con.just_up(input, con, time)
	return input[con] == -time
end
function Con.time_down(input, con, time)
	return time - input[con]
end

function Con.top_lr(input)
	local t0 = input[Con.LEFT]
	local t1 = input[Con.RIGHT]
	if t0 > t1 then
		if t0 > 0 then
			return Con.LEFT
		end
	elseif t1 > 0 then
		return Con.RIGHT
	end
	return -1
end
function Con.top_ud(input)
	local t0 = input[Con.UP]
	local t1 = input[Con.DOWN]
	if t0 > t1 then
		if t0 > 0 then
			return Con.UP
		end
	elseif t1 > 0 then
		return Con.DOWN
	end
	return -1
end


function Con.connect_to_wheel()
	love.wheelmoved = function(_, y)
		Mouse_wheel = y
	end
end

return Con
