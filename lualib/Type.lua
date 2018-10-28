--By Mmoniot
local Dump = require'lualib/Dump'

local error = error
local setmetatable = setmetatable
local pairs = pairs


local function CreateType(meta)
	meta.__index = meta
	meta.__metatable = error
	local function new(...)
		local obj = meta.__new and meta.__new(...) or {}
		setmetatable(obj, meta)
		return obj
	end
	return new
end
local function CreateCopy(meta)
	local copy = {}
	for i, v in pairs(meta) do
		copy[i] = v
	end
	return copy
end


local WEAK = {__mode = 'k'}
local ToToRep = {}
setmetatable(ToToRep, WEAK)
local function CreateSecureType(meta)
	local toRep = {}
	setmetatable(toRep, WEAK)
	for i, v in pairs(meta) do
		if type(v) == 'function' then
			meta[i] = function(proxy, ...)
				return v(toRep[proxy], ...)
			end
		end
	end
	meta.__index = meta
	meta.__metatable = error
	local create = meta.__new__
	meta.__new__ = nil
	local new
	if create then
		new = function(...)
			local rep = create(...)
			local proxy = {}
			setmetatable(proxy, meta)
			toRep[proxy] = rep
			return rep
		end
	else
		new = function()
			local rep = {}
			local proxy = {}
			setmetatable(proxy, meta)
			toRep[proxy] = rep
			return rep
		end
	end
	ToToRep[meta] = toRep
	return new
end
local function ExtendSecureType(super, meta)
	local toRep = ToToRep[super]
	for i, v in pairs(meta) do
		if type(v) == 'function' then
			meta[i] = function(proxy, ...)
				return v(toRep[proxy], ...)
			end
		end
	end
	Dump.copy(super, meta)
	meta.__index = meta
	meta.__metatable = error
	local create = meta.__new__
	meta.__new__ = nil
	local new
	if create then
		new = function(...)
			local rep = create(...)
			local proxy = {}
			setmetatable(proxy, meta)
			toRep[proxy] = rep
			return proxy
		end
	else
		new = function()
			local rep = {}
			local proxy = {}
			setmetatable(proxy, meta)
			toRep[proxy] = rep
			return proxy
		end
	end
	return new
end



return {
	new = CreateType,
	newSecure = CreateSecureType,
	extendSecure = ExtendSecureType,
	clone = CreateCopy,
}
