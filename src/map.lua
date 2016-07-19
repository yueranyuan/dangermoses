class "Building" (Object) {
    PATTERNS = {"eagle", "tree", "moses-lot", "scorp"},
    all_imgs = {},

    __init__ = function(self, pattern, type)
        assert(lume.find(Building.PATTERNS, pattern) ~= nil)
        self.img = Building.all_imgs[pattern]
        self.type = type
        self.state = "waiting"
        self.color = Map.TYPES[self.type]
        self.coord = v(0, 0)  -- why not named pos? because pos is for world coordinates
        self:super__init__()
    end,

    update = function(self)
        self.shown = self.state ~= "waiting"
        self.pos = self.coord * Map.scale
    end,

    build = function(self)
        self.state = "built"
        map:place_building(self)
    end,

    draw = function(self)
        --- draw nothing. The building is shown by its effects on the cells
        --- it hovers over on the Map
    end,

    is_buildable = function(self, builder)
        local cells = map:get_cell_collisions(self)
        local active_types = lume.set(lume.concat(map:get_active_types(cells), {self.type}))
        for _, com in ipairs(committees) do
            if lume.find(active_types, com.type) then
                local favorable_votes = com.seat_holders["neutral"] * builder.popularity / 100
                if favorable_votes + com.seat_holders[builder] < com.n_seats / 2 then
                    return false
                end
            end
        end
        return true
    end
}
lume.each(Building.PATTERNS, function(v)
    Building.all_imgs[v] = love.graphics.newImage("grafix/"..v..".png")
end)

class "Map" (Object){
    TYPES = {park={0, 255, 0}, house={255, 0, 0}, road={0, 0, 255}},
    scale = 10,

    __init__ = function(self)
        -- load grid from map image
        local pixels = love.graphics.newImage("grafix/map.png"):getData()
        self.grid = {}
        for y = 0, pixels:getHeight() - 1 do
            local row = {}
            for x = 0, pixels:getWidth() - 1 do
                local r, g, b, a = pixels:getPixel(x, y)
                row[x] = "empty"
                for type, color in pairs(Map.TYPES) do
                    if r == color[1] and g == color[2] and b == color[3] then
                        row[x] = type
                    end
                end
            end
            self.grid[y] = row
        end
        self.hovered_cells = {}
        self.active_types = {}
        self:super__init__()
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

    update = function(self, dt)
        if player.building ~= nil then
            self.hovered_cells = self:get_cell_collisions(player.building)
            self.active_types = lume.set(lume.concat(self:get_active_types(self.hovered_cells),
                                                          {player.building.type}))
        else
            self.hovered_cells = {}
            self.active_types = {}
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
        for _, coord in ipairs(self.hovered_cells) do
            self:draw_cell(coord, lume.concat(player.building.color, {100}))
        end
    end
}

class "BuildingButton" (Object) {
    REFRESH_TIME = 10.0,
    BUTTON_SIZE = 60,
    ICON_SCALE = 3,

    __init__ = function(self, pos, type)
        self.type = type
        self.color = Map.TYPES[type]
        self.refresh_time = 0.0
        self:super__init__(pos, v(BuildingButton.BUTTON_SIZE, BuildingButton.BUTTON_SIZE))

        self:next()
    end,

    next = function(self)
        self.state = 'showing'
        self.pattern = lume.randomchoice(Building.PATTERNS)
        self.icon = Building.all_imgs[self.pattern]
        self.icon_shape = v(self.icon:getWidth(), self.icon:getHeight())
    end,

    refresh = function(self)
        self.refresh_time = BuildingButton.REFRESH_TIME
        self.state = 'refreshing'
    end,

    update = function(self, dt)
        if self.refresh_time > 0 then
            self.refresh_time = self.refresh_time - dt
            if self.refresh_time <= 0 then
                self:next()
            end
        end
    end,

    draw = function(self)
        -- TODO: offset doesn't work yet
        self:superdraw()  -- TODO: I wish I had a super
        local pos = self.pos + self.shape / 2 - BuildingButton.ICON_SCALE * self.icon_shape / 2  -- center icon
        if self.state == 'showing' then
            love.graphics.draw(self.icon, pos.x, pos.y, 0, BuildingButton.ICON_SCALE)
        else
            love.graphics.setColor({255, 255, 255, 100})
            local progress = self.refresh_time / BuildingButton.REFRESH_TIME
            love.graphics.rectangle('fill', self.pos.x, self.pos.y, progress * self.shape.x, self.shape.y)
        end
    end,

    on_click = function(self)
        player:hold_building(Building(self.pattern, self.type))
        self:refresh()
    end
}
