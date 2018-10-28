--By Mmoniot
local World = require'lib/World'
local Console = require'Console'
local Controller = require'lib/Controller'
local Player_combat = require'lib/Player_combat'
local Platforming = require'lib/Platforming'

local math = math


local UNITSPERTILE = World.UNITSPERTILE
local TILESPERMAP = World.TILESPERMAP
local UNITSPERMAP = UNITSPERTILE*TILESPERMAP


local function in_range_square(entity0, entity1, range_x, range_y)
	local is_left_x = entity1.x - range_x < entity0.x and entity0.x < entity1.x + entity1.sx + range_x
	local is_right_x = entity1.x - range_x < entity0.x + entity0.sx and entity0.x + entity0.sx < entity1.x + entity1.sx + range_x
	local is_left_y = entity1.y - range_y < entity0.y and entity0.y < entity1.y + entity1.sy + range_y
	local is_right_y = entity1.y - range_y < entity0.y + entity0.sy and entity0.y + entity0.sy < entity1.y + entity1.sy + range_y
	return (is_left_x or is_left_y) and (is_right_x or is_right_y)
end


local INTERACT_RANGE = UNITSPERTILE/2
local function Update(state, inputs)
	--[[
	NOTE:
		Update has the sole responsibility to update the game state;
		no other relevant game state should be changed anywhere else
		state must be mutated based on it's values and the values of inputs
		out is a table of proceedures;
		it may be called from to inform the system how to display these mutations
		Update must have deterministic behavior with respect to how it mutates state
	]]--
	local player = state.chara_table[0]
	do--init sequence
		state.time = state.time + 1
		Controller.process(state, state.game.input, inputs.player)
		inputs = nil
	end


	-- do--World Upkeep
	-- 	local chara_table = state.chara_table
	-- 	for i = 1, #chara_table do
	-- 		local chara = chara_table[i]
	--
	-- 	end
	--
	--
	-- 	if inputs.Player_interact then--<--check if we want player to do this now
	-- 		--Find closest character in range to interact
	-- 		--Closeness is measured from base of hitbox
	-- 		local closest_chara
	-- 		local closeness = math.huge
	-- 		for i = 1, #chara_table do
	-- 			local chara = chara_table[i]
	-- 			if in_range_square(player, chara, INTERACT_RANGE, INTERACT_RANGE) then
	-- 				local dx = player.y + player.sy - chara.y - chara.sy
	-- 				local dy = player.x + player.sx/2 - chara.x - chara.sx/2
	-- 				local cur_closeness = dx*dx + dy*dy
	-- 				if cur_closeness < closeness then
	-- 					closeness = cur_closeness
	-- 					closest_chara = chara
	-- 				end
	-- 			end
	-- 		end
	-- 		if closest_chara then
	--
	-- 		end
	-- 	end
	-- end

	do--Player
		local stop_movement = Player_combat.run(state, state.game.player_combat)
		if not stop_movement then
			Platforming.move_player(state, player)
		end
	end
end



local Logic = {
	update = Update,
}


return Logic
