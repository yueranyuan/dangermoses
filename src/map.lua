class "Building" (Object) {
    PATTERNS = {"building1", "building2", "building3", "building4", "building5"},
    all_imgs = {},

    __init__ = function(self, pattern, type)
        assert(lume.find(Building.PATTERNS, pattern) ~= nil)
        self.img = Building.all_imgs[pattern]
        self.type = type
        self.state = "waiting"
        self.color = Map.TYPES[self.type]
        self.coord = v(0, 0)  -- why not named pos? because pos is for world coordinates

        self:super(Building).__init__(self)
    end,

    update = function(self)
        self.shown = self.state ~= "waiting"
        self.pos = self.coord * Map.scale
    end,

    build = function(self)
        self.state = "built"
        map:place_building(self)
    end,

    draw = function()
        --- draw nothing. The building is shown by its effects on the cells
        --- it hovers over on the Map
    end,

    is_buildable = function(self, builder)
        local cells = map:get_cell_collisions(self)
        local active_types = lume.set(lume.concat(map:get_active_types(cells), {self.type}))
        local active_people = map:get_active_people(cells)
        local popularity = map:get_popularity(active_people)
        for _, com in ipairs(committee_tray.committees) do
            if lume.find(active_types, com.type) then
                if not com:check_pass(builder, popularity) then return false end
            end
        end
        return true
    end
}
lume.each(Building.PATTERNS, function(v)
    Building.all_imgs[v] = love.graphics.newImage("grafix/"..v..".png")
end)

class "Map" (Object){
    TYPES = {park={144, 215, 68}, house={207, 119, 41}, road={75, 68, 215}},
    scale = 50,

    __init__ = function(self)
        self:super(Map).__init__(self)

        -- load grid from map image
        local pixels = love.graphics.newImage("grafix/map.png"):getData()
        self.grid = {}
        for y = 0, pixels:getHeight() - 1 do
            local row = {}
            for x = 0, pixels:getWidth() - 1 do
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

        self.hovered_cells = {}
        self.active_types = {}
        self.active_people = {}
        self.hovered_popularity = 0
    end,

    get_cell_collisions = function(self, building)
        -- find the overlapping coordinates.
        -- This function can also be used by the AI to evaluate placements
        -- returns: list of colliding coordinates
        local collisions = {}
        for y = 1, #building.grid do
            local yg = y + lume.round(building.coord.y)
            if yg >= 1 and yg <= #self.grid then
                for x = 1, #(building.grid[1]) do
                    local xg = x + lume.round(building.coord.x)
                    if xg >= 1 and xg <= #(self.grid[1]) then
                        if building.grid[y][x] then
                            table.insert(collisions, v(xg, yg))
                        end
                    end
                end
            end
        end
        return collisions
    end,

    get_active_people = function(self, cells)
        -- This function can also be used by the AI to evaluate placements

        -- can't use map because of in lua setting to nil is interpreted as 'delete' key
        -- and arrays are dictionaries. I wish we were using python :((((
        local arr = {}
        for _, coord in ipairs(cells) do
            local person = self.people_grid[coord.y][coord.x]
            if person then
                table.insert(arr, self.people_grid[coord.y][coord.x])
            end
        end
        return arr
    end,

    get_active_types = function(self, cells)
        -- This function can also be used by the AI to evaluate placements
        return lume.set(lume.map(cells, function(coord) return self.grid[coord.y][coord.x] end))
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

    place_building = function(self, building)
        local cells = self:get_cell_collisions(building)
        for _, coord in ipairs(cells) do
            if self.grid[coord.y][coord.x] ~= building.type then
                player.built_cells = player.built_cells + 1
            end
            self.grid[coord.y][coord.x] = building.type
        end
    end,

    update = function(self)
        -- update the various cached reactions of the hovering building
        for _, person in ipairs(self.people) do
            person.state = "neutral"
        end
        if player.building ~= nil then
            self.hovered_cells = self:get_cell_collisions(player.building)
            self.active_types = lume.set(lume.concat(self:get_active_types(self.hovered_cells),
                                                          {player.building.type}))
            self.active_people = self:get_active_people(self.hovered_cells)
            for _, person in ipairs(self.active_people) do
                person.state = person:check_state(player.building.type)
            end
        else
            self.hovered_cells = {}
            self.active_types = {}
            self.active_people = {}
        end

        -- popularity of the hovered move
        self.hovered_popularity = self:get_popularity(self.active_people)
    end,

    get_popularity = function(self, people)
        return #lume.filter(lume.map(people), function(p) return p.state == 'happy' end)
    end,

    draw = function(self)
        -- draw the base map
        for y = 1, #self.grid do
            for x = 1, #self.grid[1] do
                self:draw_cell(v(x, y))
            end
        end

        -- draw the hovering building
        for _, coord in ipairs(self.hovered_cells) do
            self:draw_cell(coord, lume.concat(player.building.color, {100}))
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

    get_cell_type = function(self)
        return map.grid[self.local_pos.y][self.local_pos.x]
    end,

    check_state = function(self, building_type)
        if building_type ~= self.type then
            return 'sad'
        elseif self:get_cell_type() ~= self.type then
            return 'happy'
        else
            return 'neutral'
        end
    end,

    draw = function(self, offset)
        self:super(Person).draw(self, offset)

        local state_text = ''
        if self.state == 'happy' then
            state_text = '+'
        elseif self.state == 'sad' then
            state_text = '-'
        end
        lg.setColor(255, 255, 255)
        lg.print(state_text, self.pos.x, self.pos.y)
    end
}