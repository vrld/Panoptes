local mode = {}

local function bbox_collide(x1,y1,w1,h1, x2,y2,w2,h2)
	return x1 + w1/2 > x2 - w2/2 and
	       x2 + w2/2 > x1 - w1/2 and
	       y1 + h1/2 > y2 - h2/2 and
	       y2 + h2/2 > y1 - h1/2
end

local function overlap(x1,y1,w1,h1, x2,y2,w2,h2)
	local ox = math.min(w1, math.min(w2, x1-x2 + (w1+w2)/2 * math.sign(x2-x1)))
	local oy = math.min(h1, math.min(h2, y1-y2 + (h1+h2)/2 * math.sign(y2-y1)))
	return vector(ox,oy)
end

local Paddle = class{
	init = function(self, pos, width, speed)
		self.pos = vector(pos, HEIGHT/2)
		self.width = width or 100
		self.speed = 0
		self.acc   = 2500
	end,

	draw = function(self)
		love.graphics.rectangle("fill", self.pos.x-10, self.pos.y-self.width/2, 20,self.width)
	end,

	move = function(self, dt, dir)
		self.speed = self.speed * .99 + dir * self.acc * dt

		self.pos.y = self.pos.y + self.speed * dt
		local sp = self.speed / 5
		if self.pos.y < self.width/2 then
			self.pos.y = self.width/2
			Timer.do_for(.1, function() self.speed = self.speed - sp * love.timer.getDelta() end)
		elseif self.pos.y > HEIGHT - self.width/2 then
			self.pos.y = HEIGHT - self.width/2
			Timer.do_for(.1, function() self.speed = self.speed - sp * love.timer.getDelta() end)
		end
	end,
}

Sound.static.pong:setPitch(1.1)
Sound.static.pong:setVolume(.7)
local paddles = {left = Paddle(15), right = Paddle(WIDTH-15)}
local ball = {
	pos = vector(WIDTH/2, HEIGHT/2),
	vel = vector(1,0):rotated((2*love.math.random()-1)*math.pi/4),
	speed = 40,
	size = 12,
	hits = 0,
	draw = function(self)
		local sz = self.size
		love.graphics.rectangle('fill', self.pos.x-sz/2, self.pos.y-sz/2, sz, sz)
	end,
	update = function(self,dt)
		self.size = 10 + math.cos((self.pos.x - WIDTH/2)/WIDTH*math.pi) * 5
		self.pos = self.pos + self.vel * dt * (self.speed + (self.hits*5)^1.2)
		if self.pos.x >= WIDTH then
			Signal.emit('pong-ball-out', 1)
		elseif self.pos.x <= 0 then
			Signal.emit('pong-ball-out', -1)
		end

		if self.pos.y - self.size <= 0 or self.pos.y + self.size >= HEIGHT then
			self.vel.y = -self.vel.y
			Sound.static.pong:play()
		end

		for _,p in ipairs{paddles.left, paddles.right} do
			if bbox_collide(self.pos.x,self.pos.y,self.size,self.size,
			                p.pos.x,p.pos.y,20,p.width) then
				--local o = overlap(self.pos.x,self.pos.y,self.size,self.size,
				--                  p.pos.x,p.pos.y,20,p.width)
				--if math.abs(o.x) <= math.abs(o.y) then
					self.vel.x = -self.vel.x
					self.pos.x = self.pos.x + self.vel.x
				--else
				--	self.vel.y = -self.vel.y
				--	self.pos.y = self.pos.y + self.vel.y
				--end
				self.vel:rotate_inplace((2*love.math.random()-1)*math.pi/8)
				self.hits = self.hits + 1
				Sound.static.pong:play()
			end
		end
	end
}

Signal.register('pong-ball-out', function(dir)
	ball.pos = vector(WIDTH/2, HEIGHT/2)
	ball.vel = vector(0,0)
	ball.hits = 0
	Timer.add(1, function()
		ball.vel = vector(dir,0):rotated((2*love.math.random()-1)*math.pi/4)
	end)
end)

function mode:reset()
	local paddles = {left = Paddle(15), right = Paddle(WIDTH-15)}
	ball.pos = vector(WIDTH/2, HEIGHT/2)
	ball.vel = vector(1,0):rotated((2*love.math.random()-1)*math.pi/4)
	ball.hits = 0
end

function mode:update(dt)
	ball:update(dt)
	paddles.right:move(dt, math.sign(ball.pos.y - paddles.right.pos.y) / 5)
end

function mode:update_active(dt)
	if love.keyboard.isDown('up') then
		paddles.left:move(dt, -1)
	elseif love.keyboard.isDown('down') then
		paddles.left:move(dt,  1)
	end
	paddles.left:move(dt, 0)
end

function mode:draw()
	love.graphics.setColor(255,255,255)
	paddles.left:draw()
	paddles.right:draw()
	ball:draw()
end

function mode:keypressed(key) end

Timer.add(2, function()
	GS.push(State.tutorial, "pong", {
		"Hey, I know this game!",
		"This is pong.",
		"Good old pong.",
		"...",
		"Boring old pong.",
		"Look, if you want to play pong, fine.",
		"Who am i to stop you?",
		"But don't think that I will stop for pong.",
		"No.",
		"If you want to come back to me, press <1>, <q> or <e>.",
		"That's it.",
		"...",
		"Okay...",
		"If you want to go back to pong, press <2>. <q> and <e> will also work.",
	})
end)

return mode
