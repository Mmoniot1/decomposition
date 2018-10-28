--By Mami
local Dump = require'lualib/Dump'
local love = require'love'
local utf8 = require'utf8'
local lf = require'love.filesystem'
local lt = require'love.timer'
local lg = love.graphics


local COLORS = {
	[0] = {15/16, 15/16, 15/16},
	[1] = {15/16, 15/16, 0},
	[2] = {15/16, 1/16, 1/16},
	[3] = {11/16, 11/16, 11/16},
}
local CONSOLE_COMMAND_OFF = 8
local TIME_STR_SIZE = 8
local LOG_MAX = 2^9
local FONT = lg.newFont('NotoMono.ttf', 12)

local xpcall = xpcall
local unpack = unpack
local pairs = pairs
local type = type
local tostring = tostring
local require = require
local table = table
local luadebug = debug
local date = os.date
local string = string
local math = math

local get_some_time = lt.getTime
local Console_origin_time

local function get_time()
    return get_some_time() - Console_origin_time
end


local Console = {}
local Log_update_draw = false
local Command_update_draw = false
local Record_update_draw = false
local Console_cur_source = 'Console'
local Console_program_level = 0
local Console_desired_level = 0
local Console_exit_arg = nil
local Commands = {}
local Program_commands = {}
local Command_help_strs = {}
local Program_help_strs = {}
local Next_program = nil
local Next_source = nil

local Log = {}
local Log_flags = {}
local Log_sources = {}
local Log_times = {}
local Log_latest = 0
local Log_size = 0
local Record = {}

local Log_text = lg.newText(FONT)
local Record_text = lg.newText(FONT)
local Command_text = lg.newText(FONT)
local LOG_TEXT_HEIGHT = 14
local COMMAND_TEXT_HEIGHT = 14

local Console_x = 2
local Console_y = 2
local Console_sx = 600
local Console_sy = 595
local Command_str = ''
local Log_first_display_entry = 0
local Console_prompt_open = false


local function Log_add_entry(text, source, flag)
	Log_update_draw = true
	Log_latest = Log_latest%LOG_MAX + 1
	Log_size = math.min(Log_size + 1, LOG_MAX)
	Log[Log_latest] = text
	Log_flags[Log_latest] = flag
	Log_sources[Log_latest] = source
	Log_times[Log_latest] = get_time()
end
local function Log_clear()
	Log_update_draw = true
	for i = 1, Log_size do
		Log[i] = nil
		Log_flags[i] = nil
		Log_sources[i] = nil
		Log_times[i] = nil
	end
	Log_latest = 0
	Log_size = 0
	Log_first_display_entry = 0
	Log_add_entry('Cleared', 'Console', 3)
end
local function Record_update(name, value)
	Record_update_draw = true
	Record[name] = value
end
local function Record_clear()
	Record_update_draw = true
	Dump.clear(Record)
end

function Console.prompt_open()
	Console_prompt_open = true
	Command_update_draw = true
end
function Console.prompt_close()
	Console_prompt_open = false
	Command_str = ''
	Command_update_draw = true
end
function Console.prompt_scroll_down()
	if Log_first_display_entry > 0 then
		Log_first_display_entry = Log_first_display_entry - 1
	end
end
function Console.prompt_scroll_up()
	if Log_first_display_entry < Log_size - 1 then
		Log_first_display_entry = Log_first_display_entry + 1
	end
end
function Console.prompt_text_input(c)
	Command_update_draw = true
    Command_str = Command_str..c
end
function Console.prompt_scroll(_, y)
	-- Console.print(y)
	if y > 0 then
		-- Console.print(y)
		-- for _ = 1, y do
			Console.prompt_scroll_up()
		-- end
	elseif y < 0 then
		-- for _ = 1, -y do
			Console.prompt_scroll_down()
		-- end
	end
end
function Console.prompt_key_pressed(key)
    if key == "backspace" then
        -- get the byte offset to the last UTF-8 character in the string.
        local byteoffset = utf8.offset(Command_str, -1)

        if byteoffset then
            -- remove the last UTF-8 character.
            -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
            Command_str = string.sub(Command_str, 1, byteoffset - 1)
			Command_update_draw = true
        end
	elseif key == 'return' then
		Log_first_display_entry = 0
		local str = Command_str
		Command_str = ''
		Command_update_draw = true
		Console.command(str)
    end
end

function Console.set_frame(x, y, sx, sy)
	Console_x = x
	Console_y = y
	Console_sx = sx
	Console_sy = sy
	Command_update_draw = true
