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
        NextButton(v(government.pos.x + 50, GAME_HEIGHT - 100))
        self:super(HUD).__init__(self)
        self.z_order = 2
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
        -- draw influence count
        self:lgSetColor(255, 255, 255)
        lg.print("influence: "..player.influence, 0, GAME_HEIGHT - 100)

        -- draw messages
        if #self.message > 0 then
            lg.setColor(0, 0, 0, 200)
            lg.rectangle('fill', 0, GAME_HEIGHT / 2, GAME_WIDTH, 20)
            lg.setColor(self.message_color)
            local text_width = GAME_WIDTH - self.message_timer * 100  -- the running text effect
            lg.printf(self.message, 0, GAME_HEIGHT / 2, text_width, 'center')
        end

        -- draw mouse
        lg.setColor(255, 255, 255)
        if player.power then
            local power = player.power
            lg.setColor(255, 255, 255)
            lg.draw(power.img, controller.mousepos.x - power.shape.x / 2, controller.mousepos.y - power.shape.y / 2)
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
        self:super(NextButton).__init__(self, pos, v(100, 60))
    end,

    on_click = function(self)
        government:next()
        for _, powerup in lume.ripairs(Powerup.powerups) do
            powerup:next()
        end
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
        local shape = v((#lume.keys(Map.TYPES) + 1) * (BuildingButton.BUTTON_SIZE + 5) + 20, BuildingButton.BUTTON_SIZE)
        self:super(BuildingButtonTray).__init__(self, v(750, GAME_HEIGHT - 100), shape)

        -- add building buttons
        self.buttons = {}
        for type_i, type in ipairs(lume.keys(Map.TYPES)) do
            local offset = v((type_i - 1) * (BuildingButton.BUTTON_SIZE + 5) + 10, 0)
            local button = BuildingButton(self.pos + offset, type, self)
            table.insert(self.buttons, button)
        end

        -- add refresh button
        local offset = v(#lume.keys(Map.TYPES) * (BuildingButton.BUTTON_SIZE + 5) + 10, 0)
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
    ICON_SCALE = 3,

    __init__ = function(self, pos, type, tray)
        self.tray = tray
        self.type = type
        local type_color = Map.TYPES[type]
        self.color = {type_color[1] * 0.3, type_color[2] * 0.3, type_color[3] * 0.3}
        self.refresh_time = 0.0
        self:super(BuildingButton).__init__(self, pos, v(BuildingButton.BUTTON_SIZE, BuildingButton.BUTTON_SIZE))

        self:next()
    end,

    next = function(self)
        self.clickable = true
        self.state = 'showing'
        self.pattern = lume.randomchoice(Building.PATTERNS)
        self.building = Building(self.pattern, self.type)
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
        local icon = self.building.img
        local icon_shape = self.building.shape
        local icon_color = self.building.color
        local pos = self.pos + self.shape / 2 - BuildingButton.ICON_SCALE * icon_shape / 2  -- center icon
        if self.state == 'showing' then
            self:lgSetColor(icon_color)
            love.graphics.draw(icon, pos.x, pos.y, 0, BuildingButton.ICON_SCALE)
        else
            self:lgSetColor({255, 255, 255, 100})
            local progress = self.refresh_time / BuildingButton.REFRESH_TIME
            love.graphics.rectangle('fill', self.pos.x, self.pos.y, progress * self.shape.x, self.shape.y)
        end
    end,

    on_click = function(self)
        if player.power then return end
        player.plan = Plan(player, self.building)
        self.tray:set_active_button(self)
        return true
    end
}

class "PowerupTray" (ButtonTray) {
    POWERS = {StrongArm, Shutdown, GoodPublicity, Swap, Mislabel, Appeal, Lackey},

    __init__ = function(self)
        self.active_button = nil
        local shape = v(#self.POWERS* (PowerupButton.BUTTON_SIZE + 30) + 20, PowerupButton.BUTTON_SIZE + 20)
        self:super(PowerupTray).__init__(self, v(0, GAME_HEIGHT - shape.y), shape)

        -- add powerup buttons
        self.buttons = {}
        for _, powerup in ipairs({StrongArm, Shutdown, Swap}) do
            local offset = v((#self.buttons) * (PowerupButton.BUTTON_SIZE + 30) + 10, 10)
            local button = PowerupButton(self.pos + offset, powerup, self, 1)
            table.insert(self.buttons, button)
        end
    end,

    add_powerup = function(self, powerup)
        for _, button in ipairs(self.buttons) do
            if button.powerup == powerup then
                button.n = button.n + 1
                return
            end
        end
        local offset = v((#self.buttons) * (PowerupButton.BUTTON_SIZE + 30) + 10, 10)
        local button = PowerupButton(self.pos + offset, powerup, self, 1)
        table.insert(self.buttons, button)
    end
}

class "PowerupButton" (Button) {
    BUTTON_SIZE = 64,

    __init__ = function(self, pos, power, tray, n)
        self.tray = tray
        self.power = power
        self.img = self.power.img
        self.color = {0, 255, 255 }
        self.n = n
        self:super(PowerupButton).__init__(self, pos)
    end,

    finish = function(self)
        self.n = self.n - 1
    end,

    draw = function(self)
        -- TODO: offset doesn't work yet
        self:super(PowerupButton).draw(self)
        self:lgSetColor(255, 255, 255)
        lg.print("X"..self.n, self.pos.x + self.shape.x, self.pos.y)
    end,

    on_click = function(self)
        if player.power then return end
        if self.n > 0 then
            local powerup = self.power()
            local usable, msg = powerup.is_usable()
            if not usable then
                hud:set_message(msg, HUD.FAIL)
                return
            end
            player.power = self.power()
            self.tray:set_active_button(self)
        end
        return true
    end
}
