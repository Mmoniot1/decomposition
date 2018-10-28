--By Mmoniot
local love = require'love'
local Console = require'Console'
local World = require'lib/World'
local Display = require'lib/Display'
local lg = require'love.graphics'
local Graphics = require'graphics/init'
local Player_combat = require'lib/Player_combat'
local Gui = require'lib/Gui'
local Combat_acts = require'lib/Combat_acts'

local math = math
local ceil = math.ceil


local UNITSPERTILE = World.UNITSPERTILE
local TILESPERMAP = World.TILESPERMAP
local UNITSPERMAP = UNITSPERTILE*TILESPERMAP
-- local MAXUNITWIDTH = 3*UNITSPERTILE*TILESPERMAP/4
-- local MAXUNITHEIGHT = 9*UNITSPERTILE*TILESPERMAP/16
-- local PixelsPerUnit = 1
-- -- local PixelsPerTile = PixelsPerUnit*UNITSPERTILE
-- -- local PixelsPerMap = PixelsPerTile*TILESPERMAP
--
-- local ScreenSize_X, ScreenSize_Y = 200, 300


local function record_entity(state, entity)
	Console.record('Position', '<'..entity.x..', '..entity.y..'>')
	Console.record('State', entity.plat_state)
	Console.record('walk_speed', entity.walk_speed)
	Console.record('Health', entity.health)
end
local function debug_info(state, player, dt)
	-- local fps = love.timer.getFPS()
	Console.record('FPS', math.floor(1/dt + .5))
	record_entity(state, player)
end

local Out = {}


local Tile_to_dev_block = {
	-- [World.TILE_EMPTY]    = Graphics.dev_blocks_empty,
	[World.TILE_LADDER]   = Graphics.dev_blocks_ladder,
	[World.TILE_WALL]     = Graphics.dev_blocks_wall,
	[World.TILE_PLATFORM] = Graphics.dev_blocks_platform,
	[World.TILE_HATCH]    = Graphics.dev_blocks_hatch,
}

function Out.init(state)
	local render_data = {
		maps = {},
		combat = {
			menu = {},
			menu_select = {},
			menu_text_attack = {},
			menu_text_defend = {},
			menu_text_escape = {},
			menu_text_fight = {},
		},
	}

	-- Gui.set_parent
	local world = state.world
	for k, map in pairs(world) do
		local map_batch = lg.newSpriteBatch(Graphics.dev_blocks, TILESPERMAP*TILESPERMAP, 'static')
		for y = 0, TILESPERMAP - 1 do
			local w = TILESPERMAP*y
			for x = 0, TILESPERMAP - 1 do
				local tile = map[w + x] or 0
				local quad = Tile_to_dev_block[tile]
				if quad then
					map_batch:add(quad, UNITSPERTILE*x, UNITSPERTILE*y, 0, 1, 1)--<--
				end
			end
		end
		render_data.maps[k] = map_batch
	end

	Gui.set_font(Graphics.font_noto_mono)

	return render_data
end


function Out.map_batch_update(state, map_batch, map)

end


local frame_times = {}
local frame_i = 1
local ave_spf = 0
for i = 1, 64 do
	frame_times[i] = 0
end
function Out.render(state, render_data, dt)
	local player = state.chara_table[0]
	local world = state.world

	Gui.screen_origin()
	Gui.screen_center()
	Gui.screen_trans(-math.floor(player.x), -math.floor(player.y))

	-- lg.translate(ScreenSize_X/2 - PixelsPerUnit*player.X, ScreenSize_Y/2 - PixelsPerUnit*player.Y)
	for k, tilemap in pairs(world) do
		lg.draw(render_data.maps[k], UNITSPERMAP*tilemap.x, UNITSPERMAP*tilemap.y, 0)
	end

	Gui.set_color(Gui.MAGENTA)
	for i = 0, #state.chara_table do
		local entity = state.chara_table[i]
		lg.rectangle('fill', entity.x, entity.y, entity.sx, entity.sy)
	end


	Gui.screen_origin()

	local menu = {
		x = 30,
		y = Display.screen_sy - 130,
		sx = Display.screen_sx - 60,
		sy = 100,
	}
	local metadata = state.game.player_combat
	if metadata.stage == Player_combat.STAGE_PLAYER_TURN then
		Gui.set_color(Gui.GRAY, .5)
		Gui.draw_box(menu, false)
		local frame = {
			x = 20,
			y = 20,
		}
		Gui.set_parent(frame, menu)
		if metadata.cur_menu == 1 then
			-- Gui.set_parent(menu_text_attack, frame)
			-- Gui.set_parent(menu_text_defend, frame)
			-- Gui.draw_text(menu_text_attack)
			Gui.set_color(Gui.WHITE)
			love.graphics.print('attack', frame.x, frame.y)
			love.graphics.print('defend', frame.x, frame.y + 16)
			love.graphics.print('escape', frame.x, frame.y + 16*2)
		else
			Gui.set_color(Gui.WHITE)
			love.graphics.print('commit', frame.x, frame.y)
		end
		local menu_select = {
			x = -4,
			y = 16*metadata.cur_select - 19,
			sx = 100,
			sy = 15,
		}
		Gui.set_parent(menu_select, frame)
		Gui.draw_box(menu_select, true)

		-- lg.setColor(127, 127, 127, 192)
		-- lg.rectangle('fill', 30, Display.screen_sy - 200, Display.screen_sx - 60, 170)
		-- lg.setColor(255, 255, 255, 255)
		-- lg.rectangle('line', 40, Display.screen_sy - 190 + 20*metadata.cur_select, 300, 20)
		-- lg.printf('attack', 40, Display.screen_sy - 190 + 20*metadata.cur_select, 300)
	elseif metadata.stage == Player_combat.STAGE_COMBAT then
		local combat_data = state.combats[0]
		local actor_pid = combat_data.order[combat_data.turn]
		local action_id = combat_data.to_selection[actor_pid]
		local action = combat_data.to_action[actor_pid]
		if action_id > 0 then
			Gui.screen_center()
			Combat_acts[action_id].render(state, combat_data, action, actor_pid)
		end
	end
	Gui.screen_origin()
	Gui.set_color(Gui.WHITE)
	-- lg.origin()
	-- lg.setColor(255, 255, 255, 255)
	-- Console.draw()
	frame_i = frame_i%64 + 1
	ave_spf = ave_spf + (dt - frame_times[frame_i])
	frame_times[frame_i] = dt
	debug_info(state, player, ave_spf/64)
end




return Out
