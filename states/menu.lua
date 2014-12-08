local st = {}

local canvas

local show_options
function st:init()
	canvas = love.graphics.newCanvas()
end

function st:enter()
	show_options = false
	Highscores = load_highscores()
end

function st:draw()
	love.graphics.setColor(100,100,100,100)
	canvas:clear(0,0,0,0)
	canvas:renderTo(function()
		love.graphics.draw(Image.blocks_large, WIDTH/2,HEIGHT/2, 0,1,1, 720/2,129/2)
	end)
	love.graphics.setColor(255,255,255)
	draw_blurred(canvas,7)
	gui.core.draw()
end

local hot
function st:update(dt)
	love.graphics.setFont(Font[80])
	gui.group.push{grow = 'down', pos = {20,20}, size={WIDTH-40,80}}
	gui.Label{text = "Panoptes", align = "center"}

	if not show_options then
		love.graphics.setColor(100,100,100,100)
		love.graphics.setFont(Font[40])
		gui.Label{text = "Highscores", align = "center",pos={nil,20}}
		love.graphics.setFont(Font[20])
		for i = 1,math.min(#Highscores,8) do
			local s = Highscores[i]
			gui.group.push{grow='right', pos = {80}, size = {160,30}}
			gui.Label{text = i..'. '..s.name, align='left'}
			gui.Label{text = s.score, align='right', size = {70}}

			local s = Highscores[i+8]
			if s then
				gui.Label{text = (10+i)..'. '..s.name, align='left', pos={140}}
				gui.Label{text = s.score, align='right', size = {70}}
			end
			gui.group.pop{}
		end
	end

	gui.group.pop{}

	love.graphics.setColor(255,255,255)
	love.graphics.setFont(Font[30])
	gui.group.push{grow = 'right', pos = {18,HEIGHT-70}, size={190,50}}
	if gui.Button{text = 'Start'} then
		GS.transition(State.game, 1)
	end

	gui.group.push{grow = 'up'}
	if gui.Button{text = 'Options'} then
		show_options = not show_options
	end
	if show_options then
		love.graphics.setFont(Font[20])
		if gui.Checkbox{checked = use_shaders, text = "Use Shaders"} then
			if not love.graphics.isSupported('shader') then
				GS.push(State.message, "Dang it!",
				"Shaders are not suppported on your system.\nSorry about that.")
				return
			end
			use_shaders = not use_shaders
		end
		if gui.Checkbox{checked = sync_highscores, text = "Sync Highscores"} then
			sync_highscores = not sync_highscores
		end
		if gui.Checkbox{checked = show_tutorial, text = "Show tutorial"} then
			show_tutorial = not show_tutorial
		end
		love.graphics.setFont(Font[30])
	end
	gui.group.pop{}

	if gui.Button{text = 'Credits'} then
		GS.push(State.credits)
	end
	if gui.Button{text = 'Exit'} then
		love.event.push('quit')
	end
	gui.group.pop{}

	local h = gui.mouse.getHot()
	if h ~= hot and h ~= nil then
		Sound.static.btn:play()
	end
	hot = h
end

return st
