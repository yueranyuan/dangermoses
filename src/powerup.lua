class "Powerup" (Object) {
    powerups = {},
    __init__ = function(self, possible_targets, n_turns)
        assert(possible_targets ~= nil, "targets must be set for a powerup")
        if n_turns == nil then
            n_turns = 0
        end

        self.possible_targets = possible_targets
        self.n_turns = n_turns
        self.turn_i = 0
        self:super(Powerup).__init__(self)
    end,

    is_usable = function(self)
        return true, nil
    end,

    provide_target = function(self, target)
        -- Return true if powerup has been used. Return false if more targets are needed
        self.target = target
        return true
    end,

    next = function(self)
        self.turn_i = self.turn_i + 1
        if self.turn_i >= self.n_turns then
            self:unuse()
        end
    end,

    use = function(self, target)
        table.insert(Powerup.powerups, self)
        if self.n_turns > 0 then
            table.insert(target.powerups, self)
        else
            self:destroy()
            lume.remove(Powerup.powerups, self)
        end
        self.target = target
        self:_use(target)
    end,

    unuse = function(self, target)
        if self.n_turns == 0 then
            return
        end
        if target == nil then
            target = self.target
        end
        self:_unuse(target)
        lume.remove(target.powerups, self)
        lume.remove(Powerup.powerups, self)
        self:destroy()
    end,

    draw = function()
    end
}

class "StrongArm" (Powerup) {
    name = "strongarm",
    __init__ = function(self)
        self:super(StrongArm).__init__(self, government.committees, 1)
    end,

    _use = function(self, target)
        target.extra_votes = target.extra_votes + 1
    end,

    _unuse = function(self, target)
        target.extra_votes = target.extra_votes - 1
    end
}

class "Shutdown" (Powerup) {
    name = "shutdown",
    __init__ = function(self)
        self:super(Shutdown).__init__(self, government.committees, 1)
    end,

    _use = function(self, target)
        self.cached_closed = target.closed
        target.closed = true
    end,

    _unuse = function(self, target)
        assert(self.cached_closed ~= nil, "cached_closed is nil. Was use() called?")
        target.closed = self.cached_closed
    end
}

class "GoodPublicity" (Powerup) {
    name = "goodpublcty",
    __init__ = function(self)
        self:super(GoodPublicity).__init__(self, government:get_laws(), 0)
    end,

    _use = function(self, target)
        target.n_haters = math.max(0, target.n_haters - 1)
    end,
}

class "Swap" (Powerup) {
    name = "swap",
    __init__ = function(self)
        local targets = lume.map(government.rooms)
        lume.remove(targets, government.mayor_office)
        self:super(Swap).__init__(self, targets, 0)
    end,

    _use = function(self, target)
        -- swap rooms
        local idx1 = lume.find(government.rooms, target[1])
        local idx2 = lume.find(government.rooms, target[2])
        government.rooms[idx1] = target[2]
        government.rooms[idx2] = target[1]
        -- swap positions
        local pos_temp = target[1].pos:clone()
        target[1]:move_with_children(target[2].pos)
        target[2]:move_with_children(pos_temp)
        -- swap laws
        local law_temp = target[1].law
        target[1].law = target[2].law
        if target[1].law ~= nil then
            target[1].law:set_room(target[1])
        end
        target[2].law = law_temp
        if target[2].law ~= nil then
            target[2].law:set_room(target[2])
        end
    end,

    provide_target = function(self, target)
        if self.target and #self.target == 1 then
            table.insert(self.target, target)
            return true
        else
            self.target = {target}
            lume.remove(self.possible_targets, target)
            return false
        end
    end,
}

class "Mislabel" (Powerup) {
    name = "mislabel",
    __init__ = function(self)
        self:super(Mislabel).__init__(self, building_button_tray.buttons, 0)
    end,

    provide_target = function(self, target)
        if self.target and #self.target == 1 then
            table.insert(self.target, target)
            return true
        else
            self.target = {target }
            self.possible_targets = lume.filter(government.committees, 'type')
            for com_i, com in lume.ripairs(self.possible_targets) do
                if com.type == self.target[1].building.type then
                    table.remove(self.possible_targets, com_i)
                end
            end
            return false
        end
    end,

    _use = function(self, target)
        target[1].building:change_type(self.target[2].type)
    end,
}

class "Appeal" (Powerup) {
    name = "appeal",
    __init__ = function(self)
        self:super(Appeal).__init__(self, government:get_laws(), 0)
    end,

    is_usable = function(self)
        if government.rooms[1].laws == nil then
            return true, nil
        else
            return false, "can only appeal when nothing is being built"
        end
    end,

    _use = function(self, target)
        target.n_failures = 0
        target.current_room.law = nil
        target:set_room(government.rooms[1])
        government.rooms[1].law = target
    end,
}
