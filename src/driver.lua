--
-- Created by IntelliJ IDEA.
-- User: yueran
-- Date: 6/8/16
-- Time: 3:45 AM
-- To change this template use File | Settings | File Templates.
--

require("src/initialize")
require("src/update")
require("src/draw")

function love.mousepressed(x, y, button, istouch)
    on_click(x, y)
end

function love.load()
    state = init_gamestate()
end

function love.update(dt)
    update(dt)
end

function love.draw()
    draw_city_map(0, 30, love.graphics.getWidth() - 200, love.graphics.getHeight() - 100)
    draw_legal(love.graphics.getWidth() - 200, 10)
    draw_hud(0, 0)
end
