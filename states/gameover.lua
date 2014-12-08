local st = {}

local canvas
function st:init()
	canvas = love.graphics.newCanvas()
	self.name = {text = ""}
end

local names = {
	'barmpot',
	'berk',
	'slowpoke',
	'muppet',
	'dimwit',
	'halfwit',
	'blockhead',
	'dunce',
	'cretin',
	'dullard',
	'dum-dum',
	'noodle'
}

local switching = false
function st:enter(pre)
	canvas:clear()
	canvas:renderTo(function() pre:draw() end)
	switching = false
end

function st:draw()
	draw_blurred(canvas, 7)
	love.graphics.setColor(20,16,10,190)
	love.graphics.rectangle('fill', 0,0, WIDTH, HEIGHT)

	gui.core.draw()
end

local hot
function st:update(dt)
	love.graphics.setFont(Font[90])
	gui.group.push{grow = 'down', pos = {20,120}, size={WIDTH-40,50}}
	gui.Label{text = "GAME OVER", align = "center"}
	love.graphics.setFont(Font[40])
	gui.Label{text = "Final Score: " .. State.game.points, align = "center", pos = {nil,70}}
	gui.Label{text = "", size = {nil,20}}

	love.graphics.setFont(Font[30])
	gui.group.push{grow = 'right', pos = {160}, size={WIDTH/2-180}}
	gui.Label{text = "Your name: ", align = "left"}
	gui.Input{info = self.name}
	gui.group.pop{}

	if gui.Button{text = "OK", pos = {(WIDTH-40-250)/2,100}, size = {250}} and not switching then
		switching = true
		if self.name.text == "" then
			local n, i = names[love.math.random(#names)], 0
			Timer.addPeriodic(.2, function()
				i = i + 1
				self.name.text = n:sub(1,i)
				self.name.cursor = i
				if i == #n then
					Timer.add(1, function()
						GS.transition(State.menu)

						add_highscore(State.game.points, self.name.text)
						if sync_highscores then
							sync_highscores_threaded()
						end
					end)
					return false
				end
			end)
			return
		end

		add_highscore(State.game.points, self.name.text)
		if sync_highscores then
			sync_highscores_threaded()
		end
		GS.transition(State.menu)
	end

	gui.group.pop{}

	local h = gui.mouse.getHot()
	if h ~= hot and h ~= nil then
		Sound.static.btn:play()
	end
	hot = h
end

function st:leave()
end

function st:textinput(text)
	gui.keyboard.textinput(text)
end

function st:keypressed(key)
	gui.keyboard.pressed(key)
end

return st
