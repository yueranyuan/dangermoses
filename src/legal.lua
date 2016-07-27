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
    end,

    get_laws = function(self)
        return lume.filter(lume.map(self.rooms, function(r) return r.law end))
    end,

    add_law = function(self, plan)
        if self.rooms[1].law ~= nil then
            return false
        end

        self.rooms[1]:set_law(Legislation(plan))
        return true
    end,

    next = function(self)
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

class "Legislation" (Object) {
    ICON_SCALE = 2,

    __init__ = function(self, plan)
        self.builder = plan.builder
        self.building = plan.building
        self.icon = self.building.img
        self.icon_shape = self.building.shape
        self.type = self.building.type
        self.color = self.building.color
        self.cells = plan.cells
        self.committees = plan.committees
        self.n_supporters = plan.n_supporters
        self.n_haters = plan.n_haters
        self.n_failures = 0
        self.powerups = {}
        self:super(Legislation).__init__(self, v(550, 0), v(200, 50))
    end,

    set_room = function(self, room)
        self.current_room = room
        self.pos.y = room.pos.y
        self.pos.x = room.pos.x - self.shape.x - 10
    end,

    draw = function(self)
        self:super(Legislation).draw(self)
        draw_transparent_rect(self.pos.x, self.pos.y, 45, self.shape.y, {50, 50, 50})
        self:lgSetColor(255, 0, 0)
        lg.print(self.n_haters, self.pos.x + 20, self.pos.y)
        if self.n_failures > 0 then
            lg.print("failed", self.pos.x, self.pos.y + 15)
        end
        self:lgSetColor(255, 255, 255)
        local pos = v(self.pos.x + self.shape.x - self.ICON_SCALE * self.icon_shape.x - 5,
                      self.pos.y + self.shape.y / 2 - self.ICON_SCALE * self.icon_shape.y / 2)
        lg.draw(self.icon, pos.x, pos.y, 0, self.ICON_SCALE)
    end,

    get_remaining_committees = function(self)
        local my_idx = lume.find(government.rooms, self.current_room)
        local n_remaining = #lume.filter(self.committees, function(com)
            return lume.find(government.rooms, com) > my_idx
        end)
        return n_remaining
    end,

    get_attackers = function(self, committee)
        if not committee:is_active() then return 0 end
        if self.n_haters <= 0 then return 0 end
        if committee.n_yeas <= 0 then return 0 end

        local n_remaining = self:get_remaining_committees()
        local n_attackers = math.floor(self.n_haters / (1 + n_remaining))
        self.n_haters = self.n_haters - n_attackers
        return n_attackers
    end
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
        self:super(Room).__init__(self, pos, v(GAME_WIDTH - pos.x, Committee.HEIGHT - 5))
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
}

class "MosesOffice" (Room) {
    __init__ = function(self, pos)
        self:super(MosesOffice).__init__(self, pos)
        local callback = function() return self:cancel_building() end
        self.cancel_button = CancelButton(pos + v(10, 10), callback)
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
        player.influence = player.influence + law.n_supporters
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

class "Committee" (Room) {
    MEMBER_IMG = lg.newImage('grafix/person.png'),

    __init__ = function(self, pos, n_members)
        self.n_members = n_members
        self:super(Committee).__init__(self, pos)

        self.n_yeas = math.ceil(self.n_members / 2)
        self.member_health = HATER_PER_MEMBER
    end,

    set_law = function(self, law)
        self:super(Committee).set_law(self, law)
        if law ~= nil then
            local n_attackers = law:get_attackers(self)
            for i = 1, n_attackers do
                self:attack()
            end
        end
    end,

    attack = function(self)
        self.member_health = self.member_health - 1
        if self.member_health <= 0 then
            self.n_yeas = math.max(self.n_yeas - 1, 0)
            self.member_health = HATER_PER_MEMBER
        end
    end,

    draw_member_pile = function(self, pos, n, color)
        if n == 0 then return end
        -- arrange the spots to stand
        local spots = {}  -- a heap to be drawn in reverse order
        local width = math.ceil(math.sqrt(n))
        local _width = width
        for i = 0,n - 1 do
            if i % width == 0 and n - i <= width then -- final line
                _width = ((n - 1) % width) + 1
            end
            local spot = v(i % width - _width / 2, -math.floor(i / width))
            table.insert(spots, spot)
        end
        local mean = utils.sum(spots) / n

        -- draw
        for _, spot in lume.ripairs(spots) do
            self:lgSetColor(color)
            local _pos = pos + (spot - mean) * 10
            lg.draw(self.MEMBER_IMG, _pos.x, _pos.y)
        end
    end,

    check_pass = function(self)
        return self.n_yeas > self.n_members / 2
    end,

    add_supporter = function(self)
        self.n_yeas = math.min(self.n_members, self.n_yeas + 1)
    end,

    decide = function(self, law)
        return self:check_pass()
    end,

    draw = function(self)
        self:super(Committee).draw(self)
        self:draw_member_pile(self.pos + v(10, 20), self.n_yeas, {0, 255, 0})
        self:draw_member_pile(self.pos + v(self.shape.x - 50, 20), self.n_members - self.n_yeas, {255, 0, 0})
        self:lgSetColor({0, 0, 0})
        lg.printf(lume.round(self.n_yeas / self.n_members * 100).."%", self.pos.x, self.pos.y + 20, self.shape.x, "center")
    end
}

class "Member" (Object) {
    IMG = lg.newImage('grafix/person.png'),

