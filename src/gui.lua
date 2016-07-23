draw_transparent_rect = function(x, y, w, h, color)
    local old_blend_mode = lg.getBlendMode()
    lg.setBlendMode("multiply")
    lg.setColor(color)
    lg.rectangle('fill', x, y, w, h)
    lg.setBlendMode(old_blend_mode)
end

class "HUD" (Object) {
    SUCCESS = {0, 255, 0},
    FAIL = {255, 0, 0},
    NEUTRAL = {255, 255, 255},
    MOUSE_IMG = lg.newImage('grafix/mouse.png'),

    __init__ = function(self)
        self.message = ""
        self.message_color = HUD.NEUTRAL
        self.message_timer = 0.0
        NextButton(v(650, GAME_HEIGHT - 100))
        self:super(HUD).__init__(self)
    end,

    update = function(self, dt)
        if self.message_timer > 0 then
            self.message_timer = self.message_timer - dt
            if self.message_timer <= 0 then
                self.message = ""
            end
        end
    end,

    set_message = function(self, msg, msg_color)
        assert(msg ~= nil, "message is nil. Did you forget to use ':' in calling set_message?")
        self.message = msg
        self.message_timer = 2.0
        if msg_color == nil then
            msg_color = HUD.NEUTRAL
        end
        self.message_color = msg_color
    end,

    draw = function(self)
        -- draw big dudes stock
        love.graphics.setColor(255, 255, 255)
        love.graphics.print("influence: "..player.influence, GAME_WIDTH - 200, 0)

        -- draw messages
        if #self.message > 0 then
            love.graphics.setColor(0, 0, 0, 200)
            love.graphics.rectangle('fill', 0, GAME_HEIGHT / 2, GAME_WIDTH, 20)
            love.graphics.setColor(self.message_color)
            local text_width = GAME_WIDTH - self.message_timer * 100  -- the running text effect
            love.graphics.printf(self.message, 0, GAME_HEIGHT / 2, text_width, 'center')
        end

        -- draw mouse
        lg.setColor(255, 255, 255)
        if player.power then
            draw_transparent_rect(controller.mousepos.x, controller.mousepos.y, 80, 20, {50, 50, 50})
            lg.setColor(255, 255, 255)
            lg.print(player.power, controller.mousepos.x, controller.mousepos.y)
        elseif player.plan then
            draw_transparent_rect(controller.mousepos.x, controller.mousepos.y, 30, 15, {10, 10, 10})
            lg.setColor(0, 255, 0)
            lg.print(player.plan.n_supporters, controller.mousepos.x, controller.mousepos.y)
            lg.setColor(255, 0, 0)
            lg.print(player.plan.n_haters, controller.mousepos.x, controller.mousepos.y + 15)
        else
            lg.draw(self.MOUSE_IMG, controller.mousepos.x, controller.mousepos.y)
        end
    end
}

class "Button" (Object) {
    __init__ = function(self, pos, shape)
        self.clickable = true
        self:super(Button).__init__(self, pos, shape)
    end,

    check_click = function(self, mousepos)
        if self.on_click == nil then return end
        if not self.clickable then return end
        if self:collide_point(mousepos) then
            return self:on_click(mousepos)
        end
    end
}

class "NextButton" (Button) {
    __init__ = function(self, pos)
        self:super(NextButton).__init__(self, pos, v(100, 50))
    end,

    on_click = function(self)
        government:next()
    end,

    draw = function(self)
        self:super(NextButton).draw(self)
        lg.setColor({0, 0, 0})
        lg.printf("Next", self.pos.x, self.pos.y + self.shape.y / 2 - 10, self.shape.x, 'center')
    end
}

class "RefreshButton" (Button) {
    __init__ = function(self, pos, tray)
        self.tray = tray
        self:super(RefreshButton).__init__(self, pos, v(BuildingButton.BUTTON_SIZE, BuildingButton.BUTTON_SIZE))
    end,

    draw = function(self, offset)
        self:super(RefreshButton).draw(self, offset)
        lg.setColor({0, 0, 0})
        lg.printf("Refresh", self.pos.x, self.pos.y + self.shape.y / 2 - 10, self.shape.x, 'center')
    end,

    on_click = function(self)
        self.tray:refresh_all()
    end
}

class "ButtonTray" (Object) {
    resolve_active_button = function(self, success)
        if success then
            self.active_button:finish()
            self.active_button = nil
        end
        for _, button in ipairs(self.buttons) do
            button.clickable = true
        end
    end,

