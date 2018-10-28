--By Mami
local GAME = 'game'
local Console = require'Console'
local Dump = require'lualib/Dump'
local World = Console.require(GAME, 'lib/World')
local Level = Console.require(GAME, 'lib/Level')
local Display = Console.require(GAME, 'lib/Display')
local Gui = Console.require(GAME, 'lib/Gui')
local Graphics = Console.require(GAME, 'graphics/init')
local lg = require'love.graphics'
local Con =  require'lib/C_Controller'

local math = math
local string = string
local floor = math.floor


local UNITSPERTILE = World.UNITSPERTILE
local TILESPERMAP = World.TILESPERMAP
local UNITSPERMAP = UNITSPERTILE*TILESPERMAP



local Builder = {}

local INIT_ZOOM = 3
function Builder.new_state()
	local world = World.new()
	return {
		time = 0,
		world = world,
		dev = {
			is_typing = false,
			type_data = {
				text = '',
				bar_pos = 0,
			},
			x = 0,
			y = 0,
			set_in_line = false,
			origin_tile_x = 0,
			origin_tile_y = 0,
			zoom = INIT_ZOOM,
			selection_is_made = false,
			selection_is_making = true,
			selection0_x = 0,
			selection0_y = 0,
			selection1_x = 0,
			selection1_y = 0,
			selected_tile = World.TILE_EMPTY,
			selected_marker = 0,
			highlighted_marker = 0,
			has_moved_marker = false,
			con = Con.new_controller(),
			clipboard_sx = 0,
			clipboard_sy = 0,
			clipboard = {},
		},
		world_update_x = {},
		world_update_y = {},
		world_marker_sets = {},
		to_marker = {},
		marker_cur_pid = 1,
		undo_pages = {},
		undo_volumes = {},--point to first page of volume
		undo_cur_page = 0,--last added in chain
		undo_cur_volume = 0,--last added
	}
end

function Builder.serialize_build(state)
	local str = Level.pack_int(1)..Level.pack_int(state.time)
	str = str..Level.pack_int(state.dev.x)..Level.pack_int(state.dev.y)
	str = str..Level.pack_int(state.dev.zoom)
	str = str..Level.serialize_level(state.world, state.to_marker, state.world_marker_sets)
	return str
end
function Builder.deserialize_build(str, pos)
	local version = Level.unpack_int(str, pos)
	pos = pos + 4
	if version == 1 then
		local state = Builder.new_state()
		state.time = Level.unpack_int(str, pos)
		state.dev.x = Level.unpack_int(str, pos + 4)
		state.dev.y = Level.unpack_int(str, pos + 8)
		state.dev.zoom = Level.unpack_int(str, pos + 12)
		state.world, state.to_marker, state.world_marker_sets = Level.deserialize_level(str, pos + 16)
		state.marker_cur_pid = #state.to_marker + 1
		return state
	else
		return Builder.new_state()
	end
end


local UNDO_ID = {
	TILE_SET = 1,
	MARKER_ADD = 2,
	MARKER_MOVE = 3,
	MARKER_REMOVE = 4,
}

local function new_undo_volume(state)
	--only call in the anticipation of a new undo page
	local next_volume = state.undo_cur_volume + 1
	local next_volume_start = state.undo_cur_page + 1
	local next_page = state.undo_cur_page + 1
	local total_pages = #state.undo_pages
	if next_page <= total_pages then
		local total_volumes = #state.undo_volumes
		for i = next_volume, total_volumes do
			--delete any contingent volumes, since they won't be able to be redone
			state.undo_volumes[i] = nil
		end
		for i = next_page, total_pages do
			--we may have contingent pages after the current position
			--delete any contingent pages, since they can't be redone
			state.undo_pages[i] = nil
		end
	end
	state.undo_volumes[next_volume] = next_volume_start
	state.undo_cur_volume = next_volume
end
local function add_undo_page(state, page)
	local next_page = state.undo_cur_page + 1
	local total_pages = #state.undo_pages
	if next_page <= total_pages then
		--somehow the undo chain is partially undone, break and fix
		Console.warn('Builder_add_undo_page', 'discrepancy detected in undo pages: partially undone. page:', next_page, 'total:', total_pages)
		new_undo_volume(state)
	end
	-- Console.print(Dump.printtab(page))
	state.undo_pages[next_page] = page
	state.undo_cur_page = next_page
