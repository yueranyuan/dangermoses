class "Agent" (Object) {
    __init__ = function(self, name, color)
        self.built_cells = 0
        self.influence = 0
        self.name = name
        self.color = color
        self:super(Agent).__init__(self)
    end,

    use_power = function(self, power, target)
        -- redundancy here makes it possible for agents to use powerups without the gui
        power:use(self, target)
        self.power = nil
        powerup_tray:resolve_active_button(true)
        hud:set_message("powerup used", HUD.SUCCESS, 2)
    end,

    build = function(self, type, pattern, coord)
        -- TODO: building should be possible for agents without the gui
    end,

    draw = function() end
}

class "Controller" {
    __init__ = function(self)
        self.mousepos = v(0, 0)
    end,

    move_mouse = function(self, pos)
        self.mousepos = v(math.max(0, math.min(GAME_WIDTH, pos.x)),
                          math.max(0, math.min(GAME_HEIGHT, pos.y)))
        if player.plan then
            player.plan:move_world_coord(self.mousepos)
        end
    end,

    click = function(self)
        if player.power then
            player.power = nil
            powerup_tray:resolve_active_button(false)
            hud:set_message("powerup use canceled", HUD.NEUTRAL, 2)
        elseif player.plan and self.mousepos.x < #map.grid[1] * MAP_SCALE then
            if #player.plan.people <= 2 and #player.plan.floor_powerups <= 0 then  -- must cover person or powerup
                building_button_tray:resolve_active_button(false)
                hud:set_message("building must contain at least 3 people or 1 powerup", HUD.FAIL, 3)
            elseif government:add_law(player.plan) then  -- add the legislation
                map:try_building(player, player.plan.building)
                if not progress.first_try_building then
                    Timer.after(0.5, function()
                        overlay:set("Good, you've successfully placed the " ..
                            "foundation for a new project.\nTo get your project "..
                            "built you'll need to get it through the relevant\n"..
                            "legal committees on the right.",
                            "graphix/building_placed.png")
                    end)
                    progress.first_try_building = true
                end
                building_button_tray:resolve_active_button(true)
                hud:set_message("project going to government", HUD.NEUTRAL, 2)
            else
                building_button_tray:resolve_active_button(false)
                hud:set_message("only 1 project per turn", HUD.FAIL, 2)
            end
            player.plan = nil
        end
    end,

    back = function(self)
        if player.plan == nil then
            return
        end
        building_button_tray:resolve_active_button(false)
        hud:set_message("building canceled", HUD.FAIL, 2)
        player.plan = nil
    end,
}
