--
-- Created by IntelliJ IDEA.
-- User: yueran
-- Date: 6/8/16
-- Time: 3:45 AM
-- To change this template use File | Settings | File Templates.
--

--- All globals are set here
lume = require "extern/lume"
log = require "extern/log"
utils = require "src/utils"
state = require "src/setup"
consts = require "src/consts"
logic = require "src/logic"
ui = require "src/ui"

function love.mousepressed(x, y, button, istouch)
    ui.onclick(x, y)
end

function love.load()
    log.outfile = "runlog.txt"
    log.trace("new game")
    log.level = "trace"
end

function love.update(dt)
    logic.update(dt)
end

function love.draw(dt)
    ui.draw(dt)
end
