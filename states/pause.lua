local st = {}

local canvas
function st:init()
	canvas = love.graphics.newCanvas()
end

function st:enter(pre)
	canvas:clear()
	canvas:renderTo(function() pre:draw() end)
end

function st:draw()
	draw_blurred(canvas, 7)
	love.graphics.setColor(20,16,10,190)
	love.graphics.rectangle('fill', 0,0, WIDTH, HEIGHT)

	love.graphics.setColor(255,255,255)
	love.graphics.setFont(Font[90])
	love.graphics.printf('PAUSE', 0, HEIGHT/2-60, WIDTH, 'center')

	love.graphics.setFont(Font[20])
	love.graphics.printf([[[Escape] to go to main menu.
Any other key to resume.]], 0, HEIGHT/2+60, WIDTH, 'center')
end

function st:keypressed(key)
	if key == 'escape' then
		GS.switch(State.menu)
	else
		GS.pop()
	end
end

return st
