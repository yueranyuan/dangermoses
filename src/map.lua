class "Building" (Object) {
    --PATTERNS = {"building1", "building2", "building3", "building4", "building5"},
    --PATTERNS = {"head", "plane", "tree", "scorp", "eagle"},
    PATTERNS = {park={"park_L1", "park_L2", "park_L3",
                      "park_M1", "park_M2", "park_M3", "park_M4",
                      "park_S1", "park_S2", "park_S3", "park_S4"},
                road={"road_L1", "road_L2", "road_L3", "road_L4", "road_L5",
                      "road_L6", "road_L7", "road_L8", "road_L9",
                      "road_M1", "road_M2", "road_M3", "road_M4", "road_M5",
                      "road_S1", "road_S2", "road_S3", "road_S4"},
                house={"tnmt_L1", "tnmt_L2", "tnmt_L3", "tnmt_L4",
                       "tnmt_M1", "tnmt_M2", "tnmt_M3",
                       "tnmt_S1", "tnmt_S2"}},
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
    Building.all_imgs[v] = love.graphics.newImage("grafix/"..v..".png")
end)

class "Map" (Object){
    TYPES = {moses={0, 255, 0}, park={150, 230, 100}, house={136, 136, 250}, road={250, 180, 130},
            washington={255, 252, 157},
            adams={251, 133, 219},
            jefferson={123, 255, 253},
            madison={122, 135, 111}},
    TYPE_ORDER = {'park', 'house', 'road', 'washington', 'adams', 'jefferson', 'madison'},
    --PERSON_TYPES = {hater={80, 80, 80}, moses={230, 230, 230}},
    PERSON_TYPES = {hater={255, 0, 0}, moses={0, 255, 0}},
    --DISTRICTS = {queens={255, 253, 56}, brooklyn={176, 176, 176}, manhattan={147, 39, 144}},
    DISTRICTS = {land={0, 0, 0}},

    FLICKER_FREQUENCY = 5,
    FLICKER_MOD = 3,

    __init__ = function(self, w, h)
        self:super(Map).__init__(self)

        self.bg = love.graphics.newImage("grafix/map_bg.png")
        -- load grid from map image
        local pixels = love.graphics.newImage("grafix/map_type.png"):getData()
        if h == nil then
            h = pixels:getHeight()
        else
            h = math.min(h, pixels:getHeight())
        end
        if w == nil then
            w = pixels:getWidth()
        else
            w = math.min(w, pixels:getWidth())
        end
        self.grid = {}
        for y = 0, h - 1 do
            local row = {}
            for x = 0, w - 1 do
                local r, g, b, _ = pixels:getPixel(x, y)
                row[x+1] = "empty"
                for type, color in pairs(Map.TYPES) do
                    if r == color[1] and g == color[2] and b == color[3] then
                        row[x+1] = type
                    end
                end
            end
            self.grid[y+1] = row
        end
        self.height = #self.grid
        self.width = #self.grid[1]

        -- load district map
        pixels = love.graphics.newImage("grafix/map_district.png"):getData()
        assert(pixels:getHeight() >= h)
        assert(pixels:getWidth() >= w)
        self.district_grid = {}
        for y = 0, h - 1 do
            local row = {}
            for x = 0, w - 1 do
                local r, g, b, _ = pixels:getPixel(x, y)
                row[x+1] = "water"
                for district, color in pairs(Map.DISTRICTS) do
                    if r == color[1] and g == color[2] and b == color[3] then
                        row[x+1] = district
                    end
                end
            end
            self.district_grid[y+1] = row
        end

        -- make people
        -- empty grid first
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
        local f = csv.open(arg[1].."/map.csv")
        local person_dict = {r="road", p="park", t="house", h="hater", m="moses"}
        local powerup_dict = {}
        for _, powerup_class in ipairs(PowerupTray.POWERS) do
            powerup_dict[powerup_class.name] = powerup_class
        end
        local y = 0
        for fields in f:lines() do
            y = y + 1
            for x, p in ipairs(fields) do
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
        sfx_mayor_pass:play()
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
        -- Play the sound for a building failing.
        sfx_mayor_reject:play()
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
        local fpu_idx = lume.find(map.floor_powerups, fpu)
        self:destroy()
        table.remove(map.floor_powerups, fpu_idx)
    end
}
