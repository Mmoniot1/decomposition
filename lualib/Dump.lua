--By Mmoniot

local math = math
local tostring = tostring
local pairs = pairs
local type = type
local error = error


local Dump = {
	EPSILON = 2^-9,
	EPSILON2 = 2^-8,
}

function Dump.lerp(n0, n1, t)
	return n0 + (n1 - n0)*t
end


function Dump.null() end
function Dump.echo(x) return x end
function Dump.echoall(...) return ... end

function Dump.copy(tab0, tab1)
	for i, v in pairs(tab0) do
		tab1[i] = v
	end
	return tab1
end
function Dump.clear(tab)
	for k, _ in pairs(tab) do
		tab[k] = nil
	end
end

function Dump.new_immutable(tab)
	tab.__index = tab
	tab.__metatable = true
	local rep = {}
	setmetatable(rep, tab)
	return rep
end


local ToCheck do
	ToCheck = {
		positive = function(x)
			return type(x) == 'number' and x > 0
		end,
		nonnegative = function(x)
			return type(x) == 'number' and x >= 0
		end,
		int = function(x)
			return type(x) == 'number' and x%1 == 0
		end,
	}
	for _, v in pairs{'nil', 'string', 'number', 'boolean', 'function', 'table', 'userdata'} do
		ToCheck[v] = function(x)
			return type(x) == v
		end
	end
end

function Dump.torepr(x)
	local str = tostring(x)
	local t = type(x)
	if str and str ~= '' then
		-- if t == 'string' then
		-- 	return x..'('..t..')'
		-- else
			return str
		-- end
	else
		return type(x)
	end
end
function Dump.message(sep, ...)
	if type(sep) ~= 'string' then
		sep = ''
	end
	local args = {...}
	local msg
	if type(args[1]) == 'string' then
		msg = args[1]
	else
		msg = Dump.torepr(args[1])
	end
	for i = 2, #args do
		if type(args[i]) == 'string' then
			msg = msg..sep..args[i]
		else
			msg = msg..sep..Dump.torepr(args[i])
		end
	end
	return msg
end
function Dump.printtab(x)
	local str = '{'
	local is = true
	for i, v in pairs(x) do
		if is then
			is = false
			str = str..Dump.torepr(i)..' = '..Dump.torepr(v)
		else
			str = str..', '..Dump.torepr(i)..' = '..Dump.torepr(v)
		end
	end
	str = str..'}'
	return str
end

function Dump.parse_fields(str)
	local it = string.gmatch(str, '.')
	local fields = {}
	local cur_field = ''
	local total = 0
	local isnt_empty = false
	for c in it do
		if c == ' ' or c == '\t' then
			if isnt_empty then
				total = total + 1
				fields[total] = cur_field
				isnt_empty = false
				cur_field = ''
			end
		elseif c == '\n' then
			break
		else
			cur_field = cur_field..c
			isnt_empty = true
		end
	end
	if isnt_empty then
		total = total + 1
		fields[total] = cur_field
	end
	return fields
end


function Dump.argerror(level, expected, got, num)
	local str = 'Invalid arg '..num..': got '..Dump.torepr(got)
	if expected then
		if type(expected) == 'table' then
			local tab = expected
			expected = tab[1]
			for i = 2, #tab - 1 do
				expected = expected..', '..tab[i]
			end
			if #tab > 1 then
				expected = expected..' or '..tab[#tab]
			end
		end
		str = str..', expected '..expected
	end
	error(str, level)
end
function Dump.assertarg(level, expected, got, num)
	if type(expected) == 'string' then
		if not ToCheck[expected](got) then
			Dump.argerror(level + 1, expected, got, num)
		end
	elseif type(expected) == 'table' then
		local is = true
		for j = 1, #expected do
			if ToCheck[expected[j]](got) then
				is = false
				break
			end
		end
		if is then
			Dump.argerror(level + 1, expected, got, num)
		end
	elseif not expected then
		Dump.argerror(level + 1, nil, got, num)
	end
end
function Dump.assertall(level, ...)
	local args = {...}
	for i = 1, #args, 2 do
		Dump.assert(level + 1, args[i], args[i + 1], (i + 1)/2)
	end
end
function Dump.createassertall(level, argtypes)
	return function(...)
		local args = {...}
		for i = 1, math.max(#args, #argtypes) do
			Dump.assert(level + 1, args[i], argtypes[i], i)
		end
	end
end





return Dump
