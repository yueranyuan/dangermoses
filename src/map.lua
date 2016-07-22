class "Building" (Object) {
    PATTERNS = {"building1", "building2", "building3", "building4", "building5"},
    all_imgs = {},

    __init__ = function(self, pattern, type)
        assert(lume.find(Building.PATTERNS, pattern) ~= nil)
        self.img = Building.all_imgs[pattern]
        self.type = type
        self.color = Map.TYPES[self.type]
        self.coord = v(0, 0)  -- why not named pos? because pos is for world coordinates
        self:super(Building).__init__(self)
    end,

    draw = function() end,
}

lume.each(Building.PATTERNS, function(v)
    Building.all_imgs[v] = love.graphics.newImage("grafix/"..v..".png")
end)

class "Map" (Object){
    TYPES = {park={144, 215, 68}, house={207, 119, 41}, road={75, 68, 215}},
    scale = 64,

    __init__ = function(self, w, h)
        self:super(Map).__init__(self)

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

        -- make people
        self.people_grid = {}
        self.people = {}
        for y = 1, #self.grid do
            local row = {}
            for x = 1, #self.grid[1] do
                if math.random() < 1.0 then
                    local person = Person(v(x, y), lume.randomchoice(lume.keys(Map.TYPES)))
                    row[x] = person
                    table.insert(self.people, person)
                end
            end
            self.people_grid[y] = row
        end
    end,

    draw_cell = function(self, coord, color)
        if color == nil then
            color = Map.TYPES[self.grid[coord.y][coord.x]]
        end
        if color == nil then
            color = {0, 0, 0}
        end
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", (coord.x-1) * Map.scale, (coord.y-1) * Map.scale, Map.scale, Map.scale)
    end,

    place_building = function(self, builder, building)
        local cells = Plan.static.get_cell_collisions(building)
        for _, coord in ipairs(cells) do
            if self.grid[coord.y][coord.x] ~= building.type then
                builder.built_cells = builder.built_cells + 1
            end
            self.grid[coord.y][coord.x] = building.type
        end
    end,

    update = function(self)
        -- update the various cached reactions of the hovering building
        for _, person in ipairs(self.people) do
            person.state = "neutral"
        end
        if player.plan then
            for _, person in ipairs(player.plan.people) do
                person.state = person:check_state(player.plan.building.type)
            end
        end
    end,

    draw = function(self)
        -- draw the base map
        for y = 1, #self.grid do
            for x = 1, #self.grid[1] do
                self:draw_cell(v(x, y))
            end
        end

        -- draw the hovering building
        if player.plan then
            for _, coord in ipairs(player.plan.cells) do
                self:draw_cell(coord, lume.concat(player.plan.building.color, {100}))
            end
        end
    end
}

class "Person" (Object) {
    PERSON_IMG = lg.newImage("grafix/person.png"),

    __init__ = function(self, local_pos, type)
        self.local_pos = local_pos
        self.type = type
        self.state = 'neutral'
        self.color = Map.TYPES[self.type]
        self.img = Person.PERSON_IMG
        self:super(Person).__init__(self)
        self.pos = (local_pos - 0.5) * Map.scale - self.shape / 2
    end,

    update = function(self)
        if player.plan and self.type ~= player.plan.building.type then
            self.color = {self.color[1], self.color[2], self.color[3], 50}
        else
            self.color = {self.color[1], self.color[2], self.color[3]}
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