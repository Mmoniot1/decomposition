--By mami
local Chara_static = require'lib/Chara_static'
local Act_table = require'lib/Combat_acts'
local Controller = require'lib/Controller'

local STAGE_NIL = 0
local STAGE_INIT = 1
local STAGE_PLAYER_TURN = 2
local STAGE_ENEMY_TURN = 3
local STAGE_INIT_COMBAT = 4
local STAGE_COMBAT = 5


local function player_combat(state, metadata)
	local cur_select = metadata.cur_select
	--<--combat states
	--lets just do two menus, attack, defend, escape on one, commit on the other
	if metadata.stage == STAGE_NIL then
		return false
	end
	local combat_data = state.combats[0]
	if metadata.stage == STAGE_INIT then
		combat_data.order[1] = 0
		combat_data.order[2] = 1
		combat_data.to_party[0] = 0
		combat_data.to_party[1] = 1
		for i = 1, #combat_data.order do
			local pid = combat_data.order[i]
			combat_data.to_selection[pid] = 0
			combat_data.to_action[pid] = {}--<--
		end
		metadata.cur_select = 1
		metadata.cur_menu = 1
		metadata.con_cooldown = 0
		metadata.stage = STAGE_PLAYER_TURN
	elseif metadata.stage == STAGE_PLAYER_TURN then
		if Controller.just_down(state.game.input, Controller.ACT, state.time) then
			if metadata.cur_menu == 1 then
				if metadata.cur_select == 1 then
					combat_data.to_selection[0] = 1
					combat_data.to_action[0].target_pid = 1
					metadata.cur_menu = 2
					metadata.cur_select = 1
				elseif metadata.cur_select == 2 then
					combat_data.to_selection[0] = 0
					metadata.cur_menu = 2
					metadata.cur_select = 1
				elseif metadata.cur_select == 3 then--immediately end combat
					combat_data.to_selection[0] = -1
					metadata.stage = STAGE_NIL
					--<--make player jump
				end
			elseif metadata.cur_menu == 2 then
				if metadata.cur_select == 1 then
					metadata.stage = STAGE_ENEMY_TURN
				end
			end
		elseif metadata.con_cooldown < state.time then
			local con = Controller.top_dpad(state.game.input)
			if con > 0 then
				if con == Controller.UP then
					if metadata.cur_menu == 1 then
						if metadata.cur_select > 1 then
							metadata.cur_select = metadata.cur_select - 1
						end
					end
				elseif con == Controller.DOWN then
					if metadata.cur_menu == 1 then
						if metadata.cur_select < 3 then
							metadata.cur_select = metadata.cur_select + 1
						end
					end
				elseif con == Controller.LEFT then
					if metadata.cur_menu > 1 then
						metadata.cur_menu = metadata.cur_menu - 1
						metadata.cur_select = 1
					end
				elseif con == Controller.RIGHT then
					if metadata.cur_menu < 2 then
						metadata.cur_menu = metadata.cur_menu + 1
						metadata.cur_select = 1
					end
				end
				metadata.con_cooldown = state.time + 10
			end
		end
	elseif metadata.stage == STAGE_ENEMY_TURN then--do enemy ai
		--for now, lets just always attack
		for pid, party in pairs(combat_data.to_party) do
			if party ~= 0 then--if they aren't in the player's party
				combat_data.to_selection[pid] = 1--<--.enemy
				combat_data.to_action[pid].target_pid = 0
			end
		end
		metadata.stage = STAGE_INIT_COMBAT
	elseif metadata.stage == STAGE_INIT_COMBAT then
		combat_data.turn = 1
		for i = 1, #combat_data.order do
			local actor_pid = combat_data.order[i]
			local action_id = combat_data.to_selection[actor_pid]
			local action = combat_data.to_action[actor_pid]
			Act_table[action_id].init(state, combat_data, action)
		end
		metadata.stage = STAGE_COMBAT
	elseif metadata.stage == STAGE_COMBAT then
		local actor_pid = combat_data.order[combat_data.turn]
		local action_id = combat_data.to_selection[actor_pid]
		local action = combat_data.to_action[actor_pid]
		Act_table[action_id].run(state, combat_data, action, actor_pid)
		if combat_data.turn > #combat_data.order then
			metadata.stage = STAGE_INIT
		end
	end
	return true
end


local combat = {
	STAGE_NIL = STAGE_NIL,
	STAGE_INIT = STAGE_INIT,
	STAGE_PLAYER_TURN = STAGE_PLAYER_TURN,
	STAGE_ENEMY_TURN = STAGE_ENEMY_TURN,
	STAGE_INIT_COMBAT = STAGE_INIT_COMBAT,
	STAGE_COMBAT = STAGE_COMBAT,
}

combat.run = player_combat


return combat
