-- Temporary to show that AI seats can't be replaced until neutrals are gone
I_AM_AN_AI_PLAYER = {color= {0, 0, 0},
                     big_dudes = 2 }

class "CommitteeTray" (Object) {
    __init__ = function(self, x)
        self:super(CommitteeTray).__init__(self, v(x, 0), v(GAME_WIDTH - x, GAME_HEIGHT))
        self.committees = {}
        for type_i, type in ipairs(lume.keys(Map.TYPES)) do
            local com = Committee(v(self.pos.x, (type_i) * Committee.HEIGHT), type)
            table.insert(self.committees, com)
        end
    end,

    draw = function(self)
        -- draw transparent block
        local old_blend_mode = lg.getBlendMode()
        lg.setBlendMode("multiply")
        lg.setColor(100, 100, 100, 100)
        lg.rectangle('fill', self.pos.x, 0, GAME_WIDTH, GAME_HEIGHT)
        lg.setBlendMode(old_blend_mode)
    end
}

class "Committee" (Object) {
    HEIGHT = 64,
    MARGIN = 15,

    __init__ = function(self, pos, type)
        self.type = type
        self.base_color = Map.TYPES[self.type]
        self.color = self.base_color
        self.n_seats = 10
        self:super(Committee).__init__(self, pos, v(GAME_WIDTH - pos.x, Committee.HEIGHT - 5))

        -- generate seats
        self.seats = {}
        local seat_pos = self.pos + self.MARGIN
        local seat_shape = self.shape - 2 * self.MARGIN
        seat_shape.x = (seat_shape.x / self.n_seats)
        for i = 0,self.n_seats - 1 do
            local seat = Seat(seat_pos + v(i * seat_shape.x, 0), seat_shape - v(2, 0), "neutral", self)
            table.insert(self.seats, seat)
        end
        self.seat_holders = {neutral=self.n_seats }
        self.seat_holders[player] = 0
        for _, AI in ipairs(AIs) do
            self.seat_holders[AI] = 0
        end
        self.holder_order = lume.concat({player, 'neutral'}, AIs)

        -- TODO: this is temporary to demonstrate AI players hold seats until all neutrals are gone
        self:update_seat("neutral", I_AM_AN_AI_PLAYER)
    end,

    update = function(self)

        local alpha = 255
        if player.building == nil then
            alpha = 255
            for _, seat in ipairs(self.seats) do
                seat.state = 'idle'
            end
        elseif lume.find(map.active_types, self.type) == nil then  -- committee not active
            alpha = 50
            for _, seat in ipairs(self.seats) do
                seat.state = 'inactive'
            end
        else  -- committee is active
            -- set whether the seats approve
            local neutral_i = 0
            for _, seat in ipairs(self.seats) do
                if seat.holder == player then
                    seat.state = 'yea'
                elseif seat.holder == 'neutral' then
                    neutral_i = neutral_i + 1
                    if neutral_i / self.seat_holders['neutral'] <= map.hovered_popularity then
                        seat.state = 'yea'
                    else
                        seat.state = 'nay'
                    end
                else
                    seat.state = 'nay'
                end
            end
        end
        self.color = {self.color[1], self.color[2], self.color[3], alpha}
    end,

    update_seat = function(self, former, incoming)
        assert(self.seat_holders[former] ~= nil)
        if former == incoming then return end

        -- can't replace non-neutral if neutrals exist
        if former ~= 'neutral' and self.seat_holders[former] > 0 then return end

        -- subtract big dude from the incoming party
        if incoming ~= "neutral" then
            if incoming.big_dudes <= 0 then return end
            incoming.big_dudes = incoming.big_dudes - 1
        end

        -- update seat holder counts
        self.seat_holders[former] = self.seat_holders[former] - 1
        self.seat_holders[incoming] = self.seat_holders[incoming] + 1

        -- reshuffle seats to reflect count
        local idx = 1
        for _, holder in ipairs(self.holder_order) do
            for _ = 1,self.seat_holders[holder] do
                self.seats[idx]:set_holder(holder)
                idx = idx + 1
            end
        end
    end,

    check_pass = function(self, builder, popularity)
        local neutral_votes = self.seat_holders["neutral"] * popularity
        return neutral_votes + self.seat_holders[builder] > self.n_seats / 2
    end
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

    on_click = function(self, mousepos)
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