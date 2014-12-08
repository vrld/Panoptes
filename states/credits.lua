local st = {}

function st:draw()
	State.menu:draw()
end

local hot
function st:update(dt)
	love.graphics.setFont(Font[80])
	gui.group.push{grow = 'down', pos = {20,20}, size={WIDTH-40,30}}
	gui.Label{text = "panoptes", align = "center", size={nil,80}}
	love.graphics.setFont(Font[40])
	gui.Label{text = "", align = "center", size={nil,30}}

	love.graphics.setFont(Font[40])
	gui.Label{text = "A game by vrld", align = "center"}
	love.graphics.setFont(Font[20])
	gui.Label{text = "Made in 48 hours for the 31st ludum dare", align = "center"}
	gui.Label{text = "themed: entire game on one screen", align = "center"}
	love.graphics.setFont(Font[25])
	gui.Label{text = "Made with LOVE (love2d.org)", align = "center"}
	gui.Label{text = "Font: Silkscreen by Jason Kotte (kotte.org)", align = "center"}

	gui.Label{text = "", align = "center", size={nil,50}}
	love.graphics.setFont(Font[40])
	gui.Label{text = "Shout out goes to", align = "center"}
	love.graphics.setFont(Font[25])
	gui.Label{text = "cappel:nord, fysx, headchant, steven colling", align = "center"}
	gui.Label{text = "bartbes, bmelts, rude, slime", align = "center"}
	gui.Label{text = "and all the lovers out there", align = "center"}
	gui.group.pop{}

	love.graphics.setFont(Font[30])
	gui.group.push{grow = 'right', pos = {WIDTH-210,HEIGHT-70}, size={190,50}}
	if gui.Button{text = 'Back'} then
		GS.pop()
	end
	gui.group.pop{}

	local h = gui.mouse.getHot()
	if h ~= hot and h ~= nil then
		Sound.static.btn:play()
	end
	hot = h
end

function st:keypressed(key)
	if key == 'escape' then
		GS.pop()
	end
end

return st
