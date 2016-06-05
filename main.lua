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
    function love.mousepressed(x, y, button, istouch)
        if button == 1 then
            print(get_cell(x, y))
        end
    end
end

function love.draw()
    draw_city_map(50, 10, love.graphics.getWidth() - 200, love.graphics.getHeight() - 100)
end
