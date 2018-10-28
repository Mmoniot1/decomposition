--By mami
local Console = require'Console'
local Controller = require'lib/Controller'
local World = require'lib/World'

local math = math


local UNITSPERTILE = World.UNITSPERTILE
-- local TILESPERMAP = World.TILESPERMAP
-- local UNITSPERMAP = UNITSPERTILE*TILESPERMAP

local STATE_FALLING = 0
local STATE_JUMPABLE_FALLING = 8
local STATE_JUMPABLE_FALLING_WIDE = 9
local STATE_GROUNDED = 1
local STATE_HIGH_JUMP = 2
local STATE_LONG_JUMP = 10
local STATE_CLIMBING = 3
local STATE_HANGING = 4
local STATE_LIFTING = 5
local STATE_LOWERING = 6
local STATE_GRABBING = 7


local HANG_COOLDOWN = 6
local HANG_FROM_FALL_COOLDOWN = 12
local CLIMB_SPEED = 2
local HANG_FUDGE = 4


local function isnt_wall(map, tx, ty)
	local tile = World.get_tile(map, tx, ty)
	return tile ~= World.TILE_WALL
end
local function isnt_ground(map, tx, ty)
	local tile = World.get_tile(map, tx, ty)
	return tile ~= World.TILE_WALL and tile ~= World.TILE_HATCH and tile ~= World.TILE_PLATFORM
end
local function isnt_standable(map, tx, ty)
	local tile = World.get_tile(map, tx, ty)
	return tile ~= World.TILE_WALL and tile ~= World.TILE_PLATFORM
end
local function is_hatch(map, tx, ty)
	local tile = World.get_tile(map, tx, ty)
	return tile == World.TILE_HATCH
end
local function isnt_hatch(map, tx, ty)
	local tile = World.get_tile(map, tx, ty)
	return tile ~= World.TILE_HATCH
end
local function is_platform(map, tx, ty)
	local tile = World.get_tile(map, tx, ty)
	return tile == World.TILE_PLATFORM
end
local function is_hangable(map, tx, ty)
	local tile = World.get_tile(map, tx, ty)
	return tile == World.TILE_PLATFORM or tile == World.TILE_HATCH
end
local function isnt_hangable(map, tx, ty)
	local tile = World.get_tile(map, tx, ty)
	return tile ~= World.TILE_PLATFORM and tile ~= World.TILE_HATCH
end
local function is_climable(map, tx, ty)
	local tile = World.get_tile(map, tx, ty)
	return tile == World.TILE_LADDER or tile == World.TILE_HATCH
end
local function is_ladder(map, tx, ty)
	local tile = World.get_tile(map, tx, ty)
	return tile == World.TILE_LADDER or tile == World.TILE_HATCH
end

local Walk_base = 4
local Walk_base_after_sprint = 8
local Walk_from_hang = 3
local Walk_sprint = 60
local To_walk = {
	.5, .5, 1, 2,
}
for i = 5, 60 do
	To_walk[i] = 2
end
To_walk[60] = 2.5
To_walk[61] = 2.5
To_walk[62] = 3


local function walk_right(state, entity, dx)
	assert(dx <= UNITSPERTILE)
	local px, py = entity.x, entity.y
	local x = px + dx
	--Check if entity is entering a tile
	local tx = World.units_to_tiles_ceil(x + entity.sx)
	if tx ~= World.units_to_tiles_ceil(px + entity.sx) then
		--Check if entity is moving into empty tiles
		if not World.check_ver_tiles(state.world, py, entity.sy, tx, isnt_wall) then
			x = World.align_to_tile_ceil(px + entity.sx) - entity.sx + UNITSPERTILE
			entity.walk_speed = 0
		end
	end
	--Check if entity is leaving a tile
	local tail_tx = World.units_to_tiles(x)
	if tail_tx ~= World.units_to_tiles(px) then
		--Check if entity is no longer grounded
		if World.check_hor_tiles(state.world, x, entity.sx, World.units_to_tiles(py + entity.sy), isnt_ground) then
			entity.plat_state = STATE_JUMPABLE_FALLING
			entity.fall_time = state.time
		end
	end
	entity.x = x
