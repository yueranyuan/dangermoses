function draw_city_map()
    local screen_width = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()

    local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

    local tile_nums = {}
    local tile_letters = {}

    for k, v in pairs(state.tiles) do
        local letter = string.find(alphabet, string.sub(k, 1, 1))
        local num = string.sub(k, 2, 2)
        table.insert(tile_letters, letter)
        table.insert(tile_nums, num)
    end

    local grid_width = math.max(unpack(tile_nums))
    local grid_height = math.max(unpack(tile_letters))

    local square_width = screen_width / grid_width
    local square_height = screen_height / grid_height

    for k, tile in pairs(state.tiles) do
        local letter = string.sub(k, 1, 1)
        local y_value = string.sub(k, 2, 2) - 1
        local x_value = string.find(alphabet, letter) - 1

        local box_origin_x = x_value * square_width
        local box_origin_y = y_value * square_height

        love.graphics.setColor(255, 255, 255, 255)

        -- Draw letters to label grid tiles.
        love.graphics.print(letter..y_value, box_origin_x + square_width / 2,
                            box_origin_y)

        -- Draw grid tiles.
        love.graphics.rectangle("line",
          box_origin_x,
          box_origin_y,
          box_origin_x + square_width,
          box_origin_y + square_height)

        -- Draw values for cost.
        love.graphics.setColor(100, 255, 100, 255)
        love.graphics.print(tile.cost, box_origin_x, box_origin_y + 15)
        love.graphics.setColor(255, 100, 100, 255)
        love.graphics.print(tile.building_type, box_origin_x, box_origin_y + 30)
    end
end
