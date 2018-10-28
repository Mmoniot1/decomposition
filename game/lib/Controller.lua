--By mami
local Console = require'Console'

local CON_LEFT = 1
local CON_RIGHT = 2
local CON_UP = 3
local CON_DOWN = 4
local CON_ACT = 5
local CON_SHIFT = 6



local Controller = {
	LEFT = CON_LEFT,
	RIGHT = CON_RIGHT,
	UP = CON_UP,
	DOWN = CON_DOWN,
	ACT = CON_ACT,
	SHIFT = CON_SHIFT,
}

function Controller.create()
	return {
		[CON_LEFT] = -1,
		[CON_RIGHT] = -1,
		[CON_UP] = -1,
		[CON_DOWN] = -1,
		[CON_ACT] = -1,
		[CON_SHIFT] = -1,
	}
end

local TO_NAME = {
	[CON_LEFT] = 'left',
	[CON_RIGHT] = 'right',
	[CON_UP] = 'up',
	[CON_DOWN] = 'down',
	[CON_ACT] = 'act',
	[CON_SHIFT] = 'shift',
}
function Controller.process(state, s_input, inputs)
	local time = state.time
	for con = CON_LEFT, CON_SHIFT do
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
function Controller.process_movement(s_input, inputs, time)
	for con = CON_LEFT, CON_DOWN do
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

function Controller.is_down(input, con)
	return input[con] > 0
end
function Controller.just_down(input, con, time)
	return input[con] == time
end
function Controller.around_down(input, con, time, range)
	return input[con] > 0 and input[con] + range >= time
end
function Controller.is_up(input, con)
	return input[con] < 0
end
function Controller.just_up(input, con, time)
	return input[con] == -time
end

function Controller.top_dpad(input)
	local top = CON_LEFT
	local best = input[top]
	for con = CON_LEFT + 1, CON_DOWN do
		local t = input[con]
		if best < t then
			top = con
			best = t
		end
	end
	if best > 0 then
		return top
	else
		return -1
	end
end

function Controller.top_lr(input)
	local t0 = input[CON_LEFT]
	local t1 = input[CON_RIGHT]
	if t0 > t1 then
		if t0 > 0 then
			return CON_LEFT
		end
	elseif t1 > 0 then
		return CON_RIGHT
	end
	return -1
end
function Controller.top_ud(input)
	local t0 = input[CON_UP]
	local t1 = input[CON_DOWN]
	if t0 > t1 then
		if t0 > 0 then
			return CON_UP
		end
	elseif t1 > 0 then
		return CON_DOWN
	end
	return -1
end

function Controller.top(input, tab)
	local top = CON_LEFT
	local best = input[top]
	for i = 1, #tab do
		local con = tab[i]
		local t = input[con]
		if best < t then
			top = con
			best = t
		end
	end
	if best > 0 then
		return top
	else
		return -1
	end
end

return Controller