end
local function walk_left(state, entity, dx)
	assert(dx <= UNITSPERTILE)
	local px, py = entity.x, entity.y
	local x = px - dx
	local tx = World.units_to_tiles(x)
	if tx ~= World.units_to_tiles(px) then
		--Check if entity is moving into empty tiles
		if not World.check_ver_tiles(state.world, py, entity.sy, tx, isnt_wall) then
			x = World.align_to_tile(px)
			entity.walk_speed = 0
		end
	end
	--Check if entity is leaving a tile
	local tail_tx = World.units_to_tiles_ceil(x + entity.sx)
	if tail_tx ~= World.units_to_tiles_ceil(px + entity.sx) then
		--Check if entity is no longer grounded
		if World.check_hor_tiles(state.world, x, entity.sx, World.units_to_tiles(py + entity.sy), isnt_ground) then
			entity.plat_state = STATE_JUMPABLE_FALLING
			entity.fall_time = state.time
		end
	end
	entity.x = x
end



local function climb_down(state, entity, dy)
	assert(dy <= UNITSPERTILE)
	local px, py = entity.x, entity.y
	local y = py + dy
	local tile_y = World.units_to_tiles_ceil(y + entity.sy)
	if tile_y ~= World.units_to_tiles_ceil(py + entity.sy) then
		--Check if entity is moving into empty tiles
		if not World.check_hor_tiles(state.world, px, entity.sx, tile_y, isnt_ground) then
			y = World.align_to_tile_ceil(py + entity.sy) - entity.sy + UNITSPERTILE
			entity.plat_state = STATE_GROUNDED
			entity.hang_cool = HANG_COOLDOWN
		elseif not World.check_hor_tiles(state.world, px, entity.sx, tile_y, is_ladder) then
			entity.plat_state = STATE_JUMPABLE_FALLING_WIDE
			entity.fall_time = state.time
		end
	end
	entity.y = y
end
local function climb_down_from_ground(state, entity, dy)
	assert(dy <= UNITSPERTILE)
	local px, py = entity.x, entity.y
	local y = py + dy
	local tile_y = World.units_to_tiles_ceil(y + entity.sy)
	if tile_y ~= World.units_to_tiles_ceil(py + entity.sy) then
		--Check if entity is moving into empty tiles
		if not World.check_hor_tiles(state.world, px, entity.sx, tile_y, isnt_standable) then
			y = World.align_to_tile_ceil(py + entity.sy) - entity.sy + UNITSPERTILE
			entity.plat_state = STATE_GROUNDED
			entity.hang_cool = HANG_COOLDOWN
		elseif not World.check_hor_tiles(state.world, px, entity.sx, tile_y, is_ladder) then
			entity.plat_state = STATE_JUMPABLE_FALLING_WIDE
			entity.fall_time = state.time
		end
	end
	entity.y = y
end
local function climb_up(state, entity, dy)
	assert(dy <= UNITSPERTILE)
	local px, py = entity.x, entity.y
	local y = py - dy
	local tile_y = World.units_to_tiles(y)
	local pretile_y = World.units_to_tiles(py)
	if tile_y ~= pretile_y then
		--Check if entity is moving into empty tiles
		if not World.check_hor_tiles(state.world, px, entity.sx, tile_y, isnt_wall) then
			y = World.align_to_tile(py)
		elseif not World.check_hor_tiles(state.world, px, entity.sx, tile_y, is_climable) then
			if not World.check_hor_tiles(state.world, px, entity.sx, World.units_to_tiles(py + entity.sy), is_hatch) then
				y = World.align_to_tile(py)
			end
		end
	end
	--Check if entity is leaving a tile
	local tail_tile_y = World.units_to_tiles_ceil(y + entity.sy)
	local tail_pretile_y = World.units_to_tiles_ceil(py + entity.sy)
	if tail_tile_y ~= tail_pretile_y then
		--Check if entity has reached ground
		if not World.check_hor_tiles(state.world, px, entity.sx, tail_pretile_y, isnt_hatch) then
			y = World.align_to_tile_ceil(py + entity.sy) - entity.sy
			entity.plat_state = STATE_GROUNDED
			entity.hang_cool = HANG_COOLDOWN
		end
	end
	entity.y = y
