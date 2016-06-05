function draw_city_map(origin_x, origin_y, width, height)

    local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

    local tile_nums = {}
    local tile_letters = {}

    -- Table to hold coordinates for each cell in the grid.
    tile_table = {}

    for k, v in pairs(state.tiles) do
        local letter = string.find(alphabet, string.sub(k, 1, 1))
        local num = string.sub(k, 2, #k)
        table.insert(tile_letters, letter)
        table.insert(tile_nums, num)
    end

    local grid_width = math.max(unpack(tile_nums))
    local grid_height = math.max(unpack(tile_letters))

    local square_width = width / grid_width
    local square_height = height / grid_height

    for k, tile in pairs(state.tiles) do
        local letter = string.sub(k, 1, 1)
        local y_value = string.sub(k, 2, #k) - 1
        local x_value = string.find(alphabet, letter) - 1

        local box_origin_x = origin_x + x_value * square_width
        local box_origin_y = origin_y + y_value * square_height

        -- Add coordinates to the tile table.
        tile_table[k] = { x_origin = box_origin_x, y_origin = box_origin_y,
            x_end = box_origin_x + square_width, y_end = box_origin_y + square_height }

        love.graphics.setColor(255, 255, 255, 255)

        -- Draw letters to label grid tiles.
        love.graphics.print(letter..(y_value + 1), box_origin_x + square_width / 2,
            box_origin_y)
        -- Draw grid tiles.
        love.graphics.rectangle("line", box_origin_x, box_origin_y,
            square_width, square_height)

        -- Draw values for cost.
        love.graphics.setColor(100, 255, 100, 255)
        love.graphics.print(tile.cost, box_origin_x, box_origin_y + 15)
        love.graphics.setColor(255, 100, 100, 255)
        love.graphics.print(tile.building_type, box_origin_x, box_origin_y + 30)

        -- Draw in-progress building.
        if tile.is_started and not tile.is_completed then
            local progress = tile.elapsed_construction_time / tile.construction_time
            love.graphics.setColor(100, 150, 200, progress * 150)
            love.graphics.rectangle("fill", box_origin_x, box_origin_y + box_height,
                square_width / 3, box_height - (box_height * progress))
        end
    end
end

-- Given an xy coordinate, return which cell that corresponds to.
function get_cell(x, y)
    for key, tile in pairs(tile_table) do
        if tile.x_origin < x and tile.x_end >= x and
           tile.y_origin < y and tile.y_end >= y then
            return(key)
        end
    end
end
