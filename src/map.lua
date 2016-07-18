class "Building" (Object) {
    SHAPES = {"eagle", "tree"},
    _cached_images = {},

    __init__ = function(self, shape, type)
        if Building._cached_images[shape] == nil then
            self.img = love.graphics.newImage("grafix/"..shape..".png")
        else
            self.img = Building._cached_images[shape]
        end
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
    end
}

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
        self.active_committees = {}
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

    get_active_committees = function(self, cells)
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
        love.graphics.rectangle("fill", coord.x * Map.scale, coord.y * Map.scale, Map.scale, Map.scale)
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
        else
            self.hovered_cells = {}
        end
        self.active_committees = lume.set(lume.concat(self:get_active_committees(self.hovered_cells), {player.building.type}))
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