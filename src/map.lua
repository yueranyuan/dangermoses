class "Building" (Object) {
    --PATTERNS = {"building1", "building2", "building3", "building4", "building5"},
    --PATTERNS = {"head", "plane", "tree", "scorp", "eagle"},
    PATTERNS = {park={"6s", "6m", "6l", "6xl"},
                road={"2s", "2m", "2l", "2xl"},
                tenament={"1s", "1m", "1l", "1xl"},
                washington={"3s", "3m", "3l", "3xl"},
                adams={"4s", "4m", "4l", "4xl"},
                jefferson={"5s", "5m", "5l", "5xl"}},
    all_imgs = {},

    __init__ = function(self, pattern, type)
        self.img = Building.all_imgs[pattern]
        assert(self.img ~= nil)
        self.type = type
        self.color = Map.TYPES[self.type]
        self.coord = v(0, 0)  -- why not named pos? because pos is for world coordinates
        self:super(Building).__init__(self)
    end,
--
    change_type = function(self, new_type)
        self.type = new_type
        self.color = Map.TYPES[self.type]
    end,

    draw = function() end,
}

lume.each(lume.set(utils.concat_arr(Building.PATTERNS)), function(v)
    Building.all_imgs[v] = love.graphics.newImage("grafix/buildings/"..v..".png")
end)

function load_grid(inp_grid, cell_func)
    local grid = {}
    for y = 1, #inp_grid do
        local row = {}
        for x = 1, #inp_grid[y] do
            local val = inp_grid[y][x]
            local out = cell_func(val, x, y)
            row[x] = out
        end
        grid[y] = row
    end
    return grid
end


class "Map" (Object){
    TYPES = {park={150, 230, 100}, tenament={136, 136, 250}, road={250, 180, 130},
            washington={255, 252, 157},
            adams={251, 133, 219},
            jefferson={123, 255, 253}},
    TYPE_ORDER = {'park', 'tenament', 'road', 'washington', 'adams', 'jefferson'},
    --PERSON_TYPES = {hater={80, 80, 80}, moses={230, 230, 230}},
    PERSON_TYPES = {hater={80, 80, 80}, park={150, 230, 100}, tenament={136, 136, 250}, road={250, 180, 130},
            washington={255, 252, 157},
            adams={251, 133, 219},
            jefferson={123, 255, 253},
            madison={122, 135, 111}},
    --DISTRICTS = {queens={255, 253, 56}, brooklyn={176, 176, 176}, manhattan={147, 39, 144}},
    DISTRICTS = {land={0, 0, 0}},

    FLICKER_FREQUENCY = 5,
    FLICKER_MOD = 3,

    __init__ = function(self, w, h)
        self:super(Map).__init__(self)

        self.bg = love.graphics.newImage("grafix/map_bg.png")
        -- load grid from map image
        local map_type_img = love.graphics.newImage("grafix/map_type.png")

        self.grid = load_grid(utils.img_to_grid(map_type_img), function(val)
            for type, color in pairs(Map.TYPES) do
                if val[1] == color[1] and val[2] == color[2] and val[3] == color[3] then
                    return type
                end
            end
            return "empty"
        end)
        self.height = #self.grid
        self.width = #self.grid[1]

