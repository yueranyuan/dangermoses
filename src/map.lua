class "Powerup"(Object) {
    __init__ = function(self, pos, type)
        self.img = love.graphics.newImage("grafix/game_icon.png")
        self.type = type
        self.hovering = false
        self:super__init__(pos)
    end,

    update = function(self, dt)
        if self.hovering then
            self.hovering = false
        else
            self.color = Building.TYPES[self.type]
        end
    end,

    hit = function(self, building)
        if building.type == self.type then
            player.influence = player.influence + 1
        else
            player.haters = player.haters + 1
        end
        self:destroy()
    end,

    hover = function(self, building)
        self.hovering = true
        if building.type == self.type then
            self.color = {0, 255, 0, 255}
        else
            self.color = {255, 0, 0, 255}
        end
    end
}

class "Building"(Object) {
    TYPES = {park={0, 255, 0, 100}, house={255, 0, 0, 100}, road={0, 0, 255, 100}},
    SHAPES = {"eagle", "scorp", "moses-lot"},

    __init__ = function(self, shape, type)
        self.img = love.graphics.newImage("grafix/"..shape..".png")
        self.type = type
        self.state = "waiting"
        self.color = self.TYPES[self.type]
        self:super__init__(v(0, 0))
    end,

    update = function(self)
        self.shown = self.state ~= "waiting"
    end,

    build = function(self)
        self.state = "built"
    end
}


