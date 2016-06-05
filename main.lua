require("initialize")
require("draw")

function love.load()
  state = init_gamestate()
end

function love.draw()
  draw_city_map
end
