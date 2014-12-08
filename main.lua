Timer  = require 'hump.timer'
GS     = require 'hump.gamestate'
vector = require 'hump.vector'
class  = require 'hump.class'
Signal = require 'hump.signal'
gui    = require 'Quickie'
require 'slam'

Barrier = class{
	init    = function(self) self.s = 0 end,
	block   = function(self) self.s = self.s + 1 end,
	done    = function(self) self.s = self.s - 1 end,
	is_free = function(self) assert(self.s >= 0) return self.s == 0 end
}

function table.element(t)
	return function(what)
		for _,v in ipairs(t) do
			if v == what then
				return true
			end
		end
		return false
	end
end

function math.sign(x)
	return x > 0 and 1 or (x < 0 and -1 or 0)
end

function GS.transition(to, length, ...)
	length = length or 1

	local fade_color, t = {30,28,25,0}, 0
	local draw, update, switch, transition = GS.draw, GS.update, GS.switch, GS.transition
	GS.draw = function()
		draw()
		color = {love.graphics.getColor()}
		love.graphics.setColor(fade_color)
		love.graphics.rectangle('fill', 0,0, WIDTH, HEIGHT)
		love.graphics.setColor(color)
	end
	GS.update = function(dt)
		update(dt)
		t = t + dt
		local s = t/length
		fade_color[4] = math.min(255, math.max(0, s < .5 and 2*s*255 or (2 - 2*s) * 255))
	end
	-- disable switching states while in transition
	GS.switch = function() end
	GS.transition = function() end

	local args = {...}
	Timer.add(length / 2, function() switch(to, unpack(args)) end)
	Timer.add(length, function()
		GS.draw, GS.update, GS.switch, GS.transition = draw, update, switch, transition
	end)
end

-- minimum frame rate
local up = GS.update
GS.update = function(dt)
	if love.keyboard.isDown('1') then dt = dt / 10 end
	return up(math.min(dt, 1/30))
end

local function Proxy(f)
	return setmetatable({}, {__index = function(t,k)
		local v = f(k)
		t[k] = v
		return v
	end})
end

State = Proxy(function(path) return require('states.' .. path) end)
Image = Proxy(function(path)
	local i = love.graphics.newImage('img/'..path..'.png')
	i:setFilter('nearest', 'nearest')
	return i
end)
Font  = Proxy(function(arg)
	if tonumber(arg) then
		return love.graphics.newFont('font/slkscr.ttf', arg)
	end
	return Proxy(function(size) return love.graphics.newFont('font/'..arg..'.ttf', size) end)
end)
Sound = {
	static = Proxy(function(path) return love.audio.newSource('snd/'..path..'.ogg', 'static') end),
	stream = Proxy(function(path) return love.audio.newSource('snd/'..path..'.ogg', 'stream') end)
}
Modes = Proxy(function(path) return require('modes.' .. path) end)

local function save_settings()
	local f = assert(love.filesystem.newFile('settings.lua', 'w'))
	f:write(([[return {tutorial = %s, shaders = %s, sync = %s}]]):format(show_tutorial, use_shaders, sync_highscores))
	f:close()
end

