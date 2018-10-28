--By mami
local Controller = require'lib/Controller'
local Gui = require'lib/Gui'
local Chara = require'lib/Chara_static'
local Console = require'Console'
local lg = require'love.graphics'


local function finish_act(state, combat_data)
	combat_data.turn = combat_data.turn + 1
	-- error(combat_data.turn)
end

local Act_table = {
	[0] = {
		init = function(state, combat_data, action, actor_pid)
		end,
		run = function(state, combat_data, action, actor_pid)
			finish_act(state, combat_data)
		end,
		render = function(state, combat_data, action, actor_pid)
		end,
	}
}

--[[
	Invariants:
	one action per actor
]]

do--frogger attack
	local FIELD_HOR_SIZE = 128
	local LEVEL_DEPTH = 64
	local MARKER_SPEED = 3
	local DAMAGE_PER_LEVEL = 16
	local WALL_VER_OFF = 32
	-- local WALL_HOR_OFF = 8
	local WALL_VER_DEPTH = 24
	local HOLE_HOR_SIZE = 32
	local MARKER_VER_SIZE = 16
	local MARKER_HOR_SIZE = 16
	local FIELD_VER_SIZE = 3*LEVEL_DEPTH
	local function get_pos(time)
		local range = (FIELD_HOR_SIZE)/2
		return math.floor(range - range*math.cos((2*math.pi/140)*time) + .5) - MARKER_HOR_SIZE/2
	end
	local function is_colliding(x, hole_x)
		local hole_cx = hole_x + HOLE_HOR_SIZE
		local flag = hole_x <= x
		if not flag and hole_cx > FIELD_HOR_SIZE then
			hole_cx = hole_cx - FIELD_HOR_SIZE
			flag = true
		end
		if flag and x <= hole_cx and x + MARKER_HOR_SIZE <= hole_cx then
			return false
		end
		return true
	end
	local function get_actor_input(state, combat_data, pid)
		if true then -- pid == 0 then
			return Controller.just_down(state.game.input, Controller.ACT, state.time)
		else
			return false
		end
	end
	local function get_target_input(state, combat_data, pid)
		if true then --pid == 0 then
			local con = Controller.top_lr(state.game.input)
			if con == Controller.LEFT then
				return -1
			elseif con == Controller.RIGHT then
				return 1
			else
				return 0
			end
		else
			return 0
		end
	end
	local function fin(state, combat_data, action)
		Chara.damage(state, action.target_pid, DAMAGE_PER_LEVEL*action.marker_level)
		finish_act(state, combat_data)
	end
	Act_table[1] = {
		init = function(state, combat_data, action, actor_pid)
			-- action.target_pid
			-- action.actor_pid
			action.drop = false
			action.marker_x = 0
			action.marker_y = 0
			action.marker_level = 0
			action.hole_offsets = {70, 5, 40}
			action.time0 = state.time
		end,
		run = function(state, combat_data, action, actor_pid)
			local d = get_target_input(state, combat_data, action.target_pid)
			if d ~= 0 then
				for y = 1, 3 do
					action.hole_offsets[y] = (action.hole_offsets[y] + d)%FIELD_HOR_SIZE
				end
			end
			if not action.drop then
				local drop = get_actor_input(state, combat_data, actor_pid)
				if drop then
					action.time0 = state.time - action.time0
					action.drop = true
				end
			end
			if action.drop then
				action.marker_y = action.marker_y + MARKER_SPEED
				-- Console.print(action.marker_y, LEVEL_DEPTH*(action.marker_level + 1))
				if action.marker_y >= LEVEL_DEPTH*(action.marker_level + 1) then
					action.drop = false
					action.marker_level = action.marker_level + 1
					action.marker_y = LEVEL_DEPTH*action.marker_level
					if action.marker_level > 2 then
						fin(state, combat_data, action)
					else
						action.time0 = state.time - action.time0
					end
				else
					--check for collisions
					local y = action.marker_y%LEVEL_DEPTH
					if y > WALL_VER_OFF - MARKER_VER_SIZE and y < WALL_VER_OFF + WALL_VER_DEPTH then
						if is_colliding(action.marker_x, action.hole_offsets[action.marker_level + 1]) then
							fin(state, combat_data, action)
						end
					end
				end
			else
				action.marker_x = get_pos(state.time - action.time0)
			end
		end,
		render = function(state, combat_data, action, actor_pid)
			Gui.set_color(Gui.RED)
			Gui.screen_trans(-FIELD_HOR_SIZE/2, -FIELD_VER_SIZE/2)
			local marker = {
				x = action.marker_x,
				y = action.marker_y,
				sx = MARKER_HOR_SIZE,
				sy = MARKER_VER_SIZE,
			}
			Gui.draw_box(marker, false)
			for y = 1, 3 do
				local hole_offset = action.hole_offsets[y]
				local hole_displace = hole_offset + HOLE_HOR_SIZE
				local wall_y = y*LEVEL_DEPTH - (LEVEL_DEPTH - WALL_VER_OFF)
				if hole_displace >= FIELD_HOR_SIZE then
					local d = hole_displace%FIELD_HOR_SIZE
					local wall = {
						x = d,
						y = wall_y,
						sx = hole_offset - d,
						sy = WALL_VER_DEPTH,
					}
					Gui.draw_box(wall, false)
				else
					local wall0 = {
						x = 0,
						y = wall_y,
						sx = hole_offset,
						sy = WALL_VER_DEPTH,
					}
					local wall1 = {
						x = hole_displace,
						y = wall_y,
						sx = FIELD_HOR_SIZE - hole_displace,
						sy = WALL_VER_DEPTH,
					}
					Gui.draw_box(wall0, false)
					Gui.draw_box(wall1, false)
				end
			end
			Gui.draw_box(marker, false)
		end,
	}
end


return Act_table
