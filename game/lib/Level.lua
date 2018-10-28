--By Mami
local Console = require'Console'
local ld = require'love.data'
local World = require'lib/World'

local pairs = pairs

local Level = {}

local function pack_int(x)
	return ld.pack('string', '<i4', x)
end
local function unpack_int(str, pos)
	return ld.unpack('<i4', str, pos)
end
Level.pack_int = pack_int
Level.unpack_int = unpack_int

function Level.serialize_world(world)
	local str = ''
	local total_maps = 0
	for _, map in pairs(world) do
		local map_str = ''
		local is_empty = true
		map_str = map_str..pack_int(map.x)..pack_int(map.y)
		for y = 0, World.TILESPERMAP - 1 do
			for x = 0, World.TILESPERMAP - 1 do
				local tile = World.get_tile(map, x, y)
				if tile ~= World.TILE_NULL then
					is_empty = false
				end
				map_str = map_str..ld.pack('string', '<i1', tile)
			end
		end
		if not is_empty then
			str = str..map_str
			total_maps = total_maps + 1
		end
	end
	return pack_int(total_maps)..str
end
function Level.deserialize_world(str, pos)
	local world = {}
	local total_maps = unpack_int(str, pos)
	local cur_pos = pos + 4
	for _ = 1, total_maps do
		local map = {}
		local map_x = unpack_int(str, cur_pos)
		local map_y = unpack_int(str, cur_pos + 4)
		cur_pos = cur_pos + 8
		for y = 0, World.TILESPERMAP - 1 do
			for x = 0, World.TILESPERMAP - 1 do
				World.set_tile(map, x, y, ld.unpack('<i1', str, cur_pos))
				cur_pos = cur_pos + 1
			end
		end
		World.set_map(world, map_x, map_y, map)
	end
	return world, cur_pos
end

function Level.compress_markers(to_marker, marker_sets)
	local to_new_pid = {}
	local highest_pid = 0
	local total_markers = 0
	for pid, _ in pairs(to_marker) do
		total_markers = total_markers + 1
		if highest_pid < pid then
			highest_pid = pid
		end
	end
	local str = pack_int(total_markers)
	local new_pid = 1
	for pid = 1, highest_pid do
		local marker = to_marker[pid]
		if marker then
			to_new_pid[pid] = new_pid
			str = str..pack_int(marker.x)..pack_int(marker.y)
			str = str..pack_int(string.len(marker.name))..marker.name
			new_pid = new_pid + 1
		end
	end
	local sets_str = ''
	local total_sets = 0
	for k, set in pairs(marker_sets) do
		if #set > 0 then
			sets_str = sets_str..pack_int(#set)
			sets_str = sets_str..pack_int(k)
			for i = 1, #set do
				sets_str = sets_str..pack_int(to_new_pid[set[i]])
				total_sets = total_sets + 1
			end
		end
	end
	str = str..pack_int(total_sets)..sets_str
	return str
end
function Level.decompress_markers(str, pos)
	local total_markers = unpack_int(str, pos)
	local to_marker = {}
	local marker_sets = {}
	local cur_pos = pos + 4
	for i = 1, total_markers do
		local marker = {
			pid = i,
			x = unpack_int(str, cur_pos),
			y = unpack_int(str, cur_pos + 4),
		}
		local name_size = unpack_int(str, cur_pos + 8)
		local name_end = cur_pos + 12 + name_size
		marker.name = string.sub(str, cur_pos + 12, name_end - 1)
		to_marker[i] = marker
		cur_pos = name_end
	end
	local total_sets = unpack_int(str, cur_pos)
	cur_pos = cur_pos + 4
	for _ = 1, total_sets do
		local set = {}
		local set_size = unpack_int(str, cur_pos)
		local set_key = unpack_int(str, cur_pos + 4)
		cur_pos = cur_pos + 8
		for i = 1, set_size do
			set[i] = unpack_int(str, cur_pos)
			cur_pos = cur_pos + 4
		end
		marker_sets[set_key] = set
	end
	return to_marker, marker_sets, cur_pos
end


function Level.serialize_level(world, to_marker, marker_sets)
	local world_str = Level.serialize_world(world)
	local marker_str = Level.compress_markers(to_marker, marker_sets)
	return world_str..marker_str
end
function Level.deserialize_level(str, pos)--markers off the map get abandonned
	local world, cur_pos = Level.deserialize_world(str, pos)
	local to_marker, marker_sets
	to_marker, marker_sets, cur_pos = Level.decompress_markers(str, cur_pos)
	for key, _ in pairs(world) do
		if not marker_sets[key] then
			marker_sets[key] = {}
		end
	end
	return world, to_marker, marker_sets, cur_pos
end


return Level
