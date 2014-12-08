local st = {}

local t = 0

local canvas
local viewcount = 0
function st:init()
	canvas = love.graphics.newCanvas()
	self.seen = {}
end

function st:enter(pre, what, msgs)
	if self.seen[what] or not show_tutorial then return GS.pop() end
	self.seen[what] = true
	viewcount = viewcount + 1
	if viewcount >= 4 then show_tutorial = false end
	self.msgs = msgs
	self.cur = 1
	canvas:clear()
	canvas:renderTo(function() pre:draw() end)
end

function st:draw()
	draw_blurred(canvas, 3)
	love.graphics.setColor(20,16,10,220)
	love.graphics.rectangle('fill', 150,150, WIDTH-300, HEIGHT-300)

	love.graphics.setFont(Font[35])
	love.graphics.setColor(255,255,255)
	local m = self.msgs[self.cur]
	local _, h = Font[35]:getWrap(m, WIDTH-340)
	h = h * Font[35]:getLineHeight() * Font[35]:getHeight()
	love.graphics.printf(m, 170,(HEIGHT-h)/2,WIDTH-340, 'center')

	gui.core.draw()
end

local hot
function st:update()
	love.graphics.setFont(Font[25])
	if self.cur > 1 and gui.Button{text = 'what?', pos = {160,HEIGHT-195}, size={100,35}} then
		self.cur = math.max(self.cur-1, 1)
	end
	if gui.Button{text = 'next', pos = {WIDTH-260,HEIGHT-195}, size={100,35}} then
		self.cur = self.cur + 1
	end

	if self.cur > #self.msgs then
		GS.pop()
	end

	local h = gui.mouse.getHot()
	if h ~= hot and h ~= nil then
		Sound.static.btn:play()
	end
	hot = h
end

return st
