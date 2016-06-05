require("initialize")
require("update")

function love.load()
    state = init_gamestate()
end

function love.update(dt)
    update(dt)
end

function love.draw()
    local v = state['tiles']['C1']['building_type']
    love.graphics.print(v, 300, 300)
end
