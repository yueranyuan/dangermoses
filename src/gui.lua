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
    SUCCESS = {100, 255, 100},
    FAIL = {255, 100, 100},
    NEUTRAL = {255, 255, 255},
    MOUSE_IMG = lg.newImage('grafix/mouse.png'),

    __init__ = function(self)
        self.message = ""
        self.message_color = HUD.NEUTRAL
        self.message_timer = 0.0
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

    set_message = function(self, msg, msg_color, time)
        assert(msg ~= nil, "message is nil. Did you forget to use ':' in calling set_message?")
        self.message = msg
        if msg_color == nil then
            msg_color = HUD.NEUTRAL
        end
        if time == nil then
            time = 0.1
        end
        self.message_timer = time
        self.message_color = msg_color
    end,

    draw = function(self)
        -- draw messages
        if #self.message > 0 then
            lg.setColor(50, 50, 100, 250)
            lg.rectangle('fill', 0, 0, government.pos.x, 50)
            lg.setColor(self.message_color)
            lg.printf(self.message, 0, 10, government.pos.x, 'center')
        end

        -- draw mouse
        lg.setColor(255, 255, 255)
        self.show_mouse = false
        if player.power then
            -- draw powerup icon
            local power = player.power
            lg.setColor(255, 255, 255)
            lg.draw(power.img, controller.mousepos.x - power.shape.x / 2, controller.mousepos.y - power.shape.y / 2)
        elseif player.plan then
            -- draw hover read-out
            local readout_shape = v(80, 15)
            local pos = controller.mousepos - readout_shape / 2
            draw_transparent_rect(pos.x, pos.y, readout_shape.x, readout_shape.y, {100, 100, 100})
            lg.setColor(255, 0, 0)
            lg.print(player.plan.n_haters, pos.x, pos.y)
            local r = readout_shape.y / 2 - 2
            for com_i, com in ipairs(player.plan.committees) do
                local pos = pos + v(20 + com_i * (r * 2 + 2), readout_shape.y / 2)
                lg.setColor(com.color)
                lg.circle('fill', pos.x, pos.y, r)
            end
            --lg.setColor(255, 255, 255)
            --local percentage = (player.plan.n_supporters / (player.plan.n_haters + player.plan.n_supporters) * 100)
            --if player.plan.n_haters + player.plan.n_supporters == 0 then
            --    percentage = 0
            --end
            --lg.print(lume.round(percentage).."%", controller.mousepos.x + 20, controller.mousepos.y)
        else
            self.show_mouse = true
        end
    end,

    draw_mouse = function(self, force)
        if self.show_mouse or force then
            lg.setColor(255, 255, 255)
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
        if not self.active_button then
            log.error("tried to resolve active button but there is none")
            return
        end
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
        local w = 3
        local h = 2
        local shape  = v(w * (BuildingButton.BUTTON_SIZE + 5), h * (BuildingButton.BUTTON_SIZE + 5))
        self:super(BuildingButtonTray).__init__(self, v(0, 0), shape)

        -- add building buttons
        self.buttons = {}
        self.clickable = true
    end,

    add_button = function(self, pos, type)
        local button = BuildingButton(pos, type, self)
        table.insert(self.buttons, button)
        return button
    end,

    refresh_all = function(self)
        for _, b in ipairs(self.buttons) do
            if b.state ~= 'refreshing' then b:refresh() end
        end
    end,

    draw = function(self, offset)
    end,

    update = function(self)
        if self.active_button == nil then
            for _, b in ipairs(self.buttons) do
                b.clickable = self.clickable
            end
        end
    end
}


class "BuildingButton" (Button) {
    BUTTON_SIZE = 60,
    ICON_SCALE = 6,

    __init__ = function(self, pos, type, tray)
        self.tray = tray
        self.type = type
        local type_color = Map.TYPES[type]
        if type == 'random' then
            type_color = {255, 255, 255}
        end
        self.base_color = {type_color[1] * 0.3, type_color[2] * 0.3, type_color[3] * 0.3 }
        self.color = lume.map(self.base_color)
        self:super(BuildingButton).__init__(self, pos, v(BuildingButton.BUTTON_SIZE, BuildingButton.BUTTON_SIZE))

        self:next()
    end,

    next = function(self)
        self.clickable = true
        local type = self.type
        if type == "random" then
            type = lume.randomchoice(lume.keys(Map.TYPES))
        end
        self.pattern = lume.randomchoice(Building.PATTERNS[type])
        self.building = Building(self.pattern, type)
        self.icon = self.building.img
        self.icon_shape = self.building.shape
        self.icon_color = self.building.color
    end,