end

local function update_map(state, map_x, map_y)
	for i = 1, #state.world_update_x do
		if state.world_update_x[i] == map_x and state.world_update_y[i] == map_y then
			return
		end
	end
	local i = #state.world_update_x + 1
	state.world_update_x[i] = map_x
	state.world_update_y[i] = map_y
end
local function create_map(state, map_x, map_y)
	local map = World.map_new()
	World.set_map(state.world, map_x, map_y, map)
	state.world_marker_sets[World.map_to_key(map_x, map_y)] = {}--all maps must have a marker set
	update_map(state, map_x, map_y)
	return map
end
local function get_tile_at_abs(state, tile_x, tile_y)
	local tile_x_map = tile_x%World.TILESPERMAP
	local map_x = (tile_x - tile_x_map)/World.TILESPERMAP
	local tile_y_map = tile_y%World.TILESPERMAP
	local map_y = (tile_y - tile_y_map)/World.TILESPERMAP
	local map = World.get_map(state.world, map_x, map_y)
	if map then
		return World.get_tile(map, tile_x_map, tile_y_map)
	else
		return World.TILE_NULL
	end
end
local function set_tile_at_abs(state, tile_x, tile_y, tile, dont_add_undo)
	--also saves for undo
	local tile_x_map = tile_x%World.TILESPERMAP
	local map_x = (tile_x - tile_x_map)/World.TILESPERMAP
	local tile_y_map = tile_y%World.TILESPERMAP
	local map_y = (tile_y - tile_y_map)/World.TILESPERMAP
	local map = World.get_map(state.world, map_x, map_y)
	if map then
		local pre_tile = World.get_tile(map, tile_x_map, tile_y_map)
		World.set_tile(map, tile_x_map, tile_y_map, tile)
		update_map(state, map_x, map_y)
		if not dont_add_undo then
			add_undo_page(state, {
				id = UNDO_ID.TILE_SET,
				tile_x = tile_x,
				tile_y = tile_y,
				pre_tile = pre_tile,
			})
		end
		return pre_tile
	else
		map = create_map(state, map_x, map_y)
		World.set_tile(map, tile_x_map, tile_y_map, tile)
		if not dont_add_undo then
			add_undo_page(state, {
				id = UNDO_ID.TILE_SET,
				tile_x = tile_x,
				tile_y = tile_y,
				pre_tile = World.TILE_NULL,
			})
		end
		return World.TILE_NULL
	end
end
local function set_tile_at_abs_in_selection(state, tile_x, tile_y, tile)
	local dev = state.dev
	if dev.selection_is_made then
		local s0_x = dev.selection0_x
		local s0_y = dev.selection0_y
		local s1_x = dev.selection1_x
		local s1_y = dev.selection1_y
		if s0_x > s1_x then
			s0_x, s1_x = s1_x, s0_x
		end
		if s0_y > s1_y then
			s0_y, s1_y = s1_y, s0_y
		end
		if tile_x >= s0_x and tile_x <= s1_x then
			if tile_y >= s0_y and tile_y <= s1_y then
				set_tile_at_abs(state, tile_x, tile_y, tile)
			end
		end
	else
		set_tile_at_abs(state, tile_x, tile_y, tile)
	end
end
local function set_tiles_in_line(state, tile0_x, tile0_y, tile1_x, tile1_y, tile)
	local distance = math.abs(tile0_x - tile1_x) + math.abs(tile0_y - tile1_y)
	set_tile_at_abs_in_selection(state, tile0_x, tile0_y, tile)
	if distance > 0 then
		set_tile_at_abs_in_selection(state, tile1_x, tile1_y, tile)
		for i = 1, distance - 1 do
			local n = i/distance
			set_tile_at_abs_in_selection(state, floor(Dump.lerp(tile0_x, tile1_x, n)), floor(Dump.lerp(tile0_y, tile1_y, n)), tile)
		end
	end
end

local function undo_undo_page(state, page)
	-- Console.print('hi', Dump.printtab(page))
	local id = page.id
	if id == UNDO_ID.TILE_SET then
		page.pre_tile = set_tile_at_abs(state, page.tile_x, page.tile_y, page.pre_tile, true)
	end
