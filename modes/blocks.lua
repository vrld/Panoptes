local mode = {}

-- "constants"
local ROWS, COLS = 14, 10
local BLOCK_WIDTH = 32
local BLOCK_SPACING = 8
local BLOCK_AREA = BLOCK_WIDTH + BLOCK_SPACING
local OFFSET_X = (WIDTH - COLS * BLOCK_AREA) / 2
local OFFSET_Y = HEIGHT

-- init stuff
local sprites = Image.blocks
sprites:setFilter("nearest", "nearest")
local iw,ih = sprites:getWidth(), sprites:getHeight()
local quads = {
	love.graphics.newQuad(0,   0, 32,32, iw,ih),
	love.graphics.newQuad(36,  0, 32,32, iw,ih),
	love.graphics.newQuad(73,  0, 32,32, iw,ih),
	love.graphics.newQuad(109, 0, 32,32, iw,ih),
	love.graphics.newQuad(146, 0, 32,32, iw,ih),
}
mode.sprites = sprites
mode.quads = quads

-- gameplay
local field, cursor, anim_barrier, combo_counter
local function to_screen(i,k)
	return (i-1)*BLOCK_AREA + OFFSET_X, OFFSET_Y - k*BLOCK_AREA
end

local all_blocks = setmetatable({}, {__index = function(t, f)
	return function(...) for b in pairs(t) do b[f](b, ...) end end
end})

local overlays = setmetatable({}, {__index = function(t, f)
	return function(...) for b in pairs(t) do b[f](b, ...) end end
end})

local Block = class{
	init = function(self, i,k, id)
		self.i, self.k = i,k
		self:update_position()
		self.id = id
		self.quad = quads[id]

		self.scale = 1
		self.rot = 0

		all_blocks[self] = true
	end,

	__tostring = function(self)
		return ('(%s,%s,%s)'):format(self.i, self.k, self.id)
	end,

	update_position = function(self)
		assert(field[self.i][self.k] == self or field[self.i][self.k] == nil,
			'at '..self.i..', '..self.k..' - not me: '..tostring(field[self.i][self.k]) .. ' -- me: '..tostring(self))
		self.pos = vector(to_screen(self.i, self.k)) + (vector(1,1) * (BLOCK_AREA/2))
	end,

	draw = function(self, dy)
		love.graphics.draw(sprites, self.quad, self.pos.x, self.pos.y - dy * BLOCK_AREA,
		                   self.rot, self.scale, self.scale,
		                   BLOCK_WIDTH/2,BLOCK_WIDTH/2)
	end,

	map = function(self, f) return f(self) end,
}

