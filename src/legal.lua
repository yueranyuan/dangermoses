class "Government" (Object) {
    __init__ = function(self, x)
        self:super(Government).__init__(self, v(x, 0), v(GAME_WIDTH - x, GAME_HEIGHT))
        self.moses_office = MosesOffice(self.pos)
        self.committees = {}
        for type_i, type in ipairs(lume.keys(Map.TYPES)) do
            local com = ProjectCommittee(v(self.pos.x, (#self.committees+1) * Committee.HEIGHT), type)
            table.insert(self.committees, com)
        end
        for district_i, district in ipairs(lume.keys(Map.DISTRICTS)) do
            local com = DistrictCommittee(v(self.pos.x, (#self.committees+1) * Committee.HEIGHT),
                                          district)
            table.insert(self.committees, com)
        end

        self.mayor_office = MayorOffice(v(self.pos.x, (#self.committees+1) * Committee.HEIGHT))
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
                    if room.law ~= nil then
                        room:process_law(room.law)
                    end
                    room:next()
                end)
            end
        end
        self:add_action(function() building_button_tray:refresh_all() end)

        self.run_next_action()
    end,

    next_old = function(self)
        self:_next()
        while #self:get_laws() > 0 and #lume.filter(self.rooms, function(r) return r:is_active() end) == 0 do
            self:_next()
        end

        self.turn_i = self.turn_i + 1
        building_button_tray:refresh_all()
    end,

    _next = function(self)
        for room_i, room in lume.ripairs(self.rooms) do
            -- decide current law
            local law = room.law
            if law and room:is_active() then
                if not room:decide(law) then
                    law.n_failures = law.n_failures + 1
                end
                room:finish(law)
            end

            -- pull previous law up to current room
            if room_i > 1 then
                room:set_law(self.rooms[room_i - 1].law)
            else
                room:set_law(nil)
            end

            -- destroy current law if it is the last
            if law and room_i == #self.rooms then
                law:destroy()
            end

            room:next()
        end
    end,

    draw = function(self)
        draw_transparent_rect(self.pos.x, 0, GAME_WIDTH, GAME_HEIGHT, {50, 50, 50})
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
        self:super(Crowd).__init__(self, pos)
    end,

    add_person = function(self, start_pos, color, callback, speed)
        if speed == nil then
            speed = 0.3
        end
        local free_member = FreeMember(start_pos:clone(), utils.shallow_copy(color))
        Timer.tween(speed, free_member, {pos={x=self.pos.x, y=self.pos.y}, color=self.color},
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
        self.n_failures = 0
        self.powerups = {}
        self.crowd_offset = v(10, 10)
        self:super(Legislation).__init__(self, v(550, 0), v(200, 50))

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
    end,

    set_room = function(self, room)
        self.current_room = room
        self.pos.y = room.pos.y
        self.pos.x = room.pos.x - self.shape.x - 10
    end,

    destroy = function(self)
        self:super(Legislation).destroy(self)
        self.crowd:destroy()
    end,

    update = function(self, dt)
        if self.n_failures > 0 then
            self.color = {150, 0, 0}
        elseif self.current_room:is_active() then
            if self.current_room:decide(self) then
                self.color = {30, 50, 30}
            else
                self.color = {50, 30, 30}
            end
        else
            self.color = {30, 30, 30}
        end
        self.crowd.pos = self.pos + self.crowd_offset
    end,

    draw = function(self)
        self:super(Legislation).draw(self)
        draw_transparent_rect(self.pos.x, self.pos.y, 45, self.shape.y, {50, 50, 50})
        self:lgSetColor(255, 0, 0)
        if self.n_failures > 0 then
            lg.print("failed", self.pos.x, self.pos.y + 10)
            self.crowd.shown = false
        end
        -- self:lgSetColor(255, 255, 255)
        self:lgSetColor(self.icon_color)
        local pos = v(self.pos.x + self.shape.x - self.ICON_SCALE * self.icon_shape.x - 5,
                      self.pos.y + self.shape.y / 2 - self.ICON_SCALE * self.icon_shape.y / 2)
        lg.draw(self.icon, pos.x, pos.y, 0, self.ICON_SCALE)
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

        local n_remaining = #self:get_remaining_committees()
        local n_attackers = math.floor(self.crowd.n / (1 + n_remaining))
        self:remove_haters(n_attackers)
        return n_attackers
    end,

    remove_haters = function(self, n)
        self.crowd.n = math.max(0, self.crowd.n - n)
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
        return function()
            Timer.tween(0.3, self.pos, {y = next_committee.pos.y}, 'in-out-quad', function()
                next_committee:set_law(self)
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

class "RoomVerdict" (Object) {
    __init__ = function(self, room)
        self.shown = false
        self.room = room
        self:super(RoomVerdict).__init__(self, room.pos, v(10, 10))
    end,

    update = function(self)
        if self.room.law and self.room:is_active() then
            if self.room:decide(self.room.law) then
                self:set_success()
            else
                self:set_fail()
            end
        else
            self:hide()
        end
    end,

    hide = function(self)
        self.shown = false
    end,

    set_fail = function(self)
        self.shown = true
        self.color = {255, 0, 0}
    end,

    set_success = function(self)
        self.shown = true
        self.color = {0, 255, 0}
    end,
}

class "Room" (Object) {
    HEIGHT = 64,
    MARGIN = 15,

    __init__ = function(self, pos)
        self:super(Room).__init__(self, pos, v(GAME_WIDTH - POWERUP_TRAY_WIDTH - pos.x, Committee.HEIGHT - 5))
        self.verdict = RoomVerdict(self)
        self.verdict:set_parent(self)
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
            if not self:decide(law) then
                law.n_failures = law.n_failures + 1
            end
            self:finish(law)
        end
    end
}

class "MosesOffice" (Room) {
    __init__ = function(self, pos)
        self:super(MosesOffice).__init__(self, pos)
        local callback = function() return self:cancel_building() end
        self.cancel_button = CancelButton(pos + v(10, 10), callback)
        self.crowd = Crowd(pos + v(self.shape.x - 50, 10), 0, {0, 255, 0})
    end,

    spend = function(self, cost)
        if self.crowd.n >= cost then
            self.crowd.n = self.crowd.n - cost
            return true
        end
        return false
    end,

    update = function(self)
        self.cancel_button.clickable = (self.law ~= nil)
        building_button_tray:set_hidden(self.law ~= nil)
    end,

    cancel_building = function(self)
        if self.law == nil then return false end
        hud:set_message("project canceled", HUD.FAIL)
        map:remove_pending_building(self.law.building)
        self.law:destroy()
        self:set_law(nil)
        return true
    end,

    add_supporters = function(self, people)
        lume.each(people, function(p)
            Timer.after(math.random() * 0.3, function()
                self.crowd:add_person(p.pos, p.color)
            end)
        end)
    end,

    draw = function(self)
        self:super(MosesOffice).draw(self)
        self:lgSetColor(0, 0, 0)
        lg.print("Moses Office: ", self.pos.x + 10, self.pos.y + 10)
    end
}

class "CancelButton" (Button) {
    __init__ = function(self, pos, callback)
        self.color = {255, 0, 0 }
        self:super(CancelButton).__init__(self, pos, v(100, 30), callback)
    end,

    draw = function(self)
        if self.clickable then
            self:super(CancelButton).draw(self)
            lg.setColor({255, 255, 255})
            lg.printf("Cancel", self.pos.x, self.pos.y + self.shape.y / 2 - 10, self.shape.x, 'center')
        end
    end
}

class "MayorOffice" (Room) {
    __init__ = function(self, pos)
        self.strikes = 3
        self.tiles = 0
        self.needed_tiles = 50
        self.past_tiles = 0
        self.past_turns = 0
        self.total_turns = 12
        self:super(MayorOffice).__init__(self, pos)
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

    next = function(self, law)
        if government.turn_i - self.past_turns >= self.total_turns then
            self.past_turns = government.turn_i
            local n_tiles = player.built_cells + map.n_pending_tiles
            self.past_tiles = n_tiles
            self.strikes = 3
        end
    end,

    approve = function(self, law)
        hud:set_message("project approved", HUD.SUCCESS)
        -- TODO: finalize building
        map:place_building(law.builder, law.building)
    end,

    disapprove = function(self, law)
        self.strikes = self.strikes - 1
        -- TODO: fail building
        hud:set_message("project rejected", HUD.FAIL)
        map:remove_pending_building(law.building)
    end,

    draw = function(self)
        self:super(MayorOffice).draw(self)
        self:lgSetColor(0, 0, 0)
        lg.print("#Strikes Remaining: "..self.strikes, self.pos.x + 10, self.pos.y + 10)
        lg.print("turns till new mayor: "..(government.turn_i - self.past_turns).."/"..self.total_turns,
                 self.pos.x + 10, self.pos.y + 25)
        local n_tiles = player.built_cells + map.n_pending_tiles
        lg.print("new tile quota: "..(n_tiles - self.past_tiles).."/"..(self.needed_tiles),
                 self.pos.x + 10, self.pos.y + 40)
    end
}

class "FreeMember" {
    __init__ = function(self, pos, color)
        self.pos = pos
        self.color = color
    end
}

class "Committee" (Room) {

    __init__ = function(self, pos, n_members)
        self.n_members = n_members
        self:super(Committee).__init__(self, pos)

        self.member_health = HATER_PER_MEMBER
        self.powerups = {}

        local n_yeas = math.ceil(self.n_members * 0.60)
        self.yea_crowd = Crowd(v(0, 0), n_yeas, {0, 255, 0})
        self.yea_crowd.parent = self
        self.nay_crowd = Crowd(v(0, 0), self.n_members - n_yeas, {255, 0, 0})
        self.nay_crowd.parent = self
    end,

    update = function(self, dt)
        self.yea_crowd.pos = self.pos + v(10, 20)
        self.nay_crowd.pos = self.pos + v(self.shape.x - 50, 20)
    end,

    attack = function(self, n, callback)
        if n == nil then
            n = 1
        end
        if n <= 0 then
            if callback then callback() end
            return
        end

        self.member_health = self.member_health - 1
        if self.member_health <= 0 and self.yea_crowd.n > 0 then
            self.yea_crowd.n = self.yea_crowd.n - 1
            self.nay_crowd:add_person(self.yea_crowd.pos, self.yea_crowd.color, function()
                self.member_health = HATER_PER_MEMBER
                self:attack(n - 1, callback)
            end, 0.3 / n)
        else
            if callback then callback() end
        end
    end,

    add_supporter = function(self)
        if self.nay_crowd.n > 0 then
            self.nay_crowd.n = self.nay_crowd.n - 1
            self.yea_crowd:add_person(self.nay_crowd.pos, self.nay_crowd.color)
        end
    end,

    check_pass = function(self)
        return self.yea_crowd.n > self.n_members / 2
    end,

    decide = function(self, law)
        return self:check_pass()
    end,

    draw = function(self)
        self:super(Committee).draw(self)
        self:lgSetColor({0, 0, 0})
        lg.printf(lume.round(self.yea_crowd.n / self.n_members * 100).."%", self.pos.x, self.pos.y + 20, self.shape.x, "center")
    end
}

class "ProjectCommittee" (Committee) {
    -- Committee where we remove neutral first
    __init__ = function(self, pos, type)
        self.type = type
        self.color = Map.TYPES[type]
        self:super(ProjectCommittee).__init__(self, pos, 15)
    end,
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