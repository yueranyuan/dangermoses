class "HUD" (Object) {
    SUCCESS = {0, 255, 0},
    FAIL = {255, 0, 0},
    NEUTRAL = {255, 255, 255},
    MOUSE_IMG = lg.newImage('grafix/mouse.png'),

    __init__ = function(self)
        self.message = ""
        self.message_color = HUD.NEUTRAL
        self.message_timer = 0.0
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
        love.graphics.setColor(255, 255, 255, 255)
        for i = 1,player.big_dudes do
            love.graphics.rectangle('fill', GAME_WIDTH - i * 17, 10, 15, 25)
        end
        if player.big_dudes == 0 then
            love.graphics.print("you have no big dudes", GAME_WIDTH - 200, 0)
        else
            love.graphics.print("big dudes: ", GAME_WIDTH - player.big_dudes * 17 - 80, 0)
        end

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
        if player.building ~= nil then
            local popularity_text = ''
            if player.building:is_buildable(player) then
                popularity_text = '(ok)'
            end
            lg.print(popularity_text..' popularity: '..lume.round(map.hovered_popularity * 100),
                      player.mousepos.x, player.mousepos.y)
        else
            lg.draw(self.MOUSE_IMG, player.mousepos.x, player.mousepos.y)
        end
    end
}

class "BuildingButtonTray" (Object) {
    __init__ = function(self)
        self.active_button = nil
        local shape = v((#lume.keys(Map.TYPES)) * BuildingButton.BUTTON_SIZE + 20, BuildingButton.BUTTON_SIZE + 20)
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

    resolve_active_button = function(self, success)
        if success then
            self.active_button:refresh()
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
        -- draw transparent block
        local old_blend_mode = lg.getBlendMode()
        lg.setBlendMode("multiply")
        lg.setColor(50, 50, 50)
        lg.rectangle('fill', self.pos.x, self.pos.y, self.shape.x, self.shape.y)
        lg.setBlendMode(old_blend_mode)
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
            self:on_click(mousepos)
        end
    end
}

class "RefreshButton" (Button) {
    __init__ = function(self, pos, tray)
        self.tray = tray
        self.color = {150, 150, 150}
        self:super(RefreshButton).__init__(self, pos, v(BuildingButton.BUTTON_SIZE, BuildingButton.BUTTON_SIZE))
    end,

    draw = function(self, offset)
        self:super(RefreshButton).draw(self, offset)
        self.color = {0, 0, 0}
        lg.print("Refresh", self.pos.x, self.pos.y + self.shape.y / 2 - 10)
    end,

    on_click = function(self)
        self.tray:refresh_all()
    end
}

class "BuildingButton" (Button) {
    REFRESH_TIME = 10.0,
    BUTTON_SIZE = 60,
    ICON_SCALE = 6,

    __init__ = function(self, pos, type, tray)
        self.tray = tray
        self.type = type
        self.color = Map.TYPES[type]
        self.refresh_time = 0.0
        self:super(BuildingButton).__init__(self, pos, v(BuildingButton.BUTTON_SIZE, BuildingButton.BUTTON_SIZE))

        self:next()
    end,

    next = function(self)
        self.state = 'showing'
        self.pattern = lume.randomchoice(Building.PATTERNS)
        self.icon = Building.all_imgs[self.pattern]
        self.icon_shape = v(self.icon:getWidth(), self.icon:getHeight())
    end,

    refresh = function(self)
        self.refresh_time = BuildingButton.REFRESH_TIME
        self.state = 'refreshing'
    end,

    update = function(self, dt)
        if self.refresh_time > 0 then
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
        player:hold_building(Building(self.pattern, self.type))
        self.tray:set_active_button(self)
    end
}
