--By mami
local lg = require'love.graphics'



local dir = 'game/graphics/'
local dev_blocks = love.graphics.newImage(dir..'blocks.png')

local dev_blocks_sx = dev_blocks:getWidth()
local dev_blocks_sy = dev_blocks:getHeight()


local w = 32

return {
	font_noto_mono = lg.newFont(dir..'NotoMono.ttf', 8),
	dev_blocks = dev_blocks,
	dev_blocks_empty    = lg.newQuad(4*w, 0, w, w, dev_blocks_sx, dev_blocks_sy),
	dev_blocks_wall     = lg.newQuad(0*w, 0, w, w, dev_blocks_sx, dev_blocks_sy),
	dev_blocks_platform = lg.newQuad(1*w, 0, w, w, dev_blocks_sx, dev_blocks_sy),
	dev_blocks_hatch    = lg.newQuad(2*w, 0, w, w, dev_blocks_sx, dev_blocks_sy),
	dev_blocks_ladder   = lg.newQuad(3*w, 0, w, w, dev_blocks_sx, dev_blocks_sy),
}