    finish = function(self)
    end,

    refresh = function(self)
        self.color = {255, 255, 255}
        self.icon_color = self.color
        self.clickable = false
        Timer.after(0.1, function()
            Timer.tween(0.2,  self.color, self.base_color, 'in-out-quad', function()
                self:next()
            end)
        end)
    end,

    draw = function(self)
        -- TODO: offset doesn't work yet
        self:super(BuildingButton).draw(self)
        local pos = self.pos + self.shape / 2 - BuildingButton.ICON_SCALE * self.icon_shape / 2  -- center icon
        self:lgSetColor(self.icon_color)
        love.graphics.draw(self.icon, pos.x, pos.y, 0, BuildingButton.ICON_SCALE)
        if not self.clickable then
            draw_transparent_rect(self.pos.x, self.pos.y, self.shape.x, self.shape.y, {100, 100, 100})
        end
    end,

    on_click = function(self)
        if player.power then return end
        if not progress.first_building then
            overlay:set("You are building your first building!\n"..
                "Try to place it somewhere with many 'supporters' (people on the map"..
                "who are the same color as the building) and few 'detractors'"..
                "(people shown as gray or a different color on the map).")
            progress.first_building = true
        end
        player.plan = Plan(player, self.building)
        self.tray:set_active_button(self)
        return true
    end
}

class "PowerupTray" (ButtonTray) {
    POWERS = {GoodPublicity, StrongArm, Shutdown, Appeal, Lackey, Mislabel, Swap},

    __init__ = function(self, starting_powerups)
        self.active_button = nil
        self.buy_mode = false

        local w, h = 4, 2

        local shape = v(w * PowerupButton.BUTTON_SIZE, h * PowerupButton.BUTTON_SIZE + 45)
        self:super(PowerupTray).__init__(self, v(GAME_WIDTH - shape.x, 0), shape)

        self.buy_mode = false
        self.buy_button = BuyButton(self.pos, v(self.shape.x, 40), function()
            if not progress.buy_button_used then
                overlay:set("You can use the 'Buy' button to buy legal"..
                    "'machinations', under-the-table tricks you can use to"..
                    "influence the legal process in your favor."..
                    "These machinations are bought with your collected supporters.")
                progress.buy_button_used = true
            end
            self.buy_mode = not self.buy_mode
            return true
        end)

        -- add powerup buttons
        self.buttons = {}
        local power_i = 0
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                power_i = power_i + 1
                if power_i <= #self.POWERS then
                    local powerup = self.POWERS[power_i]
                    local offset = v(x, y) * PowerupButton.BUTTON_SIZE + v(0, self.buy_button.shape.y + 5)
                    local n = 0
                    local n = starting_powerups[powerup] or 0
                    local button = PowerupButton(self.pos + offset, powerup, self, n)
                    table.insert(self.buttons, button)
                end
            end
        end
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
    BUTTON_SIZE = 60,

    __init__ = function(self, pos, power, tray, n)
        self.tray = tray
        self.power = power
        self.icon = self.power.img
        self.color = {255, 255, 255 }
        self.cost = self.power.cost
        self.buyable = type(self.cost) == "number"
        self.n = n
        self:super(PowerupButton).__init__(self, pos, v(PowerupButton.BUTTON_SIZE, PowerupButton.BUTTON_SIZE))
        if self.buyable then
            self.crowd = Crowd(self.pos + v(0, 30), 0, {0, 255, 0})
            self.crowd.show_n = false
        end
        self.flashing = false
    end,

    finish = function(self)
        if self.cost ~= "free" then
            self.n = self.n - 1
        end
    end,

    flash = function(self)
        self.color = {0, 0, 0 }
        Timer.tween(0.3, self.color, {255, 255, 255}, 'linear', function()
            self.color = {255, 255, 255}
        end)
    end,

    update = function(self)
        self.buyable = type(self.cost) == "number"
        if self.buyable then
            self.affordable = government.moses_office:can_spend(self.cost)
        end
        if self.buyable then
            if powerup_tray.buy_mode then
                self.crowd.n = self.cost
            else
                self.crowd.n = 0
            end
        end
    end,

    draw = function(self)
        local color = self.color
        self:lgSetColor(color[1], color[2], color[3])
        local available = (self.n > 0 or self.cost == "free")
        if ((powerup_tray.buy_mode and (not self.buyable or not self.affordable)) or
            (not powerup_tray.buy_mode and not available)) then
            self:lgSetColor(color[1], color[2], color[3], 100)
        end
        lg.draw(self.icon, self.pos.x, self.pos.y, 0, 2)

