class "Building" (Object) {
    --PATTERNS = {"building1", "building2", "building3", "building4", "building5"},
    --PATTERNS = {"head", "plane", "tree", "scorp", "eagle"},
    PATTERNS = {"rand1", "rand2", "rand3", "rand4", "rand5", "eagle"},
    all_imgs = {},

    __init__ = function(self, pattern, type)
        assert(lume.find(Building.PATTERNS, pattern) ~= nil)
        self.img = Building.all_imgs[pattern]
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

lume.each(Building.PATTERNS, function(v)
    Building.all_imgs[v] = love.graphics.newImage("grafix/"..v..".png")
end)

class "Map" (Object){
    TYPES = {park={144, 215, 68}, house={207, 119, 41}, road={75, 68, 215}},
    PERSON_TYPES = {hater={164, 40, 40}, park={144, 215, 68}, house={207, 119, 41}, road={75, 68, 215}},
    DISTRICTS = {queens={207, 179, 7}, brooklyn={151, 151, 151}, manhattan={191, 123, 199}},

    FLICKER_FREQUENCY = 5,
    FLICKER_MOD = 3,

    __init__ = function(self, w, h)
        self:super(Map).__init__(self)

        self.bg = love.graphics.newImage("grafix/map_bg.png")
        -- load grid from map image
        local pixels = love.graphics.newImage("grafix/map_blank.png"):getData()
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
        local person_dict = {r="road", p="park", t="house", h="hater" }
        local powerup_dict = {}
        for _, powerup_class in ipairs(PowerupTray.POWERS) do
            powerup_dict[powerup_class.name] = powerup_class
        end
        local y = 0
        for fields in f:lines() do
            y = y + 1
            for x, p in ipairs(fields) do
                if powerup_dict[p] then
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
        self.flicker_time = 0
        self.flicker_idx = 0
    end,

    draw_cell = function(self, coord, color, border)
        if border == nil then
            border = 0
        end
        if color == nil then
            color = Map.TYPES[self.grid[coord.y][coord.x]]
        end
        if color ~= nil then
            self:lgSetColor(color)
            lg.rectangle("fill", (coord.x-1) * MAP_SCALE - border, (coord.y-1) * MAP_SCALE - border,
                         MAP_SCALE + 2 * border, MAP_SCALE + 2 * border)
        end
    end,

    try_building = function(self, builder, building)
        table.insert(self.pending_plans, Plan(builder, building))
    end,

    place_building = function(self, builder, building)
        local cells = Plan.static.get_cell_collisions(building)
        for _, coord in ipairs(cells) do
            if self.grid[coord.y][coord.x] ~= building.type then
                builder.built_cells = builder.built_cells + 1
            end
            self.grid[coord.y][coord.x] = building.type
        end
        self:remove_pending_building(building)

        log.trace(#self.floor_powerups)
        local active_floor_powerups = Plan.static.get_active_floor_powerups(cells)
        for _, fpu in ipairs(active_floor_powerups) do
            powerup_tray:add_powerup(fpu.power_class)
            local fpu_idx = lume.find(self.floor_powerups, fpu)
            fpu:destroy()
            table.remove(self.floor_powerups, fpu_idx)
        end
        log.trace(#self.floor_powerups)
    end,

    remove_pending_building = function(self, building)
        -- remove pending plan
        for plan_i, plan in lume.ripairs(self.pending_plans) do
            if plan.building == building then
                table.remove(self.pending_plans, plan_i)
            end
        end
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
        lg.draw(self.bg, 0, 0, 0, MAP_SCALE / 2)

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
                    self:draw_cell(coord, lume.concat(player.plan.building.color, {200}))
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

    __init__ = function(self, coord, power_class)
        self.coord = coord
        self.power_class = power_class
        self.img = power_class.img
        self:super(FloorPowerup).__init__(self)
        self.pos = (coord - 0.5) * MAP_SCALE
        self.bottom_corner = v(self.pos.x, self.pos.y)
        self.pos.x = self.pos.x - self.shape.x / 2
        self.pos.y = self.pos.y - self.shape.y - 16 + 2
        self.hovered = false
    end,

    update = function(self)
        if player.plan == nil or lume.find(player.plan.floor_powerups, self) then
            self.color = {255, 255, 255}
        else
            self.color = {100, 100, 100, 100}
        end
    end,

    draw = function(self)
        self:super(FloorPowerup).draw(self)
        lg.draw(self.pointer_img, self.bottom_corner.x - 8, self.bottom_corner.y - 16)
    end
}