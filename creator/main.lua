--By Mami
local GAME = 'game'
local Console = require'Console'
local love = require'love'
local Display = Console.require(GAME, 'lib/Display')
local Builder = require'lib/Builder'
-- local Logic = require'lib/Logic'
local Out = Console.require(GAME, 'lib/Output')
local World = Console.require(GAME, 'lib/World')
local Gui = Console.require(GAME, 'lib/Gui')
local Controller =  require'lib/C_Controller'


local get_delta = love.timer.getDelta
local get_time = love.timer.getTime
local step_time = love.timer.step


local INITSTATE
local RENDER_DATA


local function save(file_name)
	file_name = file_name..'.mamb'
	local data = Builder.serialize_build(INITSTATE)
	local file_info = love.filesystem.getInfo(file_name, 'file')
	local is, err
	if file_info then
		is, err = love.filesystem.write(file_name, data)
	else
		local file = love.filesystem.newFile(file_name, 'w')
		is, err = file:write(data)
	end
	if is then
		Console.log('level_creator', 'file created at '..love.filesystem.getSaveDirectory()..'/'..file_name)
	else
		Console.error('level_creator', 'there was an error attempting to save the file: '..err)
	end
end
local function load(file_name)
	file_name = file_name..'.mamb'
	local data, size = love.filesystem.read(file_name)
	if data then
		INITSTATE = Builder.deserialize_build(data, 1)
	else
		Console.error('level_creator', 'there was an error attempting to read file at \"'..file_name..'\": '..size)
	end
end

local function init()
	love.keypressed = nil
	love.textinput = nil
	love.wheelmoved = nil
	Controller.connect_to_wheel()
	Console.add_command('save', 'save <file_name>', function(fields)
		save(fields[2])
	end)
	Console.add_command('load', 'load <file_name>', function(fields)
		load(fields[2])
	end)
	-- Console.source_add_command('export', 'export <file_name>', Console.command_forward_arg(export))


	local x, y = love.graphics.getDimensions()
	Display.window_resize(x, y)
	love.resize = function(sx, sy)
		Display.window_resize(sx, sy)
	end

	INITSTATE = Builder.new_state()

	RENDER_DATA = Out.init(INITSTATE)
end

local KEY_PROMPT = 'escape'


local Text_prompt = {
	characters = '',
	control = '',
}
local function text_inputed(c)
    Text_prompt.characters = Text_prompt.characters..c
end
local function key_pressed(key)
	Console.print(key)
    if key == "backspace" or key == 'return' or key == 'left' or key == 'right' then
		Text_prompt.control = key
    end
end

local function Update()
	local state = INITSTATE
	if state.dev.is_typing then
		Builder.update(state, Text_prompt)
		Text_prompt.characters = ''
		Text_prompt.control = ''
	else
		Builder.update(state, Controller.get_input())
		if state.dev.is_typing then
			love.keypressed = key_pressed
			love.textinput = text_inputed
			Text_prompt.characters = ''
			Text_prompt.control = ''
		end
	end
end
local function Render(dt)
	love.graphics.clear(Gui.GRAY)
	Builder.render(INITSTATE, RENDER_DATA, dt)
	love.graphics.origin()
	Console.draw()
	love.graphics.present()
end

local MAX_FPS = 60
local MIN_FPS = 5
local MIN_SPF = 1/MAX_FPS
local MAX_SPF = 1/MIN_FPS

local function run()
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
			end
		end
		step_time()
		local frame_time = get_delta()
		Console.record('FPS', 1/frame_time)
		sleep_time = sleep_time + MIN_SPF - frame_time
		if sleep_time > 0 then
			love.timer.sleep(sleep_time)-- EPSILON)
		end
	end
end


run()