    set_active_button = function(self, button)
        self.active_button = button
        for _, button in ipairs(self.buttons) do
            button.clickable = false
        end
    end,

    draw = function(self)
        draw_transparent_rect(self.pos.x, self.pos.y, self.shape.x, self.shape.y, {50, 50, 50})
    end
}

class "BuildingButtonTray" (ButtonTray) {
    __init__ = function(self)
        self.active_button = nil
        local shape = v((#lume.keys(Map.TYPES) + 1) * BuildingButton.BUTTON_SIZE + 20, BuildingButton.BUTTON_SIZE + 20)
        self:super(BuildingButtonTray).__init__(self, v(190, GAME_HEIGHT - shape.y), shape)

        -- add building buttons
        self.buttons = {}
        for type_i, type in ipairs(lume.keys(Map.TYPES)) do
            local offset = v((type_i - 1) * BuildingButton.BUTTON_SIZE + 10, 10)
            local button = BuildingButton(self.pos + offset, type, self)
            table.insert(self.buttons, button)
        end

        -- add refresh button
        local offset = v(#lume.keys(Map.TYPES) * BuildingButton.BUTTON_SIZE + 10, 10)
        self.refresh_button = RefreshButton(self.pos + offset, self)
    end,

    refresh_all = function(self)
        for _, b in ipairs(self.buttons) do
            if b.state ~= 'refreshing' then b:refresh() end
        end
    end,
}


class "BuildingButton" (Button) {
    REFRESH_TIME = 10.0,
    BUTTON_SIZE = 60,
    ICON_SCALE = 10,

    __init__ = function(self, pos, type, tray)
        self.tray = tray
        self.type = type
        self.color = Map.TYPES[type]
        self.refresh_time = 0.0
        self:super(BuildingButton).__init__(self, pos, v(BuildingButton.BUTTON_SIZE, BuildingButton.BUTTON_SIZE))

        self:next()
    end,

    next = function(self)
        self.clickable = true
        self.state = 'showing'
        self.pattern = lume.randomchoice(Building.PATTERNS)
        self.icon = Building.all_imgs[self.pattern]
        self.icon_shape = v(self.icon:getWidth(), self.icon:getHeight())
    end,

    finish = function(self)
        self:refresh()
    end,

    refresh = function(self)
        self.refresh_time = BuildingButton.REFRESH_TIME
        self.state = 'refreshing'
    end,

    update = function(self, dt)
        if self.refresh_time > 0 then
            self.clickable = false
            self.refresh_time = self.refresh_time - dt
            if self.refresh_time <= 0 then
                self:next()
            end
        end
    end,

    draw = function(self)
        -- TODO: offset doesn't work yet
        self:super(BuildingButton).draw(self)
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
        if player.power then return end
        player.plan = Plan(player, Building(self.pattern, self.type))
        self.tray:set_active_button(self)
        return true
    end
}

class "PowerupTray" (ButtonTray) {
    POWERS = {"strongarm", "strongarm2"},

    __init__ = function(self)
        self.active_button = nil
        local shape = v(#self.POWERS* PowerupButton.BUTTON_SIZE + 20, PowerupButton.BUTTON_SIZE + 20)
        self:super(PowerupTray).__init__(self, v(190, 0), shape)

        -- add powerup buttons
        self.buttons = {}
        for power_i, power in ipairs(self.POWERS) do
            local offset = v((power_i - 1) * PowerupButton.BUTTON_SIZE + 10, 10)
            local button = PowerupButton(self.pos + offset, power, self)
            table.insert(self.buttons, button)
        end
    end,
}


class "PowerupButton" (Button) {
    BUTTON_SIZE = 80,

    __init__ = function(self, pos, power, tray)
        self.tray = tray
        self.power = power
        self.color = {0, 255, 255 }
        self.n = 5
        self:super(PowerupButton).__init__(self, pos, v(self.BUTTON_SIZE - 2, self.BUTTON_SIZE))
    end,

    finish = function(self)
        self.n = self.n - 1
    end,

    draw = function(self)
        -- TODO: offset doesn't work yet
        self:super(PowerupButton).draw(self)
        lg.setColor(0, 0, 0)
        lg.printf(self.power, self.pos.x, self.pos.y + self.shape.y / 2 - 5, self.shape.x, "center")
        lg.printf("#"..self.n, self.pos.x, self.pos.y + self.shape.y / 2 + 5, self.shape.x, "center")
    end,

    on_click = function(self)
        if player.power then return end
        if self.n > 0 then
            player.power = self.power
            self.tray:set_active_button(self)
        end
        return true
    end
}
