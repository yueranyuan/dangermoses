local ui = {}

local function draw_hud(origin_x, origin_y)
    local money = lume.round(state.moses.money)
    local year = lume.round(state.world.year * 100)
    local influence = lume.round(state.moses.influence)
    local popularity = lume.round(state.moses.popularity)
    love.graphics.setColor(255, 255, 255, 255)
    local hud_text = "year: "..year.."    money: "..money.."      influence: "..influence.."      popularity: "..popularity
    hud_text = hud_text.."   positions: "
    for _, position in ipairs(state.moses.positions) do
        hud_text = hud_text.." "..position
    end
    love.graphics.print(hud_text, origin_x, origin_y)
    love.graphics.setColor(255, 0, 0, 255)
    love.graphics.print("RESIGN", 500, 0)
end

local function check_word_collision(x, y, x2, y2)
    return x > x2 and x < x2 + 30 and y > y2 and y < y2 + 20
end

local function check_resignation(x, y)
    return check_word_collision(x, y, 500, 0)
end

local function draw_legal(origin_x, origin_y, width, height)

    local bar_height = 40
    local bar_width = 60

    local x = origin_x + 10
    for action_i, action in pairs(state.legal) do
        local bar_percentage = action.position / action.total
        love.graphics.setColor(255, 255, 255, 255)
        local y = origin_y + bar_height * action_i
        local header = action.type
        if action.type == "nomination" then
            header = header.."("..action.subtype..")"
        elseif action.type == "lawsuit" then
            header = header.."("..action.tile.id..")"
        end
        love.graphics.print(header, x + bar_width + 5, y)
        -- Draw background for legal bars.
        love.graphics.rectangle("fill", x, y + 5, bar_width, bar_height - 10)
        -- Progress bar for lawsuits.
        love.graphics.setColor(0, 255, 0, 255)
        if bar_percentage > 0.80 then
            love.graphics.setColor(255, 100, 0, 255)
        end
        love.graphics.rectangle("fill", x, y + 5, bar_width * bar_percentage, bar_height - 10)
        -- Line linking legal action to tile
        if action.tile then
            for key, tile in pairs(tile_table) do
                if key == action.tile.id then
                    love.graphics.line(x, y + 5, tile.x_origin, tile.y_origin)
                end
            end
        end
        -- Building bar for lawsuits
        if action.tile then
            love.graphics.setColor(255, 255, 255, 255)
            love.graphics.rectangle("fill", x, y + 5, bar_width, 5)
            local build_bar_percentage = (action.tile.elapsed_construction_time / action.tile.construction_time)
            love.graphics.setColor(0, 0, 255, 255)
            love.graphics.rectangle("fill", x, y + 5, bar_width * build_bar_percentage, 5)
        end
        -- stats
        love.graphics.setColor(0, 255, 0, 255)
        love.graphics.print('+'..action.pros..' -'..action.cons..' exp:'..lume.round(action.expiration_time),
            x + bar_width + 5, y + 30)

        -- buttons
        love.graphics.setColor(255, 100, 0, 255)
        action.inf_x = x + bar_width + 5
        action.inf_y = y + bar_height / 2
        love.graphics.print("Inf",  action.inf_x, action.inf_y)

        if action.type == "lawsuit" then
            love.graphics.setColor(200, 200, 0, 255)
            action.settle_x = x + bar_width + 35
            action.settle_y = y + bar_height / 2
            action.settle_price = 2 * action.tile.cost
            love.graphics.print("Settle("..action.settle_price..")",  action.settle_x, action.settle_y)
        end
    end
end

local function get_influence_button(x, y)
    for action_i, action in pairs(state.legal) do
        if check_word_collision(x, y, action.inf_x, action.inf_y) then
            return action
        end
    end
end

local function get_settle_button(x, y)
    for action_i, action in pairs(state.legal) do
        if action.settle_price then
            if check_word_collision(x, y, action.settle_x, action.settle_y) then
                return action
            end
        end
    end
end

local function draw_city_map(origin_x, origin_y, width, height)
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
            love.graphics.setColor(100, 150, 200, 100 + progress * 155)
            love.graphics.rectangle("fill", box_origin_x + 2 * square_width / 3,
                box_origin_y, square_width / 3, square_height * progress)
        end

        -- Draw whether or not you're getting sued somewhere.
        if tile.lawsuit then
            love.graphics.setColor(255, 0, 0, 100)
            love.graphics.rectangle("fill", box_origin_x + 2, box_origin_y + 2,
                square_width - 4, square_height - 4)
        end
        -- Draw if the building is built.
        if tile.is_completed then
            love.graphics.setColor(200, 200, 200, 100)
            love.graphics.rectangle("fill", box_origin_x + 2, box_origin_y + 2,
                square_width - 4, square_height - 4)
        end
        -- Draw if a building has been approved.
        if tile.is_approved then
            love.graphics.setColor(0, 255, 0, 100)
            love.graphics.rectangle("fill", box_origin_x + 2, box_origin_y + 2,
                square_width - 4, square_height - 4)
        end
    end
end

local function get_cell(x, y)
    -- Given an xy coordinate, return which cell that corresponds to.
    for key, tile in pairs(tile_table) do
        print(tile.x_origin, tile.y_origin)
        if tile.x_origin < x and tile.x_end >= x and
           tile.y_origin < y and tile.y_end >= y then
            return(key)
        end
    end
    return false
end

function ui.draw(dt)
    draw_city_map(0, 30, love.graphics.getWidth() - 200, love.graphics.getHeight() - 100)
    draw_legal(love.graphics.getWidth() - 200, 10)
    draw_hud(0, 0)
end

function ui.onclick(x, y)
    local tile = get_cell(x, y)
    if tile and not tile.is_completed and not tile.is_started then
        logic.inter.build_tile(tile)
    end

    local action = get_influence_button(x, y)
    if action then
        logic.inter.add_influence(action)
    end

    local action = get_settle_button(x, y)
    if action then
        logic.inter.settle(action)
    end

    if check_resignation(x, y) then
        logic.inter.resign()
    end
end

return ui
