require("initialize")
require("update")
require("draw")

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
    draw_city_map(50, 30, love.graphics.getWidth() - 200, love.graphics.getHeight() - 100)
    draw_legal(love.graphics.getWidth() - 150, 10)
<<<<<<< HEAD
    draw_moses()
=======
    draw_hud(0, 0)
>>>>>>> 6b719d66375fc8d8669ebeead9271b1ddd2cd4f5
end
