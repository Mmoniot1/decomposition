--By Mmoniot

local pcall = pcall
local xpcall = xpcall
local setfenv = setfenv
local error = error


local SafeGlobals = {
	_VERSION = _VERSION,
	type = type,
	math = math, tonumber = tonumber, bit32 = bit32,
	string = string, tostring = tostring,
	table = table, next = next, pairs = pairs, ipairs = ipairs,
	setmetatable, getmetatable = getmetatable, newproxy = newproxy,
	rawset = rawset, rawget = rawget, rawequal = rawequal,
	coroutine = coroutine,
	error = error, pcall = pcall, xpcall = xpcall,
}



local function CopyTo(tab, from)
	for i, v in pairs(from) do
		if type(v) == 'table' then
			tab[i] = {}
			CopyTo(tab[i], v)
		else
			tab[i] = v
		end
	end
end

local function ScriptError(message)
	return message
end


local Exec = {}

function Exec.Sandbox(chunk, sandbox)
	local env = {}
	CopyTo(env, SafeGlobals)
	CopyTo(env, sandbox)
	env._G = env
	setfenv(chunk, env)
	local is, message = xpcall(chunk, ScriptError)
	if not is then
		error(message)
	end
end


return Exec