-- global, because we need this in other places
function load_highscores()
	if not love.filesystem.isFile('sco.res') then
		local f = assert(love.filesystem.newFile('sco.res', 'w'))
		f:write("1:1:1:vrld\n1:2:2:vrld\n1:3:3:vrld\n1:4:4:vrld\n1:5:5:vrld\n1:6:6:vrld\n1:7:7:vrld\n1:8:8:vrld\n1:9:9:vrld\n1:10:10:vrld\n1:11:11:vrld\n1:12:12:vrld\n1:13:13:vrld\n1:14:14:vrld\n1:15:15:vrld\n1:16:16:vrld\n1:17:17:vrld\n1:18:18:vrld")
		f:close()
	end

	local f = assert(love.filesystem.newFile('sco.res', 'r'))
	local scores = {}
	for l in f:lines() do
		local ts,s,cs,n = l:match('^([^:]+):([^:]+):([^:]+):(.*)$')
		s,ts,cs = tonumber(s), tonumber(ts), tonumber(cs)
		if s and n and s*ts == cs then
			scores[#scores+1] = {ts = tonumber(ts), cs = tonumber(cs), score=s, name=n}
		end
	end
	table.sort(scores, function(a,b)
		return a.score > b.score or (a.score == b.score and a.ts > b.ts)
	end)
	return scores
end

function add_highscore(score, name)
	local ts = os.time()
	Highscores[#Highscores+1] = {ts = ts, cs = ts*score, score = score, name = name}
	table.sort(Highscores, function(a,b)
		return a.score > b.score or (a.score == b.score and a.ts > b.ts)
	end)
	save_highscores()
end

function save_highscores()
	local hs = class.clone(Highscores)
	local f = assert(love.filesystem.newFile('sco.res', 'w'))
	table.sort(hs, function(a,b) return a.ts < b.ts end)
	for _,e in ipairs(hs) do
		assert(f:write(("%s:%s:%s:%s\n"):format(e.ts, e.score, e.cs, e.name)))
	end
	f:close()
end

function sync_highscores_threaded()
	local thr = love.thread.newThread('sync-highscores.lua')
	local ch = love.thread.getChannel('highscores')
	Timer.addPeriodic(.5, function()
		if not thr:isRunning() then
			if thr:getError() ~= nil then
				GS.push(State.message, "Error synching highscores", thr:getError())
				return false
			end
			local res = ch:pop()
			if res == nil then
				GS.push(State.message, "Error synching highscores",
					"Did not receive anything from the server")
				return false
			end

			local scores = {}
			for l in res:gmatch('([^\n]+)') do
				local ts,s,cs,n = l:match('^([^:]+):([^:]+):([^:]+):(.*)$')
				s,ts,cs = tonumber(s), tonumber(ts), tonumber(cs)

				if s == nil or ts == nil or cs == nil then
					GS.push(State.message, "Error synching highscores",
						"Received invalid answer from the server")
					return false
				end
				if s and n then
					scores[#scores+1] = {ts = tonumber(ts), cs = tonumber(cs), score=s, name=n}
				end
			end

			table.sort(scores, function(a,b)
				return a.score > b.score or (a.score == b.score and a.ts > b.ts)
			end)
			if #scores > 0 then
				Highscores = scores
				save_highscores()
			end
			return false
		end
	end)
	thr:start()
end

function love.load()
	WIDTH, HEIGHT = love.window.getWidth(), love.window.getHeight()
	camera = (require 'hump.camera')(WIDTH/2, HEIGHT/2)
	function camera:shake(duration, dx,dy)
		Timer.do_for(duration or .5, function()
			self.x = (love.math.random()*2-1)*(dx or 10) + WIDTH/2
			self.y = (love.math.random()*2-1)*(dy or 10) + HEIGHT/2
		end, function()
			self.x, self.y = WIDTH/2, HEIGHT/2
		end)
	end

	gui.core.style.gradient:set(255,255)

	gui.core.style.color.normal.bg = {0,0,0, 80}
	gui.core.style.color.hot.bg    = {0,0,0,180}
	gui.core.style.color.active.bg = {0,0,0,180}

	gui.core.style.color.normal.fg = {255,255,255}
	gui.core.style.color.hot.fg    = {153,255,0}
	gui.core.style.color.active.fg = {255,100,32}

	gui.core.style.color.normal.border = {0,0,0,0}
	gui.core.style.color.hot.border = {0,0,0,0}
	gui.core.style.color.active.border = {0,0,0,0}

	gui.keyboard.disable()

	GS.registerEvents()
	-- RELEASE
	GS.switch(State.splash)

	-- TEST
	--GS.switch(State.menu)
	--GS.switch(State.credits)
	--GS.switch(State.game)

	local draw = love.draw
	function love.draw()
		camera:draw(draw)
	end

	first_run = not love.filesystem.isFile('settings.lua')
	show_tutorial = true
	use_shaders = love.graphics.isSupported('shader')
	sync_highscores = false
	if first_run then
		save_settings()
	end

	local settings = love.filesystem.load('settings.lua')()
	show_tutorial, use_shaders, sync_highscores = settings.tutorial, settings.shaders, settings.sync

	Highscores = load_highscores()

	back_buffer = love.graphics.newCanvas()
	if love.graphics.isSupported('shader') then
		blur_shader = {
			[3] = love.graphics.newShader[[
				extern vec2 dir = vec2(0,0);
				vec4 effect(vec4 c, Image tex, vec2 uv, vec2 sc) {
					return (Texel(tex, uv) +
					        Texel(tex,uv-dir) +
					        Texel(tex,uv+dir)) / 3.0f * .9;
				}]],
			[5] = love.graphics.newShader[[
				extern vec2 dir = vec2(0,0);
				vec4 effect(vec4 c, Image tex, vec2 uv, vec2 sc) {
					return (Texel(tex, uv) +
					        Texel(tex,uv-2.*dir) + Texel(tex,uv-dir) +
					        Texel(tex,uv+2.*dir) + Texel(tex,uv+dir)) / 5.0f * .8;
				}]],
			[7] = love.graphics.newShader[[
				extern vec2 dir = vec2(0,0);
				vec4 effect(vec4 c, Image tex, vec2 uv, vec2 sc) {
					return (Texel(tex, uv) +
					        Texel(tex,uv-3.*dir) + Texel(tex,uv-2.*dir) + Texel(tex,uv-dir) +
					        Texel(tex,uv+3.*dir) + Texel(tex,uv+2.*dir) + Texel(tex,uv+dir)) / 7.0f * .7;
				}]]
		}

		--[====================================[
		local effect = love.graphics.newShader[[
		vec4 effect(vec4 c, Image tex, vec2 uv, vec2 sc) {
			vec2 p = 2*(uv-vec2(.5));
			number a = 1. - min(1., pow(length(p),2.));
			return a * Texel(tex, uv);
		}
		]]

		local canvas = love.graphics.newCanvas()
		local draw = love.draw
		love.draw = function(...)
			if not use_shaders then return draw() end

			canvas:clear()
			love.graphics.setShader()
			canvas:renderTo(draw)

			love.graphics.setCanvas()
			love.graphics.setShader(effect)
			love.graphics.draw(canvas,0,0)
			love.graphics.setShader()
		end
		--]====================================]
	end

	if sync_highscores then
		sync_highscores_threaded()
	end

	Sound.static.drop:setPitch(.8)
	Sound.static.drop:setVolume(.5)
	Sound.static.btn:setPitch(5)
	Sound.static.btn:setVolume(.8)
end

function love.quit()
	save_settings()
end

function draw_blurred(canvas, dist, s)
	dist = dist or 3
	s = s or 1
	if not use_shaders then
		love.graphics.draw(canvas,WIDTH/2,HEIGHT/2, 0,s,s, WIDTH/2,HEIGHT/2)
		return
	end
	local c = {love.graphics.getColor()}
	love.graphics.setColor(255,255,255)

	love.graphics.setShader(blur_shader[dist])
	blur_shader[dist]:send('dir', {1/WIDTH,0})

	back_buffer:clear()
	back_buffer:renderTo(function() love.graphics.draw(canvas,WIDTH/2,HEIGHT/2, 0,s,s, WIDTH/2,HEIGHT/2) end)

	blur_shader[dist]:send('dir', {0,1/HEIGHT})

	love.graphics.setColor(c)
	love.graphics.draw(back_buffer,0,0)
	love.graphics.setShader()
end

function love.update(dt)
	Timer.update(dt)
end

function love.keypressed(key)
	if (key == 'escape' or key == 'p') and not table.element{State.pause, State.splash, State.credits, State.menu}(GS.current()) then
		Timer.add(0, function() GS.push(State.pause) end) -- avoids calling keypressed on the pause state
	end
end
