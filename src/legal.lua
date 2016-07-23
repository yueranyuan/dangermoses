class "Government" (Object) {
    __init__ = function(self, x, committee_class)
        self:super(Government).__init__(self, v(x, 0), v(GAME_WIDTH - x, GAME_HEIGHT))
        if committee_class == nil then
            committee_class = Committee
        end
        self.committees = {}
        for type_i, type in ipairs(lume.keys(Map.TYPES)) do
            local com = committee_class(v(self.pos.x, type_i * Committee.HEIGHT), type)
            table.insert(self.committees, com)
        end

        self.rooms = {}
        for _, com in ipairs(self.committees) do
            table.insert(self.rooms, com)
        end
        table.insert(self.rooms, MayorOffice(v(self.pos.x, (#self.rooms + 1) * Committee.HEIGHT)))

        self.legislations = {}
    end,

    add_law = function(self, plan)
        if self.rooms[1].law ~= nil then
            return false
        end

        self.rooms[1].law = Legislation(plan)
        self.rooms[1].law:set_room(self.rooms[1])
        return true
    end,

    next = function(self)
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
                room.law = self.rooms[room_i - 1].law
                if room.law then
                    room.law:set_room(room)
                end
            else
                room.law = nil
            end

            -- destroy current law if it is the last
            if law and room_i == #self.rooms then
                law:destroy()
            end
        end
    end,

    draw = function(self)
        draw_transparent_rect(self.pos.x, 0, GAME_WIDTH, GAME_HEIGHT, {50, 50, 50})
    end
}

class "Legislation" (Object) {
    ICON_SCALE = 8,

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
        self:super(Legislation).__init__(self, v(550, 0), v(100, 50))
    end,

    set_room = function(self, room)
        self.current_room = room
        self.pos.y = room.pos.y
        self.pos.x = room.pos.x - self.shape.x - 10
    end,

    draw = function(self)
        self:super(Legislation).draw(self)
        draw_transparent_rect(self.pos.x, self.pos.y, 45, GAME_HEIGHT, {50, 50, 50})
        lg.setColor(0, 255, 0)
        lg.print(self.n_supporters, self.pos.x, self.pos.y)
        lg.setColor(255, 0, 0)
        lg.print(self.n_haters, self.pos.x + 15, self.pos.y)
        if self.n_failures > 0 then
            lg.print("failed", self.pos.x, self.pos.y + 15)
        end
        lg.setColor(255, 255, 255)
        local pos = v(self.pos.x + self.shape.x - self.ICON_SCALE * self.icon_shape.x - 5,
                      self.pos.y + self.shape.y / 2 - self.ICON_SCALE * self.icon_shape.y / 2)
        lg.draw(self.icon, pos.x, pos.y, 0, self.ICON_SCALE)
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
    end,

    is_active = function(self)
        return (self.__class__ == MayorOffice or
                lume.find(self.law.committees, self) ~= nil)
    end,

    update_law = function(self, law)
        assert(false, "update_law is not implemented for this room")
    end,

    decide = function(self, law)
        return true
    end,

    finish = function(self, law)
    end,
}

class "MayorOffice" (Room) {
    __init__ = function(self, pos)
        self.strikes = 3
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

    approve = function(self, law)
        hud:set_message("project approved", HUD.SUCCESS)
        player.influence = player.influence + law.n_supporters
        -- TODO: finalize building
        --map:place_building(law.builder, law.building)
    end,

    disapprove = function(self, law)
        self.strikes = self.strikes - 1
        -- TODO: fail building
        hud:set_message("project rejected", HUD.FAIL)
    end,

    draw = function(self)
        self:super(MayorOffice).draw(self)
        lg.setColor(0, 0, 0)
        lg.print("#Strikes Remaining: "..self.strikes, self.pos.x + 10, self.pos.y + self.HEIGHT / 2)
    end
}

class "Committee" (Room) {
    __init__ = function(self, pos, type)
        self.type = type
        self.base_color = Map.TYPES[self.type]
        self.color = self.base_color
        self.n_seats = 9
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
    end,

    init_seat_holders = function(self)
        self.seat_holders = {neutral=math.floor(self.n_seats / 2) }
        local n_players = #AIs + 1
        self.seat_holders[TAMMANY] = math.ceil(self.n_seats / 2) - n_players
        self.seat_holders[player] = 1
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
        if lume.find(law.committees, self) == nil then  -- committee not active
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
                        seat.state = 'nay'
                    end
                else
                    seat.state = 'nay'
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
        if former == incoming then return end

        if lume.find(self:can_replace(incoming), former) == nil then
            return
        end

        -- subtract big dude from the incoming party
        if incoming ~= "neutral" then
            if incoming.big_dudes <= 0 then return end
            incoming.big_dudes = incoming.big_dudes - 1
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
        local neutral_votes = self.seat_holders['neutral'] * n_supporters / (n_haters + n_supporters)
        return neutral_votes + self.seat_holders[builder]
    end,

    check_pass = function(self, builder, n_supporters, n_haters)
        return self:count_yays(builder, n_supporters, n_haters) > self.n_seats / 2
    end
}

class "Committee2" (Committee) {
    -- Committee where we remove neutral first

    can_replace = function(self, incoming)
        if self.seat_holders['neutral'] > 0 then
            return {'neutral'}
        end
        local holders = lume.keys(self.seat_holders)
        holders = lume.filter(holders, function(h) return self.seat_holders[h] > 0 end)
        lume.remove(holders, incoming)
        return holders
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
}

class "Seat" (Object) {
    __init__ = function(self, pos, shape, holder, committee)
        self.committee = committee
        self.approve = false
        self:set_holder(holder)
        self:super(Seat).__init__(self, pos, shape)
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
        -- we need to be able to click on the seats not just the committee so that the player can choose
        -- which of the enemies' dudes to replace.
        -- seat update is done on the committee level so that we can reseat everyone by allegiance
        self.committee:update_seat(self.holder, player)
    end,

    draw = function(self, offset)
        self:super(Seat).draw(self, offset)

        -- draw vote flag
        if self.state == 'yea' then
            lg.setColor(0, 255, 0, 200)
        elseif self.state == 'nay' then
            lg.setColor(255, 0, 0, 200)
        end
        if self.state == 'yea' or self.state == 'nay' then
            lg.rectangle('fill', self.pos.x, self.pos.y, self.shape.x, self.shape.y * 0.3)
        end
    end
}