        -- load district map
        local map_district_img = love.graphics.newImage("grafix/map_district.png")
        self.district_grid = load_grid(utils.img_to_grid(map_district_img), function(val)
            for district, color in pairs(Map.DISTRICTS) do
                if val[1] == color[1] and val[2] == color[2] and val[3] == color[3] then
                    return district
                end
            end
            return "water"
        end)
        assert(#self.district_grid == #self.grid and #self.district_grid[1] == #self.grid[1])

        -- auto-gen map.csv
        local map_gen_img = love.graphics.newImage("grafix/map_gen.png")
        local full_committee_grid = load_grid(utils.img_to_grid(map_gen_img), function(val)
            for type, color in pairs(Map.TYPES) do
                if val[1] == color[1] and val[2] == color[2] and val[3] == color[3] then
                    return type
                end
            end
            return "empty"
        end)
        local map_csv_grid = load_grid(full_committee_grid, function(cell, x, y)
            if cell == "empty" or self.district_grid[y][x] == "water" then
                return " "
            end

            -- fill the tile
            local rando = math.random()
            local type_idx = lume.find(Map.TYPE_ORDER, cell)
            local shittiness = (SHITTINESS_BASE + SHITTINESS_SLOPE * type_idx) / 100
            local pure_hater_thresh = SUPPORTER_CHANCE + (1 - SUPPORTER_CHANCE) * shittiness * PURE_HATER_PERCENTAGE
            local other_hater_thresh = SUPPORTER_CHANCE + (1 - SUPPORTER_CHANCE) * shittiness
            if rando < SUPPORTER_CHANCE then  -- supporter
                return cell:sub(1, 1)
            elseif rando < pure_hater_thresh then  -- pure hater
                return 'h'
            elseif rando < other_hater_thresh then -- hater of another color
                -- choose haters of neighboring committees
                local neighbors = lume.map({-2, -1, 1, 2}, function(idx)
                    return Map.TYPE_ORDER[math.min(math.max(1, type_idx - idx), #Map.TYPE_ORDER)]
                end)
                neighbors = lume.filter(neighbors, function(ne) return ne ~= cell end)
                return lume.randomchoice(neighbors):sub(1, 1)
            else
                return " "
            end
        end)
        -- add the powerups
        local used_coords = {}
        for name, n in pairs(FLOOR_POWERUP_DISTRIBUTION) do
            for _ = 1, n do
                local coord
                for try_i = 1,1000 do  -- find a place that is unique
                    coord = v(math.ceil(math.random() * #map_csv_grid[1]),
                              math.ceil(math.random() * #map_csv_grid))
                    if lume.find(used_coords, coord) == nil and self.district_grid[coord.y][coord.x] ~= "water" then
                        break
                    end
                end
                map_csv_grid[coord.y][coord.x] = name
                table.insert(used_coords, coord)
            end
        end
        -- write to file so we have a version we can edit
        local file = io.open("map_rand.csv", "w")
        io.output(file)
        for y = 1, #map_csv_grid do
            if y > 1 then
                io.write('\n')
            end
            for x = 1, #map_csv_grid[y] do
                if x > 1 then
                    io.write(',')
                end
                io.write(map_csv_grid[y][x])
            end
        end
        io.close(file)
        io.output(io.stdout)

        -- make people
        -- empty grid first
        if MAP_CSV then
            local f = csv.open(arg[1].."/"..MAP_CSV)
            local map_csv_grid = {}
            for line in f:lines() do
                table.insert(map_csv_grid, line)
            end
        end
        -- initialize empty people grid
        self.people = {}
        self.people_grid = {}
        for y = 0, h - 1 do
            local row = {}
            for x = 0, w - 1 do
                row[x+1] = "none"
            end
            self.people_grid[y+1] = row
        end
        self.floor_powerups = {}
        -- fill empty grid
        local person_dict = {r="road", p="park", t="tenament", h="hater", m="jefferson",
                             w="washington", a="adams", j="jefferson", d="madison"}
        local powerup_dict = {}
        for _, powerup_class in ipairs(PowerupTray.POWERS) do
            powerup_dict[powerup_class.name] = powerup_class
        end
        for y, fields in ipairs(map_csv_grid) do
            for x, p in ipairs(fields) do
                self.people_grid[y][x] = "none"
                if powerup_dict[p:sub(1, #p-1)] then
                    local powerup = powerup_dict[p:sub(1, #p-1)]
                    local n = tonumber(p:sub(#p, #p))
                    local fpu = FloorPowerup(v(x, y), powerup, n)
                    table.insert(self.floor_powerups, fpu)
                elseif powerup_dict[p] then
                    local fpu = FloorPowerup(v(x, y), powerup_dict[p])
                    table.insert(self.floor_powerups, fpu)
                elseif person_dict[p:sub(1, 1)] then
                    local density = 1
                    if #p > 1 then
                        density = tonumber(p:sub(2, #p))
                    end
                    local person = Person(v(x, y), person_dict[p:sub(1, 1)], density)
                    self.people_grid[y][x] = person
                    table.insert(self.people, person)
                end
            end
        end

        self.pending_plans = {}
        self.n_pending_tiles = 0
        self.flicker_time = 0
        self.flicker_idx = 0
    end,

    draw_cell = function(self, coord, color, border)
        if border == nil then
            border = 0
        end
        if color == nil then
            color = Map.TYPES[self.grid[coord.y][coord.x]]
            if color == nil then color = {255, 255, 255, 150} end
            color = {color[1], color[2], color[3], 150}
        end
        if color ~= nil then
            self:lgSetColor(color)
            lg.rectangle("fill", (coord.x-1) * MAP_SCALE - border, (coord.y-1) * MAP_SCALE - border,
                         MAP_SCALE + 2 * border, MAP_SCALE + 2 * border)
        end
    end,

    update_n_pending_tiles = function(self)
        local pending_cells = utils.set(utils.concat_arr(lume.map(self.pending_plans, "cells")))
        self.n_pending_tiles = #lume.filter(pending_cells, function(c) return self.grid[c.y][c.x] == 'empty' end)
    end,

    try_building = function(self, builder, building)
        -- Play the jackhammer sound indicating you started a building.
        sfx_jackhammer:play()
        local plan = Plan(builder, building)
        table.insert(self.pending_plans, Plan(builder, building))
        -- TEMP
        local fpu  = self.floor_powerups[1]
        self:update_n_pending_tiles()
    end,

    place_building = function(self, builder, building)
        -- Play the sound for the building succeeding.
        -- change cells and remove people
        local cells = Plan.static.get_cell_collisions(building)
        local new_supporters = {}
        for _, coord in ipairs(cells) do
            if self.grid[coord.y][coord.x] == 'empty' then
                builder.built_cells = builder.built_cells + 1
            end
            self.grid[coord.y][coord.x] = building.type
            -- remove person
            local person = self.people_grid[coord.y][coord.x]
            if person ~= 'none' then
                if person:check_state(building.type) == "happy" then
                    table.insert(new_supporters, person)
                end
                lume.remove(self.people, person)
                person:destroy()
                self.people_grid[coord.y][coord.x] = 'none'
            end
        end
        government.moses_office:add_supporters(new_supporters)

        self:remove_pending_building(building)
        -- get floor powerups
        local active_floor_powerups = Plan.static.get_active_floor_powerups(cells)
        for _, fpu in ipairs(active_floor_powerups) do
            fpu:pickup()
        end
    end,

    remove_pending_building = function(self, building)
        -- remove pending plan
        for plan_i, plan in lume.ripairs(self.pending_plans) do
            if plan.building == building then
                table.remove(self.pending_plans, plan_i)
            end
        end
        self:update_n_pending_tiles()
    end,

    update = function(self, dt)
        -- update the various cached reactions of the hovering building
        for _, person in ipairs(self.people) do
            person.state = "neutral"
        end
        if player.plan then
            for _, person in ipairs(player.plan.people) do
                person.state = person:check_state(player.plan.building.type)
            end
        end

        -- update flickering
        self.flicker_time = self.flicker_time + dt
        while self.flicker_time > 1 / self.FLICKER_FREQUENCY do
            self.flicker_time = self.flicker_time - 1 / self.FLICKER_FREQUENCY
            self.flicker_idx = (self.flicker_idx + 1) % self.FLICKER_MOD
        end
    end,

    draw = function(self)
        self:lgSetColor(255, 255, 255)
        lg.draw(self.bg, 0, 0, 0, MAP_SCALE / 4)

        -- draw the base map
        for y = 1, #self.grid do
            for x = 1, #self.grid[1] do
                if self.district_grid[y][x] ~= "water" then
                    self:draw_cell(v(x, y))
                end
            end
        end

        -- draw the pending building
        for _, plan in ipairs(self.pending_plans) do
            -- draw boundaries
            for _, coord in ipairs(plan.cells) do
                if self.district_grid[coord.y][coord.x] ~= "water" then
                    self:draw_cell(coord, {0, 0, 0}, 1)
                end
            end
            -- draw color center
            for _, coord in ipairs(plan.cells) do
                if self.district_grid[coord.y][coord.x] ~= "water" then
                    local color = 200
                    if (coord.x - self.flicker_idx) % self.FLICKER_MOD == 0 then
                        color = 255
                    end
                    self:draw_cell(coord, lume.concat(plan.building.color, {color}))
                end
            end
        end

        -- draw the hovering building
        if player.plan then
            -- draw boundaries
            for _, coord in ipairs(player.plan.cells) do
                if self.district_grid[coord.y][coord.x] ~= "water" then
                    self:draw_cell(coord, {0, 0, 0}, 1)
                end
            end
            -- draw color center
            for _, coord in ipairs(player.plan.cells) do
                if self.district_grid[coord.y][coord.x] ~= "water" then
                    --local color = player.plan.building.color
                    local color = {255, 255, 255, 50}
                    self:draw_cell(coord) -- draw original color first
                    self:draw_cell(coord, color)
                end
            end
        end
    end
}

class "Person" (Object) {
    PERSON_IMG = lg.newImage("grafix/person.png"),

    __init__ = function(self, local_pos, type, density)
        self.local_pos = local_pos
        self.density = density
        self.type = type
        self.state = 'neutral'
        self.base_color = Map.PERSON_TYPES[self.type]
        self.color = self.base_color
        self.img = Person.PERSON_IMG
        self:super(Person).__init__(self)
        self.pos = (local_pos - 0.5) * MAP_SCALE
        self.pos.x = self.pos.x - self.shape.x / 2
        self.pos.y = self.pos.y - self.shape.y
    end,

    draw = function(self)
        self:lgSetColor(self.color)
        local offsets
        if self.density == 1 then
            offsets = {v(0, 0)}
        elseif self.density == 2 then
            offsets = {v(-5, 0), v(5, 0)}
        elseif self.density == 3 then
            offsets = {v(0, -5), v(-5, 0), v(5, 0) }
        elseif self.density == 4 then
            offsets = {v(-2, -5), v(8, -5), v(-5, 0), v(5, 0) }
        else
            assert(false, "too many people on this tile")
        end

        for _, offset in ipairs(offsets) do
            local pos = self.pos + offset
            lg.draw(self.img, pos.x, pos.y)
        end
    end,

    update = function(self)
        if player.plan then
            local alpha = 100
            if lume.find(player.plan.people, self) ~= nil then
                alpha = 255
            end
            if self.type == player.plan.building.type then
                self.color = lume.concat(self.base_color, {alpha})
            else
                self.color = lume.concat(Map.PERSON_TYPES["hater"], {alpha})
            end
        else
            self.color = self.base_color
        end
    end,

    get_cell_type = function(self)
        return map.grid[self.local_pos.y][self.local_pos.x]
    end,

    check_state = function(self, building_type)
        if building_type ~= self.type then
            return 'sad'
        else
            return 'happy'
        end
    end,
}

class "FloorPowerup" (Object) {
    pointer_img = lg.newImage("grafix/powerup_pointer.png"),

    __init__ = function(self, coord, power_class, n)
        if n == nil then
            n = 1
        end

        self.coord = coord
        self.power_class = power_class
        self.n = n
        self.img = power_class.img
        self:super(FloorPowerup).__init__(self)
        self.center_pos = (coord - 0.5) * MAP_SCALE
        self.pos = self.center_pos:clone()
        self.bottom_corner = v(self.pos.x, self.pos.y)
        self.pos.x = self.pos.x - self.shape.x / 2
        self.pos.y = self.pos.y - self.shape.y
        self.hovered = false
        self.darker = false
    end,

    update = function(self)
        self.darker = not (player.plan == nil or lume.find(player.plan.floor_powerups, self))
    end,

    draw = function(self)
        -- draw hexigon
        if self.darker then
            self:lgSetColor(0, 0, 0)
        else
            self:lgSetColor(0, 100, 100)
        end
        lg.circle("fill", self.center_pos.x, self.center_pos.y - self.shape.y / 2, self.shape.x * 0.9, 6)

        -- draw logo
        for t = self.n-1, 0, -1 do
            if self.darker then
                self:lgSetColor(150, 150, 150)
            else
                self:lgSetColor(255, 255, 255)
            end
            if t > 0 then
                self:lgSetColor(100, 100, 100)
            end
            local pos = self.pos:clone() - v(t, t) * 4
            lg.draw(self.img, pos.x, pos.y)
        end
        if self.n > 1 then
            local num_pos = self.pos + v(self.shape.x - 3, 5)
            draw_transparent_rect(num_pos.x, num_pos.y, 15, 15, {50, 50, 50})
            self:lgSetColor(255, 255, 255)
            lg.print('x'..self.n, num_pos.x, num_pos.y)
        end
        --lg.draw(self.pointer_img, self.bottom_corner.x - 8, self.bottom_corner.y - 16)
    end,

    pickup = function(self)
        for t = 1,self.n do
            Timer.after(0.3 * (t - 1), function()
                powerup_tray:add_powerup_anim(self.power_class, self.pos)
            end)
        end
        lume.remove(map.floor_powerups, fpu)
        self:destroy()
    end
}
