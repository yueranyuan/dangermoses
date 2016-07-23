class "AI" (Object) {
    MAX_STEPS_PER_THINK = 4,
    POOL_REFRESH_RATE = AI_SPEED,

    __init__ = function(self, agent)
        self.agent = agent
        self.step_thresh = 0
        self.score_accum = 0
        self.building_pool = {}
        self.pool_refresh_countdown = lume.random(1, 4)
        self:super(AI).__init__(self)
    end,

    update = function(self, dt)
        if self.pool_refresh_countdown < 0.0 then
            self.pool_refresh_countdown = AI.POOL_REFRESH_RATE + lume.random(-2, 2)
            self:make_new_building()
        else
            self.pool_refresh_countdown = self.pool_refresh_countdown - dt
        end

        if self.agent.big_dudes > 0 then
            self:use_big_dude()
        end
    end,

    use_big_dude = function(self)
        local best_score = 0
        local best_committee = nil
        local best_holder = nil
        for _, com in ipairs(committee_tray.committees) do
            for _, holder in ipairs(com:can_replace(self.agent)) do
                com.seat_holders[holder] = com.seat_holders[holder] - 1
                com.seat_holders[self.agent] = com.seat_holders[self.agent] + 1
                local score = self:evaluate(self.agent)
                if score > best_score then
                    best_committee = com
                    best_holder = holder
                    best_score = score
                end
                com.seat_holders[holder] = com.seat_holders[holder] + 1
                com.seat_holders[self.agent] = com.seat_holders[self.agent] - 1
            end
        end
        if best_committee ~= nil then
            best_committee:update_seat(best_holder, self.agent)
        end
    end,

    make_new_building = function(self)
        local building_pool = lume.map(lume.shuffle(lume.keys(Map.TYPES)), function(type)
            return Building(lume.randomchoice(Building.PATTERNS), type)
        end)
        local building, coord = self:find_best(building_pool)
        if building ~= nil then
            building.coord = coord
            map:place_building(self.agent, building)
        end
    end,

    evaluate = function(self, agent)
        local scores = 0
        for _, type in ipairs(lume.keys(Map.TYPES)) do
            for y = 1, #map.grid do
                for x = 1, #map.grid[1] do
                    local pattern = lume.randomchoice(Building.PATTERNS)
                    local plan = Plan(agent, Building(pattern, type))
                    local mouse_coord = v(x, y)
                    plan:move_world_coord(mouse_coord * MAP_SCALE)  -- move like a mouse
                    if plan.buildable then
                        scores = scores + plan.n_new_cells
                    end
                end
            end
        end
        return scores
    end,

    find_best = function(self, building_pool)
        local best_coord = nil
        local best_building = nil
        local n_cells = 0
        for _, building in ipairs(building_pool) do
            local plan = Plan(self.agent, building)
            for y = 1, #map.grid do
                for x = 1, #map.grid[1] do
                    local mouse_coord = v(x, y)
                    plan:move_world_coord(mouse_coord * MAP_SCALE)  -- move like a mouse
                    if plan.buildable then
                        if plan.n_new_cells > n_cells then
                            best_building = building
                            best_coord = plan.building.coord
                            n_cells = plan.n_new_cells
                        end
                    end
                end
            end
        end
        return best_building, best_coord
    end,
}

class "Agent" (Object) {
    __init__ = function(self, name, color)
        self.big_dudes = 0
        self.built_cells = 0
        self.name = name
        self.color = color
        self:super(Agent).__init__(self)
    end,

    make_ai = function(self)
        self.ai = AI(self)
    end,

    build = function(self, pattern, type)
        
    end,

    update = function(self)
        -- get the appropriate number of big dudes
        while self.built_cells >= CELL_PER_BIG_DUDE do
            self.built_cells = self.built_cells - CELL_PER_BIG_DUDE
            self.big_dudes = self.big_dudes + 1
        end
    end,

    draw = function() end
}

class "Controller" {
    __init__ = function(self)
        self.mousepos = v(0, 0)
    end,

    move_mouse = function(self, pos)
        self.mousepos = pos
        if player.plan then
            player.plan:move_world_coord(pos)
        end
    end,

    click = function()
        if player.plan == nil then
            return
        end
        local buildable = player.plan.buildable
        if buildable then
            map:place_building(player, player.plan.building)
            hud:set_message("success in placing building", HUD.SUCCESS)
        else
            hud:set_message("failed to build this building", HUD.FAIL)
        end
        building_button_tray:resolve_active_button(buildable)
        player.plan = nil
    end,

    back = function()
        if player.plan == nil then
            return
        end
        building_button_tray:resolve_active_button(false)
        hud:set_message("building canceled", HUD.FAIL)
        player.plan = nil
    end,
}
