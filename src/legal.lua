class = require "extern/slither"

GAME_HEIGHT = 600

class "Slot" (Object) {
    width = 16,
    __init__ = function(self, local_pos, parent)
        self.local_pos = local_pos
        self.parent = parent
        self.color = {0, 0, 0, 255 }
        self.state = "neutral"
        self:super__init__(self.parent.pos + local_pos, v(self.width-1, 32))
    end,

    set_state = function(self, state)
        self.state = state
        if state == "hate" then
            self.color = {255, 0, 0, 255 }
        elseif state == "like" then
            self.color = {0, 255, 0, 255 }
        elseif state == "neutral" then
            self.color = {0, 0, 0, 255 }
        else
            assert(false, state.." is not a valid state")
        end
    end,

    update = function(self, dt)
        self.pos = self.parent.pos + self.local_pos
        self.dead = self.parent.dead
    end,

    influence = function(self)
        if self.state == "neutral" and player.influence > 0 then
            player.influence = player.influence - 1
            self:set_state("like")
        elseif self.state == "like" and player.influence <= 0 then
            player.influence = player.influence + 1
            self:set_state("neutral")
        end
    end
}

class "LegislationTable" {
    __init__ = function(self)
        self.speed = GAME_HEIGHT / 30.0
        self.bar_height = 64
        self.y = self.bar_height
        self.n = 0
    end,

    update = function(self, dt)
        if (self.y >= self.bar_height * self.n) then
            self.n = self.n + 1
            self:make_legislation()
        end
        self.y = self.y + self.speed * dt;
    end,

    make_legislation = function(self)
        local n_haters = 0
        if player.haters > 0 then
            player.haters = player.haters - 1
            n_haters = 1
        end
        Construction(self.n, 10, n_haters)
    end
}
legislationTable = LegislationTable()

class "Legislation"(Object) {
    __init__ = function(self, idx, n_slots, haters)
        self:setup(idx, n_slots, haters)
    end,

    setup = function(self, idx, n_slots, haters)
        self.idx = idx
        self.n_slots = n_slots
        self.haters = haters
        self:super__init__(v(0, 0), v(300, legislationTable.bar_height))

        self.slots = {}
        for i = 0,self.n_slots-1 do
            local slot = Slot(v(100 + i * Slot.width, 0), self)
            if i >= self.n_slots - haters then
                slot:set_state('hate')
            end
            table.insert(self.slots, slot)
        end
    end,

    update = function(self, dt)
        self.pos = v(500, legislationTable.y - legislationTable.bar_height * self.idx);
        if self.pos.y > (GAME_HEIGHT - legislationTable.bar_height) then
            local fors = lume.count(self.slots, function(s) return s.state == "like" end)
            local againsts = lume.count(self.slots, function(s) return s.state == "hate" end)
            if fors > againsts then
                self:execute()
            end
            self:destroy()
        end
    end,

    execute = function(self)
        log.trace("execute is supposed to be overwritten")
    end,
}

class "Construction" (Legislation) {
    __init__ = function(self, idx, n_slots, haters)
        self.building_shape = lume.randomchoice(Building.SHAPES)
        self.building_type = lume.randomchoice(lume.keys(Building.TYPES))
        self:setup(idx, n_slots, haters)
    end,

    execute = function(self)
        local building = Building(self.building_shape, self.building_type)
        table.insert(player.building_queue, building)
    end,

    draw = function(self)
        love.graphics.setColor(255, 255, 255, 255)
        love.graphics.rectangle("fill", self.pos.x, self.pos.y + 5, self.shape.x, self.shape.y)
        love.graphics.setColor(0, 0, 0, 255)
        love.graphics.print("Construction", self.pos.x, self.pos.y + 10)
        love.graphics.print(self.building_shape.." "..self.building_type, self.pos.x, self.pos.y + 20)
    end
}
