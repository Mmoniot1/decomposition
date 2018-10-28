--By Mami
local Console = require'Console'
local love = require'love'
local Display = require'lib/Display'
local Logic = require'lib/Logic'
local Out = require'lib/Output'
local World = require'lib/World'
local Gui = require'lib/Gui'
local Controller = require'lib/Controller'


local get_delta = love.timer.getDelta
local get_time = love.timer.getTime
local step_time = love.timer.step


local INITSTATE
local RENDER_DATA

local function tilemap_from_str(str)
	local map = World.map_new()
	local it = string.gmatch(str, '[^\t]')
	local x = 0
	local y = 0
	for c in it do
		-- Console.print(i, ': ', c)
		if c == '-' then
			World.set_tile(map, x, y, World.TILE_PLATFORM)
		elseif c == '=' then
			World.set_tile(map, x, y, World.TILE_HATCH)
		elseif c == '^' then
			World.set_tile(map, x, y, World.TILE_LADDER)
		elseif c == '.' then
			World.set_tile(map, x, y, World.TILE_EMPTY)
		elseif c == '\n' then
			x = -1
			y = y + 1
		end
		x = x + 1
	end
	return map
end

local function init()
	love.keypressed = nil
	love.textinput = nil
	love.wheelmoved = nil
	Display.init()

	local world = World.new()
	for mX = 0, 0 do
		for mY = 0, 0 do
			local map = tilemap_from_str([[
				+++++++++++++++++++
				+^.......----.....+
				+^=---++++.+......+
				+^^........+---++++
				+^^....-...+...=..+
				+^^....^...^...^..+
				+^^....^...^...^..+
				+--=...--..^-.=---+
				+..^.......^..^...+
				+..----=-..-..^...+
				+....--^--..--=-..+
				+-..--.^.--...^...+
				+-.--..^..--..^...+
				+--+++++++---++===+
				+--............^^.+
				+++++++++++++++++++
			]])
			World.set_map(world, mX, mY, map)
		end
	end

	INITSTATE = {
		chara_table = {
			[0] = {
				health = 100,
				sx = 14,
				sy = 24,
				x = 200,
				y = 264,
				plat_state = 0,
				walk_speed = 0,
				fall_time = 0,
				jump_time = 0,
				hang_cool = 0,
			},
			[1] = {
				health = 100,
				sx = 32,
				sy = 32,
				x = 158,
				y = 256,
			}
		},
		world = world,
		active_characters = {
		},
		time = 0,
		game = {
			player_combat = {
				stage = 0,
				cur_select = 1,
				cur_menu = 1,
			},
			input = {
				[Controller.LEFT] = -1,
				[Controller.RIGHT] = -1,
				[Controller.UP] = -1,
				[Controller.DOWN] = -1,
				[Controller.ACT] = -1,
				[Controller.SHIFT] = -1,
			},
		},
		combats = {
			[0] = {
				to_party = {},
				to_selection = {},
				to_action = {},
				order = {},
			},
		},
	}

	RENDER_DATA = Out.init(INITSTATE)
end

local KEY_UP = 'w'
local KEY_DOWN = 's'
local KEY_LEFT = 'a'
local KEY_RIGHT = 'd'
local KEY_ACT = 'space'
local KEY_PROMPT = 'escape'


local function Update()
	local inputs = {
		player = {
			[Controller.LEFT]  = love.keyboard.isScancodeDown(KEY_LEFT),
			[Controller.RIGHT] = love.keyboard.isScancodeDown(KEY_RIGHT),
			[Controller.UP]    = love.keyboard.isScancodeDown(KEY_UP),
			[Controller.DOWN]  = love.keyboard.isScancodeDown(KEY_DOWN),
			[Controller.ACT]   = love.keyboard.isScancodeDown(KEY_ACT),
		},
	}
	-- error()
	Logic.update(INITSTATE, inputs)
end
local function Render(dt)
	love.graphics.clear(Gui.BLACK)
	Out.render(INITSTATE, RENDER_DATA, dt)
	love.graphics.origin()
	Console.draw()--<--
	love.graphics.present()
end

local MAX_FPS = 60
local MIN_FPS = 5
local MIN_SPF = 1/MAX_FPS
local MAX_SPF = 1/MIN_FPS

local function run(x)
	init()
	step_time()

	local sleep_time = 0
	local last_render = get_time()

	local prompt_key = false
	local prompt_is_open = false
	while true do
		local exit_code = Console.pump()
		if exit_code then
			return exit_code
		end

		if love.keyboard.isScancodeDown(KEY_PROMPT) then
			if not prompt_key then
				prompt_key = true
				if prompt_is_open then
					prompt_is_open = false
					Console.prompt_close()
					love.keypressed = nil
					love.textinput = nil
					love.wheelmoved = nil
				else
					prompt_is_open = true
					Console.prompt_open()
					love.keypressed = Console.prompt_key_pressed
					love.textinput = Console.prompt_text_input
					love.wheelmoved = Console.prompt_scroll
				end
			end
		elseif prompt_key then
			prompt_key = false
		end
		if not prompt_is_open then
			Update()
		end

		if love.graphics.isActive() then
			local time = get_time()
			local last_render_dt =  time - last_render
			local buffer_overflow = sleep_time < -MIN_SPF
			local min_fps_exceeded = last_render_dt > MAX_SPF
			if not buffer_overflow or min_fps_exceeded then
				if min_fps_exceeded then
					sleep_time = 0
					Console.log('main_loop', 'min_fps_exceeded')
				end
				last_render = time
				Render(last_render_dt)
			else
				-- Console.log('main_loop', 'buffer overflow!')
				-- Console.log('main_loop', 'frame skipped!', sleep_time, get_delta())
			end
		end
		step_time()
		local frame_time = get_delta()
		sleep_time = sleep_time + MIN_SPF - frame_time
		if sleep_time > 0 then
			love.timer.sleep(sleep_time)-- EPSILON)
		end
	end
end



run()
