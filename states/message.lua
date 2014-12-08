local st = {}

local canvas
local viewcount = 0
function st:init()
	canvas = love.graphics.newCanvas()
	self.seen = {}
end

function st:enter(pre, what, msg)
	self.title = what
	self.msg = msg
	canvas:clear()
	canvas:renderTo(function() pre:draw() end)
end

function st:draw()
	draw_blurred(canvas, 3)
	love.graphics.setColor(20,16,10,220)
	love.graphics.rectangle('fill', 150,150, WIDTH-300, HEIGHT-300)
	love.graphics.setColor(255,255,255)

	love.graphics.setFont(Font[40])
	love.graphics.printf(self.title, 170,170,WIDTH-340, 'center')

	love.graphics.setFont(Font[30])
	local _, h = Font[30]:getWrap(self.msg, WIDTH-340)
	h = h * Font[30]:getLineHeight() * Font[30]:getHeight()
	love.graphics.printf(self.msg, 170,(HEIGHT-h)/2,WIDTH-340, 'center')

	gui.core.draw()
end

local hot
function st:update()
	love.graphics.setFont(Font[25])
	if gui.Button{text = 'cry', pos = {WIDTH-260,HEIGHT-195}, size={100,35}} then
		GS.pop()
	end

	local h = gui.mouse.getHot()
	if h ~= hot and h ~= nil then
		Sound.static.btn:play()
	end
	hot = h
end

return st
