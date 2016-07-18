class "Committee" (Object) {
    HEIGHT = 64,

    __init__ = function(self, pos, type)
        self.type = type
        self.base_color = Map.TYPES[self.type]
        self.color = self.base_color
        self:super__init__(pos, v(GAME_WIDTH - pos.x, Committee.HEIGHT - 5))
    end,

    update = function(self)
        if lume.find(map.active_committees, self.type) == nil then
            self.color = {self.color[1], self.color[2], self.color[3], 200}
        else
            self.color = {self.color[1], self.color[2], self.color[3], 50}
        end
    end,
}