end
local function redo_undo_page(state, page)
	local id = page.id
	if id == UNDO_ID.TILE_SET then
		page.pre_tile = set_tile_at_abs(state, page.tile_x, page.tile_y, page.pre_tile, true)
	end
end
local function undo(state)
	local cur_volume = state.undo_cur_volume
	if cur_volume <= 0 then return end
	local desired_volume = cur_volume - 1
	local cur_page = state.undo_cur_page
	local desired_page = state.undo_volumes[cur_volume] - 1
	while cur_page > desired_page do
		local undo_page = state.undo_pages[cur_page]
		undo_undo_page(state, undo_page)
		cur_page = cur_page - 1
	end
	state.undo_cur_volume = desired_volume
	state.undo_cur_page = desired_page
end
local function redo(state)
	local cur_volume = state.undo_cur_volume
	local cur_page = state.undo_cur_page
	local desired_volume = cur_volume + 1
	local desired_page
	if desired_volume > #state.undo_volumes then
		if cur_page ~= #state.undo_pages then
			Console.error('Builder_redo', 'Discrepancy detected, partially undone in last volume')
		end
		return
	elseif desired_volume == #state.undo_volumes then
		desired_page = #state.undo_pages
	else
		desired_page = state.undo_volumes[desired_volume + 1] - 1
	end
	cur_page = cur_page + 1
	while cur_page <= desired_page do
		local undo_page = state.undo_pages[cur_page]
		redo_undo_page(state, undo_page)
		cur_page = cur_page + 1
	end
	state.undo_cur_page = desired_page
	state.undo_cur_volume = desired_volume
end

local function marker_remove(marker_set, pid)
	local i = 1
	while i <= #marker_set do
		if marker_set[i] == pid then
			table.remove(marker_set, i)
			return
		end
		i = i + 1
	end
	error(Dump.message(pid, marker_set, i))
