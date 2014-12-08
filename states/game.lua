local st = {}

local modes, active
local canvas = {
	love.graphics.newCanvas(),
	love.graphics.newCanvas(),
	love.graphics.newCanvas(),
}

function st:enter()
	love.graphics.setBackgroundColor(30,28,25)
	if show_tutorial then
		modes = {Modes.blocks}
	else
		modes = {Modes.blocks, Modes.pong, Modes.snake}
	end
	active = 1
	for _, m in ipairs(modes) do m:reset() end
	self.points = 0
end

function st:update(dt)
	if self.points >= 50 and #modes == 1 then
		modes[#modes+1] = Modes.pong
		Modes.pong:reset()
		active = 2
	elseif self.points >= 100 and #modes == 2 and State.tutorial.seen.pong then
		modes[#modes+1] = Modes.snake
		Modes.snake:reset()
		active = 3
	end

	for _, m in ipairs(modes) do
		m:update(dt)
	end

	modes[active]:update_active(dt)
end

function st:draw()
	love.graphics.setColor(30,30,30,30)
	love.graphics.draw(Image.blocks_large, WIDTH/2,HEIGHT/2, 0,1,1, 720/2,129/2)
	love.graphics.setColor(255,255,255)
	for i, m in ipairs(modes) do
		canvas[i]:clear()
		canvas[i]:renderTo(function() m:draw() end)
	end

	for i = 1,#modes do
		local k = (active + i - 1) % #modes + 1
		local s = (10 - (#modes - i))/10

		if i < #modes then
			love.graphics.setColor(255,255,255,s^10*255)
			draw_blurred(canvas[k], 9 - 2*i)
		else
			love.graphics.setColor(255,255,255)
			love.graphics.draw(canvas[k],0,0)
		end
	end

	love.graphics.setFont(Font[30])
	love.graphics.printf('Score: '..State.game.points, 15,15,WIDTH-20, 'left')
end

function st:keypressed(key)
	if key == '1' then
		active = 1
	elseif key == '2' and #modes >= 2 then
		active = math.min(#modes, 2)
	elseif key == '3' and #modes >= 3 then
		active = math.min(#modes, 3)
	elseif key == 'q' then
		active = active - 1
		if active <= 0 then active = #modes end
	elseif key == 'e' then
		active = (active % #modes) + 1
	else
		modes[active]:keypressed(key)
		return
	end
	-- TODO: tween for switching modes
end

return st