    __init__ = function(self, party, yea)
        self.img = Member.IMG
        self.party = party
        self:super(Member).__init__(self)
    end,
}

class "OldCommittee" (Room) {
    __init__ = function(self, pos, n_seats)
        self.n_seats = n_seats
        self:super(Committee).__init__(self, pos)

        -- generate seats
        self.seats = {}
        local seat_pos = self.pos + self.MARGIN
        local seat_shape = self.shape - 2 * self.MARGIN
        seat_shape.x = (seat_shape.x / self.n_seats)
        for i = 0,self.n_seats - 1 do
            local seat = Seat(seat_pos + v(i * seat_shape.x, 0), seat_shape - v(2, 0), "neutral", self)
            table.insert(self.seats, seat)
        end

        -- fill the initial seats
        self.holder_order = lume.concat({player, 'neutral'}, {TAMMANY}, AIs)
        self:init_seat_holders()
        self:reshuffle_seats()

        -- powerups
        self.powerups = {}
        self.extra_votes = 0
    end,

    init_seat_holders = function(self)
        local n_players = #AIs + 1
        self.seat_holders = {neutral=self.n_seats - n_players}
        self.seat_holders[player] = 1
        self.seat_holders[TAMMANY] = 0
        for _, AI in ipairs(AIs) do
            self.seat_holders[AI] = 1
        end
    end,

    update = function(self)
        if self.law == nil then
            self.color = {self.color[1], self.color[2], self.color[3]}
            for _, seat in ipairs(self.seats) do
                seat.state = 'idle'
            end
        else
            self:update_law(self.law)
        end
    end,

    update_law = function(self, law)
        local extra_votes_remaining = self.extra_votes
        if lume.find(law.committees, self) == nil or self.closed then  -- committee not active
            self.color = {self.color[1], self.color[2], self.color[3], 50}
            for _, seat in ipairs(self.seats) do
                seat.state = 'inactive'
            end
        else  -- committee is active
            -- set whether the seats approve
            self.color = {self.color[1], self.color[2], self.color[3]}
            local neutral_i = 0
            for _, seat in ipairs(self.seats) do
                if seat.holder == player then
                    seat.state = 'yea'
                elseif seat.holder == 'neutral' then
                    neutral_i = neutral_i + 1
                    local percentage = 0
                    if law.n_supporters + law.n_haters > 0 then
                        percentage = law.n_supporters / (law.n_supporters + law.n_haters)
                    end
                    if neutral_i <= self.seat_holders['neutral'] * percentage then
                        seat.state = 'yea'
                    else
                        if extra_votes_remaining > 0 then
                            extra_votes_remaining = extra_votes_remaining - 1
                            seat.state = 'yea'
                        else
                            seat.state = 'nay'
                        end
                    end
                else
                    if extra_votes_remaining > 0 then
                        extra_votes_remaining = extra_votes_remaining - 1
                        seat.state = 'yea'
                    else
                        seat.state = 'nay'
                    end
                end
            end
        end
    end,

    decide = function(self, law)
        return self:check_pass(self.law.builder, self.law.n_supporters, self.law.n_haters)
    end,

    can_replace = function(self, incoming)
        local holders = lume.keys(self.seat_holders)
        holders = lume.filter(holders, function(h) return self.seat_holders[h] > 0 end)
        lume.remove(holders, incoming)
        if self.seat_holders[incoming] + self.seat_holders['neutral'] < self.n_seats then
            lume.remove(holders, 'neutral')
        end
        return holders
    end,

    update_seat = function(self, former, incoming)
        assert(self.seat_holders[former] ~= nil)
        if self.seat_holders[former] <= 0 then return end
        if former == incoming then return end

        if lume.find(self:can_replace(incoming), former) == nil then
            return
        end

        -- update seat holder counts
        self.seat_holders[former] = self.seat_holders[former] - 1
        self.seat_holders[incoming] = self.seat_holders[incoming] + 1

        -- reshuffle seats to reflect count
        self:reshuffle_seats()
    end,

    reshuffle_seats = function(self)
        local idx = 1
        for _, holder in ipairs(self.holder_order) do
            for _ = 1,self.seat_holders[holder] do
                self.seats[idx]:set_holder(holder)
                idx = idx + 1
            end
        end
    end,

    count_yays = function(self, builder, n_supporters, n_haters)
        return #lume.filter(self.seats, function(s) return s.state == 'yea' end)
    end,

    check_pass = function(self, builder, n_supporters, n_haters)
        return self:count_yays(builder, n_supporters, n_haters) > self.n_seats / 2
    end,
}

class "ProjectCommittee" (Committee) {
    -- Committee where we remove neutral first
    __init__ = function(self, pos, type)
        self.type = type
        self.color = Map.TYPES[type]
        self:super(ProjectCommittee).__init__(self, pos, 9)
    end,
}

class "DistrictCommittee" (Committee) {
    __init__ = function(self, pos, district)
        self.district = district
        self.district_color = Map.DISTRICTS[district]
        self.color = {255, 255, 150}
        self:super(DistrictCommittee).__init__(self, pos, 7)
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