local function find_horizontal_combo(i,k)
	if not field[i][k] then return end

	local min, max = i-1, i+1
	while min >= 1 and field[min][k] and field[min][k].id == field[i][k].id do
		min = min - 1
	end
	while max <= COLS and field[max][k] and field[max][k].id == field[i][k].id do
		max = max + 1
	end
	min, max = min+1, max-1
	if max - min + 1 < 3 then
		return
	end

	local streak = {}
	for j = min,max do
		streak[#streak+1] = {j, k}
	end
	return streak
end

local function find_vertical_combo(i,k)
	if not field[i][k] then return end

	local min, max = k-1, k+1
	while min >= 1 and field[i][min] and field[i][min].id == field[i][k].id do
		min = min - 1
	end
	while max <= field[i].count and field[i][max] and field[i][max].id == field[i][k].id do
		max = max + 1
	end
	min, max = min+1, max-1
	if max - min + 1 < 3 then
		return
	end

	local streak = {}
	for j = min,max do
		streak[#streak+1] = {i,j}
	end
	return streak
end

local function let_blocks_fall_down(i)
	local gap, nblocks = 0, 0
	for j = 1,ROWS do
		if not field[i][j] then
			gap = gap + 1
		else
			nblocks = nblocks + 1
			if gap > 0 then
				local b = field[i][j]
				anim_barrier:block()
				if gap >= 2 then
					Timer.add(.1 * (gap - 2) + math.random()*.05, function() Sound.static.drop:play() end)
				end
				Timer.tween(.1 * gap, b, {pos = {y = b.pos.y + gap*BLOCK_AREA}}, 'bounce', function()
					anim_barrier:done()
					Signal.emit('puzzle-recheck')
				end)
				b.k = j - gap
				field[i][j-gap] = field[i][j]
				field[i][j] = nil
			end
		end
	end
	field[i].count = nblocks
end

local function remove_blocks(blocks)
	local n_blocks = 0

	-- remove blocks and mark rows with blocks that need to fall down
	local cols_with_gaps = {}
	for b, idx in pairs(blocks) do
		local i,k = unpack(idx)
		anim_barrier:block()
		n_blocks = n_blocks + 1
		field[i][k] = nil

		Timer.tween(.2, b, {rot = math.pi, scale = .2}, 'linear', function()
			anim_barrier:done()
			all_blocks[b] = nil
		end)
	end

	Signal.emit('puzzle-removed-blocks', n_blocks)

	anim_barrier:block()
	Timer.add(.2 + 1/30, function()
		for i = 1,COLS do
			let_blocks_fall_down(i)
		end
		anim_barrier:done()
	end)
end

local function remove_combos(combos)
	local blocks_to_remove = {}
	for _, c in ipairs(combos) do
		for _, b in ipairs(c) do
			local i,k = unpack(b)
			blocks_to_remove[field[i][k]] = b
		end
	end
	return remove_blocks(blocks_to_remove)
end

local function check_field()
	local combos = {}

	for i = 1,COLS do
		for k = 1,ROWS do
			combos[#combos+1] = find_horizontal_combo(i,k)
			combos[#combos+1] = find_vertical_combo(i,k)
		end
	end

	if #combos >= 1 then
		remove_combos(combos)
		combo_counter = math.min(3, combo_counter + 1)
	end
end

Signal.register('puzzle-recheck', function()
	if anim_barrier:is_free() then
		check_field()
	end
end)

-- initialize playing field
local t, penalty, row = 0, 0, {}
local function initialize_next_row()
	row = {}
	for i = 1,COLS do
		local id = 0
		repeat
			id = love.math.random(1,5)
		until i <= 2 or id ~= row[i-2].id
		row[i] = Block(i,0, id)
	end
end

local function add_row()
	combo_counter = 0
	for i = 1,COLS do
		if field[i][ROWS] then
			GS.switch(State.gameover)
		end
		for k = ROWS,1,-1 do
			if field[i][k] then
				field[i][k].k = k+1
			end
			field[i][k+1] = field[i][k]
		end
		field[i][1] = row[i]
		row[i].k = 1
	end
	all_blocks.update_position()

	cursor.y = cursor.y + 1
	initialize_next_row()
	check_field()
end

-- time until adding the next row, depending on the current score and a penalty
local function time_to_next_row()
	return math.exp(-((State.game.points+penalty^2)/300)^2) * 40 + 2
end

Signal.register('puzzle-removed-blocks', function(n)
	love.audio.play(Sound.static.points)
	-- show combo counter
	if combo_counter >= 1 then
		local s = "x"..(2^math.max(0, combo_counter))
		if Sound.static[s] then
			Sound.static[s]:play()
		end
		local w = Font[30]:getWidth(s)
		local x,y = 190,60
		local o
		o = {
			r = -math.pi/8,
			s = 0,
			alpha = 0,
			draw = function()
				love.graphics.setColor(255,255,255, alpha)
				love.graphics.setFont(Font[50])
				love.graphics.print(s, x,y, o.r,o.s,o.s, w/2,15)
			end,
		}
		Timer.tween(.5, o, {s = combo_counter, r = math.pi/8, alpha = 255}, 'back', function()
			Timer.add(1, function()
				Timer.tween(.1, o, {s = 0, r = 0, alpha = 0}, 'quad', function() overlays[o] = nil end)
			end)
		end)
		overlays[o] = true
	end
	State.game.points = State.game.points + math.floor(n^1.1) * 2^math.max(0,combo_counter)
end)

local bad_things_have_happened = false
local function bad_things_happen(p)
	Sound.static.bad_thing:setPitch(1.5)
	love.audio.play(Sound.static.bad_thing)
	penalty = penalty + (p or love.math.random(5,10))
	State.game.points = math.ceil(State.game.points * .95)
	t = time_to_next_row()
	camera:shake(.3,10,10)

	if not bad_things_have_happened then
		Timer.add(.3, function() GS.push(State.tutorial, "bad_things", {
			"WOAH, DID YOU FEEL THAT?",
			"the earth just shook a little.",
			"well, more than just a little!",
			"I think I'm still in shock.",
			"Did that have to do with something that happened in pong"..(State.tutorial.seen.snake and " or snake?" or "?"),
			"Must have. I wouldn't do that to you.",
			"...",
			"Strange, didn't you have more points before?",
			"Also, that last row of blocks wasn't there before, was it?",
			"Hmm, my internal algorithms also tell me that new rows of blocks will come in faster.",
			"Better be careful from now on!",
			"Keep an eye on the other screen.",
		}) end)
		bad_things_have_happened = true
	end
end

Signal.register('pong-ball-out', function(dir)
	if dir < 0 then
		bad_things_happen()
	else
		State.game.points = State.game.points + 10 * 2^combo_counter
		combo_counter = math.max(combo_counter,1)

		local s = "x"..(2^math.max(0, combo_counter))
		if combo_counter >= 1 then
			Sound.static[s]:play()
		end
		local w = Font[30]:getWidth(s)
		local x,y = 190,60
		local o
		o = {
			r = -math.pi/8,
			s = 0,
			alpha = 0,
			draw = function()
				love.graphics.setColor(255,255,255, alpha)
				love.graphics.setFont(Font[50])
				love.graphics.print(s, x,y, o.r,o.s,o.s, w/2,15)
			end,
		}
		Timer.tween(.5, o, {s = combo_counter, r = math.pi/8, alpha = 255}, 'back', function()
			Timer.do_for(5, function() combo_counter = math.max(combo_counter,1) end, function()
				Timer.tween(.1, o, {s = 0, r = 0, alpha = 0}, 'quad', function() overlays[o] = nil end)
			end)
		end)
	
	end
end)

Signal.register('snake-bit-itself', function()
	bad_things_happen(15)
end)

Signal.register('snake-crashed', function()
	bad_things_happen()
end)

Signal.register('snake-eat-powerup', function(id, pos)
	love.audio.play(Sound.static.snake)
	Timer.tween(.05, camera, {scale=1.02}, 'quad', function()
		Timer.tween(.15, camera, {scale=1}, 'quad')
	end)
	local blocks, n = {}, 0
	all_blocks.map(function(b)
		if b.id == id and b.k > 0 then
			--assert(b == field[b.i][b.k], 'not me: '..tostring(b).. ' != '..tostring(field[b.i][b.k]))
			blocks[b] = {b.i,b.k}
			n = n + 1
		end
	end)
	if n > 0 then
		remove_blocks(blocks)
		check_field()
	end

	State.game.points = State.game.points + 5 * 2^combo_counter
end)

function mode:reset()
	all_blocks.map(function(b) all_blocks[b] = nil end)
	field = {}
	for i = 1,COLS do
		field[i] = {}
		for k = 1,ROWS/2 do
			local id = 0
			repeat
				id = love.math.random(1,5)
			until (i <= 2 or id ~= field[i-2][k].id) and (k <= 2 or id ~= field[i][k-2].id)
			field[i][k] = Block(i,k, id)
		end
		field[i].count = ROWS
	end
	cursor = vector(1,1)
	anim_barrier = Barrier()
	t, State.game.points, penalty, combo_counter = 0, 0, 0, 0
	initialize_next_row()

	love.graphics.setLineWidth(2)
end

function mode:update(dt)
	if not anim_barrier:is_free() then return end
	t = t + dt
	if t >= time_to_next_row() then
		add_row()
		t = 0
	end
end

function mode:update_active(dt)
end

function mode:draw()
	local row_progress = math.min(1, t/time_to_next_row())
	love.graphics.setColor(255,255,255)
	all_blocks.draw(row_progress)

	local x,y = to_screen(cursor.x, cursor.y + row_progress)
	if not anim_barrier:is_free() then
		love.graphics.setColor(200,200,200,100)
	end
	love.graphics.rectangle('line', x,y, 2*BLOCK_AREA, BLOCK_AREA)

	love.graphics.setColor(255,255,255)
	overlays.draw()
end

function mode:keypressed(key)
	if key == 'left' then
		cursor.x = math.max(1, cursor.x-1)
	elseif key == 'right' then
		cursor.x = math.min(COLS-1, cursor.x+1)
	elseif key == 'down' then
		cursor.y = math.max(1, cursor.y-1)
	elseif key == 'up' then
		cursor.y = math.min(ROWS, cursor.y+1)
	elseif key == ' ' then
		combo_counter = 0
		Sound.static.switch:setPitch(1.2)
		love.audio.play(Sound.static.switch)
		if not anim_barrier:is_free() then
			camera:shake(.1, 1,1)
			return
		end
		local i,k = cursor:unpack()
		if not (field[i][k] or field[i+1][k]) then return end

		local x1 = field[i+1][k] and field[i+1][k].pos.x or field[i][k].pos.x + BLOCK_AREA
		local x2 = field[i][k]   and field[i][k].pos.x   or field[i+1][k].pos.x - BLOCK_AREA

		anim_barrier:block()
		Timer.tween(.1, {field[i][k] or {pos={x=0}}, field[i+1][k] or {pos={x=0}}},
		                {{pos = {x = x1}}, {pos = {x = x2}}}, 'linear', function()
			field[i][k], field[i+1][k] = field[i+1][k], field[i][k]
			if field[i][k]   then field[i][k].i   = i end
			if field[i+1][k] then field[i+1][k].i = i+1 end
			if not field[i][k] or not field[i+1][k] then
				let_blocks_fall_down(i+1)
				let_blocks_fall_down(i)
				check_field()
			else
				check_field()
			end
			anim_barrier:done()
		end)
	elseif key == 'return' and anim_barrier:is_free() then
		add_row()
		t = 0
	end
end


Timer.add(2, function()
	GS.push(State.tutorial, "blocks", {
		"Oh, hi! I didn't see you there.",
		"Welcome to myself, the game!",
		"You look like a seasoned gamer.",
		"Maybe you have already made one or two games yourself?",
		"Thought so.",
		"Anyway, I think I should briefly explain myself.",
		"The white rectangle is your cursor.",
		"You can move the cursor with the arrow keys.",
		"You can swap blocks under the cursor by pressing <space>.",
		"FUN!",
		"My goal, or rather your goal, is to get as many points as you can.",
		"You get points by arranging three or more blocks with the same symbol in a row.",
		"These blocks will disappear and the blocks above them will fall down.",
		"Oh boy, how innovative!",
		"At the bottom, new blocks will pop in from time to time.",
		"The higher the score, the faster the blocks will come in.",
		"Though sometimes not fast enough.",
		"In that case, press <return>.",
		"That's it. Have fun!",
	})
end)

return mode