end
local function marker_add(marker_set, pid)
	marker_set[#marker_set + 1] = pid
end
local function get_marker_at_abs(state, unit_x, unit_y)
	--also saves for undo
	local map_unit_x = unit_x%World.UNITSPERMAP
	local map_x = math.floor(unit_x/World.UNITSPERMAP)
	local map_unit_y = unit_y%World.UNITSPERMAP
	local map_y = math.floor(unit_y/World.UNITSPERMAP)
	local marker_set = state.world_marker_sets[World.map_to_key(map_x, map_y)]
	if marker_set then
		local i = #marker_set
		while i > 0 do
			local pid = marker_set[i]
			local marker = state.to_marker[pid]
			if marker.x == map_unit_x and marker.y == map_unit_y then
				return marker
			end
			i = i - 1
		end
	end
	return nil
end
local function add_marker_at_abs(state, unit_x, unit_y, dont_add_undo)
	--also saves for undo
	local map_x = math.floor(unit_x/World.UNITSPERMAP)
	local map_y = math.floor(unit_y/World.UNITSPERMAP)
	local pid = state.marker_cur_pid
	state.marker_cur_pid = pid + 1
	local marker = {
		pid = pid,
		x = unit_x,
		y = unit_y,
		name = 'marker',
	}
	state.to_marker[pid] = marker
	local marker_set = state.world_marker_sets[World.map_to_key(map_x, map_y)]
	if not marker_set then
		create_map(state, map_x, map_y)
		marker_set = state.world_marker_sets[World.map_to_key(map_x, map_y)]
	end
	marker_add(marker_set, pid)
	if not dont_add_undo then
		add_undo_page(state, {
			id = UNDO_ID.MARKER_ADD,
			pid = pid,
			unit_x = unit_x,
			unit_y = unit_y,
		})
	end
	return marker
end
local function remove_marker(state, marker, dont_add_undo)
	--also saves for undo
	local map_x = math.floor(marker.x/World.UNITSPERMAP)
	local map_y = math.floor(marker.y/World.UNITSPERMAP)
	local pid = marker.pid
	local marker_set = state.world_marker_sets[World.map_to_key(map_x, map_y)]
	marker_remove(marker_set, pid)
	state.to_marker[pid] = nil
	if not dont_add_undo then
		add_undo_page(state, {
			id = UNDO_ID.MARKER_REMOVE,
			pid = pid,
			unit_x = marker.x,
			unit_y = marker.y,
		})
	end
	return marker
end
local function move_marker_to_abs(state, marker, unit_x, unit_y, dont_add_undo)
	--also saves for undo
	local pid = marker.pid
	local cur_map_x = math.floor(marker.x/World.UNITSPERMAP)
	local cur_map_y = math.floor(marker.y/World.UNITSPERMAP)
	local map_x = math.floor(unit_x/World.UNITSPERMAP)
	local map_y = math.floor(unit_y/World.UNITSPERMAP)
	if cur_map_x ~= map_x or cur_map_y ~= map_y then
		local cur_marker_set = state.world_marker_sets[World.map_to_key(cur_map_x, cur_map_y)]
		marker_remove(cur_marker_set, pid)
		local marker_set = state.world_marker_sets[World.map_to_key(map_x, map_y)]
		if not marker_set then
			create_map(state, map_x, map_y)
			marker_set = state.world_marker_sets[World.map_to_key(map_x, map_y)]
		end
		marker_add(marker_set, pid)
	end
	if not dont_add_undo then
		add_undo_page(state, {
			id = UNDO_ID.MARKER_MOVE,
			pid = pid,
			unit_x = marker.x,
			unit_y = marker.y,
		})
	end
	marker.x = unit_x
	marker.y = unit_y
	return marker
end


local MARKER = -1
local FROM_CON_TO_TILE = {
	[Con.ONE] = World.TILE_WALL,
	[Con.TWO] = World.TILE_PLATFORM,
	[Con.THREE] = World.TILE_LADDER,
	[Con.FOUR] = World.TILE_HATCH,
	[Con.FIVE] = MARKER,--places zones
}
local MAXIMUM_ZOOM = 20
function Builder.update(state, input)
	local time = state.time + 1
	state.time = time
	local dev = state.dev
	Con.process(dev.con, input, time)

	if #state.world_update_x > 0 then
		for i = 1, #state.world_update_x do
			state.world_update_x[i] = nil
			state.world_update_y[i] = nil
		end
	end

	if dev.is_typing then--returns
		local data = dev.type_data
		local pos = data.bar_pos
		local text = data.text
		local c = input.characters
		local x = input.control
		if c ~= '' then
			data.text = string.sub(text, 1, pos)..c..string.sub(text, pos + 1, -1)
			data.bar_pos = data.bar_pos + string.len(c)
			text = data.text
		end
		if x ~= '' then
			if x == 'left' then
				if pos > 0 then
					data.bar_pos = pos - 1
				end
			elseif x == 'right' then
				if pos < string.len(text) then
					data.bar_pos = data.bar_pos + 1
				end
			elseif x == 'backspace' then
				if pos > 0 then
					data.text = string.sub(text, 1, pos - 1)..string.sub(text, pos + 1, -1)
					data.bar_pos = pos - 1
				end
			elseif x == 'return' then
				if data.id == 'm' then
					state.to_marker[data.pid].name = text
					data.pid = nil
				end
				dev.is_typing = false
			end
		end
		return
	end

	local new_selection
	for i = Con.ONE, Con.FIVE do
		if Con.just_down(dev.con, i, time) then
			new_selection = i
		end
	end
	if new_selection then
		local tile = FROM_CON_TO_TILE[new_selection]
		if dev.selected_tile == tile then
			dev.selected_tile = World.TILE_EMPTY
		else
			if tile == MARKER then--remove any selections
				dev.selection_is_making = false
				dev.selection_is_made = false
			elseif dev.selected_tile == MARKER then--unselect marker
				dev.selected_marker = 0
				dev.highlighted_marker = 0
			end
			dev.selected_tile = tile
		end
		dev.set_in_line = false--prevent previous tiles from being replaced
	end
	do--Process movement
		local speed
		if Con.is_down(dev.con, Con.SHIFT, time) then
			speed = 12 + math.floor(math.sqrt(Con.time_down(dev.con, Con.SHIFT, time)))
		else
			speed = 8
		end
		local con_ud = Con.top_ud(dev.con)
		if con_ud == Con.UP then
			dev.y = dev.y - speed
		elseif con_ud == Con.DOWN then
			dev.y = dev.y + speed
		end
		local con_lr = Con.top_lr(dev.con)
		if con_lr == Con.LEFT then
			dev.x = dev.x - speed
		elseif con_lr == Con.RIGHT then
			dev.x = dev.x + speed
		end
	end
	if input.wheel > 0 then
		if dev.zoom < MAXIMUM_ZOOM - input.wheel then
			dev.zoom = dev.zoom + input.wheel
		end
	elseif input.wheel < 0 then
		if dev.zoom > -input.wheel then
			dev.zoom = dev.zoom + input.wheel
		end
	end

	if dev.selected_tile == MARKER then
		local m_unit_x = 4*math.floor(Display.pixels_to_units(input.x, dev.x)/4)
		local m_unit_y = 4*math.floor(Display.pixels_to_units(input.y, dev.y)/4)
		local cur_marker = get_marker_at_abs(state, m_unit_x, m_unit_y)
		if cur_marker then
			dev.highlighted_marker = cur_marker.pid
		else
			dev.highlighted_marker = 0
		end
		if Con.just_down(dev.con, Con.M1, time) then
			new_undo_volume(state)
			local marker = cur_marker
			if not marker then
				marker = add_marker_at_abs(state, m_unit_x, m_unit_y)
			end
			dev.selected_marker = marker.pid
			dev.has_moved_marker = false
		elseif dev.selected_marker ~= 0 then
			if Con.is_down(dev.con, Con.M1) then
				local marker = state.to_marker[dev.selected_marker]
				if marker.x ~= m_unit_x or marker.y ~= m_unit_y then
					if not dev.has_moved_marker then
						dev.has_moved_marker = true
						new_undo_volume(state)
					end
					move_marker_to_abs(state, marker, m_unit_x, m_unit_y)
				end
			else
				dev.selected_marker = 0
			end
		end
		if dev.selected_marker == 0 and Con.just_up(dev.con, Con.M2, time) then
			if cur_marker then
				dev.is_typing = true
				local data = dev.type_data
				data.id = 'm'
				data.pid = cur_marker.pid
				data.text = ''
				data.bar_pos = 0
			end
		elseif Con.just_up(dev.con, Con.DELETE, time) then
			if cur_marker then
				remove_marker(state, cur_marker)--<--here
				dev.highlighted_marker = 0
			end
		end
	else
		local m_tile_x = Display.pixels_to_tiles(input.x, dev.x)--<--impure
		local m_tile_y = Display.pixels_to_tiles(input.y, dev.y)
		if Con.is_down(dev.con, Con.M1) then
			if dev.set_in_line then
				if dev.origin_tile_x ~= m_tile_x or dev.origin_tile_y ~= m_tile_y then
					set_tiles_in_line(state, dev.origin_tile_x, dev.origin_tile_y, m_tile_x, m_tile_y, dev.selected_tile)
				end
			else
				dev.set_in_line = true
				new_undo_volume(state)
				set_tile_at_abs_in_selection(state, m_tile_x, m_tile_y, dev.selected_tile)
			end
			dev.origin_tile_x = m_tile_x
			dev.origin_tile_y = m_tile_y
		else
			dev.set_in_line = false
		end
		if Con.is_down(dev.con, Con.M2) then
			if not dev.selection_is_making then
				dev.selection_is_making = true
				dev.selection_is_made = true
				dev.selection0_x = m_tile_x
				dev.selection0_y = m_tile_y
			end
			dev.selection1_x = m_tile_x
			dev.selection1_y = m_tile_y
		elseif Con.just_up(dev.con, Con.M2, state.time) then
			dev.selection_is_making = false
			if m_tile_x == dev.selection0_x and m_tile_y == dev.selection0_y then
				dev.selection_is_made = false
			else
				dev.selection1_x = m_tile_x
				dev.selection1_y = m_tile_y
			end
		end
		if not dev.selection_is_made then
			dev.selection0_x = m_tile_x
			dev.selection0_y = m_tile_y
		end

		if Con.is_down(dev.con, Con.CONTROL) then
			local is_c = Con.just_down(dev.con, Con.C, state.time)
			local is_x = Con.just_down(dev.con, Con.X, state.time)
			if is_c or is_x then
				if dev.selection_is_made then
					local s0_x = dev.selection0_x
					local s0_y = dev.selection0_y
					local s1_x = dev.selection1_x
					local s1_y = dev.selection1_y
					if s0_x > s1_x then
						s0_x, s1_x = s1_x, s0_x
					end
					if s0_y > s1_y then
						s0_y, s1_y = s1_y, s0_y
					end
					dev.clipboard_sx = s1_x - s0_x + 1
					dev.clipboard_sy = s1_y - s0_y + 1
					local xy = 1
					if is_x then
						new_undo_volume(state)
						for tile_y = s0_y, s1_y do
							for tile_x = s0_x, s1_x do
								dev.clipboard[xy] = set_tile_at_abs(state, tile_x, tile_y, dev.selected_tile)
								xy = xy + 1
							end
						end
					else
						for tile_y = s0_y, s1_y do
							for tile_x = s0_x, s1_x do
								dev.clipboard[xy] = get_tile_at_abs(state, tile_x, tile_y)
								xy = xy + 1
							end
						end
					end
					while xy <= #dev.clipboard do
						dev.clipboard[xy] = nil
						xy = xy + 1
					end
				end
			elseif Con.just_down(dev.con, Con.V, state.time) then
				if #dev.clipboard > 0 then
					local tile_x = dev.selection0_x
					local tile_y = dev.selection0_y
					local x = 0
					local y = 0
					new_undo_volume(state)
					for xy = 1, #dev.clipboard do
						local tile = dev.clipboard[xy]
						set_tile_at_abs(state, tile_x + x, tile_y + y, tile)
						x = x + 1
						if x >= dev.clipboard_sx then
							x = 0
							y = y + 1
						end
					end
				end
			end
		end
	end

	if Con.is_down(dev.con, Con.CONTROL) then
		if Con.just_down(dev.con, Con.Z, state.time) then
			if Con.is_down(dev.con, Con.SHIFT, state.time) then
				redo(state)
			else
				undo(state)
			end
		end
	end
end



local Tile_to_dev_block = {
	-- [World.TILE_EMPTY]    = Graphics.dev_blocks_empty,
	[World.TILE_LADDER]   = Graphics.dev_blocks_ladder,
	[World.TILE_WALL]     = Graphics.dev_blocks_wall,
	[World.TILE_PLATFORM] = Graphics.dev_blocks_platform,
	[World.TILE_HATCH]    = Graphics.dev_blocks_hatch,
}

function Builder.render_init(state)
	local render_data = {
		zoom = -1,
		maps = {},
	}

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


local Toolbox, Master_image, Master_image_size do
	Master_image = Graphics.dev_blocks
	Master_image_size = Graphics.dev_blocks:getHeight()
	Toolbox = {
		{tile = World.TILE_WALL, icon = Tile_to_dev_block[World.TILE_WALL]},
		{tile = World.TILE_PLATFORM, icon = Tile_to_dev_block[World.TILE_PLATFORM]},
		{tile = World.TILE_LADDER, icon = Tile_to_dev_block[World.TILE_LADDER]},
		{tile = World.TILE_HATCH, icon = Tile_to_dev_block[World.TILE_HATCH]},
	}
	local SIZE = .05
	for i = 1, #Toolbox do
		Toolbox[i].x = .75/2 - SIZE/2 + .25*(i - 1)/(#Toolbox - 1)
		Toolbox[i].y = .8
		Toolbox[i].sx = SIZE
		Toolbox[i].sy = SIZE
	end
end

local Font = lg.newFont('Consolas.ttf', 16)
function Builder.render(state, render_data)
	local world = state.world
	local dev = state.dev

	if render_data.zoom ~= dev.zoom then
		render_data.zoom = dev.zoom
		Display.set_pixels_per_unit(dev.zoom/4)
	end

	for i = 1, #state.world_update_x do
		local map_x = state.world_update_x[i]
		local map_y = state.world_update_y[i]
		local map = World.get_map(world, map_x, map_y)
		local key = World.map_to_key(map_x, map_y)
		local map_batch = render_data.maps[key]
		if map_batch then
			map_batch:clear()
			-- map_batch:setBufferSize(total)
		else
			map_batch = lg.newSpriteBatch(Graphics.dev_blocks, 4*TILESPERMAP, 'static')
			render_data.maps[key] = map_batch
		end
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
	end

	Gui.screen_origin()
	Gui.screen_trans(-dev.x, -dev.y)

	do--render map
		local top_map_x = math.floor(dev.x/UNITSPERMAP)
		local top_map_y = math.floor(dev.y/UNITSPERMAP)
		local bottom_map_x = math.floor((dev.x + Display.screen_sx)/UNITSPERMAP)
		local bottom_map_y = math.floor((dev.y + Display.screen_sy)/UNITSPERMAP)
		for map_y = top_map_y, bottom_map_y do
			for map_x = top_map_x, bottom_map_x do
				local key = World.map_to_key(map_x, map_y)
				local batch = render_data.maps[key]
				if batch then
					local x = UNITSPERMAP*map_x
					local y = UNITSPERMAP*map_y
					Gui.set_color(Gui.DARK_GRAY)
					lg.rectangle('fill', x, y, UNITSPERMAP, UNITSPERMAP)
					Gui.set_color(Gui.WHITE)
					lg.draw(batch, x, y, 0)
					local marker_set = state.world_marker_sets[key]
					if #marker_set > 0 then
						Gui.set_color(Gui.GREEN)
						for i = 1, #marker_set do
							local pid = marker_set[i]
							local marker = state.to_marker[pid]
							lg.rectangle('fill', marker.x, marker.y, 4, 4)
						end
					end
				end
			end
		end
	end
	if dev.selection_is_made then--highlight selection
		Gui.set_color(Gui.BLUE)
		local tile_x = math.min(dev.selection0_x, dev.selection1_x)
		local tile_y = math.min(dev.selection0_y, dev.selection1_y)
		local tile_sx = math.abs(dev.selection0_x - dev.selection1_x) + 1
		local tile_sy = math.abs(dev.selection0_y - dev.selection1_y) + 1
		local frame = {
			x = UNITSPERTILE*tile_x,
			y = UNITSPERTILE*tile_y,
			sx = UNITSPERTILE*tile_sx,
			sy = UNITSPERTILE*tile_sy,
		}
		Gui.draw_box(frame, true)
		lg.print(dev.selection0_x..', '..dev.selection0_y, UNITSPERTILE*dev.selection0_x + 1, UNITSPERTILE*dev.selection0_y + 1, 0, 2)
		lg.print(tile_sx..', '..tile_sy, UNITSPERTILE*dev.selection1_x + 1, UNITSPERTILE*dev.selection1_y + 1, 0, 2)
	end

	Gui.screen_abs_origin()

	for i = 1, #Toolbox do
		local frame = Gui.get_abs_frame(Toolbox[i], Display.screen_pixels_sx, Display.screen_pixels_sy)
		frame.sy = frame.sx
		if Toolbox[i].tile == dev.selected_tile then
			Gui.set_color(Gui.BLUE, .5)
		else
			Gui.set_color(Gui.BLACK, .5)
		end
		Gui.draw_box(frame)
		Gui.set_color(Gui.WHITE, .85)
		Gui.scale_from_center(frame, .8, .8)
		Gui.draw_quad(frame, Master_image, Toolbox[i].icon, Master_image_size, Master_image_size)
	end

	-- Gui.screen_pixel_origin()

	if dev.is_typing then--display type
		local data = dev.type_data
		if data.id == 'm' then
			local marker = state.to_marker[data.pid]
			local text = data.text
			local pos = data.bar_pos
			lg.setFont(Font)
			lg.print(string.sub(text, 1, pos)..'|'..string.sub(text, pos + 1, -1), Display.units_to_pixels(marker.x, dev.x - 1), Display.units_to_pixels(marker.y, dev.y - 4), 0, 1)
		end
	else
		local pid = dev.highlighted_marker
		if pid == 0 then
			pid = dev.selected_marker
		end
		if pid ~= 0 then
			local marker = state.to_marker[pid]
			lg.setFont(Font)
			lg.print(marker.name, Display.units_to_pixels(marker.x, dev.x - 1), Display.units_to_pixels(marker.y, dev.y - 4), 0, 1)
		end
	end
end

return Builder
