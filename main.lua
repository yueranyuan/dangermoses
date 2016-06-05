require("initialize")

function love.load()
    state = init_gamestate()
end

function love.draw()
    local v = state['tiles']['C1']['building_type']
    love.graphics.print(v, 300, 300)
end
