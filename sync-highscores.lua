local http = require 'socket.http'
local url = require 'socket.url'
love.filesystem = require 'love.filesystem'

local ch = love.thread.getChannel('highscores')

local f = assert(love.filesystem.newFile('sco.res', 'r'))
local scores = {}
for l in f:lines() do
	scores[#scores+1] = l
end
f:close()

-- send highscores
local body = 'scores='..url.escape(table.concat(scores, '\n'))
local r = assert(http.request('http://vrld.org/highscores/ld31', body))
ch:push(r)
