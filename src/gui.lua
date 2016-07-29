draw_transparent_rect = function(x, y, w, h, color)
    if color == nil then
        color = {50, 50, 50}
    end
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
        elseif player.plan then
            lg.setColor(255, 255, 255)
            local percentage = (player.plan.n_supporters / (player.plan.n_haters + player.plan.n_supporters) * 100)
            if player.plan.n_haters + player.plan.n_supporters == 0 then
                percentage = 0
            end
            lg.print(lume.round(percentage).."%", controller.mousepos.x + 20, controller.mousepos.y)
        else
            lg.draw(self.MOUSE_IMG, controller.mousepos.x, controller.mousepos.y)
        end
    end
}

class "Button" (Object) {
    __init__ = function(self, pos, shape, callback)
        self.clickable = true
        self.callback = callback
        self:super(Button).__init__(self, pos, shape)
    end,

    on_click = function(self, mousepos)
        if self.callback ~= nil then
            return self.callback(mousepos)
        end
        return false
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
        sound = love.audio.newSource("sfx/next_button_typewriter.wav", "static")
        sound:play()
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
        self.hidden = false
        self.active_button = nil
        local shape = v((#Map.TYPE_ORDER) * (BuildingButton.BUTTON_SIZE + 5), BuildingButton.BUTTON_SIZE)
        self:super(BuildingButtonTray).__init__(self, v(government.pos.x - shape.x, 0), shape)

        -- add building buttons
        self.buttons = {}
        for i, type in ipairs(Map.TYPE_ORDER) do
            local offset = v((i- 1) * (BuildingButton.BUTTON_SIZE + 5), 0)
            local button = BuildingButton(self.pos + offset, type, type, self)
            table.insert(self.buttons, button)
        end
    end,

    set_hidden = function(self, val)
        self.hidden = val
        lume.each(self.buttons, function(b) b.hidden = val end)
        lume.each(self.buttons, function(b) b.clickable = not val end)
    end,

    refresh_all = function(self)
        for _, b in ipairs(self.buttons) do
            if b.state ~= 'refreshing' then b:refresh() end
        end
    end,

    draw = function(self, offset)
        if self.hidden then return end
        self:super(self.__class__).draw(self, offset)
    end
}


class "BuildingButton" (Button) {
    REFRESH_TIME = 0.3,
    BUTTON_SIZE = 60,
    ICON_SCALE = 6,

    __init__ = function(self, pos, type, shape_family, tray)
        self.tray = tray
        self.type = type
        self.shape_family = shape_family
        local type_color = Map.TYPES[type]
        self.color = {type_color[1] * 0.3, type_color[2] * 0.3, type_color[3] * 0.3 }
        self.refresh_time = 0.0
        self.hidden = false
        self:super(BuildingButton).__init__(self, pos, v(BuildingButton.BUTTON_SIZE, BuildingButton.BUTTON_SIZE))

        self:next()
    end,

    next = function(self)
        self.clickable = true
        self.state = 'showing'
        self.pattern = lume.randomchoice(Building.PATTERNS[self.shape_family])
        self.building = Building(self.pattern, self.type)
    end,

    finish = function(self)
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
        if self.hidden then return end
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

class "BuyButton" (Button) {
    __init__ = function(self, pos, callback)
        self.color = {0, 100, 0 }
        self:super(BuyButton).__init__(self, pos, v(GAME_WIDTH - pos.x, 40), callback)
    end,

    draw = function(self)
        local text = "Buy"
        if not self.clickable then text = "Back" end
        self:super(BuyButton).draw(self)
        lg.setColor({255, 255, 255})
        lg.printf(text, self.pos.x, self.pos.y + self.shape.y / 2 - 10, self.shape.x, 'center')
    end
}

class "PowerupTray" (ButtonTray) {
    POWERS = {StrongArm, Shutdown, GoodPublicity, Swap, Mislabel, Appeal, Lackey, Resilience},

    __init__ = function(self, starting_powerups)
        self.active_button = nil
        self.buy_mode = false

        local shape = v(POWERUP_TRAY_WIDTH, #self.POWERS* (PowerupButton.BUTTON_SIZE) + 20)
        self:super(PowerupTray).__init__(self, v(GAME_WIDTH - POWERUP_TRAY_WIDTH, 40), shape)

        self.buy_button = BuyButton(v(self.pos.x, 0), function()
            self.buy_mode = true
            self.buy_button.clickable = false
            return true
        end)

        -- add powerup buttons
        self.buttons = {}
        for powerup, n in pairs(starting_powerups) do
            local offset = v(2, (#self.buttons) * (PowerupButton.BUTTON_SIZE) + 10)
            local button = PowerupButton(self.pos + offset, powerup, self, n)
            table.insert(self.buttons, button)
        end
    end,

    buy_mode_off = function(self)
        self.buy_mode = false
        self.buy_button.clickable = true
    end,

    get_powerup_button = function(self, powerup)
        for _, button in ipairs(self.buttons) do
            if button.power == powerup then
                return button
            end
        end
        local offset = v(2, (#self.buttons) * (PowerupButton.BUTTON_SIZE) + 10)
        local button = PowerupButton(self.pos + offset, powerup, self, 0)
        table.insert(self.buttons, button)
        return button
    end,

    add_powerup_anim = function(self, powerup, pos)
        local button = self:get_powerup_button(powerup)
        local obj = Image(pos:clone(), powerup.img)
        Timer.tween(0.5, obj.pos, {x=button.pos.x, y=button.pos.y}, "in-out-quad", function()
            button.n = button.n + 1
            obj:destroy()
        end)
    end,

    add_powerup = function(self, powerup)
        local button = self:get_powerup_button(powerup)
        button.n = button.n + 1
    end
}

class "PowerupButton" (Button) {
    BUTTON_SIZE = 50,

    __init__ = function(self, pos, power, tray, n)
        self.tray = tray
        self.power = power
        self.icon = self.power.img
        self.color = {255, 255, 255 }
        self.cost = self.power.cost
        self.n = n
        self:super(PowerupButton).__init__(self, pos, v(PowerupButton.BUTTON_SIZE, PowerupButton.BUTTON_SIZE))
    end,

    finish = function(self)
        self.n = self.n - 1
    end,

    draw = function(self)
        -- TODO: offset doesn't work yet
        if powerup_tray.buy_mode then
            self:lgSetColor(150, 150, 150)
        else
            self:lgSetColor(255, 255, 255)
        end
        lg.draw(self.icon, self.pos.x, self.pos.y, 0, 1.5)
        lg.print("X"..self.n, GAME_WIDTH - 30, self.pos.y + 10)
        if powerup_tray.buy_mode then
            self:lgSetColor(0, 255, 0)
            lg.print(self.cost, self.pos.x + 10, self.pos.y + 10)
        end
    end,

    try_use = function(self)
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
    end,

    buy = function(self)
        if government.moses_office:spend(self.cost) then
            powerup_tray:add_powerup(self.power)
        end
        return true
    end,

    on_click = function(self)
        if powerup_tray.buy_mode then
            return self:buy()
        else
            return self:try_use()
        end
    end
}
