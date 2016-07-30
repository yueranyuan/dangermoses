class "Government" (Object) {
    __init__ = function(self, x)
        self:super(Government).__init__(self, v(x, powerup_tray.pos.y + powerup_tray.shape.y), v(GAME_WIDTH - x, GAME_HEIGHT))
        self.moses_office = MosesOffice(self.pos)
        self.committees = {}
        for type_i, type in ipairs(MAP_DATA.committees) do
            if type ~= "moses" then
                local com = ProjectCommittee(self.pos + v(0, (#self.committees+1) * Committee.HEIGHT), type)
                table.insert(self.committees, com)
            end
        end
        for district_i, district in ipairs(lume.keys(Map.DISTRICTS)) do
            if district ~= "land" then
                local com = DistrictCommittee(self.pos + v(0, (#self.committees+1) * Committee.HEIGHT),
                                              district)
                table.insert(self.committees, com)
            end
        end

        self.mayor_office = MayorOffice(self.pos + v(0, (#self.committees+1) * Committee.HEIGHT))
        self.rooms = lume.concat({self.moses_office}, self.committees, {self.mayor_office})
        self.turn_i = 0
        self.actions = {}
        self.run_next_action = function()
            if #self.actions > 0 then
                local action = table.remove(self.actions, 1)
                action()
            end
        end
    end,

    get_laws = function(self)
        return lume.filter(lume.map(self.rooms, function(r) return r.law end))
    end,

    add_law = function(self, plan)
        if self.rooms[1].law ~= nil then
            return false
        end

        Legislation(plan, self.rooms[1])
        return true
    end,

    update = function(self, dt)
        mouseenabled = #self.actions <= 0

        if 0 == #lume.filter(self.committees, function(com) return not com:is_commissioner() end) then
            if not win then
                win = true
                overlay:set("You win! But since this is a debug build you get nothing", Overlay.SHRUG_IMG)
            end
        end
    end,

    add_action = function(self, func)
        table.insert(self.actions, function()
            func()
            self.run_next_action()
        end)
    end,

    next = function(self)
        -- process all rooms
        for room_i, room in lume.ripairs(self.rooms) do
            if room.law then
                room:process_law(room.law)
            end
        end

        -- begin next turn
        self.turn_i = self.turn_i + 1
        for room_i, room in lume.ripairs(self.rooms) do
            if room.law then
                local law_action = room.law:get_action(self.run_next_action)
                if law_action ~= nil then
                    table.insert(self.actions, law_action)
                end
                self:add_action(function()
                    room:next()
                end)
            end
        end
        self:add_action(function()  end)

        self.run_next_action()
    end,

    draw = function(self)
    end
}

class "FreeMember" {
    __init__ = function(self, pos, color)
        self.pos = pos
        self.color = color
    end
}

class "Crowd" (Object) {
    PERSON_IMG = lg.newImage('grafix/person.png'),

    __init__ = function(self, pos, n, color, img)
        if img == nil then
            img = Crowd.PERSON_IMG
        end
        self.img = img
        self.n = n
        self.color = color
        self.free_members = {}
        self.show_n = true
        self:super(Crowd).__init__(self, pos)
    end,

    add_person = function(self, start_pos, color, callback, speed)
        if speed == nil then
            speed = 0.3
        end
        -- pad colors appropriately
        local target_color = self.color
        if #color < #self.color then
            color = {color[1], color[2], color[3], 255 }
        elseif #self.color < #color then
            target_color = {target_color[1], target_color[2], target_color[3], 255}
        end

        -- tween free member
        local free_member = FreeMember(start_pos:clone(), utils.shallow_copy(color))
        Timer.tween(speed, free_member, {pos={x=self.pos.x, y=self.pos.y}, color=target_color},
            'in-out-quad', function()
                self.n = self.n + 1
                lume.remove(self.free_members, free_member)
                if callback ~= nil then
                    callback()
                end
            end)
        table.insert(self.free_members, free_member)
    end,

    draw = function(self)
        local scale = math.min(1, 3 / math.sqrt(self.n))

        -- draw free members
        for _, m in ipairs(self.free_members) do
            self:lgSetColor(m.color)
            lg.draw(self.img, m.pos.x, m.pos.y, 0, scale)
        end

        if self.n == 0 then return end

        self:lgSetColor(self.color)
        -- arrange the spots to stand
        local spots = {}  -- a heap to be drawn in reverse order
        local width = math.ceil(math.sqrt(self.n))
        local _width = width
        for i = 0,self.n - 1 do
            if i % width == 0 and self.n - i <= width then -- final line
            _width = ((self.n - 1) % width) + 1
            end
            local spot = v(i % width - _width / 2, -math.floor(i / width))
            table.insert(spots, spot)
        end
        local mean = utils.sum(spots) / self.n

        -- draw
        for _, spot in lume.ripairs(spots) do
            local _pos = self.pos + (spot - mean) * scale * 10
            lg.draw(self.img, _pos.x, _pos.y, 0, scale)
        end

        -- draw n
        if self.show_n then
            local n_pos = v(self.pos.x, self.pos.y + 10)
            draw_transparent_rect(n_pos.x, n_pos.y, 15, 15, {50, 50, 50})
            self:lgSetColor(self.color)
            lg.print(self.n, n_pos.x, n_pos.y)
        end
    end,
}

class "Legislation" (Object) {
    ICON_SCALE = 4,

    __init__ = function(self, plan, room)
        self.builder = plan.builder
        self.building = plan.building
        self.icon = self.building.img
        self.icon_shape = self.building.shape
        self.type = self.building.type
        self.icon_color = self.building.color
        self.cells = plan.cells
        self.committees = plan.committees
        self.n_supporters = plan.n_supporters
        self.n_haters = plan.n_haters
        self.plan = plan
        self.n_failures = 0
        self.powerups = {}
        self.alpha = 255
        self:super(Legislation).__init__(self, v(550, 0), v(150, 50))
        self.crowd_offset = v(self.shape.x, 10)

        room:set_law(self)
        self.crowd = Crowd(self.pos + self.crowd_offset, 0, {255, 0, 0})
        self.crowd.parent = self
        lume.each(plan.people, function(p)
            if p:check_state(self.building.type) == 'sad' then
                Timer.after(math.random() * 0.3, function()
                    self.crowd:add_person(p.pos, p.color)
                end)
            end
        end)

        self.flash_handle = nil
    end,

    set_room = function(self, room)
        self.current_room = room
        self.pos.y = room.pos.y
        self.pos.x = room.pos.x - self.shape.x - 30
    end,

    destroy = function(self)
        self:super(Legislation).destroy(self)
        self.crowd:destroy()
    end,

    update = function(self, dt)
        if player.plan then
            self.alpha = 50
        else
            self.alpha = 255
        end

        self.flashing = false
        if self.n_failures > 0 then
            self.color = {150, 0, 0}
        elseif self.current_room:is_active() then
            if self.current_room:decide(self) then
                self.color = {30, 50, 30}
            else
                if not progress.first_failing_legislation then
                    overlay:set("when legislations are flashing it means they're going to fail")
                end
                self.flashing = true
            end
        else
            self.color = {30, 30, 30}
        end
        self.crowd.pos = self.pos + self.crowd_offset

        self:update_flash()
    end,

    update_flash = function(self, dt)
        if self.flashing then  -- should be flashing
            if not self.flash_handle then
                self.flash_handle = Timer.every(0.6, function()
                    Timer.tween(0.3, self, {color={255, 30, 30}}, 'linear', function()
                        Timer.tween(0.3, self, {color={50, 30, 30}}, 'linear', function()
                        end)
                    end)
                end)
            end
        else  -- should not be flashing
            if self.flash_handle then
                Timer.cancel(self.flash_handle)
                self.flash_handle = nil
            end
        end
    end,

    draw = function(self)
        local color = {self.color[1], self.color[2], self.color[3], self.alpha }
        self.crowd.color = {self.crowd.color[1], self.crowd.color[2], self.crowd.color[3], self.alpha }

        -- draw background box
        self:lgSetColor(color)
        lg.rectangle('fill', self.pos.x, self.pos.y, self.shape.x, self.shape.y)

        -- draw whether we failed
        --draw_transparent_rect(self.pos.x, self.pos.y, 45, self.shape.y, {50, 50, 50})
        self:lgSetColor(255, 0, 0, self.alpha)
        if self.n_failures > 0 then
            lg.print("failed", self.pos.x, self.pos.y + 10)
            self.crowd.shown = false
        end

        -- draw building icon
        self:lgSetColor(255, 255, 255)
        --self:lgSetColor(self.icon_color[1], self.icon_color[2], self.icon_color[3], self.alpha)
        local pos = v(self.pos.x + self.shape.x - self.ICON_SCALE * self.icon_shape.x - 15,
                      self.pos.y + self.shape.y / 2 - self.ICON_SCALE * self.icon_shape.y / 2)
        lg.draw(self.icon, pos.x, pos.y, 0, self.ICON_SCALE)

        -- draw floor powerups
        local floor_powerup_imgs = {}
        for pu_i, pu in ipairs(self.plan.floor_powerups) do
            for i = 1, pu.n do
                table.insert(floor_powerup_imgs, pu.img)
            end
        end
        for img_i, img in ipairs(floor_powerup_imgs) do
            lg.draw(img, self.pos.x + 40 * (img_i / #floor_powerup_imgs), self.pos.y + 20)
        end

        -- draw dude
        if self.n_supporters > 0 then
            self:lgSetColor(0, 255, 0)
            lg.draw(Person.PERSON_IMG, self.pos.x + 60, self.pos.y + 20)
            self:lgSetColor(255, 255, 255)
            lg.print("x"..self.n_supporters, self.pos.x + 80, self.pos.y + 25)
        end

        -- draw committees icons
        local r = 5
        for com_i, com in ipairs(self.committees) do
            local pos = self.pos + v(40 + com_i * (r * 2 + 2), r)
            self:lgSetColor(com.color)
            lg.circle('fill', pos.x, pos.y, r)
        end
    end,

    add_hater = function(self, hater)
    end,

    get_remaining_committees = function(self)
        local my_idx = lume.find(government.rooms, self.current_room)
        return lume.filter(self.committees, function(com)
            return lume.find(government.rooms, com) > my_idx
        end)
    end,

    get_attackers = function(self, committee)
        if not committee:is_active() then return 0 end
        if self.crowd.n <= 0 then return 0 end
        if self.n_failures > 0 then return 0 end

        local n_attackers = self.crowd.n
        return n_attackers
    end,

    remove_haters = function(self, n)
        if self.crowd and self.crowd.n then
            self.crowd.n = math.max(0, self.crowd.n - n)
        end
    end,

    get_action = function(self, callback)
        local committees = self:get_remaining_committees()
        local next_committee
        if #committees == 0 then
            if self.current_room == government.mayor_office then
                self.current_room:set_law(nil)
                self:destroy()
                return
            end
            next_committee = government.mayor_office
        else
            next_committee = committees[1]
        end

        if next_committee.law ~= nil then return end
        self.current_room:set_law(nil)
        local start_pos = self.pos:clone()
        next_committee:set_law(self)
        self.pos = start_pos  -- undo the position change

        return function()
            Timer.tween(0.3, start_pos, {y = next_committee.pos.y}, 'in-out-quad', function()
                local n_attackers = self:get_attackers(next_committee)
                if n_attackers > 0 then
                    next_committee:attack(n_attackers, callback)
                else
                    callback()
                end
            end)
        end
    end,
}

class "Room" (Object) {
    HEIGHT = 64,
    MARGIN = 15,

    __init__ = function(self, pos, shape)
        if shape == nil then
            shape = v(GAME_WIDTH - 80 - pos.x, Committee.HEIGHT - 5)
        end
        self:super(Room).__init__(self, pos, shape)
        self.closed = false
    end,

    set_law = function(self, law)
        self.law = law
        if law ~= nil then
            law:set_room(self)
        end
    end,

    is_active = function(self)
        return (not self.closed and self.law ~= nil and (self.__class__ == MayorOffice or
                lume.find(self.law.committees, self) ~= nil))
    end,

    update_law = function(self, law)
        assert(false, "update_law is not implemented for this room")
    end,

    decide = function(self, law)
        return true
    end,

    finish = function(self, law)
    end,

    next = function(self)
    end,

    process_law = function(self, law)
        if law and self:is_active() then
            local passed = self:decide(law)
            if not passed then
                law.n_failures = law.n_failures + 1
            end
            self:finish(law, passed)
        end
    end,

    attack = function(self, n, callback)
        callback()
    end
}

class "MosesOffice" (Room) {
    OFFICE_IMG = lg.newImage("grafix/mosesoffice.png"),

    __init__ = function(self, pos)
        self.img = MosesOffice.OFFICE_IMG
        self:super(MosesOffice).__init__(self, pos)
        self.cancel_button = CancelButton(self.pos + v(10, 10), function()
             return self:cancel_building()
        end)
        self.next_button = NextButton(v(self.pos.x + self.shape.x, self.pos.y), function()
            return self:on_next()
        end)
        self.crowd = Crowd(pos + v(self.shape.x - 70, 10), 0, {0, 255, 0})
    end,

    spend = function(self, cost)
        if self.crowd.n >= cost then
            self.crowd.n = self.crowd.n - cost
            return true
        end
        return false
    end,

    can_spend = function(self, cost)
        return self.crowd.n >= cost
    end,

    update = function(self)
        self.cancel_button.clickable = (self.law ~= nil)
        self.next_button.clickable = (self.law ~= nil)
        building_button_tray.clickable = (self.law == nil)
    end,

    cancel_building = function(self)
        if self.law == nil then return false end
        hud:set_message("project canceled", HUD.FAIL, 2)
        map:remove_pending_building(self.law.building)
        self.law:destroy()
        self:set_law(nil)
        return true
    end,

    on_next = function(self)
        if not progress.first_try_building then
            Timer.after(0.8, function()
                overlay:set("now build another thing")
            end)
            progress.first_try_building = true
        end

        sfx_next:play()
        building_button_tray:refresh_all()
        government:next()
        for _, powerup in lume.ripairs(Powerup.powerups) do
            powerup:next()
        end
        return true
    end,

    add_supporters = function(self, people)
        lume.each(people, function(p)
            Timer.after(math.random() * 0.3, function()
                government.mayor_office.n_supporters = government.mayor_office.n_supporters + 1
                self.crowd:add_person(p.pos, p.color)
            end)
        end)
    end,

    draw = function(self)
        self:super(MosesOffice).draw(self)
    end
}

class "CancelButton" (Button) {
    __init__ = function(self, pos, callback)
        self.color = {255, 0, 0 }
        self:super(CancelButton).__init__(self, pos, v(80, 30), callback)
    end,

    draw = function(self)
        if self.clickable then
            self:super(CancelButton).draw(self)
            lg.setColor({255, 255, 255})
            lg.printf("Cancel", self.pos.x, self.pos.y + self.shape.y / 2 - 10, self.shape.x, 'center')
        end
    end
}

class "NextButton" (Button) {
    __init__ = function(self, pos, callback)
        self.color = {50, 180, 50 }
        self:super(NextButton).__init__(self, pos, v(70, 60), callback)
    end,

    update = function(self, dt)
        if self.clickable then
            self.color = {50, 180, 50 }
        else
            self.color = {0, 0, 0 }
        end
    end,

    draw = function(self)
        self:super(NextButton).draw(self)
        if self.clickable then
            lg.setColor({255, 255, 255})
            lg.printf("Next", self.pos.x, self.pos.y + self.shape.y / 2 - 10, self.shape.x, 'center')
        else
            lg.setColor({255, 255, 255})
            lg.printf("select a building", self.pos.x, self.pos.y + self.shape.y / 2 - 10, self.shape.x, 'center')
        end
    end,
}

class "MayorOffice" (Room) {
    PERSON_IMG = lg.newImage("grafix/person.png"),
    OFFICE_IMG = lg.newImage("grafix/mayoroffice.png"),
    STRIKE_IMG = lg.newImage("grafix/strike.png"),
    STRIKE_POS = {v(15, 42), v(13, 56), v(17, 70)},

    __init__ = function(self, pos)
        self.strikes = 1
        self.tiles = 0
        self.needed_tiles = 50
        self.img = MayorOffice.OFFICE_IMG
        self.past_tiles = 0
        self.past_turns = 0
        self.total_turns = 12
        self.n_supporters = 0
        self.needed_supporters = 30
        self:super(MayorOffice).__init__(self, pos, v(230, 140))

        self.resign_button = ResignButton(self.pos + v(40, 50), function()
            self:resign()
        end)
    end,

    resign = function(self)
        overlay:set("you just threatened to resign! The Mayor is not pleased but he'll do what you want this time.\n You've lost all your strikes. One more failure and you'll be fired!",
                    Overlay.RESIGN_IMG)
        self.law.n_failures = 0
        self.strikes = 0
    end,

    decide = function(self, law)
        return law.n_failures == 0
    end,

    finish = function(self, law)
        if self:decide(law) then
            self:approve(law)
        else
            self:disapprove(law)
        end
    end,

    update = function(self)
        self.resign_button.clickable = (self.law ~= nil and not self:decide(self.law) and self.strikes > 0)
    end,

    next = function(self, law)
        if government.turn_i - self.past_turns >= self.total_turns then
            overlay:set("A new mayor has been elected! He is confident in your skills.\nYou now have 3 more strikes", Overlay.NEW_MAYOR_IMG)
            self.past_turns = government.turn_i
            local n_tiles = player.built_cells + map.n_pending_tiles
            self.past_tiles = n_tiles
            self.strikes = 3
        end
    end,

    approve = function(self, law)
        sfx_mayor_pass:play()
        hud:set_message("project approved", HUD.SUCCESS, 2)
        map:place_building(law.builder, law.building)
    end,

    disapprove = function(self, law)
        sfx_mayor_reject:play()
        self.strikes = self.strikes - 1
        log.trace(self.strikes)
        if self.strikes == 1 then
            overlay:set("Careful! You're on your last strike with this mayor. \nOne more failed building and you'll be fired!", Overlay.ANGRY_IMG)
        elseif self.strikes == 0 then
            overlay:set("Well, technically you lose. But since it's a debug build. You get to keep playing :3", Overlay.SHRUG_IMG)
        end
        hud:set_message("project rejected", HUD.FAIL, 2)
        map:remove_pending_building(law.building)
    end,

    draw = function(self)
        self:super(MayorOffice).draw(self)
        self:lgSetColor(255, 255, 255)
        for strike_i = 1, math.min(3, 3 - self.strikes) do
            local pos = self.pos + self.STRIKE_POS[strike_i]
            lg.draw(self.STRIKE_IMG, pos.x, pos.y)
        end
        self:lgSetColor(255, 0, 0)
        lg.print(self.total_turns - government.turn_i - self.past_turns,
                 self.pos.x + 104, self.pos.y + 35)
        local n_tiles = player.built_cells + map.n_pending_tiles

        -- draw needed supporters
        --[[for i = 1, self.needed_supporters do
            if i <= self.n_supporters then
                self:lgSetColor(0, 255, 0)
            else
                self:lgSetColor(255, 0, 0)
            end
            lg.draw(self.PERSON_IMG, self.pos.x + i * 6, self.pos.y + 50)
        end]]--
        --lg.print("new tile quota: "..(n_tiles - self.past_tiles).."/"..(self.needed_tiles),
        --         self.pos.x + 10, self.pos.y + 40)
    end
}

class "ResignButton" (Button) {
    __init__ = function(self, pos, callback)
        self.color = {255, 0, 0 }
        self:super(ResignButton).__init__(self, pos, v(80, 30), callback)
    end,

    draw = function(self)
        if self.clickable then
            self:super(ResignButton).draw(self)
            lg.setColor({255, 255, 255})
            lg.printf("Intimidate", self.pos.x, self.pos.y + self.shape.y / 2 - 10, self.shape.x, 'center')
        end
    end
}

class "Committee" (Room) {
    REPUTATION_IMG = lg.newImage("grafix/star.png"),
    COMMISSIONER_IMG = lg.newImage("grafix/commissioner.png"),
    COMMITTEE_IMG = lg.newImage("grafix/committeeroom.png"),

    __init__ = function(self, pos, n_members, ratio, resilience)
        self.n_members = n_members
        self.img = Committee.COMMITTEE_IMG
        self:super(Committee).__init__(self, pos)

        self.member_health = HATER_PER_MEMBER
        self.powerups = {}

        if resilience == nil then
            resilience = 0
        end
        self.resilience = resilience

        if ratio == nil then
            ratio = 0.50
        end
        self.n_yeas = math.ceil(self.n_members * ratio)
        self.yea_crowd_offset = v(50, 25)
        self.yea_crowd = Crowd(self.yea_crowd_offset, self.n_yeas, {0, 255, 0})
        self.yea_crowd.show_n = false
        self.yea_crowd.parent = self
        self.nay_crowd_offset = v(self.shape.x - 15, 25)
        self.nay_crowd = Crowd(self.nay_crowd_offset, self.n_members - self.n_yeas, {255, 0, 0})
        self.nay_crowd.show_n = false
        self.nay_crowd.parent = self
    end,

    is_commissioner = function(self)
        return self.resilience >= 5
    end,

    update = function(self, dt)
        if self:is_active() then
            self.yea_crowd.color = {0, 255, 0}
            self.nay_crowd.color = {255, 0, 0}
        else
            self.yea_crowd.color = {100, 100, 100 }
            self.nay_crowd.color = {100, 100, 100 }
        end
        self.yea_crowd.pos = self.pos + self.yea_crowd_offset
        self.nay_crowd.pos = self.pos + self.nay_crowd_offset

        --if self.yea_crowd.n < self.n_yeas then
            --add_supporter()
    end,

    attack = function(self, n, callback)
        if n == nil then
            n = 1
        end
        n = math.max(n - self.resilience, 0)
        if callback == nil then
            callback = function() end
        end

        self:remove_supporter(n, callback)
    end,

    remove_supporter = function(self, n, callback)
        if n == nil then
            n = 1
        end
        if n <= 0 then
            if callback then callback() end
            return
        end

        if self.yea_crowd.n > 0 then
            self.yea_crowd.n = self.yea_crowd.n - 1
            self.nay_crowd:add_person(self.yea_crowd.pos, self.yea_crowd.color)
            Timer.after(0.3 / n, function()
                self:remove_supporter(n - 1, callback)
            end)
        else
            if callback then callback() end
        end
    end,

    add_supporter = function(self, n, callback)
        if n == nil then
            n = 1
        end
        if n <= 0 then
            if callback then callback() end
            return
        end

        if self.nay_crowd.n > 0 then
            self.nay_crowd.n = self.nay_crowd.n - 1
            self.yea_crowd:add_person(self.nay_crowd.pos, self.nay_crowd.color)
            Timer.after(0.3 / n, function()
                self:add_supporter(n - 1, callback)
            end)
        else
            if callback then callback() end
        end
    end,

    check_pass = function(self)
        return self.yea_crowd.n > self.n_members / 2
    end,

    finish = function(self, law, passed)
        if passed then
            if not progress.first_resilience then
                overlay:set("good work! you got a legislation pass a committee. \nYour reputation with the committee is increasing. Every reputation point you get cancels out one hater")
            end
            if self.resilience < 5 then
                self.resilience = self.resilience + 1
                self:become_commissioner()
            end
        end
    end,

    become_commissioner = function(self)
        if self:is_commissioner() then
            sfx_commissioner:play()
            overlay:set("Good work! You just became the commissioner of "..self.name.."s!", self.icon)
        end
    end,

    decide = function(self, law)
        return self:check_pass()
    end,

    draw = function(self)
        self:super(Committee).draw(self)
        self:lgSetColor(self.color)
        lg.draw(self.img, self.pos.x, self.pos.y)

        --local center_pos = self.pos + (self.yea_crowd_offset + self.nay_crowd_offset) / 2
        --lg.print(lume.round(self.yea_crowd.n / self.n_members * 100).."%", center_pos.x, center_pos.y)

        self:lgSetColor({0, 0, 0})
        --lg.rectangle("fill", self.pos.x, self.pos.y, 30, self.shape.y)
        if self.resilience > 0 then
            local color = 255 + 100 * (self.resilience / 5)
            self:lgSetColor({color, color, color})
            if self:is_commissioner() then
                if not progress.first_commissioner then
                    overlay:set("Congradulations! you're the commissioner. Become the commissioner of every committee and you win", self.icon)
                end
                lg.draw(self.COMMISSIONER_IMG, self.pos.x + 5, self.pos.y + 5)
                else
                local offsets = {v(0, 5), v(20, 5), v(0, 30), v(20, 30) }
                for i = 1, math.min(self.resilience, #offsets) do
                    lg.draw(self.REPUTATION_IMG, self.pos.x + offsets[i].x, self.pos.y + offsets[i].y)
                end
            end
        end
    end
}

class "ProjectCommittee" (Committee) {
    __init__ = function(self, pos, type, size)
        self.type = type
        self.color = Map.TYPES[type]
        self.data = COMMITTEES[type]
        self.icon = lg.newImage(self.data.img)
        self.name = self.data.name
        self:super(ProjectCommittee).__init__(self, pos, self.data.size, self.data.ratio, self.data.resilience)
        self.button_offset = v(self.shape.x + 30, 0)
        self.button = building_button_tray:add_button(self.pos + self.button_offset, self.type)
    end,

    update = function(self, dt)
        self:super(ProjectCommittee).update(self, dt)
        self.button.pos = self.pos + self.button_offset
    end,

    draw = function(self)
        self:super(ProjectCommittee).draw(self)
        self:lgSetColor(255, 255, 255)
        lg.draw(self.icon, self.pos.x + self.shape.x / 2 + 5, self.pos.y)
    end
}

class "DistrictCommittee" (Committee) {
    __init__ = function(self, pos, district)
        self.district = district
        self.district_color = Map.DISTRICTS[district]
        self.color = {255, 255, 150}
        self:super(DistrictCommittee).__init__(self, pos, 11)
    end,

    draw = function(self)
        self:super(DistrictCommittee).draw(self)
        self:lgSetColor(self.district_color)
        lg.rectangle("fill", self.pos.x + 30, self.pos.y, 10, 10)
        self:lgSetColor({0, 0, 0})
        lg.print(self.district, self.pos.x + 40, self.pos.y)
    end
}

class "Seat" (Object) {
    IMG = lg.newImage("grafix/person.png"),
    __init__ = function(self, pos, shape, holder, committee)
        self.committee = committee
        self.approve = false
        self.img = Seat.IMG
        self:set_holder(holder)
        self:super(Seat).__init__(self, pos)

        self:set_parent(self.committee)
    end,

    set_holder = function(self, holder)
        self.holder = holder
        if holder == "neutral" then
            self.color = {100, 100, 100}
        else
            self.color = holder.color
        end
    end,

    update = function(self)
        if self.state == 'inactive' then
            self.color = {self.color[1], self.color[2], self.color[3], 20 }
        else
            self.color = {self.color[1], self.color[2], self.color[3]}
        end
    end,

    on_click = function(self)
        if player.power then return end
    end,

    draw = function(self, offset)
        self:super(Seat).draw(self, offset)

        -- draw vote flag
        if self.state == 'yea' then
            self:lgSetColor(0, 255, 0, 200)
        elseif self.state == 'nay' then
            self:lgSetColor(255, 0, 0, 200)
        end
        if self.state == 'yea' or self.state == 'nay' then
            lg.rectangle('fill', self.pos.x, self.pos.y - self.shape.y * 0.3, self.shape.x, self.shape.y * 0.3)
        end
    end
}