end
function Console.draw()
	if Log_update_draw then
		Log_update_draw = false

		local i = Log_latest%LOG_MAX + 1
		while not Log[i] do
			i = i%LOG_MAX + 1
		end
		local full_text_i = 0
		local full_text = {}
		local cur_flag
		do
			local item = Log[i]
			local flag = Log_flags[i]
			local source = Log_sources[i]
			local time = Log_times[i]
			local sec = string.format('%0.6f', time)
			if #sec > TIME_STR_SIZE then
				sec = string.sub(sec, 1, TIME_STR_SIZE)
			end
			local text = sec..' '..source..': '..item..'\n'
			cur_flag = flag
			full_text_i = full_text_i + 2
			full_text[full_text_i - 1] = COLORS[flag]
			full_text[full_text_i] = text
		end
		while i ~= Log_latest do
			i = i%LOG_MAX + 1
			local item = Log[i]
			local flag = Log_flags[i]
			local source = Log_sources[i]
			local time = Log_times[i]
			local sec = string.format('%0.6f', time)
			if #sec > TIME_STR_SIZE then
				sec = string.sub(sec, 1, TIME_STR_SIZE)
			end
			local text = sec..' '..source..': '..item..'\n'
			if cur_flag ~= flag then
				cur_flag = flag
				full_text_i = full_text_i + 2
				full_text[full_text_i - 1] = COLORS[flag]
				full_text[full_text_i] = text
			else
				full_text[full_text_i] = full_text[full_text_i]..text
			end
		end
		-- error(full_text[1][1]..full_text[1][2]..full_text[1][3]..full_text[2])
		Log_text:setf(full_text, Console_sx, 'left')
	end
	if Command_update_draw then
		Command_update_draw = false
		Command_text:setf(Command_str..'|', Console_sx, 'left')
	end
	if Record_update_draw then
		local str = ''
		local is = true
		for k, v in pairs(Record) do
			if is then
				is = false
				str = k..' = '..v
			else
				str = str..'\n'..k..' = '..v
			end
		end
		Record_text:setf(str, Console_sx/2, 'left')
	end

	local log_text_height = Log_text:getHeight() + 2
	local log_height = Console_sy
	if Log_first_display_entry > 0 then
		log_height = log_height - LOG_TEXT_HEIGHT
	end
	if Command_str ~= '' or Console_prompt_open then
		local command_text_sy = Command_text:getHeight()
		log_height = log_height - COMMAND_TEXT_HEIGHT - CONSOLE_COMMAND_OFF
		lg.setColor(0, 0, 0, .8)
		lg.rectangle('fill', Console_x, Console_sy - COMMAND_TEXT_HEIGHT - 3, Console_sx, COMMAND_TEXT_HEIGHT + 3)
		lg.setColor(0, 0, 0, .4)
		lg.rectangle('fill', Console_x, Console_y, Console_sx, log_height)
		lg.setColor(1, 1, 1, .9)
		lg.draw(Command_text, Console_x, Console_sy - COMMAND_TEXT_HEIGHT - 2)
	end
	lg.setColor(1, 1, 1, .9)
	lg.draw(Record_text, Console_x + Console_sx, Console_y)
	lg.setScissor(Console_x, Console_y, Console_sx, log_height)
	lg.draw(Log_text, Console_x, Console_y + log_height - log_text_height + LOG_TEXT_HEIGHT*Log_first_display_entry)
	lg.setScissor()
end


function Console.print(...)
	Log_add_entry(Dump.message(' ', ...), Console_cur_source, 0)
end
function Console.log(source, ...)
	Log_add_entry(Dump.message(' ', ...), source, 3)
end
function Console.warn(source, ...)
	Log_add_entry(Dump.message(' ', ...), source, 1)
end
function Console.error(source, ...)
	Log_add_entry(Dump.message(' ', ...), source, 2)
end
function Console.record(name, value)
	if type(name) == 'string' then
		local str = tostring(value)
		Record_update(name, str or type(value))
	else
		Console.error('Console', 'Attempt to use a non-string value as a record name')
	end
end
function Console.remove_record(name)
	if type(name) == 'string' then
		Record_update(name, nil)
	end
end
Console.record_clear = Record_clear
Console.log_clear = Log_clear


local function debug_exception(message)
	local str = luadebug.traceback(message, 2)
	-- Console.error(message)
	Console.error(Console_cur_source, str)
	return str
end
local function run(source, main)
	local pre_source = Console_cur_source
	local pre_path = lf.getRequirePath()
	Console_cur_source = source
	lf.setRequirePath('?.lua;'..source..'/?.lua')
	local is, _ = xpcall(main, debug_exception)
	lf.setRequirePath(pre_path)
	Console_cur_source = pre_source
	return is
end

