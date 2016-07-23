class "Agent" (Object) {
    __init__ = function(self, name, color)
        self.built_cells = 0
        self.influence = 0
        self.name = name
        self.color = color
        self:super(Agent).__init__(self)
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
        if government:add_law(player.plan) then
            map:place_building(player, player.plan.building)
            building_button_tray:resolve_active_button(true)
            hud:set_message("project going to government", HUD.NEUTRAL)
        else
            building_button_tray:resolve_active_button(false)
            hud:set_message("only 1 project per turn", HUD.FAIL)
        end
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
