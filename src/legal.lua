-- Temporary to show that AI seats can't be replaced until neutrals are gone
I_AM_AN_AI_PLAYER = {color= {0, 0, 0},
                     big_dudes = 2 }

class "Committee" (Object) {
    HEIGHT = 64,
    MARGIN = 15,

    __init__ = function(self, pos, type)
        self.type = type
        self.base_color = Map.TYPES[self.type]
        self.color = self.base_color
        self.n_seats = 10
        self:super__init__(pos, v(GAME_WIDTH - pos.x, Committee.HEIGHT - 5))

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

        -- TODO: this is temporary to demonstrate AI players hold seats until all neutrals are gone
        self:update_seat("neutral", I_AM_AN_AI_PLAYER)
    end,

    update = function(self)
        if lume.find(map.active_types, self.type) == nil then
            self.color = {self.color[1], self.color[2], self.color[3], 200}
        else
            self.color = {self.color[1], self.color[2], self.color[3], 50}
        end
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
        for holder, n in pairs(self.seat_holders) do  -- TODO: this ordering should be global across committees
            for _ = 1,n do
                self.seats[idx]:set_holder(holder)
                idx = idx + 1
            end
        end
    end
}

class "Seat" (Object) {
    __init__ = function(self, pos, shape, holder, committee)
        self.committee = committee
        self:set_holder(holder)
        self:super__init__(pos, shape)
    end,

    set_holder = function(self, holder)
        self.holder = holder
        if holder == "neutral" then
            self.color = {100, 100, 100}
        else
            self.color = holder.color
        end
    end,

    on_click = function(self, mousepos)
        -- we need to be able to click on the seats not just the committee so that the player can choose
        -- which of the enemies' dudes to replace.
        -- seat update is done on the committee level so that we can reseat everyone by allegiance
        self.committee:update_seat(self.holder, player)
    end
}