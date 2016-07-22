local static = {}

static.get_cell_collisions = function(building)
    -- find the overlapping coordinates.
    -- returns: list of colliding coordinates
    local collisions = {}
    for y = 1, #building.grid do
        local yg = y + lume.round(building.coord.y)
        if yg >= 1 and yg <= #map.grid then
            for x = 1, #(building.grid[1]) do
                local xg = x + lume.round(building.coord.x)
                if xg >= 1 and xg <= #(map.grid[1]) then
                    if building.grid[y][x] then
                        table.insert(collisions, v(xg, yg))
                    end
                end
            end
        end
    end
    return collisions
end

static.get_active_people = function(cells)
    -- can't use map because of in lua setting to nil is interpreted as 'delete' key
    -- and arrays are dictionaries. I wish we were using python :((((
    local arr = {}
    for _, coord in ipairs(cells) do
        local person = map.people_grid[coord.y][coord.x]
        if person then
            table.insert(arr, person)
        end
    end
    return arr
end

static.get_active_types = function(building, cells)
    local active_types = lume.map(cells, function(coord) return map.grid[coord.y][coord.x] end)
    table.insert(active_types, building.type)
    active_types = lume.set(active_types)
    lume.remove(active_types, 'empty')
    return active_types
end

static.get_popularity = function(building, people)
    return #lume.filter(lume.map(people), function(p)
        return p:check_state(building.type) == 'happy'
    end)
end

static.get_active_committees = function(active_types)
    local active_committees = {}
    for _, com in ipairs(committee_tray.committees) do
        if lume.find(active_types, com.type) then
            table.insert(active_committees, com)
        end
    end
    return active_committees
end

static.get_n_new_cells = function(cells, building)
    return #lume.filter(cells, function(c) return map.grid[c.y][c.x] ~= building.type end)
end

static.is_buildable = function(active_committees, builder, popularity)
    for _, com in ipairs(active_committees) do
        if not com:check_pass(builder, popularity) then return false end
    end
    return true
end

class "Plan" {
    static = static,

    __init__ = function(self, builder, building)
        self.builder = builder
        self.building = building
        self:refresh()
    end,

    move = function(self, coord)
        if coord.x ~= self.building.coord.x or coord.y ~= self.building.coord.y then
            self.building.coord = coord
            self:refresh()
        end
    end,

    move_world_coord = function(self, pos)
        local coord_center = pos / Map.scale - self.building:get_grid_shape() / 2
        self:move(v(lume.round(coord_center.x), lume.round(coord_center.y)))
    end,

    refresh = function(self)
        self.cells = static.get_cell_collisions(self.building)
        self.people = static.get_active_people(self.cells)
        self.types = static.get_active_types(self.building, self.cells)
        self.popularity = static.get_popularity(self.building, self.people)
        self.committees = static.get_active_committees(self.types)
        self.buildable = static.is_buildable(self.committees, self.builder, self.popularity)
        self.n_new_cells = static.get_n_new_cells(self.cells, self.building)
    end,
}
