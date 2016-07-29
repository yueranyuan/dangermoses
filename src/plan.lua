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
        if person and person ~= "none" then
            table.insert(arr, person)
        end
    end
    return arr
end

static.get_active_floor_powerups = function(cells)
    -- can't use map because of in lua setting to nil is interpreted as 'delete' key
    -- and arrays are dictionaries. I wish we were using python :((((
    local arr = {}
    for _, coord in ipairs(cells) do
        for _, pu in ipairs(map.floor_powerups) do
            if pu.coord == coord then
                table.insert(arr, pu)
            end
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

static.get_active_districts = function(cells)
    local active_districts = lume.set(lume.map(cells, function(coord) return map.district_grid[coord.y][coord.x] end))
    return active_districts
end

static.get_n_supporters = function(building, people)
    return utils.sum(lume.map(people, function(p)
        if p:check_state(building.type) == 'happy' then
            return p.density
        end
        return 0
    end))
end

static.get_n_haters = function(building, people)
    return utils.sum(lume.map(people, function(p)
        if p:check_state(building.type) == 'sad' then
            return p.density
        end
        return 0
    end))
end

static.get_active_committees = function(active_types, active_districts)
    local active_committees = {}
    for _, com in ipairs(government.committees) do
        if lume.find(active_types, com.type) then
            table.insert(active_committees, com)
        end
        if lume.find(active_districts, com.district) then
            table.insert(active_committees, com)
        end
    end
    return active_committees
end

static.get_n_new_cells = function(cells, building)
    return #lume.filter(cells, function(c) return map.grid[c.y][c.x] ~= building.type end)
end

static.get_is_buildable = function(cells, people)
    -- see if any new tiles are added
    local has_real_tiles = false
    for _, coord in ipairs(cells) do
        if map.district_grid[coord.y][coord.x] ~= "water" then
            has_real_tiles = true
            break
        end
    end

    return has_real_tiles and #people > 0
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
        local coord = pos / MAP_SCALE
        coord = v(math.max(0, math.min(#map.grid[1], coord.x)),
                  math.max(0, math.min(#map.grid, coord.y)))
        local coord_corner = coord - self.building:get_grid_shape() / 2
        self:move(v(lume.round(coord_corner.x), lume.round(coord_corner.y)))
    end,

    refresh = function(self)
        self.cells = static.get_cell_collisions(self.building)
        self.people = static.get_active_people(self.cells)
        self.floor_powerups = static.get_active_floor_powerups(self.cells)
        self.types = static.get_active_types(self.building, self.cells)
        self.districts = static.get_active_districts(self.cells)
        self.n_supporters = static.get_n_supporters(self.building, self.people)
        self.n_haters = static.get_n_haters(self.building, self.people)
        self.committees = static.get_active_committees(self.types, self.districts)
        self.n_new_cells = static.get_n_new_cells(self.cells, self.building)
        self.is_buildable, self.unbuildable_reason = static.get_is_buildable(self.cells, self.people)
    end,
}
