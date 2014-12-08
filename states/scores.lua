local st = {}

function st:draw()
	State.menu:draw()
end

function st:update(dt)
	love.graphics.setFont(Font[90])
	gui.group.push{grow = 'down', pos = {20,20}, size={WIDTH-40,30}}
	gui.Label{text = "LD 31", align = "center", size={nil,50}}
	love.graphics.setFont(Font[40])
	gui.Label{text = "ENTIRE GAME ON ONE SCREEN", align = "center", size={nil,50}}
	gui.Label{text = "", align = "center", size={nil,30}}

	if not show_options then
		love.graphics.setColor(100,100,100,100)
		love.graphics.setFont(Font[40])
		gui.Label{text = "Highscores", align = "center"}
		love.graphics.setFont(Font[20])
		for i = 1,math.min(#Highscores,10) do
			local s = Highscores[i]
			gui.group.push{grow='right', pos = {250}, size = {130,30}}
			gui.Label{text = i..'. '..s.name, align='left'}
			gui.Label{text = s.score, align='right'}
			gui.group.pop{}
		end
	end

	gui.group.pop{}

	love.graphics.setFont(Font[30])
	gui.group.push{grow = 'right', pos = {WIDTH-210,HEIGHT-70}, size={190,50}}
	if gui.Button{text = 'Back'} then
		GS.pop()
	end
	gui.group.pop{}
end

function st:keypressed(key)
	if key == 'escape' then
		GS.pop()
	end
end

return st