        -- draw amount
        local n_pos = self.pos + v(30, 30)
        if self.cost == "free"  then
            draw_transparent_rect(n_pos.x - 22, n_pos.y, 40, 15, {50, 50, 50})
            self:lgSetColor(255, 255, 255)
            lg.print("free", n_pos.x - 20, n_pos.y)
        else
            draw_transparent_rect(n_pos.x, n_pos.y, 30, 15, {50, 50, 50})
            self:lgSetColor(255, 255, 255)
            lg.print(self.n, n_pos.x, n_pos.y)
        end
    end,

    try_use = function(self)
        if player.power then return end
        if self.n > 0 or self.cost == "free" then
            local powerup = self.power()
            local usable, msg = powerup.is_usable()
            if not usable then
                hud:set_message(msg, HUD.FAIL, 2)
                return
            end
            player.power = self.power()
            self.tray:set_active_button(self)
        end
        return true
    end,

    buy = function(self)
        if not self.buyable then return false end
        if government.moses_office:spend(self.cost) then
            self:flash()
            powerup_tray:add_powerup(self.power)
        end
        return true
    end,

    on_click = function(self)
        if powerup_tray.buy_mode then
            return self:buy()
        else
            if not progress.first_powerup then
                overlay:set("You can use these legal machinations to influence "..
                    "the legal process and get projects through the system. " ..
                    "Click on a project to apply the machination to it.",
                    self.icon)
                progress.first_powerup = true
            end
            return self:try_use()
        end
    end,

    on_hover = function(self)
        hud:set_message(self.power.hover_text)
        return true
    end
}

class "BuyButton" (Button) {
    __init__ = function(self, pos, shape, callback)
        self.color = {0, 100, 0 }
        self.cost = cost
        self.text = "Buy"
        self:super(BuyButton).__init__(self, pos, shape, callback)
    end,

    update = function(self)
        if powerup_tray.buy_mode then
            self.text = "Back"
            self.color = {100, 0, 0 }
        else
            self.text = "Buy"
            self.color = {0, 100, 0 }
        end
    end,

    draw = function(self)
        self:super(BuyButton).draw(self)
        lg.setColor({255, 255, 255})
        lg.printf(self.text, self.pos.x, self.pos.y + self.shape.y / 2 - 10, self.shape.x, 'center')
    end
}

class "Overlay" (Object) {
    RESIGN_IMG = lg.newImage("grafix/resign_mayor.png"),
    NEW_MAYOR_IMG = lg.newImage("grafix/new_mayor.png"),
    ANGRY_IMG = lg.newImage("grafix/angry_mayor.png"),
    SHRUG_IMG = lg.newImage("grafix/shrug.png"),

    __init__ = function(self, shape)
        self.z_order = 2
        self.on = false
        local pos = v(GAME_WIDTH, GAME_HEIGHT) / 2 - shape / 2
        self:super(Overlay).__init__(self, pos, shape)

        local button_shape = v(100, 30)
        self.okay_button = OkayButton(self.pos + self.shape - button_shape, button_shape, function()
            self.on = false
        end)
        self.okay_button.z_order = self.z_order
    end,

    set = function(self, words, img)
        self.on = true
        self.words = words
        self.img = img
        if img ~= nil then
            local data = img:getData()
            local img_shape = v(data:getWidth(), data:getHeight())
            self.img_pos = v(self.pos.x + self.shape.x / 2 - img_shape.x / 2,
                             self.pos.y + (self.shape.y - 100) / 2 - img_shape.y / 2)
        end
    end,

    update = function(self)
        self.okay_button.show = self.on
    end,

    draw = function(self)
        if not self.on then return end
        draw_transparent_rect(0, 0, GAME_WIDTH, GAME_HEIGHT, {80, 80, 80})
        lg.setColor(255, 255, 255)
        lg.rectangle("fill", self.pos.x, self.pos.y, self.shape.x, self.shape.y)

        if self.img then
            lg.draw(self.img, self.img_pos.x, self.img_pos.y)
        end
        lg.setColor(0, 0, 0)
        lg.printf(self.words, self.pos.x, self.pos.y + self.shape.y - 80, self.shape.x, "center")
    end,

    on_click = function(self)
        self.on = false
    end
}

class "OkayButton" (Button) {
    draw = function(self)
        if not self.show then return end
        lg.setColor(230, 100, 100)
        lg.rectangle("fill", self.pos.x, self.pos.y, self.shape.x, self.shape.y)
        lg.setColor(255, 255, 255)
        lg.printf("Okay", self.pos.x, self.pos.y + self.shape.y / 2 - 10, self.shape.x, "center")
    end
}
