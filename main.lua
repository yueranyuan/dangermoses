require("initialize")
require("update")
require("draw")

function love.load()
  state = init_gamestate()
end

function love.update(dt)
    update(dt)
end

function love.draw()
  draw_city_map()
end
