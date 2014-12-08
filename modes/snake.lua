local mode = {}

local GRID_SPACING = 15

local powerups, snake, Powerup = setmetatable({}, {__index = function(t,f)
	return function(...) for b in pairs(t) do b[f](b,...) end end
end})
Powerup = class{
	init = function(self,i,k, id)
		self.pos = vector(i,k)
		powerups[self] = true
		self.t = 0
		self.id = id or 0
		self.alpha = 255
		if self.id ~= 0 then
			mode.timer.tween(20, self, {alpha=0}, 'expo', function()
				powerups[self] = nil
			end)
		end
	end,

	new_at_random_position = function(id)
		local p = vector(0,0)
		repeat
			p.x = love.math.random(1,math.floor(WIDTH/GRID_SPACING)-1)
			p.y = love.math.random(1,math.floor(HEIGHT/GRID_SPACING)-1)
		until not table.element(snake.chain)(p)
		return Powerup(p.x, p.y, id)
	end,

	draw = function(self)
		p = self.pos * GRID_SPACING
		if self.id == 0 then
			local s = .7 + math.sin(self.t*1*math.pi) * .05
			love.graphics.rectangle('fill', p.x-GRID_SPACING/2*s, p.y-GRID_SPACING/2*s, GRID_SPACING*s,GRID_SPACING*s)
		else
			love.graphics.setColor(255,255,255,self.alpha)
			local s = 14/32 + math.sin(self.t*1*math.pi) * .05
			love.graphics.draw(Modes.blocks.sprites, Modes.blocks.quads[self.id],
			                   p.x,p.y, self.t,s,s, 16,16)
			love.graphics.setColor(255,255,255)
		end
	end,

	update = function(self, dt)
		self.t = self.t + dt
	end,

	map = function(self, f)
		return f(self)
	end,
}

snake = {
	chain = {},
	d_next = {},
	direction = vector(1,0),

	dir = function()
		return snake.d_next[#snake.d_next] or snake.direction
	end,

	reset = function(self, pos)
		pos = pos or vector(WIDTH,HEIGHT)/GRID_SPACING/2
		pos.x = math.floor(pos.x)
		pos.y = math.floor(pos.y)
		self.chain = {pos-self.direction*3, pos-self.direction*2, pos-self.direction, pos:clone()}
		self.d_next = {}
		self.t = 0
	end,

	time_to_next_move = function(self)
		return math.max(.2, 1-(#snake.chain-4)/15)/3
	end,

	draw = function(self)
		for i, p in ipairs(self.chain) do
			p = (p-vector(.5,.5)) * GRID_SPACING
			love.graphics.rectangle('fill', p.x, p.y, GRID_SPACING,GRID_SPACING)
		end
	end,

	update = function(self, dt)
		self.t = self.t + dt
		if self.t >= self:time_to_next_move() then
			self.t = self.t - self:time_to_next_move()
			self:move()
		end
	end,

	move = function(self)
		self.direction = table.remove(self.d_next,1) or self.direction
		self.chain[#self.chain+1] = self.chain[#self.chain] + self.direction
		local head = self.chain[#self.chain]

		-- out of the playing field?
		if head.x <= 0 or head.x >= math.floor(WIDTH/GRID_SPACING) or head.y <= 0 or head.y >= math.floor(HEIGHT/GRID_SPACING) then
			self:reset()
			self.t = -1
			Signal.emit('snake-crashed')
			return
		end

		-- eat powerups
		local eaten = false
		powerups.map(function(p)
			if head == p.pos then
				Signal.emit('snake-eat-powerup', p.id, p.pos*GRID_SPACING)
				powerups[p] = nil
				eaten = true
				if p.id == 0 then
					Powerup.new_at_random_position()
				end
			end
		end)

		if not eaten then
			table.remove(self.chain, 1)
		end

		-- eat oneself
		for k = 1,#self.chain-1 do
			if head == self.chain[k] then
				self:reset()
				Signal.emit('snake-bit-itself')
			end
		end
	end,
}

function mode:reset()
	mode.timer = Timer.new()
	powerups.map(function(p) powerups[p] = nil end)
	snake:reset()
	Powerup.new_at_random_position()

	mode.timer.add(love.math.random()*20+5, function(f)
		Powerup.new_at_random_position(love.math.random(1,5))
		mode.timer.add(love.math.random()*20+20, f)
	end)
end

function mode:update(dt)
	powerups.update(dt/3)
	snake:update(dt/3)
	mode.timer.update(dt/3)
end

function mode:update_active(dt)
	powerups.update(dt)
	snake:update(dt)
	mode.timer.update(dt)
end

function mode:draw()
	love.graphics.setColor(255,255,255)
	powerups.draw()
	snake:draw()
end

function mode:keypressed(key)
	if key == 'up'        and snake.dir().y == 0 then
		snake.d_next[#snake.d_next+1] = vector( 0,-1)
	elseif key == 'down'  and snake.dir().y == 0 then
		snake.d_next[#snake.d_next+1] = vector( 0, 1)
	elseif key == 'left'  and snake.dir().x == 0 then
		snake.d_next[#snake.d_next+1] = vector(-1, 0)
	elseif key == 'right' and snake.dir().x == 0 then
		snake.d_next[#snake.d_next+1] = vector( 1, 0)
	end
end

Timer.add(1, function()
	GS.push(State.tutorial, "snake", {
		"Eurgh. Another one?",
		"Looks like snake.",
		"You know...",
		"change direction with the arrow keys",
		"... eat stuff and grow",
		"... dont hit the walls",
		"... or yourself.",
		"Waaaaaaay more exiting than me.",
		"...",
		"not.",
		"If you're ready to come back, press <1> or <e>.",
		"If for some reason you want to go back to snake, press <3> or mash <q> or <e>.",
	})
end)

return mode
