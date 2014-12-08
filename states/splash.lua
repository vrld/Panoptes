local st = {}

local base = (...):gsub('%.', '/') .. '/'
local duration_show_splash = 1 -- in seconds
local color_fg     = {220,214,204}
local color_bg     = {30,28,25}
local cell_width   = 25
local cell_height  = 25
local cell_spacing = 5

local callbacks = {}
function callbacks.after(f) callbacks.after = f end

-- ANIMATION
-- 1 -> draw square, 0 -> blank
local _ = 0
local sequence, board = {}, {
	{1,_,1,_,1,1,_,1,_,_,1,1,_},
	{1,_,1,_,1,_,_,1,_,_,1,_,1},
	{_,1,_,_,1,_,_,1,1,_,1,1,_},
}

-- GRAPHICS
local offset = {
	x = (love.graphics.getWidth() - #board[1] * (cell_spacing + cell_width)) / 2,
	y = (love.graphics.getHeight() - #board   * (cell_spacing + cell_height)) / 2,
}
local haze = {
	sx  = love.graphics.getWidth() / Image.haze:getWidth(),
	sy  = love.graphics.getHeight() / Image.haze:getHeight(),
}

-- SOUND
local woosh
local woosh_length = 1.3

local tick = {}
for k = 1,10 do
	local len = 0.06 + math.random() * .2
	local attack, release = 0.1 * len, 0.9 * len
	local freq = 300 + (math.random() * .5 + .5) * 50
	tick[k] = love.sound.newSoundData(len * 44100, 44100, 16, 1)
	for i = 0,len*44100-1 do
		local t = i / 44100
		local sample = math.sin(t * freq * math.pi * 2)
		local env = t < attack and (t/attack)^4 or (1 - (t-attack)/(release-attack))^4
		sample = sample * env * .2
		tick[k]:setSample(i, sample)
	end
end

local t = 0
function st:init()
	Image.haze:setFilter('linear', 'linear')
end

function st:enter()
	woosh = nil
	sequence = {i = 1, t = 0}
	for i = 1,#board do
		for k = 1,#board[i] do
			sequence[#sequence+1] = {y = i, x = k}
			if board[i][k] == 0 then
				sequence[#sequence+1] = {t = 1, y = i, x = k}
			end
			board[i][k] = {a = 0, da = 0}
		end
	end

	-- randomize animation
	for i = 1,#sequence do
		local k = math.random(i,#sequence)
		sequence[i], sequence[k] = sequence[k], sequence[i]
		sequence[i].dt = 1 / #sequence
	end

	t = 0
	love.graphics.setBackgroundColor(color_bg)
	love.graphics.setLineJoin('bevel')
	love.graphics.setLineWidth(2)
end

function st:draw()
	love.graphics.setColor(30,30,30,30)
	love.graphics.draw(Image.blocks_large, WIDTH/2,HEIGHT/2, 0,1,1, 720/2,129/2)
	love.graphics.setColor(255,255,255)
	for i = 1,#board do
		local y = offset.y + (i-1) * (cell_height + cell_spacing)
		for k = 1,#board[1] do
			if board[i][k].a ~= 0 then
				color_fg[4] = board[i][k].a
				love.graphics.setColor(color_fg)
				local x = offset.x + (k-1) * (cell_width + cell_spacing)
				love.graphics.rectangle('line', x,y, cell_width, cell_height)
			end
		end
	end

	if t >= duration_show_splash then
		love.graphics.setColor(color_bg)
		love.graphics.draw(Image.haze, love.graphics.getWidth(),0,0, -haze.sx * math.sqrt(t) * 2, haze.sy * math.sqrt(t) * 5)
	end
end

function st:update(dt)
	dt = math.min(dt, 1 / 25)

	if sequence[sequence.i] then
		-- vrld in - update sequence
		if sequence.t >= sequence[sequence.i].dt then
			local s = sequence[sequence.i]
			if board[s.y][s.x].da == 0 then
				board[s.y][s.x].da = 1
			else
				board[s.y][s.x].da = -board[s.y][s.x].da
			end

			local src = love.audio.newSource(tick[math.random(#tick)])
			src:play()

			sequence.t = sequence.t - sequence[sequence.i].dt
			sequence.i = sequence.i + 1
		end
		sequence.t = sequence.t + dt
	else
		-- show vrld
		t = t + dt
	end
	if t >= duration_show_splash then
		if not woosh then
			woosh = Sound.static.woosh:play()
		elseif woosh:isStopped() then
			GS.transition(State.menu, 1)
			--GS.switch(State.menu)
			return
		end
		s = (t-duration_show_splash) / woosh_length
		color_bg[4] = math.min(math.sqrt(s) * 2 * 255, 255)
	end

	-- update board alpha
	for i = 1,#board do
		for k = 1,#board[i] do
			local cell = board[i][k]
			cell.a = math.max(math.min(cell.a + 15 * cell.da * dt * 255, 255), 0)
		end
	end
end

function st:keypressed()
	if t < duration_show_splash then
		sequence.i = {}
		t = duration_show_splash
	end
end

return st