function Console.command(command_str)
	local fields = Dump.parse_fields(command_str)
	local command_name = fields[1]
	if command_name then
		local command = Commands[command_name]
		if not command then
			local commands = Program_commands[Console_cur_source]
			if commands then
				command = commands[command_name]
			end
		end
		if command then
			command(fields)
		else
			Console.warn('Console', 'No command named \"'..command_name..'\"; type \"help\" for a list of commands')
		end
	else
		Console.warn('Console', 'Please type a command; type \"help\" for a list of commands')
	end
end
function Console.quit()
	Console_desired_level = Console_program_level - 1
end
function Console.exit()
	Console_desired_level = 0
end

function Console.pump()
	love.event.pump()
	for name, a,b,c,d,e,f in love.event.poll() do
		if name == "quit" then
			Console_exit_arg = a or 0
			Console_desired_level = 0
			return Console_exit_arg
		end
		love.handlers[name](a,b,c,d,e,f)
	end
	if Console_program_level > Console_desired_level then
		return 0
	end
	return false
end
function Console.run(source, main)
	if type(main) == 'function' then
		if type(source) == 'string' then
			Console_desired_level = 1
			Next_program = main
			Next_source = source
		else
			Console.error('Console', 'attempted to run program without a source name')
		end
	else
		Console.error('Console', 'attempted to run a '..type(main)..' value')
	end
end
function Console.run_file(source)
	if not source or source == 'default' then
		source = 'game'
	end
	local name = source..'/main.lua'
	if lf.getInfo(name, 'file') then
		Console.log('Console', 'Running game found at', source)
		local main, errormsg = lf.load(name)--, debugExecption)
		if main then
			Console.run(source, main)
		else
			Console.error(source, errormsg)
			Console.warn('Console', 'Game at '..name..' did not compile')
		end
	else
		Console.warn('Console', 'Game at '..source..' had no /main.lua to execute')
	end
end
function Console.require(source, name)
	local ret = nil
	local _ = run(source, function()
		ret = require(name)
	end)
	return ret
end
function Console.add_command(name, help_str, proc)
	Program_commands[name] = proc
	Program_help_strs[name] = help_str
end

function Console.main()
	Console_origin_time = get_some_time()
	love.keyboard.setKeyRepeat(true)
	Log_add_entry(date('%c'), 'Console', 3)
	love.keypressed = Console.prompt_key_pressed
	love.textinput = Console.prompt_text_input
	love.wheelmoved = Console.prompt_scroll
	Console.prompt_open()

	Console.run_file()
	return function()

		local exit_code = Console.pump()
		if exit_code then
			return exit_code
		end
		if Next_program then
			repeat--execute the new program
				Console.prompt_close()
				Console.record_clear()
				local program = Next_program
				local source = Next_source
				Next_program = nil
				Next_source = nil
				Console_program_level = 2
				Console_desired_level = 2
				exit_code = run(source, program)
				Program_commands = {}
				Program_help_strs = {}
				Console_program_level = 1
				if Console_desired_level == 0 then
					return exit_code
				end
			until Next_program == nil
			Console.prompt_open()
			return
		end

		love.timer.step()
		if lg.isActive() then
			lg.origin()
			lg.clear(lg.getBackgroundColor())

			Console.draw()

			lg.present()
		end

		love.timer.sleep(0.005)
	end
end


do--add default commands
	local function add_command(name, help_str, proc)
		Commands[name] = proc
		Command_help_strs[name] = help_str
	end
	add_command('help', 'help <command_name>', function(fields)
		local name = fields[2]
		if name then
			local help_str = Command_help_strs[name]
			if not help_str then
				help_str = Program_help_strs[name]
			end
			if help_str then
				Console.log('Console', 'Usage: '..help_str)
			else
				Console.log('Console', '\"'..name..'\" is not a valid command')
			end
		else
			local command_names = {}
			local i = 1
			for command_name, _ in pairs(Commands) do
				command_names[i] = command_name
				i = i + 1
			end
			for command_name, _ in pairs(Program_commands) do
				command_names[i] = command_name
				i = i + 1
			end
			table.sort(command_names)
			local help_str = 'list of available commands:\n\t'..table.concat(command_names, ',\n\t')
			Console.log('Console', help_str)
		end
	end)
	add_command('record', 'record <name> <value>', function(fields)
		Record_update(fields[2], fields[3])
	end)
	add_command('echo', 'echo <text>', function(fields)
		Log_add_entry(fields[2], 'User', 0)
	end)
	add_command('clear', 'clear <log:record:all>', function(fields)
		local name = fields[2]
		if name == 'record' then
			Record_clear()
		elseif name == 'all' then
			Record_clear()
			Log_clear()
		else
			Log_clear()
		end
	end)
	add_command('quit', 'quit', Console.quit)
	add_command('exit', 'exit', Console.exit)
	add_command('run', 'run <file_name>', function(fields)
		Console.run_file(fields[2])
	end)
end

return Console
