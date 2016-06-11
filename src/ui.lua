local ui = {}

local button_pool = {}
local function add_button(x, y, w, h, callback)
    table.insert(button_pool, {x=x, y=y, w=w, h=h, callback=callback})
end

local function add_text_button(x, y, length, callback)
    add_button(x, y, 5 * length, 20, callback)
end

local function draw_hud(origin_x, origin_y)
    love.graphics.setColor(255, 255, 255, 255)
    local hud_text = lume.format(
        "year: {year}\tmoney: {money}({true_balance})\tinfluence: {influence}\tpopularity:{popularity}\tpositions:{positions}",
        {money = lume.round(state.moses.money),
         year = string.format("%.2f", state.world.year),
         influence = lume.round(state.moses.influence),
         popularity = lume.round(state.moses.popularity),
         true_balance = lume.round(state.moses.true_balance),
         positions = lume.reduce(state.moses.positions, function(a, b) return a..b end)
        })
    love.graphics.print(hud_text, origin_x, origin_y)
    love.graphics.setColor(255, 0, 0, 255)
    love.graphics.print("RESIGN", 500, 0)
    add_text_button(500, 0, string.len("RESIGN"),
        function()
            logic.inter.resign()
        end)
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
        if action.type == "lawsuit" then
            header = header.."("..action.tile.id..")"
        elseif action.type == "grant" then
            header = header.."("..lume.round(action.amount / 100).."h)"
        elseif action.subtype then
            header = header.."("..action.subtype..")"
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

        -- influence button
        love.graphics.setColor(255, 100, 0, 255)
        local inf_x = x + bar_width + 5
        local inf_y = y + bar_height / 2
        local inf_text = "Inf"
        love.graphics.print(inf_text,  inf_x, inf_y)
        add_text_button(inf_x, inf_y, string.len(inf_text),
            function()
                logic.inter.add_influence(action)
            end)

        -- lawsuit button
        if action.type == "lawsuit" then
            love.graphics.setColor(200, 200, 0, 255)
            action.settle_price = 2 * action.tile.cost
            local settle_x = x + bar_width + 30
            local settle_y = y + bar_height / 2
            local settle_text = "Settle("..action.settle_price..")"
            love.graphics.print(settle_text,  settle_x, settle_y)
            add_text_button(settle_x, settle_y, string.len(settle_text),
                function()
                    logic.inter.settle(action)
                end)
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

        -- add button to build tile
        add_button(box_origin_x, box_origin_y, square_width, square_height,
            function()
                if not tile.is_completed and not tile.is_started then
                    logic.inter.build_tile(tile.id)
                end
            end)

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
        love.graphics.setColor(100, 150 + tile.cost / 5, 100, 255)
        local cost_text = lume.round(tile.cost / 100)..'h'
        love.graphics.print(cost_text, box_origin_x, box_origin_y + 15)
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
        if tile.x_origin < x and tile.x_end >= x and
           tile.y_origin < y and tile.y_end >= y then
            return(key)
        end
    end
    return false
end

function ui.draw(dt)
    button_pool = {}  --- clear button pool
    draw_city_map(0, 30, love.graphics.getWidth() - 200, love.graphics.getHeight() - 100)
    draw_legal(love.graphics.getWidth() - 200, 10)
    draw_hud(0, 0)
end

function ui.onclick(x, y)
    for _, b in ipairs(button_pool) do
        if utils.box_contains(b, x, y) then
            b.callback()
        end
    end
end

return ui
