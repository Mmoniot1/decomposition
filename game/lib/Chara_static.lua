--By Mami
local Dump = require'lualib/Dump'


local Chara_static = {}
function Chara_static.damage(state, chara, damage)
	state.chara_table[chara].health = state.chara_table[chara].health - damage
end




local Characters = {}
Characters[1] = {
	interact = function(state, chara)
	end,
}





return Dump.new_immutable(Chara_static)
