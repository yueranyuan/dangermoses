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
        power:use(target)
        self.power = nil
        powerup_tray:resolve_active_button(true)
        hud:set_message("powerup used", HUD.SUCCESS)
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
        self.mousepos = pos
        if player.plan then
            player.plan:move_world_coord(pos)
        end
    end,

    click = function()
        if player.power then
            player.power = nil
            powerup_tray:resolve_active_button(false)
            hud:set_message("powerup use canceled", HUD.NEUTRAL)
        elseif player.plan then
            if government:add_law(player.plan) then
                map:place_building(player, player.plan.building)
                building_button_tray:resolve_active_button(true)
                hud:set_message("project going to government", HUD.NEUTRAL)
            else
                building_button_tray:resolve_active_button(false)
                hud:set_message("only 1 project per turn", HUD.FAIL)
            end
            player.plan = nil
        end
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