end


local to_high_jump = {
	7, 6, 5, 5, 4, 3, 3, 2, 2, 2, 1, 1, 1, 1, 1, 0,
}
local to_long_jump = {
	5, 4, 4, 3, 3, 2, 2, 2, 2, 2, 1, 1, 1, 1, 0,
}
local to_fall = {
	1, 1, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7, 8, 9, 10, 10, 11, 11, 12, 12
}
local function jump_long(time)
	return to_long_jump[time]
end
local function jump_high(time)
	return to_high_jump[time]
end
local function fall_fun(time)
	if time < #to_fall then
		return to_fall[time]
	else
		return to_fall[#to_fall]
	end
	-- return math.floor(7 - time/2 - time*time/16)
end
local function jump_right(state, entity, dx)
	assert(dx <= UNITSPERTILE)
	local px, py = entity.x, entity.y
	local x = px + dx
	--Check if entity is entering a tile
	local tx = World.units_to_tiles_ceil(x + entity.sx)
	if tx ~= World.units_to_tiles_ceil(px + entity.sx) then
		--Check if entity is moving into empty tiles
		if not World.check_ver_tiles(state.world, py, entity.sy, tx, isnt_wall) then
			x = World.align_to_tile_ceil(px + entity.sx) - entity.sx + UNITSPERTILE
			entity.walk_speed = 0
		end
	end
	entity.x = x
end
local function jump_left(state, entity, dx)
	assert(dx <= UNITSPERTILE)
	local px, py = entity.x, entity.y
	local x = px - dx
	local tx = World.units_to_tiles(x)
	if tx ~= World.units_to_tiles(px) then
		--Check if entity is moving into empty tiles
		if not World.check_ver_tiles(state.world, py, entity.sy, tx, isnt_wall) then
			x = World.align_to_tile(px)
			entity.walk_speed = 0
		end
	end
	entity.x = x
end
local function fall_right(state, entity, dx)
	assert(dx <= UNITSPERTILE)
	local px, py = entity.x, entity.y
	local x = px + dx
	--Check if entity is entering a tile
	local tx = World.units_to_tiles_ceil(x + entity.sx)
	if tx ~= World.units_to_tiles_ceil(px + entity.sx) then
		--Check if entity is moving into empty tiles
		if not World.check_ver_tiles(state.world, py, entity.sy, tx, isnt_wall) then
			x = World.align_to_tile_ceil(px + entity.sx) - entity.sx + UNITSPERTILE
			entity.walk_speed = 0
		end
	end
	entity.x = x
end
local function fall_left(state, entity, dx)
	assert(dx <= UNITSPERTILE)
	local px, py = entity.x, entity.y
	local x = px - dx
	local tx = World.units_to_tiles(x)
	if tx ~= World.units_to_tiles(px) then
		--Check if entity is moving into empty tiles
		if not World.check_ver_tiles(state.world, py, entity.sy, tx, isnt_wall) then
			x = World.align_to_tile(px)
			entity.walk_speed = 0
		end
	end
	entity.x = x
end


local function lift(state, entity)
	local dy = 2
	local px, py = entity.x, entity.y
	local y = py - dy
	local tile_y = World.units_to_tiles(y)
	local pretile_y = World.units_to_tiles(py)
	if tile_y ~= pretile_y then
		--Check if entity is moving into empty tiles
		if not World.check_hor_tiles(state.world, px, entity.sx, tile_y, isnt_wall) then
			y = World.align_to_tile(py)
			entity.plat_state = STATE_HANGING
			entity.walk_speed = 0--<--
			entity.hang_cool = HANG_COOLDOWN
		end
	end
	--Check if entity is leaving a tile
	local tail_tile_y = World.units_to_tiles_ceil(y + entity.sy)
	local tail_pretile_y = World.units_to_tiles_ceil(py + entity.sy)
	if tail_tile_y ~= tail_pretile_y then
		--Check if entity has reached ground
		if not World.check_hor_tiles(state.world, px, entity.sx, tail_pretile_y, isnt_hangable) then
			y = World.align_to_tile_ceil(py + entity.sy) - entity.sy
			entity.plat_state = STATE_GROUNDED
			entity.hang_cool = HANG_COOLDOWN
		end
	end
	entity.y = y
end
local function lower(state, entity)
	local dy = 2
	local px, py = entity.x, entity.y
	local y = py + dy
	local tile_y = World.units_to_tiles_ceil(y + entity.sy)
	if tile_y ~= World.units_to_tiles_ceil(py + entity.sy) then
		--Check if entity is moving into empty tiles
		if not World.check_hor_tiles(state.world, px, entity.sx, tile_y, isnt_wall) then
			y = World.align_to_tile_ceil(py + entity.sy) - entity.sy + UNITSPERTILE
			entity.plat_state = STATE_GROUNDED
			entity.hang_cool = HANG_COOLDOWN
		end
	end
	--Check if entity is leaving a tile
	local tail_tile_y = World.units_to_tiles(y)
	local pre_tail_tile_y = World.units_to_tiles(py)
	if tail_tile_y ~= pre_tail_tile_y then
		if not World.check_hor_tiles(state.world, px, entity.sx, tail_tile_y, isnt_hangable) then
			y = World.tiles_to_units(tail_tile_y)
			entity.plat_state = STATE_HANGING
			entity.walk_speed = 0--<--
			entity.hang_cool = HANG_COOLDOWN
		end
	end
	entity.y = y
end
local function grab(state, entity)
	local dy = 2
	local px, py = entity.x, entity.y
	local y = py - dy
	local tile_y = World.units_to_tiles(y)
	local pretile_y = World.units_to_tiles(py)
	if tile_y ~= pretile_y then
		--Check if entity is moving into empty tiles
		if World.check_hor_tiles(state.world, px, entity.sx, pretile_y, is_hangable) then
			y = World.align_to_tile(py)
			entity.plat_state = STATE_HANGING
			entity.walk_speed = 0--<--
			entity.hang_cool = HANG_COOLDOWN
		end
	end
	entity.y = y
end

local to_fall_open = {
	[STATE_FALLING] = 0,
	[STATE_JUMPABLE_FALLING] = 3,
	[STATE_JUMPABLE_FALLING_WIDE] = 6,
}


local function state_grouned(state, entity, input)
	local con_dpad = Controller.top_lr(input)
	local walk_speed = entity.walk_speed
	if con_dpad == Controller.RIGHT then
		if walk_speed < -Walk_base then
			entity.walk_speed = -Walk_base
		elseif walk_speed < #To_walk then
			entity.walk_speed = entity.walk_speed + 1
		end
	elseif con_dpad == Controller.LEFT then
		if walk_speed > Walk_base then
			entity.walk_speed = Walk_base
		elseif walk_speed > -#To_walk then
			entity.walk_speed = entity.walk_speed - 1
		end
	else
		if walk_speed > 0 then
			if walk_speed > Walk_base then
				entity.walk_speed = Walk_base
			else
				entity.walk_speed = entity.walk_speed - 1
			end
		elseif walk_speed < 0 then
			if walk_speed < -Walk_base then
				entity.walk_speed = -Walk_base
			else
				entity.walk_speed = entity.walk_speed + 1
			end
		end
	end
	local flag = true
	if entity.hang_cool <= 0 then
		con_dpad = Controller.top_ud(input)
		if con_dpad == Controller.UP then
			local tile_x = World.units_to_tiles(entity.x)
			if tile_x == World.units_to_tiles_ceil(entity.x + entity.sx) then--entity is not crossing a boundary
				if World.check_ver_tiles(state.world, entity.y, entity.sy, tile_x, is_climable) then
					entity.plat_state = STATE_CLIMBING
					entity.walk_speed = 0--<--
					climb_up(state, entity, CLIMB_SPEED)
					flag = false
				end
			end
			local tile_y = World.units_to_tiles(entity.y)
			if World.check_hor_tiles(state.world, entity.x, entity.sx, tile_y, is_hangable) then
				entity.plat_state = STATE_GRABBING
				flag = false
			end
		elseif con_dpad == Controller.DOWN then
			local tile_x = World.units_to_tiles(entity.x)
			if tile_x == World.units_to_tiles_ceil(entity.x + entity.sx) then--entity is not crossing a boundary
				local tile_y = World.units_to_tiles(entity.y + entity.sy)
				local tile_ground = World.get_tile_from_units(state.world, tile_x, tile_y)
				if tile_ground == World.TILE_HATCH then
					entity.plat_state = STATE_CLIMBING
					entity.walk_speed = 0--<--
					climb_down_from_ground(state, entity, CLIMB_SPEED)
					flag = false
				end
			end
			if flag then
				local tile_y = World.units_to_tiles(entity.y + entity.sy)
				local tile_left_x = World.units_to_tiles(entity.x)
				local tile_right_x = World.units_to_tiles_ceil(entity.x + entity.sx)
				local tile_left = World.get_tile_from_units(state.world, tile_left_x, tile_y)
				local tile_right = World.get_tile_from_units(state.world, tile_right_x, tile_y)
				local is_left = tile_left == World.TILE_PLATFORM or tile_left == World.TILE_HATCH
				local is_right = tile_right == World.TILE_PLATFORM or tile_right == World.TILE_HATCH
				if is_left and is_right then
					entity.plat_state = STATE_LOWERING
					flag = false
				end
			end
		end
	else
		entity.hang_cool = entity.hang_cool - 1
	end
	if flag then
		if entity.walk_speed > 0 then
			-- Console.print(entity.walk_speed,To_walk[entity.walk_speed])
			walk_right(state, entity, To_walk[entity.walk_speed])
		elseif entity.walk_speed < 0 then
			walk_left(state, entity, To_walk[-entity.walk_speed])
		end
	end
	if entity.plat_state == STATE_FALLING or entity.plat_state == STATE_GROUNDED then
		if Controller.around_down(input, Controller.ACT, state.time, 4) then
			if entity.walk_speed >= Walk_sprint or entity.walk_speed <= -Walk_sprint then
				entity.plat_state = STATE_LONG_JUMP
			else
				entity.plat_state = STATE_HIGH_JUMP
			end
			entity.jump_time = state.time
		end
	end
end
local function state_high_jump(state, entity, input)
	local con_dpad = Controller.top_lr(input)
	local walk_speed = entity.walk_speed
	if con_dpad == Controller.RIGHT then
		if walk_speed < -Walk_base then
			entity.walk_speed = -Walk_base
		elseif walk_speed < 0 then
			entity.walk_speed = entity.walk_speed + 1
		end
	elseif con_dpad == Controller.LEFT then
		if walk_speed > Walk_base then
			entity.walk_speed = Walk_base
		elseif walk_speed > 0 then
			entity.walk_speed = entity.walk_speed - 1
		end
	end
	if entity.walk_speed > 0 then
		jump_right(state, entity, To_walk[entity.walk_speed])
	elseif entity.walk_speed < 0 then
		jump_left(state, entity, To_walk[-entity.walk_speed])
	end
	local jump_time = state.time - entity.jump_time
	do--jump
		local dy = jump_high(jump_time)
		if dy > 0 then--move the entity up
			local px, py = entity.x, entity.y
			local y = py - dy
			local ty = World.units_to_tiles(y)
			if ty ~= World.units_to_tiles(py) then
				--Check if entity is moving into empty tiles
				if not World.check_hor_tiles(state.world, px, entity.sx, ty, isnt_wall) then
					--entity hit head
					y = World.align_to_tile(py)
					entity.plat_state = STATE_FALLING
					entity.fall_time = state.time
				end
				-- if Controller.is_down(input, Controller.UP) then
				-- 	local tile_y = World.units_to_tiles(py)
				-- 	if World.check_hor_tiles(state.world, px, entity.sx, tile_y, is_hangable) then
				-- 		y = World.align_to_tile(py)
				-- 		entity.plat_state = STATE_HANGING
				-- 	end
				-- end
			end
			entity.y = y
		else
			entity.plat_state = STATE_FALLING
			entity.fall_time = state.time
		end
	end
end
local function state_long_jump(state, entity, input)
	local con_dpad = Controller.top_lr(input)
	local walk_speed = entity.walk_speed
	if con_dpad == Controller.RIGHT then
		if walk_speed < -Walk_base_after_sprint then
			entity.walk_speed = -Walk_base_after_sprint
		elseif walk_speed < 0 then
			entity.walk_speed = entity.walk_speed + 1
		end
	elseif con_dpad == Controller.LEFT then
		if walk_speed > Walk_base_after_sprint then
			entity.walk_speed = Walk_base_after_sprint
		elseif walk_speed > 0 then
			entity.walk_speed = entity.walk_speed - 1
		end
	end
	if entity.walk_speed > 0 then
		jump_right(state, entity, To_walk[entity.walk_speed])
	elseif entity.walk_speed < 0 then
		jump_left(state, entity, To_walk[-entity.walk_speed])
	end
	local jump_time = state.time - entity.jump_time
	do--jump
		local dy = jump_long(jump_time)
		if dy > 0 then--move the entity up
			local px, py = entity.x, entity.y
			local y = py - dy
			local ty = World.units_to_tiles(y)
			if ty ~= World.units_to_tiles(py) then
				--Check if entity is moving into empty tiles
				if not World.check_hor_tiles(state.world, px, entity.sx, ty, isnt_wall) then
					--entity hit head
					y = World.align_to_tile(py)
					entity.plat_state = STATE_FALLING
					entity.fall_time = state.time
				end
				-- if Controller.is_down(input, Controller.UP) then
				-- 	local tile_y = World.units_to_tiles(py)
				-- 	if World.check_hor_tiles(state.world, px, entity.sx, tile_y, is_hangable) then
				-- 		y = World.align_to_tile(py)
				-- 		entity.plat_state = STATE_HANGING
				-- 	end
				-- end
			end
			entity.y = y
		else
			entity.plat_state = STATE_FALLING
			entity.fall_time = state.time
		end
	end
end
local function state_falling(state, entity, input)
	local fall_time = state.time - entity.fall_time
	local flag = true
	if fall_time < to_fall_open[entity.plat_state] and Controller.just_down(input, Controller.ACT, state.time) then
		entity.plat_state = STATE_HIGH_JUMP
		entity.jump_time = state.time
	else--fall
		local dy = fall_fun(fall_time)
		local px, py = entity.x, entity.y
		local y = py + dy
		local ty = World.units_to_tiles_ceil(y + entity.sy)
		if ty ~= World.units_to_tiles_ceil(py + entity.sy) then
			--Check if entity is moving into empty tiles
			if not World.check_hor_tiles(state.world, px, entity.sx, ty, isnt_ground) then
				y = World.align_to_tile_ceil(py + entity.sy) - entity.sy + UNITSPERTILE
				-- ty = World.units_to_tiles_ceil(y + entity.sy)
				entity.plat_state = STATE_GROUNDED
				entity.hang_cool = HANG_COOLDOWN
				flag = false
			end
		end
		--Check if entity is leaving a tile or just left a tile
		local tail_ty = World.units_to_tiles(y)
		if tail_ty ~= World.units_to_tiles(py - HANG_FUDGE) then--<--perhaps make grabbing even?
			if Controller.is_down(input, Controller.UP) then
				if World.check_hor_tiles(state.world, px, entity.sx, tail_ty, is_hangable) then
					y = World.tiles_to_units(tail_ty)
					entity.plat_state = STATE_HANGING
					entity.walk_speed = 0--<--
					entity.hang_cool = HANG_FROM_FALL_COOLDOWN
				end
			end
		end
		entity.y = y
	end
	if flag then
		local con_dpad = Controller.top_lr(input)
		if con_dpad == Controller.RIGHT then
			if entity.walk_speed < 0 then
				entity.walk_speed = entity.walk_speed + 1
			end
		elseif con_dpad == Controller.LEFT then
			if entity.walk_speed > 0 then
				entity.walk_speed = entity.walk_speed - 1
			end
		end
		if Controller.top_ud(input) > 0 then
			local tile_x = World.units_to_tiles(entity.x)
			if tile_x == World.units_to_tiles_ceil(entity.x + entity.sx) then--entity is not crossing a boundary
				if World.check_ver_tiles(state.world, entity.y, entity.sy, tile_x, is_climable) then
					entity.plat_state = STATE_CLIMBING
					entity.walk_speed = 0--<--
					climb_up(state, entity, CLIMB_SPEED)
					flag = false
				end
			end
		end
		if flag then
			if entity.walk_speed > 0 then
				fall_right(state, entity, To_walk[entity.walk_speed])
			elseif entity.walk_speed < 0 then
				fall_left(state, entity, To_walk[-entity.walk_speed])
			end
		end
	end
end
local function state_climbing(state, entity, input)
	local con_dpad = Controller.top_ud(input)
	if con_dpad == Controller.UP then
		climb_up(state, entity, CLIMB_SPEED)
	elseif con_dpad == Controller.DOWN then
		climb_down(state, entity, CLIMB_SPEED)
	else
		con_dpad = Controller.top_lr(input)
		if con_dpad == Controller.RIGHT then
			entity.plat_state = STATE_JUMPABLE_FALLING_WIDE
			entity.fall_time = state.time
			entity.walk_speed = Walk_from_hang
			fall_right(state, entity, To_walk[Walk_from_hang])
		elseif con_dpad == Controller.LEFT then
			entity.plat_state = STATE_JUMPABLE_FALLING_WIDE
			entity.fall_time = state.time
			entity.walk_speed = -Walk_from_hang
			fall_left(state, entity, To_walk[Walk_from_hang])
		elseif Controller.just_down(input, Controller.ACT, state.time) then
			entity.plat_state = STATE_FALLING
			entity.fall_time = state.time
		end
	end
end
local function state_hanging(state, entity, input)
	if entity.hang_cool <= 0 then
		local con_dpad = Controller.top_ud(input)
		if con_dpad == Controller.UP then
			entity.plat_state = STATE_LIFTING
			return
		elseif con_dpad == Controller.DOWN then
			entity.plat_state = STATE_FALLING
			entity.fall_time = state.time
			return
		end
	else
		entity.hang_cool = entity.hang_cool - 1
	end
	if entity.hang_cool < 6 then
		local con_dpad = Controller.top_lr(input)
		if con_dpad == Controller.RIGHT then
			entity.plat_state = STATE_JUMPABLE_FALLING_WIDE--<--prevent cooldown avoidance
			entity.fall_time = state.time
			entity.walk_speed = Walk_from_hang
			fall_right(state, entity, To_walk[Walk_from_hang])
		elseif con_dpad == Controller.LEFT then
			entity.plat_state = STATE_JUMPABLE_FALLING_WIDE
			entity.fall_time = state.time
			entity.walk_speed = -Walk_from_hang
			fall_left(state, entity, To_walk[Walk_from_hang])
		elseif Controller.just_down(input, Controller.ACT, state.time) then
			entity.plat_state = STATE_FALLING
			entity.fall_time = state.time
		end
	end
end

local To_state = {
	[STATE_GROUNDED] = state_grouned,
	[STATE_HIGH_JUMP] = state_high_jump,
	[STATE_LONG_JUMP] = state_long_jump,
	[STATE_FALLING] = state_falling,
	[STATE_JUMPABLE_FALLING_WIDE] = state_falling,
	[STATE_JUMPABLE_FALLING] = state_falling,
	[STATE_CLIMBING] = state_climbing,
	[STATE_HANGING] = state_hanging,
	[STATE_LIFTING] = lift,
	[STATE_LOWERING] = lower,
	[STATE_GRABBING] = grab,
}
local function move_player(state, player)
	To_state[player.plat_state](state, player, state.game.input)
end


local Platforming = {
	move_player = move_player
}

return Platforming
